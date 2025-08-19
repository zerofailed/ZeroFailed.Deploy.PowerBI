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
        [switch] $StrictMode,
        
        [Parameter()]
        [switch] $DryRun,
        
        [Parameter()]
        [switch] $ContinueOnError
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
            throw $errorMessage
        }

        # Step 3: Convert permission groups to flat permission list
        Write-Information "Step 3: Converting permission groups to individual permissions"
        
        try {
            $desiredPermissions = _ConvertFrom-PermissionGroups -PermissionGroups $PermissionGroups -ResolvedIdentities $resolvedIdentities
            Write-Information "Converted to $($desiredPermissions.Count) individual permission assignments"
        } catch {
            $errorMessage = "Failed to convert permission groups: $($_.Exception.Message)"
            $result.Errors += $errorMessage
            throw $errorMessage         
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
            throw $errorMessage            
        }

        # Step 5: Calculate permission delta
        Write-Information "Step 5: Calculating permission changes needed"
        
        try {
            $delta = _Get-PermissionDelta -CurrentPermissions $currentPermissions -DesiredPermissions $desiredPermissions -StrictMode:$StrictMode
            $result.Operations.DeltaCalculation.Success = $true
            $result.Operations.DeltaCalculation.Details = $delta
            
            Write-Information "Delta calculation complete:"
            Write-Information "  - Additions: $($delta.ToAdd.Count)"
            Write-Information "  - Updates: $($delta.ToUpdate.Count)"
            Write-Information "  - Removals: $($delta.ToRemove.Count)"
        } catch {
            $errorMessage = "Failed to calculate permission delta: $($_.Exception.Message)"
            $result.Errors += $errorMessage
            throw $errorMessage         
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
                $changeResults = _Apply-PermissionChanges -CloudConnectionId $CloudConnectionId -Delta $delta -AccessToken $AccessToken -ContinueOnError:$ContinueOnError
                
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
                    Write-Verbose "Exception Stack Trace: $($_.ScriptStackTrace)"
                }
            }
        }

        Write-Information "Permission group synchronization completed successfully"
        
    } catch {
        $result.Success = $false
        $result.Errors += "Operation failed: $($_.Exception.Message)"
        Write-Verbose $_.ScriptStackTrace
        throw "Permission group synchronization failed: $($_.Exception.Message)"     
    }

    return $result
}