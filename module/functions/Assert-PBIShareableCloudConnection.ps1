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

function Assert-PBIShareableCloudConnection
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $DisplayName,

        [Parameter(Mandatory=$true)]
        [string] $ConnectionType,

        [Parameter(Mandatory=$true)]
        [hashtable[]] $Parameters,

        [Parameter(Mandatory=$true)]
        [guid] $ServicePrincipalClientId,

        [Parameter(Mandatory=$true)]
        [securestring] $ServicePrincipalSecret,

        [Parameter(Mandatory=$true)]
        [string] $TenantId,
        
        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken
    )

    $splat = @{ 
        "Uri" = "https://api.fabric.microsoft.com/v1/connections" 
        "Method" = "GET"
        "Headers" = @{Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"; 'Content-type' = 'application/json'}
    }

    $existingConnection = Invoke-RestMethodWithRateLimit -Splat $splat | Select-Object -ExpandProperty value | Where-Object {$_.displayName -eq $DisplayName}

    if ($existingConnection) {
        Write-Information "Power BI shared cloud connection $DisplayName already exists"
        $generateBodySplat = @{
            servicePrincipalClientId = $ServicePrincipalClientId
            servicePrincipalSecret = $ServicePrincipalSecret | ConvertFrom-SecureString -AsPlainText
            tenantId = $TenantId
        }
        $updateBody = _GenerateUpdateBody @generateBodySplat
        $splat = @{ 
            "Uri" = "https://api.fabric.microsoft.com/v1/connections/$($existingConnection.id)" 
            "Method" = "PATCH"
            "Headers" = @{Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"; 'Content-type' = 'application/json'}
            "Body" = $updateBody | ConvertTo-Json -Compress -Depth 100
        }
        $response = Invoke-RestMethodWithRateLimit -Splat $splat
    } else {
        Write-Information "Connection does not exist"
        Write-Information "Creating Power BI shared cloud connection $DisplayName"
        $generateBodySplat = @{
            displayName = $DisplayName
            connectionType = $ConnectionType
            parameters = $Parameters
            servicePrincipalClientId = $ServicePrincipalClientId
            servicePrincipalSecret = $ServicePrincipalSecret | ConvertFrom-SecureString -AsPlainText
            tenantId = $TenantId
        }
        $createBody = _GenerateCreateBody @generateBodySplat
        $splat = @{ 
            "Uri" = "https://api.fabric.microsoft.com/v1/connections" 
            "Method" = "POST"
            "Headers" = @{Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"; 'Content-type' = 'application/json'}
            "Body" = $createBody | ConvertTo-Json -Compress -Depth 100
        }
        $response = Invoke-RestMethodWithRateLimit -Splat $splat
    }

    return $response
}