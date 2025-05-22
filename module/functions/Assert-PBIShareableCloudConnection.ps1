# <copyright file="Assert-PBIShareableCloudConnection.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that the specified Power BI shareable cloud connection exists.

.DESCRIPTION
Ensures that the specified Power BI shareable cloud connection exists.

.PARAMETER DisplayName
The display name of the Power BI shareable cloud connection.

.OUTPUTS

#>

function Assert-PBIShareableCloudConnection
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $DisplayName,
        [string] $ConnectionType,
        [hashtable[]] $Parameters,
        [string] $ServicePrincipalClientId,
        [securestring] $ServicePrincipalSecret,
        [string] $TenantId,
        [securestring] $AccessToken
    )

    function _GenerateCreateBody {

        param (
            $DisplayName,
            $ConnectionType,
            $Parameters,
            $ServicePrincipalClientId,
            $ServicePrincipalSecret,
            $TenantId
        )
    
        $createBody = @{
            connectivityType = "ShareableCloud"
            displayName = $DisplayName
            connectionDetails = @{
                type = $ConnectionType
                creationMethod = $ConnectionType
                parameters = $Parameters
            }
            privacyLevel = "Organizational"
            credentialDetails = @{
              singleSignOnType = "None"
              connectionEncryption = "NotEncrypted"
              skipTestConnection = $false
              credentials = @{
                credentialType = "ServicePrincipal"
                servicePrincipalClientId = $ServicePrincipalClientId
                servicePrincipalSecret = $ServicePrincipalSecret
                tenantId = $TenantId
              }
            }
        }
        
        return $createBody
    }
    
    function _GenerateUpdateBody {
    
        param(
            $ServicePrincipalClientId,
            $ServicePrincipalSecret,
            $TenantId
        )
    
        $updateBody = @{
            connectivityType = "ShareableCloud"
            credentialDetails = @{
              credentials = @{
                credentialType = "ServicePrincipal"
                servicePrincipalClientId = $ServicePrincipalClientId
                servicePrincipalSecret = $ServicePrincipalSecret
                tenantId = $TenantId
              }
            }
        }
    
        return $updateBody
    }

    $splat = @{ 
        "Uri" = "https://api.fabric.microsoft.com/v1/connections" 
        "Method" = "GET"
        "Headers" = @{Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"; 'Content-type' = 'application/json'}
    }

    $existingConnection = Invoke-RestMethod @splat | Select-Object -ExpandProperty value | Where-Object {$_.displayName -eq $DisplayName}

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
        $response = Invoke-RestMethod @splat
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
        $response = Invoke-RestMethod @splat
    }

    return $response
}