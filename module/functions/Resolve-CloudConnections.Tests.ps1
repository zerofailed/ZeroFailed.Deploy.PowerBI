# Pester tests for cloud connection resolution
BeforeAll {
    . $PSScriptRoot/Resolve-CloudConnections.ps1
    $testDataDir = Join-Path $PSScriptRoot 'test-data'

    # load required internal dependencies
    . (Join-Path $PSScriptRoot 'Get-YamlContent.ps1')
    . (Join-Path $PSScriptRoot '_Resolve-ServicePrincipal.ps1')
    . (Join-Path $PSScriptRoot '_Resolve-ConnectionTarget.ps1')
}

Describe 'Get-YamlContent' {
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

Describe '_Resolve-ServicePrincipal' {
    BeforeAll {
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

Describe '_Resolve-ConnectionTarget' {
    BeforeAll {
        $connectionTargets = @{
            blobStorage = @{
                dev = @{
                    domain = 'blob.core.windows.net'
                    account = 'devstorageaccount'
                }
            }
        }
    }

    Context 'When resolving valid references' {
        It 'Should resolve existing connection target' {
            $result = _Resolve-ConnectionTarget -ConnectionTargets $connectionTargets -Reference 'blobStorage.dev'
            $result.domain | Should -Be 'blob.core.windows.net'
            $result.account | Should -Be 'devstorageaccount'
        }
    }

    Context 'When handling invalid references' {
        It 'Should throw on non-existent reference' {
            { _Resolve-ConnectionTarget -ConnectionTargets $connectionTargets -Reference 'nonexistent.env' } | Should -Throw
        }
    }
}

Describe 'Resolve-CloudConnections' {
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
            $devConnection.target.domain | Should -Be 'blob.core.windows.net'
            $devConnection.permissions.owners | Should -Contain 'jessica.hill@endjin.com'

            # Verify custom connection properties
            $customConnection = $results | Where-Object { $_.displayName -eq 'Custom Blob Storage' }
            $customConnection | Should -Not -BeNullOrEmpty
            $customConnection.servicePrincipal.clientId | Should -Be '943a5f46-86eb-4a39-b34f-cb3046dfa30d'
            $customConnection.target.account | Should -Be 'customstorage'
        }

        It "Should apply connection target property overrides specified on the cloud connection definition" {
            $sqlConnection = $results | Where-Object { $_.displayName -eq 'Development SQL Database' }
            $sqlConnection | Should -Not -BeNullOrEmpty
            $sqlConnection.type | Should -Be 'SQL'
            $sqlConnection.servicePrincipal.clientId | Should -Be '70982f14-17c2-4eb3-867d-7e68b9a902b7'
            $sqlConnection.target.server | Should -Be 'devsql.database.windows.net'
            $sqlConnection.target.database | Should -Be 'overridden'
        }
    }

    Context 'When handling configuration errors' {
        It 'Should throw on invalid config path' {
            { Resolve-CloudConnections -ConfigPath 'nonexistent/config.yaml' } | Should -Throw
        }
    }
}

Describe 'Export-CloudConnections' {
    Context 'When exporting connections' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'connections.json'
        }

        It 'Should export connections to JSON file' {
            Export-CloudConnections -ConfigPath "$testDataDir/config.yaml" -OutputPath $tempFile
            Test-Path $tempFile | Should -BeTrue
            $content = Get-Content $tempFile | ConvertFrom-Json
            $content.Count | Should -Be 6
        }

        It 'Should return connections when no output path specified' {
            $results = Export-CloudConnections -ConfigPath "$testDataDir/config.yaml"
            $results.Count | Should -Be 6
        }
    }
}