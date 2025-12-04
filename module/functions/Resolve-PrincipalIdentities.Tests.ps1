# <copyright file="Resolve-PrincipalIdentities.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Resolve-PrincipalIdentities" {

    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/Resolve-PrincipalIdentities.ps1
        . $PSScriptRoot/Clear-PrincipalIdentityCache.ps1
        . $PSScriptRoot/_Resolve-IdentityNamesToPrincipals.ps1
        
        Mock Write-Warning {}
    }

    BeforeEach {
        # Clear cache before each test
        Clear-PrincipalIdentityCache
    }

    Context "When resolving structured identities with explicit principalId and principalType" {
        It "should return the identity unchanged when principalId and principalType are provided" {
            # Arrange
            $identities = @(
                @{ principalId = "00000000-0000-0000-0000-000000000000"; principalType = "ServicePrincipal" },
                @{ principalId = "282de1ed-2c46-4b5b-ac1d-06bcf3b19128"; principalType = "Group" }
            )
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            # Act
            $result = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken

            # Assert
            $result | Should -HaveCount 2
            $result[0].principalId | Should -Be "00000000-0000-0000-0000-000000000000"
            $result[0].principalType | Should -Be "ServicePrincipal"
            $result[1].principalId | Should -Be "282de1ed-2c46-4b5b-ac1d-06bcf3b19128"
            $result[1].principalType | Should -Be "Group"
        }

        It "should warn about structured identities missing required properties" {
            # Arrange
            $identities = @(
                @{ principalId = "00000000-0000-0000-0000-000000000000" }, # Missing principalType
                @{ principalType = "User" } # Missing principalId
            )
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            # Act & Assert
            $result = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken
            $result | Should -HaveCount 0
        }
    }

    Context "When resolving email addresses" {
        It "should resolve email addresses to User principals" {
            # Arrange
            $identities = @("user@domain.com")
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName _Resolve-IdentityNamesToPrincipals -MockWith {
                return @(
                    @{
                        emailAddress = "user@domain.com"
                        principalId = "resolved-user-id"
                        principalType = "User"
                    }
                )
            }

            # Act
            [array]$result = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken

            # Assert
            $result | Should -HaveCount 1
            $result[0].principalId | Should -Be "resolved-user-id"
            $result[0].principalType | Should -Be "User"
            $result[0].originalIdentity | Should -Be "user@domain.com"
        }

        It "should resolve email addresses to Group principals when not found as User" {
            # Arrange
            $identities = @("group@domain.com")
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName _Resolve-IdentityNamesToPrincipals -MockWith {
                return @(
                    @{
                        emailAddress = "group@domain.com"
                        principalId = "resolved-group-id"
                        principalType = "Group"
                    }
                )
            }

            # Act
            [array]$result = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken

            # Assert
            $result | Should -HaveCount 1
            $result[0].principalId | Should -Be "resolved-group-id"
            $result[0].principalType | Should -Be "Group"
            $result[0].originalIdentity | Should -Be "group@domain.com"
        }

        It "should resolve email addresses to ServicePrincipal when not found as User or Group" {
            # Arrange
            $identities = @("sp@domain.com")
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName _Resolve-IdentityNamesToPrincipals -MockWith {
                return @(
                    @{
                        emailAddress = "sp@domain.com"
                        principalId = "resolved-sp-id"
                        principalType = "ServicePrincipal"
                    }
                )
            }

            # Act
            [array]$result = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken

            # Assert
            $result | Should -HaveCount 1
            $result[0].principalId | Should -Be "resolved-sp-id"
            $result[0].principalType | Should -Be "ServicePrincipal"
            $result[0].originalIdentity | Should -Be "sp@domain.com"
        }

        It "should warn when email address cannot be resolved" {
            # Arrange
            $identities = @("unknown@domain.com")
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName _Resolve-IdentityNamesToPrincipals -MockWith {
                return @()  # No resolutions found
            }

            # Act & Assert
            $result = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken
            $result | Should -HaveCount 0
        }
    }

    Context "When using caching" {
        It "should cache resolved identities and reuse them" {
            # Arrange
            $identities = @("user@domain.com", "user@domain.com") # Same email twice
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName _Resolve-IdentityNamesToPrincipals -MockWith {
                return @(
                    @{
                        emailAddress = "user@domain.com"
                        principalId = "resolved-user-id"
                        principalType = "User"
                    }
                    @{
                        emailAddress = "user@domain.com"
                        principalId = "resolved-user-id"
                        principalType = "User"
                    }
                )
            }

            # Act
            $result = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken -UseCache

            # Assert
            $result | Should -HaveCount 2
            Assert-MockCalled -CommandName _Resolve-IdentityNamesToPrincipals -Times 1 # Should only call once due to caching
            $result[0].principalId | Should -Be "resolved-user-id"
            $result[1].principalId | Should -Be "resolved-user-id"
        }

        It "should not use cache when UseCache is disabled" {
            # Arrange
            $identities = @("user@domain.com")
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName _Resolve-IdentityNamesToPrincipals -MockWith {
                return @(
                    @{
                        emailAddress = "user@domain.com"
                        principalId = "resolved-user-id"
                        principalType = "User"
                    }              
                )
            }

            # Act
            $result = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken -UseCache:$false
            
            $result2 = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken -UseCache:$false

            # Assert
            $result | Should -HaveCount 1
            $result2 | Should -HaveCount 1
            Assert-MockCalled -CommandName _Resolve-IdentityNamesToPrincipals -Times 2 # Should call twice without caching
        }
    }

    Context "When processing mixed identity types" {
        It "should handle both email addresses and structured objects" {
            # Arrange
            $identities = @(
                "user@domain.com",
                @{ principalId = "explicit-id"; principalType = "Group" }
            )
            $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

            Mock -CommandName _Resolve-IdentityNamesToPrincipals -MockWith {
                return @(
                    @{
                        emailAddress = "user@domain.com"
                        principalId = "resolved-user-id"
                        principalType = "User"
                    }
                )
            }

            # Act
            $result = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken

            # Assert
            $result | Should -HaveCount 2
            
            # Results should contain both resolved email and explicit identity
            $emailResult = $result | Where-Object { $_.originalIdentity -eq "user@domain.com" }
            $explicitResult = $result | Where-Object { $_.principalId -eq "explicit-id" }
            
            $emailResult.principalId | Should -Be "resolved-user-id"
            $emailResult.principalType | Should -Be "User"
            
            $explicitResult.principalId | Should -Be "explicit-id"
            $explicitResult.principalType | Should -Be "Group"
        }
    }
}