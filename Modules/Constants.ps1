# Constants.ps1 - All URLs and configuration constants
class AzureConstants {
    # Azure Authentication Endpoints
    static [string] $LoginBaseUrl = "https://login.microsoftonline.com"
    static [string] $TokenEndpointTemplate = "https://login.microsoftonline.com/{0}/oauth2/v2.0/token"
    static [string] $DatabaseScope = "https://database.windows.net/.default"
    
    # Grant Types
    static [string] $ClientCredentialsGrantType = "client_credentials"
    
    # Azure SQL Database Configuration
    static [string] $SqlServerPortTemplate = "tcp:{0},1433"
    static [string] $SqlConnectionStringTemplate = "Server=tcp:{0},1433;Database={1};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    
    # Key Vault Configuration
    static [string] $ServicePrincipalClientIdSuffix = "-client-id"
    static [string] $ServicePrincipalClientSecretSuffix = "-client-secret" 
    static [string] $ServicePrincipalTenantIdSuffix = "-tenant-id"
    
    # Default Configuration Values
    static [int] $DefaultConnectionTimeout = 30
    static [int] $DefaultCommandTimeout = 120
    static [int] $DefaultRunIntervalMinutes = 30
    static [int] $DefaultMaxIterations = 10
    static [int] $DefaultRetryDelaySeconds = 300
    
    # Logging Levels
    static [string] $LogLevelInfo = "INFO"
    static [string] $LogLevelWarn = "WARN"  
    static [string] $LogLevelError = "ERROR"
    
    # Methods to get formatted strings
    static [string] GetTokenEndpoint([string] $tenantId) {
        return [AzureConstants]::TokenEndpointTemplate -f $tenantId
    }
    
    static [string] GetConnectionString([string] $sqlServer, [string] $databaseName) {
        return [AzureConstants]::SqlConnectionStringTemplate -f $sqlServer, $databaseName
    }
    
    static [string] GetClientIdSecretName([string] $servicePrincipalName) {
        return "$servicePrincipalName" + [AzureConstants]::ServicePrincipalClientIdSuffix
    }
    
    static [string] GetClientSecretSecretName([string] $servicePrincipalName) {
        return "$servicePrincipalName" + [AzureConstants]::ServicePrincipalClientSecretSuffix
    }
    
    static [string] GetTenantIdSecretName([string] $servicePrincipalName) {
        return "$servicePrincipalName" + [AzureConstants]::ServicePrincipalTenantIdSuffix
    }
}
