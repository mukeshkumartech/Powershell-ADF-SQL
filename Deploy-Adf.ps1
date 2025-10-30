param(
    [string]$ResourceGroupName,
    [string]$DataFactoryName,
    [string]$AdfRootFolder = "$(System.DefaultWorkingDirectory)"
)

Write-Host "Installing required module..."
Install-Module azure.datafactory.tools -Scope CurrentUser -Force -AllowClobber

Write-Host "Connecting to Azure..."
Connect-AzAccount -Identity

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
