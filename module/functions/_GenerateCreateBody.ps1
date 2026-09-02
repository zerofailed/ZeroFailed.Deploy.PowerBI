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
Specifies the connector kind for the connection (e.g. 'AzureBlobs', 'SQL', 'SharePoint').

.PARAMETER CreationMethod
Specifies the Power Query function used to build the connection. When omitted it defaults to
ConnectionType, which is correct for connectors where the two coincide (e.g. 'AzureBlobs',
'SQL') but not for those where they differ (e.g. 'SharePoint'/'SharePointList').

.PARAMETER Parameters
A hashtable array containing additional parameters required for the connection.

.PARAMETER CredentialType
The type of credential the connection authenticates with. Supported unattended:
'ServicePrincipal' (the default), 'WorkspaceIdentity' and 'Anonymous'. Credential types that
require interactive consent ('OAuth2', 'Basic', 'Windows') are rejected with guidance.

.PARAMETER ServicePrincipalClientId
The client ID for the service principal used for authentication. Only required when
CredentialType is 'ServicePrincipal'.

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
    # 'CredentialType' names which kind of credential to build, not a credential - the analyzer
    # matches on the parameter name alone.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialType', Justification = 'Selects a credential type by name; holds no secret')]
    [CmdletBinding()]
    param (
        $DisplayName,
        $ConnectionType,
        $CreationMethod,
        $Parameters,
        $CredentialType = 'ServicePrincipal',
        $ServicePrincipalClientId,
        $ServicePrincipalSecret,
        $TenantId
    )

    # 'type' is the connector kind; 'creationMethod' is the Power Query function that builds it.
    # They coincide for SQL and AzureBlobs, and differ for SharePoint (SharePoint/SharePointList)
    # and Fabric pipelines (FabricDataPipelines/FabricDataPipelines.Actions). Supplying a valid
    # type with an invalid creation method returns "No function found matching 'X' for Kind: 'X'",
    # which reads as though the type is wrong and sends you looking at the one thing that was right.
    if ([string]::IsNullOrEmpty($CreationMethod)) {
        $CreationMethod = $ConnectionType
    }

    $credentials = _GenerateCredentialsBlock -DisplayName $DisplayName `
                                             -CredentialType $CredentialType `
                                             -ServicePrincipalClientId $ServicePrincipalClientId `
                                             -ServicePrincipalSecret $ServicePrincipalSecret `
                                             -TenantId $TenantId

    $createBody = @{
        connectivityType = "ShareableCloud"
        displayName = $DisplayName
        connectionDetails = @{
            type = $ConnectionType
            creationMethod = $CreationMethod
            parameters = $Parameters
        }
        privacyLevel = "Organizational"
        credentialDetails = @{
            singleSignOnType = "None"
            connectionEncryption = "NotEncrypted"
            skipTestConnection = $false
            credentials = $credentials
        }
    }
    
    return $createBody
}