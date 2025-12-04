---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 11/27/2025
PlatyPS schema version: 2024-05-01
title: Remove-PBICloudConnectionPermissionBatch
---

# Remove-PBICloudConnectionPermissionBatch

## SYNOPSIS

Removes multiple permissions from a Power BI shareable cloud connection in batch.

## SYNTAX

### __AllParameterSets

```
Remove-PBICloudConnectionPermissionBatch [-CloudConnectionId] <string> [-RoleAssignments] <Object[]>
 [-AccessToken] <securestring> [[-DelayBetweenRequestsMs] <int>] [[-BatchSize] <int>]
 [-ContinueOnError] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function removes multiple role assignments from a Power BI shareable cloud connection.
It processes removals sequentially with error handling and optional retry logic.

## EXAMPLES

### EXAMPLE 1

$assignmentsToRemove = @(
    @{ id = "assignment1"; principalId = "user1" },
    @{ id = "assignment2"; principalId = "user2" }
)

$result = Remove-PBICloudConnectionPermissionBatch `
    -CloudConnectionId "connection-id" `
    -RoleAssignments $assignmentsToRemove `
    -AccessToken $token.Token `
    -ContinueOnError

### EXAMPLE 2

# With throttling to prevent rate limits
$result = Remove-PBICloudConnectionPermissionBatch `
    -CloudConnectionId "connection-id" `
    -RoleAssignments $assignmentsToRemove `
    -AccessToken $token.Token `
    -DelayBetweenRequestsMs 500 `
    -BatchSize 10

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

### -BatchSize

Optional batch size for processing requests. When specified, introduces a pause between batches.

```yaml
Type: System.Int32
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: false
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

### -ContinueOnError

Switch to continue processing remaining removals even if some fail.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
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

### -DelayBetweenRequestsMs

Optional delay in milliseconds between individual API requests to prevent rate limiting.

```yaml
Type: System.Int32
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RoleAssignments

Array of role assignment objects to remove.
Each object should contain at least an 'id' property.

```yaml
Type: System.Object[]
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

### System.Collections.Hashtable

Returns a hashtable with success and failure counts

## NOTES

## RELATED LINKS

- []()
