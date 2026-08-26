---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: https://learn.microsoft.com/en-us/rest/api/fabric/core/connections/create-connection
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 08/26/2026
PlatyPS schema version: 2024-05-01
title: Assert-PBIShareableCloudConnection
---

# Assert-PBIShareableCloudConnection

## SYNOPSIS

Creates or updates a shareable cloud connection, converging it on its declared configuration.

## SYNTAX

### __AllParameterSets

```
Assert-PBIShareableCloudConnection [-DisplayName] <string> [-ConnectionType] <string>
 [[-CreationMethod] <string>] [[-Parameters] <hashtable[]>] [[-CredentialType] <string>]
 [[-ServicePrincipalClientId] <guid>] [[-ServicePrincipalSecret] <securestring>]
 [[-TenantId] <string>] [-AccessToken] <securestring> [[-AllowCredentialUpdate] <bool>]
 [-SkipCredentialUpdates] [-ValidateConnectionType] [-ContinueOnError] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Looks the connection up by display name and either creates it or re-asserts its credential.

The credential block is built to match the connection's declared credential type, so that
connections carrying no secret at all - WorkspaceIdentity and Anonymous - are supported
alongside service principal ones.
Those two need no ServicePrincipalClientId,
ServicePrincipalSecret or TenantId, and typically no Parameters either.

ConnectionType is the connector kind; CreationMethod is the Power Query function that builds
it.
They coincide for AzureBlobs and SQL, and differ for SharePoint (built by SharePointList)
and Fabric pipelines (built by FabricDataPipelines.Actions).
CreationMethod defaults to
ConnectionType when omitted.

Set AllowCredentialUpdate to false for any connection that OneLake shortcuts are bound to.
Updating such a connection leaves every bound shortcut failing '401 Unauthorized on ListBlob'
while still reporting healthy, and delete-and-recreate does not reliably recover it.
The
default of true preserves the Key Vault secret rotation flow.

## EXAMPLES

### EXAMPLE 1

Assert-PBIShareableCloudConnection -DisplayName 'EDAP_DEV_fp__shared' -ConnectionType 'FabricDataPipelines' -CreationMethod 'FabricDataPipelines.Actions' -CredentialType 'WorkspaceIdentity' -Parameters @() -AccessToken $token

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
  Position: 8
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -AllowCredentialUpdate

Whether an existing connection may have its credential re-asserted.

```yaml
Type: System.Boolean
DefaultValue: True
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 9
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ConnectionType

The connector kind, such as AzureBlobs, SQL or SharePoint.

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

### -ContinueOnError

Logs an error and returns null rather than aborting the whole deployment.

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

### -CreationMethod

The Power Query function that builds the connection.

```yaml
Type: System.String
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

### -CredentialType

ServicePrincipal, WorkspaceIdentity or Anonymous.

```yaml
Type: System.String
DefaultValue: ServicePrincipal
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

### -DisplayName

The display name of the connection.

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

### -Parameters

The connection's target parameters, which may be empty.

```yaml
Type: System.Collections.Hashtable[]
DefaultValue: '@()'
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

### -ServicePrincipalClientId

The client ID of the service principal.

```yaml
Type: System.Guid
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 5
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ServicePrincipalSecret

The secret of the service principal.

```yaml
Type: System.Security.SecureString
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 6
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SkipCredentialUpdates

Suppresses credential updates for this run whatever each connection allows.

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

### -TenantId

The tenant ID of the service principal.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 7
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ValidateConnectionType

Checks the connection definition against the tenant before attempting a create.

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

Returns the created, updated or existing cloud connection, or $null when processing failed and ContinueOnError was set.

## NOTES

Returns the created, updated or existing connection, or $null when processing failed and
ContinueOnError was set.

## RELATED LINKS

- [](https://learn.microsoft.com/en-us/rest/api/fabric/core/connections/create-connection)
