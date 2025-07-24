# <copyright file="_Resolve-EmailAddressesToPrincipals.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Resolves a list of email addresses to their corresponding Microsoft Graph principal IDs and types.

.DESCRIPTION
This function queries the Microsoft Graph API to find the principal (User, Group, or ServicePrincipal)
associated with each provided email address. It attempts to resolve in a specific order (User, then Group, then ServicePrincipal).
This is a helper function for identity resolution within the Power BI deployment process.

.PARAMETER EmailAddresses
An array of email address strings to resolve.

.PARAMETER GraphAccessToken
Secure string containing the access token for the Microsoft Graph API.

.OUTPUTS
Returns an array of hashtables, each containing 'emailAddress', 'principalId', and 'principalType' for resolved identities.

.EXAMPLE
$resolved = _Resolve-EmailAddressesToPrincipals `
    -EmailAddresses @("user1@company.com", "group@company.com") `
    -GraphAccessToken $graphToken.Token
#>

function _Resolve-EmailAddressesToPrincipals
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
                # Only continue the search if we got a NotFound response
                if ( $_.Exception.Response.StatusCode -ne 404) {
                    throw $_
                }
                Write-Verbose "Not found as user, trying group resolution for: $email"
            }

            # Try to resolve as group
            $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$email'"
            
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
                # Only continue the search if we got a NotFound response
                if ( $_.Exception.Response.StatusCode -ne 404) {
                    throw $_
                }
                Write-Verbose "Not found as group for: $email"
            }

            # Try to resolve as service principal
            $spUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=displayName eq '$email'"
            
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
                # Only continue the search if we got a NotFound response
                if ( $_.Exception.Response.StatusCode -ne 404) {
                    throw $_
                }
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