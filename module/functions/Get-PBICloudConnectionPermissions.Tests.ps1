# <copyright file="Get-PBICloudConnectionPermissions.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Get-PBICloudConnectionPermissions" {
    
    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/Get-PBICloudConnectionPermissions.ps1

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

    Context "When retrieving permissions successfully" {
        It "should make GET request to correct endpoint and return permissions" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Invoke-RestMethodWithRateLimit -MockWith {
                return @{
                    value = @(
                        @{ id = "1"; principal = @{ id = "user1"; type = "User" }; role = "Owner" },
                        @{ id = "2"; principal = @{ id = "user2"; type = "User" }; role = "User" }
                    )
                }
            }

            # Act
            $result = Get-PBICloudConnectionPermissions -CloudConnectionId $cloudConnectionId -AccessToken $mockToken

            # Assert
            Should -Invoke Invoke-RestMethodWithRateLimit -ParameterFilter {
                $Splat.Uri -eq "https://api.fabric.microsoft.com/v1/connections/$cloudConnectionId/roleAssignments" -and
                $Splat.Method -eq "GET" -and
                $Splat.Headers.Authorization -eq "Bearer mock-token"
            } -Times 1

            $result | Should -HaveCount 2
            $result[0].id | Should -Be "1"
            $result[1].id | Should -Be "2"
        }
    }

    Context "When API call fails" {
        It "should throw an error with details" {
            # Arrange
            $cloudConnectionId = "test-connection-id"
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName Invoke-RestMethodWithRateLimit -MockWith {
                throw "API Error"
            }

            # Act & Assert
            { Get-PBICloudConnectionPermissions -CloudConnectionId $cloudConnectionId -AccessToken $mockToken } | Should -Throw "*API Error*"
        }
    }
}