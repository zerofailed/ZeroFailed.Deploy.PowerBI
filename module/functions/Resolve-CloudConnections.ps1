# PowerShell module for processing cloud connection configurations
using namespace System.Collections.Generic

function Get-YamlContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    try {
        $content = Get-Content -Path $Path -Raw
        $yaml = ConvertFrom-Yaml $content
        return $yaml
    }
    catch {
        throw "Error processing YAML file '$Path': $_"
    }
}

function Resolve-ServicePrincipal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ServicePrincipals,
        
        [Parameter(Mandatory)]
        [string]$Reference
    )

    if ($ServicePrincipals.ContainsKey($Reference)) {
        return $ServicePrincipals[$Reference]
    }
    throw "Service Principal reference '$Reference' not found"
}

function Resolve-ConnectionTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ConnectionTargets,
        
        [Parameter(Mandatory)]
        [string]$Reference
    )

    $type, $env = $Reference -split '\.'
    if ($ConnectionTargets.ContainsKey($type) -and $ConnectionTargets[$type].ContainsKey($env)) {
        return $ConnectionTargets[$type][$env]
    }
    throw "Connection Target reference '$Reference' not found"
}

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
                    $sp = Resolve-ServicePrincipal -ServicePrincipals $servicePrincipals -Reference $conn.useServicePrincipal
                    $denormalized.servicePrincipal = $sp
                }
                else {
                    $denormalized.servicePrincipal = $conn.servicePrincipal
                }

                # Resolve connection target
                if ($conn.target.useTarget) {
                    $target = Resolve-ConnectionTarget -ConnectionTargets $connectionTargets -Reference $conn.target.useTarget
                    $denormalized.target = $target
                }
                else {
                    $denormalized.target = $conn.target
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

function Export-CloudConnections {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [Parameter()]
        [string]$OutputPath
    )

    $connections = Resolve-CloudConnections -ConfigPath $ConfigPath

    if ($OutputPath) {
        $connections | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
    }
    else {
        return $connections
    }
}