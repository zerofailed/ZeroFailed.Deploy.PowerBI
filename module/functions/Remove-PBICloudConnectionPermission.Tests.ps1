# <copyright file="Remove-PBICloudConnectionPermission.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Remove-PBICloudConnectionPermission" {

    BeforeAll {
        # Dot source the function file
        . "$PSScriptRoot\Remove-PBICloudConnectionPermission.ps1"
    }

    Context "When removing a permission successfully" {
        It "should make a DELETE request to the correct endpoint" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignmentId = "test-assignment-id"
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Invoke-RestMethod -MockWith {
                return "Success"
            }

            # Act
            $result = Remove-PBICloudConnectionPermission `
                -CloudConnectionId $cloudConnectionId `
                -RoleAssignmentId $roleAssignmentId `
                -AccessToken $mockToken

            # Assert
            Assert-MockCalled -CommandName Invoke-RestMethod -ParameterFilter {
                $Uri -eq "https://api.fabric.microsoft.com/v1/connections/$cloudConnectionId/roleAssignments/$roleAssignmentId" -and
                $Method -eq "DELETE" -and
                $Headers.Authorization -eq "Bearer mock-token"
            } -Times 1

            $result | Should -Be "Success"
        }
    }

    Context "When the role assignment does not exist (404)" {
        It "should handle 404 gracefully and return null" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignmentId = "non-existent-assignment-id"
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Invoke-RestMethod -MockWith {
                # Create a proper WebException with 404 status
                $response = [System.Net.HttpWebResponse]::new()
                $response | Add-Member -MemberType NoteProperty -Name StatusCode -Value ([System.Net.HttpStatusCode]::NotFound) -Force
                
                $exception = [System.Net.WebException]::new("Not Found", $null, [System.Net.WebExceptionStatus]::ProtocolError, $response)
                $exception | Add-Member -MemberType NoteProperty -Name Response -Value @{ StatusCode = @{ value__ = 404 } } -Force
                throw $exception
            }

            # Act & Assert
            $result = Remove-PBICloudConnectionPermission `
                -CloudConnectionId $cloudConnectionId `
                -RoleAssignmentId $roleAssignmentId `
                -AccessToken $mockToken `
                -WarningAction SilentlyContinue

            $result | Should -BeNullOrEmpty
        }
    }

    Context "When insufficient permissions (403)" {
        It "should throw an error for 403 Forbidden" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignmentId = "test-assignment-id"
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Invoke-RestMethod -MockWith {
                $exception = [System.Net.WebException]::new("Forbidden")
                $exception | Add-Member -MemberType NoteProperty -Name Response -Value @{ StatusCode = @{ value__ = 403 } } -Force
                throw $exception
            }

            # Act & Assert
            { Remove-PBICloudConnectionPermission `
                -CloudConnectionId $cloudConnectionId `
                -RoleAssignmentId $roleAssignmentId `
                -AccessToken $mockToken } | Should -Throw
        }
    }

    Context "When using WhatIf parameter" {
        It "should not make actual API calls in WhatIf mode" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignmentId = "test-assignment-id"
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Invoke-RestMethod

            # Act
            $result = Remove-PBICloudConnectionPermission `
                -CloudConnectionId $cloudConnectionId `
                -RoleAssignmentId $roleAssignmentId `
                -AccessToken $mockToken `
                -WhatIf

            # Assert
            Assert-MockCalled -CommandName Invoke-RestMethod -Times 0
            $result | Should -BeNullOrEmpty
        }
    }

    Context "When handling other HTTP errors" {
        It "should throw for other HTTP error codes" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $roleAssignmentId = "test-assignment-id"
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Invoke-RestMethod -MockWith {
                $exception = [System.Net.WebException]::new("Internal Server Error")
                $exception | Add-Member -MemberType NoteProperty -Name Response -Value @{ StatusCode = @{ value__ = 500 } } -Force
                throw $exception
            }

            # Act & Assert
            { Remove-PBICloudConnectionPermission `
                -CloudConnectionId $cloudConnectionId `
                -RoleAssignmentId $roleAssignmentId `
                -AccessToken $mockToken } | Should -Throw
        }
    }
}

Describe "Remove-PBICloudConnectionPermissionBatch" {

    BeforeAll {
        . "$PSScriptRoot\Remove-PBICloudConnectionPermission.ps1"
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
            { Remove-PBICloudConnectionPermissionBatch `
                -CloudConnectionId $cloudConnectionId `
                -RoleAssignments $roleAssignments `
                -AccessToken $mockToken `
                -ContinueOnError:$false } | Should -Throw
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
                -AccessToken $mockToken `
                -WarningAction SilentlyContinue

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
            Assert-MockCalled -CommandName Remove-PBICloudConnectionPermission -ParameterFilter { $WhatIf -eq $true } -Times 1
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