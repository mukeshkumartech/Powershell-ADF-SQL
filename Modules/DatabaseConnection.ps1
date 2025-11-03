#Requires -Version 7.0
# DatabaseConnection.ps1 - PowerShell 7+ with modern features
using namespace System.Data.SqlClient
using namespace System.Management.Automation
using namespace System.Collections.Generic

. "$PSScriptRoot/Constants.ps1"

class DatabaseConnection {
    [string] $SqlServer
    [string] $DatabaseName
    [string] $AccessToken
    [SqlConnection] $Connection

    DatabaseConnection([string] $sqlServer, [string] $databaseName) {
        if ([string]::IsNullOrWhiteSpace($sqlServer)) {
            throw "SQL Server cannot be null or empty"
        }
        if ([string]::IsNullOrWhiteSpace($databaseName)) {
            throw "Database name cannot be null or empty"
        }
        
        $this.SqlServer = $sqlServer
        $this.DatabaseName = $databaseName
    }

    hidden [hashtable] GetServicePrincipalFromKeyVault([string] $keyVaultName, [string] $servicePrincipalName) {
    try {
        Write-Host "DEBUG: Line 1 - Starting GetServicePrincipalFromKeyVault method" -ForegroundColor Magenta
        Write-Host "Retrieving Service Principal credentials from Key Vault: $keyVaultName" -ForegroundColor Yellow
        
        Write-Host "DEBUG: Line 2 - About to call EnsureAzKeyVaultModule" -ForegroundColor Magenta
        # Ensure Az.KeyVault module is available
        $this.EnsureAzKeyVaultModule()
        Write-Host "DEBUG: Line 3 - EnsureAzKeyVaultModule completed" -ForegroundColor Magenta

        Write-Host "DEBUG: Line 4 - Building secret names" -ForegroundColor Magenta
        # Build secret names using constants
        $clientIdSecretName = [AzureConstants]::GetClientIdSecretName($servicePrincipalName)
        Write-Host "DEBUG: Line 5 - clientIdSecretName = $clientIdSecretName" -ForegroundColor Magenta
        
        $clientSecretSecretName = [AzureConstants]::GetClientSecretSecretName($servicePrincipalName)
        Write-Host "DEBUG: Line 6 - clientSecretSecretName = $clientSecretSecretName" -ForegroundColor Magenta
        
        $tenantIdSecretName = [AzureConstants]::GetTenantIdSecretName($servicePrincipalName)
        Write-Host "DEBUG: Line 7 - tenantIdSecretName = $tenantIdSecretName" -ForegroundColor Magenta

        Write-Host "Fetching secrets from Key Vault..." -ForegroundColor Yellow
        
        Write-Host "DEBUG: Line 8 - About to retrieve ClientId secret" -ForegroundColor Magenta
        $clientIdValue = $this.GetKeyVaultSecret($keyVaultName, $clientIdSecretName)
        Write-Host "DEBUG: Line 9 - ClientId retrieved successfully" -ForegroundColor Magenta
        
        Write-Host "DEBUG: Line 10 - About to retrieve ClientSecret secret" -ForegroundColor Magenta
        $clientSecretValue = $this.GetKeyVaultSecret($keyVaultName, $clientSecretSecretName)
        Write-Host "DEBUG: Line 11 - ClientSecret retrieved successfully" -ForegroundColor Magenta
        
        Write-Host "DEBUG: Line 12 - About to retrieve TenantId secret" -ForegroundColor Magenta
        $tenantIdValue = $this.GetKeyVaultSecret($keyVaultName, $tenantIdSecretName)
        Write-Host "DEBUG: Line 13 - TenantId retrieved successfully" -ForegroundColor Magenta
        
        Write-Host "DEBUG: Line 14 - Building secrets hashtable" -ForegroundColor Magenta
        $secrets = @{
            ClientId = $clientIdValue
            ClientSecret = $clientSecretValue
            TenantId = $tenantIdValue
        }
        Write-Host "DEBUG: Line 15 - Secrets hashtable created successfully" -ForegroundColor Magenta

        Write-Host "Successfully retrieved all Service Principal credentials from Key Vault." -ForegroundColor Green
        Write-Host "DEBUG: Line 16 - About to return secrets" -ForegroundColor Magenta

        return $secrets
        }
        catch {
            Write-Host "DEBUG: CATCH BLOCK - Error occurred" -ForegroundColor Red
            $exceptionMessage = $_.Exception.Message
            Write-Host "DEBUG: Exception message extracted: $exceptionMessage" -ForegroundColor Red
            Write-Error "Failed to retrieve Service Principal credentials from Key Vault: $exceptionMessage"
            throw "Key Vault access failed: $exceptionMessage"
        }
    }

    hidden [void] EnsureAzKeyVaultModule() {
        $requiredModules = @('Az.Accounts', 'Az.KeyVault')
        
        foreach ($moduleName in $requiredModules) {
            if (-not (Get-Module -ListAvailable -Name $moduleName)) {
                Write-Host "Installing $moduleName module..." -ForegroundColor Yellow
                Install-Module -Name $moduleName -Force -AllowClobber -Scope CurrentUser
                Write-Host "$moduleName module installed successfully." -ForegroundColor Green
            }
            
            if (-not (Get-Module -Name $moduleName)) {
                Write-Host "Importing $moduleName module..." -ForegroundColor Yellow
                Import-Module $moduleName -Force
                Write-Host "$moduleName module imported successfully." -ForegroundColor Green
            }
        }
    }

    hidden [string] GetKeyVaultSecret([string] $keyVaultName, [string] $secretName) {
        try {
            $retrievedSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -AsPlainText
            
            if ([string]::IsNullOrWhiteSpace($retrievedSecret)) {
                throw "Secret '$secretName' is empty or null"
            }
            
            Write-Host "  ✓ Retrieved secret: $secretName" -ForegroundColor Green
            return $retrievedSecret
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to retrieve secret '$secretName' from Key Vault '$keyVaultName'"
            throw "Secret retrieval failed for '$secretName': $exceptionMessage"
        }
    }

    [SqlConnection] ConnectUsingServicePrincipalFromKeyVault([string] $keyVaultName, [string] $servicePrincipalName) {
        # Input validation using PowerShell 7+ null-conditional assignment
        if ([string]::IsNullOrWhiteSpace($keyVaultName)) { throw "Key Vault name cannot be null or empty" }
        if ([string]::IsNullOrWhiteSpace($servicePrincipalName)) { throw "Service Principal name cannot be null or empty" }

        try {
            # Get Service Principal credentials from Key Vault
            $spCredentials = $this.GetServicePrincipalFromKeyVault($keyVaultName, $servicePrincipalName)
            
            # Use the retrieved credentials to connect
            return $this.ConnectUsingServicePrincipal(
                $spCredentials.ClientId, 
                $spCredentials.ClientSecret, 
                $spCredentials.TenantId
            )
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Key Vault Service Principal connection failed: $exceptionMessage"
            throw "Connection failed: $exceptionMessage"
        }
    }

    [SqlConnection] ConnectUsingServicePrincipal([string] $servicePrincipalId, [string] $servicePrincipalSecret, [string] $tenantId) {
        # Input validation using PowerShell 7+ features
        if ([string]::IsNullOrWhiteSpace($servicePrincipalId)) { throw "Service Principal ID cannot be null or empty" }
        if ([string]::IsNullOrWhiteSpace($servicePrincipalSecret)) { throw "Service Principal secret cannot be null or empty" }
        if ([string]::IsNullOrWhiteSpace($tenantId)) { throw "Tenant ID cannot be null or empty" }

        try {
            Write-Host "Connecting using Service Principal..." -ForegroundColor Yellow
            
            # Get Azure AD access token using Service Principal and constants
            $tokenEndpoint = [AzureConstants]::GetTokenEndpoint($tenantId)
            $requestBody = @{
                client_id     = $servicePrincipalId
                client_secret = $servicePrincipalSecret
                scope         = [AzureConstants]::DatabaseScope
                grant_type    = [AzureConstants]::ClientCredentialsGrantType
            }

            Write-Host "Requesting access token from: $tokenEndpoint" -ForegroundColor Yellow

            # Use PowerShell 7+ enhanced Invoke-RestMethod features
            $tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method POST -Body $requestBody -ContentType "application/x-www-form-urlencoded"
            
            if ([string]::IsNullOrWhiteSpace($tokenResponse.access_token)) { 
                throw "Failed to obtain access token from Azure AD" 
            }
            $this.AccessToken = $tokenResponse.access_token
            Write-Host "Successfully obtained access token using Service Principal." -ForegroundColor Green

            # Create connection string using constants
            $connString = [AzureConstants]::GetConnectionString($this.SqlServer, $this.DatabaseName)
            Write-Host "Establishing SQL Database connection..." -ForegroundColor Yellow

            $this.Connection = [SqlConnection]::new($connString)
            $this.Connection.AccessToken = $this.AccessToken
            
            $this.Connection.Open()
            
            Write-Host "Successfully connected to SQL Database using Service Principal." -ForegroundColor Green
            return $this.Connection
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Service Principal connection failed: $exceptionMessage"
            
            # Clean up connection if it was created
            if ($this.Connection) {
                $this.Connection.Dispose()
            }
            $this.Connection = $null
            
            throw "Service Principal authentication failed: $exceptionMessage"
        }
    }

    [void] TestConnection() {
        if (-not $this.Connection -or $this.Connection.State -ne [System.Data.ConnectionState]::Open) {
            throw "Connection is not open"
        }
        
        try {
            $cmd = $this.Connection.CreateCommand()
            $cmd.CommandText = "SELECT 1 as TestResult"
            $cmd.CommandTimeout = [AzureConstants]::DefaultCommandTimeout
            
            $result = $cmd.ExecuteScalar()
            if ($result -eq 1) {
                Write-Host "✓ Database connection test successful" -ForegroundColor Green
            } else {
                throw "Connection test returned unexpected result: $result"
            }
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Database connection test failed: $exceptionMessage"
            throw "Connection test failed: $exceptionMessage"
        }
        finally {
            if ($cmd) {
                $cmd.Dispose()
            }
        }
    }

    [void] Close() {
        if ($this.Connection) {
            try {
                if ($this.Connection.State -eq [System.Data.ConnectionState]::Open) {
                    $this.Connection.Close()
                    Write-Host "Database connection closed successfully." -ForegroundColor Green
                }
                $this.Connection.Dispose()
                $this.Connection = $null
            }
            catch {
                $exceptionMessage = $_.Exception.Message
                Write-Warning "Error closing database connection: $exceptionMessage"
            }
        }
    }
}
