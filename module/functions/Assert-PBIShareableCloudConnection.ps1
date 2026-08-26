# <copyright file="Assert-PBIShareableCloudConnection.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Assert-PBIShareableCloudConnection
{
    # 'CredentialType' names which kind of credential to use, not a credential - the analyzer
    # matches on the parameter name alone.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialType', Justification = 'Selects a credential type by name; holds no secret')]
    [CmdletBinding()]
    [OutputType([System.Object])]
    param (
        [Parameter(Mandatory=$true)]
        [string] $DisplayName,

        [Parameter(Mandatory=$true)]
        [string] $ConnectionType,

        # The Power Query function used to build the connection. Defaults to $ConnectionType
        # when not supplied, which is correct only where the two coincide.
        [Parameter()]
        [string] $CreationMethod,

        # AllowEmptyCollection is required, not cosmetic: a FabricDataPipelines connection has
        # no parameters at all, and a mandatory [hashtable[]] rejects an empty array outright
        # with "Cannot bind argument to parameter 'Parameters' because it is an empty array."
        [Parameter()]
        [AllowEmptyCollection()]
        [hashtable[]] $Parameters = @(),

        # The credential types that carry no secret (WorkspaceIdentity, Anonymous) have no
        # service principal, so none of the following three can be mandatory.
        [Parameter()]
        [string] $CredentialType = 'ServicePrincipal',

        [Parameter()]
        [guid] $ServicePrincipalClientId,

        [Parameter()]
        [securestring] $ServicePrincipalSecret,

        [Parameter()]
        [string] $TenantId,

        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken,

        # [bool] rather than [switch], deliberately: 'false' has to be expressible from YAML.
        # Defaults to true, which preserves both today's behaviour and the Key Vault secret
        # rotation flow that depends on it.
        [Parameter()]
        [bool] $AllowCredentialUpdate = $true,

        # Run-level override, for converging structure without touching any credential.
        [Parameter()]
        [switch] $SkipCredentialUpdates,

        # Checks the type, creation method and credential type against the tenant before
        # attempting a create. Improves diagnosis rather than enabling anything, so it is opt-in
        # at this level; the task turns it on by default.
        [Parameter()]
        [switch] $ValidateConnectionType,

        [Parameter()]
        [switch] $ContinueOnError
    )

    # Only a ServicePrincipal connection has credentials to pass on. Adding these keys
    # unconditionally would pipe a $null secret into ConvertFrom-SecureString, which fails with
    # "Cannot bind argument to parameter 'SecureString' because it is null" and - under the
    # build's $ErrorActionPreference of 'Stop' - is swallowed by the catch below, surfacing as a
    # generic "Failed to process cloud connection".
    $credentialSplat = @{
        credentialType = $CredentialType
    }
    if ($CredentialType -eq 'ServicePrincipal') {
        $credentialSplat += @{
            servicePrincipalClientId = $ServicePrincipalClientId
            servicePrincipalSecret = $ServicePrincipalSecret ? ($ServicePrincipalSecret | ConvertFrom-SecureString -AsPlainText) : $null
            tenantId = $TenantId
        }
    }

    try {
        # Paged: a connection on a later page would otherwise look absent, and the create that
        # followed would fail on a duplicate display name.
        $existingConnection = _Get-CloudConnectionList -AccessToken $AccessToken |
                                Where-Object { $_.displayName -eq $DisplayName } |
                                Select-Object -First 1

        if ($existingConnection) {
            Write-Information "Power BI shared cloud connection $DisplayName already exists"

            if ($SkipCredentialUpdates -or -not $AllowCredentialUpdate) {
                # Updating a connection is not a safe no-op when anything is BOUND to it.
                # Creating a OneLake shortcut binds it to a cloud connection; changing that
                # connection leaves the binding stale, every read then fails
                # '401 Unauthorized on ListBlob', the shortcut still reports healthy in a
                # list_shortcuts response, and delete-and-recreate does not reliably recover it.
                # Verified against a live tenant on 2026-08-20 - it cost a day of downtime.
                # The extension cannot know a shortcut exists, which is why this decision lives
                # in the connection's own configuration.
                Write-Information "Connection '$DisplayName' already exists - credential updates are disabled for it, leaving it untouched."
                return $existingConnection
            }

            $updateBody = _GenerateUpdateBody @credentialSplat -DisplayName $DisplayName
            $splat = @{ 
                "Uri" = "https://api.fabric.microsoft.com/v1/connections/$($existingConnection.id)" 
                "Method" = "PATCH"
                "Headers" = @{Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"; 'Content-type' = 'application/json'}
                "Body" = $updateBody | ConvertTo-Json -Compress -Depth 100
            }
            $response = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue
        } else {
            Write-Information "Connection does not exist"

            if ($ValidateConnectionType) {
                # Only worth doing on the create path: an existing connection was already
                # accepted by the tenant.
                _Assert-ValidConnectionType -ConnectionType $ConnectionType `
                                            -CreationMethod $CreationMethod `
                                            -CredentialType $CredentialType `
                                            -DisplayName $DisplayName `
                                            -AccessToken $AccessToken
            }

            Write-Information "Creating Power BI shared cloud connection $DisplayName"
            $generateBodySplat = $credentialSplat + @{
                displayName = $DisplayName
                connectionType = $ConnectionType
                creationMethod = $CreationMethod
                parameters = $Parameters
            }
            $createBody = _GenerateCreateBody @generateBodySplat
            $splat = @{ 
                "Uri" = "https://api.fabric.microsoft.com/v1/connections" 
                "Method" = "POST"
                "Headers" = @{Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"; 'Content-type' = 'application/json'}
                "Body" = $createBody | ConvertTo-Json -Compress -Depth 100
            }
            $response = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue
        }
    }
    catch {
        Write-ErrorLogMessage "Failed to process cloud connection '$DisplayName': $($_.Exception.Message)"
        if (-not $ContinueOnError) {
            throw "Stopping processing cloud connections due to error and ContinueOnError is false"
        }
        return $null
    }

    return $response
}