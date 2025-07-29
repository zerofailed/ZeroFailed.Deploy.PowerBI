# <copyright file="powerbi.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/powerbi.properties.ps1

# Synopsis: Ensures that the required module for YAML parsing is installed as part of the 'setupModules' task provided by the ZeroFailed.DevOps.Common extension
task ensurePowerShellYamlModule -Before setupModules {

    if (!$RequiredPowerShellModules.ContainsKey('powershell-yaml')) {
        $script:RequiredPowerShellModules += @{
            'powershell-yaml' = @{
                version = '[0.4.7,1.0)'
                repository = 'PSGallery'
            }
        }
    }
}

# Synopsis: Configures PowerBI/Fabric shared cloud connections and manages their permissions
task deployPowerBISharedCloudConnection -After DeployCore {

    Write-Build White "Requesting required API access tokens..."
    $token = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://api.fabric.microsoft.com'
    $graphToken = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://graph.microsoft.com'

    Write-Build White "Reading configuration files..."
    $cloudConnections = Resolve-CloudConnections `
                                -ConfigPath $PowerBiConfig `
                                -ConnectionsConfigPath $CloudConnectionsConfigPath `
                                -ConnectionFilter $CloudConnectionFilters

    foreach ($connection in $cloudConnections) {

        if (($connection | Get-Member -Name servicePrincipal) -and $connection.servicePrincipal.ContainsKey("secretUrl")) {

            Write-Build Green "`nProcessing shared cloud connection: $($connection.displayName)"

            # Lookup the KV secret based on the available version of the module
            if ((Get-Module Az.KeyVault | Select-Object -ExpandProperty Version) -ge [Version]'7.3.0') {
                $secretValue = Get-AzKeyVaultSecret -SecretId $connection.servicePrincipal.secretUrl
            }
            else {
                Write-Build White 'Parsing Secret URI for older version of Az.KeyVault module...'
                $secretUri = [uri]$connection.servicePrincipal.secretUrl
                $splat = @{
                    vaultName = $secretUri.Host.Split('.') | Select-Object -First 1
                    secretName = $secretUri.Segments[2].TrimEnd('/')
                }
                if ($secretUri.Segments.Count -gt 3) {
                    $splat += @{
                        secretVersion = $secretUri.Segments[3].TrimEnd('/')
                    }
                }
                Write-Build White "Args: $($splat | ConvertTo-Json -compress)"
                $secretValue = Get-AzKeyVaultSecret @splat
            }

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