# <copyright file="_GenerateUpdateBody.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Generates a hashtable representing the body for updating a shareable cloud connection.

.DESCRIPTION
This function constructs a hashtable that includes the necessary credential configuration details for updating
an existing shareable cloud connection. The output hashtable is designed to be converted to JSON
for API consumption.

The credential block matches the connection's declared credential type, rather than assuming
'ServicePrincipal' - a WorkspaceIdentity update body carries no secret at all, so the
unconditional service principal body would be wrong for it.

.PARAMETER DisplayName
The display name of the connection, used only to make error messages identify their subject.

.PARAMETER CredentialType
The type of credential the connection authenticates with. Defaults to 'ServicePrincipal'.

.PARAMETER ServicePrincipalClientId
The client ID for the service principal used for authentication. Only required when
CredentialType is 'ServicePrincipal'.

.PARAMETER ServicePrincipalSecret
The secret for the service principal (typically provided as a secure string).

.PARAMETER TenantId
The tenant ID associated with the service principal.

.OUTPUTS
Returns a hashtable representing the update body for a shareable cloud connection.

.EXAMPLE
$body = _GenerateUpdateBody -ServicePrincipalClientId "clientId" `
    -ServicePrincipalSecret "secret" `
    -TenantId "tenantId"
# This example returns a hashtable with the update details ready to be converted to JSON.
#>

function _GenerateUpdateBody
{
    # 'CredentialType' names which kind of credential to build, not a credential - the analyzer
    # matches on the parameter name alone.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialType', Justification = 'Selects a credential type by name; holds no secret')]
    [CmdletBinding()]
    param(
        $DisplayName,
        $CredentialType = 'ServicePrincipal',
        $ServicePrincipalClientId,
        $ServicePrincipalSecret,
        $TenantId
    )

    $credentials = _GenerateCredentialsBlock -DisplayName $DisplayName `
                                             -CredentialType $CredentialType `
                                             -ServicePrincipalClientId $ServicePrincipalClientId `
                                             -ServicePrincipalSecret $ServicePrincipalSecret `
                                             -TenantId $TenantId

    $updateBody = @{
        connectivityType = "ShareableCloud"
        credentialDetails = @{
            credentials = $credentials
        }
    }

    return $updateBody
}
