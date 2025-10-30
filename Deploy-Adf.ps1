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

# --- Build config file path ---
$configFile = Join-Path $AdfRootFolder "deployment\config-dev.json"
if (-not (Test-Path $configFile)) {
    Write-Error "❌ Configuration file not found: $configFile"
    exit 1
}
Write-Host "Using configuration file: $configFile"

# --- Prepare parameters ---
$commonParams = @{
    RootFolder        = $AdfRootFolder
    ResourceGroupName = $ResourceGroupName
    DataFactoryName   = $DataFactoryName
    Location          = "East US"
    Stage             = "dev"
    ConfigurationFile = $configFile
    DryRun            = $false
}

# --- Detect if DeleteNotInSource is supported ---
$hasDeleteParam = (Get-Command Publish-AdfV2FromJson).Parameters.ContainsKey('DeleteNotInSource')
if ($hasDeleteParam) {
    Write-Host "Using parameter -DeleteNotInSource $false"
    $commonParams['DeleteNotInSource'] = $false
} else {
    Write-Host " Module version $adfToolsVersion does not support -DeleteNotInSource. Skipping that parameter."
}

# --- Run publish ---
Write-Host "Publishing ADF from JSON files..."
Publish-AdfV2FromJson @commonParams

Write-Host "✅ ADF deployment completed successfully!"
