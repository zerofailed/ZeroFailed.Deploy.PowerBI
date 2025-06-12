# <copyright file="_GenerateUpdateBody.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Generates a hashtable representing the body for updating a Power BI shareable cloud connection.

.DESCRIPTION
This function constructs a hashtable that includes the necessary credential configuration details for updating
an existing shareable cloud connection in Power BI. The output hashtable is designed to be converted to JSON
for API consumption.

.PARAMETER ServicePrincipalClientId
The client ID for the service principal used for authentication.

.PARAMETER ServicePrincipalSecret
The secret for the service principal (typically provided as a secure string).

.PARAMETER TenantId
The tenant ID associated with the service principal.

.OUTPUTS
Returns a hashtable representing the update body for a Power BI shareable cloud connection.

.EXAMPLE
$body = _GenerateUpdateBody -ServicePrincipalClientId "clientId" `
    -ServicePrincipalSecret "secret" `
    -TenantId "tenantId"
# This example returns a hashtable with the update details ready to be converted to JSON.
#>

function _GenerateUpdateBody 
{   
    [CmdletBinding()]
    param(
        $ServicePrincipalClientId,
        $ServicePrincipalSecret,
        $TenantId
    )

    $updateBody = @{
        connectivityType = "ShareableCloud"
        credentialDetails = @{
            credentials = @{
            credentialType = "ServicePrincipal"
            servicePrincipalClientId = $ServicePrincipalClientId
            servicePrincipalSecret = $ServicePrincipalSecret
            tenantId = $TenantId
            }
        }
    }

    return $updateBody
}