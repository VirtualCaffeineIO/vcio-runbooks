# Invoke-ITTermination.ps1

Companion tool to the run book *Terminating an IT Employee with Privileged Access*.

Runs the **tenant-side** half of the termination against **every account the person holds**,
in the right order, with gates that make the expensive mistakes hard to make.

---

## Answering the obvious questions first

**Does it need PowerShell 7?** Yes. `#Requires -Version 7.2`. Windows PowerShell 5.1 stops
at the first line. Azure Cloud Shell has 7.4, so it runs there as-is.

**Will it prompt me to sign in?** Yes, as the human doing the disablement. Auth is
**delegated**, so the script can never exceed your own authority. In Cloud Shell it
auto-selects device code (no browser exists there) and prints a URL and code. Anywhere
else it opens a browser. Force device code with `-UseDeviceCode`.

**What if I need to PIM up to Global Admin first?** Handled. The script checks your
*effective* authority before it writes anything. If you hold nothing standing but are
eligible, it says so and, with `-ElevateWithPim`, activates and continues. It activates
the **narrowest roles that do the job** (Privileged Authentication Administrator +
Privileged Role Administrator) and only reaches for Global Administrator if those are
not among your eligibilities. After activating it **re-connects**, because an access
token minted before activation does not carry the new role. If your PIM policy requires
approval, it exits cleanly and tells you to re-run after the approver acts, rather than
spinning.

**Can it install its own prerequisites?** Yes. It checks for
`Microsoft.Graph.Authentication` 2.0+ and offers to install it; `-InstallPrerequisites`
skips the prompt, `-NonInteractive` turns a missing module into a hard stop instead of a
question. Cloud Shell caveat: installed modules only persist there if you have a storage
account attached.

**Why only one module?** Cloud Shell preinstalls a *subset* of Microsoft.Graph:
Authentication, Applications, Groups, Identity.DirectoryManagement, Identity.Governance,
Identity.SignIns, Users.Actions, Users.Functions. **`Microsoft.Graph.Users` and the Intune
modules are not among them**, so `Get-MgUser` does not exist there out of the box. This
script therefore calls Graph directly through `Invoke-MgGraphRequest` and needs only the
Authentication module, which is always present.

---

## What it will not do, by design

| Not done | Why | What happens instead |
|---|---|---|
| On-premises AD | Cloud Shell has no line of sight to a domain controller | Generates `onprem-<stamp>.ps1` for you to run on a domain-joined host |
| Delete any account | Deleting the admin account orphans sole ownerships (subscriptions, app registrations, vendor portals) | The script has no user-delete verb at all. A test enforces this. |
| Rotate the residue | Registrar, backup console, firewalls, vendor portals and physical are not APIs | Emitted as a task list in the dossier |
| Wipe devices by default | Irreversible | Requires `-IncludeDeviceActions`, after you have captured BitLocker and LAPS keys |
| Mailbox conversion by default | Separate failure domain, separate module | Requires `-IncludeMailbox` and degrades gracefully if EXO is unavailable |

---

## The five gates

Every one refuses **before** the first write, and the tests assert the *reason* each
refusal fires, not merely that it threw.

1. **Tenant.** The connected tenant must equal `-TenantId`. For an MSP this is the
   difference between a termination and an incident.
2. **Operator.** The signed-in user is auto-protected. You cannot terminate yourself.
3. **Confirmation token.** Execute requires a token that Report prints, derived from the
   tenant plus the exact target object IDs. You cannot execute blind, and you cannot
   reuse a token against a different person.
4. **Undeclared accounts.** If the surname search finds an account you did not declare
   or protect, Execute stops. This is the guard against cutting the daily driver and
   leaving the admin account live.
5. **Last Global Administrator.** Refuses to leave the tenant with zero active GAs.

---

## Usage

```powershell
# 1. Discovery. Writes nothing. Prints the confirmation token.
./Invoke-ITTermination.ps1 -TenantId <guid> -PrimaryUpn jdoe@contoso.com

# 2. The cut. Admin account first, automatically.
./Invoke-ITTermination.ps1 -TenantId <guid> `
    -PrimaryUpn jdoe@contoso.com `
    -AdminUpn   adm-jdoe@contoso.onmicrosoft.com `
    -Mode Execute -ConfirmationToken A1B2C3D4E5F6 -ElevateWithPim

# 3. Irreversible device actions, once you have the keys.
#    (same command, plus:)  -IncludeDeviceActions

# 4. Prove it.
./Invoke-ITTermination.ps1 -TenantId <guid> -PrimaryUpn jdoe@contoso.com `
    -AdminUpn adm-jdoe@contoso.onmicrosoft.com -Mode Validate

# 5. Wrong person? Undo everything reversible.
./Invoke-ITTermination.ps1 -TenantId <guid> -PrimaryUpn jdoe@contoso.com `
    -Mode Rollback -RollbackJournal ./termination-dossier/rollback-journal-<stamp>.json
```

## Output

| File | Contents |
|---|---|
| `dossier-<stamp>.json` | Every account, role, device, ownership, plus the manual task list |
| `onprem-<stamp>.ps1` | The AD half, generated, to run elsewhere |
| `rollback-journal-<stamp>.json` | Every reversible change, replayable by `-Mode Rollback` |
| `transcript-<stamp>.txt` | Full session transcript for the change record |

Rollback covers account disable, device disable, and role removal. Session revocation and
device wipes are **not** reversible and are never journalled as though they were.

## Order of operations

Roles come off **before** the disable, so a run that dies halfway never leaves a
privileged-but-enabled account. Disable comes **before** revoke, because revoking an
enabled account just mints fresh tokens. The admin account is processed **before** the
daily driver, because whoever still holds User Administrator can re-enable what you just
disabled.

## Testing

```powershell
pwsh -File test/run-tests.ps1
```

26 tests against a mock Graph harness. No tenant required.

## Status

Verified against the mock harness. **Not yet run against a live tenant.** Run it in
Report mode against a real termination first and read the dossier before trusting
Execute. Licence: MIT.
