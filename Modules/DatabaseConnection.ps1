# DatabaseConnection.ps1 - Updated with constants and better error handling
using namespace System.Data.SqlClient
using namespace System.Management.Automation

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
            Write-Host "Retrieving Service Principal credentials from Key Vault: $keyVaultName" -ForegroundColor Yellow
            
            # Ensure Az.KeyVault module is available
            $this.EnsureAzKeyVaultModule()

            # Build secret names using constants
            $clientIdSecretName = [AzureConstants]::GetClientIdSecretName($servicePrincipalName)
            $clientSecretSecretName = [AzureConstants]::GetClientSecretSecretName($servicePrincipalName)
            $tenantIdSecretName = [AzureConstants]::GetTenantIdSecretName($servicePrincipalName)

            Write-Host "Fetching secrets from Key Vault..." -ForegroundColor Yellow
            Write-Host "  - Client ID secret: $clientIdSecretName"
            Write-Host "  - Client Secret secret: $clientSecretSecretName"  
            Write-Host "  - Tenant ID secret: $tenantIdSecretName"

            # Get secrets from Key Vault using current Azure context
            $clientId = $this.GetKeyVaultSecret($keyVaultName, $clientIdSecretName)
            $clientSecret = $this.GetKeyVaultSecret($keyVaultName, $clientSecretSecretName)
            $tenantId = $this.GetKeyVaultSecret($keyVaultName, $tenantIdSecretName)

            Write-Host "Successfully retrieved all Service Principal credentials from Key Vault." -ForegroundColor Green

            return @{
                ClientId = $clientId
                ClientSecret = $clientSecret
                TenantId = $tenantId
            }
        }
        catch {
            Write-Error "Failed to retrieve Service Principal credentials from Key Vault: $($_.Exception.Message)"
            throw "Key Vault access failed: $($_.Exception.Message)"
        }
    }

    hidden [void] EnsureAzKeyVaultModule() {
        try {
            if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
                Write-Host "Installing Az.KeyVault module..." -ForegroundColor Yellow
                Install-Module -Name Az.KeyVault -Force -AllowClobber -Scope CurrentUser
                Write-Host "Az.KeyVault module installed successfully." -ForegroundColor Green
            }
            
            if (-not (Get-Module -Name Az.KeyVault)) {
                Write-Host "Importing Az.KeyVault module..." -ForegroundColor Yellow
                Import-Module Az.KeyVault -Force
                Write-Host "Az.KeyVault module imported successfully." -ForegroundColor Green
            }
        }
        catch {
            throw "Failed to ensure Az.KeyVault module: $($_.Exception.Message)"
        }
    }

    hidden [string] GetKeyVaultSecret([string] $keyVaultName, [string] $secretName) {
        try {
            $secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -AsPlainText -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($secret)) {
                throw "Secret '$secretName' is empty or null"
            }
            Write-Host "  ✓ Retrieved secret: $secretName" -ForegroundColor Green
            return $secret
        }
        catch {
            Write-Error "Failed to retrieve secret '$secretName' from Key Vault '$keyVaultName'"
            throw "Secret retrieval failed for '$secretName': $($_.Exception.Message)"
        }
    }

    [SqlConnection] ConnectUsingServicePrincipalFromKeyVault([string] $keyVaultName, [string] $servicePrincipalName) {
        try {
            # Validate inputs
            if ([string]::IsNullOrWhiteSpace($keyVaultName)) {
                throw "Key Vault name cannot be null or empty"
            }
            if ([string]::IsNullOrWhiteSpace($servicePrincipalName)) {
                throw "Service Principal name cannot be null or empty"
            }

            # Get Service Principal credentials from Key Vault
            $spCredentials = $this.GetServicePrincipalFromKeyVault($keyVaultName, $servicePrincipalName)
            
            # Use the retrieved credentials to connect
            return $this.ConnectUsingServicePrincipal($spCredentials.ClientId, $spCredentials.ClientSecret, $spCredentials.TenantId)
        }
        catch {
            Write-Error "Key Vault Service Principal connection failed: $($_.Exception.Message)"
            throw "Connection failed: $($_.Exception.Message)"
        }
    }

    [SqlConnection] ConnectUsingServicePrincipal([string] $servicePrincipalId, [string] $servicePrincipalSecret, [string] $tenantId) {
        try {
            # Validate inputs
            if ([string]::IsNullOrWhiteSpace($servicePrincipalId)) {
                throw "Service Principal ID cannot be null or empty"
            }
            if ([string]::IsNullOrWhiteSpace($servicePrincipalSecret)) {
                throw "Service Principal secret cannot be null or empty"
            }
            if ([string]::IsNullOrWhiteSpace($tenantId)) {
                throw "Tenant ID cannot be null or empty"
            }

            Write-Host "Connecting using Service Principal..." -ForegroundColor Yellow
            
            # Get Azure AD access token using Service Principal and constants
            $tokenEndpoint = [AzureConstants]::GetTokenEndpoint($tenantId)
            $body = @{
                client_id     = $servicePrincipalId
                client_secret = $servicePrincipalSecret
                scope         = [AzureConstants]::DatabaseScope
                grant_type    = [AzureConstants]::ClientCredentialsGrantType
            }

            Write-Host "Requesting access token from: $tokenEndpoint" -ForegroundColor Yellow

            $tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method POST -Body $body -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
            
            if (-not $tokenResponse.access_token) {
                throw "Failed to obtain access token from Azure AD"
            }
            
            $this.AccessToken = $tokenResponse.access_token
            Write-Host "Successfully obtained access token using Service Principal." -ForegroundColor Green

            # Create connection string using constants
            $connString = [AzureConstants]::GetConnectionString($this.SqlServer, $this.DatabaseName)
            Write-Host "Connection string template: $connString" -ForegroundColor Yellow

            $this.Connection = [SqlConnection]::new($connString)
            $this.Connection.AccessToken = $this.AccessToken
            
            Write-Host "Opening SQL Database connection..." -ForegroundColor Yellow
            $this.Connection.Open()
            
            Write-Host "Successfully connected to SQL Database using Service Principal." -ForegroundColor Green
            return $this.Connection
        }
        catch {
            Write-Error "Service Principal connection failed: $($_.Exception.Message)"
            
            # Clean up connection if it was created
            if ($this.Connection) {
                try { $this.Connection.Dispose() } catch { }
                $this.Connection = $null
            }
            
            throw "Service Principal authentication failed: $($_.Exception.Message)"
        }
    }

    [void] TestConnection() {
        try {
            if (-not $this.Connection -or $this.Connection.State -ne [System.Data.ConnectionState]::Open) {
                throw "Connection is not open"
            }
            
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
            Write-Error "Database connection test failed: $($_.Exception.Message)"
            throw "Connection test failed: $($_.Exception.Message)"
        }
        finally {
            if ($cmd) { $cmd.Dispose() }
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
                Write-Warning "Error closing database connection: $($_.Exception.Message)"
            }
        }
    }
}
