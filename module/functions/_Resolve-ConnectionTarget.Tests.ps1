# <copyright file="_Resolve-ConnectionTarget.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Describe '_Resolve-ConnectionTarget' {
    BeforeAll {
        # Dot source the function files
        . $PSScriptRoot/_Resolve-ConnectionTarget.ps1

        $connectionTargets = @{
            blobStorage = @{
                dev = @{
                    domain = 'blob.core.windows.net'
                    account = 'devstorageaccount'
                }
            }
        }
    }

    Context 'When resolving valid references' {
        It 'Should resolve existing connection target' {
            $result = _Resolve-ConnectionTarget -ConnectionTargets $connectionTargets -Reference 'blobStorage.dev'
            $result.domain | Should -Be 'blob.core.windows.net'
            $result.account | Should -Be 'devstorageaccount'
        }
    }

    Context 'When handling invalid references' {
        It 'Should throw on non-existent reference' {
            { _Resolve-ConnectionTarget -ConnectionTargets $connectionTargets -Reference 'nonexistent.env' } | Should -Throw
        }
    }
}