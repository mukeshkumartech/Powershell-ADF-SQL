
#Requires -Version 7.0
# Test-LocalExecution.ps1 - PowerShell 7+ local testing script
param(
    [string] $KeyVaultName = "kv-sql-demo-dev",
    [string] $SqlServer = "sqldemo-12345.database.windows.net",
    [string] $DatabaseName = "TestDatabase"


using namespace System.Collections.Generic

Write-Host "Setting up environment variables for local testing..." -ForegroundColor Green

# Set environment variables using PowerShell 7+ features
$envVars = @{
    ENVIRONMENT = "Development"
    SQL_SERVER = $SqlServer
    DATABASE_NAME = $DatabaseName
    TABLE_NAME = "EmployeeData"
    KEY_VAULT_NAME = $KeyVaultName
    SERVICE_PRINCIPAL_NAME = "sp-sql-automation"
    CONTINUOUS_MODE = "false"
    RUN_INTERVAL_MINUTES = "1"
    MAX_ITERATIONS = "1"
}

# Set all environment variables
$envVars.GetEnumerator() | ForEach-Object {
    Set-Item -Path "env:$($_.Key)" -Value $_.Value
    Write-Host "  $($_.Key) = $($_.Value)" -ForegroundColor Cyan
}

Write-Host "Environment variables set. Starting Main.ps1..." -ForegroundColor Green

# Verify PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "This script requires PowerShell 7 or higher. Current version: $($PSVersionTable.PSVersion)"
    Write-Host "Please install PowerShell 7+ from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
    exit 1
}

# Run the main script with enhanced error handling
try {
    $startTime = Get-Date
    & "$PSScriptRoot/Main.ps1"
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Host "Test execution completed successfully!" -ForegroundColor Green
    Write-Host "Execution time: $([math]::Round($duration, 2)) seconds" -ForegroundColor Cyan
}
catch {
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    throw
}
finally {
    # Clean up environment variables if needed
    Write-Host "Test completed." -ForegroundColor Green
}
