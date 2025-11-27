# ZeroFailed.Deploy.PowerBI

A [ZeroFailed](https://github.com/zerofailed/ZeroFailed) extension that provides deployment features targetted at the Power BI cloud platform.

## Overview

| Component Type | Included | Notes               |
|----------------|----------|---------------------|
| Tasks          | yes      | |
| Functions      | yes      | |
| Processes      | no       | Designed to be compatible with the default process provided by the [ZeroFailed.Deploy.Common](https://github.com/zerofailed/ZeroFailed.Deploy.Common) extension |

For more information about the different component types, please refer to the [ZeroFailed documentation](https://github.com/zerofailed/ZeroFailed/blob/main/README.md#extensions).

This extension consists of the following feature groups, click the links to see their documentation:

- Shared Cloud Connections (inc. permissions)

## Dependencies

| Extension                | Reference Type | Version |
|--------------------------|----------------|---------|
| ZeroFailed.Deploy.Common | git            | `main`  |

## Permission Management Flow

The following diagram illustrates the flow of permission management in the `Assert-PBICloudConnectionPermissionGroups` function:

```mermaid
    graph TD
        A[Start<br>Function: Assert-PBICloudConnectionPermissionGroups<br/>] --> B[Collect Identities from Permission Groups<br/>Function: Assert-PBICloudConnectionPermissionGroups<br/>]
        B --> C[Resolve Identities to Principal IDs<br/>Function: Resolve-PrincipalIdentities<br/>]
        C --> D[Convert Permission Groups to Flat List<br/>Function: _ConvertFrom-PermissionGroups<br/>]
        D --> E[Retrieve Current Permissions<br/>Function: Get-PBICloudConnectionPermissions<br/>]
        E --> F[Calculate Permission Delta<br/>Function: _Get-PermissionDelta<br/>]
        F --> G{Delta Changes?}
        G -->|No| H[No Changes Needed]
        G -->|Yes| I[Apply Permission Changes<br/>Function: _Apply-PermissionChanges<br/>]
        I --> L[Update or Create Permissions<br/>Function: Assert-PBICloudConnectionPermissions<br/>]
        L --> M[Remove Permissions<br/>Function: Remove-PBICloudConnectionPermissionBatch<br/>]
        M --> J[Retrieve Final State<br/>Function: Get-PBICloudConnectionPermissions<br/>]
        H --> K[End]
        J --> K[End]
```

## Cloud Connection Management Flow

The following diagram illustrates the flow for managing cloud connections, including resolving configurations, retrieving permissions, ensuring role assignments, and exporting connections. Each step corresponds to a specific function in the module.

```mermaid
graph TD
    A[Resolve Configuration] --> B[Retrieve Existing Permissions]
    B --> C[Ensure Role Assignments]
    C --> D[Remove Unnecessary Permissions]

    subgraph Functions
        A[Resolve-CloudConnections]
        B[Get-PBICloudConnectionPermissions]
        C[Assert-PBICloudConnectionPermissions]
        D[Remove-PBICloudConnectionPermission]
    end
```

### Configuration Model Overview

#### 1. **Main Configuration (`config.yaml`)**
- **Purpose**: Centralized configuration file referencing other YAML files.
- **Key Fields**:
  - `version`: Configuration version (e.g., `'1.0'`).
  - `configurationFiles`: References to other configuration files:
    - `servicePrincipals`: Path to service principals configuration.
    - `connectionTargets`: Path to connection targets configuration.
    - `connections`: List of connection group files (e.g., `development`, `testing`, `special-purpose`).
  - `settings`: Global settings:
    - `defaultTenantId`: Default Azure tenant ID.

#### 2. **Connection Targets (`connectionTargets.yaml`)**
- **Purpose**: Defines reusable connection targets.
- **Key Fields**:
  - `connectionTargets`: Grouped by target type (e.g., `blobStorage`, `sqlServer`).
    - Each target includes environment-specific configurations (e.g., `dev`, `test`).

#### 3. **Service Principals (`servicePrincipals.yaml`)**
- **Purpose**: Defines service principal credentials for different environments.
- **Key Fields**:
  - `servicePrincipals`: Grouped by environment (e.g., `development`, `test`).
    - Each entry includes:
      - `clientId`: Service principal client ID.
      - `secretUrl`: URL to the secret in Azure Key Vault.
      - `tenantId`: Azure tenant ID.

#### 4. **Connection Groups**
- **Purpose**: Define cloud connections for specific environments or purposes.
- **Files**:
  - **Development (`connections/development.yaml`)**
    - **Purpose**: Connections for the development environment.
    - **Key Fields**:
      - `cloudConnections`: List of connections.
        - `displayName`: Connection name.
        - `type`: Connection type (e.g., `AzureBlobs`, `SQL`).
        - `useServicePrincipal`: Reference to a service principal.
        - `target`: Reference to a connection target.
        - `permissions`: Defines `owners`, `users`, and `reshareUsers`.
  - **Special Purpose (`connections/special-purpose.yaml`)**
    - **Purpose**: Custom connections for special use cases.
    - **Key Fields**:
      - Similar to `development.yaml`, but may include inline `servicePrincipal` and `target` definitions.