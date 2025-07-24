# <copyright file="powerbi.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/powerbi.properties.ps1

task deployPowerBISharedCloudConnection -After ProvisionCore {

    $token = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://api.fabric.microsoft.com'
    $graphToken = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://graph.microsoft.com'
    $cloudConnections = Resolve-CloudConnections -ConfigPath $powerBIconfig -ConnectionFilter $CloudConnectionFilter

    foreach ($connection in $cloudConnections) {

        if (($connection | Get-Member -Name servicePrincipal) -and $connection.servicePrincipal.ContainsKey("secretUrl")) {

            Write-Build Green "`nProcessing shared cloud connection: $($connection.displayName)"

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

            Write-Build White "Configuring cloud connection..."
            $connectionResult = Assert-PBIShareableCloudConnection @splat
            Write-Build Green "✅ Cloud connection configured [Id=$($connectionResult.Id)]"

            # Manage permissions if specified
            if ($connection.permissions) {
                Write-Build White "Processing permissions..."
                
                try {
                    $permissionResult = Assert-PBICloudConnectionPermissionGroups `
                        -CloudConnectionId $connectionResult.id `
                        -PermissionGroups $connection.permissions `
                        -AccessToken $token.Token `
                        -GraphAccessToken $graphToken.Token `
                        -StrictMode `
                        -DryRun:$PowerBiDryRunMode `
                        -ContinueOnError:$PowerBiContinueOnError


                    if ($permissionResult.Success) {
                        Write-Build Green "✅ Cloud connection permissions synchronized"
                        Write-Build White "  - Identities resolved: $($permissionResult.Summary.TotalIdentitiesResolved)"
                        Write-Build White "  - Permissions added: $($permissionResult.Summary.PermissionsAdded)"
                        Write-Build White "  - Permissions updated: $($permissionResult.Summary.PermissionsUpdated)"
                        Write-Build White "  - Permissions removed: $($permissionResult.Summary.PermissionsRemoved)"
                    } else {
                        Write-Warning "Permission synchronization completed with errors for connection: $($connection.displayName)"
                        foreach ($permissionError in $permissionResult.Errors) {
                            Write-Warning "  - $permissionError"
                        }
                    }
                } catch {
                    throw "Failed to manage permissions for connection $($connection.displayName): $($_.Exception.Message)"     
                }
            } else {
                Write-Build White "No permissions specified for connection: $($connection.displayName)"
            }
        }
    }
}