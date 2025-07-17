# <copyright file="Test-PermissionObjectsValid.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Validates an array of permission objects to ensure they contain required properties.

.DESCRIPTION
This function iterates through a collection of permission objects and checks if each object
has the 'principalId', 'principalType', and 'role' properties defined. It's used to ensure
that permission data structures are well-formed before further processing.

.PARAMETER Permissions
An array of permission objects to validate. Each object is expected to have
'principalId', 'principalType', and 'role' properties.

.PARAMETER PermissionType
Specifies the type of permissions being validated ("Current" or "Desired"). This affects
which properties are checked for validity.

.OUTPUTS
Returns `$true` if all permission objects are valid, `$false` otherwise.

.EXAMPLE
$validPermissions = @(
    @{ principalId = "id1"; principalType = "User"; role = "Owner" },
    @{ principalId = "id2"; principalType = "Group"; role = "User" }
)
Test-PermissionObjectsValid -Permissions $validPermissions -PermissionType "Desired" # Returns True

$invalidPermissions = @(
    @{ principalId = "id3"; role = "Owner" } # Missing principalType
)
Test-PermissionObjectsValid -Permissions $invalidPermissions -PermissionType "Desired" # Returns False
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