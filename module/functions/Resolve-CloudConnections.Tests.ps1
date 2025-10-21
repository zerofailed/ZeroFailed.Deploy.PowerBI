# <copyright file="Resolve-CloudConnections.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe 'Resolve-CloudConnections' {
    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/Resolve-CloudConnections.ps1
        $testDataDir = Join-Path $PSScriptRoot 'test-data'
    
        # load required internal dependencies
        . (Join-Path $PSScriptRoot 'Get-YamlContent.ps1')
        . (Join-Path $PSScriptRoot '_Resolve-ServicePrincipal.ps1')
        . (Join-Path $PSScriptRoot '_Resolve-ConnectionTarget.ps1')

        # Make external functions available for mocking
        function Write-ErrorLogMessage { param($Message) }
        function Invoke-RestMethodWithRateLimit {}

        Mock Write-Information {}
        Mock Write-ErrorLogMessage {}
        Mock Invoke-RestMethodWithRateLimit {}
    }

    Context 'When processing all configuration files' {
        BeforeAll {
            $results = Resolve-CloudConnections -ConfigPath "$testDataDir/config.yaml"
        }

        It 'Should return denormalized connections' {
            # Verify number of connections
            $results.Count | Should -Be 6

            # Verify development connection properties
            $devConnection = $results | Where-Object { $_.displayName -eq 'Development Blob Storage' }
            $devConnection | Should -Not -BeNullOrEmpty
            $devConnection.type | Should -Be 'AzureBlobs'
            $devConnection.servicePrincipal.clientId | Should -Be '70982f14-17c2-4eb3-867d-7e68b9a902b7'
            $devConnection.target | Where-Object { $_.name -eq 'domain' } | Select-Object -ExpandProperty value | Should -Be 'blob.core.windows.net'
            $devConnection.permissions.owners | Should -Contain 'jessica.hill@endjin.com'

            # Verify custom connection properties
            $customConnection = $results | Where-Object { $_.displayName -eq 'Custom Blob Storage' }
            $customConnection | Should -Not -BeNullOrEmpty
            $customConnection.servicePrincipal.clientId | Should -Be '943a5f46-86eb-4a39-b34f-cb3046dfa30d'
            $customConnection.target | Where-Object { $_.name -eq 'account' } | Select-Object -ExpandProperty value | Should -Be 'customstorage'
        }

        It "Should apply connection target property overrides specified on the cloud connection definition" {
            $sqlConnection = $results | Where-Object { $_.displayName -eq 'Development SQL Database' }
            $sqlConnection | Should -Not -BeNullOrEmpty
            $sqlConnection.type | Should -Be 'SQL'
            $sqlConnection.servicePrincipal.clientId | Should -Be '70982f14-17c2-4eb3-867d-7e68b9a902b7'
            $sqlConnection.servicePrincipal.tenantId | Should -Be '00000000-0000-0000-0000-000000000001'
            $sqlConnection.target | Where-Object { $_.name -eq 'server' } | Select-Object -ExpandProperty value | Should -Be 'devsql.database.windows.net'
            $sqlConnection.target | Where-Object { $_.name -eq 'database' } | Select-Object -ExpandProperty value | Should -Be 'overridden'
        }

        It "Should apply the default tenant ID when a service principal does not define its own" {
            $sqlConnection = $results | Where-Object { $_.displayName -eq 'Test SQL Database' }
            $sqlConnection | Should -Not -BeNullOrEmpty
            $sqlConnection.type | Should -Be 'SQL'
            $sqlConnection.servicePrincipal.tenantId | Should -Be '00000000-0000-0000-0000-000000000000'
        }
    }

    Context 'When given a partial configuration path' {
        It 'Should try using a default-named configuration file' {
            $results = Resolve-CloudConnections -ConfigPath $testDataDir
            $results.Count | Should -Be 6
        }
    }

    Context 'When handling configuration errors' {
        It 'Should throw on invalid config path' {
            Mock Write-Error {}
            { Resolve-CloudConnections -ConfigPath 'nonexistent/config.yaml' } | Should -Throw
            Should -Invoke Write-ErrorLogMessage -Exactly 1 -ParameterFilter { $Message -eq 'Error whilst processing cloud connection configuration files' }
        }
    }

    Context 'When filtering connections' {
        It 'Should correctly filter for a single pattern' {
            $connections = Resolve-CloudConnections -ConfigPath "$testDataDir/config.yaml" -ConnectionFilter "Development*"
            $connections.Count | Should -Be 2
            $connections[0].displayName | Should -Be "Development Blob Storage"
            $connections[1].displayName | Should -Be "Development SQL Database"
        }

        It 'Should correctly filter for multiple patterns' {
            $connections = Resolve-CloudConnections -ConfigPath "$testDataDir/config.yaml" -ConnectionFilter @("Test*", "Custom*")
            $connections.Count | Should -Be 3
            ($connections.displayName -contains "Test Blob Storage") | Should -Be $true
            ($connections.displayName -contains "Test SQL Database") | Should -Be $true
            ($connections.displayName -contains "Custom Blob Storage") | Should -Be $true
        }

        It 'Should process all connections when no filter is provided' {
            $connections = Resolve-CloudConnections -ConfigPath "$testDataDir/config.yaml"
            $connections.Count | Should -Be 6
        }

        It 'Should log a warning when no connections match the filter' {
            Mock Write-Warning {}
            Resolve-CloudConnections -ConfigPath "$testDataDir/config.yaml" -ConnectionFilter "NON_EXISTENT_*"
            Should -Invoke Write-Warning -ParameterFilter { $Message -eq 'No connections matched the provided filter(s): NON_EXISTENT_*' }
        }
    }
}