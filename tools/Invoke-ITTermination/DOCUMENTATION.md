# Invoke-ITTermination.ps1

Reference documentation.

Runs the tenant-side half of an IT employee termination against **every account the
person holds**, in an order that survives being interrupted, with gates that make the
expensive mistakes hard to make.

Companion tool to the run book *Terminating an IT Employee with Privileged Access*.

---

## Contents

- [Why this exists](#why-this-exists)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Modes](#modes)
- [Parameter reference](#parameter-reference)
- [Permissions](#permissions)
- [Roles, and PIM elevation](#roles-and-pim-elevation)
- [Safety model](#safety-model)
- [Order of operations](#order-of-operations)
- [Output artifacts](#output-artifacts)
- [What it deliberately does not do](#what-it-deliberately-does-not-do)
- [Troubleshooting](#troubleshooting)
- [Testing](#testing)
- [Status and limitations](#status-and-limitations)
- [Licence](#licence)

---

## Why this exists

Offboarding an ordinary user is a checklist. Offboarding the person who *ran* the
checklist is a different exercise, and the usual scripts get it wrong in one specific
way: they assume one account.

Any admin working to Microsoft's own guidance has at least two. The daily driver holds
the mailbox and the laptop. The privileged account holds the roles, and Microsoft's
position is that it should be **cloud-only, not synced from AD, not shared, and not
mail-enabled**. Every one of those properties is good security, and every one of them is
a reason the admin account walks straight through a termination written around the
person's ordinary user object:

- Cloud-only, so disabling the on-prem account does nothing to it.
- Unlicensed, so it is invisible in the admin-center views most checklists were built
  against.
- No mailbox, so the mailbox step never touches it.
- Frequently excluded from Conditional Access, because carving out admin accounts is
  the oldest workaround in the tenant.
- Usually the account carrying the PIM eligibility.
- Often on the tenant's `.onmicrosoft.com` routing domain, so a search for
  `@company.com` returns nothing at all.

This tool finds both accounts, cuts the privileged one **first**, and refuses to delete
either.

---

## Requirements

| Requirement | Detail |
|---|---|
| PowerShell | **7.2 or later.** Enforced by `#Requires`. Windows PowerShell 5.1 will not run it. |
| Module | `Microsoft.Graph.Authentication` 2.0+ (the only one required) |
| Optional module | `ExchangeOnlineManagement` 3.0+, needed only for `-IncludeMailbox` |
| Licence | Intune licence for device reads; Entra ID P2 for PIM eligibility reads |
| Host | Azure Cloud Shell, or any PowerShell 7 host with internet access |

### Why only one module

Azure Cloud Shell preinstalls a **subset** of Microsoft.Graph: Authentication,
Applications, Groups, Identity.DirectoryManagement, Identity.Governance,
Identity.SignIns, Users.Actions, Users.Functions.

`Microsoft.Graph.Users` and the Intune modules are **not** in that set, so `Get-MgUser`
and `Invoke-MgRetireDeviceManagementManagedDevice` do not exist in Cloud Shell out of
the box. This script therefore talks to Graph through `Invoke-MgGraphRequest` against
pinned `v1.0` endpoints, and needs only the Authentication module, which is always
present. That also means no module-version drift changes its behaviour.

---

## Installation

```powershell
# Clone, or just download the one file.
git clone https://github.com/<you>/<repo>.git
cd <repo>

# Optional: let the script install what it needs on first run.
./Invoke-ITTermination.ps1 -TenantId <guid> -PrimaryUpn user@contoso.com -InstallPrerequisites
```

The script checks its prerequisites at startup and offers to install missing ones for
the current user. `-InstallPrerequisites` skips the prompt. `-NonInteractive` turns a
missing required module into a hard stop instead of a question, which is what you want
in a pipeline.

> **Cloud Shell caveat.** Modules installed in Cloud Shell persist only if you have a
> storage account attached. Without one, they are gone next session and the script will
> offer to install again.

---

## Quick start

```powershell
$T = '<your-tenant-guid>'

# 1. Discovery. Writes nothing to the tenant. Prints a confirmation token.
./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com

# 2. Read the dossier it wrote. Confirm the account list is right.

# 3. The cut. Admin account first, automatically.
./Invoke-ITTermination.ps1 -TenantId $T `
    -PrimaryUpn jdoe@contoso.com `
    -AdminUpn   adm-jdoe@contoso.onmicrosoft.com `
    -Mode Execute -ConfirmationToken A1B2C3D4E5F6 -ElevateWithPim

# 4. Irreversible device actions, only after you have the BitLocker and LAPS keys.
#    Same command plus:  -IncludeDeviceActions

# 5. Prove it.
./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
    -AdminUpn adm-jdoe@contoso.onmicrosoft.com -Mode Validate
```

Wrong person? Everything reversible can be undone:

```powershell
./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
    -Mode Rollback -RollbackJournal ./termination-dossier/rollback-journal-<stamp>.json
```

---

## Modes

| Mode | Writes to tenant | Purpose |
|---|---|---|
| `Report` (default) | No | Discovery. Finds accounts, roles, devices, ownerships. Writes the dossier and the on-prem script. Prints the confirmation token. |
| `Execute` | Yes | Performs the cut. Requires a matching confirmation token. |
| `Validate` | No | Asserts resolved state after the fact, including that the retained accounts still exist. |
| `Rollback` | Yes | Replays a journal in reverse, re-enabling accounts and devices and restoring role assignments. |

`Report` and `Validate` skip the operator authority check, because they are read-only.

---

## Parameter reference

### Targeting

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-TenantId` | string | **Yes** | Asserted against the connected tenant before any write. For an MSP this is the difference between a termination and an incident. |
| `-PrimaryUpn` | string | **Yes** | The daily-driver account, the one with the mailbox. |
| `-AdminUpn` | string | No | The privileged account. Optional, but if you omit it and the search finds a candidate, `Execute` stops. |
| `-SearchName` | string | No | Surname or display-name fragment for account discovery. Defaults to a value parsed from `-PrimaryUpn`. |
| `-ProtectedUpns` | string[] | No | Accounts the tool must never touch. Break-glass accounts belong here. The signed-in operator is added automatically. |

### Execution control

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Mode` | string | `Report` | `Report`, `Execute`, `Validate`, `Rollback`. |
| `-ConfirmationToken` | string | | Produced by `Report`. Required by `Execute`. |
| `-IncludeDeviceActions` | switch | off | Enables the **irreversible** Intune wipe and retire. Also the only thing that requests the wipe permission. |
| `-IncludeMailbox` | switch | off | Converts the primary mailbox to shared. Requires `ExchangeOnlineManagement`. |
| `-SharedMailboxDelegate` | string | | UPN granted Full Access to the converted mailbox. |
| `-RollbackJournal` | string | | Path to the journal, required by `-Mode Rollback`. |
| `-OutputPath` | string | `./termination-dossier` | Where artifacts are written. |

### Prerequisites and authentication

| Parameter | Type | Description |
|---|---|---|
| `-InstallPrerequisites` | switch | Install missing modules without prompting. |
| `-UseDeviceCode` | switch | Force device code sign-in. Auto-selected in Cloud Shell. |
| `-NonInteractive` | switch | Never prompt. A missing module or missing authority becomes a hard stop. |

### PIM elevation

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-ElevateWithPim` | switch | off | Activate eligible roles automatically if the operator holds no standing privilege. |
| `-ElevationHours` | int | `2` | Requested activation duration. Your PIM policy maximum still wins. |
| `-ElevationJustification` | string | run book name | Justification recorded in the PIM audit trail. |

---

## Permissions

Delegated scopes only. The script acts **as the human running it** and can never exceed
that person's authority.

| Scope | Used for | Requested |
|---|---|---|
| `User.Read.All` | Account discovery and profiling | Always |
| `User.ReadWrite.All` | Set `accountEnabled=false`, and `revokeSignInSessions` | Always |
| `Directory.Read.All` | Owned objects, directory context | Always |
| `RoleManagement.ReadWrite.Directory` | Read and remove role assignments, read and remove PIM eligibility, self-activate | Always |
| `Device.ReadWrite.All` | Disable device objects | Always |
| `Application.Read.All` | Enumerate owned app registrations | Always |
| `UserAuthenticationMethod.Read.All` | Count registered methods for the dossier. **Read only; the script never modifies them.** | Always |
| `DeviceManagementManagedDevices.Read.All` | Enumerate Intune devices | Always |
| `DeviceManagementManagedDevices.PrivilegedOperations.All` | Wipe and retire | **Only with `-IncludeDeviceActions`** |

Two notes on least privilege. The wipe permission is requested **only** when you pass
the switch, so a routine run holds no authority to wipe anything even by accident. And
`revokeSignInSessions` has a narrower documented scope, `User.RevokeSessions.All`; this
script already needs `User.ReadWrite.All` to set `accountEnabled`, which also covers it,
so no extra consent is required.

---

## Roles, and PIM elevation

The operator needs, at minimum:

| Role | For |
|---|---|
| Privileged Authentication Administrator | Disabling an **admin** account and revoking its sessions. User Administrator is not enough for privileged targets. |
| Privileged Role Administrator | Removing role assignments and PIM eligibility |
| Cloud Device Administrator | Disabling device objects (Global Administrator also covers it) |
| Intune Administrator | Device wipe and retire, only with `-IncludeDeviceActions` |
| Exchange Administrator | Only with `-IncludeMailbox` |

Global Administrator covers all of it.

### If you hold nothing standing

In a well-run tenant that is the normal case, and the script handles it rather than
failing at the first write with an opaque 403. Before `Execute` or `Rollback` it:

1. Reads the operator's **active** role assignments.
2. If Global Administrator is active, proceeds.
3. Otherwise reports exactly which roles are missing and why each is needed.
4. Reads the operator's **eligible** assignments.
5. If eligible and `-ElevateWithPim` is passed, activates and continues. Without the
   switch it stops and tells you to activate.
6. Re-connects to Graph afterwards, because **an access token minted before activation
   does not carry the new role**. This is the step hand-rolled scripts usually miss.

It activates the **narrowest roles that satisfy the run** (Privileged Authentication
Administrator plus Privileged Role Administrator) and only reaches for Global
Administrator if those two are not among the eligibilities.

### If your PIM policy requires approval

The script exits cleanly and tells you to re-run once the approver has acted, rather
than spinning until it times out. This follows the documented Graph status enum, with
two traps worth knowing if you write your own:

- `ScheduleCreated` looks terminal and is **transitional**.
- `Granted` is the settled status only of a **future-dated** activation. This script
  always requests `start = now`, so `Granted` is transitional here too. If you ever
  date-shift the schedule, revisit both.
- `PendingApproval` and `PendingAdminDecision` are **clean exits**, not failures. A
  request against an approval-required role never reaches a terminal state without a
  human.

---

## Safety model

### Design invariants

These are properties of the code, not merely intentions. Each has a test.

1. **Nothing is ever deleted.** There is no user-delete verb anywhere in the script. It
   disables, revokes, and removes role assignments. Deleting the admin account orphans
   sole ownerships (Azure subscriptions, management groups, app registrations,
   subscription billing contacts, vendor portals), and Entra soft-delete is only 30
   days. A test greps the source and fails the build if a delete verb appears.
2. **Irreversible actions are opt-in and never journalled as reversible.** Device wipe
   and retire require their own switch. The rollback journal records only
   `DisableUser`, `DisableDevice`, and `RemoveRole`.
3. **Report writes nothing.** You cannot reach `Execute` without a token that only
   `Report` can produce.
4. **Roles come off before the disable**, so a run that dies halfway never leaves a
   privileged-but-enabled account.

### The five gates

Every one refuses **before** the first write. The test suite asserts the *reason* each
refusal fires, not merely that the script threw.

| Gate | Refuses when |
|---|---|
| **Tenant** | The connected tenant does not equal `-TenantId` |
| **Operator** | A target is the signed-in user or a protected account |
| **Confirmation token** | The token does not match this tenant plus this exact target set |
| **Undeclared accounts** | The search found an account you neither declared nor protected |
| **Last Global Administrator** | The run would leave the tenant with zero active GAs |

The token is a SHA-256 over the tenant ID plus the sorted target object IDs. You cannot
execute blind, and a token generated for one person will not run against another.

---

## Order of operations

The order is not cosmetic. Each step is placed where it is because the alternative fails
in a specific way.

```
Admin account (first, because it can undo your work)
  1. Remove active role assignments        <- before disable, so a partial run
  2. Remove eligible PIM assignments          never leaves privileged-and-enabled
  3. Disable the account                   <- before revoke, so the client
  4. Revoke sessions                          cannot just mint fresh tokens
  5. Disable device objects
  6. [optional] Intune wipe / retire       <- irreversible, opt-in only

Daily driver (second)
  ... same sequence ...

Then, by hand: on-prem AD, Azure RBAC, sole ownerships, the rotation list.
```

Why admin first: someone who still holds User Administrator can re-enable the account
you just disabled. The daily driver is the account with the mailbox attached; the admin
account is the one with the tenant attached.

---

## Output artifacts

Written to `-OutputPath` (default `./termination-dossier`).

| File | Purpose |
|---|---|
| `dossier-<stamp>.json` | Machine-readable record of every account, role, device, and ownership, plus the manual task list |
| `onprem-<stamp>.ps1` | The Active Directory half, generated for you to run on a domain-joined host |
| `rollback-journal-<stamp>.json` | Every reversible change, replayable by `-Mode Rollback` |
| `transcript-<stamp>.txt` | Full session transcript for the change record |

### Sample dossier

Real output from the test harness, tenant ID redacted:

```json
{
  "tool": "Invoke-ITTermination",
  "version": "1.1.0",
  "mode": "Execute",
  "generatedUtc": "2026-08-14T02:51:45.5913464Z",
  "tenantId": "<tenant-guid>",
  "operator": "operator@contoso.com",
  "confirmToken": "32BE77CE11DF",
  "targets": [
    {
      "role": "admin",
      "upn": "adm-jdoe@contoso.onmicrosoft.com",
      "accountEnabled": true,
      "cloudOnly": true,
      "licensed": false,
      "activeRoles": ["Exchange Administrator", "Intune Administrator"],
      "eligibleRoles": ["Global Administrator"],
      "deviceCount": 0,
      "ownedApps": ["Backup Automation"],
      "ownedGroups": ["SG-Infra-Admins"],
      "authMethodCount": 1
    },
    {
      "role": "primary",
      "upn": "jdoe@contoso.com",
      "accountEnabled": true,
      "cloudOnly": false,
      "licensed": true,
      "activeRoles": [],
      "eligibleRoles": [],
      "deviceCount": 2,
      "intuneDevices": [
        { "name": "LAP-JDOE-01", "os": "Windows", "ownership": "company" },
        { "name": "JDOE-IPHONE", "os": "iOS", "ownership": "personal" }
      ],
      "ownedApps": [],
      "ownedGroups": [],
      "authMethodCount": 1
    }
  ],
  "undeclaredAccounts": [],
  "survivingGlobalAdmins": 2,
  "manualTasks": [ "..." ]
}
```

That sample is the whole argument for the tool in one object: the daily driver holds the
devices and the licence and **no roles at all**, while the admin account holds every
role, the eligible Global Administrator, and sole ownership of an app registration
called Backup Automation. A script that only knew about `jdoe@contoso.com` would have
reported complete success while changing nothing that mattered.

---

## What it deliberately does not do

| Not done | Why | What happens instead |
|---|---|---|
| On-premises Active Directory | Cloud Shell has no line of sight to a domain controller | Generates `onprem-<stamp>.ps1` to run on a domain-joined host. The script never claims this half is done. |
| Delete any account | Orphans sole ownerships; Entra soft-delete is only 30 days | No delete verb exists. Enforced by a test. |
| Rotate the privileged residue | Registrar, backup console, firewalls, hypervisors, vendor portals and physical access are not APIs | Emitted as a dated task list in the dossier |
| Azure RBAC | A separate authorisation system from Entra directory roles | Flagged in the output as owed by a human, with the scopes to check |
| Wipe devices by default | Irreversible | Requires `-IncludeDeviceActions`, after you capture BitLocker and LAPS keys |
| Convert the mailbox by default | Separate module, separate failure domain | Requires `-IncludeMailbox`, degrades gracefully if EXO is unavailable |

---

## Troubleshooting

**`The term 'Get-MgUser' is not recognized`**
You are not running this script. It does not use `Get-MgUser`. Something else in your
session does, and Cloud Shell does not ship `Microsoft.Graph.Users`.

**`Connected tenant <guid> does not match -TenantId <guid>`**
You have a cached Graph session for a different tenant. Run `Disconnect-MgGraph` and try
again. This gate exists precisely to catch tenant mix-ups.

**`'<upn>' is a protected account (operator or break-glass)`**
You are trying to terminate yourself, or an account in `-ProtectedUpns`. Sign in as
someone else.

**`<n> undeclared account(s) match this person`**
The search found accounts you did not name. Pass each as `-AdminUpn` (to terminate) or
in `-ProtectedUpns` (to leave alone), then re-run. This is the guard against cutting the
daily driver and leaving the admin account live.

**`Confirmation token mismatch`**
The target set changed since the report, or the token came from a different run. Re-run
`Report` and use the token it prints.

**`This run would leave the tenant with zero active Global Administrators`**
Give your break-glass account an active Global Administrator assignment first. Entra
will refuse the last GA removal anyway; this gate just fails earlier and more clearly.

**`Operator must activate PIM first`**
Add `-ElevateWithPim`, or activate in the portal and re-run.

**`<role> is awaiting approval (PendingApproval)`**
Your PIM policy requires an approver. Once they approve, re-run the script.

**403 on a device or Intune call**
Delegated permissions mean your own roles apply. Check Cloud Device Administrator for
device objects and Intune Administrator for wipe and retire.

**Device wipe reports success but nothing happens**
The action fires at next device check-in. An offline device keeps its local data until
it comes back online. Treat anything on an unreturned offline device as disclosed and
rotate accordingly.

---

## Testing

```powershell
pwsh -File test/run-tests.ps1
```

15 tests run against a mock Graph harness. **No tenant is required and no network call
is made.** The mock lives in `test/mockmod/` and returns realistic Graph shapes.

Coverage:

- Report completes, writes a dossier, prints a token
- Undeclared cloud-only accounts are surfaced
- The admin account is recorded as cloud-only and unlicensed with its eligible GA
- The generated on-prem script disables and contains no delete verb
- All five gates refuse, each **for the correct reason**
- Execute processes the admin account before the daily driver
- Execute does not touch devices without `-IncludeDeviceActions`
- The rollback journal contains only reversible actions
- The source contains no user-delete verb
- An operator with GA passes the authority check
- An eligible-but-not-active operator is blocked without `-ElevateWithPim`
- `-ElevateWithPim` activates the narrow roles, refreshes the token, and proceeds
  without reaching for Global Administrator

The gate tests assert the failure *reason*, not merely that the script threw. An earlier
revision had three gate tests passing for the wrong reason, because the run was dying on
an authority check before it ever reached the gate under test.

---

## Status and limitations

**Verified against the mock harness. Not yet run against a live tenant.** Run `Report`
against a real termination and read the dossier before trusting `Execute`.

Known limitations:

- Account discovery relies on Graph `$search` over display name and UPN. An admin
  account named nothing like its owner will not be found by search, so declare it with
  `-AdminUpn`.
- App registration ownership has no portal filter and no clean alternative, so
  enumeration is Graph-only by necessity.
- PIM eligibility reads require Entra ID P2. Without it, that section is skipped with a
  warning rather than failing.
- Azure RBAC is reported as owed, never actioned.
- The generated on-prem script is not idempotent by design. Read it before running it.

---

## Licence

MIT.
