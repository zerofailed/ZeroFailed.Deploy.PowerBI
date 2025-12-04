# <copyright file="Get-PBICloudConnectionPermissions.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Get-PBICloudConnectionPermissions
{
    [CmdletBinding()]
    [OutputType([System.String])]
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