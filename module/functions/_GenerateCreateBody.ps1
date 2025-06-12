# <copyright file="_GenerateCreateBody.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Generates a hashtable representing the body for creating a Power BI shareable cloud connection.

.DESCRIPTION
This function constructs a hashtable that includes all necessary configuration details for creating
a shareable cloud connection in Power BI. The output hashtable is designed to be converted to JSON
for API consumption.

.PARAMETER DisplayName
The display name for the connection.

.PARAMETER ConnectionType
Specifies the type of the connection which is also used as the creation method.

.PARAMETER Parameters
A hashtable array containing additional parameters required for the connection.

.PARAMETER ServicePrincipalClientId
The client ID for the service principal used for authentication.

.PARAMETER ServicePrincipalSecret
The secret for the service principal (typically provided as a secure string).

.PARAMETER TenantId
The tenant ID associated with the service principal.

.OUTPUTS
Returns a hashtable representing the create body for a Power BI shareable cloud connection.

.EXAMPLE
$body = _GenerateCreateBody -DisplayName "My Connection" `
    -ConnectionType "ExampleType" `
    -Parameters @{ key = "value" } `
    -ServicePrincipalClientId "clientId" `
    -ServicePrincipalSecret "secret" `
    -TenantId "tenantId"
# This example returns a hashtable with the connection details ready to be converted to JSON.
#>

function _GenerateCreateBody 
{
    [CmdletBinding()]
    param (
        $DisplayName,
        $ConnectionType,
        $Parameters,
        $ServicePrincipalClientId,
        $ServicePrincipalSecret,
        $TenantId
    )

    $createBody = @{
        connectivityType = "ShareableCloud"
        displayName = $DisplayName
        connectionDetails = @{
            type = $ConnectionType
            creationMethod = $ConnectionType
            parameters = $Parameters
        }
        privacyLevel = "Organizational"
        credentialDetails = @{
            singleSignOnType = "None"
            connectionEncryption = "NotEncrypted"
            skipTestConnection = $false
            credentials = @{
            credentialType = "ServicePrincipal"
            servicePrincipalClientId = $ServicePrincipalClientId
            servicePrincipalSecret = $ServicePrincipalSecret
            tenantId = $TenantId
            }
        }
    }
    
    return $createBody
}