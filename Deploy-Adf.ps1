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

# --- Determine config path (inside your project folder) ---
$stage = "dev"
$configFile = Join-Path $AdfRootFolder "_Powershell-ADF-SQL\Config\config-$stage.json"

if (-not (Test-Path $configFile)) {
    Write-Error "❌ Configuration file not found: $configFile"
    exit 1
}
Write-Host "Using configuration file: $configFile"

# --- Load JSON config manually ---
$config = Get-Content $configFile | ConvertFrom-Json

# --- Create deployment folder and empty CSV config if needed ---
$deploymentFolder = Join-Path $AdfRootFolder "deployment"
if (-not (Test-Path $deploymentFolder)) {
    New-Item -ItemType Directory -Path $deploymentFolder -Force
    Write-Host "Created deployment folder: $deploymentFolder"
}

$csvConfigFile = Join-Path $deploymentFolder "config-$stage.csv"
if (-not (Test-Path $csvConfigFile)) {
    # Create empty CSV with just headers (no environment replacements needed)
    "type,name,path,value" | Out-File -FilePath $csvConfigFile -Encoding UTF8
    Write-Host "Created empty CSV config file: $csvConfigFile"
} else {
    Write-Host "Using existing CSV config file: $csvConfigFile"
}

# --- Prepare parameters for ADF deployment ---
$commonParams = @{
    RootFolder        = $AdfRootFolder
    ResourceGroupName = $ResourceGroupName
    DataFactoryName   = $DataFactoryName
    Location          = if ($config.Location) { $config.Location } else { "East US" }
    Stage             = if ($config.Stage) { $config.Stage } else { $stage }
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
Publish-AdfV2FromJson @commonParams

Write-Host "✅ ADF deployment completed successfully!"
