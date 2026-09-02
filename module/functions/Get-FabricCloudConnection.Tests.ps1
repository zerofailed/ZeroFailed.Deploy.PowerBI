# <copyright file="Get-FabricCloudConnection.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe 'Get-FabricCloudConnection' {

    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/Get-FabricCloudConnection.ps1
        . $PSScriptRoot/_Get-CloudConnectionList.ps1

        # Make external functions available for mocking
        # Ref: https://github.com/zerofailed/ZeroFailed.DevOps.Common
        function Invoke-RestMethodWithRateLimit {
            param (
                [Parameter(Mandatory = $true)]
                [hashtable] $Splat,

                [Parameter()]
                [int] $MaxRetries = 3,

                [Parameter()]
                [double] $BaseDelaySeconds = 1.0,

                [Parameter()]
                [int] $MaxDelaySeconds = 60,

                [Parameter()]
                [double] $RetryBackOffExponentialFactor = 1.5
            )
        }

        $script:token = ConvertTo-SecureString 'token' -AsPlainText -Force

        $script:pipelineConnection = [pscustomobject]@{
            id                         = 'fp-123'
            displayName                = 'EDAP_DEV_fp__shared'
            connectionDetails          = [pscustomobject]@{ type = 'FabricDataPipelines'; creationMethod = 'FabricDataPipelines.Actions' }
            credentialDetails          = [pscustomobject]@{ credentialType = 'WorkspaceIdentity' }
            lastCredentialUsedDateTime = '2026-08-20T09:15:00Z'
        }
    }

    Context 'When the connection is on the first page' {

        It 'Should return its id and credential state' {
            Mock Invoke-RestMethodWithRateLimit -MockWith {
                return [pscustomobject]@{ value = @($pipelineConnection) }
            }

            $result = Get-FabricCloudConnection -DisplayName 'EDAP_DEV_fp__shared' -AccessToken $token

            $result.id | Should -Be 'fp-123'
            $result.credentialType | Should -Be 'WorkspaceIdentity'
            $result.connectionType | Should -Be 'FabricDataPipelines'
            $result.creationMethod | Should -Be 'FabricDataPipelines.Actions'
        }

        It 'Should surface lastCredentialUsedDateTime' {
            # A connection whose credential has never been used is either unused, or failing
            # before the credential is reached - which is what a wrong-tenant binding looks like.
            Mock Invoke-RestMethodWithRateLimit -MockWith {
                return [pscustomobject]@{ value = @($pipelineConnection) }
            }

            $result = Get-FabricCloudConnection -DisplayName 'EDAP_DEV_fp__shared' -AccessToken $token

            $result.lastCredentialUsedDateTime | Should -Be '2026-08-20T09:15:00Z'
        }
    }

    Context 'When the connection is on a later page' {

        It 'Should follow the continuation token to find it' {
            # An unpaged read would report this connection absent, and a create-or-update flow
            # would then attempt a create that fails on a duplicate display name.
            Mock Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Uri -match 'continuationToken') {
                    return [pscustomobject]@{ value = @($pipelineConnection) }
                }
                return [pscustomobject]@{
                    value             = @([pscustomobject]@{ id = 'other-1'; displayName = 'Some Other Connection' })
                    continuationToken = 'page-2-token'
                }
            }

            $result = Get-FabricCloudConnection -DisplayName 'EDAP_DEV_fp__shared' -AccessToken $token

            $result.id | Should -Be 'fp-123'
            Should -Invoke Invoke-RestMethodWithRateLimit -Times 2 -Exactly
        }

        It 'Should prefer a supplied continuationUri over composing one' {
            Mock Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Uri -eq 'https://api.fabric.microsoft.com/v1/connections?next=abc') {
                    return [pscustomobject]@{ value = @($pipelineConnection) }
                }
                return [pscustomobject]@{
                    value             = @()
                    continuationUri   = 'https://api.fabric.microsoft.com/v1/connections?next=abc'
                    continuationToken = 'ignored-when-a-uri-is-given'
                }
            }

            $result = Get-FabricCloudConnection -DisplayName 'EDAP_DEV_fp__shared' -AccessToken $token

            $result.id | Should -Be 'fp-123'
        }
    }

    Context 'When the list response carries no credential details' {

        It 'Should fall back to reading the connection by id' {
            Mock Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Uri -like '*/connections/fp-123') {
                    return $pipelineConnection
                }
                return [pscustomobject]@{
                    value = @([pscustomobject]@{
                        id                = 'fp-123'
                        displayName       = 'EDAP_DEV_fp__shared'
                        connectionDetails = [pscustomobject]@{ type = 'FabricDataPipelines' }
                    })
                }
            }

            $result = Get-FabricCloudConnection -DisplayName 'EDAP_DEV_fp__shared' -AccessToken $token

            $result.credentialType | Should -Be 'WorkspaceIdentity'
            Should -Invoke Invoke-RestMethodWithRateLimit -ParameterFilter { $Splat.Uri -like '*/connections/fp-123' } -Times 1
        }

        It 'Should keep the id from the list entry when the by-id read returns something unexpected' {
            # The id is the whole point of this function, so an odd detail response must never
            # be able to blank it out.
            Mock Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Uri -like '*/connections/fp-123') {
                    return [pscustomobject]@{ value = @() }   # a list-shaped response, not a connection
                }
                return [pscustomobject]@{
                    value = @([pscustomobject]@{
                        id                = 'fp-123'
                        displayName       = 'EDAP_DEV_fp__shared'
                        connectionDetails = [pscustomobject]@{ type = 'FabricDataPipelines' }
                    })
                }
            }

            $result = Get-FabricCloudConnection -DisplayName 'EDAP_DEV_fp__shared' -AccessToken $token

            $result.id | Should -Be 'fp-123'
            $result.displayName | Should -Be 'EDAP_DEV_fp__shared'
            $result.connectionType | Should -Be 'FabricDataPipelines'
            $result.credentialType | Should -BeNullOrEmpty
        }
    }

    Context 'When no connection of that display name is visible' {

        BeforeEach {
            Mock Invoke-RestMethodWithRateLimit -MockWith {
                return [pscustomobject]@{ value = @() }
            }
        }

        It 'Should return null by default' {
            Get-FabricCloudConnection -DisplayName 'Nope' -AccessToken $token | Should -BeNullOrEmpty
        }

        It 'Should throw a message naming both possible causes when ThrowIfMissing is set' {
            # "Not found" is ambiguous: a connection you hold no role on is invisible rather
            # than merely unusable, and the two causes have different fixes.
            { Get-FabricCloudConnection -DisplayName 'Nope' -AccessToken $token -ThrowIfMissing } |
                Should -Throw -ExpectedMessage '*not been provisioned*'

            { Get-FabricCloudConnection -DisplayName 'Nope' -AccessToken $token -ThrowIfMissing } |
                Should -Throw -ExpectedMessage '*not shared with the identity*'
        }
    }
}
