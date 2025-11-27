# <copyright file="Remove-PBICloudConnectionPermissionBatch.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Remove-PBICloudConnectionPermissionBatch
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory=$true)]
        [string] $CloudConnectionId,
        
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [object[]] $RoleAssignments,
        
        [Parameter(Mandatory=$true)]
        [securestring] $AccessToken,
        
        [Parameter()]
        [switch] $ContinueOnError,
        
        [Parameter()]
        [int] $DelayBetweenRequestsMs = 0,
        
        [Parameter()]
        [int] $BatchSize = 0
    )

    Write-Information "Removing $($RoleAssignments.Count) role assignments from cloud connection $CloudConnectionId"
    
    if ($DelayBetweenRequestsMs -gt 0) {
        Write-Information "Using throttling: $DelayBetweenRequestsMs ms delay between requests"
    }
    
    if ($BatchSize -gt 0) {
        Write-Information "Processing in batches of $BatchSize assignments"
    }

    $successCount = 0
    $failureCount = 0
    $failures = @()
    $requestCount = 0

    foreach ($assignment in $RoleAssignments) {
        try {
            if (-not $assignment.id) {
                Write-Warning "Role assignment missing ID property, skipping: $($assignment | ConvertTo-Json -Compress)"
                $failureCount++
                continue
            }

            $principalInfo = if ($assignment.principalId) { " (Principal: $($assignment.principalId))" } else { "" }
            Write-Verbose "Removing role assignment $($assignment.id)$principalInfo"

            if ($PSCmdlet.ShouldProcess("role assignment $($assignment.id)$principalInfo")) {
                $result = Remove-PBICloudConnectionPermission `
                    -CloudConnectionId $CloudConnectionId `
                    -RoleAssignmentId $assignment.id `
                    -AccessToken $AccessToken
            }

            $successCount++
            $requestCount++
            Write-Verbose "Successfully removed role assignment $($assignment.id)"
            
            # Apply throttling if configured
            if ($DelayBetweenRequestsMs -gt 0 -and $requestCount -lt $RoleAssignments.Count) {
                Write-Verbose "Applying throttling delay: $DelayBetweenRequestsMs ms"
                Start-Sleep -Milliseconds $DelayBetweenRequestsMs
            }
            
            # Apply batch processing pause if configured  
            if ($BatchSize -gt 0 -and ($requestCount % $BatchSize) -eq 0 -and $requestCount -lt $RoleAssignments.Count) {
                Write-Information "Processed batch of $BatchSize requests. Brief pause before next batch..."
                Start-Sleep -Seconds 2
            }

        } catch {
            $failureCount++
            $failure = @{
                RoleAssignmentId = $assignment.id
                PrincipalId = $assignment.principalId
                Error = $_.Exception.Message
            }
            $failures += $failure
            
            Write-ErrorLogMessage "Failed to remove role assignment $($assignment.id): $($_.Exception.Message)"
            Write-Verbose ($_.ScriptStackTrace -split [environment]::NewLine | Select -First 1) -Verbose
            if (-not $ContinueOnError) {
                throw "Stopping batch removal due to error and ContinueOnError is false"
            }
        }
    }

    $result = @{
        TotalRequested = $RoleAssignments.Count
        SuccessCount = $successCount
        FailureCount = $failureCount
        Failures = $failures
        IsCompleteSuccess = ($failureCount -eq 0)
    }

    Write-Information "Batch removal completed: $successCount successful, $failureCount failed"
    
    if ($failures.Count -gt 0) {
        Write-Warning "Failed to remove $($failures.Count) role assignments:"
        foreach ($failure in $failures) {
            Write-Warning "  - Assignment $($failure.RoleAssignmentId): $($failure.Error)"
        }
    }

    return $result
}