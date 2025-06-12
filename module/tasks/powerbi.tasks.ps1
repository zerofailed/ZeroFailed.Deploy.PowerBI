# <copyright file="powerbi.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

task deployPowerBISharedCloudConnection {

    $token = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://api.fabric.microsoft.com'

    foreach ($connection in $cloudConnection) {    

        $splat = @{
            DisplayName = $connection.displayName
            ConnectionType = $connection.connectionType
            Parameters = $connection.parameters
            ServicePrincipalClientId = $connection.servicePrincipalClientId
            ServicePrincipalSecret = $connection.servicePrincipalSecret
            TenantId = $connection.tenantId
            AccessToken = $token.Token
        }

        Assert-PBIShareableCloudConnection @splat
    }
}