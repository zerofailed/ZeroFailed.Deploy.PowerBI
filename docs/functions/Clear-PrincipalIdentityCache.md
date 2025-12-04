---
document type: cmdlet
external help file: ZeroFailed.Deploy.PowerBI-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.PowerBI
ms.date: 11/27/2025
PlatyPS schema version: 2024-05-01
title: Clear-PrincipalIdentityCache
---

# Clear-PrincipalIdentityCache

## SYNOPSIS

Clears the in-memory cache of resolved principal identities.

## SYNTAX

### __AllParameterSets

```
Clear-PrincipalIdentityCache [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function removes all entries from the `$script:PrincipalIdentityCache` hashtable,
forcing subsequent identity resolution calls to re-query Microsoft Graph API.
This is useful for ensuring fresh data or for testing scenarios.

## EXAMPLES

### EXAMPLE 1

Clear-PrincipalIdentityCache

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Void

This function has no outputs.

## NOTES

## RELATED LINKS

- []()
