# <copyright file="Assert-PBIShareableCloudConnection.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that the specified Power BI shareable cloud connection exists.

.DESCRIPTION
Ensures that the specified Power BI shareable cloud connection exists. If the connection already exists, the function updates it;
otherwise, it creates a new connection using the provided parameters.

.PARAMETER DisplayName
The display name of the Power BI shareable cloud connection.

.OUTPUTS
Returns the response from the Power BI API call.

.EXAMPLE
# Example usage to update an existing connection or create a new one:
$secureToken = ConvertTo-SecureString "token" -AsPlainText -Force
$secureSecret = ConvertTo-SecureString "secret" -AsPlainText -Force

$response = Assert-PBIShareableCloudConnection `
    -DisplayName "MyConnection" `
    -ConnectionType "ExampleType" `
    -Parameters @{ key = "value" } `
    -ServicePrincipalClientId "clientId" `
    -ServicePrincipalSecret $secureSecret `
    -TenantId "tenantId" `
    -AccessToken $secureToken

Write-Output $response
#>

function Assert-PBICloudConnectionPermissions
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $CloudConnectionId,
        [Parameter(Mandatory=$true)]
        [guid] $AssigneePrincipalId,
        # [Parameter(Mandatory=$true)]
        # [hashtable[]] $Parameters,
        # [Parameter(Mandatory=$true)]
        # [guid] $ServicePrincipalClientId,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Owner", "User", "UserWithReshare")]
        [string] $AssigneePrincipalRole,
        [Parameter(Mandatory=$true)]
        [ValidateSet("User", "Group", "ServicePrincipal", "ServicePrincipalProfile")]
        [string] $AssigneePrincipalType,
        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken
    )

    $splat = @{ 
        "Uri" = "https://api.fabric.microsoft.com/v1/connections/$CloudConnectionId/roleAssignments"
        "Method" = "GET"
        "Headers" = @{Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"; 'Content-type' = 'application/json'}
    }

    $existingPermissions = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue | Select-Object -ExpandProperty value | Where-Object {$_.principal.id -eq $AssigneePrincipalId}

    if ($existingPermissions) {
        Write-Information "Role assignment for $AssigneePrincipalId for the Power BI shared cloud connection $CloudConnectionId already exists"

        $updateBody = @{
            principal = @{
                id = $AssigneePrincipalId
                type = $AssigneePrincipalType
            }
            role = $AssigneePrincipalRole
        }

        if($existingPermissions.role -eq $AssigneePrincipalRole) {
            Write-Information "Role assignment for $AssigneePrincipalId for the Power BI shared cloud connection $CloudConnectionId already has the role $AssigneePrincipalRole"
        }
        else {
            Write-Information "Updating role assignment for $AssigneePrincipalId for the Power BI shared cloud connection $CloudConnectionId"
            $splat = @{ 
                "Uri" = "https://api.fabric.microsoft.com/v1/connections/$CloudConnectionId/roleAssignments/$($existingPermissions.id)"
                "Method" = "PATCH"
                "Headers" = @{Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"; 'Content-type' = 'application/json'}
                "Body" = $updateBody | ConvertTo-Json -Compress -Depth 100
            }

            $response = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue
        }
    } else {
        Write-Information "Role assignment for $AssigneePrincipalId for the Power BI shared cloud connection $CloudConnectionId does not exist"
        Write-Information "Adding role assignment for $AssigneePrincipalId for the Power BI shared cloud connection $CloudConnectionId"

        $createBody = @{
            principal = @{
                id = $AssigneePrincipalId
                type = $AssigneePrincipalType
            }
            role = $AssigneePrincipalRole
        }
        
        $splat = @{ 
            "Uri" = "https://api.fabric.microsoft.com/v1/connections/$CloudConnectionId/roleAssignments" 
            "Method" = "POST"
            "Headers" = @{Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"; 'Content-type' = 'application/json'}
            "Body" = $createBody | ConvertTo-Json -Compress -Depth 100
        }
        $response = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue
    }

    return $response
}
