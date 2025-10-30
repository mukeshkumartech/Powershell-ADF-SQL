using namespace System.Data.SqlClient

class DatabaseOperations {
    [SqlConnection]$Connection

    DatabaseOperations([SqlConnection]$connection) {
        $this.Connection = $connection
    }

    [System.Data.DataTable] GetData([string]$query) {
        try {
            $cmd = $this.Connection.CreateCommand()
            $cmd.CommandText = $query
            $adapter = [SqlDataAdapter]::new($cmd)
            $table = [System.Data.DataTable]::new()
            $adapter.Fill($table) | Out-Null
            return $table
        }
        catch {
            throw "Failed to fetch data: $_"
        }
    }

    [void] Execute([string]$query) {
        try {
            $cmd = $this.Connection.CreateCommand()
            $cmd.CommandText = $query
            $cmd.ExecuteNonQuery() | Out-Null
        }
        catch {
            throw "Failed to execute SQL query: $_"
        }
    }
}
