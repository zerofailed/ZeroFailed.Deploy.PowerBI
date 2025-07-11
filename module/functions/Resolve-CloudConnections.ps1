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
