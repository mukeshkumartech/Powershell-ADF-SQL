#Requires -Version 7.0
# Process.ps1 - Enhanced with PowerShell 7+ features
using namespace System.Collections.Generic

. "$PSScriptRoot/../Modules/DatabaseOperations.ps1"

class DataProcessor {
    $DbOps
    [string] $TableName

    DataProcessor($dbOps, [string] $tableName) {
        if ($null -eq $dbOps) { throw "Database Operations cannot be null" }
        if ([string]::IsNullOrWhiteSpace($tableName)) { throw "TableName cannot be null or empty" }
        $this.DbOps = $dbOps
        $this.TableName = $tableName
    }

    [int] RunProcess() {
        Write-Host "Reading top 5 records from table $($this.TableName)..." -ForegroundColor Yellow
        
        $querySelect = "SELECT TOP 5 EmployeeID, UserName, Department FROM [$($this.TableName)]"
        Write-Host "Executing query: $querySelect" -ForegroundColor Cyan
        $data = & $this.DbOps.GetData $querySelect
        Write-Host "Data type: $($data.GetType().FullName)" -ForegroundColor Cyan
        if ($data -ne $null) {
            Write-Host "Data has Rows property: $($data.PSObject.Properties.Name -contains 'Rows')" -ForegroundColor Cyan
            if ($data.PSObject.Properties.Name -contains 'Rows') {
                Write-Host "Rows count: $($data.Rows.Count)" -ForegroundColor Cyan
            } else {
                Write-Host "Data count: $($data.Count)" -ForegroundColor Cyan
            }
        }

        if ($data -eq $null -or $data.Count -eq 0) {
            Write-Host "No data found in $($this.TableName)." -ForegroundColor Yellow
            return 0
        }

        $processedCount = 0
        $updates = [List[hashtable]]::new()

        # Prepare all updates first (PowerShell 7+ enhanced foreach)
        foreach ($row in $data) {
            $employeeId = $row["EmployeeID"]
            $userName = $row["UserName"]
            $department = $row["Department"]

            # Skip records with null or empty EmployeeID
            if ([string]::IsNullOrWhiteSpace($employeeId)) {
                Write-Warning "Skipping record with empty EmployeeID"
                continue
            }

            # Extract base department name using enhanced regex
            $baseDepartment = if ($department -match "^(.*?)\s*-\s*") {
                $matches[1].Trim()
            } else {
                $department
            }

            # Append current datetime
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $newDepartment = "$baseDepartment - $timestamp"

            $updates.Add(@{
                EmployeeId = $employeeId
                UserName = $userName
                OldDepartment = $department
                NewDepartment = $newDepartment
                Query = "UPDATE [$($this.TableName)] SET [Department] = @NewDepartment, [ModifiedDate] = GETDATE() WHERE [EmployeeID] = @EmployeeId"
                Parameters = @{
                    "@EmployeeId" = $employeeId
                    "@NewDepartment" = $newDepartment
                }
            })
        }

        # Execute updates with enhanced logging
        foreach ($update in $updates) {
            Write-Host "Updating Employee $($update.EmployeeId) ($($update.UserName)): '$($update.OldDepartment)' → '$($update.NewDepartment)'" -ForegroundColor Cyan
            
            try {
                & $this.DbOps.ExecuteParameterized $update.Query $update.Parameters
                $processedCount++
                Write-Host "  ✅ Successfully updated Employee $($update.EmployeeId)" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to update Employee $($update.EmployeeId): $($_.Exception.Message)"
            }
        }

        Write-Host "Data processing completed for $($this.TableName). Processed: $processedCount/$($data.Count) records." -ForegroundColor Green
        return $processedCount
    }
}
