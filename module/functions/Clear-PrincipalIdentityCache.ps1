# <copyright file="Clear-PrincipalIdentityCache.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Clears the in-memory cache of resolved principal identities.

.DESCRIPTION
This function removes all entries from the `$script:PrincipalIdentityCache` hashtable,
forcing subsequent identity resolution calls to re-query Microsoft Graph API.
This is useful for ensuring fresh data or for testing scenarios.

.OUTPUTS
None.

.EXAMPLE
Clear-PrincipalIdentityCache
#>

function Clear-PrincipalIdentityCache
{
    [CmdletBinding()]
    param()
    
    if (!(Test-Path variable:/PrincipalIdentityCache) -or $PrincipalIdentityCache -isnot [hashtable]) {
        $script:PrincipalIdentityCache = @{}
        Write-Verbose "Clear-PrincipalIdentityCache: Principal identity cache initialised"
    }
    else ($script:PrincipalIdentityCache) {
        $script:PrincipalIdentityCache.Clear()
        Write-Verbose "Principal identity cache cleared"
    }
}