param(
    [string]$ResourceGroupName,
    [string]$DataFactoryName,
    [string]$AdfRootFolder
)

if (-not $AdfRootFolder) {
    $AdfRootFolder = $env:SYSTEM_DEFAULTWORKINGDIRECTORY
}

Write-Host "Using ADF root folder: $AdfRootFolder"

Write-Host "Installing required module..."
Install-Module azure.datafactory.tools -Scope CurrentUser -Force -AllowClobber

Write-Host "Connecting to Azure..."
# use the service connection credentials (already authenticated)
$ctx = Get-AzContext
Write-Host "Connected to subscription: $($ctx.Subscription.Id)"

Write-Host "Publishing ADF from JSON files..."
Publish-AdfV2FromJson `
    -RootFolder $AdfRootFolder `
    -ResourceGroupName $ResourceGroupName `
    -DataFactoryName $DataFactoryName `
    -Location "East US" `
    -Stage "dev" `
    -DeleteNotInSource $false `
    -DryRun:$false

Write-Host "✅ ADF deployment completed successfully!"
