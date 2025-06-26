# <copyright file="powerbi.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

task deployPowerBISharedCloudConnection -After ProvisionCore {

    $token = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://api.fabric.microsoft.com'

    foreach ($connection in $cloudConnection) {    

        $splat = @{
            DisplayName = $connection.displayName | Resolve-Value
            ConnectionType = $connection.connectionType
            Parameters = $connection.parameters | Resolve-Value
            ServicePrincipalClientId = $connection.servicePrincipalClientId | Resolve-Value
            ServicePrincipalSecret = $connection.servicePrincipalSecret | Resolve-Value
            TenantId = $connection.tenantId | Resolve-Value
            AccessToken = $token.Token
        }

        Assert-PBIShareableCloudConnection @splat
    }
}