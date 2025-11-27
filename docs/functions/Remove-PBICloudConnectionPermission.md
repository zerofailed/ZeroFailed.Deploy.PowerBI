---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 11/27/2025
PlatyPS schema version: 2024-05-01
title: Remove-PBICloudConnectionPermission
---

# Remove-PBICloudConnectionPermission

## SYNOPSIS

Removes a specific permission from a Power BI shareable cloud connection.

## SYNTAX

### __AllParameterSets

```
Remove-PBICloudConnectionPermission [-CloudConnectionId] <string> [-RoleAssignmentId] <string>
 [-AccessToken] <securestring> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function removes a role assignment from a Power BI shareable cloud connection using the
Fabric API.
It's designed to work with the permission synchronization system to remove
unauthorized or outdated permissions.

## EXAMPLES

### EXAMPLE 1

Remove-PBICloudConnectionPermission `
    -CloudConnectionId "a60de636-56cf-4775-8217-76bb5b33bbb3" `
    -RoleAssignmentId "assignment-id-here" `
    -AccessToken $token.Token

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
  Position: 2
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

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RoleAssignmentId

The ID of the role assignment to remove.
This is obtained from the existing permissions list.

```yaml
Type: System.String
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

### -WhatIf

Runs the command in a mode that only reports what would happen without performing the actions.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
ParameterSets:
- Name: (All)
  Position: Named
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

### System.Object

Returns the response from the Fabric API call.

## NOTES

## RELATED LINKS

- []()
