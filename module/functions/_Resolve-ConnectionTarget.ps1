# <copyright file="_Resolve-ConnectionTarget.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Resolves a connection target reference to its full details from a hashtable of connection targets.

.DESCRIPTION
This function takes a reference string (e.g., "blobStorage.dev") and looks up the corresponding
connection target configuration within a provided hashtable. It's used to denormalize
connection configurations by resolving references to their actual values.

.PARAMETER ConnectionTargets
A hashtable containing nested connection target configurations.

.PARAMETER Reference
A string representing the reference to the connection target (e.g., "blobStorage.dev").

.OUTPUTS
Returns a hashtable containing the details of the resolved connection target.

.EXAMPLE
$connectionTargets = @{
    blobStorage = @{
        dev = @{ domain = 'blob.core.windows.net'; account = 'devstorageaccount' }
    }
}
$target = _Resolve-ConnectionTarget -ConnectionTargets $connectionTargets -Reference 'blobStorage.dev'
#>

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