---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 11/27/2025
PlatyPS schema version: 2024-05-01
title: Assert-PBICloudConnectionPermissionGroups
---

# Assert-PBICloudConnectionPermissionGroups

## SYNOPSIS

Ensures that the specified Power BI cloud connection has the exact set of permissions defined in the configuration.

## SYNTAX

### __AllParameterSets

```
Assert-PBICloudConnectionPermissionGroups [-CloudConnectionId] <string>
 [-PermissionGroups] <hashtable> [-AccessToken] <securestring> [-GraphAccessToken] <securestring>
 [-StrictMode] [-DryRun] [-ContinueOnError] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function provides comprehensive permission group management for Power BI shareable cloud connections.
It performs strict synchronization, ensuring that only the permissions specified in the configuration exist
on the cloud connection.
It supports both email addresses and explicit principal IDs, with automatic resolution
of email addresses to principal IDs using Microsoft Graph API.

The function will:
1. Resolve all identities in the permission groups (email addresses to principal IDs)
1. Get current permissions from the cloud connection
1. Calculate the delta (additions, updates, removals needed)
1. Apply all necessary changes to achieve the desired state

## EXAMPLES

### EXAMPLE 1

$permissionGroups = @{
    owners = @("admin@company.com")
    users = @(
        "user1@company.com",
        @{ principalId = "00000000-0000-0000-0000-000000000000"; principalType = "ServicePrincipal" }
    )
    reshareUsers = @("poweruser@company.com")
}

$result = Assert-PBICloudConnectionPermissionGroups `
    -CloudConnectionId "a60de636-56cf-4775-8217-76bb5b33bbb3" `
    -PermissionGroups $permissionGroups `
    -AccessToken $fabricToken.Token `
    -GraphAccessToken $graphToken.Token `
    -StrictMode

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

### -ContinueOnError

Switch to continue applying permission changes even if some operations fail.
***NOTE**: Failures during pre-requisite operations will still terminate processing (e.g.
resolving Entra identities).*

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

### -DryRun

Switch to perform a dry run without making any actual changes.
Useful for testing and validation.

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

### -GraphAccessToken

Secure string containing the access token for Microsoft Graph API (for resolving email addresses).

```yaml
Type: System.Security.SecureString
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PermissionGroups

Hashtable containing permission groups with keys like "owners", "users", "reshareUsers".
Each group contains an array of identities (email addresses or structured objects with principalId/principalType).

```yaml
Type: System.Collections.Hashtable
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

### -StrictMode

Switch to enable strict synchronization.
When enabled (default), any permissions not specified
in the configuration will be removed.

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

Returns a detailed result object containing:
- Summary of operations performed
- Any errors encountered
- Before and after permission states

## NOTES

## RELATED LINKS

- []()
