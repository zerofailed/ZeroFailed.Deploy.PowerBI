# <copyright file="Get-PBICloudConnectionPermissions.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Retrieves the current permissions for a specified Power BI shareable cloud connection.

.DESCRIPTION
This function makes a GET request to the Power BI Fabric API to fetch all role assignments
(permissions) associated with a given cloud connection ID. It is typically used as part of
a synchronization process to understand the current state of permissions.

.PARAMETER CloudConnectionId
The ID of the Power BI shareable cloud connection.

.PARAMETER AccessToken
Secure string containing the access token for the Power BI Fabric API.

.OUTPUTS
Returns an array of permission objects, each containing details like 'id', 'principal' (with 'id' and 'type'), and 'role'.

.EXAMPLE
$permissions = Get-PBICloudConnectionPermissions `
    -CloudConnectionId "a60de636-56cf-4775-8217-76bb5b33bbb3" `
    -AccessToken $fabricToken.Token
#>

function Get-PBICloudConnectionPermissions
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $CloudConnectionId,
        
        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken
    )

    $splat = @{ 
        "Uri" = "https://api.fabric.microsoft.com/v1/connections/$CloudConnectionId/roleAssignments"
        "Method" = "GET"
        "Headers" = @{
            Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"
            'Content-type' = 'application/json'
        }
    }

    try {
        $response = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue
        return $response.value
    } catch {
        throw "Failed to retrieve permissions for cloud connection $CloudConnectionId`: $($_.Exception.Message)"
    }
}