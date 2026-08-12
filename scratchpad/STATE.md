
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
