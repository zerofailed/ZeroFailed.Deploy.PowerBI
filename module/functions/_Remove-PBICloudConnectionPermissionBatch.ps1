function _Remove-PBICloudConnectionPermissionBatch
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string] $CloudConnectionId,
        
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [object[]] $RoleAssignments,
        
        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken,
        
        [Parameter()]
        [switch] $ContinueOnError
    )

    Write-Information "Removing $($RoleAssignments.Count) role assignments from cloud connection $CloudConnectionId"

    $successCount = 0
    $failureCount = 0
    $failures = @()

    foreach ($assignment in $RoleAssignments) {
        try {
            if (-not $assignment.currentId) {
                Write-Warning "Role assignment missing ID property, skipping: $($assignment | ConvertTo-Json -Compress)"
                $failureCount++
                continue
            }

            $principalInfo = if ($assignment.principalId) { " (Principal: $($assignment.principalId))" } else { "" }
            Write-Verbose "Removing role assignment $($assignment.currentId)$principalInfo"

            $result = Remove-PBICloudConnectionPermission `
                -CloudConnectionId $CloudConnectionId `
                -RoleAssignmentId $assignment.currentId `
                -AccessToken $AccessToken

            $successCount++
            Write-Verbose "Successfully removed role assignment $($assignment.currentId)"

        } catch {
            $failureCount++
            $failure = @{
                RoleAssignmentId = $assignment.currentId
                PrincipalId = $assignment.principalId
                Error = $_.Exception.Message
            }
            $failures += $failure
            
            Write-Error "Failed to remove role assignment $($assignment.currentId): $($_.Exception.Message)"
            
            if (-not $ContinueOnError) {
                Write-Error "Stopping batch removal due to error and ContinueOnError is false"
                break
            }
        }
    }

    $result = @{
        TotalRequested = $RoleAssignments.Count
        SuccessCount = $successCount
        FailureCount = $failureCount
        Failures = $failures
        IsCompleteSuccess = ($failureCount -eq 0)
    }

    Write-Information "Batch removal completed: $successCount successful, $failureCount failed"
    
    if ($failures.Count -gt 0) {
        Write-Warning "Failed to remove $($failures.Count) role assignments:"
        foreach ($failure in $failures) {
            Write-Warning "  - Assignment $($failure.RoleAssignmentId): $($failure.Error)"
        }
    }

    return $result
}