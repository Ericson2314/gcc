# PRINCIPLES — read this before acting on any brief

This is the standing law of the GCC multi-target branch. Every agent reads it.

**If a brief contradicts this document, THIS DOCUMENT WINS.** Say so, stop, and
report the contradiction. Briefs are written by a coordinator who does not
measure and has been wrong many times — including once about a *design shape*
rather than a number, which is the kind an agent can build before anyone
notices. You are expected to push back. Eight agents contradicted their briefs
in one session and were right every time.

---

## 1. The goal

**GCC multi-target like LLVM: one compiler binary with all back ends linked,
and ALL BACK ENDS PASSING TESTS** — with zero target-specific information baked
in at compile time. The user's words: *"The tests were not written in terms of
multiple targets so might have to adjust the tests, but at the very least we
could build the test suite N ways for n targets, covering all the backends."*

**Where that stands.** Linking is DONE — 47 of 47 back ends link into one
`cc1` as of `80bf400ae06` (2 → 8 → 11 → 47 in one session). Passing tests is
NOT: at last measurement only **4 of 47 emit assembly and 3 assemble**, and
the testsuite has never run per-target. **The gap is correctness, and the
testsuite is now due** — it was sequenced after "all back ends building", and
that condition has been met.

**SEQUENCING IS NOT SCOPE, and the coordinator got this wrong.** The user
deferred the testsuite meaning *"do the back ends first, then come back to
it"*; the coordinator converted that into "out of scope", stopped tracking it,
and later reported it back as a **gap in the project** rather than as
something it had dropped. The user, on seeing it: *"'deferred' never meant
'out of scope' — it just meant deprioritize."*

So, as standing law for anyone reading a brief here:

- **An instruction to "go work on X" is the NEXT STEP toward this goal, not a
  replacement for it.** The goal only changes when the user changes it.
- **Nothing leaves the board silently.** If you stop tracking something, say
  so explicitly and say why.
- A deprioritised item is still a measurement obligation: when the condition
  that deprioritised it is met, it becomes due without anyone re-authorising
  it.
- **DO NOT STOP AT A MILESTONE TO AWAIT INSTRUCTION.** The user, explicitly:
  *"not stop after getting the backend working to await future instruction!"*
  Finishing "all back ends link" is not the end of a task, it is the moment
  the next one becomes due — and the next one was already written down. Report
  the milestone and keep going in the same breath. Waiting for permission that
  was already given is the most expensive thing an agent can do here.

**THE BUILD CENSUS — several partially-overlapping figures are in circulation,
so re-measure rather than quote, and say which build you measured.**

Chronological, each true when taken:

| measurement | figure | caveat |
|---|---|---|
| 48 configured, before the opts fix | **0** back ends produce objects | 974 diagnostics, all `loongarch-opts.h`, **in `build/gen*.o`** — nothing downstream attempted, and `make -k` silence read as success |
| 47 (loongarch dropped), before poly | 4 → **8** clean | i386, aarch64, riscv, rs6000 + mips, nds32, s390, sparc |
| 48, after the opts fix | **48** produce objects | one defect, 974 diagnostics — the largest amplification recorded |
| 47, after the poly fix | errors 3060 → **842**; failing back ends 39 → **11** | poly-class 2224 → 2 real |

**No figure yet exists with BOTH the opts fix and the poly fix merged.** Anyone
building multi-back-end should report it.

**Amplification is the reason counts mislead here**: single defects have
produced **974**, **725**, **606** (from only *two* back ends) and **94**
diagnostics. **Report causes, not lines**, and say how many back ends a cause
covers.

**Two attribution rules, both learned by getting them wrong today:**
- **Never attribute a diagnostic to a back end by the nearest preceding compile
  line** — invalid under `-j8`; i386's command is followed by visium's errors
  from another job. Use make's **failing-target** lines.
- Under `-k`, **"never attempted" and "passed" are the same silence.** Read the
  filesystem as a second instrument.

**PREFER THE LOUDEST AVAILABLE SIGNAL, AND CHECK WHETHER YOU CAN MANUFACTURE
ONE.** The user, after a day of this: *"the obvious thing to do is enable all
backends and then grind fixing build failures … build failures are the easiest
thing to debug."* He is right, and the failure of judgement is worth naming
precisely.

A whole day went into the **hardest** class of signal — silent wrong code, a
wrong CFA offset, a null `ix86_cost` found under gdb, a macro resolving to the
primary's *unconfigured* default. Each of those costs a debugger session and a
bespoke injection arm to establish anything at all. Meanwhile a **build
failure** names a file, a line and a cause, deterministically, and forty of
them at once sort into five groups.

And the lever that converts one into the other was sitting unused: **configure
more back ends.** The two-back-end habit is *why* those bugs were silent — with
only i386 and aarch64, a leak usually produces a plausible answer rather than
a diagnostic.

So before starting a deep investigation, ask: **is there a configuration in
which this bug would announce itself?** If yes, build that configuration
first. Depth on a narrow build feels productive because every wall yields a
real result; it is still the expensive way to find them.

**PRIORITY RULE, from the user: build failures before test failures.**
*"correctness failures are harder … so lets prioritize build failures over
test failures — unless we think we are breaking the compiler when we fix the
build."*

The exception is the load-bearing half, because **"make it build" has a known
wrong shape on this branch**: adding an `#ifndef` floor, a default value or a
"sensible fallback" so a missing answer stops erroring. That is the first item
in §2a. It converts a loud build failure into a silent correctness bug, and
the fallback is always the primary's answer, which is the bug being
eliminated. **A build fix that could not have been written without inventing
an answer is not a build fix.**

So: grind build failures first, and for each one ask whether the fix supplies
a *real* per-base answer or merely stops the compiler complaining. If the
latter, it is a correctness change wearing a build fix's clothes — stop and
report it as a design question.

**TWO BACK ENDS IS A HABIT, NOT A CONSTRAINT — AND IT IS WHY SO MUCH HERE IS
"UNMEASURABLE".** Everything on this branch has been built with i386 +
aarch64, and that got treated as a property of the environment. It is a
choice, and the goal is **all** back ends in one binary. The user: *"aren't we
trying to build **all** the backends?"*

Look how much rests on it, every item a recorded honest negative:

- **51 `gcc/config/` files** whose `tm.h` include could not be classified.
- `INCOMING_REG_PARM_STACK_SPACE` — correct **by luck**: i386 returns 0 for
  SysV, the same as aarch64's absence.
- `ARG_POINTER_CFA_OFFSET` — correct **only because `FIRST_PARM_OFFSET` is 0
  in both bases**. *Passing for a reason a third back end would destroy.*
- `STACK_GROWS_DOWNWARD` / `ARGS_GROW_DOWNWARD` — genuinely per-base, **46 vs
  3** definers, but they **agree on this pair**.
- `RELOAD_ELIMINABLE_REGS`, `HONOR_REG_ALLOC_ORDER` — no in-tree back end
  defines them, so no arm can be both-sided.
- ~~The DFA-absent case — both configured bases have reservations.~~
  **SETTLED, AND IT IS THE BEST ARGUMENT ON THIS LIST.** Not by "a third back
  end would help" but by forty-seven: **14 of the 47 have no
  `define_insn_reservation` at all** — avr cris fr30 ft32 gcn h8300 mmix moxie
  msp430 nvptx pdp11 rl78 vax xstormy16 — measured from each
  `insn-attr-common-<base>.h`, i.e. from `genattr-common`'s own answer
  (`scratchpad/a98009045f7229938-dfacensus.sh`), **over all 47 headers** —
  the first reading of that census said 13 of 45 because it was taken while
  the build was still generating them, and a directory read mid-write looks
  exactly like a complete one. Shared code read the
  **primary's** `#ifdef INSN_SCHEDULING`, so **eleven** of them ICEd on
  `int f (int x) { return x + 1; }` at `-O2` — no header, no libc — with
  *"back end 'X' has no pipeline automaton"*. Widest cause by breadth **and**
  largest by volume (1,449 results) on the 28-back-end board, the only time
  those two orderings have agreed. Fixed by `mt_has_insn_scheduling ()`.

  Three things to carry, none of them about the DFA:

  - **The item was written as a limit of the INSTRUMENT and read as a limit of
    the WORLD.** "Both configured bases have reservations" is true and is a
    fact about i386 + aarch64. It sat on this list while the defect it names
    was live on eleven back ends and was the largest single ICE cause in the
    tree. *A "cannot tell" entry is a debt, and it accrues interest silently.*
  - **A self-describing diagnostic is invisible to a text-keyed ranking.** The
    message names the back end, so one shared defect keys as N causes of one
    back end each and can never rise in a breadth ordering. It was recorded as
    **avr's alone, twice**. The property that makes a message useful to a
    human is the property that hides it from the instrument. Fold every field
    that varies with the **target**, no field that varies with the **defect**;
    `scratchpad/a98009045f7229938-foldcheck.sh` asserts the fold still covers
    the population, and found a second escapee (`target %qs names back end
    %qs`) that is not `back end`-shaped at all.
  - **`-O0` is the least representative level available.** Over the 45 targets
    with a `specs-config`, a one-line function gives `-O0` ok = 38, `-O1` = 37,
    **`-O2` = 28**; ten back ends compile it at `-O0` and ICE at `-O2`.
    Scheduling is an `-O2` pass, so every precondition that probed at `-O0` —
    including the one written *because* a back end dying on its first input is
    invisible to a `.sum` ranking — reproduced the exact blindness it existed
    to remove, one optimisation level down.

Every one is the same sentence: **two back ends cannot tell.** So "unmeasurable
with this pair" is not a permanent verdict, it is a **request for a third back
end** — and adding one is worth more than most individual conversions, because
it converts a whole class of luck into evidence at once. Before writing that
phrase, ask whether one more configured target would settle it.

**AND AS OF TASK #150, A THIRD BACK END IS NOT A FREE ACTION — MEASURED, WITH
THE BLOCKERS NAMED.** The paragraph above is right about *why* to want one and
was silent about the cost. Four base sets were configured for #150 and **only
`i386 + aarch64` yielded a usable `cc1`**:

| base set | what stopped it |
|---|---|
| i386 aarch64 rs6000 s390 | `cc1` does not link: `print_operand`, `print_operand_address`, `legitimate_pic_operand_p`, `legitimize_pic_address`, `regclass_map` multiply defined |
| i386 aarch64 riscv mips | `cc1` does not link: `extract_base_offset_in_addr`; and `insn_mips::unspecv_strings{,_len}` undefined |
| i386 aarch64 riscv | links, but **x86_64 then ICEs in `multi_target_select`** — "back end 'i386' installs no garbage-collection markers"; and riscv's `cc1` **segfaults before parsing** |
| i386 aarch64 | works |

`extract_base_offset_in_addr` is fixed (a `MULTI_TARGET_RENAME_NAMES` entry —
no shared TU names it, so each back end simply keeps its own). The rest are
open and are **four independent causes**, not one.

Three things this changes about how the lever should be described:

- **"Configure more back ends" currently costs a debugging session per extra
  base, not zero.** It is still the right lever; it is not the cheap one the
  paragraph above implies. Budget for it.
- **The `MULTI_TARGET_RENAME_NAMES` comment named a `sweep.sh` as its authority
  and that file DID NOT EXIST**, and the check it described was over "the two
  object SETS" — the two-back-end habit written into the instrument itself.
  **The N-way replacement is `scratchpad/mt-rename-sweep.sh`, and it is the
  survivor of six.** That sentence went on to name `t150-`, `t155-`, `t157-`,
  `t165-` and `t167-rename-gap.sh` in turn — one job, six authorities, no
  diagnostic, i.e. this branch's own root bug in its own tooling, with four
  add/add merge conflicts on colliding `t<NNN>` names in a single day. The
  survivor is the **union** of their arms, because later was not automatically
  better: the *oldest* of the six was the only one that exits nonzero and the
  only one that compares just the objects that are actually linked. See
  `scratchpad/INSTRUMENTS.md` for the current set and
  `scratchpad/ATTIC.md` for which arm came from where.
- **The gengtype-marker and riscv-segfault failures appear only at three
  bases**, so they were invisible to every measurement this branch has taken.
  Expect more of these, and expect each new base to find its own.

**THERE IS NO NON-ARCH-SPECIFIC `tm.h`, AND THERE NEVER WAS ONE.** This is the
whole bug in one artefact, and it is worth reading the file before reasoning
about it. The bare `gcc/tm.h` in a two-backend build is 1578 bytes whose
business end is:

```c
#ifdef IN_GCC
# include "config/i386/biarch64.h"
# include "config/i386/i386.h"
# include "config/i386/unix.h"
# include "config/i386/att.h"
# include "config/i386/x86-64.h"
# include "config/i386/gnu-user-common.h"
# include "config/i386/gnu-user64.h"
# include "config/i386/linux-common.h"
# include "config/i386/linux64.h"
#endif
```

i386's **entire header chain, under a target-neutral filename**. It is not a
generic `tm.h` missing its per-target parts — **it is the i386 `tm.h` wearing
a name that does not say so.** 248 shared TUs write `#include "tm.h"`
believing they get something generic and get x86. `Pmode`, `ELIMINABLE_REGS`,
`INIT_EXPANDERS`, `ACCUMULATE_OUTGOING_ARGS` were each a file reading that
list and not knowing it.

By contrast `<base>-inc/tm.h` is a 62-byte shim that **says which base it is**:
`#include "tm-i386.h"`.

**Terminal state: no SHARED translation unit includes `tm.h`.** Not "delete
the generic one" — **delete the one that lies**. A per-base file including its
own `tm.h` is correct and stays. Say it in the shared/per-base form; the
stronger "no `tm.h` anywhere" phrasing has been in this file and an agent
could act on it wrongly.

Two things not to lose when it goes: its **top half is genuinely
target-neutral** (`DEFAULT_LIBC`, `HAVE_LD_PIE`, `TARGET_HAS_IFUNC` fallbacks)
and must land somewhere, not simply vanish; and it ends with
`#include "defaults.h"`, which is where the per-base redirects live — so the
machinery replacing it is currently reached *through* it.

Currently **248 files outside `config/` include `tm.h`**, plus 101 under it.
Those 248 are the channel: `INIT_EXPANDERS`, `Pmode`, `ELIMINABLE_REGS`,
`ACCUMULATE_OUTGOING_ARGS` and `STACK_DYNAMIC_OFFSET` were each a shared TU
reading the primary's `tm.h`. **"Delete the shared `tm.h`" and "finish the
macro conversion" are the same task stated twice.**

**DO NOT RELY ON `-I` SHADOWING. Name the base at the point of inclusion.**
User ruling: *"I think it would be good to do `#include \"<base>/tm.h\"` …
that way we don't rely on -I shadowing."* Each back end has a `<base>-inc/`
directory carrying its own `tm.h`, `tm_p.h`, `tm-preds.h`, `tm-constrs.h` and
generated `insn-*.h` — **this branch invented those; upstream has exactly one
`tm.h`.** Per-base files got them via `-I<base>-inc` plus a plain
`#include "tm.h"`, which means **a missing or mis-ordered `-I` silently
resolves to the primary's header with no diagnostic.**

That is not hypothetical: `d7a12b9d5c4`'s own subject is *"one `.o` rule per
back-end object, **and the include directory did not reach them**"* — the
mechanism existed and did not reach its consumers, in the include path.

**RULED: wherever a `tm.h` include survives it is `BASE_HEADER (tm.h)`;
wherever it need not survive it is DELETED. Never hardcode a path.** Hardcoding
*can* work for a single-base file, and is still wrong, because **it fails
silently when the classification is wrong**: a file spelling
`"riscv-inc/tm.h"` that is ever built for a second base gets riscv's headers
and compiles cleanly, since that file exists. `BASE_HEADER` cannot do that —
`MT_BASE` is per *object*, so it always follows what is actually being built.

The classification is genuinely error-prone, which is the point.
`config/linux.cc` is built for **both** bases (`mt-i386/linux.o` and
`mt-aarch64/linux.o`), so "it lives under `config/`" tells you nothing. And the
upstream population is inconsistent for no reason: of the `config/*/*-c.cc`
files, `aarch64-c.cc`, `arc-c.cc`, `bpf-c.cc`, `ia64-c.cc` spell `tm.h` while
`arm-c.cc`, `avr-c.cc`, `i386-c.cc`, `microblaze-c.cc` do not. Hardcoding means
auditing 101 files and being right every time, with silence as the penalty for
being wrong. The macro needs no audit — which also keeps the upstreaming story
to one mechanical transformation rather than a per-file judgement a reviewer
must re-derive.

**The four populations, with no `-I` selection anywhere:**

| population | count | action |
|---|---|---|
| **shared headers** | **4** — `target.h`, `backend.h`, `cp/cp-tree.h`, `m2/gm2-gcc/gcc-consolidation.h` | **stop including `tm.h`** |
| shared TUs | 248 | stop including it (macro conversion) |
| `gcc/config/` glue | 101 | `BASE_HEADER (tm.h)` |
| compiled N times | 7 | `BASE_HEADER` — **done** |

**The count was 5 and is 4.** `multi-target-base.h` was in that list by a
**false positive**: all nineteen of its `tm.h` occurrences are inside its own
explanatory comment block, which quotes `#include "tm.h"` as prose. It includes
no `tm.h`. Measured by `scratchpad/t141-tmh-census.sh`; the "whole transitive
channel" claim itself HOLDS, and the corrected first-hop split is
`backend.h` 462 / `target.h` 400 / `cp-tree.h` 47 / `gcc-consolidation.h` 20.
Other first-hop names in the census (`optabs.h`, `calls.h`, `rtl-ssa.h`, ...)
are intermediates that reach `tm.h` THROUGH these four, not extra channels.

**AND `defaults.h` HAS ZERO SOURCE-LEVEL INCLUDERS — its only route into any TU
is the tail `mkconfig.sh` appends to `tm.h`.** Since `defaults.h:1900+` is this
branch's entire conversion layer (cdata redirects, `MULTI_TARGET_UNION_*`, 32
`mt_*()` calls), **deleting `tm.h` from the four headers today would un-define
the CONVERTED macros too** -- and the ones on `#if` lines would then silently
evaluate FALSE. Severing `defaults.h` from `tm.h` therefore BLOCKS the whole
removal. See `scratchpad/T141-TMH-REMOVAL-PLAN.md`.

**Those four headers are the whole transitive channel** — `i386.cc` and
`aarch64.cc` spell no `tm.h` at all and reach it through them. They are why
`tm.h` reaches ~520 of 622 TUs, and being shared they cannot name a base, so
for them the only move is deletion.

**Note for upstreaming: upstream also finds `tm.h` via `-I`**, since it is
generated into the build dir — but upstream has **one candidate**, so `-I` is
finding a file, not choosing between bases. Using `-I` to *select* is this
branch's invention, and removing it removes a divergence rather than adding
one. (`gcc/config/` and `libgcc/config/` are separate trees with the same
directory names and entirely different contents; all of the above is `gcc/`.)

**The landed form** is `gcc/multi-target-base.h`, with `-DMT_BASE=<cpu>-inc`
per object and **the call site taking a bare, unquoted argument**:

```c
#define MT_HDR_STR(f) #f
#define MT_HDR_XSTR(f) MT_HDR_STR (f)
#define BASE_HEADER(f) MT_HDR_XSTR (MT_BASE/f)  /* -DMT_BASE=<cpu>-inc */
#include BASE_HEADER (tm.h)                     /* "i386-inc/tm.h" */
```

**It yields the QUOTED include, not the angle-bracket one**, per the user:
*"I like the version that results in `"..."` not `<...>` better."* An earlier
form was plain substitution into `<MT_BASE/f>`; that also worked, and this
file recorded it as the landed shape. Only the expansion changed — the call
sites still read `BASE_HEADER (tm.h)`, argument unquoted.

**The double indirection is mandatory.** `MT_HDR_STR`'s parameter is adjacent
to `#`, so its argument is **not** macro-expanded; `MT_HDR_XSTR` exists solely
to force one expansion first. Without it you get `"MT_BASE/tm.h"` — a
*plausible-looking wrong path*, which is the exact silent-failure shape this
whole change removes. Measured: the witness catches its removal too, with
`fatal error: MT_BASE/mt-inc-tag-i386.h`. `t140-inject.sh` **ARM 6** reads the
expansion and carries its own negative control.

Two consequences of `"..."` over `<...>`, both **checked, not assumed**:
`"..."` searches the including file's own directory first (**zero** directories
named `*-inc` anywhere in the source tree, so nothing can shadow), and the
twenty `.deps` entries for these objects are **byte-identical** before and
after.

One `-D` serves every header. Everything else was measured and fails:

```
#include BASE "/tm.h"                 warning only, silently drops "/tm.h"
#define H(f) BASE ## "/" ## f         error: pasting "BASE" and ""/"" ...
#define H(f) CAT(<,BASE/f>)           error: pasting "<" and "i386" ...
#include <MT_BASE/tm.h>               no expansion in the literal <> form
#include H("tm.h")   (quoted arg)     i386-inc/"tm.h": No such file
```

**`##` cannot express this, for two independent reasons**: its operands are
**not macro-expanded** (the error says pasting `"BASE"`, not `"i386-inc"`), and
it must yield **one** valid preprocessing token, which a path is not. And
`#include` does not concatenate adjacent string literals — it takes the first
and **warns** about the rest, which is the dangerous outcome.

**The `-D` is `MT_BASE`, not `BASE`: `BASE` collides** — a template parameter
in `aarch64-sve-builtins-shapes.cc:1154` and a macro parameter in two more
files. `-DBASE=aarch64-inc` fails with `error: expected nested-name-specifier
before 'aarch64'`, **naming neither the flag nor the file**.

**BASE_HEADER ALONE DOES NOT CLOSE THE HOLE, and the reason is a lesson about
testing.** Transitive includes (`rtl.h` → `insn-modes.h`) are still resolved by
`-I`, so `-DMT_BASE` and `-I<base>-inc` become **two authorities for one
fact** — this branch's own root bug. A generated **witness pair** makes them
check each other: `<base>-inc/mt-inc-witness.h`, reachable *only* through the
`-I`, containing `#include BASE_HEADER (mt-inc-tag-<base>.h)`.

**A TEST IN A REDUCED ENVIRONMENT CAN PASS FOR A REASON THE REAL ENVIRONMENT
REMOVES.** The coordinator "measured" that a wrong base fails by name — in a
toy directory containing **only** `i386-inc`. In a real two-base build
`aarch64-inc/tm.h` **exists**, so a wrong `MT_BASE` silently compiles the wrong
headers. The reassuring result was produced by the *absence* of the other
directory, which is exactly what the real build supplies. Build the minimal
case, then ask what the real environment adds back.

## 2. The user's standing rulings

These are settled. Do not relitigate them; do apply them to whatever you are
handed.

- **No single target, ever.** Not a primary, not a default, not a fallback.
  There is no single-target mode to fall back to.
- **`gcc/configure.ac` is about host and build only — never target.** It was cut
  from 7,982 lines to ~3,449 on that principle.
- **Every `--with`/`--enable` is about the host (or rarely build), never the
  target.** Hence `--enable-host-shared` → `--enable-shared` and
  `--enable-targets` → `--enable-backends` (it selects which back ends go *into
  the binary* — a property of the artefact, i.e. host-side).
- **The top level is the only component that legitimately deals in targets**,
  because it is the dispatcher: it takes **targets, plural**, maps triples →
  back ends, and instantiates per-target trees. Everything below it gets
  `--host` or a back-end list. This is the stated exception to "avoid
  `--target`", not a violation of it.
- **Runtime libraries are single-host.** Plurality lives at the top level; one
  host per runtime tree; no target at all inside `gcc/`.
- **`libgcc`, `target-specs` are `target_module`s**, one instance per configured
  target, configured with `--host=<target>`.
- **`crt` belongs to libgcc, not gcc** — it is runtime and must not be built with
  gcc's configuration.
- **Multilib is mandatory everywhere.** Both `--enable-multilib` and
  `--disable-multilib` were deleted. Multilib *nests inside* per-target
  instantiation; it is an asset, not an obstacle.
- **`target-specs` runs AFTER gcc is built**, as its own configure the user
  invokes. gcc must not generate specs as a build-time prerequisite.
- **Do not rename libgcc symbols; do not let PSIs clobber each other.** Namespace
  rather than rename.

**There is a category of POST-INSTALL, PER-TARGET ENVIRONMENT ADAPTATION**, and
several open problems are one problem once you see it. The user's framing:
*"fixincludes sounds like target-specs — something that might be run post
install, once we are at the final deployed machine, to fix up the headers."*

- `target-specs` probes the actual `as`/`ld` for a target.
- `fixincludes` patches the actual system headers for a target.
- collect2's tool paths (`MD_EXEC_PREFIX`, `REAL_*_FILE_NAME`) are which tools
  exist for a target.
- cppdefault's system header directory is where a target's headers are.

All four are facts about **the deployed machine**, per target. Baking any of
them at gcc build time is wrong for the same reason: **the build machine is not
the deployment machine**, and a compiler serving N targets has no single answer
to bake anyway. They belong in the per-target directory
(`$(libdir)/gcc/$(version)/<target>/`), written by something the user runs after
installing, and read at run time.

**Test for this category:** if the answer could change without rebuilding the
compiler — a new binutils, a different sysroot, headers fixed in place — it is
post-install adaptation, not build configuration.

**AND THE COROLLARY, WHICH IS THE USER'S RULING AND IS STANDING LAW: ambient
adaptation is right for builds and deployments and WRONG FOR UNIT TESTS.**
`target-specs` exists to match whatever assembler and linker happen to sit
beside an installed compiler. That is correct, and it must stay. But a
`scan-assembler` test asserts *fixed text*, so if the capability set behind it
is **probed**, the same test on two machines with different binutils gives
different answers — and a result that varies with the box is not a regression
test. Today, every `scan-assembler` number this project has quoted is a
statement about **this machine**.

So a test run must **pin** the configuration: a declared, checked-in capability
set per target, with the probes not run at all. Consequences, all of which cut
in our favour:

- **No assembler is needed to score `scan-assembler` tests**, because nothing
  is being probed. The "17 of 47 scorable" ceiling is an artefact of the
  harness, not a property of the tests. `powerpc` alone has ~1379
  `scan-assembler` tests and is currently unscorable.
- The guard refusing the host `as` **stays exactly as it is**, because a pinned
  run is a *different mode*, not a fallback inside the probing one. That
  distinction has to be structural — a conservative-default branch inside the
  prober would be the same silent-wrong-answer with better manners.
- A pinned set must come from a **real probe against a real assembler, captured
  once and committed** — never invented. A file saying `as_tls=0` because
  nobody asked, sitting beside one saying `as_tls=0` because an assembler
  answered, is this project's most expensive recurring failure wearing a
  config file.
- A pinned run's numbers must be **marked**, so they can never be compared
  like-for-like with a probed run without someone noticing.

Eventually the same question arrives for binutils itself — a multi-target `as`
and `ld` — at which point "which assembler" stops being ambient at all.

**HOOK vs CAPABILITY — the other half of that test.** Not every per-target fact
belongs in `target-specs`. The user's rule: *"hooks can be used for static
defaults that vary per target."*

- **A target hook (`targetm.*`)** is for a **static** per-target answer that is
  part of the compiler itself — it ships with the back end, cannot change
  without rebuilding, and the back end is the authority. Example: which
  exception model a target uses by default. `arm_except_unwind_info` already
  computes it from target state; that is a hook doing its job.
- **A `target-specs` capability** is for a fact about the **deployed
  environment** for that target — probed, and able to change without rebuilding
  the compiler. Example: whether this machine's `as` supports `.hidden`.

**Ask: could this differ between two installations of the same compiler serving
the same target?** If yes → capability. If no → hook. Getting this wrong is not
harmless: a static fact routed through the probe channel becomes something an
operator can get wrong, and a probed fact frozen into a hook becomes a lie the
moment the toolchain changes.

**`gcc/configure.ac` is the forcing function.** The user's words: *"I bring up
gcc/configure.ac a lot because I think it is a good forcing function."* If that
file is host-and-build only, then every target fact has had to move somewhere
legitimate — a per-target config, a runtime read, the top level. Shrinking it is
not cosmetic bookkeeping; it is how you find out what is still wrong. It went
7,982 → ~3,500 lines, `gcc_GAS_CHECK_FEATURE` 51 → 0, `case $target` 15 → 1.

Concretely, the first systematic audit of its remaining `--with-*` (only done
because the question kept being asked) found two target-side flags nobody had
noticed: `--with-build-sysroot`, which sets `SYSROOT_CFLAGS_FOR_TARGET`, and
`--with-fixincludes-machine`, a *machine name*. Both had survived every earlier
pass. **When in doubt about whether something is done, ask what is still in
`gcc/configure.ac` and why.**

**Why "no primary" is the strategy, in the user's words: eradicating it
"should force us to fix bugs."** Today every leak has a plausible fallback —
the primary's answer — so wrong code runs silently. With no primary there is no
valid answer to fall back on, so the same code must fail at build time. It is
`#ifdef X` → `if (X)` applied to the whole build system.

## 2a. Changes that LOOK like fixes and actually undo this project

Read this list before you make anything red turn green. Every item is a real
temptation that presents itself as an obvious small fix, and every one of them
destroys the work rather than advancing it. **If your fix is on this list, you
have found a design question, not a bug. Stop and report.**

- **Reintroducing a primary, a default, or a fallback target** — including
  "just for the native case", "just so a bare `gcc` works", or an install rule
  that bakes one target into `gcc/`. A default target is a primary by another
  name. A bare `gcc` failing by name when no target is selected is **correct
  behaviour**, not a bug to fix.
- **Un-unioning a vocabulary** to make a divergence go away. The unions are
  load-bearing: the mode union is the only thing stopping `SImode` meaning 18 to
  one back end and 17 to another. If a union causes a problem (see
  `HAVE_V8HFmode`), the fix is downstream of the union, not a retreat from it.
- **Adding an `#ifndef` floor / a default value / a "sensible fallback"** so a
  missing answer stops erroring. The fallback is always the primary's answer,
  which is the bug. Never let the absence of an answer be an answer.

  **THE DISTINCTION THIS RULE ACTUALLY TURNS ON — and one agent got it right
  and flagged it rather than burying it.** What is banned is a floor that
  yields **the primary's** answer to a base that never said anything. A floor
  on the **supply** side, giving a base *upstream's own documented value for a
  back end that genuinely does not define the macro*, is a **real per-base
  answer** and is fine.

  Worked example, `JUMP_TABLES_IN_TEXT_SECTION`: **40 of 48 back ends define
  it**; the consumer side is already
  `#define … (targetm_cdata.jump_tables_in_text_section)`, so `final.cc:101`'s
  `#ifndef` is **dead**; and the added floor supplies upstream's own `0` to the
  8 back ends that say nothing. No base ever reads another's value.

  **The test:** ask *whose* answer the fallback is. If a second configured back
  end would change it, it is the primary's and it is banned. If it is the same
  value upstream would give that back end standing alone, it is that back end's
  own answer. **State which, in the commit, whenever you add one.**

  **AN `#ifndef` IN A SHARED TU IS NEVER TAKEN IF THE PRIMARY DEFINES THE NAME,
  SO "IT HAS A FALLBACK" IS NOT EVIDENCE THE FALLBACK RUNS.** #176 cost 509 ICEs
  on this. `regs.h:30` guards `REGMODE_NATURAL_SIZE` with `#ifndef`, but
  `i386.h:1112` defines it first, so **all eight shared consumers called
  `ix86_regmode_natural_size`** — aarch64 answers `BYTES_PER_SVE_VECTOR` for
  variable-width SVE modes, i386 answers `UNITS_PER_WORD`, and
  `gen_lowpart_common` divided by the wrong granularity and returned 0.

  **Worse, `multi-target-macros.h` ALREADY LISTED THAT NAME AS CONVERTED** —
  through a `UNITS_PER_WORD` closure at `regs.h:31`. The entry was true for a
  back end that defines nothing and **dead for the four that define it**. So a
  name's presence on the converted list is not evidence either. When checking
  any conversion, ask **what the primary's `tm.h` expands the macro to**, not
  whether a fallback exists and not whether the list names it. Both answer a
  different question than the one that matters.
- **Deleting, relaxing, or narrowing a check that fails.** The check is usually
  the only thing standing between a silent wrong answer and a diagnostic. If
  `--enable-backends=all` reports "45 options blocks for 48 back ends", three
  back ends are unexplained — that is the check working.
- **Editing a probe, retiring an arm, or adjusting an expected value** so the
  scoreboard improves. This is the test-harness floor and it has been refused
  four times, including the subtle form: changing a macro's value so the
  *tautological* i386 column flips red, whose obvious next move is editing the
  probe list.
- **Converting a runtime read back to a compile-time macro** because it is
  simpler. The whole project is the other direction.
- **"Fixing" the top level by removing its target handling.** The top level is
  the dispatcher; targets there are the design.
- **Making a diagnostic disappear without establishing what it was reporting.**
  An unterminated quote, a redundant `@`, a `test: =:` error — on this project
  each has twice meant something was silently truncated with exit 0.
- **Reverting a per-base object, header, or namespace to a shared one** because
  the shared one builds. It builds because it is answering for everyone.

The general form: **if your change makes a measurement stop objecting without
changing the thing it was objecting to, you have deleted evidence.**

## 2b. A debugging-shaped task can contain a design decision

This is the failure that produced the `default-target` mistake, and it is worth
naming because it is invisible from inside the task.

"Write the install rule so a plain `gcc` works" reads as debugging: a symptom, a
missing file, an obvious fix. It was actually a decision about **whether `gcc/`
may know a target at all** — settled policy, contradicted by the obvious fix.

**Test:** if completing the task requires you to *invent* where something lives,
who owns it, or what the default is, it is design, not debugging. Ordinary
debugging changes code so it does what it already intended. Design decides what
it should intend.

When you hit one: say so and report the options with costs. Do not resolve it by
picking whichever makes the build succeed.

## 3. The bug we are hunting, in all its disguises

**One name, several authorities, no diagnostic.** It links cleanly and means
different things. Instances found so far:

| disguise | example |
|---|---|
| shared numbering | `SImode` = 18 for i386, 17 for aarch64 |
| shared numbering | `UNSPECV_BLOCKAGE` = 1 vs 5; `N_REG_CLASSES` 34 vs 20 |
| kind mismatch | `internal_dfa_insn_code`: function vs function *pointer* |
| identity by address | `CUMULATIVE_ARGS_MAGIC` = `&targetm.calls`, broken by copying |
| mutation discarded | 12 back-end writes through `targetm` lost to a copy |
| COMDAT body | `optab_handler` — linker keeps one of three bodies, by link order |
| unsupplied hook | `TARGET_LIBCALL_VALUE` — every target got i386's registers |
| sized by one, written by another | `cl_optimization` — an 8-byte **overflow** |
| bound by one, indexed by another | `NUM_UNSPECV_VALUES` 114 vs a 40-entry table |
| guard hiding a *declaration* | `rs6000_gnu_attr`; `<ldfcn.h>` in collect2 |
| **the union's answer leaking** | `HAVE_V8HFmode` — "exists somewhere" ≠ "exists here" |
| **a MAKE variable with one authority** | `PASSES_EXTRA` — fed only by `-include $(tmake_file)`, which is the legacy single `${target}`'s fragments, so `pass-instances.def` held i386's three target passes and **not one** from the other seven configured back ends |
| **a SHARED header keyed on a per-base macro, in a TU that never reads `tm.h`** | `TARGET_SUPPORTS_WIDE_INT` — `rtl.h`'s `CASE_CONST_UNIQUE` reads it, `rtl.cc` includes no `tm.h`, so `#if` on an *undefined* name read 0 while 260 other shared objects read i386's 1; `CONST_POLY_INT` dropped out of the switch, its rtl format is the **empty string**, and `rtx_equal_p` therefore compared **no operands** and returned true |

**THE `TARGET_SUPPORTS_WIDE_INT` INSTANCE IS THE `#if` TRAP AND THE
"ONE NAME, SEVERAL AUTHORITIES" BUG AT THE SAME TIME, AND IT WAS INVISIBLE TO
EVERY EXISTING ARM.** §4 already records that `#if FOO` on an undefined `FOO`
silently evaluates false; this is that trap in a **shared** header, where the
consequence is not "a file changed behaviour" but "two translation units in one
binary disagree about what an `rtx` *is*". Measured (`06179fbe3df`, 47 bases):

```
rtx_equal_p ((const_poly_int:DI [8, 8]), (const_poly_int:DI [48, 8])) = 1
```

`try_split`'s infinite-loop guard then discarded **every** split of aarch64's
`*add<mode>3_poly_1` — the split RAN and produced correct code, which was
thrown away — and the insn ICEd in `final.cc:2846`. Worth **4,024 + 176**
results in two directories where stock fails zero.

Three transferable pieces:

- **The leak can be DOWNSTREAM of the thing it breaks.** Six suspects were
  eliminated first — the wrong base's `split_insns`, a `split5` gate reading
  `targetm.stack_regs ()`, `epilogue_completed`, the split predicate,
  `reg_overlap_mentioned_p`, an empty sequence — and each elimination was
  correct. The defect was in a *shared consumer of the split's output*. When
  every part of a mechanism measures right and the mechanism still fails, stop
  testing the mechanism and read what happens to its result.
- **A per-base macro that a shared HEADER reads is a different population from
  one a shared TU reads**, and `git grep` scores neither. Score it from the
  build's own `.deps`: *which objects include the header AND reach `tm.h`*.
  Here 260 do and **11 do not** — `rtl`, `print-rtl`, `rtlhash`, `read-rtl`,
  `real`, `rtl-error`, `lists`, `rtx-vector-builder`, `print-tree`,
  `function-tests`, `gcc-rich-location`, i.e. comparison, hashing and dumping
  of `rtx`.
- **A comment recording a measured removal is evidence about what was
  measured, not about what was safe.** `rtl.cc`'s comment reasons carefully and
  correctly about `hard-reg-set.h`'s register widths, and `rtl.h` was never in
  scope. Same family as the `sweep.sh` citation: the comment reads as though
  the question had been asked.

**THE `PASSES_EXTRA` INSTANCE IS WORTH READING BECAUSE IT WAS IN A CHANNEL
NOTHING HAD LISTED, AND IT SHOWED BOTH HALVES AT ONCE.** Leaked PRESENCE:
shared `passes.cc` walks the list unconditionally, so `-fdump-passes` while
compiling for **aarch64** reported `rtl-x86_cse : ON` — i386's pass gated on
and running for another target. Leaked ABSENCE: aarch64's eight passes were
not in the tree at all, so BTI insertion, `ldp_fusion` and early-ra had never
run on this branch. Fixed in `b349257c0a2` by deriving the list from the
back-end list, tagging each file with its owner, renaming the inserted pass
`<pass>_mt_<base>` and gating on `multi_target_current_base ()`.

Three transferable pieces:

- **Ask which variable a `@substitution@` came from, not what it is named
  after.** `tmake_file`, `extra_objs`, `c_target_objs`, `target_gtfiles` and
  `out_file` are all `${target}`-shaped and all had this bug. When you meet a
  make variable fed by `config.gcc`, the question is whether it was collected
  once or per back end.
- **`-fdump-passes` distinguishes ABSENT from OFF, and a generated file cannot.**
  Before the fix, aarch64's passes did not appear in that dump at all; reading
  their absence as "off" would have been the wrong conclusion from the same
  silence. Prefer an instrument that reads the running compiler.
- **An ordering trap between a rename and a shared consumer can be dissolved
  rather than traded.** `make_pass_insert_bti` was in `MULTI_TARGET_RENAME_NAMES`
  justified by "nothing shared names it", true only while the pass was absent.
  Rather than revoking the rename, shared code was made to call a per-base
  **forwarder** compiled inside that base's own TU, so the renamed name is
  spelled only where the `-D` reaches. The rename list needed no edit. Reach
  for this shape whenever shared code appears to need a renamed symbol.

Note the last one runs **opposite** to the others: normally the primary's answer
leaks to everyone; there the union's does. Same root — one authority answering
for many.

**AND A FOURTH PIECE, PAID FOR BY READING THE THREE ABOVE AS A TEMPLATE AND
STILL GETTING IT HALF RIGHT (#189).** `EXTRA_HEADERS` has **two** authorities,
not one, and they are *different kinds of thing*:

```
config.gcc      extra_headers=...      -> @extra_headers_list@ -> EXTRA_HEADERS
tmake fragments EXTRA_HEADERS += ...   -> -include $(tmake_file)
```

The second is the **identical channel** `PASSES_EXTRA` travels on. An agent
holding `b349257c0a2` as its template fixed the `config.gcc` side, measured a
census of 180 headers over 14 back ends from `config.gcc` alone, called it
complete — and the build stopped on `mm_malloc.h`, which no `config.gcc` line
mentions and `config/i386/t-pmm_malloc` appends. The census was an undercount
by construction and said nothing about it.

So, for any per-back-end make variable: **enumerate BOTH channels before
claiming a population.** Ask `git grep -n '<VAR>' gcc/config/` as well as
`grep '<var>=' config.gcc`. Nine fragments over eight back ends feed
`EXTRA_HEADERS`, and two of them (`avr/t-avr`, `frv/t-frv`) use `=` rather than
`+=`, i.e. they *clobber* — a form a `+=`-shaped scan skips silently.

**Fixing one channel is a partial fix BY CONSTRUCTION, and it presents as a
complete one**, because the half you did fix is real, measurable and
demonstrably works. The only reason this was caught before shipping is that the
fix kept the legacy channel alive as a cross-check instead of deleting it —
which is the *first* transferable piece above, doing exactly the job it was
written for, against its own author.

Corollary worth stating because it recurs: **a prior agent's "I deliberately
left this alone" comment may be answerable now.** `config/rs6000/t-rs6000-headers`
declines to move `EXTRA_HEADERS += rs6000-vecdefines.h`, reasoning that it
"would make a build that merely configures rs6000 install a powerpc header".
That was correct **against one flat `include/`** and is **dissolved** by the
per-back-end directory: `include-rs6000/` is reached only when rs6000 is the
base in force, so installing it is no longer a claim about anyone else's
target. When you meet a recorded refusal, check whether the thing it was
refusing has changed underneath it — and say which, since the comment stays in
the tree.

**The design rule that fixes it:** union the vocabulary, keep the data per
configuration, select at run time, qualify only what actually collides. Landed
eight times. Reuse the union-list mechanism (`#`-prefixed setting lines, hard
failure by name when a base is missing); do not invent a second one.

## 4. Method — this project has produced 26+ false greens

**Never let the absence of an answer be an answer.** No `#ifndef` floors. A
missing value must fail *by name*. The natural fallback is always the primary's
answer, which is the bug.

**A CHECK THAT CANNOT SAY *WHICH* THING DISAGREES IS MOST OF A CHECK.** From
the `target_rtl` layout witness, whose own comment states it: *"Named
individually rather than summed: a check that cannot say WHICH structure
disagrees is most of a check."* A summed comparison would have caught the same
bug and told nobody where to look. Seven structs are compared **one at a
time**, and the diagnostic names the back end, the struct and both sizes:

```
back end 'i386' computes 'sizeof (struct target_rtl)' as 5968, but
target-independent code allocates 6184; a bound in its header is not
spelled MULTI_TARGET_UNION_*
```

It then fired **unprompted** on a second struct nobody had asked about, which
is what a check of this shape buys. Prefer N named comparisons to one
aggregate, and make the message say what to do next.

**Verification must be able to fail.** Inject a deliberate `#error`; require the
build to FAIL naming it. **An injection that does not fire is a finding** — one
revealed four sites inside a dead `#if TARGET_XCOFF`; another revealed a
936-byte empty `collect2-aix.o` silently built for weeks.

**"IT STILL COMPILES" IS NOT SUFFICIENT EVIDENCE THAT AN INCLUDE IS UNUSED.**
`#if FOO` on an **undefined** `FOO` does not error — it silently evaluates to
**false**. So a file that uses a `tm.h` macro *only inside a conditional*
compiles cleanly with the include removed, scores "vestigial", and has its
behaviour changed with **no diagnostic**. Three of twenty-nine candidates were
exactly that shape (`i386-jit.cc` on `#if TARGET_64BIT_DEFAULT`,
`mingw/msformat-c.cc` on `#ifdef TARGET_OVERRIDES_FORMAT_INIT`,
`avr/avr-devices.cc`).

**And the instrument written to catch that missed one of them.** It derived
`tm.h`'s macro set by `-dM` difference — rigorous, 12,689 names, and *i386
-linux's* 12,689 names. `TARGET_OVERRIDES_FORMAT_INIT` lives in
`config/mingw/mingw32.h` and was invisible to it. The version that works asks
whether the identifier is `#define`d **anywhere under `config/`** —
deliberately over-broad, because it can only *revoke* a deletion, never
authorise one. **When an instrument can only take away, make it too eager;
when it can grant, make it exact.**

**A GUARD SCRIPT CAN BUILD SOMEBODY ELSE'S TREE AND REPORT A CLEAN GREEN.**
Twenty-three `tNNN-build.sh` scripts had `SRC=` hardcoded to **another agent's
worktree**. They configure, build and pass — against a compiler that is not
the one under test. Measured by content anchor: this worktree has **39**
`MULTI_TARGET` hits in `gcc/Makefile.in`; the trees those scripts pointed at
had **27, 28 or 39**. A script pointing at a 28 builds a compiler **missing
eleven landed changes** and reports success, with no diagnostic anywhere.

Two lessons, and the second is the sharper one:
- **Every harness must assert which tree it is measuring**, by content anchor,
  not by assuming its own `$0` location.
- **A loud break can mask a silent one.** These scripts were *also* broken by
  the `--enable-targets` flag day, which is what got them looked at. Fixing
  only the loud defect would have left every "repaired" script measuring the
  wrong compiler — and would have looked like a completed repair. When you fix
  a noisy failure in something that was not being watched, **audit the thing
  mechanically rather than by eye** before declaring it healthy.

**AND THE FOLLOW-UP CORRECTED THE PARAGRAPH ABOVE — READ BOTH.** The trees
those scripts pointed at measure **23, 27, 28 or 39** (the paragraph above
says 27/28/39; `eb-*` pointed at a **23**, the stalest, and it was missed).
More importantly the framing "**another** agent's worktree" is wrong about
*authoring time* and right only about *inheritance*. Measured: for all 22
`FOREIGN-SRC` scripts, the worktree in `SRC=` is **the worktree of the agent
who wrote that script**. Each author hardcoded its OWN absolute path; the line
was correct when written and when run, and became foreign only when the file
was committed and inherited by the next worktree. Across ~50 worktrees, **506**
scripts carry a hardcoded `SRC=`: **21** name their own tree, **485** name
someone else's. So the exposure was real and large — **and never fired.**

**The distinction matters because it decides whether past greens survive**, and
you cannot settle it from the scripts. Settle it from **the builds' own
testimony**: each build dir's `config.log` records the absolute srcdir
`configure` ran from. That instrument is independent of the scripts by
construction and survives them being repaired afterwards. 96 read: **every
build dir was configured from the tree of the agent that owned that task, at
that task's own timestamp, with the anchor monotonic in time (23→27→28→30→37→
39)**. A fired defect would show as an owner mismatch or an anchor going
backwards against the clock; neither appears. `scratchpad/built-tree-audit.sh`.

**THE ANCHOR VALUE IS 49 as of `b2b5b42b128`** — it went DOWN, because
deleting `-I<base>-inc` removed comment blocks naming `MULTI_TARGET_INC`. A
monotonic assumption about this number is wrong in both directions. Run the
grep.

**It was 55**, measured at the forty-seven-back-end merge — not
51 and not 54, which are what the two sides of that merge each believed.
Seventh value: 45 → 47 → 48 → 50 → 51 → 52 → 54 → 55. Set `WANT_ANCHOR=55`.

That two concurrent branches each bumped this line to a different number, and
the merged tree matched neither, is the clearest possible statement of why the
assert is exact: **the value is a property of the tree, not of anybody's
belief about it.** Run `grep -c MULTI_TARGET gcc/Makefile.in` on the tree you
are about to build and use what it says. Do not copy a number out of a brief,
including this one — check it.

Everything the paragraphs below say about *why* the assert stays exact still
holds; only the number moved, which is the point they make.

**AND THE LAST THREE MOVES CAME FROM COMMENT PROSE, NOT FROM MECHANISM.**
50 → 52 → 54 is four `MULTI_TARGET_*` names appearing inside explanatory
comment blocks in `gcc/Makefile.in`. That is worth saying out loud because it predicts the shape
of the next false alarm: an agent diffing the anchor against the *rules* will
find nothing changed and conclude a script is broken. The anchor is a content
hash of one file, deliberately including its comments — which is what makes it
catch a stale tree at all. Do not "fix" it by narrowing the grep to rule lines;
that would make it blind to exactly the tree-staleness it exists to detect.

**THE ANCHOR VALUE WAS 50 as of `89883e54f02`** (the eleven-back-end merge).

**The anchor value was 48 as of the `add_clobbers` selector (task #150)**, which
added the `build/genemit.o : BUILD_CPPFLAGS += -DGEN_MULTI_TARGET` rule and its
comment. It was 47 before that, and the paragraph below — written when 47 was
new — is kept verbatim because its argument is the durable part and its number
is not. **This is the third value this line has had. Do not treat the next
change as a defect in the scripts.**

**The anchor value was 47 as of `1518ec4f96f`, not 45.** The `target_*` struct
sweep added a `DEPFILES` rule naming `MULTI_TARGET_REG_PROBES` twice. Every
`*-conf.sh` written before that merge asserts `WANT_ANCHOR:-45` *exactly*, so
they now refuse a **correct** tree with rc=9. That is the intended direction —
an exact assert fails loudly rather than silently measuring the wrong tree —
but it means a new task must set `WANT_ANCHOR=47` or write a fresh conf script.
Do not relax the assert to `>=`: the whole point is that a tree missing the
change fails here rather than reporting a green for a compiler that is not this
one. Expect this line to need updating again; the number is not the invariant,
the exactness is.

**"ASSEMBLES, RIGHT ELF MACHINE" IS NOT ENOUGH — riscv64 PASSED IT WHILE
EMITTING 32-BIT CODE.** The acceptance bar this project used to promote
aarch64 from "emits assembly" to "works" was: a real cross assembler accepts
the output and `readelf -h` reports the right machine. Measured at eleven
bases, riscv passes that bar on code that is wrong in the worst way:

```
long mt_shift (long, int)      ->  sw   (32-bit store of the return address)
                                   .cfi_offset 1, -4
                                   sll / srai on a 64-bit long
                                   no `sd' or `ld' anywhere
```

In an **ELF64** object. Word size 4. Both-sided: aarch64 and s390 are correct
64-bit on the identical function. Root cause is the `ix86_pmode Init (PMODE_SI)`
shape — **the primary's unconfigured default reaching a base that never set
it** — the same defect class as `Pmode` in #124, and the same root as riscv's
empty `.attribute arch, ""`.

The consequence is general: **fix the one directive the assembler rejects and
the file assembles into a well-formed object `readelf` is happy with.** So the
bar must include a *semantic* arm — word size, ABI, register widths — not only
"a tool accepted it". Any back end promoted under the old bar needs
re-checking.

Corollary for this project's habit of trusting tools: an assembler validates
*syntax for a machine*, not *that the compiler meant that machine*. The token
arm (does aarch64's output contain x86 register names) is a real check and it
passed — 40 hits on x86_64's own output, 0 on aarch64's and s390's — but it
cannot see a target compiled at the wrong width, because every instruction it
emits is genuinely a valid instruction of that architecture.

**`-I<base>-inc` IS GONE (#174), AND WHAT IT COST IS THE TRANSFERABLE PART.**
`-DMT_BASE` is now the only thing that says which back end an object's headers
come from; `git grep -- '-I.*-inc\>' ':(exclude)scratchpad'` is **0**. The
shape is `MT_HEADER (f)` from `gcc/multi-target-header.h` for a header serving
both populations, `BASE_HEADER (f)` for a source compiled only per back end.

Removal was silent, not loud: 15 of 16 stems also exist under their plain name
in the build root, and for seven that copy is byte-identical to i386's.

**THE SITE COUNT WAS 17 AND IT WAS 30, AND THE MISSING THIRTEEN WERE MISSING
FOR TWO DIFFERENT REASONS — BOTH WORTH GENERALISING.**

- Four `tm.h` and ten `options.h` sites in shared headers were **counted under
  a different acceptance grep** and so were absent from a census that believed
  itself complete. `target.h:57`'s plain `"tm.h"` cost 243 diagnostics in
  `mt-arm/arm-c.o`. *When you enumerate a population by stem, enumerate every
  stem, not the ones your task is named after.*
- Four families of **generated** per-base sources (`options-init.cc`,
  `options-tables.cc`, `insn-modes-<cpu>.cc`, `rs6000-builtins.cc`) are not in
  the source tree, so `git grep` over `gcc/` cannot see them. Enumerated from
  the build dir instead. *Rule 1 of §4 again: grep the generated artefact.*
  `genmodes.cc`'s own comment had predicted this exact bug and nobody had
  acted on it.

**AND THE THIRD DEFECT WAS VISIBLE ONLY TO THE DEPS-DIFF.**
`mt-<cpu>/options-{init,tables}.o` set `MULTI_TARGET_INC` and **never
`MULTI_TARGET_BASE_DEF`** — they reached their base entirely through the
include path. Both arms compiled clean; 94 objects silently swapped
`<cpu>-inc/insn-modes.h` for the build root's. **No build could have seen it**,
which is the whole reason "it builds" was refused as the bar. Final:
per-back-end headers LOST **0**, added **0**, over the 2000 objects both
47-back-end builds produced.

**A TARGET-SPECIFIC VARIABLE ASSIGNMENT DOES NOT MAKE A TARGET OUT OF DATE.**
Adding `MULTI_TARGET_BASE_DEF` left 46 of 47 objects unrebuilt, and the
deps-diff still reported the loss on stale `.Po` files. Delete the objects by
hand after any fix that only changes a compile flag.

The witness moved with the `-I`: `mt-inc-witness.h` was findable only through
it. `multi-target-base.h` now builds the directory from `MT_BASE` and the file
name from `MULTI_TARGET_TARGETM_BASE`, so the two flags check each other, and
it was verified **in the real 47-base build dir** — `aarch64-inc/mt-inc-tag-i386.h:
No such file`, with a passing negative control. It is silent for the 51 objects
carrying `MT_BASE` alone; deriving a second flag from the same make rule would
be a mitigation that cannot fire.

Two older cautions, both caught only by a 47-back-end build, still hold: a back
end's `.h` may not name a base **unconditionally** (the shared `tm.h` includes
`config/i386/i386.h`, so ~520 shared TUs read it — `MT_HEADER` is what made
those three convertible); and 8 bad include orders once amplified into 251
diagnostics from one cause.

**A MISSING TOOL LOOKS EXACTLY LIKE A ZERO RESULT.** The coordinator
"refuted" an agent's evidence with `strings foo.o | grep -c 'include-'` → 0
and called it definitive. `strings` **is not installed here**; the 0 was
`command not found` piped into `grep -c`. The agent was right and the
refutation was the false green — inside an investigation of a false green.

Two habits that would have caught it: **run a negative control on the
instrument itself** (a pattern that must NOT match — if it also reads 0 with
no error, the tool ran; if the command is missing you see it immediately), and
**prefer tools you have already used in this session**. `grep -a` on the object
gave the answer in one line, with the control returning 0 as it should.

Generalise: `command not found`, an empty file, a truncated log and a genuine
zero are the same output through a counting pipe. Anything shaped
`cmd | grep -c` needs `cmd` to have demonstrably run.

**A GUARD THAT REPORTS PROTECTING NOTHING IS A STOP, NOT A GREEN.** Cleaning
207 stale `/tmp` build dirs, the coordinator wrote a keep-list for the four
live agents' directories. It printed `removed=207 kept_live=0` — and the delete
ran anyway. Zero protected while four agents were mid-build is not a pass; it
is the guard reporting that it matched nothing. (The ids were truncated in the
directory names, so the substring test found none of them.)

Destructive operations need the inverse acceptance test: **assert the expected
number of protected items BEFORE deleting, and abort if it is zero.** Same
shape as every other false green here — "everything is fine" and "the
instrument did not run" produce the same output.

**CURRENT BARS — `7375c86aa4c`, anchor 49, two bases, cold from an immutable
snapshot.** `specs-config` MOVED and it is not a regression:

```
make all-gcc                MAKERC=0, 0 error:, cc1 links
cc1 -quiet -nostdinc -O2 -ftarget-config=<cfg> big.c -o x.s
  x86_64                    12369 bytes  md5 378fc33c1e70   (unchanged)
specs-config  wc -l         232                            x86_64, aarch64
  was 230 before #189
```

**THE `specs-config` md5 IS NOT A BAR. DO NOT QUOTE IT AS ONE.** It is a
function of **the probing toolchain's paths** — the build dir and the tools dir
land inside the file — so two correct builds of the same tree give different
md5s, and an agent checking against a recorded one **scores a correct build as
a failed bar**. Measured: `ce3e57e29397` and `cfbc7a65e54e` are both correct,
from different build dirs. **The line count is the stable part**; if you want a
content check, normalise the paths out first, and say in the same breath which
build dir and tools dir produced it.

This entry previously listed `cfbc7a65e54e` / `575aff0c188b` as bars, and every
brief that copied them has been handing agents a check that fires on success.
The same is true of `mt-bars.sh`'s `-g` md5, for the same reason in a different
place: the build dir lands in `DW_AT_producer`.

The two extra lines are the per-back-end include directory each target's spec
now names. **Every brief written before `7375c86aa4c` quotes 230 /
`a6c4c68bdf33`**, so an agent holding an older brief will score this as a
failure. It is the fix landing. The artefact it produces:

```
include/           16 files   target-neutral ginclude only
include-i386/     120 files   incl. mm_malloc.h (tmake-fragment channel)
include-aarch64/   10 files   incl. arm_neon_sve_bridge.h
```

**AND THE `specs-config` md5 IS ENVIRONMENT-SENSITIVE, SO THOSE FOUR MD5s ARE
NOT A BAR — THE LINE COUNT IS.** Measured at `3b9f7c8f695`, anchor 52, cold,
47 bases (`scratchpad/abe9f294136236fc8-specsdiff.sh`). A fresh build
reproduces `232 / 224 non-blank / all md5s distinct / no duplicate-md5
fallback signature` exactly, and reproduces **none** of the recorded md5s:

```
x86_64-pc-linux-gnu         2 differing lines of 232
  < native_system_header_dir /nix/store/q5wv2ldp...-glibc-2.42-67-dev/include
  > native_system_header_dir /usr/include
aarch64 / riscv64 / s390x   the same ONE line, each with its own glibc path
alpha / avr / mips64 / or1k IDENTICAL, 232 lines, byte for byte
```

One line of 232, and it is an absolute path into the nix store. The four that
differ are exactly the four **glibc** targets, for which `taa-specs.sh` writes
that target's own header directory into the command; the four bare-metal ELF
targets have no libc, take `target-specs/configure.ac:570`'s own `/usr/include`
default on both runs, and are byte-identical. **That identity is the control**
— it says the compiler is the same and only the environment moved.

So these md5s encode a **glibc store path**, reproducible only by a run that
used `taa-specs.sh` with those store paths still live. Same shape as
`mt-bars.sh`'s `-g` arm, which INSTRUMENTS.md already records as
path-sensitive and never-quotable-bare — and the same shape as the aarch64
`-S` bar being filename-sensitive. **Quote it as 232 / 224 / all distinct plus
a line-diff against a named control, never as four md5s.** An agent holding
the md5s will otherwise score a correct build as a failed bar, which is the
direction that wastes a day.

Note the general form, since this is the third artefact on this branch to have
it: **an md5 is the right instrument for "is this the same file" and says
nothing about WHY when the answer is no.** Pair every md5 bar with a
line-differ, or the first mismatch produces a story instead of a diff.

**QUOTE EVERY BAR WITH THE COMMAND THAT PRODUCED IT. THREE TIMES IN ONE DAY, A
"DISAGREEMENT" WAS ONE QUANTITY READ TWO WAYS.**

```
specs-config      wc -l 230        grep -c . 222      (8 blank lines)
big.c at -O2      .s  12369 / 378fc33c1e70            .o  6376 / b55aaccf5ca7
```

Both pairs are the **same file at the same commit**. Each time, one party
reported a figure, another reported a different one, and the reconciliation
offered was a *story* — "different configurations", "an inherited gap some
earlier change introduced and nobody re-measured". Each time the real answer
was a different measuring command, and settling it took under a minute.

The canonical bars, so this stops recurring — **two bases**, at
`70c9d9b3194`, cold, from an immutable snapshot:

```
cc1 -quiet -nostdinc -O2 -ftarget-config=<specs-config> big.c -o x.s
  x86_64   12369 bytes  md5 378fc33c1e70
  aarch64  12210 bytes  md5 ce1b968e06b1
specs-config  wc -l 230   grep -c . 222   md5 a6c4c68bdf33
```

Two rules follow. **State the artefact and the command**, not "12369 bytes".
And **when two measurements of one thing disagree, first hypothesis: they are
not measuring the same thing** — test that before constructing an account in
which both are true. A reconciliation that explains everything and predicts
nothing is not a finding.

Third rule, from the same episode: **the bars are base-count dependent.** The
figures above are two-base. Quoting a bar without its base count invites an
agent to score a real regression as a bar failure, or the reverse.

**AND THE EXAMPLE THIS RULE CARRIED WAS ITSELF A MISATTRIBUTION — IT WAS NEVER
THE COUNT.** This file said "at three and four bases x86_64 `-O2` currently
ICEs in `type_natural_mode`", and #157 and #170 recorded the same at 3, 4, 8
and 11. Measured (task #164, snapshot `80bf400ae06`, anchor 55, cold, from
immutable snapshots):

```
2 bases  i386 aarch64                 MIN_MODE_VECTOR_INT = V2QI   12369 / 378fc33c1e70
3 bases  i386 aarch64 rs6000          MIN_MODE_VECTOR_INT = V2QI   12369 / 378fc33c1e70
4 bases  i386 aarch64 rs6000 s390     MIN_MODE_VECTOR_INT = V1QI   ICE at i386.cc:2155
```

**Three bases reproduce the two-base bar exactly.** The variable is not how
many back ends are configured, it is *whether any configured back end defines
a mode narrower than i386's narrowest of that class* — s390's `V1QI`
(`s390-modes.def:280`), riscv's `VNx1*`. The union's `MIN_MODE_VECTOR_INT` is
then a mode i386 does not have, i.e. a **hole**, whose `mode_next` is
`VOIDmode`, so `FOR_EACH_MODE_FROM (mode, MIN_MODE_VECTOR_INT)` ran zero
times. Fixed in `688b3afe25d` by starting such walks at
`GET_CLASS_NARROWEST_MODE (C)` — the one table `genmodes` emits with *this*
base's answer to exactly that question. After it, the bar is `12369 /
378fc33c1e70` at **2, 3, 4 and 11 bases, byte for byte** (11 = the
`t170-bases11.txt` set, `cc1` linking, `error:` 0). **So the x86_64 `-O2`
codegen bar is no longer base-count dependent and may be quoted at any base
count** — which is the point of fixing it: it is the branch's strongest
regression detector and it was off in every configuration the project is
actually aiming at.

The transferable part: **"it appears at N and not at N−1" is not evidence that
N is the cause.** Base sets on this branch grow by adding a *named* back end,
so a count is always confounded with a membership change; say which back end
entered the set, then test a same-sized set without it.

**STANDING USER RULING — GET THE BACK ENDS BUILDING, EVEN IF EVERYTHING IS
BUSTED.** Verbatim: *"just get those backends building — even if everything is
busted it's OK, we'll figure it out. it should be mechanical, right? and the
hooks pattern is well established upstream."* Earlier in the same exchange:
*"that's rote."*

This **suspends §2a's ban on stubs and `#ifndef` floors, for link-level fixes,
for this phase only.** The goal metric is the **count of back ends that link**;
per-base functionality is explicitly deferred. Two conditions attach:

- Prefer a **fail-by-name abort** (`gcc_unreachable ()`, or an `internal_error`
  naming the symbol and the base) over a plausible wrong value. A stub that
  quietly returns the primary's answer is exactly the defect class this project
  exists to remove and the hardest to find later; one that aborts is trivial.
- **Record every stub in one committed list.** The correctness pass then
  inherits a work queue instead of an archaeology problem.

§2a is NOT repealed — it resumes the moment this phase ends, and it still
governs anything that is not a link-level unblock.

**CHECK WHETHER THE HOOK ALREADY EXISTS BEFORE BUILDING A MECHANISM.** The
coordinator asserted that the `print_operand` family "needs a SELECTOR, not a
rename, because `targhooks.cc` and `final.cc` name it". Measured, that is
false in the way that mattered:

- `TARGET_PRINT_OPERAND` / `TARGET_PRINT_OPERAND_ADDRESS` are **already target
  hooks** — `target.def:1107`, `:1116`.
- `final.cc:3679`/`:3695` call `targetm.asm_out.print_operand`, i.e. *through
  the hook*.
- `targhooks.cc` defines only `default_print_operand`, never the bare name.
- The 8 back ends defining a bare global `print_operand` are each supplying
  *their own* function, registered as their own hook.

So no shared TU names the bare symbol, and the settled rule gives a **bare
rename**. Generalise: upstream has spent twenty years moving target behaviour
behind `targetm`, so **before designing dispatch, ask whether `target.def`
already has the hook and whether shared code reaches the bare name or the
hook.** Much of what looks like new mechanism here is a rename plus an existing
hook — which is what makes the user's "it should be mechanical" the right
prior.

**A WRITTEN INVARIANT IS NOT A CHECKED ONE — AND A MACRO-MEDIATED ACCESS
DEFEATS THE GREP THAT WOULD HAVE CHECKED IT.** `genmodes.cc`'s `CONST_MODE_*`
block argues `const` is safe for all eight mode tables because "there is not
one assignment to one of them outside this generator — and neither does any
hand-written back-end source." That is true of **six** of the eight.
`tree.h:2503` makes `TYPE_IBIT(NODE)` expand to `mode_ibit[TYPE_MODE(NODE)]`,
so `avr.cc:1245-1246` really do write a mode table. **Grepping any back end
for `mode_ibit` finds nothing** — it is reached only through two `tree.h`
macros, which is exactly how the claim survived being written down and
believed.

So: **search for the ACCESSOR, not only the name.** And when a comment asserts
"nothing does X", treat it as an unrun test — write the test.

Invisible to any pair without avr, which is the only back end defining
`ADJUST_IBIT`/`ADJUST_FBIT`. Another entry for the two-back-ends-cannot-tell
list.

Method note from the same task, worth copying: its first both-sided arm was
**tautological** — it required avr's and i386's `mode_ibit` *bodies* to differ,
and they are byte-identical **correctly**, because the mode vocabulary is
unioned and the static table is the vocabulary's own data. The real
discriminator was the *adjustment* (avr 2 writes, i386 0). The agent recorded
the broken arm in the script rather than quietly swapping it out, which is what
lets the next reader see why the obvious check is wrong.

**`tm.h` IS FOUR CHANNELS, NOT ONE — AND EVERY "WHO NEEDS `tm.h`" FIGURE IN
THIS FILE MEASURES ONE OF THEM.** `mkconfig.sh` assembles it as: a
target-neutral top half → `#include "options.h"` → the back end's header chain
→ `insn-flags`/`insn-modes` → `defaults.h`. In a build dir, `gcc/tm.h:40` **is**
the `options.h` line.

So a TU can be perfectly clean against the `config/` target-macro vocabulary
and still genuinely need `tm.h` — for `OPT_*` enumerators or `global_options`
accessors, which that vocabulary does not contain and never could. Measured:
`main.cc` (`flag_checking`) and `c-family/cppspec.cc` (`OPT_x`, `OPT_o`) both
scored CLEAR and were revoked by the build.

Consequence: **`t141-delete-ready.txt`'s 23 and Class A's 39 are upper
bounds.** A second vocabulary — `options.h` names plus the `mkconfig.sh` top
half — is required before any further deletion is authorised. Three of eight
attempted deletions survived; five were revoked, two by this cause and three by
the transitive one the plan already named (a TU whose own text is clean but
which includes `rtl.h`, which reaches `hard-reg-set.h` and itself spells
`BITS_PER_WORD`).

The older framing in this file — "`tm.h` is the i386 `tm.h` wearing a name that
does not say so" — is true of the *back end's header chain*, which is the third
of the four. It is not true of the whole file, and reading it as though it were
is what made a one-vocabulary scan look sufficient.

**THE SECOND VOCABULARY WAS BUILT (task #160) AND IT IS NOT WHERE THE LOSS IS.
Read this before sizing any further deletion.** Four vocabularies now exist
(`t160-vocab.sh`) and the channel count is **five**, not four: `insn-constants.h`
has its own line in `tm.h` beside `options.h`. The brief's open question about
`insn-flags`/`insn-modes` has opposite answers — `insn-flags.h` has no other
includer, while `insn-modes.h` reaches every shared TU through `coretypes.h:553`
ahead of `tm.h`, so it needs no vocabulary at all.

**"ARRIVES AHEAD OF `tm.h`" IS A FACT ABOUT ORDERING, NOT A CERTIFICATE OF
NEUTRALITY.** The clause above — "so it needs no vocabulary at all" — is a
non-sequitur, and #187 measured what it was hiding. `insn-modes.h` /
`insn-modes-inline.h` are the **widest leak channel in the compiler: 812 of 833
shared objects**, every shared object that opens anything, and the build root's
copy is **byte-identical to i386's**. Wider than `tm.h` (451 shared openers) and
`tm_p.h` (122). Whenever a line here explains *how* a header reaches everyone,
check separately whether the thing that reaches them is per-base; the two
questions are independent and this file conflated them for the widest file in
the tree.

**AND "WIDEST LEAK CHANNEL" IS THE WRONG NAME FOR IT — 812 IS A COUNT OF AN
`#include`, NOT OF A DEPENDENCE ON ANYTHING THAT DIFFERS (#193).** The
paragraph above is right that byte-identity to i386 is a fact worth having and
wrong to stop there. Measured, same 47-base build, `dc7507542ce`, anchor 52
(`t193-agent-a167f499b5c9c334c-modeprov.sh`, `-modediff.sh`):

```
insn-modes.h         47 files,  3 distinct bodies    (comments stripped)
insn-modes-inline.h  47 files,  1 distinct body      -- TARGET-NEUTRAL, measured
insn-flags-<base>.h  45 files, 45 distinct bodies    -- the negative control
```

The whole divergence of `insn-modes.h` over 47 back ends is **five names**:
`PSImode`, `CPSImode`, `E_PSImode`, `E_CPSImode` — defined only by `avr` and
`msp430`, which both declare a `PSI` mode, so genmodes qualifies them
(`avr_PSImode`) and aliases the bare name to whichever base is in force — and
**`NUM_INT_N_ENTS`**. The shared copy defines none of the first four, so a
shared TU spelling `PSImode` is a compile error, not a silent leak. The union
did its job; the numbering, the class ranges, `MAX_BITSIZE_MODE_ANY_*`,
`NUM_POLY_INT_COEFFS` and every `mode_*` accessor in
`insn-modes-inline.h` are byte-identical across all 47.

`NUM_INT_N_ENTS` is the one real item and it is the **union-bound-as-SIZE vs
as-PREDICATE** distinction again, live:

```
insn-modes.h (= i386's), and 45 bases         NUM_INT_N_ENTS 1   int_n_data = { TI 128 }
insn-modes-avr.h                              NUM_INT_N_ENTS 2   { avr_PSI 24,    TI 128 }
insn-modes-msp430.h                           NUM_INT_N_ENTS 2   { msp430_PSI 20, TI 128 }
```

`tree.cc:294-295` allocates `int_n_enabled_p[NUM_INT_N_ENTS]` and
`int_n_trees[NUM_INT_N_ENTS]` from the SHARED header, i.e. **1**, and ~25
shared TUs loop `for (i = 0; i < NUM_INT_N_ENTS; i++)`. So on avr and msp430
the second `int_n` entry is never registered. `avr.cc:16327` is compiled with
avr's header, loops to **2**, and indexes the shared 1-element `int_n_trees`;
it is in bounds today only because genmodes bubble-sorts the table by precision
and avr's `PSI` (24) lands at [0] before `TI` (128).

**The trap, stated because it is the obvious fix and it is wrong:** making
`NUM_INT_N_ENTS` the union maximum (2) everywhere gives the other 45 bases a
loop that reads `int_n_data[1]` past the end of a one-element
`const int_n_data_t` table. Correct shape is the settled one —
`MULTI_TARGET_UNION_NUM_INT_N_ENTS` sizing the shared arrays, and the loop
bound coming from the SELECTED base at run time.

**LANDED (`ebf24b3f2fc`), AND THE BRIEF'S PRESCRIBED MECHANISM WAS THE WRONG
ONE — the reason generalises to every future union bound.** The obvious home
was `multi-target-reg-probe.cc` + `gen-reg-widths.sh`, which is where
`MAX_BITS_PER_WORD` and four other union bounds come from, and it carries the
identical argument (an array bound must be a constant expression). It cannot
work here, and not by accident: that probe's answer arrives in
`multi-target-reg-widths.h`, which is *generated from the probe objects*, and
a probe object is a translation unit including `coretypes.h` and hence
`machmode.h`. Sizing `machmode.h`'s arrays from it makes `machmode.h` depend
on a file generated from a compile of `machmode.h`. **`expmed.h`,
`hard-reg-set.h` and `lower-subreg.h` can include that header because they are
downstream of `tm.h`; `machmode.h` and `tree.h` are upstream of everything.**
So before routing a bound through the reg probe, ask which side of `tm.h` its
consumers sit on.

The channel that does work is the one already answering `NUM_POLY_INT_COEFFS`
and both `MAX_BITSIZE_MODE_ANY_*`: a `#`-prefixed setting line in
`modes-union.list`. The union run has read every configured back end's modes
file by the time it writes that list, so the number is free there and arrives
through a header every translation unit already has. Measured, 47 bases:

```
modes-union.list      #num_int_n_ents 3          (msp430 PSI 20, avr PSI 24, TI 128)
insn-modes.h          NUM_INT_N_ENTS 1   MULTI_TARGET_UNION_NUM_INT_N_ENTS 3
insn-modes-aarch64.h  NUM_INT_N_ENTS 1   MULTI_TARGET_UNION_NUM_INT_N_ENTS 3
insn-modes-avr.h      NUM_INT_N_ENTS 2   MULTI_TARGET_UNION_NUM_INT_N_ENTS 3
insn-modes-msp430.h   NUM_INT_N_ENTS 2   MULTI_TARGET_UNION_NUM_INT_N_ENTS 3
```

Note the union is **3 where no back end has more than 2** — avr's and
msp430's `PSI` are distinct qualified modes. Correct for a layout bound, and
exactly what no loop may use. Three names now: `NUM_INT_N_ENTS` (this base's
own), `MULTI_TARGET_UNION_NUM_INT_N_ENTS` (the layout), `MT_NUM_INT_N_ENTS`
(the selected base's run-time count, a `num_int_n_ents` variable that
`genmodes` emits beside `int_n_data` and `MT_SCALAR_TABLES` installs with it,
exactly as `unspec_strings_len` travels with `unspec_strings`).

**AND THE EVIDENCE ARM PICKED THE WRONG OBSERVABLE FIRST, WHICH IS THE MORE
USEFUL HALF.** It asserted avr would gain `__SIZEOF_INT128__` once index 1 was
reachable. It does not and must not: `c-cppbuiltin.cc:1710` is guarded by
`int_n_enabled_p[i]`, which `toplev.cc:2218` sets from
`scalar_mode_supported_p`, and **avr has no `TImode`**. The arm reported
`FAILED` on a green tree. The observable that discriminates is the KEYWORD,
because `c-parser.cc` creates the identifiers unconditionally:

```
index 1 not registered   error: unknown type name '__int128'
index 1 registered       error: '__int128' is not supported on this target
```

avr and msp430 now give the second. Control (so the two messages are known to
be distinguishable rather than assumed): `__int24` on x86_64 and on msp430
gives the first, with the "did you mean" suggestion naming that base's own
registered set. Both-sided: x86_64 and aarch64 still accept `__int128` and
still reject `__int24`. `scratchpad/agent-a3cea52a56e315ee4-intn.sh`.

Generalise: **when a value's consumer is guarded by a second predicate, the
value becoming reachable does not make the consumer fire.** Find an observable
downstream of the bound and *upstream* of every other gate.

Corollary, same measurement: `git grep '"tm.h"'` **undercounts the real
population by 7.6×** — 59 source spellings against 451 shared objects that
actually open it, plus 5 files spelling `MT_HEADER (tm.h)` that the grep cannot
see at all. #68's criterion is not merely foolable in principle; the factor is
measured. Score that population with `t187-perbase-read.sh`, which reads each
object's `.deps/*.Po`, and keep the grep only as a tripwire beside it.

Re-scored over all 625 shared TUs, the four vocabularies move the Class A
population **not at all**: 31 CLEAR + 8 hit only by `options.h` names = the
same 39. What actually revokes is the **transitive** channel, which no
text-reading instrument can see:

```
             tm.h line deleted and rebuilt:   FAIL   PASS
own text CLEAR                                  17     14
own text OPTIONS-ONLY                            5      3

causes:  13 flag_checking (options.h, via system.h's gcc_checking_assert)
          8 enum reg_class (hard-reg-set.h:551, via rtl.h)
          1 OPT_E          (the file's own text)
```

So **21 of the 22 revocations come through headers and exactly 1 from a file's
own text.** Two consequences worth carrying: the `options.h` and top-half
channels are **target-neutral** — `options.h` is generated from every
configured back end's `.opt` files, so a TU that includes it directly gets no
primary's answer, and the remedy is a missing include rather than a conversion;
and the instrument that settles any of this is a **build with the line deleted**
(`t160-amputate.sh`), not a scan.

**THE `options.h` HALF OF THAT SENTENCE IS FALSE, MEASURED (#193). THE SHARED
`options.h` IS i386's, AND IT IS THE SECOND-WIDEST LEAK CHANNEL — 579 shared
readers.** #187 declined to score it and left it UNDECIDED rather than
inheriting the claim, which was the right call. Cold 47-base build,
`dc7507542ce`, anchor 52, `t193-agent-a167f499b5c9c334c-optionsclass.sh`:

```
root options.h vs options-i386.h      base-only    1   root-only    1
root options.h vs options-aarch64.h   base-only   13   root-only  869
root options.h vs options-riscv.h     base-only  845   root-only  862
bases with a name the root lacks:  47 of 47      -> it is NOT the union
i386's 829 back-end-private option macros, in the shared options.h:  828
EVERY other back end's private macros,   in the shared options.h:      0
```

**Two true halves made one false sentence, and that is the transferable
part.** The option-code VOCABULARY (`enum opt_code`) *is* unioned, by
`optionlist-vocab` + `opt-stub.awk`, and so is the `struct gcc_options`
LAYOUT. Both facts are real and both are about the parts of the header that
must agree between bases. The MACROS are the third part and they are the
primary's, because `gcc/Makefile.in`'s `s-options-h` rule generates the shared
header with **`-v union_base=$(multi_target_base)`**. `opth-gen.awk` says so
itself, twice, under "Residual, stated rather than hidden": it puts back out of
scope only what is foreign **to that one base**. Nobody read past the vocabulary
claim to the macro one.

**And the values arm is where it bites, which is the arm a name-set scan cannot
have.** 96 names have more than one body across the 47 bases; the shared
`options.h` defines **36** of them, with the primary's body:

```
TARGET_64BIT   root/i386  ((ix86_isa_flags   & OPTION_MASK_ISA_64BIT) != 0)
               mips       ((target_flags     & MASK_64BIT)            != 0)
               riscv      ((riscv_isa_flags  & MASK_64BIT)            != 0)
               rs6000     ((rs6000_isa_flags & OPTION_MASK_64BIT)     != 0)
MASK_LONG_DOUBLE_128   i386 (1U<<16)  alpha (1U<<12)  s390 (1U<<5)  sparc (1U<<9)
MASK_ACCUMULATE_OUTGOING_ARGS   i386 (1U<<3)   avr (1U<<1)
also TARGET_FDPIC, TARGET_GENERAL_REGS_ONLY, TARGET_BMI, TARGET_DEBUG,
     TARGET_DIV, TARGET_EMBEDDED_DATA, SET_TARGET_64BIT, ...
```

`dwarf2codeview.cc:2111,:2498,:6848` is a **shared** TU spelling `TARGET_64BIT`,
so CodeView output asks i386's ISA flag for all 47 back ends — and
`ix86_isa_flags` is `global_options.x_ix86_isa_flags`, i.e. the option-state
class `nm` cannot see and whose pre-`ix86_option_override` value is the
*unconfigured* default, the `Pmode`/riscv-32-bit shape again.
`ada/gcc-interface/decl.cc:62` and `targtyps.cc:226` guard on
**`#ifdef TARGET_64BIT`**, which is true for every target because i386 defines
it. Only 13 shared sources spell any of the 36, so the blast radius is small —
but "579 shared readers" was never the right number for it, and neither is 0.

**Generalise: "this header is generated from every back end's inputs" does not
make its OUTPUT neutral.** Ask which back end the generator was told it was
generating *for*. Here the answer is a make variable, `$(multi_target_base)`,
named in the rule.

`c3ca86166f8` closed the 8 by giving `rtl.h`/`hard-reg-set.h` the conversion
layer; the 23 direct includers now score 21 PASS / 2 FAIL, both on `options.h`.

**AND A POISON CAN SUPPRESS THE FIX UNDER TEST.** That instrument's first
version amputated with `-DGCC_TM_H`, the `t152-probe.sh` shape. It empties
`tm.h` and it also answers "has `tm.h` been read here" with YES — which is the
question the new neutral `enum reg_class` is guarded on. The arm reported all
8 failures unchanged on a tree where they were fixed. **Before reusing a
poisoned-guard arm, ask what else reads that guard**; the shape of the false
negative is "the change did nothing", which is exactly the reading an agent
will believe.

**A LOG BEING WRITTEN LOOKS EXACTLY LIKE A LOG THAT FINISHED — STAMP THE
EXIT.** An agent reported "13 errors → 7, 4 back ends → 2" and later withdrew
**both** figures: neither build had completed when it read them, so the delta
compared two mid-build snapshots stopped at two different unknown points.
Its own non-vacuity arm did not catch it, because that arm tested **existence
and non-emptiness** — precisely the two properties a truncated log has. A
partial log is non-empty, contains real compile lines, and greps clean.

The fix is structural, not vigilance: **write `<tag>.rc` only after `make`
returns, and have the scorer REFUSE any log lacking that stamp.** Then an
unfinished build is a hard failure by name instead of a smaller number.

This compounds with the `-k` rule above — under `-k`, "never attempted" and
"passed" are the same silence, and under truncation "not yet reached" joins
them. Two different ways for the same absence to read as success.

Credit where due: the agent found this in its own landed work and withdrew the
numbers unprompted, which is the behaviour this file exists to produce. The
content assertions in that task survived untouched, because none of them came
from a log count — they were both-sided assertions on generated files and
linked objects.

**AN INSTRUMENT THAT CANNOT SHOW ITS OWN FIXES LANDING CANNOT BE USED TO GRIND
A POPULATION.** Before working a queue an instrument produced, apply the test:
*take a defect this project already fixed, and check the instrument now reports
it clean.* `mta7-targhook-matrix.sh` failed that — it still listed all seven
pairs `d65b829e7a8` had fixed for rs6000, because it had no arm asking whether
the back end already supplied the hook. A queue from such a tool cannot
converge: every pass re-finds the last pass's work.

It was wrong two further ways, both of the kind a plausible-looking grep
invites:

- **Substring matching.** `grep "define PRINT_OPERAND"` also matches
  `#define PRINT_OPERAND_ADDRESS`. Word-bounding took that macro from 19
  definers to 14.
- **Scope chosen by directory rather than by what the compiler reads.** The
  definer grep looked only in `gcc/config/<be>/`, but `gcc/config/elfos.h`
  sits one level up, is in nearly every ELF target's `tm.h` chain, and defines
  two of the hooks — **66 of the 87 "silent" pairs**. The replacement
  (`tgh-hdrmatrix.sh`) preprocesses each base's real `tm-<base>.h` with
  `cpp -dM` instead of guessing from paths. Measured population: **6 pairs
  over 4 back ends, not 90 over 45**, and one macro's 21 pairs were **zero** —
  every base defines it.

Generalise: **ask what the compiler actually reads, not what the directory
layout suggests it reads.** And when replacing an instrument, run both and
require them to agree on the part that is not in dispute — here both agreed on
all 121 ICE pairs with zero contradictions, and that cross-check is what made
the fixes safe to apply.

Corollary already paid for twice: **the old instrument still reports the old
numbers on the fixed tree.** Leave it in place unmodified rather than editing
it to agree, so the two readings can be compared — zero movement in a blind
instrument is evidence about the instrument, not about the work.

**NEVER BUILD FROM THE LIVE WORKING TREE.** The coordinator did, to check
whether `cc1` links at HEAD, and merged a branch into that tree while `make`
was running. The build reported `multiple definition of add_clobbers` — a
perfect diagnosis of a state that never existed in any commit: `insn-emit-5.o`
generated *before* the merge, `multi-target-select.o` compiled *after* it.
**A torn read looks exactly like a real defect, and it names real symbols.**
Build from an immutable snapshot: `git worktree add /tmp/snap <sha>`, assert
the anchor AND `git diff --quiet` in the harness, and let the srcdir be
something nobody can write. A build whose sources can change under it measures
nothing, and it will not tell you that.

**`specs-config` WAS 230 lines when this was written; it is 232 since #163, and
the md5s quoted below are environment-sensitive and are NOT bars — see the
correction near line 978. What follows is kept as history, not as a check.**

**`specs-config` IS 230 lines — and the story of this paragraph is the
lesson.** An agent reported 222, measured on three targets with distinct md5s,
and called 230 a stale coordinator figure. That was plausible (the coordinator
*had* been repeating 230 without measuring) so the correction went into this
file unchecked. Then it was measured at HEAD `7979e8742cb`, cold, from an
immutable snapshot:

```
x86_64-pc-linux-gnu        230 lines  md5 a6c4c68bdf33
aarch64-unknown-linux-gnu  230 lines  md5 f1a5ab201d95
x86_64 -O2 big.c           12369 bytes  md5 378fc33c1e70
```

**AND THE EXPLANATION IN THE PARAGRAPH ABOVE IS ALSO WRONG — MEASURED AT
`bc7566b3bd4`.** The two figures are not different configurations. They are
**the same file counted two ways**: `wc -l` says 230 and `grep -c .` says 222,
the difference being 8 blank lines, and the md5s are `a6c4c68bdf33` /
`f1a5ab201d95` — byte for byte the ones recorded below for the 230 reading.
`t150-specs.sh` prints `grep -c .` and `t152-bars.sh` printed `wc -l`; nobody
was wrong about the artefact and both harnesses were right about their own
number.

That makes this paragraph a better example than it was. Two agents each
measured correctly, disagreed, and the disagreement was reconciled by a story
("different configurations") that no one checked — for a second time on the
same line. The lesson is not "say which build" alone, it is **quote the
artefact's identity, not a statistic about it.** An md5 would have settled
this the first time; a line count could not, because a line count is a
function of the counting program as well as the file. `t160-bars.sh` prints
both counts and the md5 for that reason.

So: a bar figure is a claim to check — **including when the claim is that a bar figure is wrong.** A
correction is not privileged over the thing it corrects. State the build dir
and the commit beside any bar you quote, or the next reader cannot tell which
of two true numbers applies to them.

**A GUARD THE BUILD SYSTEM CITES BY NAME MAY NOT EXIST.** `gcc/Makefile.in`
named a `sweep.sh` as the check for bare duplicate symbols across back
ends. It had never been written. The defect it was supposed to catch was live:
`extract_base_offset_in_addr` is defined bare by aarch64, riscv **and** arm — a
hard link failure, and invisible to the i386+aarch64 pair. This is worse than
`mechanism-present-but-never-invoked`: a comment naming a guard reads as
evidence the guard ran. **`scratchpad/mt-cite-check.sh` is now that
confirmation, run over `gcc/Makefile.in` and this file; it found a SECOND such
citation on its first run.** Before trusting any named check, confirm the file
exists and run it.**

**A HOLE WITH A REAL CLASS IS A USABLE OBJECT.** `genmodes.cc` unions the mode
*vocabulary* and keeps *data* per base, so a mode another configured back end
defines and this one lacks is a hole: precision 0, size 0, null format —
everything says "not here" **except its class**, which `read_union_list`
(`genmodes.cc:1619`) set from the shared numbering. Every `machmode.h`
predicate reads class *alone*, so a hole was a usable scalar int of width zero,
and `init_expmed` cached RTL costs for other back ends' zero-width modes on
every compilation. Generalise: **when you split data per base but keep one
vocabulary, every discriminator field must say "absent" — one field still
answering the old way is enough to make the absent thing usable.**

**A fix that moves the count by ZERO has refuted your story, and that is a
result.** Working the options-accessor leak, an agent's first draft put the
`#undef` block at end-of-file and made things worse: 63 → **254** diagnostics,
5 → 21 back ends. Cause: `TARGET_FDPIC` is `Mask(FDPIC)` in `arm.opt` *and*
`Var(TARGET_FDPIC)` in `bfin.opt` — two authorities **inside the options
generator itself** — so `options-arm.h` defines it twice and an end-of-file
undef killed arm's own Mask macro. The reflex repair was to exclude the shared
`options.h`, on a plausible story about which headers a TU sees. Result:
**254 → 254.** That zero is the only reason the story was caught as false.
Record such zeros in the generator rather than dropping them; a plausible
mechanism that moves nothing was never the mechanism.

Related, and do not inherit it untested: `f3a75a98014`'s note says a TU sees
only one options header. **False for the per-base glue** — `arm-c.cc` reaches
both. It did not bite in that task, but it is a stated invariant with a live
counterexample.

Generalise it: **"this artefact names the wrong path" and "this artefact was
USED to produce a wrong result" are two claims, and the second needs its own
instrument.** Repairing the first without measuring the second leaves you
unable to say which past results still stand — and the honest answer here was
*all of them*, which no amount of re-reading the scripts could have shown.
An all-clear is only worth stating when the instrument that produced it could
have said otherwise.

**SWEEP THE FAMILY; DO NOT MEET IT ONE WALL AT A TIME.** Four generated
per-base families were found built, linked, **and never selected** — the
`targetm` asm ops, the optab tables, the predicates/constraints, and the insn
attribute tables — each discovered by *walking into it* during an unrelated
debug session. When the fourth turned up, enumerating the whole of `OBJS`
took one agent-session and produced a verdict per family, including six that
were already clean (worth stating: **a family you checked and judged fine is
a result; silence about it is not**). It also found, *outside* the family it
was sent to look at, a **163KB overrun of a shared `.bss` object**:
`NUM_INSN_CODES` was 15429 (i386's) while shared code writes at codes up to
20511.

**"Is a per-base variant built?" and "does a selector exist?" and "does
anything CALL the selector?" are three arms, not one.** A selector has been
found complete, well-commented and with **no caller anywhere** while its table
arm was green and correct.

**"WHERE DOES IT ICE" IS NOT THE MEASUREMENT. "IS THE OUTPUT RIGHT" IS.**
A wall was handed between agents as *"`int g(int a){return a+1;}` fails in
`aarch64_can_eliminate` during postreload"*. At branch HEAD it did not fail at
all — it **compiled, exited 0, and emitted**

    str  x19, [x7, -32]!

with matching wrong CFI: i386's `STACK_POINTER_REGNUM` and
`FRAME_POINTER_REGNUM` (7 and 19) used as **aarch64's** stack and frame
pointers. The loud failure had already become a quiet one, and tracking ICEs
would have recorded that as *progress*.

So: **every wall report must state what the compiler produced, not only where
it stopped.** A wall that "moves" may have become silent wrong code. Check the
emitted assembly against the target's real registers before believing a
failure went away — and treat a disappeared ICE as suspicious until the output
is inspected.

**THE SYMBOL INSTRUMENT IS BLIND TO MACROS THAT EXPAND TO OPTION STATE, AND
THAT IS EXACTLY WHERE THE WORST LEAKS LIVE.** `nm -uC` scores them as *absent*,
and not by bad luck: `ix86_pmode` is `global_options.x_ix86_pmode`, a struct
member shared code legitimately links against, so **no object anywhere carries
an undefined reference naming it**. Two agents hit this independently — one
found `nm` scoring four real leaks clean because `Var(ix86_branch_cost)` is
likewise `global_options.x_…`. So the instrument sees macros expanding to
**code** and misses macros expanding to **option state**. When a macro's body
is an option variable, `nm` cannot help you; read the value in the running
`cc1`.

**The silent-default variant, which is worse than an ordinary leak.** i386's
`Pmode` is `(ix86_pmode == PMODE_DI ? DImode : SImode)`, and `ix86_pmode` is
`Init (PMODE_SI)`, promoted to `PMODE_DI` only by `ix86_option_override` —
which runs only when i386 is selected. So shared code compiling for aarch64
did **not** get x86_64's answer; it got the primary's **unconfigured
default**, correct for *neither* base. Note the trap in that: **a leak serving
the primary's real value would have produced the right mode by luck and hidden
this indefinitely.** When you find an option-state macro, check what it reads
before any `*_option_override` has run, not what it reads afterwards.

**An undefined symbol names the macro that DRAGGED IT IN, not the macro that
caused the control flow.** `nm -uC` cleared three walls in a row and then
pointed at the wrong macro on the fourth. `cfgexpand.o` showed
`U ix86_incoming_stack_boundary`, and `INCOMING_STACK_BOUNDARY` really does
leak — but the function was only *entered* because
`SUPPORTS_STACK_ALIGNMENT` is `(MAX_STACK_ALIGNMENT > STACK_BOUNDARY)`, and
only i386, cygming and nvptx define `MAX_STACK_ALIGNMENT`, so `defaults.h`'s
`#ifdef` is true purely because the primary is i386. aarch64's own answer
makes it `128 > 128` — **false** — so aarch64 should have returned two lines
in and never reached the assert at all. Converting the named macro alone
would have left aarch64 inside the function running i386's realignment path,
with the assert now passing: **a loud failure turned quiet.** So: when a
symbol names your suspect, walk the *guards* that decided you reached that
line, and convert the closure.

**Ask what would have had to change for your comparison to mean anything, then
show it did.** Models: `nm -C` 1379 `poly_int<1u>`→0 and 0→1619 `poly_int<2u>`;
`targetm` instructions 3060→0 with `targetm_ptr` 0→2938; `sub $0x4b8,%rsp` →
`sub $0x9d8,%rsp`; `sizeof` 1520→1528 while the settled struct held at 8392.

**Both-sided evidence.** Showing target A gets A's answer proves nothing unless
you also show target B still gets B's. One-sided evidence cannot distinguish
"fixed" from "everyone now gets the same new answer".

**Separate arms on the data and on the selection.** A green arm on a per-base
table says nothing about whether the pointer choosing between tables is wired.
`targetm_asm_ops` was pinned to the primary while `target_asm_ops_for()` had
**no caller anywhere**, and the table arm was green and correct.

Six rules that each cost a session:

1. **Absence of an artefact is not absence of a mechanism.** No file in a build
   dir ≠ no rule; make is lazy. Grep the generated `.mk`, never `ls`.

   **AND GREPPING THE GENERATED TEXT IS NOT ENOUGH — RUN IT (#189).** A
   generator emitted a make recipe iterating `source>dest` pairs:

   ```
   for pair in .../config/i386/pmm_malloc.h>mm_malloc.h ; do
   bash: -c: line 1: syntax error near unexpected token `>'
   ```

   The generated text was **exactly correct** — every generator arm passed,
   including one asserting that pair verbatim. `>` is a shell **redirection**,
   so the fault existed only in what a shell does with correct text. **A
   generator-level arm cannot see this class at all**, by construction: it
   compares strings, and the string was right.

   So for anything that generates a **recipe** rather than data, the arm has to
   be "make ran this rule and the file appeared", not "the rule looks right".
   The cheap version is one `make <the-one-target>` in an already-built dir,
   which costs seconds and is the only thing that would have caught it. Same
   family as the `$(eval)` case in rule 7: a **plausible, complete, non-empty**
   artefact that is wrong when executed.
2. **Presence of a mechanism is not evidence anything invokes it.** A complete,
   well-commented mode union sat inert for weeks. Grep the generated fragment
   for your flag; diff the artefact it should have changed.
3. **A written invariant is not evidence anyone ran it.** A comment claiming "no
   back end writes through `targetm`" was false by 12 sites the moment someone
   ran the grep it described. A `Makefile.in` comment about `OBJS` was false.
4. **A measurement that scores 0 may be a false negative from the instrument.**
   Confirm a 0 by finding the thing under another name.

   **And a count is not the divergence.** `ELIMINABLE_REGS` leaks between
   bases, and i386 and aarch64 both have **exactly four pairs** — a
   length check would have scored the leak as *absent*. (`vax.h` has one,
   `rs6000.h` six, so a count looks like a discriminator until you try it on
   the pair you actually have.) All four register *numbers* differ. **Print
   the contents and compare them; do not assert on a count**, and do not
   predict which elements differ — a previous wall's missing registers turned
   out to be 16–19, not the 92–94 predicted.
5. **A clean result from an instrument with unexamined blind spots is worth very
   little.** Strong-symbol sweeps hid COMDAT; the COMDAT sweep hid macros; the
   macro probe found `BYTES_BIG_ENDIAN` by failing to compile. **State your
   instrument's blind spots.**

   **Including gdb.** An arm set three breakpoints in one run and narrated
   labels between `finish` commands, assuming they fired in the order written.
   One function is hit first and repeatedly, so all three readings were *that
   one function's* return value under three different names — two arms
   compared the wrong function entirely, and **the third passed**, because
   0/1 happened to be what it was reading. One breakpoint per run, and match
   gdb's own reported breakpoint against the function under test.
6. **A diagnostic-driven sweep fixes exactly the copies some configured triple
   compiles.** A poly_int sweep fixed 2 sites and left 7 identical siblings,
   having demonstrably reached those files. **Sweep the source, not the build
   output** — ~186 targets are never built.
7. **A mitigation can score the very error it was written to catch as a pass.**
   TOPLEVEL-DESIGN §2.2 twice described the `$(eval)` failure mode as "a
   silently empty recipe" and mandated a **non-emptiness assertion**. Measured
   by injecting the error rather than by reading: under-quoting `$$(srcdir)`
   produces a complete, non-empty, *plausible* recipe with the call-time value
   baked in where a deferred one belonged. The prescribed check would have
   passed. **The failure was silently WRONG, not silently EMPTY** — and a
   length test cannot tell those apart. Diff the artefact against an
   independently-produced control; never assert on its size.

   Generalise it: **whenever you write a mitigation, inject the exact fault it
   names and confirm the mitigation fires.** An unfired mitigation is
   indistinguishable from an absent one, and reads as protection.

   **The same lesson arrived twice in one day by a different route, which is
   the signal.** `target-specs/configure` was exiting 1 for *every* target
   (a key emitted but absent from `ts_expected`), aborting partway and leaving
   `specs-<target>` **truncated at 39 lines** instead of 101. Every aarch64
   measurement taken in that window used a truncated spec file. The guards
   missed it because **they assert the file is non-empty — and 39 lines is
   non-empty.**

   So: **"non-empty" and "long enough" and "exists" are not checks.** They are
   the shape that passes on the corrupted artefact. Check the artefact against
   what it should *be* — a line count you predicted, a diff against a control,
   the specific keys you expect by name. If you find yourself asserting
   `test -s`, ask what a half-written version of that file looks like, because
   that is the case the assertion will meet.

   **Third instance, and the sharpest: a GENERATOR that ran, exited 0, and
   changed nothing.** An agent added a probe symbol, a loop and a refusal
   check to `gen-reg-widths.sh` — but never added the `#define` to its
   heredoc. The header came out **byte-identical**, `move-if-change` therefore
   kept the old one, and make reported success. Exit status, existence,
   timestamp and non-emptiness *all* pass on that. Note `move-if-change`
   actively hides it: its whole purpose is to make "no change" invisible to
   make.

   **So for anything generated, assert on the CONTENT you added, by name and
   value, and run that arm first.** "The generator ran" is not evidence the
   generator did anything.

**Check the count in BOTH directions when moving a walk onto a union list.** A
fix can improve the axis you are watching while silently regressing the one you
are not. Real case: `cl_optimization_compare` walked `flags[]` with 1116
comparisons and **zero** aarch64 members. Switching it to `sv_flags[]` compiles
and adds 17 aarch64 members — and takes the count **1116 → 585**, because `R`
records are the *save* set while that walk needs every option with a
`gcc_options` member. **531 common options silently stop being compared.** A
non-vacuity check asking only "did aarch64 appear?" scores that as a pass. The
correct fix added a new record kind: 1116 → 1169, none lost, 44 aarch64.

**Never retire or weaken a probe to move a number** (the test-harness floor).
Refused four times, including the subtle form: changing a macro's value to flip
the *tautological* i386 column. An arm turning green because both bases now
expand to the same target-neutral text is a **wrong-reason** flip — retire it as
`CONVERTED_CDATA` with a TAB arm, never bank it.

**One file complaining while ninety stay quiet can mean the ninety are silently
wrong** (the `-I<base>-inc` bug). And its dual: **many errors in one file while
siblings compile clean is usually systemic** (the `GCC_TM_H` forwarder bug).

**Landing a subset is fine; leaving a non-linking `cc1` blocks everyone.** If you
cannot land it whole, land what keeps `cc1` linking and hand over a
decomposition with measurements. That call has been made correctly 17 times here
and never regretted. **A half-fix that makes a failing check pass while the
answer is still wrong is worse than the failure.**

## 5. Environment traps, each paid for in hours

- **THE FULL BUILD SHELL is mandatory.** `nm`/`make` are not on PATH outside
  the nix-shell; a reduced shell writes `#define rlim_t long` into
  `auto-host.h`, which looks exactly like someone else's source bug.

  **THIS RULE CITED `DEVSHELL.md` FOR MONTHS AND THAT FILE HAS NEVER EXISTED
  IN THE HISTORY OF THIS BRANCH.** Measured with
  `git log --all --diff-filter=AD -- '*DEVSHELL*'`: **no commit ever added
  it.** It is cited here and by ten `t<NNN>-*.sh` scripts, and
  `eb-shell.sh`'s first line still reads *"Full build shell per DEVSHELL.md"*.
  **A rule pointing at an unreadable file is worse than no rule, because it
  reads as satisfied** — every agent who met this line assumed the detail was
  written down somewhere and moved on.

  Nothing here is reconstructed from guesses. The mechanism survives in
  `eb-shell.sh` (the `-p` set, `NIX_HARDENING_ENABLE`, the pinned
  `cache.nixos.org` substituter) and the `rlim_t` assertion survives inline in
  `t106-build.sh:57`, `t133-reconf-gcc.sh:31` and others. **Use `eb-shell.sh`;
  it is the authority, and it always was.** What is genuinely lost is whatever
  else that document said, and that is stated rather than invented.

  **AND `mt-cite-check.sh` PASSES ON THIS.** It exists because
  `gcc/Makefile.in` cited a `sweep.sh` under the scratchpad directory which did
  not exist — the same defect. (Spelled without its prefix deliberately: the
  checker cannot tell a **quotation** of a bad citation from a citation, so
  writing that path here in full makes the check fail on this very paragraph.
  Measured, by making it fail.) It greps
  `scratchpad/[A-Za-z0-9_...]*`, and this rule wrote
  `DEVSHELL.md` **bare, with no `scratchpad/` prefix**, so the checker never
  saw it. One filename spelling outside the pattern and the instrument reports
  a clean green on the very defect it was written to catch. **A citation
  checker keyed on a path prefix cannot see a citation that omits the prefix**;
  cite files by their `scratchpad/` path so the checker can refuse them.
- **Worktrees are created at bare-repo HEAD `7208eca60d0`**, 39,111 commits
  behind. It presents as *"stale line numbers"*, not *"wrong tree"*.

  **THE ANCHOR DOES NOT LOCALISE YOU, AND THIS FILE USED TO IMPLY IT DID.**
  Grepping `MULTI_TARGET` in `gcc/Makefile.in` distinguishes the bare-repo HEAD
  (**0**) from a real tree, and nothing more: the value has been 23, 27, 28, 30,
  37, 39, 45, 47, 49, 52 at different tips, so **several trees give a plausible
  number** and a *wrong-but-plausible* one is the dangerous case. Measured
  live: an agent reset off the stale HEAD, landed on `2b20283b6b1` — a genuine
  ancestor 19 commits back — read anchor **47**, and had a report half-written
  saying *"the brief's 52 is stale, the tree says 47"*. Both numbers were
  correct readings of different commits; the brief was right.

  **The tell was not the number, it was what was MISSING.** At that ancestor,
  `INSTRUMENTS.md`, both boards, `mt-lib.sh`, `mtcheck.sh` and half the harness
  are absent — which reads as *"the brief cites files that were never
  committed"* rather than *"you are 19 commits back"*, and is indistinguishable
  from the `DEVSHELL.md` case two bullets up, which is real. So the two
  failure modes point at the same evidence and the same evidence does not
  separate them.

  **THE BRANCH IS `multi-target-0`.** It was renamed from `multi-target`, and
  for a while afterwards a bare `multi-target` still resolved — by git's DWIM to
  the surviving remote-tracking ref — to a tree that happened to be identical to
  the tip. One name, two authorities, agreeing **by luck**, and it would have
  gone stale silently as commits landed: the ancestor check passing, the anchor
  reading 52, every file probe passing, right up until it quietly didn't. The
  remote ref has since been deleted, so `git rev-parse multi-target` now fails
  with *"Needed a single revision"* — **the loud failure, which is the one we
  want.** Any brief still naming `multi-target` now errors instead of resolving
  to a plausible wrong tree. If you are reading such a brief, that is why.

  **Check, in this order, and do not stop at the first:**
  ```sh
  git merge-base --is-ancestor HEAD multi-target-0  # ancestor, not tip => STALE
  git rev-parse HEAD; git rev-parse multi-target-0  # must be EQUAL
  ls scratchpad/INSTRUMENTS.md                      # a RECENT file must exist
  ```
  `--is-ancestor` returns **true** on a stale ancestor, so it alone says
  nothing; it is the *equality* that localises. And before concluding a brief
  cites files nobody committed, run `git log --all -- <that path>` — a file
  present in history but absent from your checkout means **you are on the wrong
  commit**, not that the brief is wrong.
- **The git index is SHARED.** `git commit` commits whatever is staged, including
  another agent's files. `git diff --cached` immediately before every commit.
- **EVERY `t<NNN>-build.sh` ON THIS BRANCH HAS THE SAME WRONG TEST, AND IT
  COSTS A BUILD.** They run `make cc1` inside `$D/gcc` *if that directory
  exists*, and `make all-gcc` at the top level otherwise. But `$D/gcc` exists
  as soon as anything has run `configure-gcc` — including a script that only
  wanted to make one generated file. The `cc1` link then fails with

      No rule to make target '../libcpp/libcpp.a', needed by 'cc1-checksum.cc'

  because libiberty, libcpp, libdecnumber and libbacktrace were never built.
  **It reads as a broken tree and it is a broken heuristic.** Build the top
  level (`scratchpad/t171-topbuild.sh`), or make the test "has `libcpp.a` been
  built", never "does the directory exist".
- **A TASK NUMBER IN YOUR BRIEF IS NOT SOMETHING YOU CAN READ. Subagents have
  no `TaskList`/`TaskGet`/`TaskUpdate`.** The coordinator briefed an agent to
  "update the tasks themselves (`TaskUpdate`)" — tools that do not exist in a
  subagent's roster. The agent verified their absence twice via `ToolSearch`,
  reported the contradiction instead of improvising, and updated nothing.
  **That is the correct response** and it is what §"if a brief contradicts this
  document" asks for.

  This is the coordinator's error, not the agent's — and it had already been
  written down before it was repeated. If you are handed a task number, treat
  it as a *label for a body of findings that must be restated in the brief
  itself*. If the brief does not contain the finding, it is not available to
  you; say so rather than reconstructing it from `STATE.md`, which for several
  numbers has no section at all.
- **NEVER EDIT A SCRIPT AN IN-FLIGHT RUN IS EXECUTING — `sh` READS BY BYTE
  OFFSET, NOT ALL AT ONCE.** A near-miss, reported because it nearly cost a
  six-hour four-target board. `mtcheck.sh` was running; 50 lines were inserted
  near line 64 while the interpreter was executing the target loop several
  hundred lines below. POSIX shells read the script file lazily and keep a file
  OFFSET, so **inserting lines ABOVE the current position shifts every later
  byte and the shell can resume mid-statement**, executing a fragment of a line
  that never existed in any version of the file. The run survived (22 `expect`
  processes, 6 `cc1`, 221 files written in 60s, all verified rather than
  assumed) — but survival was luck, not design.

  The failure mode is the worst shape this file tracks: it produces a **real
  syntax error, or worse a valid-but-different command, in a script that reads
  correctly when you `cat` it afterwards.** There is no artefact to inspect
  because the file on disk is the *new* one and the damage was to a *read in
  progress*. INSTRUMENTS.md already says "if you must fork, an in-flight run
  must not see your edits"; this is the mechanism behind that sentence, and it
  applies to every file the run will still open — including the ones it calls
  only at the END, which is the easy one to forget. `mtcheck.sh` invokes the
  scorer after the last target, hours later.

  So: **before editing any harness file, check whether a run is executing it or
  will still source it**, and if so copy it to a name that says why, or wait.
  `pgrep -af <script>` answers the first half; reading the script for what it
  invokes late answers the second.

- **A LONE BACKQUOTE IN A `#` COMMENT CAN BREAK A SHELL SCRIPT 150 LINES
  AWAY — AND IT PUT THE TIP OF THIS BRANCH IN A STATE THAT COULD NOT
  CONFIGURE, FOR A DAY.** Measured, not theorised: `multi-target-0` at
  `a5cd237d9db` died with

  ```
  gen-target-manifest.sh: line 372: syntax error near unexpected token `('
  make: *** [Makefile:4779: configure-gcc] Error 1
  ```

  **While the shell scans for the closing backquote of a multi-line command
  substitution it does NOT honour `#` comments.** `e02b705aeea` added two
  comment lines in the house `` `foo' `` style *inside* the substitution
  assigned to `gcc_mt_data`, each contributing one backquote; the parity of
  every backquote after them flipped, and the damage surfaced on **line 372,
  an unrelated comment that had been legal for months**, whose backquote now
  *opened* a substitution containing `struct GTY(())`.

  Three things, and the last is the general one:

  - **The diagnostic names the victim, not the cause**, and the victim is a
    line nobody touched. `sh -n` over the FILE at five commits localised it in
    seconds; reading the reported line cannot.
  - **The commit that introduced it was itself about comments that lie** — it
    corrected three source comments citing calibration scripts that were never
    committed, and broke the build with the prose of the correction. The
    agent that fixed it then **reproduced the bug while writing the warning
    about it**, by spelling the warning with backquotes inside the block the
    warning is about.
  - Same family as the heredoc case two bullets down and as
    `s-macro_list`: **shell text that reads correctly is not shell text that
    parses.** `mt-conf.sh` now runs `sh -n` over every `$SRC/gcc/*.sh` before
    configuring, because a loud failure nobody runs is a silent one.
- **Build your own build dir.** Sharing `/tmp/b-objs` produces meaningless
  verdicts and spurious `mv: cannot stat tmp-*` failures; it has killed runs.
  **In a shared build dir, a file you did not write is not a fixture.**

  **AND `/tmp/b<task number>` IS NOT YOUR OWN.** Measured live: an agent
  configured `/tmp/b141`, built it, took a full green set — and mid-task
  `$D/gcc/Makefile` vanished and `config.log` came back naming *another*
  worktree, because a second agent had reconfigured the same path. The srcdir
  assertion caught it by name, which is that guard finally firing on a live
  event rather than a historical one. Task numbers are handed out in
  neighbouring blocks, so they collide by construction. **Name the build dir
  after your worktree** (`/tmp/b-<worktree suffix>`), and re-run anything you
  measured before the collision: the readings were in fact identical, and were
  still discarded, because you cannot show the other agent was not building in
  that tree while you measured.
- **A generator or configure script can fail and exit 0** — four times. One `'`
  in a comment truncated a block out of a generated makefile; a backtick in a
  heredoc comment wrote nothing and silently defaulted all 97 capability keys.
  Read `config.log`; check the artefact, not the exit status.
- **`config.status` re-uses cached substitutions — `--recheck` is required**, in
  the full shell.
- **A quoted `#include` beats every `-I`.** Per-base sources must be compiled
  from `mt-<cpu>/`; the build-root copy opens the primary's headers.
- **Stale `.deps/*.Po`** from a cloned build dir makes objects silently not
  rebuild — it produced a Frankenstein `cc1` that ICEd. **An A/B control across
  `git stash` is not an A/B control** (mtimes refresh). Delete objects.
- **`make` in the wrong directory**: `cc1` builds in `<builddir>/gcc`; at the top
  level you get `No rule to make target 'cc1'` — or worse, `Nothing to be done`
  and exit 0 next to a stale binary.
- `-j16` once failed with **no diagnostic at all** under memory pressure; use
  `-j8`. `pgrep -f` matches its own command line; `pgrep -a` is the tell.
- **Tool-not-found piped into `grep -c` scores 0** — in the direction that makes
  the reference look correct. Assert your tools exist and inputs are non-empty
  before scoring anything.
- `@substitutions@` inside `Makefile.in` **comments** are still substituted, and
  are invisible in `git diff`.
- Immediate vs recursive assignment has bitten three times (`INCLUDES :=`
  dropped a flag; `ALL_GTFILES_H :=` made a late `+=` silently too late).
- Never `2>/dev/null`. Use `cmd > out 2> err` and assert `err` is empty.

## 6. Current acceptance bars

- **stock-compare**: `scratchpad/stock-compare.sh` with an **absolute** `IN`
  (a relative path silently produced a false green, and the negative control
  reported "ok, differs" while comparing two nonexistent files) —
  **5/5 IDENTICAL** vs `/tmp/b-stock` (genuine upstream at merge-base
  `c31b7a09eea`), distinct md5s per side, negative control firing.
- **Probe scoreboard — DO NOT QUOTE A FIGURE FROM THIS FILE. Run the harness
  and read what it prints.** The figures below are a record, not a reading.

  **The instrument died and nobody noticed for a day.** `macro-probe-run.sh`
  exited **rc=9 before probing anything** — arm 0's INT control had been
  re-anchored to `STACK_POINTER_REGNUM`, which was then converted to a runtime
  call, and a call is not an integral constant expression. Every figure quoted
  in that window was **the last successful run's**, propagated into brief after
  brief as if current. **A control anchored on a macro this project is
  converting is a control with an expiry date**; the comment above that control
  had predicted exactly this death, about a *different* macro, and nobody
  applied the sentence to the control's own witness. It is re-anchored to
  `MIN_UNITS_PER_WORD` (i386 4, aarch64 8, mt 4), measured in all three
  contexts first, with 0/1-valued candidates rejected because a defaulted 0 is
  indistinguishable from a correct reading.
  **THE TRUSTED COUNT IS ZERO.** Re-measured 2026-08-13 after the probe
  controls were rebuilt on harness-written fixtures:

  ```
  149 on the board = 71 unconverted + 32 TAB + 37 EXIST + 1 UNION + 8 debt
  probing 81 macros;  i386 81/0;  aarch64 PASS 5 / FAIL 76
  aarch64 5 = 4 redirect-vs-itself (UNTRUSTED BY CONSTRUCTION) + 1 other
  ```

  and the single "other" is `MAX_BITS_PER_WORD` reading **64 in all three
  contexts** -- target-neutral agreement, wrong-reason shape 2. So **no
  aarch64 header pass is currently trusted.** Earlier claims of 2, then 1,
  were each one wrong-reason green short of this. **Do not diff 216 arms
  against 162**: the difference is the retire set growing, which is
  legitimate retirement, not loss.


  Current reading, **which the harness now prints with its own decomposition**
  rather than leaving it to prose here: **216 arms over 108 macros — i386
  108/0, aarch64 29/79**, where the 29 is **2 trusted +
  27 `UNTRUSTED-redirect-vs-itself`**, each tagged in the listing. The rise
  from 8 to 29 is **21 more macros having become target-neutral, which is not
  progress**; the trusted count is unchanged at **2**. The board is
  **149 macros = 75 unconverted + 32 TAB + 9 EXIST + 33 with no arm at all**.

  The decomposition moved from prose here to computed-at-the-point-of-print
  **because the raw number was quoted anyway, twice, after a warning not to.**
  If a caveat has to be remembered, it will not be.

  **THE "TRUSTED 2" WAS NEVER 2.** `MAX_BITSIZE_MODE_ANY_MODE` had **already
  been converted** by the genmodes union (i386 1024, aarch64 8192, shared
  8192) while the board said `UNCONVERTED` — the completeness gate derives
  conversions from `defaults.h` redirects plus a hand list, and **a union
  macro is in neither**. Both base contexts therefore read 8192, so its header
  arm was green for target-neutral-agreement and **was banked as one of the
  two trusted passes**. Trusted is **1**. A sixth probe shape,
  `union-probe.sh`, exists because no other shape can score a union macro: the
  number is deliberately identical, so every other arm is green by
  construction.

  **THE aarch64 CODEGEN BAR IS FILENAME-SENSITIVE AND WAS QUOTED WITHOUT ITS
  INPUT.** `-S` emits a `.file` directive, so the same compiler on the same
  source gives 369 / 371 / 373 bytes for `x.c` / `one.c` / `mtbar.c`. The
  recorded "373 bytes / `b01d9157fdc1`" is reproduced by **any seven-character
  basename** — it is evidence about a filename, not about codegen. **Never
  quote that bar without the input path**, and prefer a diff against a control
  to a byte count.

  **A FALLING PASS COUNT IS THE SHAPE OF SUCCESS HERE.** Closing the arm debt
  took the aarch64 header PASS column **29 → 3**, and that is the good
  outcome: 29 was 2 trusted + 27 `UNTRUSTED-redirect-vs-itself`, 3 is 2
  trusted + 1, and **the trusted count never moved.** Twenty-six untrusted
  greens were exchanged for arms that can fail. Anyone reading the raw total
  as a regression has read it backwards — which is precisely why the harness
  now prints the decomposition rather than trusting a reader to remember it.

  **A THRESHOLD CALIBRATED ON A NUMBER THIS PROJECT MOVES IS THE SAME BUG AS
  THE DEAD CONTROL.** `macro-probe.sh` carried `[ NMACRO -ge 100 ]`, which
  refused a *correct* run at 82 after macros retired to other arms. The fix is
  not to lower it to 80 — that expires at the next retirement and is
  indistinguishable from moving a number to make a check pass. It is now the
  identity `NMACRO + |RETIRED ∩ ALL| == |ALL|`. Its first draft immediately
  earned its keep by firing on something else: **11 board macros had never
  been in `macro-probe-list.txt` at all**, because they never had a header
  arm.

  This line was reconciled after two documents disagreed, and **both were
  partly right on the same board**: this file had #92's retire-3 but not
  #108's six (2 / 110); STATE.md had #108's six but not #92's retire-3
  (5 / 104 + 6). `5 − 3 = 2` and `104 + 6 = 110` — the arithmetic closes, but
  it was settled by re-running the harness, because closing arithmetic is
  exactly how a wrong shared number survives. #92's retire-3
  (`FIRST_PSEUDO_REGISTER`, `N_REG_CLASSES`, `REGNO_REG_CLASS`) was a
  **correction, not a regression** — same wrong-reason flip as the six, caught
  rather than banked; they are `CONVERTED_REGS` and carry TAB arms that read
  the running `cc1` against each base's own headers.

  Earlier figures, kept because each was quoted after it stopped being true.
  230/58 with aarch64 5/110 and 24/5 is the pre-#92 state and is now stale.
  (An earlier version of this line said aarch64 2/113. That is stale and was
  arithmetically impossible at 230 arms — 113+2 = 115 macros; the 2/113 figure
  belonged to the 266-arm era before 18 macros were retired to TAB. Two agents
  measured 5/110 independently. **If a number in a brief cannot be reconciled
  with the arm count, say so rather than reporting against it.**)
- **Stderr**: the **incremental** floor is **at most 32 lines** — 8
  `is unchanged` + 24 `'@' is redundant` from unmodified aarch64 `.md` files,
  because those rules write through `move-if-change` with no stamp. **It varies
  with what was last rebuilt**: a no-op `make` in a dir whose `.md` rules had
  not re-run gave **8**, with the 24 absent entirely. Quote the composition you
  measured, never a remembered number.

  **A cold build is NOT empty** — an earlier version of this file said so and it
  is false on this host. A cold `all-gcc` is ~870 lines, ~370 of them
  `warning:`, dominated by `-Wmissing-field-initializers` and
  `-Wunused-parameter` from **nixpkgs gcc 15.2 compiling GCC** — host-compiler
  noise, not this tree. Figures of 664 / 698 / 867 are all the cold arm and are
  not comparable with the 32.

  So: classify against the 32-line composition for incremental, and against a
  recorded cold baseline for cold. **Never quote a stderr number without saying
  which arm it is.**
- `make cc1` rc=0 and `multi-target-objs` rc=0.

## 7. Reporting

**A TASK NUMBER IN YOUR BRIEF IS NOT SOMETHING YOU CAN READ.** The task list
lives in the coordinator's tooling; it is not in the worktree, and `STATE.md`
has sections for only some of it. A brief saying "read tasks #59, #56, #53"
is asking for something you do not have. **This is the coordinator's error,
not yours.** Say so plainly in your report, work from the measured evidence
and from `STATE.md`, and do **not** report against numbers you could not read
— an agent that quietly writes "#56: done" because the brief mentioned it is
manufacturing a green. One agent hit exactly this, said "these six are not in
this worktree", and worked from the wall it could measure instead. That was
the right response.

Coordinator's side of the same rule: **inline the content, not the pointer.**
If a task's finding matters to the brief, quote the finding.

**COMMIT YOUR WORK BEFORE REPORTING IT DONE.** Twice now an agent has reported
a change as "landed" and left it uncommitted in its worktree — once 65 lines,
once 15 files and +881/−332. The coordinator then has to read the diff and
commit it on your behalf, which is slower and puts an unreviewed change in
someone else's hands. `git diff --cached` before committing (the index is
shared), then `git log --oneline -1` to confirm the commit exists.

**"No `AC_ARG_*` and no assignment" does NOT mean a variable is unsettable.**
Generated `configure` auto-assigns `with_X` / `enable_X` from the command line
even with no `AC_ARG_*` for them. A naive scan for unsettable variables reports
**~40 false positives**; the genuinely unsettable set is small. Force the
variable and observe the branch before believing it is dead.

**When every arm of your probe reads empty, that looks exactly like "branch not
taken."** An agent's probe harness was wrong four ways and **all four failed
towards its hypothesis** — because an all-empty read is indistinguishable from
the thing it was trying to prove. Add a non-vacuity FATAL: the harness must
refuse to score when it cannot show it read anything at all.

**A count check passes when two errors cancel.** Measured: a generated
`global_options_init` had **1674 elements for a 1669-member struct** — five
invented and two missing. All the compiler said was `too many initializers for
gcc_options`. It noticed the *count* and nothing about the **1656 misplaced
values** — and had the five and the two been equal, it would have said nothing
at all while every member after the first divergence held another member's
value. Compare bodies, offsets and names; a count is the weakest evidence
available and is silent in exactly the case that matters.

**BEFORE A CHECK CLEARS A HYPOTHESIS, ASK WHETHER IT COULD HAVE FIRED — THREE
TIMES IN ONE SESSION THE ANSWER WAS NO, AND EACH TIME THE CLEAN RESULT READ AS
CONFIRMATION.** This is the session's dominant failure mode and it is worth
recognising by shape rather than by instance:

| the claim | the "evidence" | why it could not fire |
|---|---|---|
| the specs fix caused the cselib ICE | a no-specs fixture compiled "clean" | the fixture had been `rm -rf`'d; `xgcc` said *no target selected*, produced no object, and the grep was for the ICE string, which that message lacks |
| the `sed` was correct | paren balance; no `FIRST_PSEUDO_REGISTER` left inside the replacement | both ask *is the output well-formed*; the bug was *did the match start where I meant* — clean on 16 corruptions |
| aarch64 is immune to the cselib bug | aarch64 codegen byte-identical, fixed vs unfixed | measured at `-O2` **without `-g`**, and `cselib` is reached through `vartrack`, which only runs with debug info — the affected path was never entered |

Each is a check that answers a *different question* than the one being
settled, and a negative from such a check is worth nothing while looking
exactly like a strong result. **State the question your check asks, out loud,
and compare it to the question you need answered.** If they differ, the clean
result is not evidence.

The third row also carries a second lesson: **a figure measured at one base
count does not survive a change in the base set.** The union
`FIRST_PSEUDO_REGISTER` is **95 at two bases and 128 at four**, so "aarch64's
own value equals the union" was true when recorded and false when reused —
and at four bases *every base except the widest* has a misclassified band.
Re-measure a union width in the configuration you are actually in.

**A CHECKLIST OF OUTPUT PROPERTIES CANNOT SUBSTITUTE FOR A FIXTURE WITH
KNOWN-BAD CASES, BECAUSE YOU CAN ONLY CHECK FOR CORRUPTIONS YOU ALREADY
IMAGINED.** This is the general statement; the episode below is one instance
of it, and the instance is less important than the shape.

A bulk `sed` converting 176 register classifiers was run behind two
hand-written pre-checks — paren balance, and "no `FIRST_PSEUDO_REGISTER`
survives inside the replacement". **Both came back clean on a tree with 16
corruptions in it, and neither could have done otherwise**, because both
answer *is the output well-formed* and the actual question was *did the match
start where I meant*. The pattern was rooted at `REGNO (` and matched the TAIL
of `DF_REF_REGNO (use)`:

```c
if (DF_REF_!HARD_REGISTER_NUM_P (REGNO (use))
```

— an orphaned identifier prefix, same substring family as
`grep "define PRINT_OPERAND"` matching `PRINT_OPERAND_ADDRESS`. The compiler
caught it: the cheapest detector available and, on that route, the LAST one.

**Then the corrected pattern matched NOTHING and looked identical to a clean
tree.** `\<\([A-Za-z_][A-Za-z_0-9]*REGNO\)` requires at least one character
before `REGNO`, so it cannot match bare `REGNO` at all — the null-result-as-a-
pass shape, arriving inside the regex this time, and invisible to every
output-property check by construction: an unmodified file has perfect paren
balance.

So the two failure modes are **matched too much** and **matched too little**,
and no amount of inspecting the *output* distinguishes either from success.
Only an input with known answers does.

- **Test the pattern on a FIXTURE containing every shape, INCLUDING the ones
  that must not match, and read the output before touching a file.** Six lines
  sufficed: bare `REGNO`, nested `REGNO (SUBREG_REG (x))`, prefixed
  `DF_REF_REGNO`, `ORIGINAL_REGNO`, a `for`-loop bound, and an array-size use.
  The last two must come through UNCHANGED — a fixture is the only thing that
  shows a negative case staying negative. Both failures were visible in that
  output in under a second; each had already cost a twenty-minute build when
  found the other way.
- **Word-anchor every identifier** (`\<`) and make the prefix group OPTIONAL
  rather than required.
- **Leave a standing tripwire for the substring victims**, not a one-time
  verification. `mt-rename-sweep.sh` now asserts that the prefixed `*_REGNO`
  identifiers are intact in the tree, because the next agent to sed anything
  regno-shaped will meet this same trap and the same two clean-looking checks
  will pass for them too.

**`awk '$0 ~ f'` ON A DEMANGLED C++ NAME MATCHES NOTHING.** The `()` in
`foo(rtx_insn*)` is an **empty regex group**, so the pattern matches nothing
and six object-level arms scored EMPTY — which reads as *"there is no per-base
copy"*, the opposite of the truth. Use `index($0, f)`. Sibling case: an `nm -C`
sweep anchored on `$` scored zero definitions for twelve of fourteen entry
points, the two that "worked" being function *pointers* with no argument-list
suffix.

**"There is no fallback for this macro" is NOT "this macro is not yet
defined."** An agent skipped the `#undef` when redirecting `FUNCTION_MODE`,
reasoning correctly that `defaults.h` has no fallback for it — but **the
primary's `i386.h` has already been read** by that point. `rc` stayed 0, the
redirect still won, and **the only signal was 495 warnings**. Always `#undef`
before redefining, and treat a warning-count change as a finding rather than
noise.

**`python3` IS NOT IN THE DEV SHELL, and a script that "runs" without it can
score a false green.** An injection arm written in Python did **nothing** —
`python3: command not found` — so every downstream reading was of the
*unmodified, fixed* compiler. It was caught only because that arm asserted
both halves of every hunk were actually gone; a "did it still build?" check
would have passed cleanly. Use `awk`/`sed`, and **assert that your injection
produced the state you intended** rather than that it exited. (A sibling case:
an injection deleted a `#define` but left the matching `#undef`, so the macro
became *undefined* rather than the primary's — the injection ran, and produced
a third state nobody was testing.)

**Your grep's `--include` list can exclude the answer.** Real case: a search for
what invokes `gen-reg-widths.sh` used `--include='*.in' --include='*.ac'
--include='*.sh' --include='Makefile*'` and concluded **nothing invoked it**.
The invocation is in a `*.awk` file, emitted into the *generated* makefile. That
is rule 1 of this section, committed by the person who wrote it. **Search the
generated artefact, and check what your filter excluded before believing a
zero.**

**`nm -u` with a plain-name grep can score 0 on C++ symbols — but check which
part failed.** Measured one way: nine of `function.o`'s ten undefined `ix86_*`
references are mangled, so a sweep built that way called the file clean.
Measured the other way, later: plain `nm -u | grep ix86_` scores the same as
`nm -uC`, because `_Z13ix86_cfun_abiv` *contains* the substring — the 0 needs
`grep -w` or `^`. **So the lesson is about the pattern, not the tool.** Use
`nm -uC`, and know which of the two you are relying on.

**One symbol can have several macro paths.** `ix86_cfun_abi` survived after
`STACK_BOUNDARY` was converted, because `function.cc` also spells
`ACCUMULATE_OUTGOING_ARGS`, which also expands `TARGET_64BIT_MS_ABI`. Closing
the path you found does not close the symbol; re-measure rather than assuming. This is the same shape as the
`T D B R` filter hiding COMDAT, and as `internal_dfa_insn_code` scoring 0
because it is a function on one back end and a pointer on another: **a zero from
a name-matching instrument is a claim about the instrument, not the code.**

**A symbol's name does not tell you which macro pulled it in.** `function.cc`
references `ix86_local_alignment`, which comes from `STACK_SLOT_ALIGNMENT` — not
from `LOCAL_ALIGNMENT`, which the name suggests and which that file never
spells. Converting the macro the symbol implies converts one nothing uses.

**An exit status of 0 is not evidence a pipeline succeeded.** Real case found
this session: `s-macro_list` ICEd and exited 0, because the ICE was the *head*
of a pipeline whose status is the last command's (`sort`'s). An empty
`macro_list` shipped and `fixinc.sh` read it as "nothing is predefined". Use
`set -o pipefail`, or check the artefact.



**A SINGLE RUN CANNOT TELL "THIS BACK END EMITS" FROM "THIS BACK END CORRUPTS
THE HEAP", AND IT FAILS TOWARDS THE GREEN.** Measured (`ta76-flaky.sh`):
mips64 at `-O2`, same `cc1`, same input, same config, twelve runs —

```
5  rc=0  md5 ec1e83b08653      emits 4262 bytes
7  rc=4  md5 725f91e9fac0      SIGSEGV in GIMPLE `fixup_cfg'
```

and ia64 gives **five distinct outcomes in eight runs**. The first mips run
taken returned rc=0 and would have gone into the table as *emits*. So for any
back end newly reaching codegen, **run it N times and require one outcome**;
`STABLE` is an arm, not an assumption. The pay-off is not only avoiding a
false green: instability is itself a *diagnosis*. It says memory corruption
rather than a missing per-base answer, which is a different search entirely —
and it reclassified two walls the brief carried as unrelated (a hang, and
`free(): invalid size`) into one class.

Corollary that cost a session in the other direction: **gdb disables ASLR, so
a corruption bug can vanish under the debugger.** mips faulted 7 times in 12
outside gdb and *never* inside it. "It does not reproduce under gdb" is
evidence about the bug's class, not evidence that it is gone.

**RUN THE INFERIOR FROM gdb, NOT `gdb -p` — AND THEN A HANG REPORTS LIKE A
CRASH.** This host's `ptrace_scope` refuses attaching to a non-descendant, so
`gdb -p` answers `ptrace: Operation not permitted` and a spinning `cc1`
becomes "the spin site is unlocated" — which is where mips's non-termination
sat for a whole task. Launching with `gdb --args` makes the inferior a
descendant, and `timeout -s INT <n>s gdb -batch -x cmds` then interrupts it
and runs `bt` exactly as it would after a signal. One script covers SIGSEGV,
SIGFPE, SIGABRT and non-termination. `scratchpad/ta76-gdb.sh`.

**A LEAKED ANSWER THAT IS TOO SMALL DELETES CODE, AND THAT IS A DIFFERENT
SEARCH FROM A LEAKED ANSWER THAT IS WRONG.** `EPILOGUE_USES` was i386's in
`df-scan.cc:3647` — the only shared consumer — so the registers a back end
needs live on return were simply absent from the exit block's use set.
Dataflow then concluded the instructions writing them were dead and **DCE
deleted them**. On aarch64 SME2 that emptied every ZA-writing function to a
bare `ret`: rc=0, empty stderr, a well-formed `.s` that a real cross assembler
accepts, and **9,050 FAILs in one directory where stock fails zero**.

Three transferable pieces:

- **The compiler emitting LESS code is a leak symptom, and nothing in this
  project's instrument set was looking for it.** ICE counts, error counts,
  assembler acceptance and `readelf` all pass on an empty function. The only
  thing that sees it is comparing the emitted body against a control.
- **`defaults.h`'s `#ifndef EPILOGUE_USES` was dead** because `i386.h:1767`
  defines the name first — the `REGMODE_NATURAL_SIZE` trap already in this
  file, in a new place. **25 of 47 back ends define the macro**; all 25 were
  answered by i386.
- **It was worth a latent wrong-code bug on a target nobody was looking at.**
  `riscv_epilogue_uses` returns true for `RETURN_ADDR_REGNUM` unconditionally,
  so `ra`'s restore was dead and DCE removed it — in a function ending in a
  sibcall, which would then return through a stale `ra`. Found by the
  both-sided arm, at `-O2`, in ordinary code with no SME anywhere near it.

**ASK WHETHER THE FAIL COLUMN IS COMPILE FAILURES OR WRONG CODE BEFORE
INVESTIGATING ANYTHING — THEY ARE DIFFERENT SEARCHES AND THE COLUMN DOES NOT
SAY.** One classifier (`a5764a65f9eec0063-kinds.sh`) split the four ACLE
directories in seconds and redirected the whole task:

```
sme2/acle-asm   FAIL 9050   BODIES 8926  COMPILE 124   <- wrong code
sve/acle        FAIL 4034   BODIES    0  COMPILE 2016  <- a DIFFERENT bug
```

**`sve/acle` and `sve2/acle` have ZERO `check-function-bodies` failures**, so
a cause whose entire effect is wrong emitted code cannot explain them — a
one-line result that would otherwise have been an afternoon of assuming the
cluster was homogeneous because it looks homogeneous.

**AND A DEFECT CAN HIDE BEHIND ANOTHER DEFECT, IN THE DIRECTION THAT MAKES THE
FIRST LOOK WORSE.** With `EPILOGUE_USES` fixed, `sme2`'s COMPILE column ROSE
124 -> 744 while its FAIL total fell 9050 -> 744. Nothing had regressed: the
instructions were now reaching the assembler for the first time, and the
assembler was refusing them because
`ASM_DECLARE_FUNCTION_NAME` — **also i386's**, `varasm.cc:2218` — meant
aarch64 never emitted the per-function `.arch` directive `#pragma GCC target`
needs. Fixing that took the directory to **37,594 / 0, parity with stock.**

So: **a rising sub-count beside a falling total is not evidence of a
regression, and neither is it evidence of progress.** Read what the new
failures actually SAY. Here the difference between "my fix broke 620 tests"
and "620 tests got far enough to fail somewhere new" was one line of assembler
diagnostic — and the first reading was the natural one.

Corollary, paid for twice in that same hour: **`mtcheck.sh` writes every run to
the same `gcc.sum`/`gcc.log`**, so a second run destroys the first's
artefacts, and the destroyed file reads as a present one. The `.rc` stamp says
a run FINISHED; it does not say the file still belongs to that run. Copy both
artefacts to a run-specific name before starting anything else.

**A THIRD INSTANCE OF "THE BOUND IS THE UNION'S, THE NUMBERING IS PER BASE",
AND IT IS THE COMMONEST REMAINING SHAPE.** `MULTI_TARGET_UNION_*` is the
LAYOUT; a **loop** or a **`memcpy` length** must be the selected base's own
count. Two live ones found in one task:

- `reginfo.cc:simplifiable_subregs` walked `0 .. FIRST_PSEUDO_REGISTER` (the
  union's **334**, ia64's) asking `targetm.hard_regno_nregs`, which rs6000
  answers from a table **119** wide. Measured arrival: `xregno = 238`. The
  fault was an FPE in `subreg_get_info` because the out-of-bounds read said
  *zero registers*. Its own sibling twelve hundred lines up already had the
  right bound **and a comment saying the short-circuit in front of it must not
  be relied on** — this loop had no short-circuit at all.
- `memcpy (reg_alloc_order, <own>_alloc_order, sizeof (reg_alloc_order))` in
  arm, arc and nds32, and the same on `fixed_regs`/`call_used_regs` in rx.
  Upstream the two widths are one number, so `sizeof` of either was correct;
  here it reads off the end of the back end's own array.

So: **grep for `sizeof` of a shared union-sized array inside `config/`, and
for `< FIRST_PSEUDO_REGISTER` / `< N_REG_CLASSES` in shared code that then
calls a `targetm` hook with the index.** Those two greps are cheap and each
found a live crash. `MT_FIRST_PSEUDO_REGISTER` and `MT_N_REG_CLASSES` exist
precisely so a site can say which of the two it means.

**NAME BUILD DIRS AND SNAPSHOTS AFTER THE FULL WORKTREE ID.** A coordinator
sweep of `/tmp/b-*` and `/tmp/snap-*` deleted 207 directories with a guard
that matched worktree-id **substrings** and protected nothing; four builds and
their snapshots went with it. `/tmp/snap-a76e99-f` is not a name a guard can
recognise. Use `/tmp/b-<full worktree id>` **and** `/tmp/snap-<full worktree
id>`, and re-measure anything that was in flight — a build dir deleted under a
running `make` gives results untrustworthy in both directions, and a vanished
object looks exactly like the ICE class you are hunting.

**A FOURTH INSTANCE OF "THE BOUND IS THE UNION'S, THE NUMBERING IS PER BASE",
AND THIS ONE IS NOT AN ARRAY BOUND AT ALL — IT IS A BIT POSITION (#185).**
`AARCH64_APPROX_MODE` (`aarch64-protos.h`) is `1 << (MODE - MIN_MODE_FLOAT)`.
Upstream that is a dense index over aarch64's own **5** float and **55**
vector-float modes, so the shift is at most 59 and a `uint64_t` is the right
width. Here `MIN_MODE_FLOAT` .. `MAX_MODE_FLOAT` are the shared numbering's,
which is **10 and 210** at 47 bases, and the shift reaches **219**. Measured in
a `cc1` with `mt-aarch64/aarch64.o` rebuilt `-fsanitize=shift`:

```
aarch64.cc:17140 / :17205 / :17316   shift exponent 136 is too large for
                                     64-bit type 'long unsigned int'
```

Four things worth carrying, and the first three are corrections to the brief:

- **The magnitude is a function of base MEMBERSHIP, not base COUNT, and it had
  already SATURATED.** 2 bases → 76, 3 → 83, 4 → 204, 11 → **219**, 47 →
  **219**. The eleven-base set already holds both ends of the range (riscv's
  RVV, aarch64's SVE `VNx8DF`), so thirty-six further back ends moved it by
  zero. Same shape as the `type_natural_mode` correction above: *"it appears at
  N and not at N−1" is not evidence that N is the cause.*
- **The two-base build reproduces it (76 > 63).** "A small build cannot show
  this" was wrong, and in the direction that costs a day of build time.
- **The in-range cases were wrong too, silently.** `V4SF` got bit 35 where a
  single-target aarch64 gives it bit 11. Only the UB is loud; the whole bit
  assignment was another base set's. So *"is the shift defined"* and *"is the
  bit the right bit"* are two questions, and fixing the first without the
  second would have been a half-fix that passes UBSan.
- **Grep for a mode-ordinal difference used as a SHIFT, separately from one
  used as an INDEX.** Ten other `- MIN_MODE_` sites exist (`expmed.h`,
  `real.h`, the `BUILT_IN_COMPLEX_*` range in `tree-core.h`) and every one
  indexes an array whose bound is *the same union quantity*, so bound and index
  agree and they are correct. The bit-position one is the outlier because its
  bound — 64 — comes from nowhere near the mode machinery and so cannot track
  the numbering.

The fix is the settled split, and it generalises: `genmodes` now emits
`mode_class_index[]` (this base's dense 0-based position for a mode within its
class, `0xffff` for a hole) and `class_num_modes[]` (this base's own count per
class), both on `MT_MODE_TABLES` beside `class_narrowest_mode`, which was
already the same split for the same reason. **Reach for those two whenever a
back end wants "which one of MY modes of this class is this".**

Method note, because the null result here has a specific shape: **"UBSan
reported nothing" and "UBSan was never enabled on that translation unit" are
the same empty log.** `a51a0e8b2b458063b-ubshift.sh` refuses to score until it
has seen `__ubsan_handle_shift_out_of_bounds` as an undefined reference in the
rebuilt object, and exits 9 rather than 0 otherwise. And the reproducer needs
**SVE**: Advanced SIMD's shifts (20 .. 37) are in range, so a plain `float`
loop at `-Ofast` reports nothing and looks exactly like a fixed compiler.

And one near-miss worth the line: this task **overwrote the snapshot directory
its already-configured PRE build dir pointed at**. Nothing failed — a build dir
re-reads its srcdir long after configure (`mt-bars.sh` takes `big.c` from it;
rebuilding one object recompiles *its* source), so the next arm would have
compiled the FIXED header and reported the bug gone, with a green everywhere.
**Put the sha in the snapshot path**, not just the worktree id.

**A FIFTH LEAK SHAPE: A BARE `#ifdef` ON A NAME THE PRIMARY *DEFINES*. NO
FLOOR ANYWHERE, SO NO FLOOR SWEEP CAN SEE IT — AND IT LEAKS PRESENCE AND VALUE
AT THE SAME TIME.** `INSTRUMENTS.md`'s four classes all involve a `defaults.h`
`#ifndef` or a generated header. `EH_RETURN_STACKADJ_RTX` has neither:
`i386.h:2187` defines it, shared code asks `#ifdef`, so the guard is **true for
all 47** and the register inside is the primary's. `CX_REG` is 2; on riscv,
register 2 is `sp`. `except.cc`'s
`emit_move_insn (EH_RETURN_STACKADJ_RTX, crtl->eh.ehr_stackadj)` therefore wrote
riscv64's stack adjustment **into the stack pointer**, while riscv's own
epilogue (compiled per base, and correct) still read `a4`, which nothing set.
The same `#ifdef` also ran the guarded code for the back ends that define
nothing. Sweep for it as: *a bare `#ifdef <NAME>` in a shared TU where `<NAME>`
IS defined by the primary and by some other back end with a different body.*

**AND A LOUD LEAK CAN MASK A SILENT ONE ON THE SAME CONSTRUCT, SO ASK WHAT THE
DIAGNOSTIC WAS PREVENTING BEFORE YOU REMOVE IT.** `EH_RETURN_HANDLER_RTX`'s
floor makes `__builtin_eh_return` **error out** on aarch64 and s390x. That
error is the only thing keeping those two targets away from the
`EH_RETURN_STACKADJ_RTX` bug above. Fixing the handler alone — the obvious,
well-evidenced, single-macro change — would have converted a diagnostic into
wrong code **on two further targets**, and every instrument this project owns
would have scored it as progress. The rule is the `EPILOGUE_USES` /
`ASM_DECLARE_FUNCTION_NAME` rule stated forwards: when you are about to delete
a diagnostic, find out what runs next.

**AND THE BUG ABOVE WAS FOUND BY REPAIRING AN INSTRUMENT, ON ITS FIRST RUN
AFTERWARDS.** `agent-a992b7e5fa4ffaaa7-ehreturn.sh` hardcoded another
worktree's build dir, had no non-vacuity arm, and printed multi-target's `rc`
with **no control**. Repaired to diff against genuine stock, it immediately
reported `riscv64 rc=0 DIFFERS from stock` about a target the handover note
recorded as **passing** — because `rc=0` was the only thing the old script
could see. *Repairing a known-bad instrument is not overhead deferred from the
real work; on this branch it has twice been the fastest route to a new
defect.*

Say what you measured, what you did not, and what your instrument cannot see.
**A measured "still cannot be checked, because X" is a useful result; an
unexamined pass is not.** Distinguish upper bounds from lower bounds explicitly
and never quote one as the other. If a number in your brief is stale or
impossible, say so rather than reporting against it.

---

## PASSING TESTS COME BEFORE SIMPLIFYING, BECAUSE THEY ARE WHAT MAKES "WAS THIS NECESSARY?" FALSIFIABLE

The user's ruling, and the reasoning is the part to keep:

> The main thing now is getting those tests passing for as many back ends and
> front ends as possible.  **Only then are we able to ask "was this really
> necessary?"** — because it is hard to falsify a claim that something *wasn't*
> necessary while we are still failing tests, or worse, haven't bothered to
> test something.

This branch has accumulated many mechanisms — `targ_caps`, `target-cdata`,
`target_frame_desc`, the `target-*.h` selectors, `MULTI_TARGET_UNION_*`, the
`MT_*` runtime forms, `MULTI_TARGET_RENAME_NAMES`, per-base headers,
`modes-union.list` settings.  Each was justified locally, and cutting the set
down is a real goal.  **It is not a goal to pursue yet**, and the reason is
epistemic rather than aesthetic:

**"Mechanism X was unnecessary" is a claim about what breaks without X.  A
passing test suite is the instrument that can refute it.**  Remove X, rebuild,
re-run: something fails, or nothing does.  That is an experiment.

**Without passing tests the claim is unfalsifiable in the worst way — it looks
supported.**  Remove X while a target is still failing 500 tests and it fails
501, or 500, and neither number tells you anything.  Remove X for a target
nobody has ever run and the silence reads exactly like success.  **A back end
with no test results cannot notice the loss of anything**, which is precisely
the condition nine front ends and nineteen back ends are in today.

Note the asymmetry with everything else in this file.  Elsewhere the danger is
a check that cannot fire; here the danger is a *simplification* that cannot be
contradicted.  It is the same defect wearing different clothes: **an
unfalsifiable claim and a null result are the same object**, and this project
has spent more time on that one shape than on all its compiler bugs together.

So: **tests first, then the necessity question, then the cuts.**  When the
survey in the consolidation task is written, every proposed merge must name the
experiment that would refute it — and that experiment must be runnable on the
back ends that would be affected, which means those back ends must already be
scoring.

---

## TESTING *ALL* BACK ENDS IS THE POINT, NOT A THOROUGHNESS PREFERENCE

The user's statement of why, and it is the argument for the whole exercise:

> Testing **all** back ends, not just some, is the only way to make sure we
> catch all the assumptions we might compile in by mistake.  And test all the
> front ends too.

**A leaked assumption is invisible from any set of targets that shares it.**
That is not a probabilistic claim about coverage; it is a structural one.  The
primary's answer reaching everyone can only be *seen* by a target that would
have answered differently, so a board of targets that agree measures nothing
about the axis they agree on.

**The worked proof, and it was luck rather than method.** Every target this
project has ever scored against a stock control — x86_64, aarch64, riscv64,
s390x — is **LP64**.  `ASM_OUTPUT_ADDR_VEC_ELT` was i386's for all 47 back
ends, 38 definers with 34 distinct bodies, and it emitted `.quad` where aarch64
and riscv64 index a **4-byte** table: `.rodata` exactly twice the size the
code reads, entries unscaled where the `add` scales by 4.  **It was caught only
because two of those four happen to use RELATIVE jump tables.**  Had all four
used absolute tables, i386's answer would have looked correct on every scored
target and the divergence would still be live.

So the coverage gaps are not "less confidence" — they are **specific classes of
defect that cannot be detected at all**:

  * every scored target LP64        => pointer width, word size, `Pmode`
  * no 32-bit target                => `INT_TYPE_SIZE` (six back ends ask for
                                       16; `sizeof(int)` is 4 on all of them)
  * nine front ends never built     => their own `tm.h` readers, their ABIs
  * nineteen back ends never scored => whatever only they would disagree with

**A FIFTH TARGET WAS SCORED AGAINST A STOCK CONTROL AND THE PREDICTION HELD —
BUT NOT ON THE AXIS THIS LIST NAMES.**  `arm-unknown-linux-gnueabihf`, debt
**3,288** (`A660907426E03E4E9-ARM-BOARD.md`).  **89% of it is one cause, and it
is not pointer width**: `TYPE_OPERAND_FMT`.  `defaults.h:260` builds
`ASM_OUTPUT_TYPE_DIRECTIVE` from the primary's `"@%s"`, and **on ARM `@` begins
a comment**, so `.type x, @object` has an empty operand and `as` refuses it.

Two corrections to how this section should be read:

**1. The mechanism is stronger than "invisible where targets agree".**
`aarch64` asks for `%object` too — it is one of the four — and its assembler
**ACCEPTS** `@object`, as do riscv64's, s390x's and x86_64's.  So the defect is
**live and active on a scored target right now** and produces no failure.  The
four did not lack the property; they could not *complain*.  That is a class no
sample size on those four reaches, and it is wider than any list of
target-attribute axes.

**2. The axis this list names appears only derivatively, and it appears in the
HARNESS.**  `check_effective_target_ilp32` is
`check_no_compiler_messages ilp32 **object** { ... }` — the assembler runs — so
`ilp32` reads FALSE on the multi-target arm compiler while that compiler's own
answer (`sizeof (void *) == 4`) is correct and is never consulted.  189
`object`-mode and 116 `assembly`-mode selectors in `target-supports.exp` are
answered by the assembler.  **The compiler was right about the 32-bit axis and
the board could not find that out.**

**BOTH ARE NOW FIXED, AND HOW THE SECOND ONE WAS FOUND IS THE PART TO KEEP.**
arm's debt is **3,288 -> 191** and its scope gap **21,181 -> 874**
(`A9364E5CD42E818AD-TYPEFMT.md`); `ilp32` and `int32plus` read TRUE with the
`lp64` negative control still firing.  But the `.type` fix ALONE did not restore
them.  The arm board offered that as a prediction and was careful to label it
one; it was tested and **it is false**.  `check_effective_target_ilp32`'s body
is `int dummy[...]` with no initializer, so it goes to `.bss` and never reaches
the site that had been fixed — and following the refutation is what found
`emit_bss` routing every back end's uninitialized globals through
`x86_output_aligned_bss` in `i386.cc`.

**Had the prediction been assumed instead of tested, the task would have closed
with the larger leak intact and the whole debt attributed to the smaller one.**
A prediction that would be expensive to be wrong about is worth its measurement
even when it looks obviously right — and this one looked obviously right.

The transferable lesson is to widen the list rather than tick an entry off it:
the four also agree about assembler comment characters, `.align` semantics and
`.type` operand syntax.  **A new target is worth what it DISSENTS about, and
the dissents are not enumerable in advance** — which is the argument for
breadth, not a refinement of it.

**THREE CORRECTIONS TO THE `.align` CLAIM THAT USED TO STAND HERE**, all
measured in `A9364E5CD42E818AD-TYPEFMT.md`, and each is worth more than the
sentence it replaces.

**1. The `.align 4` was real and its stated cause was wrong.**  This paragraph
used to attribute it to `ASM_OUTPUT_ALIGN` being unconverted.  That macro was
already converted, in `7247d7aea83` — an ancestor of the very commit the arm
board was measured on — and arm's `.data` path already emitted `.align 2`
correctly there.  The `.align 4` comes from `ASM_OUTPUT_ALIGN` being expanded
inside `x86_output_aligned_bss`, in `i386.cc`, a per-base translation unit where
the redirect does not apply and the macro is genuinely i386's.  **A converted
macro can still be leaked by an unconverted CALLER.**  That is a fifth leak
shape beside INSTRUMENTS.md's four, and no sweep for unconverted macros can see
it, because the macro is converted.

**2. "`1 << LOG` for i386 and the POWER for the others" is not the shape of the
space.**  Expanded per base rather than grepped for, `ASM_OUTPUT_ALIGN` has
**seven** distinct shapes over 47 back ends: the power (18), `1 << LOG` bytes
(13), `.balign 1 << LOG` (5), `.p2align LOG` (6), pdp11's `.even` with no
operand, nvptx's no-op, and mmix's function call — plus rx switching on
`target_flags`.  A two-class summary of a target-macro's answers should be
assumed wrong until it has been expanded per base.

**3. The defect it pointed at was bigger than `.align`.**  `i386/gnu-user.h:87`
defines `ASM_OUTPUT_ALIGNED_BSS` as `x86_output_aligned_bss`, so shared
`emit_bss` routed **every uninitialized global on all 47 back ends** through
i386's back end — including `i386.cc:973`'s decision to place a variable in
`.lbss` based on `ix86_cmodel` and `ix86_section_threshold`.  arm's `.bss`
placement was being decided by i386's code model.

And the front-end half is not a smaller version of the same point.  **C++ was
enabled for the first time and immediately produced the highest-severity defect
on the branch** — eight back ends emitting an ABI-incompatible pointer to
member function, silently, at rc=0, assembling into correct-machine ELF.
Nothing was looking, because no instrument compiled C++.  `d/` was then found
to carry the same vtable defect **before it had ever been built**.

**Corollary for how to choose work.** A new target or front end that has never
been scored is worth more than another pass over one that has, even when the
scored one has a larger residual — because the unscored one can refute
assumptions and the scored one can only refine a number.  Prefer breadth until
every back end and every front end has produced at least one result.

---

## THE PACKAGING SHAPE, CONFIRMED BY THE USER: THE COMPILER SHIPS BACK ENDS, THE WRAPPER SHIPS TARGETS

Stated to the user and confirmed verbatim ("yes that's exactly correct"), so this
is settled and not a proposal:

> **`gcc-unwrapped` ships back ends, `cc-wrapper` ships targets.**  So
> `target-specs` and `fixincludes` are per-target derivations feeding the
> wrapper, and **libgcc is just another consumer of a composed target.**

The chain:

```
gcc-unwrapped   ONE derivation, all 47 back ends, NO target, one store path
  |
target-specs    per target -- probes the REAL as/ld, writes specs-config
fixincludes     per target -- fixes THAT target's system headers
  |
cc-wrapper      per target -- COMPOSES the target from gcc-unwrapped
                + specs-config + fixed headers + binutils + libc/sysroot
  |
libgcc          one machine's library: --host=<that machine>, NO --target
  |
libstdcxx, libgfortran, ...     same shape
```

**What this settles, each of which was an open question until now:**

  * **A target is not something the compiler HAS; it is something COMPOSED.**
    The wrapper's store path *is* that target's identity.  This is LLVM's
    shape, and it is why one `gcc-unwrapped` serves everybody.
  * **Per-target data belongs with the per-target thing** -- the wrapper --
    which is why `target-specs` and `fixincludes` must be their own
    derivations.  A component cannot consume what is buried inside the
    compiler's own build.
  * **`libgcc` is not special.**  It is a consumer, one machine's library,
    `--host=<that machine>` and no `--target` at all.  Every `*_FOR_TARGET`
    export in its expression describes a machine it does not have.
  * **The store-path arithmetic is LLVM's**: one big compiler, N small
    wrappers -- not N compilers.

**And the corollary that makes the env-var dance deletable rather than
tidiable**: the three-machine `build`/`host`/`target` vocabulary is the DISTRO
layer's, and **nix is already the outer build system**.  GCC's top level exists
to instantiate a tree per target and drive them in dependency order, which is
what a package set does.  Running it from inside nixpkgs is a distro inside a
distro, and every `touch stamp-h`, `noconfigdirs` subtraction and `cd` into a
sibling's tree is one layer telling the other "no, I've got this".  **Skip the
top level, run only the component's own build system, and there is nothing left
to shift.**

Do not weaken GCC's top level -- it must keep working for `./configure && make`,
where it legitimately IS the distro.  Stop *using* it here.

## THE TARGET LIST IS A DISTRO'S SAMPLE, AND IT STOPS AT THE TOP LEVEL

The set of valid target triples is **infinite**: `config.sub` matches wildcard
families, so no enumeration is or can be complete. What is finite — and
therefore legitimately enumerable — is:

  * **back ends**, which are `gcc/config/<cpu>/` directories;
  * **the pattern-match arms** in `config.gcc` and its kin. `*-*-linux-musl*)`
    is ONE arm matching infinitely many triples;
  * **structural configure options** — the ones that are *choices*, not strings.

The user's name for this is **finite control flow**: the input space is
infinite, the behaviour space is finite. That is the existence proof for this
whole branch. Every control-flow path can be compiled into one `cc1` and
selected at run time precisely because there are finitely many of them. A
per-triple answer could never be compiled in.

THE RULE. `--enable-targets=...` is the *only* thing permitted to be per-target.
It is a **finite sampling of an infinite space**, and that sample may be used
**only within GCC's top-level build system** — which is playing the role
nixpkgs' `gcc-ng` plays, or any other distro doing the same job. It must not
reach `gcc/`, must not reach an installed artefact, and must not key any
generated file.

THE MECHANICAL TEST: **does a target triple appear anywhere below the top
level?** In a source file, a generated file, an installed path, a manifest key.
If yes, a sample of an infinite set is standing in for finite behaviour, and it
is wrong however convenient. In particular an installed directory named after a
triple is always this defect — see the `install-target-headers` correction.

WHY IT KEEPS BEING GOT WRONG, and every instance is the same error —
enumerating INPUTS where the finite thing is BRANCHES:

  * `gcc/default-backends` is 47 **triples**, one per back end, each carrying an
    arbitrary OS. So arm's option set is `arm-eabi`'s and every linux-arm target
    silently lacks `gnu-user.opt`, `linux.opt`, `linux-android.opt`.
  * i686 alongside x86_64 configured cleanly and gave `TARGET_64BIT` a
    compile-time **0**, because the dedup keyed on `cpu_type` and the *first
    triple* won.
  * musl "has no back end" although `config.gcc` handles musl perfectly well —
    the arm exists; the sample does not contain it.
  * `install-target-headers.sh` writes `<target>/include/` per configured
    target, so a target supplied later has none.

The corollary that makes the architecture fall out: `gcc-unwrapped` is the
finite side — all back ends, all control flow, built once. `target-specs` is
the infinite side — one arbitrary triple, canonicalised, computed, probed,
instantiated on demand. The split between the two derivations *is* the
finite/infinite boundary, and that is the only place it can be.

### The branching narrows infinity to infinity, not to a list

A refinement of the rule above, and the reason no amount of case analysis ever
produces a target list.

`config.gcc` does have combined arms — "this OS *and* this arch" — and it is
tempting to read a sufficiently specific one as naming a target. It does not.
`aarch64*-*-linux*` narrows the space, and what remains is **still infinite**.
The branching partitions an infinite set into **finitely many infinite
regions**. The regions are enumerable. Their members never are.

So:

  * key on a REGION — the tuple of branches taken, i.e. the whole `config.gcc`
    answer — and you have a finite, total classification;
  * key on a MEMBER — any particular triple, however "representative" — and you
    have an arbitrary sample standing in for a region, which is the defect.

This is why `tm-<triple>.h` is wrong in KIND and not merely in placement. It is
keyed on a member. `gcc/default-backends` was the same error one layer up: 47
members chosen to stand for 47 regions, each dragging in whatever OS its
representative happened to carry.

And note the corollary, because it is what makes the whole thing tractable:
comparing WHOLE ANSWERS decides region-equality without anyone having to know
which fields a given arm reads. Measured: `config.gcc` answers are byte-identical
across `x86_64-unknown-linux-gnu`, `x86_64-pc-linux-gnu` and
`x86_64-foobar-linux-gnu`, and across `aarch64-unknown-linux-musl`,
`aarch64-foo-linux-musl` and `x86_64-alpine-linux-musl` — six spellings, three
regions. But the vendor field is **not** universally inert: `aarch64*-wrs-vxworks*`,
`alpha*-dec-*vms*`, `rs6000-ibm-aix7.1.*`, `mips*-img-linux*`,
`mmix-knuth-mmixware` all match on it. So never strip a field to decide
equality — compare the answer.

THE STRONGEST FORM OF THE TEST, from the user: the compiler build must depend
only on `--enable-backends`, **never** on `--enable-targets`. The top level uses
the target enumeration solely to drive multibuild; it must never reach the
compiler's own configuration. Mechanically:

    same --enable-backends  =>  BYTE-IDENTICAL compiler,
                                whatever --enable-targets said.

Configure once naming a glibc triple and once naming a musl triple of the same
back end; every object, every generated header and `cc1` itself must be
identical. Any difference is a target fact compiled in where a runtime fact
belongs — and this branch has already moved 92 such facts into the runtime
config, so the channel exists and the residue is the work.
