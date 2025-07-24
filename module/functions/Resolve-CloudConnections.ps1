# <copyright file="Resolve-CloudConnections.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Resolves and denormalizes cloud connection configurations from YAML files.

.DESCRIPTION
This function reads a main configuration file, along with referenced service principals
and connection targets, to produce a denormalized list of cloud connection objects.
It handles the resolution of references and merges global settings into each connection.

.PARAMETER ConfigPath
The path to the main configuration YAML file (e.g., config.yaml).

.OUTPUTS
Returns a list of denormalized cloud connection objects, each containing all resolved details.

.EXAMPLE
$connections = Resolve-CloudConnections -ConfigPath "C:\config\main.yaml"
foreach ($conn in $connections) {
    Write-Host "Connection: $($conn.displayName), Type: $($conn.type)"
}
#>

# PowerShell module for processing cloud connection configurations
using namespace System.Collections.Generic


function Resolve-CloudConnections {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    # Load main configuration
    try {
        $configDir = Split-Path $ConfigPath -Parent
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }
        $config = Get-YamlContent -Path $ConfigPath

        # Load service principals
        $spPath = Join-Path $configDir $config.configurationFiles.servicePrincipals
        $servicePrincipals = (Get-YamlContent -Path $spPath).servicePrincipals

        # Load connection targets
        $ctPath = Join-Path $configDir $config.configurationFiles.connectionTargets
        $connectionTargets = (Get-YamlContent -Path $ctPath).connectionTargets

        # Process each connection group
        $denormalizedConnections = [List[object]]::new()

        foreach ($group in $config.configurationFiles.connections) {
            $groupName = $group.Keys[0]
            $groupPath = Join-Path $configDir $group.Values[0]
            $connections = (Get-YamlContent -Path $groupPath).cloudConnections

            # Process each connection in the group
            foreach ($conn in $connections) {
                $denormalized = @{
                    groupName = $groupName
                    displayName = $conn.displayName
                    type = $conn.type
                }

                # Resolve service principal
                if ($conn.useServicePrincipal) {
                    $sp = _Resolve-ServicePrincipal -ServicePrincipals $servicePrincipals -Reference $conn.useServicePrincipal
                    $denormalized.servicePrincipal = $sp
                }
                else {
                    $denormalized.servicePrincipal = $conn.servicePrincipal
                }

                # Apply the default tenant ID if one hasn't been specified
                if (!$denormalized.servicePrincipal.ContainsKey('tenantId') -or [string]::IsNullOrEmpty($denormalized.servicePrincipal['tenantId'])) {
                    Write-Verbose "Applying default tenant ID to service principal: $($denormalized.servicePrincipal)"
                    $denormalized.servicePrincipal['tenantId'] = $config.settings.defaultTenantId
                }

                # Resolve connection target
                if ($conn.target.useTarget) {
                    $target = _Resolve-ConnectionTarget -ConnectionTargets $connectionTargets -Reference $conn.target.useTarget
                    $denormalized.target = $target
                    # Override connection target properties (e.g. the database name on a SQL connection)
                    if ($conn.target.ContainsKey('parameters')) {
                        # Create a hashtable for efficient parameter lookup
                        $targetLookup = @{}
                        for ($i = 0; $i -lt $denormalized.target.Count; $i++) {
                            $targetLookup[$denormalized.target[$i].name] = $i
                        }
                        
                        # Process parameter overrides efficiently
                        $newParameters = [System.Collections.Generic.List[object]]::new()
                        foreach ($paramOverride in $conn.target.parameters) {
                            if ($targetLookup.ContainsKey($paramOverride.name)) {
                                # Update existing parameter value
                                $denormalized.target[$targetLookup[$paramOverride.name]].value = $paramOverride.value
                            }
                            else {
                                # Add new parameter to the list for later addition
                                $newParameters.Add($paramOverride)
                            }
                        }
                        
                        # Add all new parameters at once
                        if ($newParameters.Count -gt 0) {
                            $denormalized.target += $newParameters.ToArray()
                        }
                    }
                }
                else {
                    $denormalized.target = $conn.target.parameters
                }

                # Copy permissions
                $denormalized.permissions = $conn.permissions

                # Add global settings
                $denormalized.settings = $config.settings

                $denormalizedConnections.Add([PSCustomObject]$denormalized)
            }
        }

        return $denormalizedConnections
    }
    catch {
        throw "Error processing cloud connections: $_"
    }
}
