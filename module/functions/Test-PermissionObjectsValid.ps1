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