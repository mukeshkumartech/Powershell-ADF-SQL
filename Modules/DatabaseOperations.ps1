# DatabaseOperations.ps1 - Function-based approach to avoid class caching issues
using namespace System.Data.SqlClient

function New-DatabaseOperations {
    param([SqlConnection]$Connection)
    
    return @{
        Connection = $Connection
        GetData = {
            param([string]$query)
            try {
                $cmd = $Connection.CreateCommand()
                $cmd.CommandText = $query
                $adapter = [SqlDataAdapter]::new($cmd)
                $table = [System.Data.DataTable]::new()
                $adapter.Fill($table) | Out-Null
                return $table
            }
            catch {
                throw "Failed to fetch data: $_"
            }
        }.GetNewClosure()
        Execute = {
            param([string]$query)
            try {
                $cmd = $Connection.CreateCommand()
                $cmd.CommandText = $query
                $cmd.ExecuteNonQuery() | Out-Null
            }
            catch {
                throw "Failed to execute SQL query: $_"
            }
        }.GetNewClosure()
        ExecuteParameterized = {
            param([string]$query, [hashtable]$parameters)
            try {
                $cmd = $Connection.CreateCommand()
                $cmd.CommandText = $query
                
                foreach ($param in $parameters.GetEnumerator()) {
                    [void]$cmd.Parameters.AddWithValue($param.Key, $param.Value)
                }
                
                $cmd.ExecuteNonQuery() | Out-Null
            }
            catch {
                throw "Failed to execute parameterized SQL query: $_"
            }
        }.GetNewClosure()
    }
}
