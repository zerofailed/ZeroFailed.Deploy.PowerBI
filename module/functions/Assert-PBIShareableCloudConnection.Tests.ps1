# <copyright file="Assert-PBIShareableCloudConnection.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Assert-PBIShareableCloudConnection" {

    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/Assert-PBIShareableCloudConnection.ps1
        . $PSScriptRoot/_GenerateCreateBody.ps1
        . $PSScriptRoot/_GenerateUpdateBody.ps1
        . $PSScriptRoot/_Get-CloudConnectionList.ps1

        # Make external functions available for mocking
        # Ref: https://github.com/zerofailed/ZeroFailed.DevOps.Common
        function Invoke-RestMethodWithRateLimit {
            param (
                [Parameter(Mandatory=$true)]
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
    }

    Context "When an existing connection is found" {
        It "should update the connection via PATCH" {
            # Arrange: mock GET to return an existing connection and PATCH to return a test value.
            Mock -CommandName Invoke-RestMethodWithRateLimit -MockWith {
                 if ($Splat.Method -eq "GET") {
                    # Simulate a GET response that finds the connection.
                    return @{ value = @([pscustomobject]@{ displayName = "ExistingConnection"; id = "abc123" }) }
                } elseif ($Splat.Method -eq "PATCH") {
                    return "updated"
                }
            }

            Mock _GenerateCreateBody -MockWith {return @{}}
            Mock _GenerateUpdateBody -MockWith {return @{}}

            # Act
            $result = Assert-PBIShareableCloudConnection -DisplayName "ExistingConnection" `
                -ConnectionType "TestType" `
                -Parameters @{} `
                -ServicePrincipalClientId "e795e7b2-a973-436c-a55e-cb06a2fcd68e" `
                -ServicePrincipalSecret (ConvertTo-SecureString "secret" -AsPlainText -Force) `
                -TenantId "tenant" `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force)

            # Assert
            $result | Should -Be "updated"
            Should -Invoke Invoke-RestMethodWithRateLimit -ParameterFilter { $Splat.Method -eq "PATCH" } -Times 1
            Should -Invoke Invoke-RestMethodWithRateLimit -ParameterFilter { $Splat.Method -eq "GET" } -Times 1
            Should -Invoke _GenerateCreateBody -Times 0
            Should -Invoke _GenerateUpdateBody -Times 1
        }
    }

    Context "When no existing connection is found" {
        It "should create the connection via POST" {
            # Arrange: mock GET to return no connection and POST to return a test value.
            Mock -CommandName Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Method -eq "GET") {
                    return @{ value = @() }
                } elseif ($Splat.Method -eq "POST") {
                    return "created"
                }
            }

            Mock _GenerateCreateBody -MockWith {return @{}}
            Mock _GenerateUpdateBody -MockWith {return @{}}

            # Act
            $result = Assert-PBIShareableCloudConnection -DisplayName "NewConnection" `
                -ConnectionType "NewType" `
                -Parameters @{} `
                -ServicePrincipalClientId "e795e7b2-a973-436c-a55e-cb06a2fcd68e" `
                -ServicePrincipalSecret (ConvertTo-SecureString "secret" -AsPlainText -Force) `
                -TenantId "tenant" `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force)

            # Assert
            $result | Should -Be "created"
            Should -Invoke Invoke-RestMethodWithRateLimit -ParameterFilter { $Splat.Method -eq "POST" } -Times 1
            Should -Invoke _GenerateCreateBody -Times 1
            Should -Invoke _GenerateUpdateBody -Times 0
        }

        It "should pass an explicitly specified creation method through to _GenerateCreateBody" {
            Mock -CommandName Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Method -eq "GET") {
                    return @{ value = @() }
                } elseif ($Splat.Method -eq "POST") {
                    return "created"
                }
            }

            Mock _GenerateCreateBody -MockWith {return @{}}
            Mock _GenerateUpdateBody -MockWith {return @{}}

            # Act
            Assert-PBIShareableCloudConnection -DisplayName "NewConnection" `
                -ConnectionType "CommonDataService" `
                -CreationMethod "CommonDataService.Database" `
                -Parameters @{} `
                -ServicePrincipalClientId "e795e7b2-a973-436c-a55e-cb06a2fcd68e" `
                -ServicePrincipalSecret (ConvertTo-SecureString "secret" -AsPlainText -Force) `
                -TenantId "tenant" `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force)

            # Assert
            Should -Invoke _GenerateCreateBody -Times 1 -ParameterFilter { $creationMethod -eq "CommonDataService.Database" }
        }
    }

    Context "When credential updates are suppressed" {

        BeforeAll {
            $script:existingArgs = @{
                DisplayName              = "ExistingConnection"
                ConnectionType           = "TestType"
                Parameters               = @{}
                ServicePrincipalClientId = "e795e7b2-a973-436c-a55e-cb06a2fcd68e"
                ServicePrincipalSecret   = (ConvertTo-SecureString "secret" -AsPlainText -Force)
                TenantId                 = "tenant"
                AccessToken              = (ConvertTo-SecureString "token" -AsPlainText -Force)
            }
        }

        BeforeEach {
            Mock -CommandName Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Method -eq "GET") {
                    return @{ value = @([pscustomobject]@{ displayName = "ExistingConnection"; id = "abc123" }) }
                } elseif ($Splat.Method -eq "PATCH") {
                    return "updated"
                }
            }
            Mock _GenerateCreateBody -MockWith { return @{} }
            Mock _GenerateUpdateBody -MockWith { return @{} }
        }

        It "should PATCH by default, exactly as before" {
            # The CR-N1 regression guard for this feature: an existing configuration says
            # nothing about credential updates and must keep converging on the declared state.
            $result = Assert-PBIShareableCloudConnection @existingArgs

            $result | Should -Be "updated"
            Should -Invoke Invoke-RestMethodWithRateLimit -ParameterFilter { $Splat.Method -eq "PATCH" } -Times 1
        }

        It "should not PATCH when the connection opts out" {
            $result = Assert-PBIShareableCloudConnection @existingArgs -AllowCredentialUpdate $false

            Should -Invoke Invoke-RestMethodWithRateLimit -ParameterFilter { $Splat.Method -eq "PATCH" } -Times 0
            Should -Invoke _GenerateUpdateBody -Times 0
            $result.id | Should -Be "abc123"
        }

        It "should not PATCH when the run suppresses all credential updates" {
            Assert-PBIShareableCloudConnection @existingArgs -SkipCredentialUpdates | Out-Null

            Should -Invoke Invoke-RestMethodWithRateLimit -ParameterFilter { $Splat.Method -eq "PATCH" } -Times 0
        }

        It "should still create a connection that does not yet exist" {
            # The opt-out suppresses updates, not provisioning.
            Mock -CommandName Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Method -eq "GET") {
                    return @{ value = @() }
                } elseif ($Splat.Method -eq "POST") {
                    return "created"
                }
            }

            $result = Assert-PBIShareableCloudConnection @existingArgs -AllowCredentialUpdate $false

            $result | Should -Be "created"
            Should -Invoke Invoke-RestMethodWithRateLimit -ParameterFilter { $Splat.Method -eq "POST" } -Times 1
        }
    }

    Context "When the connection uses a credential type that carries no secret" {

        BeforeAll {
            . $PSScriptRoot/_GenerateCredentialsBlock.ps1
        }

        It "should create the connection with no service principal and no parameters" {
            # Two separate failure modes are being guarded here, both of which stop this call
            # before any of the credential logic runs:
            #  - a mandatory [hashtable[]] rejects an empty array outright, and a
            #    FabricDataPipelines connection has no parameters at all
            #  - piping a $null secret into ConvertFrom-SecureString fails parameter binding
            Mock -CommandName Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Method -eq "GET") {
                    return @{ value = @() }
                } elseif ($Splat.Method -eq "POST") {
                    return [pscustomobject]@{ id = "fp-123"; displayName = "EDAP_DEV_fp__shared" }
                }
            }

            $result = Assert-PBIShareableCloudConnection -DisplayName "EDAP_DEV_fp__shared" `
                -ConnectionType "FabricDataPipelines" `
                -CreationMethod "FabricDataPipelines.Actions" `
                -CredentialType "WorkspaceIdentity" `
                -Parameters @() `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force)

            $result.id | Should -Be "fp-123"
            Should -Invoke Invoke-RestMethodWithRateLimit -ParameterFilter { $Splat.Method -eq "POST" } -Times 1
        }

        It "should send a create body carrying the credential type alone" {
            Mock -CommandName Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Method -eq "GET") {
                    return @{ value = @() }
                } elseif ($Splat.Method -eq "POST") {
                    $script:capturedBody = $Splat.Body | ConvertFrom-Json
                    return [pscustomobject]@{ id = "fp-123" }
                }
            }

            Assert-PBIShareableCloudConnection -DisplayName "EDAP_DEV_fp__shared" `
                -ConnectionType "FabricDataPipelines" `
                -CreationMethod "FabricDataPipelines.Actions" `
                -CredentialType "WorkspaceIdentity" `
                -Parameters @() `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force) | Out-Null

            $capturedBody.connectionDetails.type | Should -Be "FabricDataPipelines"
            $capturedBody.connectionDetails.creationMethod | Should -Be "FabricDataPipelines.Actions"
            $capturedBody.credentialDetails.credentials.credentialType | Should -Be "WorkspaceIdentity"
            $capturedBody.credentialDetails.credentials.PSObject.Properties.Name | Should -HaveCount 1
        }

        It "should send an update body carrying no service principal secret" {
            Mock -CommandName Invoke-RestMethodWithRateLimit -MockWith {
                if ($Splat.Method -eq "GET") {
                    return @{ value = @([pscustomobject]@{ displayName = "EDAP_DEV_fp__shared"; id = "fp-123" }) }
                } elseif ($Splat.Method -eq "PATCH") {
                    $script:capturedBody = $Splat.Body | ConvertFrom-Json
                    return "updated"
                }
            }

            Assert-PBIShareableCloudConnection -DisplayName "EDAP_DEV_fp__shared" `
                -ConnectionType "FabricDataPipelines" `
                -CredentialType "WorkspaceIdentity" `
                -Parameters @() `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force) | Out-Null

            $capturedBody.credentialDetails.credentials.credentialType | Should -Be "WorkspaceIdentity"
            $capturedBody.credentialDetails.credentials.servicePrincipalSecret | Should -BeNullOrEmpty
        }
    }
}