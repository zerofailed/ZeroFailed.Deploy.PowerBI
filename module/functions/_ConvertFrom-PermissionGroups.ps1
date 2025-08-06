# <copyright file="_ConvertFrom-PermissionGroups.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Converts a hashtable of permission groups into a flat array of individual permission objects.

.DESCRIPTION
This function takes a structured hashtable of permission groups (e.g., owners, users) and
transforms it into a flat array of permission objects, each containing a principal ID,
principal type, and the corresponding Power BI role. It uses a lookup of already resolved
identities to ensure consistency and efficiency.

.PARAMETER PermissionGroups
Hashtable containing permission groups with keys like "owners", "users", "reshareUsers".
Each group contains an array of identities (email addresses or structured objects).

.PARAMETER ResolvedIdentities
Array of objects representing identities that have already been resolved to principal IDs and types.
This is used to map the identities in PermissionGroups to their resolved forms.

.OUTPUTS
Returns an array of permission objects, each with 'principalId', 'principalType', and 'role' properties.

.EXAMPLE
$permissionGroups = @{
    owners = @("user1@domain.com")
    users = @("user2@domain.com")
}
$resolvedIdentities = @(
    @{ originalIdentity = "user1@domain.com"; principalId = "id1"; principalType = "User" },
    @{ originalIdentity = "user2@domain.com"; principalId = "id2"; principalType = "User" }
)
$permissions = _ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities
#>

using namespace System.Collections.Generic

function _ConvertFrom-PermissionGroups
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable] $PermissionGroups,
        
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [object[]] $ResolvedIdentities
    )

    $permissions = [List[object]]::new()
    
    # Create lookup for resolved identities
    $identityLookup = @{}
    foreach ($identity in $ResolvedIdentities) {
        $key = if ($identity.originalIdentity -is [string]) {
            $identity.originalIdentity
        } else {
            "$($identity.principalId):$($identity.principalType)"
        }
        $identityLookup[$key] = $identity
    }

    # Map permission group names to PowerBI roles
    $roleMapping = @{
        "owners" = "Owner"
        "users" = "User"
        "reshareUsers" = "UserWithReshare"
    }

    foreach ($groupName in $PermissionGroups.Keys) {
        if (-not $roleMapping.ContainsKey($groupName)) {
            Write-Warning "Unknown permission group: $groupName"
            continue
        }

        $role = $roleMapping[$groupName]
        $groupMembers = $PermissionGroups[$groupName]

        if ($groupMembers -and $groupMembers.Count -gt 0) {
            foreach ($member in $groupMembers) {
                $lookupKey = if ($member -is [string]) {
                    $member
                } else {
                    "$($member.principalId):$($member.principalType)"
                }

                if ($identityLookup.ContainsKey($lookupKey)) {
                    $identity = $identityLookup[$lookupKey]
                    $permissions.Add(@{
                        principalId = $identity.principalId
                        principalType = $identity.principalType
                        role = $role
                    })
                } else {
                    Write-Warning "Could not find resolved identity for: $lookupKey"
                }
            }
        }
    }

    Write-Verbose "Converted $($PermissionGroups.Keys.Count) permission groups to $($permissions.Count) individual permissions"
    
    # Ensure PowerShell doesn't unroll an empty or single item array
    return ,$permissions
}