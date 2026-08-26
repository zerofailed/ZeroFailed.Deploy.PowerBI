# Implementation plan — `ZeroFailed.Deploy.PowerBI` → `ZeroFailed.Deploy.FabricConnections`

> Derived from [`zerofailed_connection_extension_plan.md`](zerofailed_connection_extension_plan.md) (revision 2).
> Baseline commit: `e1b7843`. Branch: `feature/fabric-connections`.
>
> This document is the *execution* plan: the proposal says what to change and why, this says
> in what order, against which lines, with which tests, and what must be true before each
> commit is raised. Where reading the code changed the proposal's instructions, that is
> recorded in §1 — **read §1 before writing any code**, two of the four items would otherwise
> produce code that silently does nothing.

---

## 0. Preconditions

### 0.1 Tooling

`Pester 3.4.0` (the Windows in-box version) is the only Pester on this machine. The suite is
Pester 5 (`BeforeDiscovery`, `-ForEach`, `Should -Invoke`). Before anything else:

```powershell
Install-PSResource Pester -Scope CurrentUser -TrustRepository
Install-PSResource powershell-yaml -Scope CurrentUser -TrustRepository   # 0.4.12 already present
```

Full build (installs ZeroFailed, runs Pester, regenerates markdown docs):

```powershell
./build.ps1
```

Fast inner loop while iterating on one function:

```powershell
Invoke-Pester ./module/functions/_GenerateCreateBody.Tests.ps1 -Output Detailed
```

### 0.2 Record the baseline

Run the suite and **save the output** before the first edit. Every commit below must leave it
green, and CR-N1 (byte-identical bodies for existing `SQL` / `AzureBlobs` configs) is the
acceptance bar for the whole change set.

```powershell
Invoke-Pester ./module -Output Detailed | Tee-Object -FilePath ./_baseline-pester.txt
```

### 0.3 One decision to take before WP5

§4.1 of the proposal — *does a same-type secret rotation invalidate a bound OneLake shortcut?* —
is unverified and changes how `allowCredentialUpdate` is **documented**, not how it is built.
WP5 can therefore be implemented on schedule; only its README/skill wording (WP8, WP10) is
blocked on the answer. The ten-minute tenant test is described in §4.1 of the proposal. Treat
"unanswered" as a documentation TODO, not as a reason to hold WP5.

---

## 1. Corrections to the proposal, found by reading the code

Four items. Each was verified by execution on 2026-08-26 with `pwsh` 7 against an isolated
repro; the first two would otherwise produce broken code.

### 1.1 ⚠️ An unsupplied `[guid]` parameter binds to `$null`, **not** `[guid]::Empty`

The proposal's warning box in Change 3 says the opposite and recommends
`-eq [guid]::Empty` as the safe check. That check **never fires**:

```
IsNull                  : True
$Spn -eq [guid]::Empty  : False
[string]::IsNullOrEmpty : True
if ($Spn) {...}         : false
```

**Consequence:** follow the proposal's advice and the "no service principal was resolved"
throw in `_GenerateCreateBody` becomes dead code, and a `ServicePrincipal` connection with a
missing client id reaches the REST API instead of failing with the intended message.

**Use** `[string]::IsNullOrEmpty($ServicePrincipalClientId)` — or plain `if (-not $x)`, which is
also correct. Delete the warning box from the proposal when WP8 touches the docs.

### 1.2 A `WorkspaceIdentity` connection cannot bind `-Parameters @()` — not mentioned in the proposal

[Assert-PBIShareableCloudConnection.ps1:16-17](../module/functions/Assert-PBIShareableCloudConnection.ps1#L16-L17) declares:

```powershell
[Parameter(Mandatory=$true)]
[hashtable[]] $Parameters,
```

The target config for `EDAP_DEV_fp__shared` has `parameters: []`, which denormalises to an empty
array. Verified:

```
EMPTY ARRAY BIND FAILED: Cannot bind argument to parameter 'Parameters' because it is an empty array.
```

So the acceptance test in the proposal's *Target configuration* section fails at **parameter
binding**, before any of the new credential-type logic runs. Change 3 only removes `Mandatory`
from the service-principal parameters; `$Parameters` needs it too, plus
`[AllowEmptyCollection()]`:

```powershell
[Parameter()]
[AllowEmptyCollection()]
[hashtable[]] $Parameters = @(),
```

A `null` `target` (no `target:` key at all) also needs to survive — prefer defaulting to `@()`
in `Resolve-CloudConnections` so the shape is settled in one place.

### 1.3 The secret is unwrapped unconditionally on the call path Change 3 opens up

[Assert-PBIShareableCloudConnection.ps1:48](../module/functions/Assert-PBIShareableCloudConnection.ps1#L48) and [:67](../module/functions/Assert-PBIShareableCloudConnection.ps1#L67):

```powershell
servicePrincipalSecret = $ServicePrincipalSecret | ConvertFrom-SecureString -AsPlainText
```

With `$ServicePrincipalSecret` unsupplied (every `WorkspaceIdentity` / `Anonymous` connection)
this raises *"Cannot bind argument to parameter 'SecureString' because it is null."* Under the
build's `$ErrorActionPreference = 'Stop'` it becomes terminating and is swallowed by the
function's own `catch`, surfacing as a generic *"Failed to process cloud connection"*.

**Build the splat conditionally** — only add the three service-principal keys when the
credential type is `ServicePrincipal`. This belongs in WP3 alongside the `switch`.

### 1.4 `GET /v1/connections` is not paged

[Assert-PBIShareableCloudConnection.ps1:42](../module/functions/Assert-PBIShareableCloudConnection.ps1#L42) filters `displayName` over a single unpaged
response; there is no `continuationToken` handling. In a tenant with more connections than one
page, an existing connection is not found and the task attempts a **create**, which fails on
duplicate display name.

This is pre-existing and out of the proposal's scope, but WP6 (`Get-FabricCloudConnection`)
needs paged retrieval anyway. **Write the paging helper once as a private function and have
both call sites use it** — the marginal cost is near zero and it removes a latent bug.

---

## 2. Work packages

Ordered as the proposal's *Suggested commit sequence*: behaviour changes land on the current
names so each diff reads against the code as it stands, then the rename is one mechanical
commit. One commit per work package.

| WP | Commit | Proposal | Requirements | Risk |
|----|--------|----------|--------------|------|
| WP1 | Fix the null-service-principal crash | Change 2 | CR-03 | None |
| WP2 | Decouple `creationMethod` from `type` | Change 1 | CR-01 | None |
| WP3 | Credential types beyond `ServicePrincipal` | Change 3 | CR-02, CR-03, CR-04 | Low |
| WP4 | Warn instead of skipping silently | Change 5 | CR-07 | Low |
| WP5 | `allowCredentialUpdate`, default `true` | Change 4 | CR-05, CR-05a, CR-06 | Low |
| WP6 | `Get-FabricCloudConnection` + id output | Change 9 | CR-09, CR-10 | None |
| WP7 | Validate against `supportedConnectionTypes` | Change 6 | CR-08 | Low |
| WP8 | Documentation, shortcut warning everywhere | Change 7 | CR-N3 | None |
| WP9 | **Rename the module** | Change 8 | CR-11 | **Breaking** |
| WP10 | Marketplace skill rename and rewrite | Change 10 | CR-N3 | None — other repo |

---

### WP1 — Fix the null-service-principal crash (CR-03, part 1)

**Confirmed as described.** The repro reproduces exactly:
`THROWS: You cannot call a method on a null-valued expression.`

[Resolve-CloudConnections.ps1:99-112](../module/functions/Resolve-CloudConnections.ps1#L99-L112) — replace the unconditional
`else` + default-tenant block with the guarded form from the proposal.

One detail the proposal's guard gets right and is easy to get wrong when retyping it: after
`$d.servicePrincipal = $null`, `$d.ContainsKey('servicePrincipal')` is **`True`** (verified).
The `-and $denormalized.servicePrincipal` clause is load-bearing — keep both halves.

**Tests** — [Resolve-CloudConnections.Tests.ps1](../module/functions/Resolve-CloudConnections.Tests.ps1):

- a connection with neither `servicePrincipal` nor `useServicePrincipal` resolves without
  throwing. **Write this test first and watch it fail**, so it is known to test something.
- `Development SQL Database1` still receives `tenantId` from its own SP (existing test).
- `Test SQL Database` still receives the default tenant (existing test).

**Test data** — add a no-credential connection to [module/_test-data/connections/testing.yaml](../module/_test-data/connections/testing.yaml).
Note this raises the expected connection count from **7 to 8** in
`Resolve-CloudConnections.Tests.ps1` (two assertions) — an intentional, reviewable diff.

**Done when:** suite green; the new test fails on `HEAD~1` and passes on `HEAD`.

---

### WP2 — Decouple `creationMethod` from `type` (CR-01)

[_GenerateCreateBody.ps1](../module/functions/_GenerateCreateBody.ps1) — add `$CreationMethod` to the `param` block,
default it to `$ConnectionType` when null or empty, use it at [line 62](../module/functions/_GenerateCreateBody.ps1#L62). Carry the explanatory
comment from the proposal into the source: the *"No function found matching 'X' for Kind: 'X'"*
misdirection is the whole reason the parameter exists, and it is not in Microsoft's docs.

Update the comment-based help too — `.PARAMETER ConnectionType` currently reads *"which is also
used as the creation method"*, which becomes false.

[Resolve-CloudConnections.ps1:94-97](../module/functions/Resolve-CloudConnections.ps1#L94-L97) — denormalise `creationMethod` beside
`type`. May be `$null`; defaulted downstream.

[Assert-PBIShareableCloudConnection.ps1](../module/functions/Assert-PBIShareableCloudConnection.ps1) — add `[Parameter()] [string] $CreationMethod` and pass it into `$generateBodySplat` in the create branch only.

[powerbi.tasks.ps1:66-75](../module/tasks/powerbi.tasks.ps1#L66-L75) — add `CreationMethod = $connection.creationMethod`
to the splat.

**Tests** — `_GenerateCreateBody.Tests.ps1` **does not exist yet**; both body generators are
currently untested. Create it, following the dot-source convention used by
[Assert-PBIShareableCloudConnection.Tests.ps1](../module/functions/Assert-PBIShareableCloudConnection.Tests.ps1):

- omitted `CreationMethod` → `creationMethod -eq $ConnectionType` *(CR-N1 regression guard)*
- supplied `CreationMethod` → used verbatim
- `type: SharePoint` / `creationMethod: SharePointList`

**Done when:** an `AzureBlobs` create body is byte-identical to the baseline
(`ConvertTo-Json -Compress -Depth 100` string comparison is the cheapest way to assert this).

---

### WP3 — Credential types beyond `ServicePrincipal` (CR-02, CR-03, CR-04)

The largest package. Four files.

[_GenerateCreateBody.ps1](../module/functions/_GenerateCreateBody.ps1) — replace the hard-coded `credentials` block at
[lines 70-75](../module/functions/_GenerateCreateBody.ps1#L70-L75) with the `switch` from the proposal, `$CredentialType = 'ServicePrincipal'` by
default. Guard the `ServicePrincipal` arm with `[string]::IsNullOrEmpty(...)` per §1.1, **not**
`-eq [guid]::Empty`.

[Assert-PBIShareableCloudConnection.ps1](../module/functions/Assert-PBIShareableCloudConnection.ps1):

- `$ServicePrincipalClientId`, `$ServicePrincipalSecret`, `$TenantId` → `[Parameter()]`
- `$Parameters` → `[Parameter()] [AllowEmptyCollection()] [hashtable[]] $Parameters = @()` *(§1.2)*
- add `[Parameter()] [string] $CredentialType = 'ServicePrincipal'`
- build `$generateBodySplat` **conditionally**, adding the three SP keys only when
  `$CredentialType -eq 'ServicePrincipal'` *(§1.3 — otherwise the `ConvertFrom-SecureString`
  pipe throws on a null secret)*

[Resolve-CloudConnections.ps1](../module/functions/Resolve-CloudConnections.ps1) — denormalise `credentialType` beside
`creationMethod`. Also default `$denormalized.target` to `@()` when the connection declares no
target, so `$Parameters` always has a well-formed shape *(§1.2)*.

[powerbi.tasks.ps1](../module/tasks/powerbi.tasks.ps1) — pass `CredentialType` in the splat. (The surrounding
guard is restructured in WP4; keep this commit to the splat.)

**Tests** — new contexts in `_GenerateCreateBody.Tests.ps1`:

- default (omitted) → `ServicePrincipal` body identical to today *(CR-N1)*
- `WorkspaceIdentity` → `credentialDetails.credentials` has exactly one key, `credentialType`
- `Anonymous` → likewise
- `OAuth2`, `Basic`, `Windows` → throw, message contains the connection display name and the
  portal path
- unknown value → throws
- `ServicePrincipal` with no client id → throws with a useful message *(the §1.1 regression
  guard — this test is what proves the null check is right)*

In `Assert-PBIShareableCloudConnection.Tests.ps1`:

- `-CredentialType WorkspaceIdentity` with no SP parameters and `-Parameters @()` issues a
  `POST` and does not throw *(the §1.2/§1.3 guard)*

**Done when:** the `EDAP_DEV_fp__shared` shape from the proposal's *Target configuration*
survives a full dry run through `Resolve-CloudConnections` → `Assert-…` with the REST call
mocked.

---

### WP4 — Never skip a connection silently (CR-07)

[powerbi.tasks.ps1:41](../module/tasks/powerbi.tasks.ps1#L41) — the guard
`if (($connection | Get-Member -Name servicePrincipal) -and $connection.servicePrincipal.ContainsKey("secretUrl"))`
wraps the **entire** loop body and has no `else`. Restructure per the proposal so the loop
processes every connection and only the *Key Vault lookup* is conditional on
`credentialType -eq 'ServicePrincipal'`.

Keep the Key Vault lookup — including the `Az.KeyVault` ≥ 6.3.0 / legacy branch at [lines 46-63](../module/tasks/powerbi.tasks.ps1#L46-L63) —
byte-identical; move it, do not rewrite it. That block is load-bearing and untested.

The `continue` path must `Write-Warning` naming the connection and the reason. This is the
point of the change: a run that previously reported success having done nothing will now say so.

**Tests:** the task file is not directly Pester-covered today (the module tests only assert
structure and copyright). Do not build a task-execution harness for this — instead assert the
new behaviour at the boundary it is observable from, and note the gap in the PR description.

**Done when:** a `ServicePrincipal` connection with no `secretUrl` warns and the loop continues
to the next connection.

---

### WP5 — Let a connection opt out of credential updates (CR-05, CR-05a, CR-06)

**Default `true`** — this is what makes the change non-breaking and keeps Key Vault secret
rotation working. Do not invert it.

[Assert-PBIShareableCloudConnection.ps1](../module/functions/Assert-PBIShareableCloudConnection.ps1):

```powershell
[Parameter()] [bool]   $AllowCredentialUpdate = $true,
[Parameter()] [switch] $SkipCredentialUpdates
```

`[bool]` not `[switch]`, deliberately: `false` must be expressible from YAML. Early-return the
existing connection when either suppresses the update, with the shortcut-outage explanation as a
code comment — it is the piece of knowledge most worth carrying upstream and it is not in
Microsoft's documentation.

[_GenerateUpdateBody.ps1](../module/functions/_GenerateUpdateBody.ps1) — add `$CredentialType` and mirror WP3's switch.
A `WorkspaceIdentity` update body carries no secret; the current unconditional
service-principal body is wrong for it (CR-06). Factor the switch into a shared private
function rather than duplicating it across the two generators.

[Resolve-CloudConnections.ps1](../module/functions/Resolve-CloudConnections.ps1) — denormalise `allowCredentialUpdate`,
defaulting to `$true` when the key is absent. Careful: `$conn.allowCredentialUpdate` is `$null`
when absent and `$false` when present-and-false — test `ContainsKey`, not truthiness.

[powerbi.properties.ps1](../module/tasks/powerbi.properties.ps1) — add `$PowerBiSkipCredentialUpdates ??= $false`
(renamed to `$FabricConnectionsSkipCredentialUpdates` in WP9), and pass both values through the
task splat.

**Tests** — `Assert-PBIShareableCloudConnection.Tests.ps1`:

- key absent → `PATCH` issued, exactly as today *(CR-N1 regression guard)*
- `-AllowCredentialUpdate $false` → **no** `PATCH`, existing connection object returned
- `-SkipCredentialUpdates` → no `PATCH` even where the connection allows it
- `WorkspaceIdentity` update body contains no `servicePrincipalSecret`

and in `Resolve-CloudConnections.Tests.ps1`, that `allowCredentialUpdate: false` in YAML
survives denormalisation as `$false` rather than being defaulted back to `$true`.

**Documentation is blocked on §4.1**, the code is not — see §0.3.

---

### WP6 — Expose resolved connection ids (CR-09, CR-10)

New public function `module/functions/Get-FabricCloudConnection.ps1`. **Use `Get-`, not
`Resolve-CloudConnection`**: the proposal's reasoning holds — a one-character difference between
"read my config" (no API call, desired state) and "call the tenant" (actual state) will be
mis-called, and the failure is silent. Flag the name in the PR for the maintainers, since it is
their preference to overrule.

```powershell
Get-FabricCloudConnection -DisplayName <string> -AccessToken <securestring> [-ThrowIfMissing]
```

Returns `$null`, or an object carrying at least `id`, `credentialType`,
`lastCredentialUsedDateTime`.

Three implementation notes, all from the proposal and all worth honouring:

- **Page the list** *(§1.4)* — write the `continuationToken` loop as a private helper and
  retro-fit [Assert-PBIShareableCloudConnection.ps1:42](../module/functions/Assert-PBIShareableCloudConnection.ps1#L42) to use it in this same commit.
- **Fall back to `GET /v1/connections/{id}`** when the list entry carries no
  `credentialDetails`. One extra call, negligible at this scale, and it removes the need to know
  what the list endpoint guarantees.
- **Make "not found" say it is ambiguous.** A connection you hold no role on is *invisible*,
  even to a tenant admin. "Not provisioned" and "not shared with this identity" have different
  fixes and the message must name both.

Also surface `displayName` → `id` for every processed connection from
`deployPowerBISharedCloudConnection` (CR-09). The create path already has the id at
[powerbi.tasks.ps1:80](../module/tasks/powerbi.tasks.ps1#L80); today it only reaches the build log.

**Tests** — new `Get-FabricCloudConnection.Tests.ps1` (a public function, so the module test
suite **requires** a `.Tests.ps1` beside it): found on page 1; found on page 2 via
continuation token; not found → `$null`; not found with `-ThrowIfMissing` → throws with the
both-causes message; list entry without `credentialDetails` → falls back to the by-id GET.

---

### WP7 — Validate against `supportedConnectionTypes` (CR-08)

New private `module/functions/_Assert-ValidConnectionType.ps1`, calling
`GET /v1/connections/supportedConnectionTypes?showAllCreationMethods=true` **once per
deployment** — cache the result, do not call it per connection.

Turn *"No function found matching 'X' for Kind: 'X'"* into a message naming the actual problem
and listing the valid creation methods for the requested type.

Validate `credentialType` against `supportedCredentialTypes` too, with this caveat **in the code
comment** so nobody mistakes what the check proves: **support is not access.** A
`WorkspaceIdentity` SharePoint connection is created happily, passes `skipTestConnection: false`,
and then fails the first real operation with *"Unauthorized exception, failed to retrieve
SharePoint drives"*. Validation prevents a malformed request; it says nothing about whether the
credential can read the source.

Lowest-value of WP1-WP7 — it improves diagnosis rather than enabling anything. If time is short,
this is the one to defer.

---

### WP8 — Documentation (CR-N3)

- Regenerate [docs/functions/](functions/) — this happens as part of `./build.ps1`
  (`$PSMarkdownDocsOutputPath = './docs/functions'`); do not hand-edit.

> **Two traps in the doc generation, both found the hard way.**
>
> **Keep every `.PARAMETER` description to a single short sentence.** `GeneratePSMarkdownDocs`
> runs `New-MarkdownCommandHelp` *and then* `Update-CommandHelp` over the same files. For a
> description PlatyPS renders across more than one line, the update pass appends it again
> instead of replacing it — so the text doubles on **every** build, compounding each run. A
> one-sentence description round-trips unchanged. Put the prose in `.DESCRIPTION`, which does
> not suffer from this, or in this README. Verify by running `GeneratePSMarkdownDocs` twice
> and diffing; a stable file is the acceptance test. This is an upstream defect in
> `ZeroFailed.Build.PowerShell` and is worth reporting there.
>
> **`.OUTPUTS` is split on commas**, each fragment treated as a type name. Give it a bare type
> and put the sentence in `.NOTES`. The description under the type heading is hand-written into
> the `.md` and preserved across regenerations — that is this repo's existing convention.
- [README.md](../README.md) → *Configuration Model Overview* → §4 *Connection Groups*: add `creationMethod`
  (optional, defaults to `type`), `credentialType` (optional, defaults to `ServicePrincipal`),
  `allowCredentialUpdate` (optional, defaults to `true`), and state that `servicePrincipal` is
  not required for `WorkspaceIdentity` or `Anonymous`.
- New README section **"Connections bound to OneLake shortcuts"** explaining why
  `allowCredentialUpdate` exists.
- Delete the inverted `[guid]::Empty` warning from
  [`zerofailed_connection_extension_plan.md`](zerofailed_connection_extension_plan.md) and
  record the §1 corrections there, so the proposal and the code do not disagree.

**Put the shortcut warning everywhere** (maintainer: *"probably it should be everywhere"*):

| Destination | Repository |
|---|---|
| This extension's `README.md` | here |
| `deploy-fabric-connections` skill → `## Gotchas` | zerofailed-marketplace (WP10) |
| `deploy-fabric` skill → `## Gotchas` + `## Related` | zerofailed-marketplace (WP10) |
| `ZeroFailed.Deploy.Fabric` `README.md` | separate repo — raise a PR |

The final row is a fourth repository and needs its own PR; flag it rather than letting it drop.

---

### WP9 — Rename to `ZeroFailed.Deploy.FabricConnections` (CR-11)

**Last, and mechanical only — no behaviour change in this commit.** `ModuleVersion` is `0.0.1`,
so this is the cheapest it will ever be, and pre-1.0 means **no back-compat aliases**: state the
breaking change in the README with the two-line migration instead.

The rename map is in Change 8 of the proposal. Beyond it, five things this repo specifically needs:

1. **New module GUID.** A renamed module is a new module — `00fabf80-…` must not be reused.
2. [module/ZeroFailed.Deploy.PowerBI.module.tests.ps1](../module/ZeroFailed.Deploy.PowerBI.module.tests.ps1) derives `$moduleName` from its own
   filename and asserts `$moduleName.psm1` / `.psd1` exist. Rename it and the suite follows;
   miss it and the failure message is confusing.
3. [.zf/config.ps1:19](../.zf/config.ps1#L19) hard-codes `ModulePath = "$here/module/ZeroFailed.Deploy.PowerBI.psd1"` —
   the build breaks if this is missed.
4. **`Set-Alias ZeroFailed.Deploy.PowerBI.tasks`** in [the .psm1](../module/ZeroFailed.Deploy.PowerBI.psm1), and the matching
   `-Alias` on `Export-ModuleMember`. Both must change together.
5. **`LicenseUri` / `ProjectUri`** in the manifest's `PSData` point at the old repository URL.

Two current-convention fixes to make while renaming, both flagged by the `deploy-fabric` skill's
own gotchas:

- [module/dependencies.psd1](../module/dependencies.psd1) **is the legacy declaration** and duplicates
  `PrivateData.ZeroFailed.ExtensionDependencies` in the `.psd1` — which already exists and is
  the current form. Delete the legacy file. Follow the `author-zerofailed-extension` skill,
  which is the authority here.
- **`FunctionsToExport` is commented out** in the manifest, so export is governed only by the
  `.psm1` wildcard. Set it explicitly while the function names are changing anyway.

One thing to raise rather than silently change: [powerbi.properties.ps1](../module/tasks/powerbi.properties.ps1) uses `=` for
`$PowerBiConfig`, `$PowerBiDryRunMode` and `$PowerBiContinueOnError` but `??=` for
`$CloudConnectionFilters` and `$CloudConnectionsConfigPath`. The `??=` form is the ZeroFailed
convention for consumer-overridable properties. Normalising all five is a one-line-each fix that
belongs in this commit — but confirm with the maintainers first, since it changes override
semantics rather than just names.

**Done when:** a consuming `.zf/config.ps1` works after the two-line migration and no other
change, and `./build.ps1` is green.

---

### WP10 — Marketplace skill (CR-N3)

Repository: `zerofailed/zerofailed-marketplace` — **not in this workspace**, needs a separate
clone and PR.

Rename `plugins/zerofailed-tools/skills/deploy-powerbi` → `deploy-fabric-connections`, rewrite
the frontmatter and the sections per the table in Change 10 of the proposal, and add the four
gotchas — those are the highest-value part, because they are what an agent reads before doing
something irreversible.

Note the skill to change is **`deploy-powerbi`**, not `deploy-fabric`: the latter documents
`ZeroFailed.Deploy.Fabric` (workspaces, Git integration, RBAC, deployment pipelines), a
different extension. Add a `## Related` cross-reference in each pointing at the other.

---

## 3. Definition of done

Carried from the proposal, plus the items §1 added. Unit-testable rows are gated by the suite;
the tenant rows need a real Fabric tenant and cannot be closed from this repository alone.

**Gated by `./build.ps1`:**

- [ ] Existing Pester suite green.
- [ ] An existing `SQL` config produces a byte-identical create body *(CR-N1)*.
- [ ] An existing `AzureBlobs` config produces a byte-identical create body *(CR-N1)*.
- [ ] A connection with no service principal resolves without throwing *(CR-03, WP1)*.
- [ ] A `WorkspaceIdentity` connection with `parameters: []` binds and POSTs *(§1.2, §1.3)*.
- [ ] An `OAuth2` definition fails with a message naming the connection and the alternative *(CR-04)*.
- [ ] A `ServicePrincipal` connection with **no client id** throws *(the §1.1 guard)*.
- [ ] A `ServicePrincipal` connection with no `secretUrl` **warns** and continues *(CR-07)*.
- [ ] `allowCredentialUpdate: false` → no `PATCH`; key absent → `PATCH`, as today *(CR-05)*.
- [ ] `-SkipCredentialUpdates` → no `PATCH` anywhere *(CR-05a)*.
- [ ] `WorkspaceIdentity` update body carries no `servicePrincipalSecret` *(CR-06)*.
- [ ] `Get-FabricCloudConnection` returns id and credential type, `$null` for absent, and finds
      a connection on page 2 *(CR-10, §1.4)*.

**Needs a tenant:**

- [ ] A `SharePoint` / `SharePointList` connection is created successfully.
- [ ] A `FabricDataPipelines` / `WorkspaceIdentity` connection is created successfully, with no
      service principal declared anywhere in its config.
- [ ] A rotated Key Vault secret still reaches its connection on the next deployment.
- [ ] §4.1 answered: does a same-type secret rotation invalidate a bound shortcut?
- [ ] §4.2 answered: does delete-and-recreate break a semantic model's binding?

**Needs another repository:**

- [ ] `ZeroFailed.Deploy.Fabric` README carries the shortcut warning *(WP8)*.
- [ ] `zerofailed-marketplace` skill renamed and rewritten *(WP10)*.

---

## 4. What this plan does not do

- **Writing connection ids into downstream config files.** Reading is in scope (CR-10); writing
  is not. A deploy task that edits source files is a poor fit for ZeroFailed.
- **Shortcut awareness.** The extension cannot know a shortcut is bound to a connection.
  `allowCredentialUpdate` puts the decision in the connection's own configuration, which is the
  only place that knowledge exists.
- **Deployment-pipeline features.** Those belong in `ZeroFailed.Deploy.Fabric`.
- **Touching the permission-management path** (CR-N4). It works, it is the most valuable part of
  the extension, and nothing here needs it to change.
