# Main.ps1 - Entry point with complete error handling and configuration
param (
    [string] $ConfigFilePath = $null
)

# Import all required modules
try {
    . "$PSScriptRoot/../Modules/Constants.ps1"
    . "$PSScriptRoot/../Modules/AppConfig.ps1"
    . "$PSScriptRoot/../Modules/DatabaseConnection.ps1"
    . "$PSScriptRoot/../Modules/DatabaseOperations.ps1"
    . "$PSScriptRoot/Process.ps1"
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

# Enhanced logging function
function Write-LogMessage {
    param(
        [string] $Message, 
        [string] $Level = [AzureConstants]::LogLevelInfo,
        [string] $Color = "White"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Set color based on level
    switch ($Level) {
        "ERROR" { $Color = "Red" }
        "WARN"  { $Color = "Yellow" }
        "INFO"  { $Color = "Green" }
        default { $Color = "White" }
    }
    
    Write-Host $logMessage -ForegroundColor $Color
}

# Global error handling
$ErrorActionPreference = "Stop"

try {
    Write-LogMessage "=== PowerShell SQL Automation Started ===" "INFO"
    
    # Load configuration
    Write-LogMessage "Loading application configuration..." "INFO"
    
    if ($ConfigFilePath -and (Test-Path $ConfigFilePath)) {
        # Load from JSON file if provided
        $configJson = Get-Content $ConfigFilePath | ConvertFrom-Json
        $configHash = @{}
        $configJson.PSObject.Properties | ForEach-Object { $configHash[$_.Name] = $_.Value }
        $config = [AppConfig]::new($configHash)
        Write-LogMessage "Configuration loaded from file: $ConfigFilePath" "INFO"
    } else {
        # Load from environment variables
        $config = [AppConfig]::new()
        Write-LogMessage "Configuration loaded from environment variables" "INFO"
    }
    
    # Display configuration
    $config.DisplayConfiguration()
    
    $iteration = 0
    $totalErrors = 0

    do {
        $iteration++
        Write-LogMessage "=== Starting Iteration $iteration of $($config.MaxIterations) ===" "INFO"
        
        $dbConn = $null
        $conn = $null
        
        try {
            # Initialize database connection
            Write-LogMessage "Initializing database connection..." "INFO"
            $dbConn = [DatabaseConnection]::new($config.SqlServer, $config.DatabaseName)
            
            # Connect using Service Principal from Key Vault
            Write-LogMessage "Connecting to database using Service Principal from Key Vault..." "INFO"
            $conn = $dbConn.ConnectUsingServicePrincipalFromKeyVault($config.KeyVaultName, $config.ServicePrincipalName)
            
            # Test the connection
            Write-LogMessage "Testing database connection..." "INFO"
            $dbConn.TestConnection()
            
            # Initialize database operations
            Write-LogMessage "Initializing database operations..." "INFO"
            $dbOps = [DatabaseOperations]::new($conn)
            
            # Run the data processing
            Write-LogMessage "Starting data processing for table: $($config.TableName)" "INFO"
            $processor = [DataProcessor]::new($dbOps, $config.TableName)
            $processor.RunProcess()
            
            Write-LogMessage "Iteration $iteration completed successfully." "INFO"
            
            # Wait before next iteration (if continuous mode)
            if ($config.ContinuousMode -and $iteration -lt $config.MaxIterations) {
                Write-LogMessage "Waiting $($config.RunIntervalMinutes) minutes before next iteration..." "INFO"
                Start-Sleep -Seconds ($config.RunIntervalMinutes * 60)
            }
        }
        catch {
            $totalErrors++
            Write-LogMessage "Error in iteration $iteration : $($_.Exception.Message)" "ERROR"
            Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" "ERROR"
            
            # In continuous mode, wait and retry
            if ($config.ContinuousMode -and $iteration -lt $config.MaxIterations) {
                $retryDelay = [AzureConstants]::DefaultRetryDelaySeconds
                Write-LogMessage "Waiting $($retryDelay / 60) minutes before retry..." "WARN"
                Start-Sleep -Seconds $retryDelay
            } else {
                # In single run mode, exit with error
                throw
            }
        }
        finally {
            # Always clean up connections
            if ($dbConn) {
                try {
                    $dbConn.Close()
                }
                catch {
                    Write-LogMessage "Warning: Error closing database connection: $($_.Exception.Message)" "WARN"
                }
            }
        }
        
    } while ($config.ContinuousMode -and $iteration -lt $config.MaxIterations)

    # Final summary
    Write-LogMessage "=== PowerShell SQL Automation Completed ===" "INFO"
    Write-LogMessage "Total iterations completed: $iteration" "INFO"
    Write-LogMessage "Total errors encountered: $totalErrors" "INFO"
    
    if ($totalErrors -eq 0) {
        Write-LogMessage "All iterations completed successfully!" "INFO"
        exit 0
    } else {
        Write-LogMessage "Completed with $totalErrors errors. Check logs for details." "WARN"
        exit 0  # Exit successfully even with errors in continuous mode
    }
}
catch {
    Write-LogMessage "Fatal error in main execution: $($_.Exception.Message)" "ERROR"
    Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}
