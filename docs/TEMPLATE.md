# Run Book: <Scenario title>

| | |
|---|---|
| **Status** | Draft / Published |
| **Written** | YYYY-MM-DD |
| **Last reviewed** | YYYY-MM-DD |
| **Review by** | YYYY-MM-DD (six months from last review) |
| **Estate** | Which products this assumes |
| **Companion tool** | Path, or "none" |
| **Checklist only** | Path to the items-only file, if one ships |

Run books name portal surfaces, and portal surfaces move. If the review-by date has passed, verify each product noun against the current admin centers before you trust a line.

---

<!-- DECK. One paragraph. Name the scenario and the end state. Not a table of contents. -->

<Entry condition, in plain words>. By the end of this run book <the exit condition, stated as resolved state>.

<!-- FRAMING. Why this scenario is its own thing and who it is for. What makes it different from its obvious neighbour. -->

**Prerequisites.** <Roles, licences, modules, and who must be present before step 1.>

**Outside IT.** <The HR, manager, finance or legal touchpoint, if there is one. One or two sentences. Say who owns it and what IT needs from them.>

---

## Step 1: <Phase name>

<!-- One or two sentences on what this phase is for and why it comes first. -->

- [ ] <Checklist item. Items only. The whole run book must be executable from the boxes alone.>
- [ ] <Item>
- [ ] <Item>

**The walk-through.**

1. **<Item, restated.>** In the <admin center>, open **<Product noun>**, **<Product noun>**, and <action>. <Why, in one clause, if it is not obvious.>
2. ...

```powershell
# <Phase name>, as one block
# One consolidated block per phase. Not a line-by-line echo of the clicks.
```

<!-- DECISION TABLE at any branch point. Real product option names in the cells. -->

| Situation | Action | Why |
|---|---|---|
| | | |

---

## Step 2: <Phase name>

...

---

## A worked example: <a specific day, with a time>

<!-- Not optional. Concrete times, concrete values, one paragraph or a short sequence. This is the part that makes the run book usable. -->

---

## Validation: proving the end state

<!-- Resolved state, never behaviour. "They could not log in when we tried" proves nothing. -->

- [ ] <Stored state assertion>
- [ ] <Stored state assertion>

```powershell
# The asserts, scripted. Each with the expected value in a comment.
```

---

## The tail: 24 hours and 30 days

- [ ] 24 h: <what is owed>
- [ ] 30 d: <what is owed>
- [ ] Record filed, ticket closed

---

<!--
HOUSE RULES, checked before merge:
- No em dashes, no en dashes, anywhere. grep the file; the count must be zero.
- No screenshots, no screen geography ("top right", "the blue button").
- Every load-bearing claim verified against current Microsoft Learn, and every command
  verified separately by running it. A claims pass does not verify commands.
- Nothing invented: no post IDs, slugs, counts, measurements or dates read from documents.
- Voice: first person, experienced consultant, calm and opinionated. No vendor praise.
-->
