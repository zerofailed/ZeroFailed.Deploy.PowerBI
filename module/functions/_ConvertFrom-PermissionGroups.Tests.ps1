# <copyright file="_ConvertFrom-PermissionGroups.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "_ConvertFrom-PermissionGroups" {

    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/_ConvertFrom-PermissionGroups.ps1
        Mock Write-Warning {}
    }

    Context "When converting permission groups to flat permission list" {
        It "should convert all permission groups correctly" {
            # Arrange
            $permissionGroups = @{
                owners = @("user1@domain.com")
                users = @("user2@domain.com", "user3@domain.com")
                reshareUsers = @("user4@domain.com")
            }
            
            $resolvedIdentities = @(
                @{ originalIdentity = "user1@domain.com"; principalId = "id1"; principalType = "User" },
                @{ originalIdentity = "user2@domain.com"; principalId = "id2"; principalType = "User" },
                @{ originalIdentity = "user3@domain.com"; principalId = "id3"; principalType = "User" },
                @{ originalIdentity = "user4@domain.com"; principalId = "id4"; principalType = "User" }
            )

            # Act
            $result = _ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities

            # Assert
            $result | Should -HaveCount 4
            
            [array]$owners = $result | Where-Object { $_.role -eq "Owner" }
            [array]$users = $result | Where-Object { $_.role -eq "User" }
            [array]$reshareUsers = $result | Where-Object { $_.role -eq "UserWithReshare" }
            
            $owners | Should -HaveCount 1
            $users | Should -HaveCount 2
            $reshareUsers | Should -HaveCount 1
            
            $owners[0].principalId | Should -Be "id1"
            $users[0].principalId | Should -BeIn @("id2", "id3")
            $users[1].principalId | Should -BeIn @("id2", "id3")
            $reshareUsers[0].principalId | Should -Be "id4"
        }

        It "should handle mixed identity types (emails and structured objects)" {
            # Arrange
            $permissionGroups = @{
                owners = @(
                    "user1@domain.com",
                    @{ principalId = "explicit-id"; principalType = "ServicePrincipal" }
                )
            }
            
            $resolvedIdentities = @(
                @{ originalIdentity = "user1@domain.com"; principalId = "id1"; principalType = "User" },
                @{ originalIdentity = "explicit-id:ServicePrincipal"; principalId = "explicit-id"; principalType = "ServicePrincipal" }
            )

            # Act
            $result = _ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities

            # Assert
            $result | Should -HaveCount 2
            $result[0].role | Should -Be "Owner"
            $result[1].role | Should -Be "Owner"
            
            $principalIds = $result | Select-Object -ExpandProperty principalId
            $principalIds | Should -Contain "id1"
            $principalIds | Should -Contain "explicit-id"
        }

        It "should handle empty permission groups" {
            # Arrange
            $permissionGroups = @{
                owners = @()
                users = @("user1@domain.com")
                reshareUsers = $null
            }
            
            $resolvedIdentities = @(
                @{ originalIdentity = "user1@domain.com"; principalId = "id1"; principalType = "User" }
            )

            # Act
            [array]$result = _ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities

            # Assert
            $result | Should -HaveCount 1
            $result[0].role | Should -Be "User"
            $result[0].principalId | Should -Be "id1"
        }

        It "should warn about unknown permission groups" {
            # Arrange
            $permissionGroups = @{
                owners = @("user1@domain.com")
                unknownGroup = @("user2@domain.com")
            }
            
            $resolvedIdentities = @(
                @{ originalIdentity = "user1@domain.com"; principalId = "id1"; principalType = "User" }
            )

            # Act & Assert
            [array]$result = _ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities
            
            # Should only process known groups
            $result | Should -HaveCount 1
            $result[0].role | Should -Be "Owner"
        }

        It "should warn about unresolved identities" {
            # Arrange
            $permissionGroups = @{
                owners = @("user1@domain.com", "unknown@domain.com")
            }
            
            $resolvedIdentities = @(
                @{ originalIdentity = "user1@domain.com"; principalId = "id1"; principalType = "User" }
                # Missing resolution for unknown@domain.com
            )

            # Act & Assert
            [array]$result = _ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities
            
            # Should only process resolved identities
            $result | Should -HaveCount 1
            $result[0].principalId | Should -Be "id1"
        }
    }
}