---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 11/27/2025
PlatyPS schema version: 2024-05-01
title: Get-YamlContent
---

# Get-YamlContent

## SYNOPSIS

Reads a YAML file and converts its content to a PowerShell object.

## SYNTAX

### __AllParameterSets

```
Get-YamlContent [-Path] <string> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function provides a convenient way to parse YAML configuration files
into PowerShell objects, making it easy to access structured data.
It performs a path check and includes error handling for file access or parsing issues.

## EXAMPLES

### EXAMPLE 1

$config = Get-YamlContent -Path "C:\config.yaml"
$value = $config.someKey.nestedValue

## PARAMETERS

### -Path

The full or relative path to the YAML file.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object

Returns a PowerShell object representing the YAML content.

## NOTES

## RELATED LINKS

- []()
