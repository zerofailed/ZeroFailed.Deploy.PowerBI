# <copyright file="Get-FabricCloudConnection.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Retrieves a single shared cloud connection from the tenant by display name.

.DESCRIPTION
Resolves a connection that this deployment did not necessarily provision, so that a use-case
repository can obtain its id and credential state without any create or update side effect.

This is deliberately NOT named 'Resolve-CloudConnection'. Despite the similar shape, it does
something entirely different from Resolve-CloudConnections: that function reads YAML from disk
and returns desired state without talking to Fabric at all, whereas this one queries the tenant
and returns actual state. A one-character difference between the two would be mis-called, and
the failure would be silent - a config object where a live one was expected.

.PARAMETER DisplayName
The display name of the connection to retrieve.

.PARAMETER AccessToken
A Fabric API access token.

.PARAMETER ThrowIfMissing
When set, a connection that cannot be found raises a terminating error rather than returning
$null.

.OUTPUTS
System.Object

.NOTES
Returns a connection carrying at least 'id', 'credentialType' and
'lastCredentialUsedDateTime', or $null when no connection of that display name is visible.

.EXAMPLE
$connection = Get-FabricCloudConnection -DisplayName 'EDAP_DEV_fp__shared' -AccessToken $token
$connection.id
# Returns the id of an existing connection, or $null if it is not visible to this identity.

.LINK
https://learn.microsoft.com/en-us/rest/api/fabric/core/connections/list-connections
#>

function Get-FabricCloudConnection
{
    [CmdletBinding()]
    [OutputType([System.Object])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $DisplayName,

        [Parameter(Mandatory = $true)]
        [securestring] $AccessToken,

        [Parameter()]
        [switch] $ThrowIfMissing
    )

    $connection = _Get-CloudConnectionList -AccessToken $AccessToken |
                    Where-Object { $_.displayName -eq $DisplayName } |
                    Select-Object -First 1

    if (!$connection) {
        # "Not found" is ambiguous here and the message has to say so. A connection the calling
        # identity holds no role on is invisible rather than merely unusable, so a miss means
        # either "not provisioned" or "not shared with this identity" - and those have
        # different fixes.
        $message = "Cloud connection '$DisplayName' was not found. Either it has not been provisioned, or it exists but is not shared with the identity running this deployment - a connection you hold no role on is invisible, even to a tenant admin."
        if ($ThrowIfMissing) {
            throw $message
        }
        Write-Verbose $message
        return $null
    }

    # The list endpoint does not reliably carry credentialDetails, so fall back to the by-id
    # read when it is absent. One extra call, negligible at this scale, and it removes the need
    # to know which fields the list response guarantees.
    #
    # The detail response only ever fills gaps - it never replaces the list entry outright.
    # The list entry is the one thing already known to identify the right connection, and an
    # unexpected response shape here would otherwise blank out the id that is the whole point
    # of this function.
    $detail = $null
    if (!$connection.credentialDetails) {
        $splat = @{
            'Uri'     = "https://api.fabric.microsoft.com/v1/connections/$($connection.id)"
            'Method'  = 'GET'
            'Headers' = @{
                Authorization  = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"
                'Content-type' = 'application/json'
            }
        }
        $detail = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue
    }

    $connectionDetails = $connection.connectionDetails ?? $detail.connectionDetails
    $credentialDetails = $connection.credentialDetails ?? $detail.credentialDetails

    return [PSCustomObject]@{
        id             = $connection.id
        displayName    = $connection.displayName
        connectionType = $connectionDetails.type
        creationMethod = $connectionDetails.creationMethod
        # Lets a caller assert that a connection is not deployed against an interim credential.
        credentialType = $credentialDetails.credentialType
        # A connection whose credential has NEVER been used is either unused, or failing before
        # the credential is reached - which is what a wrong-tenant binding looks like. Reading
        # this field is what settled a full day's misdiagnosis on the project that found it.
        lastCredentialUsedDateTime = $connection.lastCredentialUsedDateTime ?? $detail.lastCredentialUsedDateTime
        connection     = $detail ?? $connection
    }
}
