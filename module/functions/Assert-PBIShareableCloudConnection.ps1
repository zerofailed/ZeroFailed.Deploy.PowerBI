# <copyright file="Assert-PBIShareableCloudConnection.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Assert-PBIShareableCloudConnection
{
    [CmdletBinding()]
    [OutputType([System.Object])]
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
        [securestring] $AccessToken,

        [Parameter()]
        [switch] $ContinueOnError
    )

    $splat = @{ 
        "Uri" = "https://api.fabric.microsoft.com/v1/connections" 
        "Method" = "GET"
        "Headers" = @{Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"; 'Content-type' = 'application/json'}
    }

    try {
        $existingConnection = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue | Select-Object -ExpandProperty value | Where-Object {$_.displayName -eq $DisplayName}

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
            $response = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue
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
            $response = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue
        }
    }
    catch {
        Write-ErrorLogMessage "Failed to process cloud connection '$DisplayName': $($_.Exception.Message)"
        if (-not $ContinueOnError) {
            throw "Stopping processing cloud connections due to error and ContinueOnError is false"
        }
        return $null
    }

    return $response
}