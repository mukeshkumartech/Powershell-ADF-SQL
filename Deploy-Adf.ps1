param(
    [string]$ResourceGroupName,
    [string]$DataFactoryName,
    [string]$AdfRootFolder
)

# --- Default to the working directory ---
if (-not $AdfRootFolder) {
    $AdfRootFolder = $env:SYSTEM_DEFAULTWORKINGDIRECTORY
}

Write-Host "Using ADF root folder: $AdfRootFolder"

# --- Ensure TLS 1.2 for PowerShell Gallery ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Install latest version of the module ---
Write-Host "Installing required module..."
try {
    Uninstall-Module azure.datafactory.tools -AllVersions -Force -ErrorAction SilentlyContinue
} catch { Write-Host "No existing module found, skipping uninstall." }

Install-Module azure.datafactory.tools -Scope CurrentUser -Force -AllowClobber -AllowPrerelease
Import-Module azure.datafactory.tools -Force

# --- Show installed version ---
$adfToolsVersion = (Get-Module azure.datafactory.tools).Version
Write-Host "Using azure.datafactory.tools version: $adfToolsVersion"

# --- Connect to Azure ---
Write-Host "Connecting to Azure..."
$ctx = Get-AzContext
if (-not $ctx) {
    Write-Host "No existing Azure context found. Trying managed identity or release connection..."
}
Write-Host "Connected to subscription: $($ctx.Subscription.Id)"

# --- Determine config path ---
$stage = "dev"
$configFile = Join-Path $AdfRootFolder "Config\config-$stage.json"

if (-not (Test-Path $configFile)) {
    Write-Warning "Configuration file not found: $configFile"
    Write-Host "Using default configuration values"
    $config = @{
        SqlServer = "sqldemo-12345.database.windows.net"
        DatabaseName = "TestDatabase"
        TableName = "TestTable"
        Location = "East US"
    }
} else {
    Write-Host "Using configuration file: $configFile"
    $config = Get-Content $configFile | ConvertFrom-Json
}

# --- Create deployment folder and CSV config ---
$deploymentFolder = Join-Path $AdfRootFolder "deployment"
if (-not (Test-Path $deploymentFolder)) {
    New-Item -ItemType Directory -Path $deploymentFolder -Force
    Write-Host "Created deployment folder: $deploymentFolder"
}

$csvConfigFile = Join-Path $deploymentFolder "config-$stage.csv"
if (-not (Test-Path $csvConfigFile)) {
    # Create CSV config with proper values from JSON config
    $sqlServer = if ($config.SqlServer) { $config.SqlServer } else { "sqldemo-12345.database.windows.net" }
    $databaseName = if ($config.DatabaseName) { $config.DatabaseName } else { "TestDatabase" }
    $tableName = if ($config.TableName) { $config.TableName } else { "TestTable" }
    
   $csvContent = @"
type,name,path,value
pipeline,ExecutePowerShellScript,parameters.SqlServer.defaultValue,$sqlServer
pipeline,ExecutePowerShellScript,parameters.DatabaseName.defaultValue,$databaseName
pipeline,ExecutePowerShellScript,parameters.TableName.defaultValue,$tableName
"@
    $csvContent | Out-File -FilePath $csvConfigFile -Encoding UTF8
    Write-Host "Created CSV config file: $csvConfigFile"
    Write-Host "CSV Configuration:"
    Write-Host "  SQL Server: $sqlServer"
    Write-Host "  Database: $databaseName"
    Write-Host "  Table: $tableName"
} else {
    Write-Host "Using existing CSV config file: $csvConfigFile"
}

# --- Prepare parameters for ADF deployment ---
$commonParams = @{
    RootFolder        = $AdfRootFolder
    ResourceGroupName = $ResourceGroupName
    DataFactoryName   = $DataFactoryName
    Location          = if ($config.Location) { $config.Location } else { "East US" }
    Stage             = $stage
    DryRun            = $false
}

# --- Handle optional DeleteNotInSource flag ---
$hasDeleteParam = (Get-Command Publish-AdfV2FromJson).Parameters.ContainsKey('DeleteNotInSource')
if ($hasDeleteParam) {
    $deleteFlag = if ($config.PSObject.Properties.Name -contains 'DeleteNotInSource') { 
        [bool]$config.DeleteNotInSource 
    } else { 
        $false 
    }
    Write-Host "Using parameter -DeleteNotInSource $deleteFlag"
    $commonParams['DeleteNotInSource'] = $deleteFlag
} else {
    Write-Host "Module version $adfToolsVersion does not support -DeleteNotInSource. Skipping that parameter."
}

# --- Run publish ---
Write-Host "Publishing ADF from JSON files..."
Write-Host "Parameters:"
$commonParams.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key): $($_.Value)" }

Publish-AdfV2FromJson @commonParams

Write-Host "✅ ADF deployment completed successfully!"
