# Extending `ZeroFailed.Deploy.PowerBI` to a broader set of connections

*…and renaming it `ZeroFailed.Deploy.FabricConnections`*

> Status: **revision 2** — accepted with refinements · Author: Data Engineering (endjin) · Date: 2026-08-26
> Target repository: [zerofailed/ZeroFailed.Deploy.PowerBI](https://github.com/zerofailed/ZeroFailed.Deploy.PowerBI)
> → to be renamed **`ZeroFailed.Deploy.FabricConnections`**
> Also touches: [zerofailed/zerofailed-marketplace](https://github.com/zerofailed/zerofailed-marketplace) — the `deploy-powerbi` skill
> Origin: [`docs/dataops_backlog.md`](dataops_backlog.md) DO-01 · [`docs/requirements.md`](requirements.md) FR-06, OQ-14a, OQ-20
>
> **This document is written to be handed to an agent working in the target repository.**
> It carries the evidence from the project that found these gaps, because that evidence does
> not exist in the target repo and the changes are hard to justify without it.

### What changed in revision 2

Maintainer review answered all four open questions and raised one new requirement. The
substantive change is CR-05, which **the feedback improved rather than merely confirmed**:

| | Revision 1 | Revision 2 |
|---|---|---|
| Module name | Open question | **Renamed** to `ZeroFailed.Deploy.FabricConnections` (Change 8) |
| Credential update | Global switch, default **off** | **Per-connection `allowCredentialUpdate`, default on** — secret rotation is a legitimate flow that a global default-off would have broken (Change 4) |
| Connection ids | Non-goal | **In scope** — new `Get-FabricCloudConnection` for use-case repos (Change 9) |
| Shortcut warning | Open question | **Everywhere** — extension README, both marketplace skills (Change 7) |
| Marketplace skill | Not covered | **New requirement** — rename and rewrite `deploy-powerbi` (Change 10) |

Two questions remain genuinely open, both raised by the maintainer and neither answerable from
this project's evidence. They are in §4, and one of them should be settled **before** Change 4
is written.

---

## How to read the evidence labels

Every factual claim below is one of:

- **Verified by execution** — code was run and the result observed, on the date given.
- **Verified against source** — read out of the target repository at commit `e1b7843`.
- **Verified against the tenant** — observed against a live Fabric tenant by the HAT project.
- **Unverified** — reasoned, not tested. Treat as a hypothesis and confirm before relying on it.

---

## 1. Background

### 1.1 Where this comes from

The **Hospitality and Ticketing (HAT)** solution is a code-first Microsoft Fabric build:
workspaces provisioned from `topology.json`, items deployed by git integration, environment
configuration in a Fabric variable library. Everything is source-controlled and deployable
except one plane — **cloud connections**, which hold credentials, are not Fabric git items,
and are not deployed by `fabric-cicd`.

HAT needs exactly two, and neither can be expressed by the extension today:

| Connection | Type / creation method | Credential | Purpose |
|---|---|---|---|
| `EDAP_{env}_sp__hat` | `SharePoint` / `SharePointList` | `ServicePrincipal` | Backs a OneLake shortcut onto a SharePoint document library. Without it there is no ingest at all |
| `EDAP_{env}_fp__shared` | `FabricDataPipelines` / `FabricDataPipelines.Actions` | `WorkspaceIdentity` | Required by every `InvokePipeline` activity. Without it no orchestrated run works |

The second is instructive: its name ends `__shared` because it is **not HAT-specific**. A
`FabricDataPipelines` connection is identical in every Fabric solution in the tenant. Managing
it inside a use-case repository is already the wrong home for it, which is the broader case for
this work.

To keep moving, HAT wrote its own provisioning script (`deployment/create_connections.py`,
Python over the Fabric REST API). This proposal is the opposite of defending that script: **the
extension's permission management is better than what HAT built, and should be adopted rather
than reimplemented.** What follows is the minimum set of changes that lets a Fabric project use
it, contributed upstream rather than forked, because the evidence behind each change was
expensive to obtain and should not have to be obtained twice.

### 1.2 What the extension does today

*Verified against source at `e1b7843`.*

A genuinely good design, and more capable than its name suggests:

- **A denormalised YAML config model** — `config.yaml` referencing `servicePrincipals.yaml`,
  `connectionTargets.yaml`, and one or more connection group files. Targets are reusable and
  environment-keyed (`blobStorage.dev`), with per-connection parameter overrides.
- **Key Vault secret resolution**, handling both modern and legacy `Az.KeyVault` shapes.
- **Permission management that is the standout piece**: Graph identity resolution with caching,
  a computed delta over `owners` / `users` / `reshareUsers`, `-StrictMode`, `-DryRun`, and a
  structured result reporting added/updated/removed.
- **Rate-limit-aware REST calls** via `Invoke-RestMethodWithRateLimit`.
- **Pester tests beside every function**, dot-sourcing the function under test and mocking
  external calls.

### 1.3 Why it cannot be used as-is

Four blockers. The first two are expressiveness; the third and fourth are safety.

#### B1 — `creationMethod` is hard-coded to equal `type`

`module/functions/_GenerateCreateBody.ps1`, lines 58–64:

```powershell
connectionDetails = @{
    type           = $ConnectionType
    creationMethod = $ConnectionType      # <-- always identical
    parameters     = $Parameters
}
```

`type` and `creationMethod` are different things in the Fabric API. `type` is the connector
kind; `creationMethod` is the Power Query function that builds it. They coincide for
`AzureBlobs` and `SQL`, which is why this has never surfaced. They do **not** coincide for
SharePoint (`SharePoint` / `SharePointList`) or Fabric pipelines
(`FabricDataPipelines` / `FabricDataPipelines.Actions`), so **neither HAT connection is
expressible**.

*Verified against the tenant, 2026-08-20:* `GET /v1/connections/supportedConnectionTypes`
returns exactly one SharePoint entry — `type: SharePoint`, `creationMethod: SharePointList`,
parameter `sharePointSiteUrl`.

The failure mode is worth knowing because it misdirects: supplying a valid `type` with an
invalid `creationMethod` returns **"No function found matching 'X' for Kind: 'X'"**, which
reads as though the *type* is wrong. Time is then spent on the one thing that was correct.

#### B2 — `credentialType` is hard-coded to `ServicePrincipal`

In `_GenerateCreateBody.ps1` (line 71) and `_GenerateUpdateBody.ps1` (line 46). Fabric supports
several, and two matter here:

- **`WorkspaceIdentity`** — no secret, no parameters, no Key Vault lookup. Required by
  `FabricDataPipelines` and the target state for SharePoint.
- **`Anonymous`** — no secret, for public endpoints.

Neither can be expressed, and both are *simpler* than the supported case rather than harder —
the body just carries `credentialType` and nothing else.

#### B3 — A connection without a service principal cannot be declared at all

This is worse than it first appears, and worse than reported in HAT's own backlog.

`module/tasks/powerbi.tasks.ps1` guards the whole loop body:

```powershell
if (($connection | Get-Member -Name servicePrincipal) -and $connection.servicePrincipal.ContainsKey("secretUrl")) {
```

There is no `else`. A connection without a service principal is **silently skipped** — the task
reports success having done nothing.

But execution never reaches that guard. `Resolve-CloudConnections.ps1` lines 100–112 assign the
service principal and then apply the default tenant unconditionally:

```powershell
$denormalized.servicePrincipal = $conn.servicePrincipal          # $null when not declared
if (!$denormalized.servicePrincipal.ContainsKey('tenantId') -or ...) {
```

**Verified by execution, 2026-08-26** (`pwsh` 7, isolated repro):

```
THROWS: You cannot call a method on a null-valued expression.
```

The `catch` at line 165 logs and rethrows, so the whole deployment aborts. **A non-service-
principal connection therefore cannot even be declared today** — it is not a silent skip, it is
a hard failure with an error that names neither the connection nor the field.

Both defects need fixing, and in this order: the crash first, then the silent skip.

#### B4 — An existing connection has its credential `PATCH`ed on every run

`Assert-PBIShareableCloudConnection.ps1`, the `if ($existingConnection)` branch:

```powershell
$updateBody = _GenerateUpdateBody @generateBodySplat
"Method" = "PATCH"
```

Unconditional, every run. For a Power BI SQL connection this is reasonable idempotency —
re-assert the credential, converge on the declared state.

**For a connection that OneLake shortcuts are bound to, it is an outage.**

*Verified against the tenant, 2026-08-20.* Creating a shortcut **binds** it to a cloud
connection. Updating that connection — even restoring the credential it already had — leaves
the binding stale, and every read through the shortcut then fails
`401 Unauthorized on ListBlob`. The shortcut still reports healthy in a `list_shortcuts`
response. **Delete-and-recreate did not recover it.** Renaming over
`PATCH /v1/connections/{id}` is worse still: it re-validates the credential as a side effect and
can destroy the connection outright. HAT's ingestion was down for the remainder of that day.

The extension has no way to know a shortcut exists, which is exactly why this cannot be
decided globally — see Change 4, where review feedback replaced the original global switch with
a per-connection opt-out.

> **Important scope limit on this evidence.** What HAT observed was a credential **change** and
> a **rename** over `PATCH`. Whether a same-type **secret rotation** — the same service
> principal, a new secret value — also invalidates a bound shortcut is **unverified**. It is
> the crux of the maintainer's question in §4.1, and it is the difference between "rotation is
> safe everywhere" and "rotation needs the same opt-out". Do not assume either way.

### 1.4 Two facts that shaped this proposal

Both cost the HAT project real time and both belong in the target repo's guidance:

**A passing connection test is not evidence of source access.** A `WorkspaceIdentity` SharePoint
connection is created happily with `skipTestConnection: false`, passes its own test, and then
fails the first real operation with *"Unauthorized exception, failed to retrieve SharePoint
drives"*. The test proves the credential could be **acquired**, nothing more. *(Verified against
the tenant, 2026-08-20.)*

**Credential type is effectively immutable.** Changing it in place is unreliable; delete and
recreate. Microsoft support gives the same instruction for `InvokePipeline` connections —
*"if the connection was previously saved with OAuth 2.0 and cannot be changed, delete the
existing connection and create a new one from scratch"*. This is the second reason B4 matters:
the update path is not merely dangerous, it is not reliably effective either.

---

## 2. Requirements

Numbered for citation. Each is testable.

### Functional

| ID | Requirement | Priority |
|---|---|---|
| **CR-01** | A connection definition shall be able to specify `creationMethod` independently of `type`. When omitted it shall default to `type`, preserving today's behaviour. | Must |
| **CR-02** | A connection definition shall be able to specify `credentialType`. Supported unattended: `ServicePrincipal`, `WorkspaceIdentity`, `Anonymous`. When omitted it shall default to `ServicePrincipal`. | Must |
| **CR-03** | A connection whose credential needs no secret shall be deployable **without** a `servicePrincipal` block, without error and without being skipped. | Must |
| **CR-04** | A credential type requiring interactive consent (`OAuth2`, `Basic`, `Windows`) shall be **rejected with a clear message** naming the connection and what to do instead. It shall not be silently skipped, and it shall not fail with a REST error. | Must |
| **CR-05** | A connection shall be able to **opt out** of credential updates, so that a connection backing a OneLake shortcut is not re-`PATCH`ed by a routine deployment. The default shall remain *update*, preserving both today's behaviour and the Key Vault secret-rotation flow. | Must |
| **CR-05a** | A deployment shall be able to suppress **all** credential updates for one run, so structure can be converged without touching credentials. | Should |
| **CR-06** | When credential update is requested, the update body shall match the connection's declared `credentialType`, not assume `ServicePrincipal`. | Must |
| **CR-07** | A connection that is configured but cannot be processed shall produce a **warning naming the connection and the reason** — never a silent skip. | Must |
| **CR-08** | `type` and `creationMethod` should be validated against `GET /v1/connections/supportedConnectionTypes` before any create is attempted, failing with the valid values for that type. | Should |
| **CR-09** | The connection id of every processed connection shall be available to the caller in a machine-readable form. | Must |
| **CR-10** | A **single** connection shall be resolvable from the tenant by display name, without any create or update side effect, so a use-case repository's deployment can obtain the id and credential state of a connection it did not provision. | Must |
| **CR-11** | The module shall be renamed to reflect that it manages Fabric shared cloud connections rather than Power BI. | Must |

### Non-functional

| ID | Requirement |
|---|---|
| **CR-N1** | **Fully backwards compatible.** Every existing `AzureBlobs` and `SQL` configuration must deploy unchanged, producing a byte-identical request body. This is the acceptance bar for the whole change. |
| **CR-N2** | Pester coverage for each new branch, following the existing convention — dot-source the function, mock `Invoke-RestMethodWithRateLimit`, assert on the generated body. |
| **CR-N3** | Documentation regenerated for every changed function under `docs/functions/`, and the config model in `README.md` updated. |
| **CR-N4** | No change to the permission-management path. It works and is the most valuable part of the extension. |

### Explicit non-goals

- **Writing connection ids into downstream configuration files.** *Reading* them is now in
  scope (CR-10); writing them is not. A deploy task that edits source files is a poor fit for
  ZeroFailed. HAT keeps that in a separate read-only script
  (`deployment/resolve_connections.py`), and the separation has held up well.
- **Shortcut awareness.** The extension cannot know a shortcut is bound to a connection. CR-05
  puts the decision in the connection's own configuration, which is the only place that
  knowledge exists.
- **Deployment-pipeline features.** Those belong in
  [`ZeroFailed.Deploy.Fabric`](https://github.com/zerofailed/ZeroFailed.Deploy.Fabric), which
  already owns workspace provisioning, Git integration, workspace identity, RBAC and deployment
  pipelines. This extension stays scoped to shared cloud connections — which is what the rename
  in CR-11 makes explicit.

---

## 3. Solution — an actionable plan

Ten changes, ordered so each is independently reviewable, the behaviour changes land on the current names, and the rename comes last as one mechanical commit.
File paths are relative to the repository root.

> **Before starting:** run the existing Pester suite and record the result. Every change below
> must leave it green, and CR-N1 is the acceptance bar — an existing `SQL` or `AzureBlobs`
> config must produce a byte-identical body.

---

### Change 1 — Decouple `creationMethod` from `type` (CR-01)

**`module/functions/_GenerateCreateBody.ps1`**

Add a `$CreationMethod` parameter, defaulting to `$ConnectionType` when not supplied:

```powershell
param (
    $DisplayName,
    $ConnectionType,
    $CreationMethod,          # NEW - defaults to $ConnectionType
    $Parameters,
    ...
)

# 'type' is the connector kind; 'creationMethod' is the Power Query function that builds it.
# They coincide for SQL and AzureBlobs, and differ for SharePoint (SharePoint/SharePointList)
# and Fabric pipelines (FabricDataPipelines/FabricDataPipelines.Actions). Supplying a valid
# type with an invalid creation method returns "No function found matching 'X' for Kind: 'X'",
# which reads as though the type is wrong.
if ([string]::IsNullOrEmpty($CreationMethod)) { $CreationMethod = $ConnectionType }

connectionDetails = @{
    type           = $ConnectionType
    creationMethod = $CreationMethod
    parameters     = $Parameters
}
```

**`module/functions/Resolve-CloudConnections.ps1`** — denormalise it (near line 95, beside
`type`):

```powershell
$denormalized = @{
    displayName    = $conn.displayName
    type           = $conn.type
    creationMethod = $conn.creationMethod    # NEW - may be $null, defaulted downstream
}
```

**`module/functions/Assert-PBIShareableCloudConnection.ps1`** — add a `[string] $CreationMethod`
parameter (not mandatory) and pass it into the splat.

**`module/tasks/powerbi.tasks.ps1`** — add to the splat:

```powershell
CreationMethod = $connection.creationMethod
```

**Tests** — in `_GenerateCreateBody.Tests.ps1`:
- omitted `CreationMethod` produces `creationMethod -eq $ConnectionType` *(this is the CR-N1 regression guard)*
- supplied `CreationMethod` is used verbatim
- a SharePoint case: `type: SharePoint`, `creationMethod: SharePointList`

---

### Change 2 — Fix the null-service-principal crash (CR-03, part 1)

**`module/functions/Resolve-CloudConnections.ps1`**, around lines 100–112.

This is a bug fix and should land before the feature work that depends on it. Guard the default
tenant application so it only runs when a service principal is actually present:

```powershell
if ($conn.useServicePrincipal) {
    $denormalized.servicePrincipal = _Resolve-ServicePrincipal -ServicePrincipals $servicePrincipals -Reference $conn.useServicePrincipal
}
elseif ($conn.servicePrincipal) {
    $denormalized.servicePrincipal = $conn.servicePrincipal
}

# Only meaningful when a service principal is present. Credential types such as
# WorkspaceIdentity and Anonymous carry no principal and no tenant, and the previous
# unconditional call threw "You cannot call a method on a null-valued expression" —
# aborting the whole deployment with an error naming neither the connection nor the field.
if ($denormalized.ContainsKey('servicePrincipal') -and $denormalized.servicePrincipal) {
    if (!$denormalized.servicePrincipal.ContainsKey('tenantId') -or [string]::IsNullOrEmpty($denormalized.servicePrincipal['tenantId'])) {
        $denormalized.servicePrincipal['tenantId'] = $config.settings.defaultTenantId
    }
}
```

**Tests** — in `Resolve-CloudConnections.Tests.ps1`:
- a connection with **no** `servicePrincipal` and no `useServicePrincipal` resolves without
  throwing *(fails before this change — worth confirming that first, so the test is known to
  test something)*
- an existing SP-based connection still receives the default tenant

---

### Change 3 — Support credential types beyond `ServicePrincipal` (CR-02, CR-03, CR-04)

**`module/functions/_GenerateCreateBody.ps1`** — replace the hard-coded credentials block with a
switch:

```powershell
param (
    ...
    $CredentialType = 'ServicePrincipal',
    ...
)

$credentials = switch ($CredentialType) {
    'ServicePrincipal' {
        if ([string]::IsNullOrEmpty($ServicePrincipalClientId)) {
            throw "Connection '$DisplayName' uses ServicePrincipal but no service principal was resolved."
        }
        @{
            credentialType           = 'ServicePrincipal'
            servicePrincipalClientId = $ServicePrincipalClientId
            servicePrincipalSecret   = $ServicePrincipalSecret
            tenantId                 = $TenantId
        }
    }
    # Both of these carry no secret and no parameters - the body is the credentialType alone.
    'WorkspaceIdentity' { @{ credentialType = 'WorkspaceIdentity' } }
    'Anonymous'         { @{ credentialType = 'Anonymous' } }

    # Interactive consent cannot be scripted. Fail with the recipe rather than a REST error
    # or, worse, a half-created connection. (CR-04)
    { $_ -in @('OAuth2', 'Basic', 'Windows') } {
        throw ("Connection '$DisplayName' requires credentialType '$_', which needs " +
               "interactive consent and cannot be created unattended. Create it in the " +
               "portal (Manage connections and gateways -> + New -> Cloud), or switch the " +
               "definition to ServicePrincipal or WorkspaceIdentity.")
    }
    default { throw "Connection '$DisplayName' has unknown credentialType '$_'." }
}
```

**`module/functions/Assert-PBIShareableCloudConnection.ps1`** — the service principal parameters
are currently `[Parameter(Mandatory=$true)]`. **They must become optional**, or a
`WorkspaceIdentity` connection cannot be invoked at all:

```powershell
[Parameter()] [guid]         $ServicePrincipalClientId,
[Parameter()] [securestring] $ServicePrincipalSecret,
[Parameter()] [string]       $TenantId,
[Parameter()] [string]       $CredentialType = 'ServicePrincipal',
```

> ⚠️ **Corrected during implementation.** Revision 2 stated that `[guid]` on an unsupplied
> parameter binds to the **empty GUID** and recommended comparing against `[guid]::Empty`. That
> is wrong, and following it would have made the guard dead code. *(Verified by execution,
> 2026-08-26:)* an unsupplied `[guid]` parameter binds to **`$null`** — so
> `$x -eq [guid]::Empty` is **`False`**, while `[string]::IsNullOrEmpty($x)` and `if (-not $x)`
> both correctly report it as absent. Use `[string]::IsNullOrEmpty()`.
>
> This also means `$Parameters` needs `[AllowEmptyCollection()]`, and the service-principal keys
> must be added to the generate-body splat conditionally — neither was in this document. See
> §1 of [`implementation_plan.md`](implementation_plan.md) for the evidence.

**`module/functions/Resolve-CloudConnections.ps1`** — denormalise `credentialType` alongside
`creationMethod`.

**Tests** — new contexts in `_GenerateCreateBody.Tests.ps1`:
- default (omitted) produces the `ServicePrincipal` body **identical to today** *(CR-N1)*
- `WorkspaceIdentity` produces `credentialDetails.credentials` with exactly one key
- `Anonymous` likewise
- `OAuth2` throws, and the message names the connection
- `ServicePrincipal` with no client id throws with a useful message

---

### Change 4 — Let a connection opt out of credential updates (CR-05, CR-05a, CR-06)

**Revised after review, and the revision matters.** Revision 1 proposed a global switch
defaulting to *off*. That was wrong for a flow this project does not have and the maintainers
do: **Key Vault secret rotation**, where the YAML is unchanged, the secret behind it has been
rotated, and the ADO pipeline must push the new value. A default-off switch would have silently
stopped rotating credentials — replacing a loud failure with a quiet one, which is precisely
what the rest of this document argues against.

**The knowledge of whether a connection is safe to update lives with the connection**, not with
the deployment. A SQL connection wants rotation. A connection backing a OneLake shortcut must
not be touched. So the flag belongs in the connection's own YAML:

```yaml
- displayName: EDAP_DEV_sp__hat
  type: SharePoint
  creationMethod: SharePointList
  credentialType: ServicePrincipal
  allowCredentialUpdate: false      # backs a OneLake shortcut - see README
  useServicePrincipal: development
```

**Default `true`**, which preserves today's behaviour exactly, keeps every existing config
working, and keeps rotation working (CR-N1).

**`module/functions/Assert-PBIShareableCloudConnection.ps1`:**

```powershell
[Parameter()] [bool]   $AllowCredentialUpdate = $true
[Parameter()] [switch] $SkipCredentialUpdates   # run-level override, CR-05a
```

```powershell
if ($existingConnection) {
    if ($SkipCredentialUpdates -or -not $AllowCredentialUpdate) {
        # Updating a connection is not a safe no-op when anything is BOUND to it. Creating a
        # OneLake shortcut binds it to a cloud connection; changing that connection leaves the
        # binding stale, every read then fails 401 Unauthorized on ListBlob, the shortcut still
        # reports healthy, and delete-and-recreate does not reliably recover it. Verified
        # against a live tenant 2026-08-20 - it cost a day of downtime.
        Write-Information "Connection '$DisplayName' already exists - credential updates are disabled for it, leaving it untouched."
        return $existingConnection
    }
    ...existing PATCH path, with the credential type honoured (CR-06)...
}
```

**`module/functions/_GenerateUpdateBody.ps1`** — take `$CredentialType` and build the matching
credentials block, mirroring Change 3. A `WorkspaceIdentity` update body carries no secret, so
the current unconditional service-principal body would be wrong for it.

**`module/functions/Resolve-CloudConnections.ps1`** — denormalise `allowCredentialUpdate`,
defaulting to `$true` when the key is absent.

**`module/tasks/powerbi.properties.ps1`:**

```powershell
# Synopsis: When true, suppresses credential updates for ALL connections in this run, whatever
# their own allowCredentialUpdate setting. For converging structure without touching secrets.
$PowerBiSkipCredentialUpdates ??= $false
```

**Tests:**
- default (key absent): `PATCH` issued, exactly as today *(CR-N1 regression guard)*
- `allowCredentialUpdate: false`: **no** `PATCH`, existing connection returned
- `-SkipCredentialUpdates`: no `PATCH` even where the connection allows it
- `WorkspaceIdentity` update body contains no `servicePrincipalSecret`

> **Read §4.1 before writing this.** Whether a same-type secret *rotation* invalidates a bound
> shortcut is unverified. If it turns out rotation is safe and only credential-*type* changes
> are destructive, this flag is still correct but its documentation changes substantially — it
> becomes advice for a narrower case rather than a standing rule for shortcut-backed
> connections.

---

### Change 5 — Never skip a connection silently (CR-07)

**`module/tasks/powerbi.tasks.ps1`** — the guard on `servicePrincipal.secretUrl` predates
credential types that need no secret. Restructure so the loop processes everything and only the
*secret lookup* is conditional:

```powershell
foreach ($connection in $cloudConnections) {
    Write-Build Green "`nProcessing shared cloud connection: $($connection.displayName)"

    $secretValue = $null
    $credentialType = $connection.credentialType ?? 'ServicePrincipal'

    if ($credentialType -eq 'ServicePrincipal') {
        if (-not $connection.servicePrincipal -or -not $connection.servicePrincipal.ContainsKey('secretUrl')) {
            # Previously this condition skipped the connection with no message at all, so the
            # task reported success having done nothing.
            Write-Warning "Skipping '$($connection.displayName)': credentialType is ServicePrincipal but no servicePrincipal with a secretUrl was resolved."
            continue
        }
        ...existing Key Vault lookup...
    }
    ...existing create/permissions logic, with CredentialType and CreationMethod in the splat...
}
```

---

### Change 6 — Validate against the tenant before creating (CR-08)

New private function `module/functions/_Assert-ValidConnectionType.ps1`:

```powershell
# GET /v1/connections/supportedConnectionTypes?showAllCreationMethods=true
# Paged via continuationToken. Returns entries with .type, .creationMethods[].name and
# .supportedCredentialTypes.
```

Call it once per deployment, before the loop, and fail with the valid creation methods for the
requested type. This turns *"No function found matching 'X' for Kind: 'X'"* — which misdirects
onto the type — into a message naming the actual problem.

Also worth validating `credentialType` against `supportedCredentialTypes` for the type, with one
caveat that should be in the code comment: **support is not access.** A `WorkspaceIdentity`
SharePoint connection is created happily, passes its own test, and then fails the first real
operation. Validation here prevents a malformed request; it proves nothing about whether the
credential can read the source.

*Lower priority than 1–5: it improves diagnosis rather than enabling anything.*

---

### Change 7 — Documentation (CR-N3)

- `docs/functions/*.md` regenerated for `Assert-PBIShareableCloudConnection` and any newly
  public function.
- `README.md` → *Configuration Model Overview* → connection group fields: add
  `creationMethod` (optional, defaults to `type`) and `credentialType` (optional, defaults to
  `ServicePrincipal`), and note that `servicePrincipal` is not required for `WorkspaceIdentity`
  or `Anonymous`.
- A short **"Connections bound to OneLake shortcuts"** note explaining why
  `allowCredentialUpdate` exists. This is the piece of knowledge most worth carrying upstream —
  it is not in Microsoft's documentation and it is not discoverable until it breaks something.

**Put the shortcut warning everywhere**, per the maintainer's *"probably it should be
everywhere"*. It applies to anything that touches a connection, not only to this task:

| Destination | Why |
|---|---|
| This extension's `README.md` | The task that can trigger it |
| `deploy-fabric-connections` skill, `## Gotchas` | What an agent reads before acting |
| `deploy-fabric` skill, `## Gotchas` + `## Related` | That extension creates the workspaces and shortcuts live in them |
| `ZeroFailed.Deploy.Fabric` `README.md` | Same reason |

---

### Change 8 — Rename to `ZeroFailed.Deploy.FabricConnections` (CR-11)

**Accepted by the maintainers.** The extension is expected to stay specific to shared cloud
connections; workspace provisioning, deployment pipelines and the rest live in
[`ZeroFailed.Deploy.Fabric`](https://github.com/zerofailed/ZeroFailed.Deploy.Fabric).

**Do this last.** Every functional change above is easier to review against the current file
and function names, and the rename is then one mechanical commit that touches everything and
changes no behaviour.

| What | From | To |
|---|---|---|
| Repository | `ZeroFailed.Deploy.PowerBI` | `ZeroFailed.Deploy.FabricConnections` |
| Manifest / root module | `module/ZeroFailed.Deploy.PowerBI.psd1` / `.psm1` | `…FabricConnections.psd1` / `.psm1` |
| Module GUID | `00fabf80-…` | **new GUID** — a renamed module is a new module |
| Task file | `module/tasks/powerbi.tasks.ps1` | `module/tasks/fabricConnections.tasks.ps1` |
| Properties file | `module/tasks/powerbi.properties.ps1` | `module/tasks/fabricConnections.properties.ps1` |
| Task name | `deployPowerBISharedCloudConnection` | `deployFabricCloudConnections` |
| Properties | `$PowerBiConfig`, `$PowerBiDryRunMode`, `$PowerBiContinueOnError`, `$CloudConnectionFilters`, `$CloudConnectionsConfigPath` | `$FabricConnectionsConfig`, `$FabricConnectionsDryRunMode`, … |
| Public functions | `Assert-PBIShareableCloudConnection`, `Assert-PBICloudConnectionPermissions`, `Assert-PBICloudConnectionPermissionGroups`, `Get-PBICloudConnectionPermissions`, `Remove-PBICloudConnectionPermission`, `Remove-PBICloudConnectionPermissionBatch` | drop `PBI`, e.g. `Assert-FabricCloudConnection`, `Assert-FabricCloudConnectionPermissions` |
| Alias in `.psm1` | `ZeroFailed.Deploy.PowerBI.tasks` | `ZeroFailed.Deploy.FabricConnections.tasks` |

**`ModuleVersion` is `0.0.1`**, so this is the cheapest it will ever be. That is the argument
for doing it now rather than after more projects take a dependency — and, given pre-1.0, for
**not** carrying back-compat aliases. State the breaking change in the README instead, with the
two-line migration every consumer needs:

```powershell
# .zf/config.ps1 - before
Name = "ZeroFailed.Deploy.PowerBI"
$PowerBiConfig = "./pbiconfig/config.yaml"

# after
Name = "ZeroFailed.Deploy.FabricConnections"
$FabricConnectionsConfig = "./connections/config.yaml"
```

Two things to fix while renaming, both flagged by the `deploy-fabric` skill's own gotchas as
current-convention issues:

- **Migrate the dependency declaration** from the legacy `module/dependencies.psd1` to
  `PrivateData.ZeroFailed.ExtensionDependencies` in the `.psd1`. Follow the
  `author-zerofailed-extension` skill, which is the authority on this.
- **`FunctionsToExport` is commented out** in the manifest, so export is governed only by the
  `.psm1` wildcard. Set it explicitly while the function names are changing anyway.

---

### Change 9 — Expose resolved connection ids (CR-09, CR-10)

**Accepted, with one naming concern to settle first.**

The maintainers suggested `Resolve-CloudConnection`, singular, as a partner to the existing
`Resolve-CloudConnections`. The intent is right; the name is a trap. **The two functions would
do completely different things:**

| | `Resolve-CloudConnections` (existing) | proposed singular |
|---|---|---|
| Input | YAML config files on disk | a display name |
| Talks to Fabric? | **No** — pure config denormalisation | **Yes** — queries the tenant |
| Returns | the desired state | the actual state |

A one-character difference between "read my config" and "call the API" will be mis-called, and
the failure is silent — you get a config object where you expected a live one. **Recommend
`Get-FabricCloudConnection`**, which follows the PowerShell `Get-` convention for retrieval and
cannot be confused with the resolver. *(Maintainer's call — the requirement is CR-10, the name
is a preference.)*

```powershell
function Get-FabricCloudConnection {
    param (
        [Parameter(Mandatory)] [string]       $DisplayName,
        [Parameter(Mandatory)] [securestring] $AccessToken,
        [Parameter()]          [switch]       $ThrowIfMissing
    )
}
```

Returns `$null`, or an object carrying at least:

| Property | Why |
|---|---|
| `id` | The reason the function exists |
| `credentialType` | Lets a caller assert it is not deployed against an interim credential |
| `lastCredentialUsedDateTime` | See below |

Three notes for whoever implements it:

- **`GET /v1/connections` may not carry `credentialDetails`.** HAT's equivalent uses what the
  list returns and falls back to `GET /v1/connections/{id}` — one extra call, negligible at this
  scale. *(Unverified which fields the list endpoint guarantees; the fallback removes the need
  to know.)*
- **Surface `lastCredentialUsedDateTime`.** A connection whose credential has *never* been used
  is either unused, or failing **before** the credential is reached — which is what a
  wrong-tenant binding looks like. Reading this field is what settled a full day's misdiagnosis
  on the HAT project after every other theory had been tried.
- **"Not found" is ambiguous and the message should say so.** A connection you hold no role on
  is not merely unusable, it is *invisible* — even to a tenant admin. So a miss means either
  "not provisioned" or "not shared with this identity", and those have different fixes.

Also add a public `deployFabricCloudConnections` task output, or return value from
`Assert-FabricCloudConnection`, giving `displayName` → `id` for every connection processed
(CR-09). The create path already has the id; today it is only written to the build log.

---

### Change 10 — Update the marketplace skill (CR-N3)

Repository: [zerofailed/zerofailed-marketplace](https://github.com/zerofailed/zerofailed-marketplace).

**The skill to change is `deploy-powerbi`, not `deploy-fabric`.** `plugins/zerofailed-tools/skills/deploy-fabric`
documents `ZeroFailed.Deploy.Fabric` — workspace provisioning, Git integration, RBAC, deployment
pipelines — and is a different extension.
`plugins/zerofailed-tools/skills/deploy-powerbi` is the one that documents *this* module: its
description already reads *"declarative Power BI/Fabric shared cloud connections and their
owner/user/reshare permission synchronization via YAML config"*.

**Rename the skill directory** `deploy-powerbi` → `deploy-fabric-connections`, and update the
frontmatter:

```yaml
---
name: deploy-fabric-connections
description: Use when configuring or troubleshooting a ZeroFailed deployment that uses ZeroFailed.Deploy.FabricConnections — declarative Fabric shared cloud connections (SharePoint, Fabric pipelines, SQL, blob) and their owner/user/reshare permission synchronization via YAML config. Covers connection types and creation methods, credential types including workspace identity, its properties, tasks, YAML configuration schema, and dependency chain.
---
```

Then, section by section:

| Section | Change |
|---|---|
| `## Configuration (YAML)` → *4. Connection groups* | Add `creationMethod`, `credentialType` and `allowCredentialUpdate`, each with its default and the reason it exists |
| `## Properties` | Rename every `$PowerBi*`, add `$FabricConnectionsSkipCredentialUpdates` |
| `## Tasks` | `deployPowerBISharedCloudConnection` → `deployFabricCloudConnections` |
| `## Functions` | Add `Get-FabricCloudConnection`; rename the `PBI`-prefixed ones |
| `## Usage` | Update the `.zf/config.ps1` sample; add a migration note for the rename |
| `## Gotchas` | Add the four below |

The gotchas are the highest-value part of the skill, because they are what an agent reads before
it does something irreversible:

- **`type` and `creationMethod` are different things, and often differ.** `SharePoint` uses
  `SharePointList`; `FabricDataPipelines` uses `FabricDataPipelines.Actions`. A valid type with
  the wrong creation method fails *"No function found matching 'X' for Kind: 'X'"*, which reads
  as though the type is wrong.
- **Never update a connection that OneLake shortcuts are bound to.** Set
  `allowCredentialUpdate: false`. Changing such a connection leaves every bound shortcut failing
  `401 Unauthorized on ListBlob` while still reporting healthy, and delete-and-recreate does not
  reliably recover it.
- **A passing connection test is not evidence of source access.** A `WorkspaceIdentity`
  SharePoint connection is created happily, passes its own test, and then fails the first real
  operation. The test proves the credential could be *acquired*.
- **Credential type is effectively immutable.** Delete and recreate rather than switching in
  place — and note that recreating yields a **new connection id**, so anything bound to the old
  one needs rebinding.

**Also add a cross-reference to the `deploy-fabric` skill.** The two extensions are used
together — workspaces from one, the connections those workspaces need from the other — and the
shortcut warning belongs in both, per the maintainer's *"probably it should be everywhere"*. A
`## Related` line in each pointing at the other is enough.

---

### Target configuration

The two HAT connections, once all of the above lands. This is the acceptance test for the whole
change set:

```yaml
version: '1.0'

cloudConnections:
  # Backs a OneLake shortcut, so it must never be re-PATCHed by a routine deployment.
  - displayName: EDAP_DEV_sp__hat
    type: SharePoint
    creationMethod: SharePointList          # CR-01: differs from type
    credentialType: ServicePrincipal        # CR-02
    allowCredentialUpdate: false            # CR-05: bound shortcut - do not touch
    useServicePrincipal: development
    target:
      parameters:
        - dataType: Text
          name: sharePointSiteUrl
          value: https://contoso.sharepoint.com/sites/example
    permissions:
      users:
        - principalId: "<security-group-object-id>"
          principalType: "Group"

  # Required by every InvokePipeline activity. No secret, no parameters, no service principal.
  - displayName: EDAP_DEV_fp__shared
    type: FabricDataPipelines
    creationMethod: FabricDataPipelines.Actions
    credentialType: WorkspaceIdentity       # CR-02, CR-03 - no servicePrincipal block at all
    target:
      parameters: []
    permissions:
      users:
        - principalId: "<security-group-object-id>"
          principalType: "Group"
```

Note the `permissions` block on both. A connection carries its **own** access list, independent
of workspace RBAC: a connection you are not on is not merely unusable, it is *invisible*, even
to a tenant admin. Omit this and the pipeline works for whoever created the connection and
fails for everyone else — a failure that surfaces at handover rather than in testing. The
extension's existing permission management handles it; it just has to be used.

---

### Suggested commit sequence

| # | Commit | Risk |
|---|---|---|
| 1 | Fix the null-service-principal crash (Change 2) | None — bug fix, existing configs unaffected |
| 2 | Decouple `creationMethod` from `type` (Change 1) | None — additive, defaults preserve behaviour |
| 3 | Support `WorkspaceIdentity` / `Anonymous`, reject interactive (Change 3) | Low — additive |
| 4 | Warn instead of skipping silently (Change 5) | Low — new warnings may appear in existing runs, which is the point |
| 5 | `allowCredentialUpdate`, default true (Change 4) | Low — **defaults preserve today's behaviour**, unlike revision 1. Settle §4.1 first |
| 6 | `Get-FabricCloudConnection` and id output (Change 9) | None — new function |
| 7 | Validate against `supportedConnectionTypes` (Change 6) | Low |
| 8 | Documentation, including the shortcut warning everywhere (Change 7) | None |
| 9 | **Rename to `ZeroFailed.Deploy.FabricConnections` (Change 8)** | **Breaking — own commit, own review, mechanical only** |
| 10 | Marketplace skill rename and rewrite (Change 10) | None — separate repository |

Commits 1–8 are on the current names, so each diff is readable against the code as it stands.
The rename lands once, changes no behaviour, and commit 10 follows it in the other repository.

### Definition of done

- [ ] Existing Pester suite green, unchanged.
- [ ] An existing `SQL` config produces a byte-identical create body *(CR-N1)*.
- [ ] A `SharePoint` / `SharePointList` connection is created successfully against a real tenant.
- [ ] A `FabricDataPipelines` / `WorkspaceIdentity` connection is created successfully, with no
      service principal declared anywhere in its config.
- [ ] Re-running against the shortcut-backed connection (`allowCredentialUpdate: false`) issues
      **no** `PATCH`; re-running against a connection without the flag still does.
- [ ] A rotated Key Vault secret still reaches its connection on the next deployment.
- [ ] An `OAuth2` definition fails with a message naming the connection and the alternative.
- [ ] A `ServicePrincipal` connection with no `secretUrl` **warns** and continues.
- [ ] `Get-FabricCloudConnection` returns the id and credential type of an existing connection,
      and `$null` for an absent one.
- [ ] After the rename, a consuming `.zf/config.ps1` works with the two-line migration and no
      other change.

---

## 4. Open questions

Four of the original questions were answered by review and are now folded into §2 and §3. Two
remain, both raised by the maintainers, and **neither can be answered from this project's
evidence.**

### 4.1 Does a same-type secret rotation break a bound shortcut?

**Settle this before writing Change 4.** *(Unverified.)*

HAT's evidence covers a credential **change** and a **rename** over `PATCH`. It does not cover
rotating a secret while keeping the same service principal and the same credential type — which
is the routine ADO flow the maintainers described.

Two outcomes, and they lead to different documentation:

| If rotation is **safe** | If rotation **also** breaks bindings |
|---|---|
| `allowCredentialUpdate: false` becomes advice for the narrow case of changing credential *type* | It is a standing rule for every shortcut-backed connection, and rotation for those becomes a delete-recreate-rebind procedure rather than a pipeline step |

**Cheap test:** create a shortcut against a service-principal connection, read through it,
rotate the secret in Key Vault, re-run the deployment, read again. Ten minutes, and it decides
how the feature is described.

### 4.2 Does deleting and recreating a connection break a semantic model's binding to it?

Raised by the maintainers, and it matters more than it first appears because "delete and
recreate" is the standing advice for credential-type changes throughout this document.

**Reasoning, not evidence:** a recreated connection gets a **new GUID**. Anything that binds by
id — a semantic model's SCC binding, a OneLake shortcut, a pipeline activity's connection
reference — is then pointing at an object that no longer exists. By construction it should
dangle. *(Unverified: nobody has tested a semantic model specifically, and it is possible the
binding is resolved by name or repaired on refresh.)*

If that reasoning holds, two things follow and both are worth writing down:

1. **Delete-and-recreate is not a cheap fallback.** Every consumer must be re-bound afterwards,
   and there is no inventory of what is bound to a given connection. That materially raises the
   value of making in-place rotation work well, which is the opposite conclusion to revision 1.
2. **The advice needs a caveat wherever it appears** — in this document, in the extension
   README, and in both skills.

**Test:** bind a semantic model to a shared cloud connection, delete and recreate the
connection with the same display name and settings, and see whether the model still refreshes.

> Both questions share a shape worth noting: **a connection is not a leaf.** Things bind to it —
> shortcuts, semantic models, pipeline activities — and none of those bindings are visible from
> the connection itself. Until there is a way to enumerate them, any operation that changes a
> connection's identity or credential is acting with incomplete information. That is the real
> argument for `allowCredentialUpdate` living in configuration: it is the only place a human can
> record what they know and the API cannot.
