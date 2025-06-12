# <copyright file="Assert-PBIShareableCloudConnection.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Assert-PBIShareableCloudConnection" {

    BeforeAll {
        # Dot source the function file to load Assert-PBIShareableCloudConnection into the test session.
        . "$PSScriptRoot\Assert-PBIShareableCloudConnection.ps1"
        . "$PSScriptRoot\_GenerateCreateBody.ps1"
        . "$PSScriptRoot\_GenerateUpdateBody.ps1"
    }

    Context "When an existing connection is found" {
        It "should update the connection via PATCH" {
            # Arrange: mock GET to return an existing connection and PATCH to return a test value.
            Mock -CommandName Invoke-RestMethod -MockWith {
                 if ($Method -eq "GET") {
                    # Simulate a GET response that finds the connection.
                    return @{ value = @([pscustomobject]@{ displayName = "ExistingConnection"; id = "abc123" }) }
                } elseif ($Method -eq "PATCH") {
                    return "updated"
                }
            }

            Mock _GenerateCreateBody -MockWith {return @{}}
            Mock _GenerateUpdateBody -MockWith {return @{}}

            # Act
            $result = Assert-PBIShareableCloudConnection -DisplayName "ExistingConnection" `
                -ConnectionType "TestType" `
                -Parameters @{} `
                -ServicePrincipalClientId "client" `
                -ServicePrincipalSecret (ConvertTo-SecureString "secret" -AsPlainText -Force) `
                -TenantId "tenant" `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force)

            # Assert
            $result | Should -Be "updated"
            Assert-MockCalled -CommandName Invoke-RestMethod -ParameterFilter { $Method -eq "PATCH" } -Times 1
            Assert-MockCalled -CommandName Invoke-RestMethod -ParameterFilter { $Method -eq "GET" } -Times 1
            Assert-MockCalled -CommandName _GenerateCreateBody -Times 0
            Assert-MockCalled -CommandName _GenerateUpdateBody -Times 1
        }
    }

    Context "When no existing connection is found" {
        It "should create the connection via POST" {
            # Arrange: mock GET to return no connection and POST to return a test value.
            Mock -CommandName Invoke-RestMethod -MockWith {
                if ($Method -eq "GET") {
                    return @{ value = @() }
                } elseif ($Method -eq "POST") {
                    return "created"
                }
            }

            Mock _GenerateCreateBody -MockWith {return @{}}
            Mock _GenerateUpdateBody -MockWith {return @{}}

            # Act
            $result = Assert-PBIShareableCloudConnection -DisplayName "NewConnection" `
                -ConnectionType "NewType" `
                -Parameters @{} `
                -ServicePrincipalClientId "client" `
                -ServicePrincipalSecret (ConvertTo-SecureString "secret" -AsPlainText -Force) `
                -TenantId "tenant" `
                -AccessToken (ConvertTo-SecureString "token" -AsPlainText -Force)

            # Assert
            $result | Should -Be "created"
            Assert-MockCalled -CommandName Invoke-RestMethod -ParameterFilter { $Method -eq "POST" } -Times 1
            Assert-MockCalled -CommandName _GenerateCreateBody -Times 1
            Assert-MockCalled -CommandName _GenerateUpdateBody -Times 0
        }
    }
}