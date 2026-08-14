# TASK TRIAGE

Worktree `agent-a5a890fe981eb66d0`, HEAD `80bf400ae06`, anchor
`grep -c MULTI_TARGET gcc/Makefile.in` = **55** (measured, not quoted).

The worktree arrived stale at the bare-repo HEAD `7208eca60d0` with anchor
**0**; `git reset --hard multi-target` fixed it before any measurement was
taken. PRINCIPLES §5 predicts exactly this and it is worth restating that the
tell was the anchor, not the line numbers.

---

## 0. THE BRIEF ASKS FOR SOMETHING THIS AGENT CANNOT READ, AND PRINCIPLES SAYS SO IN ADVANCE

The brief says: *"The task list is in the harness (use `TaskList`/`TaskGet`)"*
and *"Then **update the tasks themselves** (`TaskUpdate`)"*.

**There is no `TaskList`, `TaskGet`, or `TaskUpdate` tool in this harness.**
Measured, twice, with `ToolSearch`: `select:TaskList,TaskGet,TaskUpdate`
returns *"No matching deferred tools found"*, and a keyword search for
`+Task` returns only `TaskStop` (a background-process killer, unrelated).
The deferred-tool roster is `EnterWorktree`, `ExitWorktree`, `Monitor`,
`NotebookEdit`, `SendMessage`, `TaskStop`, `WebFetch`, `WebSearch`, and four
OAuth stubs. Nothing else.

PRINCIPLES §7, line 1410, is this exact situation, written down after it
happened before:

> **A TASK NUMBER IN YOUR BRIEF IS NOT SOMETHING YOU CAN READ.** The task list
> lives in the coordinator's tooling; it is not in the worktree ... A brief
> saying "read tasks #59, #56, #53" is asking for something you do not have.
> **This is the coordinator's error, not yours.** ... an agent that quietly
> writes "#56: done" because the brief mentioned it is manufacturing a green.

And PRINCIPLES line 5: *"If a brief contradicts this document, THIS DOCUMENT
WINS. Say so, stop, and report the contradiction."* Reported.

**Consequences, stated plainly:**

- The deliverable *"for every open task, one of DEAD/LIVE/..."* **cannot be
  produced for ~60 tasks.** I can see neither their subjects nor their bodies.
- *"Update the tasks themselves (`TaskUpdate`)"* **cannot be done at all.** No
  task was closed, corrected, or annotated, because no tool exists to do it.
- I have **not** invented verdicts for numbers I could not read. Every entry
  below is triaged against text I actually opened.

What I did instead, which is the checkable core of the request: the brief's
own method — `git merge-base --is-ancestor` over every named cause — applied
to **every commit SHA named anywhere in `PRINCIPLES.md` and `STATE.md`**, plus
re-measurement of the specific figures the brief and those documents quote.
That is the "named-cause list read as current" hazard the task is really
about, and it *is* answerable from the worktree.

Scripts, all committed and all asserting the tree they measure:
`scratchpad/triage-sha.sh`, `triage-tmh.sh`, `triage-loud20.sh`,
`triage-emit.sh`, `triage-misc.sh`, `triage-ts.sh`.

---

## 1. FLAGS THAT CHANGE A LIVE AGENT'S BRIEF RIGHT NOW

### 1a. Emit-correctness agent — your C1 root cause is already named in #169's LOUD queue, and it is a `#ifdef`, not a table

`T170-EMITS.md` attributes three of the five non-emitting back ends
(ia64, visium, xtensa) to *"C1 — a null function pointer in a per-base table"*
at `optimize_mode_switching()`. That framing sends you looking for an unfilled
selector slot. Measured at HEAD, the mechanism is upstream of that:

```
gcc/mode-switching.cc:43    #ifdef OPTIMIZE_MODE_SWITCHING
gcc/mode-switching.cc:817       if (OPTIMIZE_MODE_SWITCHING (e))
gcc/mode-switching.cc:1292   #endif /* OPTIMIZE_MODE_SWITCHING */
gcc/mode-switching.cc:1322   #ifdef OPTIMIZE_MODE_SWITCHING
```

`OPTIMIZE_MODE_SWITCHING` is **unconverted** — it appears on no redirect line
in `defaults.h`, `multi-target-macros.h` or `multi-target-base.h`
(`triage-loud20.sh`). It is simultaneously **#169's LOUD-queue entry at weight
47**, i.e. 47 of 48 back ends are served the primary's answer for it. The
whole of `mode-switching.cc` is compiled under i386's answer to a `#ifdef`.

So #170's C1 and #169's LOUD entry are **one defect described twice**, and the
`#ifdef` is the thing to convert. This is PRINCIPLES' *"walk the guards that
decided you reached that line, and convert the closure"* — the null pointer is
where it stops, not why.

The two DFA entry points (`insn_has_dfa_reservation_p`, `state_transition`,
riscv/mips) are a genuinely separate family and that half of C1 stands.

### 1b. `Init(...)` / riscv-word-size agent — `Pmode` is already converted; your population is 401 across 45 files

`Pmode` is **DEAD as a leak**: `multi-target-macros.h:567` reads
`#define Pmode (mt_pmode ())`. i386's `config/i386/i386.h:2001` still carries
its own `(ix86_pmode == PMODE_DI ? DImode : SImode)`, which is correct and is
i386's own answer, not a leak. If your brief still describes `Pmode` as an
open wall, it is stale.

`ix86_pmode ... Init(PMODE_SI)` is still present at
`config/i386/i386.opt:314`. That is fine in itself — the defect PRINCIPLES
records was `Pmode` *reaching shared code*, and that channel is closed.

The unconfigured-default **class** is live and now has a measured size:
**401 `Init(...)` directives across 45 `.opt` files** under `gcc/config/`.
If you were briefed a different number, use this one.

### 1c. Per-target testsuite agent — the harness EXISTS and is wired in; what is missing is the caller

`gcc/testsuite/lib/multi-target.exp` exists, and `lib/gcc-dg.exp:42` really
does `load_lib multi-target.exp`. So this is **not** an absent mechanism.

But it is **inert by construction**: `multi-target.exp:33` and `:102` both gate
on `[info exists env(MT_TARGET_NAME)] && $env(MT_TARGET_NAME) ne ""`, and
**nothing sets `MT_TARGET_NAME`** — no hit anywhere in the tree outside the
file's own guards and its comment. `gcc/Makefile.in` has no `MT_TARGET`
reference in any test rule.

This is PRINCIPLES' *"mechanism present but never invoked"* / *"three arms, not
one"*. The missing piece is the per-target driver loop that sets the variable,
not the harness. Anyone writing a fresh harness would be rebuilding a landed
one; anyone reading "the harness is missing" has the diagnosis backwards.

---

## 2. THE ANCESTRY SWEEP — THE BRIEF'S OWN METHOD, RUN OVER EVERYTHING NAMED

`scratchpad/triage-sha.sh`: extract every 7–12 hex token from `PRINCIPLES.md`
and `STATE.md`, keep the ones that resolve to commits, and
`git merge-base --is-ancestor <sha> HEAD` each.

**132 candidate tokens → 61 real commits → 59 IN-HEAD, 2 NOT-ANCESTOR.**

The two exceptions are both benign, and neither is a pending fix:

| sha | subject | reading |
|---|---|---|
| `7208eca60d0` | `find_a_program: Only search for prefixed paths...` | the **bare-repo HEAD** itself, 39k commits behind — PRINCIPLES §5 cites it as the stale-worktree marker. Correctly not an ancestor. |
| `bb013cbe0f6` | `Get rid of with_multisrctop, and MULTISRCTOP` | superseded: `abd0a87eb25`, **identical subject**, IS in HEAD. Same work, re-committed; not an outstanding change. |

**This is the headline negative result, and it is worth stating loudly because
the brief predicted the opposite.** The brief's motivating incident — six
blockers handed over, four already fixed on a branch that was not an ancestor
— **does not currently reproduce.** Every named fix recorded in either standing
document is in HEAD. There is no parallel-branch backlog hiding behind the
documentation right now.

That is a real finding and not an absence of one: the instrument could have
said otherwise, and on 2 of 61 it did.

---

## 3. VERDICTS ON WHAT IS READABLE

### STALE FIGURES, LIVE CAUSE — the `tm.h` terminal state (#68 / #141 / #160 / #173 territory)

PRINCIPLES §1 states the populations as **248 shared TUs outside `config/`**,
**101 under `config/`**, and **4 shared headers**. Re-measured at HEAD
(`triage-tmh.sh`, matching `^\s*#\s*include\s+"tm\.h"`):

| population | PRINCIPLES says | measured at HEAD `80bf400ae06` |
|---|---|---|
| outside `config/` | 248 | **145** |
| under `config/` | 101 | **47** |
| the four shared headers | 4 | **4 — unchanged, all still include it** |
| `BASE_HEADER (tm.h)` sites | — | **37** |

So roughly **40% of the shared-TU channel and 53% of the `config/` glue have
already been closed** since those figures were written, and any sizing done
from 248/101 overstates the remaining work by more than two-fold.

**The cause is live and the blocker is precisely the unchanged row.**
`target.h`, `backend.h`, `cp/cp-tree.h` and `m2/gm2-gcc/gcc-consolidation.h`
each still carry exactly one `#include "tm.h"`. PRINCIPLES is explicit that
these four are the whole transitive channel and that deleting them today would
un-define the *converted* macros too, because `defaults.h` reaches every TU
only as the tail `mkconfig.sh` appends to `tm.h`. That ordering constraint is
unchanged and still governs; see `T141-TMH-REMOVAL-PLAN.md`.

### LIVE — #169's LOUD queue, essentially untouched

The census (`T169-GUARD-CENSUS.txt`) was taken at **anchor 50**; HEAD is
**55**, so it is five anchor-moves old and was due for exactly this check.
Its measurement commit context is in HEAD (`8e87bbadcc8`, IN-HEAD).

Of the 16 named LOUD macros, `triage-loud20.sh` finds **0 converted**. Two
show a hit in the layer and both are *upstream defaults, not conversions*:

- `defaults.h:1374  #define TARGET_SUPPORTS_WIDE_INT 0` — a plain fallback.
  This is the VALUE-axis story the census tells (48/48 define it; i386 says 1;
  37 bases disagree), and it confirms rather than retires the entry.
- `defaults.h:443  #define EH_RETURN_DATA_REGNO(N) (void (N), INVALID_REGNUM)`
  — likewise a default, not a per-base redirect.

So #169's LOUD half is **LIVE at full weight**. The brief calls #169's *silent*
half the priority; note the census itself states the LOUD 20 is a **floor**
(the LOUD/SILENT split is by brace depth and the stripping pass can only lose
braces), and that the SILENT half at 363 macros is 18.1x the loud one.

### LIVE — #170's emit table, with one caveat about its age

`T170-EMITS.md`: **11 link, 4 emit, 3 assemble to an object of the right ELF
machine.** Measured at `8e87bbadcc8`, anchor 50 — **IN-HEAD**, so it is a
measurement on an ancestor, not on a divergent branch. It is stale by five
anchor-moves but not *wrong-tree* stale.

I did **not** re-run it. Doing so is a multi-base build, which the brief
correctly rules out for a measurement task, and three agents are live in the
same area. Treat the table as a lower bound on progress and re-take it before
quoting it as current.

The four-back-end binutils gap (sparc, ia64, visium, xtensa: 0 nixpkgs
attributes each, against aarch64=1 and riscv=2 as the non-vacuity control)
is a property of the machine and does not expire. Note its own conclusion:
all four **ICE before emitting a byte** even with a labelled fallback config,
so binutils is not what is blocking them.

### UNCHECKABLE — #164, #172, #38, #97, #68, #173, and the ~50 unnamed others

`grep -n '#164\|#172\|#173\|#38\|#97'` over `STATE.md` returns **no section
for any of them**. `#68` appears twice, both times as a passing cross-reference
to an "Arm D" and an "Arm B boundary" whose defining text is not in the file.
`#160` appears only in `PRINCIPLES.md`, in the second-vocabulary paragraph.

`STATE.md` is 13,926 lines and carries sections for a *subset* of task
numbers. The subset does not include most of the ones the brief prioritises.

**These are UNCHECKABLE for a precise reason, not a vague one:** the task
bodies live in coordinator tooling this agent has no tool to reach (§0), and
`STATE.md` — the documented fallback — has no text for them. This is the
legitimate verdict the brief allows, and it applies to the majority of the
list.

**The oldest low-numbered tasks:** the brief says they matter least and invites
me to say so rather than skip silently. I am saying so — and adding that I
could not read them either, so "matters least" is the brief's judgement and not
a finding of mine. I have no evidence about them in any direction.

### Noted, not fixed — two trivial items filed rather than touched

Per the brief's "file it as a task rather than touching it":

1. **`gcc/config/site`, `gcc/err`, and `temp.c` are untracked at the repo
   root** (they were in the starting `git status`). `temp.c` and `err` look
   like debugging residue. Worth someone confirming they are nobody's live
   fixture before removal — PRINCIPLES §5: *"In a shared build dir, a file you
   did not write is not a fixture."* I did not touch them.
2. **`scratchpad/sweep.sh` is still absent** while `gcc/Makefile.in` cites it
   by name as the duplicate-symbol guard. PRINCIPLES §4 records this ("A GUARD
   THE BUILD SYSTEM CITES BY NAME MAY NOT EXIST") and names
   `scratchpad/t150-rename-gap.sh` as the N-way replacement — which does exist.
   The **`Makefile.in` comment still points at the file that was never
   written**, so the next reader gets the same false assurance. A one-line
   comment correction, deliberately not made here because `Makefile.in` is the
   anchor file and editing it would move the anchor off 55 under three live
   agents.

---

## 4. COUNTS BY VERDICT

Scoped to what was actually readable. I am not reporting a denominator of ~60.

| verdict | count | items |
|---|---|---|
| **DEAD** | **2** | `Pmode` as a shared-code leak (converted, `multi-target-macros.h:567`); `bb013cbe0f6` (superseded by `abd0a87eb25`, identical subject, in HEAD) |
| **LIVE** | **4** | #169 LOUD queue (0 of 16 converted); the four shared-header `tm.h` includes; `OPTIMIZE_MODE_SWITCHING` `#ifdef` in `mode-switching.cc`; `MT_TARGET_NAME` set by nothing |
| **STALE FIGURES, LIVE CAUSE** | **2** | `tm.h` populations 248/101 → **145/47**; #170 emit table and #169 census both taken at anchor 50, HEAD is 55 |
| **SUPERSEDED** | **1** | `scratchpad/sweep.sh` → `t150-rename-gap.sh` (but the `Makefile.in` citation still names the dead file) |
| **UNCHECKABLE** | **~50+** | every task number with no `STATE.md` section — including #164, #172, #38, #97, #68, #173, and the entire low-numbered tail |

**Ancestry sweep: 61 commits tested, 59 IN-HEAD, 2 NOT-ANCESTOR, 0 outstanding
fixes found stranded off-branch.**

---

## 5. WHAT THIS DOES NOT CLAIM

- **Nothing here is a build.** Every figure above is a grep, a `git
  merge-base`, or a file read. The `tm.h` counts are text matches on
  `#include "tm.h"` and do not see the transitive channel — PRINCIPLES §4 is
  explicit that 21 of 22 revocations came through headers and only 1 from a
  file's own text, and that only an amputation build settles it. **145 is a
  count of direct includers, not a count of TUs that need `tm.h`.**
- The LOUD-20 conversion check is **deliberately over-broad** (it can only
  flag "look again", never authorise closing an entry) and it reads three
  files. A macro converted by some other mechanism — a union, a generator —
  would score `unconverted` here. PRINCIPLES records exactly that trap:
  `MAX_BITSIZE_MODE_ANY_MODE` was converted by the genmodes union while the
  board said `UNCONVERTED`. **Treat the 0-of-16 as "no evidence of
  conversion", not as proof of non-conversion.**
- I did not re-run #170's emit table, the probe scoreboard, or any acceptance
  bar. Three agents are live in those areas and the brief forbids fixing.
- **No task was updated**, because no tool exists to update one (§0). The
  triage above is the whole of what could be delivered.
