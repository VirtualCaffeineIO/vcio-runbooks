# Run Book Checklist: Terminating an IT Employee with Privileged Access

Order matters. Work top to bottom.

## Before the conversation (quiet prep)

- [ ] Confirm a second privileged person (not the leaver) has the roles to do all of this
- [ ] Confirm the break-glass account works and the leaver does not know it
- [ ] Find EVERY account they hold, not just the mailbox one
  - Search on surname, not UPN; search your admin prefix (`adm-`, `a-`, `.admin`)
  - Show the on-premises sync column: cloud-only admin accounts hide from AD-shaped checklists
  - Check the `.onmicrosoft.com` routing domain, not just the company domain
  - Expect: daily driver (synced, mailboxed) + admin account (cloud-only, unlicensed, no mailbox)
- [ ] Inventory their Entra roles, active AND eligible (PIM), PER ACCOUNT
- [ ] Inventory Azure RBAC at management group, subscription, resource group scope
- [ ] Inventory their registered devices
- [ ] Inventory groups, Teams, and app registrations they own
- [ ] Note mailbox size (under 50 GB = no license needed after conversion)
- [ ] Decide: shared mailbox (continuity) or litigation hold + inactive mailbox (preservation)
- [ ] Decide disposition of each device (returning vs remote wipe)
- [ ] Start the dossier document, dated

## Identity cut (during the meeting)

**Admin account FIRST. It is the one that can undo your work.**

- [ ] Disable the admin account, revoke its sessions
- [ ] Remove its active role assignments
- [ ] Remove its eligible PIM assignments
- [ ] Remove its Azure RBAC assignments (separate system from Entra roles)
- [ ] Do NOT delete it (see below)

Then the daily driver:

- [ ] Hybrid: disable the AD account
- [ ] Hybrid: reset the AD password twice (random values)
- [ ] Disable the Entra account
- [ ] Revoke sessions (refresh tokens + browser cookies)
- [ ] Disable every registered device object
- [ ] Remove any remaining role assignments, both kinds
- [ ] If leaver is last Global Admin: activate break-glass GA first, then remove theirs
- [ ] Shared admin account the whole team uses: rotate it, do not disable it
- [ ] Remember the token clock: non-CAE apps can ride tokens up to 1 hour; SaaS app sessions live until the app re-checks

## Devices

- [ ] Capture BitLocker recovery keys BEFORE retire/delete
- [ ] Capture LAPS passwords BEFORE retire/delete
- [ ] Wipe corporate devices (returning or not; offline device = treat data as disclosed)
- [ ] Retire BYOD-enrolled devices
- [ ] Selective wipe MAM-only phones
- [ ] Do NOT delete device records until wipe/retire reports complete

## Mailbox and data

- [ ] Litigation risk? Place hold first, take the inactive-mailbox path instead of shared
- [ ] Convert mailbox to shared
- [ ] Block ActiveSync, IMAP, POP on the shared mailbox
- [ ] Grant Full Access to the manager/team
- [ ] Remove the license (after conversion confirms, if under 50 GB)
- [ ] Do NOT delete the account: it anchors the shared mailbox, forever
- [ ] Mark the anchor account so cleanup never removes it (naming prefix or exclusion group)
- [ ] Grant manager access to their OneDrive now
- [ ] Reassign groups, Teams, and DLs they owned
- [ ] Optional: auto-reply on the shared mailbox

## Privileged residue (rotate what they knew, by blast radius)

- [ ] Break-glass credentials: rotate, test, reseal (same day)
- [ ] Shared admin account used in common by the team: rotate (same day)
- [ ] DNS/domain registrar, cert authority, federation accounts (same day)
- [ ] Backup console, backup deletion PIN, immutability settings (same day)
- [ ] Hypervisor root (same day)
- [ ] Firewall, switches, Wi-Fi controllers, NAS, iDRAC/iLO, UPS (this week, tracked)
- [ ] App registrations they own: new owner, rotate every client secret
- [ ] Find and reassign SOLE ownerships before anyone thinks about deleting the account:
  - Azure subscriptions and management groups where they are the only Owner
  - Enterprise applications and app registrations with one owner
  - Subscription technical and billing contacts
  - SaaS tenants outside SSO where they are the only admin
  - Vendor and licensing portals keyed to their account
- [ ] Service accounts, API keys, scripts with embedded creds (enumerate first, then rotate)
- [ ] Their authentication methods: remove authenticators, FIDO2 keys, any TAP
- [ ] On-prem: remove disabled account from Domain Admins and all privileged groups
- [ ] Check services/scheduled tasks running as their personal account
- [ ] Rotate LAPS passwords they read recently
- [ ] Vendor/partner portals: remove named accounts, rotate shared ones
- [ ] MSP: remove from GDAP security groups, repeat this section per customer tenant
- [ ] Physical: door codes, alarm codes, keys, hardware tokens collected and deregistered

## Validation (state, not behavior)

- [ ] EVERY account shows disabled, admin account included
- [ ] Role assignments: zero per account, both active and eligible
- [ ] Azure RBAC: zero at every scope
- [ ] Every device object disabled
- [ ] Mailbox type = SharedMailbox, license removed
- [ ] Watch sign-in logs 24 hours, per account, including NON-interactive (surviving tokens show there)
- [ ] Any post-cut success = a missed surface; the log entry names it
- [ ] Both retained accounts still RESOLVE (a "user not found" means someone over-deleted)

## The tail

- [ ] 24 h: wipes reported complete; triage overnight breakage as discovery (finds missed service accounts)
- [ ] 30 d: license reclaimed, device records cleaned up
- [ ] 30 d: rotation checklist fully closed, every line owned and dated
- [ ] 30 d: account decision made deliberately
  - Daily driver stays if it anchors a shared mailbox
  - **Admin account stays regardless** (sole ownerships; Entra soft-delete is only 30 days)
- [ ] 30 d: both retained accounts marked so a future cleanup does not undo this
- [ ] File the dossier with the change record, including one plain sentence on why those accounts are kept
- [ ] Close the ticket
