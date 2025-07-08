# <copyright file="Remove-PBICloudConnectionPermission.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Removes a specific permission from a Power BI shareable cloud connection.

.DESCRIPTION
This function removes a role assignment from a Power BI shareable cloud connection using the
Fabric API. It's designed to work with the permission synchronization system to remove
unauthorized or outdated permissions.

.PARAMETER CloudConnectionId
The ID of the Power BI shareable cloud connection.

.PARAMETER RoleAssignmentId
The ID of the role assignment to remove. This is obtained from the existing permissions list.

.PARAMETER AccessToken
Secure string containing the access token for the Power BI Fabric API.

.OUTPUTS
Returns the response from the Power BI API call, or $null if the operation was successful.

.EXAMPLE
Remove-PBICloudConnectionPermission `
    -CloudConnectionId "a60de636-56cf-4775-8217-76bb5b33bbb3" `
    -RoleAssignmentId "assignment-id-here" `
    -AccessToken $token.Token
#>

function Remove-PBICloudConnectionPermission
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string] $CloudConnectionId,
        
        [Parameter(Mandatory=$true)]
        [string] $RoleAssignmentId,
        
        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken
    )

    Write-Verbose "Removing role assignment $RoleAssignmentId from cloud connection $CloudConnectionId"

    if ($PSCmdlet.ShouldProcess("Role Assignment $RoleAssignmentId", "Remove from Cloud Connection $CloudConnectionId")) {
        try {
            $splat = @{ 
                "Uri" = "https://api.fabric.microsoft.com/v1/connections/$CloudConnectionId/roleAssignments/$RoleAssignmentId"
                "Method" = "DELETE"
                "Headers" = @{
                    Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"
                    'Content-type' = 'application/json'
                }
            }

            $response = Invoke-RestMethod @splat
            Write-Information "Successfully removed role assignment $RoleAssignmentId from cloud connection $CloudConnectionId"
            return $response

        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.Exception.Message
            
            # Handle specific error cases
            if ($statusCode -eq 404) {
                Write-Warning "Role assignment $RoleAssignmentId not found on cloud connection $CloudConnectionId (may already be removed)"
                return $null
            } elseif ($statusCode -eq 403) {
                Write-Error "Insufficient permissions to remove role assignment $RoleAssignmentId from cloud connection $CloudConnectionId"
                throw
            } else {
                Write-Error "Failed to remove role assignment $RoleAssignmentId from cloud connection $CloudConnectionId`: $errorMessage"
                throw
            }
        }
    } else {
        Write-Information "Would remove role assignment $RoleAssignmentId from cloud connection $CloudConnectionId (WhatIf mode)"
        return $null
    }
}

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
        [switch] $ContinueOnError = $true
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

            $result = Remove-PBICloudConnectionPermission `
                -CloudConnectionId $CloudConnectionId `
                -RoleAssignmentId $assignment.id `
                -AccessToken $AccessToken

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
            
            Write-Error "Failed to remove role assignment $($assignment.id): $($_.Exception.Message)"
            
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