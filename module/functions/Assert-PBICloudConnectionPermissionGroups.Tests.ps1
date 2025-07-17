# <copyright file="Assert-PBICloudConnectionPermissionGroups.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Assert-PBICloudConnectionPermissionGroups" {

    BeforeAll {
        # Dot source the function files
        . "$PSScriptRoot\Assert-PBICloudConnectionPermissionGroups.ps1"
        . "$PSScriptRoot\Resolve-PrincipalIdentities.ps1"
        . "$PSScriptRoot\_Get-PermissionDelta.ps1"
        . "$PSScriptRoot\Remove-PBICloudConnectionPermission.ps1"
        . "$PSScriptRoot\Assert-PBICloudConnectionPermissions.ps1"
        . "$PSScriptRoot\Get-PBICloudConnectionPermissions.ps1"
        . "$PSScriptRoot\_ConvertFrom-PermissionGroups.ps1"
        . "$PSScriptRoot\_Apply-PermissionChanges.ps1"
        . "$PSScriptRoot\Remove-PBICloudConnectionPermissionBatch.ps1"

        Mock Write-Error {}
        Mock Write-Warning {}
    }

    Context "When all operations succeed" {
        It "should complete full permission synchronization successfully" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $permissionGroups = @{
                owners = @("admin@company.com")
                users = @("user@company.com")
            }
            $fabricToken = ConvertTo-SecureString "fabric-token" -AsPlainText -Force
            $graphToken = ConvertTo-SecureString "graph-token" -AsPlainText -Force

            # Mock identity resolution
            Mock -CommandName Resolve-PrincipalIdentities -MockWith {
                return @(
                    @{ originalIdentity = "admin@company.com"; principalId = "00000000-0000-0000-0000-000000000000"; principalType = "User" },
                    @{ originalIdentity = "user@company.com"; principalId = "00000000-0000-0000-0000-000000000001"; principalType = "User" }
                )
            }

            # Mock current permissions retrieval
            Mock -CommandName Get-PBICloudConnectionPermissions -MockWith {
                return @()  # No current permissions
            }

            # Mock permission assertions
            Mock -CommandName Assert-PBICloudConnectionPermissions -MockWith {
                return "Success"
            }

            # Act
            $result = Assert-PBICloudConnectionPermissionGroups `
                -CloudConnectionId $cloudConnectionId `
                -PermissionGroups $permissionGroups `
                -AccessToken $fabricToken `
                -GraphAccessToken $graphToken

            # Assert
            $result.Success | Should -Be $true
            $result.Summary.TotalIdentitiesResolved | Should -Be 2
            $result.Summary.PermissionsAdded | Should -Be 2
            $result.Summary.PermissionsUpdated | Should -Be 0
            $result.Summary.PermissionsRemoved | Should -Be 0
            $result.Errors | Should -HaveCount 0

            Assert-MockCalled -CommandName Resolve-PrincipalIdentities -Times 1
            Assert-MockCalled -CommandName Get-PBICloudConnectionPermissions -Times 2 # Before and after
            Assert-MockCalled -CommandName Assert-PBICloudConnectionPermissions -Times 2
        }
    }

    Context "When no changes are needed" {
        It "should report success with no operations when permissions match" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $permissionGroups = @{
                owners = @("admin@company.com")
            }
            $fabricToken = ConvertTo-SecureString "fabric-token" -AsPlainText -Force
            $graphToken = ConvertTo-SecureString "graph-token" -AsPlainText -Force

            # Mock identity resolution
            Mock -CommandName Resolve-PrincipalIdentities -MockWith {
                return @(
                    @{ originalIdentity = "admin@company.com"; principalId = "00000000-0000-0000-0000-000000000000"; principalType = "User" }
                )
            }

            # Mock current permissions - already has the desired permission
            Mock -CommandName Get-PBICloudConnectionPermissions -MockWith {
                return @(
                    @{ id = "existing-1"; principal = @{ id = "00000000-0000-0000-0000-000000000000"; type = "User" }; role = "Owner" }
                )
            }

            # Act
            $result = Assert-PBICloudConnectionPermissionGroups `
                -CloudConnectionId $cloudConnectionId `
                -PermissionGroups $permissionGroups `
                -AccessToken $fabricToken `
                -GraphAccessToken $graphToken

            # Assert
            $result.Success | Should -Be $true
            $result.Summary.TotalChanges | Should -Be 0
            $result.Errors | Should -HaveCount 0

            Assert-MockCalled -CommandName Resolve-PrincipalIdentities -Times 1
            Assert-MockCalled -CommandName Get-PBICloudConnectionPermissions -Times 1
        }
    }

    Context "When strict mode removes unauthorized permissions" {
        It "should remove permissions not specified in configuration" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $permissionGroups = @{
                owners = @("admin@company.com")
            }
            $fabricToken = ConvertTo-SecureString "fabric-token" -AsPlainText -Force
            $graphToken = ConvertTo-SecureString "graph-token" -AsPlainText -Force

            # Mock identity resolution
            Mock -CommandName Resolve-PrincipalIdentities -MockWith {
                return @(
                    @{ originalIdentity = "admin@company.com"; principalId = "00000000-0000-0000-0000-000000000000"; principalType = "User" }
                )
            }

            # Mock current permissions - has extra unauthorized permission
            Mock -CommandName Get-PBICloudConnectionPermissions -MockWith {
                return @(
                    @{ id = "existing-1"; principal = @{ id = "00000000-0000-0000-0000-000000000000"; type = "User" }; role = "Owner" },
                    @{ id = "existing-2"; principal = @{ id = "unauthorized-id"; type = "User" }; role = "User" }
                )
            }

            # Mock removal
            Mock -CommandName Remove-PBICloudConnectionPermissionBatch -MockWith {
                return @{
                    TotalRequested = 1
                    SuccessCount = 1
                    FailureCount = 0
                    Failures = @()
                    IsCompleteSuccess = $true
                }
            }

            # Act
            $result = Assert-PBICloudConnectionPermissionGroups `
                -CloudConnectionId $cloudConnectionId `
                -PermissionGroups $permissionGroups `
                -AccessToken $fabricToken `
                -GraphAccessToken $graphToken `
                -StrictMode

            # Assert
            $result.Success | Should -Be $true
            $result.Summary.PermissionsRemoved | Should -Be 1
            
            Assert-MockCalled -CommandName Remove-PBICloudConnectionPermissionBatch -Times 1
        }
    }

    Context "When dry run mode is enabled" {
        It "should not make actual changes in dry run mode" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $permissionGroups = @{
                owners = @("admin@company.com")
            }
            $fabricToken = ConvertTo-SecureString "fabric-token" -AsPlainText -Force
            $graphToken = ConvertTo-SecureString "graph-token" -AsPlainText -Force

            # Mock identity resolution
            Mock -CommandName Resolve-PrincipalIdentities -MockWith {
                return @(
                    @{ originalIdentity = "admin@company.com"; principalId = "00000000-0000-0000-0000-000000000000"; principalType = "User" }
                )
            }

            # Mock current permissions - no existing permissions
            Mock -CommandName Get-PBICloudConnectionPermissions -MockWith {
                return @()
            }

            # Mock permission operations (should not be called in dry run)
            Mock -CommandName Assert-PBICloudConnectionPermissions
            Mock -CommandName Remove-PBICloudConnectionPermissionBatch

            # Act
            $result = Assert-PBICloudConnectionPermissionGroups `
                -CloudConnectionId $cloudConnectionId `
                -PermissionGroups $permissionGroups `
                -AccessToken $fabricToken `
                -GraphAccessToken $graphToken `
                -DryRun

            # Assert
            $result.Success | Should -Be $true
            
            # Should not make actual changes
            Assert-MockCalled -CommandName Assert-PBICloudConnectionPermissions -Times 0
            Assert-MockCalled -CommandName Remove-PBICloudConnectionPermissionBatch -Times 0
        }
    }

    Context "When identity resolution fails" {
        It "should fail gracefully when identity resolution fails" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $permissionGroups = @{
                owners = @("admin@company.com")
            }
            $fabricToken = ConvertTo-SecureString "fabric-token" -AsPlainText -Force
            $graphToken = ConvertTo-SecureString "graph-token" -AsPlainText -Force

            # Mock identity resolution to fail
            Mock -CommandName Resolve-PrincipalIdentities -MockWith {
                throw "Graph API error"
            }
            Mock -CommandName Get-PBICloudConnectionPermissions -MockWith {}

            # Act & Assert
            { Assert-PBICloudConnectionPermissionGroups `
                -CloudConnectionId $cloudConnectionId `
                -PermissionGroups $permissionGroups `
                -AccessToken $fabricToken `
                -GraphAccessToken $graphToken } | Should -Throw

            # Should not proceed to other operations
            Should -Invoke -CommandName Get-PBICloudConnectionPermissions -Times 0
        }
    }

    Context "When permission retrieval fails" {
        It "should fail gracefully when current permissions cannot be retrieved" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $permissionGroups = @{
                owners = @("admin@company.com")
            }
            $fabricToken = ConvertTo-SecureString "fabric-token" -AsPlainText -Force
            $graphToken = ConvertTo-SecureString "graph-token" -AsPlainText -Force

            # Mock identity resolution
            Mock -CommandName Resolve-PrincipalIdentities -MockWith {
                return @(
                    @{ originalIdentity = "admin@company.com"; principalId = "00000000-0000-0000-0000-000000000000"; principalType = "User" }
                )
            }

            # Mock current permissions retrieval to fail
            Mock -CommandName Get-PBICloudConnectionPermissions -MockWith {
                throw "Fabric API error"
            }

            # Act & Assert
            { Assert-PBICloudConnectionPermissionGroups `
                -CloudConnectionId $cloudConnectionId `
                -PermissionGroups $permissionGroups `
                -AccessToken $fabricToken `
                -GraphAccessToken $graphToken } | Should -Throw
        }
    }

    Context "When some permission operations fail with ContinueOnError" {
        It "should continue processing and report partial success" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $permissionGroups = @{
                owners = @("admin@company.com")
                users = @("user@company.com")
            }
            $fabricToken = ConvertTo-SecureString "fabric-token" -AsPlainText -Force
            $graphToken = ConvertTo-SecureString "graph-token" -AsPlainText -Force

            # Mock identity resolution
            Mock -CommandName Resolve-PrincipalIdentities -MockWith {
                return @(
                    @{ originalIdentity = "admin@company.com"; principalId = "00000000-0000-0000-0000-000000000000"; principalType = "User" },
                    @{ originalIdentity = "user@company.com"; principalId = "00000000-0000-0000-0000-000000000001"; principalType = "User" }
                )
            }

            # Mock current permissions
            Mock -CommandName Get-PBICloudConnectionPermissions -MockWith {
                return @()
            }

            # Mock permission assertions - one succeeds, one fails
            Mock -CommandName Assert-PBICloudConnectionPermissions -MockWith {
                if ($AssigneePrincipalId -eq "00000000-0000-0000-0000-000000000001") {
                    throw "Permission assignment failed for 00000000-0000-0000-0000-000000000001"
                }
                return "Success"
            }

            # Act
            $result = Assert-PBICloudConnectionPermissionGroups `
                -CloudConnectionId $cloudConnectionId `
                -PermissionGroups $permissionGroups `
                -AccessToken $fabricToken `
                -GraphAccessToken $graphToken `
                -ContinueOnError

            # Assert
            $result.Success | Should -Be $true # Success because ContinueOnError is true
            $result.Summary.PermissionsAdded | Should -Be 1 # Only one succeeded
            $result.Errors | Should -HaveCount 1 # One error reported
            $result.Errors[0] | Should -BeLike "*Permission assignment failed for 00000000-0000-0000-0000-000000000001*"
        }
    }

    Context "When mixed identity types are provided" {
        It "should handle both email addresses and structured objects" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $permissionGroups = @{
                owners = @(
                    "admin@company.com",
                    @{ principalId = "00000000-0000-0000-0000-000000000002"; principalType = "ServicePrincipal" }
                )
            }
            $fabricToken = ConvertTo-SecureString "fabric-token" -AsPlainText -Force
            $graphToken = ConvertTo-SecureString "graph-token" -AsPlainText -Force

            # Mock identity resolution
            Mock -CommandName Resolve-PrincipalIdentities -MockWith {
                return @(
                    @{ originalIdentity = "admin@company.com"; principalId = "00000000-0000-0000-0000-000000000000"; principalType = "User" },
                    @{ originalIdentity = @{ principalId = "00000000-0000-0000-0000-000000000002"; principalType = "ServicePrincipal" }; principalId = "00000000-0000-0000-0000-000000000002"; principalType = "ServicePrincipal" }
                )
            }

            # Mock current permissions
            Mock -CommandName Get-PBICloudConnectionPermissions -MockWith {
                return @()
            }

            # Mock permission assertions
            Mock -CommandName Assert-PBICloudConnectionPermissions -MockWith {
                return "Success"
            }

            # Act
            $result = Assert-PBICloudConnectionPermissionGroups `
                -CloudConnectionId $cloudConnectionId `
                -PermissionGroups $permissionGroups `
                -AccessToken $fabricToken `
                -GraphAccessToken $graphToken

            # Assert
            $result.Success | Should -Be $true
            $result.Summary.TotalIdentitiesResolved | Should -Be 2
            $result.Summary.PermissionsAdded | Should -Be 2

            # Verify both types were processed
            Assert-MockCalled -CommandName Assert-PBICloudConnectionPermissions -ParameterFilter { 
                $AssigneePrincipalId -eq "00000000-0000-0000-0000-000000000000" -and $AssigneePrincipalType -eq "User" 
            } -Times 1
            Assert-MockCalled -CommandName Assert-PBICloudConnectionPermissions -ParameterFilter { 
                $AssigneePrincipalId -eq "00000000-0000-0000-0000-000000000002" -and $AssigneePrincipalType -eq "ServicePrincipal" 
            } -Times 1
        }
    }
}