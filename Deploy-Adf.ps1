# Azure Data Factory Deployment Script - FIXED ENCODING
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$DataFactoryName,
    
    [Parameter(Mandatory=$false)]
    [string]$AdfRootFolder = "$(Build.ArtifactStagingDirectory)/_Powershell-ADF-SQL"
)

Write-Host "ADF Deployment Starting..."
Write-Host "Root Folder: $AdfRootFolder"
Write-Host "Resource Group: $ResourceGroupName"
Write-Host "Data Factory: $DataFactoryName"

# Install module
Write-Host "Installing module..."
Install-Module -Name azure.datafactory.tools -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck
Import-Module azure.datafactory.tools -Force
Write-Host "Module installed: $((Get-Module azure.datafactory.tools).Version)"

# Verify connection
$context = Get-AzContext
Write-Host "Connected to: $($context.Subscription.Id)"

# Deploy - SIMPLE VERSION WITHOUT ANY OPTIONS
Write-Host "Deploying ADF..."
Publish-AdfV2FromJson -RootFolder $AdfRootFolder -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName

Write-Host "SUCCESS: DEPLOYMENT COMPLETED!"
