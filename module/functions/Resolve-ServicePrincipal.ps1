function Resolve-ServicePrincipal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ServicePrincipals,
        
        [Parameter(Mandatory)]
        [string]$Reference
    )

    if ($ServicePrincipals.ContainsKey($Reference)) {
        return $ServicePrincipals[$Reference]
    }
    throw "Service Principal reference '$Reference' not found"
}