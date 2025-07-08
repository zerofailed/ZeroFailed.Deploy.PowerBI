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
        [switch] $UseCache = $true
    )

    # Initialize cache if not exists
    if ($UseCache -and -not $script:PrincipalIdentityCache) {
        $script:PrincipalIdentityCache = @{}
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
        $emailResolutions = Resolve-EmailAddressesToPrincipals -EmailAddresses $emailsToResolve -GraphAccessToken $GraphAccessToken
        
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

<#
.SYNOPSIS
Resolves email addresses to principal IDs and types using Microsoft Graph API.

.DESCRIPTION
Internal function that handles the actual Microsoft Graph API calls to resolve email addresses
to principal IDs and determine their types (User, Group, ServicePrincipal, etc.).

.PARAMETER EmailAddresses
Array of email addresses to resolve.

.PARAMETER GraphAccessToken
Secure string containing the Microsoft Graph API access token.

.OUTPUTS
Returns an array of objects with emailAddress, principalId, and principalType properties.
#>

function Resolve-EmailAddressesToPrincipals
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string[]] $EmailAddresses,
        
        [Parameter(Mandatory=$true)]
        [securestring] $GraphAccessToken
    )

    $resolvedPrincipals = @()
    $graphToken = $GraphAccessToken | ConvertFrom-SecureString -AsPlainText

    foreach ($email in $EmailAddresses) {
        try {
            Write-Verbose "Resolving email address: $email"
            
            # Try to resolve as user first
            $userUri = "https://graph.microsoft.com/v1.0/users/$email"
            $headers = @{ 
                Authorization = "Bearer $graphToken"
                'Content-Type' = 'application/json'
            }

            try {
                $user = Invoke-RestMethod -Uri $userUri -Headers $headers -Method GET
                $resolvedPrincipals += @{
                    emailAddress = $email
                    principalId = $user.id
                    principalType = "User"
                }
                Write-Verbose "Resolved $email as User with ID: $($user.id)"
                continue
            } catch {
                Write-Verbose "Not found as user, trying group resolution for: $email"
            }

            # Try to resolve as group
            $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=mail eq '$email' or proxyAddresses/any(x:x eq 'SMTP:$email')"
            
            try {
                $groupResponse = Invoke-RestMethod -Uri $groupUri -Headers $headers -Method GET
                if ($groupResponse.value -and $groupResponse.value.Count -gt 0) {
                    $group = $groupResponse.value[0]
                    $resolvedPrincipals += @{
                        emailAddress = $email
                        principalId = $group.id
                        principalType = "Group"
                    }
                    Write-Verbose "Resolved $email as Group with ID: $($group.id)"
                    continue
                }
            } catch {
                Write-Verbose "Not found as group for: $email"
            }

            # Try to resolve as service principal
            $spUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=servicePrincipalNames/any(x:x eq '$email')"
            
            try {
                $spResponse = Invoke-RestMethod -Uri $spUri -Headers $headers -Method GET
                if ($spResponse.value -and $spResponse.value.Count -gt 0) {
                    $sp = $spResponse.value[0]
                    $resolvedPrincipals += @{
                        emailAddress = $email
                        principalId = $sp.id
                        principalType = "ServicePrincipal"
                    }
                    Write-Verbose "Resolved $email as ServicePrincipal with ID: $($sp.id)"
                    continue
                }
            } catch {
                Write-Verbose "Not found as service principal for: $email"
            }

            # If we get here, the email couldn't be resolved
            Write-Warning "Could not resolve email address: $email"
            
        } catch {
            Write-Error "Error resolving email address $email`: $_"
        }
    }

    return $resolvedPrincipals
}

<#
.SYNOPSIS
Clears the principal identity resolution cache.

.DESCRIPTION
Utility function to clear the cached principal identity resolutions. Useful for testing
or when you need to force fresh resolution of identities.
#>

function Clear-PrincipalIdentityCache
{
    [CmdletBinding()]
    param()
    
    if ($script:PrincipalIdentityCache) {
        $script:PrincipalIdentityCache.Clear()
        Write-Verbose "Principal identity cache cleared"
    }
}