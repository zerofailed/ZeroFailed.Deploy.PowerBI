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