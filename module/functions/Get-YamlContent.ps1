# <copyright file="Get-YamlContent.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Reads a YAML file and converts its content to a PowerShell object.

.DESCRIPTION
This function provides a convenient way to parse YAML configuration files
into PowerShell objects, making it easy to access structured data. It performs
a path check and includes error handling for file access or parsing issues.

.PARAMETER Path
The full or relative path to the YAML file.

.OUTPUTS
Returns a PowerShell object representing the YAML content.

.EXAMPLE
$config = Get-YamlContent -Path "C:\config.yaml"
$value = $config.someKey.nestedValue
#>

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