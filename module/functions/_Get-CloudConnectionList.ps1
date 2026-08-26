# <copyright file="_Get-CloudConnectionList.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Retrieves every shared cloud connection visible to the caller, following continuation tokens.

.DESCRIPTION
'GET /v1/connections' is a paged endpoint. Filtering a single unpaged response for a display
name silently misses any connection that falls on a later page, which for a create-or-update
flow means attempting a create for a connection that already exists - and failing on a
duplicate display name.

Note that "visible to the caller" is doing real work in that sentence: a connection the calling
identity holds no role on is not merely unusable, it is invisible, even to a tenant admin.

.PARAMETER AccessToken
A Fabric API access token.

.OUTPUTS
An array of connection objects, which may be empty.

.EXAMPLE
$connections = _Get-CloudConnectionList -AccessToken $token
#>

function _Get-CloudConnectionList
{
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [Parameter(Mandatory = $true)]
        [securestring] $AccessToken
    )

    $headers = @{
        Authorization  = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"
        'Content-type' = 'application/json'
    }

    $connections = [System.Collections.Generic.List[object]]::new()
    $uri = 'https://api.fabric.microsoft.com/v1/connections'

    while ($uri) {
        $splat = @{
            'Uri'     = $uri
            'Method'  = 'GET'
            'Headers' = $headers
        }
        $response = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue

        if ($response.value) {
            $connections.AddRange([object[]]$response.value)
        }

        # continuationUri carries the fully-formed next request; fall back to composing one from
        # the token for responses that only supply that.
        if ($response.continuationUri) {
            $uri = $response.continuationUri
        }
        elseif ($response.continuationToken) {
            $uri = "https://api.fabric.microsoft.com/v1/connections?continuationToken=$([uri]::EscapeDataString($response.continuationToken))"
        }
        else {
            $uri = $null
        }
    }

    return $connections.ToArray()
}
