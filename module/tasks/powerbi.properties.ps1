# <copyright file="powerbi.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: Power BI properties for shared cloud connections.
$PowerBiConfig = "./pbiconfig/config.yaml"

# Synopsis: When true, runs the process in a 'report only' mode, where no actual changes are made
$PowerBiDryRunMode = $false

# Synopsis: When false, any error will abort the whole process, otherwise errors will be reported by processing will continue
$PowerBiContinueOnError = $true

# Synopsis: An array of wildcard expressions used to filter which cloud connections will be processed, based on their display name
$CloudConnectionFilters ??= @()

# Synopsis: The path to the directory containing the cloud connection configuration files
$CloudConnectionsConfigPath ??= ''