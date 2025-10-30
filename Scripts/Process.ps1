# Import required modules
. "$PSScriptRoot/../Modules/DatabaseOperations.ps1"

class DataProcessor {
    [DatabaseOperations]$DbOps
    [string]$TableName

    DataProcessor([DatabaseOperations]$dbOps, [string]$tableName) {
        $this.DbOps = $dbOps
        $this.TableName = $tableName
    }

    [void] RunProcess() {
        Write-Host "Reading top 5 records from table $($this.TableName)..."
        $querySelect = "SELECT TOP 5 * FROM $($this.TableName);"
        $data = $this.DbOps.GetData($querySelect)

        if ($data.Rows.Count -eq 0) {
            Write-Host "No data found in $($this.TableName)."
            return
        }

        foreach ($row in $data.Rows) {
            $id = $row["ID"]
            $city = $row["City"]

            # Extract base city name (remove any previous timestamp after ' - ')
            if ($city -match "^(.*?)\s*-\s*") {
                $baseCity = $matches[1].Trim()
            } else {
                $baseCity = $city
            }

            # Append current datetime
            $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            $newCity = "$baseCity - $timestamp"

            Write-Host "Updating ID $row.ID: '$city' → '$newCity'"

            $queryUpdate = "UPDATE $($this.TableName) SET City='$newCity' WHERE ID=$id"
            $this.DbOps.Execute($queryUpdate)
        }

        Write-Host "Data processing completed for $($this.TableName)."
    }
}
