# <copyright file="Remove-PBICloudConnectionPermission.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Remove-PBICloudConnectionPermission
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Object])]
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

            $response = Invoke-RestMethodWithRateLimit -Splat $splat -InformationAction Continue
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
                throw "Insufficient permissions to remove role assignment $RoleAssignmentId from cloud connection $CloudConnectionId"
            } else {
                throw "Failed to remove role assignment $RoleAssignmentId from cloud connection $CloudConnectionId`: [$statusCode] $errorMessage"
            }
        }
    } else {
        Write-Information "Would remove role assignment $RoleAssignmentId from cloud connection $CloudConnectionId (WhatIf mode)"
        return $null
    }
}



