# <copyright file="powerbi.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/powerbi.properties.ps1
task deployPowerBISharedCloudConnection -After ProvisionCore {

    $token = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://api.fabric.microsoft.com'
    $graphToken = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://graph.microsoft.com'
    $cloudConnections = Resolve-CloudConnections -ConfigPath $powerBIconfig

    foreach ($connection in $cloudConnections) {

        if (($connection | Get-Member -Name servicePrincipal) -and $connection.servicePrincipal.ContainsKey("secretUrl")) {

            $secretValue = Get-AzKeyVaultSecret -Id $connection.servicePrincipal.secretUrl

            # Create or update the cloud connection
            $splat = @{
                DisplayName = $connection.displayName
                ConnectionType = $connection.type
                Parameters = $connection.target
                ServicePrincipalClientId = $connection.servicePrincipal.clientId
                ServicePrincipalSecret = $secretValue.SecretValue
                TenantId = $connection.servicePrincipal.tenantId
                AccessToken = $token.Token
            }

            $connectionResult = Assert-PBIShareableCloudConnection @splat

            # Manage permissions if specified
            if ($connection.permissions) {
                Write-Information "Managing permissions for connection: $($connection.displayName)"
                
                try {
                    $permissionResult = Assert-PBICloudConnectionPermissionGroups `
                        -CloudConnectionId $connectionResult.id `
                        -PermissionGroups $connection.permissions `
                        -AccessToken $token.Token `
                        -GraphAccessToken $graphToken.Token `
                        -StrictMode

                    if ($permissionResult.Success) {
                        Write-Information "Successfully synchronized permissions for connection: $($connection.displayName)"
                        Write-Information "  - Identities resolved: $($permissionResult.Summary.TotalIdentitiesResolved)"
                        Write-Information "  - Permissions added: $($permissionResult.Summary.PermissionsAdded)"
                        Write-Information "  - Permissions updated: $($permissionResult.Summary.PermissionsUpdated)"
                        Write-Information "  - Permissions removed: $($permissionResult.Summary.PermissionsRemoved)"
                    } else {
                        Write-Warning "Permission synchronization completed with errors for connection: $($connection.displayName)"
                        foreach ($error in $permissionResult.Errors) {
                            Write-Warning "  - $error"
                        }
                    }
                } catch {
                    Write-Error "Failed to manage permissions for connection $($connection.displayName): $($_.Exception.Message)"
                    throw
                }
            } else {
                Write-Information "No permissions specified for connection: $($connection.displayName)"
            }
        }
    }
}