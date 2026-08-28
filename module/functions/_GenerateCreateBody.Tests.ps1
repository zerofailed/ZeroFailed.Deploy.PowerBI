# <copyright file="_GenerateCreateBody.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "_GenerateCreateBody" {

    BeforeAll {
        . $PSScriptRoot/_GenerateCreateBody.ps1
    }

    Context "When no creation method is specified" {
        It "should default the creation method to the connection type" {
            $body = _GenerateCreateBody -DisplayName "MyConnection" `
                -ConnectionType "SQL" `
                -Parameters @{} `
                -ServicePrincipalClientId "clientId" `
                -ServicePrincipalSecret "secret" `
                -TenantId "tenantId"

            $body.connectionDetails.type | Should -Be "SQL"
            $body.connectionDetails.creationMethod | Should -Be "SQL"
        }
    }

    Context "When a creation method is specified" {
        It "should use the specified creation method instead of the connection type" {
            $body = _GenerateCreateBody -DisplayName "MyConnection" `
                -ConnectionType "CommonDataService" `
                -CreationMethod "CommonDataService.Database" `
                -Parameters @{} `
                -ServicePrincipalClientId "clientId" `
                -ServicePrincipalSecret "secret" `
                -TenantId "tenantId"

            $body.connectionDetails.type | Should -Be "CommonDataService"
            $body.connectionDetails.creationMethod | Should -Be "CommonDataService.Database"
        }
    }
}
