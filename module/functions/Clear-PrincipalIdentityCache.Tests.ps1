# <copyright file="Clear-PrincipalIdentityCache.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Clear-PrincipalIdentityCache" {

    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/Clear-PrincipalIdentityCache.ps1
        . $PSScriptRoot/_Resolve-IdentityNamesToPrincipals.ps1
        . $PSScriptRoot/Resolve-PrincipalIdentities.ps1
    }

    It "should clear the cache successfully" {
        # Arrange - populate cache first
        $identities = @("user@domain.com")
        $mockToken = ConvertTo-SecureString "mock-token" -AsPlainText -Force

        Mock -CommandName _Resolve-IdentityNamesToPrincipals -MockWith {
            return @(
                @{
                    emailAddress = "user@domain.com"
                    principalId = "test-id"
                    principalType = "User"
                }
            )
        }

        Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken -UseCache

        # Act
        Clear-PrincipalIdentityCache

        # Resolve again - should call API again if cache was cleared
        Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $mockToken -UseCache

        # Assert
        Assert-MockCalled -CommandName _Resolve-IdentityNamesToPrincipals -Times 2 # Called twice, so cache was cleared
    }
}