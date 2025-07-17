# <copyright file="Get-YamlContent.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe 'Get-YamlContent' {
    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/Get-YamlContent.ps1

        $testDataDir = Join-Path $PSScriptRoot 'test-data'
    }

    Context 'When loading valid YAML files' {
        It 'Should load service principals configuration' {
            $result = Get-YamlContent -Path "$testDataDir/servicePrincipals.yaml"
            $result.servicePrincipals | Should -Not -BeNullOrEmpty
            $result.servicePrincipals.development.clientId | Should -Be '70982f14-17c2-4eb3-867d-7e68b9a902b7'
        }

        It 'Should load connection targets configuration' {
            $result = Get-YamlContent -Path "$testDataDir/connectionTargets.yaml"
            $result.connectionTargets | Should -Not -BeNullOrEmpty
            $result.connectionTargets.blobStorage.dev.domain | Should -Be 'blob.core.windows.net'
        }

        It 'Should load main configuration' {
            $result = Get-YamlContent -Path "$testDataDir/config.yaml"
            $result.configurationFiles | Should -Not -BeNullOrEmpty
            $result.settings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When handling invalid files' {
        It 'Should throw when file does not exist' {
            { Get-YamlContent -Path 'nonexistent.yaml' } | Should -Throw
        }
    }
}