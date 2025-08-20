# <copyright file="_Apply-PermissionChanges.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Applies permission changes (additions, updates, removals) to a Power BI shareable cloud connection.

.DESCRIPTION
This function orchestrates the application of permission changes to a Power BI shareable cloud connection based on a calculated delta.
It iterates through additions, updates, and removals, calling the appropriate functions to modify permissions.
It supports continuing on error for batch operations.

.PARAMETER CloudConnectionId
The ID of the Power BI shareable cloud connection.

.PARAMETER Delta
Hashtable containing the permission changes to apply, including 'ToAdd', 'ToUpdate', and 'ToRemove' arrays.

.PARAMETER AccessToken
Secure string containing the access token for the Power BI Fabric API.

.PARAMETER ContinueOnError
Switch to continue processing even if some operations fail.

.OUTPUTS
Returns a hashtable with success and failure counts, plus details of any failures for each operation type (Add, Update, Remove).

.EXAMPLE
$delta = _Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired -StrictMode
$result = _Apply-PermissionChanges `
    -CloudConnectionId "a60de636-56cf-4775-8217-76bb5b33bbb3" `
    -Delta $delta `
    -AccessToken $fabricToken.Token `
    -ContinueOnError
#>

function _Apply-PermissionChanges
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $CloudConnectionId,
        
        [Parameter(Mandatory=$true)]
        [hashtable] $Delta,
        
        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken,
        
        [Parameter()]
        [switch] $ContinueOnError
    )

    $changeResults = @{
        Success = $true
        AddResults = @{ SuccessCount = 0; FailureCount = 0; Failures = @() }
        UpdateResults = @{ SuccessCount = 0; FailureCount = 0; Failures = @() }
        RemoveResults = @{ SuccessCount = 0; FailureCount = 0; Failures = @() }
    }

    # Apply additions
    if ($Delta.ToAdd.Count -gt 0) {
        Write-Information "Adding $($Delta.ToAdd.Count) new permissions"
        foreach ($add in $Delta.ToAdd) {
            try {
                Assert-PBICloudConnectionPermissions `
                    -CloudConnectionId $CloudConnectionId `
                    -AssigneePrincipalId $add.principalId `
                    -AssigneePrincipalRole $add.role `
                    -AssigneePrincipalType $add.principalType `
                    -AccessToken $AccessToken | Out-Null
                
                $changeResults.AddResults.SuccessCount++
                Write-Verbose "Successfully added permission for principal $($add.principalId) with role $($add.role)"
            } catch {
                $changeResults.AddResults.FailureCount++
                $changeResults.AddResults.Failures += @{
                    PrincipalId = $add.principalId
                    Role = $add.role
                    Error = $_.Exception.Message
                }
                
                Write-Error "Failed to add permission for principal $($add.principalId): $($_.Exception.Message)" -ErrorAction Continue
                Write-Verbose $_.ScriptStackTrace -Verbose
                if (-not $ContinueOnError) {
                    throw "Stopping 'apply additions' due to error and ContinueOnError is false"
                }
            }
        }
    }

    # Apply updates
    if ($Delta.ToUpdate.Count -gt 0) {
        Write-Information "Updating $($Delta.ToUpdate.Count) existing permissions"
        foreach ($update in $Delta.ToUpdate) {
            try {
                Assert-PBICloudConnectionPermissions `
                    -CloudConnectionId $CloudConnectionId `
                    -AssigneePrincipalId $update.principalId `
                    -AssigneePrincipalRole $update.newRole `
                    -AssigneePrincipalType $update.principalType `
                    -AccessToken $AccessToken | Out-Null
                
                $changeResults.UpdateResults.SuccessCount++
                Write-Verbose "Successfully updated permission for principal $($update.principalId) from $($update.currentRole) to $($update.newRole)"
            } catch {
                $changeResults.UpdateResults.FailureCount++
                $changeResults.UpdateResults.Failures += @{
                    PrincipalId = $update.principalId
                    CurrentRole = $update.currentRole
                    NewRole = $update.newRole
                    Error = $_.Exception.Message
                }
                Write-Error "Failed to update permission for principal $($update.principalId): $($_.Exception.Message)" -ErrorAction Continue
                Write-Verbose $_.ScriptStackTrace -Verbose
                if (-not $ContinueOnError) {
                    throw "Stopping 'apply updates' due to error and ContinueOnError is false"
                }
            }
        }
    }

    # Apply removals
    if ($Delta.ToRemove.Count -gt 0) {
        Write-Information "Removing $($Delta.ToRemove.Count) unauthorized permissions"
        $removeResult = Remove-PBICloudConnectionPermissionBatch `
            -CloudConnectionId $CloudConnectionId `
            -RoleAssignments $Delta.ToRemove `
            -AccessToken $AccessToken `
            -ContinueOnError:$ContinueOnError
        
        $changeResults.RemoveResults = $removeResult
    }

    $totalFailures = $changeResults.AddResults.FailureCount + $changeResults.UpdateResults.FailureCount + $changeResults.RemoveResults.FailureCount
    $changeResults.Success = ($totalFailures -eq 0) -or $ContinueOnError

    return $changeResults
}