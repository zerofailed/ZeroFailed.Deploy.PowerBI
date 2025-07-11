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