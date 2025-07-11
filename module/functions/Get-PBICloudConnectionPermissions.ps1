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
        $response = Invoke-RestMethod @splat
        return $response.value
    } catch {
        Write-Error "Failed to retrieve permissions for cloud connection $CloudConnectionId`: $($_.Exception.Message)"
        throw
    }
}