---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: ''
Locale: en-US
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 10/14/2026
PlatyPS schema version: 2024-05-01
title: Assert-PBICloudConnectionPermissions
---

# Assert-PBICloudConnectionPermissions

## SYNOPSIS

Ensures that an identity has the specified role on a Power BI shareable cloud connection.

## SYNTAX

### __AllParameterSets

```
Assert-PBICloudConnectionPermissions [-CloudConnectionId] <string> [-AssigneePrincipalId] <guid>
 [-AssigneePrincipalRole] <string> [-AssigneePrincipalType] <string> [-AccessToken] <securestring>
 [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Looks up the existing role assignments on the cloud connection.
If the identity already has a
role assignment with a different role, the function updates it; if it has none, the function
creates a new role assignment.
No change is made when the identity already has the specified role.

## EXAMPLES

### EXAMPLE 1

Assert-PBICloudConnectionPermissions `
    -CloudConnectionId "a60de636-56cf-4775-8217-76bb5b33bbb3" `
    -AssigneePrincipalId "00000000-0000-0000-0000-000000000000" `
    -AssigneePrincipalRole "User" `
    -AssigneePrincipalType "ServicePrincipal" `
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
