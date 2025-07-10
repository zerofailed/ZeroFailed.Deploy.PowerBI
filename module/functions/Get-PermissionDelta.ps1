# <copyright file="Get-PermissionDelta.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Calculates the differences between current and desired permissions for a cloud connection.

.DESCRIPTION
This function analyzes the current permissions on a cloud connection and compares them with
the desired permissions to determine what actions need to be taken: additions, updates, or removals.
It supports strict synchronization mode where all non-configured permissions are removed.

.PARAMETER CurrentPermissions
Array of current permission objects from the PowerBI Fabric API, each containing:
- id: The role assignment ID
- principal: Object with id and type
- role: The assigned role (Owner, User, UserWithReshare)

.PARAMETER DesiredPermissions
Array of desired permission objects, each containing:
- principalId: The principal ID (GUID)
- principalType: The principal type (User, Group, ServicePrincipal, ServicePrincipalProfile)
- role: The desired role (Owner, User, UserWithReshare)

.PARAMETER StrictMode
Switch to enable strict synchronization. When enabled, any current permissions not found
in the desired permissions will be marked for removal.

.OUTPUTS
Returns a hashtable with three arrays:
- ToAdd: Permissions that need to be created
- ToUpdate: Permissions that exist but have different roles
- ToRemove: Permissions that should be removed (only in strict mode)

.EXAMPLE
$current = @(
    @{ id = "1"; principal = @{ id = "user1"; type = "User" }; role = "User" },
    @{ id = "2"; principal = @{ id = "user2"; type = "User" }; role = "Owner" }
)

$desired = @(
    @{ principalId = "user1"; principalType = "User"; role = "Owner" },
    @{ principalId = "user3"; principalType = "User"; role = "User" }
)

$delta = Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired -StrictMode
#>

function Get-PermissionDelta
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [object[]] $CurrentPermissions,
        
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [object[]] $DesiredPermissions,
        
        [Parameter()]
        [switch] $StrictMode
    )

    Write-Verbose "Calculating permission delta for $($CurrentPermissions.Count) current and $($DesiredPermissions.Count) desired permissions"
    Write-Verbose "Strict mode: $StrictMode"

    # Initialize result arrays
    $toAdd = @()
    $toUpdate = @()
    $toRemove = @()

    # Create lookup hashtables for efficient comparison
    $currentLookup = @{}
    $desiredLookup = @{}

    # Build current permissions lookup by principal ID
    foreach ($current in $CurrentPermissions) {
        if ($current.principal -and $current.principal.id) {
            $key = $current.principal.id.ToString().ToLower()
            $currentLookup[$key] = $current
            Write-Verbose "Current permission: Principal $key has role $($current.role)"
        }
    }

    # Build desired permissions lookup by principal ID
    foreach ($desired in $DesiredPermissions) {
        if ($desired.principalId) {
            $key = $desired.principalId.ToString().ToLower()
            $desiredLookup[$key] = $desired
            Write-Verbose "Desired permission: Principal $key should have role $($desired.role)"
        }
    }

    # Find permissions to add or update
    foreach ($desiredKey in $desiredLookup.Keys) {
        $desired = $desiredLookup[$desiredKey]
        
        if ($currentLookup.ContainsKey($desiredKey)) {
            # Permission exists, check if role needs updating
            $current = $currentLookup[$desiredKey]
            
            if ($current.role -ne $desired.role) {
                Write-Verbose "Permission update needed: Principal $desiredKey role change from $($current.role) to $($desired.role)"
                $toUpdate += @{
                    currentId = $current.id
                    principalId = $desired.principalId
                    principalType = $desired.principalType
                    currentRole = $current.role
                    newRole = $desired.role
                    operation = "Update"
                }
            } else {
                Write-Verbose "Permission already correct: Principal $desiredKey has correct role $($desired.role)"
            }
        } else {
            # Permission doesn't exist, needs to be added
            Write-Verbose "Permission addition needed: Principal $desiredKey role $($desired.role)"
            $toAdd += @{
                principalId = $desired.principalId
                principalType = $desired.principalType
                role = $desired.role
                operation = "Add"
            }
        }
    }

    # Find permissions to remove (only in strict mode)
    if ($StrictMode) {
        foreach ($currentKey in $currentLookup.Keys) {
            if (-not $desiredLookup.ContainsKey($currentKey)) {
                $current = $currentLookup[$currentKey]
                Write-Verbose "Permission removal needed: Principal $currentKey with role $($current.role) not in desired state"
                $toRemove += @{
                    currentId = $current.id
                    principalId = $current.principal.id
                    principalType = $current.principal.type
                    role = $current.role
                    operation = "Remove"
                }
            }
        }
    }

    # Validate that we're not removing all owners
    $currentOwners = $CurrentPermissions | Where-Object { $_.role -eq "Owner" }
    $desiredOwners = $DesiredPermissions | Where-Object { $_.role -eq "Owner" }
    
    if ($currentOwners.Count -gt 0 -and $desiredOwners.Count -eq 0) {
        Write-Warning "Warning: No owners specified in desired permissions. This may leave the connection without any owners."
    }

    # Log summary
    Write-Information "Permission delta summary:"
    Write-Information "  - Additions needed: $($toAdd.Count)"
    Write-Information "  - Updates needed: $($toUpdate.Count)"
    Write-Information "  - Removals needed: $($toRemove.Count)"

    return @{
        ToAdd = $toAdd
        ToUpdate = $toUpdate
        ToRemove = $toRemove
        Summary = @{
            AdditionsCount = $toAdd.Count
            UpdatesCount = $toUpdate.Count
            RemovalsCount = $toRemove.Count
            TotalChanges = $toAdd.Count + $toUpdate.Count + $toRemove.Count
        }
    }
}

<#
.SYNOPSIS
Validates permission objects to ensure they have required properties.

.DESCRIPTION
Helper function to validate that permission objects contain the required properties
for processing. Used internally by Get-PermissionDelta.

.PARAMETER Permissions
Array of permission objects to validate.

.PARAMETER PermissionType
String indicating the type of permissions being validated ("Current" or "Desired").

.OUTPUTS
Returns $true if all permissions are valid, $false otherwise.
#>

function Test-PermissionObjectsValid
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [object[]] $Permissions,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Current", "Desired")]
        [string] $PermissionType
    )

    $isValid = $true

    foreach ($permission in $Permissions) {
        if ($PermissionType -eq "Current") {
            if (-not $permission.principal -or -not $permission.principal.id -or -not $permission.role) {
                Write-Error "Invalid current permission object: Missing principal.id or role"
                $isValid = $false
            }
        } elseif ($PermissionType -eq "Desired") {
            if (-not $permission.principalId -or -not $permission.principalType -or -not $permission.role) {
                Write-Error "Invalid desired permission object: Missing principalId, principalType, or role"
                $isValid = $false
            }
        }
    }

    return $isValid
}

<#
.SYNOPSIS
Converts permission groups (owners, users, reshareUsers) to flat permission array.

.DESCRIPTION
Helper function that converts the structured permission groups format used in configuration
files to a flat array of permission objects suitable for delta calculation.

.PARAMETER PermissionGroups
Hashtable containing permission groups with keys like "owners", "users", "reshareUsers".

.PARAMETER ResolvedIdentities
Array of resolved identity objects from Resolve-PrincipalIdentities function.

.OUTPUTS
Returns an array of permission objects with principalId, principalType, and role properties.

.EXAMPLE
$groups = @{
    owners = @("user1@domain.com")
    users = @("user2@domain.com", @{ principalId = "guid"; principalType = "Group" })
}
$resolved = Resolve-PrincipalIdentities -Identities @("user1@domain.com", "user2@domain.com") -GraphAccessToken $token
$permissions = ConvertFrom-PermissionGroups -PermissionGroups $groups -ResolvedIdentities $resolved
#>

function ConvertFrom-PermissionGroups
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable] $PermissionGroups,
        
        [Parameter(Mandatory=$true)]
        [object[]] $ResolvedIdentities
    )

    $permissions = @()
    
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
                    $permissions += @{
                        principalId = $identity.principalId
                        principalType = $identity.principalType
                        role = $role
                    }
                } else {
                    Write-Warning "Could not find resolved identity for: $lookupKey"
                }
            }
        }
    }

    Write-Verbose "Converted $($PermissionGroups.Keys.Count) permission groups to $($permissions.Count) individual permissions"
    return $permissions
}