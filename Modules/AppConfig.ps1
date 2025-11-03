# AppConfig.ps1 - Application configuration management
. "$PSScriptRoot/Constants.ps1"

class AppConfig {
    [string] $Environment
    [string] $SqlServer
    [string] $DatabaseName
    [string] $TableName
    [string] $KeyVaultName
    [string] $ServicePrincipalName
    [bool] $ContinuousMode
    [int] $RunIntervalMinutes
    [int] $MaxIterations
    
    # Constructor that reads from environment variables with defaults
    AppConfig() {
        $this.Environment = $this.GetEnvValue("ENVIRONMENT", "Development")
        $this.SqlServer = $this.GetEnvValue("SQL_SERVER", $null)
        $this.DatabaseName = $this.GetEnvValue("DATABASE_NAME", $null)
        $this.TableName = $this.GetEnvValue("TABLE_NAME", "TestTable")
        $this.KeyVaultName = $this.GetEnvValue("KEY_VAULT_NAME", $null)
        $this.ServicePrincipalName = $this.GetEnvValue("SERVICE_PRINCIPAL_NAME", "sp-sql-automation")
        $this.ContinuousMode = [bool]::Parse($this.GetEnvValue("CONTINUOUS_MODE", "false"))
        $this.RunIntervalMinutes = [int]($this.GetEnvValue("RUN_INTERVAL_MINUTES", [AzureConstants]::DefaultRunIntervalMinutes.ToString()))
        $this.MaxIterations = [int]($this.GetEnvValue("MAX_ITERATIONS", [AzureConstants]::DefaultMaxIterations.ToString()))
        
        $this.ValidateConfiguration()
    }
    
    # Constructor that accepts parameters (for testing or manual configuration)
    AppConfig([hashtable] $configParams) {
        $this.Environment = $configParams.Environment ?? "Development"
        $this.SqlServer = $configParams.SqlServer
        $this.DatabaseName = $configParams.DatabaseName
        $this.TableName = $configParams.TableName ?? "TestTable"
        $this.KeyVaultName = $configParams.KeyVaultName
        $this.ServicePrincipalName = $configParams.ServicePrincipalName ?? "sp-sql-automation"
        $this.ContinuousMode = $configParams.ContinuousMode ?? $false
        $this.RunIntervalMinutes = $configParams.RunIntervalMinutes ?? [AzureConstants]::DefaultRunIntervalMinutes
        $this.MaxIterations = $configParams.MaxIterations ?? [AzureConstants]::DefaultMaxIterations
        
        $this.ValidateConfiguration()
    }
    
    hidden [string] GetEnvValue([string] $envVarName, [string] $defaultValue) {
        $value = [System.Environment]::GetEnvironmentVariable($envVarName)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $defaultValue
        }
        return $value
    }
    
    hidden [void] ValidateConfiguration() {
        $errors = @()
        
        if ([string]::IsNullOrWhiteSpace($this.SqlServer)) {
            $errors += "SQL_SERVER environment variable is required"
        }
        
        if ([string]::IsNullOrWhiteSpace($this.DatabaseName)) {
            $errors += "DATABASE_NAME environment variable is required"
        }
        
        if ([string]::IsNullOrWhiteSpace($this.KeyVaultName)) {
            $errors += "KEY_VAULT_NAME environment variable is required"
        }
        
        if ($this.RunIntervalMinutes -le 0) {
            $errors += "RUN_INTERVAL_MINUTES must be greater than 0"
        }
        
        if ($this.MaxIterations -le 0) {
            $errors += "MAX_ITERATIONS must be greater than 0"
        }
        
        if ($errors.Count -gt 0) {
            throw "Configuration validation failed:`n" + ($errors -join "`n")
        }
    }
    
    [void] DisplayConfiguration() {
        Write-Host "`n=== Application Configuration ===" -ForegroundColor Green
        Write-Host "Environment: $($this.Environment)" -ForegroundColor Cyan
        Write-Host "SQL Server: $($this.SqlServer)" -ForegroundColor Cyan
        Write-Host "Database: $($this.DatabaseName)" -ForegroundColor Cyan
        Write-Host "Table: $($this.TableName)" -ForegroundColor Cyan
        Write-Host "Key Vault: $($this.KeyVaultName)" -ForegroundColor Cyan
        Write-Host "Service Principal: $($this.ServicePrincipalName)" -ForegroundColor Cyan
        Write-Host "Continuous Mode: $($this.ContinuousMode)" -ForegroundColor Cyan
        Write-Host "Run Interval: $($this.RunIntervalMinutes) minutes" -ForegroundColor Cyan
        Write-Host "Max Iterations: $($this.MaxIterations)" -ForegroundColor Cyan
        Write-Host "================================`n" -ForegroundColor Green
    }
}
