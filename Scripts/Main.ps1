param (
    [string]$ConfigFilePath = "../Config/config-dev.json"
)


# --- Imports ---
. "$PSScriptRoot/../Modules/DatabaseConnection.ps1"
. "$PSScriptRoot/../Modules/DatabaseOperations.ps1"
. "$PSScriptRoot/Process.ps1"


# --- Load Config ---
if (-not (Test-Path $ConfigFilePath)) {
    throw "Configuration file not found: $ConfigFilePath"
}

$config = Get-Content $ConfigFilePath | ConvertFrom-Json

Write-Host "`n--- Starting Process ---"
Write-Host "Environment: $($config.Environment)"
Write-Host "SQL Server: $($config.SqlServer)"
Write-Host "Database: $($config.DatabaseName)"
Write-Host "Use Managed Identity: $($config.UseManagedIdentity)"

# --- Initialize and connect ---
$dbConn = [DatabaseConnection]::new($config.SqlServer, $config.DatabaseName)
$conn = $dbConn.Connect($config.UseManagedIdentity, $config.SecretsFile)

# --- Initialize DB Ops ---
$dbOps = [DatabaseOperations]::new($conn)

# --- Run the process ---
$processor = [DataProcessor]::new($dbOps, $config.TableName)
$processor.RunProcess()

# --- Cleanup ---
$conn.Close()
Write-Host "`nProcess completed successfully."
