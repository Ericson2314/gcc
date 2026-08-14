# T141 — removing the shared `tm.h` channel: census, classification, plan

Measured on this worktree, anchor `grep -c MULTI_TARGET gcc/Makefile.in` = **47**.
Instruments: `t141-tmh-census.sh` (reachability), `t141-need.sh` (dependency).
Data: `t141-census.txt`, `t141-need.txt`, `t141-zero-raw.txt`, `t141-delete-ready.txt`.

Both instruments are **source-level** and deliberately independent of any build
dir, per PRINCIPLES rule 6 — a diagnostic-driven sweep only ever reaches the
copies some configured triple compiles, and ~186 targets are never built.

---

## 0. THE FINDING THAT REORDERS THE WHOLE TASK

**`gcc/defaults.h` has ZERO source-level includers anywhere in the tree.**

```
$ grep -rn 'include.*"defaults\.h"' --include='*.h' --include='*.cc' gcc/
(no output)
```

Its only route into any translation unit is the tail that `gcc/mkconfig.sh`
appends to `tm.h` and `tm-<base>.h` (`mkconfig.sh:188-199`, whose own comment
reads *"A tm header is not usable without defaults.h"*).

And `defaults.h` from roughly line 1900 onward **is this branch's entire
conversion layer**:

| line | shape |
|---|---|
| `defaults.h:2024` | `#define FIRST_PSEUDO_REGISTER MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER` |
| `defaults.h:2053-2100` | ~20 `#define <M> (targetm_cdata.<f>)` cdata redirects |
| `defaults.h:2904` | `#define POINTER_SIZE (mt_pointer_size ())` — 32 such `mt_*()` calls |

So: **every runtime redirect this project has landed is reached only through the
header the project exists to delete.** PRINCIPLES already says this in one
sentence (*"the machinery replacing it is currently reached through it"*); what
is new here is that it is not a caveat, it is the **critical path**, and it
makes the obvious first move actively dangerous.

Concretely, deleting `#include "tm.h"` from `target.h`/`backend.h` today does
not just remove target macros — it removes `POINTER_SIZE`,
`JUMP_TABLES_IN_TEXT_SECTION`, `BYTES_BIG_ENDIAN`, `BITS_PER_WORD` and the rest
of the *converted* set as well. Per the standing trap, the ones used on `#if`
lines then silently evaluate FALSE. **The conversion work would be undone by the
deletion it was performed to enable, with no diagnostic.**

**Therefore Phase 0 below blocks everything else.**

---

## 1. VERIFIED CENSUS

### 1a. The channel is FOUR headers, not five

The brief and PRINCIPLES §1 both say five. Measured:

```
$ grep -rln '#[ \t]*include[ \t]*"tm\.h"' --include='*.h' gcc/
backend.h  cp/cp-tree.h  m2/gm2-gcc/gcc-consolidation.h  multi-target-base.h  target.h
```

but `multi-target-base.h` is a **false positive**: all 19 of its `tm.h`
occurrences are inside the explanatory comment block (`multi-target-base.h:23,
25, 29, 36, ...`), which quotes `#include "tm.h"` as prose. It contains no
`tm.h` include. The header channel is:

| header | shared TUs reaching `tm.h` through it (first hop) |
|---|---|
| `backend.h` | 462 |
| `target.h` | 400 |
| `cp/cp-tree.h` | 47 |
| `m2/gm2-gcc/gcc-consolidation.h` | 20 |

The other first-hop names in `t141-census.txt` (`optabs.h` 121, `calls.h` 117,
`optabs-tree.h` 33, `tree-vectorizer.h` 32, `rtl-ssa.h` 16, …) are **not**
additional channels — none of them includes `tm.h`; they are intermediates that
reach it through `target.h`/`backend.h`. So the "these are the whole transitive
channel" claim **holds**, with the count corrected 5 → 4.

### 1b. Population

1665 TUs scanned (all `.cc`/`.c` under `gcc/`, excluding `testsuite/`).

| | count |
|---|---|
| reach `tm.h` | **803** |
| do not | 862 |
| — of the 803: under `config/` (ruled: `BASE_HEADER (tm.h)`) | 178 |
| — **shared** | **625** |
| — — shared, with a DIRECT `#include "tm.h"` | 127 |
| — — shared, reaching it ONLY through the four headers | 498 |

The brief's "roughly 520 of 622" is close on the shared total (625) and
understates the through-headers figure; the correct pair is **625 shared /
498 through-headers-only**.

### 1c. "Includes it" vs "needs it" — the second instrument

Vocabulary: every identifier `#define`d anywhere under `gcc/config/`, plus
`gcc/defaults.h`. Reported as a bracketing pair, never as one number:

| vocabulary | names | shared TUs touching ≥1 | touching none |
|---|---|---|---|
| **raw** (upper bound on need) | 10845 | 586 | **39** |
| **refined** (lower bound) | 5432 | 342 | 283 |

The refined pass filters to ALL-CAPS ≥4 chars not also defined in a shared
`gcc/` header. **Only the raw figure may authorise a deletion**, per the
standing rule that an instrument which can only revoke should be too eager and
one that can grant must be exact — see §4, where the refined pass was caught
granting a wrong deletion.

**So the headline is: of 625 shared TUs in the channel, 39 provably need
nothing, and the other 586 need at least one identifier that some back-end
header defines.** The optimistic reading ("most TUs need nothing") is **not**
supported. It is supported only against the refined vocabulary, which is the
one demonstrated to be unsound for this purpose.

---

## 2. CLASSIFICATION BY FIXABLE SHAPE

### Class A — nothing needed (delete the include)
**39 shared TUs**, of which **23 are direct includers** and therefore
actionable file-by-file with no shared-header change:
`t141-delete-ready.txt`. Twelve are the `algol68/a68-low-*.cc` family; the rest
are `main.cc`, `gcc-main.cc`, `lists.cc`, `rtl-error.cc`, `rtlhash.cc`,
`lto/lto-dump.cc`, `c/c-aux-info.cc`, `c-family/cppspec.cc`, `a68spec.cc`, plus
`gencheck.cc` and `genmddump.cc`.

Caveat that must not be skipped: **`gencheck.cc` and `genmddump.cc` are
generator files.** They are single-target by construction and compiled once per
base. Zero macro use means deletion is right for them too, but they sit next to
the `genemit`/`genattrtab` work another agent owns — hand them over separately
rather than folding them into a bulk deletion.

### Class B — runtime value via `targetm` / cdata
The already-working shape, and the largest by macro count: `defaults.h:2053-2100`
plus the 32 `mt_*()` calls. Nothing structurally new is needed here — the
mechanism is landed and proven. What it needs is Phase 0, so that the redirects
survive the deletion, and then more macros moved onto it.

### Class C — per-base compilation (`BASE_HEADER (tm.h)`)
The 178 `config/` TUs. Ruled, mechanical, no judgement per file — that is
precisely why `BASE_HEADER` was chosen over hardcoded paths. Not part of the
shared-channel removal; listed so the census is complete.

### Class D — HARD RESIDUE 1: macros in array bounds
**54 shared TUs.** Dominated by the register file:

```
24 FIRST_PSEUDO_REGISTER   9 N_REG_CLASSES   9 GENERAL_REGS
 8 ARG_POINTER_REGNUM      7 REGNO_REG_CLASS  3 FRAME_POINTER_REGNUM
 3 BITS_PER_WORD           2 STACK_POINTER_REGNUM ... (24 distinct names)
```

**This class already has its mechanism and it is proven**: `MULTI_TARGET_UNION_*`
plus the generated `multi-target-reg-widths.h` (`hard-reg-set.h:51-61`,
`expmed.h:32`). Note `hard-reg-set.h:52-53` define the union macros as the raw
`tm.h` names, but **only under `#ifdef GENERATOR_FILE`**, which is correct and
is documented in place — generators are single-target and compiled against their
own base's `tm-<base>.h`. Non-generator code takes the generated header.

So Class D is *not* open-ended design work. It is: apply an existing pattern to
the 24 names above at the ~54 sites that still spell the raw name. The header
already carries the warning that a bound left spelled with the unqualified name
is **silent** (`hard-reg-set.h:41-46`) and that `init_reg_sets` checks all seven
struct sizes at start-up and names the struct that disagrees. That start-up
check is the acceptance instrument for this class — it exists, it fires by name,
and it should be run rather than reasoned about.

### Class E — HARD RESIDUE 2: macros on `#if` lines
**116 shared TUs**, ~250 distinct macro names. This is the genuinely hard
residue and it does not have one mechanism. It sorts into three sub-shapes:

**E1 — "does this target override the default?" (the large majority).** The
long tail of ~150 names used in exactly one TU each:
`ASM_OUTPUT_*` (~40 names, `varasm.cc`/`final.cc`), `DEBUG_*_SECTION` (~25,
`dwarf2out.cc`), `COLLECT_*`/`LD_*_SWITCH` (`collect2.cc`), `IFCVT_MODIFY_*`
(`ifcvt.cc`). Each is `#ifdef X ... use X ...`. These are the classic
hook-vs-default question and the answer is already settled policy: a static
per-target answer owned by the back end is a **target hook**. The work is
volume, not novelty, and it is cleanly partitionable **by consuming file**,
which is what makes it parallelisable.

**E2 — the shared-numbering ones, which are NOT E1 and must not be treated as
such.** `SWITCHABLE_TARGET` (17 TUs), `NO_DOT_IN_LABEL` / `NO_DOLLAR_IN_LABEL`
(10 each), `TARGET_SUPPORTS_WIDE_INT` (6), `STACK_GROWS_DOWNWARD` (4),
`PCC_STATIC_STRUCT_RETURN` (5). These are read by many TUs, and several change
**type layout or code shape**, not just an output string. `STACK_GROWS_DOWNWARD`
is the recorded case where the two configured bases **agree** (46 vs 3 definers
across the tree) — so this pair cannot test it, and per PRINCIPLES that is a
request for a third configured back end, not a verdict.

**E3 — the irreducible ones.** `TARGET_SUPPORTS_WIDE_INT` and
`SWITCHABLE_TARGET` select between *different declarations and different struct
layouts*. A runtime value cannot express that. These need either the union
treatment (build both, select at run time) or a decision that all configured
bases must agree, enforced by a check that **fails by name** when they do not.
**This is the one place in the plan where a design decision remains open**, and
per §2b it should be surfaced rather than resolved by whoever gets there first.

---

## 3. DEPENDENCY-ORDERED EXECUTION PLAN

```
Phase 0  sever defaults.h from tm.h            [BLOCKS EVERYTHING]  1 agent
   |
   +--> Phase 1  Class A deletions (23 TUs)                    parallel, N agents
   |
   +--> Phase 2  Class D array bounds (24 names)               1 agent
   |
   +--> Phase 3  Class E1 hook conversions                     parallel, by FILE
   |
   +--> Phase 4  E2/E3 design questions                        needs a 3rd back end
   |
   +--> Phase 5  delete tm.h from the four headers             1 agent, last
```

### Phase 0 — sever `defaults.h` from `tm.h`. ONE agent. Blocking.
Give `defaults.h` a route that does not pass through `tm.h`. The conversion
layer in it is **target-neutral by construction** — it names `targetm_cdata`,
`mt_*()` and `MULTI_TARGET_UNION_*`, never a back end — so it can be included
directly by shared code.

Shape: split `defaults.h` into the target-neutral conversion layer (included
directly, e.g. from `coretypes.h`) and the residue that genuinely needs the
base's own header (stays on the `mkconfig.sh` tail for `tm-<base>.h`).

**Acceptance, and it must be able to fail:** after Phase 0, a shared TU that
includes neither `tm.h` nor anything reaching it must still see
`POINTER_SIZE` expanding to `mt_pointer_size ()`. Inject a deliberate `#error`
into the neutral layer and require the build to fail naming it — an injection
that does not fire is itself a finding.

**Collision risk: HIGH.** `defaults.h` and `coretypes.h` are read by nearly
every TU. This must be one agent, landed alone, with the tree otherwise quiet.
It is the reason the rest of the plan is cheap.

### Phase 1 — Class A deletions. Parallel, no collision.
23 files, each touched by exactly one agent, no shared header modified.
Partition by directory (`algol68/`, then the singletons). **Collision risk:
NONE** — disjoint files.
Required evidence per file, because "it still compiles" is not proof: the
over-broad raw-vocabulary scan must be re-run on the file and score zero, AND
the object must be rebuilt. Hold `gencheck.cc`/`genmddump.cc` back for the
generator owner.

### Phase 2 — Class D. One agent.
Apply `MULTI_TARGET_UNION_*` to the ~54 raw-name array-bound sites.
**Collision risk: MEDIUM** — touches `regs.h`, `ira-int.h`, `hard-reg-set.h`.
Single owner. Acceptance is the existing `init_reg_sets` start-up check, which
already names the disagreeing struct and both sizes.

### Phase 3 — Class E1. Parallel, partitioned BY CONSUMING FILE.
`varasm.cc`, `final.cc`, `dwarf2out.cc`, `collect2.cc`, `ifcvt.cc`, … are
disjoint, and the macro families map almost one-to-one onto them. **Collision
risk: LOW between agents, MEDIUM against `targhooks.cc`**, which another agent
owns — so each Phase 3 agent must add its hook defaults through the owner
rather than editing `targhooks.cc` directly. That is the single serialisation
point in an otherwise parallel phase.

### Phase 4 — E2/E3. Blocked on a third configured back end.
Do not attempt `STACK_GROWS_DOWNWARD` or `ARGS_GROW_DOWNWARD` with i386 +
aarch64: they agree, so no arm can be both-sided and any green is luck.
Configuring a third base is worth more than the conversion itself.

### Phase 5 — delete `tm.h` from the four headers. Last, one agent.
After Phases 0–3 this should be a four-line change. If it is not — if TUs break
— that is the census being wrong, which is the loud signal we want, and each
break names a file and a macro.

---

## 4. WHAT THE INSTRUMENTS CANNOT SEE

Stated because a clean result from an instrument with unexamined blind spots is
worth very little.

- **The census does not follow angle-bracket includes** (no system header
  reaches `tm.h`) and **follows includes inside `#if` blocks unconditionally**.
  The latter is over-broad on purpose: it can only ADD reachers, never remove
  them, so it authorises no deletion.
- **Generated headers are invisible to it.** `insn-*.h`, `options.h`,
  `multi-target-reg-widths.h` are not in the source tree, so edges through them
  are not counted. The 803 is therefore a **lower bound** on reachers.
- **The need scan reads each TU's own text only, not the shared headers it
  includes.** A shared header using a macro in an array bound propagates that
  need to every includer, and this scan will not show it. `hard-reg-set.h` is
  exactly that shape. **This is the largest known gap and the next thing to
  measure.**
- **A macro reached only through another macro is invisible.** The recorded case:
  `function.cc` references `ix86_local_alignment` via `STACK_SLOT_ALIGNMENT`, not
  via `LOCAL_ALIGNMENT`, which is the name the symbol suggests.

### The refined vocabulary was caught granting a wrong deletion — twice

Both are recorded because each moved the answer, and neither was predicted.

**First**, filter (b) originally subtracted every name defined in a shared
`gcc/` header — **including `defaults.h`**. That subtracted exactly the
population under study: a macro with a `defaults.h` fallback and a per-target
override is the `JUMP_TABLES_IN_TEXT_SECTION` shape, i.e. the core case.
Excluding `defaults.h` from the subtraction moved the result **229 → 342 TUs**
and the array-bound residue **5 → 54**. A blind spot worth 113 TUs and a 10×
error in the residue this task exists to size.

**Second, and sharper:** even after that repair the refined pass listed
`algol68/a68-low-generator.cc` as needing nothing. The raw pass revoked it —
the file uses `POINTER_SIZE` at lines 89 and 175. `POINTER_SIZE` is defined in
`defaults.h` **twice** (`:864` generic, `:2904` the `mt_pointer_size ()`
redirect) as well as in 28 back-end headers, and some ordering of the filters
still hid it.

The lesson is the standing one, arriving on its own: **the refined instrument
must never authorise a deletion.** Only the raw, over-broad one may, and that
is why Class A is sized at 39 rather than 283.

---

## 5. WHAT WAS DELIBERATELY NOT LANDED, AND WHY

The brief invites landing a small independent piece as a demonstration. The
obvious candidate was the 23 Class A deletions, and **it is being handed over
rather than landed.**

Reason: §0. Deleting a `tm.h` include today also removes `defaults.h`, and
`defaults.h` is where the conversion layer lives. For a TU that provably uses no
macro at all the deletion is still correct — but it is correct for a reason that
Phase 0 is about to change, and the 23 files cannot be *verified* here: this
task did no build, so the only evidence is source-level, and PRINCIPLES is
explicit that "it still compiles" would not have been sufficient evidence
either. Landing 23 unverified deletions into a tree five other agents are
building from would hand them a failure whose cause is mine.

The demonstration that the plan works is §0 itself: a claim in the standing
document ("five headers") and a claim in the brief ("most TUs need nothing")
were both checkable, and both moved when checked — 5 → 4, and 283 → 39.
