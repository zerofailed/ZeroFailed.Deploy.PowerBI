---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 11/27/2025
PlatyPS schema version: 2024-05-01
title: Resolve-PrincipalIdentities
---

# Resolve-PrincipalIdentities

## SYNOPSIS

Resolves a collection of identities (email addresses or structured objects) to principal IDs and types.

## SYNTAX

### __AllParameterSets

```
Resolve-PrincipalIdentities [-Identities] <Object[]> [-GraphAccessToken] <securestring> [-UseCache]
 [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function takes a mixed array of identities - either email address strings or structured objects
with principalId and principalType properties - and resolves them to a consistent format with
principal IDs and types. Email addresses are resolved using Microsoft Graph API.

## EXAMPLES

### Example 1

$identities = @(
    "user@domain.com",
    @{ principalId = "00000000-0000-0000-0000-000000000000"; principalType = "ServicePrincipal" }
)
$resolved = Resolve-PrincipalIdentities -Identities $identities -GraphAccessToken $graphToken
#>

## PARAMETERS

### -GraphAccessToken

Secure string containing the Microsoft Graph API access token for resolving email addresses.

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

### -Identities

Array of identities to resolve. Can contain:
- Email address strings (e.g., "user@domain.com")
- Structured objects with principalId and principalType properties

```yaml
Type: System.Object[]
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

### -UseCache

Switch to enable caching of resolved identities for performance optimization.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
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

### System.Array

Returns an array of objects with resolved principalId, principalType, and originalIdentity properties.

## NOTES

## RELATED LINKS

- []()
