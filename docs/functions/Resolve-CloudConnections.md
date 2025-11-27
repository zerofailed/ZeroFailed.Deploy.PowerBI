---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 11/27/2025
PlatyPS schema version: 2024-05-01
title: Resolve-CloudConnections
---

# Resolve-CloudConnections

## SYNOPSIS

Resolves and denormalizes cloud connection configurations from YAML files.

## SYNTAX

### __AllParameterSets

```
Resolve-CloudConnections [-ConfigPath] <string> [[-ConnectionsConfigPath] <string>]
 [[-ConnectionFilter] <string[]>] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function reads a main configuration file, along with referenced service principals
and connection targets, to produce a denormalized list of cloud connection objects.
It handles the resolution of references and merges global settings into each connection.

## EXAMPLES

### EXAMPLE 1

$connections = Resolve-CloudConnections -ConfigPath "C:\config\main.yaml"
foreach ($conn in $connections) {
    Write-Host "Connection: $($conn.displayName), Type: $($conn.type)"
}

### EXAMPLE 2

$connections = Resolve-CloudConnections -ConfigPath "C:\config\main.yaml" -ConnectionFilter SQL*DEV*
foreach ($conn in $connections) {
    Write-Host "Connection: $($conn.displayName), Type: $($conn.type)"
}

## PARAMETERS

### -ConfigPath

The path to the main configuration YAML file (e.g., config.yaml).

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ConnectionFilter

An array of wildcard string expressions used to filter the connections that will be processed, based on their display name.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ConnectionsConfigPath

The path where the connection configuration files are stored.

```yaml
Type: System.String
DefaultValue: connections
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Array

Returns a list of cloud connection objects, denormalized to contain all the associated configuration.

## NOTES

## RELATED LINKS

- []()
