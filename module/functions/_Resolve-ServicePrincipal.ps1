# <copyright file="_Resolve-ServicePrincipal.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Resolves a service principal reference to its full details from a hashtable of service principals.

.DESCRIPTION
This function takes a reference string (e.g., "development") and looks up the corresponding
service principal configuration within a provided hashtable. It's used to denormalize
connection configurations by resolving references to their actual values.

.PARAMETER ServicePrincipals
A hashtable containing service principal configurations.

.PARAMETER Reference
A string representing the reference to the service principal (e.g., "development").

.OUTPUTS
Returns a hashtable containing the details of the resolved service principal.

.EXAMPLE
$servicePrincipals = @{
    development = @{ clientId = 'abc'; secretUrl = 'xyz' }
}
$sp = _Resolve-ServicePrincipal -ServicePrincipals $servicePrincipals -Reference 'development'
#>

function _Resolve-ServicePrincipal {
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