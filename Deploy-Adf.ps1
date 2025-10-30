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

# ✅ Use existing Azure DevOps service connection context
$context = Get-AzContext
Write-Host "Using Azure context for subscription: $($context.Subscription.Id)"

Write-Host "Publishing ADF from JSON files..."
Publish-AdfV2FromJson `
    -RootFolder $AdfRootFolder `
    -ResourceGroupName $ResourceGroupName `
    -DataFactoryName $DataFactoryName `
    -AzContext $context `            # 👈 This line forces use of current authenticated context
    -Location "East US" `
    -Stage "dev" `
    -DeleteNotInSource $false `
    -DryRun:$false

Write-Host "✅ ADF deployment completed successfully!"
