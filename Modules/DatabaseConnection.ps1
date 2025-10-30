# Requires PowerShell 5.1+
using namespace System.Data.SqlClient
using namespace System.Management.Automation

class DatabaseConnection {
    [string]$SqlServer
    [string]$DatabaseName
    [string]$AccessToken
    [SqlConnection]$Connection

    DatabaseConnection([string]$sqlServer, [string]$databaseName) {
        $this.SqlServer = $sqlServer
        $this.DatabaseName = $databaseName
    }

    hidden [PSCredential] LoadLocalCredentials([string]$SecretsFile) {
        if (-not (Test-Path $SecretsFile)) {
            throw "Secrets file not found: $SecretsFile"
        }

        $secrets = Get-Content $SecretsFile | ConvertFrom-Json
        $username = $secrets.SqlUser
        $password = ConvertTo-SecureString $secrets.SqlPassword
        return [PSCredential]::new($username, $password)
    }

    [SqlConnection] ConnectUsingCredentials([PSCredential]$creds) {
        try {
            Write-Host "Connecting using local SQL credentials..."
            $connString = "Server=tcp:$($this.SqlServer),1433;Database=$($this.DatabaseName);User ID=$($creds.UserName);Password=$($creds.GetNetworkCredential().Password);Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
            $this.Connection = [SqlConnection]::new($connString)
            $this.Connection.Open()
            Write-Host "Connected using SQL credentials."
            return $this.Connection
        }
        catch {
            throw "SQL credential connection failed: $_"
        }
    }

    [SqlConnection] ConnectUsingManagedIdentity() {
        try {
            Write-Host "Connecting using Managed Identity..."
            $tokenResponse = Invoke-RestMethod -Method GET `
                -Headers @{Metadata="true"} `
                -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://database.windows.net/"
            $this.AccessToken = $tokenResponse.access_token

            $connString = "Server=tcp:$($this.SqlServer),1433;Database=$($this.DatabaseName);Authentication=Active Directory Access Token;"
            $this.Connection = [SqlConnection]::new($connString)
            $this.Connection.AccessToken = $this.AccessToken
            $this.Connection.Open()
            Write-Host "Connected using Managed Identity."
            return $this.Connection
        }
        catch {
            throw "Managed Identity connection failed: $_"
        }
    }

    [SqlConnection] Connect([bool]$UseManagedIdentity, [string]$SecretsFile) {
        if ($UseManagedIdentity) {
            return $this.ConnectUsingManagedIdentity()
        } else {
            $creds = $this.LoadLocalCredentials($SecretsFile)
            return $this.ConnectUsingCredentials($creds)
        }
    }
}
