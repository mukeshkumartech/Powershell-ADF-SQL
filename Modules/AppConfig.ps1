# AppConfig.ps1 - Application configuration management (PowerShell 5.1/7+ Compatible)
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
        $this.RunIntervalMinutes = [int]($this.GetEnvValue("RUN_INTERVAL_MINUTES", "30"))
        $this.MaxIterations = [int]($this.GetEnvValue("MAX_ITERATIONS", "10"))
        
        $this.ValidateConfiguration()
    }
    
    # Constructor that accepts parameters (compatible version)
    AppConfig([hashtable] $configParams) {
        if ($configParams.Environment) {
            $this.Environment = $configParams.Environment
        } else {
            $this.Environment = "Development"
        }
        
        $this.SqlServer = $configParams.SqlServer
        $this.DatabaseName = $configParams.DatabaseName
        
        if ($configParams.TableName) {
            $this.TableName = $configParams.TableName
        } else {
            $this.TableName = "TestTable"
        }
        
        $this.KeyVaultName = $configParams.KeyVaultName
        
        if ($configParams.ServicePrincipalName) {
            $this.ServicePrincipalName = $configParams.ServicePrincipalName
        } else {
            $this.ServicePrincipalName = "sp-sql-automation"
        }
        
        if ($configParams.ContinuousMode -ne $null) {
            $this.ContinuousMode = $configParams.ContinuousMode
        } else {
            $this.ContinuousMode = $false
        }
        
        if ($configParams.RunIntervalMinutes) {
            $this.RunIntervalMinutes = $configParams.RunIntervalMinutes
        } else {
            $this.RunIntervalMinutes = 30
        }
        
        if ($configParams.MaxIterations) {
            $this.MaxIterations = $configParams.MaxIterations
        } else {
            $this.MaxIterations = 10
        }
        
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
            throw "Configuration validation failed:`n$($errors -join "`n")"
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
