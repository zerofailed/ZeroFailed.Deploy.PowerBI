# <copyright file="_Assert-ValidConnectionType.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe '_Assert-ValidConnectionType' {

    BeforeAll {
        # Dot source the function file
        . $PSScriptRoot/_Assert-ValidConnectionType.ps1

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
    }

    BeforeEach {
        # The real shape, as observed against a live tenant: exactly one SharePoint entry, whose
        # creation method is 'SharePointList' rather than 'SharePoint'.
        Mock Invoke-RestMethodWithRateLimit -MockWith {
            return [pscustomobject]@{
                value = @(
                    [pscustomobject]@{
                        type                    = 'SharePoint'
                        creationMethods         = @([pscustomobject]@{ name = 'SharePointList' })
                        supportedCredentialTypes = @('ServicePrincipal', 'OAuth2')
                    }
                    [pscustomobject]@{
                        type                    = 'AzureBlobs'
                        creationMethods         = @([pscustomobject]@{ name = 'AzureBlobs' })
                        supportedCredentialTypes = @('ServicePrincipal', 'Key')
                    }
                )
            }
        }
    }

    AfterEach {
        # The cache lives for the lifetime of the module, so each test starts from a clean one.
        Remove-Variable -Name SupportedConnectionTypeCache -Scope Script -ErrorAction SilentlyContinue
    }

    Context 'When the definition is valid' {

        It 'Should accept a creation method that differs from the type' {
            { _Assert-ValidConnectionType -ConnectionType 'SharePoint' `
                                          -CreationMethod 'SharePointList' `
                                          -DisplayName 'EDAP_DEV_sp__hat' `
                                          -AccessToken $token } | Should -Not -Throw
        }

        It 'Should default the creation method to the type when none is given' {
            { _Assert-ValidConnectionType -ConnectionType 'AzureBlobs' `
                                          -DisplayName 'Development Blob Storage' `
                                          -AccessToken $token } | Should -Not -Throw
        }

        It 'Should accept a supported credential type' {
            { _Assert-ValidConnectionType -ConnectionType 'SharePoint' `
                                          -CreationMethod 'SharePointList' `
                                          -CredentialType 'ServicePrincipal' `
                                          -DisplayName 'EDAP_DEV_sp__hat' `
                                          -AccessToken $token } | Should -Not -Throw
        }

        It 'Should read the supported types only once across repeated calls' {
            _Assert-ValidConnectionType -ConnectionType 'AzureBlobs' -DisplayName 'A' -AccessToken $token
            _Assert-ValidConnectionType -ConnectionType 'AzureBlobs' -DisplayName 'B' -AccessToken $token

            Should -Invoke Invoke-RestMethodWithRateLimit -Times 1 -Exactly
        }
    }

    Context 'When the creation method is wrong for the type' {

        It 'Should name the problem and list the valid creation methods' {
            # Left to the tenant this fails "No function found matching 'SharePoint' for
            # Kind: 'SharePoint'", which reads as though the type is wrong.
            { _Assert-ValidConnectionType -ConnectionType 'SharePoint' `
                                          -CreationMethod 'SharePoint' `
                                          -DisplayName 'EDAP_DEV_sp__hat' `
                                          -AccessToken $token } |
                Should -Throw -ExpectedMessage "*creationMethod 'SharePoint', which is not valid for type 'SharePoint'*"

            { _Assert-ValidConnectionType -ConnectionType 'SharePoint' `
                                          -CreationMethod 'SharePoint' `
                                          -DisplayName 'EDAP_DEV_sp__hat' `
                                          -AccessToken $token } |
                Should -Throw -ExpectedMessage '*SharePointList*'
        }
    }

    Context 'When the type is not supported by the tenant' {

        It 'Should name the connection and list the supported types' {
            { _Assert-ValidConnectionType -ConnectionType 'NotAThing' `
                                          -DisplayName 'Bad Connection' `
                                          -AccessToken $token } |
                Should -Throw -ExpectedMessage "*'Bad Connection' declares type 'NotAThing'*"
        }
    }

    Context 'When the credential type is not supported for the type' {

        It 'Should name the connection and list the supported credential types' {
            { _Assert-ValidConnectionType -ConnectionType 'AzureBlobs' `
                                          -CredentialType 'WorkspaceIdentity' `
                                          -DisplayName 'Development Blob Storage' `
                                          -AccessToken $token } |
                Should -Throw -ExpectedMessage "*credentialType 'WorkspaceIdentity', which is not supported for type 'AzureBlobs'*"
        }
    }

    Context 'When the tenant returns nothing' {

        It 'Should warn and skip validation rather than block the deployment' {
            Mock Invoke-RestMethodWithRateLimit -MockWith { return [pscustomobject]@{ value = @() } }
            Mock Write-Warning {}

            { _Assert-ValidConnectionType -ConnectionType 'SharePoint' `
                                          -DisplayName 'EDAP_DEV_sp__hat' `
                                          -AccessToken $token } | Should -Not -Throw

            Should -Invoke Write-Warning -Times 1
        }
    }
}
