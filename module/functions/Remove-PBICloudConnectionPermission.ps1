# <copyright file="Remove-PBICloudConnectionPermission.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Removes a specific permission from a Power BI shareable cloud connection.

.DESCRIPTION
This function removes a role assignment from a Power BI shareable cloud connection using the
Fabric API. It's designed to work with the permission synchronization system to remove
unauthorized or outdated permissions.

.PARAMETER CloudConnectionId
The ID of the Power BI shareable cloud connection.

.PARAMETER RoleAssignmentId
The ID of the role assignment to remove. This is obtained from the existing permissions list.

.PARAMETER AccessToken
Secure string containing the access token for the Power BI Fabric API.

.OUTPUTS
Returns the response from the Power BI API call, or $null if the operation was successful.

.EXAMPLE
Remove-PBICloudConnectionPermission `
    -CloudConnectionId "a60de636-56cf-4775-8217-76bb5b33bbb3" `
    -RoleAssignmentId "assignment-id-here" `
    -AccessToken $token.Token
#>

function Remove-PBICloudConnectionPermission
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string] $CloudConnectionId,
        
        [Parameter(Mandatory=$true)]
        [string] $RoleAssignmentId,
        
        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken
    )

    Write-Verbose "Removing role assignment $RoleAssignmentId from cloud connection $CloudConnectionId"

    if ($PSCmdlet.ShouldProcess("Role Assignment $RoleAssignmentId", "Remove from Cloud Connection $CloudConnectionId")) {
        try {
            $splat = @{ 
                "Uri" = "https://api.fabric.microsoft.com/v1/connections/$CloudConnectionId/roleAssignments/$RoleAssignmentId"
                "Method" = "DELETE"
                "Headers" = @{
                    Authorization = "Bearer $($AccessToken | ConvertFrom-SecureString -AsPlainText)"
                    'Content-type' = 'application/json'
                }
            }

            $response = Invoke-RestMethodWithRateLimit -Splat $splat
            Write-Information "Successfully removed role assignment $RoleAssignmentId from cloud connection $CloudConnectionId"
            return $response

        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.Exception.Message
            
            # Handle specific error cases
            if ($statusCode -eq 404) {
                Write-Warning "Role assignment $RoleAssignmentId not found on cloud connection $CloudConnectionId (may already be removed)"
                return $null
            } elseif ($statusCode -eq 403) {
                Write-Error "Insufficient permissions to remove role assignment $RoleAssignmentId from cloud connection $CloudConnectionId"
                throw
            } else {
                Write-Error "Failed to remove role assignment $RoleAssignmentId from cloud connection $CloudConnectionId`: $errorMessage"
                throw
            }
        }
    } else {
        Write-Information "Would remove role assignment $RoleAssignmentId from cloud connection $CloudConnectionId (WhatIf mode)"
        return $null
    }
}



