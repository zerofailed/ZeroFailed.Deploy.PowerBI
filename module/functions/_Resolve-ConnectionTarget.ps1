function _Resolve-ConnectionTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ConnectionTargets,
        
        [Parameter(Mandatory)]
        [string]$Reference
    )

    $type, $env = $Reference -split '\.'
    if ($ConnectionTargets.ContainsKey($type) -and $ConnectionTargets[$type].ContainsKey($env)) {
        return $ConnectionTargets[$type][$env]
    }
    throw "Connection Target reference '$Reference' not found"
}