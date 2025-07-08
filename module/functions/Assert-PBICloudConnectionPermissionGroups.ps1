# <copyright file="Assert-PBICloudConnectionPermissionGroups.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that the specified Power BI cloud connection has the exact set of permissions defined in the configuration.

.DESCRIPTION
This function provides comprehensive permission group management for Power BI shareable cloud connections.
It performs strict synchronization, ensuring that only the permissions specified in the configuration exist
on the cloud connection. It supports both email addresses and explicit principal IDs, with automatic resolution
of email addresses to principal IDs using Microsoft Graph API.

The function will:
1. Resolve all identities in the permission groups (email addresses to principal IDs)
2. Get current permissions from the cloud connection
3. Calculate the delta (additions, updates, removals needed)
4. Apply all necessary changes to achieve the desired state

.PARAMETER CloudConnectionId
The ID of the Power BI shareable cloud connection.

.PARAMETER PermissionGroups
Hashtable containing permission groups with keys like "owners", "users", "reshareUsers".
Each group contains an array of identities (email addresses or structured objects with principalId/principalType).

.PARAMETER AccessToken
Secure string containing the access token for the Power BI Fabric API.

.PARAMETER GraphAccessToken
Secure string containing the access token for Microsoft Graph API (for resolving email addresses).

.PARAMETER StrictMode
Switch to enable strict synchronization. When enabled (default), any permissions not specified
in the configuration will be removed.

.PARAMETER DryRun
Switch to perform a dry run without making any actual changes. Useful for testing and validation.

.PARAMETER ContinueOnError
Switch to continue processing even if some operations fail.

.OUTPUTS
Returns a detailed result object containing:
- Summary of operations performed
- Any errors encountered
- Before and after permission states

.EXAMPLE
$permissionGroups = @{
    owners = @("admin@company.com")
    users = @(
        "user1@company.com",
        @{ principalId = "f3498fd9-cff0-44a9-991c-c017f481adf0"; principalType = "ServicePrincipal" }
    )
    reshareUsers = @("poweruser@company.com")
}

$result = Assert-PBICloudConnectionPermissionGroups `
    -CloudConnectionId "a60de636-56cf-4775-8217-76bb5b33bbb3" `
    -PermissionGroups $permissionGroups `
    -AccessToken $fabricToken.Token `
    -GraphAccessToken $graphToken.Token `
    -StrictMode
#>

function Assert-PBICloudConnectionPermissionGroups
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string] $CloudConnectionId,
        
        [Parameter(Mandatory=$true)]
        [hashtable] $PermissionGroups,
        
        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken,
        
        [Parameter(Mandatory=$true)]
        [securestring] $GraphAccessToken,
        
        [Parameter()]
        [switch] $StrictMode = $true,
        
        [Parameter()]
        [switch] $DryRun = $false,
        
        [Parameter()]
        [switch] $ContinueOnError = $true
    )

    Write-Information "Starting permission group synchronization for cloud connection: $CloudConnectionId"
    Write-Information "Strict mode: $StrictMode, Dry run: $DryRun"

    $result = @{
        CloudConnectionId = $CloudConnectionId
        Success = $false
        Operations = @{
            IdentityResolution = @{ Success = $false; Details = @() }
            PermissionRetrieval = @{ Success = $false; Details = @() }
            DeltaCalculation = @{ Success = $false; Details = @() }
            PermissionChanges = @{ Success = $false; Details = @() }
        }
        Summary = @{
            TotalIdentitiesResolved = 0
            PermissionsAdded = 0
            PermissionsUpdated = 0
            PermissionsRemoved = 0
            TotalChanges = 0
        }
        Errors = @()
        BeforeState = @()
        AfterState = @()
    }

    try {
        # Step 1: Collect all identities from permission groups
        Write-Information "Step 1: Collecting identities from permission groups"
        $allIdentities = @()
        
        foreach ($groupName in $PermissionGroups.Keys) {
            $groupMembers = $PermissionGroups[$groupName]
            if ($groupMembers -and $groupMembers.Count -gt 0) {
                $allIdentities += $groupMembers
                Write-Verbose "Found $($groupMembers.Count) identities in group '$groupName'"
            }
        }

        Write-Information "Found $($allIdentities.Count) total identities across all permission groups"

        # Step 2: Resolve all identities to principal IDs and types
        Write-Information "Step 2: Resolving identities to principal IDs"
        
        try {
            $resolvedIdentities = Resolve-PrincipalIdentities -Identities $allIdentities -GraphAccessToken $GraphAccessToken -UseCache
            $result.Operations.IdentityResolution.Success = $true
            $result.Operations.IdentityResolution.Details = $resolvedIdentities
            $result.Summary.TotalIdentitiesResolved = $resolvedIdentities.Count
            
            Write-Information "Successfully resolved $($resolvedIdentities.Count) identities"
        } catch {
            $errorMessage = "Failed to resolve identities: $($_.Exception.Message)"
            $result.Errors += $errorMessage
            Write-Error $errorMessage
            throw
        }

        # Step 3: Convert permission groups to flat permission list
        Write-Information "Step 3: Converting permission groups to individual permissions"
        
        try {
            $desiredPermissions = ConvertFrom-PermissionGroups -PermissionGroups $PermissionGroups -ResolvedIdentities $resolvedIdentities
            Write-Information "Converted to $($desiredPermissions.Count) individual permission assignments"
        } catch {
            $errorMessage = "Failed to convert permission groups: $($_.Exception.Message)"
            $result.Errors += $errorMessage
            Write-Error $errorMessage
            throw
        }

        # Step 4: Get current permissions from the cloud connection
        Write-Information "Step 4: Retrieving current permissions from cloud connection"
        
        try {
            $currentPermissions = Get-PBICloudConnectionPermissions -CloudConnectionId $CloudConnectionId -AccessToken $AccessToken
            $result.Operations.PermissionRetrieval.Success = $true
            $result.Operations.PermissionRetrieval.Details = $currentPermissions
            $result.BeforeState = $currentPermissions
            
            Write-Information "Retrieved $($currentPermissions.Count) current permissions"
        } catch {
            $errorMessage = "Failed to retrieve current permissions: $($_.Exception.Message)"
            $result.Errors += $errorMessage
            Write-Error $errorMessage
            throw
        }

        # Step 5: Calculate permission delta
        Write-Information "Step 5: Calculating permission changes needed"
        
        try {
            $delta = Get-PermissionDelta -CurrentPermissions $currentPermissions -DesiredPermissions $desiredPermissions -StrictMode:$StrictMode
            $result.Operations.DeltaCalculation.Success = $true
            $result.Operations.DeltaCalculation.Details = $delta
            
            Write-Information "Delta calculation complete:"
            Write-Information "  - Additions: $($delta.ToAdd.Count)"
            Write-Information "  - Updates: $($delta.ToUpdate.Count)"
            Write-Information "  - Removals: $($delta.ToRemove.Count)"
        } catch {
            $errorMessage = "Failed to calculate permission delta: $($_.Exception.Message)"
            $result.Errors += $errorMessage
            Write-Error $errorMessage
            throw
        }

        # Step 6: Apply permission changes
        if ($delta.Summary.TotalChanges -eq 0) {
            Write-Information "No permission changes needed - configuration is already synchronized"
            $result.Operations.PermissionChanges.Success = $true
            $result.Success = $true
        } else {
            Write-Information "Step 6: Applying permission changes"
            
            if ($DryRun) {
                Write-Information "DRY RUN MODE - No actual changes will be made"
                Write-Information "Would perform the following operations:"
                
                foreach ($add in $delta.ToAdd) {
                    Write-Information "  ADD: Principal $($add.principalId) as $($add.role)"
                }
                foreach ($update in $delta.ToUpdate) {
                    Write-Information "  UPDATE: Principal $($update.principalId) from $($update.currentRole) to $($update.newRole)"
                }
                foreach ($remove in $delta.ToRemove) {
                    Write-Information "  REMOVE: Principal $($remove.principalId) with role $($remove.role)"
                }
                
                $result.Operations.PermissionChanges.Success = $true
                $result.Success = $true
            } else {
                $changeResults = Apply-PermissionChanges -CloudConnectionId $CloudConnectionId -Delta $delta -AccessToken $AccessToken -ContinueOnError:$ContinueOnError
                
                $result.Operations.PermissionChanges = $changeResults
                $result.Summary.PermissionsAdded = $changeResults.AddResults.SuccessCount
                $result.Summary.PermissionsUpdated = $changeResults.UpdateResults.SuccessCount
                $result.Summary.PermissionsRemoved = $changeResults.RemoveResults.SuccessCount
                $result.Summary.TotalChanges = $result.Summary.PermissionsAdded + $result.Summary.PermissionsUpdated + $result.Summary.PermissionsRemoved
                
                # Collect any errors from the change operations
                if ($changeResults.AddResults.Failures) {
                    $result.Errors += $changeResults.AddResults.Failures | ForEach-Object { "Add failed for $($_.PrincipalId): $($_.Error)" }
                }
                if ($changeResults.UpdateResults.Failures) {
                    $result.Errors += $changeResults.UpdateResults.Failures | ForEach-Object { "Update failed for $($_.PrincipalId): $($_.Error)" }
                }
                if ($changeResults.RemoveResults.Failures) {
                    $result.Errors += $changeResults.RemoveResults.Failures | ForEach-Object { "Remove failed for $($_.PrincipalId): $($_.Error)" }
                }
                
                $result.Success = ($result.Errors.Count -eq 0) -or $ContinueOnError
                
                # Get final state
                try {
                    $result.AfterState = Get-PBICloudConnectionPermissions -CloudConnectionId $CloudConnectionId -AccessToken $AccessToken
                } catch {
                    Write-Warning "Could not retrieve final permission state: $($_.Exception.Message)"
                }
            }
        }

        Write-Information "Permission group synchronization completed successfully"
        
    } catch {
        $result.Success = $false
        $result.Errors += "Operation failed: $($_.Exception.Message)"
        Write-Error "Permission group synchronization failed: $($_.Exception.Message)"
        throw
    }

    return $result
}

<#
.SYNOPSIS
Retrieves current permissions from a Power BI cloud connection.

.DESCRIPTION
Helper function to get the current role assignments from a Power BI shareable cloud connection.

.PARAMETER CloudConnectionId
The ID of the Power BI shareable cloud connection.

.PARAMETER AccessToken
Secure string containing the access token for the Power BI Fabric API.

.OUTPUTS
Returns an array of current permission objects.
#>

function Get-PBICloudConnectionPermissions
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $CloudConnectionId,
        
        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken
    )

    $splat = @{ 
        "Uri" = "https://api.fabric.microsoft.com/v1/connections/$CloudConnectionId/roleAssignments"
        "Method" = "GET"
        "Headers" = @{
            Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"
            'Content-type' = 'application/json'
        }
    }

    try {
        $response = Invoke-RestMethod @splat
        return $response.value
    } catch {
        Write-Error "Failed to retrieve permissions for cloud connection $CloudConnectionId`: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
Applies the calculated permission changes to the cloud connection.

.DESCRIPTION
Helper function that orchestrates the application of all permission changes (add, update, remove)
based on the calculated delta.

.PARAMETER CloudConnectionId
The ID of the Power BI shareable cloud connection.

.PARAMETER Delta
The permission delta object from Get-PermissionDelta.

.PARAMETER AccessToken
Secure string containing the access token for the Power BI Fabric API.

.PARAMETER ContinueOnError
Switch to continue processing even if some operations fail.

.OUTPUTS
Returns a detailed result object with success/failure information for each operation type.
#>

function Apply-PermissionChanges
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
        [switch] $ContinueOnError = $true
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
                    -AccessToken $AccessToken
                
                $changeResults.AddResults.SuccessCount++
                Write-Verbose "Successfully added permission for principal $($add.principalId) with role $($add.role)"
            } catch {
                $changeResults.AddResults.FailureCount++
                $changeResults.AddResults.Failures += @{
                    PrincipalId = $add.principalId
                    Role = $add.role
                    Error = $_.Exception.Message
                }
                Write-Error "Failed to add permission for principal $($add.principalId): $($_.Exception.Message)"
                
                if (-not $ContinueOnError) {
                    throw
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
                    -AccessToken $AccessToken
                
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
                Write-Error "Failed to update permission for principal $($update.principalId): $($_.Exception.Message)"
                
                if (-not $ContinueOnError) {
                    throw
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