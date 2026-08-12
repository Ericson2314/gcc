
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
