# CLASS (c) -- THE 91 NON-CONSTANT MACROS: A DESIGN WITH COSTS

Nothing implemented. Nothing in the tree changed by this document except the
harness scripts in `scratchpad/`. Every number below is measured in this
session, with a positive control, and the control's output is shown.

Inputs: `scratchpad/MACRO-LEAK.md` (the classification), `STATE.md` (the arms),
`/tmp/cdes/` (this session's raw measurements).

---

## 0. WHAT CHANGED IN THE PICTURE

Three measurements move the design, and two of them move it in the *cheap*
direction. They are stated first because MACRO-LEAK's `RECOMMENDATION` was
written without them.

| question | MACRO-LEAK's position | measured now |
|---|---|---|
| do `targetm` indirect calls break the x86_64 byte-identity arm? | "the one thing that would break it"; unmeasured | **No. The arm is structurally insensitive to it.** See §3. |
| how much of the 91 does upstream already have hooks for? | "upstream has already done this for most of the target macro list" | **1 of 91.** 20 partial, 68 nothing. See §1. |
| are any of the 91 also class (d) (`#if` lines)? | not asked | **Zero, over 2526 files, control firing.** See §2. |

The second one is the expensive surprise and it is the number that should
decide whether this route is attempted at all.

---

## 1. THE HOOK INVENTORY -- HOW MANY ALREADY EXIST

Cross-referenced against `gcc/target.def` (540 hooks), `gcc/c-family/c-target.def`
(8), `gcc/common/common-target.def` (11) and `gcc/doc/tm.texi`, at the
**merge-base** `c31b7a09eea` -- i.e. against upstream, not against this branch.
Full table: `/tmp/cdes/hookmap.txt`, 91 lines.

    HOOK_EXISTS    1     a genuine 1:1 upstream replacement
    HOOK_PARTIAL  20     a related hook exists, semantics do NOT cover the macro
    NO_HOOK       70     nothing

**`LIBCALL_VALUE` is the only one of the 91 that upstream has already
converted** (`TARGET_LIBCALL_VALUE`, and tm.texi documents the macro as the
hook's fallback).

Two more are already done **on this branch and not upstream**, which is a
credit to the branch and must not be double-counted as upstream progress:
`TARGET_ASM_OUTPUT_EXTERNAL` and `TARGET_ASM_GLOBAL_OP` exist at HEAD and not at
the merge-base. So **3 of 91 are done, 88 are not.**

The 20 `HOOK_PARTIAL` cases are the dangerous ones for anyone sizing this from
a hook name. Each has a hook that *looks* like the answer and is not:

  * `STRICT_ALIGNMENT` vs `TARGET_SLOW_UNALIGNED_ACCESS` -- correctness vs cost.
    tm.texi requires the hook to return true whenever the macro is true; the
    hook is strictly weaker and substituting it silently changes correctness
    into a cost heuristic.
  * `BIGGEST_ALIGNMENT` vs `TARGET_ABSOLUTE_BIGGEST_ALIGNMENT` -- the hook is
    the compile-time maximum over *all* targets, i.e. exactly the unioned
    quantity, not the selected target's own value. Using it would produce the
    class-(b) union answer where class (c) behaviour is required.
  * `WORDS_BIG_ENDIAN` vs `TARGET_FLOAT_WORDS_BIG_ENDIAN` -- floating-point
    word order only.
  * `SELECT_CC_MODE` vs `TARGET_CC_MODES_COMPATIBLE` -- merges two CC modes,
    never chooses one.
  * `Pmode` vs `TARGET_ADDR_SPACE_ADDRESS_MODE` -- the hook *defaults to*
    `Pmode`; it is downstream of the thing that must vary.

Full reasons, one line each, in the agent record; the table is in
`/tmp/cdes/hookmap.txt`.

**Five of the 70 are not target macros at all.** `HAVE_adddf3`,
`HAVE_atomic_compare_and_swap{si,di}`, `HAVE_cpymemdi`, `HAVE_setmemdi` are
`insn-flags.h` optab-existence predicates generated per back end. There is no
hook mechanism for them by design, and there should not be one: they need a
per-back-end optab table selected with the target config. They are a sixth
category, not 5 more hooks.

**Net: the class-(c) route is ~86 new hooks to design, document in tm.texi,
default, and convert every back end to -- plus one optab-table mechanism.** It
is not "upstream mostly did it".

---

## 2. CLASS (c) INTERSECTS CLASS (d) AND THE CONSTANT-EXPRESSION TRAP IN ZERO PLACES

Both sweeps are the kind of result that is worthless without a control, so both
carry one and both controls fired.

### 2a. `#if`/`#elif` arithmetic lines

Every `#if`/`#elif` line in every `*.cc`/`*.h`/`*.c` under `gcc/` excluding
`config/` and `testsuite/` -- **2526 files** -- naming one of the 91 other than
through `defined()`.

    positive control  FIRST_PSEUDO_REGISTER -> hard-reg-set.h:45, hard-reg-set.h:164
                      (exactly the 2 sites MACRO-LEAK records)
    class (c) hits    0 macros, 0 sites

**No macro in class (c) is read by the preprocessor.** Class (c) and class (d)
are disjoint. Every one of the 91 is hook-able in principle; none of them
inherits class (d)'s "no mechanism exists" problem.

### 2b. Contexts where C++ *requires* a constant expression

The failure this looks for is not a wrong value, it is a build that cannot
compile: array bound, `case` label, enumerator, bitfield width, `static_assert`,
namespace-scope initialiser. A macro used there cannot become a function call
at all, hook or not, and nobody had measured it.

Script: `/tmp/cdes/constctx.sh`, 2453 files.

    positive control  FIRST_PSEUDO_REGISTER  90 sites
    positive control  N_REG_CLASSES          73 sites   (matches the recorded 73)
    class (c) raw hits                       25 sites, 8 macros
    class (c) after reading all 25           0

All 25 are false positives of the pattern and each was read: 12 are
`ira_pressure_class_translate[REGNO_REG_CLASS (r)]`-shaped *runtime indices*,
the rest are `const` **local** initialisers (`const int dope = 4 *
UNITS_PER_WORD;`, `const bool backwards = WORDS_BIG_ENDIAN;`), which C++ does
not require to be constant expressions. Sites listed in
`/tmp/cdes/constctx.txt`.

**So there is no compile-time blocker anywhere in class (c).** This is the
single most encouraging measurement in the document, and it is the one I would
most want a second pair of eyes on, because a false negative here turns a
staged plan into a wall.

---

## 3. THE `ira-costs.cc` QUESTION -- SETTLED, AND IT WAS TWO QUESTIONS

MACRO-LEAK: *"This is a real compile-time regression on the primary and it is
the one thing that would break the x86_64 byte-identity arm."*

Those are two different claims and they have different answers.

### 3a. Byte identity: **settled, not at risk**

The x86_64 arm compares the **assembly `cc1` emits**. `targetm.regno_reg_class
(r)` returning exactly what `regclass_map[r]` returned is the same value
computed by a different instruction sequence *inside cc1*. Nothing in the
emitted `.s` can observe how cc1 fetched it. The arm is insensitive to the
conversion by construction; it can only go red if a hook returns a *different*
value, which is precisely what it should catch.

This is not only an argument. **The experiment has already been run on this
branch.** `f82b65386d0` turned `targetm` from a constant-foldable `const struct`
into a **global pointer**, which is the identical de-optimisation (every hook
access became an unfoldable indirect load), across all 540 hooks at once. The
x86_64 arm is green against genuine upstream GCC at all five `-O` levels after
it -- re-verified this session, 10/10, §6.

I regard the byte-identity half as settled. What is *not* settled is a hook
that changes a value, and no amount of arm-greenness protects against that; that
is what the per-macro probes are for (§5).

### 3b. Throughput: measured, and small

Isolated microbenchmark of the `ira-costs.cc:2461` loop shape -- allocno x hard
reg, indexing `reg_class_size` and a move-cost matrix by the fetched class --
three ways, `-O2`, best of 5, 18.8M calls per run
(`/tmp/cdes/indirect-cost.cc`):

    DIRECT    regclass_map[r]                0.724 ns/call
    HOOKINL   const targetm.hook(r)          0.724 ns/call   (+0.0%)  -- fully folded
    INDIRECT  targetm_ptr->hook(r)           1.302 ns/call   (+79.8%)
    extra cost of the indirect call          0.578 ns/call

So the *relative* cost of the fetch is +80%, and the *absolute* cost is 0.58 ns.
`HOOKINL` folding to exactly `DIRECT` is the control that says the benchmark is
measuring the pointer, not the call.

Aggregate, on the real compilers, same input, output verified byte-identical so
the two are doing equal work (`scratchpad/big.c`, `-O2`, best of 15):

    stock  cc1  70.19 ms
    mt     cc1  72.34 ms      ratio 1.0307   (+3.07%)

+3% is the cost of *everything the branch has already done* -- the pointerised
`targetm`, the second back end's effect on i-cache and page tables -- not of the
91 conversions, which have not happened. It is an upper bound on the damage so
far and it is small. It is also at the edge of what a two-different-builds
comparison can resolve (different configure flags, different debug info); treat
it as "a few percent, not a factor", not as three-point-zero-seven.

**Verdict: the indirect-call cost is not a reason to reject the class-(c)
route, and it is not what the byte-identity arm measures.** §4 removes most of
it anyway.

---

## 4. THE DESIGN: SPLIT CLASS (c) BY *WHAT VARIES*, NOT BY MACRO KIND

Class (c) has been treated as one thing -- "code, so it must be a hook". It is
two things, and the split falls almost exactly along the cheap/expensive line.

**(c-DATA): the value is fixed once the target config and the command line are
known.** `BYTES_BIG_ENDIAN` is `TARGET_BIG_END`; `UNITS_PER_WORD` is
`(TARGET_64BIT ? 8 : 4)`; `Pmode` is `(ix86_pmode == PMODE_DI ? DImode :
SImode)`. These read *option state*, and option state is settled at the end of
option processing and does not change again. They do not need a call at all:
they need **one scalar in a per-target-config global, written once when
`-ftarget-config=` selects a base and options are finalised**, read as a single
load -- the same cost as today's `regclass_map[]` array load, and *cheaper* than
today's `(TARGET_64BIT ? 8 : 4)`, which is a load plus a test plus a select.

**(c-CODE): the value depends on an argument or on per-function state.**
`REGNO_REG_CLASS(r)`, `SELECT_CC_MODE(op,x,y)`, and the ones that read `cfun`.
These need a real hook call and pay the 0.58 ns.

Measured split over the 2340 use sites in `gcc/*.cc` (`/tmp/cdes/usecount.txt`,
1267 TUs swept):

| subclass | macros | uses | mechanism | per-use cost |
|---|---:|---:|---|---|
| (c-DATA) config-invariant | **35** | **1824** | per-config scalar, refreshed once | one load; **cheaper than today** |
| (c-DATA') object-like but reads `cfun` | 7 | 104 | real hook, or an inline reading `crtl` | 0.58 ns |
| (c-CODE) function-like | 49 | 412 | real hook | 0.58 ns |

**The entire hot head of the distribution is (c-DATA).** The six macros that
carry 60% of all uses -- `Pmode` 646, `UNITS_PER_WORD` 256, `BYTES_BIG_ENDIAN`
233, `WORDS_BIG_ENDIAN` 98, `POINTER_SIZE` 86, `BIGGEST_ALIGNMENT` 86 -- are
every one of them config-invariant scalars. The hottest thing that genuinely
needs a call is `REGNO_REG_CLASS` at 61 sites, and MACRO-LEAK's worry about
`BYTES_BIG_ENDIAN` at 304 sites and `Pmode`/`UNITS_PER_WORD` at 925 sites
**does not apply to them at all** under this design. That worry was the main
cost argument against option B and it dissolves.

The 7 `cfun`-readers are `ACCUMULATE_OUTGOING_ARGS` (51), `PREFERRED_STACK_
BOUNDARY` (29), `TRAMPOLINE_ALIGNMENT` (8), `EXIT_IGNORE_STACK` (6),
`INCOMING_FRAME_SP_OFFSET` (6), `INCOMING_STACK_BOUNDARY` (2),
`ADJUST_REG_ALLOC_ORDER` (2). Several of these already read `crtl` fields that
the back end wrote, so the per-config indirection is only over the *fallback*.

### Why (c-DATA) is not the same mistake as class (b)

It looks like the unioning move and it is not. Class (b) unions **one value
across bases** and hopes the union is safe for all of them -- that is why
`FIRST_PSEUDO_REGISTER` at 95 is a landmine. (c-DATA) keeps **one slot per
selected configuration**, written from the selected base's own expression, read
under a target-neutral name. Nothing is unioned; the vocabulary is shared and
the datum is per-config. That *is* the branch's established move ("union the
vocabulary, keep data per configuration, select at run time"), applied to names
that MACRO-LEAK correctly showed have no constant to union -- because the thing
being selected is not a compile-time constant, it is a value computed once at
run time from the selected base's option state.

There is one property to check per macro before it may go in (c-DATA), and it
cannot be skipped: **is the value really invariant after option processing?**
`UNITS_PER_WORD` under `#pragma target`/`__attribute__((target))` on i386 is
the case to test first. If any of the 35 varies with per-function target
attributes it belongs in (c-DATA') and pays the call. I have not tested this.

---

## 5. WHAT THE PROBES MUST BECOME -- AND THE ANTI-FLOOR RULE

The existing instrument (`scratchpad/macro-probe.sh`) measures **the header and
preprocessor context a middle-end TU is compiled in**. That is the right thing
to measure for an unconverted macro and it is structurally blind to runtime
`targetm` dispatch -- which is exactly what a converted macro becomes. Left
alone, converting a macro **deletes its arm**: the name vanishes from both
bases' headers, the probe scores `KIND absent/absent` -> FAIL, forever. 91 arms
that can never go green is a scoreboard that has stopped measuring, and the
temptation to drop them is the test-harness floor by another route.

### The fourth probe shape: TAB

For a macro converted to hook `H`, the question changes from *what does the
preprocessor see* to *whose code will run*, and that is statically answerable
from the built `cc1`:

  1. **Conversion completeness.** The macro must be absent from every base's
     `<base>-inc` header set. Present = not converted; that is a FAIL, and it
     is the arm that stops a half-done conversion reading as done.
  2. **Dispatch correctness.** For each base B, resolve the function pointer
     stored in slot `H` of B's target struct in the linked `cc1` (`nm`/
     `objdump -R`/`readelf`; the initialisers are static const data with
     relocations naming the callee) and assert the symbol belongs to B's back
     end -- `aarch64_*` for aarch64, `ix86_*`/`i386` for i386.
  3. **Discrimination control**, without which (2) proves nothing: the two
     bases' slots must resolve to *different* symbols for a macro known to
     differ, and the i386 slot must resolve to the same symbol the primary used
     before conversion.

TAB sees the one thing EXP cannot -- which definition linked -- and it is the
direct answer to the two-stage-poison finding (`regclass_map` linking and
answering i386's register classes for every target).

For (c-DATA), TAB's step 2 reads a **data** slot rather than a code pointer,
which cannot be resolved statically because it is written at run time. Those
need step 2 to become a runtime dump: a `-fdump-target-config` in `cc1` that
prints every per-config scalar for the selected base, compared against the
value the probe measures in that base's header context today. That is a real
piece of work and it is the honest cost of keeping the scoreboard alive.

### The rule that keeps the number honest

Every one of the 138 names carries a **status**, and the score is over statuses,
never over the surviving arms:

    UNCONVERTED  -> scored by INT/STR/EXP as today.  Absence = FAIL.
    CONVERTED    -> scored by TAB.  Absence of a TAB arm = FAIL.
    RETIRED      -> requires a written reason and a replacement arm named.

A macro may only move `UNCONVERTED -> CONVERTED` **together with its TAB arm in
the same change**. A name that disappears from the headers and has no TAB arm
scores FAIL, not "absent". That makes the two ways of moving the number
dishonestly -- deleting the probe, and converting the macro out from under it
-- both fail loudly, by name.

Note what this costs: the aarch64 column cannot approach green until the
conversions land, so the scoreboard will move slowly and *should*. 138 is a
**lower bound**; ~1049 identical-text non-integer macros remain unclassified and
the next surprise is most likely there.

---

## 6. STAGED PLAN

Ordered by ratio of arms-turned-green to risk, not by use count. Each stage
keeps the x86_64 byte-identity arm green (§3a says it cannot be broken by the
mechanism, so a red arm at any stage means a hook returned a *wrong value*,
which is the signal you want).

**Stage 0 -- 3 macros, 0 new hooks: prove the TAB probe.**
`LIBCALL_VALUE` (upstream hook already), `ASM_OUTPUT_EXTERNAL` and
`GLOBAL_ASM_OP` (branch hooks already). No conversion work at all; the entire
content is building the TAB arm and its discrimination control on macros whose
answer is already known. If TAB cannot turn these three green, nothing later is
measurable. `GLOBAL_ASM_OP` is the ideal first case: `.globl` vs `.global`
assembles identically, so it is the arm that catches what a weaker check cannot.

**Stage 1 -- the funnels: 12 macros, ~4 conversion sites.**
`addresses.h` already collapses 9 `#ifdef`-tested macros into 3 inline bodies
(`base_reg_class`, `index_reg_class`, `ok_for_base_p_1`) -- confirmed at
`gcc/addresses.h:20-91`. Three more are single-header-only: `LOCAL_ALIGNMENT`
and `HAVE_setmemdi` appear *only* in `defaults.h`, `ASM_OUTPUT_EXTERNAL` only in
`target-def.h` (verified: zero uses in any `gcc/*.cc`). Best ratio available.

**Stage 2 -- (c-DATA), 35 macros, 1824 uses, 0 new hooks.**
The per-config scalar table. This is the largest win and the *cheapest*
mechanism, and it needs no `target.def` work at all -- so it is not blocked on
the 86-hook problem. It requires: the invariance check per macro (§4), the
refresh point at end of option processing, and the runtime-dump probe. It also
fixes the ABI-visible silent divergences -- `WCHAR_TYPE` (`int` vs `unsigned
int`), `PTRDIFF_TYPE`, `SIZE_TYPE`, `ASM_COMMENT_START`, `GLOBAL_ASM_OP` --
which are the cheapest ways for a future aarch64 arm to be wrong.

**Stage 3 -- the long tail: 63 macros at <=10 uses each, 304 uses total.**
Mechanical, no hot path, one new hook each. This is where the ~86-hook cost
actually lands, and it is the stage to stop at and re-decide if the hook count
proves as expensive as §1 suggests.

**Stage 4 -- `REGNO_REG_CLASS` and the remaining hot function-like macros.**
Deliberately last: highest call frequency, and by then the mechanism and the
probes are proven.

**Not in any stage: the 5 `HAVE_*` optab predicates.** They need a per-back-end
optab table, not a hook, and that is a separate design.

**Do first, ahead of all of the above** (unchanged from MACRO-LEAK, and I agree):
class (e), because those are buffer overflows rather than wrong output.

---

## 7. RE-VERIFICATION OF THE ARM THIS SESSION HARDENED

`scratchpad/stock-compare.sh` had a false green (the negative control reported
"ok, differs" while comparing two nonexistent files). Hardened, then re-run:

    input /tmp/acc2/t.c                5/5 IDENTICAL, 5 distinct md5s each side
    input scratchpad/big.c             5/5 IDENTICAL, 5 distinct md5s each side
    ------------------------------------------------------------------
    10/10 holds against genuine upstream GCC at c31b7a09eea.

Details of the audit in `STATE.md`.

---

## 8. WHAT I AM NOT CONFIDENT ABOUT

  * **The (c-DATA) invariance assumption, §4.** The whole cheap path rests on
    "option state is settled after option processing and does not change".
    `#pragma GCC target` / `__attribute__((target))` on i386 switches
    `TARGET_64BIT`-adjacent state *per function*. I did not test whether any of
    the 35 varies under it. If `UNITS_PER_WORD` does, the largest stage loses
    its cost advantage and 256 use sites move to (c-DATA'). **This is the
    load-bearing unmeasured claim of this document**, in the same position
    `ira-costs.cc` occupied in the last one, and it is cheaper to settle: one
    probe TU with a target attribute.
  * **The 20 `HOOK_PARTIAL` judgements.** They are semantic reads of tm.texi,
    not measurements. If several are actually adequate, the hook count falls;
    if `TRAMPOLINE_SIZE`/`TRAMPOLINE_ALIGNMENT` (flagged as arguable) go the
    other way it rises. A wrong "partial" here costs design time; a wrong
    "exists" would silently substitute different semantics, which is worse, so
    the classification was made conservative in the direction of more work.
  * **The `#if` and constant-expression zeros, §2.** Both are greps with
    working controls, so they cannot be *silently* empty -- but a grep can
    still miss a construction I did not think to pattern. Macro-expanded uses
    (a class-(c) macro reached through *another* macro that then lands in a
    `#if` or an array bound) would not be seen. The N_REG_CLASSES lesson is
    exactly that the interesting case is one level down.
  * **The +3.07% aggregate timing.** Two differently-configured builds. It is
    evidence of "small", not a measurement of the conversion, which has not
    happened.
  * **TAB's step 2 for (c-DATA).** I have described a runtime dump; I have not
    checked that the per-config scalars would be reachable from a dump hook at
    a point where they are already written, nor what it costs. Presence of a
    mechanism in a design document is not evidence anything invokes it.
  * **Whether any of this should be attempted.** §1 is the number that argues
    against: ~86 new hooks, each needing a `target.def` entry, tm.texi
    documentation, a default, and a conversion in every back end in the tree.
    Stage 2 is 1824 of 2340 uses for zero new hooks, so the plan is arranged so
    that the expensive part can be declined after Stage 2 without wasting the
    cheap part. I would present that choice rather than assume it.
