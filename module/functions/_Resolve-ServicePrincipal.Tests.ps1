# <copyright file="_Resolve-ServicePrincipal.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe '_Resolve-ServicePrincipal' {
    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/_Resolve-ServicePrincipal.ps1

        $servicePrincipals = @{
            development = @{
                clientId = '70982f14-17c2-4eb3-867d-7e68b9a902b7'
                secretUrl = 'https://endjintest.vault.azure.net/secrets/dev-connection-secret/'
                tenantId = '1c89d1da-a483-414f-ac8c-ccaf199db0a7'
            }
        }
    }

    Context 'When resolving valid references' {
        It 'Should resolve existing service principal' {
            $result = _Resolve-ServicePrincipal -ServicePrincipals $servicePrincipals -Reference 'development'
            $result.clientId | Should -Be '70982f14-17c2-4eb3-867d-7e68b9a902b7'
        }
    }

    Context 'When handling invalid references' {
        It 'Should throw on non-existent reference' {
            { _Resolve-ServicePrincipal -ServicePrincipals $servicePrincipals -Reference 'nonexistent' } | Should -Throw
        }
    }
}