# <copyright file="Remove-PBICloudConnectionPermissionBatch.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Remove-PBICloudConnectionPermissionBatch" {

    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/Remove-PBICloudConnectionPermissionBatch.ps1
        . $PSScriptRoot/Remove-PBICloudConnectionPermission.ps1

        # Make external functions available for mocking
        function Write-ErrorLogMessage { param($Message) }

        Mock Write-Error {}
        Mock Write-Warning {}
    }

    Context "When removing multiple permissions successfully" {
        It "should process all role assignments and return success summary" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignments = @(
                @{ id = "assignment1"; principalId = "user1" },
                @{ id = "assignment2"; principalId = "user2" }
            )
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Remove-PBICloudConnectionPermission -MockWith {
                return "Success"
            }

            # Act
            $result = Remove-PBICloudConnectionPermissionBatch `
                -CloudConnectionId $cloudConnectionId `
                -RoleAssignments $roleAssignments `
                -AccessToken $mockToken

            # Assert
            Assert-MockCalled -CommandName Remove-PBICloudConnectionPermission -Times 2
            
            $result.TotalRequested | Should -Be 2
            $result.SuccessCount | Should -Be 2
            $result.FailureCount | Should -Be 0
            $result.IsCompleteSuccess | Should -Be $true
            $result.Failures | Should -HaveCount 0
        }
    }

    Context "When some removals fail" {
        It "should continue processing and report failures when ContinueOnError is true" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignments = @(
                @{ id = "assignment1"; principalId = "user1" },
                @{ id = "assignment2"; principalId = "user2" },
                @{ id = "assignment3"; principalId = "user3" }
            )
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Remove-PBICloudConnectionPermission -MockWith {
                if ($RoleAssignmentId -eq "assignment2") {
                    throw "Failed to remove assignment2"
                }
                return "Success"
            }

            # Act
            $result = Remove-PBICloudConnectionPermissionBatch `
                -CloudConnectionId $cloudConnectionId `
                -RoleAssignments $roleAssignments `
                -AccessToken $mockToken `
                -ContinueOnError

            # Assert
            Assert-MockCalled -CommandName Remove-PBICloudConnectionPermission -Times 3
            
            $result.TotalRequested | Should -Be 3
            $result.SuccessCount | Should -Be 2
            $result.FailureCount | Should -Be 1
            $result.IsCompleteSuccess | Should -Be $false
            $result.Failures | Should -HaveCount 1
            $result.Failures[0].RoleAssignmentId | Should -Be "assignment2"
            $result.Failures[0].Error | Should -Be "Failed to remove assignment2"
        }

        It "should stop processing when ContinueOnError is false" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignments = @(
                @{ id = "assignment1"; principalId = "user1" },
                @{ id = "assignment2"; principalId = "user2" },
                @{ id = "assignment3"; principalId = "user3" }
            )
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Remove-PBICloudConnectionPermission -MockWith {
                if ($RoleAssignmentId -eq "assignment2") {
                    throw "Failed to remove assignment2"
                }
                return "Success"
            }

            # Act & Assert
            {
                Remove-PBICloudConnectionPermissionBatch `
                    -CloudConnectionId $cloudConnectionId `
                    -RoleAssignments $roleAssignments `
                    -AccessToken $mockToken `
                    -ContinueOnError:$false
            } | Should -Throw
        }
    }

    Context "When role assignments are missing required properties" {
        It "should skip assignments without ID and report as failures" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignments = @(
                @{ id = "assignment1"; principalId = "user1" },
                @{ principalId = "user2" },  # Missing id
                @{ id = "assignment3"; principalId = "user3" }
            )
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Remove-PBICloudConnectionPermission -MockWith {
                return "Success"
            }

            # Act
            $result = Remove-PBICloudConnectionPermissionBatch `
                        -CloudConnectionId $cloudConnectionId `
                        -RoleAssignments $roleAssignments `
                        -AccessToken $mockToken

            # Assert
            Assert-MockCalled -CommandName Remove-PBICloudConnectionPermission -Times 2 # Should skip the one without ID
            
            $result.TotalRequested | Should -Be 3
            $result.SuccessCount | Should -Be 2
            $result.FailureCount | Should -Be 1
        }
    }

    Context "When using WhatIf parameter" {
        It "should not make actual removals in WhatIf mode" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignments = @(
                @{ id = "assignment1"; principalId = "user1" }
            )
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Remove-PBICloudConnectionPermission

            # Act
            $result = Remove-PBICloudConnectionPermissionBatch `
                -CloudConnectionId $cloudConnectionId `
                -RoleAssignments $roleAssignments `
                -AccessToken $mockToken `
                -WhatIf

            # Assert
            Assert-MockCalled -CommandName Remove-PBICloudConnectionPermission -ParameterFilter { $WhatIf -eq $true } -Times 0
        }
    }

    Context "When processing empty role assignments array" {
        It "should handle empty array gracefully" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignments = @()
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Remove-PBICloudConnectionPermission

            # Act
            $result = Remove-PBICloudConnectionPermissionBatch `
                -CloudConnectionId $cloudConnectionId `
                -RoleAssignments $roleAssignments `
                -AccessToken $mockToken

            # Assert
            Assert-MockCalled -CommandName Remove-PBICloudConnectionPermission -Times 0
            
            $result.TotalRequested | Should -Be 0
            $result.SuccessCount | Should -Be 0
            $result.FailureCount | Should -Be 0
            $result.IsCompleteSuccess | Should -Be $true
        }
    }
}