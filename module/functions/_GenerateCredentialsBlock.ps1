# <copyright file="_GenerateCredentialsBlock.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Generates the 'credentials' hashtable for a shared cloud connection create or update body.

.DESCRIPTION
Builds the credential block that both _GenerateCreateBody and _GenerateUpdateBody embed, so
that a connection's declared credential type is honoured consistently on both paths.

Fabric supports several credential types, but only three can be established without a human
at a browser:

- ServicePrincipal   - client id, secret and tenant.
- WorkspaceIdentity  - no secret, no parameters. Required by FabricDataPipelines connections.
- Anonymous          - no secret, for public endpoints.

The remainder ('OAuth2', 'Basic', 'Windows') require interactive consent and are rejected here
with the recipe for doing it by hand, rather than being allowed to fail as an opaque REST error
or, worse, to leave a half-created connection behind.

.PARAMETER DisplayName
The display name of the connection, used only to make error messages identify their subject.

.PARAMETER CredentialType
The credential type to generate a block for. Defaults to 'ServicePrincipal'.

.PARAMETER ServicePrincipalClientId
The client ID for the service principal. Required when CredentialType is 'ServicePrincipal'.

.PARAMETER ServicePrincipalSecret
The service principal secret, as plain text. Required when CredentialType is 'ServicePrincipal'.

.PARAMETER TenantId
The tenant ID for the service principal. Required when CredentialType is 'ServicePrincipal'.

.OUTPUTS
Returns a hashtable representing the 'credentials' block.

.EXAMPLE
$credentials = _GenerateCredentialsBlock -DisplayName 'EDAP_DEV_fp__shared' -CredentialType 'WorkspaceIdentity'
# Returns @{ credentialType = 'WorkspaceIdentity' }
#>

function _GenerateCredentialsBlock
{
    # 'CredentialType' names which kind of credential to build, not a credential - the analyzer
    # matches on the parameter name alone.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialType', Justification = 'Selects a credential type by name; holds no secret')]
    [CmdletBinding()]
    param (
        $DisplayName,
        $CredentialType = 'ServicePrincipal',
        $ServicePrincipalClientId,
        $ServicePrincipalSecret,
        $TenantId
    )

    if ([string]::IsNullOrEmpty($CredentialType)) {
        $CredentialType = 'ServicePrincipal'
    }

    switch ($CredentialType) {
        'ServicePrincipal' {
            # NOTE: an unsupplied [guid] parameter binds to $null, NOT to [guid]::Empty, so
            # IsNullOrEmpty is the check that actually fires here. Comparing against
            # [guid]::Empty would make this guard dead code.
            if ([string]::IsNullOrEmpty($ServicePrincipalClientId)) {
                throw "Connection '$DisplayName' uses credentialType 'ServicePrincipal' but no service principal was resolved. Declare a 'servicePrincipal' block or a 'useServicePrincipal' reference for it."
            }
            @{
                credentialType           = 'ServicePrincipal'
                servicePrincipalClientId = $ServicePrincipalClientId
                servicePrincipalSecret   = $ServicePrincipalSecret
                tenantId                 = $TenantId
            }
        }

        # Both of these carry no secret and no parameters - the block is the credentialType alone.
        'WorkspaceIdentity' { @{ credentialType = 'WorkspaceIdentity' } }
        'Anonymous'         { @{ credentialType = 'Anonymous' } }

        { $_ -in @('OAuth2', 'Basic', 'Windows') } {
            throw ("Connection '$DisplayName' requires credentialType '$_', which needs " +
                   "interactive consent and cannot be created unattended. Create it in the " +
                   "portal (Manage connections and gateways -> + New -> Cloud), or switch the " +
                   "definition to ServicePrincipal or WorkspaceIdentity.")
        }

        default {
            throw "Connection '$DisplayName' has unknown credentialType '$_'. Supported unattended values are: ServicePrincipal, WorkspaceIdentity, Anonymous."
        }
    }
}
