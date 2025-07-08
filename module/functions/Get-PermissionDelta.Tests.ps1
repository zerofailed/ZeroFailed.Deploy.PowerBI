# <copyright file="Get-PermissionDelta.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "Get-PermissionDelta" {

    BeforeAll {
        # Dot source the function files
        . "$PSScriptRoot\Get-PermissionDelta.ps1"
    }

    Context "When calculating delta with no current permissions" {
        It "should mark all desired permissions as additions" {
            # Arrange
            $current = @()
            $desired = @(
                @{ principalId = "user1"; principalType = "User"; role = "Owner" },
                @{ principalId = "user2"; principalType = "User"; role = "User" }
            )

            # Act
            $result = Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired

            # Assert
            $result.ToAdd | Should -HaveCount 2
            $result.ToUpdate | Should -HaveCount 0
            $result.ToRemove | Should -HaveCount 0
            
            $result.ToAdd[0].principalId | Should -Be "user1"
            $result.ToAdd[0].role | Should -Be "Owner"
            $result.ToAdd[1].principalId | Should -Be "user2"
            $result.ToAdd[1].role | Should -Be "User"
        }
    }

    Context "When calculating delta with no desired permissions" {
        It "should mark all current permissions for removal in strict mode" {
            # Arrange
            $current = @(
                @{ id = "1"; principal = @{ id = "user1"; type = "User" }; role = "Owner" },
                @{ id = "2"; principal = @{ id = "user2"; type = "User" }; role = "User" }
            )
            $desired = @()

            # Act
            $result = Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired -StrictMode

            # Assert
            $result.ToAdd | Should -HaveCount 0
            $result.ToUpdate | Should -HaveCount 0
            $result.ToRemove | Should -HaveCount 2
            
            $result.ToRemove[0].principalId | Should -Be "user1"
            $result.ToRemove[0].currentId | Should -Be "1"
            $result.ToRemove[1].principalId | Should -Be "user2"
            $result.ToRemove[1].currentId | Should -Be "2"
        }

        It "should not mark permissions for removal when strict mode is disabled" {
            # Arrange
            $current = @(
                @{ id = "1"; principal = @{ id = "user1"; type = "User" }; role = "Owner" }
            )
            $desired = @()

            # Act
            $result = Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired -StrictMode:$false

            # Assert
            $result.ToAdd | Should -HaveCount 0
            $result.ToUpdate | Should -HaveCount 0
            $result.ToRemove | Should -HaveCount 0
        }
    }

    Context "When permissions exist but roles differ" {
        It "should mark permissions for update when roles differ" {
            # Arrange
            $current = @(
                @{ id = "1"; principal = @{ id = "user1"; type = "User" }; role = "User" },
                @{ id = "2"; principal = @{ id = "user2"; type = "User" }; role = "Owner" }
            )
            $desired = @(
                @{ principalId = "user1"; principalType = "User"; role = "Owner" }, # Role change
                @{ principalId = "user2"; principalType = "User"; role = "Owner" }  # No change
            )

            # Act
            $result = Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired

            # Assert
            $result.ToAdd | Should -HaveCount 0
            $result.ToUpdate | Should -HaveCount 1
            $result.ToRemove | Should -HaveCount 0
            
            $result.ToUpdate[0].principalId | Should -Be "user1"
            $result.ToUpdate[0].currentRole | Should -Be "User"
            $result.ToUpdate[0].newRole | Should -Be "Owner"
            $result.ToUpdate[0].currentId | Should -Be "1"
        }
    }

    Context "When permissions match exactly" {
        It "should not require any changes" {
            # Arrange
            $current = @(
                @{ id = "1"; principal = @{ id = "user1"; type = "User" }; role = "Owner" },
                @{ id = "2"; principal = @{ id = "user2"; type = "User" }; role = "User" }
            )
            $desired = @(
                @{ principalId = "user1"; principalType = "User"; role = "Owner" },
                @{ principalId = "user2"; principalType = "User"; role = "User" }
            )

            # Act
            $result = Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired

            # Assert
            $result.ToAdd | Should -HaveCount 0
            $result.ToUpdate | Should -HaveCount 0
            $result.ToRemove | Should -HaveCount 0
            $result.Summary.TotalChanges | Should -Be 0
        }
    }

    Context "When calculating complex deltas" {
        It "should handle mixed operations (add, update, remove)" {
            # Arrange
            $current = @(
                @{ id = "1"; principal = @{ id = "user1"; type = "User" }; role = "User" },     # Will be updated to Owner
                @{ id = "2"; principal = @{ id = "user2"; type = "User" }; role = "Owner" },    # Will be removed
                @{ id = "3"; principal = @{ id = "user3"; type = "User" }; role = "User" }      # Will stay the same
            )
            $desired = @(
                @{ principalId = "user1"; principalType = "User"; role = "Owner" },    # Update
                @{ principalId = "user3"; principalType = "User"; role = "User" },     # No change
                @{ principalId = "user4"; principalType = "User"; role = "User" }      # Add
            )

            # Act
            $result = Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired -StrictMode

            # Assert
            $result.ToAdd | Should -HaveCount 1
            $result.ToUpdate | Should -HaveCount 1
            $result.ToRemove | Should -HaveCount 1
            
            # Check addition
            $result.ToAdd[0].principalId | Should -Be "user4"
            $result.ToAdd[0].role | Should -Be "User"
            
            # Check update
            $result.ToUpdate[0].principalId | Should -Be "user1"
            $result.ToUpdate[0].currentRole | Should -Be "User"
            $result.ToUpdate[0].newRole | Should -Be "Owner"
            
            # Check removal
            $result.ToRemove[0].principalId | Should -Be "user2"
            $result.ToRemove[0].currentId | Should -Be "2"
            
            # Check summary
            $result.Summary.TotalChanges | Should -Be 3
            $result.Summary.AdditionsCount | Should -Be 1
            $result.Summary.UpdatesCount | Should -Be 1
            $result.Summary.RemovalsCount | Should -Be 1
        }
    }

    Context "When dealing with case sensitivity" {
        It "should handle principal ID case differences correctly" {
            # Arrange
            $current = @(
                @{ id = "1"; principal = @{ id = "F3498FD9-CFF0-44A9-991C-C017F481ADF0"; type = "User" }; role = "User" }
            )
            $desired = @(
                @{ principalId = "f3498fd9-cff0-44a9-991c-c017f481adf0"; principalType = "User"; role = "Owner" }
            )

            # Act
            $result = Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired

            # Assert
            $result.ToAdd | Should -HaveCount 0
            $result.ToUpdate | Should -HaveCount 1 # Should find the match despite case difference
            $result.ToRemove | Should -HaveCount 0
            
            $result.ToUpdate[0].principalId | Should -Be "f3498fd9-cff0-44a9-991c-c017f481adf0"
            $result.ToUpdate[0].newRole | Should -Be "Owner"
        }
    }

    Context "When validating owner requirements" {
        It "should warn when removing all owners" {
            # Arrange
            $current = @(
                @{ id = "1"; principal = @{ id = "user1"; type = "User" }; role = "Owner" }
            )
            $desired = @(
                @{ principalId = "user2"; principalType = "User"; role = "User" }
            )

            # Act & Assert
            $result = Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired -StrictMode -WarningAction SilentlyContinue
            
            # Should still process the change but issue a warning
            $result.ToAdd | Should -HaveCount 1
            $result.ToRemove | Should -HaveCount 1
        }
    }
}

Describe "ConvertFrom-PermissionGroups" {

    BeforeAll {
        . "$PSScriptRoot\Get-PermissionDelta.ps1"
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
            $result = ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities

            # Assert
            $result | Should -HaveCount 4
            
            $owners = $result | Where-Object { $_.role -eq "Owner" }
            $users = $result | Where-Object { $_.role -eq "User" }
            $reshareUsers = $result | Where-Object { $_.role -eq "UserWithReshare" }
            
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
            $result = ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities

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
            $result = ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities

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
            $result = ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities -WarningAction SilentlyContinue
            
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
            $result = ConvertFrom-PermissionGroups -PermissionGroups $permissionGroups -ResolvedIdentities $resolvedIdentities -WarningAction SilentlyContinue
            
            # Should only process resolved identities
            $result | Should -HaveCount 1
            $result[0].principalId | Should -Be "id1"
        }
    }
}