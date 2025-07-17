# <copyright file="Assert-PBICloudConnectionPermissions.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Assert-PBICloudConnectionPermissions" {

    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/Assert-PBICloudConnectionPermissions.ps1
    }

    Context "When an existing permission is found" {
        It "should not update when the role is the same" {
            # Arrange: mock GET to return an existing permission with same role
            Mock -CommandName Invoke-RestMethod -MockWith {
                if ($Method -eq "GET") {
                    return @{
                        value = @(
                            @{
                                id = "existing-id"
                                principal = @{
                                    id = "f3498fd9-cff0-44a9-991c-c017f481adf0"
                                    type = "User"
                                }
                                role = "User"
                            }
                        )
                    }
                }
            }

            # Act
            $result = Assert-PBICloudConnectionPermissions `
                -CloudConnectionId "test-connection" `
                -AssigneePrincipalId "f3498fd9-cff0-44a9-991c-c017f481adf0" `
                -AssigneePrincipalRole "User" `
                -AssigneePrincipalType "User" `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force)

            # Assert
            Assert-MockCalled -CommandName Invoke-RestMethod -ParameterFilter { $Method -eq "GET" } -Times 1
            Assert-MockCalled -CommandName Invoke-RestMethod -ParameterFilter { $Method -eq "PATCH" } -Times 0
        }

        It "should update the permission when the role is different" {
            # Arrange: mock GET to return existing permission with different role and PATCH to return updated
            Mock -CommandName Invoke-RestMethod -MockWith {
                if ($Method -eq "GET") {
                    return @{
                        value = @(
                            @{
                                id = "existing-id"
                                principal = @{
                                    id = "f3498fd9-cff0-44a9-991c-c017f481adf0"
                                    type = "User"
                                }
                                role = "User"
                            }
                        )
                    }
                } elseif ($Method -eq "PATCH") {
                    return "updated"
                }
            }

            # Act
            $result = Assert-PBICloudConnectionPermissions `
                -CloudConnectionId "test-connection" `
                -AssigneePrincipalId "f3498fd9-cff0-44a9-991c-c017f481adf0" `
                -AssigneePrincipalRole "Owner" `
                -AssigneePrincipalType "User" `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force)

            # Assert
            $result | Should -Be "updated"
            Assert-MockCalled -CommandName Invoke-RestMethod -ParameterFilter { $Method -eq "GET" } -Times 1
            Assert-MockCalled -CommandName Invoke-RestMethod -ParameterFilter { 
                $Method -eq "PATCH" -and
                $Body -like '*"role":"Owner"*'
            } -Times 1
        }
    }

    Context "When no existing permission is found" {
        It "should create new permission via POST" {
            # Arrange: mock GET to return no permissions and POST to return created
            Mock -CommandName Invoke-RestMethod -MockWith {
                if ($Method -eq "GET") {
                    return @{ value = @() }
                } elseif ($Method -eq "POST") {
                    return "created"
                }
            }

            # Act
            $result = Assert-PBICloudConnectionPermissions `
                -CloudConnectionId "test-connection" `
                -AssigneePrincipalId "f3498fd9-cff0-44a9-991c-c017f481adf0" `
                -AssigneePrincipalRole "User" `
                -AssigneePrincipalType "ServicePrincipal" `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force)

            # Assert
            $result | Should -Be "created"
            Assert-MockCalled -CommandName Invoke-RestMethod -ParameterFilter { $Method -eq "GET" } -Times 1
            Assert-MockCalled -CommandName Invoke-RestMethod -ParameterFilter { 
                $Method -eq "POST" -and
                $Body -like '*"type":"ServicePrincipal"*'
            } -Times 1
        }
    }
}