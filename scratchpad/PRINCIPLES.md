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

One compiler binary serving all back ends, with **zero target-specific
information baked in at compile time**.

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
- The DFA-absent case — both configured bases have reservations.

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
- **The `MULTI_TARGET_RENAME_NAMES` comment names `scratchpad/sweep.sh` as its
  authority and that file DOES NOT EXIST**, and the check it describes is over
  "the two object SETS" — the two-back-end habit written into the instrument
  itself. `scratchpad/t150-rename-gap.sh` is the N-way replacement.
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

Note the last one runs **opposite** to the others: normally the primary's answer
leaks to everyone; there the union's does. Same root — one authority answering
for many.

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

**The anchor value is 48 as of the `add_clobbers` selector (task #150)**, which
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

Both figures were real; they are **different configurations**, and neither
party said which build produced its number. So: a bar figure is a claim to
check — **including when the claim is that a bar figure is wrong.** A
correction is not privileged over the thing it corrects. State the build dir
and the commit beside any bar you quote, or the next reader cannot tell which
of two true numbers applies to them.

**A GUARD THE BUILD SYSTEM CITES BY NAME MAY NOT EXIST.** `gcc/Makefile.in`
names `scratchpad/sweep.sh` as the check for bare duplicate symbols across back
ends. It had never been written. The defect it was supposed to catch was live:
`extract_base_offset_in_addr` is defined bare by aarch64, riscv **and** arm — a
hard link failure, and invisible to the i386+aarch64 pair. This is worse than
`mechanism-present-but-never-invoked`: a comment naming a guard reads as
evidence the guard ran. **Before trusting any named check, confirm the file
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

- **DEVSHELL.md is mandatory.** `nm`/`make` are not on PATH outside the
  nix-shell; a reduced shell writes `#define rlim_t long` into `auto-host.h`,
  which looks exactly like someone else's source bug.
- **Worktrees are created at bare-repo HEAD `7208eca60d0`**, 39,111 commits
  behind. It presents as *"stale line numbers"*, not *"wrong tree"*. Check:
  `git merge-base --is-ancestor HEAD multi-target`, or grep `MULTI_TARGET` in
  `gcc/Makefile.in` — **empty means wrong tree**.
- **The git index is SHARED.** `git commit` commits whatever is staged, including
  another agent's files. `git diff --cached` immediately before every commit.
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



Say what you measured, what you did not, and what your instrument cannot see.
**A measured "still cannot be checked, because X" is a useful result; an
unexamined pass is not.** Distinguish upper bounds from lower bounds explicitly
and never quote one as the other. If a number in your brief is stale or
impossible, say so rather than reporting against it.
