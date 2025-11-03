# Test-LocalExecution.ps1 - For testing locally before deploying to Azure DevOps
param(
    [string] $KeyVaultName = "kv-sql-automation-001",
    [string] $SqlServer = "your-server.database.windows.net",
    [string] $DatabaseName = "YourDatabase"
)

Write-Host "Setting up environment variables for local testing..." -ForegroundColor Green

# Set environment variables for testing
$env:ENVIRONMENT = "Development"
$env:SQL_SERVER = $SqlServer
$env:DATABASE_NAME = $DatabaseName
$env:TABLE_NAME = "TestTable"
$env:KEY_VAULT_NAME = $KeyVaultName
$env:SERVICE_PRINCIPAL_NAME = "sp-sql-automation"
$env:CONTINUOUS_MODE = "false"
$env:RUN_INTERVAL_MINUTES = "1"
$env:MAX_ITERATIONS = "1"

Write-Host "Environment variables set. Starting Main.ps1..." -ForegroundColor Green

# Run the main script
try {
    & "$PSScriptRoot/Main.ps1"
    Write-Host "Test execution completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
