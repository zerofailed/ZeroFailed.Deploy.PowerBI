# <copyright file="Remove-PBICloudConnectionPermissionBatch.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Removes multiple permissions from a Power BI shareable cloud connection in batch.

.DESCRIPTION
This function removes multiple role assignments from a Power BI shareable cloud connection.
It processes removals sequentially with error handling and optional retry logic.

.PARAMETER CloudConnectionId
The ID of the Power BI shareable cloud connection.

.PARAMETER RoleAssignments
Array of role assignment objects to remove. Each object should contain at least an 'id' property.

.PARAMETER AccessToken
Secure string containing the access token for the Power BI Fabric API.

.PARAMETER ContinueOnError
Switch to continue processing remaining removals even if some fail.

.OUTPUTS
Returns a hashtable with success and failure counts, plus details of any failures.

.EXAMPLE
$assignmentsToRemove = @(
    @{ id = "assignment1"; principalId = "user1" },
    @{ id = "assignment2"; principalId = "user2" }
)

$result = Remove-PBICloudConnectionPermissionBatch `
    -CloudConnectionId "connection-id" `
    -RoleAssignments $assignmentsToRemove `
    -AccessToken $token.Token `
    -ContinueOnError
#>
function Remove-PBICloudConnectionPermissionBatch
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
            if (-not $assignment.id) {
                Write-Warning "Role assignment missing ID property, skipping: $($assignment | ConvertTo-Json -Compress)"
                $failureCount++
                continue
            }

            $principalInfo = if ($assignment.principalId) { " (Principal: $($assignment.principalId))" } else { "" }
            Write-Verbose "Removing role assignment $($assignment.id)$principalInfo"

            if ($PSCmdlet.ShouldProcess("role assignment $($assignment.id)$principalInfo")) {
                $result = Remove-PBICloudConnectionPermission `
                    -CloudConnectionId $CloudConnectionId `
                    -RoleAssignmentId $assignment.id `
                    -AccessToken $AccessToken
            }

            $successCount++
            Write-Verbose "Successfully removed role assignment $($assignment.id)"

        } catch {
            $failureCount++
            $failure = @{
                RoleAssignmentId = $assignment.id
                PrincipalId = $assignment.principalId
                Error = $_.Exception.Message
            }
            $failures += $failure
            
            Write-Error "Failed to remove role assignment $($assignment.id): $($_.Exception.Message)" -ErrorAction Continue
            
            if (-not $ContinueOnError) {
                throw "Stopping batch removal due to error and ContinueOnError is false"
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