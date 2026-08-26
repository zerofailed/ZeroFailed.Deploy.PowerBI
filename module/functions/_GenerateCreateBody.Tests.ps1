# <copyright file="_GenerateCreateBody.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe '_GenerateCreateBody' {

    BeforeAll {
        # Dot source the function file
        . $PSScriptRoot/_GenerateCreateBody.ps1

        # Hashtable enumeration order is not guaranteed, so a raw ConvertTo-Json comparison of
        # two independently-built bodies is flaky. Sorting keys at every level makes the
        # serialised form canonical, which is what lets the CR-N1 guard below be a genuine
        # byte-for-byte comparison rather than a field-by-field spot check.
        function ConvertTo-CanonicalJson {
            param($InputObject)

            function Convert-Node($node) {
                if ($node -is [System.Collections.IDictionary]) {
                    $ordered = [ordered]@{}
                    foreach ($key in ($node.Keys | Sort-Object)) {
                        $ordered[$key] = Convert-Node $node[$key]
                    }
                    return $ordered
                }
                if ($node -is [array]) {
                    return @($node | ForEach-Object { Convert-Node $_ })
                }
                return $node
            }

            Convert-Node $InputObject | ConvertTo-Json -Compress -Depth 100
        }

        # The arguments an existing AzureBlobs configuration supplies. Nothing here mentions a
        # creation method, because no configuration written before this change could.
        $script:baselineArgs = @{
            DisplayName              = 'Development Blob Storage'
            ConnectionType           = 'AzureBlobs'
            Parameters               = @(
                @{ dataType = 'Text'; name = 'account'; value = 'devstorage' }
                @{ dataType = 'Text'; name = 'domain';  value = 'blob.core.windows.net' }
            )
            ServicePrincipalClientId = '70982f14-17c2-4eb3-867d-7e68b9a902b7'
            ServicePrincipalSecret   = 'secret'
            TenantId                 = '00000000-0000-0000-0000-000000000001'
        }
    }

    Context 'When no creation method is supplied' {

        It 'Should default the creation method to the connection type' {
            $body = _GenerateCreateBody @baselineArgs

            $body.connectionDetails.type | Should -Be 'AzureBlobs'
            $body.connectionDetails.creationMethod | Should -Be 'AzureBlobs'
        }

        It 'Should treat an empty creation method the same as an omitted one' {
            $body = _GenerateCreateBody @baselineArgs -CreationMethod ''

            $body.connectionDetails.creationMethod | Should -Be 'AzureBlobs'
        }

        It 'Should produce a request body identical to the one generated before creationMethod existed' {
            # The CR-N1 regression guard. This is the acceptance bar for the whole change set:
            # every existing AzureBlobs and SQL configuration must deploy unchanged.
            $expected = @{
                connectivityType  = 'ShareableCloud'
                displayName       = 'Development Blob Storage'
                connectionDetails = @{
                    type           = 'AzureBlobs'
                    creationMethod = 'AzureBlobs'
                    parameters     = @(
                        @{ dataType = 'Text'; name = 'account'; value = 'devstorage' }
                        @{ dataType = 'Text'; name = 'domain';  value = 'blob.core.windows.net' }
                    )
                }
                privacyLevel      = 'Organizational'
                credentialDetails = @{
                    singleSignOnType     = 'None'
                    connectionEncryption = 'NotEncrypted'
                    skipTestConnection   = $false
                    credentials          = @{
                        credentialType           = 'ServicePrincipal'
                        servicePrincipalClientId = '70982f14-17c2-4eb3-867d-7e68b9a902b7'
                        servicePrincipalSecret   = 'secret'
                        tenantId                 = '00000000-0000-0000-0000-000000000001'
                    }
                }
            }

            $actual = _GenerateCreateBody @baselineArgs

            ConvertTo-CanonicalJson $actual | Should -BeExactly (ConvertTo-CanonicalJson $expected)
        }
    }

    Context 'When a creation method is supplied' {

        It 'Should use it verbatim' {
            $body = _GenerateCreateBody @baselineArgs -CreationMethod 'SomeOtherMethod'

            $body.connectionDetails.type | Should -Be 'AzureBlobs'
            $body.connectionDetails.creationMethod | Should -Be 'SomeOtherMethod'
        }

        It 'Should support a SharePoint connection, whose creation method differs from its type' {
            $sharePointArgs = $baselineArgs.Clone()
            $sharePointArgs.DisplayName = 'EDAP_DEV_sp__hat'
            $sharePointArgs.ConnectionType = 'SharePoint'
            $sharePointArgs.CreationMethod = 'SharePointList'

            $body = _GenerateCreateBody @sharePointArgs

            $body.connectionDetails.type | Should -Be 'SharePoint'
            $body.connectionDetails.creationMethod | Should -Be 'SharePointList'
        }

        It 'Should support a Fabric data pipelines connection' {
            $pipelineArgs = $baselineArgs.Clone()
            $pipelineArgs.DisplayName = 'EDAP_DEV_fp__shared'
            $pipelineArgs.ConnectionType = 'FabricDataPipelines'
            $pipelineArgs.CreationMethod = 'FabricDataPipelines.Actions'

            $body = _GenerateCreateBody @pipelineArgs

            $body.connectionDetails.type | Should -Be 'FabricDataPipelines'
            $body.connectionDetails.creationMethod | Should -Be 'FabricDataPipelines.Actions'
        }
    }
}
