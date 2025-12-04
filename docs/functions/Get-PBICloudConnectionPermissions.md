---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 11/27/2025
PlatyPS schema version: 2024-05-01
title: Get-PBICloudConnectionPermissions
---

# Get-PBICloudConnectionPermissions

## SYNOPSIS

Retrieves the current permissions for a specified Power BI shareable cloud connection.

## SYNTAX

### __AllParameterSets

```
Get-PBICloudConnectionPermissions [-CloudConnectionId] <string> [-AccessToken] <securestring>
 [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function makes a GET request to the Power BI Fabric API to fetch all role assignments
(permissions) associated with a given cloud connection ID.
It is typically used as part of
a synchronization process to understand the current state of permissions.

## EXAMPLES

### EXAMPLE 1

$permissions = Get-PBICloudConnectionPermissions `
    -CloudConnectionId "a60de636-56cf-4775-8217-76bb5b33bbb3" `
    -AccessToken $fabricToken.Token

## PARAMETERS

### -AccessToken

Secure string containing a valid access token for the Fabric API.

```yaml
Type: System.Security.SecureString
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -CloudConnectionId

The ID of the Power BI shareable cloud connection.

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

### System.String

Returns a JSON-formatted array of permission objects.

## NOTES

## RELATED LINKS

- []()
