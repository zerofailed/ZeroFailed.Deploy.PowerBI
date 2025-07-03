# <copyright file="powerbi.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/powerbi.properties.ps1
task deployPowerBISharedCloudConnection -After ProvisionCore {

    $token = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://api.fabric.microsoft.com'
    $cloudConnections = Resolve-CloudConnections -ConfigPath $powerBIconfig

    foreach ($connection in $cloudConnections) { 

        if (($connection | Get-Member -Name servicePrincipal) -and $connection.servicePrincipal.ContainsKey("secretUrl")) {

            $secretValue = Get-AzKeyVaultSecret -Id $connection.servicePrincipal.secretUrl

            $splat = @{
                DisplayName = $connection.displayName 
                ConnectionType = $connection.type
                Parameters = $connection.target 
                ServicePrincipalClientId = $connection.servicePrincipal.clientId 
                ServicePrincipalSecret = $secretValue.SecretValue
                TenantId = $connection.servicePrincipal.tenantId 
                AccessToken = $token.Token
            }

            Assert-PBIShareableCloudConnection @splat
        }
    }
}