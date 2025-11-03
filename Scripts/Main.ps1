using namespace System.Collections.Generic
using namespace System.IO
#Requires -Version 7.0

# Main.ps1 - Entry point with PowerShell 7+ features
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

# Enhanced logging function with structured logging
function Write-LogMessage {
    param(
        [string] $Message, 
        [string] $Level = [AzureConstants]::LogLevelInfo,
        [hashtable] $Properties = @{}
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = @{
        Timestamp = $timestamp
        Level = $Level
        Message = $Message
        Properties = $Properties
    }
    
    # Set color based on level
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "INFO"  { "Green" }
        default { "White" }
    }
    
    # Display structured log entry
    $logMessage = "[$timestamp] [$Level] $Message"
    if ($Properties.Count -gt 0) {
        $logMessage += " | $($Properties | ConvertTo-Json -Compress)"
    }
    
    Write-Host $logMessage -ForegroundColor $color
}

# Global error handling
$ErrorActionPreference = "Stop"

try {
    Write-LogMessage "=== PowerShell SQL Automation Started ===" "INFO" @{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        OS = $PSVersionTable.OS
    }
    
    # Load configuration using modern PowerShell 7+ features
    Write-LogMessage "Loading application configuration..." "INFO"
    
    $config = if ($ConfigFilePath -and (Test-Path $ConfigFilePath)) {
        # Load from JSON file using static factory method
        [AppConfig]::FromJsonFile($ConfigFilePath)
    } else {
        # Load from environment variables
        [AppConfig]::new()
    }
    
    # Display configuration
    $config.DisplayConfiguration()
    
    $iteration = 0
    $totalErrors = 0
    $executionResults = [List[hashtable]]::new()

    do {
        $iteration++
        $iterationStartTime = Get-Date
        
        Write-LogMessage "=== Starting Iteration $iteration of $($config.MaxIterations) ===" "INFO" @{
            Iteration = $iteration
            MaxIterations = $config.MaxIterations
        }
        
        $dbConn = $null
        $conn = $null
        $iterationResult = @{
            Iteration = $iteration
            StartTime = $iterationStartTime
            Status = "Failed"
            Error = $null
            ProcessedRecords = 0
        }
        
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
            $processedCount = $processor.RunProcess()
            
            $iterationResult.ProcessedRecords = $processedCount
            $iterationResult.Status = "Success"
            $iterationResult.EndTime = Get-Date
            $iterationResult.Duration = ($iterationResult.EndTime - $iterationResult.StartTime).TotalSeconds
            
            Write-LogMessage "Iteration $iteration completed successfully." "INFO" @{
                ProcessedRecords = $processedCount
                DurationSeconds = $iterationResult.Duration
            }
            
            # Wait before next iteration (if continuous mode)
            if ($config.ContinuousMode -and $iteration -lt $config.MaxIterations) {
                Write-LogMessage "Waiting $($config.RunIntervalMinutes) minutes before next iteration..." "INFO"
                Start-Sleep -Seconds ($config.RunIntervalMinutes * 60)
            }
        }
        catch {
            $totalErrors++
            $iterationResult.Error = $_.Exception.Message
            $iterationResult.EndTime = Get-Date
            $iterationResult.Duration = ($iterationResult.EndTime - $iterationResult.StartTime).TotalSeconds
            
            Write-LogMessage "Error in iteration $iteration" "ERROR" @{
                ErrorMessage = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
                DurationSeconds = $iterationResult.Duration
            }
            
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
                    Write-LogMessage "Warning: Error closing database connection" "WARN" @{
                        ErrorMessage = $_.Exception.Message
                    }
                }
            }
            
            # Add iteration result to collection
            $executionResults.Add($iterationResult)
        }
        
    } while ($config.ContinuousMode -and $iteration -lt $config.MaxIterations)

    # Final summary with rich analytics
    $totalProcessedRecords = ($executionResults | Measure-Object -Property ProcessedRecords -Sum).Sum
    $successfulIterations = ($executionResults | Where-Object { $_.Status -eq "Success" }).Count
    $averageDuration = ($executionResults | Measure-Object -Property Duration -Average).Average
    
    Write-LogMessage "=== PowerShell SQL Automation Completed ===" "INFO" @{
        TotalIterations = $iteration
        SuccessfulIterations = $successfulIterations
        TotalErrors = $totalErrors
        TotalProcessedRecords = $totalProcessedRecords
        AverageDurationSeconds = [math]::Round($averageDuration, 2)
        SuccessRate = [math]::Round(($successfulIterations / $iteration) * 100, 2)
    }
    
    if ($totalErrors -eq 0) {
        Write-LogMessage "All iterations completed successfully!" "INFO"
        exit 0
    } else {
        Write-LogMessage "Completed with $totalErrors errors. Check logs for details." "WARN"
        exit 0  # Exit successfully even with errors in continuous mode
    }
}
catch {
    Write-LogMessage "Fatal error in main execution" "ERROR" @{
        ErrorMessage = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }
    exit 1
}
