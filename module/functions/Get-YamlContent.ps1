# <copyright file="Get-YamlContent.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Get-YamlContent {
    [CmdletBinding()]
    [OutputType([System.Object])]
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