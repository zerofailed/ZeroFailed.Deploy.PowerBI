---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 11/27/2025
PlatyPS schema version: 2024-05-01
title: Assert-PBICloudConnectionPermissions
---

# Assert-PBICloudConnectionPermissions

## SYNOPSIS

Ensures that the specified Power BI shareable cloud connection exists.

## SYNTAX

### __AllParameterSets

```
Assert-PBICloudConnectionPermissions [-CloudConnectionId] <string> [-AssigneePrincipalId] <guid>
 [-AssigneePrincipalRole] <string> [-AssigneePrincipalType] <string> [-AccessToken] <securestring>
 [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Ensures that the specified Power BI shareable cloud connection exists.
If the connection already exists, the function updates it;
otherwise, it creates a new connection using the provided parameters.

## EXAMPLES

### EXAMPLE 1

# Example usage to update an existing connection or create a new one:
$secureToken = ConvertTo-SecureString "token" -AsPlainText -Force
$secureSecret = ConvertTo-SecureString "secret" -AsPlainText -Force

$response = Assert-PBIShareableCloudConnection `
    -DisplayName "MyConnection" `
    -ConnectionType "ExampleType" `
    -Parameters @{ key = "value" } `
    -ServicePrincipalClientId "clientId" `
    -ServicePrincipalSecret $secureSecret `
    -TenantId "tenantId" `
    -AccessToken $secureToken

Write-Output $response

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
  Position: 4
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -AssigneePrincipalId

The Entra principalId (aka objectId) of the identity the permissions are being assigned to.

```yaml
Type: System.Guid
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

### -AssigneePrincipalRole

The Power BI role that will be assigned to the identity.

```yaml
Type: System.String
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

### -AssigneePrincipalType

The type of Entra identity being assigned the permissions.

```yaml
Type: System.String
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

### -CloudConnectionId

The unique identifier of the Power BI Cloud Connection to update.

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

Returns the response from the Fabric API call.

## NOTES

## RELATED LINKS

- []()
