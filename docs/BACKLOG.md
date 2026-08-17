# Run book backlog

Scenarios agreed for the pillar, not yet drafted. Ideation only: title plus entry and exit condition. No steps are written until a scenario is picked for drafting.

Last updated 2026-08-17. Target volume is three to four dozen. The center of gravity is daily and recurring work; the once-a-career events sit in a separate tier and are drafted only after the daily tier has depth.

Status key: **drafted** has a file under `runbooks/`. **agreed** is on the list. **held** was proposed and parked.

## Identity lifecycle

| # | Scenario | Entry | Exit | Outside IT | Status |
|---|---|---|---|---|---|
| I-01 | Terminating an IT employee with privileged access | HR confirms a privileged person is leaving | Every account disabled and tokenless, devices reclaimed, mailbox shared, everything they knew rotated, dossier filed | HR owns the meeting; IT owns the clock | drafted |
| I-02 | Terminating an ordinary employee | HR confirms a departure with a hard cutoff time | Account disabled and tokenless, device reclaimed, mailbox and OneDrive dispositioned, licences recovered, record filed | Acts on HR's written confirmation only | agreed |
| I-03 | Onboarding a new employee | Signed offer, start date, role and manager known | Account live with MFA registered, device enrolled, memberships assigned by role not by copying a colleague, user signed in before day one ends | Manager owns the access request | agreed |
| I-04 | Onboarding a new administrator | New IT hire or existing employee gaining privileged duties | Separate cloud-only admin account to the standard I-01 assumes, phishing-resistant MFA, PIM-eligible not standing, break-glass knowledge granted deliberately, grant documented | | agreed |
| I-05 | Role change or department transfer | HR or manager confirms a move with an effective date | Old access removed not just new access added, memberships re-derived from the new role, owned objects and shared mailbox rights reviewed, licence profile updated | | agreed |
| I-06 | Extended leave | HR confirms leave, with or without a return date | Sign-in blocked, sessions revoked, auto-reply and delegation set, licence decision made, devices held not wiped, everything staged so return is a re-enable | HR owns dates; IT never learns the reason | agreed |
| I-07 | Rehire or return from leave | HR confirms a return | Account re-enabled or re-created (a deliberate choice), MFA re-registered fresh, access re-derived for the current role, stale devices deregistered | | agreed |
| I-08 | Contractor or vendor access grant | Signed agreement and a named internal sponsor | Account created with expiry set at birth, scoped to the engagement, sponsor recorded, expiry calendared | | agreed |
| I-09 | Contractor offboarding | Engagement ends, on schedule or early | Access revoked, guest object removed or blocked, invitations dead, shared credentials rotated, sponsor confirms nothing broke | | agreed |
| I-10 | Death of an employee | HR confirms | Access secured without account-holder cooperation, mailbox and files preserved not dispositioned, auto-replies worded by HR, devices recovered with patience | HR leads everything outward-facing | agreed |
| I-11 | Legal name change | HR confirms new name and effective date | Display name, UPN, address and aliases updated with the old address kept as an alias, sign-in tested on every device, lingering places enumerated | | agreed |
| I-12 | Executive travel hardening | Named person, destination, dates | Temporary controls applied, reversal date scheduled, return-side sweep done before normal access resumes | | agreed |

Held for this cluster: seasonal or temp-worker batch variant of I-03 and I-08; shared mailbox and service account ownership handover (may be a step inside I-02).

## Daily operational

| # | Scenario | Entry | Exit | Status |
|---|---|---|---|---|
| O-01 | Password reset and account lockout | User cannot sign in | Identity verified by procedure, password reset, MFA still works, sessions checked, ticket closed | agreed |
| O-02 | MFA reset or new phone | New phone, lost phone, or broken authenticator | Old methods removed, new method registered through a verified channel (TAP), old device's methods gone | agreed |
| O-03 | New device setup and handoff | Replacement or new laptop in hand for a named user | Enrolled, compliant, user signed in, data landed, old device wiped and shelved or disposed | agreed |
| O-04 | Device swap for repair or warranty | User's device is going away temporarily | Loaner issued and enrolled, user working, broken unit's data safe, swap-back tracked | agreed |
| O-05 | Software install request | User wants an app not in Company Portal | Approved or declined against a stated standard, deployed through Intune not by hand, added to catalog | agreed |
| O-06 | Licence request or reassignment | Someone needs a seat | Free seat found or purchased, assigned, confirmed working, licence sheet still true | agreed |
| O-07 | Shared mailbox or distribution list request | Team asks for a new address or access to one | Created with an owner recorded, membership set, send-as decided, appears in requesters' Outlook | agreed |
| O-08 | Permission request to a share, site or Team | User cannot open something | Data owner approved, access granted through the group not the individual ACL, approval recorded | agreed |
| O-09 | Guest access for an external collaborator | Someone wants to add an outsider | Guest invited within policy, scoped, sponsor recorded, expiry set | agreed |
| O-10 | Printer or scan-to-email not working | The ticket | Classified (driver, queue, network, SMTP relay), fixed, fix noted against that printer | agreed |
| O-11 | Meeting room not working | Someone is standing in the room | Room device signed in and healthy, calendar processing verified, room checked back into the health list | agreed |
| O-12 | VPN or remote access will not connect | Remote user cannot reach what they need | Classified (client, cert, MFA, their network), user working, head-end issues escalated deliberately | agreed |
| O-13 | Mobile phone setup or replacement | New or replacement phone, corporate or BYOD | Enrolled or MAM-protected per policy, mail and Teams working, old phone retired | agreed |
| O-14 | Returned device: collect, wipe, reissue or dispose | A device came back | Data escrow confirmed, wiped, back in the loaner pool or disposed with the disposal recorded | agreed |
| O-15 | Restore request | User reports something deleted or overwritten | Restored from the right layer (recycle bin, retention, version history, backup), user confirms, request logged | agreed |
| O-16 | New starter did not get X | First week, something was missed | Gap filled, onboarding checklist amended so the miss becomes structural | agreed |

## Recurring scheduled

Trigger for each is a calendar entry. The run book states its cadence out loud.

| # | Scenario | Cadence | Exit | Status |
|---|---|---|---|---|
| R-01 | Patch Tuesday cycle | Monthly | Pilot ring deployed and watched, broad ring released, failures triaged, exceptions documented with an expiry, compliance numbers read | agreed |
| R-02 | Backup restore spot-check | Monthly | One real item restored from each layer that matters, verified readable, timing noted, result recorded even when it worked | agreed |
| R-03 | Licence true-up before renewal | 30 to 60 days before renewal | Assigned versus purchased reconciled, seats on disabled accounts reclaimed, unused premium SKUs downgraded, next-term need handed to whoever signs | agreed |
| R-04 | Access review for one system | Monthly, rotating | Every account and permission on that system confirmed by its owner, removals executed same day, review dated | agreed |
| R-05 | Certificate and secret expiry sweep | Monthly | Everything with a clock enumerated (public certs, app secrets, Apple MDM push cert, ADE token, Entra Connect, domain registration), anything inside 60 days ticketed with an owner, inventory updated | agreed |
| R-06 | Stale device cleanup | Monthly or quarterly | Devices past the inactivity threshold identified in Entra and Intune, cross-checked against leaver do-not-delete markers, cleaned up, count recorded | agreed |
| R-07 | Privileged access and role review | Quarterly | Every role holder and PIM eligibility justified or removed, break-glass confirmed present and unused, admin count compared to last quarter | agreed |
| R-08 | Break-glass account test | Quarterly | Signed in with the actual credential, confirmed it works, sign-in alert confirmed to have fired, credential resealed, test dated | agreed |
| R-09 | Security alert and report review | Weekly | The week's Defender and Entra risk alerts triaged to closed or escalated, quarantine handled, risky sign-ins dispositioned, recurring items ticketed | agreed |
| R-10 | Documentation freshness pass | Monthly, rotating | One area read against reality, corrections made, reviewed date stamped | agreed |

## Held tiers

Proposed and parked. Not daily work. Draft only after the tiers above have depth.

**Larger operational events**: day one in a tenant you just inherited; failed Autopilot deployment triage; tenant-to-tenant cutover day; new office standup; office closure; internet outage at the primary site; Microsoft 365 is down; on-prem server hardware failure; a bad patch shipped; planned wildcard or public certificate renewal; domain controller failure in a two-DC shop; file server or NAS migration; telephony carrier cutover; switch or firewall replacement.

**Incident response**: compromised user account; compromised admin account; business email compromise; phishing campaign; malicious OAuth consent; password spray; credentials in a breach dump; ransomware first hour; lost or stolen phone; lost or stolen laptop; malware on an endpoint; data spill; insider threat suspicion; certificate already expired; Apple MDM push cert or ADE token expired; Entra Connect stopped syncing.

Before any incident run book is drafted, two checks are required. The IR series already published on the blog is doctrine about running an incident; run books are the procedure for one incident type, and the line must hold. And the CIAOPS catalog (Robert Crane's Business Premium breach and incident series, 2025 onward) is the closest neighbour in this space: single-scenario, SMB, Microsoft-specific. It differs from these run books in being long-form prose reference rather than checklist-first, and in anchoring to the Business Premium SKU. Read the relevant CIAOPS piece before drafting any incident run book so the two do not cover the same ground with less depth.

**MSP**: customer offboarding and the GDAP unwind; customer onboarding.

**Requests needing a decision, not a fix** (candidate cluster, not yet ideated): personal device use, team wants to buy a SaaS tool, local admin request, sender allowlist request. Exit condition would be a recorded decision against a stated standard.

## Competitive notes

Nothing found in the daily-ticket or recurring-scheduled space at this format and audience. The identity-lifecycle space has MSP marketing checklists (NinjaOne, MSP Corp, ITechPlus) that are listicles, not procedures. The incident space has Microsoft's own playbooks (SOC-tier), FRSecure's downloadable BEC and sibling playbooks (vendor-neutral, IR-team audience), NetDiligence Breach Plan Connect (paid, insurance-channel, breach-coach oriented) and CIAOPS (see above). SRE runbook content (PagerDuty, Nobl9, OneUptime) is service-alert shaped and not for this reader.
