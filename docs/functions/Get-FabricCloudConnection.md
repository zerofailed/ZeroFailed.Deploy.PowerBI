---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: https://learn.microsoft.com/en-us/rest/api/fabric/core/connections/list-connections
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 08/26/2026
PlatyPS schema version: 2024-05-01
title: Get-FabricCloudConnection
---

# Get-FabricCloudConnection

## SYNOPSIS

Retrieves a single shared cloud connection from the tenant by display name.

## SYNTAX

### __AllParameterSets

```
Get-FabricCloudConnection [-DisplayName] <string> [-AccessToken] <securestring> [-ThrowIfMissing]
 [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Resolves a connection that this deployment did not necessarily provision, so that a use-case
repository can obtain its id and credential state without any create or update side effect.

This is deliberately NOT named 'Resolve-CloudConnection'.
Despite the similar shape, it does
something entirely different from Resolve-CloudConnections: that function reads YAML from disk
and returns desired state without talking to Fabric at all, whereas this one queries the tenant
and returns actual state.
A one-character difference between the two would be mis-called, and
the failure would be silent - a config object where a live one was expected.

## EXAMPLES

### EXAMPLE 1

$connection = Get-FabricCloudConnection -DisplayName 'EDAP_DEV_fp__shared' -AccessToken $token
$connection.id

## PARAMETERS

### -AccessToken

A Fabric API access token.

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

### -DisplayName

The display name of the connection to retrieve.

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

### -ThrowIfMissing

When set, a connection that cannot be found raises a terminating error rather than returning
$null.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object

Returns the connection, carrying at least its 'id', 'credentialType' and 'lastCredentialUsedDateTime', or $null when no connection of that display name is visible to the calling identity.

## NOTES

Returns a connection carrying at least 'id', 'credentialType' and
'lastCredentialUsedDateTime', or $null when no connection of that display name is visible.

## RELATED LINKS

- [](https://learn.microsoft.com/en-us/rest/api/fabric/core/connections/list-connections)
