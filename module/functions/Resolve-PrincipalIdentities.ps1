# <copyright file="Resolve-PrincipalIdentities.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

using namespace System.Collections.Generic

function Resolve-PrincipalIdentities
{
    [CmdletBinding()]
    [OutputType([array])]
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

    $resolvedIdentities = [List[object]]::new()
    $emailsToResolve = @()

    foreach ($identity in $Identities) {
        if ($identity -is [string]) {
            # Handle email address string
            if ($UseCache -and $script:PrincipalIdentityCache.ContainsKey($identity)) {
                Write-Verbose "Using cached identity for: $identity"
                $resolvedIdentities.Add($script:PrincipalIdentityCache[$identity])
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
                $resolvedIdentities.Add($resolvedIdentity)
                
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
            $resolvedIdentities.Add($resolvedIdentity)
            
            # Cache the resolution
            if ($UseCache) {
                $script:PrincipalIdentityCache[$resolution.emailAddress] = $resolvedIdentity
            }
        }
    }

    # Ensure PowerShell doesn't unroll an empty or single item array
    return ,$resolvedIdentities
}
