# vcio-runbooks

Single-scenario operational run books for Microsoft estates, written for the one or two person IT shop.

A run book here is one situation, entry condition to exit condition. "Terminating an IT employee with privileged access" is a run book. "Operating Intune" is not. Each one is built to be executed from its checklists alone at 2 pm on a bad day, with the walk-through underneath for any line that needs the detail.

## Who this is for

The admin who owns Intune, Defender, identity and the helpdesk at the same time. Microsoft's own guidance assumes a SOC and a change board. These assume you, and possibly one other person, and that the second person is newer than you.

## What is here

| Path | Contents |
|---|---|
| `runbooks/identity/` | Joiners, movers, leavers |
| `runbooks/operational/` | Daily ticket work |
| `runbooks/recurring/` | Scheduled work with a calendar entry as its trigger |
| `tools/` | Companion scripts, one directory per tool, each with its own README and tests |
| `docs/TEMPLATE.md` | The run book format. Start every new one from it. |
| `docs/BACKLOG.md` | Scenarios agreed but not yet drafted |

## Run books

| Run book | Cluster | Status |
|---|---|---|
| [Terminating an IT employee with privileged access](runbooks/identity/terminating-it-employee-privileged-access.md) | Identity | Draft |

## The format, in short

1. A deck naming the scenario and the end state.
2. Why this scenario is its own thing, and who it is for.
3. Prerequisites: roles, licences, who must be present.
4. Numbered phases. Each opens with its checklist, then a GUI walk-through in durable product nouns, then one consolidated script block.
5. Decision tables at branch points, using real product option names.
6. At least one worked example with concrete times.
7. Validation by resolved state, never by behaviour.
8. A tail: what is owed at 24 hours and at 30 days.

No screenshots. No screen geography. Product nouns survive UI churn; pixel positions do not.

## Review dates

Run books decay faster than doctrine because they name portal surfaces. Every run book carries a written date, a last-reviewed date and a review-by date in its header. Past the review-by date, verify each product noun against the current admin centers before trusting a line. Pull requests that update the review date after a verification pass are welcome.

## Companion scripts

Where a run book ships a script, the script follows one design: Report mode is the default and writes nothing; Execute requires a confirmation token that only Report can produce; nothing irreversible sits in the default path; a rollback journal records only genuinely reversible actions; every gate refuses before the first write; least privilege, with scopes requested conditionally; and an honest statement of what the tool cannot reach. Tested by running, not by reading.

## Licence

Prose under CC BY 4.0. Scripts under MIT. See `LICENSE`.

## Related

Published versions appear on the VCIO blog. This repository is the canonical source for the run books and their tools.
