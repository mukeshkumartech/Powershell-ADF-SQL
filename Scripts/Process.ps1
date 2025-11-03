#Requires -Version 7.0
# Process.ps1 - Enhanced with PowerShell 7+ features
using namespace System.Collections.Generic

. "$PSScriptRoot/../Modules/DatabaseOperations.ps1"

class DataProcessor {
    [DatabaseOperations] $DbOps
    [string] $TableName

    DataProcessor([DatabaseOperations] $dbOps, [string] $tableName) {
        $this.DbOps = $dbOps ?? $(throw "DatabaseOperations cannot be null")
        $this.TableName = $tableName ?? $(throw "TableName cannot be null or empty")
    }

    [int] RunProcess() {
        Write-Host "Reading top 5 records from table $($this.TableName)..." -ForegroundColor Yellow
        
        $querySelect = "SELECT TOP 5 * FROM $($this.TableName);"
        $data = $this.DbOps.GetData($querySelect)

        if ($data.Rows.Count -eq 0) {
            Write-Host "No data found in $($this.TableName)." -ForegroundColor Yellow
            return 0
        }

        $processedCount = 0
        $updates = [List[hashtable]]::new()

        # Prepare all updates first (PowerShell 7+ enhanced foreach)
        foreach ($row in $data.Rows) {
            $id = $row["ID"]
            $city = $row["City"]

            # Extract base city name using enhanced regex with null-conditional operator
            $baseCity = if ($city -match "^(.*?)\s*-\s*") { 
                $matches[1].Trim() 
            } else { 
                $city 
            }

            # Append current datetime
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $newCity = "$baseCity - $timestamp"

            $updates.Add(@{
                Id = $id
                OldCity = $city
                NewCity = $newCity
                Query = "UPDATE $($this.TableName) SET City='$newCity' WHERE ID=$id"
            })
        }

        # Execute updates with enhanced logging
        foreach ($update in $updates) {
            Write-Host "Updating ID $($update.Id): '$($update.OldCity)' → '$($update.NewCity)'" -ForegroundColor Cyan
            
            try {
                $this.DbOps.Execute($update.Query)
                $processedCount++
            }
            catch {
                Write-Warning "Failed to update record ID $($update.Id): $($_.Exception.Message)"
            }
        }

        Write-Host "Data processing completed for $($this.TableName). Processed: $processedCount/$($data.Rows.Count) records." -ForegroundColor Green
        return $processedCount
    }
}
