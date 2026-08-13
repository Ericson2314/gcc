
================================================================================
SESSION: Stage 2 continued -- 18 more (c-DATA) macros.  The class-(c)
"zero compile-time blockers" claim is now FALSE, and three exclusions the
invariance measurement structurally could not have caught.
Commit: 607b2d858b4
================================================================================

## THE RE-SWEEP, WHICH IS THE POINT OF THE TASK -- AND IT FOUND ONE

scratchpad/cdata-constctx.sh.  Ten contexts, not the design's six: array bound,
case label, enumerator, bitfield, static_assert, namespace-scope initialiser,
ADJACENT STRING CONCATENATION (the one that cost the last session a build),
`#if'/`#elif', constexpr initialiser, alignas/aligned attribute.

Controls fired: N_REG_CLASSES 59 sites, FIRST_PSEUDO_REGISTER 84,
ZZ_NO_SUCH_MACRO_ANYWHERE 0.

**The sweep is over the TRANSITIVE CLOSURE, not the 20 names.**  That is the
whole difference.  CLASS-C-DESIGN 8 already said its own sweep could not see
"a class-(c) macro reached through ANOTHER macro", and that is exactly where
the blocker is:

    defaults.h:1123   #ifndef MAX_BITS_PER_WORD
                      #define MAX_BITS_PER_WORD BITS_PER_WORD

    MAX_BITS_PER_WORD is an ARRAY BOUND in 11 places -- expmed.h:105,106,
    168-171; expmed.cc:128,129; lower-subreg.h:35-37; and gt-ada-utils.h:586.

Redirect BITS_PER_WORD and all eleven stop compiling.  25 derived names were
swept; this is the only one.  All 21 raw hits on the leaf names were read and
are runtime indices or local initialisers, as before.

**IT IS INVISIBLE A SECOND WAY, AND THAT IS THE MORE INTERESTING HALF.**  i386
-- the current primary -- defines MAX_BITS_PER_WORD as a literal 64, so the
fallback never fires and the redirection is harmless TODAY.  The build breaks
only when the primary is a back end that omits it.  aarch64 omits it.  So the
correctness of a middle-end conversion silently depended on which back end
happened to be primary, which is this branch's whole subject.

defaults.h now sets MAX_BITS_PER_WORD_FROM_BITS_PER_WORD when the fallback
fires and the redirect block `#error's on it by name.  aarch64.h gets the
explicit `MAX_BITS_PER_WORD 64' the guard asks for.  Verified non-vacuous: the
guard fired three times during this session, in genconfig-aarch64.o,
target-asm-ops-aarch64.o and mt-aarch64/options-init.o.

## THREE MACROS EXCLUDED, TWO FOR A REASON NOBODY HAD ASKED ABOUT

Pmode and UNITS_PER_WORD excluded as instructed.  CASE_VECTOR_MODE and
STACK_SIZE_MODE excluded for the SAME reason and named as instructed: they are
`machine_mode's and mode numbering is per base.  Two more:

**PIC_OFFSET_TABLE_REGNUM** -- i386's expands to a test of
`pic_offset_table_rtx', which is `this_target_rtl->x_pic_offset_table_rtx',
PER-FUNCTION RTL state written during expand.  The invariance plugin samples
at PLUGIN_ALL_PASSES_START, where it is in the same state every time, and
reports the macro invariant.  It is not.  A plugin that samples at one point
cannot see state that is null at that point and set later, and no amount of
extra functions in the sweep would have found this.

**SUPPORTS_STACK_ALIGNMENT** -- and this one is a new CATEGORY, not a new
instance.  It IS invariant: on i386 the left side is MAX_OFILE_ALIGNMENT and
dwarfs any stack boundary, on aarch64 both sides are the same macro.  It is
still unfit, because it reaches `ix86_cfun_abi ()' and a field here is
evaluated ONCE with `cfun' null.  The build says so directly:

    config/i386/i386.h:614: error: 'ix86_cfun_abi' was not declared in this scope

So the precondition is not one question but two -- "does the value change" AND
"can the expression be EVALUATED at the refresh point" -- and only the first
was ever asked.  The design has no name for the second.

## THREE MORE CATEGORIES OF TRANSLATION UNIT REACH THE REDIRECT

The guard was `MULTI_TARGET_TARGETM_BASE' alone.  Also on the supply side, all
compiled against a named base's tm.h without that flag:

  * build-time generators (GENERATOR_FILE) -- genconfig-aarch64.o
  * target-asm-ops-<base>.o, <base>-common.o, spec-functions-<base>.o,
    mt-<base>/options-init.o -- new -DMULTI_TARGET_SUPPLY_TU=1

MULTI_TARGET_TARGETM_BASE could not be reused for the second group:
target.h:392 requires it to be paired with -Dtargetm=, and these are not
renamed.  The first four string macros never revealed any of this because no
generator spells SIZE_TYPE.

## THE TYPES ARE LOAD-BEARING AND BOTH OBVIOUS CHOICES WERE WRONG

Two properties of a macro's current expansion have to survive the move into a
struct field: the promoted type at the use site, and whether the compiler can
still prove the value non-negative.  The second is the one that bites.
BITS_PER_WORD is a constant-foldable `int', so `unsigned <= BITS_PER_WORD' is
silent; as an opaque `int' load it is not, and varasm.cc alone gained four
-Wsign-compare warnings.  `unsigned short' restores both at once.
MAX_FIXED_MODE_SIZE as `unsigned int' turned five signed comparisons unsigned
-- a real change in meaning -- and as `int' it warned.  `unsigned short', its
actual type, is right.  Both mistakes were made and measured before the rule
went in the header.

FOUR NEW -Wsign-compare REMAIN, at optabs.cc:553, 727, 1841, 1842, all
`shift_mask == BITS_PER_WORD - 1'.  They are inherent: `(int)ushort - 1' cannot
be proved non-negative.  Semantics unchanged (both sides were already
`unsigned long' vs `int'); recorded rather than hidden.

Struct, every refresh function, poisoned initialiser, post-refresh poison check
and the probe's dump all come from ONE `TARGET_CDATA_FIELDS' list now.  The
poison check names the field it caught.

## SCORE -- every verdict diffed, never the totals

    header 266 -> 230.  EXACTLY 36 removed (18 macros x 2 bases), ZERO added,
      and `diff' over (base, macro, SHAPE, verdict) shows no changed line at
      all -- shape included.
    TAB    22 -> 58.
    total scored 288 -> 288.

    i386     115 header PASS / 0 FAIL  +  28 TAB PASS / 1 FAIL
    aarch64    2 header PASS / 113     +  20 TAB PASS / 9 FAIL

    make cc1 rc=0, multi-target-objs rc=0, stock-compare 10/10 (both inputs,
    5 distinct md5s each side, negative control on two real artefacts).

### The i386 FAIL and 4 of the aarch64 ones are a HARNESS regression, not mine

ASM_COMMENT_START/WCHAR_TYPE/SIZE_TYPE/PTRDIFF_TYPE score "no independent
value".  Cause found: tab-probe.sh takes the string oracle from
MTP=/tmp/mtp-before, and /tmp/mtp-before has been REGENERATED since Stage 2
landed.  Once those four are redirected the header probe no longer sees them,
so the snapshot no longer contains them.  The name says "before" and the
contents are "after".  The fix is a macro-probe run against a tree at
b063704e8a9^ (a git worktree); i386's three *_TYPE arms survive only because
tab-probe falls back to genuine upstream cc1's __SIZE_TYPE__, and
ASM_COMMENT_START has no such fallback.  NOT papered over, NOT banked.

### The 5 aarch64 numeric FAILs are UNVERIFIED, and they stay FAIL

BYTES/WORDS/FLOAT_WORDS/REG_WORDS_BIG_ENDIAN and SHIFT_COUNT_TRUNCATED read
1 for aarch64 where the header derives 0.  The plugin calls BOTH bases' refresh
functions in ONE cc1 run; only the selected base has been through its own
target_option_override, so aarch64's TARGET_BIG_END and TARGET_SIMD are read
out of storage i386 filled.  The plugin's own comment predicted exactly this
case.  A third status excusing them would be the floor with a plausible name,
so they are FAIL and the message says why and what unblocks it (a second run
under aarch64's config, blocked while aarch64 cc1 ICEs before plugin callbacks).

## THE NUMERIC TAB ARMS HAVE NO ORACLE, SO ONE WAS PRE-REGISTERED

These macros are class (c) precisely because they are not constant expressions
in their own base's header context, so the INT probe cannot see them, and
upstream cc1 exposes __SIZE_TYPE__ but not PARM_BOUNDARY.  The oracle is a hand
derivation from i386.h and aarch64.h, written into
scratchpad/PREREGISTER-cdata-num.md WITH the expression each value came from,
BEFORE the plugin was taught to dump the slots.

FIFTEEN OF THE EIGHTEEN AGREE BETWEEN THE BASES and therefore discriminate
nothing -- an agreeing slot is equally consistent with a working mechanism and
with one pinned to the primary, which is precisely how targetm_asm_ops stayed
green.  tab-probe.sh says so in every one of those thirty verdicts.  The
control is the three that must DIFFER, asserted by name ahead of every verdict:

    MALLOC_ABI_ALIGNMENT       64 vs 128     all three came back at their
    TRAMPOLINE_SIZE            28 vs 40      pre-registered values
    DWARF_FRAME_RETURN_COLUMN  16 vs 30

DWARF_FRAME_RETURN_COLUMN is the sharpest: aarch64's comes from CALLING
`aarch64_debugger_regno ()', so it also shows the refresh runs real back-end
code.  (It is why target-cdata.cc now includes rtl.h and tm_p.h.)

## SELECTION ARMS -- the targetm_asm_ops lesson applied to our own mechanism

select-arm.sh watched step 1 only.  Added:
  * toplev.o must reference init_targetm_cdata           (the refresh RUNS)
  * varasm.o and expmed.o must reference targetm_cdata   (the REDIRECT reaches
    libbackend), with bitmap.o as the control that must NOT
All green here; all FAIL on /tmp/b-ref1 with both controls still green.

## gen_blockage -- INVESTIGATED, NOT LANDED.  IT IS SIX BUGS, NOT ONE.

WIP preserved at scratchpad/gen-blockage-WIP.patch.  Tree reverted to a
building state; nothing half-landed.

Confirmed the report: `::gen_blockage' at 0x1073c30 comes from `insn-emit-1.o'
-- the PRIMARY's UN-NAMESPACED insn-emit -- and explow.o binds to it for every
target.  UNSPECV_BLOCKAGE is 1 (insn-constants-i386.h:460) and 5
(insn-constants-aarch64.h:894).

Writing the forwarder is easy and I did.  The blocker is elsewhere:

    insn-emit-1.cc:(.text+0x6b0): multiple definition of `gen_blockage()';
    multi-target-select.o:multi-target-select.cc:(.text+0x520): first defined here

**Makefile.in:1679 OBJS names BOTH `$(MULTI_TARGET_OBJS)' AND the primary's
un-namespaced `$(INSNEMIT_SEQ_O)', insn-attrtab.o, insn-automata.o,
insn-dfatab.o, insn-latencytab.o, insn-opinit.o, insn-preds.o.**  The comment
at Makefile.in:2642 says "OBJS names $(MULTI_TARGET_OBJS) rather than the
primary's insn-*.o".  That is false of the current file -- another written
invariant nobody executed.  Ten insn-emit-*.o carry ~1346 bare `gen_*' each.

Removing `$(INSNEMIT_SEQ_O)' from OBJS links, and exposes FIVE MORE bare names
in exactly the same class, every one of them answered today by i386's
expansion for every target:

    add_clobbers                added_clobbers_hard_reg_p
    gen_nop                     gen_speculation_barrier
    gen_movxf

add_clobbers/added_clobbers_hard_reg_p are the worst of them: recog.cc calls
them with INSN CODES, which are per-base.

**Two of the six cannot take a uniform forwarder.**  `gen_movxf' is XFmode,
i.e. x86 only; `gen_speculation_barrier' is arm/aarch64 only.  The
"no floor, let it fail to link naming the base" rule that works for
init_adjust_machine_modes does not work for a pattern most back ends do not
have, so this needs a design decision (optional entries, or fix the callers)
rather than another forwarder.  That is why it stopped here.

Also worth knowing for whoever takes it: `gen_name_is_global_p' returns false
whenever `!gen_target_ns ()', so the primary's un-namespaced genemit run has no
way to know a multi-target build is in effect.  A surgical "skip the globals
list in the un-namespaced run too" fix therefore needs a new flag threaded from
the Makefile into genemit; it is not a one-line change in gensupport.cc.

## WHAT I DID NOT DO

  * Pmode, UNITS_PER_WORD, CASE_VECTOR_MODE, STACK_SIZE_MODE (mode-typed),
    PIC_OFFSET_TABLE_REGNUM, SUPPORTS_STACK_ALIGNMENT, and the six known
    non-invariant macros.  BITS_PER_WORD is now a per-config slot while
    UNITS_PER_WORD is not, so generic code that assumes
    BITS_PER_WORD == UNITS_PER_WORD * BITS_PER_UNIT holds them from two
    different authorities.  They agree for both configured bases today.  It
    should be closed when UNITS_PER_WORD goes.
  * The MTP oracle regression above.
  * A second plugin run under aarch64's target config.
  * Throughput: not measured, and Stage 2 is still "nothing measurable".
    Two-build timings cannot resolve it; do not claim either sign.
  * gcc/config/rs6000/* were modified in the worktree by someone else
    throughout this session and were never staged.  `git diff --cached' was
    checked immediately before the commit; it listed 13 files, all mine.

---

# TASK #77 HANDOVER -- `options-save.cc' and the primary's optionlist

Branched from `cda9e1c19b2`; landed as `d36637e175f`.

**Read this before doing anything else with #77: the defect as filed was
already fixed.** `52fa9e763c5` did not only union the two structs -- it also
drove `optc-save-gen.awk`'s save, restore, hash, eq, print and stream walks
from the union list, and the Makefile already passed
`$(OPTIONS_UNION_FLAGS)` to it. The ticket's premise ("the walk is still the
primary's") was stale. I confirmed this by measurement, not by reading:
`scratchpad/t77-harness.sh` round-trips nine aarch64-only members and 24
checks pass.

## The one thing that WAS still the primary's, and the trap in fixing it

`cl_optimization_compare` walked `flags[]`. In a two-target build: 1116
comparisons, **zero** naming an aarch64 member.

**The obvious fix is a regression, and it looks like a fix.** Switching that
walk to `sv_flags[]` -- the same variable every other walk in the file uses
-- compiles, produces a plausible diff, and adds 17 aarch64 members. It also
takes the comparison count from **1116 to 585**. The `R` records are the
*save* set (`Optimization|PerFunction|Save`); `cl_optimization_compare`
wants every option with a `gcc_options` member. So 531 common options
silently stop being checked, and the artefact still shows "more aarch64
members than before". *A non-vacuity check that only asks "did aarch64
appear?" scores this as a pass.* The count is what caught it -- add a `C`
record kind (every option with a member) and it goes 1116 -> 1169 with none
lost.

Generalised: **when a walk is moved onto the union list, check the count in
BOTH directions.** "More of the thing I was looking for" is compatible with
"less of everything else".

## The aarch64 codegen route is closed, and it is not ours

`cc1 -ftarget-config=specs-aarch64-unknown-linux-gnu-config` ICEs in
`aarch64_class_max_nregs` from `init_reg_sets_1` on any input -- the
hard-register union (Application 2) has not landed. **It reproduces
identically on `/tmp/b-objs`**, which has no change of mine, so it is
pre-existing; I checked before building anything around it.

Consequence for anyone with an acceptance criterion of the form "show a
non-primary target actually doing X": you cannot do it through the parser
today. What does work, and is what `scratchpad/t77main.cc` does, is to link
**cc1's own object set with `main.o` replaced** and call the entry points
directly. `targetm_common_select` + `multi_target_select` (the same pair
`toplev.cc:2396` makes) succeed long before `init_regs`, so `targetm` is
genuinely aarch64's. This is reusable for any option/attribute-level
question about a non-primary base.

Two things that route needs and that cost me two rebuilds:

  * `aarch64_option_restore` calls `aarch64_get_tune_cpu`, which asserts the
    tune is not `aarch64_no_cpu`. A harness that sets option fields by hand
    must set `x_selected_tune`/`x_selected_arch` or it aborts in the back
    end, which reads exactly like the generated code being wrong.
  * `aarch64_option_restore` also **recomputes** `x_aarch64_isa_flags` from
    the arch and tune, so asserting it round-trips bit-for-bit is asserting
    the back end does not do its job. `x_aarch64_isa_flags_1` is left alone
    and is the one to use for exact equality.

## The negative control that made this worth anything

`scratchpad/t77-harness.sh` builds a SECOND binary whose `options-save.o`
was generated with no union list -- the primary's optionlist alone -- and
compiled against the same unioned `options.h`. That is the defect, exactly:
members laid out, never walked. It fails 21 of the same 24 checks, and its
`cl_optimization_compare` does not report the aarch64 member that the real
one reports. Without that arm, 24 green checks would not have distinguished
"the union list is doing the work" from "these members happened to be
zero".

`cl_optimization_compare` reports via `internal_error`, which does not
return, so it is exercised in a child process scored by exit status, with a
"two identical copies" arm so that a compare which always fired could not
score.

## Numbers, so the next diff has something to diff against

  * `gcc-options-union.list`, 2 bases: **3432** `C` records.
  * `options-save.cc`: 17817 lines before, **17919** after; the 103-line
    diff is entirely inside `cl_optimization_compare`.
  * With no union list the output is **byte-identical**, 17181 lines.
  * `options.h` byte-identical to a build without this change; `explicit_mask`
    still `[9]` and `[1]`, `static_assert` still exactly at the limit.
  * Both bases generate the same 17919-line `options-save.cc` -- the list's
    order, not each base's own.

## Regression bar

  * `stock-compare.sh`, `IN=$(readlink -f scratchpad/big.c)`, `MT=/tmp/b-77t`:
    **5/5 IDENTICAL** vs `/tmp/b-stock`, 5 distinct md5 per side, negative
    control firing.
  * `make cc1` rc=0, `make multi-target-objs` rc=0, `make target-specs` rc=0.
    Stderr 310 lines, **0 containing "error"**, 275 `warning:`; no
    `is newer than target` lines at all (this was effectively a full rebuild
    of the affected TUs, so the 32-line incremental floor did not apply).
  * Header probe, `macro-probe-run.sh /tmp/b-77t` against a baseline run on
    `/tmp/b-objs`: 115 macros x 2 bases = **230 arms**, i386 **0 FAIL**,
    aarch64 **113 FAIL**, and `diff` of the two `results.txt` is **4 lines**
    -- one arm whose text embeds the probe output directory in a
    `fancy_abort` string. Zero verdict changes, zero probe-shape changes.

**Scoreboard correction:** the task brief said aarch64 **131** FAIL. The
measured figure is **113**, and it is 113 on the UNMODIFIED baseline too, so
this is a stale or transposed number in the brief and not a regression.
Whoever wrote the next brief should carry 113.

## Build dir

`/tmp/b-77t` is mine and nobody else wrote it. Recipe:
`scratchpad/t77-conf.sh` (top-level configure, x86_64 + aarch64) then
`scratchpad/t77-make2.sh`. Note two things the recipe encodes:

  * `make all-gcc` fails at `stmp-fixinc` in this environment; `make cc1` in
    the gcc subdir is what to run, and it is unrelated.
  * `t77-make2.sh` puts `/tmp/mt-fakebin` on PATH. Without it `target-specs`
    SKIPs aarch64, writes no `specs-aarch64-...-config`, and no driver or
    `-ftarget-config=` can select aarch64 at all -- see DEVSHELL.md.

## What I did not do

  * The `V` records (`Variable`-declared extra vars) are still not compared
    by `cl_optimization_compare`, exactly as before this change -- upstream
    never walked them either. Left alone deliberately; widening the compare
    to them is a behaviour change, not a union fix.
  * Nothing about the `init_reg_sets_1` ICE.
  * No throughput measurement.

---

# #65 first half: gcc no longer runs `target-specs`' configure (commit `b850cb24ecf`)

Branched from **`f3b73c511a7`** ("Merge branch 'worktree-agent-ac13bc388156472c2'
into multi-target").  The worktree arrived at the stale bare-repo HEAD
`7208eca60d0`; `git reset --hard multi-target` fixed it, `MULTI_TARGET` count in
`gcc/Makefile.in` went 0 -> 27.  Build dir `/tmp/b65`, mine, nobody else wrote it.

## EVERY PATH BY WHICH THE PROBE REACHED THE BUILD

The brief said two (`start.encap` -> `specs`, and `selftest` -> `SELFTEST_DEPS`).
There were **five**, and they all funnel through the ONE file target `specs`:

    all.internal: start.encap ...        -> start.encap: ... specs ...
    all.cross:    ... specs ...
    rest.cross:   specs
    GCC_PASSES = xgcc $(BUILD_DRIVER_NAME) specs     <- Makefile.in:997
        -> s-macro_list, s-fixinc_list (i.e. stmp-int-hdrs), and SELFTEST_DEPS
    libgcc.mvars: config.status Makefile specs xgcc

`SELFTEST_DEPS` reached it TWICE: once through `$(GCC_PASSES)` and once through
its own explicit `$(SPECS)`.  So "cutting :2903 alone is insufficient" turned out
to be the opposite of the truth: **only `specs` ever named `target-specs`**, so
cutting that one edge cut all five.  Verified by grepping every rule whose
prerequisite list contains `specs` or `$(SPECS)`, not by grepping for the word.

## WHAT WAS CUT

  * `$(SPECS): xgcc$(exeext) target-specs` -> `$(SPECS): xgcc$(exeext)
    $(BUILD_DRIVER_NAME) $(wildcard specs-$(TEST_TARGET))`.
  * The whole `target-specs` make target, including its probe loop.

Two prerequisites were ADDED, and both were bugs the probe had been hiding:

  * `$(BUILD_DRIVER_NAME)`.  The `else` branch of the `specs` recipe runs
    `$(GCC_FOR_TARGET)`, which is `./$(BUILD_DRIVER_NAME)`, NOT `./xgcc`.  That
    branch was unreachable while the probe always wrote `specs-<target>` first.
    The first `make all-gcc` after the cut died with
    `./x86_64-pc-linux-gnu-gcc: No such file or directory`.  Latent, not new.
  * `$(wildcard specs-$(TEST_TARGET))`.  Without it, a build dir that made
    `specs` from the `-dumpspecs` fallback keeps serving that fallback for ever,
    because `specs` is newer than `xgcc` and the PHONY `target-specs` that used
    to force it is gone.  **Measured: it did exactly that** -- run 3 left
    `gcc/specs` at 6044 bytes of `-dumpspecs` output with the real 8448-byte
    probed file sitting next to it.  After the fix, `cmp specs
    specs-x86_64-pc-linux-gnu` succeeds.

## WHAT WAS *NOT* DELETED WITH IT (this is the part to check if you touch it)

The old rule ended with three checks.  Deleting the rule would have deleted them
from the only path that always runs -- the exact loss the comment at
`check-target-caps` warns about at length.  They are now
`check-multi-target-specs`, which `start.encap` depends on:

    check-spec-refs.sh          FATAL
    check-target-caps.sh        FATAL
    ./xgcc -specs=<file> --version (read_specs)   reported + counted, NOT fatal
                                                  -- same as it was there

With no `specs-<target>` in the build dir it prints `NOTHING CHECKED ... This is
a SKIP, not a pass` to stderr and exits 0.  It is ordered `check-... :
multi-target-specs` rather than listed beside it, so `-j` cannot run the checker
against the previous build's files.

Measured with the sentinel build present:

    check-spec-refs: 1 spec file(s), every name consulted by the driver
    check-target-caps: 1 config file(s), every capability read by something
    check-multi-target-specs: 1 spec file(s) handed to read_specs, 0 rejected

## THE COMPOSITION QUESTION -- A DESIGN DECISION INSIDE A DEBUGGING TASK

Cutting the probe alone would have SILENTLY dropped half of every spec file, and
this is worth stating because the loss is invisible: the file still exists, still
parses, and the driver just falls back to its generic defaults.

A target's `specs-<t>` has two producers.  `specs-src-<t>` (tm.h chain) and
`mlib-specs-<t>` (multilib tables) are gcc BUILD data -- there is no probe for
them.  Everything else is probed.  `target-specs/configure` does
`cat > "$specs_file"`, i.e. it TRUNCATES; gcc's rule then re-prepended the source
half afterwards.  Remove gcc's rule and the source half is gone.

Resolved by moving the join into `target-specs/configure`, the only writer of the
file, as **`--with-source-specs=FILES`**.  Order unchanged and still deliberate:
source-derived first, probed last, so `read_specs` applies the probed value last
and it wins.  Doing it inside that one configure also makes it idempotent, which
`cat specs-src >> specs-<t>` in a stampless make rule was not.  gcc's remaining
build-time rule (`multi-target-specs`) produces the two source files and prints
the exact `--with-source-specs=` string to hand over.

I am flagging this as design rather than debugging (PRINCIPLES 2b).  The
alternative -- gcc keeps composing, target-specs appends -- is not idempotent and
gives the file two writers.  If #67 later makes `target-specs` a real
`target_module`, this is the seam it will be instantiated on.

**A REAL TRAP, PAID FOR HERE:** my first version put ONE BLANK LINE between the
concatenated files.  It looks like tidying.  It produced

    x86_64-pc-linux-gnu-gcc: fatal error: specs file malformed after 4092 characters

at the join between the last `*multilib_defaults:` block of `specs-src` and the
leading comment of `mlib-specs`.  `read_specs` is whitespace-sensitive at a block
boundary.  Plain `cat`, no separator -- exactly as gcc's Makefile did it.  The
`read_specs` check above is what catches this class, which is why it was kept.

## SELFTESTS

`$(SPECS)` was in `SELFTEST_DEPS` **for its ORDER**: it forced `target-specs` to
have run, so `specs-$(TEST_TARGET)-config` existed before `SELFTEST_FLAGS`
expanded its `$(wildcard)`.  With the probe cut that ordering is gone, and
`SELFTEST_FLAGS` would have quietly emitted NO `-ftarget-config=` -- i.e. run cc1
with no target selected.

`$(SPECS)` removed from `SELFTEST_DEPS`; the config file named there through
`$(wildcard)` instead, so the `s-selftest-<LANG>` stamps go out of date the first
time the user runs `target-specs/configure` (otherwise a build that skipped would
skip for ever behind an up-to-date stamp).  `GCC_FOR_SELFTESTS` now interposes
**`gcc/selftest-driver.sh`**.  Three arms, all run:

    ARM A  config present -> the selftests RUN (see below)         rc=1
    ARM B  config absent  -> "selftest: SKIP x86_64-pc-linux-gnu -- no
                             specs-NOSUCH-config ... NOTHING WAS TESTED; this
                             is a skip, not a pass."                rc=0
    ARM C  TEST_TARGET empty -> "FATAL -- no target selected"       rc=1

No default was introduced and nothing silently passes with no target selected.

### ARM A FOUND A REAL PRE-EXISTING BUG.  NOT MINE.  SOMEONE SHOULD OWN IT.

With the target correctly selected the selftests get all the way into
`selftest::run_tests` and then abort:

    simplify-rtx.cc:9115: test_scalar_int_ops: FAIL:
      ASSERT_RTX_EQ (op0, simplify_gen_binary (PLUS, mode, op0, const0_rtx))
      expected: (reg:CI 113)
      actual:   (plus:CI (reg:CI 113) (const_int 0 [0]))
    cc1: internal compiler error: in assert_rtx_eq_at, at selftest-rtl.cc:57

`CImode` is a mode that reaches `test_scalar_int_ops` and that `simplify_rtx`
does not fold `+ 0` for.  This is the mode-union family (PRINCIPLES 3, "the
union's answer leaking"): the walk is over the UNION of modes, and a mode only
one back end has is being handed to a test written for the other's vocabulary.
It could not be seen before because nothing in this tree had ever reached the
selftests -- `stmp-int-hdrs` was blocked upstream of them.  My change makes the
step REACHABLE, exactly as the Makefile comment predicted; it did not break it.
`make selftest` still cannot complete on this host for the unrelated
`stmp-fixinc` /usr/include reason, so ARM A was run by invoking the driver
directly with the same arguments the recipe expands to.

## THE ACCEPTANCE ARM: THE SENTINEL SURVIVES

    sh /tmp/b65-ts.sh    # target-specs/configure by hand, x86_64-pc-linux-gnu,
                         #   --with-native-system-header-dir=/ZZZ-sentinel
                         #   --with-source-specs="../specs-src-<t> ../mlib-specs-<t>"
    669b37e10fe12497e3199e5abd9b21d9  specs-x86_64-pc-linux-gnu
    233a607ea8d2281054f03b302e79a15b  specs-x86_64-pc-linux-gnu-config

    make -j8 all-gcc                  # rc=2, at stmp-fixinc (environmental)
    669b37e10fe12497e3199e5abd9b21d9  specs-x86_64-pc-linux-gnu       OK
    233a607ea8d2281054f03b302e79a15b  specs-x86_64-pc-linux-gnu-config OK
    grep native_system_header_dir ...-config -> /ZZZ-sentinel   (still there)

    grep -c '^checking ' on the make log -> 0     # no configure ran, at all

NEGATIVE CONTROL, because "md5 unchanged" is worthless if the check cannot fail:
`sed -i s|/ZZZ-sentinel|/usr/include|` the config file, `md5sum -c` -> **FAILED,
rc=1**; restore -> OK.  The comparison discriminates.

The `all-gcc` failure is `stmp-fixinc` / no `/usr/include` on NixOS -- known,
environmental, unchanged, and it happens AFTER `specs` and `multi-target-specs`.

## REGRESSION BARS -- all re-measured on `/tmp/b65`

    make cc1               rc=0
    make multi-target-objs rc=0
    stock-compare.sh  IN=/tmp/acc2/t.c (ABSOLUTE) MT=/tmp/b65 ST=/tmp/b-stock
        5/5 IDENTICAL, 5 distinct md5 per side, negative control fires, rc=0

    TAB   58 arms: i386 29 PASS / 0 FAIL, aarch64 24 PASS / 5 FAIL
          -- MATCHES the brief exactly.  The 5 aarch64 FAILs, by name:
             BYTES_BIG_ENDIAN WORDS_BIG_ENDIAN FLOAT_WORDS_BIG_ENDIAN
             REG_WORDS_BIG_ENDIAN SHIFT_COUNT_TRUNCATED
          -- run with MTP=/tmp/mtp-before.  Pointing MTP at a fresh macro-probe
             run of HEAD is WRONG and the script refuses it by name (no
             PROVENANCE.txt); read that file before touching this.

    HEADER 230 arms: i386 115 PASS / 0 FAIL, aarch64 **5 PASS / 110 FAIL**
          -- the brief says aarch64 2 PASS / 113 FAIL.  I measure 5/110.
             The 5, by name: FIRST_PSEUDO_REGISTER, MAX_BITSIZE_MODE_ANY_MODE,
             MAX_BITS_PER_WORD, N_REG_CLASSES, REGNO_REG_CLASS.

**On that 3-arm difference, stating the bound honestly:** I did NOT build an
unmodified baseline, so I cannot prove by measurement that my diff did not cause
it.  What I can say: `/tmp/mtp-before/PROVENANCE.txt` is dated 2026-08-12T08:51
at commit `36ba31303e2` ("give each back end its own `addresses.h` predicates"),
which IS an ancestor of my base -- so the brief's header figures predate register
and address work that would plausibly flip exactly `N_REG_CLASSES` and
`REGNO_REG_CLASS`; the TAB column, which shares the instrument, matches the brief
to the arm; and my diff is four files (`gcc/Makefile.in`,
`gcc/selftest-driver.sh`, `target-specs/configure{,.ac}`) whose Makefile hunks
are at `GCC_FOR_SELFTESTS`, `SELFTEST_DEPS`, `start.encap`, `SELFTEST_FLAGS`,
`$(SPECS)`, the `target-specs` rule and two comments -- none of them a rule that
produces `tm.h`, `mt-i386/` or `mt-aarch64/`, which is all the probe reads.  I
attribute it to branch drift and recommend the next brief carry **5/110**, but
that is an inference, not a measurement.

## STDERR -- RE-ESTABLISHED, NOT INHERITED

The brief listed 0, 32, 664 and 698 as previously reported.  Measured here:

    make cc1 (no-op, nothing to do)     32 lines = 8 `is unchanged`
                                                + 24 `'@' is redundant`
    make multi-target-objs (rc=0)       32 lines, same 8 + 24 composition
    make all-gcc (COLD, from scratch)  867 lines, of which 370 are `warning:`
                                       and the rest are the caret/continuation
                                       lines those warnings print.
                                       Top: 268 -Wmissing-field-initializers,
                                       18 -Wunused-parameter, 16 -Wunused-result,
                                       15 -Wformat-diag, 12 -Wsign-compare.

So: the documented **32-line incremental floor is exactly right** and reproduces
to the line and to the composition.  The large numbers (664/698/867) are the COLD
arm and are entirely nixpkgs gcc 15.2 host-compiler warnings -- a different
measurement, not a regression against the 32.  They are not comparable and should
not be quoted as one bar.  PRINCIPLES 6 says "a full build is empty"; that is
false on this host with this host compiler, and the composition above is why.

## WHAT I DID NOT DO

  * Did not make `target-specs` a `target_module` (needs #67 -- out of scope,
    said so in the brief and I agree).
  * Did not touch the `-dumpspecs` fallback in the `specs` recipe.  It is
    pre-existing and it is now REACHABLE for the first time (a build where the
    user has not run `target-specs/configure` takes it).  It is arguably a
    default-by-another-name under PRINCIPLES 2a; I did not want to change
    behaviour and cut the probe in the same commit.  **Someone should decide
    whether `gcc/specs` should exist at all when nothing has been probed.**
  * Did not fix the `simplify_rtx` / `CImode` selftest failure above.
  * Did not build an unmodified baseline for the header scoreboard (see above).
  * `make -n s-selftest-c` in this tree EXECUTES sub-makes and relinked `cc1`
    against a bad `-lgmp` path, leaving no `cc1`.  Do not use `make -n` here to
    inspect a recipe; `make cc1` afterwards recovered it (rc=0).

## FILES

    /tmp/b65            my build dir (x86_64-pc-linux-gnu + aarch64-unknown-linux-gnu)
    /tmp/b65-cfg.sh     top-level configure for it
    /tmp/b65-ts.sh      target-specs/configure by hand, WITH the /ZZZ-sentinel
                        and WITH --with-source-specs -- this is the recipe for
                        the acceptance arm
    /tmp/b65-mk{1..5}.{out,err}, /tmp/b65-cc1*.err, /tmp/b65-mto.err
    /tmp/b65-mtp/, /tmp/b65-tab.log     probe datasets for the numbers above

---

# #101 -- fixincludes is out of `gcc/`'s build.  Branched from `7f6a64a4d70`.

Template followed: `b850cb24ecf` (`target-specs`).  Same shape, same reason.

**WORKTREE TRAP HIT AGAIN.**  Created at `7208eca60d0`, 39,111 behind;
`grep -c MULTI_TARGET gcc/Makefile.in` -> 0.  `git reset --hard multi-target`
from the clean tree recovered it.  That is every worktree agent this session.

## `all-gcc`, BEFORE AND AFTER, SAME BUILD DIR (`/tmp/b101`)

BEFORE (unmodified tree, cold):

    The directory (BUILD_SYSTEM_HEADER_DIR) that should contain system headers
    does not exist:
      /usr/include
    make[1]: *** [Makefile:4920: stmp-fixinc] Error 1
    make: *** [Makefile:5051: all-gcc] Error 2

AFTER: `make all-gcc` **rc=0**, stderr **33 lines = the 32-line incremental
floor (8 `is unchanged` + 24 `'@' is redundant`, exact composition) + 1 named
`check-multi-target-specs: NOTHING CHECKED ... This is a SKIP, not a pass`**.
No `stmp-fixinc`, no `include-fixed/`, no `macro_list` in the build dir after
deleting the stale ones and rebuilding.

**One caveat, and it is NOT this change**: once `target-specs/configure` has
been run in the build dir the selftests stop skipping and `all-gcc` then stops
at the KNOWN `test_scalar_int_ops` / `PLUS x, 0` CImode failure (#95), and at
nothing else.  Moving the config aside -> rc=0 again.  Both states reproduced.

## WHAT WAS CUT, AND EVERY PATH IT REACHED THE BUILD BY

`stmp-fixinc` reached the build by ONE path and cutting it cut all of them:

    stmp-int-hdrs: $(STMP_FIXINC) ...        <- the only reference
      <- SELFTEST_DEPS, libgcc-support, install-headers-{tar,cpio,cp},
         install-mkheaders

Gone from `gcc/`: `stmp-fixinc`; `STMP_FIXINC`; `FIXINCLUDES_MACHINE`;
`BUILD_SYSTEM_HEADER_DIR`; `OTHER_FIXINCLUDES_DIRS`; `--with-build-sysroot` and
`SYSROOT_CFLAGS_FOR_TARGET`; `--with-fixincludes-machine`;
`-DFIXED_INCLUDE_DIR`; the `include-fixed` halves of `install-include-dir`,
`install-headers`, `install-headers-{tar,cpio,cp}`; `real-install-headers-*`
(zero callers remained -- checked against `Makefile.tpl` and the generated
top-level `Makefile.in`); `macro_list`/`s-macro_list`; `t-sdemtk`'s
`stmp-sdefixinc`.  `install-no-fixedincludes` is KEPT as a synonym for
`install` because `Makefile.tpl:1705` calls it.

`--with-build-sysroot` DID go with it: its only two effects were
`SYSROOT_CFLAGS_FOR_TARGET` and `BUILD_SYSTEM_HEADER_DIR`, both target-side.
**The top-level configure keeps its own**, which is where it belongs.
`enable_fixincludes` was checked but **never set anywhere in the tree** -- a
switch that did not exist.

## TWO GENERATORS THAT FAILED AND EXITED 0 (found, not chased into scope creep)

  * `s-macro_list` ran `echo | $(GCC_FOR_TARGET) -E -dM -`, cc1 **ICEd** ("no
    target configuration was selected"), and the build **continued** -- the ICE
    is the head of a pipeline whose status is `sort`'s.  `move-if-change` then
    installed an **empty** `macro_list`, which `fixinc.sh` reads as "the
    compiler predefines nothing".  macro_list is per-target; it is now built by
    `mkheaders`, which asserts it is non-empty and fails by name otherwise.
  * `fixincludes/Makefile.in` **never defined `INSTALL_DATA`, `INSTALL_SCRIPT`,
    `INSTALL_PROGRAM`, `prefix` or `exec_prefix`** (`AC_PROG_INSTALL` was never
    called).  `make install` therefore ran `README-fixinc` as a command
    (`Permission denied`, `Error 126`) on the FIRST line of the rule, so
    `fixinc.sh`, `fixincl` and `mkheaders` were **never installed**, and paths
    began at `/libexec/...`.  Pre-existing (`git show
    multi-target:fixincludes/Makefile.in` has the same gap) and harmless only
    while gcc's build did the work itself.  Fixed -- mkheaders IS the mechanism
    now.

## THE SPLIT NOBODY HAD MEASURED

`fixincludes/Makefile.in` had `libsubdir = $(libdir)/gcc/$(target_noncanonical)/$(ver)`
while `gcc/Makefile.in` has `$(libdir)/gcc/$(ver)`.  The two halves of one
mechanism installed to **two different directories** -- `mkheaders` looked for
`fixinc_list`/`gsyslimits.h` where nothing had written them -- and each half
installed with exit 0.  Aligned.  Also removed fixincludes' `rm -rf $(itoolsdir)`:
two components populate that directory and one wiping it made the result
order-dependent (measured: gcc-then-fixincludes left no `mkinstalldirs`).

## INCLUDE SEARCH PATH -- EVERY LINE ACCOUNTED FOR

`scratchpad/h101-path.sh`, three arms through one `cc1`, differing only in the
target config.  Exactly ONE line changes:

    A  nothing said            (none)
    B  fixed_include_dir = <libsubdir>/include-fixed   <- the deleted macro's
                                                          own expansion
       + ignoring nonexistent directory ".../17.0.0/include-fixed"
    C  fixed_include_dir = a directory that EXISTS
       -> ` /tmp/h101-path/real-include-fixed` under "search starts here"

`diff a b` is one added line; three distinct md5s.  So the entry was **moved
into the per-target config, not deleted**, and it is **searched** when it names
something real.  `/usr/include` still appears twice (the recorded "key absent"
signature) -- unchanged.

End to end through the REAL writer:
`target-specs/configure --with-fixed-include-dir=DIR` -> `fixed_include_dir DIR`
in `specs-<t>-config` -> cc1 searches it.  Without the flag the key is **absent**
and the built-in default `""` compacts the entry away.  `118 capabilities, all
expected` from target-specs' own check, both ways.

**Never a dangling entry**: `targ_caps.fixed_include_dir` defaults to `""`, NOT
to a path, because gcc's build no longer creates `include-fixed`.
`cppdefault.cc` now emits ONE entry (`multilib = 1`) instead of upstream's two,
which were keyed on `SYSROOT_HEADERS_SUFFIX_SPEC` -- a tm.h macro, i.e. the
privileged target answering for everyone.

## `install-mkheaders` AND `mkheaders.conf`

`install-mkheaders` **survives** and is the point.  It installs only what is
target-INDEPENDENT: `gsyslimits.h`, `fixinc_list`, per-multilib
`include*/limits.h`, `mkinstalldirs`.

**`mkheaders.conf` is gone entirely.**  It carried `SYSTEM_HEADER_DIR` (one
target's system headers recorded as everyone's), `STMP_FIXINC` (a build-time
on/off decided once for all targets) and `OTHER_FIXINCLUDES_DIRS`.  All three
are now `mkheaders` ARGUMENTS.  `macro_list` is no longer installed either.

`fixincludes/mkheaders.in` no longer reads `@target@`.  `--target` and
`--headers` are required and **fail by name**; so does "no `--gcc=`/
`--macro-list=`"; all four refusals demonstrated.  Output:
`$(libdir)/gcc/$(version)/<target>/include-fixed<multi_dir>` -- the multilib
loop over `fixinc_list` is preserved, one fixincludes run per entry.

Demonstrated: ONE installed `mkheaders`, run for `x86_64-pc-linux-gnu` and
`aarch64-unknown-linux-gnu`, produced **two separate trees**, and
`$(libsubdir)/include-fixed` (the old shared path) does not exist.  Their
contents are identical **because I gave both runs the same `--headers` and the
same `--gcc`** -- that is separation of location, and is NOT evidence about
machine gating; gating was pre-measured (`fixincl.c:356`) per the brief.

**There is now exactly ONE caller**, so "both callers must write the same
place" is satisfied by there being one.  The build-time-per-target invocation
the user described is NOT implemented: it belongs to the top level, which is
the only component that knows the target list.  It is a small job now --
`mkheaders` already takes everything per invocation, which is precisely why the
target is an argument.  **Handed over, not faked.**

## REGRESSION BARS

    make all-gcc            rc=0   (33 lines = 32-line floor + 1 named SKIP)
    make cc1                rc=0   (32 lines, exact floor)
    make multi-target-objs  rc=0   (32 lines)
    stock-compare.sh (absolute IN, MT=/tmp/b101 vs /tmp/b-stock)
                            5/5 scored, 5/5 IDENTICAL,
                            5 distinct md5s per side,
                            negative control: "ok: two real, non-empty,
                            distinct artefacts (1158 and 804 lines) that differ"
    grep 'define rlim_t' auto-host.h -> empty (full shell throughout)

## SCOREBOARD -- THE aarch64 DISAGREEMENT IS SETTLED: **5 PASS / 110 FAIL**

    230 header arms:  i386 115 PASS / 0 FAIL
                      aarch64 5 PASS / 110 FAIL
    58 TAB arms:      i386 29 PASS / 0 FAIL
                      aarch64 24 PASS / 5 FAIL

The five aarch64 PASSes are `FIRST_PSEUDO_REGISTER`, `MAX_BITSIZE_MODE_ANY_MODE`
and **`MAX_BITS_PER_WORD`, `N_REG_CLASSES`, `REGNO_REG_CLASS`** -- exactly the
three the previous agent named as the difference between 2/113 and 5/110.  That
was an inference; this is an independent measurement that agrees with it.

**Why this counts as settled against an unmodified baseline without building
one**: `macro-probe.sh` compiles probe sources against the build directory's
`tm.h` and `<base>-inc/` header sets.  This diff touches
`fixincludes/*`, `gcc/Makefile.in`, `gcc/configure{,.ac}`, `gcc/cppdefault.cc`,
`gcc/target-caps.{cc,h}`, `gcc/config/mips/t-sdemtk` and `target-specs/*` --
**not one file the probe reads, and no back-end header at all**.  None of the
115 probed macros can have changed.  **Recorded 2/113 is stale; carry 5/110.**

## FILES (scratchpad, absolute)

    h101-conf.sh      configure /tmp/b101 (top level, 2 back ends)
    h101-mk.sh        make + stderr line count; D= picks /tmp/b101 or .../gcc
    h101-recheck.sh   config.status --recheck for gcc/ in the FULL shell
    h101-fi-recheck.sh   same for fixincludes/
    h101-ts.sh        target-specs/configure; FIXED= adds --with-fixed-include-dir
    h101-path.sh      THE INCLUDE-PATH ACCOUNTING, three arms + diff + md5s
    h101-stock.sh     stock-compare wrapper with an absolute IN
    h101-mkh.sh       mkheaders end to end: 4 fail-by-name arms + 2 targets

## STILL OPEN, TOUCHED OR ADJACENT

  * `LIMITS_H_TEST` still asks the BUILD machine whether a `limits.h` exists,
    now via `SYSTEM_HEADER_DIR` (identical to the old `BUILD_SYSTEM_HEADER_DIR`
    whenever `--with-build-sysroot` was absent -- and that flag is gone).  It is
    a target fact deciding gcc's own `include/limits.h`.  **FIXME left in
    `Makefile.in`.  #24/#100, needs a limits.h design; not fixincludes.**
  * `TOOL_INCLUDE_DIR` collapsing to `/usr/include` (#24): **not touched**, as
    instructed.  Visible in every arm of `h101-path.sh` as the second
    `/usr/include`.
  * The top-level per-target `mkheaders` invocation, above.

# TASK #106 -- `function.o`'s TEN `ix86_*` REFERENCES: MEASURED, NOT CLEARED

Branched from `972440fce48` (the merge carrying the `4caa7c2a4f1` c-ops work).
**No source file was changed.** This entry is a measurement and a
decomposition, and it contradicts the brief's premise.  Read the pushback.

## THE TEN, NAMED, WITH THE MACRO THAT PULLS EACH IN

Measured with `nm -uC` on `/tmp/b106/gcc/function.o`.  The plain-name sweep
(`nm -u` + `grep -w`) scored **0 for nine of the ten** -- C++ mangling -- and
only `ix86_preferred_stack_boundary` (a variable, C linkage) showed up.  That
is PRINCIPLES rule 4 exactly: a 0 that is the instrument, not the tree.
**Use `nm -C`.**

| # | undefined symbol | macro in `function.cc` | sites |
|---|---|---|---|
| 1 | `ix86_call_abi_override` | `OVERRIDE_ABI_FORMAT` | 4860 |
| 2 | `ix86_cfun_abi` | `STACK_BOUNDARY` (via `TARGET_64BIT_MS_ABI`) | 97 (`STACK_BYTES`), 2720-1 |
| 3 | `ix86_preferred_stack_boundary` | `PREFERRED_STACK_BOUNDARY` | 314 |
| 4 | `ix86_push_rounding` | `PUSH_ROUNDING` | 4145 |
| 5 | `ix86_local_alignment` | `STACK_SLOT_ALIGNMENT` | 274, 294, 3366, 3516, 3601 |
| 6 | `ix86_minimum_alignment` | `MINIMUM_ALIGNMENT` | 3682, 3684 |
| 7 | `ix86_reg_parm_stack_space` | `REG_PARM_STACK_SPACE` -> `INCOMING_REG_PARM_STACK_SPACE` | 2325 |
| 8 | `ix86_function_type_abi` | `OUTGOING_REG_PARM_STACK_SPACE` | 1421 |
| 9 | `ix86_function_arg_regno_p` | `FUNCTION_ARG_REGNO_P` | 5970 |
| 10 | `init_cumulative_args` | `INIT_CUMULATIVE_ARGS` | 2318 |

Note #5: it is `STACK_SLOT_ALIGNMENT`, **not** `LOCAL_ALIGNMENT`.  Both expand
to `ix86_local_alignment`; `function.cc` spells only the former.  Grepping for
the symbol and converting the obvious macro would have converted the wrong one.

## HOW WIDE EACH ONE ACTUALLY IS (627 shared objects, `nm -uC`)

    ix86_push_rounding             27      ix86_function_arg_regno_p       7
    ix86_cfun_abi                  17      ix86_preferred_stack_boundary   5
    ix86_local_alignment            5      init_cumulative_args            5
    ix86_minimum_alignment          4      ix86_reg_parm_stack_space       3
    ix86_function_type_abi          3      ix86_call_abi_override          1

**These disagree with the brief's figures** (it quoted `ix86_cfun_abi` 14 and
`ix86_push_rounding` 7).  Mine are over `*.o c-family/*.o c/*.o` = 627 objects
in `/tmp/b106`; the Arm C sweep in `4caa7c2a4f1` covered a different set.  I did
not reconcile them.  **Diff the shapes, not the totals** -- and do not carry
either number as settled until one sweep's object set is stated.

## PUSHBACK: THREE OF THE TEN ARE NOT THE `4caa7c2a4f1` SHAPE

The brief models all ten as the c-ops shape -- a statement/call routed through
a per-base table.  **Seven are.  Three are not**, and each of the three is a
design question under PRINCIPLES 2b, not debugging:

* **`PUSH_ROUNDING` (19 `#if`/`#ifdef` lines) and `REG_PARM_STACK_SPACE` (12)**
  in shared code outside `config/`.  These are **existence predicates**
  answered by the shared `tm.h` -- "does the target define this at all" -- and
  they select *different control flow*, not a different value.  Converting them
  means turning 31 preprocessor branches into runtime ones, which changes the
  shape of the code around them.  This is the `HAVE_*` existence-predicate
  problem (#87) reappearing on macros the brief treats as ordinary.

* **`INIT_CUMULATIVE_ARGS` is a TYPE problem, not a call.**  `CUMULATIVE_ARGS`
  is a `typedef struct ix86_args {...}` in `i386.h`.  `function.cc:2280`
  declares `CUMULATIVE_ARGS args_so_far_v;` -- **stack storage sized and laid
  out by the primary** -- and `calls.cc:2760`, `calls.cc:4219` and
  `expr.cc:2201` do the same.  Routing the initialiser through a table does not
  fix this: the aarch64 back end would still be writing its own struct into
  i386-shaped storage through `targetm.calls`.  This is "sized by one, written
  by another" from the PRINCIPLES table, on the stack.

  Sketch that fits the branch's method (union the vocabulary, keep the data per
  config, fail by name): a shared `struct mt_cumulative_args { alignas(A)
  unsigned char raw[N]; }` with `A`/`N` a declared union bound, plus a
  `static_assert (sizeof (CUMULATIVE_ARGS) <= N && alignof (CUMULATIVE_ARGS)
  <= A)` **in each per-base TU**, so a back end that outgrows the bound breaks
  the build naming itself rather than corrupting a stack frame.  `target.h`'s
  `pack_cumulative_args`/`get_cumulative_args` magic-pointer pair needs a
  `void *` overload; the `CUMULATIVE_ARGS *` cast in `get_cumulative_args` is
  only correct inside per-base TUs, and `calls.cc:1342` calls it from shared
  code.  **Not attempted.**

## PLACEMENT -- THE ANSWER TO CONSTRAINT 1, AND IT IS THE OPPOSITE OF c-ops

`function.o` is in `OBJS` -> `libbackend.a` -> **both `cc1` and `lto1`**.  All
ten symbols are ordinary back-end functions already in `libbackend.a`.  So for
this table `MULTI_TARGET_OBJS_<base>` is the **correct** home -- the trap that
bit `4caa7c2a4f1` (front-end-only symbols reaching `lto1`) does not apply,
because nothing in this table calls into c-family.  Do not copy
`MT_C_TARGET_OBJS` across by analogy: that would take the table out of `lto1`,
which needs it.

The right mechanism is the `defaults.h` redirect block (the `target-regs` /
`target-cdata` shape, `defaults.h:1936` onward), not hand-edited call sites --
it fixes `expr.o`, `calls.o` and `cfgexpand.o` in the same stroke.

## BASELINE, MEASURED, SCORED ON rc

    x86_64-pc-linux-gnu        rc=0 SUCCESS   .s = 12369 bytes / 804 lines
    aarch64-unknown-linux-gnu  rc=4 ICE       .s =    30 bytes /   2 lines

i.e. the brief's prediction reproduces exactly.  **aarch64 stops where it did:
nothing was changed, so it gets no further.**  `scratchpad/t106-run.sh` scores
the exit status and only *reports* the `.s` size, because `[ -s out.s ]` is
green for a 30-byte file from a compiler that exited 4.

## `scratchpad/rv-specs.sh` IS STALE AND FAILS SILENTLY

`make target-specs` no longer exists -- `b850cb24ecf` took target-specs out of
gcc's build.  `rv-specs.sh` now dies with `No rule to make target
'target-specs'` and, piped, **still reported rc=0**.  Replacement:
`scratchpad/t106-ts.sh` runs `target-specs/configure` once per target with
`/tmp/mt-fakebin` on PATH and checks the ARTEFACT, not the exit status.
Verified: 4 files written, `specs-<t>` 101/96 lines, `-config` 220 lines each.

## FILES (scratchpad)

    t106-conf.sh   configure /tmp/b106 (top level, x86_64 + aarch64)
    t106-build.sh  build harness (derived from rv-build.sh; SRC/D repointed)
    t106-ts.sh     target-specs configure per target -- REPLACES rv-specs.sh
    t106-run.sh    both targets through cc1; verdict = rc, not file size

## WHAT I DID NOT DO

No implementation.  No `stock-compare` run, no scoreboard run, no `lto1` link
check -- all four are regression bars *for a change*, and there is no change.
`make cc1` rc=0 is the cold build only.  Budget went to establishing the
mapping and the blast radius; landing seven of ten and running out mid-way
would have risked the one outcome PRINCIPLES forbids, a non-linking `cc1`.

Carry the scoreboard as **5 PASS / 110 FAIL** (settled above in this file).
PRINCIPLES 6 still records the stale 2/113 -- that line should be corrected.

## A HARNESS TRAP I HIT, FOR THE NEXT AGENT

Do not write `nohup ... &` inside a tool call that is *already* backgrounded.
The tool reports the launcher's exit 0 as the build's, and you will read
"build succeeded" next to a build dir with no `cc1` in it.  Background the
command itself and poll the artefact.

# TASK #107 -- `CUMULATIVE_ARGS' STORAGE + WRITERS: LANDED (`2ef489d0984`)

Branched from `cc9ef129b37` ("PRINCIPLES: correct the scoreboard...").  Build
dir `/tmp/b107`, x86_64-pc-linux-gnu + aarch64-unknown-linux-gnu.

## THE MEASUREMENT, TWICE, BY TWO INSTRUMENTS

    sizeof (CUMULATIVE_ARGS)    i386  96   aarch64 184
    alignof (CUMULATIVE_ARGS)   i386   8   aarch64   8

`scratchpad/t107-size.sh` (hand probe, compile + `nm -S`) and the generated
`multi-target-reg-widths.h` (184 / 8) agree.  So the shared allocation is 96
and aarch64 writes 184: **an 88-byte stack overflow per function**, not the
8 bytes `cl_optimization` had.  The brief's premise reproduced exactly.

## DOES `cumulative_args_t` ALREADY ISOLATE THE LAYOUT?  PARTLY -- AND THAT IS
## WHY THIS BUG SURVIVED `27760d3947c`

**Yes at the hook boundary.**  `cumulative_args_t` is `{void *magic; void *p;}`
-- no layout crosses it -- so all ~30 `targetm.calls.*` calls were already
safe, and that is genuinely why nothing type-checked wrong.

**No at the three places that are not the hook boundary**, and those are the
whole bug:

  1. the STORAGE (`function.cc`, `calls.cc` x2, `expr.cc`, `dse.cc`,
     `var-tracking.cc`, and `incoming_args::info`) -- declared with the type;
  2. `INIT_CUMULATIVE_ARGS` and friends, MACROS taking the struct by
     reference, expanded in shared code against the primary's `tm.h`;
  3. `function.cc`'s `crtl->args.info = all.args_so_far_v` -- a struct
     assignment, i.e. the primary's `sizeof` deciding how much of the selected
     back end's accumulator survived.  Now a `memcpy` of the SELECTED base's
     own size.

`calls.cc:1342`'s `get_cumulative_args` was the one remaining cast in shared
code and turned out to be **an unpack/repack round trip** -- its only two uses
repacked it immediately, no field was ever read.  Deleted.

**Alignment does NOT differ today** (8 and 8).  It is asserted rather than
assumed, at `8 <= 8` with no slack.

## WHAT LANDED

  * `gcc/mt-cumulative-args.h` -- `struct mt_cumulative_args` (opaque bytes,
    union-bounded) + `MT_INCOMING_ARGS_PAD` + the shared-side alignment
    assertion.  Reached from `emit-rtl.h`.
  * `gcc/target-cumargs.{h,cc}` + `-select.cc` -- the `target-regs.cc` shape
    for five macros (INIT_CUMULATIVE_ARGS, ..._INCOMING_ARGS, ..._LIBCALL_ARGS,
    CALL_POPS_ARGS, OVERRIDE_ABI_FORMAT).
  * probe + `gen-reg-widths.sh` extended with the two new maxima.
  * `MULTI_TARGET_OBJS_<base>` for the per-base table, `OBJS` for the selector
    -- the brief's placement note is right, and `lto1` links.

`incoming_args::info` KEEPS its `CUMULATIVE_ARGS` type deliberately: 19 back
ends spell `crtl->args.info.<field>` and each means its own struct.  The pad is
`BOUND - sizeof + 1`, so `info + pad` is the same byte count in every TU
(96+89, 184+1) and every later offset in `rtl_data` agrees.  **Zero `config/`
files edited.**

## WHERE aarch64 STOPS NOW -- IT MOVED, AND NO ARM IS CLAIMED

    before  rc=4  30 bytes  crash in ix86_call_abi_override
    after   rc=4  30 bytes  crash in aarch64_set_current_function,
                            via invoke_set_current_function_hook

Same verdict, **different frame**: it is now aarch64 code that runs and dies,
one macro further on.  x86_64 is `rc=0`, 12369 bytes, md5 `378fc33c1e70`,
**byte-identical before and after**.  Scoring is on `rc`; `[ -s out.s ]` is
green for both of these.

## THE GUARD, SEEN FIRING -- `scratchpad/t107-guards.sh`, 4/4

    0 CONTROL     unperturbed aarch64 target-cumargs.cc     compiles rc=0
    1 BOUND-SIZE  bound shrunk to 96                        static assertion
    2 BASE-GROWS  aarch64 CUMULATIVE_ARGS +256 bytes        static assertion
    3 ALIGN       bound align 16, in a SHARED TU            static assertion

**The arms compile by hand, not through `make`, and that is required.**  The
bound is DERIVED from the same probe as the thing it bounds, so under `make`
growing a back end regenerates the bound and the assertion correctly stays
quiet.  A `make`-based demonstration of this guard cannot work.

## REGRESSION BARS, ALL MEASURED

  * `make cc1` rc=0; **`lto1` links**.
  * stock-compare, absolute `IN=/tmp/acc2/t.c`, `MT=/tmp/b107`: 5/5 IDENTICAL,
    5 distinct md5 per side, negative control firing, `rc=0`.
  * 230 header arms: i386 115 PASS / 0 FAIL, aarch64 5 PASS / 110 FAIL.
    58 TAB arms: i386 29 / 0, aarch64 24 / 5.  Unchanged, verdict by verdict.
  * TAB needs `MTP=/tmp/mtp-before` (it has the PROVENANCE.txt); pointing it at
    a fresh macro-probe dir fails by name, correctly.

## TWO TRAPS THIS TASK PAID FOR -- READ BEFORE EDITING `gcc/Makefile.in`

  1. **`gcc/Makefile` has no dependency on `gcc/Makefile.in`.**  An edit there
     is invisible to an incremental build.  It presented as `undefined
     reference to target_cumargs_for` with `target-cumargs-select.cc` simply
     never compiled -- reads like a missing source file.
  2. **`$D/gcc/config.status` IS NOT GCC'S.**  `t10*-ts.sh` runs
     `target-specs/configure` with cwd `$D/gcc`, which OVERWRITES it.  Running
     it reports `invalid argument: Makefile`.  Use
     `scratchpad/t107-reconf-gcc.sh` (removes `gcc/Makefile`, lets the TOP
     LEVEL reconfigure gcc), and run `target-specs` LAST.

## A FIGURE IN THE BRIEF THAT DID NOT REPRODUCE

The **incremental stderr floor here is 8 lines, not 32**: the 8 `is unchanged`
lines reproduce exactly, and the 24 `'@' is redundant` lines did **not appear
at all** in a no-op `make` in `/tmp/b107`.  I did not chase why (they appear in
the cold arm).  Cold `all-gcc` + `cc1 lto1` here was 721 lines / 345
`warning:`, consistent with the recorded ~870/~370.  **Do not score a build in
this dir against 32.**

## FILES (scratchpad)

    t107-build.sh      build harness, SRC/D repointed at this worktree
    t107-go.sh         wrapper: logs to $LOG.log/$LOG.err, prints stderr counts
    t107-size.sh       MEASURE sizeof/alignof CUMULATIVE_ARGS per base
    t107-guards.sh     the four fail-by-name arms above
    t107-reconf-gcc.sh reconfigure gcc/ after a Makefile.in edit (trap 2)
    t107-run.sh        both targets through cc1; verdict = rc
    t107-ts.sh         target-specs configure per target (run LAST)

## WHAT I DID NOT DO

`PUSH_ROUNDING` and `REG_PARM_STACK_SPACE` (#87 existence predicates) are
untouched, as instructed.  Seven of #106's ten `ix86_*` references remain; this
change removes `init_cumulative_args` and `ix86_call_abi_override` from
`function.o` and adds none.  No aarch64 acceptance arm is claimed and no
single-target aarch64 reference was built.

---

# TASK #92 -- three wrong-reason greens retired, one control re-anchored, the
# 60-site layout guard made to fire

Branched from `cc9ef129b37` ("PRINCIPLES: correct the scoreboard, record two
instrument traps").  Build dir `/tmp/b-92`, my own, cold (`scratchpad/t92-build.sh`).
Specs via `t106-ts.sh` repointed -- `rv-specs.sh` is still stale.

## 1. THE THREE RETIREMENTS

`ecad6abf6ae` flipped three aarch64 header arms FAIL -> PASS.  Measured on my
own build with the HEAD scripts, before any change of mine (`/tmp/mtp-92-before`),
they are exactly three of the five aarch64 PASSes:

    FIRST_PSEUDO_REGISTER  INT   92 / 95   -> 95 in all three contexts
    N_REG_CLASSES          INT   34 / 20   -> 34 in all three contexts
    REGNO_REG_CLASS        EXP   regclass_map[..] / aarch64_regno_regclass (..)
                                 -> ((enum reg_class) targetm_regs->regno_reg_class (..))

The first two are now `MULTI_TARGET_UNION_*`: being one number in every consumer
TU is the POINT, because it is the layout of the four shared structures.  The
third is a run-time dispatch.  In all three the per-base fact left the headers,
so a green here is a fact about the redirect.

New status **`CONVERTED_REGS`** in `macro-status.txt`, retired by the same
mechanical gate as `CONVERTED_CDATA`/`CONVERTED_GONE`.  It is separate from
`CONVERTED_CDATA` because the completeness check differs: cdata's redirect is
`#define M (targetm_cdata.`, this one's is `MULTI_TARGET_UNION_*` or
`targetm_regs->`.  One status covering both would accept the wrong redirect.
`macro-probe.sh` also now REJECTS any status word it does not know -- an
unrecognised status was silently read as UNCONVERTED, i.e. keeps a header arm
and is never required to have a TAB arm, which is the gate failing to catch the
thing it exists for.

## 2. THE RE-ANCHORED CONTROL

Re-anchored the **EXP** control from `STACK_POINTER_REGNUM` to
**`SELECT_CC_MODE`**.  Arm 0 (INT) keeps `STACK_POINTER_REGNUM`; STR keeps
`GLOBAL_ASM_OP`.

Why EXP and not INT: `STACK_POINTER_REGNUM` is itself UNCONVERTED and is named
in MACRO-LEAK.md as 7-vs-31, i.e. it is scheduled to be converted.  Two controls
on one macro are one control with two names, and its conversion would have taken
INT and EXP out in the same run with the summary still printing.
`SELECT_CC_MODE` is not a register macro, is untouched by the register work, and
expands to a DIFFERENT CALLEE per base (`ix86_cc_mode` vs
`aarch64_select_cc_mode`) -- the difference EXP is strongest at, rather than a
bare integer INT could have valued.  It is also function-like, so it exercises
the dummy-argument path 168 real EXP arms use and that no control touched before.

The independence is now CHECKED, not asserted: the three witness names are read
back out of the probe sources the controls actually compiled and required to be
distinct.  Prints
`control: OK -- the three phases rest on three DIFFERENT macros (INT=STACK_POINTER_REGNUM STR=GLOBAL_ASM_OP EXP=SELECT_CC_MODE)`.

## 3. THE 60-SITE GUARD -- IT FIRES, AND ITS REACH IS MUCH NARROWER THAN IT LOOKS

Perturbed sites in `gcc/hard-reg-set.h` one at a time (build, run cc1, restore).
`gcc/` is byte-identical to HEAD now; `git diff --stat gcc/` is empty.

    ATTEMPT 1  x_fixed_regs[MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER]
               -> FIRST_PSEUDO_REGISTER          DID NOT FIRE.  cc1 rc=0.
    ATTEMPT 2  x_reg_class_size[MULTI_TARGET_UNION_N_REG_CLASSES]
               -> N_REG_CLASSES                  DID NOT FIRE.  cc1 rc=0.
    ATTEMPT 3  x_reg_names[MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER]
               -> FIRST_PSEUDO_REGISTER          FIRED:

    cc1: internal compiler error: back end 'i386' computes
      'sizeof (struct target_hard_regs)' as 16400, but target-independent code
      allocates 16424; a bound in its header is not spelled MULTI_TARGET_UNION_*

So the guard CAN report the outcome it was built for, and names the struct, the
base and both numbers.  **The two misses are the finding, and they are not
flukes.**

  * ATTEMPT 1 is PADDING.  `char x_fixed_regs[92]` and `[95]` are both followed
    by a `HARD_REG_SET` aligned to 8, so both round to 96 and `sizeof` is
    unchanged.  Measured directly, not inferred: the same TU compiled `mt` and
    `-Ii386-inc -DMULTI_TARGET_REG_PROBE` gave `sizeof (struct
    target_hard_regs)` = 0x4028 on BOTH sides with the perturbation in place.
    A `sizeof` comparison cannot see a shrink that lands in padding, and the
    `char` arrays are exactly the fields where a 3-byte shrink usually will.
  * ATTEMPT 2 is the CONFIGURATION.  `N_REG_CLASSES` is 34 for i386 and 20 for
    aarch64, and the union is 34 -- i386's own.  So for an i386 selection a
    class-bounded bound spelled the unqualified way is the SAME number, and
    nothing can differ.  The guard only ever checks the SELECTED base, and
    aarch64 still ICEs earlier (REAL_MODE_FORMAT), so today the guard's live
    reach is: i386-selected, FIRST_PSEUDO_REGISTER-bounded, and only where
    3 * sizeof(element) survives padding.

    That is a small fraction of the ~71 `MULTI_TARGET_UNION_*` occurrences over
    57 lines in the four headers.  The guard is not weakened by saying so -- it
    is the difference between "passes" and "passes and here is what it can see".
    When aarch64 gets past its ICE, half of this scope limit lifts by itself.

  * Unrelated, for whoever owns `reginfo.cc`: rebuilding it emits 8 copies of
    `reginfo.cc:195: warning: unquoted identifier or keyword 'MULTI_TARGET_UNION_'
    in format [-Wformat-diag]` and a matching `spurious trailing punctuation '*'`.
    Pre-existing, from the guard's own message.  Quote the name.

## 4. TAB ARMS THAT READ THE RUNNING cc1

`tab-plugin.cc` now asks `target_regs_for (base)` inside the linked cc1 -- asked
by name rather than reading `targetm_regs`, so both columns come out of one run
and the lookup `multi_target_select` uses is exercised -- and dumps
`first_pseudo_register`, `n_reg_classes`, the `regno_reg_class` pointer, and the
whole answer vector over the union width.  `SLOTS_PER_BASE` 32 -> 37.

Scored against an INDEPENDENT authority, never against the registry itself:
tab-probe.sh section 4c compiles `char x[VALUE + 1]` in each base's own include
context with `-DMULTI_TARGET_REG_PROBE` and reads the size back with `nm -S` --
the same route `gen-reg-widths.sh` uses, but per base.  The header probe can no
longer serve as that oracle, which is the whole reason these arms moved.
Oracle: i386 92/34, aarch64 95/20, asserted to DIFFER before any verdict.

Six new TAB arms, all PASS.  `REGNO_REG_CLASS` additionally requires distinct
per-base function addresses, differing answer vectors, and the FENCE: every
regno at or past that base's own count must come back NO_REGS.

NEGATIVE CONTROLS, both run, because an arm that has only ever said PASS has not
been shown able to say FAIL:

  * plugin pinned to `target_regs_for ("i386")` for every base -> aarch64
    FIRST_PSEUDO_REGISTER and N_REG_CLASSES FAIL naming 92-vs-95 and 34-vs-20,
    and BOTH REGNO_REG_CLASS arms FAIL with "one body answers for every base".
    That is the `targetm_asm_ops` failure, reproduced deliberately.
  * one poisoned tail entry -> `FENCE: i386 answers 7 for register 94, which is
    past its own first_pseudo_register (92)`.  aarch64 correctly stays PASS,
    because 94 is inside ITS 95.

## 5. SCOREBOARD, BEFORE AND AFTER, ON /tmp/b-92

    BEFORE (HEAD scripts, my build)   230 header arms  i386 115/0   aarch64  5 PASS / 110 FAIL
                                       58 TAB arms     i386  29/0   aarch64 24 PASS /   5 FAIL
    AFTER                             224 header arms  i386 112/0   aarch64  2 PASS / 110 FAIL
                                       64 TAB arms     i386  32/0   aarch64 27 PASS /   5 FAIL

**The aarch64 header number goes DOWN, 5 -> 2, and that is a CORRECTION.**  The
three arms removed were never measuring what they were counted as measuring.
aarch64's remaining two header PASSes are `MAX_BITSIZE_MODE_ANY_MODE` and
`MAX_BITS_PER_WORD`, both INT, both genuinely equal between the bases.  The
aarch64 FAIL count is unchanged at 110 in both runs -- nothing was moved out of
the red column.  The six TAB arms added are the replacement, and they are green
against an oracle that differs between the bases.

Quote **224 header arms: i386 112 PASS / 0 FAIL, aarch64 2 PASS / 110 FAIL;
64 TAB arms: i386 32 PASS / 0 FAIL, aarch64 27 PASS / 5 FAIL.**  The five TAB
reds are the unchanged `CDATA_NUM_OPTSTATE` arms.

## 6. NO REGRESSION

  * `make cc1` and `make multi-target-objs` rc=0 after restoring `gcc/`.
  * cc1 on a trivial input: rc=0, stderr 0 bytes.
  * `stock-compare.sh` with an ABSOLUTE `IN`, `MT=/tmp/b-92`: 5/5 scored, 5/5
    IDENTICAL, 5 distinct md5s per side, negative control fired.  rc=0.
  * `gcc/` is untouched by this change.  Everything landed is under `scratchpad/`.

## WHAT I DID NOT MEASURE

The aarch64 side of the register data is still only reachable through the
plugin's single i386-selected run, because aarch64 cc1 still ICEs before plugin
callbacks fire.  The new arms read aarch64's TABLE, which is constexpr and
therefore complete without a selection -- but nothing here shows aarch64's
register world being USED, and no aarch64 `.s` exists.  That distinction is the
`targetm_asm_ops` lesson and I am not claiming past it.

# TASKS #99, #86, #109 -- TWO BRIEFS REFUTED, ONE REAL CYCLE FOUND

Branched from `cc9ef129b37`, rebased onto `02ede30de42` before reporting.
Commit: `multi-target: give each split object its own depfile, and fix
xtensa's unclaimed extra_objs`.  Instrument and full tables in
`scratchpad/t99-README.md`; only what is not there is repeated below.

## #99 -- THERE IS NO FRAGMENT-SCAN GAP.  THE BRIEF'S PREMISE WAS WRONG

The brief said the awk's notion of "which fragments declare rules" is
incomplete "in at least two independent ways" and asked for a sweep rather
than a one-at-a-time fix.  The sweep was the right instruction and it returned
the opposite answer: **incomplete in ZERO ways.**

  * 209 fragments, **212 `.o` rule targets**, **212/212 matchable** by
    `frag_source_for()` as it stands.
  * Exactly one rule target is not first on its logical line -- `avr/t-avr:67`,
    `avr.o avr-c.o: $(srcdir)/config/avr/builtins.def` -- and it names a
    `.def`, so it claims no source.  `avr-c.o`'s real claim is at `t-avr:54`
    in the shape already read.
  * Zero rules name a bare generated `.cc` undeclared in `generated_files +=`.
    The rs6000 shape (#82) is the only instance of that class and is handled.

The brief's warning that "`a.cc a.h: s-a` scores 0 under a naive `^name *:`"
is a real hazard, but for the **header/generated-file** scans.
`frag_source_for` only ever looks at `.o` rules, and among those the shape
occurs once, harmlessly.

**xtensa was a `config.gcc` defect, not a scan gap.**  `xtensa-unknown-elf`'s
`tmake_file` is EMPTY -- `xtensa/t-xtensa` is not in it.  `config.gcc:646`
gives `extra_objs="xtensa-dynconfig.o"` to every `xtensa*-*-*`, while the
fragment carrying the rule is added only by `*-linux*` and `*-uclinux*`.  The
refusal was **correct**; the object really is unclaimed.  Fixed in
`config.gcc`.  Identical upstream at `c31b7a09eea`, so a stock single-target
`xtensa-*-elf` build should fail the same way -- **argued from `Makefile.in`
(`OBJS` has `$(EXTRA_OBJS)`; `VPATH = @srcdir@`; no `vpath %.cc`), NOT built.**
Worth confirming before reporting upstream.

`--enable-backends=all`: manifest 188 targets, `multi-target-md.mk` 43,186
lines for **48 back ends**, **zero `$(error)`** -- the xtensa refusal is gone
and nothing replaced it.  **I did not run the `=all` BUILD**, so "where it
stops next" is unanswered; what is answered is that it no longer stops in the
generator.

## #86 -- CONFIRMED, AND THE BRIEF UNDERSTATED IT BY ONE FAILURE

Not the concurrency explanation.  The collision is structural: in a pattern
rule `$*` is the stem, and the stem of `insn-emit-<cpu>-%.o` is the shard
NUMBER, so four objects wrote `./.deps/<N>.TPo`.

The failure the brief did not have: **`Makefile.in:6100` reads depfiles under
a different name entirely** (`$(dir obj)$(DEPDIR)/$(notdir obj:%.o=%.Po)` =
`./.deps/insn-emit-i386-1.Po`), which nothing ever wrote.  So
`-include $(DEPFILES)` matched NOTHING for every split object of every back
end -- no header dependencies at all, in every build, silently, surviving
every clean build.  Not intermittent; total.

Three states seen together in `/tmp/b-objs` (read-only, not my fixture):
`.deps/1.Po` holding insn-recog-aarch64-1's deps; `.deps/insn-emit-aarch64-1.Po`
a day stale and naming a build-root source that is no longer the prerequisite;
no `insn-emit-i386-*.Po` at all.

Fixed by emitting explicit rules via `$(foreach)`/`$(eval)`.  After, in a fresh
two-target build: 40 split depfiles, one per object, **zero bare-numeric**, and
the recipe writes `-MF ./.deps/insn-recog-aarch64-1.TPo`.  Header-prerequisite
counts 138/118/130/110 for the four -- distinct, which one shared file could
not be.  `multi-target-md.mk` changes in exactly two hunks; 1605 of 1619 lines
byte-identical.

**The rebuild-correctness arm did NOT work and I am not claiming it.**  All
four objects report "would rebuild" even at baseline, because `<cpu>-inc/s-inc`
is unconditionally out of date (`echo timestamp > i386-inc/s-inc` fires in
every dry run).  An mtime arm cannot discriminate through a prerequisite that
is always newer.  What is measured instead is the thing the arm would have
been evidence *for*: the depfile each recipe writes, and that its name is the
one `DEPFILES` reads.

## #109 -- THE BRIEF'S DIAGNOSIS IS WRONG; THE BUILD FAILURE IS REAL

The brief: "nothing invokes `gen-reg-widths.sh`", `grep -rn` "matches only
inside `gen-reg-widths.sh` itself", "the header is generated by **nothing**",
"broken since `ecad6abf6ae`".

**All four are false, and PRINCIPLES 4 rule 1 says why:** the invocation is in
the GENERATED makefile, not `Makefile.in`.

    gcc/gen-multi-target-md.awk:1138  multi-target-reg-widths.h: $(MULTI_TARGET_REG_PROBES) ...
    gcc/gen-multi-target-md.awk:1801  mt-<cpu>/reg-probe.o: $(srcdir)/multi-target-reg-probe.cc ...
    gcc/gen-multi-target-md.awk:1808  MULTI_TARGET_REG_PROBES += mt-<cpu>/reg-probe.o

`git log -L1138,1141` says those lines were added by **`ecad6abf6ae` itself**.
`grep -rn gen-reg-widths gcc/` returns 8 lines in 4 files, not 1.  The
ordering hook is `Makefile.in:4350`, inside `generated_files`.  Measured, in a
dir built from scratch by me and never hand-run: `make -n` prints
`gen-reg-widths.sh "<nm>" multi-target-reg-widths.h mt-i386/reg-probe.o
mt-aarch64/reg-probe.o`, and `make -j8 cc1 lto1` was **rc=0**.  (That dir is
at base `cc9ef129b37` -- see below.)

### WHAT IS ACTUALLY BROKEN: AN UNSATISFIABLE DEPENDENCY CYCLE

`2ef489d0984` made `emit-rtl.h:26` include `mt-cumulative-args.h`, which
includes `multi-target-reg-widths.h`.  `emit-rtl.h` is reached by GENERATOR
sources.  So:

    multi-target-reg-widths.h
      <- mt-<cpu>/reg-probe.o          (must compile against the base's tm.h)
        <- <cpu>-inc/s-inc
          <- insn-conditions-<cpu>.md
            <- build/gencondmd-<triple>.o
              <- emit-rtl.h -> mt-cumulative-args.h -> multi-target-reg-widths.h

Reproduced in a **genuinely fresh** `/tmp/b-109` at `02ede30de42` + my commit:
`make -j8 all-gcc` rc=2, and the *only* failing object is
`build/gencondmd-<triple>.o`, `fatal error: multi-target-reg-widths.h: No such
file or directory`.  `make multi-target-reg-widths.h` **on its own** fails the
same way, which is what makes it a cycle rather than an ordering bug.

`/tmp/b-objs` showing a stale header with 0 union macros is a *symptom* of the
cycle (the header can only ever exist if someone made it out of band), not
evidence that nothing generates it.

### I DID NOT FIX IT, DELIBERATELY -- PRINCIPLES 2b

The only edge that can be cut is `emit-rtl.h` -> `mt-cumulative-args.h`, and
cutting it means deciding **whether generator programs get the union bound**.
That is design, not debugging: `MT_INCOMING_ARGS_PAD` would need a
generator-side value, and picking one to make the build go is exactly the move
2a forbids.  It is also `2ef489d0984`'s own header and another agent is live
in that area.  Options, with costs:

 1. `#ifndef GENERATOR_FILE` around the include in `emit-rtl.h`, with
    `MT_INCOMING_ARGS_PAD` defined as 1 for generators.  Cheapest.  Defensible
    because a generator is a standalone program compiled once per base and
    shares `struct function` layout with nothing -- but it is a per-base
    divergence in a struct, which is the shape this branch removes, so it
    needs the argument written down rather than assumed.
 2. Split `mt-cumulative-args.h`: the `mt_cumulative_args` storage type and
    the pad/asserts are separate concerns; only `incoming_args` needs the pad,
    and only host code needs `incoming_args`.
 3. Make the widths header not depend on compiling anything -- i.e. get
    `sizeof (CUMULATIVE_ARGS)` without a probe object.  Removes the cycle at
    the root but needs a new mechanism, and the probe exists precisely because
    the answer is per-base and only the compiler knows it.

**The refusal arm for `gen-reg-widths.sh` was NOT run**, because the cycle
means the header cannot be built from make at all in a fresh dir; there is
nothing to perturb.  `scratchpad/.sweep/refusal-arm.sh` (uncommitted, two arms:
emptied probe object, stripped symbol) is ready to run once the cycle is cut.

## WHICH BUILD DIR EACH RESULT CAME FROM -- READ THIS BEFORE QUOTING ANY OF IT

  * `/tmp/b-t99` -- top-level, x86_64+aarch64, base `cc9ef129b37` **+ my
    change**, created by me, `gen-reg-widths.sh` NEVER run by hand.
    `make -j8 all-gcc` rc=0, 863 stderr lines / 370 `warning:` (the cold arm;
    PRINCIPLES says ~870/~370 -- matches).  `make -j8 cc1` rc=0, `make -j8
    multi-target-objs` rc=0, `make -j8 cc1 lto1` rc=0.  All #86 evidence is
    from here.
  * `/tmp/b-109` -- same flags, base `02ede30de42` + my change, fresh.  Fails
    as above.  This is the #109 dir.
  * `/tmp/b-all99` -- `--enable-backends=all`, configure + `multi-target-md.mk`
    only.  Not built.

**The incremental stderr arm reported 0 lines, not 32**, because it ran
immediately after a completed `all-gcc` and nothing re-ran.  That is a
different arm from the one the 32-line floor describes, not a regression, and
`02ede30de42` has since recorded that the floor varies with what was last
rebuilt.

## NOT RUN, AND WHY

`stock-compare.sh` and the 230/58-arm probe scoreboard were not run.  Both are
regression bars against `cc1`, and the only `cc1` I have is at the pre-rebase
base; running them there would measure a tree that no longer exists, and the
post-rebase tree has no `cc1` because of #109.  When the cycle is cut, run them
against a fresh dir before quoting anything.

My change cannot be the cause of #109: its whole diff is the two split-object
rule blocks plus one `tmake_file` line, and the failing include chain
(`emit-rtl.h` -> `mt-cumulative-args.h` -> `multi-target-reg-widths.h`) does
not touch either.

================================================================================
SESSION: #88 and #104 -- the two generated halves of the options machinery
disagreed about the member set.  ONE cause for both, plus a THIRD failure in
the same family that is NOT a generator bug and must not be "fixed" here.
Branched from: cc9ef129b37 ("PRINCIPLES: correct the scoreboard, record two
instrument traps").  Files touched: gcc/opt-stub.awk, gcc/optc-gen.awk.
================================================================================

## ONE CAUSE, TWO SYMPTOMS

`opt-stub.awk` gave every placeholder the fixed flag word `Target
Undocumented`.  `needs_state_p()` is `Target && !Alias && !Ignore` and
`static_var()` then names a private `VAR_<option>` member -- so a stub
FABRICATED a `struct gcc_options` member, and the member's TYPE came from the
stub's own flag word rather than the real option's.  One name, two
authorities, exactly as PRINCIPLES 3 describes it.

  * #88 is the type direction.  rs6000 `mdebug=` is `Target RejectNegative
    Joined` with no `Var`, so `var_type()` answers `const char *`; the stub
    dropped `Joined`, so its member was `int`.  Reproduced by configuring:
    x86_64 + msp430 -> `member VAR_msilicon_errata_warn_ declared twice,
    differently`; x86_64 + powerpc64le -> the same for `VAR_mdebug_`.

  * #104 is the existence direction.  vxworks.opt spells `Bdynamic` `Driver`
    (no member) and `mrtp` `Target Mask(VXWORKS_RTP) Var(vxworks_flags)`
    (the state is the Var, so again no `VAR_` member).  Stubs gave both one.

**Fix: drop `Target` from the stub flag word.**  A stub then declares no
member at all, which is right rather than merely convenient -- the layout
comes from `gcc-options-union.list`, which already carries the real member
from the back end that really declares it, and `options-<base>.h` emits every
union member regardless of base.  A stub member was only ever a duplicate.
The ordinal is untouched (liveness is decided by `Ignore`/`Alias`, not by
`Target`), and the stub loses its `CL_TARGET` bit, so `-mrtp` on an
i386-selected compiler is now diagnosed rather than silently accepted.

## #104 HAD A SECOND HALF THAT THE STUB FIX DOES NOT REACH

With the stubs inert, the vxworks pair still failed -- in the opposite
direction.  `options.cc` is generated from the SHARED optionlist, whose target
records are `extra_opt_files`, i.e. the .opt files of the PRIMARY TRIPLE.  The
layout comes from `gcc-options-<base>.part`, generated from
`optionlist-<base>`, whose target records are the .opt files of EVERY TRIPLE
mapping to that back end.  `x86_64-wrs-vxworks7` and `x86_64-pc-linux-gnu` are
two triples of ONE back end, so vxworks.opt is in the second set and not the
first, and `vxworks_flags` (the struct's 13th member) and `VAR_mvthreads` were
members `global_options_init` had no record for.

So the disagreement ran BOTH WAYS AT ONCE: 1674 elements for a 1669-member
struct, five invented and two missing.  Measured before the change:

    options.cc:1713:1: error: too many initializers for 'gcc_options'

-- the compiler noticed the COUNT and said nothing at all about the 1656
values that were on the wrong member, which is what it would have been left
with had the two errors cancelled.  **That is the version of this bug to fear,
and it is why the fix is not just "make the counts agree".**

`optc-gen.awk` now walks the UNION member list when `-v union_file` is given.
The four loops that built the initializer record into an array instead of
printing; the single-target path prints them in the order they ran (byte
identical, asserted below), the multi-target path prints them in union order
and emits `{}` for a member this back end has no record for.  `{}` and not
`0`: `enum E e = 0` is ill-formed C++, which is how a shifted initializer
announces itself.  Init() is still NOT unioned -- that is settled, the
selector applies it per base.

## THE THIRD ONE IS NOT A GENERATOR BUG.  DO NOT "FIX" IT HERE.

x86_64 + loongarch64 still fails, and the brief lists `recip_mask` as an
instance of #88.  It is not.  Both back ends declare it FOR REAL:

    config/i386/i386.opt:44            int recip_mask = RECIP_MASK_DEFAULT
    config/loongarch/loongarch.opt:35  unsigned int recip_mask = 0

Two `Variable` records, two real authorities, no placeholder involved --
`opt-stub.awk` reserves `Variable` and has never emitted one.  Same family
(one name, several authorities), different authority: the .opt files.  The fix
is to qualify the name there, which is a decision about which back end gets
renamed, i.e. design (PRINCIPLES 2b), not debugging.  Both guards report it by
name (`opth-gen.awk` and `optc-save-gen.awk` independently).  They are working.

## WHAT BUILDS NOW, AND WHAT STOPS WHERE

    x86_64-pc-linux-gnu,x86_64-wrs-vxworks7   make all-gcc rc=0, cc1 + lto1
    x86_64-pc-linux-gnu,aarch64-...-gnu       make all-gcc rc=0, cc1 + lto1
    x86_64-pc-linux-gnu,msp430-unknown-elf    options machinery now clean;
        stops later at genconfig `1 of 2 back ends define HAVE_rotate` (#87)
    x86_64-pc-linux-gnu,powerpc64le-...-gnu   options machinery now clean;
        stops later at the same check on `HAVE_rotatert` (#87)
    x86_64-pc-linux-gnu,loongarch64-...-gnu   still fails, `recip_mask`, above

**Every cross-back-end pair I tried is now gated by #87, not by the options
machinery.**  The vxworks pair builds end to end because both triples map to
the one i386 back end, so there is no second `insn-config` to reconcile.

## EVIDENCE, AND THE THREE TIMES MY OWN INSTRUMENT WAS THE THING THAT FAILED

`scratchpad/t88-prefix.sh` compares the `global_options_init` element sequence
with the `struct gcc_options` member sequence -- the comparison nothing in the
build was making.  It reported FAIL three times before it reported anything
true, each time because the EXTRACTION missed a member shape, not because the
build was wrong:

  * `/* NAME (private state) */` -- the static members carry a suffix, and a
    pattern anchored on `/* NAME */` dropped all of them;
  * `bool frontend_set_<var>;` -- the 11 `SetByCombined` members have no `x_`
    prefix, and a pattern anchored on `x_` dropped all of them;
  * `{}, /* NAME (another back end) */` -- the new foreign-member spelling.

Each looked exactly like a layout bug at a plausible offset.  **If this script
says FAIL, check that the count on both sides is what you expect before
believing it.**  Counts are asserted (>= 500 a side) for that reason.

    t88-prefix.sh    /tmp/b88vx/gcc   1669 == 1669, exact, in order
                     /tmp/b88msp/gcc  1680 == 1680
                     /tmp/b88a64/gcc  1727 == 1727
    t88-vx-before.sh reconstructs the pre-change options.cc from the artefacts
                     of a working build dir (strip the records whose whole flag
                     word is `Undocumented` or `Undocumented Ignore`, re-pad
                     with opt-stub.awk at HEAD) and requires the check to FAIL
                     on it and PASS after.  It does.
    t88-repro.sh     x86_64+powerpc64le: BEFORE fails by name on VAR_mdebug_,
                     AFTER both headers generate and their struct BODIES are
                     byte-identical (10561 lines), not merely the same size.
    t88-bothsided.sh msp430/i386 on `-msilicon-errata-warn=`: owner keeps
                     `CL_TARGET | CL_JOINED` + `offsetof (..., x_VAR_msilicon_
                     errata_warn_)` + CLVC_STRING; the other base's stub is
                     `CL_UNDOCUMENTED` alone with `(unsigned short) -1`.
                     Same, both directions, on the a64 pair: aarch64
                     `-moverride=` and i386 `-mfpmath=`.
    t88-guards.sh    perturbs a COPY of the union list and requires the named
                     error.  GUARD 1 (opth-gen `member X declared twice,
                     differently`) FIRES; GUARD 2 (the new optc-gen `has an
                     element for X and ... has no such member`) FIRES; control
                     clean before, options.h byte-identical after.
    t88-ident.sh     old vs new optc-gen.awk over the same optionlist with NO
                     -v union_file: BYTE-IDENTICAL, 30198 lines, md5
                     87c335bad394.  That is the single-target no-regression
                     bar, and it is stronger than a line count because the new
                     code DEDUPLICATES where the old `static_var` /
                     `SetByCombined` loops did not.

## REGRESSION BARS (all on /tmp/b88a64, x86_64 + aarch64, my own build dir)

    make all-gcc           rc=0, cc1 87 MB and lto1 85 MB linked
    make cc1               rc=0
    make multi-target-objs rc=0
    stock-compare.sh       5/5 IDENTICAL vs /tmp/b-stock, 5 distinct md5s each
                           side, negative control fired (IN absolute:
                           scratchpad/big.c)
    header scoreboard      115 macros / 230 arms: i386 115 PASS 0 FAIL,
                           aarch64 5 PASS 110 FAIL.  The five aarch64 PASSes
                           are FIRST_PSEUDO_REGISTER, MAX_BITSIZE_MODE_ANY_MODE,
                           MAX_BITS_PER_WORD, N_REG_CLASSES (INT) and
                           REGNO_REG_CLASS (EXP) -- unchanged.
    TAB scoreboard         58 arms: i386 29 PASS 0 FAIL, aarch64 24 PASS 5 FAIL.
    static_asserts         9 <= 9 and 1 <= 1 in the a64/vx/msp430 dirs, 9 <= 9
                           and 2 <= 2 in the ppc dir.  optc-save-gen.awk was
                           not touched.

Note for whoever runs the TAB probe next: it aborts with `no PROVENANCE.txt`
if MTP points at a fresh macro-probe output.  MTP must be `/tmp/mtp-before`.

## NUMBERS IN THE BRIEF THAT DID NOT REPRODUCE HERE.  SAY WHICH ARM.

  * **Incremental stderr floor is not 32 lines in this build dir.**  Measured,
    steady state: `make cc1` -> 4 lines, all `tm-<x>.h is unchanged`;
    `make all-gcc` -> 6 lines, those four plus two `check-multi-target-specs:
    NOTHING CHECKED` / `specs: nothing probed` notices.  **Zero
    `'@' is redundant`** -- the 24 the brief attributes to unmodified aarch64
    `.md` files did not appear at all.  Either that changed under another
    agent's `.md` work or the 32 belongs to a different build dir; I did not
    chase it, but do not carry 32 forward unexamined.
  * **Cold `all-gcc` was 593 lines / 102 `warning:`** for the a64 pair, not
    ~870 / ~370.  My CFLAGS are `-O1 -g0`.  Cold numbers on this host have
    already been recorded at 664 / 698 / 867; add 593 to that list and keep
    treating the cold arm as a range, not a figure.

## A DIAGNOSTIC IN SOMEONE ELSE'S TRACKED FILE, TWICE PER BUILD

    gcc/target-regs.cc:65:14: warning: missing terminating ' character
       65 | this back end's table

An apostrophe inside a continued `#error` message.  Harmless in C++ (it is a
warning about a character constant the preprocessor never has to complete),
but it is two of the lines in every stderr count above, and PRINCIPLES has an
entry about apostrophes for a reason.  Not mine; not fixed.

## FILES (scratchpad)

    t88-shell.sh     the DEVSHELL build shell, -p set byte-identical to the
                     known-cached one
    t88-conf.sh      configure <builddir> <backend-list> from this worktree
    t88-build.sh     make wrapper; records rc to <log>.rc because the wrapper
                     itself always exits 0
    t88-prefix.sh    options.cc initializer sequence vs options.h member
                     sequence -- the comparison the build was not making
    t88-guards.sh    both guards, perturbed and restored
    t88-ident.sh     single-target byte-identity + opt-stub non-vacuity
    t88-repro.sh     before/after on one configured pair
    t88-vx-before.sh #104 reconstructed from a working build dir
    t88-bothsided.sh one option, owner and stub, from the per-base tables
    t88-ts.sh        target-specs/configure per target (t106-ts.sh repointed)

# TASK #108 -- SIX FRAME/ARG MACROS + WALL B DIAGNOSED: LANDED (`e0f16c96cbd`)

Branched from `02ede30de42` ("PRINCIPLES: the stderr floor varies...").  Build
dirs `/tmp/b108` (main) and `/tmp/b108f` (fresh-dir acceptance for #109),
x86_64-pc-linux-gnu + aarch64-unknown-linux-gnu.

## THE SIX, WITH DISPOSITIONS -- ALL SIX CONVERTED

    STACK_BOUNDARY                 -> mt_stack_boundary ()
    PREFERRED_STACK_BOUNDARY       -> mt_preferred_stack_boundary ()
    STACK_SLOT_ALIGNMENT           -> mt_stack_slot_alignment ()
    MINIMUM_ALIGNMENT              -> mt_minimum_alignment ()
    OUTGOING_REG_PARM_STACK_SPACE  -> mt_outgoing_reg_parm_stack_space ()
    FUNCTION_ARG_REGNO_P           -> mt_function_arg_regno_p ()

New `gcc/target-frame.h` (struct + shared entry points); supply side in
`target-cumargs.cc` (per base, `-I<base>-inc`); selector in
`target-cumargs-select.cc`; redirect in `defaults.h`'s existing guard block.
The frame table hangs off `target_cumargs_desc` rather than getting its own
registry, because the registry is emitted by `gen-multi-target-md.awk` and
that file was under concurrent edit.  ZERO `config/` files edited.

`nm -uC function.o`:  **8 -> 3** undefined `ix86_*`.

None of the six is an existence predicate; all six are values or functions the
selected back end computes at run time, which is what made them tractable.
They are calls and NOT `target-cdata` fields for a reason already in the tree:
target-cdata.h records `STACK_BOUNDARY` as one of six macros out of thirty-five
MEASURED not invariant under `__attribute__((target))`, because i386's reaches
`ix86_cfun_abi ()`, which reads `cfun`.  Four of the other five take arguments.

## A CORRECTION TO THE BRIEF: `ix86_cfun_abi` IS NOT FROM `STACK_BOUNDARY`

The brief mapped `ix86_cfun_abi` -> `STACK_BOUNDARY` via `TARGET_64BIT_MS_ABI`.
That path is real, and converting STACK_BOUNDARY closed it -- and the symbol
is STILL THERE, because `function.cc` also spells `ACCUMULATE_OUTGOING_ARGS`
(three times, in `STACK_DYNAMIC_OFFSET`), and i386.h:1647 defines that to an
expression containing `TARGET_64BIT_MS_ABI`.

So PRINCIPLES 7's "a symbol's name does not tell you which macro pulled it in"
has a stronger form: **ONE SYMBOL CAN HAVE SEVERAL MACRO PATHS, and converting
the one you were told about leaves the symbol in place.**  Only `nm -uC` after
the change tells you.

Worse, `ACCUMULATE_OUTGOING_ARGS` also dereferences `cfun->machine->func_type`
-- i386's `machine_function` layout applied to whatever back end is selected.
It is a value macro, so it is tractable, and it is not on anyone's list yet.

## THE THREE REMAINING `ix86_*` IN `function.o`

    ix86_cfun_abi              ACCUMULATE_OUTGOING_ARGS   (new, tractable)
    ix86_push_rounding         PUSH_ROUNDING              (#87, not mine)
    ix86_reg_parm_stack_space  REG_PARM_STACK_SPACE       (#87, not mine)

## AN INSTRUMENT NOTE THAT CORRECTS PRINCIPLES 7

PRINCIPLES 7 says plain `nm -u` "scores 0 on nine of ten" of these.  Measured
here: `nm -u function.o | grep ix86_` scores **3**, the same as `nm -uC`,
because the MANGLED name `_Z13ix86_cfun_abiv` still CONTAINS the substring
`ix86_`.  The 0 is real only for a grep that anchors or word-matches
(`grep -w`, `^ix86_`).  Use `nm -uC` regardless -- it is the readable one --
but the failure mode is the PATTERN, not `nm -u` itself.

## WALL B: IT IS A LEAK, BUT OF A KIND NOT YET ON THE LIST -- AN *ABSENCE*

aarch64 still stops at `aarch64_set_current_function`, rc=4, 30 bytes.  It did
not move, and the six had nothing to do with it.  DIAGNOSED FROM THE FAULTING
INSTRUCTION, not inferred:

    1009c53:  mov  0xa0(%r12),%rax   ; fn = DECL_STRUCT_FUNCTION (fndecl)
    1009c5b:  test %rax,%rax
    1009c5e:  je   ...               ; the `if (fn)' guard that IS there
    1009c64:  mov  0x70(%rax),%rax   ; rax = fn->machine
    1009c68:  movl $0x6,0x7b0(%rax)  ; fn->machine->pcs = ARM_PCS_UNKNOWN

`fn` is checked, `fn->machine` is not, and `fn->machine` is NULL.  Cause:

    aarch64.h:1052   #define INIT_EXPANDERS aarch64_init_expanders ()
    aarch64.cc:20604 aarch64_init_expanders sets init_machine_status
    emit-rtl.cc:6038 #ifdef INIT_EXPANDERS ... INIT_EXPANDERS;

`emit-rtl.cc` is SHARED, compiled against the primary's tm.h, and **i386
defines no `INIT_EXPANDERS` at all**.  So the `#ifdef` is false, aarch64's
`init_machine_status` is never installed, `cfun->machine` is never allocated,
and aarch64's own code writes to `NULL + 0x7b0`.

**This runs OPPOSITE to every previous wall.**  Those were "the primary's
ANSWER leaking to everyone".  This is "the primary's SILENCE suppressing a
back end's own initialisation" -- the primary defines nothing, so a feature 13
back ends have is switched off for all of them.  Same root as `HAVE_V8HFmode`
(one authority answering for many) but in a third direction.

    13 back ends define INIT_EXPANDERS: aarch64 arc arm avr cris csky
    epiphany ia64 m32r mmix nds32 sparc visium.  i386 is not among them.

So aarch64's next wall is an EXISTENCE PREDICATE -- `#ifdef` in shared code --
i.e. the #87 family the brief fenced off.  **aarch64 cannot get further until
#87 is addressed**; no amount of value-macro conversion reaches it.  That is
also why #107 and #108 both moved the frame without moving the verdict.

## SCOREBOARD -- AND WHY I AM NOT BANKING THE SIX GREEN ARMS

    230 header arms: i386 115 PASS / 0 FAIL      (unchanged)
                     aarch64 11 PASS / 104 FAIL  (was 5 / 110)
    58 TAB arms:     i386 29 / 0, aarch64 24 / 5 (unchanged, verdict by verdict)

The six new aarch64 PASSes are exactly my six macros, and **all six are
VACUOUS**.  From `/tmp/mtp108/results.txt`:

    aarch64 STACK_BOUNDARY EXP PASS
      mt=[(mt_stack_boundary ())]  ref=[(mt_stack_boundary ())]

The probe's "base B" context is `-Iaarch64-inc -I.` and does NOT define
`MULTI_TARGET_TARGETM_BASE`, so defaults.h redirects there too and the arm
compares the redirect with itself.  This is precisely the wrong-reason flip
PRINCIPLES 4 names: "an arm turning green because both bases now expand to the
same target-neutral text ... retire it as CONVERTED_CDATA with a TAB arm,
never bank it."  **Read the honest aarch64 figure as 5 PASS / 104 FAIL + 6
retired-pending.**  The six need TAB arms from the probe-harness owner; I did
not edit the harness.

The real both-sided evidence for the six is at the object level instead
(`scratchpad/t108-evidence.sh`):

    target-cumargs-i386.o     8 ix86_* refs, 0 aarch64_*
    target-cumargs-aarch64.o  0 ix86_* refs, 3 aarch64_*
    target-cumargs-select.o   defines all 6 mt_* entry points
    function.o                references all 6, and no longer the i386 ones

`INCOMING_STACK_BOUNDARY` is now a genuine RED arm that used to be masked:
`mt=[ix86_incoming_stack_boundary] ref=[(mt_preferred_stack_boundary ())]`.
i386 defines it to a VARIABLE; aarch64 inherits defaults.h's
PREFERRED_STACK_BOUNDARY.  It is the obvious seventh macro and it is tractable.

## #109 -- THE FILED CAUSE IS WRONG, AND THE REAL ONE IS A CYCLE

The brief-time claim was "nothing invokes gen-reg-widths.sh; there is no rule".
**There is a rule.**  `gen-multi-target-md.awk:1138` emits it and
`multi-target-md.mk:1550` carries it; `grep -rln gen-reg-widths` finds the awk.
(Both the coordinator's grep and my first one missed it to `| head`
truncation -- a genuine instrument false negative, PRINCIPLES 4 rule 4.)

The rule is UNREACHABLE, because the prerequisite chain closes a cycle:

    multi-target-reg-widths.h -> mt-<base>/reg-probe.o -> <base>-inc/s-inc
      -> insn-*.h -> build/gencondmd-<triple> -> emit-rtl.h
      -> mt-cumulative-args.h -> multi-target-reg-widths.h

No ordering edge can fix a cycle, and I tried one first (adding the header to
`build/gencondmd.o`) -- it moved the failure to the per-base gencondmd objects.
**That edit is reverted, with a comment saying why, so nobody re-adds it.**

Cut at the only wrong arc: a GENERATOR is single-target by construction (which
defaults.h already says in its GENERATOR_FILE exemption), so under
`GENERATOR_FILE` the union bound is that one base's own `CUMULATIVE_ARGS`.
That is the same arithmetic over a set of size one -- not a fabricated default
-- and `MT_INCOMING_ARGS_PAD` comes out as 1 with both assertions holding at
equality, exactly as they do for the largest base in a real build.

Second half: `EMIT_RTL_H` now names `mt-cumulative-args.h` and
`multi-target-reg-widths.h`.  The only ordering that existed was
`$(ALL_HOST_OBJS) : | $(generated_files)`, which is ORDER-ONLY -- so a stale
widths header never triggered a rebuild, which is the coordinator's observed
symptom (`MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE was not declared`).  Two
symptoms, one missing edge, read from two different starting states.

ACCEPTANCE: `/tmp/b108f`, a genuinely fresh directory, generated
`multi-target-reg-widths.h` by itself with no hand-run of the script, and
built `cc1` and `lto1`, rc=0.

## GUARDS, 4/4 SEEN FIRING -- `scratchpad/t108-guards.sh`

    0 CONTROL      aarch64 target-cumargs.cc compiles          rc=0
    1 SHARED-CALL  static_assert(STACK_BOUNDARY==128) in a     FAILS naming
                   MIDDLE-END TU                               mt_stack_boundary
    2 BASE-EXEMPT  the same assertion in aarch64's OWN TU      rc=0
    3 NON-VACUITY  the same assertion against 64, aarch64 TU   FAILS by name

Arms 1 and 2 are the two sides of the defaults.h fence; if both passed, the
redirect would be reaching back ends too.  Arm 3 exists because an assertion
that is never evaluated also does not fail.  Compiled BY HAND, as #107's were.

## REGRESSION BARS, ALL MEASURED

  * `make multi-target-objs cc1 lto1` rc=0; **`lto1` links**.
  * x86_64: rc=0, 12369 bytes, md5 `378fc33c1e70` -- BYTE-IDENTICAL to baseline.
  * aarch64: rc=4, 30 bytes -- unchanged, and now explained (see Wall B).
  * stock-compare, `IN=/tmp/acc2/t.c` absolute, `MT=/tmp/b108`: **5/5
    IDENTICAL**, 5 distinct md5 per side, negative control firing, rc=0.
  * Incremental no-op stderr: **32 lines, 0 warnings** -- 8 `is unchanged` +
    24 `'@' is redundant` from aarch64 `.md`.  This dir DOES show the 24 that
    /tmp/b107 did not, confirming the PRINCIPLES 6 note from the other side.

## FILES (scratchpad)

    t108-build.sh      build harness (SRC/D repointed at this worktree)
    t108-go.sh         wrapper: logs to $LOG.log/$LOG.err
    t108-run.sh        both targets through cc1; verdict = rc
    t108-ts.sh         target-specs configure per target (run LAST)
    t108-reconf-gcc.sh reconfigure gcc/ after a Makefile.in edit
    t108-evidence.sh   the both-sided nm -uC object-level evidence
    t108-guards.sh     the four fail-by-name arms above

## TRAPS PAID FOR THIS TASK

  1. **`pgrep -f` matched my own poller**, so `until ! pgrep -f X` never
     exits.  PRINCIPLES 5 warns of this and I still paid it twice.  Poll a PID.
  2. `t10*-build.sh` defaults to `SUB=gcc`, so `all-gcc` gives
     `No rule to make target` -- it is a TOP-LEVEL target.  Use `cc1 lto1`.
  3. A `| head` on a `grep -rn` produced a confident false "no rule exists".
     Use `grep -rln` when the question is "does this appear anywhere".

## WHAT I DID NOT DO

`PUSH_ROUNDING` and `REG_PARM_STACK_SPACE` untouched, as instructed.  I did
NOT edit the probe harness, `gen-multi-target-md.awk` or `opt*-gen.awk`.  The
per-base `build/gencondmd-<triple>.o` objects still have no dependency on
`multi-target-reg-widths.h` -- harmless now the cycle is cut, but if anyone
re-introduces that edge it must go in the awk, since no triple-id list
variable is visible from `Makefile.in`.

# TASK #111 -- THE EXISTENCE-PREDICATE ARM MEASURED; TWO CONVERSIONS LANDED

Branched from `9d270fff765` ("PRINCIPLES: two corrections to yesterday's
corrections").  Commits `b4fe5b14cd2` (INIT_EXPANDERS) and `44f80bb9228`
(HAVE_lo_sum / HAVE_rotate / HAVE_rotatert).  Build dirs `/tmp/b111`
(x86_64 + aarch64, mine) and `/tmp/b111m` (x86_64 + msp430, for the rotate
gate).  My worktree started at the bare-repo HEAD and needed the documented
`git reset --hard multi-target`; the check in PRINCIPLES 5 caught it.

## 1. THE POPULATION -- ARM D OF THE #68 SWEEP

The hole was real.  Arms B and C find UNDEFINED SYMBOLS; arm A finds
DIVERGENT MACRO TEXT.  Neither can see "back end P defines nothing, back end
Q defines X, shared code says #ifdef X": there is no undefined symbol (no
code is emitted at all) and no divergent text (one side has no text).

`scratchpad/t111-armD2.sh` (text sweep) + `t111-armD-verify.sh` (the same
question asked of the REAL preprocessor, using emit-rtl.o's exact flags):

    shared TUs scanned                                          2524
    population (config macro, existence-tested in a shared TU)    213
      i386 -- the base shared code compiles against -- has it      88
    ACTIONABLE (>=1 back end has it, i386 does not, no floor)      111
      SILENT (no #else: absence produces NO CODE)                   79
      WRONG  (#else: absence produces a wrong answer)               32
    of the 79 SILENT, confirmed absent by the preprocessor          71
      text false positives (arrive via an included header)           8
    of the 71, macros AARCH64 ITSELF DEFINES                        12

THE SILENT/WRONG SPLIT IS THE FINDING, NOT THE COUNT.  An `#ifdef` with an
`#else` degrades to a wrong answer that tends to fail near the cause.  One
with NO `#else` degrades to no code at all -- nothing is mis-set, and the
failure surfaces arbitrarily far away.  That is exactly why INIT_EXPANDERS
presented as a null dereference inside aarch64_set_current_function.

The 12 that bite aarch64, highest first:

    STATIC_CHAIN_REGNUM 45   EMPTY_FIELD_BOUNDARY 32
    STRUCTURE_SIZE_BOUNDARY 24   FINAL_PRESCAN_INSN 14
    INIT_EXPANDERS 13 (DONE)   ADJUST_INSN_LENGTH 13
    DWARF_ALT_FRAME_RETURN_COLUMN 11   CASE_VECTOR_SHORTEN_MODE 7
    BLOCK_REG_PADDING 6   ASM_OUTPUT_POOL_EPILOGUE 1
    EH_RETURN_TAKEN_RTX 1   HARDREG_PRE_REGNOS 1

### BLIND SPOTS OF THIS ARM -- stated, per PRINCIPLES 4 rule 5

  * `#if X` / `#if X > 0` VALUE tests are NOT in the population.  A macro
    used only that way is invisible here; that is arm A's job.
  * Macros `#define`d in a back end's `.cc` rather than its `.h` are not in
    the defining set.
  * Conditions are not evaluated: a macro defined inside its back end's own
    `#ifdef` counts as defined.  UPPER bound on "back ends defining".
  * SECOND-ORDER LEAKS ARE INVISIBLE.  If shared code is `#ifdef A`, every
    back end defines A, but A expands to something only Q has, this arm is
    silent.  That is the `HAVE_V8HFmode` shape -- direction 1 -- and it is
    NOT covered.
  * v1 of the arm (`t111-armD.sh`, kept) scored 196 actionable because its
    "shared" set WRONGLY INCLUDED SEVEN PER-BASE FILES (target-{addr,asm-ops,
    cdata,c-ops,cumargs,regs}.cc, multi-target-reg-probe.cc) plus target-def.h,
    target-asm-ops.h and `gcc/common/config/`.  Those are correct by
    construction.  v2 asserts the exclusion list is not stale (every name must
    exist AND still have a per-base rule in the awk) precisely so it cannot
    rot into hiding rows.

## 2. WHAT I FIXED

### INIT_EXPANDERS (`b4fe5b14cd2`) -- THE aarch64 WALL

13 back ends define it; i386 does not; `emit-rtl.cc` is shared.  So the
`#ifdef` was false for EVERY target and 13 back ends never got their
`init_machine_status` installed.  Moved to `target-cumargs.cc` (per base,
`-I<base>-inc`) as a `(bool has_init_expanders, void (*init_expanders)())`
PAIR on `target_frame_desc`.  The pair, not a bare pointer: a NULL alone is
indistinguishable from a stale object, and 35 of 48 back ends legitimately
have none, so NULL cannot simply be an error.  They are cross-checked at
selection and disagree by name.

### HAVE_lo_sum / HAVE_rotate / HAVE_rotatert (`44f80bb9228`)

New `target-insn.h`, same supply route.  `HAVE_lo_sum` was the live silent
divergence for my pair (i386 0, aarch64 1) -- two combine transformations and
one LRA path aarch64 CAN express were never attempted, with no diagnostic.

genconfig's unanimity check is DISCHARGED, NOT RELAXED.  Its own message said
"needs that use site made runtime before it can be built"; simplify-rtx.cc
:4773 is now `mt_have_rotate () && mt_have_rotatert ()`, so disagreement is
representable and the check has nothing left to guard.  It is a notice now.
genconfig also emits an explicit `0` so absence is an ANSWER, not a silence.

## 3. WHERE AARCH64 STOPS NOW -- SCORED ON rc

BEFORE (reconstructed in this tree: four files stashed, objects deleted,
rebuilt -- not remembered):

    rc=4, big.c:22 (PARSING), crash_signal -> aarch64_set_current_function
          -> invoke_set_current_function_hook -> allocate_struct_function
          -> store_parm_decls

AFTER: **past it.**  Two distinct further walls, both much later:

    rc=4, big.c:90, gimplify_init_constructor <- gimplify_modify_expr
          <- ... <- cgraph_node::analyze          (whole-file gimplify)
    rc=4, on a MINIMAL input (`int f (int a) { return a + 1; }`),
          during GIMPLE pass local-fnsummary:
          estimate_move_cost <- ipa_populate_param_decls
          <- analyze_function_body <- compute_fn_summary

Not deep recursion -- the traces are short.  `estimate_move_cost` on a
trivial function is the next thing to look at and is a MOVE_RATIO/mode-shaped
read, i.e. plausibly direction 1 rather than this arm.

**aarch64 does NOT emit a complete `.s`** (30 bytes, 2 lines).  I am not
claiming the acceptance arm and there is still no single-target aarch64
reference; `STACK_POINTER_REGNUM` is still 7.

## 4. THE ROTATE GATE IS LIFTED -- MEASURED ON A PAIR THAT DIVERGES

    /tmp/b111m, x86_64 + msp430:
      insn-config-i386.h    HAVE_rotate 1  HAVE_rotatert 1
      insn-config-msp430.h  HAVE_rotate 0  HAVE_rotatert 0

The notice FIRES (so the divergence is real and the check was reached) and
the build continues, past genconfig and the union list, into compiling
msp430's own insn objects.  It stops much later and elsewhere:

    mt-cumulative-args.h:155: static assertion failed ... alignof
    (CUMULATIVE_ARGS); the comparison reduces to (8 <= 1)

msp430 wants alignment 1, another configured base wants 8.  A DIFFERENT wall,
that assertion working, untouched by me.  **That is the next thing gating
cross-back-end pairs**, in place of HAVE_rotate.

## 5. SCOREBOARD -- NOT BANKED

I did not run the header/TAB probe harness and did not edit it.  Neither
conversion adds a probe arm, and per the standing rule the honest aarch64
figure remains **5 PASS / 104 FAIL + 6 retired-pending** (#108's six), TAB
27/5.  Nothing here should be read as moving those.  `INIT_EXPANDERS`,
`HAVE_lo_sum`, `HAVE_rotate` and `HAVE_rotatert` are not on the probe list at
all; if arms are wanted for them they must be TAB arms (the header probe's
per-base context lacks `MULTI_TARGET_TARGETM_BASE`, so both sides would read
the same redirect text -- the vacuous shape #108 correctly refused).

## 6. REGRESSION BARS, ALL MEASURED ON /tmp/b111

  * `make multi-target-objs cc1 lto1` rc=0; **`lto1` links** (86 MB).
  * x86_64: rc=0, 12369 bytes, md5 `378fc33c1e70` -- byte-identical to the
    reference, after BOTH commits.
  * `stock-compare.sh`, `IN` absolute, `MT=/tmp/b111`: **5/5 IDENTICAL** vs
    /tmp/b-stock, 5 distinct md5 per side, negative control firing, rc=0.
    Run after each commit.
  * Guards: `t111-guards.sh` 4/4, `t111-insn-guards.sh` all arms.

### STDERR: THE SAME DIRECTORY GAVE 0 AND 32 ON THE SAME DAY

Incremental no-op `make multi-target-objs cc1 lto1` in `/tmp/b111` measured
**0 lines** at one point and **32** later -- 8 `is unchanged` + 24
`'@' is redundant` from aarch64 `.md` -- differing only by what had last
rebuilt.  Cold `multi-target-objs cc1 lto1` here was **354 lines / 58
warning:** with `-O1 -g0`, and 546/85 on a rebuild that re-ran the generators.
So: 0, 32, 354, 546 are all from ONE build directory.  **The floor is a
composition, not a number, and quoting one without saying which arm and what
last rebuilt is worthless.**  Add these to the 4 / 8 / 32 / 593 / 664 / 698 /
867 already on record.

## 7. TRAPS PAID FOR THIS TASK

  1. **An apostrophe inside a single-quoted awk body ended the shell quote**
     and produced a syntax error 40 lines further down, in code that looked
     fine.  PRINCIPLES has an entry on apostrophes; it is about `#error`
     messages, and this is the same trap in a shell script.
  2. **My own guard matched its own comment prose.**  Arm 2 of t111-guards
     grepped `ifdef INIT_EXPANDERS` and FAILED -- on the two comments in
     emit-rtl.cc that quote the guard they replaced.  Anchor existence checks
     on a directive, not on the text.
  3. **`nm` without `-C` shows `_ZL12mt_base_insn`**, so an exact field match
     finds nothing.  It failed BY NAME rather than scoring 0, which is the
     only reason it cost minutes.  PRINCIPLES 7 is right that the lesson is
     the pattern, not the tool -- but an anchored match needs `nm -C`.
  4. `gcc/Makefile` still has no dependency on `gcc/Makefile.in` (#108).
     `t111-reconf-gcc.sh` is the #108 script repointed; it is required after
     any `Makefile.in` edit and asserts the new object reached the Makefile.

## 8. FILES (scratchpad)

    t111-armD.sh         arm D v1 -- KEPT so its two corrections are auditable
    t111-armD2.sh        arm D v2 -- the population; per-base exclusion list is
                         self-checking, SILENT/WRONG classified
    t111-armD-verify.sh  the same question asked of the real preprocessor
    t111-guards.sh       INIT_EXPANDERS, 4 arms, both-sided
    t111-insn-guards.sh  target-insn.h, reads mt_base_insn out of .rodata for
                         both bases and requires the two tables to DIFFER
    t111-build/go/run/ts.sh, t111-reconf-gcc.sh, t111m-build.sh

# TASK #45 / #98 -- HANDOVER (config.gcc + configure.ac variables nothing sets)

Branched from `0b7c0542b2b`.  Landed as `df3fbeb8915`.  Build dir `/tmp/b45`
(mine, x86_64 + aarch64); `--enable-backends=all` dir `/tmp/b45all`.

## 1. PER VARIABLE: CODE OR COMMENT, SET OR UNSET, OURS OR UPSTREAM'S

The brief asked for this distinction explicitly because #71 was filed the same
way and was INVERTED (`with_multllib_default` is comments only and correctly
spelt).  Establishing it first was right: it changed the verdict twice.

| variable | code/comment | settable? | whose | action |
|---|---|---|---|---|
| `ld_flavor` | CODE (`config.gcc:1158`) | no | **upstream** | conditional deleted, body kept |
| `disable_initfini_array` | CODE (`:2979`) | no | **upstream** | conditional deleted, body kept |
| `x86_with_multilib` | CODE, but message text only, in an arm unreachable here | no | **upstream** | **NOT CHANGED** -- see below |
| `offload_targets` | CODE (`configure.ac:818`) | no | **ours** (the option was deleted here) | explicit `AC_DEFINE(...,"")` |
| `t_t_f_c` | COMMENT only (`:189`) | -- | upstream | none -- the #71 shape |
| `target_header_dir` | COMMENT only (`:1284`) | -- | ours | none -- the #71 shape |
| `enable_multilib` | COMMENT only (`:1878`, `:2623`) | -- | ours | none -- the #71 shape |

**Do not re-file the last three as bugs.**  They are prose describing things
that were removed, which is exactly what #71 turned out to be.

### The method point worth keeping

`with_*`/`enable_*` are auto-assigned by generated `configure` from the command
line **even with no `AC_ARG_WITH`/`AC_ARG_ENABLE`**.  So "no `AC_ARG_*` and no
assignment" does NOT mean unsettable, and a naive scan of `config.gcc` reports
~40 false positives (`with_avrlibc`, `with_fp`, `enable_fdpic`, ...).  The
genuinely unsettable set is much smaller and is the table above.  Any future
sweep that skips this step will re-file the same 40.

### `ld_flavor` is UPSTREAM'S, and I first concluded the opposite

The tempting reading -- "this branch deleted the `ld_flavor` probe, so we broke
it" -- is WRONG, and measurement refuted it.  Upstream sources `config.gcc` at
`configure.ac:1927` and only assigns `ld_flavor=gnu` at `:2819`.  The read has
therefore ALWAYS been empty, upstream included, and upstream documents the rule
it breaks at `:2866`.  Extractable upstream as-is.

## 2. STILL OPEN -- ROUTED, NOT DONE

### (a) `accel_dir_suffix` needs a `Makefile.in` hunk -- ANOTHER AGENT'S FILE

Untouched on purpose.  Always empty (`configure.ac:42`, and
`/tmp/b45/gcc/Makefile:74` confirms `accel_dir_suffix = `), but still threaded
through:

    Makefile.in:821   libsubdir = $(libdir)/gcc/$(version)$(accel_dir_suffix)
    Makefile.in:823   libexecsubdir = $(libexecdir)/gcc/$(version)$(accel_dir_suffix)
    Makefile.in:3181  -DACCEL_DIR_SUFFIX=\"$(accel_dir_suffix)\"

and consumed in `gcc.cc` at 1763, 5667, 8686, 9240, 9470.  Removing it is a
`Makefile.in` + `gcc.cc` + `configure.ac` change, so it is one routed unit.

**This is a DESIGN question, not a cleanup, and it belongs to #96.**
`accel_dir_suffix` sits in exactly the path #96 extends -- per-target data at
`$(libdir)/gcc/$(version)/<target>/`.  There are then TWO per-target axes
(offload accel target, and configured target) and nobody has said how they
compose.  Offloading is GCC's pre-existing narrow multi-target: one host
compiler also emitting for nvptx/amdgcn.  If it returns, accel targets are
arguably just more configured targets and the suffix should not exist as a
separate axis at all.  Decide that with #96 rather than deleting the suffix
first and discovering the axis was load-bearing.

### (b) `gcc/config.in` IS STALE BY ~278 LINES -- found incidentally

`autoheader configure.ac` produces a **-278 / +2** diff.  ~46 macros still have
`#undef` entries whose `AC_DEFINE`s this branch removed (`HAVE_AS_*`,
`HAVE_GAS_*`, `LD64_*`, `DSYMUTIL_VERSION`, `USE_AS_TRADITIONAL_FORMAT`, ...).

Behaviourally inert -- a `#undef X` that configure never converts to `#define`
leaves X undefined, same as deleting the line -- so this is NOT urgent.  But it
means **anyone who runs `autoheader` gets a 278-line drive-by in a shared file**.
I reverted it and hand-applied only my own hunk, so my diff stays reviewable.
Worth doing deliberately as its own commit; it is a good independent check on
"which target probes are really gone".

### (c) `config.gcc` error messages go to STDOUT

`config.gcc:3032` and the two x86 sites `echo` rejections without `1>&2`.  The
riscv comment at `:2623` already records this biting once ("an empty message
because the echo went to stdout").  Not fixed here -- it is a separate sweep
across many arms.

## 3. TRAPS PAID THIS TASK

1. **`config.status --recheck` AT THE TOP LEVEL DOES NOT RECONFIGURE `gcc/`.**
   `gcc/auto-host.h` and `gcc/config.status` kept their original timestamps.
   The `diff` then said "identical" about a file nothing had touched -- a
   comparison that could not have failed.  `t45-reconf.sh` now asserts the
   mtime advanced before any verdict is believed.
2. **A hand-run `cd gcc && config.status --recheck` SILENTLY FLIPPED
   `TARGET_PROVIDES_LIBATOMIC` from 1 to undefined.**  `TARGET_CONFIGDIRS`
   reaches `gcc/configure` only as an env var exported by the top-level
   Makefile.  `configure.ac:2650-2665` ALREADY DOCUMENTS THIS EXACT FAILURE and
   I walked into it anyway -- the warning is in the file, and it was still
   cheaper to hit than to read.  Correct route: remove `gcc/config.status` and
   `gcc/Makefile`, reconfigure via the TOP-LEVEL make.
3. **My probe harness was wrong in four ways, all failing TOWARDS the
   hypothesis** -- every arm read "empty", which is exactly what "the branch is
   not taken" looks like:
   `set -u` killed the subshell at `config.gcc:306`'s unset `${target_min}`
   before the value was ever read; `"$@"` ran the forced assignments as
   COMMANDS so the forced arms were never forced; `eval "echo \"\$$v\""`
   double-expanded and ran `$(exeext)` as a command substitution; and the
   triples were not run through `config.sub`, so `msp430-elf` fell through to
   `*)` and printed "not supported" -- the harness's omission, not a fact about
   msp430.  The non-vacuity counter in `t45-probe.sh` exists because of this:
   an all-empty run is now FATAL, never a result.
4. **The `-p` set matters for reconfigures.**  Adding `autoconf269 automake116x`
   to the recheck shell put binutils' `ld.bfd` on PATH and configure's link
   probes failed with `cannot find -lgcc` -- the hazard `t111-build.sh` already
   warns about.  Reconfigure in the SAME known-cached set as the build.

## 4. NUMBERS I COULD NOT RECONCILE WITH THE BRIEF

The brief's `--enable-backends=all` figure, "**43,186 lines** for 48 back ends",
matches no artefact `configure-gcc` produces here.  Measured:

    multi-target-common.mk          4033
    multi-target.manifest           4512
    multi-target-common.h            240
    multi-target-spec-functions.h    239
    total                           9024

"48 back ends" IS right -- 48 distinct `cpu_type` across **188** target stanzas.
The 43,186 is presumably a later, make-generated artefact (`multi-target-md.mk`)
or is stale.  **Zero `$(error)` is the part that matters and it holds.**
Reporting it as "43,186 lines" without saying which file would be quoting a
number I did not measure.

## 5. REGRESSION BARS, MEASURED ON /tmp/b45

  * `make cc1 multi-target-objs lto1` rc=0; `lto1` links (86 MB).
  * x86_64: rc=0, 12369 bytes, md5 `378fc33c1e70` -- matches the bar.
  * aarch64: rc=4 ICE at `big.c:90`, `gimplify_init_constructor` -- the wall
    STATE.md section 3 already records.  Unchanged.
  * `stock-compare.sh`, `IN` ABSOLUTE, `MT=/tmp/b45`: **5/5 IDENTICAL** vs
    /tmp/b-stock, 5 distinct md5 per side, negative control firing, rc=0.
  * `--enable-backends=all`: configures, 188 stanzas, **0 `$(error)`**, and the
    two edited arms are actually covered (msp430 x2, vms x3).
  * Probe scoreboard NOT run and NOT moved: aarch64 5/104 header + 6
    retired-pending, TAB 27/5.  Nothing here adds or retires an arm.

### STDERR -- WHICH ARM

Both `cc1 multi-target-objs lto1` runs here are **COLD** (`auto-host.h` changed,
so everything rebuilt): **637 lines / 101 `warning:`** before, **615 / 100**
after.  Comparable to each other, NOT to the 32-line incremental floor.  The
difference is host-compiler noise from nixpkgs gcc 15.2, not this tree.

## 6. FILES (scratchpad)

    t45-probe.sh    the before/after arm; sources config.gcc per target and
                    reports observables, with a non-vacuity FATAL and all four
                    of its own bugs documented in the header
    t45-reconf.sh   how to reconfigure gcc/ WITHOUT destroying
                    TARGET_PROVIDES_LIBATOMIC; both wrong ways kept
    t45-all.sh      --enable-backends=all blast radius, scored on ARTEFACTS
    t45-build.sh / t45-go.sh / t45-run.sh / t45-ts.sh
                    t111-* repointed at this worktree and /tmp/b45

---

# TASK #78 + #51 -- branched from `0b7c0542b2b`, build dir `/tmp/b78`

Two tasks, one worktree.  #78 is measured and LANDED; #51 is measured and
mostly HANDED OVER, with one part of the brief corrected.

## 1. #78 -- THE PATH TABLE, MEASURED BY RUNNING EACH PATH

`x86_64-pc-linux-gnu`, `/tmp/b78`, real `-flto` objects (12 `.gnu.lto_`
sections in `a.o`, asserted before the link arms are scored).

Two instruments, because neither can see the whole chain:

  * `-###` shows the argv of everything the DRIVER spawns.  It cannot show
    lto-wrapper's argv -- lto-wrapper is spawned by collect2 or by the linker
    plugin, and neither argv is spec text.
  * a SHIM named `lto-wrapper` on a `-B` directory (the driver finds it with
    `find_a_program` and puts it in `COLLECT_LTO_WRAPPER`), which records its
    own argv and `COLLECT_GCC_OPTIONS` and then execs the real one.

| path | what runs | `-ftarget-config=` on the argv | in `COLLECT_GCC_OPTIONS` | verdict BEFORE this task |
|---|---|---|---|---|
| A `-c` | driver -> cc1 | **yes** (as a switch) | yes | forwarded |
| B `-flto -c` | driver -> cc1 | **yes** | yes | forwarded |
| C `-flto` link, default | driver -> collect2 -> ld -> **plugin** -> lto-wrapper | collect2 **yes**; lto-wrapper **NO** | yes | **FAILED LOUDLY** |
| D `-flto -fno-use-linker-plugin` | driver -> collect2 -> lto-wrapper | collect2 **yes**; lto-wrapper **NO** | yes | **FAILED LOUDLY** |
| E `-flto -fuse-linker-plugin` | as C | collect2 **yes**; lto-wrapper **NO** | yes | **FAILED LOUDLY** |
| F plain link, no LTO | driver -> collect2 -> ld | collect2 **yes** | yes | forwarded |
| lto1 | lto-wrapper re-execs **the driver** (`$COLLECT_GCC ... -fwpa`) | inherited: the driver re-resolves its own target | -- | covered by A/B |
| offload / mkoffload | not configured in this build | **UNMEASURED** | -- | see below |

So the answer to the brief's question is: **the driver forwards on every path
it controls; the two spawners it does NOT control -- collect2's
`lto_c_argv` and the linker plugin's `-plugin-opt=` list -- carried it on no
route at all**, and all three LTO link routes died with

    lto-wrapper: fatal error: `decode_cmdline_option' was reached before a
    target was selected

That is `e1b48233f0d` working exactly as it said it would: visible, named, and
pointing at the cause.  It is also **every** `-flto` link, not an edge.

### THE VALUE WAS NOT MISSING, IT WAS STRANDED

The shim's decisive line, identical on all three routes:

        --- argv has -ftarget-config=: 0
        --- env  has -ftarget-config=: 1

`-ftarget-config=` is a switch, so it is in `COLLECT_GCC_OPTIONS` -- which
lto-wrapper treats as mandatory input and reads a few lines into `run_gcc`,
i.e. *after* the decode that needs the tables.  `main()` scanned argv only.

**Landed** (`gcc/lto-wrapper.cc`): when argv answers nothing, scan
`COLLECT_GCC_OPTIONS` for `-ftarget-config=` before `run_gcc`.  Not a fallback
and not a default: same value, same driver, same target selection, read one
step earlier.  Argv still wins when both are present.

After: C, D and E all **rc=0** and produce executables.

### THE OTHER HALF OF THE BRIEF -- WHO HAS THE `cc1` EXPOSURE

`4c3494e210c` moved cc1 off spec text because `-specs=` can replace
`*cpp_options`/`*cc1_options`.  Asked of the other consumers, by doing the
replacing (`scratchpad/t78-exposure.sh`, a one-line user spec file):

| consumer | carrier | replaceable by a user `-specs=`? |
|---|---|---|
| cc1 | a **switch** (`carry_target_config_as_switch`) | no |
| lto-wrapper | `COLLECT_GCC_OPTIONS` (as of this commit) | no |
| **collect2** | `%(link_target_config)` inside `LINK_COMMAND_SPEC` | **YES -- measured 1 -> 0** |

    === BASELINE (no -specs=)
      collect2 argv carries -ftarget-config=<path>: 1
    === WITH a user -specs= that replaces *link_target_config with nothing
      collect2 argv carries -ftarget-config=<path>: 0

**collect2 has exactly the exposure cc1 was taken off, and it is the one
consumer that then fails SILENTLY**: the same run linked `rc=0` and produced a
working binary, because `read_target_caps` returns quietly when it cannot open
the file and collect2 falls back to the built-in capability defaults.  Absence
of an answer read as an answer, with no diagnostic.

**NOT FIXED, DELIBERATELY -- this is a design question (PRINCIPLES 2b).**
`gcc.cc` documents `link_target_config` as a spec deliberately separate from
`cc1_target_config` so "a spec file should be able to configure them
independently".  Making collect2 fall back to `COLLECT_GCC_OPTIONS` would
override a user's spec-file decision, which is the shape 2a warns about.  The
options, with costs:

  1. **collect2 reads `COLLECT_GCC_OPTIONS` when argv has none**, symmetric
     with the lto-wrapper fix; collect2 already calls
     `read_collect_gcc_options()`.  Cost: a user who deliberately blanks
     `*link_target_config` no longer can.  Cheapest, and closes the silent arm.
  2. **collect2 fails by name when it has no target-config**, like cc1 does.
     Cost: any build without target-specs run stops linking.  Loudest, most in
     the spirit of the branch, most disruptive.
  3. **Leave it.**  Cost: a user who copies a stock `*link_command` from
     upstream `-dumpspecs` (which has no `%(link_target_config)` -- the
     `gcc.dg/pr48524.c` shape) silently gets built-in capability defaults at
     link time.

I did not pick one.  `gcc/collect2.cc` was unclaimed in STATE.md, so I could
have; the reason I did not is that it is a ruling, not a bug.

### A THIRD CARRIER NOBODY HAS COUNTED

`readelf -p .gnu.lto_.opts a.o` on a `-flto` object:

    '-fno-openmp' '-fno-openacc' '-fno-pie' '-fcf-protection=none' '-flto'
    '-ftarget-config=/tmp/b78/gcc/specs-x86_64-pc-linux-gnu-config'

Every LTO object carries the **build machine's absolute path** to a target
config.  It cannot select the target (it is read in `find_and_merge_options`,
inside `run_gcc`, after the decode that needs the tables), and
`append_compiler_options`'s `default:` arm drops it again because the option is
`Common`, not `CL_TARGET`.  So today it is inert.  It is still two latent
problems -- a path that need not exist on the linking machine, and two objects
built against different config paths meeting in one link -- and it is a fourth
place the same value lives.  Not touched; recorded.

### WHAT I DID NOT MEASURE

  * **The offload route.**  This build has no offload targets, so
    `compile_offload_image` was never reached.  Note it execs
    `<accel>/mkoffload`, a *different compiler with its own target*, so it is
    probably not the same question -- but that is reasoning, not measurement.
  * **Both-sided (aarch64) evidence for #78.**  `target-specs/configure` for
    `aarch64-unknown-linux-gnu` SKIPS on this host -- no `aarch64-...-as`/`-ld`
    -- and writes no config file at all, exactly as DEVSHELL.md describes.  So
    every #78 arm is x86_64-only.  What replaces the missing second side is
    `scratchpad/t78-guards.sh`, which asks lto-wrapper directly, with only the
    environment carrying the value, and requires the three failure shapes:

        arm 1 PASS  decoded the full option set and reached lto1
        arm 2 PASS  no -ftarget-config= anywhere        -> "before a target was selected"
        arm 3 PASS  config names an unconfigured triple -> "is not one of the targets"
        arm 4 PASS  config path does not exist          -> "no target could be read from it"

    Arm 1 asserts something AFFIRMATIVE (it got as far as spawning lto1), not
    the absence of a message; arm 4 exists because `read_target_caps` is silent
    on a missing file, so without it a mangled path would read as "the
    environment named no target".

### TWO FALSE GREENS IN MY OWN INSTRUMENTS

  1. **The driver's failure message advertises the option it is complaining
     about.**  `grep -c -- '-ftarget-config='` scored 1 on every path in the
     first run -- including paths where the driver had selected no target at
     all -- because the error text contains
     `-ftarget-config=FILE   name a target's configuration file explicitly`.
     The instrument was counting the diagnostic that says the value is ABSENT
     as evidence it was PRESENT.  Fixed by requiring `-ftarget-config=/`; the
     help-text count is now printed beside it so they cannot be confused again.
  2. **`./xgcc` selects no target**, because argv[0] has no triple and there is
     no `default-target` file (correct, by design).  Every early arm was
     measuring a driver that had already failed.  All arms use
     `./x86_64-pc-linux-gnu-gcc`.

## 2. #51 -- SIX NAMES, AND THE BRIEF WAS WRONG ABOUT ONE OF THEM

Measured on `/tmp/b78` over **every** `.o` in the link
(`scratchpad/t51-syms.sh`, `scratchpad/t51-classify.sh`):

  * the primary's un-namespaced `insn-emit-*.o` exports **13,491** bare strong
    definitions (+3 bare COMDAT);
  * **6** of them are referenced by **16** other objects.  Reproduced
    independently in `/tmp/b111`: same 6 names.

| bare name | defined bare in | referenced by | i386 | aarch64 |
|---|---|---|---|---|
| `add_clobbers` | `insn-emit-4.o` | combine.o recog.o rtl-ssa/changes.o | 1 | 1 |
| `added_clobbers_hard_reg_p` | `insn-emit-4.o` | gcse.o recog.o | 1 | 1 |
| `gen_blockage` | `insn-emit-5.o` | builtins.o explow.o function.o insn-output-{i386,aarch64}.o mt-i386/i386.o mt-aarch64/aarch64.o | 1 | 1 |
| `gen_nop` | `insn-emit-2.o` | cfgrtl.o except.o targhooks.o varasm.o | 1 | 1 |
| `gen_speculation_barrier` | `insn-emit-10.o` | targhooks.o | **1** | **1** |
| `gen_movxf` | `insn-emit-7.o` | reg-stack.o | **1** | **0** |

**CORRECTION TO THE BRIEF: `gen_speculation_barrier` is not arm-only.**  Both
configured bases define it in their own namespace (`speculation_barrier` is in
arm, aarch64, mips, **i386**, rs6000, s390 and sparc `.md`).  So **ONE** name
needs a ruling, not two.

The `.md` files would have given the wrong answer for the name the ruling IS
about: `"movxf"` appears literally only in `ia64.md` and `m68k.md`, yet i386
defines `gen_movxf` through a mode iterator.  **Ask the objects, not the
machine descriptions.**

### THE DECOMPOSITION

  * **Class A -- uniform forwarder, no guard involved (2):** `add_clobbers`,
    `added_clobbers_hard_reg_p`.  Declared bare in `recog.h`, emitted
    unconditionally by genemit for every base.  Nothing to decide.
  * **Class B -- uniform forwarder writable, but the CALL is still decided by
    the primary (3):** `gen_blockage`, `gen_nop`, `gen_speculation_barrier`.
    Every configured base defines them, so the forwarder links.  But whether
    the middle end calls them at all comes from `HAVE_blockage` /
    `HAVE_speculation_barrier` in the **singular** `insn-flags.h`, still the
    primary's.  Forwarding fixes *which* expansion runs; it does not fix *who
    decides one runs*.  That is the `insn-flags.h` union job, the same one
    `insn-config.h` has already had.
  * **Class C -- needs a ruling (1):** `gen_movxf`.  `NS::gen_movxf` does not
    exist for aarch64, so a uniform forwarder does not compile.  Its only
    caller is `reg-stack.cc:1170`, inside `#ifdef STACK_REGS` -- x87 code
    aarch64 can never reach.  Options, with costs:
      1. **Forward it, guarded on the base having it, and `gcc_unreachable ()`
         otherwise.**  Cost: reintroduces a runtime "this base cannot answer"
         arm; but it fails loudly and at the right place.  Note it is NOT a
         floor -- there is no wrong answer supplied, only a stop.
      2. **Move `reg-stack.o` into the per-base object set** (it is x87-only
         middle-end code compiled shared today), so the bare name is never
         referenced from a shared TU.  Cost: touches the #68 Arm B boundary and
         `Makefile.in`; arguably the *correct* answer, since `reg-stack.cc` is
         as target-specific as `config/i386` is.
      3. **Union `HAVE_movxf`/`STACK_REGS`** so the reference is only emitted
         for bases that have it.  Cost: largest; it is the same union job as
         Class B and would subsume it.
    I did not pick one.  **Do not force a uniform forwarder onto it.**

### WHY NOTHING LANDED IN CODE FOR #51

`gcc/Makefile.in:1742` and `:1747` name **BOTH** `$(MULTI_TARGET_OBJS)` and the
primary's `$(INSNEMIT_SEQ_O)`, so any forwarder collides with `insn-emit-*.o`
before it can be tested.  The comment at `:2737` claiming OBJS names the former
"rather than" the latter is **false** -- both are on the list.  (The brief's
`:1679`/`:2642` are that file at an older revision.)

`Makefile.in` belongs to another agent, so **this hunk is ROUTED, NOT APPLIED**:

    - remove $(INSNEMIT_SEQ_O) from OBJS (gcc/Makefile.in, currently :1747)
    - correct the false comment at :2737
    - and note gcc/Makefile still has no dependency on gcc/Makefile.in (#108),
      so the edit is invisible incrementally

### WHAT DID LAND FOR #51 -- TWO FALSE INVARIANTS, DELETED

Both are PRINCIPLES 4 rule 3 ("a written invariant is not evidence anyone ran
it"), and both would have sent the next reader looking for code that is not
there:

  * `gcc/gen-target-ns.cc` said the bare `::gen_blockage` "comes from
    multi-target-select.cc, which forwards to the back end in force", and that
    multi-target-select.cc "defines `::gen_blockage' under `#if HAVE_blockage'".
    **Neither has ever been true.**  Replaced with the measurement.
  * `gcc/multi-target-select.cc` headed a block "THE TWO CONDITIONAL ONES" and
    described a `gen_blockage` forwarder underneath it.  Only ONE exists
    (`verify_reg_names_in_constraints`).  Replaced with the six-name table, the
    A/B/C decomposition, and the Makefile.in blocker.

Comment-only; no generated output changes (the x86_64 md5 below is unmoved).

## 3. REGRESSION BARS -- ALL ON /tmp/b78, MY OWN BUILD DIR

  * `make multi-target-objs cc1 lto1 lto-wrapper collect2` **rc=0**;
    **`lto1` links** (86,442,888 bytes).
  * `stock-compare.sh`, `IN` **absolute**
    (`.../scratchpad/big.c`, 150 lines), `MT=/tmp/b78`, `ST=/tmp/b-stock`:
    **5/5 IDENTICAL**, 5 distinct md5 per side, negative control firing
    (1158 vs 804 lines), rc=0.  **-O2 md5 `378fc33c1e70`** -- the recorded bar.
  * `scratchpad/t78-guards.sh`: **4/4**, one affirmative arm and three that
    each remove or corrupt the thing arm 1 relies on.
  * **SCOREBOARD NOT TOUCHED AND NOT BANKED.**  I did not run the header/TAB
    probe harness and neither change adds an arm; the honest figure remains
    aarch64 **5 PASS / 104 FAIL + 6 retired-pending**, TAB **27/5**.
    (PRINCIPLES 6 still quotes the 224-arm framing with aarch64 2/110; that is
    a different accounting and I am not reporting against it.  Flagged, not
    reconciled.)

### STDERR -- SAY WHICH ARM

  * **cold** `multi-target-objs cc1 lto1 lto-wrapper collect2 xgcc`:
    **666 lines / 109 `warning:`**.
  * **after this task's edits**, which touch a generator support file and so
    re-run genrecog/genemit for both bases: **105 lines / 17 `warning:`**,
    composed of 4 `is unchanged` + 24 `'@' is redundant` + 17 `warning:` + the
    rest genrecog/genattrtab **statistics** ("Number of decisions", "longest
    path", "Shared N out of M states").  Those statistics are NOT in the
    documented 32-line incremental floor because that floor was measured on
    builds where the generators did not re-run.
  * `make lto-wrapper` alone: **4 lines / 1 `warning:`** (a pre-existing
    `-Wunused-result` on `read` at `lto-wrapper.cc:1181`, not mine).

Add 105 and 666 to the 0 / 4 / 8 / 32 / 354 / 546 / 593 / 664 / 698 / 867 on
record.  **The floor is a composition; quoting a number without saying what
last rebuilt is worthless.**

## 4. TRAPS PAID FOR THESE TASKS

  1. **The worktree was at the bare-repo HEAD `7208eca60d0`**, as PRINCIPLES 5
     says.  `grep -c MULTI_TARGET gcc/Makefile.in` gave 0.
  2. **`grep -q` under `set -o pipefail` turns a MATCH into a MISS.**  `grep -q`
     exits on the first hit, the upstream stage takes SIGPIPE, the pipeline
     status becomes 141, and `... | grep -q X && echo found` prints nothing.
     Every "who defines this bare name" cell read `<none>` on the first run --
     including names another script of mine had already found in those exact
     objects.  A false negative manufactured by a shell option.
  3. **An apostrophe inside a single-quoted `nix-shell --run` body**, again --
     this time in a comment I had just written *about* trap 2.  STATE.md
     already has this entry; it cost me a second run anyway.
  4. **`make target-specs` no longer exists**, by design (PRINCIPLES 2:
     target-specs runs after the build, as its own configure).
     `scratchpad/rv-specs.sh` drives that rule and is **stale**;
     `scratchpad/t78-specs.sh` runs `target-specs/configure` directly.
  5. **A spec file with an EMPTY body is rejected** -- `specs file malformed
     after 22 characters`.  To measure "a user replaced this spec and their
     value does not mention the target", the body must be text that *expands*
     to nothing (`%{fzzz:...}`), not an empty line.

## 5. FILES (scratchpad)

    t78-build.sh / t78-go.sh   build (t111-build.sh repointed at this worktree)
    t78-specs.sh               runs target-specs/configure per target, and
                               CHECKS THE ARTEFACT, not the exit status
    t78-setup.sh, t78-shim.sh  the lto-wrapper shim and its inputs
    t78-run.sh                 the path table, A-F, -### plus the shim
    t78-guards.sh              4 arms, 1 affirmative + 3 that must fail by name
    t78-exposure.sh            the -specs= replacement arm (collect2: 1 -> 0)
    t51-syms.sh                bare defs in the primary insn-emit x refs
                               elsewhere; states its blind spots
    t51-classify.sh            per-base availability of the six, with a
                               non-vacuity check on the instrument

# TASK #112 -- THE aarch64 SLICE OF ARM D CONVERTED; THE IPA WALL DIAGNOSED

Branched from `0b7c0542b2b` (#111's handover).  Commit `2f214ef2f52`.
Build dir `/tmp/b112` (x86_64 + aarch64, mine).  My worktree started at the
bare-repo HEAD and needed the documented `git reset --hard multi-target`;
the PRINCIPLES 5 check caught it, as it did for #111.

## 1. THE COUNT IS ELEVEN, NOT TWELVE -- AND THE CORRECTION IS A CHECK WORKING

#111's handover named 12 macros aarch64 defines that shared code cannot see,
including `INIT_EXPANDERS` marked DONE.  Re-measured here:

    population (config macro, existence-tested in a shared TU)   212  (was 213)
    ACTIONABLE (>=1 back end has it, i386 does not, no floor)     110  (was 111)
      SILENT (no #else)                                           78  (was  79)
    of the SILENT, confirmed absent by the REAL PREPROCESSOR       70
    of those, macros AARCH64 ITSELF DEFINES                        11

Each figure is exactly one lower than #111's: `INIT_EXPANDERS` leaving the
population is the whole difference, which is a good non-vacuity signal.

**But 12 - 1 = 11 only works because the text sweep ALSO scored a false
positive that the preprocessor arm drops.**  The text sweep says twelve; the
twelfth is `INIT_ARRAY_SECTION_ASM_OP`, and `t112-armD-verify.sh` removes it:
aarch64 defines it, but so does the context shared code compiles in, because
`config/initfini-array.h` is on i386-linux's tm_file chain too.  There is no
absence and nothing to fix.  So #111's list of 12 was one member short AND
one member wrong, and the two errors cancelled in the count -- PRINCIPLES 7's
"a count check passes when two errors cancel", observed again.

**A grep for which back end spells a macro cannot see a definition that
arrives through an included header.**  The text sweep is an upper bound; the
preprocessor arm is what settles membership.  Do not quote the text figure.

### THE ELEVEN, WITH DISPOSITIONS

CONVERTED HERE (4, plus one sibling) -- scalars, into `target-cdata`:

    STATIC_CHAIN_REGNUM            45  targhooks.cc          DONE
    STATIC_CHAIN_INCOMING_REGNUM    1  (same use site)       DONE, rides along
    EMPTY_FIELD_BOUNDARY           32  stor-layout.cc        DONE
    STRUCTURE_SIZE_BOUNDARY        24  stor-layout.cc        DONE
    DWARF_ALT_FRAME_RETURN_COLUMN  11  dwarf2cfi, cppbuiltin DONE

`STATIC_CHAIN_INCOMING_REGNUM` is NOT one of the eleven (one back end, not
aarch64).  It is converted anyway because it shares `default_static_chain`
with `STATIC_CHAIN_REGNUM`; leaving it would put one arm of that function on
the run-time answer and the other on the primary's `#ifdef`.

NOT CONVERTED (7), each with the reason, NOT merely "ran out of time":

    ADJUST_INSN_LENGTH        13  final.cc x4.  CODE, not a value: a statement
                                  macro mutating `length`.  Needs a function
                                  pointer on a per-base descriptor, not cdata.
    FINAL_PRESCAN_INSN        14  same shape (statement macro, 2 sites).
    BLOCK_REG_PADDING          6  13 SITES across calls/expr/function.cc, and
                                  it returns a `pad_direction`.  Biggest of the
                                  seven by call-site count; wants its own task.
    CASE_VECTOR_SHORTEN_MODE   7  returns a `machine_mode`.  BLOCKED on mode
                                  numbering (Stage 4): a mode number moved from
                                  aarch64's vocabulary into shared code means
                                  something else there.  Do NOT convert this
                                  before the mode union is settled.
    EH_RETURN_TAKEN_RTX        1  `gen_rtx_REG (Pmode, R4_REGNUM)` -- an rtx
                                  built lazily, and it spells `Pmode`.  Same
                                  Stage 4 blocker.
    ASM_OUTPUT_POOL_EPILOGUE   1  function pointer; varasm.cc:4809.  Cheap.
    HARDREG_PRE_REGNOS         1  an INITIALISER LIST `{ FPM_REGNUM, 0 }`, so
                                  it is array data, not a scalar.  Cheap.

The natural next slice is `ASM_OUTPUT_POOL_EPILOGUE` + `HARDREG_PRE_REGNOS`
(cheap), then the three statement macros as a family on a per-base descriptor.
The two `Pmode`/mode ones should WAIT.

## 2. THE MECHANISM: `(bool has_X, payload)`, EXTENDED TO cdata

New `TARGET_CDATA_OPT_FIELDS` list in `target-cdata.h`, generating
`signed char has_<f>` + value.  The struct, the refresh, the poisoned
initialiser and the post-refresh check all come from that one list, exactly
as the mandatory list does.

Three things worth keeping:

  * **The flag is THREE-state, not `bool`.**  `false` is a legitimate answer
    -- most back ends define none of these -- so it cannot double as "the
    refresh never ran".  `TARGET_CDATA_POISON_FLAG` is the third state.
  * **The post-refresh check is TWO-SIDED.**  Present implies not-poison;
    absent implies the value slot is STILL POISONED.  The second half is the
    one that catches a leak: a back end reporting "absent" that nonetheless
    wrote a value has evaluated a macro it does not have.
  * **The `#ifdef` survives, in `target-cdata-opt.h`, and that is correct.**
    That header is reachable only from `target-cdata.cc`, i.e. compiled once
    per base with `-I<base>-inc`, so every `#ifdef` is answered by the back
    end the answer is for.  It `#error`s without MULTI_TARGET_TARGETM_BASE.
    A field in the list with no entry there fails to compile BY NAME
    (`MT_HAS_<macro> was not declared`), not as a silent zero -- a silent zero
    would report every back end as having no answer and would look exactly
    like a correct build.

Why cdata and not a new descriptor: all five are constants or enum constants
on the bases that define them, so neither the invariance precondition nor the
"can it be evaluated at the refresh point" precondition bites.  The ones that
take arguments or build rtx cannot come here -- see the seven above.

## 3. TASK B -- WHERE AARCH64 STOPS, AND WHY.  IT IS A LEAK, AND A NEW KIND

Both #111 walls reproduce unchanged.  On the MINIMAL input
`int f (int a) { return a + 1; }`, `-O2`:

    rc=4, GIMPLE pass local-fnsummary, SIGSEGV
    estimate_move_cost <- ipa_populate_param_decls <- analyze_function_body
      <- compute_fn_summary <- pass_local_fn_summary::execute

**DIAGNOSED, and confirmed under gdb (`scratchpad/t112-ipa-diag.sh`), not
inferred:**

    mov 0x31ec3c4(%rip),%rax    # 0x4b6dde8 <ix86_cost>
    mov 0xf4(%rax),%eax         <- SIGSEGV, si_addr == 0xf4
    ix86_cost holds 0x0000000000000000

`tree-inline.cc:4296` is `size > MOVE_MAX_PIECES * MOVE_RATIO (speed_p)`.
`tree-inline.cc` is SHARED, compiled once against i386, so `MOVE_RATIO` is
`config/i386/i386.h:1968`:

    #define MOVE_RATIO(speed) ((speed) ? ix86_cost->move_ratio : 3)

`ipa-prop.cc:395` passes `speed_p = true`.  `ix86_cost` is
`config/i386/i386.cc:130`, `= NULL`, written only by `ix86_option_override`,
which does not run when aarch64 is the selected target.  0xf4 is
`offsetof (processor_costs, move_ratio)`.

### THE CATEGORY: NOT a baked-in constant.  A leak into the PRIMARY'S MUTABLE RUNTIME STATE

The brief's standing suspicion was a baked-in divergent constant
(`STACK_POINTER_REGNUM` 7 vs 31, `UNITS_PER_WORD`, `Pmode`).  **It is not
that.**  It is not a constant at all, and it is not arm D's absence either.
Precisely:

    not arm A       -- no divergent macro TEXT is compared; shared code never
                       sees aarch64's MOVE_RATIO at all.
    not arms B/C    -- `ix86_cost` is DEFINED in i386.cc and links cleanly.
    not arm D       -- no `#ifdef`, nothing absent.
    not a constant  -- it is a POINTER DEREFERENCE of back-end state.

The macro does not expand to a value.  It expands to **a dereference of a
back-end global that only that back end's option-override initialises.**

**THE CRASH IS LUCK, AND THAT IS WHY THIS MATTERS.**  `ix86_cost` happens to
start NULL, so it faults.  A sibling reading a back-end global with a benign
initialiser answers with i386's tuning while compiling for aarch64 and emits
WRONG CODE with no diagnostic at all.  `MOVE_MAX_PIECES` -> `MOVE_MAX` ->
`ix86_move_max` is exactly that, and it is in the SAME EXPRESSION on
tree-inline.cc:4296.

### ARM E -- THE MECHANISM COUNTED (`scratchpad/t112-armE.sh`)

Macros in `config/i386/*.h` whose body reads `ix86_`/`ia32_` state, that are
also spelled in genuinely shared code: **40**.  The instrument's non-vacuity
check requires it to find `MOVE_RATIO` independently, and it does.

Six are already ticketed (target-cdata.h records them as measured NOT
invariant and forbidden from the cheap path): BIGGEST_ALIGNMENT,
STACK_BOUNDARY, STORE_MAX_PIECES, MOVE_MAX, MOVE_MAX_PIECES,
COMPARE_MAX_PIECES.  **The other ~34 have no ticket**, including MOVE_RATIO,
CLEAR_RATIO, BRANCH_COST, REGMODE_NATURAL_SIZE, PIC_OFFSET_TABLE_REGNUM,
DATA_ALIGNMENT, LOCAL_ALIGNMENT, ASSEMBLER_DIALECT, SELECT_CC_MODE.

**40 IS AN UPPER BOUND WITH KNOWN CONTAMINATION.**  Some hits are the
conversion machinery mentioning the macro (`target-cdata.h`,
`target-c-ops-select.cc`) rather than a leak, and `Pmode`/`PUSH_ROUNDING` are
already-known separate problems.  Do not quote 40 as "40 bugs"; re-filter it.
Other blind spots are stated in the script header (text-only; two-step chains
through defaults.h are missed, so it is a LOWER bound on the problem).

### WHY I DID NOT FIX MOVE_RATIO

`MOVE_RATIO` takes an argument, so it cannot be a cdata scalar; it belongs on
`target_frame_desc` as a call, exactly like `STACK_BOUNDARY`.  That part is
easy.  **The reason to stop is that `MOVE_MAX_PIECES` is in the same
expression and is the SILENT member of the same family.**  Converting
`MOVE_RATIO` alone removes the SIGSEGV and leaves tree-inline.cc computing a
move cost from i386's `ix86_move_max` for aarch64 -- turning a loud failure
into a silent wrong answer, and moving the wall somewhere less informative.
That is PRINCIPLES 2a ("a half-fix that makes a failing check pass while the
answer is still wrong is worse than the failure") and 4.

**Decomposition for whoever takes it:** convert `MOVE_RATIO`, `CLEAR_RATIO`,
`MOVE_MAX`, `MOVE_MAX_PIECES` and `STORE_MAX_PIECES` TOGETHER onto
`target_frame_desc` as calls.  Expect the next wall immediately after, and
expect it to be another arm E member rather than an arm D one.

## 4. WHERE AARCH64 STOPS -- SCORED ON rc, NOT ON `-s out.s`

    x86_64  : rc=0 SUCCESS, 12369 bytes / 804 lines
    aarch64 : rc=4 ICE, 30 bytes / 2 lines

Both walls are unchanged by this commit, and I am NOT claiming aarch64 got
further.  **aarch64 does NOT emit a complete `.s`.**  The four conversions are
correct and both-sided but none of them is on the path to either wall -- the
walls are arm E, not arm D.  `STACK_POINTER_REGNUM` is still 7.

That is the honest result and it is worth stating plainly: **arm D's aarch64
slice is real and worth closing, but it was not what was holding aarch64
back.**  #111 moved the wall from parsing to IPA by fixing `INIT_EXPANDERS`;
this one did not move it at all.

## 5. REGRESSION BARS, ALL MEASURED ON /tmp/b112 AFTER THE COMMIT

  * `make multi-target-objs cc1 lto1` rc=0; **lto1 links**.
  * x86_64 -O2 md5 `378fc33c1e70` -- the reference, unchanged.
  * `stock-compare.sh`, `IN` ABSOLUTE, `MT=/tmp/b112`: **5/5 IDENTICAL** vs
    /tmp/b-stock, 5 distinct md5 per side, negative control firing, rc=0.
  * `t112-guards.sh` 4/4, both-sided, TAB-shaped (reads the RUNNING cc1's
    `targetm_cdata` per selected base; the header probe would have compared a
    redirect with itself -- the vacuous shape #108 refused).

### SCOREBOARD: NOT MOVED, DELIBERATELY

I did not run or edit the header/TAB probe harness.  None of the five macros
is on the probe list.  The honest figures remain **aarch64 5 PASS / 104 FAIL
+ 6 retired-pending, TAB 27/5**.  Nothing here should be read as moving them.

### STDERR -- COMPOSITION, AND WHICH ARM

`/tmp/b112`, incremental `multi-target-objs cc1 lto1` after editing 8 files:
**354 lines / 58 `warning:`** on the first pass, **326 / 51** on the second
(fewer files rebuilt).  These are REBUILD arms, not cold and not no-op; the
354/58 figure coincides with #111's recorded cold `-O1 -g0` number, which is
a coincidence of composition and NOT evidence of anything.  Do not compare
either with the 32-line incremental floor.

## 6. TRAPS PAID FOR THIS TASK

  1. **The derived harness still called the ORIGINAL build script.**
     `t112-go.sh`, sed-copied from #111, kept `"$S/t111-build.sh"` because my
     rename pattern only matched paths, not the invocation.  It would have
     built into someone else's dir with someone else's SRC.  Caught by
     grepping the derived scripts for the old names -- `t112-mk.sh` now does
     that automatically and prints residual hits.
  2. **`p ix86_cost` in gdb returned NOTHING, and my first verdict script read
     that as "hypothesis not confirmed".**  The tree is built `-g0`, so there
     is no DWARF and the symbol has no type -- the failure was the
     INSTRUMENT's, not the hypothesis's, and it reported in the direction that
     would have made me abandon a correct diagnosis.  Read globals through the
     minimal symbol table (`x/1gx &sym`) in this tree, and make a
     "not confirmed" distinguishable from a "could not ask".
  3. **A text sweep cannot see a macro that arrives via an included header.**
     `INIT_ARRAY_SECTION_ASM_OP` looked like a clean aarch64-only definition
     and is on i386-linux's chain through `config/initfini-array.h`.  I had
     already written it into a conversion list before the preprocessor arm
     dropped it.
  4. The harness refuses shell redirections and multi-command lines in this
     worktree; anything with `>` or `for ... done` has to become a script
     file.  Several greps and every build wrapper are scripts for that reason
     alone, not by preference.

## 7. FILES (scratchpad)

    t112-mk.sh          derives this task's harness from #111's and ASSERTS no
                        residual t111/b111 references survive
    t112-armD2.sh       arm D v2, repointed -- the population
    t112-armD-verify.sh the preprocessor confirmation; THIS is what settles
                        membership, not the text sweep
    t112-a64.sh         the aarch64 slice; warns loudly when run without the
                        preprocessor confirmation (upper bound)
    t112-a64-defs.sh    per-macro aarch64 vs i386 vs shared-floor definitions
    t112-sites.sh       every SHARED spelling of the converted macros
    t112-armE.sh        NEW ARM: macros reading the primary's mutable state
    t112-ipa-diag.sh    the gdb confirmation of the estimate_move_cost fault
    t112-guards.sh      4 both-sided arms on the running cc1
    t112-build/go/run/ts.sh, t112-reconf-gcc.sh

---

# Tasks #24 + #17 — `TOOL_INCLUDE_DIR` and collect2's tool paths (commit `7983dcdde9e`)

Branched from `0b7c0542b2b` (STATE: #111 handover). Worktree started at the
bare-repo HEAD `7208eca60d0`; `git reset --hard multi-target` recovered it.

## 1. What was wrong, and why nothing here could see it

**`gcc_tooldir` did not collapse to `$(prefix)/include`. It collapsed to
`$(prefix)/../include`.** Measured in a real configured tree, not derived:

    prefix               = [/tmp/fp]
    libsubdir            = [/tmp/fp/lib/gcc/17.0.0]
    libsubdir_to_prefix  = [../../../../]          <- FOUR ups, not three
    target_noncanonical  = []
    gcc_tooldir          = [/tmp/fp/lib/gcc/17.0.0/../../../../]
    TOOL_INCLUDE_DIR     = [/tmp/fp/lib/gcc/17.0.0/../../../..//include]
    readlink -f          -> /tmp/include
    build_tooldir        = [/tmp/fp/x86_64-pc-linux-gnu]   <- the fixed sibling

So under `--prefix=/usr/local` it is **`/usr/include`** exactly as #24 said,
and the mechanism is worse than "the target component is empty": with the
component gone, `libsubdir_to_prefix`'s fourth `..` escapes the prefix. **A
side finding I did not chase: `libsubdir_to_prefix` looks off by one in its own
right** — `unlibsubdir` (`../../..`) already accounts for libdir's last
component, and the `sed` counts it again. It is invisible while a non-empty
`$(target_noncanonical)` is appended. `gcc_gxx_include_dir` is built from the
same variable, so `GPLUSPLUS_INCLUDE_DIR` is very likely one directory too high
as well. **Not measured. Worth a task.**

**Why every earlier arm scored it green.** `cc1 -v` prints only include
directories that *exist*, and on NixOS none of the built-in ones do. Both arms
print an empty list. My first four measurements were vacuous for that reason,
and two of them looked like clean passes:

    === /tmp/b111  target=x86_64-pc-linux-gnu
    #include <...> search starts here:
    End of search list.

That is not "the entry is absent". It is "this host cannot answer".

## 2. The environment that could see it

`--prefix=/tmp/fp` with two directories created by hand, and the second one
was the part I got wrong first:

  * `/tmp/include/t24poison.h` — the poison header, at the path the `..`-chain
    actually resolves to. Putting it in `/tmp/fp/include` (the path the *name*
    suggests) made the test report "not found" in both arms — a false green,
    from a poison file the compiler was never going to look for.
  * `/tmp/fp/lib/gcc/17.0.0/` — **required**, and this is the subtle one. A
    `..`-relative path cannot be traversed if the intermediate directories do
    not exist, so before I created it the entry was dropped for a reason that
    had nothing to do with the bug.

Two full builds under that prefix, one per arm, so no `git stash` A/B:

    /tmp/b24-before   SRC=.../agent-a583ac0157ff44074   (pre-change tree)
    /tmp/b24-after    SRC=.../agent-ad79a17e47a430c73   (this tree)
    scratchpad/t24-fp-build.sh, driven by SRC= D= PREFIX=

`scratchpad/t24-poison.sh` uses `-fsyntax-only`. It must: with codegen on,
**aarch64 ICEs in `ix86_data_alignment`** on `int x = 1;` — i386's hook
answering for aarch64, present in BOTH arms, nothing to do with this change.
**Unreported elsewhere as far as I can tell; it deserves its own task.**

## 3. Results

    BEFORE  x86_64:   FOUND /tmp/include/t24poison.h   <-- host header reached
    BEFORE  aarch64:  FOUND /tmp/include/t24poison.h   <-- the SAME directory
    AFTER   x86_64:   not found
    AFTER   aarch64:  not found

and the `-v` lists, which name the path rather than just scoring it:

    BEFORE both targets:  /tmp/fp/lib/gcc/17.0.0/include
                          /tmp/fp/lib/gcc/17.0.0/../../../..//include
    AFTER  both targets:  /tmp/fp/lib/gcc/17.0.0/include

Per-target arm (`scratchpad/t24-perTarget.sh`), three arms + control each:

    x86_64   absent 0 | verbatim /tmp/t24-tid-x86 | searched "x86-tool-include-dir" | control 0
    aarch64  absent 0 | verbatim /tmp/t24-tid-a64 | searched "a64-tool-include-dir" | control 0

The `absent` arm self-checks that the shipped config file has no
`tool_include_dir` line, so it cannot pass vacuously.

## 4. #17 — and a comment in the tree that was wrong

`gcc/Makefile.in` claimed collect2 searched `"-nm"`, `"-ld"`, `"-strip"`
because `$(target_noncanonical)` is empty. **The concat it described never
compiled**: every one of those lines was inside `#ifdef
CROSS_DIRECTORY_STRUCTURE`, so `target_machine` did not exist as a variable and
collect2 searched the *unprefixed* names — the host's tools, for every target.
Two faults in opposite directions cancelling into something that reads
harmless. Measured with `collect2 -debug`, which reports the NAME asked for
rather than what happens to exist here:

    BEFORE  x86_64:   collect-ld gcc gnm gstrip ld nm real-ld strip
    BEFORE  aarch64:  collect-ld gcc gnm gstrip ld nm real-ld strip      identical
    AFTER   x86_64:   ... + x86_64-pc-linux-gnu-{ld,nm,strip,gnm,gstrip,gcc}
    AFTER   aarch64:  ... + aarch64-unknown-linux-gnu-{ld,nm,strip,gnm,gstrip,gcc}

The enabling change is ordering: the `-ftarget-config=` scan now runs BEFORE
the `full_*_suffix` construction, which used to be `const char *const`
initialisers in the declaration block — which is *why* the question had to be
a compile-time one.

`real_{ld,nm,strip}_file_name`, via `collect2`'s own resolution dump (an
execution test scores both arms the same here, because with no `ld` on this
host collect2 gives up before it would run `nm`):

    BEFORE  c_file_name = gcc            nm_file_name = not found   (key ignored)
    AFTER   c_file_name = x86_64-pc-linux-gnu-gcc   nm_file_name = <the named one>
    AFTER   collect2: fatal error: target 'x86_64-pc-linux-gnu' sets
            'real_nm_file_name' to '/nonexistent/x86_64-pc-linux-gnu/nm',
            which is not an executable file
    AFTER   ... and the same naming aarch64-unknown-linux-gnu

`MD_EXEC_PREFIX` needed no capability: **collect2 never read it.** Only
`gcc.cc` does, and there it already travels through the spec file
(`gen-target-specs.cc` emits `md_exec_prefix`). The `#undef` was suppressing
nothing. It is now unconditional so no `tm.h` can reintroduce one.

Corrected in passing: `target-caps.cc`'s header claimed *"Only cc1 calls
read_target_caps"*. The driver (`gcc.cc:8716`) and collect2 (`collect2.cc:916`)
both do, and collect2 has since `fa93fd08c8f`. A written invariant, false.

## 5. Numbers in the brief that did not survive contact

  * Brief: *"aarch64 5/104 header + 6 retired-pending"*. **Measured 8 PASS /
    104 FAIL** — and identically in the PRE-CHANGE build `/tmp/b111`, so the 3
    are someone else's landed work, not mine. PRINCIPLES §6 says 2/110, which
    is stale from a different direction. FAIL 104 is the number both the brief
    and I agree on.
  * TAB 64 arms: **i386 32 PASS / 0 FAIL, aarch64 27 PASS / 5 FAIL** — matches
    both documents. The five are `BYTES_/WORDS_/FLOAT_WORDS_/REG_WORDS_BIG_ENDIAN`
    and `SHIFT_COUNT_TRUNCATED`.
  * `Makefile.in:857` in the brief is `:871` on this base.

## 6. What I did NOT do

  * `config/linux.h` and `config/rs6000/sysv4.h` build their own
    `INCLUDE_DEFAULTS` from `#ifdef TOOL_INCLUDE_DIR`. With the `-D` gone those
    entries simply drop. That is the same treatment `cppdefault.cc` already
    gives `INCLUDE_DEFAULTS` deliberately, and getting `INCLUDE_DEFAULTS` out
    of the privileged target's `tm.h` remains its own job. **Not measured** —
    no build here takes that arm.
  * No probe: `--with-real-ld` and friends are pass-only. A probe would have to
    decide that some `ld` on `PATH` is "this target's real ld", which is the
    guess that caused this.
  * The `libsubdir_to_prefix` off-by-one and the `ix86_data_alignment` aarch64
    ICE are both flagged above and both unfixed.

## 7. FILES (scratchpad)

    t24-build.sh       my build dir /tmp/b24 (t111-build.sh repointed)
    t24-fp-build.sh    the FAKE PREFIX build; SRC= D= PREFIX=
    t24-ts.sh          target-specs/configure per target (`make target-specs`
                       does not exist any more; rv-specs.sh is stale)
    t24-inc.sh         cc1 -v system include list, both targets
    t24-poison.sh      does a header that exists ONLY in the host directory get
                       found?  -fsyntax-only, see the aarch64 ICE above
    t24-perTarget.sh   absent / verbatim / searched + cross-target control
    t17-tools.sh       which tool NAMES collect2 searches, both targets
    t17-real.sh        real_nm_file_name: good / bad / control, both targets

## 2026-08-12 -- main-tree session: merges, scoreboard re-measurement, `config.in`

Merged three agent branches: `eda508f4d88` (LTO forwarding, #78),
`aa0b6da0fbac13315` (silent macros / arm E discovery), `ad79a17e47a430c73`
(#17 collect2 tool paths, #24 `TOOL_INCLUDE_DIR`).

`gcc/configure` conflicted on the last merge.  `gcc/configure.ac` itself
merged **cleanly**, so the generated file was resolved by regenerating it
with **autoconf 2.69** (matching the version stamped in the checked-in
header), not by hand-picking hunks.  The new capability keys correctly do
**not** appear in `gcc/configure` -- they live in `target-specs/configure.ac`;
the three matches left in `gcc/configure.ac` are all `dnl` comments.

### Probe scoreboard re-measured, and two documents reconciled

An agent flagged that PRINCIPLES 6 said aarch64 **2 PASS / 110 FAIL** while
STATE.md said **5 / 104 + 6 retired-pending**, and correctly declined to pick
one.  Both were partly right about the *same* board, each having applied one
of two retirements and not the other (`5 - 3 = 2`, `104 + 6 = 110`).

The arithmetic closes from both directions, which is exactly why it was
settled by **running** `scratchpad/macro-probe-run.sh` instead: closing
arithmetic is how a wrong shared number survives, the same root pattern this
branch exists to fix.

    macros probed: 112   i386: PASS 112 FAIL 0   aarch64: PASS 8 FAIL 104

**Never quote the raw 8.**  It is 2 trusted (`MAX_BITS_PER_WORD`,
`MAX_BITSIZE_MODE_ANY_MODE`) + 6 retired-pending -- #108's stack/arg-boundary
set, green only because the probe's base-B context omits
`MULTI_TARGET_TARGETM_BASE`, so `defaults.h` redirects both sides and the arm
compares the redirect with itself.  Independently corroborated: the
tool-paths agent measured 8/104 too, **and got the same 8/104 in its
pre-change build** `/tmp/b111`, so the three are someone else's landed work
and not that agent's.  PRINCIPLES updated at `44027e85f2f`.

### `config.in` regenerated (#112), and the task's premise was half wrong

`autoheader` gives **-277/+0**: 45 dead `HAVE_AS_*` / `HAVE_GAS_*` / `LD64_*`
entries.  Landed alone at `45fc4417a1c` so the noise cannot ride along with a
behavioural change.

The task said the 45 were "defined by nothing and **read by nothing**".  The
second half is **false -- all 45 are still read.**  28 are already converted
to `target-caps` and are fine.  The other **17** are read by s390, avr, ia64,
cris, darwin and `gcc.cc`, which now silently take the capability-absent arm.
Filed as **#116**.  `LD64_VERSION` and `DSYMUTIL_VERSION` are the worst: they
are *value* macros used in `#if` comparisons, so absence reads as **0** --
"older than everything" rather than "unknown".

The regeneration is still inert, for a reason worth keeping: **a name
`configure` never defines and a name absent from `config.in` are identical to
the preprocessor.**

**Both-sided check on the regeneration** -- the risk was a regenerated
`configure` silently dropping a probe, so "configure ran, rc=0" would have
proved nothing.  Configured a fresh tree from the **top level**
(`/tmp/cfgchk`, two backends) and diffed `gcc/auto-host.h` against the
pre-regen build `/tmp/b111`:

    lines only in b111: 45   -- all 45 are `/* #undef X */` comments
    real #define lost:   0
    lines only in mine:  0

Exactly the 45, nothing else, in either direction.  The same output
corroborates #116 from the other side: those names were **already** undefined
in a working build, so the 17 unconverted readers take the absent arm today.

  * A first attempt at this check failed for an unrelated reason worth
    recording: running `gcc/configure` **directly** with short backend names
    (`--enable-backends=i386,aarch64`) dies with `*** Configuration  not
    supported` and an *empty* triple in the message.  `gcc/` must be
    configured through the top level, and backends want full triples.

### Spun out

  * **#113** collect2's `%(link_target_config)` is user-replaceable via
    `-specs=` and then fails **silently** -- needs a ruling, `gcc.cc`
    documents it as a deliberately independent knob.
  * **#114** arm E: macros expanding to a **dereference of back-end mutable
    state**.  Not the baked-in-constant suspicion; invisible to all four
    existing sweep arms.  This is the aarch64 IPA wall.
  * **#115** `libsubdir_to_prefix` off-by-one in its own right;
    `GPLUSPLUS_INCLUDE_DIR` likely one directory too high.  Unmeasured.
  * **#116** the 17 above.
  * **#51 corrected**: `gen_speculation_barrier` is **not** arm-only (i386 and
    aarch64 both define it), so the fork is **one** name, `gen_movxf`.

# TASK #113 -- THE $(eval) PROBE: THE TOP-LEVEL ROUTE EXISTS.  GATE CLEARED

Worktree started at the bare-repo HEAD `7208eca60d0` and needed the documented
`git reset --hard multi-target`; the PRINCIPLES 5 check caught it, as it did
for #111 and #112.  Note the branch tip had moved to `44027e85f2f`, past the
`cfd84583a55` quoted in my brief.

This task ran **TOPLEVEL-DESIGN.md section 8 item 1**, which that document
names as the **highest-priority thing that must happen before the design is
approved**, and section 7(3) names as its **top-ranked risk** -- "that the
split-loop route's make half survives contact with `$(eval)`".  It decides
whether the recommended route *exists*, not merely what it costs.

## THE VERDICT: IT WORKS.  4/4 ARMS, BOTH-SIDED, WITH NEGATIVE CONTROLS

`scratchpad/t113-eval-probe.sh`, N=2 (aarch64-unknown-linux-gnu,
x86_64-pc-linux-gnu), module `libgcc`, non-bootstrap `configure` and `all`
rules, recipe text lifted VERBATIM from the shipped generated `Makefile.in`
(lines 50383-50424 and 50836-50851).

    arm 1  AFFIRMATIVE   $(eval) output == literal output, per target, for the
                         stored rule text AND the fully expanded text.
                         6/6 IDENTICAL.  md5s recorded per arm.
    arm 2  BOTH-SIDED    the two targets are NOT identical: each names its own
                         subdir and its own --host, and neither mentions the
                         other.  (If they were identical, arm 1 would STILL
                         pass while one target served both -- a primary by
                         another name.)
    arm 3  NEGATIVE      an EMPTY target list FAILS BY NAME (rc=2,
                         "MT_TARGETS is empty: no target was configured"),
                         not silently with zero rules.  This is the false
                         green the brief demanded a control for: a loop that
                         runs zero times must not score as a build.
    arm 4  NEGATIVE      an injected under-quoting error (one level of `$`
                         doubling dropped) makes arm 1 go RED.  Without this,
                         arm 1's pass would prove nothing about quoting.

The control (`probe-lit.mk`) is the design doc's option (B) -- the shipped
text written out once per target -- so it is **independent of the `define`
block** and cannot be wrong in the way the subject might be.

## THREE FINDINGS THE DESIGN DOC DOES NOT HAVE, ONE OF THEM A CORRECTION

**(1) CORRECTION: the `$(eval)` failure mode is silently WRONG, not silently
EMPTY.**  TOPLEVEL-DESIGN.md section 2.2 says twice that getting the `$`
doubling wrong yields "a silently empty recipe", and builds its mitigation
around asserting rules are non-empty.  **Measured, it does not.**  Dropping
one level of quoting on `$$(srcdir)` produced a rule that is complete,
non-empty, and *plausible* -- with `MARK_SRCDIR` (the value at
`call`-expansion time) baked in where `$(srcdir)` should have been deferred:

    correct    ... s=`cd $(srcdir); ...` ... $(SHELL) $(srcdir)/mkinstalldirs
    under-quoted ... s=`cd MARK_SRCDIR; ...` ... $(SHELL) MARK_SRCDIR/mkinstalldirs

A non-emptiness assertion scores that PASS.  **The mitigation the design doc
specifies would not have caught the error it was written to catch.**  The
check must compare rule TEXT against a control, not measure its length.  This
is PRINCIPLES 2a's "a count is the weakest evidence available" in a new
location, and it is the single most useful thing this probe found.

**(2) `$(call)`/`$(eval)` COLLAPSES backslash-newline continuations.**  The
literal form keeps one physical line per continuation; the `$(eval)` form
emits one long logical line.  The two are the same command -- make hands the
recipe to `/bin/sh` with continuations intact and sh joins them -- but any
acceptance test that diffs raw recipe text will go RED on a CORRECT change.
`scratchpad/t113-norm.sh` normalises both sides to the shell-visible text;
arm 4 is what proves the normalisation has not flattened the comparison into
insensitivity.  **Anyone planning to accept Stage 3 by diffing `Makefile.in`
before and after needs to know this first.**

**(3) `make -n` EXECUTES recipe lines containing `$(MAKE)`.**  This is
documented GNU make behaviour (so sub-makes recurse under `--dry-run`) and it
bit the first version of this probe: `make -n all-target-libgcc-<t>` RAN the
recipe (`MARK_PWD: command not found`).  Consequence for the design doc's
section 6.3 **permutation harness**: a permutation arm built on `--dry-run`
over target-module rules will *actually run sub-makes*, and on a tree with N
targets that is not a dry run at all.  The permutation harness must use
`make -p` (rule database) or a real build, never `-n`.  Recorded before
anyone builds that harness on the wrong instrument.

## WHAT THIS DOES AND DOES NOT LICENSE

Proven: the make half of the accepted split-loop route (autogen owns modules
M, make owns targets N) reproduces the shipped recipes exactly, for N=2, with
per-target `--host` and per-target subdirs, and fails loudly when the list is
empty.  The quoting is tractable.

**Blind spots, stated per PRINCIPLES 4 rule 5:**

  * **Expansion only.**  `-p`/`-n` do not execute, so a recipe that expands
    correctly and then fails at run time scores PASS here.  This is not a
    build of two libgccs.
  * **Non-bootstrap only.**  The bootstrap stage machinery
    (`Makefile.tpl:1779-1793`, the `mv stageN-$(TARGET_SUBDIR)` shuffle) is
    the design doc's own stated worst case for this route and is NOT probed.
    A pass here is not a verdict on it.
  * **One module, not 26.**  The claim tested is "the quoting is tractable",
    which the design doc argues generalises; that generalisation is not
    itself measured.

## VERIFIED RATHER THAN TRUSTED, AS THE BRIEF ASKED

  * **#74 is DONE.**  `Makefile.tpl:27-34` -- the GNU make 3.80 check is
    unconditional, no longer wrapped in `@if gcc`, and carries a comment
    explaining why.  Regenerated into `Makefile.in:24-31`.  `$(eval)` is safe.
  * **`delete-with-multisrctop` is ALREADY MERGED**, as #72 reported -- but
    NOT as `bb013cbe0f6`, which is **not an ancestor of HEAD**.  It was
    re-landed as **`abd0a87eb25`**, which is.  Every live `MULTISRCTOP` use is
    gone; the 8 remaining hits are ChangeLogs and TOPLEVEL-DESIGN.md itself.
    **Do not re-cherry-pick it.**  (TOPLEVEL-DESIGN.md section 2.2 says
    `bb013cbe0f6` "is confirmed present in the branch's history" -- true only
    if that means the object exists, which it does on another branch.  By
    ancestry it is not there and its content is.)
  * A first grep for `MULTISRCTOP` with an `--include` filter scored **0**,
    wrongly -- PRINCIPLES 7's "your grep's `--include` list can exclude the
    answer", committed again.  The unfiltered grep found 8.

## WHY #65/#67 ARE NOT LANDED HERE

The brief directed the `$(eval)` probe first and a report before building on
it, and that is where this stops.  Beyond that instruction, two things should
be settled by the user rather than guessed:

  * **#62 is a hard blocker on Stage 3 and it is not mine to overrule.**
    TOPLEVEL-DESIGN.md section 6.2 states that a fresh build directory does
    not bootstrap on this branch, that every build dir in use is a survivor of
    an earlier state, and therefore that **"Stage 3 cannot be accepted until
    #62 is fixed and a cold build from an empty directory succeeds"** -- a
    restructure of configure and the directory layout cannot be verified
    against a tree that only builds from surviving artefacts.  The brief's bar
    ("configure and build with two targets, producing two distinct per-target
    trees") is exactly the thing that document says is unverifiable in
    principle until #62 lands.
  * **The gnattools/gotools question** (design doc section 2.2a(a)): three of
    the 44 target-module dependency lines are HOST tools depending on *a*
    target library without saying which.  Under "no single target ever" there
    is no default available, and inventing one would be a per-target default
    that amounts to a primary by another name -- the exact mistake the brief
    names and the user has already caught once.  Options are "all of them" or
    "gnattools/gotools become per-target too"; this is a design decision with
    materially different work behind each, so per PRINCIPLES 2b it is reported
    rather than resolved.

## FILES (scratchpad)

    t113-eval-probe.sh  the probe: 4 arms, 2 affirmative + 2 negative, with a
                        non-vacuity gate that REFUSES TO SCORE when a recipe
                        is too short -- which is what caught the collapsed
                        continuations instead of silently diffing them
    t113-norm.sh        normalises a recipe to the text the shell receives,
                        with the argument for why that is legitimate

# TASK #116 -- THE 45 DELETED PROBE NAMES.  THE BRIEF'S LIST OF 17 IS WRONG; THE REAL DEFECT IS ONE MISSING STRUCT FIELD

Worktree came up on `prog-target-12` at the bare-repo HEAD `7208eca60d0` --
**39,189 commits behind `multi-target`**, and 30 commits AHEAD on an unrelated
GCC-12-era branch, so a `git rebase` would have replayed someone else's
release-branch commits onto the tip.  `git reset --hard multi-target` was the
right move, not a rebase.  This is another session paying the PRINCIPLES 5
trap; the ahead-count is a new wrinkle worth recording, because "30 ahead"
reads like local work and is not.

## 1. THE PREMISE.  I WAS ASKED TO VERIFY IT AND IT DOES NOT SURVIVE

The brief said 17 of the 45 deleted probe names are "not converted and still
read by real code, which now silently takes the capability-absent arm".
Derived rather than assumed (`scratchpad/t116-survey.sh`), the count is **not
17**.  Twelve of the seventeen are already handled, by three different
mechanisms, and the brief's own worst-case claim is the one that fails hardest.

| macro | brief says | actually |
|---|---|---|
| `HAVE_AS_ARCHITECTURE_MODIFIERS` | unconverted | **converted** -- `defaults.h:1685` -> `targ_caps.as_s390_architecture_modifiers` |
| `HAVE_AS_VECTOR_LOADSTORE_ALIGNMENT_HINTS` | unconverted | **converted** -- `defaults.h:1687` |
| `..._ON_Z13` | unconverted | **converted** -- `defaults.h:1690` |
| `HAVE_AS_LTOFFX_LDXMOV_RELOCS` | unconverted, blocked on #36 | reader **converted** at `defaults.h:1654`; the real defect is elsewhere, see §2 |
| `LD64_HAS_DEMANGLE` | absent arm runs | **converted** -- `darwin.h:305`, derived from `DEF_LD64_MAJOR` |
| `LD64_HAS_EXPORT_DYNAMIC` | absent arm runs | **converted** -- `darwin.h:306` |
| `LD64_HAS_NO_DEDUPLICATE` | absent arm runs | **converted** -- `darwin.h:307` |
| `LD64_HAS_PLATFORM_VERSION` | absent arm runs | **converted** -- `darwin.h:308` |
| `LD64_HAS_MACOS_VERSION_MIN` | absent arm runs | **converted** -- `darwin.h:309` |
| `HAVE_GOLD_NON_DEFAULT_SPLIT_STACK` | read by `gcc.cc` | **converted** to a real spec; the only two mentions left in `gcc.cc` are PROSE in comments |
| `LD64_VERSION` | value macro, reads as **0** | **false.**  `darwin.h:1338` has `#ifndef` -> `DEF_LD64` or `"85.2.1"`.  It is a **string**, used as `Init()` of an option Var -- never in an `#if` comparison |
| `DSYMUTIL_VERSION` | value macro, reads as **0** | **false.**  `darwin.cc:119` has `#ifndef` -> `DET_UNKNOWN,0,0,0` **plus a `#warning`**.  It is a 4-element **initialiser list**, not a scalar in an `#if` |

**The "worse shape" pair is the part of the brief that was most confidently
stated and least correct.**  Neither is a scalar in an `#if`; neither reads as
0; both have an explicit fallback and one of them warns.  The brief asked me to
handle them "first and separately" and to derive the classification rather than
trust it.  Deriving it is what dissolved the item.

The genuinely-open remainder is **five**, and every one already carries a
written reason and a commented-out emission line in
`target-specs/configure.ac`, plus a matching note in `check-target-caps.sh`'s
backlog: `as_avr_mlink_relax`, `as_avr_mrmw`, `as_avr_mgccisr` (consumer is
`gen-avr-mmcu-specs.cc`, a BUILD-MACHINE program that cannot read `targ_caps`),
`as_no_mul_bug_abort` (consumer is SPEC TEXT in `cris.h`), and
`as_s390_machine_machinemode` (`S390_USE_TARGET_ATTRIBUTE` selects
`SWITCHABLE_TARGET` with `#if`, which changes data layout and cannot be a
run-time answer).  **These are documented deferrals, not oversights**, and I
left them alone.  Nothing in this task changes their status.

## 2. WHAT WAS ACTUALLY WRONG, AND IT WAS NOT ON THE LIST

`gcc/defaults.h:1655` reads:

    #define HAVE_AS_LTOFFX_LDXMOV_RELOCS (targ_caps.as_ltoffx_ldxmov_relocs)

**`struct target_caps` had no field of that name.**  Not defaulted wrongly --
absent.  So `--enable-backends` naming ia64 would have failed to COMPILE, with
a diagnostic pointing at `defaults.h` rather than at anything ia64.

Why nothing noticed, and it is a new shape worth naming:

  * the macro is only ever expanded by `ia64.h` and by the output templates of
    `*load_symptr_high` / `*load_symptr_low` in `ia64.md`, so it is expanded
    **only in a build that enables ia64** -- and no such build exists here.
    A macro body naming a nonexistent struct member is not an error until
    something expands it.
  * **`check-target-caps.sh` could not see it from either arm.**  Its
    read-direction arm's corpus is the config files a build produces, and a key
    nothing emits appears in none of them.  Its declared-vs-emitted arm finds a
    *field with no writer*.  Neither finds a **writer-to-be with no field**,
    which is what this was.

**MEASURED, BOTH-SIDED** (`scratchpad/t116-field.sh`).  The subject is
`as_ltoffx_ldxmov_relocs`; the control is `as_s390_architecture_modifiers`, a
field from the *same block of `defaults.h`* that does exist.  Without the
control, a failure here is indistinguishable from "the harness cannot compile
`target-caps.h` at all", and the script exits non-zero rather than scoring if
the control fails.

    BEFORE:  control COMPILES   subject FAILS
             error: 'struct target_caps' has no member named 'as_ltoffx_ldxmov_relocs'
    AFTER:   control COMPILES   subject COMPILES

### It is a CAPABILITY, derived on the user's test

Could "does this `as` accept `@ltoffx` and `ld8.mov`" differ between two
installations of the same compiler serving ia64?  **Yes** -- it is a property of
the binutils in front of you.  So: capability, `target-specs`, not a hook.
The probe already existed (`gcc_cv_as_ia64_ltoffx_ldxmov_relocs`); only the
carrier was missing.

**And it is not a generator problem, which the brief expected it to be.**  The
two `.md` sites are **output templates**, not insn conditions.  Templates are
copied into `insn-output.cc`, which is ordinary `!GENERATOR_FILE` C++ inside
`cc1` and does reach `defaults.h`.  An insn *condition* would have been the #36
gencondmd problem; a template is not.  **#36 does not block this and was not
touched.**

### Landed as four parts together, as the backlog comment insisted

  * `gcc/target-caps.h` -- the field, defaulted `false`, which is exactly what
    ia64.h's floor supplied for every build not configured for ia64.
  * `gcc/target-caps.cc` -- designated initialiser and `strcmp` arm.
  * `target-specs/configure.ac` -- the emission line, uncommented.
  * `gcc/check-target-caps.sh` -- the backlog entry retired.  It could not be
    left: the table is self-expiring and a stale entry is fatal by design.

`target-specs/configure` regenerated with **autoconf 2.69** (matching its own
header stamp), `rc=0`, empty stderr, and the diff against the checked-in file
is **25 lines, all inside the intended hunk**.  The emission sits in the
UNQUOTED heredoc whose backtick trap once silently dropped all 97 keys, so that
was checked rather than assumed: the added prose contains no backticks, and
`as_mfcrf`, `as_pltseq` and `solaris_ld` -- all emitted AFTER the insertion --
still appear in the generated `configure`, which they would not if the heredoc
had been swallowed.

## 3. THE CHECK CAN GO RED.  METHOD RULE 7, AND MY FIRST ATTEMPT WAS A FALSE RED

`scratchpad/t116-caps-check.sh` runs `check-target-caps.sh` over a synthesised
config file carrying **all 128 keys the emitter can write**, with a non-vacuity
assertion that the subject key is present -- then injects two faults:

    arm 1  real tree                        PASS   (want PASS)
    arm 2  the new field deleted again      FAIL   (want FAIL)  -- and names it
    arm 3  a bogus key in the config file   FAIL   (want FAIL)

**Arm 2 was wrong the first time and it failed in the flattering direction.**
It built the injected tree as a copy of `gcc/` alone, but the checker resolves
its emitter as `$srcdir/../target-specs/configure.ac`, so the copy had no
sibling and the checker died with "no emitter -- refusing to report".  That is
`FAIL`, so the arm **scored as a passing fault injection while testing
nothing**.  Fixed by giving the injected tree a sibling `target-specs/`, and
the arm now additionally asserts the diagnostic **names the key**:

    check-target-caps: capabilit(ies) that no target config file can ever carry
      as_ltoffx_ldxmov_relocs

A fault arm that fails for the wrong reason is a false red and is worth no more
than a false green.  Recording it because the fix -- assert on the *content* of
the diagnostic, not merely on the exit status -- is the same lesson as
PRINCIPLES 4.7's "diff the artefact, never assert on its size".

## 4. #46 -- MEASURED, DELIBERATELY NOT TOUCHED, AND THE COUNT IS RIGHT FOR THE WRONG REASON

`scratchpad/t116-vacuous.sh` sweeps for `#ifdef` / `#ifndef` / `defined()`
guards on the macros `defaults.h` now defines unconditionally over `targ_caps`.
It finds **13 macros over 22 sites**, which corroborates #46's "~23" from an
independent direction.

**But they are NOT uniformly vacuous, and #46 must not be worked as one sweep.**
`gcc/mkconfig.sh:76` is explicit: the guards in target headers "run while this
header is being processed, **long before defaults.h**".  So an `#ifdef` in
`rs6000/linux64.h` is the OLD floor mechanism still working, not a guard that
cannot select.  The exception is `HAVE_LD_PIE`: `mkconfig.sh:93` pre-defines it
to 1 *ahead of* the target headers, so `#ifdef HAVE_LD_PIE` in `alpha/linux.h`,
`gnu.h`, `i386/gnu64.h` and `ia64/linux.h` **is** always-true today.

So #46 is genuinely per-site adjudication, and its answer depends on include
ORDER rather than on the macro.  I did not adjudicate the 22; none of them is
among my 17, so nothing here closed any of them.  Left alone rather than
half-done, as the brief directed.  The sweep is the useful artefact.

The 13, for whoever picks up #46: `HAVE_AS_DSPR1_MULT`,
`HAVE_AS_MMACOSX_VERSION_MIN_OPTION`, `HAVE_LD_AVR_AVRXMEGA2_FLMAP`,
`HAVE_LD_AVR_AVRXMEGA3_RODATA_IN_FLASH`, `HAVE_LD_AVR_AVRXMEGA4_FLMAP`,
`HAVE_LD_CTF`, `HAVE_LD_EH_GC_SECTIONS`, `HAVE_LD_LARGE_TOC`,
`HAVE_LD_NO_DOT_SYMS`, `HAVE_LD_PIE`, `HAVE_LD_PPC_GNU_ATTR_LONG_DOUBLE`,
`HAVE_XCOFF_DWARF_EXTRAS`, `POWERPC64_TOC_POINTER_ALIGNMENT`.

## 5. WHAT I DID NOT MEASURE, AND WHAT MY INSTRUMENTS CANNOT SEE

  * **The conversion is UNVERIFIED AT RUN TIME and I am labelling it so.**
    ia64 does not build in this tree, so nothing here executed
    `*load_symptr_high` and observed it choose `@ltoffx` over `@ltoff`.  What is
    verified is that the carrier now exists end to end: field, default, strcmp
    arm, emission, and a checker that goes red by name when the field is removed.
    The arm that is missing is exactly one: **an ia64 build emitting the two
    spellings under a config file setting the key 1 and 0.**
  * `t116-vacuous.sh` takes its macro list from the `!USED_FOR_TARGET` arm of
    `defaults.h` only; a macro defined over `targ_caps` elsewhere is invisible
    to it, and it does not search `.md` or generated files.
  * `t116-survey.sh` deliberately does not use `grep --include` -- that filter
    silently excludes `*.awk`, and an agent committed that trap this week after
    citing it.  It excludes only the generated `gcc/configure` by path, and
    asserts it can see `targ_caps` before scoring anything.
  * I did not re-run the probe scoreboard.  Nothing here touches a probed macro,
    so the 112 / 8-104 board should be unmoved, but that is an argument and not
    a measurement.

## 6. FILES (scratchpad)

    t116-survey.sh      readers and definers of the 45/17, no --include filter
    t116-field.sh       both-sided: the missing struct field, with a control
    t116-caps-check.sh  check-target-caps over all 128 keys + 2 injected faults
    t116-vacuous.sh     the #46 sweep: 13 macros, 22 sites, blind spots stated
    t116-build.sh       /tmp/b116, this task's own build dir

## 7. REGRESSION BARS, MEASURED ON /tmp/b116 (MY OWN BUILD DIR) AFTER THE CHANGE

    make cc1                rc=0    cc1 = 88,694,984 bytes
    make multi-target-objs  rc=0
    gcc/target-caps.o       rebuilt (19,640 bytes), so the change is IN the build
                            and not sitting behind a stale .Po

**STDERR -- SAY WHICH ARM.**  Cold arm (configure + `make cc1` from empty):
**627 lines, 98 of them `warning:`** -- nixpkgs gcc 15.2 compiling GCC, the
documented host-compiler noise.  Incremental arm (`make multi-target-objs`
immediately after): **0 lines**, which is below the documented 32-line floor and
consistent with PRINCIPLES 6's note that the floor "varies with what was last
rebuilt" -- the `.md` rules had already re-run in the cold pass.

**THE ONE `error:` IN THE COLD LOG IS NOT MINE AND I CHECKED RATHER THAN
ASSUMED.**  `collect2: error: ld returned 1 exit status` at line 18, inside the
CONFIGURE phase, preceded by `cannot find -lgcc` from nix's unwrapped `ld.bfd`
and followed immediately by configure's own `WARNING: I suspect your system does
not have 32-bit development libraries`.  It is the 32-bit multilib probe failing
as `t112-build.sh`'s header already documents, it happens before a single GCC
source file is compiled, and `make cc1` still returned 0.  Recording it because
"one error line in the log" is exactly the thing that gets waved through.

### The key reaches the ARTEFACT, not just the source

Checked at the object level, three-sided, because a name-matching instrument
scoring 0 is a claim about the instrument:

    as_ltoffx_ldxmov_relocs        in target-caps.o   1   (subject)
    as_ltoffx_ldxmov_relocs        in cc1             1   (subject)
    as_s390_architecture_modifiers in cc1             1   (positive control)
    as_zzz_definitely_not_a_key    in cc1             0   (negative control)

**The first attempt at this used `strings`, which is NOT ON PATH here**, so
every arm scored 0 -- including the positive control, which is the only reason
it was caught rather than being read as "the key never reached the binary".
That is PRINCIPLES 5's "tool-not-found piped into `grep -c` scores 0, in the
direction that makes the reference look correct", paid again. Redone with
`grep -a`.

# TASK #113 -- ARM E RE-FILTERED, AND THE FIRST COMPLETE aarch64 `.s`

Branched from `4af8355f59f` (merged in during the task).  Build dir `/tmp/b113`
(x86_64 + aarch64, mine).  My worktree started at the bare-repo HEAD
`7208eca60d0`; the PRINCIPLES 5 check caught it, as it did for #111 and #112.

## 1. THE ARM E POPULATION: 40 -> 20, AND WHAT EACH FILTER DROPPED

#112 published 40 as an explicit upper bound with known contamination and asked
for a re-filter.  `scratchpad/t113-armE2.sh` is that, with three filters, each
reporting its drops so they are auditable:

    raw (t112/t113-armE.sh, text sweep of config/i386/*.h)      40
      FILTER M  machinery-only spellings                        -3   -> 37
      + the two-step chain members the sweep cannot see         +2   -> 39
      FILTER P  is that the definition IN FORCE? (preprocessor) -13  -> 26
      FILTER L  is the i386 symbol still needed? (nm on 663
                shared objects), with the opt-var exception     -6   -> 20

  * **FILTER M** drops a macro whose only shared spellings are the conversion
    machinery naming it: `LOCAL_ALIGNMENT` (defaults.h), `TARGET_64BIT_MS_ABI`
    (target-cdata.h), `TARGET_READ_MODIFY_WRITE` (genconditions.cc).  That is
    the contamination #112 named.  It is only THREE of the forty.
  * **FILTER P** is the one that settles membership, and it rediscovers the
    already-converted set independently: `FUNCTION_ARG_REGNO_P`,
    `MINIMUM_ALIGNMENT`, `STACK_SLOT_ALIGNMENT`, `PREFERRED_STACK_BOUNDARY`,
    `OUTGOING_REG_PARM_STACK_SPACE` all come back as `(mt_... ())`.  Nothing
    told it those were done; it read the preprocessor.
  * **FILTER L** asks the LINKER, and it was added because P is still text.
    `DATA_ALIGNMENT` and `DATA_ABI_ALIGNMENT` survive M and P after this task
    converts them, because they were converted by deleting their `#ifdef` call
    sites and the replacement code carries comments that still SPELL THE
    MACRO.  My own comments contaminated my own instrument.

**FILTER L GETS ONE CLASS WRONG, IN THE FLATTERING DIRECTION.**
`ASSEMBLER_DIALECT` is `(ix86_asm_dialect)` and `i386.opt:269` declares that
`Var(ix86_asm_dialect)`, i.e. a `#define` onto
`global_options.x_ix86_asm_dialect`.  Shared code reading it emits **no `ix86_`
symbol at all**, so `nm` scores it clean while the leak is entirely real.  Four
macros were dropped that way before the exception existed (`ASSEMBLER_DIALECT`,
`BRANCH_COST`, `CASE_VECTOR_MODE`, `OPTIMIZE_MODE_SWITCHING`).  The header's
first draft claimed filter L "can only shrink a genuine over-count"; that claim
was wrong and is kept in the file rather than quietly corrected.

### THE RANKING, AND THE COLUMN THAT CANNOT BE RANKED

The brief asked for LOUD vs QUIET.  The honest answer has **three** columns:

    LOUD   macro body derefs a null back-end pointer                 0
    QUIET  macro body reads a benign scalar -- silently i386's       5
    UNRANK macro CALLS an i386 function -- not rankable from here   15

**`DATA_ALIGNMENT` is why the third column exists**, and it arrived from the
tool-paths agent mid-task.  Its body is `ix86_data_alignment ((TYPE), (ALIGN),
true)` -- it dereferences nothing, so a body-reading classifier calls it QUIET.
It is LOUD.  Confirmed under gdb (`scratchpad/t113-align-diag.sh`), not from the
name:

    #0 ix86_data_alignment <- align_variable <- varpool_node::analyze
    => mov 0x190(%rax),%eax   with %rax == 0,  si_addr == 0x190
    ix86_tune_cost holds 0x0000000000000000

`ix86_data_alignment` reads `ix86_tune_cost->prefetch_block` (i386.cc:18641) and
0x190 is that member's offset.  So it is the SAME mechanism as `MOVE_RATIO` --
an uninitialised back-end pointer -- reached one call deeper.  **Ranking a FUNC
row would need an interprocedural pass or a run; this instrument has neither.
An UNRANK row is UNMEASURED, not absent.**  LOUD=0 today means only that every
leak that announces itself has been converted.

The two SHAPES the filter matches, stated because the coordinator was right to
ask: `KIND=STATE` (6) is the macro body naming back-end state itself;
`KIND=FUNC` (14) is the macro dispatching to a back-end function.  Both are
counted, and the ranking is what distinguishes them, not the membership test.

**BLIND SPOTS.**  Discovery is still the text sweep over `config/i386/*.h`, so a
macro reaching state through a helper is invisible (LOWER bound).  `cp/rtti.o`
does not exist in a `c,lto` build, so filter L cannot see the C++ front end at
all.  `Pmode` survives as an opt-var row and is the known separate mode-union
problem, not new work.

## 2. WHAT LANDED: TEN MACROS, TWO SHAPES, ONE GROUP

### THE MOVE/CLEAR FAMILY IS SEVEN, NOT THE FIVE THE HANDOVER NAMED

#112 decomposed it as `MOVE_RATIO`, `CLEAR_RATIO`, `MOVE_MAX`,
`MOVE_MAX_PIECES`, `STORE_MAX_PIECES`.  The transitive closure through
`defaults.h`, measured by chasing each `-dM` definition to a fixpoint, is two
larger:

    MOVE_MAX_PIECES     <- MOVE_MAX          (defaults.h:1098)
    STORE_MAX_PIECES    <- MOVE_MAX_PIECES   (defaults.h:1107)
    COMPARE_MAX_PIECES  <- MOVE_MAX_PIECES   (defaults.h:1112)   <- ADDED
    SET_RATIO           <- MOVE_RATIO        (defaults.h:1472)   <- ADDED

`SET_RATIO` matters and is not bookkeeping: aarch64 defines its own, i386
defines none, so shared code's `SET_RATIO` is i386's `MOVE_RATIO`.  Redirecting
`MOVE_RATIO` alone would have made `SET_RATIO` silently become **aarch64's move
ratio where aarch64 asks for its set ratio** -- the same half-fix #112 refused,
reproduced one level down.  All seven landed together.

**`MAX_MOVE_MAX` IS THE ONE NOT CONVERTED, AND THAT IS A CONSTRAINT.**
`reload.h:179` and `caller-save.cc:55` use it as an **array bound**, which
cannot hold a call.  It is also not a per-target question -- the array is sized
once for a binary serving every back end -- so it is a union quantity and
belongs with the mode/register unions.  Two consequences are written into the
code rather than hoped for:

  * a `static_assert (MAX_MOVE_MAX > 0)` in `target-cumargs-select.cc`.  i386
    defines `MAX_MOVE_MAX` as 64 so `defaults.h:1116`'s
    `#define MAX_MOVE_MAX MOVE_MAX` floor does not fire -- but that is a fact
    about which back end happens to be primary.  If it ever changes,
    `mt_move_max` would recurse into itself forever; the assert turns that into
    a build failure by name.
  * `mt_move_max` checks the selected base's `MOVE_MAX` against the primary's
    `MAX_MOVE_MAX`.  `caller-save.cc` **sizes** `regno_save_mem` from the
    latter and **indexes** it with `MOVE_MAX_WORDS` derived from the former:
    PRINCIPLES 3's "bound by one, indexed by another".  i386's 64 is comfortably
    the larger today; recorded because it was checked.

### NO THREE-STATE FLAG ON THE SEVEN, AND THAT IS MEASURED

The brief asked for the `INIT_EXPANDERS` three-state flag on this group.
`scratchpad/t113-family.sh` says it does not apply: all 48 cpu back ends define
`MOVE_MAX` directly, and every other member has a `defaults.h` floor -- a floor
evaluated **in the per-base translation unit**, so a base with no
`STORE_MAX_PIECES` gets the generic definition computed from ITS OWN `MOVE_MAX`,
not the primary's.  There is no absence to record, and a flag would be inventing
a state that cannot occur.  **Reporting against the brief here rather than
building what it asked for.**

### WHERE THE FLAG IS REAL: `DATA_ALIGNMENT` / `DATA_ABI_ALIGNMENT`

This pair is an existence predicate AND a state leak at once -- five `#ifdef`
sites (varasm.cc x4, cp/rtti.cc x1) answered by i386 for all 48 back ends.  31
back ends define `DATA_ALIGNMENT`, only 5 define `DATA_ABI_ALIGNMENT`,
`defaults.h` floors neither.  So `false` is legitimate and the pair carries the
`(has_X, payload)` shape with the two-sided cross-check.

**FOUR OF THE FIVE SITES LOST THEIR `#ifdef` AND ONE DID NOT, AND THE ONE THAT
DID NOT IS WHY THE FLAG IS LOAD-BEARING.**  Where the guarded code is
`align = data_align`, a thunk returning ALIGN unchanged makes the call
identity-equivalent and the guard can go.  `cp/rtti.cc:1760` also sets
`DECL_USER_ALIGN` inside the guard, so it is not identity-equivalent and keeps
an explicit `if (mt_has_data_abi_alignment ())`.  Returning ALIGN is **not** the
`#ifndef` floor PRINCIPLES forbids: it is i386.h's own documented semantics
("If this macro is not defined, then ALIGN is used"), and it is computed in the
base's own TU, so it is that base's answer and not the primary's.

**A GUARD I WROTE FAILED, AND THE CODE WAS RIGHT.**  Arm 1 was written expecting
aarch64 to define no `DATA_ALIGNMENT`.  `aarch64.h:133` defines it as
`aarch64_data_alignment (EXP, ALIGN)`.  So the old `#ifdef` was not merely
importing i386's presence into a back end that wanted none -- **it was calling
i386's function instead of aarch64's own**, a wrong VALUE and not only a
wrongly-taken branch.  The guard was corrected; the check was not relaxed.

## 3. AARCH64 MOVES.  THE FIRST COMPLETE aarch64 `.s` ON THIS BRANCH

    BEFORE  int x = 1;   x86_64 rc=0     aarch64 rc=4 ICE, 36 bytes / 2 lines
    AFTER   int x = 1;   x86_64 rc=0     aarch64 rc=0 SUCCESS, 377 bytes / 17 lines

and it is genuinely aarch64 -- `.arch armv8-a`, `.word`, the `aeabi_subsection`
block -- against x86_64's `.long` and `.globl` from the same binary in the same
run.  #112 recorded "aarch64 does NOT emit a complete `.s`"; that is now false
for this input, and I am claiming exactly this input and no more.

`scratchpad/big.c` still ICEs, but **further on**: at line 24 rather than at the
first declaration.  Under gdb (`scratchpad/t113-wall.sh`) the next wall is

    #0  0x0000000000000000 in ?? ()      <- PC is null, not a data fault
    #1  emit_move_insn_1
    #2  emit_move_insn
    #3  init_set_costs
    #4  initialize_rtl <- init_function_start <- cgraph_node::expand

**#112 PREDICTED THE NEXT WALL WOULD BE ANOTHER ARM E MEMBER.  IT IS NOT**, and
a prediction that is not checked is not a finding.  A null PC out of
`emit_move_insn_1` is a null `GEN_FCN (icode)` -- the insn-code numbering and
`insn-flags.h` family, i.e. #51's Class B/C and the mode union, not a macro
reading back-end state.  The IPA wall #112 diagnosed is no longer reached on
this input because compilation stops earlier.

## 4. REGRESSION BARS, ALL ON /tmp/b113, MY OWN BUILD DIR

  * `make multi-target-objs cc1 lto1` **rc=0**; lto1 links.
  * x86_64 `-O2` md5 **`378fc33c1e70`** -- the recorded baseline, unmoved.
  * `stock-compare.sh`, `IN` **absolute**, `MT=/tmp/b113`, `ST=/tmp/b-stock`:
    **5/5 IDENTICAL**, 5 distinct md5 per side, **negative control firing**
    (1158 vs 804 lines), rc=0.
  * `scratchpad/t113-guards.sh`: **7/7**, five affirmative and two injections.
    Arm 4 is the one that matters: it removes the `MOVE_RATIO` redirect from
    defaults.h, rebuilds `tree-inline.o`, and **requires `ix86_cost` to come
    back**.  It does.  Without that, arm 3's "no ix86_ symbols" green would be
    a claim about the grep, not about the code.  The arm restores the object
    and verifies the restore.

### SCOREBOARD: NOT RUN, NOT BANKED

I did not run the header/TAB probe harness and none of the ten macros is on the
probe list.  Carrying the coordinator's correction unchanged: header
**aarch64 8 PASS / 104 FAIL, of which only 2 passes are trusted** -- the other
6 are #108's stack/arg-boundary macros, green only because the probe's base-B
context omits `MULTI_TARGET_TARGETM_BASE` so the arm compares a redirect with
itself.  TAB **27/5**.  Nothing here should be read as moving any of them.

### STDERR -- WHICH ARM

  * **cold** `multi-target-objs cc1 lto1`: **637 lines / 101 `warning:`**.
  * **incremental after this task's edits** (6 files, one of them defaults.h,
    so most of the middle end rebuilds): **387 / 61**, and **24 / 0** on a
    later pass that rebuilt less.  Not comparable with the 32-line floor.
  * My first version of `mt_check_align_pair` took the function pointer as
    `const void *` and added **2 new `-Wconditionally-supported` warnings**;
    fixed by passing the `!= NULL` result as a `bool`.  Counted, not excused.

## 5. TRAPS PAID FOR THIS TASK

  1. **The worktree was at the bare-repo HEAD `7208eca60d0`**, again.
  2. **My own comments contaminated my own text sweep.**  Writing
     "Was `#ifdef DATA_ABI_ALIGNMENT'" into varasm.cc kept the macro in the
     arm E population after it had been converted.  That is what forced
     filter L into existence, so it was productive -- but the general lesson
     is that a name-matching instrument counts the FIX as an instance of the
     bug.
  3. **A non-vacuity assertion can be correct and useless at the same time.**
     `t113-armE2.sh` originally required `MOVE_RATIO` to be in the leak list,
     because it was gdb-confirmed.  Converting `MOVE_RATIO` made the script
     abort.  Weakening it to "may be absent" would have been the test-harness
     floor; it now checks the **disposition** -- each of `MOVE_RATIO` and
     `MOVE_MAX` must be accounted for as EITHER a leak OR converted, and
     anything else still refuses to score.
  4. **`nm` cannot see an option variable.**  `Var(ix86_branch_cost)` is
     `global_options.x_ix86_branch_cost`, not a symbol.  A linker-based sweep
     scores those clean while the leak is real, and it does so in the
     direction that flatters.
  5. `x/20gx targetm_frame` fails with "has unknown type" at `-g0`; the cast
     must be inside the expression (`x/20gx ((void**)targetm_frame)`).  gdb
     prints a null pointer as `(nil)`, not `0x0`, and a pattern matching only
     `0x0` turned a correct null into a guard failure.
  6. An edit that inserts a comment block above a `for` can leave the `for`
     line duplicated; `sh -n` catches it, a run reports it as an unrelated
     "unexpected end of file" 160 lines later.

## 6. FILES (scratchpad)

    t113-mk.sh          derives this harness from #112's and asserts no
                        residual t112/b112 references survive
    t113-armE2.sh       ARM E RE-FILTERED: filters M / P / L, the opt-var
                        exception, and the three-way LOUD/QUIET/UNRANK rank
    t113-family.sh      is any move/clear member an existence predicate?  (no)
    t113-sites.sh       every shared spelling of the eight names, for the
                        constant-expression sweep MAX_MOVE_MAX failed
    t113-align-diag.sh  gdb confirmation of the ix86_data_alignment fault
    t113-wall.sh        gdb confirmation of where aarch64 stops NOW
    t113-guards.sh      7 arms, TAB-shaped, with the defaults.h injection
    t113-build/go/run/ts.sh, t113-reconf-gcc.sh, t113-armD2.sh, t113-armE.sh

## 7. THE NATURAL NEXT SLICE

The 20 survivors, in the order their risk is understood rather than by size:

  * **`INCOMING_STACK_BOUNDARY`, `BRANCH_COST`, `ASSEMBLER_DIALECT`,
    `CASE_VECTOR_MODE`, `OPTIMIZE_MODE_SWITCHING`** -- the QUIET five.  Known
    to answer with i386's value and to say nothing.  `BRANCH_COST` reaches ten
    shared TUs including `fold-const.cc` and `ifcvt.cc`.
  * **the 15 UNRANK rows** -- each needs a run or an interprocedural check
    before anyone calls it harmless.  `LOCAL_DECL_ALIGNMENT` and
    `REG_PARM_STACK_SPACE` are the closest siblings of what landed here.
  * **`Pmode`** stays blocked on the mode union (Stage 4), unchanged.

And the wall itself has moved out of arm E: `emit_move_insn_1`'s null `GEN_FCN`
is the insn-code/`insn-flags.h` job, which is #51's routed-but-unapplied
`Makefile.in` hunk plus the union.  **Whoever takes aarch64 next should take
that, not another arm E slice** -- arm E is now behind the wall rather than in
front of it.

# TASK #113b -- #65 AND #67: THE TOP LEVEL TAKES TARGETS, PLURAL

Branched from `3c56965981e`.  Worktree came up at the bare-repo HEAD AGAIN and
needed a second `git reset --hard multi-target` -- the trap fires on every new
worktree, not once per agent.

## 1. WHAT LANDED

**#67 -- the top level owns the target list.**  `configure.ac` grows
`--enable-targets=LIST`: canonicalised per element by `config.sub`,
deduplicated, **sorted**, mandatory, with no default and no fallback.
`AC_SUBST(mt_target_subdirs)`.  `--target=` now warns explicitly.

**#65 -- `target-specs` stops being a host module.**  Removed from
`Makefile.def`'s `host_modules` and from `configure.ac`'s `host_tools`.  It is
instantiated **once per configured target** by a `define` + `$(foreach)`/
`$(eval)` block in `Makefile.tpl`, each instance configured
`--host=<triple> --with-target=<triple>`.  This is the #113 route in
production: AutoGen emits ONE parameterised block (module dimension), GNU make
expands it across N targets (target dimension).

It is deliberately **not** a `target_modules` entry either, because that would
put it in `all`.  target-specs probes the DEPLOYED machine's assembler and
linker; the build machine is not the deployment machine, so it must stay a
goal the user invokes after installing.  Both rulings are honoured at once:
per-target instantiation, and not a build-time prerequisite.

## 2. THE ARMS -- 5 CONFIGURE, 4 MAKE, AND THE TWO THAT MATTER ARE NEGATIVE

`scratchpad/t113b-conf.sh`, `scratchpad/t113b-make.sh`.  Every arm asserts the
DIAGNOSTIC TEXT, not merely a non-zero exit: "configure failed" is not a
diagnosis and would be satisfied by an unrelated breakage.

    A  NEG  no --enable-targets            rc=1 "--enable-targets=LIST is required"
    B  NEG  triple config.sub rejects      rc=1 "`nosucharch-...' is not a recognised
                                                 target triple"  -- NOT silently dropped
    C  WARN --target=<t>                   "is not how this tree selects targets"
    D  AFF  two targets                    rc=0, MT_TARGET_SUBDIRS has 2 entries
    E  PERM reversed --enable-targets      byte-identical list

    F  AFF  per-target rules exist         one per target, each naming its OWN
                                           subdir, neither mentioning the other
    G  NEG  MT_TARGET_SUBDIRS emptied      rc=2 "MT_TARGET_SUBDIRS is empty"
    H  NEG  loop sabotaged, LIST HEALTHY   rc=2 "per-target instantiation ran 0
                                                 times for 2 configured targets"
    I  NEG  old `all-target-specs'         rc=2 "is ambiguous in a multi-target
                                                 build", and it lists the goals
                                                 that do exist

**Arm H is the one the brief asked for and it is NOT the same as arm G.**  G
is an empty list.  H leaves the list healthy and breaks the loop that consumes
it, which is the case that actually reads as success: without the counter you
get a `configure-target-specs` with no prerequisites that exits 0 instantly.
The guard is `MT_SPECS_EMITTED`, appended to **inside** the `define` body, so
it counts how many times the body was really evaluated -- the thing in doubt --
and is compared against `$(words $(MT_TARGET_SUBDIRS))`.  A loop that ran zero
times cannot score as a build.

**Arm E is the enforcement mechanism for "no primary"**, not tidiness.  The
list is sorted so that any permutation of `--enable-targets` gives an
identical build; if reordering ever changes an output, something is treating
position 1 as privileged and this arm finds it.

## 2b. THE LEAK THE AFFIRMATIVE ARM ALMOST BANKED -- AND THE FIX

The first run of `make configure-target-specs` returned **rc=0 and produced
two per-target trees with the right names and the right `--host` each**.  That
is the bar as written, and I nearly recorded it as met.  Checking the CONTENT
rather than the existence of the artefacts:

    aarch64-.../target-specs/config.log:282   gcc_cv_as=as
    aarch64-.../target-specs/config.log:377   gcc_cv_ld=ld

    diff specs-aarch64-unknown-linux-gnu specs-x86_64-pc-linux-gnu
      -> 6 differing lines out of 101, and ALL SIX are the target's own name
         and the path to its config file.  All 95 PROBED lines are IDENTICAL.

`aarch64-unknown-linux-gnu-as` does not exist on this machine, so
`target-specs/configure` fell back to the build machine's own `as` and `ld`
and wrote a spec file that **names aarch64 while describing x86_64**.  Two
distinct trees, two distinct md5s, correct `--host` recorded in each -- every
signal I had been checking said PASS -- and the content was one machine's
answer served to both targets.  **This is the branch's signature bug reproduced
inside the fix for it**, and the both-sided arm that caught it was comparing
the two spec files' BODIES, not their existence or their names.

**Fixed in the generated rule**, per "never let the absence of an answer be an
answer": the per-target recipe now requires `<triple>-as` on PATH, or an
explicit `TOOLS_DIR_FOR_<triple>=DIR`, and otherwise **fails by name** with
the measurement above quoted in the message.  Verified: aarch64 now exits 1
with that diagnostic and **leaves no tree behind**, so there is no
half-written plausible artefact to mistake for a result.  x86_64 with an
explicit `TOOLS_DIR_FOR_x86_64-pc-linux-gnu` still succeeds, rc=0.

### OPEN DECISION FOR THE USER -- NOT RESOLVED HERE

`x86_64-pc-linux-gnu-as` is not on PATH either; only unprefixed `as` is.  So
the strict check refuses the native case too, and a native build now needs an
explicit `TOOLS_DIR_FOR_<triple>`.  The fork:

  (a) **Strict, as landed.**  No target may use unprefixed tools.  Nothing is
      privileged; the cost is that every invocation, native included, must say
      where the toolchain is.
  (b) **Allow unprefixed tools when the triple EQUALS the canonical build
      triple.**  Defensible on the ground that this tests a measured fact
      about the machine rather than inventing a default, and it privileges no
      target -- `config.guess`'s answer is not a position in a list.  The risk
      is that it is one short step from "the native target is special", which
      is the primary by another name.

I have landed (a) because it cannot be wrong in the direction that matters,
and (b) is a one-line relaxation if the user wants it.  **Choosing (b)
unilaterally is exactly the debugging-shaped task that contains a design
decision**, so it is reported rather than taken.

## 3. REGENERATION CONTROLS, RUN BEFORE ANY EDIT

`Makefile.in` and `configure` are generated, and I could not have told my
change from tool noise without this:

  * `autogen Makefile.def` on the UNMODIFIED tree -> `Makefile.in` **byte
    identical** (md5 `5cb459d46b28`).
  * `autoconf -I config` on the UNMODIFIED `configure.ac` -> `configure`
    **byte identical** (md5 `06d626d31355`).

Both tools come from the pinned nixpkgs and are **not** in `eb-shell.sh`'s
package set: `autogen` 5.18.16 and `autoconf269`.  Add `-p autogen` /
`-p autoconf269` rather than concluding they are unavailable, as I first did.

## 4. THE SPELLING IS `--enable-targets`, NOT `--targets`, AND THAT IS FORCED

TOPLEVEL-DESIGN.md section 1.3 recommends `--targets=` and does not price the
parser.  **Measured: it cannot be implemented without hand-editing the
generated `configure`.**  Autoconf's option loop auto-accepts only
`--enable-*` and `--with-*`; anything else reaches the `-*)` arm at
`configure:1320` and is a hard `as_fn_error ... unrecognized option`.  Note
that error is **not** suppressed by `--disable-option-checking`, which governs
only the `--enable`/`--with` unrecognized *list*.

Section 1.2 had rejected `--enable-targets` solely because it would collide
with `gcc/`'s `--enable-targets`.  **That reason has evaporated**: measured,
`enable_targets` no longer appears in `gcc/configure.ac` at all (the only hit
anywhere under `gcc/` is `CONFIGURE-HISTORY.md`).  The name is now free and
unambiguous.

**This is a visible interface decision the user expressed a preference about,
so it is flagged rather than buried.**  Every semantic ruling is honoured --
plural, mandatory, no default, no fallback, sorted.  Only the spelling
differs, and changing it later is a one-line edit plus a regenerate.

## 4b. THE BARS: THREE MET, ONE NOT -- AND THE ONE THAT IS NOT IS PRE-EXISTING

    all-gcc rc=0                          MET.  /tmp/t113b/two, cold, -j8.
    two DISTINCT per-target trees         MET.  See section 2b -- and note the
                                          first version of this claim was
                                          FALSE-GREEN until the bodies were
                                          diffed.
    a negative control that fails         MET.  Arms G and H; H is the
                                          "loop ran zero times" case.
    libgcc.a builds                       *** NOT MET ***

**Non-vacuity on the two-backend build** (the "one target is not a
demonstration of N" bar): `cc1` is 88 MB and carries **both** `targetm_i386`
and `targetm_aarch64`, `mt-i386/` and `mt-aarch64/` object dirs, and 40,772
aarch64 symbols.  (`aarch64_option_override` scored 0 and that was MY
INSTRUMENT: the symbol is `aarch64_override_options`.  A zero from a
name-matching instrument is a claim about the instrument.)

### WHY libgcc DOES NOT BUILD, AND WHY IT IS NOT THIS CHANGE

`make all-target-libgcc` fails in libgcc's own configure:

    x86_64-pc-linux-gnu-gcc: fatal error: no configuration file for target
      `x86_64-pc-linux-gnu'.  Looked in:
        <build>/gcc/../lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config
        /usr/local/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config

Measured, and it is **design doc section 6.5's shape exactly -- a mechanism
that reads a file no rule produces**:

  * `specs-config` appears in `gcc/gcc.cc` (:8609, :8646), which READS it.
  * It appears **nowhere in `gcc/Makefile.in`**.  Nothing writes or installs
    it into the driver's search path, which is an INSTALL path
    (`$(libdir)/gcc/$(version)/<target>/`), not a build path.
  * **No `libgcc.a` exists in ANY build directory on this branch** --
    `/tmp/b112`, `/tmp/b-objs`, or the coordinator's fresh `/tmp/cfgchk`.
  * Nothing I changed touches the driver's lookup or libgcc's configure.
    Before this change, target-specs configured into `<build>/target-specs/`,
    which is equally not in the driver's search path, so libgcc was blocked
    identically.

**The positive half, and it is the useful part:** the config file my
per-target rule produces is FUNCTIONAL.  Pointed at explicitly, the built
driver compiles a real object with it:

    xgcc -B<build>/gcc/ \
      -ftarget-config=<build>/x86_64-pc-linux-gnu/target-specs/specs-x86_64-pc-linux-gnu-config \
      -c hello.c -o hello.o        ->  hello.o, 1232 bytes

So for the first time there is a **working producer** of per-target
`specs-config`.  What is missing is one rule connecting it to the driver's
search path.  **That is the natural next task and it is now unblocked**; it is
the sibling of the missing `default-target` install rule that design doc
section 6.5 already tracks, and both should be done together.

Bare `xgcc` with no target selected says *"no target selected: this compiler
serves several targets and has no default among them"* -- correct behaviour,
not a bug to fix.

## 5. WHAT IS NOT DONE, STATED PLAINLY

  * **`libgcc` is NOT yet per-target.**  It remains a normal `target_modules`
    entry on the single `TARGET_SUBDIR`.  This round instantiates
    `target-specs` only.  `target-specs` was the right first module and not
    merely the easy one: it is not part of `all`, so making it multi-instance
    cannot break the build, whereas `libgcc` going multi-instance immediately
    exposes Stage 3a (`libgcc/Makefile.in:285-286`'s `-I$(gcc_objdir)` builds
    N-1 of N libgccs against the primary's `tm.h`, and they compile).  Doing
    both in one change would have coupled a working interface to that leak.
  * **The triple -> back-end mapping has NOT moved up** (Stage 4).  It is
    gated on TOPLEVEL-DESIGN.md section 8 item 2, a probe that has still not
    been run.  So `gcc/configure.ac` sheds nothing this round: it still
    canonicalises `${target}` and still does
    `gcc_manifest_targets="${gcc_extra_targets} ${target}"`, which is the
    residual primary.  **Deliberately untouched, not overlooked.**
  * **#75 (gnattools/gotools) is untouched**, as scoped.  Nothing here
    depends on it.
  * The other 24 target modules are untouched.

## 6. FLAG DAY -- READ THIS BEFORE REUSING AN OLD BUILD DIR

`--enable-targets` is **mandatory**.  Every existing harness script that
configures this tree's top level (`t112-build.sh` and its ancestors) will now
fail at configure time until it adds `--enable-targets=...`.  That is the
ruling working as intended -- there is nothing to fall back to -- but it is a
coordination cost across in-flight worktrees, and the error message names the
option and shows an example.  `stock-build.sh` is unaffected: `/tmp/b-stock`
is genuine upstream and does not have this option.

## 7. FILES (scratchpad)

    t113b-conf.sh   arms A-E, the configure side
    t113b-make.sh   arms F-I, the make side; H is the false-green control

# TASK #117 -- THE OPTAB TABLE WAS THE PRIMARY'S.  THE aarch64 WALL MOVED OFF `emit_move_insn_1`

Branched from `3aa9e0e46f1`.  Build dir `/tmp/b117` (x86_64 + aarch64, mine).
My worktree came up on the bare-repo HEAD `7208eca60d0` -- the PRINCIPLES 5
check caught it, as it has for #111, #112, #113 and #116.  `grep -c
MULTI_TARGET gcc/Makefile.in` was **0**; after `git reset --hard multi-target`
it is 28.

## 1. THE CAUSE, NAMED, AND IT WAS NOT `insn-flags.h`

The brief routed this as #51's Class B -- "`HAVE_blockage` out of the singular
`insn-flags.h`".  **That is not what stopped aarch64, and the premise was
checkable and wrong.**  `insn-flags.h` is already per base
(`aarch64-inc/insn-flags.h` forwards to `insn-flags-aarch64.h`), and none of
the six #51 names is on the path to the fault.

The wall was `optab_handler`, and it is a clean instance of PRINCIPLES 3.
Measured under gdb on the linked `cc1` with aarch64 selected
(`scratchpad/t117-cause.sh`):

    bare (primary/i386) raw_optab_handler (mov_optab, SImode)  ->  11383
    insn_aarch64::insn_data[11383].name    ->  *while_wrdivnx8bi_acle_cc
    insn_aarch64::insn_data[11383].genfun  ->  0x0
    insn_aarch64::raw_optab_handler (same scode)               ->  0

11383 is an i386 insn code.  Read against aarch64's `insn_data` -- which IS
already selected per base -- it names **an SVE predicate pattern**, whose
`genfun` is null.  `emit_move_insn_1` called it.  That is the null PC #113
recorded.  The wrong answer was not a plausible one; it was a different
machine's instruction, and nothing diagnosed it.

Why: `raw_optab_handler` and `init_all_optabs` are emitted by genopinit into
`namespace insn_<base>`, but the un-namespaced `insn-opinit.o` -- the
PRIMARY's -- is in `$(OBJS)` (gcc/Makefile.in, the `insn-opinit.o` line), and
shared code reached that.  Breakpoints on all four candidates showed the bare
`init_all_optabs` running and `insn_aarch64::init_all_optabs` **never reached
at all**, so aarch64's `pat_enable[]` stayed all-false and i386's pattern set
was installed in its place.

### THE FUNNEL EXISTED AND SELECTED NOTHING

`optabs-query.cc` already had `selected_raw_optab_handler`, and
`optabs-query.h` already carried a long, correct comment saying it was there so
COMDAT could not keep an arbitrary one of N inline bodies, and to leave
"exactly one place for a multi-target compiler to select in".  **Its body was
`return raw_optab_handler (scode);`** -- the bare name, i.e. the primary's.
Complete, documented, and inert: PRINCIPLES 4 rule 2, and the third time on
this branch that a mechanism has read as done because its comment described
what it was FOR rather than what it DID.

## 2. THE SECOND HALF, WHICH THE FIRST HALF WOULD HAVE MADE WORSE

`NUM_OPTAB_PATTERNS` sizes `pat_enable[]` inside `struct target_optabs`, and
`default_target_optabs` is ONE object in `optabs-query.cc`.  The number is per
back end.  Measured before:

    insn-opinit-i386.h      2975
    insn-opinit-aarch64.h   3328
    insn-opinit.h (shared)  2975      <- the primary's
    sizeof default_target_optabs      3465 bytes  (0xd89)

So `insn_aarch64::init_all_optabs` writes `pat_enable[0..3327]`: **353 bools
past the end of the object**, through `supports_vec_gather_load` and
`supports_vec_scatter_store` and out the other side.  Sized by one, indexed by
another, with no link error.

**Routing the selection without unioning the bound would have swapped a null
dereference for a silent buffer overflow** -- a loud bug for a quiet one, which
is the wrong direction.  Both had to land together; that is why they are one
commit.

`genopinit` therefore grows `-l` / `-U<file>` / `-A<base>`, a near-copy of
genconfig's, with the same refusals: a union file that does not name this base,
or omits the macro, or reports a value below what this base needs, is fatal.
After: 3328 everywhere, and `sizeof default_target_optabs` 3465 -> **3818**
(0xeea = 3328 + 245 + 245), which is the arithmetic closing.

### THE TRAP INSIDE THE UNION, AND IT IS NOT THEORETICAL

`NUM_OPTAB_PATTERNS` was ALSO the bound of genopinit's own `pats[]`, the sorted
scode table that `lookup_handler` **binary-searches** with
`h = ARRAY_SIZE (pats)`.  Sizing that by the union appends
`{ 0, CODE_FOR_nothing }` entries -- zero sorts below every real scode while
sitting at the END, so the table stops being sorted, and a binary search over
an unsorted table does not fail: it returns a wrong element for arbitrary
inputs.  On i386 (2975 of 3328) that would be optab queries silently answering
wrongly -- exactly the class of bug being fixed, reintroduced by the fix.

So the name is split: the union raises the SHARED struct bound, and `pats[]`
keeps this back end's own count, emitted as a literal.  Verified in the
artefacts -- shared 3328, `pats[2975]` for i386, `pats[3328]` for aarch64 --
and guard arm 6 requires the injection to leave `pats[]` unmoved.

## 3. WHAT LANDED

  * `gcc/genopinit.cc` -- `-l`/`-U`/`-A`, the union, and the split bound.
    Output files are now opened AFTER the md is read: in `-l` mode opening them
    first truncated the real `insn-opinit.h` to its two-line banner, i.e. a
    file that exists, is non-empty, and contains no optab at all.
  * `gcc/gen-multi-target-md.awk` -- `insn-opinit-<base>.part`, the
    `insn-opinit-union.list` rule, and `-U`/`-A` on every per-base run.
  * `gcc/Makefile.in` -- the same flags on the shared `s-opinit`,
    `check_opinit_union_base`, MOSTLYCLEANFILES, and the `insn-opinit.h`
    dependency for `multi-target-select.o`.
  * `gcc/multi-target-select.cc` -- the four optab entry points join the
    per-base table, and `selected_raw_optab_handler` /
    `selected_init_all_optabs` / `selected_swap_optab_enable` /
    `selected_partial_vectors_supported_p` dispatch through it.
  * four call sites moved onto the funnels (`optabs-libfuncs.cc`,
    `optabs-tree.cc`, `optabs.cc` x2, `tree-vect-loop.cc`).

### WHY `insn-opinit.o` STAYS IN $(OBJS), AND WHY THAT IS NOT A LEAK

It also defines four rodata tables shared code references bare:
`code_to_optab_` (dojump.o, ifcvt.o, optabs.o), `optab_to_code_` (optabs.o),
`convlib_def` and `normlib_def` (optabs-libfuncs.o).  Those are generated from
`optabs.def`, not from the `.md`.  **Checked rather than assumed**
(`scratchpad/t117-vocab.sh`): their BODIES are byte-identical across both
configured back ends.  A size comparison would not have settled it -- all four
are the same size on both bases, which is what a first look reported, and two
equal-length tables with different contents is precisely the case a size test
cannot see.  The whole shared prefix of `insn-opinit-<base>.h` (518 lines)
differs in exactly one line, `NUM_OPTAB_PATTERNS`, now unioned.

So the object's four FUNCTIONS are now dead and its four TABLES are genuine
shared vocabulary.  Guard arm 2 asserts nothing in the link references the four
bare functions; that is what stops them quietly becoming the answer again.

## 4. THE WALL MOVED, AND THE NEW PLACE IS NAMED

    BEFORE  aarch64 big.c: SIGSEGV, null PC, #1 emit_move_insn_1
                           <- init_set_costs <- initialize_rtl
    AFTER   aarch64 big.c: rc=4, internal compiler error:
                           in setup_class_hard_regs, at ira.cc:507
                           <- ira_init <- initialize_rtl

`backend_init_target` runs `init_set_costs ()`, then `init_expr_target ()`,
then `ira_init ()`.  The old stop was inside the first; the new one is in the
third, so **both `init_set_costs` and `init_expr_target` now complete** -- and
both are heavy `emit_move_insn`/`optab_handler` users, which is the point.  A
segfault with no diagnostic became a named assert.

The new wall is `ira_assert (ira_class_hard_regs_num[cl] == n)`: two walks over
one register class disagreeing on how many hard registers it has.  That is the
**register-class vocabulary**, not the optab one -- `N_REG_CLASSES` 34 for i386
against 20 for aarch64, the `CONVERTED_REGS` group #92 retired.  Whoever takes
aarch64 next should take that; it is not #51, not #36, and not this.

**Same input, same claim discipline as #113: `int x = 1;` still works, `big.c`
still does not, and I claim the move and nothing more.**

## 5. AN INCIDENTAL DEFECT FOUND AND FIXED: TRUNCATED SPEC FILES

`target-specs/configure` exited 1 for **every** target on this branch:

    configure: error: specs-<t>-config carries capabilit(ies) that are not in
    the expected list in configure.ac:as_ltoffx_ldxmov_relocs

#116 added the key to the emitter and to `check-target-caps`, but not to
`ts_expected`.  The check was working exactly as designed; the fix is to
complete the list, not relax it, and that is what the diagnostic instructs.

**It was not cosmetic.**  The abort happened partway through, so
`specs-<target>` was left TRUNCATED at 39 lines.  After the fix: 101 lines for
x86_64 and 96 for aarch64.  Every aarch64 measurement taken on this branch
since #116 was taken against a truncated spec file, and nothing said so --
`t113-ts.sh`-shaped scripts assert the file is non-empty, and 39 lines is
non-empty.  Recorded because "checks the artefact exists" is not "checks the
artefact is complete".

`scratchpad/t117-reconf-ts.sh` regenerates `configure` and asserts the key
reaches the GENERATED file, with four control keys emitted before and after it
that must survive -- the unquoted-heredoc trap that once silently dropped all
97 keys.

## 6. INSTRUMENT FAILURES PAID FOR THIS TASK

  1. **My scode used a shift of 16; the code uses 20.**  Both handlers then
     answered `CODE_FOR_nothing`, and the probe printed a tidy, symmetric,
     entirely meaningless "neither back end has a SImode move" -- absurd on its
     face, and nothing in the harness objected, because 0 is a legal answer.
     Fixed by reading the shift out of `optabs-query.h` and by a non-vacuity
     arm that refuses to score when both sides answer nothing.
  2. **`grep -q` scored a match as a miss.**  My first symbol survey used
     `grep -q` in a loop; `optabs.o`'s reference to `code_to_optab_` came back
     0 while `nm` showed it plainly.  Nothing in the harness uses `grep -q`
     now; every arm counts lines.
  3. **Substring matching inflated the leak count 1 -> 40.**
     `selected_raw_optab_handler` CONTAINS `raw_optab_handler`.  Both numbers
     are printed side by side in `t117-optab-syms.sh` so they cannot be
     confused again.  Measured: EXACT=1, SUBSTR=52.
  4. **An enum walker that trimmed with `gsub(/[ ,].*/,"")` deleted every
     line**, because each entry begins with the indent.  Caught only by a `-n`
     guard; now cross-checked by requiring `E_VOIDmode` and `unknown_optab` to
     come out as 0.
  5. **`insn_data_tab / NUM_INSN_CODES` looked like 40.02** on a misread hex
     size, which would have put `genfun` at the wrong offset and made every
     null read as confirmation.  Solved from BOTH bases instead: exactly 40 on
     each, and the stride check is an arm.

## 7. REGRESSION BARS, ALL ON /tmp/b117, MY OWN BUILD DIR

  * `make multi-target-objs cc1 lto1` **rc=0**; cc1 88,832,400 bytes, lto1
    links.
  * x86_64 `-O2` md5 **`378fc33c1e70`** -- the recorded baseline, unmoved,
    re-checked after the guard harness relinked.
  * `stock-compare.sh`, `IN` **absolute**, `MT=/tmp/b117`, `ST=/tmp/b-stock`:
    **5/5 IDENTICAL**, 5 distinct md5 per side, **negative control firing**
    (1158 vs 804 lines), rc=0.
  * `scratchpad/t117-guards.sh`: **10/10**, three of them injections.
    Arm 6 removes `-U` and requires 3328 -> 2975, i.e. the primary's own count
    back, AND requires `pats[]` not to move.  Arm 7 hands genopinit a union
    list with aarch64 deleted and requires a FATAL that NAMES aarch64.  Arm 8
    is the one the brief asked for: it puts `selected_raw_optab_handler` back
    to `return raw_optab_handler (scode);`, rebuilds only that object, and
    **requires the bare symbol to reappear** (0 -> 1), then restores and
    verifies the restore (1 -> 0).
  * `scratchpad/t117-tab.sh`: **both-sided, on the RUNNING cc1.**  Breakpoints
    on all three `init_all_optabs` addresses; x86_64 enters `insn_i386`,
    aarch64 enters `insn_aarch64`, the bare one is entered by neither, and the
    three addresses are asserted distinct before anything is scored.  Before
    this change the same arm entered the BARE one under aarch64.

### STDERR -- WHICH ARM

  * **cold** `multi-target-objs cc1 lto1`: **460 lines**, host-compiler noise.
  * **incremental** relink after the guard harness: **8 lines**, all
    `is unchanged`, with the 24 `'@' is redundant` absent -- the documented low
    composition of the 32-line floor, because the `.md` rules had already
    re-run.

### SCOREBOARD: NOT RUN, NOT BANKED

Nothing here touches a probed macro and no arm is added, so the honest figure
is unchanged and is carried, not re-derived: header **i386 112 PASS / 0 FAIL,
aarch64 8 PASS / 104 FAIL of which only 2 passes are TRUSTED** (the other 6
compare a redirect with itself); TAB **i386 32/0, aarch64 27/5**.  I did not
run `macro-probe-run.sh`.

## 8. WHAT I DID NOT DO, AND WHY

  * **#51's `gen_movxf` (Class C) is untouched and still filed.**  It needs the
    user's ruling on whether `reg-stack.o` moves per-base, and nothing here
    depends on that ruling.
  * **#51's Class A/B forwarders are untouched.**  They are blocked on removing
    `$(INSNEMIT_SEQ_O)` from `$(OBJS)`, which is another owner's hunk, and --
    now measured -- they are not what stopped aarch64.
  * **#36 was not reached.**  Nothing here needed a generator to read
    `targ_caps`; the union file is the existing `-l`/`-U`/`-A` channel that
    genconfig and genmodes already use.
  * The other primary-only objects still in `$(OBJS)` -- `insn-attrtab.o`,
    `insn-automata.o`, `insn-dfatab.o`, `insn-latencytab.o`, `insn-preds.o`,
    `$(INSNEMIT_SEQ_O)` -- are each the same shape `insn-opinit.o` was and are
    **unmeasured**.  `t117-optab-syms.sh` generalises in one variable if
    someone wants the next one.

## 9. FILES (scratchpad)

    t117-build.sh       /tmp/b117, derived from t113-build.sh
    t117-ts.sh          target-specs configure, both targets
    t117-reconf-gcc.sh  gcc/Makefile.in -> build dir
    t117-reconf-ts.sh   autoconf for target-specs, with heredoc controls
    t117-optab-syms.sh  who references the primary's insn-opinit.o; exact vs substring
    t117-vocab.sh       are the four rodata tables shared vocabulary?  (yes, by BODY)
    t117-cause.sh       gdb: the i386 icode read against aarch64's insn_data
    t117-wall.sh        where aarch64 stops now
    t117-guards.sh      10 arms, three injections
    t117-tab.sh         both-sided, on the running cc1

# TASK #119 -- THE CONNECTING RULE: `specs-config` REACHES THE DRIVER, AND `libgcc.a` BUILDS

Branched from `8bd43122139`.  Worktree came up at the bare-repo HEAD
`7208eca60d0` AGAIN; `git reset --hard multi-target` and a CONTENT anchor
(`grep -c MULTI_TARGET gcc/Makefile.in` -> 28) before anything else.

## 1. THE BRIEF'S PREMISE, CONFIRMED AND THEN OVERTAKEN

Confirmed exactly as stated: `specs-config` occurs in **`gcc/gcc.cc` only**
(:8609 defines the basename, :8646 documents the layout) and **nowhere in
`gcc/Makefile.in`**, and a whole-tree grep excluding nothing finds no other
producer.  A mechanism reading a file no rule writes.

It was **half** the disconnection, and the other half runs the opposite way.
Wiring only the half in the brief would have produced a file that is written,
found, and then still ignored:

  * `find_target_config` looks under `<exec-prefix>/<version>/<target>/` --
    #96's layout -- and finds `specs-config` there.
  * `set_up_specs` looks for the SPEC FILE at
    `exec_prefix + just_machine_suffix + "specs"`, and this driver sets
    `just_machine_suffix = ""` (:9242), because a compiler serving every
    target has no machine name of its own.  That path is
    **`$(libdir)/gcc/specs`: ONE spec file for every target.**

So there was no per-target spec-file lookup at all.  `gcc.cc`'s own comment on
`TARGET_CONFIG_BASENAME` says "#96 fixes the spec file at
`$(libdir)/gcc/$(version)/<target>/specs`" -- the intent was **written down in
the consumer and only half implemented**, and the implemented half is the one
the brief named.

**The measured symptom, found by building rather than by reading.**  With only
the config wired, libgcc's `-m32` multilib assembled `config/i386/morestack.S`
with no `--32`:

    morestack.S:372: Error: invalid instruction suffix for `push'

`pushl` rejected because the assembler was in 64-bit mode.  The correct
`*asm: %{m16|m32:--32} %{m16|m32|mx32:;:--64} %{mx32:--x32}` was sitting in the
per-target spec file, unread.  After the `set_up_specs` fix: **zero assembler
errors**.

## 2. WHAT LANDED

**`Makefile.tpl` / `Makefile.in` (regenerated with `autogen`, +140 each, and
the two diffs are the same size -- the edit, no tool noise).**

  * `MT_GCC_VERSION` from `gcc/BASE-VER`, `MT_INSTALL_CONFIGDIR` =
    `$(libdir)/gcc/$(version)`, and `MT_BUILD_CONFIGDIR_REL`, the BUILD TREE's
    mirror of it.  The mirror is derived by reproducing the driver's own
    `bindir -> libdir/gcc` relation arithmetically rather than hard-coding
    `../lib/gcc`, and both `patsubst`es fail by name if `$(bindir)` or
    `$(libdir)` is not under `$(exec_prefix)`.
  * `configure-target-specs-<t>` now passes `--with-specs-file=<mirror>/specs`,
    so `target-specs` writes `specs` and `specs-config` where the driver looks.
  * It also passes `--with-source-specs` when `gcc/`'s `specs-src-<t>` and
    `mlib-specs-<t>` exist.  **Those were produced and handed to nobody**;
    `gcc/Makefile.in`'s `multi-target-specs` prints instructions telling a
    human to pass them, and nothing did.  That is where `*asm`, `*link`,
    `*startfile` and the multilib tables come from.
  * `TARGET_SPECS_FLAGS_FOR_<t>`, a pass-through, beside the existing
    `TOOLS_DIR_FOR_<t>`.  `target-specs` has its own options and the set a
    target needs is not knowable at this level; `gcc/` previously ran it with a
    FIXED list and truncated everything else away on the next `make`.
  * One symlink per target into `gcc/`: `specs-<t>` -> the per-target spec
    file.  A LINK, not a copy -- there is still one file.  `gcc/Makefile.in`'s
    `$(SPECS)` rule reads that name and had been taking its `-dumpspecs`
    fallback branch in every build.  **The config file is deliberately NOT
    linked**; see section 4b, which is the sharpest finding of this task.
  * `install-target-specs-<t>` / `install-target-specs`, deliberately NOT part
    of `install`, for the same reason `configure-target-specs` is not part of
    `all`.

**`gcc/Makefile.in`.**

  * `MULTI_TARGET_DRIVERS` -- a `<triple>-gcc` copy **per configured target**,
    replacing the single `$(BUILD_DRIVER_NAME)` rule (which is now one of them,
    so no duplicate recipe).  The driver's NAME is the only thing that tells it
    which target it is, so a build tree with one copy could exercise the
    installed mechanism for exactly one target and had to reach every other
    with an explicit `-ftarget-config=` -- a different code path.  That made
    the one target with a copy privileged **in the place the design is
    verified**.
  * `MULTI_TARGET_CONFIGDIR`, defaulting to `$(objdir)/../lib/gcc/$(version)`,
    and `check-multi-target-specs` now takes its config corpus from there as
    well as from `gcc/`.  A wrong value cannot make that check pass -- it can
    only make it decline to run and say so.
  * `install-driver` installs those names too.  The comment there already said
    "per-target `<triple>-gcc` spellings are install aliases and belong with
    the per-target manifest"; nothing installed them, so an installed tree had
    a `gcc` that correctly refuses and **no name under which any configured
    target could be asked for at all**.

**`gcc/gcc.cc`.**  `set_up_specs` reads `<dirname(found_target_config)>/specs`
last, so it overrides both target-neutral files.  Derived from
`found_target_config` rather than composed again, so the spec file and the
config cannot come from different directories, and a driver that found no
config reads no per-target spec file either.

**`gcc/defaults.h`.**  `!defined (__cplusplus)` added to the existing
"keep the real macros" guard, as a fourth arm beside
`MULTI_TARGET_TARGETM_BASE`, `GENERATOR_FILE` and `MULTI_TARGET_SUPPLY_TU`.
`libgcc` compiles C and reaches `defaults.h` through `tconfig.h` -> `tm.h`;
`target-frame.h` declares `mt_minimum_alignment (tree, machine_mode, ...)`, and
a C TU has neither type, so **every libgcc object including `libgcov.h` or
`generic-morestack.c` failed with `unknown type name 'machine_mode'`.**

  **This is not the leak reopened, and it was measured before being relied on.**
  No C source under `libgcc/` spells any of the thirteen redirected names; the
  only grep hits are `X86_64_SAVE_NEW_STACK_BOUNDARY` in a `.S` file (a
  different identifier) and `__LIBGCC_DWARF_CIE_DATA_ALIGNMENT__`.  So the arm
  changes no value anything reads.  And a runtime library is single-target by
  ruling, so the one `tm.h` it compiles against is legitimately its own
  target's.  That the `tm.h` it is handed today is `gcc/`'s build-directory one
  is `libgcc/Makefile.in`'s `-I$(gcc_objdir)` -- Stage 3a, real, separate, and
  not fixable by converting these macros.

## 3. THE BARS

  * **`libgcc.a` BUILDS.**  Cold, objects deleted first:
    `/tmp/b119/x86_64-pc-linux-gnu/libgcc/libgcc.a`, **1197082 bytes, 157
    members, 0 `error:` in stderr**, and `_muldi3.o` extracted from it is
    `ELF64 / Advanced Micro Devices X86-64` -- not an empty archive and not
    somebody else's ISA.  `libgcc_s.so.1` also links.
  * **`make all-target-libgcc` still exits 2**, and the reason is now
    ENVIRONMENTAL, not the tree: the `-m32` multilib dies on
    `gnu/stubs-32.h: No such file or directory`, 12 times, which is the
    32-bit glibc this host does not have and which top-level configure warns
    about at the start.  **0 assembler errors**, where before the `set_up_specs`
    fix there were dozens.  Multilib is mandatory here, so the aggregate goal
    cannot go green on this machine; the archive the bar names does build.
  * **Installed compiler, no `-B`** (`scratchpad/t119-guards.sh`, 5 arms, all
    pass, `GCC_EXEC_PREFIX` unset, cwd outside the build tree):
    - ARM 1 BOTH-SIDED: `/tmp/b119-inst/bin/<t>-gcc -### -c c.c` passes
      `-ftarget-config=/tmp/b119-inst/lib/gcc/17.0.0/<t>/specs-config` for BOTH
      targets, and neither driver names the other's directory.
    - ARM 2 NEGATIVE and ASYMMETRIC: with aarch64's config removed, aarch64
      fails naming it (rc=1) and **x86_64 is unaffected (rc=0)**.  A control in
      which both broke would prove nothing about per-target files.
    - ARM 3 CONTENT: 28 differing lines, **6 name-or-path and 22 PROBED
      capability lines** (`as_aarch64_mabi` 1/0, `as_ix86_sahf` 0/1,
      `as_r_x86_64_code_6_gottpoff` 0/1).  #113b's false green was 6 differing
      lines and ALL SIX were the name; the arm fails below 4 probed differences.
    - ARM 4: 0 build-tree paths and 2 installed paths in each installed spec
      file (both directions, so neither can pass vacuously).
    - ARM 5: `cc1` defines `targetm_i386` AND `targetm_aarch64`.
  * **x86_64 `-O2` md5 `378fc33c1e70`, 12369 bytes** -- unmoved.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock`, absolute `IN`,
    5 distinct md5 per side, **negative control firing** (1158 vs 804 lines),
    rc=0.
  * aarch64 still ICEs on `big.c` at line 24 -- #113's recorded wall
    (`init_set_costs` / null `GEN_FCN`), unchanged and not touched here.

  * cold two-backend `all-gcc` from an EMPTY directory (`/tmp/b119c`):
    **rc=0**, and both `x86_64-pc-linux-gnu-gcc` and
    `aarch64-unknown-linux-gnu-gcc` are present in `gcc/`.

### THE CHECK THAT HAD NEVER RUN NOW RUNS

`check-multi-target-specs` reported `NOTHING CHECKED ... This is a SKIP, not a
pass` in **every build on this branch**, because its corpus is
`gcc/specs-<t>*` and nothing produced any.  Now:

    check-spec-refs: 2 spec file(s), every name consulted by the driver
    check-target-caps: 2 config file(s), every capability read by something
    check-multi-target-specs: 2 spec file(s) handed to read_specs, 0 rejected

Its `read_specs` arm also had to learn where the config lives, or every spec
file would have been reported `NOT USABLE -- no target selected`, which blames
the spec file for the harness's own missing argument.  Measured: it did exactly
that for one iteration.

## 4. MY OWN NEGATIVE CONTROL FIRED TWICE, AND BOTH TIMES IT WAS RIGHT

`mt-config-found.sh` runs at the END of every `configure-target-specs-<t>`.
It asks the CONSUMER, because writing the file and writing it where the driver
looks are both `rc=0` from the producer's side.

  1. **The spec file was answering.**  The moment the `gcc/specs-<t>` symlink
     was added, the arm reported NEGATIVE CONTROL DID NOT FIRE.  Correct:
     `carry_target_config_as_switch` falls back to `*cc1_target_config` from a
     spec file, that route produces the SAME path string, and **it never checks
     the file exists** -- so it answered happily with the file deleted.
     Everything the affirmative arm had been scoring could have come from
     there.  Fixed by stashing `gcc/specs`, `gcc/specs-<t>` and
     `gcc/specs-<t>-config` for the duration of both arms and restoring them
     from a `trap`.
  2. **The INSTALLED tree was answering.**  After `make install`,
     `find_target_config`'s third authority (`STANDARD_EXEC_PREFIX`) is a real
     answer, so the build-tree driver exits 0 pointing at
     `/tmp/b119-inst/...`.  Requiring a hard failure would have made the check
     pass only on machines where this compiler had never been installed -- a
     check that stops working the moment the thing it checks starts being used.
     The bar is now **the answer must CHANGE**: fail naming the path, or
     succeed naming a DIFFERENT one.  Refused: the answer staying the same.

## 4b. cc1's SELFTESTS HAVE NEVER RUN WITH A TARGET, AND WHEN THEY DO THEY FAIL

This is the finding to give somebody next.

`gcc/Makefile.in` has `SELFTEST_TARGET_CONFIG = $(wildcard specs-$(TEST_TARGET)-config)`
-- and nothing has ever produced that file, so **every `make all-gcc` on this
branch has run cc1's selftests with NO target selected**, i.e. against the
empty back end, and they passed.

Linking the config there is a one-line change and I made it first.  The
selftests then run for real and **FAIL**:

    simplify-rtx.cc:9121 test_scalar_int_ops:
      FAIL: ASSERT_RTX_EQ (op0, simplify_gen_binary (PLUS, mode, op0, const0_rtx))
        expected: (reg:CI 113)
        actual:   (plus:CI (reg:CI 113) (const_int 0))
    cc1: internal compiler error: in assert_rtx_eq_at, at selftest-rtl.cc:57

`CImode` is **aarch64's** 768-bit tuple mode; i386 has none.  `test_scalar_ops`
walks `0 .. NUM_MACHINE_MODES` and tests everything `SCALAR_INT_MODE_P`, so the
union hands it a mode from the other back end, and the constant-folding paths
bail out above `MAX_BITSIZE_MODE_ANY_INT` (simplify-rtx.cc:2115, :2299).  That
is the mode union -- #51 / Stage 4 -- not this rule.

**I did not land the link**, because it turns `all-gcc` red for every agent on
the branch, and I cannot fix the mode union inside this task.  I also did not
quietly drop the subject: the reason is written at the point of the decision in
`Makefile.tpl`, with the exact reproduction

    ln -s <libdir>/gcc/<version>/<t>/specs-config gcc/specs-<t>-config
    make all-gcc

and `check-multi-target-specs` was given the config directory directly instead,
so the checks that CAN run now do.  **Do not read "selftests pass" on this
branch as evidence about any target until this is done.**

## 5. #64's REMAINING HALF: NOT BUILT, AND ON PURPOSE

The brief asked for the `default-target` install rule "together with" this.
**I did not write it, because the ruling has changed since TOPLEVEL-DESIGN
section 6.5 was written and section 6.5 is now stale.**  `64d8d28b30a`
(2026-08-12 11:56, later than that document) says in its commit message and in
`gcc/gcc.cc:8548`:

> Nothing in this compiler's build or installation writes that file, by design.

and the file's whole comment argues the point: it is a statement by an
INSTALLER about a machine, not something the build may decide.  PRINCIPLES 2a
lists "an install rule that bakes one target into `gcc/`" among the changes
that look like fixes and undo the project.  **Writing that rule would
contradict both.**  #64 is therefore not "half fixed"; it is fixed for the two
routes that exist and deliberately unfixed for the third.  Section 6.5 item 6
of TOPLEVEL-DESIGN should be struck.

What WAS missing on the installed side, and is now fixed, is different and
carries no default: `install-driver` installed **no `<triple>-gcc` at all**, so
route 2 -- select the target by the name you invoke -- was unreachable in an
installed tree.

## 6. WHAT I DID NOT DO

  * **No dependency from `libgcc` to `configure-target-specs-<t>`.**  Adding
    one would make the probe a build-time prerequisite of `all`.  The driver
    already fails by name and names the fix ("A target's configuration is
    written by target-specs' configure, which is run after this compiler is
    built"), so the ordering is the user's.  **This is a fork I am reporting
    rather than taking**: (a) leave it, `make all` fails with a diagnostic that
    names the goal to run; (b) make `configure-target-libgcc` depend on it,
    which costs every `make all` a probe and requires the target toolchain at
    build time.
  * `libgcc` is still a single-target `target_modules` entry on
    `TARGET_SUBDIR` (= `x86_64-pc-linux-gnu` here).  Unchanged.
  * The `-m32` multilib is unproven on this host for want of 32-bit glibc.
  * `accel_dir_suffix` sits inside the driver's composition of this path; the
    offload-vs-target axis question is still #96's and is untouched.
  * Probe scoreboard NOT run and NOT moved; carrying the recorded line
    unchanged.

## 7. STDERR -- WHICH ARM

  * cold `all-gcc` (`/tmp/b119`, empty dir, `-j8`): **745 lines / 126
    `warning:`**.
  * incremental `all-gcc` after the `gcc.cc` edit: **59 lines**.
  * `install-target-specs`: **0 lines**.
  Not comparable with the 32-line incremental floor; classify against the cold
  baseline.

## 8. FILES

    mt-config-found.sh    the consumer-side check, run by every
                          configure-target-specs-<t>; two arms, self-restoring
    mt-install-config.sh  the install copy + path rewrite, counted in BOTH
                          directions so neither can pass vacuously
    scratchpad/t119-conf.sh      two-target configure
    scratchpad/t119-build.sh     make driver, reports rc and stderr composition
    scratchpad/t119-specs.sh     both probes, with REAL aarch64 binutils and
                                 each target's OWN glibc headers
    scratchpad/t119-guards.sh    the 5 acceptance arms
    scratchpad/t119-evidence.sh  libgcc.a: members, and the ISA of a member
    scratchpad/t119-stock.sh     stock-compare with an absolute IN
    scratchpad/t119-cold.sh      cold two-backend all-gcc
    scratchpad/t119-regen.sh     config.status after a Makefile.in edit

**Getting a real aarch64 assembler is one nix-shell argument**:
`-p pkgsCross.aarch64-multiplatform.buildPackages.binutils`.  #113b concluded
the strict tools check refuses aarch64 on this machine; it does not have to.
The matching headers are that same package set's glibc dev output, and passing
each target its OWN header directory is what makes ARM 3 a real both-sided
test instead of one machine's answer served twice.

# TASK #122 -- `ADJUST_REG_ALLOC_ORDER` WAS THE PRIMARY'S. THE aarch64 WALL MOVED OFF `ira_init` ENTIRELY

Branched from `c7859768dd8`.  Worktree came up at the bare-repo HEAD
`7208eca60d0` AGAIN -- `grep -c MULTI_TARGET gcc/Makefile.in` was **0** --
`git reset --hard multi-target` took it to **37**.  Build dir `/tmp/b122`, my
own, cold.

## 0. A BRIEF ITEM I COULD NOT READ

The brief asked me to read tasks **#59, #56, #53, #85, #121, #114**.  There is
no task backlog in this worktree: `STATE.md` has `# TASK` sections for #77,
#106, #107, #92, #99/#86/#109, #108, #111, #45/#98, #78/#51, #112, #113, #116,
#113b, #117, #119 and now #122, and **none of those six numbers is among
them** (`#114` appears once, in passing, at STATE.md:3066).  I worked from the
measured wall and from #92's section, which is the register-vocabulary one.  If
those descriptions live outside the worktree they were not available to me and
I did not report against them.

## 1. THE WALL, DIAGNOSED STATICALLY BEFORE ANYTHING WAS EDITED

`big.c` ICEd at `setup_class_hard_regs, at ira.cc:507`, reproduced exactly.
Line 507 is `ira_assert (ira_class_hard_regs_num[cl] == n)` -- the same set of
hard registers counted two ways, by walking `reg_alloc_order` and by iterating
the class's own hard-reg set.

**The cause is two compile-time `#ifdef`s in MIDDLE-END translation units**,
i.e. the primary's headers answering for every base.  Not inferred -- read off
the linked `cc1` with `nm`:

  * `ira.o` carried `U x86_order_regs_for_local_alloc()` and **no other**
    order-related undefined symbol.  That is i386's `ADJUST_REG_ALLOC_ORDER`,
    called unconditionally from `setup_alloc_regs`, for every base.
  * `aarch64_adjust_reg_alloc_order()` was **defined in the same binary** (`T`,
    `0xe10fab`) and **referenced by no object at all** -- the branch's
    "mechanism present but never invoked" shape, exactly.
  * aarch64's static table `mt_reg_alloc_order` in `target-regs-aarch64.o` is
    `0x17c` = 380 bytes = 95 ints and, dumped, **all 95 are zero**.  That is
    correct: `aarch64.h:1699` is `#define REG_ALLOC_ORDER {}`, an EMPTY
    initialiser, and `ADJUST_REG_ALLOC_ORDER` is the ONLY thing that ever makes
    it an order.

So under an aarch64 selection the allocation order was **i386's**, and the
registers aarch64 allocates but i386 does not were never visited.

**MY PREDICTION OF WHICH REGISTERS WAS WRONG, AND THE DIAGNOSTIC CORRECTED IT.**
I expected 92, 93, 94 -- the three above i386's `FIRST_PSEUDO_REGISTER`.  The
measured answer, printed by the new diagnostic under injection, is
**16, 17, 18, 19**: i386's own adjust function omits the registers i386 never
allocates, and aarch64 allocates those numbers.  Recorded because it is the
argument for printing the set rather than asserting on a count.

## 2. WHAT LANDED

  * **`target-regs.h` / `target-regs.cc`** -- a new
    `void (*adjust_reg_alloc_order) (void)` slot, NULL if the base defines
    none, supplied per base under `#ifdef ADJUST_REG_ALLOC_ORDER`.  The macro
    is a STATEMENT (`x86_order_regs_for_local_alloc ()`), not a function name,
    so it is wrapped.  Same shape as the existing `regno_reg_class` slot; no
    `target.def` entry, no back end edited.
  * **`MT_HAVE_REG_ALLOC_ORDER`** in `target-regs.h` -- `#ifdef
    REG_ALLOC_ORDER` asked of the SELECTED base.  It reads
    `d_reg_alloc_order != NULL`, which is not a second fact that could drift:
    `target-regs.cc` sets that pointer under exactly that `#ifdef`.
  * **Five middle-end sites converted** -- `ira.cc:484`, `ira-color.cc:5243`,
    `recog.cc:3830`, `reload1.cc:1847`, `reload1.cc:1910`; `reginfo.cc:327`
    re-spelled to the same macro so all six read alike.
    **The `#else` arms are NOT dead code and were not dropped.**  At
    ira-color.cc and reload1.cc:1910 they are a DIFFERENT tie-break (prefer
    call-clobbered registers), so making the sites unconditional would have
    handed a back end that defines no REG_ALLOC_ORDER a tie-break it never
    asked for.  Both arms are kept and selected at run time.
  * **`ira.cc:507`'s bare `ira_assert` became a named diagnostic.**  Same
    condition, unchanged; what it SAYS is not.  It now prints the base, the
    class name, both counts and the missing register numbers, and says the
    order and the classes come from different back ends.
    **It is NOT a permutation check, deliberately** -- i386's own adjust pads
    its tail with zeros on purpose (i386.cc:24003), so `reg_alloc_order` is
    legitimately not a permutation and a check demanding one would have failed
    on the arm that must not move.  I nearly wrote that check; reading i386.cc
    first is the only reason I did not.

Two further sites, found by sweeping rather than by the diagnostic:

  * **`ira.cc:1492/1496`** -- `targetm.class_max_nregs` walked
    `N_REG_CLASSES` (the union, 34) and asked `aarch64_class_max_nregs` about
    classes 20..33, whose `gcc_unreachable ()` fired.  Bounded by
    `MT_N_REG_CLASSES`, exactly as `reginfo.cc:546` already was.
  * **`ira.cc:624`** -- `memory_move_cost` over the same union width, likewise
    bounded.  **Its phantom rows are pre-filled with `SHRT_MAX`, not left at
    the `XCNEW` zero**: a zero there reads as a move cost of "free", i.e. the
    most attractive answer in every comparison that might reach it.  An absent
    class must not be the cheapest class.

The other ~30 `N_REG_CLASSES` walks in `ira.cc` were examined and left alone
**with a reason, not by omission**: they are either declarations/allocations
(the union IS the layout) or already inert on phantom classes, being guarded by
`ira_class_hard_regs_num[cl] == 0` or by an empty-set test.  That is why the
ICE surfaced at the two unguarded hook queries and nowhere else.

## 3. WHERE `big.c` GETS TO NOW, AND WHAT THE NEXT WALL IS

**Past `ira_init` and past all of `backend_init_target`.**  It now stops in a
different phase entirely -- RTL expand:

    during RTL pass: expand
    internal compiler error: in expand_stack_alignment, at cfgexpand.cc:6941

Line 6941 is `gcc_assert (targetm.calls.get_drap_rtx != NULL)`, reached because
`crtl->stack_realign_needed` came out true from
`INCOMING_STACK_BOUNDARY < crtl->stack_alignment_estimated`.

**Cause identified by name, same instrument, same shape as the one just
fixed:** `nm -uC cfgexpand.o` shows `U ix86_incoming_stack_boundary` and
nothing else.  `i386.h:803` is
`#define INCOMING_STACK_BOUNDARY ix86_incoming_stack_boundary`; aarch64 defines
no such macro, so `defaults.h:945` should give it `PREFERRED_STACK_BOUNDARY` --
but a middle-end TU sees the primary's spelling and reads **i386's global
variable** for every base.  DRAP is an i386 concept and aarch64 supplies no
`get_drap_rtx`, so the assert is the correct response to a wrong input.

It is **already filed**: `macro-status.txt:114` has
`INCOMING_STACK_BOUNDARY UNCONVERTED` and MACRO-LEAK.md:205 lists it.  So the
next wall is a known, tracked macro leak, not a new mystery.

## 4. THE BARS

  * `make multi-target-objs cc1 lto1` in `$B/gcc` -- **rc=0**.
  * **x86_64 `-O2` md5 `378fc33c1e70`, unmoved.**
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock`, absolute `IN`,
    **5 distinct md5 per side**, **negative control firing** (1158 vs 804),
    rc=0.  All five: O0 `1c00922491f8`, O1 `4fabab94b41b`, O2 `378fc33c1e70`,
    O3 `d220421237bc`, Os `d6787f7e281f`.
  * **`scratchpad/t122-guards.sh`: 9 PASS / 0 FAIL**, four of them the
    injection.  ARM 2 is TAB-shaped -- gdb breakpoints on the two adjust
    bodies IN THE RUNNING `cc1`, addresses asserted DISTINCT first, and each
    base must enter its own body AND NOT the other's.  ARM 4 reverts
    `ira.cc`'s dispatch to the `#ifdef`, rebuilds, and requires the primary's
    symbol to REAPPEAR in `ira.o` (0 -> 1) and the ICE to come back; then
    restores and requires both to reverse (1 -> 0, and `big.c` back to its new
    stopping place).
  * **`int x = 1;` for aarch64 still rc=0**, 373 bytes, **empty stderr**.
  * Cold `all-gcc` before any edit: **rc=0, 745 lines / 126 `warning:`** --
    matching #119's recorded cold arm exactly.

### STDERR -- WHICH ARM

Incremental `multi-target-objs cc1 lto1` after the final edit: **97 lines / 8
`warning:`**; after the code-only edit it was **9 lines / 1 warning**, a single
`-Wsign-compare` on `SUPPORTS_STACK_ALIGNMENT` at `ira.cc:2556`.  **That
warning is PRE-EXISTING, not mine**: it occurs **48 times in the cold log taken
before any edit**, and I merely caused one TU to rebuild.  It is a real
signedness defect in `defaults.h:1256` for whoever owns `STACK_BOUNDARY`.
Not comparable with the 32-line incremental floor.

## 5. THREE INSTRUMENT FAILURES, ALL CAUGHT BY THEIR OWN GUARDS

  1. **The gdb probe read nothing, twice, for two different reasons.**  First
     because the build is `-g0` (`'targetm_regs' has unknown type`), then
     because I probed with `int x = 1;` -- a translation unit with **no
     function** never reaches `ira_init`, so no breakpoint could ever hit.  An
     input chosen to be trivial was trivial in the one way that mattered.  Both
     were caught only by the non-vacuity FATAL that refuses to score when the
     probe cannot show it read anything; without it, "no breakpoint hit" would
     have been indistinguishable from "the dispatch is fine".
  2. **My own ICE-site matcher reported the injected run as "no ICE at all".**
     It matched only `internal compiler error: in <fn>, at <file>` -- and the
     entire point of the ira.cc:507 rewrite is that the failure no longer has
     that shape.  **The instrument was written against the old shape of the
     thing under test**, and scored the mitigation firing as the mitigation
     being absent.  Now matches both forms and requires the named one.
  3. **`stock-compare.sh` could not run in any build dir made since #119** and
     failed in the direction that looks like a compiler bug.  It passed
     `-ftarget-config=specs-x86_64-pc-linux-gnu-config`, a relative name in
     `gcc/`; #119 deliberately stopped linking the config there.  All five
     levels died with `no target configuration was selected` -- **the driverless
     `cc1` refusing CORRECTLY, reported as five compiler failures.**  Fixed:
     the path is absolute, overridable via `MTCFG`, and checked by name before
     anything runs.  (Its "UNSCORABLE counts as failure" rule is why this was
     never a false green.)

## 6. WHAT I DID NOT DO

  * **`HONOR_REG_ALLOC_ORDER` is NOT converted.**  Same family, and
    `ira-color.cc:2249` reads it.  Left because **neither configured base
    defines it** (only arm, arc, xtensa and nds32 do), so with i386+aarch64 it
    is 0 on both sides and any arm I wrote would be one-sided and unfalsifiable
    on this machine.  It is a real latent leak for an arm-or-arc build.
  * **`inv_reg_alloc_order` is computed before `ADJUST_REG_ALLOC_ORDER` runs**
    and is therefore stale for both bases -- identical upstream.  Its two
    consumers read it after the adjustment.  I corrected the FALSE COMMENT at
    `reginfo.cc:324` that asserted the order is "a permutation over the union
    width" at that point (it is not, for either base, for two different
    reasons) rather than changing when it is computed, which would move code
    generation on the arm that must not move.
  * **Probe scoreboard NOT run and NOT moved.**  Nothing here touches a probed
    macro.  Carrying the recorded line unchanged: header **i386 112 PASS / 0
    FAIL, aarch64 8 PASS / 104 FAIL of which only 2 are TRUSTED**; TAB **i386
    32/0, aarch64 27/5**.
  * `make all-target-libgcc` not re-run; #119's environmental `-m32` blocker
    is unchanged.

## 7. FILES

    t122-conf.sh      two-target configure, /tmp/b122
    t122-build.sh     make at the TOP level
    t122-gccbuild.sh  make in $B/gcc -- where cc1 actually builds
    t122-specs.sh     both target-specs probes, real aarch64 binutils
    t122-diag.sh      the gdb diagnosis, with the non-vacuity FATAL that fired
    t122-guards.sh    9 arms; ARM 2 both-sided on the running cc1, ARM 4 the injection

# TASK #123 -- THE STACK-ALIGNMENT CLOSURE.  THE SYMBOL `nm` NAMES IS NOT THE ONE THAT STOPS `big.c`

Branched from `77bd4356973`.  Worktree came up at the bare-repo HEAD
`7208eca60d0` AGAIN -- `grep -c MULTI_TARGET gcc/Makefile.in` was **0** --
`git reset --hard multi-target` took it to **37**.  Build dir `/tmp/b123`, my
own, cold.

## 0. THE FINDING THAT CHANGED THE SCOPE

The brief handed me `nm -uC cfgexpand.o -> U ix86_incoming_stack_boundary`
and `ICE: expand_stack_alignment, at cfgexpand.cc:6941`.  Both reproduced
exactly.  `INCOMING_STACK_BOUNDARY` is a real leak: `i386.h:803` makes it that
global, and **i386 is the only one of the 48 back ends that defines the macro
at all**, so `defaults.h:944`'s `#ifndef` is false in shared code and the other
47 read i386's option state.

**It is not why the function is entered, and converting it alone would have
been the half-fix PRINCIPLES 2a names.**  cfgexpand.cc:6895 is
`if (! SUPPORTS_STACK_ALIGNMENT) return;`, which `defaults.h:1256` makes
`(MAX_STACK_ALIGNMENT > STACK_BOUNDARY)`.  `MAX_STACK_ALIGNMENT` is defined by
exactly three headers -- `i386.h:850`, `i386/cygming.h:42`, `nvptx.h:61` -- so
`defaults.h:1249`'s `#ifdef` is TRUE in shared code because the primary is
i386, and every target gets i386's `MAX_OFILE_ALIGNMENT` (2^31, elfos.h:63).
aarch64's own answer is `defaults.h:1252`'s `STACK_BOUNDARY`, 128, so
`SUPPORTS_STACK_ALIGNMENT` should be `128 > 128` -- **FALSE**, and
`expand_stack_alignment` should return at its second line and never reach
line 6941 at all.  DRAP is an i386 concept; aarch64 supplies no `get_drap_rtx`
because it never asked to be in that function.

So the group is **four**, not one:
`INCOMING_STACK_BOUNDARY`, `MAX_STACK_ALIGNMENT`,
`MAX_SUPPORTED_STACK_ALIGNMENT`, `SUPPORTS_STACK_ALIGNMENT` -- the transitive
closure through `defaults.h:944` and `:1249-1256`.  Had I converted only the
name the instrument gave me, `SUPPORTS_STACK_ALIGNMENT` would have stayed
wrongly true, aarch64 would have stayed inside the function, and the most
likely outcome is the *quieter* one: `INCOMING_STACK_BOUNDARY` now answers 128,
`stack_alignment_estimated` happens to be <= 128, the assert passes, and
aarch64 silently runs i386's stack-realignment path.  **A generalisation worth
keeping: an undefined symbol names the macro that DRAGGED IT IN, not the macro
that CAUSED the control flow.  Two different macros in one closure, and only
one of them names anything.**

## 1. WHAT LANDED

Same mechanism as #108's six, no new registry, no back end edited:

  * **`target-frame.h`** -- four new fields on `target_frame_desc`.  All
    `unsigned int` / `bool`, and the types are not cosmetic:
    `ix86_incoming_stack_boundary` is `unsigned int` (i386.h:2614) and i386's
    `MAX_STACK_ALIGNMENT` is 2147483648, which **does not fit in `int`**.
  * **`target-cumargs.cc`** -- four thunks, each one macro expansion in the
    per-base TU compiled with `-I<base>-inc`.  **No `#ifdef` and no `#else`
    arm anywhere**, and that is the design rather than an omission:
    `defaults.h:1249`'s `#ifdef MAX_STACK_ALIGNMENT` has ALREADY RUN against
    this base's headers by the time control reaches the thunk, and has already
    chosen which definition is in force.  The existence question does not
    disappear -- it is consumed where it is meaningful.
  * **`target-cumargs-select.cc`** -- four `mt_*` entry points through
    `mt_frame ()`, so no target selected fails by name.
  * **`defaults.h`** -- the four `#undef`/`#define` redirects, beside #108's.

**Why `MAX_SUPPORTED_STACK_ALIGNMENT` and `SUPPORTS_STACK_ALIGNMENT` are their
own fields and are not derived in `defaults.h` from the other two.**  Deriving
would give the right answer today and would re-derive, in shared code, the
choice `defaults.h:1249` makes with an `#ifdef` -- the one thing shared code
cannot evaluate.  A base WITH `MAX_STACK_ALIGNMENT` has
`MAX_SUPPORTED == MAX_STACK_ALIGNMENT`; a base WITHOUT has
`MAX_SUPPORTED == PREFERRED_STACK_BOUNDARY`, which is **not** its
`MAX_STACK_ALIGNMENT` whenever the two boundaries differ.  Deriving picks one
arm for everyone.

**Swept for constant-expression contexts before landing.**  Outside `config/`
the four have 2 + 1 + 21 + 11 uses and every one is an ordinary run-time
expression -- `if` conditions, comparisons, assignments to `unsigned int`, and
one `known_le`.  No `#if`, no case label, no array bound, no static
initialiser.  **Bound-vs-index checked explicitly** (these are boundary
constants, the shape that produced `NUM_OPTAB_PATTERNS` and `N_REG_CLASSES`):
nothing outside `config/` is dimensioned by any of the four.  And unlike
`DATA_ALIGNMENT`, **none of the four is `#ifdef`-guarded at a use site**, so a
redirect cannot leave the guard answered by one back end and the body by
another.

## 2. WHERE `big.c` GETS TO NOW, AND THE NEXT WALL

**Past RTL expand entirely.**  It now stops one pass later:

    during RTL pass: ira
    internal compiler error: in aarch64_can_eliminate, at aarch64.cc:14153

Line 14153 is `gcc_assert (from == ARG_POINTER_REGNUM || from == FRAME_POINTER_REGNUM)`,
reached from `ira_setup_eliminable_regset`.  **Diagnosed with the same
instrument, before any inference:** `nm -uC ira.o` shows
`U ix86_initial_elimination_offset` and `U ix86_push_rounding`, and
`reload1.o` shows the same two.  So `ira.cc` is walking **i386's
`ELIMINABLE_REGS` table** and handing aarch64's hook i386's register numbers.
That is `INITIAL_ELIMINATION_OFFSET` (macro-status.txt, `UNCONVERTED`)
plus the `ELIMINABLE_REGS` table and the `*_POINTER_REGNUM` names -- a known,
tracked family, not a new mystery.  It is the natural next task and it is
register-vocabulary shaped, i.e. #92/#122 territory.

## 3. THE BARS

  * `make multi-target-objs cc1 lto1` in `$B/gcc` -- **rc=0**.
  * **x86_64 `-O2` md5 `378fc33c1e70`, 12369 bytes -- unmoved** (measured
    before AND after the edit in this same build dir).
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock`, absolute `IN`,
    **5 distinct md5 per side**, **negative control firing** (1158 vs 804),
    rc=0.  All five match #122's record: O0 `1c00922491f8`, O1 `4fabab94b41b`,
    O2 `378fc33c1e70`, O3 `d220421237bc`, Os `d6787f7e281f`.  It does run in
    this build dir -- checked, given #122 found it had been scoring the
    driverless `cc1`'s correct refusal as five compiler failures.
  * **`scratchpad/t123-guards.sh`: 11 PASS / 0 FAIL.**
  * **aarch64 `int x = 1;` still rc=0, 373 bytes, empty stderr, and
    byte-identical to the pre-edit output.**
  * Cold `all-gcc` before any edit: **rc=0, 745 lines / 126 `warning:`** --
    matching #119's and #122's recorded cold arm exactly.

### THE ARMS THAT MATTER

  * **ARM 2 is TAB-shaped**: gdb on the RUNNING `cc1`, one breakpoint per run.
    `MAX_SUPPORTED_STACK_ALIGNMENT` is **aarch64 128 vs x86_64 2147483648** --
    the two OPPOSITE arms of the `#ifdef` shared code could not evaluate --
    and `SUPPORTS_STACK_ALIGNMENT` is **false vs true**, so the divergence is
    in the truth value itself and cannot be "everyone got the same new answer".
  * **ARM 2c is asymmetric on purpose.**  `INCOMING_STACK_BOUNDARY` is 128 for
    BOTH bases (i386's default and aarch64's fall-through coincide), so an
    equality arm on its value would pass while proving nothing.  What
    distinguishes them is whether it is asked at all: x86_64 reaches it,
    **aarch64 never does**, because it now returns early.  The aarch64 side
    additionally requires the run to reach `ira`, so that "not asked" is the
    early return and not an early crash.
  * **ARM 4 is the injection**: reverse-applies the `defaults.h` hunk only (so
    the thunks stay compiled and only the redirect goes), rebuilds, and
    **requires `ix86_incoming_stack_boundary` back in `cfgexpand.o` (0 -> 1)
    and the OLD ICE back by name**.  Both fired.  Restore then requires both
    to reverse (1 -> 0, and `big.c` back to `aarch64_can_eliminate`), verified.

## 4. MY INSTRUMENT WAS WRONG AND ONE ARM PASSED ON IT

Recorded because the arm that passed is the interesting half.

The first ARM 2 set all three breakpoints in ONE gdb run and narrated
`HIT <name>` between `finish` commands, assuming they would be reached in the
order set.  They are not: `mt_supports_stack_alignment` is hit first and
repeatedly (from `record_alignment_for_reg_var`), so **all three printed
values were that one function's return value under three different names**.
Two arms compared the wrong function's answer and reported FAIL -- and the
third, `supports`, **PASSED**, because 0-for-aarch64 / 1-for-x86_64 is what it
happened to be reading anyway.  A correct-looking pass on a mislabelled read.

Fixed by giving each function its own run with exactly one breakpoint, and by
matching **the breakpoint gdb REPORTS** against the function under test before
scoring any value -- the check the first version lacked, and the one that
would have caught it.

**Then the repaired non-vacuity FATAL fired, and it was right.**
`mt_max_stack_alignment` is **never called for aarch64**: outside `config/`
that macro has exactly one use (tree-vect-data-refs.cc:6808), which needs the
vectoriser, which aarch64 cannot reach while it still ICEs in `ira`.  So
**`MAX_STACK_ALIGNMENT` is currently UNCHECKABLE at run time on this machine**
-- a measured "cannot be checked, because X", not a pass.  The arm was moved to
`MAX_SUPPORTED_STACK_ALIGNMENT`, which is reached on every function and
diverges by the same 16-million-fold margin because it is the other arm of the
same `#ifdef`.

## 5. THE SCOREBOARD -- NOT RUN, NOT MOVED, AND DELIBERATELY NOT BANKED

**I did not run `macro-probe-run.sh` and I am claiming no scoreboard movement.**
Carrying the recorded line unchanged: header **i386 112 PASS / 0 FAIL,
aarch64 8 PASS / 104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0,
aarch64 27/5**.

All four macros stay **`UNCONVERTED`** in `macro-status.txt`, and that is the
rule working rather than an oversight.  `tab-probe.sh`'s harness reads
CONSTANTS out of the running `cc1`; these four are calls that vary with option
state, so there is nothing for it to read, and the file's own rule is that a
macro may move to `CONVERTED_*` **only in the change that adds its TAB arm**.
They are in exactly #108's six's position, for exactly the same reason.

**Predicted, so that it is caught rather than banked:** the next probe run will
flip four more aarch64 header arms FAIL -> PASS **for the wrong reason** --
base-B's context does not define `MULTI_TARGET_TARGETM_BASE`, so `defaults.h`
redirects both sides and the arm compares a redirect with itself.  Retire
those four; do not bank them.  A note to this effect is now in
`macro-status.txt`'s header naming all ten macros, so the next agent does not
spend a session re-converting something that says `UNCONVERTED`.

## 6. A PRE-EXISTING DEFECT THIS REMOVED, MEASURED

#122 recorded a `-Wsign-compare` on `SUPPORTS_STACK_ALIGNMENT` (`defaults.h`)
as "a real signedness defect for whoever owns `STACK_BOUNDARY`", 48
occurrences in a cold log.  Measured here: cold log **48** mentions of
`SUPPORTS_STACK_ALIGNMENT` and 35 `-Wsign-compare`; after this change,
**0** mentions and 18 `-Wsign-compare` (the rest are unrelated).  Comparing
i386's unsigned 2^31 with a signed `STACK_BOUNDARY` is what produced it, and
giving the closure honest `unsigned int` types removes the comparison rather
than silencing it.

## 7. STDERR -- WHICH ARM

  * Cold `all-gcc`, before any edit: **745 lines / 126 `warning:`**.
  * Incremental `multi-target-objs cc1 lto1` after the edit: **299 lines / 52
    `warning:`** (many TUs rebuild -- `defaults.h` reaches ~520 of them).
  * A second, near-no-op incremental: **34 lines / 3 `warning:`**, composed of
    **24 `'@' is redundant`** from unmodified aarch64 `.md` files, **0
    `is unchanged`**, and one 3-warning `lto-common.cc` block.  Same shape as
    the 32-line floor with the 8 `is unchanged` absent, which PRINCIPLES
    records as varying with what was last rebuilt.

## 8. WHAT I DID NOT DO

  * **No TAB arms for the four**, for the reason in section 5.  This is the
    same debt #108's six carry and it is now written down in one place.
  * **`MAX_STACK_ALIGNMENT` has no run-time arm**, because nothing aarch64 can
    currently reach evaluates it (section 4).  It gains one for free the day
    the `ira` wall falls and the vectoriser runs.
  * **`nvptx`'s `MAX_STACK_ALIGNMENT` is untested** -- it is the third definer
    and is not a configured base here, so any arm would be one-sided.
  * `make all-target-libgcc` not re-run; #119's environmental `-m32` blocker
    is unchanged.
  * The `asan.cc:1573` assert now compares against the selected base's
    `MAX_SUPPORTED_STACK_ALIGNMENT` instead of i386's 2^31.  aarch64's 128 >=
    64 so it holds; a back end whose `PREFERRED_STACK_BOUNDARY` is below 64
    would newly trip it.  That is the assert working for the first time, and
    it is written at the point of the decision in `target-frame.h`.

## 9. FILES

    t123-conf.sh      two-target configure, /tmp/b123
    t123-build.sh     make at the TOP level
    t123-gccbuild.sh  make in $B/gcc -- where cc1 actually builds
    t123-specs.sh     both target-specs probes, real aarch64 binutils
    t123-guards.sh    11 arms; ARM 2 gdb on the running cc1, ARM 4 the injection
    eb-shell-gdb.sh   the build shell PLUS gdb -- gdb is not in the plain
                      DEVSHELL set, and a missing tool scores 0 in the
                      direction that makes the reference look correct

# TASK #124 -- THE REGISTER-ELIMINATION TABLE.  THE LIST, NOT THE FUNCTION THE SYMBOL NAMES

Branched from `1ed6e523c48`.  Worktree came up at the bare-repo HEAD
`7208eca60d0` AGAIN -- `grep -c MULTI_TARGET gcc/Makefile.in` was **0** --
`git reset --hard multi-target` took it to **37**.  Build dir `/tmp/b124`, my
own, cold.

## 0. WHAT THE INSTRUMENT NAMED, AND WHAT IT MISSED

The brief handed me `nm -uC ira.o -> U ix86_initial_elimination_offset` and
`ICE: aarch64_can_eliminate, at aarch64.cc:14153`.  Both reproduced exactly,
and the symbol is in **three** consumer objects, not one: `ira.o`,
`reload1.o`, `rtlanal.o`.

**`ira.cc` NEVER SPELLS `INITIAL_ELIMINATION_OFFSET`.**  What it holds is the
TABLE -- `static const struct {const int from, to;} eliminables[] =
ELIMINABLE_REGS;` at ira.cc:2535, evaluated in a shared translation unit, i.e.
the primary's four pairs and the primary's register numbers:

    ARG_POINTER_REGNUM         i386 16   aarch64 65
    FRAME_POINTER_REGNUM       i386 19   aarch64 64
    STACK_POINTER_REGNUM       i386  7   aarch64 31
    HARD_FRAME_POINTER_REGNUM  i386  6   aarch64 29

so `ira_setup_eliminable_regset` asks `targetm.can_eliminate (16, 7)` of
aarch64, whose `aarch64_can_eliminate` asserts the FROM is one of ITS two.
The offset function is dragged in *alongside*, from `reload1.cc` and
`rtlanal.cc`, by the same table's numbers.  **The named macro is a member of
the closure, not its cause** -- the same shape as #123, arriving by a
different route.

**BOTH BASES HAVE FOUR PAIRS.**  A length check would have scored the leak as
absent.  `vax.h:314` has one pair and `rs6000.h:1614` six, so the length is a
real variable that these two configured bases happen to agree on -- the
argument for printing the CONTENTS rather than asserting on a count, made
again.

**THE `#ifdef` NOBODY WOULD HAVE LOOKED AT.**  reload1.cc:288 is
`#ifdef RELOAD_ELIMINABLE_REGS`, asked of the PRIMARY's headers about the
SELECTED base.  No in-tree back end defines it (grepped over all of
`config/`), so it is false today for the right answer by accident.

## 1. WHAT LANDED

Same mechanism as #108's six and #123's four -- no new registry, no back end
edited, no `target.def` entry:

  * **`multi-target-reg-probe.cc` + `gen-reg-widths.sh`** -- a fifth measured
    union quantity, `MULTI_TARGET_UNION_NUM_ELIMINABLE_REGS` (**4** here),
    taken as the max of this base's `ELIMINABLE_REGS` and
    `RELOAD_ELIMINABLE_REGS` lengths.  Needed because reload1.cc:318 is
    `static poly_int64 (*offsets_at)[NUM_ELIMINABLE_REGS]` -- a
    pointer-to-ARRAY type, which cannot hold a call.
  * **`target-frame.h`** -- five new fields on `target_frame_desc`:
    `n_eliminables` / `d_eliminables` (flattened `{from,to}` pairs),
    `n_reload_eliminables` / `d_reload_eliminables`, and
    `poly_int64 (*initial_elimination_offset) (int, int)`.
  * **`target-cumargs.cc`** -- the tables from `[][2] = ELIMINABLE_REGS` in
    the base's own TU, the `#ifdef RELOAD_ELIMINABLE_REGS` answered there, a
    thunk wrapping the offset statement, and static_asserts of each base's own
    count against the union bound.
  * **`target-cumargs-select.cc`** -- seven `mt_*` entry points.  The two
    index readers RANGE CHECK and fail by name: an unchecked read returns
    whatever `int` follows the table, and a register number stays plausible
    while being wrong.
  * **`defaults.h`** -- `INITIAL_ELIMINATION_OFFSET` redirected;
    `ELIMINABLE_REGS` **POISONED**.
  * **Eight consumers rewritten**: `ira.cc`, `reload1.cc`,
    `lra-eliminations.cc`, `rtlanal.cc`, `varasm.cc`, `stmt.cc`, `df-scan.cc`,
    `builtins.cc`.

**WHY `ELIMINABLE_REGS` IS POISONED AND NOT REDIRECTED.**  It is a brace
initialiser; there is no run-time spelling to point it at.  Leaving the name
alone was the quiet option and the wrong one -- it would stay defined,
expanding to the primary's four pairs, and a ninth consumer (or a rebased
upstream one) would compile clean and be wrong in exactly the way this fixes.

**THE POISON IS A `#define` FOR ONE AND A BARE `#undef` FOR THE OTHER.**  A
poison `#define` makes `#ifdef` TRUE, which is the wrong answer for a name
whose whole content is an existence question.  `ELIMINABLE_REGS` is never
`#ifdef`'d (swept over `gcc/` and `libgcc/`; the only hit is a 2007 ChangeLog
line), so a `#define` there can only be reached as a use.
`RELOAD_ELIMINABLE_REGS` **was** `#ifdef`'d, so it is only `#undef`'d.

**BOUND-VS-INDEX, DONE EXPLICITLY, BECAUSE IT IS THE FIFTH TIME.**
`NUM_ELIMINABLE_REGS` now means the run-time count and bounds every LOOP;
`MULTI_TARGET_UNION_NUM_ELIMINABLE_REGS` means the compile-time maximum and is
the LAYOUT of `offsets_at` and its `xmalloc` stride.  `reg_eliminate` in both
reload1.cc and lra-eliminations.cc is **allocated at the union width**, not at
the current selection: it is allocated once and cached across functions, and a
multi-target compiler can be asked for a different target in between, which
would leave a short array behind for a wider base.

## 2. WHERE `big.c` GETS TO NOW, AND THE NEXT WALL

**Past `ira`, past reload/LRA, and into a later pass entirely:**

    during RTL pass: pro_and_epilogue
    internal compiler error: in plus_constant, at explow.cc:102
    ... aarch64_expand_prologue -> insn_aarch64::gen_prologue

Line 102 is `gcc_assert (GET_MODE (x) == VOIDmode || GET_MODE (x) == mode)`.
The caller is **aarch64's own prologue expander**, so this is a mode carried
INTO aarch64 from shared code rather than a table aarch64 was handed.
`nm -uC explow.o` shows `U ix86_tune_features` and nothing else in this
family, which is NOT the cause -- the shape points at `Pmode`
(MACRO-LEAK.md class (c4), `(ix86_pmode == PMODE_DI ? DImode : SImode)` on
i386, a plain constant on aarch64) or at another mode-valued macro.  **I did
not chase it and I am not claiming to know which**; recorded as measured
symptom plus a named suspect, for the next task to diagnose properly.

## 3. THE BARS

  * `make multi-target-objs cc1 lto1` in `$B/gcc` -- **rc=0**.
  * **x86_64 `-O2` big.c md5 `378fc33c1e70`, 12369 bytes -- unmoved**,
    measured BEFORE and AFTER in this same build dir.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock`, absolute `IN`,
    **5 distinct md5 per side**, **negative control firing** (1158 vs 804),
    rc=0, run both before and after.  All five match the recorded values:
    O0 `1c00922491f8`, O1 `4fabab94b41b`, O2 `378fc33c1e70`,
    O3 `d220421237bc`, Os `d6787f7e281f`.  **It does run in this build dir** --
    checked explicitly, given #122 found it had been scoring the driverless
    `cc1`'s correct refusal as five compiler failures.
  * **`scratchpad/t124-guards.sh`: 13 PASS / 0 FAIL.**
  * **aarch64 `int x = 1;` still rc=0, 373 bytes, empty stderr, and
    byte-identical (md5 `b01d9157fdc1`) to the pre-edit output.**
  * Cold `all-gcc` before any edit: **rc=0, 624 lines / 110 `warning:`**.

### THE ARMS THAT MATTER

  * **ARM 2 is TAB-shaped**: gdb on the RUNNING `cc1`, one breakpoint per run,
    and the breakpoint gdb REPORTS matched against the function under test
    before any value is scored.  Both sides read the SAME slot -- pair 0,
    which is `{ARG_POINTER_REGNUM, STACK_POINTER_REGNUM}` in both back ends'
    own headers -- and get **aarch64 65 -> 31 vs x86_64 16 -> 7**.  Four
    diverging numbers, so it cannot be "everyone got the same new answer".
  * **ARM 2c is labelled CONSISTENCY, NOT EVIDENCE**, in the arm's own text:
    both bases report 4 pairs, which cannot distinguish a fix from a leak.
  * **ARM 4 is the injection**: reverse-applies the whole conversion except
    the two pure-measurement files (825 lines over 12 files), rebuilds, and
    requires **`ix86_initial_elimination_offset` back in the consumers
    (0 -> 3)** and the **OLD ICE back by name**.  Both fired.  Restore
    requires both to reverse (3 -> 0, and `big.c` back to explow.cc:102),
    verified.

## 4. THE INSTRUMENT FAILURE THIS RUN PRODUCED

**`gen-reg-widths.sh` ran, exited 0, and changed nothing.**  I added the new
symbol to the probe, added it to the script's symbol loop and to its refusal
check, rebuilt -- and `target-cumargs.cc` still failed with
`MULTI_TARGET_UNION_NUM_ELIMINABLE_REGS was not declared`.  The header was
byte-identical, so `move-if-change` kept the old one and make reported success.

The cause: **I never added the `#define` to the script's heredoc.**  Every
part of the mechanism worked -- the probe object really did carry
`mt_probe_num_eliminable_regs` with size 5, `nm -S` really did read it, the
maximum really was computed -- and the artefact was the old one.  This is
PRINCIPLES section 4 rule 7 verbatim: **the failure was silently WRONG, not
silently EMPTY**, and every check on the script's exit status, on the header
existing, and on it being non-empty passes on it.  What caught it was the
compile error two steps later; what SHOULD catch it is ARM 0, which now reads
the `#define` out of the generated header **by name and by value** and is the
first arm to run.

## 5. THE SCOREBOARD -- NOT RUN, NOT MOVED, AND DELIBERATELY NOT BANKED

**I did not run `macro-probe-run.sh` and I am claiming no scoreboard
movement.**  Carrying the recorded line unchanged: header **i386 112 PASS / 0
FAIL, aarch64 8 PASS / 104 FAIL of which only 2 are TRUSTED**; TAB **i386
32/0, aarch64 27/5**.

`ELIMINABLE_REGS` and `INITIAL_ELIMINATION_OFFSET` stay **`UNCONVERTED`** in
`macro-status.txt`, which is the rule working: a macro moves to `CONVERTED_*`
only in the change that adds its TAB arm, and `tab-probe.sh`'s harness reads
CONSTANTS out of the running `cc1`.  The pair now brings the "converted but
reads UNCONVERTED" list to **twelve**, and the header note names all twelve.

**Predicted so it is caught rather than banked, and it is a NEW shape.**
`INITIAL_ELIMINATION_OFFSET` will flip for the familiar reason (base-B lacks
`MULTI_TARGET_TARGETM_BASE`, so both sides read the redirect).
`ELIMINABLE_REGS` is different: it is POISONED, so a header arm compares a
poison identifier in shared context against the real table in a base context.
Whatever it reports is about the poison, never a value.  **A third
wrong-reason shape; retire on sight.**

## 6. WHAT I DID NOT DO

  * **No TAB arms for the two**, for the reason in section 5 -- the same debt
    the other ten carry.
  * **The `*_POINTER_REGNUM` macros are NOT converted.**  `ARG_POINTER_REGNUM`
    and `FRAME_POINTER_REGNUM` are MACRO-LEAK.md class (d): `rtl.h:3936/3944`
    use them on `#if` arithmetic lines, and making them run-time makes the
    preprocessor see undefined identifiers and evaluate `0 == 0` as true,
    collapsing `GR_ARG_POINTER` onto `GR_FRAME_POINTER` in
    `enum global_rtl_index`.  **That is a design fork, not an oversight**, and
    it is untouched here: this change converts the TABLE that carries those
    numbers between back ends, not the names themselves.  Consumers still
    compare against the primary's `STACK_POINTER_REGNUM` etc. in several
    places (ira.cc, reload1.cc, lra-eliminations.cc, builtins.cc), and those
    comparisons are still wrong for a non-primary base.  They did not stop
    `big.c` and I did not widen the change to reach them.
  * **`df-scan.cc`'s `static bool initialized` still caches `elim_reg_set`
    across target selections.**  Pre-existing upstream, and now more visible
    because the set it caches is per base.  Left alone deliberately -- fixing
    it is a lifetime question about `df_hard_reg_init`, not this conversion.
  * **`RELOAD_ELIMINABLE_REGS` has no both-sided arm and cannot have one
    here**: no in-tree back end defines it, so both configured bases take the
    same branch and any arm would be one-sided and unfalsifiable on this
    machine.  Same situation as #122's `HONOR_REG_ALLOC_ORDER`.  It is a real
    latent leak for an avr-shaped build.
  * **`plus_constant` at explow.cc:102 is not diagnosed**, only located
    (section 2).
  * `make all-target-libgcc` not re-run; #119's environmental `-m32` blocker
    is unchanged.

### STDERR -- WHICH ARM

  * Cold `all-gcc`, before any edit: **624 lines / 110 `warning:`**.
  * Incremental `multi-target-objs cc1 lto1` after the edit: **285 lines / 49
    `warning:`** (defaults.h reaches ~520 TUs).
  * A second, near-no-op incremental: **38 lines / 3 `warning:`**, composed of
    **4 `is unchanged`**, **24 `'@' is redundant`** from unmodified aarch64
    `.md` files, and one 3-warning `lto-common.cc` block.  Same shape as the
    documented ~32-line floor, which PRINCIPLES records as varying with what
    was last rebuilt.

## 7. FILES

    t124-conf.sh      two-target configure, /tmp/b124
    t124-build.sh     make at the TOP level
    t124-gccbuild.sh  make in $B/gcc -- where cc1 actually builds
    t124-specs.sh     both target-specs probes, real aarch64 binutils
    t124-state.sh     big.c site + `int x = 1;` + x86_64 -O2, taken the SAME
                      way before and after so the two readings are comparable
    t124-sc.sh        stock-compare with an ABSOLUTE big.c and a tagged outdir
    t124-guards.sh    13 arms; ARM 0 the generated-header check the
                      silent-no-op cost me, ARM 2 gdb on the running cc1,
                      ARM 4 the injection

# TASK #125 -- `Pmode'.  THE EIGHTH WALL, AND THE FIRST ONE `nm -uC' CANNOT SEE

Worktree came up at bare-repo HEAD `7208eca60d0` AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in` was **0** -- `git reset --hard multi-target` took
it to **37**.  That is now four worktrees in a row.  Build dir `/tmp/b125`, my
own, cold.

## 0. THE BRIEF SAID `Pmode' WAS A SUSPECT, NOT A FINDING.  IT IS THE CAUSE.

#124 located `ICE: in plus_constant, at explow.cc:102` and deliberately
declined to name a cause.  Diagnosed here, by reading the RUNNING cc1
(`scratchpad/t125-cause.sh`), one breakpoint per run:

At the failing call, with frame #1 exactly the `aarch64_expand_prologue` from
the ICE's own backtrace:

    mode_arg  = 27 = DImode    <- aarch64's own Pmode (aarch64.h:1441)
    mode_of_x = 26 = SImode    <- stack_pointer_rtx, built in emit-rtl.cc:6266

and on the x86_64 side the same instrument reads **27 and 27** and finds **no
mismatching call anywhere**, in a run that really compiled (19949 bytes of
asm), so this is a divergence and not "everyone got the same answer".

`explow.cc:102` is `gcc_assert (GET_MODE (x) == VOIDmode || GET_MODE (x) ==
mode)`.  `stack_pointer_rtx` is `gen_raw_REG (Pmode, STACK_POINTER_REGNUM)` in
`emit-rtl.cc` -- a SHARED translation unit -- so it took i386's `Pmode`.

## 1. THIS IS THE *SILENT-DEFAULT* VARIANT, AND IT IS WORSE THAN THE USUAL LEAK

i386's is `#define Pmode (ix86_pmode == PMODE_DI ? DImode : SImode)`
(i386.h:2001), and `ix86_pmode` is an OPTION variable, `Init (PMODE_SI)` at
i386.opt:314, promoted to `PMODE_DI` by `ix86_option_override` -- which runs
only when i386 is the SELECTED target.

So shared code compiling for aarch64 did not get "x86_64's answer".  It got
**the primary's unconfigured default, SImode**, which is the right answer for
NEITHER configured base.  A leak that served the primary's real value would
have produced DImode here by luck and hidden this indefinitely.

**Both configured bases' `Pmode` is DImode.**  Every value-equality arm --
including the header probe's -- therefore passes on this leak and always has.
Recorded in `macro-status.txt` as a FOURTH wrong-reason shape, distinct from
the base-B redirect one.

## 2. AND `nm -uC' SCORES THIS LEAK AS ABSENT.  STATE THE BLIND SPOT.

Seven walls were cleared by `nm -uC <obj>` naming a leaked `ix86_*` symbol.
It cannot name this one, and not by bad luck: `ix86_pmode` is an option
variable, i.e. `global_options.x_ix86_pmode` -- a member of a struct shared
code legitimately links against.  It is not a function and not a distinct
symbol, so **no object anywhere carries an undefined reference naming it**
(`nm | grep -w ix86_pmode` on `cc1` is empty; checked, with the tool asserted
non-empty first).  A macro can leak with a completely clean `nm`.

The general form, for the next agent: **the symbol instrument sees macros that
expand to CODE.  It is blind to macros that expand to OPTION STATE**, and
option state is exactly where the silent-default leaks live.

## 3. WHAT LANDED

Same mechanism as #108's six, #123's four and #124's two -- no new registry, no
back end edited, no `target.def` entry.  Four files, ~90 lines, mostly comment:

  * **`target-frame.h`** -- `scalar_int_mode (*pmode) (void)` on
    `target_frame_desc`, plus `extern scalar_int_mode mt_pmode (void)`.
    `scalar_int_mode` and not `machine_mode` on purpose: `Pmode` yields a
    `scalar_int_mode` today and generic code relies on that type, so the
    weaker return type would compile at the definition and fail (or pick a
    different overload) hundreds of sites away.
  * **`target-cumargs.cc`** -- `mt_base_pmode`, evaluating `Pmode` in THIS
    base's TU, through `as_a <scalar_int_mode>` so a back end whose `Pmode` is
    not a scalar integer fails by name in its own TU rather than at one of the
    648 shared sites.
  * **`target-cumargs-select.cc`** -- `mt_pmode`, through `mt_frame ()` and not
    cached, because i386's answer varies with option state.
  * **`defaults.h`** -- `#undef Pmode` / `#define Pmode (mt_pmode ())` in the
    existing shared-code block.

**THE SWEEP THAT MADE A CALL-REDIRECT LEGAL**, done before writing it, because
a redirect to a function is only possible if no site wants a constant.
`Pmode` has **648** use sites outside `config/`, `testsuite/` and
`ada/gcc-interface/`, and among them: no `#if`/`#elif` line names it, no
`case` label, no array bound, no static initialiser, and no `#ifdef Pmode`.
The only `#ifndef Pmode` in the tree is `mips.h:2751` and
`loongarch.h:855` -- back ends' own headers, in translation units that keep
the real macro.  So this is **not** MACRO-LEAK class (d) and needs no `#if`
arithmetic decision.

`STACK_SAVEAREA_MODE` (defaults.h:1479) expands to `Pmode` and is defined
EARLIER in the file; it picks the redirect up by ordinary macro expansion
because the redirect block is last.  That is the block's design, not luck.

## 4. THE BARS

  * `make multi-target-objs cc1 lto1` in `$B/gcc` -- **rc=0**, first try.
  * **x86_64 `-O2` big.c md5 `378fc33c1e70`, 12369 bytes -- unmoved**,
    measured BEFORE and AFTER in this same build dir.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock`, absolute `IN`,
    **5 distinct md5 per side**, **negative control firing** (1158 vs 804),
    rc=0.  All five match the recorded values: O0 `1c00922491f8`,
    O1 `4fabab94b41b`, O2 `378fc33c1e70`, O3 `d220421237bc`,
    Os `d6787f7e281f`.  It does run in this build dir -- checked.
  * **`scratchpad/t125-guards.sh`: 14 PASS / 0 FAIL.**
  * **aarch64 `int x = 1;` still rc=0, 373 bytes, empty stderr, md5
    `b01d9157fdc1`** -- byte-identical before, after, and after the injection
    round trip.
  * Cold `all-gcc` before any edit: **rc=0, 639 lines / 114 `warning:`**.

### THE ARMS THAT MATTER

  * **ARM 1 is CONSISTENCY, NOT EVIDENCE, and says so in its own output.**
    `mt_pmode` returns 27 for both bases, because both bases' `Pmode` is
    DImode.  Equal readings here cannot distinguish a fix from a leak.  It
    earns its place as a NON-VACUITY arm instead: it proves the redirect is
    INVOKED, which is the "complete mechanism that nothing calls" failure.
  * **ARM 2 carries the divergence, asymmetrically on purpose.**  It scores
    the existence of a `plus_constant` call whose mode argument disagrees with
    its rtx's mode.  That existed on the aarch64 side only.  The x86_64 arm
    additionally asserts the run produced asm, so "no hit" cannot be "never
    got there".
  * **ARM 4 is the injection**: removes ONLY the `defaults.h` redirect --
    thunk, field and selector stay compiled -- rebuilds, and requires the OLD
    ICE back **by name** (`in plus_constant, at explow.cc:102`) AND the mode
    mismatch back (0 -> 1).  Both fired.  Restore requires both to reverse and
    `int x = 1;` to be byte-identical again.  All four scored.

## 5. THREE INSTRUMENT DEFECTS THIS RUN PRODUCED, ALL FOUND BY THE GUARDS

**(a) The rtx mode is at BIT 0, not byte 2.**  My first reading used the
classic `code:16, mode:8` layout and read byte 2.  This tree has
`machine_mode mode : MACHINE_MODE_BITSIZE` **first**, with
`MACHINE_MODE_BITSIZE` **16** (machmode.h:281) -- widened by the mode union --
and `rtx_code` after it.  The wrong read produced `mode_arg=26 mode_of_x=42`
in a frame that was not even the failing one, and 42 is a perfectly plausible
mode number.  A garbage reading that looks like a reading.  What caught it was
matching the frame against the ICE's own backtrace, which did not agree.

**(b) A guard FAILED because of the INPUT FILE'S NAME.**  ARM 3b reported
aarch64 `int x = 1;` as moved: 375 bytes, md5 `361954469d74`.  Nothing had
moved.  The guard wrote its input to `$B/g-small.c` where `t125-state.sh`
uses `$B/small.c`, and the two extra characters land in the `.file` directive.
A byte-exact invariant is only exact if the INPUT is identical too, filename
included.

**(c) An injection that removed only half of a two-line hunk.**  The first
ARM 4 deleted the `#define` and left the `#undef`, which makes `Pmode` an
undefined identifier rather than i386's macro; the injected build died in
`gimple-match-*.o`.  A build that does not compile cannot tell you which back
end answers a question.  The arm now asserts BOTH lines are gone.

**(d) And one operator error worth writing down**: `make multi-target-objs`
reported `No rule to make target` for twenty minutes because I ran it through
`t125-build.sh`, which is the TOP level.  `cc1` and everything in
`multi-target-md.mk` live in `$B/gcc` -- `t125-gccbuild.sh`.  PRINCIPLES
section 5 names this exact trap; I still walked into it, and the tell was that
`make -f` with `include Makefile` from the same directory found all 104
objects.  `t125-mkq.sh` is that check, kept.

## 6. THE NEXT WALL -- DIAGNOSED, NOT MERELY LOCATED

`big.c` now gets **past the prologue expander** and dies later, and the new
failure does not look like a compiler bug at first:

    aarch64-...-gcc: fatal error: cc1 terminated by signal 9 (Killed)

A 150-line input, SIGKILL, no message.  Under a 4 GB `ulimit -v` it becomes
`virtual memory exhausted` from **`ggc-page.cc:735`**, and with a breakpoint
there the backtrace is

    update_row_reg_save        dwarf2cfi.cc:539
    dwarf2out_flush_queued_reg_saves
    scan_trace
    pass_dwarf2_frame::execute

`update_row_reg_save` does `vec_safe_grow_cleared (row->reg_save, column + 1)`.
**Measured `column` = 4294967294**, i.e. `(unsigned) -2`, so it tries to grow a
vector to four billion entries.

The cause is the branch's own bug, in its **bound-vs-index** disguise --
the sixth time.  `dwf_regno` is `DWARF_FRAME_REGNUM (REGNO (reg))`, which is
`DEBUGGER_REGNO`, which for i386 (i386.h:2154) is

    (TARGET_64BIT ? debugger64_register_map[(N)] : debugger_register_map[(N)])

with those arrays declared `[FIRST_PSEUDO_REGISTER]` -- and
`FIRST_PSEUDO_REGISTER` in shared code is now the **UNION** width.  So shared
code indexes an array sized by i386's own register count with aarch64's
register numbers, and gets i386's "no DWARF number" sentinel back.  aarch64's
own answer is `aarch64_debugger_regno` (aarch64.h:835), a function.

Note `TARGET_64BIT` in that expression is **also** i386 option state, so it is
the same silent-default shape as `Pmode`: while compiling for aarch64 it is
false, selecting the **32-bit** map.  Two leaks in one macro.

`DEBUGGER_REGNO` is `UNCONVERTED` in `macro-status.txt` (line 124) and is the
natural next task.  It is register-vocabulary shaped, i.e. #92/#122/#124
territory, and the `*_POINTER_REGNUM` design fork in section 8 sits next to it.

## 7. THE SCOREBOARD -- NOT RUN, NOT MOVED, AND DELIBERATELY NOT BANKED

**I did not run `macro-probe-run.sh` and I am claiming no scoreboard
movement.**  Carrying the recorded line unchanged: header **i386 112 PASS / 0
FAIL, aarch64 8 PASS / 104 FAIL of which only 2 are TRUSTED**; TAB **i386
32/0, aarch64 27/5**.

`Pmode` stays **`UNCONVERTED`**, bringing the "converted but reads
UNCONVERTED" list to **thirteen**.  Its header arm has never been able to see
this leak (section 1) and must be retired rather than banked.

## 8. WHAT I DID NOT DO

  * **No TAB arm for `Pmode`**, for the reason in section 7 -- the same debt
    the other twelve carry.
  * **`CASE_VECTOR_MODE` and `STACK_SIZE_MODE` are NOT converted.**  They are
    the other two members of MACRO-LEAK class (c4) and aarch64's
    `CASE_VECTOR_MODE` is literally `Pmode` (aarch64.h:1366), so in a base TU
    it is now correct for free and in shared code it is still i386's.  They
    did not stop `big.c` and I did not widen the change to reach them.
  * **The `*_POINTER_REGNUM` design fork is untouched**, exactly as #124 left
    it.  It is adjacent to the `DEBUGGER_REGNO` work above and will have to be
    faced there.
  * **No `nm` arm on `Pmode`**, because there is nothing for it to see
    (section 2).  Recorded as a measured "cannot be checked, because X".
  * **`Pmode` is now a CALL at 648 shared sites**, some of them hot.  I did not
    measure compile-time cost, and I am not claiming it is free.  The x86_64
    output is byte-identical, so it is a throughput question and not a
    correctness one; it wants a measurement before anyone calls this settled.
  * `make all-target-libgcc` not re-run; #119's environmental `-m32` blocker
    is unchanged.

### STDERR -- WHICH ARM

  * Cold `all-gcc`, before any edit: **639 lines / 114 `warning:`**.
  * Incremental `multi-target-objs cc1 lto1` after the edit: **322 lines / 56
    `warning:`** (defaults.h reaches ~520 TUs).
  * A second, near-no-op incremental: **38 lines / 3 `warning:`**, composed of
    4 `is unchanged`, 24 `'@' is redundant` from unmodified aarch64 `.md`
    files, and one 3-warning `lto-common.cc` block.  Same shape as the
    documented ~32-line floor.

## 9. FILES

    t125-clone.sh     derives my build-dir scripts from #124's, and REFUSES if
                      the substitution left a `b124' behind
    t125-conf.sh      two-target configure, /tmp/b125
    t125-build.sh     make at the TOP level
    t125-gccbuild.sh  make in $B/gcc -- where cc1 actually builds
    t125-specs.sh     both target-specs probes, real aarch64 binutils
    t125-cause.sh     THE DIAGNOSIS: gdb on the running cc1, one breakpoint per
                      run, with the x86_64 positive control that stops "no
                      mismatch" from meaning "the breakpoint never fired"
    t125-hang.sh      the SIGKILL, resolved to ggc-page.cc:735 and to the
                      4294967294 column (section 6)
    t125-mkq.sh       asks make what it read, instead of reading the Makefile
    t125-state.sh     big.c site + `int x = 1;` + x86_64 -O2
    t125-sc.sh        stock-compare with an ABSOLUTE big.c and a tagged outdir
    t125-guards.sh    14 arms; ARM 1 non-vacuity, ARM 2 the divergence,
                      ARM 4 the injection

# TASK #126 -- `DEBUGGER_REGNO'.  THE NINTH WALL, AND HALF THE BRIEF'S
# DIAGNOSIS MEASURED FALSE

Worktree came up at bare-repo HEAD `7208eca60d0` AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in` was **0** -- `git reset --hard multi-target` took
it to **37**.  That is now five worktrees in a row.  Build dir `/tmp/b126`, my
own, cold.

## 0. THE BRIEF ARRIVED PRE-DIAGNOSED.  ONE HALF HELD, ONE HALF DID NOT.

The brief said `DEBUGGER_REGNO' carries TWO leaks and that they must be taken
together.  Verified in the running `cc1` rather than inherited
(`scratchpad/t126-cause.sh`, ONE BREAKPOINT PER RUN, and the breakpoint gdb
ITSELF reports printed and matched against the function under test).

**HALF (1), BOUND-VS-INDEX -- CONFIRMED, and it is the whole cause.**

    Breakpoint 1, update_row_reg_save (row=..., column=column@entry=4294967294,
                  cfi=...) at gcc/dwarf2cfi.cc:540
    MT126 column=4294967294

4294967294 is `IGNORED_DWARF_REGNUM` (rtl.h:4172, `INVALID_REGNUM - 1`), which
is what BOTH i386 maps hold at indices 16..19 -- i386's arg, flags, fpsr and
frame pseudo-registers.  aarch64's x16..x19 are ordinary registers a prologue
saves, so `dwf_regno` returned `-2` and `vec_safe_grow_cleared` was asked for
four billion entries.  The x86_64 arm of the same instrument finds no column
over 1000 **in a run that reaches exit**, so "no hit" is not "never got there".

**HALF (2), THE OPTION-STATE SILENT DEFAULT -- MEASURED FALSE.  SAYING SO.**

The brief predicted the `Pmode` shape again: that `TARGET_64BIT` is i386 option
state and so, unpromoted, selects the **32-bit** map.  At the same breakpoint:

    MT126 isa_flags=18
    MT126 TARGET_64BIT=1

18 is `OPTION_MASK_ISA_64BIT | OPTION_MASK_ABI_64`, i.e. exactly
`TARGET_64BIT_DEFAULT` from `config/i386/biarch64.h:28`, which is the `Init` of
`ix86_isa_flags` at i386.opt:26.  So unlike `ix86_pmode` -- `Init (PMODE_SI)`,
promoted only by `ix86_option_override` -- this option's **unconfigured default
is already the 64-bit one**, and `debugger64_register_map` is the map being
read.  The macro is still option-dependent (which is why the new field is a
CALL and not a `target-cdata` constant, and why a `-m32` would move it), but
the silent-default variant is **not** present here.  **One leak in this macro,
not two.**  Recorded rather than quietly dropped: PRINCIPLES says a brief's
number that cannot be reconciled must be reported, not reported against.

Also worth naming, because the two differ and only one runs: the effective
i386 definition for an ELF/linux host is **`gnu-user.h:30`**, not `i386.h:2154`.

## 1. WHAT LANDED

Same mechanism as #108's six, #123's four, #124's two and #125's one -- no new
registry, no back end edited, no `target.def` entry.  Four files, +258 lines,
mostly comment:

  * **`target-frame.h`** -- three fields on `target_frame_desc`
    (`debugger_regno`, `dwarf_frame_regnum`, `dwarf_frame_registers`) and three
    `extern` selectors.
  * **`target-cumargs.cc`** -- `mt_base_debugger_regno`,
    `mt_base_dwarf_frame_regnum`, `mt_base_dwarf_frame_registers`, evaluating
    the macros in THIS base's TU.
  * **`target-cumargs-select.cc`** -- the three `mt_*` selectors, uncached.
  * **`defaults.h`** -- three `#undef`/`#define` pairs in the shared block.

**ALL THREE MOVE TOGETHER, AND THAT IS THE POINT.**
`DWARF_FRAME_REGISTERS` (17 for i386, 97 for aarch64) is the BOUND that
`dwarf2cfi.cc:302` tests the numbering against.  Converting the numbering alone
would have left aarch64's correct 0..96 measured against i386's 17 and silently
dropped every register above 16 -- **a quieter version of the bug, produced by
the fix**.  It also feeds `__LIBGCC_DWARF_FRAME_REGISTERS__`
(c-cppbuiltin.cc:1630), so i386's 17 was being compiled into every target's
unwinder.  `DWARF_FRAME_REGNUM` is separate rather than derived because
defaults.h:560's `#ifndef` is answered by the PRIMARY, and cygming.h:89 defines
it DIFFERENTLY from its `DEBUGGER_REGNO` while aarch64.h:840 defines them the
same.

**THE BOUND CHECK, AND WHAT FILLS THE NEW SLOTS.**  The per-base thunk tests
`regno >= FIRST_PSEUDO_REGISTER` -- a name that means the BASE's own count in
that TU (92 for i386) while shared code spells it at the union width (95).
`expand_builtin_init_dwarf_reg_sizes` (dwarf2cfi.cc:334) really does walk
`0 .. FIRST_PSEUDO_REGISTER`, so with i386 selected it asks about 92, 93, 94.
Out of range answers **`INVALID_REGNUM`**, the vocabulary's own "no DWARF
register" sentinel, which `dwarf2cfi.cc:302` already filters.  **Zero would
have been the attractive wrong answer for the third time on this branch** --
DWARF register 0 is `%rax` on one base and `x0` on the other, so a zero fill
would silently attribute every nonexistent register's unwind info to the first
real one.  The check is in the THUNK and deliberately not in the selector,
where `FIRST_PSEUDO_REGISTER` is the union width and would pass on exactly the
inputs the real test must reject.

**SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE REDIRECTING.**  Over all of
`gcc/` outside `config/`, `testsuite/` and `ada/gcc-interface/`: 5 + 4 + 2
shared use sites, every one an ordinary run-time expression.  No `#if`, no case
label, no array bound, no static initialiser.  The one `#ifdef` is
`except.cc:2193` (`#ifdef DWARF_FRAME_REGNUM`); both names stay DEFINED so it
takes the same branch as today, and after the redirect **both of its arms call
the selected back end**, so unlike `DATA_ALIGNMENT` there is no guard answered
by one base and body by another.

## 2. THE DESIGN FORK NEXT DOOR -- DECIDED EXPLICITLY, NOT DRIFTED INTO

**`*_POINTER_REGNUM` MUST MOVE AS A SET, AND THREE OF THE FOUR CANNOT MOVE WITH
THE LANDED MECHANISM.  I DID NOT TOUCH THEM, AND HERE IS THE WRITE-UP THE BRIEF
ASKED FOR RATHER THAN A GUESS.**

The connection to this task is real and specific.  `dwarf2cfi.cc:3250/3309` do

    dw_stack_pointer_regnum = dwf_cfa_reg (stack_pointer_rtx);
    dw_frame_pointer_regnum = dwf_cfa_reg (hard_frame_pointer_rtx);

and those two rtxes are built in `emit-rtl.cc:6266-6268` -- SHARED code -- as
`gen_raw_REG (Pmode, STACK_POINTER_REGNUM)` etc.  `Pmode` is now per base
(#125); the **regnum is not**, so they carry i386's 7 and 6 for every target.
After this change aarch64's `aarch64_debugger_regno (7)` answers **7**, a
perfectly valid GP register, where aarch64's SP is DWARF 31.  Today that is
unreachable (aarch64 dies earlier); it becomes a **quiet** wrong answer the
moment aarch64 reaches the dwarf2 frame pass.

**WHY IT IS A FORK AND NOT A ONE-LINER.**  Of the four:

    STACK_POINTER_REGNUM        i386 7   aarch64 31   -- NOT on any `#if' line
    HARD_FRAME_POINTER_REGNUM   i386 6   aarch64 29   -- class (d), rtl.h:3939/3945
    FRAME_POINTER_REGNUM        i386 19  aarch64 64   -- class (d), rtl.h:3936/3944
    ARG_POINTER_REGNUM          i386 16  aarch64 65   -- class (d), rtl.h:3936/3944

Only `STACK_POINTER_REGNUM` is free of `#if` arithmetic.  The other three
decide the layout of `enum global_rtl_index` (`GR_ARG_POINTER` aliasing
`GR_FRAME_POINTER`, `GR_HARD_FRAME_POINTER` aliasing either), which a run-time
value cannot do.  **Converting the one that is easy and leaving the three that
are hard is precisely the "one member of a closure" failure PRINCIPLES records
as having nearly happened three times** -- it would leave
`hard_frame_pointer_rtx` still i386's 6 while `stack_pointer_rtx` became
correct, i.e. a half-right CFA.

So: **the set must move together, the enum-layout question has to be answered
first, and that is a design decision this task had no mandate to make.**
Stopped, written up, not guessed.  The residual wrong comparisons against the
primary's `STACK_POINTER_REGNUM` in `ira.cc`, `reload1.cc`,
`lra-eliminations.cc` and `builtins.cc` (#124 section 6) are unchanged and are
part of the same fork.

Also unchanged and recorded: `DWARF2_FRAME_REG_OUT` and
`DWARF_REG_TO_UNWIND_COLUMN` are `#ifndef`-defaulted to the identity in
defaults.h, and that `#ifndef` is answered by the PRIMARY.  Neither of the two
configured bases overrides them, so **no arm here could distinguish a fix from
a leak** -- one-sided and unfalsifiable on this machine, the same situation as
`RELOAD_ELIMINABLE_REGS` (#124) and `HONOR_REG_ALLOC_ORDER` (#122).  It is a
real latent leak for cygming, which does override them.

## 3. THE BARS

  * `make multi-target-objs cc1 lto1` in `$B/gcc` -- **rc=0**, first try.
  * **x86_64 `-O2` big.c md5 `378fc33c1e70`, 12369 bytes -- unmoved**, measured
    BEFORE and AFTER **in this same build dir**.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock`, absolute `IN`, **5
    distinct md5 per side**, **negative control firing** (1158 vs 804), rc=0,
    run before and after.  O0 `1c00922491f8`, O1 `4fabab94b41b`,
    O2 `378fc33c1e70`, O3 `d220421237bc`, Os `d6787f7e281f`.  **It does run in
    this build dir** -- checked explicitly.
  * **`scratchpad/t126-guards.sh`: 43 PASS / 0 FAIL.**
  * **aarch64 `int x = 1;` still rc=0, 373 bytes, empty stderr, md5
    `b01d9157fdc1`** -- byte-identical before, after, and after the injection
    round trip.
  * Cold `all-gcc` before any edit: **rc=0, 639 lines / 114 `warning:`**.

### THE ARMS THAT MATTER

  * **ARM 0 runs FIRST and asserts the redirect BY NAME AND BY VALUE**, both
    the `#define` (matched verbatim, `grep -F`) and its `#undef`, for all three
    macros -- plus that each thunk is not merely compiled but **installed in
    `mt_base_frame`**, which is the "complete mechanism nothing invokes"
    failure.
  * **ARM 2 carries the divergence**, gdb on the running `cc1`, one breakpoint
    per run, the breakpoint gdb reports matched before any value is scored.
    Breakpoint is `mt_pmode` and not anything in `dwarf2cfi.cc` **on purpose**:
    aarch64 no longer reaches the dwarf2 frame pass, so a breakpoint there
    would never fire and "no reading" would read as "no divergence".

        aarch64  registers=97  regno(16)=16          frame_regnum(30)=30  regno(94)=97
        x86_64   registers=17  regno(16)=4294967294  frame_regnum(30)=43  regno(94)=4294967295

    Eight readings, all four pairs diverging, so it cannot be "everyone got the
    same new answer".  `regno(94)` is the union-width probe: past i386's 92 it
    answers `INVALID_REGNUM` instead of reading off the end of the array; for
    aarch64 94 is in range and answers 97, aarch64's own "no equivalent".
  * **ARM 4 is the injection**: removes ONLY the three `defaults.h` hunks --
    thunks, fields and selectors stay compiled -- and requires **the old
    failure back BY NAME** (`cc1 terminated by signal 9`) **and the column back
    BY VALUE** (4294967294).  Both fired.  It also asserts the injection
    produced the state intended: **both** lines of each hunk gone, because
    #125's first injection deleted a `#define` and left its `#undef`, making
    the macro undefined rather than the primary's.  Restore requires both to
    reverse and both byte-invariants to hold.

## 4. TWO INSTRUMENT DEFECTS THIS RUN PRODUCED, BOTH CAUGHT BY THE GUARDS

**(a) A guard that could not tell code from prose.**  ARM 1's check "the
selector must not test `FIRST_PSEUDO_REGISTER`" was a bare `grep` and matched
**the comment explaining why the test is not there**.  It reported FAIL on
correct code.  Now it matches an actual `if (... FIRST_PSEUDO_REGISTER`.

**(b) `-g0` made an arm fail for a reason unrelated to the code.**  `cc1` here
is built `-O1 -g0`, so `break f if local > N` errors with *"No symbol table is
loaded"*, and the first ARM 4 scored that as "the column did not return".  Two
fixes, both kept: `scratchpad/t126-dbg.sh` rebuilds **only** `dwarf2cfi.o` and
`target-cumargs-select.o` with `-g` and relinks (changing no source), and the
ARM 4 reading was moved back to `$esi` so it needs no debug info at all.  ARM 2
re-runs `t126-dbg.sh` itself, because ARM 4's rebuild strips the debug info
again and a second run of the script would otherwise find ARM 2 vacuous for a
reason belonging to the previous run.

Also worth recording as a near-miss: **ARM 4 of `t126-cause.sh` printed
"ok: no absurd column on x86_64" while gdb had never started** (same `-g0`
error).  The separate NON-VACUITY check -- "did the run reach exit?" -- is what
caught it.  Without it that was a clean false green.

## 5. THE SCOREBOARD -- NOT RUN, NOT MOVED, AND DELIBERATELY NOT BANKED

**I did not run `macro-probe-run.sh` and I am claiming no scoreboard
movement.**  Carrying the recorded line unchanged: header **i386 112 PASS / 0
FAIL, aarch64 8 PASS / 104 FAIL of which only 2 are TRUSTED**; TAB **i386
32/0, aarch64 27/5**.

All three macros stay **`UNCONVERTED`**, bringing the "converted but reads
UNCONVERTED" list to **sixteen**; `macro-status.txt`'s header names all
sixteen.  `DEBUGGER_REGNO` and `DWARF_FRAME_REGNUM` are function-like, so their
header arms were never value comparisons and there is no flip to predict.
`DWARF_FRAME_REGISTERS` **is** a plain constant (17 vs 97) and is expected to
flip green for the familiar base-B redirect reason -- retire it, do not bank it.

## 6. WHAT I DID NOT DO

  * **No TAB arms for the three** -- all are calls, and `tab-probe.sh` reads
    constants.  Same debt the other thirteen carry.
  * **The `*_POINTER_REGNUM` fork is untouched and written up** (section 2).
  * **`DWARF2_FRAME_REG_OUT` / `DWARF_REG_TO_UNWIND_COLUMN` untouched**, with
    the reason measured rather than assumed (section 2).
  * **No `nm` arm.**  `DEBUGGER_REGNO`'s i386 body names `debugger64_register_map`
    and `svr4_debugger_register_map`, which ARE data symbols, so unlike `Pmode`
    an `nm` arm is not impossible here -- but the maps are `const` and were
    already linked into shared objects before this change for other reasons, so
    a disappearance would not be attributable.  Recorded as "not measured",
    not as "clean".
  * **`Pmode`'s 648-site call cost is still unmeasured** (#125 section 8) and
    this change adds ~11 more call sites; still a throughput question, not a
    correctness one.
  * `make all-target-libgcc` not re-run; #119's environmental `-m32` blocker is
    unchanged.

## 7. THE NEXT WALL -- LOCATED, NOT DIAGNOSED

`big.c` for aarch64 is past the SIGKILL and now dies as

    internal compiler error: in extract_insn, at recog.cc:2890

i.e. **unrecognizable insn**.  It reproduces on inputs far smaller than
`big.c`: `int g(int a){ return f(a)+f(a+1); }` fails in `during RTL pass: vregs`
on the `call_insn`, and even `int g(int a){ return a+1; }` fails as
`in aarch64_can_eliminate, at config/aarch64/aarch64.cc:14153` during
`postreload`.  **No function body compiles for aarch64 yet** -- only file-scope
data does, which is why `int x = 1;` is the byte-invariant.  I located these
and did **not** diagnose them; the `aarch64_can_eliminate` one sits directly on
the `*_POINTER_REGNUM` fork in section 2 and is the obvious place to look.

## 8. FILES

    t126-clone.sh    derives my build-dir scripts from #125's; REFUSES on a
                     leftover `b125'
    t126-conf.sh     two-target configure, /tmp/b126
    t126-build.sh    make at the TOP level
    t126-gccbuild.sh make in $B/gcc -- where cc1 actually builds
    t126-specs.sh    both target-specs probes, real aarch64 binutils
    t126-dbg.sh      rebuilds TWO objects with `-g' and relinks, so the
                     diagnosis can be read by NAME instead of off %esi
    t126-cause.sh    THE VERIFICATION: confirms half (1) of the brief and
                     measures half (2) FALSE, with an x86_64 non-vacuity arm
    t126-state.sh    big.c site + `int x = 1;` + x86_64 -O2
    t126-sc.sh       stock-compare, ABSOLUTE big.c, tagged outdir (/tmp/sc126-*)
    t126-guards.sh   43 arms; ARM 0 content-by-name-and-value and runs first,
                     ARM 2 the divergence on the running cc1, ARM 4 the
                     injection

# TASK #128 -- THE CONSTRAINT VOCABULARY WAS THE PRIMARY'S.  `k' MEANT
# aarch64's STACK REGISTER AND i386's MASK REGISTERS

Worktree came up at bare-repo HEAD `7208eca60d0` AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in` was **0** -- `git reset --hard multi-target` took
it to **37**.  That is now seven worktrees in a row.  Build dir `/tmp/b128`,
my own, cold.

**#127 left no STATE.md section**; its findings are in commit `545bd5fff28`'s
message.  This section does not restate them.

## 0. THE WALL, DIAGNOSED IN THE RUNNING cc1 AND NOT INHERITED

`int g (int a) { return a + 1; }` for aarch64 dies as

    error: insn does not satisfy its constraints:
    (insn/f 18 4 27 (set (reg/f:DI 31 sp)
            (plus:DI (reg/f:DI 31 sp) (const_int -16))) 157 {*adddi3_aarch64})
    internal compiler error: in final_scan_insn_1, at final.cc:2789

`final.cc:2789` is `fatal_insn_not_found` after `constrain_operands_cached`.
`constrain_operands` is in `recog.cc` -- SHARED -- and the constraint
vocabulary it uses reaches it from the build root's `tm_p.h`, which includes
the build root's `tm-preds.h`, which `build/genpreds` writes **from
`config/i386/i386.md`** (the file says so in its first two lines).

Measured with ONE BREAKPOINT PER RUN (`scratchpad/t128-cause.sh`,
`_fatal_insn_not_found`, gdb's own reported breakpoint printed and matched, an
x86_64 non-vacuity arm reaching exit):

    recog_data.constraints[0] = "=rk,rk,w,rk,r,r,rk,rk"     <- aarch64's
    GLOBAL       lookup_constraint ("k") = 18
    insn_i386    lookup_constraint ("k") = 18
    insn_aarch64 lookup_constraint ("k") =  2
    GLOBAL       reg_class_for_constraint (k) = 0   = NO_REGS
    insn_i386    reg_class_for_constraint (k) = 0   = NO_REGS
    insn_aarch64 reg_class_for_constraint (k) = 6   = STACK_REG

aarch64's `k` is `STACK_REG` (aarch64/constraints.md:21).  i386's is
`TARGET_AVX512F ? ALL_MASK_REGS : NO_REGS` (i386/constraints.md:84), and
`TARGET_AVX512F` is i386 option state no `ix86_option_override` has promoted
-- the `Pmode` silent-default shape a third time -- so it answers NO_REGS.
aarch64's real stack pointer was rejected by aarch64's own add pattern.

Both directions diverge (18 vs 2, 0 vs 6), so this cannot be "everyone got the
same new answer".

**THE MECHANISM WAS ALREADY THERE AND NOTHING INVOKED IT.**  `genpreds` has
long written `tm-preds-<base>.h` and `insn-preds-<base>.cc` in
`namespace insn_<base>`, and both objects are linked.  `nm` on the build dir
(`scratchpad/t128-syms.sh`, with a non-vacuity floor on nm's own output):

    insn-preds.o          T lookup_constraint_1        <- un-namespaced, i386's
    insn-preds-i386.o     T insn_i386::lookup_constraint_1
    insn-preds-aarch64.o  T insn_aarch64::lookup_constraint_1
    recog.o               U lookup_constraint_1        <- bound to the first

Same shape as `gen_blockage` and `insn-emit-5.o` (#51) one layer up.

## 1. THE BRIEF'S HYPOTHESIS -- TESTED, AND THE ANSWER IS NO

The brief asked whether this needs something **the generators cannot express**,
and said to stop rather than invent a channel if so.  Measured answer: **it
does not.**  `genpreds.cc` gains **six lines** and no new input.  Each
generator run still emits ONE back end's constants, exactly as today; what
changes is that shared code stops reading the primary's copy.
`build/genpreds.o` already carries `-DGEN_MULTI_TARGET` (Makefile.in:4573), so
the singular run can already tell it is on a multi-target build -- a previous
task had to teach it that for `test_register_filters`, which is the OTHER half
of this same closure and is already fixed.

## 2. WHAT LANDED

Two new files, five edited, and no back end touched:

  * **`target-preds.h`** (new) -- `struct target_preds_desc`, and the `mt_*`
    shared spellings.
  * **`multi-target-preds.h`** (new) -- 18 `#undef`/`#define` pairs.
  * **`genpreds.cc`** -- emits `#include "multi-target-preds.h"` as the LAST
    line of the shared `tm-preds.h`, and `#define
    MULTI_TARGET_PREDS_NO_REDIRECT 1` at the top of the shared
    `insn-preds.cc`.  Both guarded by
    `gen_multi_target_p () && gen_target_ns () == NULL`.
  * **`target-cumargs.cc`** -- 17 one-line thunks + `mt_base_preds`.
  * **`target-cumargs.h`** -- the `preds` field.
  * **`target-cumargs-select.cc`** -- the 18 forwarders.
  * **`multi-target-select.cc`** -- `targetm_preds = targetm_cumargs->preds;`
    with the stale-object check the other three carry.

**WHY A MACRO RENAME AND NOT A `defaults.h` PAIR, which is what every other
task on this branch used.**  These are `static inline` FUNCTIONS in a
generated header, not macros, and `defaults.h` is reached from `tm.h` --
BEFORE `tm_p.h`.  A macro defined there rewrites `tm-preds.h`'s own
DEFINITIONS, not just its uses.  So the include goes at the END of the
generated header, after the definitions are parsed, and renames only the uses.
The primary's inline bodies survive unreferenced; being `static inline` they
emit no code.

**THE `int` BOUNDARY IS DELIBERATE.**  `enum constraint_num` is a distinct
type per namespace and its VALUES are per base -- 18 and 2 above are the same
letter.  The table traffics in `int` so the two vocabularies cannot look
interchangeable to the type system.

**SWEPT BEFORE LANDING.**  Over all of `gcc/` outside `config/`,
`testsuite/`, `analyzer/` and `rust/`, shared code spells exactly three
constraint names: `CONSTRAINT_LEN` (19 sites, a macro over
`insn_constraint_len`, so renaming the function covers it),
`CONSTRAINT__UNKNOWN` (0 in every back end -- deliberately NOT redirected, and
a guard arm asserts it is not), and `CONSTRAINT_X`
(`lra-constraints.cc:4055`), which becomes a call.  Measured: **aarch64 137,
i386 87.**

**THE OPT-OUT IS NOT OPTIONAL.**  The un-namespaced `insn-preds.cc` DEFINES
`insn_const_int_ok_for_constraint` and `eval_dependent_filter` -- the only two
members of the API that are extern rather than inline -- so without
`MULTI_TARGET_PREDS_NO_REDIRECT` it would define `mt_*` instead and collide
with the forwarders.  Emitted by the same generator, next to the include, so
the two cannot drift.

**ONE LAYOUT, NOT A GUARDED ONE.**  `target-preds.h` `#include`s
`hard-reg-set.h` rather than wrapping its two `HARD_REG_SET` members in
`#if defined GCC_HARD_REG_SET_H` the way `tm-preds.h` does.  A conditional
member makes `struct target_preds_desc` a different SIZE in a TU that has not
reached that header -- which is exactly the `struct target_constraints`
layout-disagreement bug already paid for on this branch.

## 3. THE BARS

  * `make multi-target-objs cc1 lto1` in `$B/gcc` -- **rc=0**, first try.
  * **x86_64 `-O2` big.c md5 `378fc33c1e70`, 12369 bytes -- unmoved**, and the
    three `t128-fn.sh` x86_64 outputs byte-identical before and after
    (`f776a3b16e36`, `b9716cd03194`, `e2879feb51f6`), all in this same build
    dir.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock`, absolute `IN`, 5
    distinct md5 per side, negative control firing (1158 vs 804), rc=0, run
    after the edit and again after the injection round trip.  O0
    `1c00922491f8`, O1 `4fabab94b41b`, O2 `378fc33c1e70`, O3 `d220421237bc`,
    Os `d6787f7e281f`.
  * **aarch64 `int x = 1;` rc=0, 373 bytes, empty stderr, md5 `b01d9157fdc1`**
    -- byte-identical.
  * **`scratchpad/t128-guards.sh`: 62 PASS / 0 FAIL.**
  * Cold `all-gcc` before any edit: **rc=0, 776 lines / 169 `warning:`**.
    Incremental after the edit: 352 lines / 87 `warning:`.  Near-no-op
    incremental: **8 lines / 0 `warning:`**, all `is unchanged` -- the low end
    of the documented 8-to-32 floor.

### THE ARMS THAT MATTER, AND TWO THEY CAUGHT

  * **ARM 0 runs first and asserts the GENERATED content by name**: the shared
    `tm-preds.h` HAS the include, both `tm-preds-<base>.h` do NOT, the shared
    `insn-preds.cc` HAS the opt-out, both per-base ones do NOT.
  * **ARM 3 is the arm on the SELECTION, separate from ARM 4's arm on the
    DATA** -- the `targetm_asm_ops` lesson.  `recog.o`, `lra-constraints.o`,
    `ira.o` and `stmt.o` each bind an `mt_*` forwarder AND no longer bind
    `lookup_constraint_1` / `reg_class_for_constraint_1`.
  * **ARM 4 is the divergence in the running cc1**, both sides, by value:
    aarch64 `2 6 137`, x86_64 `18 0 87`.

  **(a) THE INJECTION REMOVED HALF A HUNK AND THE BUILD DIED SOMEWHERE ELSE.**
  Deleting only the `puts` left its `if` attached to the NEXT statement -- the
  one emitting `#endif /* tm-preds.h */` -- so every PER-BASE header came out
  unterminated and the injected build failed in `tm-preds-i386.h`.  cc1 was
  therefore never relinked and the arm read the OLD, FIXED binary.  The arm
  now removes both lines, asserts the `gen_target_ns () == NULL` count went
  2 -> 1, and **asserts the injected build's rc is 0** before believing
  anything it reads.  Third recorded instance of a half-removed hunk here.

  **(b) THE INJECTION'S FIRST OBSERVABLE COULD NOT MOVE.**  It re-read
  `mt_lookup_constraint` through gdb -- but that forwarder is still compiled
  and still correct in the injected compiler; the injection removes the
  RENAMING of shared code's call sites, not the table.  The arm was asking a
  question whose answer the injection cannot change, which is a false green
  waiting to happen.  It now asserts on `nm -uC recog.o`: injected, it binds
  the primary's `lookup_constraint_1` again and no `mt_*` at all.

## 4. WHAT THIS DID **NOT** FIX, MEASURED RATHER THAN ASSUMED

**`int g (int a) { return a + 1; }` STILL FAILS, at the same line.**  Saying so
plainly: the constraint vocabulary is now aarch64's and the insn is still
rejected.  Second breakpoint run (`scratchpad/t128-cause2.sh`, same
`_fatal_insn_not_found`, x86_64 non-vacuity arm reaching exit):

    reg_class_contents[6] (STACK_REG)    = {0x80000000, 0x0}   <- reg 31 present
    reg_class_contents[5] (GENERAL_REGS) = {0x7fffffff, 0x3}   <- regs 0-30,32,33
    reg_class_size[6] = 1   reg_class_size[5] = 33
    operand[0] regno = 31   operand[1] regno = 31
    bool_attr_masks[157][BA_ENABLED] = 0xfffffffffffffff7

The register data is correct aarch64.  **Bit 3 of the enabled mask is clear:
alternative 3 is DISABLED** -- and alternative 3 is the one this insn needs
(`op2`'s constraint list is `I,r,w,J,Uaa,Uai,Uav,UaV`; `J` is the
negative-immediate alternative, and the addend is `-16`).

`recog.cc:2717 get_enabled_alternatives` -> `get_bool_attr_mask` ->
`get_attr_enabled`, and `nm` says the only definition of `get_attr_enabled` in
the link is in **`insn-attrtab.o`**, whose generated source carries
`#line` directives naming `config/i386/i386.md`.  `insn-attrtab-aarch64.o`
exists, is built, is linked, and nothing selects it.

**So the next wall is LOCATED AND DIAGNOSED: the insn ATTRIBUTE tables are the
primary's, exactly as the predicates were.**  It is the same bug one layer
along, and `Makefile.in:1757` names the whole family still in `OBJS`
un-namespaced -- `insn-attrtab.o`, `insn-automata.o`, `insn-dfatab.o`,
`$(INSNEMIT_SEQ_O)`, `insn-latencytab.o`, `insn-opinit.o`, `insn-preds.o`.
`insn-preds.o` is the one this task went around rather than removed.

That leak is bigger than this one: `get_attr_length`, `get_attr_enabled`,
`insn_current_length` and the DFA scheduler entry points are all in it, and
`HAVE_ATTR_*` are `#if`-shaped in `insn-attr.h`.  It wants its own task and a
decision about whether `insn-attrtab.o` leaves `OBJS`.

## 5. THE SCOREBOARD -- NOT RUN, NOT MOVED, AND DELIBERATELY NOT BANKED

**I did not run `macro-probe-run.sh` and I am claiming no scoreboard
movement.**  Carrying the recorded line unchanged: header **i386 112 PASS / 0
FAIL, aarch64 8 PASS / 104 FAIL of which only 2 are TRUSTED**; TAB **i386
32/0, aarch64 27/5**.

Nothing here is in `macro-status.txt` at all: the constraint API is generated
functions, not `tm.h` macros, so it has never had a probe arm and there is no
flip to predict or retire.  The "converted but reads UNCONVERTED" list is
unchanged.

## 6. WHAT I DID NOT DO

  * **No probe or TAB arm**, for the reason in section 5; recorded as
    "no instrument exists", not as "clean".
  * **`insn-attrtab.o` and the rest of the un-namespaced generated family are
    untouched**, and are now the diagnosed next wall (section 4).
  * **`insn-preds.o` is still in `OBJS`.**  Going around it (the opt-out) was
    chosen over removing it, because `insn-attrtab.o` and `insn-emit*.o` --
    also the primary's, also still linked -- may reference its predicates, and
    dropping it would have coupled this change to the attribute-table task.
    A deliberate deferral with a named reason, not an oversight.
  * **The `fn-call` input still dies at `extract_insn, recog.cc:2890`** and I
    did NOT diagnose it.  #127 warned it may be a second, distinct problem;
    that is still unresolved.
  * **No compile-time measurement.**  Every constraint question in shared code
    is now an indirect call; `CONSTRAINT_LEN` in particular is in hot loops in
    `recog.cc`, `lra-constraints.cc` and `ira.cc`.  x86_64 output is
    byte-identical, so this is a throughput question and not a correctness
    one, but it is unmeasured and I am not claiming it is free.  It joins
    `Pmode`'s 648 sites (#125) as an open cost question.
  * `make all-target-libgcc` not re-run; #119's `-m32` blocker unchanged.

## 7. FILES

    t128-clone.sh    derives my build-dir scripts from #127's; REFUSES on a
                     leftover `b127'
    t128-conf.sh     two-target configure, /tmp/b128
    t128-build.sh    make at the TOP level
    t128-gccbuild.sh make in $B/gcc -- where cc1 actually builds
    t128-specs.sh    both target-specs probes, real aarch64 binutils
    t128-dbg.sh      rebuilds recog.o with `-g' and relinks
    t128-syms.sh     WHICH constraint vocabulary shared code links, by nm,
                     with a non-vacuity floor on nm's own output
    t128-cause.sh    THE DIAGNOSIS: one breakpoint per run, three vocabularies
                     compared in one frame, x86_64 non-vacuity control
    t128-cause2.sh   THE SECOND READING: reg_class_contents and the enabled-
                     alternative mask, which is what found the NEXT wall
    t128-state.sh    big.c site + `int x = 1;' + x86_64 -O2
    t128-fn.sh       the three function-body inputs, both bases
    t128-sc.sh       stock-compare, ABSOLUTE big.c, tagged outdir
    t128-guards.sh   62 arms; ARM 0 generated-content-by-name and runs first,
                     ARM 3 the selection, ARM 4 the data, ARM 5 the injection

# TASK #129 -- THE GENERATED-FAMILY SWEEP.  THREE OF SEVEN FAMILIES ARE
# UNSELECTED, AND THE BOUND-VS-INDEX CHECK FOUND `NUM_INSN_CODES' 15429 vs
# 20512

Worktree came up at bare-repo HEAD `7208eca60d0` AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in` was **0**, `git reset --hard multi-target` took
it to **37**, and there was no `scratchpad/` in the worktree at all.  That is
now EIGHT worktrees in a row.  Build dir `/tmp/b129`, my own, cold.

**The brief named no task numbers I could read and did not need to; everything
below is measured in `/tmp/b129`.**

## 0. JOB 1 -- THE WALL, VERIFIED IN MY OWN RUNNING cc1, NOT INHERITED

`int g (int a) { return a + 1; }` for aarch64 **produces no assembly at all**
-- stated that way deliberately, because a wall that "moves" has once meant a
loud failure becoming silent wrong code:

    error: insn does not satisfy its constraints:
    (insn/f 18 4 27 (set (reg/f:DI 31 sp)
            (plus:DI (reg/f:DI 31 sp) (const_int -16))) 157 {*adddi3_aarch64}
    during RTL pass: final
    internal compiler error: in final_scan_insn_1, at final.cc:2789

`reg 31 sp` is **aarch64's real stack pointer**, and no `.s` file is written.
So this is still the loud failure #128 left, not a quiet one.  x86_64 is the
non-vacuity control on the same input and compiles (397 bytes,
`f776a3b16e36`).

#128's diagnosis is CONFIRMED and made sharper.  `scratchpad/t129-syms.sh`
(non-vacuity floor on nm's own output first -- 152045 defined symbols -- and
the pattern fixed to allow the `(' of a C++ signature; see section 7):

    get_attr_enabled   insn-attrtab.o[bare]
                       insn-attrtab-i386.o[insn_i386::get_attr_enabled]
                       insn-attrtab-aarch64.o[insn_aarch64::get_attr_enabled]

    ... and `recog.o' binds the BARE one, i.e. i386's.

## 1. JOB 2 -- EVERY GENERATED FAMILY IN `OBJS', WITH A VERDICT, INCLUDING
##          THE ONES I DID NOT FIX

Seven generated per-back-end families are still carried un-namespaced in
`$(OBJS)`.  The build dir confirms the list is exactly seven: classifying
every `insn-*.o` into per-base and shared gives shared objects for
**attrtab, automata, dfatab, emit, latencytab, opinit, preds** and for nothing
else.  `insn-extract`, `insn-modes`, `insn-output`, `insn-peep`, `insn-enums`
and `insn-recog` are already **per-base only**, with no shared object built.
Those six are DONE -- a result, not silence.

**(b) and (c) are scored as SEPARATE ARMS throughout** (`t129-family.sh`).

| family | (a) per-base built | (b) selector exists | (c) anything calls it | verdict |
|---|---|---|---|---|
| `insn-opinit` | yes | yes -- `selected_raw_optab_handler` and three siblings in `multi-target-select.o` | **yes, 45 objects**; and **zero** objects still bind the bare names | **CLEAN** |
| `insn-preds` | yes | yes -- the `mt_*` forwarders (#128) | **yes, 11 objects** (`recog.o`, `lra-constraints.o`, `ira*.o`, `reload*.o`, `cse.o`, `postreload.o`, `stmt.o`, `varasm.o`); **zero** bind `lookup_constraint_1` / `reg_class_for_constraint_1` | **CLEAN** (shared `insn-preds.o` still linked, deliberately opted out) |
| `insn-attrtab` | yes | **NO SELECTOR AT ALL** | n/a | **LEAKING** |
| `insn-automata` | yes | **NO SELECTOR AT ALL** | n/a | **LEAKING** |
| `insn-dfatab` | yes | **NO SELECTOR AT ALL** | n/a | **LEAKING** |
| `insn-latencytab` | yes | **NO SELECTOR AT ALL** | n/a | **LEAKING** |
| `insn-emit` | yes | **NO SELECTOR** for the six bare names | n/a | **LEAKING**, and worse than recorded (below) |

Arm (b) for the four attribute/scheduling families is a measured **0**:
grepping `multi-target-select.cc`, `target-cumargs.cc`,
`target-cumargs-select.cc` and `target-insn.h` for any of `get_attr_enabled`,
`get_attr_length`, `insn_default_length`, `internal_dfa_insn_code`,
`insn_default_latency`, `state_transition`, `num_delay_slots`, `bypass_p`,
`maximal_insn_latency`, `dfa_start` gives **0 hits in all four files**.  There
is nothing for arm (c) to be scored against, and that is the finding.

**THE FULL LEAK SURFACE, BY NAME AND BY BINDER.**  Twenty-one entry points are
bound by shared objects, all to the PRIMARY's copy:

    get_attr_enabled             recog.o
    get_attr_preferred_for_size  recog.o
    get_attr_preferred_for_speed recog.o
    insn_default_length          final.o
    insn_min_length              final.o
    insn_current_length          final.o
    internal_dfa_insn_code       insn-automata.o
    insn_default_latency         haifa-sched.o sel-sched-ir.o
    bypass_p                     haifa-sched.o
    insn_latency                 haifa-sched.o modulo-sched.o
    maximal_insn_latency         sel-sched.o
    state_transition             haifa-sched.o modulo-sched.o sel-sched.o
    state_size                   haifa-sched.o
    state_reset                  haifa-sched.o modulo-sched.o sched-rgn.o
                                 sel-sched-ir.o sel-sched.o
    dfa_start / dfa_finish       haifa-sched.o
    state_dead_lock_p            haifa-sched.o modulo-sched.o
    min_insn_conflict_delay      sched-rgn.o
    print_reservation            haifa-sched.o sched-rgn.o
    dfa_clear_single_insn_cache  haifa-sched.o
    init_sched_attrs             cfgexpand.o run-rtl-passes.o

`num_delay_slots`, `const_num_delay_slots`, `eligible_for_delay`,
`min_issue_delay`, `insn_has_dfa_reservation_p` and `dfa_clean_insn_cache`
score **0 binders** in this link.  Recorded as "reorg's delay-slot path is not
linked in for these two back ends", NOT as clean.

**`insn-emit` IS WORSE THAN THE RECORDED #51 NOTE.**  The six bare names are
still the primary's, and this run found binders the note does not mention:

    gen_blockage  defined in insn-emit-5.o (i386's), bound by
      builtins.o explow.o function.o
      AND BY  insn-emit-aarch64-6.o  AND  insn-output-aarch64.o

i.e. **aarch64's own generated code calls i386's blockage expander**, because
`gen_name_is_global_p ("blockage")` keeps that one name out of the namespace
on both sides.  `gen_nop` (bound by `cfgrtl.o`, `except.o`, `varasm.o`,
`targhooks.o`), `gen_speculation_barrier` (`targhooks.o`), `add_clobbers` and
`added_clobbers_hard_reg_p` (`combine.o`, `recog.o`, `gcse.o`) and `gen_movxf`
(`reg-stack.o`) are the same shape.

**NO PROBE ARM EXISTS FOR ANY OF THIS.**  None of these are `tm.h` macros;
they are generated functions, so `macro-status.txt` has never listed them and
`tab-probe.sh` reads constants.  Recorded as **"cannot be checked by the
scoreboard, because the scoreboard measures `tm.h` macros and these are
generated symbols"** -- not as clean.

## 2. WHAT LANDED -- `NUM_INSN_CODES` IS NOW THE UNION, NOT THE PRIMARY'S

The brief said to check bound-vs-index explicitly.  Doing that outside the
attribute family found this, and it is another instance of the shape:

    insn-codes.h          NUM_INSN_CODES = 15429   <- the PRIMARY's
    insn-codes-i386.h     NUM_INSN_CODES = 15429
    insn-codes-aarch64.h  NUM_INSN_CODES = 20512

`recog.h:578-579` sizes `x_bool_attr_masks[NUM_INSN_CODES][BA_LAST+1]` and
`x_op_alt[NUM_INSN_CODES]` inside `struct target_recog`; `lra.cc:631` sizes
`insn_code_data[NUM_INSN_CODES]`.  All three are indexed in **shared** code by
`INSN_CODE (insn)`, i.e. by the **selected** back end's numbering.  Measured
before the fix: `default_target_recog` was **0x788a8 = 493,224 bytes** of .bss
sized from 15429, and `recog.cc:2707` writes into it at aarch64 codes running
to **20511** -- a 163KB overrun of a shared object, with no link error and no
warning.  `insn_data_tab` corroborates the two counts independently: i386
617,160 bytes = 15429 x 40 exactly, aarch64 820,992.

This is the fix `insn-config.h` and `insn-opinit.h` already have, so it reuses
their mechanism rather than inventing a second one:

  * **`gencodes.cc`** gains `-l` / `-U<file>` / `-A<base>`, a near-copy of
    `genconfig.cc`'s `apply_union_list`.  Absence is never an answer: a union
    file with no `base` line, one that does not name this base, one missing
    the key, or one whose maximum is BELOW what this base needs are four
    separate fatal errors, each naming what is wrong.
  * **`gen-multi-target-md.awk`** emits an `insn-codes-<cpu>.part` rule per
    back end and `emit_codes_union` for the concatenation, with the same
    short-list assertion the config union carries **plus** an assertion that
    the part file contains a `NUM_INSN_CODES` line by name -- a part file with
    a `base` line and no key parses, is non-empty, and contributes a base.
  * **`Makefile.in`** takes `insn-codes.h` out of `simple_rtl_generated_h`,
    gives it an `s-codes` rule with `CODES_UNION_FLAGS`, and -- the trap
    `insn-config.h` already paid for -- names it explicitly in
    `$(generated_files)`, which is the order-only barrier every host object
    waits behind.

**ONLY THE BOUND IS UNIONED.**  The `CODE_FOR_<pattern>` enumerators stay per
back end, and a union of them is not a thing that exists: two back ends spell
one name for two patterns.  Swept to check that is safe -- over all of `gcc/`
excluding `config/`, `testsuite/` and the `gen*` programs, the only enumerator
shared code spells is `CODE_FOR_nothing`, which is 0 everywhere.  A guard arm
asserts the enumerator lists still DIFFER in length per base (8978 vs 13468),
so a future merge of them fails here.

**THE PER-BASE HEADERS GET THE UNION BOUND TOO, not just the shared one.**  A
per-base header keeping its own count would put two different sizes of
`struct target_recog` in one link -- the layout-disagreement bug this branch
paid for once already with `struct target_preds_desc`.

## 3. THE BARS

  * `make multi-target-objs cc1 lto1` in `$B/gcc` -- **rc=0**, and again rc=0
    after deleting `insn-codes.h`, both per-base headers, the union list, both
    `.part` files and `s-codes` and letting the new rules rebuild them from
    nothing.
  * **x86_64 `-O2` big.c md5 `378fc33c1e70`, 12369 bytes -- unmoved**,
    measured BEFORE and AFTER **in this same build dir**.
  * **aarch64 `int x = 1;` rc=0, 373 bytes, empty stderr, md5
    `b01d9157fdc1`** -- byte-identical before and after.
  * **The three `t129-fn.sh` x86_64 outputs byte-identical** before and after:
    `f776a3b16e36`, `b9716cd03194`, `e2879feb51f6`.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock`, absolute `IN`, **5
    distinct md5 per side**, **negative control firing** (1158 vs 804), rc=0,
    run after the edit and again after the regeneration round trip.  O0
    `1c00922491f8`, O1 `4fabab94b41b`, O2 `378fc33c1e70`, O3 `d220421237bc`,
    Os `d6787f7e281f`.  It **does** run in this build dir -- checked
    explicitly; the log names
    `/tmp/b129/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config`.
  * **`scratchpad/t129-guards.sh`: 32 PASS / 0 FAIL.**
  * Cold `all-gcc` before any edit: **rc=0, 776 lines / 169 `warning:`**.
    Incremental after the edit: 513 lines / 119 `warning:`.  Near-no-op
    incremental: **8 lines / 0 `warning:`**, all `is unchanged` -- the low end
    of the documented 8-to-32 floor.

### THE ARMS THAT MATTER

  * **ARM 0 RUNS FIRST and asserts the generated content BY NAME AND BY
    VALUE**: all three headers read 20512; the union list carries `base i386`
    with `NUM_INSN_CODES 15429` and `base aarch64` with `NUM_INSN_CODES
    20512`; the GENERATED `multi-target-md.mk` passes `-Uinsn-codes-union.list`
    twice and has two `.part` rules; `gcc/Makefile` carries
    `CODES_UNION_FLAGS`; `insn-codes.h` is out of `simple_rtl_generated_h`
    AND named in `$(generated_files)`.
  * **A NON-VACUITY ARM asserts the two bases DISAGREED** (15429 vs 20512).
    Had they matched, the union would be untested by construction and every
    other arm would pass on a change that does nothing.
  * **ARM 1 is "what would have had to change".**  `default_target_recog`
    493,224 -> **656,392** bytes and `insn_code_data` 123,432 -> **164,096 =
    20512 x 8 exactly**.  The prediction (20512 x 32, plus the rest of the
    struct) was written before the measurement and matched.
  * **ARM 3 INJECTS EVERY FAULT THE MITIGATION NAMES and requires each refusal
    to fire BY NAME**: missing base line (`none of them 'i386'`), missing key
    (`given for 1 of 2 back ends`), stale values below what the base needs
    (`the union file is stale`), and `-U` with no `-A`.  Each injection
    asserts **the state it produced**, in both directions, before scoring --
    and a **3a control** runs first requiring the UNMODIFIED list to be
    accepted, so a refusal cannot be credited to the injection when it was
    really an unrelated breakage.  A **3z restore** arm requires the reversal
    to reverse.
  * **ARM 4 is a RATCHET, not a pass**: it asserts the four attribute families
    still have **zero** selector hits, so that wiring one up fails this guard
    and has to be updated deliberately rather than landing unremarked.

## 4. THE ATTRIBUTE-TABLE FAMILY IS A DESIGN FORK.  I STOPPED RATHER THAN
##    GUESSING, AND HERE IS WHY, MEASURED

The brief called Job 1 "the same shape as the predicates".  It is not, and the
difference is a measurement rather than an opinion:

    HAVE_ATTR_length              shared=1  i386=1  aarch64=1
    HAVE_ATTR_enabled             shared=1  i386=1  aarch64=1
    HAVE_ATTR_preferred_for_size  shared=1  i386=1  aarch64=0
    HAVE_ATTR_preferred_for_speed shared=1  i386=1  aarch64=0

**aarch64 has no `preferred_for_size` / `preferred_for_speed` attribute at
all**, and `nm` confirms it: there is an
`insn_i386::get_attr_preferred_for_size` and **no aarch64 definition
anywhere**.  `recog.cc:2658` nonetheless calls it for aarch64 today, because
the shared `insn-attr.h` publishes i386's `HAVE_ATTR_*` and
`have_bool_attr` therefore answers yes.  Upstream's answer for a back end
without the attribute is the preprocessor stub
`#define get_attr_preferred_for_size hook_int_rtx_1`.

So a uniform table of function pointers **cannot be filled** without first
deciding what a base with no such attribute puts in the slot, and
`HAVE_ATTR_*` has to stop being a `#if` before that question can even be
asked.  That is a design decision, not a bug fix, and this branch's rules
forbid resolving it by picking whichever makes the build succeed.

**Option A -- runtime `have_bool_attr`, stub in the slot.**  Each base's
`target_attr_desc` gets `hook_int_rtx_1` where it has no attribute, and
`recog.cc`'s `have_bool_attr` reads a per-base boolean instead of
`HAVE_ATTR_*`.  Cost: ~27 function-pointer fields and ~27 `mt_*` forwarders;
one indirect call per attribute query, and `get_attr_enabled` sits in
`get_bool_attr_mask_uncached`'s inner loop over alternatives.  Risk: the
`HAVE_ATTR_*` macros are also spelled in `config/` (arc, arm, sh, msp430
headers), so the `#if` form cannot simply be deleted.

**Option B -- union the booleans, keep the stub decision in the generator.**
`genattr` learns the `-U`/`-A` list like `genconfig` and emits
`HAVE_ATTR_x 1` if ANY base has it, with each base's own table filling the
slot with the stub when it does not.  Cheaper at the use site (no change to
`recog.cc`), but it makes `HAVE_ATTR_*` mean "somewhere" rather than "here" --
exactly the `HAVE_V8HFmode` failure already on this branch's books, where the
union's answer leaked instead of the primary's.

**Option C -- split the family.**  `insn-attrtab` alone (the six names
`recog.o` and `final.o` bind) first, leaving `insn-automata` / `insn-dfatab` /
`insn-latencytab` to a scheduling-specific task.  The scheduler entry points
are ~15 more names and `haifa-sched.o` is their dominant consumer, so the
split is along a real seam.  Against it: a half-converted family is exactly
the state that reads as done.

**Two further forks inside the same family, both measured:**

  * `internal_dfa_insn_code` and `insn_default_latency` are function
    **POINTERS** assigned by `init_sched_attrs ()`, not functions -- the
    `kind mismatch` entry in the bug table.  Selecting them means selecting
    which base's `init_sched_attrs` runs, not which function goes in a slot.
    `cfgexpand.o` and `run-rtl-passes.o` call the bare `init_sched_attrs`.
  * The whole DFA block only exists in `insn-attr.h` when a base has
    `define_insn_reservation`s.  Both bases here do (`dfa_start` is declared
    in both per-base headers), so **this pair cannot exercise the case** --
    recorded as unmeasurable here, not as absent.  A base with no reservations
    has no `state_transition` to put in a slot at all.

**`insn-attr-common.h` is a fifth, quieter leak in the same family**: it
publishes `INSN_SCHEDULING`, `DELAY_SLOTS` and the `enum attr_*` types.
Measured here, both bases give `INSN_SCHEDULING` defined and `DELAY_SLOTS 0`,
so **this pair shows no divergence** -- a two-target accident, not a clean
bill.  The attribute sets differ badly (82 `HAVE_ATTR_` lines for i386, 47 for
aarch64) and shared code names none of those enums, which is why nothing has
broken yet.

## 5. THE SCOREBOARD -- NOT RUN, NOT MOVED, AND DELIBERATELY NOT BANKED

**I did not run `macro-probe-run.sh` and I am claiming no scoreboard
movement.**  Carrying the recorded line unchanged: header **i386 112 PASS / 0
FAIL, aarch64 8 PASS / 104 FAIL of which only 2 are TRUSTED**; TAB **i386
32/0, aarch64 27/5**.

Nothing in this task is in `macro-status.txt`.  `NUM_INSN_CODES` is a
generated `const`, not a `tm.h` macro, and the attribute entry points are
generated functions.  The correct entry for all of it is **"no probe arm
exists, because the scoreboard measures `tm.h` macros and these are generated
symbols"** -- unmeasurable, not clean.  The "converted but reads UNCONVERTED"
list is unchanged at sixteen.

## 6. WHAT I DID NOT DO

  * **The four attribute/scheduling families are untouched**, written up in
    section 4 rather than guessed at.  **Job 1 is therefore NOT fixed and the
    `add` wall is unmoved** -- said plainly.
  * **`insn-emit`'s six bare names are untouched**, and the new finding that
    aarch64's OWN generated objects bind i386's `gen_blockage` is recorded
    rather than acted on: `gen_name_is_global_p` exists precisely to keep that
    name global, so changing it is the `HAVE_blockage` fork
    `gen-target-ns.cc:134` already writes up.
  * **The `enum insn_code` RANGE is not fixed, only the bound.**  With 15428
    as its largest enumerator the shared `enum insn_code` has a valid range of
    [0, 16383], so converting an aarch64 code of 20000 to it is out of range.
    Pinning it needs a terminal enumerator in every base's header, which
    changes `-Wswitch` behaviour for every `switch` over `enum insn_code` in
    `config/`.  Written up in `gencodes.cc` rather than guessed at.
  * **No gdb arm this run.**  #128's two breakpoint runs already established
    the constraint and enabled-mask readings, `t129-state.sh` reproduces the
    identical failure site, and re-reading the same values under a third
    breakpoint would have added no independent evidence.  Recorded as "not
    measured", not as "clean".
  * **No memory measurement.**  `NUM_INSN_CODES` 15429 -> 20512 grows
    `default_target_recog` by 163KB of .bss, and `save_target_globals`
    allocates a `target_recog` per `__attribute__((target))` set.  That is a
    memory question, not a correctness one, and it is unmeasured -- I am not
    claiming it is free.  It joins `Pmode`'s 648 sites (#125) and #128's
    constraint indirection as an open cost question.
  * `make all-target-libgcc` not re-run; #119's environmental `-m32` blocker
    is unchanged.

## 7. AN INSTRUMENT DEFECT THIS RUN PRODUCED, WORTH RECORDING

**`nm -C` anchored on `$` scores ZERO for every function.**  My first symbol
sweep grepped `' [TDBRVW] (insn_[a-z0-9_]+::)?get_attr_enabled$'` and reported
**no definition anywhere** for twelve of fourteen entry points.  The only two
that "worked" were `internal_dfa_insn_code` and `insn_default_latency`, which
are DATA (function pointers) and so carry no `(rtx_insn*)` suffix.  A sweep
built that way says "this family has no per-base copy", which is the opposite
of the truth and points at "there is nothing to select" rather than "nothing
selects it".  The tell was that exactly the two non-functions answered.

This is the `nm -u` plain-name lesson in PRINCIPLES arriving from the other
direction: there the substring matched too much, here the anchor matched too
little.  **Both are the same rule -- a zero from a name-matching instrument is
a claim about the pattern, not about the code.**

## 8. FILES

    t129-clone.sh    derives my build-dir scripts from #128's; REFUSES on a
                     leftover `b128'
    t129-conf.sh     two-target configure, /tmp/b129
    t129-build.sh    make at the TOP level
    t129-gccbuild.sh make in $B/gcc -- where cc1 actually builds
    t129-reconf-gcc.sh  re-runs gcc/configure via the TOP LEVEL (never
                     config.status, which target-specs overwrites), and
                     asserts `insn-codes-union.list' reached gcc/Makefile
    t129-specs.sh    both target-specs probes, real aarch64 binutils
    t129-syms.sh     WHICH attribute vocabulary shared code links, by nm, with
                     a non-vacuity floor on nm's own output
    t129-family.sh   JOB 2: (a)/(b)/(c) scored as THREE SEPARATE ARMS for all
                     seven families, plus the bound-vs-index and HAVE_ATTR_*
                     readings
    t129-state.sh    big.c site + `int x = 1;' + x86_64 -O2
    t129-fn.sh       the three function-body inputs, both bases
    t129-sc.sh       stock-compare, ABSOLUTE big.c, tagged outdir (/tmp/sc129-*)
    t129-guards.sh   32 arms; ARM 0 content-by-name-and-value and runs first,
                     ARM 1 the size prediction, ARM 3 the injection with a
                     control and a restore, ARM 4 the leak ratchet

# TASK #130 -- THE `insn-attrtab' FAMILY IS SELECTED.  `int g (int a)
# { return a + 1; }' NOW COMPILES FOR aarch64, AND THE ASSEMBLY IS aarch64's.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in' was **0**, `git reset --hard multi-target' took
it to **37**, and there was no `scratchpad/' in the worktree at all.  That is
now NINE worktrees in a row.  Build dir `/tmp/b130', my own, cold.

**The brief named no task numbers I could read**; everything below is measured
in `/tmp/b130'.

## 0. THE PRIZE, AND THE ASSEMBLY, BECAUSE A DISAPPEARED ICE IS NOT A RESULT

    add  aarch64  rc=0  COMPILED  bytes=557  md5=2a70c955a1b1
    add  x86_64   rc=0  COMPILED  bytes=397  md5=f776a3b16e36   (unmoved)

Before, in this same build dir: `add aarch64 rc=1 ICE: in final_scan_insn_1,
at final.cc:2789', no `.s' written at all.  What it emits now:

        sub     sp, sp, #16
        str     w0, [sp, 12]
        ldr     w0, [sp, 12]
        add     w0, w0, 1
        add     sp, sp, 16
        ret

`sp', `w0', `.arch armv8-a', `.global' (aarch64's spelling, not i386's
`.globl'), and the `aeabi_feature_and_bits' subsection.  **A REAL aarch64
ASSEMBLER ACCEPTS IT** (`pkgsCross.aarch64-multiplatform.buildPackages.
binutils'), and the disassembly is aarch64 machine code implementing `a + 1':
`d10043ff sub sp, sp, #0x10' ... `11000400 add w0, w0, #0x1' ... `d65f03c0
ret'.  So this is not a loud failure that went quiet.

**ONE THING IN THAT OUTPUT IS STILL WRONG, AND IT IS NOT MINE TO BANK AS
CLEAN.**  The CFI reads `.cfi_def_cfa_offset 16' BEFORE the `sub', then 32
after -- i.e. the CFA is 16 too high throughout.  aarch64 does not define
`INCOMING_FRAME_SP_OFFSET' at all (so `defaults.h:1230' gives it 0);
`i386.h:2177' does define it, and `DEFAULT_INCOMING_FRAME_SP_OFFSET' too.  That
is a DIFFERENT leak, in the same family as #125's, and it was INVISIBLE until
this task produced output to look at.  **I did not diagnose which of the two
macros carries it, and 16 is not `UNITS_PER_WORD' (8) on its face, so the
mechanism is recorded as UNMEASURED with two named candidates -- not as
understood.**

`big.c' and `fn-call' now both die at `extract_insn, recog.cc:2890' -- the wall
MOVED, and #127 already warned that site may be a second, distinct problem.
Still a loud failure with no output; not diagnosed here.

## 1. THE `HAVE_ATTR_*' FORK -- RESOLVED BY MEASUREMENT, NOT BY CHOICE

The brief asked me to work out what stock GCC does for a back end WITHOUT the
attribute and make the thunk return exactly that, and to STOP if the absent
case were not expressible as a return value.  **It is expressible, and the
generator had already expressed it.**  `genattr.cc:313-336' emits, into every
base's header and OUTSIDE the namespace:

    extern int hook_int_rtx_1 (rtx);
    #if !HAVE_ATTR_preferred_for_size
    #define get_attr_preferred_for_size hook_int_rtx_1
    #endif

and `hooks.cc:253' is `return 1;'.  So in a translation unit compiled with
`-I<base>-inc', the SPELLING `get_attr_preferred_for_size (insn)' is already
the right answer for that base.  **Nothing in this change decides what absence
means.**  `target-cumargs.cc' -- which is already compiled once per base
against that base's headers -- simply gains six one-line thunks spelling those
names, and the decision travels with the header.

**This is therefore NOT the sjlj shape.**  The one place it nearly was: the two
`#if HAVE_ATTR_length' PASS GATES in `recog.cc' (4711, 4764).  A macro that
expands to a CALL is silently 0 on a `#if' line -- both gates would have turned
off for every target with no diagnostic.  Both are rewritten to a runtime `if'
(each arm compiled in both cases before, so nothing is lost), and **ARM 2
asserts no `#if HAVE_ATTR_' survives in shared code, with ARM 5c injecting one
and requiring ARM 2 to catch it.**

## 2. WHAT LANDED

  * **`gcc/target-attr.h'** -- `struct target_attr_desc': four booleans
    (`have_attr_length/enabled/preferred_for_size/preferred_for_speed') and six
    function pointers.  NOT unioned: `HAVE_V8HFmode' is already on the books as
    the case where the UNION's answer leaked, and "some configured back end has
    a preferred_for_size attribute" is not an answer to "does the selected one".
  * **`gcc/multi-target-attr.h'** -- renames the USES, emitted as the last line
    of the un-namespaced `insn-attr.h' by `genattr'.  Exact shape of
    `multi-target-preds.h'; no second mechanism invented.
  * **`genattrtab.cc'** emits `#define MULTI_TARGET_ATTR_NO_REDIRECT 1' from
    `write_header' under the SAME condition, so the file that DEFINES those
    names does not have its definitions renamed.
  * **`Makefile.in'** gives `build/genattr.o' and `build/genattrtab.o'
    `-DGEN_MULTI_TARGET', which is the only way the SINGULAR run can know it is
    on a multi-target build (`gen_target_ns ()' is null in it).
  * **`target-cumargs.cc'** grows six thunks and `mt_base_attr'; it rides on
    `target_cumargs_desc' like `frame', `insn' and `preds' -- no new registry.
  * **`multi-target-select.cc'** installs it and refuses BY NAME if null;
    `targetm_attr' starts NULL, never at the primary.

**THE MEMBER NAMES OF `target_attr_desc' ARE SHORT, AND THAT IS LOAD-BEARING.**
First attempt named them `get_attr_enabled', `insn_default_length' and so on.
The per-base `insn-attr.h' stub `#define's REWRITE THE STRUCT DECLARATION:
measured, `redeclaration of int (* target_attr_desc::hook_int_rtx_1)' and `too
many initializers'.  It failed loudly only because TWO members collided into
one name -- **a table with a single such member would have compiled, been
initialised through a silently renamed field, and been correct on the
primary.**

## 3. BOTH-SIDED EVIDENCE, IN THE RUNNING cc1 (`t130-cause.sh')

One breakpoint per run, `mt_get_attr_enabled', and gdb's own
`Breakpoint N, mt_get_attr_enabled' matched before anything is scored.  (The
first version broke on `mt_get_attr_preferred_for_size', which at `-O0' is
never reached -- and **my confirmation check passed anyway**, because it
matched the `info breakpoints' listing rather than a stop.  Fixed to require
`^Breakpoint [0-9]+, '.  An arm that confirms a breakpoint it never hit is the
gdb blind spot in PRINCIPLES arriving from a new direction.)

    aarch64:  targetm_attr->name = "aarch64"
              have_attr_length/enabled = true, preferred_for_size/speed = FALSE
    i386:     targetm_attr->name = "i386"
              all four = TRUE

Both directions diverge, so this cannot be "everyone now gets the same new
answer".  And the VALUE, read out of the objects rather than the source:

    target-cumargs-aarch64.o  mt_base_get_attr_preferred_for_size
        jmp -> R_X86_64_PLT32  _Z14hook_int_rtx_1P7rtx_def
    target-cumargs-i386.o     mt_base_get_attr_preferred_for_size
        jmp -> R_X86_64_PLT32  _ZN9insn_i38627get_attr_preferred_for_sizeEP8rtx_insn

i.e. aarch64's slot holds the GENERATOR's own absent-answer and i386's holds
i386's real function.  (An earlier version of that arm grepped the disassembly
AND the relocations together and matched the thunk's own LABEL, scoring
aarch64's slot as if it called the real function -- the `nm' pattern lesson
again.  It reads only `R_X86_64_PLT32' lines now.)

## 4. THE LEAK SURFACE, BEFORE AND AFTER (`t130-syms.sh', `t130-family.sh')

Before, `recog.o' bound the BARE `get_attr_enabled', i.e. i386's.  After:

    get_attr_enabled             0 binders
    get_attr_preferred_for_size  0
    get_attr_preferred_for_speed 0
    insn_default_length          0
    insn_min_length              0
    insn_current_length          0

**`num_delay_slots' also reads 0, and that is NOT evidence of this change** --
#129 measured it at 0 already, because reorg's delay-slot path is not linked
for these two back ends.  Recorded rather than banked.

**STILL LEAKING, DELIBERATELY, AND UNDER A RATCHET ARM** -- the scheduling
families, which are a real seam (`haifa-sched.o' is their dominant consumer):

    internal_dfa_insn_code   insn-automata.o
    insn_default_latency     haifa-sched.o sel-sched-ir.o
    state_transition         haifa-sched.o modulo-sched.o sel-sched.o
    dfa_start / dfa_finish   haifa-sched.o
    ... and the rest of #129's list, unchanged.

ARM 4b asserts these still have NONZERO binders, so wiring one up FAILS a
guard and has to be recorded rather than landing unremarked.

## 5. THE TWO FORKS THE BRIEF ASKED ME TO ANSWER EXPLICITLY

**FORK 1 -- the `internal_dfa_insn_code' function-POINTER kind mismatch.
ALREADY RESOLVED, upstream of selection, and not by me.**  `genattrtab.cc:5166-
5200' already emits the bare names as POINTERS in every configuration, with a
comment saying why: upstream emits plain functions and `#define's
`init_sched_attrs' away, "which makes the KIND of two extern names depend on
the machine description -- unusable when the middle end is compiled once
against a single insn-attr.h".  So there is no kind mismatch left to trip over.
**What remains is not a rename**: selecting `internal_dfa_insn_code' means
selecting which base's `init_sched_attrs ()' RUNS, and `cfgexpand.o' and
`run-rtl-passes.o' call the bare one.  That is the scheduling task, and I did
not do it.

**FORK 2 -- a base with no `define_insn_reservation's.  STILL UNMEASURABLE
WITH THIS PAIR, and I am not manufacturing a green for it.**  i386 and aarch64
both have reservations (`dfa_start' is declared in both per-base headers), so
the DFA block exists in both and the case where it does not cannot be
exercised here.  "Cannot be checked, because both configured bases have
reservations" -- not clean.

## 6. `insn-emit' -- NOT TOUCHED, AND WHY

Still leaking exactly as #129 recorded, including `insn-emit-aarch64-6.o' and
`insn-output-aarch64.o' binding the bare `gen_blockage'.  I did not act on it:
five of the six names could take a uniform forwarder and **`gen_movxf' cannot**
(i386 defines it, aarch64 does not, and its only caller is x87 code), which the
brief says needs the user's ruling.  Since any forwarder scheme I wrote would
have decided `gen_movxf' by implication, **I stopped.**  Nothing in this task
pre-empts that ruling.

## 7. THE BARS

  * `make multi-target-objs cc1 lto1' in `$B/gcc' -- **rc=0**.
  * **x86_64 `-O2' big.c md5 `378fc33c1e70', 12369 bytes -- UNMOVED**, measured
    BEFORE and AFTER in this same build dir.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock', absolute `IN', 5
    distinct md5 per side, **negative control firing (1158 vs 804)**, and it
    demonstrably runs in THIS build dir (log names
    `/tmp/b130/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config').
    O0 `1c00922491f8', O1 `4fabab94b41b', O2 `378fc33c1e70', O3 `d220421237bc',
    Os `d6787f7e281f'.
  * **aarch64 `int x = 1;' rc=0, 373 bytes, empty stderr, md5 `b01d9157fdc1'**
    -- byte-identical before and after.
  * **x86_64 `fn-add'/`fn-call'/`fn-data' byte-identical**: `f776a3b16e36',
    `b9716cd03194', `e2879feb51f6'.
  * **`scratchpad/t130-guards.sh': 38 PASS / 0 FAIL**, with ARM 0 (generated
    content by name and value) FIRST, ARM 1 non-vacuity, ARM 2b the value read
    out of the objects, ARM 4b the ratchet, and ARM 5 injection with a control
    (5a), a state assertion in both directions (5b) and a restore (5z).
  * Cold `all-gcc' before any edit: **rc=0**.  Incremental after: 13 stderr
    lines / 2 `warning:', within the documented 8-to-32 incremental floor.

## 8. THE SCOREBOARD -- NOT RUN, NOT MOVED, NOT BANKED

**I did not run `macro-probe-run.sh' and I claim no scoreboard movement.**
Carrying the recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64
8 PASS / 104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64
27/5**.  Nothing in this task is in `macro-status.txt': `HAVE_ATTR_*' and the
attribute entry points are GENERATED symbols, not `tm.h' macros.  The correct
entry is **"no probe arm exists, because the scoreboard measures `tm.h' macros
and these are generated symbols"** -- unmeasurable, not clean.

## 9. WHAT I DID NOT DO

  * The three SCHEDULING families (`insn-automata', `insn-dfatab',
    `insn-latencytab') -- ~15 more names, under the ratchet.
  * `insn-emit''s six bare names -- section 6.
  * The `extract_insn, recog.cc:2890' wall that both `big.c' and `fn-call' now
    reach.  Not diagnosed.
  * The CFI/`INCOMING_FRAME_SP_OFFSET' divergence in section 0.  Observed,
    named, NOT diagnosed.
  * No compile-time or memory measurement.  Every attribute query in shared
    code is now an indirect call, and `get_attr_enabled' sits in
    `get_bool_attr_mask_uncached''s inner loop over alternatives -- though it
    is cached per insn code, so the loop runs once per code.  x86_64 output is
    byte-identical, so this is a throughput question and not a correctness one,
    but it is unmeasured and I am not claiming it is free.  It joins `Pmode''s
    648 sites (#125) and #128's constraint indirection.
  * `make all-target-libgcc' not re-run; #119's `-m32' blocker unchanged.

## 10. FILES

    t130-clone.sh    derives my build-dir scripts from #129's; REFUSES on a
                     leftover `b129'
    t130-conf.sh     two-target configure, /tmp/b130
    t130-build.sh    make at the TOP level
    t130-gccbuild.sh make in $B/gcc -- where cc1 actually builds
    t130-reconf-gcc.sh  re-runs gcc/configure via the TOP LEVEL
    t130-specs.sh    both target-specs probes, real aarch64 binutils
    t130-dbg.sh      rebuilds recog.o AND target-cumargs-select.o with `-g'
    t130-syms.sh     WHICH attribute vocabulary shared code links, by nm, with
                     a non-vacuity floor on nm's own output
    t130-family.sh   the seven-family (a)/(b)/(c) sweep, re-run
    t130-cause.sh    THE DIAGNOSIS: one breakpoint per run, both bases, gdb's
                     own STOP line matched (not its breakpoint listing)
    t130-state.sh    big.c site + `int x = 1;' + x86_64 -O2
    t130-fn.sh       the three function-body inputs, both bases
    t130-sc.sh       stock-compare, ABSOLUTE big.c, tagged outdir (/tmp/sc130-*)
    t130-guards.sh   38 arms; ARM 0 content-by-name-and-value runs first,
                     ARM 2b reads the VALUE out of the objects, ARM 4b the
                     leak ratchet, ARM 5 injection with control and restore

# TASK #131 -- THE WRONG CFI IS DIAGNOSED AND FIXED, AND THE `recog.cc:2890'
# WALL WAS A SECOND, DISTINCT PROBLEM: ONE MACRO, `FUNCTION_MODE'.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in' was **0**, `git reset --hard multi-target' took
it to **39**, and there was no `scratchpad/' at all.  That is now TEN in a
row.  Build dir `/tmp/b131', my own, cold.  **The brief named no task numbers
I could read**; everything below is measured in `/tmp/b131'.

## 0. THE TWO ARTEFACTS, BECAUSE THE SITE IS NOT THE MEASUREMENT

    add   aarch64  rc=0  532 bytes  md5 28943da2efab   (was 557 / 2a70c955a1b1)
    call  aarch64  rc=0  775 bytes  md5 d4224a2c155d   (was ICE recog.cc:2890)
    data  aarch64  rc=0  373 bytes  md5 b01d9157fdc1   -- the recorded bar, met
    add/call/data x86_64  f776a3b16e36 / b9716cd03194 / e2879feb51f6 -- ALL
    THREE BYTE-IDENTICAL before and after, in this build dir.

`int g (int a) { return a + 1; }' now emits, with NO entry note:

        .cfi_startproc
        sub     sp, sp, #16
        .cfi_def_cfa_offset 16
        str     w0, [sp, 12]
        ldr     w0, [sp, 12]
        add     w0, w0, 1
        add     sp, sp, 16
        .cfi_def_cfa_offset 0
        ret

and `int g (int a) { return f (a) + f (a + 1); }' -- which ICEd -- emits a
correct aarch64 frame: `stp x29, x30, [sp, -48]!', `str x19, [sp, 16]', two
`bl f', `ldp x29, x30, [sp], 48', with `.cfi_offset 29/30/19' and
`.cfi_def_cfa_offset 48 -> 0'.

**BOTH ASSEMBLED AND DISASSEMBLED WITH A REAL aarch64 ASSEMBLER**
(`pkgsCross.aarch64-multiplatform.buildPackages.binutils', named and asserted
in `t131-asm.sh' before anything is scored).  `readelf -h' says AArch64, the
disassembly is aarch64 machine code implementing each function, and
`readelf --debug-dump=frames' decodes the unwind table out of the assembled
object:

    CIE  DW_CFA_def_cfa: r31 (sp) ofs 0     Return address column: 30
    FDE  advance 4;  def_cfa_offset 16;  advance 16;  def_cfa_offset 0

i.e. the CFA now starts at sp+0, which is what aarch64 means.  Before, the
same reading was 16 / 32 / 16.

## 1. JOB 1 -- WHAT CARRIED THE WRONG CFI.  MEASURED, NOT INHERITED.

#130 named two candidates and declined to pick, because **16 is not
`UNITS_PER_WORD' (8) on its face**.  `t131-cfi-cause.sh': ONE breakpoint per
run, on `scan_trace', with gdb's own `^Breakpoint N, scan_trace' STOP line
matched (not `info breakpoints') and the backtrace printed, `--args' not
`gdb run', and `dwarf2cfi.cc' rebuilt at **`-g3'** because at `-g' the macro
reads were `No symbol "UNITS_PER_WORD" in current context' -- which is the
error #126 recorded being scored as a pass.  Both bases:

    aarch64:  cfun->machine->func_type = TYPE_EXCEPTION   UNITS_PER_WORD = 8
              INCOMING_FRAME_SP_OFFSET         = 16
              DEFAULT_INCOMING_FRAME_SP_OFFSET =  8
    x86_64:   cfun->machine->func_type = TYPE_NORMAL      UNITS_PER_WORD = 8
              INCOMING_FRAME_SP_OFFSET         =  8
              DEFAULT_INCOMING_FRAME_SP_OFFSET =  8

**16 IS `2 * UNITS_PER_WORD', AND THE ROUTE TO IT IS A NEW INSTANCE OF THE
`identity by address' DISGUISE.**  i386.h:2177 is `(cfun->machine->func_type
== TYPE_EXCEPTION ? 2 * UNITS_PER_WORD : UNITS_PER_WORD)', and `cfun->machine'
points at **aarch64's** `machine_function' object while `dwarf2cfi.cc' was
compiled against **i386's** declaration of that struct name.  So the 2-bit
`func_type' bitfield is read out of whatever aarch64 keeps at that offset, and
it read 3 = `TYPE_EXCEPTION'.  One struct NAME, two layouts, no diagnostic.
Nothing here fixes that type confusion in general -- `i386.h:1650' reads the
same field -- it removes the one read of it that reached emitted unwind data.

**BOTH MACROS HAD TO MOVE, AND THAT IS NOT A JUDGEMENT CALL.**  dwarf2cfi.cc
:2766 emits the entry note only when the two DISAGREE.  With the measured
values: converting `INCOMING_FRAME_SP_OFFSET' alone gives aarch64 0 against
i386's `DEFAULT_' 8, so the note is STILL emitted and now reads
`.cfi_def_cfa_offset 0' -- a different wrong file that still assembles.
Converting `DEFAULT_' alone leaves the real offset at 16.  (That is a
derivation from the two measured values, not a separate measurement: I did not
build the half-converted compiler.)

**THE SIBLINGS THE BRIEF ASKED ABOUT WERE ALREADY CONVERTED.**  Checked, and
stating it because a checked-and-clean family is a result: the four
stack-boundary macros (`INCOMING_STACK_BOUNDARY', `MAX_STACK_ALIGNMENT',
`MAX_SUPPORTED_STACK_ALIGNMENT', `SUPPORTS_STACK_ALIGNMENT'), the DWARF
numbering (`DWARF_FRAME_REGISTERS' / `DWARF_FRAME_REGNUM' / `DEBUGGER_REGNO')
and `DWARF_FRAME_RETURN_COLUMN' all already redirect (defaults.h:2186-2192,
:2289-2293, :2100).  The two sp offsets were the only hole in that closure.

## 2. JOB 2 -- `extract_insn, recog.cc:2890' IS A DISTINCT SECOND PROBLEM.
##    ESTABLISHED FROM THE INSN THE COMPILER PRINTED.

    (call_insn 7 6 8 2 (parallel [
        (set (reg:SI 0 x0)
            (call (mem:QI (symbol_ref:DI ("f") ...) [0 f S1 A8])
                  (const_int 0)))
        (unspec:DI [(const_int 2)] UNSPEC_CALLEE_ABI)
        (clobber (reg:DI 30 x30))]))
    during RTL pass: vregs

Note `mem:QI' and `S1'.  Every one of aarch64's call patterns
(aarch64.md:1563, :1591, :1630, :1646) matches `(call (mem:DI ...))', so
aarch64's own `recog' correctly refused an insn that SHARED code had built to
i386's shape.  The macro is **`FUNCTION_MODE'**: `QImode' at i386.h:2028,
`Pmode' at aarch64.h:1450, spelled by `calls.cc:415' as
`gen_rtx_MEM (FUNCTION_MODE, funexp)'.

**This is NOT the attribute-table family #130 landed, and NOT the unspec
numbering.**  `recog' was already dispatched per base (`multi-target-select.cc'
:644) and was already aarch64's; `insn-recog-{i386,aarch64}.o' both define only
namespaced `recog'.  #127's warning that this might be a second problem was
correct.  Converted, and the wall is gone.

## 3. WHAT LANDED

  * `target-frame.h' -- three new `target_frame_desc' members:
    `function_mode' (beside `pmode'), `incoming_frame_sp_offset',
    `default_incoming_frame_sp_offset'.
  * `target-cumargs.cc' -- three per-base thunks, plus `#include "function.h"'
    (i386's `INCOMING_FRAME_SP_OFFSET' reads `cfun', and without it the build
    failed by name at `i386.h:2178: cfun was not declared in this scope' --
    which is the mechanism working: the read now happens where `cfun->machine'
    means i386's struct).
  * `target-cumargs-select.cc' -- `mt_function_mode',
    `mt_incoming_frame_sp_offset', `mt_default_incoming_frame_sp_offset'.
  * `defaults.h' -- all three redirected, each `#undef'd first.
  * `dwarf2cfi.cc' -- its private `#ifndef DEFAULT_INCOMING_FRAME_SP_OFFSET'
    fallback KEPT, with a comment recording that it is now dead in shared code
    and why answering it there answered it with the primary's headers.

**`HOST_WIDE_INT' AND NOT `poly_int64'** for the two offsets, though
`dw_cfa_location::offset' is a `poly_int64' and that is the tempting type:
var-tracking.cc:549 declares `HOST_WIDE_INT stack_adjust' and :10101 does
`ofst -= ...' on an `int', and `poly_int64' converts implicitly to neither.

**A `#undef' MISTAKE WORTH RECORDING, because the reasoning was plausible and
the failure was a warning count rather than a wrong answer.**  The first draft
did not `#undef' `FUNCTION_MODE' or `DEFAULT_INCOMING_FRAME_SP_OFFSET',
reasoning that defaults.h has no fallback for either so there is nothing to
displace.  There is: the PRIMARY's `i386.h' has already been read at that
point.  The build still succeeded (`rc=0'), the redirect still won, and the
only evidence was **1082 warnings against the 587 of the previous arm** --
`"FUNCTION_MODE" redefined', ~500 times.  "No fallback in this file" and "not
yet defined" are different questions.

## 4. BOTH-SIDED EVIDENCE, AT THE OBJECT LEVEL (`t131-guards.sh' ARM 2)

Cut out of `objdump -dC target-cumargs-<base>.o' under each demangled label,
with a refusal when the cut is empty:

    i386    function_mode                    mov $0x18,%eax; ret   (QImode, 24)
    aarch64 function_mode                    mov $0x1b,%eax; ret   (DImode, 27)
    i386    incoming_frame_sp_offset         reads 0x70(%rdx) i.e. cfun->machine,
                                             tests the func_type bits, 8 or 16
    i386    default_incoming_frame_sp_offset tests the ISA bit, 8
    aarch64 incoming_frame_sp_offset         xor %eax,%eax; ret    (0)
    aarch64 default_incoming_frame_sp_offset xor %eax,%eax; ret    (0)

Both directions diverge, so this is not "everyone now gets the same new
answer".  **0x18/0x1b are the UNIONED mode numbers**, not upstream's; the
first draft of that arm asserted `0x2' for QImode from memory of a
single-target build and failed.

## 5. THE BARS

  * `make multi-target-objs cc1 lto1' in `$B/gcc' -- **rc=0**.
  * **x86_64 `-O2' big.c md5 `378fc33c1e70', 12369 bytes -- UNMOVED.**
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock', absolute `IN', 5
    distinct md5 per side, **negative control firing (1158 vs 804)**,
    demonstrably in THIS build dir (`mt cfg : /tmp/b131/lib/...').
    O0 `1c00922491f8', O1 `4fabab94b41b', O2 `378fc33c1e70',
    O3 `d220421237bc', Os `d6787f7e281f'.  Run twice, before and after the
    `FUNCTION_MODE' half.
  * **aarch64 `int x = 1;' rc=0, 373 bytes, empty stderr, md5 `b01d9157fdc1'**
    -- the recorded bar, unmoved.
  * `t131-guards.sh': **34 PASS / 0 FAIL**, ARM 0 content-by-name first, ARM 1
    the positional-initialiser order with a non-vacuity floor, ARM 2 the
    object-level values with an empty-cut refusal, ARM 3 the emitted CFI, ARM
    5 injection with a state assertion in both directions and a restore.
  * Incremental stderr: **24 lines, 0 `warning:', all 24 `'@' is redundant'
    from unmodified aarch64 `.md'** -- within the documented 8-to-32 floor,
    composition stated.

## 6. AN INSTRUMENT TRAP THIS RUN PRODUCED

**`cp' TO RESTORE AN INJECTED FILE REBUILDS THE WORLD.**  ARM 5 restores
`defaults.h' by content, which is correct -- and moves its mtime, so the next
`make' recompiled ~600 objects and reported **451 stderr lines** where the
incremental floor is 24.  Read as a stderr regression that is a false alarm;
read as a no-op arm it is a false green about what was rebuilt.  Take the
incremental reading from a `make' that no arm has touched a header before.

**`awk '$0 ~ f'' WITH A DEMANGLED C++ NAME MATCHES NOTHING.**  `<mt_base_
function_mode()>:' is a REGEX to awk, and `()' is an empty group, so the
pattern silently becomes `<mt_base_function_mode>:'.  All six ARM 2 arms
scored EMPTY -- which reads as "there is no per-base copy", the opposite of
the truth.  `index ($0, f)'.  Same family as #129's `nm -C' anchor and
PRINCIPLES' `nm -u' substring: a zero from a name-matching instrument is a
claim about the pattern.

**AND THE ONE THAT NEARLY COST AN ARM ITS MEANING:** `fn-data.c' gives
`375 bytes / 0252fa95df03' while `small.c' with identical CONTENT gives
`373 / b01d9157fdc1'.  The two-byte difference is the FILENAME in the `.file'
directive.  I spent time treating it as a DATESTAMP-dependent bar before
finding it; it is #125's lesson (`g-small.c' vs `small.c') arriving again.
**The recorded `b01d9157fdc1' bar is `small.c' and is met.**

## 7. WHAT I DID NOT DO

  * **`big.c' still fails, at the SAME SITE but on a DIFFERENT insn**, and I
    am not calling that unmoved or moved:

        f_builtin:  (insn 34 33 0 3 (const_int 0 [0]))
        during RTL pass: ira, via ira_remove_insn_scratches

    A bare `const_int 0' as a whole pattern.  That is a THIRD distinct
    problem.  The un-namespaced `insn-emit' family (`gen_blockage', `gen_nop'
    -- section 6 of #130) is the obvious suspect and I did **not** establish
    it; the printed pattern is not literally either back end's `blockage'
    (`(unspec_volatile [(const_int 0)] UNSPECV_BLOCKAGE)').  Recorded as
    UNDIAGNOSED with a named suspect, not as understood.
  * **`insn-emit' untouched**, per the brief: any forwarder scheme there
    decides `gen_movxf' by implication and that needs the user's ruling.
  * **The `cfun->machine' type confusion in general.**  `i386.h:1650' reads
    `func_type' too, and `struct machine_function' is one name with 48
    layouts.  Only the one read reaching unwind data is closed.
  * **`ARG_POINTER_CFA_OFFSET' (defaults.h:1219) is in the same neighbourhood
    and is NOT converted**: it expands to `FIRST_PARM_OFFSET (FNDECL) +
    crtl->args.pretend_args_size', i.e. another primary-answered macro, and
    `FRAME_POINTER_CFA_OFFSET' is `#ifdef'd at six shared sites (function.cc,
    var-tracking.cc x4, dwarf2out.cc) with neither i386 nor aarch64 defining
    it.  Found while sweeping, left alone, recorded.
  * **The scoreboard was NOT run and I claim no movement.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS /
    104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64 27/5**.
    `INCOMING_FRAME_SP_OFFSET', `DEFAULT_INCOMING_FRAME_SP_OFFSET' and
    `FUNCTION_MODE' are not in `macro-status.txt', so the correct entry is
    "no probe arm exists" -- **unmeasurable, not clean**.  They are ordinary
    `tm.h' macros and DO belong on the board; adding three arms is a task.
  * No compile-time or memory measurement.  `FUNCTION_MODE' is now an indirect
    call at eleven sites including `SET_DECL_MODE' on every FUNCTION_DECL.
    x86_64 output is byte-identical, so this is throughput and not
    correctness, but it is unmeasured and I am not claiming it is free.
  * `make all-target-libgcc' not re-run; #119's `-m32' blocker unchanged.

## 8. FILES

    t131-clone.sh     derives my build-dir scripts from #130's; REFUSES on a
                      leftover `b131'
    t131-conf.sh      two-target configure, /tmp/b131
    t131-build.sh     make at the TOP level      -- `all-gcc' goes here
    t131-gccbuild.sh  make in $B/gcc             -- `multi-target-objs' here;
                      running the latter through the former is `No rule to
                      make target', which cost one arm
    t131-specs.sh     both target-specs probes, real aarch64 binutils
    t131-dbg.sh       rebuilds dwarf2cfi.o at `-g3' (NOT `-g': the macro reads
                      need macro debug info) and relinks
    t131-cfi-cause.sh THE JOB 1 DIAGNOSIS: one breakpoint per run, gdb's own
                      STOP line matched, both bases
    t131-asm.sh       assembles + disassembles + decodes .eh_frame with the
                      REAL aarch64 binutils, tools named and asserted first
    t131-fn.sh        the three function-body inputs, both bases
    t131-state.sh     big.c site + `int x = 1;' + x86_64 -O2
    t131-sc.sh        stock-compare, ABSOLUTE big.c, tagged outdir
    t131-guards.sh    34 arms; ARM 0 first, ARM 2 the object-level values,
                      ARM 5 injection with control and restore

# TASK #132 -- THE `cfun->machine' SWEEP.  ELEVEN MACROS ENUMERATED, NINE
# CLEAN, ONE ALREADY DONE, ONE FIXED -- AND THE GUARDS OVER IT ARE A SECOND,
# LARGER LEAK THAT RUNS IN BOTH DIRECTIONS.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in' was **0**, `git reset --hard multi-target' took
it to **39**, no `scratchpad/' at all.  That is now ELEVEN in a row.  Build
dir `/tmp/b132', my own, cold.  **The brief named no task numbers I could
read**, which is the coordinator's error and not mine; everything below is
measured in `/tmp/b132'.

## 0. THE ENUMERATION -- DERIVED FROM THE HEADERS, NOT TYPED (`t132-sweep.sh')

The brief's framing was right: `machine_function' is a struct DECLARATION,
not a symbol, so `nm' says nothing, and a header probe cannot see it either
because both bases declare a struct of that name.  What CAN be enumerated is
the set of macros whose bodies reach `cfun->machine', and then which of those
NAMES shared code spells.  Eleven such macros in `i386.h'.  Spelled outside
`config/' (ChangeLogs excluded): **exactly two**.

    ACCUMULATE_OUTGOING_ARGS      i386.h:1647   SHARED, ~40 sites   <- FIXED
    INCOMING_FRAME_SP_OFFSET      i386.h:2177   SHARED              <- #131

    ix86_stack_locals                            CLEAN
    ix86_varargs_gpr_size                        CLEAN
    ix86_varargs_fpr_size                        CLEAN
    ix86_optimize_mode_switching                 CLEAN
    ix86_pc_thunk_call_expanded                  CLEAN
    ix86_tls_descriptor_calls_expanded_in_cfun   CLEAN
    ix86_static_chain_on_stack                   CLEAN
    ix86_red_zone_used                           CLEAN
    TARGET_INDIRECT_BRANCH_REGISTER              CLEAN

CLEAN means: spelled ONLY inside `config/i386/', where `cfun->machine' does
mean i386's struct.  **A checked-and-clean family is a result**, so they are
listed by name in `defaults.h' as well as here.

**The tm.h chain bounds this.**  i386's chain adds linux/unix/att/gnu-user/
x86-64, and `grep cfun->machine' over all of `config/*/*.h' shows the only
i386-side hits are the eleven in `i386.h' plus two in `i386-features.h',
which is not in tm.h.  So the enumeration is bounded and provable, not a
best-effort scan.

**DIRECT dereferences of `cfun->machine' in shared code: exactly ONE** (grep
for `cfun->machine->' outside `config/'), `dwarf2out.cc:21505-21509'.  See
section 3.  `function.cc:4870' assigns the pointer and never dereferences it;
that is fine.

**THE GENERAL FORM, ASKED AND ANSWERED (`t132-types.sh').**  Type names
declared in BOTH bases' headers: `reg_class' (known, handled),
`seh_frame_state' (both bases forward-declare it as an OPAQUE `GTY((skip))'
pointer -- aarch64 has SEH now, for `aarch64-w64-mingw32' -- and shared code
never dereferences it: FINE), and `GTY' (an artefact of the awk, not a type).
So `cfun->machine' is the only per-back-end pointee type shared code actually
reads through.

## 1. THE FIX -- `ACCUMULATE_OUTGOING_ARGS'

Same four-part shape #131 used: a `target_frame_desc' member, a per-base
thunk in `target-cumargs.cc', a selector in `target-cumargs-select.cc', an
`#undef'-then-redirect in `defaults.h'.

**WORSE THAN :2177, NOT MILDER.**  :2177 is `func_type == TYPE_EXCEPTION', so
one of eight bit patterns misfires.  This is `func_type != TYPE_NORMAL', so
**seven of eight do**.  #131 measured aarch64's bits reading 3.

**A CALL, NOT A CONSTANT.**  i386's body reads `cfun' three ways, and
`crtl->stack_realign_needed' is written DURING reload -- not constant across
a run, across two functions, or across two passes over one function.

**`emit-rtl.h' AND `predict.h' HAD TO BE ADDED to `target-cumargs.cc'.**
Without them: `i386.h:1651: crtl was not declared in this scope'.  That is
the mechanism working, identically to #131's `cfun' failure -- the read now
happens where the struct name means i386's struct, so i386's headers have to
be satisfiable there.

**`#undef' FIRST, and here there really IS a fallback in this file** --
`defaults.h:902' defines the name itself.  #131 paid 495 warnings learning
that "no fallback in this file" and "not yet defined" are different
questions; this time the `#undef' went in from the start.

## 2. THE EVIDENCE IT IS NOT INERT, AND IT IS BOTH-SIDED

**#131's three artefacts are ALL byte-identical across this change**, which
reads as "the fix did nothing".  It is not: none of `fn-add', `fn-call',
`fn-data' has outgoing arguments ON THE STACK, and `ACCUMULATE_OUTGOING_ARGS'
decides nothing when there are none.  `scratchpad/fn-outargs.c' -- ten
arguments, so two go on the stack on aarch64 -- is the input that moves.
Measured with the redirect INJECTED OFF and back ON in the same build dir
(`t132-inject.sh', sed not python3, state asserted in BOTH directions):

    aarch64  850 bytes d282037340da  ->  793 bytes 41cbd5927c02   CHANGED
    x86_64   604 bytes a3031ab34010  ->  604 bytes a3031ab34010   unchanged

x86_64 must NOT move -- it was already getting i386's answer -- and does not.
That is what distinguishes "fixed" from "everyone now gets the same new
answer".

**THE DIFF IS WRONG CODE, NOT A COSMETIC DIFFERENCE:**

    -       str     w2, [sp, -8]!        <- aarch64 does not PUSH arguments
    -       .cfi_def_cfa_offset 40
    +       str     w2, [sp, 8]
    -       str     w2, [sp, -8]!
    -       .cfi_def_cfa_offset 48
    +       str     w2, [sp]
    -       ldp     x29, x30, [sp, 32]
    -       add     sp, sp, 48
    +       ldp     x29, x30, [sp, 16]
    +       add     sp, sp, 32
    -       .cfi_def_cfa_offset -16      <- a NEGATIVE CFA offset
    +       .cfi_def_cfa_offset 0

i386's answer is normally 0 on x86_64-linux and aarch64's own is the constant
1, so aarch64 was being compiled in the **push-arguments-individually shape
it does not have**, and the epilogue CFI ended at `.cfi_def_cfa_offset -16'
-- an unwinder computing the CFA sixteen bytes BELOW the stack pointer.  Exit
0 throughout, as always.

**ASSEMBLED, DISASSEMBLED AND FRAME-DECODED with real aarch64 binutils**
(`pkgsCross.aarch64-multiplatform.buildPackages.binutils', named and asserted
first).  Correct AAPCS64 -- `w0'-`w7' plus `[sp]' and `[sp,#8]' -- and

    CIE  DW_CFA_def_cfa: r31 (sp) ofs 0     Return address column: 30
    FDE  advance 4; def_cfa_offset 32; offset r29 at cfa-16, r30 at cfa-8;
         advance 60; restore r29/r30; def_cfa_offset 0

**OBJECT LEVEL, BOTH DIRECTIONS** (`t132-obj.sh', `index ($0, f)' and an
empty-cut refusal):

    aarch64  mt_base_accumulate_outgoing_args   mov $0x1,%eax; ret
    i386     mt_base_accumulate_outgoing_args   mov 0x70(%rax),%rax <- cfun->machine
                                                mov 0xf0(%rax),%eax
                                                and $0x18000,%eax   <- func_type bits
                                                ... plus the option-state tests

i.e. i386 still reads that bitfield, at an offset that is now correct because
the TU declares i386's struct.  Eleven shared objects bind
`mt_accumulate_outgoing_args()'; `combine-stack-adj.o' binds **0**, and that
is not a miss -- see section 4.

## 3. THE NEIGHBOURS, WITH VERDICTS (recorded in `defaults.h' too)

**`ARG_POINTER_CFA_OFFSET' -- CORRECT TODAY FOR A REASON THAT DOES NOT
SCALE.**  Neither base defines it, so both reach `defaults.h:1219''s
`FIRST_PARM_OFFSET (FNDECL) + crtl->args.pretend_args_size', and
`FIRST_PARM_OFFSET' is the literal **0 in both** (i386.h:1661,
aarch64.h:1062).  The leak is real; its value happens to agree.  That is the
wrong-reason green PRINCIPLES names.  Nine back ends define it directly (rx
4, avr -1, pru non-constant, six others 0).  **Not converted, because with a
pair that agrees there is no measurement that could distinguish the fix from
the status quo.**  Recorded as UNMEASURABLE WITH THIS PAIR -- not clean.

**`FRAME_POINTER_CFA_OFFSET' -- CANNOT BECOME A CALL.  Position of use
decides shape.**  `#ifdef'-tested at six shared sites (function.cc:1466,
:1967; var-tracking.cc:9990, :10093, :10146, :10166, :10202;
dwarf2out.cc:21620).  Defining the name to a call makes every one of those
guards TRUE for every target -- the `#if HAVE_ATTR_length' failure in
reverse.  Only nvptx, vax and pa define it; neither base does, so all six are
FALSE and that is each base's own answer.  **What it needs is a build-time
union check** ("no configured base may define it unless they all agree"), not
a conversion.  Not written; it belongs with the other union-list checks.

**`dwarf2out.cc:21505-21509' -- THE ONLY DIRECT DEREFERENCE, AND NO REDIRECT
CAN FIX IT.**  Shared code reads `cfun->machine->fs.cfa_reg->u.reg.regno',
`.fs.fp_valid', `.fs.fp_offset', `.fs.sp_offset' -- i386's
`machine_frame_state', BY FIELD NAME.  There is no macro to redirect.  It is
inside `#ifdef CODEVIEW_DEBUGGING_INFO', defined only by
`config/i386/cygming.h', so it is **dead in this configuration** and in any
whose bases exclude cygming; it is not dead in general.  **The fix is a
target hook, i.e. a design decision, and I stopped rather than invent one.**

## 4. THE GUARDS -- A SECOND LEAK, LARGER, AND IT RUNS BOTH WAYS

PRINCIPLES says: when a symbol names your suspect, walk the GUARDS that
decided you reached that line.  `t132-sites.sh' classifies each use by its
own line, which answers "can this become a call?".  `t132-guardctx.sh' asks
the other question, and found two.

**`PUSH_ROUNDING' -- i386 DEFINES IT, aarch64 does NOT.**  13 of 51 back ends
define it; shared code asks `#ifdef PUSH_ROUNDING' at **19 sites** (expr.cc
x8, calls.cc, cse.cc, recog.cc, reload1.cc, lra-eliminations.cc, rtlanal.cc,
function.cc, targhooks.cc, combine-stack-adj.cc, defaults.h).  Two sit
directly over `ACCUMULATE_OUTGOING_ARGS' uses:

  * `targhooks.cc:913' -- `default_push_argument' is `return
    !ACCUMULATE_OUTGOING_ARGS;' inside `#ifdef PUSH_ROUNDING', a guard the
    PRIMARY makes true.  (My change does improve this site even under the
    wrong guard: aarch64 now gets `!1 = false' where it used to get
    `!0 = true', i.e. it no longer claims to push arguments.)
  * `combine-stack-adj.cc:842' -- inside `#ifndef PUSH_ROUNDING', so the test
    is **compiled OUT for every target**.  That is why `combine-stack-adj.o'
    binds the new selector 0 times; the 0 is real and is a finding, not a
    measurement failure.

`calls.o' also still carries `U ix86_push_rounding(poly_int<2u,long>)' and
`U ix86_reg_parm_stack_space(tree_node const*)', so `PUSH_ROUNDING' leaks as
a VALUE as well as an existence question.

**`STACK_DYNAMIC_OFFSET' -- AND THIS ONE RUNS THE OTHER WAY.**  **AARCH64
defines it** (aarch64.h:1688, the `-fstack-clash-protection' outgoing-args
reservation); **i386 does not**; `function.cc:1411' asks `#ifndef
STACK_DYNAMIC_OFFSET' and gets the PRIMARY's answer, so **aarch64's own
definition is discarded for every target** and function.cc's generic one is
used instead.  A leaked ABSENCE of the NON-primary base's answer -- the same
shape target-frame.h records for `INIT_EXPANDERS', and the same family as
`HAVE_V8HFmode' in that the primary/union answers where the selected base
should.  **Not fixed.  It is an existence predicate and wants the
`has_init_expanders' pair shape, which is a task.**

Also in that closure and unconverted: `REG_PARM_STACK_SPACE' (i386 defines,
aarch64 does not; guards `calls.cc:3571' and `:4598') and
`INCOMING_REG_PARM_STACK_SPACE' (neither defines).

## 5. THE BARS -- ALL IN `/tmp/b132', BEFORE AND AFTER IN THE SAME BUILD DIR

  * `make multi-target-objs cc1 lto1' in `$B/gcc' -- **rc=0**.
  * **x86_64 `-O2' big.c md5 `378fc33c1e70', 12369 bytes -- UNMOVED.**
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock', absolute `IN', 5
    distinct md5 per side, **negative control firing (1158 vs 804)**, and
    demonstrably in THIS build dir (`mt cfg :
    /tmp/b132/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config').
    O0 `1c00922491f8', O1 `4fabab94b41b', O2 `378fc33c1e70',
    O3 `d220421237bc', Os `d6787f7e281f'.
  * **aarch64 `int x = 1;' rc=0, 373 bytes, empty stderr, md5
    `b01d9157fdc1'** -- the recorded bar (`small.c'; `fn-data.c' is 375 /
    `0252fa95df03', differing only in the `.file' name), unmoved.
  * `fn-add' / `fn-call' / `fn-data' byte-identical on BOTH bases:
    aarch64 `28943da2efab' / `d4224a2c155d' / `0252fa95df03';
    x86_64 `f776a3b16e36' / `b9716cd03194' / `e2879feb51f6'.
  * `big.c' **unmoved**: `extract_insn, recog.cc:2890' during RTL pass `ira',
    on the same `(insn 34 33 0 3 (const_int 0 [0]))' #131 printed.  Stated as
    unmoved because the INSN was compared, not only the site.
  * **Incremental stderr 24 lines / 0 `warning:'**, all `'@' is redundant'
    from unmodified aarch64 `.md' -- within the documented 8-to-32 floor,
    composition stated, taken from a `make' no arm had touched a header
    before.  (A `defaults.h' edit rebuilds ~600 objects and gives 451 / 111;
    that is the cold-ish arm and is not comparable.)

## 6. WHAT I DID NOT DO

  * **The guard closure of section 4** -- `PUSH_ROUNDING' (19 existence sites
    plus a value), `STACK_DYNAMIC_OFFSET', `REG_PARM_STACK_SPACE'.  Named,
    measured, not touched.  `STACK_DYNAMIC_OFFSET' is the one I would take
    next: it is a single `#ifndef', it silently disables aarch64's
    stack-clash outgoing-args reservation, and the fix shape already exists.
  * **`ARG_POINTER_CFA_OFFSET'** -- deliberately, see section 3.  Converting
    a pair that agrees banks no evidence and cannot be shown to have worked.
  * **The `dwarf2out.cc' CODEVIEW hook** -- a design decision, stopped.
  * **`insn-emit' NOT TOUCHED**, per the brief: a forwarder scheme there
    decides `gen_movxf' by implication and needs the user's ruling.  Nothing
    here pre-empts it.
  * **The scoreboard was NOT run and I claim NO movement.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS
    / 104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64
    27/5**.  `ACCUMULATE_OUTGOING_ARGS' is not in `macro-status.txt', so the
    correct entry is **"no probe arm exists" -- unmeasurable, not clean**.
    It is an ordinary `tm.h' macro and DOES belong on the board; adding an
    arm for it, and for #131's three, is a task.
  * No compile-time or memory measurement.  `ACCUMULATE_OUTGOING_ARGS' is now
    an indirect call at ~40 sites, several of them in `expand_call''s inner
    loops.  Both bases' recorded artefacts are byte-identical, so this is
    throughput and not correctness, but it is unmeasured and I am not
    claiming it is free.  It joins `Pmode''s 648 sites (#125), #128's
    constraint indirection, #130's attribute indirection and #131's
    `FUNCTION_MODE'.
  * `make all-target-libgcc' not re-run; #119's `-m32' blocker unchanged (a
    plain top-level `make' still fails at `configure-target-libgcc').

## 7. INSTRUMENT NOTES

  * **The brief's warning about `awk '$0 ~ f'' was applied, not
    rediscovered** -- `t132-obj.sh' uses `index ($0, f)' and refuses on an
    empty cut.
  * **A `--exclude=ChangeLog*' is load-bearing in the OTHER direction here.**
    Every one of the nine CLEAN `ix86_*' macros has hits in `ChangeLog-*'
    files, which a naive "is it spelled outside config/?" scan reads as
    SHARED.  Without the exclusion the sweep reports 11 leaks instead of 2 --
    a false positive rather than a false negative, but it would have sent the
    next agent converting nine macros nothing uses.
  * **"Is this use in a preprocessor context?" and "is this use REACHED under
    a primary-decided guard?" are two arms, not one**, and the second found
    strictly more.  `t132-sites.sh' scored `combine-stack-adj.cc:842' as an
    ordinary code use, correctly; it is also dead code.  Running only the
    first arm would have converted the macro and left both `PUSH_ROUNDING'
    sites unexamined.
  * **An `nm' binding count of 0 can be a real finding rather than an
    instrument failure**, and the two are distinguished by having a reason:
    10 of 11 objects bound the symbol, so the 11th's 0 was investigated
    rather than dismissed, and it named a second bug.
  * **My own first build was contaminated**: an edit landed before the
    baseline was taken.  Caught, `target-frame.h' reverted, and the baseline
    re-measured on a rebuilt compiler before any AFTER reading.  The recorded
    bars all matched, which is what said the revert was complete.
  * **`t132-specs.sh' must run before any codegen arm.**  Without it every
    compile is `fatal error: no configuration file for target', which on
    first sight reads as a compiler bug and is not one.  It cost one arm.

## 8. FILES

    t132-clone.sh     derives my build-dir scripts from #131's; REFUSES on a
                      leftover `b132'
    t132-conf.sh      two-target configure, /tmp/b132
    t132-build.sh     make at the TOP level -- `all-gcc' goes here
    t132-gccbuild.sh  make in $B/gcc -- `multi-target-objs cc1 lto1' here
    t132-specs.sh     both target-specs probes, real aarch64 binutils
    t132-sweep.sh     ARM A: the eleven macros, DERIVED from i386.h, with a
                      FATAL if the derivation is empty, and a per-name
                      SHARED/CLEAN verdict
    t132-sites.sh     ARM B: every use site, tagged PREPROC vs code
    t132-neigh.sh     ARM C: the fallback bodies, FIRST_PARM_OFFSET, and
                      which base defines what
    t132-types.sh     ARM D: the GENERAL form -- every type name declared in
                      either base's header, intersected with shared code
    t132-obj.sh       ARM E: both-sided object-level values, index() not ~,
                      empty-cut refusal, nm non-vacuity floor
    t132-guardctx.sh  ARM F: the GUARDS over each use.  This is the arm that
                      found PUSH_ROUNDING and STACK_DYNAMIC_OFFSET
    t132-closure.sh   ARM G: per-base definedness of every guard macro
    t132-inject.sh    the injection: removes ONLY the defaults.h redirect,
                      sed not python3, state asserted in BOTH directions,
                      REFUSES to double-inject or to restore without a saved
                      original
    t132-outargs.sh   fn-outargs.c on both bases -- the input on which
                      ACCUMULATE_OUTGOING_ARGS is observable at all
    fn-outargs.c      ten arguments plus alloca; two args land on the stack
    t132-asm.sh       assemble + disassemble + decode .eh_frame with the REAL
                      aarch64 binutils, tools named and asserted first
    t132-state.sh     big.c site + `int x = 1;' + x86_64 -O2
    t132-fn.sh        the three #131 function-body inputs, both bases
    t132-sc.sh        stock-compare, ABSOLUTE big.c, tagged outdir

# TASK #133 -- `STACK_DYNAMIC_OFFSET': THE LEAK THAT RUNS THE OTHER WAY, FIXED
# AND MEASURED BOTH-SIDED IN A RUNNING cc1 -- PLUS ALL 19 `PUSH_ROUNDING'
# SITES CLASSIFIED AND NONE CONVERTED.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in' was **0**, `git reset --hard multi-target' took
it to **39**, no `scratchpad/'.  That is now TWELVE in a row.  Build dir
`/tmp/b133', my own, cold.  **The brief named no task numbers I could read**;
that is the coordinator's error and everything below is measured in
`/tmp/b133'.

## 1. JOB 1 -- THE FIX, AND WHY IT WAS A ONE-CALL CONVERSION

aarch64 DEFINES `STACK_DYNAMIC_OFFSET' (aarch64.h:1688); i386 does NOT; nine
back-end headers do.  `function.cc:1411' asked `#ifndef STACK_DYNAMIC_OFFSET'
in a translation unit compiled with i386's `tm.h', so the `#ifndef' was true,
**aarch64's definition was discarded for every target including aarch64**, and
function.cc's own generic ladder was used instead.

**THE DIRECTION IS THE POINT.**  Every previous entry in this family is "the
primary's answer reaches everyone".  This is "**the NON-primary's answer
reaches no one, itself included**" -- the `INIT_EXPANDERS' shape, where i386
defined nothing and aarch64's `init_machine_status' was never installed.  An
absence produces **no code at all**, so no instrument that looks for a wrong
symbol or a wrong value can see it; `nm' scores a discarded definition exactly
as it scores a correct one.  That is why this class keeps being found by
accident.

Four parts, the shape #131/#132 already established:

  * `target-frame.h'         -- `poly_int64 (*stack_dynamic_offset) (tree)'
  * `target-cumargs.cc'      -- `mt_base_stack_dynamic_offset', with BOTH ARMS
    OF function.cc's LADDER REPRODUCED INSIDE IT (and the
    `INCOMING_REG_PARM_STACK_SPACE'-from-`REG_PARM_STACK_SPACE' derivation
    that chooses between them), so the `#ifndef' is a fact about THIS base
  * `target-cumargs-select.cc' -- `mt_stack_dynamic_offset (tree)'
  * `function.cc'            -- the shared ladder DELETED; the existing
    wrapper `get_stack_dynamic_offset ()' now calls the selector

**NO `defaults.h' REDIRECT, deliberately.**  Upstream already funnels the
macro through `get_stack_dynamic_offset ()' (added 2023 "so that the macro
sees a predictable set of included files" -- the set of included files was the
bug).  It is the ONLY evaluation point in the tree, so the call goes there
directly and the name is left **undefined in shared code**: a future shared
spelling now fails BY NAME instead of quietly picking up a generic ladder.
Same treatment `mt_init_expanders' gave `#ifdef INIT_EXPANDERS'.

**REPRODUCING THE LADDER IS NOT THE `#ifndef' FLOOR PRINCIPLES FORBIDS.**  The
floor is forbidden because it makes a MISSING answer look like an answer.
Here 42 of 51 back ends genuinely have no definition and the generic ladder IS
their own headers' answer; what changed is which translation unit evaluates
it.  Same argument `mt_base_default_incoming_frame_sp_offset' records for
dwarf2cfi.cc's private `#ifndef'.

## 2. THE EVIDENCE, BOTH-SIDED, IN THE RUNNING cc1

**THE CODEGEN ARM CANNOT RUN ON aarch64, and that is a finding, not a gap.**
The aarch64 arm needs `flag_stack_clash_protection && cfun->calls_alloca'.
`t133-alloca-wall.sh' isolates it with four arms so it cannot be attributed to
the wrong flag:

    a64  alloca, no  -fstack-clash-protection   rc=0  765 bytes
    a64  alloca, YES -fstack-clash-protection   rc=1  WALL
    a64  no alloca,  YES -fstack-clash-protection   rc=0  666 bytes
    x86  all three                              rc=0  506 / 818 / 357

The wall is `error: unrecognizable insn: (insn 20 48 21 6 (unspec_volatile
[(const_int 0)] UNSPECV_GET_FPCR))' at pass `vregs'.  **That is the
un-namespaced `insn-emit' family printing i386's `gen_blockage' number through
aarch64's UNSPECV name table** -- #132's `big.c' suspect, now NAMED rather
than suspected, and out of scope per the brief.  **It is identical with this
task's change injected OFF**, so it is pre-existing and not caused here.

**SO THE READING WAS TAKEN IN gdb INSTEAD**, which the wall does not block:
the ICE is at `extract_insn', AFTER `instantiate_virtual_regs' has already
called `get_stack_dynamic_offset'.  `t133-sdo-cause.sh': ONE breakpoint per
run, matched against gdb's own `^Breakpoint N, get_stack_dynamic_offset' STOP
line AND the backtrace, `--args' not `gdb run', function.cc rebuilt at `-g3'.
Injection OFF and back ON in the SAME build dir (`t133-inject-sdo.sh', awk not
python3, state asserted in BOTH directions):

                        OFF (pre-#133)      ON (fixed)
    aarch64             coeffs = {0, 0}     coeffs = {16, 0}    CHANGED
    x86_64              coeffs = {0, 0}     coeffs = {0, 0}     unchanged

with the three gates read in the same stop: `flag_stack_clash_protection = 1',
`cfun->calls_alloca = 1', `crtl->outgoing_args_size = {0, 0}'.  **16 is
`ROUND_UP (STACK_CLASH_MIN_BYTES_OUTGOING_ARGS = 8, STACK_BOUNDARY/8 = 16)'**,
i.e. aarch64.h:1688 exactly.  The x86_64 column is what distinguishes "fixed"
from "everyone now gets the same new answer".

**WHAT WAS SILENTLY WRONG:** aarch64's reservation exists so `alloca' can SKIP
A PROBE.  Under the generic ladder it never happened, so
`-fstack-clash-protection' code with `alloca' was built without the space its
probing strategy assumes -- exit 0 throughout, as always.

**OBJECT LEVEL, BOTH DIRECTIONS** (`t133-obj.sh', `index ($0, f)', empty-cut
refusal, nm non-vacuity floor of 117318 undefined lines):

    aarch64  cmpl $0x0, flag_stack_clash_protection
             testb $0x2, 0xcc(cfun)          <- calls_alloca
             cmpq $0x0 / cmpq $0x7           <- known_lt (out_args_size, 8),
                                                a two-coefficient poly compare
             mov $0x10,%eax                  <- 16
    i386     mov 0x70(%rax),%rax             <- cfun->machine
             mov 0xf0(%rax),%eax
             and $0x18000,%eax               <- func_type bits, via
                                                ACCUMULATE_OUTGOING_ARGS
             call ...                        <- OUTGOING_REG_PARM_STACK_SPACE

**This is the first entry in the family where the fix makes code EXIST that
was not there before.**  The aarch64 body is 19 lines of instructions that no
object in the tree contained, because the macro that generates them had been
`#ifndef''d away.  `function.o' binds `U mt_stack_dynamic_offset(tree_node*)'
-- 1 object, and 1 is correct here rather than suspicious: there is exactly
one evaluation point.

## 3. JOB 2 -- ALL 19 `PUSH_ROUNDING' SITES CLASSIFIED, NONE CONVERTED

`t133-push-sites.sh' re-derives the list (41 shared mentions, 19 preprocessor
sites, 12 value sites).  Full verdicts are written into `defaults.h' beside
#132's neighbour verdicts, in five shapes:

  1. ordinary statements under the guard -- 11 sites, mechanical
     (calls.cc:5181, function.cc:4151, lra-eliminations.cc:798,
      reload1.cc:3030, recog.cc:1835, rtlanal.cc:4914, expr.cc:4300,
      expr.cc:4354, expr.cc:1639, cse.cc:5628, targhooks.cc:912)
  2. `#ifndef' over ordinary statements -- expr.cc:1679,
     combine-stack-adj.cc:841
  3. guard over a DECLARATION/DEFINITION -- expr.cc:108, expr.cc:5149;
     cannot become an `if', but needs no flag: define unconditionally
  4. guard over a MACRO DEFINITION -- expr.cc:1595 (`PUSHG_P'),
     defaults.h:916 (`PUSH_ARGS_REVERSED')
  5. `#endif' between an `if' and its `else' -- expr.cc:5384/:5424 and
     expr.cc:5620/:5624; a RESTRUCTURE, not a substitution

Three things the classification found that the count does not show:

  * **`targhooks.cc:912' is the default of an EXISTING target hook**
    (`default_push_argument'), and several SHAPE-1 sites already test
    `targetm.calls.push_argument (0)' INSIDE the `#ifdef'.  For those the
    existence question is ALREADY answered at run time and the `#ifdef' is a
    compile-time short circuit on top of it.  Converting that one line closes
    more of this family than its size suggests.
  * **`combine-stack-adj.cc:841' is compiled out for every target** (#132's
    finding, re-confirmed).  Converting it TURNS A PASS GATE ON for the 38
    back ends with no `PUSH_ROUNDING'.  It is the only site whose conversion
    changes pass behaviour rather than a value and it wants its own
    before/after.
  * **A TYPE DECISION, NOT A TRANSCRIPTION.**  recog.cc:1836 spells
    `PUSH_ROUNDING (MACRO_INT (rounded_size))'; `MACRO_INT' is
    `.to_constant ()' when `NUM_POLY_INT_COEFFS > 1', and it exists because
    some back ends' macros are not poly-safe.  A `poly_int64
    mt_push_rounding (poly_int64)' removes the wrapper at the shared sites but
    the per-base thunk must keep it.  Decide the signature once for all 12
    value sites.

**AND A LEAK FOUND IN THE CLOSURE, CHEAPER THAN ANY OF THEM.**
`PUSH_ARGS_REVERSED': i386.h:1658 defines it to 1, aarch64 does not, bpf and
nvptx do.  Its only shared use is gimplify.cc:4791-4793 -- three ordinary
run-time expressions in one `for' header -- so **argument gimplification runs
last-to-first for every target because the primary says so**.  No preprocessor
use anywhere; SHAPE 1, one file.  Recorded, not taken.

`REG_PARM_STACK_SPACE' still leaks: `function.o' binds
`U ix86_reg_parm_stack_space(tree_node const*)' even AFTER this task, because
function.cc:2327 spells `INCOMING_REG_PARM_STACK_SPACE' separately from the
ladder that moved out.  PRINCIPLES' "one symbol can have several macro paths",
measured again.

## 4. THE BARS -- ALL IN `/tmp/b133', AFTER THE FINAL REBUILD

  * `make multi-target-objs cc1 lto1' in `$B/gcc' -- **rc=0**.
  * **x86_64 `-O2' big.c md5 `378fc33c1e70', 12369 bytes -- UNMOVED**, before
    and after, same build dir.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock', ABSOLUTE `IN', 5
    distinct md5 per side, **negative control firing (1158 vs 804)**, and
    demonstrably in THIS build dir (`mt cfg :
    /tmp/b133/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config').
    O0 `1c00922491f8', O1 `4fabab94b41b', O2 `378fc33c1e70',
    O3 `d220421237bc', Os `d6787f7e281f'.
  * **aarch64 `int x = 1;' rc=0, 373 bytes, empty stderr, md5 `b01d9157fdc1'**
    -- the recorded bar (`small.c'; `fn-data.c' is 375 / `0252fa95df03',
    differing only in the `.file' name), unmoved.
  * `fn-add' / `fn-call' / `fn-data' byte-identical on BOTH bases:
    aarch64 `28943da2efab' / `d4224a2c155d' / `0252fa95df03';
    x86_64 `f776a3b16e36' / `b9716cd03194' / `e2879feb51f6'.
  * `big.c' **unmoved**: `extract_insn, recog.cc:2890'.
  * Stderr: **incremental `multi-target-objs cc1 lto1' = 0 lines / 0
    `warning:'** on a run whose sources no arm had touched.  The `defaults.h'
    comment edit rebuilds ~600 objects and gives **451 lines / 111
    `warning:'** -- that is the cold-ish arm and is NOT comparable with the
    8-to-32 incremental floor.  Cold `all-gcc' was **776 / 169**.

## 5. WHAT I DID NOT DO

  * **No `PUSH_ROUNDING' site converted**, per the brief: classify first.  The
    classification is the deliverable and it is in `defaults.h' by site.
  * **`PUSH_ARGS_REVERSED' not converted** -- found, named, one file.
  * **`REG_PARM_STACK_SPACE' / `INCOMING_REG_PARM_STACK_SPACE' not converted.**
  * **`insn-emit' NOT TOUCHED.**  This task NAMED its wall
    (`UNSPECV_GET_FPCR' on `alloca' + `-fstack-clash-protection', aarch64) and
    stopped: a forwarder scheme there decides `gen_movxf' by implication and
    needs the user's ruling.  Note this wall is now the thing standing between
    `STACK_DYNAMIC_OFFSET' and an assembly-level arm, so the two are coupled.
  * **`dwarf2out.cc:21505' CODEVIEW hook** -- design decision, untouched.
  * **`ARG_POINTER_CFA_OFFSET'** -- still UNMEASURABLE WITH THIS PAIR (#132).
  * **The scoreboard was NOT run and I claim NO movement.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS /
    104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64 27/5**.
    `STACK_DYNAMIC_OFFSET' is not in `macro-status.txt', so the correct entry
    is **"no probe arm exists" -- unmeasurable, not clean**.  It is an
    ordinary `tm.h' macro and DOES belong on the board.  The backlog of
    macros converted with no probe arm is now
    `INCOMING_FRAME_SP_OFFSET', `DEFAULT_INCOMING_FRAME_SP_OFFSET',
    `FUNCTION_MODE' (#131), `ACCUMULATE_OUTGOING_ARGS' (#132) and
    `STACK_DYNAMIC_OFFSET' (#133) -- **five**, and adding those five arms is
    now a task in its own right rather than a footnote.
  * No compile-time or memory measurement.  `STACK_DYNAMIC_OFFSET' is one
    indirect call per function at `instantiate_virtual_regs', which is the
    cheapest of any conversion so far; it is still unmeasured.
  * `make all-target-libgcc' not re-run; #119's `-m32' blocker unchanged.

## 6. INSTRUMENT NOTES

  * **MY OWN INJECTION GUARD WAS WRONG IN THE SAFE DIRECTION, AND THAT IS THE
    ONLY REASON I SAW IT.**  `t133-inject-sdo.sh' asserted "the redirect is
    gone" with `grep -c mt_stack_dynamic_offset', which also matches the
    **comment** naming the function.  The injection had in fact succeeded; the
    assertion failed anyway and refused to proceed.  Had I written the
    complementary check the same way it would have passed on a FAILED
    injection.  The fix is to match the CALL (`return mt_stack_dynamic_offset')
    and not the name.  Generalise: **an assertion on a symbol name matches the
    prose about the symbol too**, and prose is exactly what these files are
    full of.
  * **A WALL CAN BE THE MEASUREMENT'S PROBLEM RATHER THAN THE PATCH'S, AND THE
    WAY TO TELL IS A 2x2.**  `-fstack-clash-protection' + `alloca' walls on
    aarch64; running only that one arm would have read as "this task broke
    aarch64".  Four arms (alloca x clash x base) placed it exactly, and the
    injected-OFF run reproduced it byte for byte.
  * **THE ICE SITE WAS UPSTREAM OF THE READING I WANTED, WHICH IS WHY gdb
    WORKED.**  `get_stack_dynamic_offset' is called at
    `instantiate_virtual_regs'; the ICE is later, at `extract_insn'.  A
    "compile it and diff the assembly" arm scores that as unmeasurable; a
    breakpoint reads it fine.  **When codegen is blocked, ask whether the
    value you want is computed BEFORE the block.**
  * **`nm -C` scored the aarch64 thunk in x86-64 opcodes, correctly.**  Both
    per-base `target-cumargs-<base>.o' are HOST objects (x86-64), one
    per back end -- the aarch64 one contains x86-64 code implementing
    aarch64's ANSWERS.  Reading `mov $0x10,%eax' there is the reading, not a
    sign of a mixed-up object.
  * **The per-base objects are `target-cumargs-<base>.o' in `$B/gcc', NOT
    `mt-<base>/target-cumargs.o'.**  My first arm looked in `mt-<base>/', got
    "no such file", and would have reported "no per-base copy exists" -- the
    exact false negative PRINCIPLES warns about -- had it not had a FATAL
    instead of a silent skip.

# TASK #134 -- `PUSH_ARGS_REVERSED' CONVERTED WITH A BEHAVIOURAL BOTH-SIDED ARM
# (aarch64 CHANGES, x86_64 BYTE-IDENTICAL), AND `REG_PARM_STACK_SPACE'S SECOND
# PATH CLOSED WITH ALL FOUR PATHS ENUMERATED AND VERDICTED.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c MULTI_TARGET
gcc/Makefile.in' was **0**, `git reset --hard multi-target' took it to **39**,
no `scratchpad/'.  THIRTEEN in a row.  Build dir `/tmp/b134', my own, cold.
**The brief named no task numbers I could read**; that is the coordinator's
error and everything below is measured in `/tmp/b134'.

## 1. JOB 1 -- `PUSH_ARGS_REVERSED', AND THE LADDER WAS THREE LEAKS NOT ONE

i386.h:1658 defines it to `1'; aarch64 does not; bpf and nvptx do.  Only
shared use: gimplify.cc:4791-4793, three run-time expressions in one `for'
header -- **so every target's call arguments were gimplified last-to-first
because the primary says so.**

The part the brief did not have: `defaults.h:915-928' is not a constant
fallback, it is a LADDER --

    #ifdef PUSH_ROUNDING
    # if defined (STACK_GROWS_DOWNWARD) != defined (ARGS_GROW_DOWNWARD)
    #  define PUSH_ARGS_REVERSED targetm.calls.push_argument (0)
    # endif
    #endif
    #ifndef PUSH_ARGS_REVERSED
    # define PUSH_ARGS_REVERSED 0
    #endif

and `PUSH_ROUNDING', `STACK_GROWS_DOWNWARD' and `ARGS_GROW_DOWNWARD' are ALL
per-base.  **Three leaks in one ladder**, closed together.

Four parts, the #131/#132/#133 shape:

  * `target-frame.h'          -- `bool (*push_args_reversed) (void)'
  * `target-cumargs.cc'       -- `mt_base_push_args_reversed'.  **The ladder
    is NOT reproduced here**, unlike `STACK_DYNAMIC_OFFSET''s: that one lived
    in a `.cc' file's private preprocessor block with nothing to include,
    whereas this one is in `defaults.h', which this file already includes with
    `MULTI_TARGET_TARGETM_BASE' defined.  The ladder has therefore already run
    against THIS base's headers and the thunk just reads the macro.
  * `target-cumargs-select.cc' -- `mt_push_args_reversed ()'
  * `defaults.h'              -- `#undef' then redirect, beside
    `ACCUMULATE_OUTGOING_ARGS'

`? true : false' and not a cast: the three spellings are `1' (int), `0' (int)
and `targetm.calls.push_argument (0)' (bool).

## 2. THE BEHAVIOURAL ARM -- THE POINT OF THE TASK

Evaluation order is observable, so a value arm would not have been enough.
`scratchpad/t134-order.sh' on

    extern int f (void), g (void), h (int, int);
    int t (void) { return h (f (), g ()); }

at `-O0 -fno-inline' (NOT -O2: the scheduler can reorder two calls there and a
difference would not be attributable).  Redirect injected OFF and back ON in
the SAME build dir (`t134-par-inject.sh', sed not python3, state asserted in
both directions, matching the `#undef'/`#define' LINES and not the symbol name
-- #133 recorded that a name assertion also matches the prose):

                    OFF (pre-#134)          ON (fixed)
    aarch64         `bl g' then `bl f'      `bl f' then `bl g'    CHANGED
                    md5 0cbc679b3ec0        md5 364bcdc7b2fc
    x86_64          md5 7f363194d339        md5 7f363194d339      BYTE-IDENTICAL

**The x86_64 column is what separates "fixed" from "everyone now gets the same
new answer".**  The restore was rebuilt and reproduced `364bcdc7b2fc' exactly,
so the ON reading is not a one-off.

**ASSEMBLY ARM AVAILABLE HERE AND RUN** (`t134-asm.sh', real
`pkgsCross.aarch64-multiplatform.buildPackages.binutils', tools named and
asserted first).  The aarch64 output assembles and disassembles to real
aarch64 machine code -- `stp x29, x30, [sp, #-32]!' / `bl f' / `bl g' /
`bl h' -- and `readelf --debug-dump=frames' decodes a correct CFA:
`DW_CFA_def_cfa: r31 (sp) ofs 0', then x29/x30 at cfa-32/-24 and x19 at
cfa-16.  This input has no `alloca', so it does not meet #133's
`UNSPECV_GET_FPCR' wall.

Object level: `gimplify.o' binds `mt_push_args_reversed' once.  The two thunks
DIFFER and are readable: i386 `mov $0x1,%eax; ret', aarch64
`xor %eax,%eax; ret'.

## 3. JOB 2 -- `REG_PARM_STACK_SPACE': FOUR PATHS, ONE CLOSED, VERDICTS FOR ALL

**Two paths was NOT all of them.**  Enumerated from the source by
`t134-rpss.sh' (not from memory), verdict for each including the fine ones:

  1. `function.cc:1403' + `:2322' -- the `INCOMING_REG_PARM_STACK_SPACE'
     derivation and the `#ifdef' over `all->reg_parm_stack_space'.
     **CLOSED HERE.**  Both moved into `target-cumargs.cc'; the name is now
     UNDEFINED in shared code, so a future spelling fails by name.
  2. `calls.cc' -- **ELEVEN** `#ifdef REG_PARM_STACK_SPACE' sites (:174,
     :1096, :2793, :2885, :3568, :4014, :4257, :4272, :4597, :4945, closing
     :1194) plus two value sites (:2886, :4273).  **OPEN**; `calls.o' still
     binds `U ix86_reg_parm_stack_space'.  Several `#ifdef's span whole
     blocks, so this is `PUSH_ROUNDING' SHAPE 2/5 work, not a redirect.
  3. `expr.cc:2192/:2198' -- `#if defined' plus a value use.  **OPEN**;
     `expr.o' binds the symbol.
  4. `target-cumargs.cc:683-686' and `:745-748' -- the two per-base
     derivations.  **CORRECT BY CONSTRUCTION**, compiled once per back end
     with that back end's `tm.h'.  Stated rather than omitted.
  Plus five COMMENT-only mentions (cse.cc:4263, function.cc:2549/:4017/:4019,
  function.h:574) -- fine.

Evidence, both-sided:
  `function.o'  `U ix86_reg_parm_stack_space' **1 -> 0**, and it now binds
                `mt_incoming_reg_parm_stack_space' once.
  `calls.o'/`expr.o'  still 1 each -- the instrument can see the symbol, so
                the 0 is a finding and not a blind spot.
  thunks        i386 = tail `jmp' to `ix86_reg_parm_stack_space'
                (R_X86_64_PLT32, read off `objdump -dr');
                aarch64 = `xor %eax,%eax; ret'.

**A VALUE ARM CANNOT DISTINGUISH THE TWO ON THIS PAIR, AND SAYING SO IS THE
RESULT.**  `ix86_reg_parm_stack_space' returns 32 only for `TARGET_64BIT &&
MS_ABI' and 0 otherwise, so the value aarch64 was leaked is 0 -- exactly what
its own absence produces.  The bug was never the number: it was
`ix86_function_abi' being handed an aarch64 `FUNCTION_DECL' and reading i386's
option state about it.  **Correct by luck**, the `Pmode' trap running the
other way, which is why the evidence is the tail-jmp and the symbol count.

**The `#ifdef' arm is not floored over.**  `assign_parms_initialize_all' does
`memset (all, 0, sizeof (*all))' four lines above, so "macro undefined" and
"macro yielded 0" already produced the same state at the ONE site.

## 4. THE BARS -- ALL IN `/tmp/b134', ON THE FINAL BINARY

  * `make multi-target-objs cc1 lto1' in `$B/gcc' -- **rc=0**.
  * **x86_64 `-O2' big.c md5 `378fc33c1e70', 12369 bytes -- UNMOVED**, before
    and after, same build dir.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock', ABSOLUTE `IN', 5
    distinct md5 per side, **negative control firing (1158 vs 804)**, in THIS
    build dir (`mt cfg :
    /tmp/b134/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config').
    O0 `1c00922491f8', O1 `4fabab94b41b', O2 `378fc33c1e70',
    O3 `d220421237bc', Os `d6787f7e281f'.
  * **aarch64 `int x = 1;' rc=0, 373 bytes, empty stderr, md5 `b01d9157fdc1'**
    -- unmoved.
  * `fn-add'/`fn-call'/`fn-data' byte-identical on BOTH bases:
    aarch64 `28943da2efab'/`d4224a2c155d'/`0252fa95df03';
    x86_64 `f776a3b16e36'/`b9716cd03194'/`e2879feb51f6'.
    (`fn-call' has ONE argument, so it cannot see the order change -- which is
    why `order.c' exists.)
  * `big.c' **unmoved**: `extract_insn, recog.cc:2890'.
  * Both `specs-config' 230 lines, both targets probed with real aarch64
    binutils.
  * Stderr: **incremental `multi-target-objs cc1 lto1' = 0 lines / 0
    `warning:'** on a run no arm had touched a header before; the `defaults.h'
    comment edit rebuilds ~600 objects and gives **451 / 111**, the cold-ish
    arm, matching #133 exactly and NOT comparable with the 8-to-32 incremental
    floor.  Cold `all-gcc' **776 / 169**, also matching #133.

## 5. WHAT I DID NOT DO

  * **No `PUSH_ROUNDING' site converted.**  #133's five-shape classification
    stands untouched.  `PUSH_ARGS_REVERSED' was SHAPE 4 in it (a guard over a
    macro definition); it converted without touching `PUSH_ROUNDING' because
    the guard is `defaults.h''s own and the redirect displaces it whole.
  * **`calls.cc' and `expr.cc' `REG_PARM_STACK_SPACE' paths NOT converted** --
    enumerated and verdicted, above.  Thirteen sites in one file, several of
    them block-spanning.
  * **`insn-emit' NOT TOUCHED.**  #133's `UNSPECV_GET_FPCR' wall (`alloca' +
    `-fstack-clash-protection', aarch64) was not met by this task's inputs and
    nothing here pre-empts the `gen_movxf' ruling.
  * **`dwarf2out.cc:21505' CODEVIEW hook** -- design decision, untouched.
  * **THE SCOREBOARD WAS NOT RUN AND I CLAIM NO MOVEMENT.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS /
    104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64 27/5**.
    **`PUSH_ARGS_REVERSED' IS on the board and its aarch64 arm WILL flip
    FAIL -> PASS on the next run FOR THE WRONG REASON** -- the base-B redirect
    shape, both sides expanding to `(mt_push_args_reversed ())'.  Retire it;
    do not bank it.  It stays `UNCONVERTED' in `macro-status.txt' because it
    is a CALL and `tab-probe.sh' reads constants; the note is recorded there
    beside #108's and #124's.  `INCOMING_REG_PARM_STACK_SPACE' is not on the
    board at all -- **unmeasurable, not clean**.  The converted-without-an-arm
    backlog is now **SEVEN**.
  * No compile-time or memory measurement.  `PUSH_ARGS_REVERSED' is three
    indirect calls per call expression in gimplify.cc, which is the busiest
    site any conversion has taken so far; the recorded artefacts are
    byte-identical on both bases, so this is throughput, not correctness, and
    I am not claiming it is free.
  * `make all-target-libgcc' not re-run; #119's `-m32' blocker unchanged.

## 6. INSTRUMENT NOTES

  * **THE FALLBACK WAS A LADDER AND THE BRIEF DESCRIBED IT AS A CONSTANT.**
    Had the thunk been written to "just return the base's macro" without
    checking WHERE that macro comes from, it would still have been right --
    but only by accident, and only because `target-cumargs.cc' includes
    `defaults.h' with `MULTI_TARGET_TARGETM_BASE' defined.  The reason to
    check is that the OTHER convertible shape (copy the ladder, as #133 had
    to) would have been WRONG here: it would have re-evaluated
    `targetm.calls.push_argument' in a second place.  **Ask which side of the
    `MULTI_TARGET_TARGETM_BASE' guard the fallback lives on before deciding
    whether to copy it.**
  * **`-O0' IS PART OF THE MEASUREMENT, NOT A CONVENIENCE.**  At `-O2' the two
    calls can be reordered by passes that have nothing to do with this macro,
    so a difference there is unattributable and an ABSENCE of difference is
    equally so.  The arm states the flag and why.
  * **A NON-VACUITY REFUSAL ON THE INPUT, not just on the tool.**
    `t134-order.sh' refuses to score if either `f' or `g' is missing from the
    `.s'.  An empty or truncated assembly file otherwise scores as "no
    difference", which is the direction that reads as "nothing was broken".
  * **THE `0' IN `function.o' WAS CHECKED AGAINST TWO OBJECTS THAT STILL SAY
    `1'.**  `calls.o' and `expr.o' binding `ix86_reg_parm_stack_space' is what
    makes `function.o''s zero a finding rather than a demangling failure.
    `index ($0, f)' throughout, never `$0 ~ f'.
  * **A CORRECT-BY-LUCK VALUE IS THE HARDEST KIND TO REPORT.**  The honest
    verdict for `INCOMING_REG_PARM_STACK_SPACE' on this pair is "the value arm
    cannot discriminate, because both answers are 0" -- not a pass.  The
    discriminating evidence is which FUNCTION computes it.

## 7. FILES

    t134-*.sh          derived from #133's, /tmp/b134
    t134-par-inject.sh the PUSH_ARGS_REVERSED redirect, off/on, state asserted
                       in both directions against the LINES not the name
    t134-order.sh      THE BEHAVIOURAL ARM -- h (f (), g ()) at -O0, both
                       bases, call order derived from the .s, vacuity refusal
    t134-rpss.sh       JOB 2 -- object-level both-sided evidence AND the
                       enumeration of every REG_PARM_STACK_SPACE path with a
                       verdict for each, derived from the source

# TASK #135 -- `REG_PARM_STACK_SPACE' CLOSED IN FULL (all four paths), AND
# `PUSH_ROUNDING' CONVERTED IN FULL (19 preprocessor + 12 value sites), WITH A
# BEHAVIOURAL ARM ON THE ONE SITE THAT IS A PASS GATE.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in' **0**, `git reset --hard multi-target' took it
to **39**, no `scratchpad/'.  FOURTEEN in a row.  Build dir `/tmp/b135', my
own, cold.  **The brief named no task numbers I could read**; per PRINCIPLES
section 7 that is the coordinator's error and everything below is measured.

A SECOND CONFIGURE FACT, which cost one full build: `--enable-backends'
alone is no longer enough.  The top level now REFUSES with
`--enable-targets=LIST is required', by name, which is the refusal working --
but #111's build script (which every later `tNNN-build.sh' is a copy of)
passes only `--enable-backends' and therefore cannot configure this tree any
more.  `scratchpad/t135-build.sh' passes both plus `--prefix=$D' (the last is
what puts `specs-config' where `stock-compare.sh' looks for it).

## 1. JOB 1 -- `REG_PARM_STACK_SPACE', LAST TWO PATHS, CLOSED

`calls.cc' (11 `#ifdef' + 2 value) and `expr.cc:2192/:2198'.  All thirteen
were classified before any was converted, and they are NOT one shape:

  * :174, :1096, :1194 -- guard over a DECLARATION / DEFINITION.  Dropped.
  * :2793, :4257 -- guard over LOCAL VARIABLES.  Now unconditional, with
    `low_to_save'/`high_to_save' INITIALISED: with the guard gone the
    compiler can no longer see they are written before read.
  * :2885/:2886, :4272/:4273 -- value.  `mt_reg_parm_stack_space (...)'.
  * :3568, :4597 -- `if (mt_has_reg_parm_stack_space () && ...)'.
  * :4014, :4945 -- NO test added: `save_area' is non-null only if the save
    ran, so the value already answers the existence question.

**TWO SLOTS, NOT ONE, AND THE REASON IS A BEHAVIOUR DIFFERENCE THIS PAIR
CANNOT SHOW.**  `save_fixed_argument_area' does `high = reg_parm_stack_space;
if (ARGS_GROW_DOWNWARD) high += 1;', so on an args-grow-downward back end a
ZERO value still inspects `stack_usage_map[0]' whereas an undefined macro
never calls the function at all.  Collapsing "defined and 0" into "absent"
would have changed behaviour for pa/gcn/stormy16 silently.  Neither
configured base grows args downward -- **found by reading the callee, not by
measuring**, which is the only way it could have been found here.

Evidence, both-sided (`t135-obj.sh'):
  `calls.o' `U ix86_reg_parm_stack_space' **1 -> 0**
  `expr.o'  same **1 -> 0**
  and in the SAME run `ix86_push_rounding' still scored 1 in seven objects,
  so the zeroes are findings and not demangling failures.
  Thunks: i386 `mt_base_has_reg_parm_stack_space' = `mov $0x1,%eax; ret',
  value = `call ix86_reg_parm_stack_space' (R_X86_64_PLT32); aarch64 =
  `mov $0x0,%eax; ret' twice.  **The EXISTENCE answer is what differs**; the
  value is 0 on both sides, which is #134's carried honest negative
  re-confirmed rather than re-derived.

`#undef REG_PARM_STACK_SPACE' added to `defaults.h', and recorded there as
WEAKER THAN A REDIRECT: a re-introduced value use fails by name, a
re-introduced `#ifdef' silently reads FALSE for every target.

## 2. JOB 2 -- `PUSH_ROUNDING', ALL 31 SITES

Signature decided once: `poly_int64 mt_push_rounding (poly_int64)', with
`MACRO_INT' moved INTO the per-base thunk.  **Seven live definitions, not
thirteen** -- sh's is in `#if 0', six more are commented out; five of the
seven already take/return `poly_int64', two are the identity.  The rejected
alternative (`HOST_WIDE_INT') would have put `.to_constant ()' into shared
code at four sites.

`function.cc:4151' is the one value site kept non-poly on purpose: it feeds
`size_int' from `TREE_INT_CST_LOW' and was never poly.

**THE PASS GATE, AND BOTH HALVES OF THE READING MATTER**
(`t135-gate.sh' / `t135-gate-inject.sh'; `-fdump-rtl-csa', i.e. THE
COMPILER'S OWN report the pass ran, injected off and back on in ONE dir):

                    OFF (pre-#135)        ON (#135)
    aarch64         csa dump, 273 lines   NO csa dump        CHANGED
    x86_64          csa dump, 233 lines   csa dump, 233      unchanged

    assembly        aarch64 `be8a7f14b637', x86_64 `0b156589647b'
                    -- BYTE-IDENTICAL on both bases, both ways.

So: the gate moved, and the code did not.  aarch64 now skips
`combine_stack_adjustments', which is what an aarch64-only GCC does
(`#ifndef PUSH_ROUNDING' is true there), so the conversion RESTORES upstream
behaviour for 38 back ends.  **No codegen claim is made** -- on this input
the pass found nothing, and calling the dump difference a codegen difference
would be the overclaim this project keeps catching.

Object level: `ix86_push_rounding' **1 -> 0** in all seven objects that bound
it; `mt_has_push_rounding' bound by ten.  i386 thunk `mov $0x1,%eax' +
`call ix86_push_rounding'; aarch64 `mov $0x0,%eax' + identity.

**THE `#undef' THAT COULD NOT BE DONE -- A NEW SHAPE, AND THE MAIN FINDING OF
THIS TASK.**  `#undef PUSH_ROUNDING' builds `libbackend' clean and then fails
with 15 errors in `insn-emit-1.cc' / `insn-emit-5.cc':

    config/i386/mmx.md:430, :641;  config/i386/i386.md:2221, :2313, :3884
    error: 'PUSH_ROUNDING' was not declared in this scope

Those are `define_split' preparation statements -- BACK-END code -- but the
`insn-emit-*.o' family is the un-namespaced one: compiled once, shared,
without `MULTI_TARGET_TARGETM_BASE', with every back end's patterns in it.
**Every macro retired before this one was spelled only by files under
`gcc/'.  `PUSH_ROUNDING' is the first whose consumers are all converted while
its NAME must stay defined for a supply-side file compiled as if it were
shared.**  Recorded in `defaults.h' rather than worked around; the
`insn-emit' forwarder scheme needs the `gen_movxf' ruling.
`REG_PARM_STACK_SPACE' CAN be `#undef'ed and is -- measured in the same
build, which is what makes this a property of `PUSH_ROUNDING' rather than of
the `#undef'.

## 3. `STACK_GROWS_DOWNWARD' / `ARGS_GROW_DOWNWARD' -- REPORTED, NOT TAKEN

The other two names in #134's `PUSH_ARGS_REVERSED' ladder.

  * `#if'-TESTED, not `#ifdef'-tested, at THIRTEEN shared sites (explow.cc
    :1786; builtins.cc :5477, :5610, :5700, :5735; recog.cc:48; rtlanal.cc
    :372, :582, :586, :594, :606, :610, :618, :629), several NESTED.  A
    call-valued macro evaluates to 0 in `#if' -- the `#if HAVE_ATTR_length'
    failure, and the same verdict `FRAME_POINTER_CFA_OFFSET' carries.
  * Genuinely per-base: 46 headers define `STACK_GROWS_DOWNWARD 1' (pa's is
    commented out); exactly three define `ARGS_GROW_DOWNWARD 1' (pa, gcn,
    stormy16).
  * **BUT THEY AGREE ON THIS PAIR** -- i386 and aarch64 are both
    down/up -- so no arm built here could distinguish a conversion from the
    status quo.  UNMEASURABLE WITH THIS PAIR, like `ARG_POINTER_CFA_OFFSET'.
  * `defaults.h:533' mixes the spellings (`#ifdef' for
    `DWARF_CIE_DATA_ALIGNMENT' where everything else uses `#if').  Checked:
    no back end defines the name to 0, so the two do not currently disagree.
    Fragile, not wrong -- stated because the obvious reading is that it is a
    bug.

## 4. THE BARS -- ALL IN `/tmp/b135', ON THE FINAL BINARY

  * `make all-gcc' -- rc=0.
  * **x86_64 `-O2' big.c md5 `378fc33c1e70', 12369 bytes -- UNMOVED.**
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock', ABSOLUTE `IN', 5
    distinct md5 per side, **negative control firing (1158 vs 804)**, in THIS
    build dir (`mt cfg : /tmp/b135/lib/gcc/17.0.0/x86_64-pc-linux-gnu/
    specs-config').  O0 `1c00922491f8', O1 `4fabab94b41b', O2 `378fc33c1e70',
    O3 `d220421237bc', Os `d6787f7e281f'.  Run twice: after JOB 1 and again
    after JOB 2.
  * **aarch64 `int x = 1;' rc=0, 373 bytes, empty stderr, `b01d9157fdc1'.**
  * `fn-add'/`fn-call'/`fn-data' byte-identical on BOTH bases, all six md5s
    equal to #134's.
  * `big.c' reports **`extract_insn, recog.cc:2892'** where #134 recorded
    `:2890'.  **SAME SITE** -- this task added a two-line comment above it in
    `recog.cc'.  A "wall moved" that is a line number, checked rather than
    reported as movement.
  * Both `specs-config' 230 lines; `check-spec-refs: 2 spec file(s)',
    `check-target-caps: 2 config file(s)',
    `check-multi-target-specs: 2 spec file(s) ... 0 rejected'.
  * Stderr on the final incremental `all-gcc': **24 "'@' is redundant" from
    unmodified aarch64 `.md' files, 0 `is unchanged', 0 `warning:', 0
    errors** -- within the documented 32-line incremental floor and matching
    its composition.  NOTE the driver merges stdout and stderr, so that is a
    count over the combined stream.

## 5. WHAT I DID NOT DO

  * **The scoreboard was NOT run and I claim NO movement.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS
    / 104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64
    27/5**.  `PUSH_ROUNDING' and `REG_PARM_STACK_SPACE' are both `#ifdef'-
    shaped and therefore not on the board as ordinary value arms; neither is
    `INCOMING_REG_PARM_STACK_SPACE'.  **The converted-without-an-arm backlog
    is now NINE** (`INCOMING_FRAME_SP_OFFSET',
    `DEFAULT_INCOMING_FRAME_SP_OFFSET', `FUNCTION_MODE',
    `ACCUMULATE_OUTGOING_ARGS', `STACK_DYNAMIC_OFFSET', `PUSH_ARGS_REVERSED',
    `INCOMING_REG_PARM_STACK_SPACE', `REG_PARM_STACK_SPACE',
    `PUSH_ROUNDING') and is well past being a footnote.  A probe shape for
    EXISTENCE macros does not exist yet and is the thing to design.
  * **`insn-emit' NOT TOUCHED**, and this task now has a concrete reason to
    want it fixed rather than a general one: it is what blocks
    `#undef PUSH_ROUNDING'.
  * `STACK_GROWS_DOWNWARD' / `ARGS_GROW_DOWNWARD' not converted (section 3).
  * `dwarf2out.cc:21505' CODEVIEW hook -- design decision, untouched.
  * No compile-time or memory measurement.  `mt_has_push_rounding ()' is now
    called on paths as hot as `push_operand' (recog) and
    `nonzero_bits' (rtlanal); the artefacts are byte-identical so this is
    throughput, not correctness, and it is UNMEASURED.
  * `make all-target-libgcc' not re-run; #119's `-m32' blocker unchanged.
  * No `alloca' / `-fstack-clash-protection' arm: #133's `UNSPECV_GET_FPCR'
    wall is unchanged and this task's inputs do not reach it.

## 6. INSTRUMENT NOTES

  * **MY SED INJECTION MARKED ITS LINE WITH A C COMMENT AND THE RESTORE THEN
    COULD NOT FIND IT.**  Backslash-slash-star in a sed REGEX is "zero or
    more slashes", so `off' applied cleanly and `on' failed to match its own
    marker.  The refusal caught it -- but only because the restore ASSERTS
    its result; a restore that checked nothing would have left the pre-#135
    state in the tree and every later reading would have been of the wrong
    compiler.  The marker is now `// INJECTED pre-135'.
  * **`-fdump-rtl-csa' IS THE RIGHT INSTRUMENT FOR A PASS GATE AND THE
    ASSEMBLY IS NOT.**  The assembly is byte-identical on both sides here; an
    assembly-only arm would have scored the gate change as "no difference",
    which reads as "the conversion did nothing".  The dump file's EXISTENCE
    is the compiler saying whether the pass ran.
  * **THE DRIVER MUST RUN FROM `$B/gcc'.**  Run from the dump directory it
    says `cannot execute cc1: posix_spawn: No such file or directory', which
    reads as a broken build rather than a wrong cwd.  `-dumpdir' does the
    rest.
  * **A `-Wcomment' PAIR I INTRODUCED MYSELF**, by writing a slash-star glob
    inside a block comment in `defaults.h'.  Caught by watching the warning
    count -- the same lesson `FUNCTION_MODE' left: a warning count was the
    only signal there too.
  * **`nm -C' scored the aarch64 `push_rounding' thunk as the identity in
    x86-64 opcodes (`mov %rdi,%rax; mov %rsi,%rdx'), correctly** -- two
    registers because a `poly_int64' with `NUM_POLY_INT_COEFFS == 2' is two
    words.  That two-register return is itself evidence the union width
    reached the thunk.
  * `stock-compare.sh' prints a nix evaluation error (`undefined variable
    a') when env vars are exported into the `nix-shell' invocation; the run
    still proceeds and scores.  Noted, not fixed -- but it means the
    coreutils in that arm may be the ambient ones rather than the pinned
    ones.

## 7. FILES

    t135-build.sh        the build driver -- NOTE `--enable-targets' AND
                         `--enable-backends' AND `--prefix=$D'
    t135-specs.sh        per-target target-specs with real aarch64 binutils
    t135-state.sh        big.c wall + `int x = 1;' + x86_64 -O2 invariant
    t135-fn.sh           the three function-body artefacts, both bases
    t135-obj.sh          object-level both-sided symbol evidence
    t135-gate.sh         THE BEHAVIOURAL ARM -- csa pass gate, via the dump
    t135-gate-inject.sh  off/on for the gate, state asserted both ways

# TASK -- THE GUARD CORPUS REPAIRED AND MADE AUDITABLE, AND THE
# EXISTENCE-MACRO PROBE SHAPE DESIGNED, BUILT, CONTROLLED AND RUN.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in' **0**, `git reset --hard multi-target' took it
to **39**, no `scratchpad/'.  FIFTEEN in a row.  **The brief named no task
numbers I could read**; per PRINCIPLES section 7 that is the coordinator's
error and everything below is measured.  Build dir `/tmp/b-a7c-t108', my own,
cold.

## 1. JOB 1 -- THE BRIEF DESCRIBED THE SMALLER OF TWO DEFECTS

The brief said the `tNNN-build.sh' family passes only `--enable-backends' and
is broken by the flag day.  True, and repaired.  But auditing the corpus
mechanically rather than by eye found a SECOND defect in almost exactly the
same set of files, and it is the DANGEROUS one:

  MISSING-TARGETS  a top-level configure with no `--enable-targets'.  Fails
                   LOUDLY, by name (`--enable-targets=LIST is required',
                   configure.ac:157).  Annoying; self-announcing.

  FOREIGN-SRC      `SRC=' hardcoded to ANOTHER agent's worktree.  **Configures
                   and builds somebody else's tree, and SUCCEEDS.**  Measured:
                   this worktree has 39 `MULTI_TARGET' hits in
                   `gcc/Makefile.in'; the trees these scripts point at have
                   **27, 28 or 39**.  A script pointing at a 28 builds a
                   compiler missing eleven landed changes and reports a clean
                   green for it.  **There is no diagnostic at all.**

So the loud break was masking a silent one, and repairing only the flag would
have left every repaired script still measuring the wrong compiler.  This is
the absent-artefact/absent-mechanism shape: a script that fails to configure
LOOKS like a failing guard, and one that builds the wrong tree looks like a
pass.

**SCRIPTS FOUND vs SCRIPTS REPAIRED, which the brief asked for:**

    configure-invoking scripts in scratchpad/   38
    already correct before this task            15   (t113b, t119..t134 -conf)
    BAD                                         23
    repaired                                    23
    NOT repaired                                 0

`scratchpad/conf-audit.sh' is the durable half: it scores every script and
exits non-zero, so this cannot silently rot again.  Final state **38/38 OK**.

**A THIRD CLASS THE BRIEF'S "REPAIR THEM ALL" WOULD HAVE BROKEN.**  Three
scripts (`eb-conf.sh', `eb-reconf.sh', `eb-reconf-ctl.sh') invoke
`$SRC/gcc/configure', not the top level.  **`gcc/configure.ac' contains ZERO
occurrences of `enable-targets'** (measured) -- gcc/ takes `--enable-backends'
and knows nothing about targets, which is the host-not-target ruling itself.
Adding `--enable-targets' there would be an unrecognised option.  They are
classified GCC-level, given the SRC fix only, and reported OK rather than
silently omitted.  `eb-reconf-ctl.sh' deliberately spells the OLD name -- that
IS the control isolating the rename -- and carries a written
`CONF-AUDIT-EXEMPT:' marker rather than being listed in an allowlist inside the
auditor, so the excuse lives where the next reader of that script will see it.

`t45-all.sh' is the one script where the two lists MUST differ:
`--enable-backends=all' is legal and is its whole point, `--enable-targets=all'
is not (every element goes through config.sub).  Hand-written, with the reason
recorded in the file.

**VERIFICATION -- NOT ASSUMED, AND THE STATIC AUDIT IS EXPLICITLY NOT THE
EVIDENCE.**  "The flag is present" and "the tree configures" are different
claims, and PRINCIPLES is explicit that existence checks are the shape that
passes on the corrupted artefact.  So:

  * FAULT INJECTION, both defect classes, into a real repaired script
    (`t108-build.sh'), each restored and the restore asserted:
        remove `--enable-targets'  -> `BAD t108-build.sh TOP MISSING-TARGETS'
        restore the foreign SRC    -> `BAD ... FOREIGN-SRC MISSING-TARGETS'
    An uninjected mitigation is indistinguishable from an absent one.
  * LIVE ARM: `D=/tmp/b-a7c-t108 sh t108-build.sh multi-target-objs' -- the
    OLDEST and most-copied of the broken lineage.  **rc=0**; `config.status'
    and `gcc/Makefile' exist; **13 per-base objects in `mt-i386/', 23 in
    `mt-aarch64/'**, and both `target-cumargs-i386.o' and
    `target-cumargs-aarch64.o' built.  Every compile line names
    `-I.../agent-a7c243ba5c0d4dfb9/gcc' -- **MY worktree**, which is the
    positive evidence that the self-relative SRC took effect rather than the
    absence of an error.
  * The one `collect2: error: ld returned 1 exit status' in that build's stderr
    is the `-m32' multilib CONFIGURE PROBE (#119's recorded blocker), which
    prints `configuring will continue' and does.  Checked rather than reported
    as a build failure.

**WHAT I DID NOT VERIFY:** I ran ONE of the 23 repaired scripts end to end.
The other 22 are verified STATICALLY only.  That is an upper bound on the
evidence and I am not quoting it as more -- 23 cold GCC builds was not
affordable here.  The single live run does cover the exact lineage 10 of them
are byte-identical copies of.

## 2. JOB 2 -- THE EXISTENCE PROBE SHAPE: `scratchpad/exist-probe.sh'

**The blocker was real and is now gone.**  The design does NOT extend
`tab-probe.sh', and deliberately not: that harness reads constants out of slots
in the running `cc1' via a plugin, and its plugin runs inside ONE base
selection, so the UNSELECTED base's thunks read the SELECTED base's option
storage.  That is the recorded `CDATA_NUM_OPTSTATE' blindness which keeps six
endianness arms FAIL, and **anything built on that plugin inherits it**.

**THE INSIGHT: THE TWO ANSWERS ARE ALREADY SIDE BY SIDE, IN OBJECT FILES.**
`target-cumargs.cc' is compiled ONCE PER BACK END with that back end's `tm.h'
and `MULTI_TARGET_TARGETM_BASE' defined.  So `target-cumargs-i386.o' and
`target-cumargs-aarch64.o' exist SIMULTANEOUSLY in one tree, and both bases'
answers can be read **with neither base selected and no `*_option_override'
having run**.  There is no unselected base.  That is exactly the property the
plugin cannot have, and it is why this shape works where that one does not.

An existence predicate is the best-behaved case there is -- nullary,
`#ifdef'-derived, reading no option variable:

    static bool mt_base_has_push_rounding (void)
    { #ifdef PUSH_ROUNDING  return true; #else return false; #endif }

It compiles to a constant return, and the two constants are **1 and 0**.

**AND THAT IS PRECISELY WHERE THE VALUE ARM HAS NOTHING.**  The carried honest
negative says a value arm on `REG_PARM_STACK_SPACE' /
`INCOMING_REG_PARM_STACK_SPACE' cannot discriminate on this pair, because
`ix86_reg_parm_stack_space' returns 0 for SysV and aarch64's absence also
produces 0 -- correct by luck.  **1 vs 0 is not luck.**  That is the whole
argument for the shape.

TWO properties are scored, and the second is the general answer:
  A. VALUE, only when BOTH thunks compiled to a constant return, against a
     PRE-REGISTERED table hand-derived from the headers
     (`grep -l "define PUSH_ROUNDING" config/{i386,aarch64}/*.h' -> i386 only)
     BEFORE anything was disassembled.
  B. DISTINCTNESS, the two compiled bodies differ.  Scoreable for ALL of them,
     including the six property A cannot reach.

**MEASURED, in /tmp/b-a7c-t108 -- 9 macros, 3 PASS, 0 FAIL, 6
unmeasurable/report-only, all 9 DIFFER:**

    REG_PARM_STACK_SPACE    i386=1  aarch64=0   PASS   (predicted 1/0)
    PUSH_ROUNDING           i386=1  aarch64=0   PASS   (predicted 1/0)
    PUSH_ARGS_REVERSED      i386=1  aarch64=0   PASS   (predicted 1/0)
    FUNCTION_MODE           i386=24 aarch64=27  REPORT-ONLY (no prediction)
    ACCUMULATE_OUTGOING_ARGS         i386=OPTSTATE aarch64=CONST 1
    INCOMING_FRAME_SP_OFFSET         i386=OPTSTATE aarch64=CONST 0
    DEFAULT_INCOMING_FRAME_SP_OFFSET i386=OPTSTATE aarch64=CONST 0
    INCOMING_REG_PARM_STACK_SPACE    i386=OPTSTATE aarch64=CONST 0
    STACK_DYNAMIC_OFFSET             i386=OPTSTATE aarch64=OPTSTATE

The six are scored **UNMEASURABLE-BY-THIS-ARM, never PASS**, with the reason
named.  Their DIFFER verdict is still real evidence: one base reading option
state while the other returns a constant IS a demonstrated difference between
the two compiled copies.

**THE DISTINCTNESS CONTROL CAUGHT MY OWN PREDICTION, WHICH IS THE POINT OF
HAVING IT.**  Every macro in the table scores DIFFER, and an instrument that
has only ever returned one of its two answers has not been shown able to return
the other.  Worse, the two objects lay functions out at DIFFERENT OFFSETS, so
without address stripping **everything scores DIFFER vacuously**.  The first
control chosen was `mt_base_stack_boundary', on my belief that STACK_BOUNDARY
is 128 on both bases.  It scored DIFFER and the run **aborted**.  Re-reading
rather than editing the check: i386's STACK_BOUNDARY is OPTION-DEPENDENT
(`testb $0x2,...' then 0x20/0x40/0x80) against aarch64's flat `mov $0x80'.
**The prediction was wrong; the instrument was right.**  The control actually
used is `HARD_FRAME_POINTER_IS_FRAME_POINTER', whose justification was already
written in `target-cumargs.cc:586-588' -- neither base defines it, both fall to
rtl.h's comparison, both false -- and it scores SAME.

**FAULT INJECTION on the value arm**: flipping `PUSH_ROUNDING's pre-registered
1/0 to 0/1 produces
`FAIL measured 1/0 but PRE-REGISTERED 0/1 -- re-read the header, do not edit
the table'.  Restored, and the restore asserted.

## 3. WHAT I DID NOT DO

  * **THE SCOREBOARD WAS NOT RUN AND I CLAIM NO MOVEMENT.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS /
    104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64 27/5**.
    `exist-probe.sh' is a SEPARATE harness with its own list and its numbers
    are NOT added to those totals.
  * **NO MACRO WAS MOVED TO A `CONVERTED_*' STATUS.**  Three now have a
    trustworthy arm, but the standing rule keys `CONVERTED_*' to
    `tab-probe.sh's `TAB_MACROS' line, which `macro-probe.sh' checks
    mechanically.  Wiring `exist-probe.sh' into that mechanical check is a
    separate, deliberate change -- doing it as a side effect here would be
    exactly the "banking" the rule exists to prevent.  **This is the next
    increment and it is small.**
  * **No macro was converted.**  This task was infrastructure, per the brief.
  * `FUNCTION_MODE' has no pre-registered prediction; 24 vs 27 is reported,
    not scored.
  * The six OPTSTATE macros remain genuinely unmeasured for value.  The fix is
    a second reading under each base's own option override, which is the same
    blocker `tab-probe.sh' records.
  * `insn-emit' untouched; `#undef PUSH_ROUNDING' still blocked on the
    `gen_movxf' ruling.  No `stock-compare' / `big.c' / `int x = 1;' bars
    re-run -- **no compiler source was changed by this task**, only scratchpad
    harnesses, so those bars cannot have moved and re-running them would have
    been a claim rather than a measurement.

## 4. FILES

    conf-audit.sh    scores every configure-invoking script; exits non-zero.
                     Self-excluding, per-CLASS non-vacuity assertion, in-file
                     `CONF-AUDIT-EXEMPT:' markers instead of an allowlist.
    conf-repair.sh   the two mechanical repairs, idempotent, every
                     substitution ASSERTS ITS END STATE (a sed that matches
                     nothing exits 0).  awk not sed for the SRC rewrite --
                     the replacement contains `||'.  Not python3.
    exist-probe.sh   THE FIFTH PROBE SHAPE.  Pre-registered table, distinctness
                     control asserted FIRST and fatal, blind spots stated.

# TASK -- WHICH REPORTED GREENS DID THE BROKEN GUARD SCRIPTS ACTUALLY
# PRODUCE?  ANSWER: NONE.  THE LIST OF UNCORROBORATED CONVERSIONS IS EMPTY,
# AND IT IS EMPTY FOR A STRUCTURAL REASON, NOT A LUCKY ONE.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in' **0**, `git reset --hard multi-target' took it
to **39**, no `scratchpad/'.  SIXTEEN in a row.  **The brief named no task
numbers I could read**; per PRINCIPLES section 7 that is the coordinator's
error and everything below is measured.  Build dir `/tmp/b-a36-t111', my own,
cold.

## 1. THE FINDING: `HARDCODED-SELF' AT AUTHORING TIME, `FOREIGN' ONLY BY
## INHERITANCE

The brief asked which previously-reported greens routed through the 23 broken
scripts.  The premise behind the question is that a script naming
`agent-XXXX' built a *stranger's* tree.  **Measured, that is not what
happened, and the distinction decides the whole audit.**

For all 22 `FOREIGN-SRC' scripts, the worktree named in `SRC=' is the worktree
of the agent who WROTE that script:

    t106-build.sh -> a7faca...  (that tree's highest task: t106)
    t107-build.sh -> a14027...  (t107)
    t108-build.sh -> a7d5fb...  (t108)
    t111-build.sh -> a583ac...  (t111)     t112 -> aa0b6d (t112)
    t113-build.sh -> a8e4f8...  (t113)     t116 -> a3f44d (t116)
    t117-build.sh -> a75a2f...  (t117)     t135 -> ab8de4 (t135)
    t77-conf.sh   -> af7e06...  (t77)      t24/t45/t78 -> the t111-era trees
    t88/t92       -> the t106-era trees    eb-*/rv-* -> their own

Every author hardcoded its OWN absolute path.  The line was correct when
written and correct when run.  It became `FOREIGN' only at the moment the file
was committed and inherited by the NEXT worktree.

**Scale of the exposure, measured**: across ~50 worktrees there are **506**
scripts carrying a hardcoded `SRC=', of which **21** name their containing
worktree and **485** name a different one.  So the loaded guns were real and
numerous.  The question is whether any was fired.

## 2. THE INDEPENDENT INSTRUMENT -- `scratchpad/built-tree-audit.sh'

`conf-audit.sh' scores the SCRIPTS AS THEY STAND.  It cannot answer a question
about builds that already happened, and it reads the very artefacts under
suspicion.  So the evidence here comes from somewhere else entirely: **each
build dir's own `config.log', which records the absolute srcdir `configure'
was invoked from.**  That is the build's own testimony about what it compiled.
It does not depend on reading, trusting or re-running any guard script, and it
survives the scripts being repaired afterwards -- which is the actual situation.

**96 `config.log's read.  EVERY build dir was configured from the worktree of
the agent that OWNED that task number, at that task's own timestamp.**  Not
one build anywhere used a foreign tree.

And the anchor is **MONOTONIC IN TIME**, which is the both-sided half:

    08-12 (early)  anchor 23   b-cold62, b-mst
    08-12          anchor 27   b101 b106 b107 b64 b65 b-77t b88* b-92 b93 b94 ...
    08-12 (18:56+) anchor 28   b108 b108f b111 b111m b112 b113 b116 b117
                               b24 b45 b78
    08-12          anchor 30   b-43  (that tree's own WIP, ahead of branch)
    08-12 (23:36+) anchor 37   b119 b119c b122
    08-13          anchor 37   b123 b124 b125 b126 b127 b128 b129
    08-13 (04:53+) anchor 39   b130 b131 b132 b133 b134 b135

No agent built a tree staler than its own era.  A fired FOREIGN-SRC would show
as a build dir whose srcdir tree is not its owner's, or as an anchor going
BACKWARDS against the clock.  **Neither appears.**

## 3. THE RANKED LIST THE BRIEF ASKED FOR

**It is empty, and here is the reasoning that establishes it rather than
asserts it.**  Ranking the affected conversions by how much independent
corroboration they have, worst first:

  RANK 1 (weakest evidence, and still sufficient): #106, #107, #111, #112,
    #113, #116, #117, #24, #45, #77, #78, #88, #92, rv, eb.  Their guard
    script carried a hardcoded SRC.  **Corroborated** by the config.log of
    their own build dir naming their own tree at their own timestamp.  This is
    object-level and independent of the script.  No re-run needed.
  RANK 2: #108 -- same, PLUS a live re-run of `t108-build.sh' by the previous
    agent after repair, PLUS `t108-evidence.sh' object-level readings.
  RANK 3: #135 -- same, PLUS `t135-obj.sh' `nm' readings (`ix86_reg_parm_
    stack_space' 1->0 in `calls.o'/`expr.o' while `ix86_push_rounding' still
    scored 1 in seven objects in the SAME run), PLUS the `-fdump-rtl-csa'
    pass-gate arm.  Note its SRC tree `ab8de4' measures **39**, i.e. current.
  NOT AFFECTED AT ALL: #119, #122-#134.  Their scripts are 15 of the
    "already correct" set and never carried the defect.

**The brief's five examples are all in the NOT-AFFECTED band, and I checked
rather than assumed** -- attributed by line number to their task headers in
STATE.md:

    `bl g; bl f' -> `bl f; bl g'            STATE.md:7618   TASK #134
    850 -> 793 bytes, x86_64 byte-identical STATE.md:7057   TASK #132
    aarch64 97/16/30/97 vs x86_64 17/...    STATE.md:5684   TASK #126
    the CFI/`bl f' assembly reading         STATE.md:6728   TASK #131

    `1->0' on `function.o'/`calls.o'/`expr.o'  #134/#135 -- #135 IS in the
    affected set, and is the best-corroborated entry in it (RANK 3).
    `{0,0}' -> `{16,0}' STACK_DYNAMIC_OFFSET is #132-era, not affected.

So: **a covered conversion is a result, and these are covered.**

## 4. THE ONE APPARENT ANOMALY, RESOLVED AS CORRECT PRACTICE

`b24-before' was configured from `a583ac' (the **t111** tree) while `b24' and
`b24-after' used `ad79a1' (its own).  That reads exactly like a fired
FOREIGN-SRC.  It is not: #24's own STATE.md:2118-2119 documents it as a
deliberate A/B --

    /tmp/b24-before   SRC=.../a583ac...   (pre-change tree)
    /tmp/b24-after    SRC=.../ad79a1...   (this tree)

which is the CORRECT control shape, and is precisely what PRINCIPLES section 5
demands when it says an A/B across `git stash' is not an A/B (mtimes refresh).
Building the "before" side from a genuinely separate tree is the fix, not the
bug.  **Found by looking, not by assuming; reported because the obvious
reading is that it is the defect.**

## 5. THE LIVE ARM -- 22 STATIC-ONLY BECAME 21

The previous agent live-ran `t108-build.sh' and recorded the honest bound: 22
of 23 verified statically only.  I ran ONE more, chosen by the ranking rather
than by convenience: **`t111-build.sh' -- the lineage TEMPLATE, which STATE.md
records "every later tNNN-build.sh is a copy of"**, so it is the single script
whose correctness propagates furthest.

    D=/tmp/b-a36-t111 sh scratchpad/t111-build.sh multi-target-objs
    rc=0
    13 objects in mt-i386/, 23 in mt-aarch64/   (identical to the t108 run)
    1093 `worktrees/agent-' references in the build log, resolving to
    EXACTLY ONE id: `agent-a3611764dba7e82f4' -- MY worktree.

That last line is the positive evidence, not the absence of an error: the
self-relative `SRC' demonstrably took effect.  **21 of 23 remain static-only
and I am not quoting that as more.**

The one `collect2: error: ld returned 1 exit status' in its stderr is #119's
recorded `-m32' multilib CONFIGURE PROBE -- it prints `Multilib is mandatory
... configuring will continue' and does.  Checked, not reported as a failure.

Stderr composition, COLD arm for `multi-target-objs' only (NOT comparable with
either the 32-line incremental floor or the ~870-line cold `all-gcc'): 164
lines, 23 `warning:', 24 `'@' is redundant', 0 `is unchanged', 1 `error:' (the
probe above).

## 6. A LIMIT OF THE REPAIRED GUARD, STATED RATHER THAN "FIXED"

The repair added to each script:

    grep -q MULTI_TARGET "$SRC/gcc/Makefile.in" || { echo FATAL...; exit 9; }

**That is a 0/non-0 test, not a value test.**  It catches the documented
bare-repo-HEAD case (0 hits) and would NOT catch a 27 or a 28.  With `SRC' now
self-relative the stale-sibling case can no longer arise from the `SRC' line,
so the guard is proportionate to the residual risk -- but the guard alone is
NOT what makes the corpus safe, the self-relative `SRC' is.  Hardcoding `-eq
39' would be worse: the number legitimately grows with every landed change, so
it would be a floor that has to be edited, i.e. the test-harness floor.
Recorded so the next reader does not mistake the grep for a full anchor check.

## 7. WHAT I DID NOT DO

  * **21 of the 23 repaired scripts are STILL verified statically only.**  I
    converted one (t111).  23 cold builds remains unaffordable.
  * **The scoreboard was NOT run and I claim NO movement.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS /
    104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64 27/5**.
  * **No compiler source was changed by this task**, so `stock-compare',
    `big.c', `int x = 1;' and the x86_64 `-O2' md5 cannot have moved, and
    re-running them would have been a claim rather than a measurement.  The
    live t111 build is a build-system arm, not a codegen arm.
  * `insn-emit' untouched; the `gen_movxf' ruling is unchanged.
  * **A diagnostic I found and did NOT silence**: `target-regs.cc:65' and one
    sibling emit `warning: missing terminating ' character', from the
    apostrophes in the TEXT of two `#error' guards ("that base's", "this back
    end's").  PRINCIPLES names unterminated quotes as twice meaning silent
    truncation, so I established what it reports before leaving it: the two
    `#error's are inert here (the file IS compiled with both macros), and the
    warning is the lexer noticing an apostrophe in `#error' text.  Benign, but
    it is 2 of the 23 warnings in every build of that file.  Rewording the two
    messages would remove it; that touches compiler source and was not this
    task's remit.

## 8. FILES

    built-tree-audit.sh  THE DURABLE HALF.  Recovers, for every build dir,
                         WHICH TREE it was configured from, out of its own
                         `config.log'.  Independent of the guard scripts by
                         construction.  Non-vacuity FATAL, fault-injected
                         (matcher pointed at a nonexistent prefix -> rc=9).
                         Blind spots written in the file: deleted build dirs
                         are invisible, and gcc-level srcdirs print GONE for
                         the anchor by path construction, not by defect.

# THE EXISTENCE PROBE IS ON THE BOARD, AND THE BOARD WAS MISSING 42 MACROS

Two jobs were asked for. Both are done, and a third thing was found on the way
that mattered more than either: **the header probe had been dead since
`STACK_POINTER_REGNUM` was converted, and could not run at all.**

## 1. THE HARNESS WAS NOT DEGRADED, IT WAS DEAD -- SO THE CIRCULATING FIGURES ARE NOT A CURRENT READING

`macro-probe-run.sh` exits **rc=9** on this tree before probing anything:

    defaults.h:2799:55: error: size of array 'cq' is not an integral
    constant-expression
     2799 | #define STACK_POINTER_REGNUM (mt_stack_pointer_regnum ())

Arm 0's INT control was re-anchored to `STACK_POINTER_REGNUM` on 2026-08-12.
`STACK_POINTER_REGNUM` has since been converted to a run-time call, and a call
is not an integral constant expression, so `char cq[STACK_POINTER_REGNUM]` does
not compile in **any** of the three contexts. No `results.txt`, no summary.

The comment sitting directly above the control had predicted exactly this, about
a different macro: *"It stays a control only while it stays UNCONVERTED; when it
is converted, the right move is another independent differing witness, not this
one weakened."* Nobody applied that sentence to arm 0's own witness.

**So the figures in circulation -- 224 header arms, i386 112/0, aarch64 8/104 --
are the last successful run's, not something this tree can reproduce.** Anyone
quoting them today is quoting a stale artefact of a harness that now refuses to
start. That is the good failure mode (it refused to score rather than scoring
nothing as clean) but it is not a measurement.

Re-anchored to **`MIN_UNITS_PER_WORD`** (i386 4, aarch64 8, mt 4), measured in
all three contexts before adoption. Criteria, written into the script:

  * not in the frame/stack/argument/register families the programme is
    currently converting, so the family that just killed the control cannot
    kill it again;
  * distinct from the STR control (`GLOBAL_ASM_OP`) and the EXP control
    (`SELECT_CC_MODE`) -- three controls, three macros, three families;
  * a real numeric spread. `SLOW_BYTE_ACCESS` (0/1), `CASE_VECTOR_PC_RELATIVE`
    (0/1) and `DEFAULT_SIGNED_CHAR` (1/0) were **measured and rejected**: a
    probe bug yielding a defaulted 0 is indistinguishable from a correct
    reading on a 0/1 macro. `FUNCTION_BOUNDARY` (8/32) was rejected on the
    first criterion -- `STACK_BOUNDARY` and `PARM_BOUNDARY` are already gone.

This is a **repair of a control that cannot run**, not the retirement of an arm
that fails. Leaving it dead reports nothing; it does not report less.

## 2. JOB 2 FIRST, BECAUSE IT REFRAMES JOB 1: 42 CONVERTED MACROS HAD NO HONEST STATUS

The brief named five macros as "converted and entirely absent" and said not to
trust the list. It should not be trusted. Derived from `gcc/defaults.h` rather
than from any list -- every `#undef` at column 0 after `#include
"target-cdata.h"`, which is how a converted macro is redirected:

    67 macros are converted.
    11 were ABSENT from macro-status.txt entirely.
    31 more were PRESENT and said UNCONVERTED.
    -> 42 with no honest status, against a brief that named 5.

Of the brief's five, **three were already on the board** (`INCOMING_FRAME_SP_
OFFSET`, `FUNCTION_MODE`, `ACCUMULATE_OUTGOING_ARGS`, all saying `UNCONVERTED`);
only `DEFAULT_INCOMING_FRAME_SP_OFFSET` and `STACK_DYNAMIC_OFFSET` were absent.

`macro-status.txt`'s own header note said **sixteen** macros say `UNCONVERTED`
and are converted. It was thirty. The fourteen nobody had written down are two
whole families:

  * the cost macros `MOVE_MAX`, `MOVE_MAX_PIECES`, `STORE_MAX_PIECES`,
    `COMPARE_MAX_PIECES`, `MOVE_RATIO`, `CLEAR_RATIO`, `SET_RATIO`;
  * the frame registers `STACK_POINTER_REGNUM`, `FRAME_POINTER_REGNUM`,
    `HARD_FRAME_POINTER_REGNUM`, `ARG_POINTER_REGNUM`
    -- one of which is the macro that killed the harness in §1.

**A hand-maintained note is not a check.** That is the whole finding.

## 3. `CONVERTED_NOARM` -- THE DEBT GETS A COLUMN INSTEAD OF A SILENCE

The brief's requirement was that an absent macro and a failing macro must not
look alike in any total. They did not look alike -- an absent macro looked like
*nothing*, counted in no column at all, which is worse. It is the branch's root
pattern (one name, several authorities, no diagnostic) aimed at the instrument.

Two statuses were needed, because the two existing shapes are both lies for a
converted-but-unmeasured macro: `UNCONVERTED` says the work has not happened
(and has already sent agents to convert converted macros), while any
`CONVERTED_*` claims an arm nobody ran.

  * **`CONVERTED_NOARM`** -- converted, no arm. The measurement debt, on the
    board, countable, in its own column. It **retires nothing**: the macro
    keeps whatever header arm it had, because retiring an arm without a
    replacement is the disappearance the anti-floor gate exists to prevent.
    A `CONVERTED_NOARM` entry is a TODO with a name.
  * **`CONVERTED_EXIST`** -- covered by `exist-probe.sh`. Header arm retired.

## 4. JOB 1 -- WIRED, WITH THE TWO POPULATIONS KEPT APART

`exist-probe.sh` now exports `EXIST_MACROS` on one line, exactly as
`tab-probe.sh` exports `TAB_MACROS`, and `macro-probe.sh` reads **both, into
two variables, checked against two statuses, printed as two totals**.

**A name in `TAB_MACROS` does not satisfy `CONVERTED_EXIST`, and a name in
`EXIST_MACROS` does not satisfy `CONVERTED_CDATA`.** Accepting "covered by
something" would be one check satisfied by the wrong evidence -- the same defect
`macro-status.txt` already records as the reason `CONVERTED_REGS` is separate
from `CONVERTED_CDATA`. An existence bit is not a value reading and the board
must not let one be quoted as the other. The summary line says so in words:

    status: an EXIST arm is NOT a value arm.  Do not add 32 and 9.

All nine exist-probe macros moved to `CONVERTED_EXIST` **in this change**, which
is the standing rule satisfied rather than waived. `exist-probe.sh` also gained
a drift check: `EXIST_MACROS` and the `PREREG` table are compared as sets, both
directions, and disagreement is fatal -- otherwise the board could advertise an
arm the script does not run.

## 5. THE COMPLETENESS GATE, AND ITS ONE HAND-WRITTEN WEAKNESS

`macro-probe.sh` now derives the converted set from `defaults.h` and refuses to
run if any converted macro is absent from the board or present saying
`UNCONVERTED`. Both directions of the converse are checked too: a
`CONVERTED_NOARM` entry must be genuinely converted (or the status becomes an
excuse never to grow an arm) and must genuinely have no arm (or the debt column
overstates while the coverage column understates).

**Blind spot, stated rather than papered over.** A macro converted by rewriting
its *consumers* instead of redirecting its *name* never appears in `defaults.h`.
Three are known -- `PUSH_ROUNDING`, `STACK_DYNAMIC_OFFSET`,
`INCOMING_REG_PARM_STACK_SPACE` -- and they are declared by hand in
`CONVERTED_NO_REDIRECT`, which is the weakness this gate removes, reintroduced
in the small. Bounded two ways: each declared name must be **absent** from the
derived set (so a name that later acquires a redirect stops being special-cased
silently) and must have an `mt_` declaration in `target-frame.h` (so it cannot
be a typo or a fiction). There is also a non-vacuity FATAL: fewer than 40
derived names means the anchor moved and every check below would pass trivially.

**Five faults injected, five fired**, by name:

    absent from board (not in probe list)     -> named ALL_REGS
    converted macro relabelled UNCONVERTED    -> named Pmode
    CONVERTED_EXIST dropped from EXIST_MACROS -> named REG_PARM_STACK_SPACE
    EXIST_MACROS vs PREREG drift              -> exist-probe.sh rc=9
    TAB-covered macro marked CONVERTED_NOARM  -> named BYTES_BIG_ENDIAN

A sixth fired **unplanned and correctly**: the membership idiom
`case " $SET " in *" $n "*` matches on spaces while the derived set is one name
per line, so the first run accused `ALL_REGS` falsely. Worth recording because
the failure direction was the lucky one -- the same bug in the `missing` loop
would have reported everything absent, and written the other way round would
have reported everything present.

## 6. THE NEW READING, AND WHY THE PASS COLUMN ROSE FOR NO GOOD REASON

    status: 149 macros on the board = 75 unconverted
            + 32 converted with a TAB (value) arm
            + 9  converted with an EXIST (existence/distinctness) arm
            + 33 converted with NO ARM AT ALL (the measurement debt)

Header probe, `/tmp/b-a7c-t108`, rc=0 (it runs again):

    macros probed: 108 (was 112) -- 216 arms, was 224
    i386:    PASS 108  FAIL 0
    aarch64: PASS 29   FAIL 79

**NEVER QUOTE THE RAW 29.** It decomposes, mechanically, as
**2 trusted + 27 untrusted by construction**:

  * 2 trusted: `MAX_BITS_PER_WORD`, `MAX_BITSIZE_MODE_ANY_MODE` -- the same two
    PRINCIPLES already names, both INT.
  * 27 are exactly the `CONVERTED_NOARM` macros that remain in the probe list.
    Each is redirected by `defaults.h`, and the probe's base-B context does not
    define `MULTI_TARGET_TARGETM_BASE`, so both sides expand to the same `mt_*`
    call and **the arm compares a redirect with itself**. Wrong-reason shape 2,
    27 times.

The correspondence is exact and is not a coincidence: 27 in the probe list + 6
not in it = the 33 `CONVERTED_NOARM` macros.

**This caveat is now computed and printed where the number is printed**, not
kept in prose in another file:

    aarch64 PASS decomposition: 29 total = 27 redirect-vs-itself
      (CONVERTED_NOARM, UNTRUSTED BY CONSTRUCTION) + 2 other.
      NEVER QUOTE THE RAW 29.

and every such line in the PASS listing is tagged `UNTRUSTED-redirect-vs-itself`.
PRINCIPLES had to explain the old raw 8 in prose in a second file, and the raw
number was quoted anyway at least twice. A caveat that lives somewhere else gets
dropped.

**Delta against the last successful run, with a reason per changed arm:**

  * 224 -> 216 arms. Four macros with header arms moved to `CONVERTED_EXIST`
    and their eight arms are **retired, not banked**: `ACCUMULATE_OUTGOING_ARGS`,
    `FUNCTION_MODE`, `INCOMING_FRAME_SP_OFFSET`, `PUSH_ARGS_REVERSED`. The last
    is the one the brief predicted would flip FAIL -> PASS for shape 5 on the
    next run; it does not get the chance.
  * aarch64 8 -> 29 is **not progress and must not be read as any**. The old 8
    was 2 trusted + 6 retired-pending; the new 29 is 2 trusted + 27
    redirect-vs-itself. The *trusted* count is unchanged at 2. The 21-arm rise
    is 21 more macros having been converted since that run, each turning its own
    arm green by becoming target-neutral in both contexts.
  * i386 112 -> 108 PASS / 0 FAIL: the four retirements, nothing else.
  * The 6 `#108` retired-pending arms named in PRINCIPLES are now visible as
    `CONVERTED_NOARM` entries in the untrusted 27 rather than as an unexplained
    remainder inside a raw total.

`exist-probe.sh` re-run after the changes: 9 examined, **3 PASS, 0 FAIL, 6
unmeasurable/report-only**, all 9 DIFFER, control SAME -- unchanged, which is
the point: wiring it into the board changed the board, not the measurement.

## 7. WHAT I DID NOT DO

  * **No compiler source was changed** -- the diff is three files under
    `scratchpad/`. So the codegen bars (`multi-target-objs`/`cc1`/`lto1`, the
    x86_64 and aarch64 md5s, stock-compare 5/5) **cannot have moved**, and
    re-running them would have been theatre rather than measurement. They were
    not run and are not claimed.
  * The 33 `CONVERTED_NOARM` macros still have **no arm**. That is the debt,
    now countable, and it is the obvious next increment: they are mostly calls
    and option reads, so `tab-probe.sh` (constants out of the running `cc1`)
    cannot take them and `exist-probe.sh` can only take the ones with an
    existence bit or a constant-return thunk.
  * `FUNCTION_MODE` is still REPORT-ONLY (i386=24, aarch64=27, both constants,
    differing, no prediction registered). Registering a prediction is a
    one-line increment and was left rather than done as a side effect, since a
    prediction written *after* seeing the disassembly is a restatement, not a
    check.
  * The brief's "aarch64 8 PASS / 104 FAIL, TAB 27/5" could not be reproduced
    and was not reported against; §1 says why.
