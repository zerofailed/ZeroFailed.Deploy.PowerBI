# <copyright file="Remove-PBICloudConnectionPermission.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Remove-PBICloudConnectionPermission" {

    BeforeAll {
        # Dot source the function file
        . "$PSScriptRoot\Remove-PBICloudConnectionPermission.ps1"

        Mock Write-Error {}
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