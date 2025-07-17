# <copyright file="powerbi.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: Power BI properties for shared cloud connections.
$powerBIconfig = "./pbiconfig/config.yaml"

# Synopsis: When true, runs the process in a 'report only' mode, where no actual changes are made; defaults to False
$PowerBiDryRunMode = $false

# Synopsis: When false, any error will abort the whole process, otherwise errors will be reported by processing will continue; defaults to True
$PowerBiContinueOnError = $true