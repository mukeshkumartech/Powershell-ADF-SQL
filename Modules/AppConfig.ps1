# AppConfig.ps1 - Application configuration management (PowerShell 7+)
using namespace System.Collections.Generic

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
    
    # Constructor that accepts parameters (PowerShell 7+ null-coalescing operator)
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
    
    # Static factory method for JSON configuration
    static [AppConfig] FromJsonFile([string] $jsonFilePath) {
        if (-not (Test-Path $jsonFilePath)) {
            throw "Configuration file not found: $jsonFilePath"
        }
        
        $jsonContent = Get-Content $jsonFilePath -Raw | ConvertFrom-Json
        $configHash = @{}
        
        # Convert PSObject to hashtable
        $jsonContent.PSObject.Properties | ForEach-Object { 
            $configHash[$_.Name] = $_.Value 
        }
        
        return [AppConfig]::new($configHash)
    }
    
    hidden [string] GetEnvValue([string] $envVarName, [string] $defaultValue) {
        return $env:$envVarName ?? $defaultValue
    }
    
    hidden [void] ValidateConfiguration() {
        $errors = [List[string]]::new()
        
        if ([string]::IsNullOrWhiteSpace($this.SqlServer)) {
            $errors.Add("SQL_SERVER environment variable is required")
        }
        
        if ([string]::IsNullOrWhiteSpace($this.DatabaseName)) {
            $errors.Add("DATABASE_NAME environment variable is required")
        }
        
        if ([string]::IsNullOrWhiteSpace($this.KeyVaultName)) {
            $errors.Add("KEY_VAULT_NAME environment variable is required")
        }
        
        if ($this.RunIntervalMinutes -le 0) {
            $errors.Add("RUN_INTERVAL_MINUTES must be greater than 0")
        }
        
        if ($this.MaxIterations -le 0) {
            $errors.Add("MAX_ITERATIONS must be greater than 0")
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
    
    # Convert to JSON for serialization
    [string] ToJson() {
        $configObject = @{
            Environment = $this.Environment
            SqlServer = $this.SqlServer
            DatabaseName = $this.DatabaseName
            TableName = $this.TableName
            KeyVaultName = $this.KeyVaultName
            ServicePrincipalName = $this.ServicePrincipalName
            ContinuousMode = $this.ContinuousMode
            RunIntervalMinutes = $this.RunIntervalMinutes
            MaxIterations = $this.MaxIterations
        }
        
        return $configObject | ConvertTo-Json -Depth 3
    }
}
