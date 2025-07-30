# <copyright file="Resolve-PrincipalIdentities.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Resolves a collection of identities (email addresses or structured objects) to principal IDs and types.

.DESCRIPTION
This function takes a mixed array of identities - either email address strings or structured objects 
with principalId and principalType properties - and resolves them to a consistent format with 
principal IDs and types. Email addresses are resolved using Microsoft Graph API.

.PARAMETER Identities
Array of identities to resolve. Can contain:
- Email address strings (e.g., "user@domain.com")
- Structured objects with principalId and principalType properties

.PARAMETER GraphAccessToken
Secure string containing the Microsoft Graph API access token for resolving email addresses.

.PARAMETER UseCache
Switch to enable caching of resolved identities for performance optimization.

.OUTPUTS
Returns an array of objects with resolved principalId, principalType, and originalIdentity properties.

.EXAMPLE
$identities = @(
    "user@domain.com",
    @{ principalId = "f3498fd9-cff0-44a9-991c-c017f481adf0"; principalType = "ServicePrincipal" }
)
$resolved = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $graphToken
#>

function Resolve-PrincipalIdentities
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [object[]] $Identities,
        
        [Parameter(Mandatory=$true)]
        [securestring] $GraphAccessToken,
        
        [Parameter()]
        [switch] $UseCache
    )

    # Initialize cache if not exists
    if ($UseCache -and (!(Test-Path variable:/PrincipalIdentityCache) -or $PrincipalIdentityCache -isnot [hashtable])) {
        $script:PrincipalIdentityCache = @{}
        Write-Verbose "Resolve-PrincipalIdentities: Principal identity cache initialised"
    }

    $resolvedIdentities = @()
    $emailsToResolve = @()

    foreach ($identity in $Identities) {
        if ($identity -is [string]) {
            # Handle email address string
            if ($UseCache -and $script:PrincipalIdentityCache.ContainsKey($identity)) {
                Write-Verbose "Using cached identity for: $identity"
                $resolvedIdentities += $script:PrincipalIdentityCache[$identity]
            } else {
                $emailsToResolve += $identity
            }
        } elseif ($identity -is [hashtable] -or $identity -is [PSCustomObject]) {
            # Handle structured object with explicit principalId and principalType
            if ($identity.principalId -and $identity.principalType) {
                $resolvedIdentity = @{
                    principalId = $identity.principalId
                    principalType = $identity.principalType
                    originalIdentity = $identity
                }
                $resolvedIdentities += $resolvedIdentity
                
                # Cache structured identities too
                if ($UseCache) {
                    $cacheKey = "$($identity.principalId):$($identity.principalType)"
                    $script:PrincipalIdentityCache[$cacheKey] = $resolvedIdentity
                }
            } else {
                Write-Warning "Structured identity missing required principalId or principalType: $($identity | ConvertTo-Json -Compress)"
            }
        } else {
            Write-Warning "Unsupported identity format: $($identity.GetType().Name)"
        }
    }

    # Resolve email addresses in batch if any exist
    if ($emailsToResolve.Count -gt 0) {
        Write-Verbose "Resolving $($emailsToResolve.Count) email addresses via Microsoft Graph"
        $emailResolutions = _Resolve-IdentityNamesToPrincipals -EmailAddresses $emailsToResolve -GraphAccessToken $GraphAccessToken
        
        foreach ($resolution in $emailResolutions) {
            $resolvedIdentity = @{
                principalId = $resolution.principalId
                principalType = $resolution.principalType
                originalIdentity = $resolution.emailAddress
            }
            $resolvedIdentities += $resolvedIdentity
            
            # Cache the resolution
            if ($UseCache) {
                $script:PrincipalIdentityCache[$resolution.emailAddress] = $resolvedIdentity
            }
        }
    }

    return $resolvedIdentities
}

