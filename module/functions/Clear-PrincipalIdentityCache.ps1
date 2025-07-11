function Clear-PrincipalIdentityCache
{
    [CmdletBinding()]
    param()
    
    if ($script:PrincipalIdentityCache) {
        $script:PrincipalIdentityCache.Clear()
        Write-Verbose "Principal identity cache cleared"
    }
}