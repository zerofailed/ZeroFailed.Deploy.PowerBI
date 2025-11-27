# <copyright file="Clear-PrincipalIdentityCache.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Clear-PrincipalIdentityCache
{
    [CmdletBinding()]
    [OutputType([System.Void])]
    param()
    
    if (!(Test-Path variable:/PrincipalIdentityCache) -or $PrincipalIdentityCache -isnot [hashtable]) {
        $script:PrincipalIdentityCache = @{}
        Write-Verbose "Clear-PrincipalIdentityCache: Principal identity cache initialised"
    }
    else {
        $script:PrincipalIdentityCache.Clear()
        Write-Verbose "Principal identity cache cleared"
    }
}