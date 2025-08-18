# <copyright file="Resolve-CloudConnections.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

using namespace System.Collections.Generic

<#
.SYNOPSIS
Resolves and denormalizes cloud connection configurations from YAML files.

.DESCRIPTION
This function reads a main configuration file, along with referenced service principals
and connection targets, to produce a denormalized list of cloud connection objects.
It handles the resolution of references and merges global settings into each connection.

.PARAMETER ConfigPath
The path to the main configuration YAML file (e.g., config.yaml).

.PARAMETER ConnectionFilter
An array of wildcard string expressions used to filter the connections that will be processed, based on their display name.

.OUTPUTS
Returns a list of denormalized cloud connection objects, each containing all resolved details.

.EXAMPLE
$connections = Resolve-CloudConnections -ConfigPath "C:\config\main.yaml"
foreach ($conn in $connections) {
    Write-Host "Connection: $($conn.displayName), Type: $($conn.type)"
}

.EXAMPLE
$connections = Resolve-CloudConnections -ConfigPath "C:\config\main.yaml" -ConnectionFilter SQL*DEV*
foreach ($conn in $connections) {
    Write-Host "Connection: $($conn.displayName), Type: $($conn.type)"
}
#>
function Resolve-CloudConnections {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [Parameter()]
        [string]$ConnectionsConfigPath = 'connections',

        [Parameter(Mandatory=$false)]
        [string[]]$ConnectionFilter
    )

    # Load main configuration
    try {
        if (Test-Path $ConfigPath -PathType Container) {
            # Assume the convention-based filename if only a directory has been provided
            $ConfigPath = Join-Path $ConfigPath 'config.yaml'
        }
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }
        $configDir = Split-Path $ConfigPath -Parent
        $config = Get-YamlContent -Path $ConfigPath

        # Load service principals
        $spPath = Join-Path $configDir $config.configurationFiles.servicePrincipals
        $servicePrincipals = (Get-YamlContent -Path $spPath).servicePrincipals

        # Load connection targets
        $ctPath = Join-Path $configDir $config.configurationFiles.connectionTargets
        $connectionTargets = (Get-YamlContent -Path $ctPath).connectionTargets

        # Process each connection group
        $denormalizedConnections = [List[object]]::new()

        # Resolve path to the connection configuration files
        if (![IO.Path]::IsPathRooted($ConnectionsConfigPath)) {
            $ConnectionsConfigPath = Join-Path (Split-Path -Parent $ConfigPath) $ConnectionsConfigPath
        }
        $ConnectionsConfigPath = Resolve-Path $ConnectionsConfigPath

        # Look for connection config files in the specified directory
        Write-Information "Looking for connection configuration files under '$ConnectionsConfigPath'" -InformationAction Continue
        [array]$connectionConfigFiles = Get-ChildItem -Path $ConnectionsConfigPath -Filter *.yaml -Recurse

        if (!$connectionConfigFiles) {
            Write-Warning "No connection configuration files found under '$ConnectionsConfigPath'"
            return
        }

        Write-Information "Found $($connectionConfigFiles.Count) file(s)" -InformationAction Continue
        
        # Filter connections if ConnectionFilter is provided
        $connectionsToProcess = [List[object]]::new()
        foreach ($connectionConfigFile in $connectionConfigFiles) {
            # TODO: Extract this logic to a private function
            
            # Parse the contents of each YAML file in the group
            $connectionsInGroup = (Get-YamlContent -Path $connectionConfigFile).cloudConnections
            
            if ($PSBoundParameters.ContainsKey('ConnectionFilter') -and $ConnectionFilter.Count -gt 0) {
                foreach ($conn in $connectionsInGroup) {
                    $displayName = $conn.displayName
                    $matched = $false
                    foreach ($filterPattern in $ConnectionFilter) {
                        if ($displayName -like $filterPattern) {
                            $matched = $true
                            break
                        }
                    }
                    if ($matched) {
                        $connectionsToProcess.Add($conn)
                    }
                }                
            } else {
                $connectionsToProcess.AddRange($connectionsInGroup)
            }
        }

        if ($connectionsToProcess.Count -eq 0) {
            Write-Warning "No connections matched the provided filter(s): $($ConnectionFilter -join ', ')"
        }

        # Process each connection in the group
        foreach ($conn in $connectionsToProcess) {
            $denormalized = @{
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
                    # TODO: Extract this logic to private function
                    
                    # Convert target array to hashtable for O(1) lookup and direct manipulation
                    $targetParams = @{}
                    foreach ($param in $denormalized.target) {
                        $targetParams[$param.name] = $param
                    }
                    
                    # Process parameter overrides with direct hashtable operations
                    foreach ($paramOverride in $conn.target.parameters) {
                        if (!$paramOverride.ContainsKey('name') -or !$paramOverride.ContainsKey('value')) {
                            throw "A parameter override for the '$($conn.displayName)' connection is missing at least one required key: name, value"
                        }
                        
                        if ($targetParams.ContainsKey($paramOverride.name)) {
                            # Update existing parameter value directly
                            $targetParams[$paramOverride.name].value = $paramOverride.value
                        } else {
                            # Add new parameter directly to hashtable
                            $targetParams[$paramOverride.name] = $paramOverride
                        }
                    }
                    
                    # Convert back to array in one operation
                    $denormalized.target = $targetParams.Values
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

        return $denormalizedConnections
    }
    catch {
        Write-Error 'Error whilst processing cloud connection configuration files' -ErrorAction Continue
        Write-Verbose "Exception Stack Trace: $($_.ScriptStackTrace)"
        throw $_
    }
}
