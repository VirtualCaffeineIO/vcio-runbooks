# Run Book: Terminating an IT Employee with Privileged Access

| | |
|---|---|
| **Status** | Draft. Not yet published. |
| **Written** | 2026-08-14 |
| **Last reviewed** | 2026-08-14 |
| **Review by** | 2027-02-14 |
| **Estate** | Entra ID, Intune, Exchange Online, with or without on-premises Active Directory |
| **Companion tool** | [`tools/Invoke-ITTermination`](../../tools/Invoke-ITTermination/) (v1.4.0, mock-tested, not yet run against a live tenant) |
| **Checklist only** | [`terminating-it-employee-privileged-access.checklist.md`](terminating-it-employee-privileged-access.checklist.md) |

Run books name portal surfaces, and portal surfaces move. If the review-by date has passed, verify each product noun against the current admin centers before you trust a line.

-----

An IT employee with privileged access is leaving, and you have one pass to get this right. By the end of this run book their identity is disabled and tokenless, their devices are blocked and reclaimed, their mailbox is a shared mailbox the team can read, and every credential they knew that was never theirs has been rotated. The order matters more than the speed.

Offboarding an ordinary user is a checklist, and most of it survives being done sloppily. Offboarding the person who ran the checklist is a different exercise, because their access does not end at their account. They know passwords that were never theirs. They own automation that will keep running after they leave. They can name every gap in your controls, because they built the controls. And they almost certainly have more than one account, because the daily-driver mailbox account and the privileged account are supposed to be separate. This run book is written for that person: the sysadmin, the infrastructure engineer, the one of two people in the IT department.

It works for the friendly resignation with two weeks of notice and for the termination that ends with a 2 pm walkout. The difference between those two is compression, never order. Everything here assumes a Microsoft-centric estate: Entra ID, Intune, Exchange Online, with or without on-prem Active Directory. Where the run book says "the account," read it as "each of their accounts," and read the section on the second account before you start, because that distinction is the one most likely to bite you. Each step opens with its checklist, the items and nothing else, so you can run the whole termination from the boxes alone. Under each checklist sits the walk-through, admin centers named, for any line where you need the detail, and where a section has several portal moves, a single consolidated PowerShell block reproduces them for the reader who scripts the cut. The last third of the run book deliberately leaves the tenant, because the departing admin's access does too.

**Prerequisites.** A second privileged person who is not the leaver, holding: `Privileged Authentication Administrator` or Global Administrator in Entra (disabling an admin account requires Privileged Authentication Administrator; User Administrator is only enough for non-admin accounts), at least `Cloud Device Administrator` for device disable, an Intune role carrying the Retire and Wipe remote tasks, Exchange Administrator, and Domain Admin equivalent on-prem if you are hybrid. A working break-glass account you can prove is not known to the leaver. If you want the consolidated blocks, Microsoft Graph PowerShell and the Exchange Online module installed somewhere that is not the leaver's machine.

-----

## Step 1: Build the dossier before the conversation happens

The identity cut happens during the termination conversation, and that is only possible if the inventory work happened before it. Quietly, before the meeting, enumerate what this person holds. You are answering five questions: how many accounts do they have, what roles do those accounts hold, what devices are theirs, what objects do they own, and what credentials do they know that are not attached to any account of theirs. The first four come out of the portals. The fourth is a judgment call you make honestly, and the honest answer for a long-tenured admin is usually "assume all of them."

  - [ ] Second privileged person confirmed, with the roles from the prerequisites line
  - [ ] Break-glass account works and is unknown to the leaver
  - [ ] Every account they hold found, not just the mailbox one (admin accounts, cloud-only accounts, on-prem-only accounts, test accounts they made)
  - [ ] Roles inventoried, active and eligible, per account
  - [ ] Devices inventoried
  - [ ] Owned groups, Teams, and app registrations inventoried
  - [ ] Mailbox size noted (under 50 GB means the license comes back)
  - [ ] Mailbox path decided: shared, or hold and inactive
  - [ ] Disposition decided per device: returning or remote wipe
  - [ ] Dossier started and dated

**The walk-through.**

1.  **Find every account first, then run the rest of this list once per account.** In the Microsoft Entra admin center, open **Entra ID**, **Users**, and search on the person's surname rather than their UPN, so you catch the naming variants. Then search again for your admin-account convention, whatever it is locally: `adm-`, `a-`, `.admin`, `-adm`. Add the **On-premises sync enabled** and **Company name** columns to the results view, because they separate the synced daily-driver account from the cloud-only admin account at a glance. The section after this walk-through says why this is the step people skip.
2.  Select the user. The **Assigned roles** page lists their directory roles. In a PIM tenant it shows both **Eligible assignments** and **Active assignments**; record both, because an eligible Global Administrator does not show up as an active role anywhere else.
3.  Cross-check in PIM: **ID Governance**, **Privileged Identity Management**, **Microsoft Entra roles**, then **Assignments**, filtered to the user. This is the surface you will remove them from later, so note what you see now.
4.  Still on the user, open **Devices** and record every registered and joined device, with its join type and whether it is Intune-managed.
5.  Open the user's **Groups** page and switch to the **Ownership** tab. Groups they own need a new owner before the account is disabled, or they orphan.
6.  App registrations have no owner filter in the portal, so ownership enumeration is one of this run book's honest Graph-only moves: `Get-MgUserOwnedObject` in the block below returns every group and app registration they own in one list. Record the app registrations specifically; step 5 rotates their secrets.
7.  In the Microsoft 365 admin center, open **Users**, **Active users**, select the user, and note the mailbox size on the **Mail** tab. Under 50 GB matters for the license decision in step 4.

<!-- end list -->

``` wp-block-code
# The dossier, as one block
Connect-MgGraph -Scopes "User.Read.All","RoleManagement.Read.Directory","Application.Read.All"

# 1. Find every account before profiling any of them.
#    Search the surname, not the UPN, and show the sync flag.
Get-MgUser -Search 'displayName:Doe' -ConsistencyLevel eventual -All `
    -Property Id,UserPrincipalName,DisplayName,AccountEnabled,OnPremisesSyncEnabled |
    Select-Object UserPrincipalName,DisplayName,AccountEnabled,OnPremisesSyncEnabled

# 2. Then profile each account you found.
foreach ($upn in @("adm-jdoe@contoso.onmicrosoft.com","jdoe@contoso.com")) {
    $u = Get-MgUser -UserId $upn
    Write-Host "=== $upn ==="
    Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$($u.Id)'" -All  # active roles
    Get-MgUserRegisteredDevice -UserId $u.Id -All                                         # devices
    Get-MgUserOwnedObject -UserId $u.Id -All                                              # owned groups + apps
}
```

Export it all into a dossier document and date it. Then decide the two disposition questions now, in the calm: whether the mailbox becomes a shared mailbox or an inactive one, and whether each device is coming back or being wiped in the field. Making those calls mid-termination produces bad answers.

-----

## The second account, and why it survives a careful termination

Any admin working to Microsoft's own guidance has at least two accounts. The daily driver holds the mailbox, the Teams presence, the laptop, and no privilege worth the name. The admin account holds the roles, and Microsoft's position is that privileged accounts should be cloud-only, with no tie to on-premises Active Directory, not shared between people, and not mail-enabled. Every one of those properties is good security, and every one of them is a reason the admin account walks straight through a termination written around the person's ordinary user object.

Work through why. It is cloud-only, so disabling and resetting the on-prem account does nothing to it, and no sync cycle will carry the change. It is unlicensed, so it is invisible in the Microsoft 365 admin center views that most offboarding checklists were written against. It has no mailbox, so the mailbox step never touches it and nobody notices it is missing. It is likely excluded from the Conditional Access policies that constrain everyone else, because carving out admin accounts is the oldest workaround in the tenant. It probably carries the PIM eligibility. And its UPN is frequently on the tenant's `.onmicrosoft.com` routing domain rather than the company domain, so a search that assumes `@contoso.com` returns nothing at all.

> The account you built to be separate from everything is separate from your offboarding too.

So the run book runs twice, and the order inverts the intuition: the admin account is cut *first*, because it is the one that can undo your work. Someone who still holds User Administrator can re-enable the account you just disabled. The daily driver is the account with the mailbox and the sentiment attached to it; the admin account is the one with the tenant attached to it.

| Account type                                 | How you find it                                                                                                       | What it needs                                                       |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Daily driver, synced from AD                 | Obvious; it is the one with the mailbox                                                                               | The whole run book, steps 2 through 7                               |
| Admin account, cloud-only                    | Surname search plus your `adm-` convention; filter for on-premises sync disabled; check the `.onmicrosoft.com` domain | Steps 2, 5, and 6. No mailbox work. Cut first, and never delete it. |
| On-prem-only admin account                   | Active Directory Users and Computers, not Entra; it may never have synced                                             | Disable and double reset on-prem; remove from privileged groups     |
| Shared admin account, several people know it | You already know; it is the estate's worst-kept secret                                                                | Rotate, do not disable. Treat it as break-glass class in step 5.    |
| Service or test accounts they created        | Owned-objects list, plus accounts with no manager and no sign-in history                                              | Judgment. Disable and watch what breaks, rather than deleting.      |

The last row is the one that generates argument, so take a position: disable, wait, and let the breakage identify the dependency. A test account nobody can account for is not evidence of innocence, and an account that turns out to run a production job announces itself within a day of being disabled, which is a cheaper way to find out than the alternatives.

**Disable the admin account. Do not delete it, and do not let anyone delete it in six months either.** A long-tenured admin's privileged account accumulates sole ownership of things nobody thinks to check: the only Owner on an Azure subscription or a management group, the sole owner of an app registration or enterprise application, the named technical or billing contact on a subscription, the only administrator on a SaaS tenant that sits outside your SSO, the account a vendor portal recognises. Disabling breaks none of that. Deleting orphans all of it, and it does so silently, surfacing months later as a resource nobody can manage and a support case nobody wants.

Entra soft-deletes a user for 30 days, so an accidental deletion inside that window is recoverable and a deletion outside it is not. Orphaned Azure ownership has a documented recovery path (a Global Administrator can elevate access at root scope and reassign Owner), which is worth knowing precisely because it is the kind of thing you find out you need at the wrong moment. Third-party SaaS and vendor portals frequently have no equivalent path at all, and that is where deletion turns into a procurement conversation. So the disposition for the admin account is the same shape as the shared-mailbox anchor, arrived at from the opposite direction: it stays, disabled, unlicensed, stripped of roles, marked, indefinitely. Reassign the ownerships at your leisure, then keep the empty account anyway.

-----

## Step 2: The first fifteen minutes, cutting identity

This step runs while the termination conversation is happening, executed by the second privileged person. The order is deliberate: disable first, then revoke. Revoking sessions on an account that is still enabled achieves little, because the client signs back in and mints fresh tokens. Disable closes the front door; revocation invalidates what is already in their pocket. If you are hybrid, start on-prem, and do not wait for sync to carry the disable to the cloud. Do both directly. Run the whole sequence against the admin account first, then against the daily driver, for the reason the previous section gives.

  - [ ] Admin account disabled and sessions revoked, first
  - [ ] Admin account active role assignments removed
  - [ ] Admin account eligible PIM assignments removed
  - [ ] Admin account Azure RBAC assignments removed (separate surface from Entra roles)
  - [ ] AD account disabled (hybrid)
  - [ ] AD password reset twice, random values (hybrid)
  - [ ] Entra daily-driver account disabled
  - [ ] Sessions revoked on the daily driver
  - [ ] Every device object disabled
  - [ ] Any remaining role assignments removed, both kinds, both accounts
  - [ ] Last-GA guard handled through break-glass, if it applies
  - [ ] Any shared admin account rotated rather than disabled
  - [ ] Nothing deleted: the admin account is disabled and kept, sole ownerships intact

**The walk-through.**

1.  **The admin account, before anything else.** Run items 2, 3, 5 and 6 of this list against it now. It is cloud-only, so it has no on-prem half and no mailbox, which makes it the fastest account in this run book to cut and the most expensive one to leave running.
2.  **Hybrid only, on-prem first.** In Active Directory Users and Computers, right-click the user and select **Disable Account**. Then right-click again, select **Reset Password**, and set a long random password. Do the reset twice, with two different random values; the double reset mitigates pass-the-hash against the old credential.
3.  **Disable in Entra.** In the Microsoft Entra admin center, open **Entra ID**, **Users**, select the user, and under **Account status** select **Edit**. Clear **Account enabled** and save.
4.  **Revoke sessions.** On the same user's **Overview** page, select **Revoke sessions**. This invalidates their refresh tokens and browser session cookies; expect a delay of a few minutes before it fully lands.
5.  **Disable their devices.** In **Entra ID**, open **Devices**, **All devices**, select each device from the dossier, and select **Disable**. A disabled device object cannot use its Primary Refresh Token to authenticate.
6.  **Remove active roles.** In **Entra ID**, open **Roles & admins**, select each role from the dossier, tick the user, and select **Remove assignment**. In a PIM tenant the same removal lives in PIM: **ID Governance**, **Privileged Identity Management**, **Microsoft Entra roles**, **Roles**, select the role, find the user on the **Active roles** tab, and select **Remove**.
7.  **Remove eligible roles.** Same PIM surface, **Eligible roles** tab, **Remove**. An eligible assignment survives everything else in this run book and reactivates with one approval, which is why it gets its own numbered step instead of a footnote.
8.  **Remove Azure RBAC, which is a different system.** Entra directory roles and Azure resource roles are separate surfaces, and clearing one tells you nothing about the other. In the Azure portal, check **Access control (IAM)**, **Role assignments**, at management group, subscription, and resource group scope, and in PIM check **Azure resources** for eligible assignments there too. Owner or Contributor on a subscription outlives every step above it in this list.

One guard to know about before step 5 surprises you: Entra will refuse to remove the last active Global Administrator assignment, which is precisely why the break-glass account exists. If the leaver is your last standing GA, the break-glass account takes an active assignment first, then the leaver's comes off.

``` wp-block-code
# The identity cut, as one block
# On-prem (hybrid): disable, then reset the password twice
Disable-ADAccount -Identity jdoe
Set-ADAccountPassword -Identity jdoe -Reset -NewPassword (Read-Host -AsSecureString)
Set-ADAccountPassword -Identity jdoe -Reset -NewPassword (Read-Host -AsSecureString)

# Entra: disable, revoke, block devices, strip active roles.
# Admin account FIRST, then the daily driver.
Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.AccessAsUser.All"

$accounts = @(
    "adm-jdoe@contoso.onmicrosoft.com",   # privileged, cloud-only
    "jdoe@contoso.com"                    # daily driver, synced
)

foreach ($upn in $accounts) {
    $u = Get-MgUser -UserId $upn

    Update-MgUser -UserId $u.Id -AccountEnabled:$false
    Revoke-MgUserSignInSession -UserId $u.Id

    Get-MgUserRegisteredDevice -UserId $u.Id -All | ForEach-Object {
        Update-MgDevice -DeviceId $_.Id -AccountEnabled:$false
    }

    Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$($u.Id)'" -All |
        ForEach-Object {
            Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId $_.Id
        }
}
# Eligible PIM assignments: remove in the PIM portal, or via the Graph
# roleEligibilityScheduleRequests API with the adminRemove action.
# Azure RBAC is a separate surface: check Access control (IAM) per scope.
```

Now the part the run book cannot compress: the clock. Disabling the account stops new tokens immediately, and for CAE-capable workloads (Outlook, Teams, SharePoint and OneDrive on modern clients) the disable is enforced in near real time. Everything else rides out the access token it already holds, and the default access token lifetime is one hour. Third-party SaaS applications that issued their own session cookie after an Entra sign-in keep their session until the app reevaluates it, which is governed by the app, not by you. Deprovision those apps directly where they matter.

> The account dies in seconds. The tokens die on their own schedule. Plan the meeting around the tokens.

-----

## Step 3: Devices, block first, reclaim second

The device disable in step 2 already did the urgent half. What remains is disposition, and the right action depends on whose device it is and where it is.

  - [ ] BitLocker recovery keys captured before any retire or delete
  - [ ] LAPS passwords captured before any retire or delete
  - [ ] Corporate devices wiped, returning or not
  - [ ] BYOD enrollments retired
  - [ ] MAM-only phones selective-wiped
  - [ ] Device records left in place until every action reports complete

| Device situation                         | Action                         | Why                                                                                                                                                                          |
| ---------------------------------------- | ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Corporate Windows or Mac, being returned | Wipe, then reprovision         | Factory reset removes their profile, cached credentials, and anything they staged. Autopilot or ADE rebuilds it for the next user.                                           |
| Corporate device, not coming back        | Wipe anyway, immediately       | The wipe fires on next check-in. If the device stays offline it keeps its local data, so treat anything on an unreturned offline device as disclosed and rotate accordingly. |
| Personal device, MDM-enrolled (BYOD)     | Retire                         | Removes company apps, profiles, certificates and mail, leaves their personal data alone. Certificates delivered by Intune are removed and revoked.                           |
| Personal phone, MAM-only                 | Selective wipe of managed apps | App protection data is removed at next app launch check-in. There is no device object to disable, which is the trade you accepted with MAM-only.                             |

**The walk-through.**

1.  **Capture the escrow first.** In the Microsoft Intune admin center, open **Devices**, **All devices**, and select the device. Record the BitLocker key from the device's **Recovery keys** node and the local admin password from its **Local admin password** node. Retiring or deleting the Intune object for an Entra-joined device triggers removal of the BitLocker key protectors and suspends BitLocker as a safeguard, and once the records are gone they are gone.
2.  **Wipe the corporate devices.** On the same device page, select **Wipe** from the actions along the top and confirm. The action fires at next check-in; the device page's activity feed shows when it reports complete.
3.  **Retire the BYOD enrollments.** Same page, **Retire**. Company data, profiles and certificates come off; personal data stays.
4.  **Selective-wipe the MAM-only phone.** In **Apps**, open **App selective wipe**, create a wipe request targeting the user, and the protected app data is removed the next time each managed app checks in.
5.  **Leave the records alone until the actions report complete.** Delete removes the management relationship and the audit trail; it does not make a missed wipe happen. Clean up device objects at the 30-day mark, not today.

-----

## Step 4: The mailbox and the data

This step runs after sign-in is blocked, never before, and it opens with a branch you decided back in step 1. If there is any realistic prospect of litigation or a compliance obligation around this departure, the mailbox's job is preservation: place a litigation hold (in the Exchange admin center, the mailbox's **Others** tab carries **Manage litigation hold**) and take the inactive-mailbox path rather than a shared mailbox. If the mailbox's job is continuity, the customers and vendors who mail this address still reaching a human, convert it to shared. You cannot make one mailbox do both jobs well.

  - [ ] Litigation branch decided; hold placed if preservation wins
  - [ ] Mailbox converted to shared
  - [ ] ActiveSync, IMAP, and POP blocked on the shared mailbox
  - [ ] Full Access granted to the successor
  - [ ] License removed after the conversion confirms
  - [ ] Anchor account kept, and marked against cleanup
  - [ ] OneDrive access granted to the manager
  - [ ] Owned groups, Teams, and distribution lists reassigned

| Path                                   | What it gives you                                                                                       | What it costs you                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Shared mailbox                         | The address stays alive, the team reads and sends from it, history is browsable, no license under 50 GB | Not a preservation mechanism; content is editable by anyone with access |
| Litigation hold, then inactive mailbox | Immutable preservation, searchable through eDiscovery                                                   | Receives nothing; the address goes dark; requires the hold license tier |

**The walk-through**, for the continuity path:

1.  **Convert.** In the Microsoft 365 admin center, open **Users**, **Active users**, select the user, and on the **Mail** tab select **Convert to shared mailbox**, then **Convert**.
2.  **Block the client protocols.** In the Exchange admin center, open **Recipients**, **Mailboxes**, select the mailbox, and under its email apps settings disable **Mobile (Exchange ActiveSync)**, **IMAP**, and **POP3**. A shared mailbox should never be a mailbox somebody's phone still syncs.
3.  **Grant the people taking over.** On the same mailbox, open the **Delegation** settings and add the manager or team under **Read and manage (Full Access)**. The mailbox auto-maps into their Outlook.
4.  **Remove the license.** Back in the Microsoft 365 admin center, once the user's Mail tab confirms the mailbox is shared and it is under 50 GB, remove the license on the **Licenses and apps** tab.
5.  **Do not delete the account.** The shared mailbox needs the account object as its anchor, disabled and unlicensed, forever. Deleting the anchor account is the single most common way this entire run book gets quietly undone months later, usually by someone tidying up stale users. Mark it so your future self recognizes it: a display-name prefix such as `ZZ-Shared-`, or an exclusion group your cleanup scripts respect, whichever convention your estate already uses.
6.  **Hand over the OneDrive.** In the Microsoft 365 admin center, on the user's **OneDrive** tab, use **Create link to files** to grant the manager access now, while everyone remembers. Content survives 30 days after any future account deletion by default, and the safe assumption is that nobody will remember in time.
7.  **Reassign what they owned.** Groups, Teams, and distribution lists from the dossier's ownership list each get a new owner. This is what the ownership enumeration in step 1 was for.

<!-- end list -->

``` wp-block-code
# The mailbox moves, as one block
Connect-ExchangeOnline

Set-Mailbox -Identity "jdoe@contoso.com" -Type Shared
Set-CASMailbox -Identity "jdoe@contoso.com" -ActiveSyncEnabled $false -ImapEnabled $false -PopEnabled $false
Add-MailboxPermission -Identity "jdoe@contoso.com" -User "manager@contoso.com" -AccessRights FullAccess -AutoMapping $true

Get-Mailbox -Identity "jdoe@contoso.com" | Select-Object RecipientTypeDetails
# expect: SharedMailbox, before you touch the license
```

-----

## Step 5: The privileged residue, rotating what they knew

Everything above would be the same run book for a departing accountant. This section is why the IT termination is its own scenario. A privileged employee's real access inventory is the set of credentials they have seen, and no directory query returns it. You rotate from an assumption of knowledge, in order of blast radius.

  - [ ] Break-glass rotated, tested, resealed (today)
  - [ ] Any shared admin account the team uses in common rotated (today)
  - [ ] Registrar, DNS, certificate authority, and federation accounts rotated (today)
  - [ ] Backup console and deletion protections rotated (today)
  - [ ] Hypervisor root rotated (today)
  - [ ] Infrastructure passwords rotated (this week, tracked in the dossier)
  - [ ] App registration owners reassigned, every client secret rotated
  - [ ] Sole ownerships found and reassigned: Azure subscriptions and management groups, enterprise apps, subscription technical and billing contacts, non-SSO SaaS tenants, vendor portals
  - [ ] Service accounts and embedded secrets enumerated, then rotated
  - [ ] Authentication methods, FIDO2 keys, and any TAP removed from every account they held
  - [ ] Disabled account pulled from Domain Admins and every privileged group
  - [ ] Services and scheduled tasks running as their account checked
  - [ ] Recently read LAPS passwords rotated
  - [ ] Vendor and partner portal accounts removed or rotated
  - [ ] GDAP groups cleaned, per-customer pass scheduled (MSP)
  - [ ] Physical codes recoded, tokens collected and deregistered

| Credential class             | Examples                                                                                                | Move                                                                                                                                                |
| ---------------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Break-glass accounts         | The emergency Global Admin                                                                              | If they ever knew it, it is burned. Rotate today, test the new credential works, reseal the store.                                                  |
| Identity-adjacent external   | DNS registrar, domain registrar, certificate authority accounts, federation config                      | Rotate first among external accounts. Control of DNS is control of the tenant's front door.                                                         |
| Destruction-capable          | Backup console, backup deletion PIN, immutability settings, hypervisor root                             | Rotate the same day. This class is what turns a bad departure into an unrecoverable one.                                                            |
| Infrastructure admin         | Firewall, switches, Wi-Fi controllers, NAS, iDRAC and iLO, UPS                                          | Rotate this week, tracked as a checklist in the dossier.                                                                                            |
| Service accounts and secrets | App registration client secrets, API keys, scripts with embedded credentials, scheduled task identities | Enumerate first, then rotate deliberately. Rotating blind breaks production; not rotating leaves a standing credential in a departed person's head. |
| Vendor and partner portals   | Microsoft partner and licensing portals, ISP, telco, SaaS admin consoles outside SSO                    | Remove their named accounts; rotate anything shared.                                                                                                |
| Physical                     | Door codes, alarm codes, server room keys, hardware tokens                                              | Collect, recode, and deregister returned FIDO2 keys from the account's authentication methods.                                                      |

**The walk-through.** The tenant-side rotations each have a home in the portals. App registrations they owned: in the Microsoft Entra admin center, open **Entra ID**, **App registrations**, select each app from the dossier's ownership list, add a new owner under **Owners**, then open **Certificates & secrets** and rotate every client secret, because a secret is knowable by whoever created it, and a valid secret does not care that its creator's user account is disabled. Their authentication methods: on the user, open **Authentication methods** and remove the registered authenticators, FIDO2 keys, and any Temporary Access Pass, because a disabled account gets re-enabled someday by someone who does not know this history, and it should come back clean.

On-prem: in Active Directory Users and Computers, pull the disabled account out of Domain Admins and its cousins anyway, since a disabled account in Domain Admins is one re-enable away from domain control. While you are in the neighborhood, check for services and scheduled tasks running as their personal account, and rotate any LAPS passwords they read recently: in Intune the device action is **Rotate local admin password** on the device page, and on-prem AD supports on-demand rotation per machine.

If you are an MSP or the leaver worked customer tenants through GDAP, this whole section forks per customer: in Partner Center, remove them from the security groups that carry the GDAP role assignments, then run the credential-class table again for anything they knew inside each customer estate. That work is measured in days, and it belongs on a schedule with an owner, not on a someday list.

-----

## A worked example: the 2 pm walkout

Your infrastructure engineer of six years is being terminated for cause, effective at a 2:00 meeting today. At 1:15 you build the dossier, and the surname search returns two accounts: `jdoe@contoso.com`, synced and mailboxed, and `adm-jdoe@contoso.onmicrosoft.com`, cloud-only and unlicensed, which is where all four active roles and the eligible Global Administrator actually live. Between them: three registered devices, eleven owned objects including two app registrations with live secrets, and, found on the admin account, sole Owner on the subscription that runs the backup vault. At 1:50 you sign in with your own account, open both users in Entra, and stage the tabs you will need. At 2:01, as the meeting starts, you make the cut, admin account first: **Account enabled** cleared, **Revoke sessions**, four role assignments removed, the eligible GA removed in PIM, subscription Owner reassigned to you. Then the daily driver: AD disable and double reset, **Account enabled** cleared, **Revoke sessions**, three devices disabled. At 2:10 the **Wipe** is issued to the laptop sitting in the meeting room and the **Retire** to the BYOD phone. At 2:40, meeting over, the mailbox converts to shared and the manager gets Full Access. Between 3:00 and 5:00 the same-day rotation class happens: break-glass, registrar, backup console, hypervisor. The infrastructure and service-account rotations are scheduled across the next four working days, each line in the dossier getting an owner and a date. Both accounts stay in the tenant, disabled and marked, and the dossier says in one sentence why. The first fifteen minutes were staged in open tabs. The residue was scheduled. Nothing was left to memory.

-----

## Step 6: Validation, proving the cut

Validate resolved state, not behavior. "They could not log in when we tried" proves nothing, because the interesting failure modes are tokens and side doors, and a login test exercises neither.

  - [ ] Every account found in step 1 shows disabled, admin account included
  - [ ] Role assignments zero per account, active and eligible both
  - [ ] Azure RBAC assignments zero at every scope
  - [ ] Every device object disabled
  - [ ] Mailbox type SharedMailbox, license removed
  - [ ] Sign-in logs watched for 24 hours, per account, non-interactive included
  - [ ] PIM eligible list empty, per account
  - [ ] Retained accounts still present and still disabled (you did not over-delete)

**The walk-through.** In the portals, the resolved state reads like this: the user's profile shows **Account status** disabled and the **Assigned roles** page is empty on both tabs; every device on the user's **Devices** list shows disabled; the user's **Mail** tab in the Microsoft 365 admin center reports a shared mailbox and no license. The same asserts, scripted:

``` wp-block-code
foreach ($upn in @("adm-jdoe@contoso.onmicrosoft.com","jdoe@contoso.com")) {
    $u = Get-MgUser -UserId $upn -Property Id,AccountEnabled
    "$upn enabled: $($u.AccountEnabled)"
    # expect: False

    "$upn roles: $((Get-MgRoleManagementDirectoryRoleAssignment `
        -Filter "principalId eq '$($u.Id)'" -All).Count)"
    # expect: 0

    Get-MgUserRegisteredDevice -UserId $u.Id -All |
        ForEach-Object { Get-MgDevice -DeviceId $_.Id -Property AccountEnabled } |
        Select-Object AccountEnabled
    # expect: False on every row
}
# Both accounts must still RESOLVE. A "user not found" here means
# someone deleted an account this run book says to keep.

Get-Mailbox -Identity "jdoe@contoso.com" | Select-Object RecipientTypeDetails
# expect: SharedMailbox
```

Then the behavioral tail. In the Microsoft Entra admin center, open **Entra ID**, **Monitoring & health**, **Sign-in logs**, filter to the user, and watch for the next 24 hours. Read the **User sign-ins (non-interactive)** tab as carefully as the interactive one, because surviving tokens show up there. The expected picture is interactive attempts failing with an account-disabled error and zero successes anywhere. A success after the cut means a surface you missed, and the log entry tells you which one. Last, confirm in PIM that the user's **Eligible assignments** list is empty; an eligible role survives everything else in this run book and reactivates with one approval.

-----

## Step 7: The tail, 24 hours and 30 days

  - [ ] 24 h: wipes reported complete, overnight breakage triaged as discovery
  - [ ] 30 d: license reclaimed, device records cleaned up
  - [ ] 30 d: rotation checklist closed, every line owned and dated
  - [ ] 30 d: account decision made deliberately; a shared-mailbox anchor stays, and the admin account stays regardless
  - [ ] 30 d: both retained accounts marked so a future cleanup does not undo this
  - [ ] Dossier filed with the change record, ticket closed

At 24 hours: review the sign-in logs, confirm the wipes reported complete on each device's page, and triage anything that broke overnight. Treat every overnight failure as discovery rather than nuisance, because a script that failed at 3 am is how you find the service account you missed, and finding it this way is the good outcome.

At 30 days: reclaim the license if you have not already, clean up the wiped devices' Intune and Entra records, close out the rotation checklist with every line owned and dated, and make the account decision deliberately. If the mailbox went shared, the daily-driver account stays, disabled, unlicensed, and marked, indefinitely, because it anchors the mailbox. If it went the inactive-mailbox route, deleting the daily driver completes that design. The admin account stays either way, for the ownership reasons above, so the end state of a clean termination is usually one or two retained accounts that are disabled, empty of roles, and deliberately marked as not-stale. Write that in the dossier in plain words, because the person who eventually questions those accounts will not be you, and the dossier is the only thing that will answer them. File it with the change record and close the ticket. The run book ends when the dossier does.
