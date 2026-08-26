# <copyright file="_Assert-ValidConnectionType.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Validates a connection's type, creation method and credential type against the tenant.

.DESCRIPTION
Checks a connection definition against 'GET /v1/connections/supportedConnectionTypes' before any
create is attempted, so that a malformed definition fails with a message naming the actual
problem and the valid alternatives.

The failure this exists to prevent misdirects badly: supplying a valid type with an invalid
creation method returns "No function found matching 'X' for Kind: 'X'", which reads as though
the type is wrong, and sends you looking at the one thing that was correct.

IMPORTANT: support is not access. A WorkspaceIdentity SharePoint connection passes this check,
is created happily, passes its own connection test, and then fails the first real operation with
"Unauthorized exception, failed to retrieve SharePoint drives". This validation prevents a
malformed request; it proves nothing about whether the credential can read the source.

The supported types are fetched once and cached for the lifetime of the module, since they do
not change during a deployment.

.PARAMETER ConnectionType
The connector kind to validate.

.PARAMETER CreationMethod
The Power Query function to validate. When empty, the connection type is used.

.PARAMETER CredentialType
The credential type to validate. Optional.

.PARAMETER DisplayName
The display name of the connection, used only to make error messages identify their subject.

.PARAMETER AccessToken
A Fabric API access token.

.PARAMETER Force
Bypasses the cache and re-reads the supported types from the tenant.

.EXAMPLE
_Assert-ValidConnectionType -ConnectionType 'SharePoint' -CreationMethod 'SharePointList' -DisplayName 'EDAP_DEV_sp__hat' -AccessToken $token
#>

function _Assert-ValidConnectionType
{
    # 'CredentialType' names which kind of credential to validate, not a credential - the
    # analyzer matches on the parameter name alone.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialType', Justification = 'Selects a credential type by name; holds no secret')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ConnectionType,

        [Parameter()]
        [string] $CreationMethod,

        [Parameter()]
        [string] $CredentialType,

        [Parameter()]
        [string] $DisplayName,

        [Parameter(Mandatory = $true)]
        [securestring] $AccessToken,

        [Parameter()]
        [switch] $Force
    )

    if ([string]::IsNullOrEmpty($CreationMethod)) {
        $CreationMethod = $ConnectionType
    }

    if ($Force -or $null -eq $script:SupportedConnectionTypeCache) {
        $headers = @{
            Authorization  = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"
            'Content-type' = 'application/json'
        }
        $supported = [System.Collections.Generic.List[object]]::new()
        $uri = 'https://api.fabric.microsoft.com/v1/connections/supportedConnectionTypes?showAllCreationMethods=true'

        while ($uri) {
            $response = Invoke-RestMethodWithRateLimit -Splat @{
                'Uri'     = $uri
                'Method'  = 'GET'
                'Headers' = $headers
            } -InformationAction Continue

            if ($response.value) {
                $supported.AddRange([object[]]$response.value)
            }

            if ($response.continuationUri) {
                $uri = $response.continuationUri
            }
            elseif ($response.continuationToken) {
                $uri = "https://api.fabric.microsoft.com/v1/connections/supportedConnectionTypes?showAllCreationMethods=true&continuationToken=$([uri]::EscapeDataString($response.continuationToken))"
            }
            else {
                $uri = $null
            }
        }

        $script:SupportedConnectionTypeCache = $supported.ToArray()
    }

    $supportedTypes = $script:SupportedConnectionTypeCache

    if (!$supportedTypes) {
        Write-Warning "Could not read the supported connection types from the tenant; skipping validation of '$DisplayName'."
        return
    }

    $match = $supportedTypes | Where-Object { $_.type -eq $ConnectionType } | Select-Object -First 1
    if (!$match) {
        throw ("Connection '$DisplayName' declares type '$ConnectionType', which this tenant does not support. " +
               "Supported types are: $(($supportedTypes.type | Sort-Object) -join ', ').")
    }

    $validCreationMethods = @($match.creationMethods.name)
    if ($validCreationMethods -and $CreationMethod -notin $validCreationMethods) {
        throw ("Connection '$DisplayName' declares creationMethod '$CreationMethod', which is not valid for type '$ConnectionType'. " +
               "Valid creation methods for this type are: $(($validCreationMethods | Sort-Object) -join ', ').")
    }

    if (![string]::IsNullOrEmpty($CredentialType)) {
        $validCredentialTypes = @($match.supportedCredentialTypes)
        if ($validCredentialTypes -and $CredentialType -notin $validCredentialTypes) {
            throw ("Connection '$DisplayName' declares credentialType '$CredentialType', which is not supported for type '$ConnectionType'. " +
                   "Supported credential types for this type are: $(($validCredentialTypes | Sort-Object) -join ', ').")
        }
    }
}
