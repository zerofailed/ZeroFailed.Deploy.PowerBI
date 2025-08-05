# <copyright file="_Get-PermissionDelta.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe "_Get-PermissionDelta" {

    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/_Get-PermissionDelta.ps1
        . $PSScriptRoot/Get-PBICloudConnectionPermissions.ps1

        Mock Write-Warning {}
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
            $result = _Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired

            # Assert
            $result.ToAdd | Should -HaveCount 2
            $result.ToUpdate | Should -HaveCount 0
            $result.ToRemove | Should -HaveCount 0
            
            $result.ToAdd.principalId | Should -Contain "user1"
            $result.ToAdd | Where-Object { $_.principalId -eq 'user1' } | Select-Object -ExpandProperty role | Should -Be "Owner"
            $result.ToAdd.principalId | Should -Contain "user2"
            $result.ToAdd | Where-Object { $_.principalId -eq 'user2' } | Select-Object -ExpandProperty role | Should -Be "User"
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
            $result = _Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired -StrictMode

            # Assert
            $result.ToAdd | Should -HaveCount 0
            $result.ToUpdate | Should -HaveCount 0
            $result.ToRemove | Should -HaveCount 2
            
            $result.ToRemove[0].principalId | Should -Be "user1"
            $result.ToRemove[0].id | Should -Be "1"
            $result.ToRemove[1].principalId | Should -Be "user2"
            $result.ToRemove[1].id | Should -Be "2"
        }

        It "should not mark permissions for removal when strict mode is disabled" {
            # Arrange
            $current = @(
                @{ id = "1"; principal = @{ id = "user1"; type = "User" }; role = "Owner" }
            )
            $desired = @()

            # Act
            $result = _Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired -StrictMode:$false

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
            $result = _Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired

            # Assert
            $result.ToAdd | Should -HaveCount 0
            $result.ToUpdate | Should -HaveCount 1
            $result.ToRemove | Should -HaveCount 0
            
            $result.ToUpdate[0].principalId | Should -Be "user1"
            $result.ToUpdate[0].currentRole | Should -Be "User"
            $result.ToUpdate[0].newRole | Should -Be "Owner"
            $result.ToUpdate[0].id | Should -Be "1"
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
            $result = _Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired

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
            $result = _Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired -StrictMode

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
            $result.ToRemove[0].id | Should -Be "2"
            
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
            $result = _Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired

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
            $result = _Get-PermissionDelta -CurrentPermissions $current -DesiredPermissions $desired -StrictMode
            
            # Should still process the change but issue a warning
            $result.ToAdd | Should -HaveCount 1
            $result.ToRemove | Should -HaveCount 1
        }
    }
}
