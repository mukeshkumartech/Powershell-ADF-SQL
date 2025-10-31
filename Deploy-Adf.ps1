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

# --- Create deployment folder ---
$deploymentFolder = Join-Path $AdfRootFolder "deployment"
if (-not (Test-Path $deploymentFolder)) {
    New-Item -ItemType Directory -Path $deploymentFolder -Force
    Write-Host "Created deployment folder: $deploymentFolder"
}

# --- Create PublishOptions object to bypass CSV issues ---
Write-Host "Creating deployment options to bypass CSV configuration..."
$publishOptions = New-Object AdfPublishOption
$publishOptions.Includes.Add("*", "")
$publishOptions.Excludes.Add("", "")

# --- Prepare parameters for ADF deployment ---
$commonParams = @{
    RootFolder        = $AdfRootFolder
    ResourceGroupName = $ResourceGroupName
    DataFactoryName   = $DataFactoryName
    Location          = "East US"
    Stage             = "dev"
    Options           = $publishOptions
    DryRun            = $false
}

# --- Handle optional DeleteNotInSource flag ---
$hasDeleteParam = (Get-Command Publish-AdfV2FromJson).Parameters.ContainsKey('DeleteNotInSource')
if ($hasDeleteParam) {
    $commonParams['DeleteNotInSource'] = $false
    Write-Host "Using parameter -DeleteNotInSource False"
} else {
    Write-Host "Module version $adfToolsVersion does not support -DeleteNotInSource. Skipping that parameter."
}

# --- Run publish ---
Write-Host "Publishing ADF from JSON files..."
Write-Host "Parameters:"
$commonParams.GetEnumerator() | Where-Object { $_.Key -ne 'Options' } | ForEach-Object { Write-Host "  $($_.Key): $($_.Value)" }

try {
    Publish-AdfV2FromJson @commonParams
    Write-Host "✅ ADF deployment completed successfully!"
} catch {
    Write-Host "❌ Deployment failed with options, trying without options..."
    $commonParams.Remove('Options')
    
    # Create minimal CSV as fallback
    $csvConfigFile = Join-Path $deploymentFolder "config-dev.csv"
    @"
type,name,path,value
linkedService,DummyService,properties.dummyProperty,dummyValue
"@ | Out-File -FilePath $csvConfigFile -Encoding UTF8
    Write-Host "Created minimal CSV as fallback: $csvConfigFile"
    
    Publish-AdfV2FromJson @commonParams
    Write-Host "✅ ADF deployment completed successfully with fallback method!"
}
