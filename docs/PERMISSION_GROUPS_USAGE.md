# PowerBI Cloud Connection Permission Group Management

This document describes how to use the new permission group management functionality to manage PowerBI cloud connection permissions declaratively.

## Overview

The new permission group management system provides:

- **Strict Synchronization**: Ensures only configured permissions exist on cloud connections
- **Hybrid Identity Support**: Supports both email addresses and explicit principal IDs
- **Group-based Management**: Organize permissions by role (owners, users, reshareUsers)
- **Automatic Resolution**: Automatically resolves email addresses to principal IDs using Microsoft Graph

## Configuration Format

### Basic Configuration (Email Addresses)

```yaml
cloudConnections:
  - displayName: Development Blob Storage
    type: AzureBlobs
    useServicePrincipal: development
    target:
      useTarget: blobStorage.dev
    permissions:
      owners:
        - admin@company.com
        - lead.developer@company.com
      users:
        - dev.team@company.com
        - contractor@partner.com
      reshareUsers:
        - power.users@company.com
```

### Advanced Configuration (Mixed Identity Types)

```yaml
cloudConnections:
  - displayName: Production SQL Database
    type: SQLServer
    useServicePrincipal: production
    target:
      useTarget: sqlServer.prod
    permissions:
      owners:
        - admin@company.com
        - principalId: "00000000-0000-0000-0000-000000000000"
          principalType: "ServicePrincipal"
      users:
        - prod.team@company.com
        - principalId: "282de1ed-2c46-4b5b-ac1d-06bcf3b19128"
          principalType: "Group"
      reshareUsers: []
```

## Permission Groups

### owners
- **PowerBI Role**: `Owner`
- **Description**: Users/principals with full control over the connection
- **Best Practice**: Keep this group small and limited to administrators

### users
- **PowerBI Role**: `User` 
- **Description**: Users/principals who can use the connection in their reports
- **Best Practice**: Most end users should be in this group

### reshareUsers
- **PowerBI Role**: `UserWithReshare`
- **Description**: Users/principals who can use and share the connection with others
- **Best Practice**: Use sparingly for trusted power users

## Principal Types

When using explicit principal IDs, you can specify the following types:

- **User**: Individual Azure AD users
- **Group**: Azure AD security groups or Microsoft 365 groups
- **ServicePrincipal**: Application service principals
- **ServicePrincipalProfile**: Service principal profiles

## Deployment

The permission synchronization happens automatically during the PowerBI deployment task:

```powershell
# This will now manage permissions as well as connections
Invoke-Build deployPowerBISharedCloudConnection
```

## Manual Permission Management

You can also manage permissions manually using the new functions:

```powershell
# Get tokens
$fabricToken = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://api.fabric.microsoft.com'
$graphToken = Get-AzAccessToken -AsSecureString -ResourceUrl 'https://graph.microsoft.com'

# Define permission groups
$permissionGroups = @{
    owners = @("admin@company.com")
    users = @(
        "user@company.com",
        @{ principalId = "00000000-0000-0000-0000-000000000000"; principalType = "ServicePrincipal" }
    )
    reshareUsers = @()
}

# Synchronize permissions
$result = Assert-PBICloudConnectionPermissionGroups `
    -CloudConnectionId "your-connection-id" `
    -PermissionGroups $permissionGroups `
    -AccessToken $fabricToken.Token `
    -GraphAccessToken $graphToken.Token `
    -StrictMode

# Check results
Write-Host "Success: $($result.Success)"
Write-Host "Identities resolved: $($result.Summary.TotalIdentitiesResolved)"
Write-Host "Permissions added: $($result.Summary.PermissionsAdded)"
Write-Host "Permissions updated: $($result.Summary.PermissionsUpdated)"
Write-Host "Permissions removed: $($result.Summary.PermissionsRemoved)"
```

## Dry Run Mode

You can test permission changes without making actual modifications:

```powershell
$result = Assert-PBICloudConnectionPermissionGroups `
    -CloudConnectionId "your-connection-id" `
    -PermissionGroups $permissionGroups `
    -AccessToken $fabricToken.Token `
    -GraphAccessToken $graphToken.Token `
    -DryRun
```

## Features

### Strict Mode (Default)
- Removes any permissions not specified in the configuration
- Ensures exact match between configuration and actual permissions
- Recommended for production environments

### Non-Strict Mode
- Only manages permissions explicitly defined in configuration
- Leaves other existing permissions untouched
- Useful for gradual migration or shared environments

### Error Handling
- Continues processing even if some operations fail (when ContinueOnError is enabled)
- Provides detailed error reporting
- Gracefully handles API rate limits and transient failures

### Caching
- Automatically caches identity resolutions for performance
- Reduces Microsoft Graph API calls
- Can be disabled if needed

## Security Considerations

1. **Principle of Least Privilege**: Only grant necessary permissions
2. **Owner Management**: Always ensure at least one owner exists
3. **Service Principal Security**: Use dedicated service principals with minimal required permissions
4. **Regular Review**: Periodically review and update permission configurations

## Troubleshooting

### Common Issues

1. **Identity Resolution Failures**
   - Ensure email addresses are valid Azure AD identities
   - Check Microsoft Graph API permissions
   - Verify the Graph access token has sufficient scope

2. **Permission Sync Failures**
   - Check PowerBI Fabric API permissions
   - Ensure the service principal has admin rights on the connection
   - Review rate limiting and retry logic

3. **Configuration Errors**
   - Validate YAML syntax
   - Ensure principal IDs are valid GUIDs
   - Check principal types match actual Azure AD object types

### Debugging

Enable verbose logging for detailed information:

```powershell
$VerbosePreference = "Continue"
$InformationPreference = "Continue"

# Run your permission management operations
```

## Migration from Manual Permission Management

1. **Audit Current Permissions**: Document existing permissions on connections
2. **Create Configuration**: Add permissions section to your connection YAML files
3. **Test with Dry Run**: Use `-DryRun` to validate changes before applying
4. **Gradual Rollout**: Start with non-production connections
5. **Monitor Results**: Review operation results and logs

## Best Practices

1. **Use Email Addresses When Possible**: Easier to read and maintain than GUIDs
2. **Group Management**: Use Azure AD groups for managing multiple users
3. **Environment Separation**: Different permission sets for dev/test/prod
4. **Version Control**: Store permission configurations in source control
5. **Regular Audits**: Periodically review and clean up permissions
6. **Documentation**: Document the purpose of each permission assignment

## API Rate Limits

The system includes built-in rate limiting awareness:
- Automatic retry with exponential backoff
- Batching of operations where possible
- Caching to reduce API calls

## Examples

See the test configuration files for additional examples:
- `module/_functions/_test-data/connections/development.yaml`
- `module/_functions/_test-data/connections/testing.yaml`
- `module/_functions/_test-data/connections/special-purpose.yaml`