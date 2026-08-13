#!/usr/bin/env bash
#
# THE PER-MACRO ARM.  One probe per leaked target macro, replacing the single
# unreachable "aarch64 asm is byte-identical to a reference" gate.
#
# WHAT IS MEASURED
#
#   A middle-end translation unit in the multi-target build sees the PRIMARY
#   base's `tm.h' -- literally, `-I.' in the build directory resolves `tm.h' to
#   the x86 one.  Every target macro it spells therefore carries the primary's
#   value no matter which base `-ftarget-config=' later selects.  For each
#   macro M and each configured base B this script asks one question:
#
#       does M, as seen by a middle-end TU, agree with M as seen by base B?
#
#   It does that by compiling the SAME probe source in three contexts inside
#   the real build directory:
#
#       mt        -I.                 what a middle-end TU actually sees
#       i386      -Ii386-inc  -I.     base i386's own headers
#       aarch64   -Iaarch64-inc -I.   base aarch64's own headers
#
#   PASS for (M,B) means mt agrees with B.  Today mt IS the i386 header set, so
#   every i386 arm passes and that is close to tautological -- it is the
#   positive control, and after any fix it becomes a real no-regression arm.
#   The aarch64 arms are the measurement, and they are expected to be red.
#
# WHY NOT A TEXT DIFF (this is the whole reason the script is shaped this way)
#
#   `N_REG_CLASSES' is `((int) LIM_REG_CLASSES)' on BOTH bases -- byte-identical
#   definition text -- and measures 34 on i386 and 20 on aarch64, because
#   LIM_REG_CLASSES is a back-end-generated enumerator, not a macro.  It is the
#   macro behind the aarch64.cc:14322 ICE and it appears in no text-diff list.
#   So values are probed, never definition text, wherever a value exists.
#
# THREE PROBE SHAPES, in order of strength.  Each macro gets the strongest one
# that applies, and the shape used is printed with the verdict.
#
#   INT  integer constant expression.  `char q[((V >> 8k) & 0xff) + 1]', eight
#        symbols, value read back with `nm -S'.  Exact, 64-bit, signed-safe.
#        No execution, no target assembler needed.
#
#   STR  string literal.  `char n[sizeof(S)]' for the length, then
#        `char c_k[S[k] + 1]' per byte.  Exact.  This is what catches
#        GLOBAL_ASM_OP: `\t.globl\t' vs `\t.global\t' ASSEMBLES IDENTICALLY, so
#        every check weaker than a byte comparison passes it.  This one does not.
#
#   EXP  fully preprocessed expansion.  For the 91 class-(c) macros there is no
#        value to compare: they expand to back-end CODE (`ix86_cc_mode (...)',
#        `regclass_map[...]', reads of the primary's option variables).  The
#        probe preprocesses a marked use of the macro -- supplying dummy
#        arguments for function-like ones -- and compares the resulting token
#        stream between contexts.
#
#        WHAT EXP CAN SEE: a differing callee, a differing global, a differing
#        option variable, a differing argument count, a differing constant that
#        survives to the token stream.
#
#        WHAT EXP CANNOT SEE, stated because a clean EXP result is worth much
#        less than a clean INT one:
#          * identical tokens with differing meaning -- exactly the
#            N_REG_CLASSES trap, one level down.  If an expansion bottoms out
#            in an ENUMERATOR or a variable whose definition differs per base,
#            EXP reports agreement.  INT/STR are tried first precisely so that
#            every macro that CAN be valued is valued; EXP only ever runs on
#            macros that no compiler can evaluate at translation time.
#          * behaviour.  Two identical token streams that call the same
#            function name still call whichever definition linked.
#          * whitespace and comment differences are normalised away
#            deliberately; only the token sequence is compared.
#
# WHAT NONE OF THE THREE CAN SEE, for the whole instrument:
#
#   * anything selected at RUN TIME inside cc1.  This measures the header and
#     preprocessor context a TU is compiled in.  A macro routed through
#     `targetm' is invisible here and is correctly so -- that is why the two
#     `targetm' hook initialisers are excluded rather than scored.
#   * a macro whose value is right at every use site but whose USE is wrong.
#   * the ~1049 identical-text non-integer macros that have never been
#     classified.  The probe set below is a LOWER BOUND on the population.
#     Do not read 138 as a ceiling.
#
# USAGE
#   scratchpad/macro-probe.sh [builddir]        default /tmp/b-objs
#   writes  $OUT/results.txt   one line per (base,macro), machine readable
#           $OUT/summary.txt   the counts
#   OUT defaults to /tmp/mtp-out.
#
#   gcc/testsuite/gcc.target/multi-target/macro-probe.exp turns results.txt
#   into one PASS/FAIL per macro, named by macro.

set -o pipefail

BUILD=${1:-/tmp/b-objs}
OUT=${OUT:-/tmp/mtp-out}
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/.." && pwd)/gcc
MACROS=${MACROS:-$HERE/macro-probe-list.txt}

die () { echo "FATAL: $*" >&2; exit 9; }

# Tool guard.  A missing tool must never score as a clean zero: that already
# happened once on this project, `nm' was absent, "command not found" went into
# `grep -c', and both compilers scored 0 symbols -- in the direction that made
# the reference look correct.
for t in g++ nm awk sed sort comm grep; do
  command -v "$t" >/dev/null || die "missing tool: $t (are you inside the nix-shell?)"
done
[ -d "$BUILD/gcc" ] || die "no build dir $BUILD/gcc"
# ABSOLUTE FROM HERE ON.  `ctx_dir' writes the control fixtures by path while
# the script later `cd's into $BUILD/gcc; a relative $BUILD would put the
# fixtures somewhere else after the cd, and the arms would then be measuring a
# directory nobody is compiling against.  PRINCIPLES records the same class of
# defect in stock-compare.sh, where a relative path produced a false green.
BUILD=$(cd "$BUILD" && pwd) || die "cannot resolve $BUILD"
[ -f "$BUILD/gcc/tm.h" ] || die "no $BUILD/gcc/tm.h"
[ -s "$MACROS" ] || die "no macro list $MACROS"
mkdir -p "$OUT" || die "cannot create $OUT"

# Delete every artefact before every arm, so a stale file cannot be read as a
# fresh result.
rm -f "$OUT"/results.txt "$OUT"/summary.txt "$OUT"/val-*.txt "$OUT"/exp-*.txt \
      "$OUT"/dm-*.txt "$OUT"/err-*.txt

BASES="i386 aarch64"
CTXS="mt i386 aarch64"

ctx_inc () {                      # include flags that define the context
  # MTP_INJECT=same-context COLLAPSES the contexts -- every context resolves
  # its headers exactly as `mt' does.  This is the fault arm 0 exists to
  # catch, and it is in the script rather than in a report so that the next
  # agent can re-run it.  See `INJECTION ARMS' below.
  if [ "$MTP_INJECT" = same-context ]; then echo ""; return; fi
  case $1 in
    mt) echo "" ;;
    *)  echo "-I$1-inc" ;;
  esac
}

# The directory each context's quoted `#include' resolves to FIRST.  `mt' has
# no `-I<base>-inc', so its first hit is the build root via `-I.'; a base
# context's first hit is its own `<base>-inc'.  This is not a second model of
# the include path -- it is read off `ctx_inc' above, and the fixture arms
# below FAIL if the two ever disagree, because each fixture states which
# directory it came from and the arm checks that against this function.
ctx_dir () {
  case $1 in
    mt) echo "$BUILD/gcc" ;;
    *)  echo "$BUILD/gcc/$1-inc" ;;
  esac
}

CPPFLAGS="-DIN_GCC -DHAVE_CONFIG_H -I. -I$SRC -I$SRC/../include \
 -I$SRC/../libcpp/include -I$SRC/../libcody -I$SRC/../libdecnumber \
 -I$SRC/../libdecnumber/bid -I../libdecnumber -I$SRC/../libbacktrace"

PRE='#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#include "hard-reg-set.h"'

########################################################################
# THE ANTI-FLOOR GATE.
#
# Converting a macro to a hook DELETES its arm here: the name vanishes from
# both bases' headers and the KIND probe scores absent/absent forever.  A
# scoreboard that punishes progress invites the obvious next move -- quietly
# editing this list -- which is the test-harness floor by a longer route.
#
# So a name may leave the header probe ONLY by being marked CONVERTED_GONE in
# macro-status.txt AND appearing in tab-probe.sh's TAB_MACROS.  Both halves are
# checked here, mechanically, before anything is probed.  Deleting a probe and
# converting a macro out from under one now fail loudly, by name.
########################################################################
STATUS=${STATUS:-$HERE/macro-status.txt}
TABSH=${TABSH:-$HERE/tab-probe.sh}
[ -s "$STATUS" ] || die "no macro status file $STATUS"
[ -s "$TABSH" ] || die "no $TABSH; a CONVERTED macro could not be covered"
TAB_COVERED=$(sed -n 's/^TAB_MACROS="\(.*\)"$/\1/p' "$TABSH")
[ -n "$TAB_COVERED" ] || die "could not read TAB_MACROS from $TABSH -- the \
coverage check would pass vacuously, which is worse than no check"

# THE FIFTH SHAPE'S LIST, read the same way and kept deliberately SEPARATE.
#
# `exist-probe.sh' reads the two per-base OBJECTS side by side with neither
# base selected.  Its arms are EXISTENCE bits and distinctness verdicts, not
# values, and a board that added its coverage into TAB's would let "this macro
# exists in one base and not the other" be read as "this macro's value has been
# verified in both".  Those are different propositions and this script keeps
# two variables, checks them against two statuses, and prints two totals.
EXISTSH=${EXISTSH:-$HERE/exist-probe.sh}
[ -s "$EXISTSH" ] || die "no $EXISTSH; a CONVERTED_EXIST macro could not be covered"
EXIST_COVERED=$(sed -n 's/^EXIST_MACROS="\(.*\)"$/\1/p' "$EXISTSH")
[ -n "$EXIST_COVERED" ] || die "could not read EXIST_MACROS from $EXISTSH -- \
the coverage check would pass vacuously, which is worse than no check"

# THE SIXTH SHAPE'S LIST, kept separate for the third time and for the same
# reason.  `union-probe.sh' scores a proposition neither of the other two can
# state: that the ONE shared answer is the MAXIMUM over the configured back
# ends and is not the primary's own.  For a union macro every other arm on this
# board is green BY CONSTRUCTION -- the number is deliberately identical in
# every translation unit, because it sizes stack buffers whose bounds checks
# use the same constant -- so agreement is not evidence and must not be banked.
UNIONSH=${UNIONSH:-$HERE/union-probe.sh}
[ -s "$UNIONSH" ] || die "no $UNIONSH; a CONVERTED_UNION macro could not be covered"
UNION_COVERED=$(sed -n 's/^UNION_MACROS="\(.*\)"$/\1/p' "$UNIONSH")
[ -n "$UNION_COVERED" ] || die "could not read UNION_MACROS from $UNIONSH -- \
the coverage check would pass vacuously, which is worse than no check"

ALL=$(grep -v '^#' "$MACROS" | awk 'NF{print $1}' | sort -u)
for n in $ALL; do
  awk -v m="$n" '$1 !~ /^#/ && $1==m{f=1} END{exit !f}' "$STATUS" \
    || die "$n is probed but has no status in $STATUS"
done

# EVERY STATUS WORD MUST BE ONE THIS SCRIPT KNOWS.  Without this, a typo or a
# status invented in another file is treated as "not CONVERTED_*", i.e. the
# macro silently keeps a header arm and never acquires a TAB one -- the
# anti-floor gate passing because it did not recognise the name it was meant to
# catch.  Adding CONVERTED_REGS is exactly the change that could have done it.
for st in $(awk '$1 !~ /^#/ && NF{print $2}' "$STATUS" | sort -u); do
  case $st in
    UNCONVERTED|CONVERTED_SUPPLY|CONVERTED_CDATA|CONVERTED_REGS|CONVERTED_GONE) ;;
    CONVERTED_EXIST|CONVERTED_NOARM|CONVERTED_UNION) ;;
    *) die "unknown status word [$st] in $STATUS.  An unrecognised status is \
treated as UNCONVERTED by every test below, so the macro would keep a header \
arm it can no longer measure and would never be required to have a TAB arm." ;;
  esac
done

RETIRED=""
# CONVERTED_CDATA -- A THIRD STATUS, AND THE REASON FOR IT IS A FALSE GREEN
# THAT WAS CAUGHT RATHER THAN BANKED.
#
# The rule above was written for arms that DISAPPEAR.  A (c-DATA) conversion
# does something the rule did not anticipate: it turns a failing arm GREEN, for
# entirely the wrong reason.  `defaults.h' redirects the macro to a per-config
# slot, so in BOTH bases' header contexts the name now expands to the same
# target-neutral text, and the EXP probe -- correctly, on its own terms --
# reports agreement.  Measured, on the first run after Stage 2:
#
#   before   aarch64 ASM_COMMENT_START STR  FAIL  mt=[23] ref=[2f2f]
#   after    aarch64 ASM_COMMENT_START EXP  PASS  mt=[(targetm_cdata.asm_...)]
#                                                 ref=[(targetm_cdata.asm_...)]
#
# Four aarch64 arms flipped FAIL -> PASS that way, taking the aarch64 column
# from 2 to 6.  Every one of those four passes says only "both headers agree
# that this macro is now a redirect" -- which is true, and is not what the arm
# was measuring.  Banking them would have been a floor built out of progress.
#
# So a (c-DATA) macro's header arm is RETIRED, exactly as a hook conversion's
# is, and its TAB arm is mandatory by the same mechanical check.  The three
# statuses now say three different things about one question -- does the header
# probe still measure this macro's VALUE? -- and the answer for CONVERTED_CDATA
# is no.
#
# CONVERTED_REGS -- A FOURTH STATUS, AND THE SAME LESSON A SECOND TIME.
#
# ecad6abf6ae moved the register vocabulary to per-configuration data and three
# aarch64 arms went green in the same run: FIRST_PSEUDO_REGISTER,
# N_REG_CLASSES and REGNO_REG_CLASS.  Its author flagged them and did not bank
# them, which is why they are being retired here rather than discovered later.
#
# What actually happened, per macro:
#
#   FIRST_PSEUDO_REGISTER  92 (i386) / 95 (aarch64) -> 95 in ALL THREE contexts.
#   N_REG_CLASSES          34 / 20             -> 34 in all three contexts.
#     Both are now MULTI_TARGET_UNION_*, the compile-time maximum over the
#     configured back ends.  Being the same number everywhere is the POINT --
#     it is the layout of the four shared structures -- so the header probe is
#     measuring a constant and calling it agreement.
#   REGNO_REG_CLASS        `regclass_map[(x)]' / `aarch64_regno_regclass (x)'
#                          -> `((enum reg_class) targetm_regs->regno_reg_class
#                              ((int) (x)))' in all three contexts.
#
# In every case the per-base fact moved to a RUN-TIME datum reachable only
# through `targetm_regs', which macro-probe.sh is structurally blind to.  A
# green here is not weaker evidence than before; it is evidence about a
# different proposition.  Retired, with mandatory TAB arms that read the
# running cc1.
for n in $(awk '$1 !~ /^#/ && ($2=="CONVERTED_GONE" || $2=="CONVERTED_SUPPLY" || $2=="CONVERTED_CDATA" || $2=="CONVERTED_REGS") {print $1}' "$STATUS"); do
  case " $TAB_COVERED " in
    *" $n "*) ;;
    *) die "$n is marked CONVERTED in $STATUS but tab-probe.sh does not cover \
it.  A macro may only move UNCONVERTED -> CONVERTED together with its TAB arm; \
without one it would simply disappear from the score." ;;
  esac
done

# CONVERTED_EXIST -- A FIFTH STATUS, CHECKED AGAINST A SECOND LIST.
#
# Same mechanical rule, different list, and the separation is the point: a name
# in TAB_MACROS does NOT satisfy CONVERTED_EXIST and a name in EXIST_MACROS
# does NOT satisfy CONVERTED_CDATA.  Accepting "covered by either" would be one
# check satisfied by the wrong evidence -- the same defect macro-status.txt
# already records as the reason CONVERTED_REGS is separate from
# CONVERTED_CDATA.
for n in $(awk '$1 !~ /^#/ && $2=="CONVERTED_EXIST" {print $1}' "$STATUS"); do
  case " $EXIST_COVERED " in
    *" $n "*) ;;
    *) die "$n is marked CONVERTED_EXIST in $STATUS but exist-probe.sh's \
EXIST_MACROS does not cover it.  A macro may only move to CONVERTED_EXIST \
together with its EXIST arm.  Note that a TAB arm does NOT satisfy this: the \
two shapes measure different propositions." ;;
  esac
done
# ... and the converse, which is the one that would otherwise rot silently: a
# name in EXIST_MACROS that the board does not record as CONVERTED_EXIST means
# an arm is being run and reported by exist-probe.sh while the board still
# scores the macro some other way.  That is two authorities for one name, which
# is the bug this whole branch is hunting.
for n in $EXIST_COVERED; do
  st=$(awk -v m="$n" '$1 !~ /^#/ && $1==m{print $2}' "$STATUS")
  [ -n "$st" ] || die "exist-probe.sh scores $n but it has no status in \
$STATUS.  A macro measured by a harness and absent from the board is counted \
in no column at all."
  [ "$st" = CONVERTED_EXIST ] || die "exist-probe.sh scores $n but $STATUS \
says [$st].  Two authorities for one name.  Either the arm is real, in which \
case the status is CONVERTED_EXIST, or the arm should be removed from \
EXIST_MACROS."
done

# CONVERTED_UNION -- A SIXTH STATUS, AND THE WRONG-REASON GREEN IT RETIRES WAS
# BEING BANKED AS ONE OF ONLY TWO TRUSTED PASSES ON THE WHOLE BOARD.
#
# `MAX_BITSIZE_MODE_ANY_MODE' is 1024 for i386 and 8192 for aarch64 (measured,
# from the per-base generators).  The union run writes the maximum, 8192, into
# the ONE shared `insn-modes.h', which is the correct and intended fix: the
# macro sizes stack buffers in `fold-const.cc', `simplify-rtx.cc', `expr.cc'
# and `gimple-fold.cc', and each buffer's bounds check is written in terms of
# the same constant, so the value MUST be compile-time and identical in every
# translation unit (genmodes.cc:1402-1434).
#
# The header arm therefore reads 8192 in both base contexts and scores PASS --
# saying only "this name is now target-neutral", wrong-reason shape 2.  It has
# been counted as TRUSTED because nothing on the board knew the macro had been
# converted: the completeness gate derives the converted set from
# `defaults.h''s redirects and a hand-declared no-redirect list, and a macro
# converted by the genmodes UNION appears in NEITHER.  That is this branch's
# own root pattern -- one name, several authorities, no diagnostic -- aimed at
# the instrument for the second time, and in the opposite direction to the
# first: the earlier defect made a converted macro invisible, this one made it
# read as unconverted AND banked its green.
#
# Retired here, replaced by `union-probe.sh', which compares the shared answer
# against the per-base generators' own answers and can fail (fault-injected:
# `INJECT=primary' makes the shared answer the primary's 1024 and the arm
# reports FAIL, which is the state the tree was actually in before the union
# run was wired up).
for n in $(awk '$1 !~ /^#/ && $2=="CONVERTED_UNION" {print $1}' "$STATUS"); do
  case " $UNION_COVERED " in
    *" $n "*) ;;
    *) die "$n is marked CONVERTED_UNION in $STATUS but union-probe.sh's \
UNION_MACROS does not cover it.  A macro may only move to CONVERTED_UNION \
together with its UNION arm.  A TAB or EXIST arm does NOT satisfy this: the \
shapes measure different propositions." ;;
  esac
done
for n in $UNION_COVERED; do
  st=$(awk -v m="$n" '$1 !~ /^#/ && $1==m{print $2}' "$STATUS")
  [ -n "$st" ] || die "union-probe.sh scores $n but it has no status in $STATUS"
  [ "$st" = CONVERTED_UNION ] || die "union-probe.sh scores $n but $STATUS says \
$st.  Either the status is CONVERTED_UNION, or the arm should be removed from \
UNION_MACROS."
done

for n in $(awk '$1 !~ /^#/ && ($2=="CONVERTED_GONE" || $2=="CONVERTED_CDATA" || $2=="CONVERTED_REGS" || $2=="CONVERTED_EXIST" || $2=="CONVERTED_UNION") {print $1}' "$STATUS"); do RETIRED="$RETIRED $n"; done

########################################################################
# THE COMPLETENESS GATE -- "ABSENT" MUST NOT BE A THIRD, INVISIBLE VERDICT.
#
# Everything above scores over the macros that happen to be LISTED.  A macro
# that was converted and never added to macro-status.txt was therefore counted
# in NO column -- not passing, not failing, not converted, not unconverted.  It
# is the branch's root pattern (one name, several authorities, no diagnostic)
# applied to the instrument, and PRINCIPLES already names the shape twice:
# "absence of an artefact is not absence of a mechanism", and "an absent
# control is not a passing control".
#
# Measured the first time this gate ran, 2026-08-13: 67 macros are converted;
# 11 were absent from the board entirely and 31 more were present saying
# UNCONVERTED.  A hand-written note in macro-status.txt claimed sixteen.  The
# fourteen it missed were two whole families (the MOVE_*/RATIO cost macros and
# the four frame-pointer register numbers), converted with nobody recording it.
#
# THE SET IS DERIVED, NOT LISTED, because a list is exactly what failed.
# `defaults.h' redirects a converted macro by `#undef'ing the name inside the
# multi-target block and redefining it as an `mt_*' call (or, for
# ELIMINABLE_REGS, a poison identifier, or, for REG_PARM_STACK_SPACE and
# RELOAD_ELIMINABLE_REGS, leaving it undefined).  Every one of those is an
# `#undef' at column 0 after `#include "target-cdata.h"', so that is the
# derivation.  It is a property of the compiler source, which is the authority.
#
# ITS ONE BLIND SPOT, STATED RATHER THAN PAPERED OVER: a macro converted by
# REWRITING ITS CONSUMERS instead of redirecting its name never appears in
# defaults.h at all.  Three are known -- PUSH_ROUNDING, STACK_DYNAMIC_OFFSET
# and INCOMING_REG_PARM_STACK_SPACE -- and they are declared below by hand,
# which is the weakness this gate was written to remove, reintroduced in the
# small.  It is bounded two ways: each declared name must be ABSENT from the
# derived set (so a name that later acquires a redirect stops being special-
# cased silently) and must have an `mt_' declaration in target-frame.h (so it
# cannot be a typo or a fiction).
CONVERTED_NO_REDIRECT="PUSH_ROUNDING STACK_DYNAMIC_OFFSET INCOMING_REG_PARM_STACK_SPACE"

# A SECOND BLIND SPOT, FOUND BY WALKING THE `UNCONVERTED' LIST RATHER THAN BY
# TRUSTING IT: a macro converted by the genmodes UNION appears in neither
# channel above.  It has no `#undef' in defaults.h -- there is nothing to
# redirect, because the fix is that every translation unit gets ONE
# compile-time number -- and no `mt_' thunk in target-frame.h, because it is
# not a runtime read and must not become one.  `MAX_BITSIZE_MODE_ANY_MODE' sat
# on the board saying UNCONVERTED, with a green header arm banked as one of the
# board's two TRUSTED passes, while the conversion was landed and working.
#
# Bounded the same two ways as the list above, so it cannot become an
# assertion: each name must be ABSENT from the derived redirect set, and must
# be spelled by genmodes.cc's union machinery (`union_max_bitsize_any_*' /
# `union_note_max_bitsize'), which is where the maximum is actually computed.
CONVERTED_BY_UNION="MAX_BITSIZE_MODE_ANY_MODE"

DEFAULTS_H=$SRC/defaults.h
FRAME_H=$SRC/target-frame.h
[ -s "$DEFAULTS_H" ] || die "no $DEFAULTS_H -- the converted set cannot be derived"
[ -s "$FRAME_H" ] || die "no $FRAME_H -- the no-redirect list cannot be checked"

DERIVED=$(awk '/^#include "target-cdata.h"/{on=1} on && /^#undef /{print $2}' \
            "$DEFAULTS_H" | sort -u)
# NON-VACUITY.  If the anchor line ever moves or is renamed, this awk yields
# nothing and every check below passes trivially -- an all-empty read that is
# indistinguishable from "everything is on the board".  PRINCIPLES: the harness
# must refuse to score when it cannot show it read anything.
NDERIVED=$(echo "$DERIVED" | awk 'NF' | wc -l)
[ "$NDERIVED" -ge 40 ] || die "only $NDERIVED converted macros derived from \
$DEFAULTS_H (expected 60+).  The anchor '#include \"target-cdata.h\"' or the \
'#undef' shape has changed, and every completeness check below would pass \
vacuously.  Fix the derivation; do not lower this bound."

DERIVED_SP=$(echo $DERIVED)
for n in $CONVERTED_NO_REDIRECT; do
  case " $DERIVED_SP " in
    *" $n "*) die "$n is in CONVERTED_NO_REDIRECT but defaults.h DOES redirect it now. \
Remove it from the hand-written list: it is derived, and keeping it in both \
places is a second authority for the same fact." ;;
  esac
  lc=$(echo "$n" | tr 'A-Z' 'a-z')
  # Reading a FILE, not a pipe: no SIGPIPE, so `grep -q' is safe here.  It
  # would not be on the receiving end of a pipeline under `set -o pipefail',
  # which PRINCIPLES records as turning a match into a miss (rc 141).
  grep -q "^extern .*[^a-z_]mt_$lc *(" "$FRAME_H" \
    || die "$n is declared converted-without-redirect but target-frame.h \
declares no mt_ entry point for it.  An unbacked name here would exempt a \
macro from the board on nothing but an assertion."
done

# NEWLINE-NORMALISED ON PURPOSE.  `$DERIVED' is one name per LINE, and the
# `case " $SET " in *" $n "*' membership idiom below matches on SPACES.  Left
# unnormalised the idiom silently never matches, and every membership test
# reports "not a member" -- which fired immediately, as a false accusation
# against ALL_REGS.  Recorded because the failure direction was the lucky one:
# the same bug in the `missing'/`lying' loops above would have reported
# everything absent, and in a check written the other way round it would have
# reported everything present.
GENMODES_CC=$SRC/genmodes.cc
[ -s "$GENMODES_CC" ] || die "no $GENMODES_CC -- the union channel cannot be checked"
for n in $CONVERTED_BY_UNION; do
  case " $DERIVED_SP " in
    *" $n "*) die "$n is in CONVERTED_BY_UNION but defaults.h DOES redirect it \
now.  Remove it from the hand-written list: it is derived, and keeping it in \
both places is a second authority for the same fact." ;;
  esac
  grep -q "union_note_max_bitsize\|union_max_bitsize" "$GENMODES_CC" \
    || die "CONVERTED_BY_UNION names $n but genmodes.cc has no union-maximum \
machinery at all.  The channel would be an assertion rather than a fact."
  grep -qw "$n" "$GENMODES_CC" \
    || die "$n is declared converted-by-union but genmodes.cc never spells it. \
An unbacked name here would exempt a macro from the board on nothing but an \
assertion."
done

CONVERTED_SET="$DERIVED_SP $CONVERTED_NO_REDIRECT $CONVERTED_BY_UNION"

missing= ; lying=
for n in $CONVERTED_SET; do
  st=$(awk -v m="$n" '$1 !~ /^#/ && $1==m{print $2}' "$STATUS")
  if [ -z "$st" ]; then missing="$missing $n"
  elif [ "$st" = UNCONVERTED ]; then lying="$lying $n"
  fi
done
[ -z "$missing" ] || die "these macros are CONVERTED in gcc/defaults.h and are \
ABSENT from $STATUS, so they are counted in no column of any total:$missing.  \
Add them.  If a converted macro has no arm yet, its status is CONVERTED_NOARM \
-- the debt, on the board, countable -- never absence and never UNCONVERTED."
[ -z "$lying" ] || die "these macros are CONVERTED in gcc/defaults.h and \
$STATUS says UNCONVERTED:$lying.  That reading has already sent agents to \
convert macros that were already converted.  Use CONVERTED_NOARM if there is \
no arm yet."

# And the converse direction.  A CONVERTED_NOARM entry must be genuinely
# converted (otherwise it is UNCONVERTED wearing a status that excuses it from
# ever growing an arm) and must genuinely have no arm (otherwise the debt
# column overstates and the coverage columns understate).
for n in $(awk '$1 !~ /^#/ && $2=="CONVERTED_NOARM" {print $1}' "$STATUS"); do
  case " $CONVERTED_SET " in
    *" $n "*) ;;
    *) die "$n is marked CONVERTED_NOARM but is not in the derived converted \
set.  CONVERTED_NOARM excuses a macro from needing an arm; it must not be \
reachable for a macro that is simply unconverted." ;;
  esac
  case " $TAB_COVERED $EXIST_COVERED " in
    *" $n "*) die "$n is marked CONVERTED_NOARM but IS covered by a probe \
list.  The debt column would overstate and the coverage column understate. \
Give it the status of the arm it actually has." ;;
    *) ;;
  esac
done

########################################################################
# THE SUMMARY, WITH THE POPULATIONS KEPT APART.
#
# One total a reader can trust means one total that does not silently add
# unlike things.  Four numbers, and the fourth is the one that used to be
# invisible.
n_unconv=$(awk '$1 !~ /^#/ && $2=="UNCONVERTED"' "$STATUS" | wc -l)
n_tab=$(awk '$1 !~ /^#/ && ($2=="CONVERTED_SUPPLY" || $2=="CONVERTED_CDATA" || $2=="CONVERTED_REGS" || $2=="CONVERTED_GONE")' "$STATUS" | wc -l)
n_exist=$(awk '$1 !~ /^#/ && $2=="CONVERTED_EXIST"' "$STATUS" | wc -l)
n_noarm=$(awk '$1 !~ /^#/ && $2=="CONVERTED_NOARM"' "$STATUS" | wc -l)
NOARM_LIST=$(awk '$1 !~ /^#/ && $2=="CONVERTED_NOARM" {printf "%s ", $1}' "$STATUS")
[ -n "$NOARM_LIST" ] || die "CONVERTED_NOARM list read empty while the count \
says $n_noarm -- the aarch64 PASS decomposition below would report every pass \
as trusted, which is the exact inversion this branch keeps paying for"
n_union=$(awk '$1 !~ /^#/ && $2=="CONVERTED_UNION"' "$STATUS" | wc -l)
n_board=$(awk '$1 !~ /^#/ && NF' "$STATUS" | wc -l)
echo "status: $n_board macros on the board = \
$n_unconv unconverted \
+ $n_tab converted with a TAB (value) arm \
+ $n_exist converted with an EXIST (existence/distinctness) arm \
+ $n_union converted by the genmodes UNION with a UNION (maximum) arm \
+ $n_noarm converted with NO ARM AT ALL (the measurement debt)"
echo "status: completeness -- $NDERIVED converted macros derived from \
gcc/defaults.h plus $(echo $CONVERTED_NO_REDIRECT | wc -w) declared \
converted-without-redirect plus $(echo $CONVERTED_BY_UNION | wc -w) declared \
converted-by-union; all present on the board and none saying UNCONVERTED"
echo "status: an EXIST arm is NOT a value arm, and a UNION arm is neither. \
Do not add $n_tab, $n_exist and $n_union."
echo "status: retiring from the header probe:${RETIRED:- none}"

NAMES=$(for n in $ALL; do
          case " $RETIRED " in *" $n "*) ;; *) echo "$n";; esac
        done)
NMACRO=$(echo "$NAMES" | wc -l)

# THE NON-VACUITY CHECK ON THE HEADER LIST, AND WHY IT IS NO LONGER A CONSTANT.
#
# It used to be `[ "$NMACRO" -ge 100 ]'.  That number was calibrated when the
# retire set was small, and it is a CONTROL WITH AN EXPIRY DATE in exactly the
# sense PRINCIPLES records for arm 0's INT control: the header population
# shrinks every time a macro legitimately acquires a TAB or EXIST arm, so the
# floor was guaranteed to fire eventually ON A CORRECT RUN.  It did, at 82,
# when 28 macros moved off CONVERTED_NOARM onto the EXIST arm -- a RETIREMENT
# WITH A REPLACEMENT, which is the shape this project wants, refused by a guard
# that could not tell it from a collapse.
#
# The obvious repair -- lower 100 to 80 -- would expire again on the next
# retirement, and would be indistinguishable from editing a probe to move a
# number.  So the check is an ARITHMETIC IDENTITY instead, which is invariant
# under legitimate retirement and is violated by the thing the floor was
# actually guarding against (a parse of the board or of the retire set that
# silently reads short):
#
#     NMACRO + |RETIRED intersect ALL| == |ALL|,   and NMACRO > 0.
#
# AGAINST |ALL| AND NOT AGAINST THE BOARD, and the first draft of this check
# got that wrong -- which is worth keeping, because the wrong version FIRED and
# told the truth about something else.  It reported `82 probed + 63 retired =
# 145, but the board has 149', and the four missing are real: eleven macros are
# on the board and have never been in `macro-probe-list.txt' at all, because
# they never had a header arm to begin with (the register-class enumerators and
# the existence macros).  The board and the header list are DIFFERENT
# populations and equating them is the same mistake as adding the TAB and EXIST
# totals.  The identity has to be within one population.
#
# A list that reads short now fails BY NAME with the arithmetic printed, at any
# list size, rather than at a threshold somebody has to remember to move.
NALL=$(echo "$ALL" | wc -l)
NRETIRED=$(for n in $ALL; do
             case " $RETIRED " in *" $n "*) echo "$n";; esac
           done | wc -l)
[ "$NMACRO" -gt 0 ] || die "the header macro list is EMPTY; refusing to report"
[ $((NMACRO + NRETIRED)) -eq "$NALL" ] || die "header list arithmetic does \
not close: $NMACRO probed + $NRETIRED retired = $((NMACRO + NRETIRED)), but \
macro-probe-list.txt holds $NALL macros.  Something read short -- do NOT adjust \
a threshold, find the entry that went missing."
echo "probing $NMACRO macros in $BUILD"

cd "$BUILD/gcc" || die "cd $BUILD/gcc"

########################################################################
# ARM 0 -- POSITIVE CONTROL, RUN FIRST.
#
# Probe a macro whose value is known and DIFFERS between the two bases, and one
# that is known to be identical, before probing anything unknown.  If the
# harness cannot reproduce the control it is not measuring the two bases and
# every later number is worthless.
#
# RE-ANCHORED 2026-08-12, FROM `FIRST_PSEUDO_REGISTER' TO `STACK_POINTER_REGNUM'.
#
# The control WAS 92/95/92 and it FIRED, correctly, the first time it was run
# after the register-vocabulary change: all three contexts answered 95.  That
# is not the harness breaking.  `FIRST_PSEUDO_REGISTER' is now a compile-time
# UNION -- deliberately the same number in every consumer translation unit,
# because it is the layout of `target_hard_regs' -- so it has stopped being a
# thing the header probe can discriminate bases with.  The per-base fact moved
# to `targetm_regs->first_pseudo_register', which is a RUN-TIME datum and
# therefore TAB's business, not this probe's.
#
# THIS IS THE `wrong-reason flip' THE BRIEF WARNS ABOUT, SEEN FROM THE OTHER
# SIDE, so it is worth being exact about what is and is not being claimed:
#   * `FIRST_PSEUDO_REGISTER' and `N_REG_CLASSES' agreeing across the three
#     contexts is NOT evidence that anything was fixed.  It is evidence that
#     they became target-neutral.  They must be RETIRED from this probe, and
#     the runtime counts covered by an arm that reads the running `cc1'.
#   * Re-anchoring the control is a different act from retiring an arm.  The
#     control exists to prove the harness can tell the bases apart at all, and
#     `STACK_POINTER_REGNUM' (i386 7, aarch64 31) is untouched by this change
#     and still proves exactly that.  Changing the control to something that
#     agreed would have been green-washing; changing it to something that still
#     differs is keeping it alive.
#
# RE-ANCHORED 2026-08-13 (third time), FROM `STACK_POINTER_REGNUM' TO
# `MIN_UNITS_PER_WORD', AND THE COMMENT ABOVE PREDICTED THIS EXACT DEATH.
#
# The re-anchor of 2026-08-12 wrote, of SELECT_CC_MODE: "It stays a control
# only while it stays UNCONVERTED; when it is converted, the right move is
# another independent differing witness, not this one weakened."  The same
# sentence applied to arm 0's own witness and nobody applied it.
# `STACK_POINTER_REGNUM' was converted -- `defaults.h:2799' now redirects it to
# `(mt_stack_pointer_regnum ())' -- and a run-time call is not an integral
# constant expression, so the control's `char cq[STACK_POINTER_REGNUM]' does
# not compile in ANY context.
#
# THE WHOLE HARNESS WAS DEAD, NOT DEGRADED, and that is worth being exact
# about because it changes what past numbers mean.  Arm 0 runs before anything
# is probed, and it `die's with rc=9.  Measured on this tree before any change
# in this commit: `macro-probe-run.sh /tmp/b-a7c-t108' exits 9 after printing
# the status line, with
#
#   defaults.h:2799:55: error: size of array 'cq' is not an integral
#   constant-expression
#
# and produces NO results.txt and NO summary.  So the scoreboard figures in
# circulation (224 header arms, i386 112/0, aarch64 8/104) cannot be
# reproduced by running this script today; they are the last successful run's,
# not a current reading.  This is the good failure mode -- the control refused
# to score rather than scoring nothing as clean -- but a control that cannot
# COMPILE is one step from a harness whose summary prints anyway, which is
# what arm 0b exists to catch.
#
# `MIN_UNITS_PER_WORD' is chosen on the independence criterion the previous
# re-anchor wrote down, and measured in all three contexts before being
# adopted (i386 4, aarch64 8, mt 4):
#   * it is NOT in the frame/stack/argument/register-vocabulary families that
#     the conversion programme is currently working through, so no member of
#     the family that just killed this control can kill it again;
#   * it is not the EXP control (`SELECT_CC_MODE') nor the STR control
#     (`GLOBAL_ASM_OP'), so the three controls rest on three macros in three
#     different families -- the property the second re-anchor was written to
#     restore and which lasted one day;
#   * 4 vs 8 is a real numeric spread, not a 0/1 bit.  Several candidates
#     measured 0/1 (`SLOW_BYTE_ACCESS' 0/1, `CASE_VECTOR_PC_RELATIVE' 0/1,
#     `DEFAULT_SIGNED_CHAR' 1/0) and were rejected: a probe bug that yields a
#     defaulted 0 is indistinguishable from a correct reading on those.
#     `FUNCTION_BOUNDARY' (8/32) was rejected for the first criterion -- it is
#     a `*_BOUNDARY', and `STACK_BOUNDARY' and `PARM_BOUNDARY' are already
#     converted.
#
# This is a REPAIR of a control that cannot run, not the retirement of an arm
# that fails.  The distinction is the test-harness floor, and it cuts the
# other way here: leaving the control dead leaves the entire header probe
# unrunnable, which reports nothing rather than reporting less.
########################################################################
# RE-ANCHORED 2026-08-13 A SECOND TIME ON THE SAME DAY, AND THIS TIME NOT ONTO
# A MACRO AT ALL.  `MIN_UNITS_PER_WORD' lasted hours.  `UNITS_PER_WORD' became
# `(mt_units_per_word ())', `defaults.h:1120' defines MIN_UNITS_PER_WORD AS
# UNITS_PER_WORD, and `char cq[MIN_UNITS_PER_WORD]' therefore stopped compiling
# in every context -- rc=9, no results.txt, no summary, for the THIRD time
# (SELECT_CC_MODE -> STACK_POINTER_REGNUM -> MIN_UNITS_PER_WORD).
#
# THE PATTERN IS NOT "WE PICKED BADLY THREE TIMES".  Each re-anchor satisfied
# its own written criteria and each died to this project's own conversion
# programme, which is systematically converting exactly the population the
# criteria drew from.  A control anchored on a real GCC target macro has an
# expiry date BY CONSTRUCTION, and the expiry is catastrophic rather than
# graceful: arm 0 runs before anything is probed, so the whole header probe
# becomes unrunnable and the last successful run's figures get quoted as
# current.  That already happened for about a day.
#
# So the fourth re-anchor is onto a FIXTURE THIS SCRIPT WRITES.  Three tiny
# headers are generated into the three directories the three contexts resolve
# quoted includes from:
#
#     $BUILD/gcc/mtp-ctl-{int,str,exp}.h            <- the `mt' context, via -I.
#     $BUILD/gcc/i386-inc/mtp-ctl-{int,str,exp}.h   <- via -Ii386-inc
#     $BUILD/gcc/aarch64-inc/mtp-ctl-{int,str,exp}.h<- via -Iaarch64-inc
#
# IT RIDES THE SAME MECHANISM AS THE REAL PROBES, which is the only thing that
# makes it a control at all.  The real probes reach `tm.h' by a QUOTED include
# from a source in $OUT resolved against `$inc $CPPFLAGS'; the fixture is
# reached by a quoted include from the SAME source against the SAME flags.  A
# fixture reached some other way -- a `-D' on the command line, a file next to
# the probe source -- would prove the harness can pass a value to a compiler,
# which nobody doubts, and would prove nothing about `-I<base>-inc'.
#
# THE THREE CRITERIA THE PREVIOUS RE-ANCHORS WROTE DOWN, SATISFIED BY
# CONSTRUCTION RATHER THAN BY A SEARCH FOR A SURVIVING MACRO:
#   * INDEPENDENT of the conversion programme.  `MTP_CTL_INT' is not a GCC
#     macro; no back end defines it, `defaults.h' cannot redirect it, no hook
#     conversion can delete it.  There is no family it can be dragged down
#     with, because it has no family.
#   * IN A DIFFERENT FAMILY FROM THE OTHER TWO CONTROLS.  The three controls
#     key on three different macros in three different FILES -- and the file
#     separation is deliberate: sharing one fixture header would make one
#     truncated write take out all three phases at once, which is precisely
#     the "two controls that move together are one control with two names"
#     defect the 2026-08-12 re-anchor was written to remove.
#   * A REAL NUMERIC SPREAD, NOT A 0/1 BIT.  4241 vs 8317 -- and unlike the
#     rejected `SLOW_BYTE_ACCESS'-style candidates, a probe bug that defaults
#     to 0, or that reads a stale/absent value, cannot land on either number
#     by accident.  The old control's 4-vs-8 could plausibly be produced by
#     some other macro; 4241 cannot.
#
# WHAT THIS FIXTURE DOES *NOT* PROVE, STATED RATHER THAN PAPERED OVER.  It
# proves the `-I' SELECTION differs between contexts and carries a per-context
# answer into a probe compiled exactly like the real ones.  It does not prove
# the two bases' REAL header sets differ -- that is a fact about the tree, not
# about the instrument, and the old real-macro control did carry it.  It is
# not dropped: ARM 0c below asserts it directly on the `-dM' dumps, which is a
# text-level fact no macro conversion can flatten (a conversion rewrites both
# bases' headers alike, so it cannot make them equal).
#
# ORIGIN TAGS, AND THE SILENT FALLBACK THEY CATCH.  `-I.' is in CPPFLAGS for
# every context, so a MISSING `aarch64-inc/mtp-ctl-int.h' does not fail to
# compile -- it silently resolves to the build-root copy, which holds the
# PRIMARY's answer.  That is this branch's own root bug aimed at its own
# control, and it would read as "the two contexts agree".  So every fixture
# also states WHICH DIRECTORY IT IS, the arm checks that against `ctx_dir',
# and `fixture_verify' checks all nine files on disk BEFORE anything is
# compiled.  "The control is broken" and "the contexts agree" are therefore
# two different diagnostics with two different texts.
#
# INJECTION ARMS (both required by the brief, both re-runnable):
#   MTP_INJECT=same-context   collapse the contexts.  Arm 0 must FAIL by name.
#   MTP_INJECT=break-fixture  delete a fixture file.  `fixture_verify' must
#                             refuse, with wording that cannot be mistaken for
#                             a verdict about the contexts.
########################################################################
FIX_INT=mtp-ctl-int.h
FIX_STR=mtp-ctl-str.h
FIX_EXP=mtp-ctl-exp.h

# `mt' takes the PRIMARY's answers, because `mt' IS the primary's header set --
# the same relation the real probes have and the same one arm 0 has always
# asserted.  ARM 0c is what keeps that from being a bare assumption.
fix_int    () { case $1 in aarch64) echo 8317 ;; *) echo 4241 ;; esac; }
fix_origin () { case $1 in aarch64) echo 202  ;; *) echo 101  ;; esac; }
fix_str    () { case $1 in aarch64) echo mtpglobal ;; *) echo mtpglobl ;; esac; }
fix_call   () { case $1 in
                  aarch64) echo 'mtp_aarch64_select_cc_mode (OP, X, Y)' ;;
                  *)       echo 'mtp_i386_cc_mode ((OP),(X),(Y))' ;;
                esac; }

fixture_write () {
  local ctx d
  for ctx in $CTXS; do
    d=$(ctx_dir $ctx)
    [ -d "$d" ] || die "control fixture: $d does not exist, so the $ctx \
context has no directory to be distinguished by.  This is a broken BUILD DIR, \
not a verdict about the contexts."
    rm -f "$d/$FIX_INT" "$d/$FIX_STR" "$d/$FIX_EXP"
    printf '#define MTP_CTL_INT %s\n#define MTP_CTL_INT_ORIGIN %s\n' \
      "$(fix_int $ctx)" "$(fix_origin $ctx)" > "$d/$FIX_INT" \
      || die "control fixture: cannot write $d/$FIX_INT"
    printf '#define MTP_CTL_STR "%s"\n#define MTP_CTL_STR_ORIGIN %s\n' \
      "$(fix_str $ctx)" "$(fix_origin $ctx)" > "$d/$FIX_STR" \
      || die "control fixture: cannot write $d/$FIX_STR"
    printf '#define MTP_CTL_EXP(OP,X,Y) %s\n#define MTP_CTL_EXP_ORIGIN %s\n' \
      "$(fix_call $ctx)" "$(fix_origin $ctx)" > "$d/$FIX_EXP" \
      || die "control fixture: cannot write $d/$FIX_EXP"
  done
  if [ "$MTP_INJECT" = break-fixture ]; then
    rm -f "$(ctx_dir aarch64)/$FIX_INT"
    echo "INJECT: deleted $(ctx_dir aarch64)/$FIX_INT"
  fi
  fixture_write_verify
}

# ASSERT ON THE CONTENT, BY NAME AND VALUE, AND RUN IT FIRST.  PRINCIPLES
# records a generator that ran, exited 0 and changed nothing; existence,
# timestamp, exit status and non-emptiness all passed on it.  Nine files are
# checked for the exact `#define' line they were supposed to receive.  Note
# these are FILE reads, not pipelines, so `grep -q' cannot turn a match into a
# miss via SIGPIPE under `set -o pipefail'.
FIXBAD=""
fixchk () {                       # fixchk <file> <exact line> <label>
  # `2>/dev/null' is forbidden on this project, so ABSENCE is tested first and
  # separately -- which also keeps "the file is gone" and "the file says the
  # wrong thing" as two distinguishable reports rather than one.
  if [ ! -f "$1" ]; then FIXBAD="$FIXBAD $1[ABSENT:$3]"; return; fi
  grep -qxF "$2" "$1" || FIXBAD="$FIXBAD $1[WRONG-CONTENT:$3]"
}
fixture_write_verify () {
  local ctx d bad
  FIXBAD=""
  for ctx in $CTXS; do
    d=$(ctx_dir $ctx)
    fixchk "$d/$FIX_INT" "#define MTP_CTL_INT $(fix_int $ctx)" value
    fixchk "$d/$FIX_INT" "#define MTP_CTL_INT_ORIGIN $(fix_origin $ctx)" origin
    fixchk "$d/$FIX_STR" "#define MTP_CTL_STR \"$(fix_str $ctx)\"" string
    fixchk "$d/$FIX_EXP" "#define MTP_CTL_EXP(OP,X,Y) $(fix_call $ctx)" call
  done
  bad=$FIXBAD
  [ -z "$bad" ] || die "THE CONTROL FIXTURE IS BROKEN -- these generated files \
are absent or do not hold the #define they were written with:$bad.  READ THIS \
AS 'THE INSTRUMENT IS BROKEN', NOT AS A VERDICT ABOUT THE TWO CONTEXTS: no \
context has been compared with any other at this point, and nothing has been \
probed.  A missing per-base fixture would otherwise resolve through -I. to the \
build-root copy and read exactly like 'the contexts agree'."
}
fixture_write
echo "control: fixture written and content-verified in \
$(for c in $CTXS; do printf '%s ' "$(ctx_dir $c)"; done)"

CTLMACRO=MTP_CTL_INT
control () {
  local ctx inc v o
  for ctx in $CTXS; do
    inc=$(ctx_inc $ctx)
    { echo "$PRE"
      echo "#include \"$FIX_INT\""
      echo "char cq[$CTLMACRO];"
      echo "char cqo[${CTLMACRO}_ORIGIN];"
    } > "$OUT/ctl.cc"
    g++ -c -o "$OUT/ctl.o" "$OUT/ctl.cc" $inc $CPPFLAGS -std=c++14 -w \
        > "$OUT/err-ctl-$ctx.txt" 2>&1 \
      || { cat "$OUT/err-ctl-$ctx.txt"; die "control probe ($CTLMACRO) did not \
compile in $ctx.  $CTLMACRO is a FIXTURE this script writes, not a GCC macro, \
so this is not a conversion killing the control: either $(ctx_dir $ctx) is not \
on the $ctx include path (the mechanism the real probes ride is broken) or the \
fixture is malformed.  Neither is a statement about whether the contexts \
differ."; }
    v=$(nm -S --defined-only "$OUT/ctl.o" | awk '$4=="cq"{print strtonum("0x" $2)}')
    o=$(nm -S --defined-only "$OUT/ctl.o" | awk '$4=="cqo"{print strtonum("0x" $2)}')
    [ -n "$v" ] && [ -n "$o" ] \
      || die "control: nm produced nothing for $ctx (tool present but silent)"
    # ORIGIN FIRST.  If the context resolved somebody else's fixture, the VALUE
    # comparison below would be comparing a directory with itself and would
    # report agreement -- the exact reading this control exists to make
    # impossible.
    [ "$o" = "$(fix_origin $ctx)" ] || die "control: the $ctx context resolved \
$FIX_INT from the WRONG DIRECTORY -- it reports origin $o, and $(ctx_dir $ctx) \
was written with origin $(fix_origin $ctx).  THE TWO PROBE CONTEXTS ARE NOT \
DISTINCT: $ctx is picking up another context's headers through the include \
path, so every arm in this run would compare a header set with itself.  Check \
the -I order in ctx_inc/CPPFLAGS before believing any figure from this harness."
    echo "control $ctx $CTLMACRO=$v origin=$o"
    eval "CTL_$ctx=$v"
  done
  [ "$CTL_i386" = 4241 ] || die "control: i386 $CTLMACRO=$CTL_i386, expected 4241"
  [ "$CTL_aarch64" = 8317 ] || die "control: aarch64 $CTLMACRO=$CTL_aarch64, expected 8317"
  [ "$CTL_mt" = 4241 ] || die "control: mt $CTLMACRO=$CTL_mt, expected 4241 (mt == primary)"
  [ "$CTL_i386" != "$CTL_aarch64" ] || die "control: the two bases measured the \
same; the contexts are not distinguishable"
  echo "control: OK -- the three contexts are distinguishable through the same \
quoted-include/-I mechanism the real probes use, and mt == i386"
}
control

########################################################################
# ARM 0b -- POSITIVE CONTROLS FOR THE STR AND EXP PHASES.
#
# Added 2026-08-11 after an audit.  Arm 0 controlled the INT phase only, and
# INT is the phase least likely to degrade silently.  The two weaker phases had
# NO control at all, and the gap was asymmetric in the dangerous direction:
#
#   * STR: 4 of 138 arms.  If the byte probe silently produced nothing, those
#     macros fall through to EXP or to KIND and still score FAIL, i.e. the
#     scoreboard is unchanged and the phase's death is invisible.
#   * EXP: 168 of the 276 arms -- the majority of the instrument -- and in the
#     recorded run it has ZERO passes.  A phase that never once reports
#     agreement has never demonstrated that it CAN.  If normalisation, marker
#     handling or the -dM parse degraded so that every expansion came out empty
#     or garbled, every EXP arm would still be red and the summary would look
#     exactly as it looks when the phase is healthy.  Red for the right reason
#     and red for no reason are indistinguishable without this control.
#
# So: one macro whose bytes are known and DIFFER (GLOBAL_ASM_OP, `.globl' vs
# `.global' -- the pair that assembles identically), one macro whose expansion
# is known and differs (SELECT_CC_MODE), and one SYNTHETIC macro defined by
# this script identically in all three contexts, which EXP must report as
# AGREEING.  The synthetic one is the only evidence that a PASS is reachable.
#
# RE-ANCHORED 2026-08-12 (second time), FROM `STACK_POINTER_REGNUM' TO
# `SELECT_CC_MODE', AND THE REASON IS INDEPENDENCE, NOT A FAILING CONTROL.
#
# History: the EXP witness was REGNO_REG_CLASS until ecad6abf6ae converted it
# to a run-time dispatch, at which point it expanded identically in all three
# contexts and could no longer witness anything.  It was re-pointed at
# STACK_POINTER_REGNUM -- which is correct on its own terms, and which arm 0's
# INT control had ALREADY been re-pointed at in the same change.
#
# That left the INT control and the EXP control resting on ONE macro.  Two
# controls that move together are one control with two names: any future change
# to STACK_POINTER_REGNUM -- and it IS in the conversion programme, listed
# UNCONVERTED in macro-status.txt and named in MACRO-LEAK.md as 7-vs-31 -- would
# take out the INT and EXP controls in the same run, and the summary would still
# print.  The whole point of arm 0b is that a phase can die invisibly.
#
# `SELECT_CC_MODE' is chosen for what it does NOT touch:
#   * it is not a register macro, not a count, and not in the register
#     vocabulary ecad6abf6ae moved, so no register work can flip it;
#   * it expands to a DIFFERENT CALLEE per base -- `ix86_cc_mode ((OP),(X),(Y))'
#     against `aarch64_select_cc_mode (OP, X, Y)' -- which is the one kind of
#     difference EXP is strongest at seeing, rather than a bare integer that
#     INT could have valued anyway;
#   * it is function-like, so it also exercises the dummy-argument path that
#     168 of the real EXP arms use and that arm 0 never touches.  The previous
#     witness was object-like and left that path uncontrolled.
# It stays a control only while it stays UNCONVERTED; when it is converted, the
# right move is another independent differing witness, not this one weakened.
########################################################################
CTLDEF='#define MTPCTL_AGREE(x) mtpctl_callee ((x), 42)'

str_exp_control () {
  local ctx inc agree rrc gao sby sor eor
  for ctx in $CTXS; do
    inc=$(ctx_inc $ctx)

    # --- STR control: the MTP_CTL_STR fixture, byte exact, via the same
    #     sizeof/index shape the STR phase uses.  If this cannot be valued,
    #     STR is dead.  Index 7 is where "mtpglobl" and "mtpglobal" first
    #     differ in a BYTE as well as in length, so this control now exercises
    #     both halves of the phase; the GLOBAL_ASM_OP version compared lengths
    #     only.  (This index was written as 6 first and the control CAUGHT IT
    #     -- both bases read 98, 'b' -- which is the arm doing its job against
    #     its own author on its first run.)
    { echo "$PRE"
      echo "#include \"$FIX_STR\""
      echo 'char ctl_len[sizeof (MTP_CTL_STR)];'
      echo 'char ctl_b0[(MTP_CTL_STR)[7] + 129];'
      echo 'char ctl_so[MTP_CTL_STR_ORIGIN];'
    } > "$OUT/ctlstr.cc"
    g++ -c -o "$OUT/ctlstr.o" "$OUT/ctlstr.cc" $inc $CPPFLAGS -std=c++14 -w \
        > "$OUT/err-ctlstr-$ctx.txt" 2>&1 \
      || { cat "$OUT/err-ctlstr-$ctx.txt"; die "STR control: the MTP_CTL_STR \
fixture did not compile in $ctx -- the STR phase cannot work.  This is the \
instrument, not a converted macro: see fixture_write."; }
    gao=$(nm -S --defined-only "$OUT/ctlstr.o" | awk '$4=="ctl_len"{print strtonum("0x" $2)}')
    sby=$(nm -S --defined-only "$OUT/ctlstr.o" | awk '$4=="ctl_b0"{print strtonum("0x" $2)-129}')
    sor=$(nm -S --defined-only "$OUT/ctlstr.o" | awk '$4=="ctl_so"{print strtonum("0x" $2)}')
    [ -n "$gao" ] && [ -n "$sby" ] && [ -n "$sor" ] \
      || die "STR control: nm produced nothing for $ctx"
    [ "$sor" = "$(fix_origin $ctx)" ] || die "STR control: the $ctx context \
resolved $FIX_STR from the WRONG DIRECTORY (origin $sor, expected \
$(fix_origin $ctx) from $(ctx_dir $ctx)).  The contexts are not distinct."
    echo "control-str $ctx sizeof(MTP_CTL_STR)=$gao byte7=$sby origin=$sor"
    eval "CTLS_$ctx=$gao"; eval "CTLB_$ctx=$sby"

    # --- EXP control: the synthetic agreeing macro and a known-differing one,
    #     through the SAME marker/normalise path as the real EXP phase.
    { echo "$PRE"; echo "#include \"$FIX_EXP\""; echo "$CTLDEF"
      echo 'MTPBEGIN 1 MTPMID MTPCTL_AGREE(zz) MTPEND'
      echo 'MTPBEGIN 2 MTPMID MTP_CTL_EXP (mtpop, mtpx, mtpy) MTPEND'
      echo 'MTPBEGIN 3 MTPMID MTP_CTL_EXP_ORIGIN MTPEND'
    } > "$OUT/ctlexp.cc"
    g++ -E "$OUT/ctlexp.cc" $inc $CPPFLAGS -std=c++14 -w \
        > "$OUT/ctlexp-$ctx.i" 2> "$OUT/err-ctlexp-$ctx.txt" \
      || { cat "$OUT/err-ctlexp-$ctx.txt"; die "EXP control: preprocessing failed in $ctx"; }
    tr '\n' ' ' < "$OUT/ctlexp-$ctx.i" | sed 's/MTPBEGIN/\n/g' | grep MTPEND \
      | sed 's/MTPEND.*$//' \
      | awk -F'MTPMID' 'NF==2 { k=$1; b=$2;
            gsub(/[ \t]+/," ",k); gsub(/^ +| +$/,"",k);
            gsub(/[ \t]+/," ",b); gsub(/^ +| +$/,"",b); print k "|" b }' \
      > "$OUT/ctlexp-$ctx.txt"
    [ "$(wc -l < "$OUT/ctlexp-$ctx.txt")" = 3 ] \
      || die "EXP control: captured $(wc -l < "$OUT/ctlexp-$ctx.txt") of 3 expansions in $ctx"
    agree=$(awk -F'|' '$1==1{print $2}' "$OUT/ctlexp-$ctx.txt")
    rrc=$(awk -F'|' '$1==2{print $2}' "$OUT/ctlexp-$ctx.txt")
    eor=$(awk -F'|' '$1==3{print $2}' "$OUT/ctlexp-$ctx.txt")
    [ "$eor" = "$(fix_origin $ctx)" ] || die "EXP control: the $ctx context \
resolved $FIX_EXP from the WRONG DIRECTORY (origin [$eor], expected \
$(fix_origin $ctx) from $(ctx_dir $ctx)).  The contexts are not distinct."
    # An expansion that is still the macro's own name is a non-expansion, and a
    # non-expansion compared with a non-expansion looks like agreement.
    case $agree in *MTPCTL_AGREE*) die "EXP control: MTPCTL_AGREE did not expand in $ctx";; esac
    case $rrc in *MTP_CTL_EXP*) die "EXP control: MTP_CTL_EXP did not expand in $ctx";; esac
    # The witness must still be a CALL, not a bare token: if a future change
    # made MTP_CTL_EXP expand to a constant, the two bases could still
    # differ and the control would pass while no longer exercising the
    # differing-callee path it was chosen for.
    case $rrc in *'('*')'*) ;; *) die "EXP control: MTP_CTL_EXP expanded to \
[$rrc] in $ctx, which is not a call.  The witness was chosen because it names a \
different FUNCTION per base; if it has stopped doing that it is no longer \
controlling the case it claims to.";; esac
    [ -n "$agree" ] || die "EXP control: empty expansion in $ctx"
    echo "control-exp $ctx agree=[$agree] rrc=[$rrc]"
    eval "CTLA_$ctx=\$agree"; eval "CTLR_$ctx=\$rrc"
  done

  # STR must be able to SEE a difference, in BOTH of the things the phase
  # measures: the length (mtpglobl 8+NUL vs mtpglobal 9+NUL) and an individual
  # byte (index 6: 'l' 108 vs 'a' 97).
  [ "$CTLS_i386" = 9 ] || die "STR control: i386 sizeof(MTP_CTL_STR)=$CTLS_i386, expected 9"
  [ "$CTLS_aarch64" = 10 ] || die "STR control: aarch64 sizeof(MTP_CTL_STR)=$CTLS_aarch64, expected 10"
  [ "$CTLS_mt" = 9 ] || die "STR control: mt sizeof(MTP_CTL_STR)=$CTLS_mt, expected 9 (mt == primary)"
  [ "$CTLS_i386" != "$CTLS_aarch64" ] || die "STR control: the two bases measured the same length; STR cannot discriminate"
  [ "$CTLB_i386" = 108 ] || die "STR control: i386 MTP_CTL_STR[7]=$CTLB_i386, expected 108 ('l')"
  [ "$CTLB_aarch64" = 97 ] || die "STR control: aarch64 MTP_CTL_STR[7]=$CTLB_aarch64, expected 97 ('a')"
  [ "$CTLB_i386" != "$CTLB_aarch64" ] || die "STR control: the two bases \
measured the same BYTE.  A length-only difference would still be caught, but \
the per-byte arm -- the one that exists because .globl and .global assemble \
identically -- would be uncontrolled."

  # EXP must be able to report AGREEMENT (the direction never exercised by the
  # real macro set, which is 100% red under EXP) ...
  [ "$CTLA_mt" = "$CTLA_i386" ] && [ "$CTLA_mt" = "$CTLA_aarch64" ] \
    || die "EXP control: a macro defined IDENTICALLY in all three contexts was \
reported as differing (mt=[$CTLA_mt] i386=[$CTLA_i386] aarch64=[$CTLA_aarch64]). \
Every EXP FAIL in this run would be unattributable."
  # ... and to report DISAGREEMENT.
  [ "$CTLR_mt" != "$CTLR_aarch64" ] \
    || die "EXP control: MTP_CTL_EXP is written to name a DIFFERENT CALLEE per \
base (mtp_i386_cc_mode vs mtp_aarch64_select_cc_mode) and EXP reported it \
identical; the phase cannot discriminate"
  [ "$CTLR_mt" = "$CTLR_i386" ] \
    || die "EXP control: mt and i386 disagree on MTP_CTL_EXP, but mt IS the \
i386 header set; the contexts are not what they claim to be"
  echo "control: OK -- STR discriminates by length (9 vs 10) and by byte \
(108 vs 97); EXP reports agreement AND disagreement, so an EXP FAIL is a \
measurement and not a dead phase"
}
str_exp_control

# INDEPENDENCE OF THE CONTROLS, CHECKED RATHER THAN ASSERTED IN A COMMENT.
#
# Read the witness names back out of the probe sources the controls actually
# compiled -- not out of variables that could drift from them -- and require
# the three phases to rest on three different macros.  Between 2026-08-12
# morning and this run, INT and EXP both keyed on STACK_POINTER_REGNUM, and
# nothing in the harness would have said so.
ctl_int_macro=$(sed -n 's/^char cq\[\([A-Za-z_][A-Za-z0-9_]*\)\].*/\1/p' "$OUT/ctl.cc")
ctl_str_macro=$(sed -n 's/^char ctl_len\[sizeof (\([A-Za-z_][A-Za-z0-9_]*\))\].*/\1/p' "$OUT/ctlstr.cc")
ctl_exp_macro=$(sed -n 's/^MTPBEGIN 2 MTPMID \([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' "$OUT/ctlexp.cc")
for v in "$ctl_int_macro" "$ctl_str_macro" "$ctl_exp_macro"; do
  [ -n "$v" ] || die "could not read a control's witness macro back out of its \
own probe source (INT=[$ctl_int_macro] STR=[$ctl_str_macro] EXP=[$ctl_exp_macro]); \
the independence check would pass vacuously"
done
{ [ "$ctl_int_macro" != "$ctl_exp_macro" ] && [ "$ctl_int_macro" != "$ctl_str_macro" ] \
  && [ "$ctl_str_macro" != "$ctl_exp_macro" ] ; } \
  || die "two controls key on the same macro (INT=$ctl_int_macro \
STR=$ctl_str_macro EXP=$ctl_exp_macro).  They are then one control with two \
names: a single change to that macro takes both out in the same run, and the \
summary still prints."
echo "control: OK -- the three phases rest on three DIFFERENT macros \
(INT=$ctl_int_macro STR=$ctl_str_macro EXP=$ctl_exp_macro)"

# ... AND ON THREE DIFFERENT FILES.  Now that the witnesses are fixtures this
# script writes, "three different macros" is cheap to satisfy and would be
# satisfied by three `#define's in ONE header -- which one truncated write, one
# bad `printf', one full disk takes out together.  Three names in one file is
# one control with three names, the same defect the macro-based version had.
for f in "$FIX_INT" "$FIX_STR" "$FIX_EXP"; do
  n=$(for g in "$FIX_INT" "$FIX_STR" "$FIX_EXP"; do [ "$g" = "$f" ] && echo x; done | wc -l)
  [ "$n" = 1 ] || die "two controls read their witness from the same fixture \
file ($f).  Give each phase its own file."
done
grep -qxF "#include \"$FIX_INT\"" "$OUT/ctl.cc" || die "the INT control's probe \
source does not include $FIX_INT; the witness is not arriving by the quoted-\
include path the real probes use"
grep -qxF "#include \"$FIX_STR\"" "$OUT/ctlstr.cc" || die "the STR control's \
probe source does not include $FIX_STR"
grep -qxF "#include \"$FIX_EXP\"" "$OUT/ctlexp.cc" || die "the EXP control's \
probe source does not include $FIX_EXP"
echo "control: OK -- and on three DIFFERENT fixture files, each reached by a \
quoted #include ($FIX_INT $FIX_STR $FIX_EXP)"

########################################################################
# ARM 0c -- THE REAL HEADER SETS, WHICH THE FIXTURE DELIBERATELY DOES NOT
# SPEAK FOR.
#
# The fixtures prove the `-I' SELECTION differs and carries a per-context
# answer.  They cannot prove the two bases' actual headers differ, because
# this script wrote them.  The retired real-macro control did carry that fact
# incidentally, and dropping it silently would be exactly the "weaken the
# control while replacing it" move the brief forbids.
#
# So it is asserted directly, on the whole `-dM' dump rather than on any one
# macro.  THIS ARM CANNOT BE KILLED BY THE CONVERSION PROGRAMME, which is the
# whole reason it is shaped this way: converting a macro rewrites BOTH bases'
# view of it identically, so a conversion moves lines from the "differing" pile
# to the "agreeing" pile and can never make the two header sets equal unless
# every target macro has been converted -- at which point this branch is
# finished and the harness is supposed to say so loudly rather than quietly
# keep scoring.
#
# The mt/i386 half is an ORDERING, not an identity: `mt' resolves the build
# root's `tm.h' (i386's chain under a target-neutral name) while `i386'
# resolves the `i386-inc' shim, and the two are not required to be
# byte-identical -- the build root's file also carries the genuinely
# target-neutral top half.  What must hold is that mt is CLOSER to i386 than to
# aarch64, which is the proposition "mt is the primary's header set" in the
# only form that survives that asymmetry.
########################################################################
header_set_arm () {
  local ctx inc d_ia d_mi d_ma
  for ctx in $CTXS; do
    inc=$(ctx_inc $ctx)
    echo "$PRE" > "$OUT/dmctl-$ctx.cc"
    g++ -E -dM "$OUT/dmctl-$ctx.cc" $inc $CPPFLAGS -std=c++14 -w \
        > "$OUT/dmctl-$ctx.txt" 2> "$OUT/err-dmctl-$ctx.txt" \
      || { cat "$OUT/err-dmctl-$ctx.txt"; die "ARM 0c: -dM dump failed in $ctx"; }
    [ "$(wc -l < "$OUT/dmctl-$ctx.txt")" -gt 5000 ] \
      || die "ARM 0c: $ctx dump has only $(wc -l < "$OUT/dmctl-$ctx.txt") \
lines; not a real dump, and every comparison below would be between two \
near-empty files -- which reads as agreement"
    sort -u "$OUT/dmctl-$ctx.txt" > "$OUT/dmctl-$ctx.s"
  done
  d_ia=$(comm -3 "$OUT/dmctl-i386.s" "$OUT/dmctl-aarch64.s" | wc -l)
  d_mi=$(comm -3 "$OUT/dmctl-mt.s"   "$OUT/dmctl-i386.s"    | wc -l)
  d_ma=$(comm -3 "$OUT/dmctl-mt.s"   "$OUT/dmctl-aarch64.s" | wc -l)
  echo "control-headers: differing #define lines -- i386/aarch64 $d_ia, \
mt/i386 $d_mi, mt/aarch64 $d_ma"
  [ "$d_ia" -ge 200 ] || die "ARM 0c: the i386 and aarch64 contexts' -dM dumps \
differ in only $d_ia lines.  Either the two -I directories are resolving to the \
same real headers -- in which case every arm in this run compares a header set \
with itself -- or the branch has genuinely finished converting, which is not a \
thing this harness may assume quietly.  Establish which before touching this \
bound."
  [ "$d_mi" -lt "$d_ma" ] || die "ARM 0c: mt is not closer to i386 ($d_mi) than \
to aarch64 ($d_ma).  'mt IS the primary's header set' is the premise every i386 \
arm's tautological PASS rests on, and it does not hold in this build dir."
  echo "control: OK -- the two bases' REAL headers differ ($d_ia #define lines) \
and mt sits with i386, so the fixture arms above are not the only evidence the \
contexts are distinct"
}
header_set_arm

########################################################################
# PHASE INT -- batch compile with drop-and-retry.
#
# One TU holding eight arrays per macro.  Macros that are not integral constant
# expressions make it fail; the compiler names them, they are dropped, retry.
# That converges in a handful of rounds and costs three compiles per round
# instead of 138.
########################################################################
int_phase () {
  local ctx=$1 inc round n k nbad
  inc=$(ctx_inc $ctx)
  echo "$NAMES" > "$OUT/cur-$ctx.txt"
  : > "$OUT/nonint-$ctx.txt"
  for round in 1 2 3 4 5 6 7 8 9 10; do
    { echo "$PRE"
      while read -r n; do
        for k in 0 1 2 3 4 5 6 7; do
          echo "char Q${k}_${n}[ ((( (long long)(${n}) ) >> ($k*8)) & 0xff) + 1 ];"
        done
      done < "$OUT/cur-$ctx.txt"
    } > "$OUT/int-$ctx.cc"
    if g++ -c -o "$OUT/int-$ctx.o" "$OUT/int-$ctx.cc" $inc $CPPFLAGS \
         -std=c++14 -w -fmax-errors=0 > "$OUT/err-int-$ctx.txt" 2>&1; then
      nm -S --defined-only "$OUT/int-$ctx.o" \
        | awk '$4 ~ /^Q[0-7]_/ {print $4, $2}' > "$OUT/nm-int-$ctx.txt"
      [ -s "$OUT/nm-int-$ctx.txt" ] || die "INT $ctx: object compiled but nm found no probe symbols"
      awk '{ split($1,a,"_"); k=substr(a[1],2)+0;
             name=substr($1, index($1,"_")+1);
             b[name,k]=strtonum("0x" $2)-1; seen[name]=1 }
           END { for (m in seen) { v=0; for (k=7;k>=0;k--) v = v*256 + b[m,k];
                                   if (v >= 2^63) v -= 2^64;
                                   printf "%s %d\n", m, v } }' \
          "$OUT/nm-int-$ctx.txt" | sort > "$OUT/val-$ctx.txt"
      echo "INT $ctx: $(wc -l < "$OUT/val-$ctx.txt") macros valued at round $round"
      return 0
    fi
    grep -oE 'Q[0-7]_[A-Za-z_][A-Za-z0-9_]*' "$OUT/err-int-$ctx.txt" \
      | sed 's/^Q[0-7]_//' | sort -u > "$OUT/bad-$ctx.txt"
    nbad=$(wc -l < "$OUT/bad-$ctx.txt")
    if [ "$nbad" = 0 ]; then
      echo "INT $ctx: STUCK at round $round, no macro named in the errors:" >&2
      head -5 "$OUT/err-int-$ctx.txt" >&2
      die "INT $ctx: cannot converge"
    fi
    cat "$OUT/bad-$ctx.txt" >> "$OUT/nonint-$ctx.txt"
    grep -vxF -f "$OUT/bad-$ctx.txt" "$OUT/cur-$ctx.txt" > "$OUT/next-$ctx.txt"
    mv "$OUT/next-$ctx.txt" "$OUT/cur-$ctx.txt"
    [ -s "$OUT/cur-$ctx.txt" ] || { : > "$OUT/val-$ctx.txt"; return 0; }
  done
  die "INT $ctx: did not converge in 10 rounds"
}
for c in $CTXS; do int_phase $c; done

########################################################################
# PHASE STR -- string-literal macros, byte exact.
#
# Only tried on macros INT could not value.  Length first (`sizeof'), then one
# array per byte.  GLOBAL_ASM_OP and ASM_COMMENT_START are the point of this
# phase: they are emitted into the assembly file and `.globl' vs `.global'
# assembles identically.
########################################################################
str_phase () {
  local ctx=$1 inc round n k nbad len
  inc=$(ctx_inc $ctx)
  sort -u "$OUT/nonint-$ctx.txt" > "$OUT/scur-$ctx.txt"
  : > "$OUT/nonstr-$ctx.txt"
  : > "$OUT/str-$ctx.txt"
  [ -s "$OUT/scur-$ctx.txt" ] || return 0
  # round 1..n: length probe with drop-and-retry
  for round in 1 2 3 4 5 6 7 8 9 10; do
    { echo "$PRE"
      while read -r n; do echo "char L_${n}[ sizeof(${n}) ];"; done < "$OUT/scur-$ctx.txt"
    } > "$OUT/str-$ctx.cc"
    if g++ -c -o "$OUT/str-$ctx.o" "$OUT/str-$ctx.cc" $inc $CPPFLAGS \
         -std=c++14 -w -fmax-errors=0 > "$OUT/err-str-$ctx.txt" 2>&1; then
      break
    fi
    grep -oE 'L_[A-Za-z_][A-Za-z0-9_]*' "$OUT/err-str-$ctx.txt" \
      | sed 's/^L_//' | sort -u > "$OUT/sbad-$ctx.txt"
    nbad=$(wc -l < "$OUT/sbad-$ctx.txt")
    if [ "$nbad" = 0 ]; then
      cp "$OUT/scur-$ctx.txt" "$OUT/nonstr-$ctx.txt"; : > "$OUT/scur-$ctx.txt"; break
    fi
    cat "$OUT/sbad-$ctx.txt" >> "$OUT/nonstr-$ctx.txt"
    grep -vxF -f "$OUT/sbad-$ctx.txt" "$OUT/scur-$ctx.txt" > "$OUT/snext-$ctx.txt"
    mv "$OUT/snext-$ctx.txt" "$OUT/scur-$ctx.txt"
    [ -s "$OUT/scur-$ctx.txt" ] || break
  done
  [ -s "$OUT/scur-$ctx.txt" ] || { sort -u "$OUT/nonstr-$ctx.txt" -o "$OUT/nonstr-$ctx.txt"; return 0; }
  # `sizeof' also succeeds for non-strings (ints already gone, but rtx/mode
  # macros can have a sizeof).  Byte probe filters them: indexing a non-array
  # will not compile, and such a macro then falls through to EXP.
  nm -S --defined-only "$OUT/str-$ctx.o" \
    | awk '$4 ~ /^L_/ {print substr($4,3), strtonum("0x" $2)}' | sort > "$OUT/len-$ctx.txt"
  for round in 1 2 3 4 5; do
    { echo "$PRE"
      while read -r n len; do
        k=0
        while [ $k -lt $((len - 1)) ]; do
          echo "char C${k}_${n}[ (${n})[$k] + 129 ];"
          k=$((k + 1))
        done
      done < "$OUT/len-$ctx.txt"
    } > "$OUT/strb-$ctx.cc"
    if g++ -c -o "$OUT/strb-$ctx.o" "$OUT/strb-$ctx.cc" $inc $CPPFLAGS \
         -std=c++14 -w -fmax-errors=0 > "$OUT/err-strb-$ctx.txt" 2>&1; then
      nm -S --defined-only "$OUT/strb-$ctx.o" \
        | awk '$4 ~ /^C[0-9]+_/ { split($4,a,"_"); k=substr(a[1],2)+0;
                                  name=substr($4, index($4,"_")+1);
                                  b[name,k]=strtonum("0x" $2)-129; seen[name]=1;
                                  if (k+1 > n[name]) n[name]=k+1 }
               END { for (m in seen) { s="";
                       for (k=0;k<n[m];k++) s = s sprintf("%02x", b[m,k]+0);
                       printf "%s %s\n", m, s } }' | sort > "$OUT/str-$ctx.txt"
      echo "STR $ctx: $(wc -l < "$OUT/str-$ctx.txt") macros valued as strings"
      break
    fi
    grep -oE 'C[0-9]+_[A-Za-z_][A-Za-z0-9_]*' "$OUT/err-strb-$ctx.txt" \
      | sed -E 's/^C[0-9]+_//' | sort -u > "$OUT/sbbad-$ctx.txt"
    nbad=$(wc -l < "$OUT/sbbad-$ctx.txt")
    [ "$nbad" = 0 ] && { cat "$OUT/len-$ctx.txt" | awk '{print $1}' >> "$OUT/nonstr-$ctx.txt"; : > "$OUT/len-$ctx.txt"; break; }
    cat "$OUT/sbbad-$ctx.txt" >> "$OUT/nonstr-$ctx.txt"
    grep -vwF -f "$OUT/sbbad-$ctx.txt" "$OUT/len-$ctx.txt" > "$OUT/lnext-$ctx.txt"
    mv "$OUT/lnext-$ctx.txt" "$OUT/len-$ctx.txt"
    [ -s "$OUT/len-$ctx.txt" ] || break
  done
  sort -u "$OUT/nonstr-$ctx.txt" -o "$OUT/nonstr-$ctx.txt"
}
for c in $CTXS; do str_phase $c; done

########################################################################
# PHASE EXP -- fully preprocessed expansion, for macros no compiler can value.
#
# Arity comes from the context's own `-dM' dump, so a macro that is object-like
# on one base and function-like on the other is reported as an ARITY
# disagreement rather than silently mis-probed.
########################################################################
exp_phase () {
  local ctx=$1 inc n
  inc=$(ctx_inc $ctx)
  echo "$PRE" > "$OUT/dm-$ctx.cc"
  g++ -E -dM "$OUT/dm-$ctx.cc" $inc $CPPFLAGS -std=c++14 -w \
      > "$OUT/dm-$ctx.txt" 2> "$OUT/err-dm-$ctx.txt" \
    || { cat "$OUT/err-dm-$ctx.txt"; die "EXP $ctx: -dM dump failed"; }
  [ "$(wc -l < "$OUT/dm-$ctx.txt")" -gt 5000 ] \
    || die "EXP $ctx: -dM dump has only $(wc -l < "$OUT/dm-$ctx.txt") lines; not a real dump"

  # arity: -1 undefined, 0 object-like, k>0 function-like with k parameters
  awk -v list="$OUT/allnames.txt" '
    BEGIN { while ((getline m < list) > 0) want[m]=1; }
    /^#define / {
      rest = substr($0, 9);
      if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*\(/)) {
        name = substr(rest, 1, RLENGTH-1);
        if (!(name in want)) next;
        p = substr(rest, RLENGTH+1); cl = index(p, ")");
        args = substr(p, 1, cl-1);
        gsub(/[ \t]/, "", args);
        k = (args == "") ? 0 : split(args, tmp, ",");
        printf "%s %d F\n", name, k;
      } else {
        name = rest; sub(/[ \t].*$/, "", name);
        if (!(name in want)) next;
        printf "%s 0 O\n", name;
      }
    }' "$OUT/dm-$ctx.txt" | sort -u > "$OUT/arity-$ctx.txt"
  # An awk that fails still exits 0 through a pipe.  An empty arity table would
  # silently turn every EXP probe into "no data", which scores as a divergence
  # -- red for the wrong reason.  Refuse instead.
  [ -s "$OUT/arity-$ctx.txt" ] \
    || die "EXP $ctx: arity table is empty; the dump parse failed, no probe can be built"

  # The probe is keyed by a NUMBER, not by the macro's name.  Writing the name
  # into the marker line would be self-defeating: the preprocessor expands it,
  # and the key becomes the expansion.  That bug reads as "every macro
  # disagrees" and it was actually hit here before this comment existed.
  local idx=0
  { echo "$PRE"
    while read -r n; do
      local a kind args k
      idx=$((idx + 1))
      a=$(awk -v m="$n" '$1==m{print $2}' "$OUT/arity-$ctx.txt")
      kind=$(awk -v m="$n" '$1==m{print $3}' "$OUT/arity-$ctx.txt")
      [ -n "$a" ] || continue
      # A ZERO-PARAMETER function-like macro (SETUP_FRAME_ADDRESSES() is one)
      # still needs the parentheses: written bare it does not expand at all,
      # both contexts then yield the macro's own name, and the probe reports
      # agreement.  That is a false green and it was observed here.
      if [ "$kind" = F ]; then
        args=""; k=0
        while [ $k -lt "$a" ]; do
          [ -n "$args" ] && args="$args,"
          args="${args}mtpA$k"; k=$((k + 1))
        done
        echo "MTPBEGIN $idx MTPMID ${n}($args) MTPEND"
      else
        echo "MTPBEGIN $idx MTPMID $n MTPEND"
      fi
    done < "$OUT/expcur-$ctx.txt"
  } > "$OUT/exp-$ctx.cc"
  local want got
  want=$(wc -l < "$OUT/expcur-$ctx.txt")
  got=$(grep -c MTPBEGIN "$OUT/exp-$ctx.cc")
  [ "$got" = "$want" ] \
    || die "EXP $ctx: built $got probe uses for $want macros; a macro the phase \
was asked about has no probe, and a missing probe must not read as agreement"

  g++ -E "$OUT/exp-$ctx.cc" $inc $CPPFLAGS -std=c++14 -w \
      > "$OUT/exp-$ctx.i" 2> "$OUT/err-exp-$ctx.txt" \
    || { cat "$OUT/err-exp-$ctx.txt"; die "EXP $ctx: preprocessing failed"; }

  # One expansion per line; normalise whitespace so only the token sequence
  # is compared.  MTPBEGIN/MTPMID/MTPEND are not macros, so they survive.
  tr '\n' ' ' < "$OUT/exp-$ctx.i" \
    | sed 's/MTPBEGIN/\n/g' | grep MTPEND \
    | sed 's/MTPEND.*$//' \
    | awk -F'MTPMID' -v list="$OUT/expcur-$ctx.txt" '
        BEGIN { i=0; while ((getline m < list) > 0) name[++i]=m }
        NF==2 { key=$1; body=$2;
        gsub(/[ \t]+/, " ", key); gsub(/^ +| +$/, "", key);
        gsub(/[ \t]+/, " ", body); gsub(/^ +| +$/, "", body);
        if (key !~ /^[0-9]+$/) { print "BADKEY " key > "/dev/stderr"; bad=1; next }
        print name[key+0], body }
        END { if (bad) exit 3 }' | sort > "$OUT/exp-$ctx.txt" \
    || die "EXP $ctx: a probe key was not a plain integer -- the marker was macro-expanded"
  echo "EXP $ctx: $(wc -l < "$OUT/exp-$ctx.txt") expansions captured of $want asked"
  [ "$(wc -l < "$OUT/exp-$ctx.txt")" = "$want" ] \
    || die "EXP $ctx: captured $(wc -l < "$OUT/exp-$ctx.txt") of $want expansions"
}
echo "$NAMES" > "$OUT/allnames.txt"
for c in $CTXS; do
  # EXP gets exactly what INT and STR could not value.  Deriving that by
  # SUBTRACTING what was valued -- rather than by trusting the phases'
  # bookkeeping of what they rejected -- is deliberate: the rejection lists are
  # built from compiler diagnostics, and a diagnostic that does not name the
  # probe variable silently drops a macro out of every table, which then scores
  # as "absent on both sides" and reads like a divergence.  That happened.
  comm -23 <(sort -u "$OUT/nonint-$c.txt") <(awk '{print $1}' "$OUT/str-$c.txt" | sort -u) \
    > "$OUT/expcur-$c.txt"
  exp_phase $c
done

########################################################################
# SCORING
########################################################################
lookup () { awk -v m="$2" '$1==m { $1=""; sub(/^ /,""); print; found=1 }
                           END { if (!found) print "<absent>" }' "$1"; }

: > "$OUT/results.txt"
for b in $BASES; do
  while read -r n; do
    kind=""; mtv=""; refv=""
    if grep -q "^$n " "$OUT/val-mt.txt" && grep -q "^$n " "$OUT/val-$b.txt"; then
      kind=INT; mtv=$(lookup "$OUT/val-mt.txt" "$n"); refv=$(lookup "$OUT/val-$b.txt" "$n")
    elif grep -q "^$n " "$OUT/str-mt.txt" && grep -q "^$n " "$OUT/str-$b.txt"; then
      kind=STR; mtv=$(lookup "$OUT/str-mt.txt" "$n"); refv=$(lookup "$OUT/str-$b.txt" "$n")
    elif grep -q "^$n " "$OUT/exp-mt.txt" && grep -q "^$n " "$OUT/exp-$b.txt"; then
      kind=EXP; mtv=$(lookup "$OUT/exp-mt.txt" "$n"); refv=$(lookup "$OUT/exp-$b.txt" "$n")
    else
      # The two contexts did not even agree on what KIND of thing this is:
      # an integer here, a non-constant there.  That is a real divergence and
      # it is reported as one, never quietly skipped.
      kind=KIND
      mtv=$(grep -q "^$n " "$OUT/val-mt.txt" && echo int \
            || { grep -q "^$n " "$OUT/str-mt.txt" && echo string \
                 || { grep -q "^$n " "$OUT/exp-mt.txt" && echo nonconst || echo absent; }; })
      refv=$(grep -q "^$n " "$OUT/val-$b.txt" && echo int \
            || { grep -q "^$n " "$OUT/str-$b.txt" && echo string \
                 || { grep -q "^$n " "$OUT/exp-$b.txt" && echo nonconst || echo absent; }; })
    fi
    # An EXP result that is just the macro's own name means the macro did not
    # expand -- it is not evidence of agreement, it is evidence of no probe.
    if [ "$kind" = EXP ] && { [ "$mtv" = "$n" ] || [ "$refv" = "$n" ]; }; then
      kind=NOEXPAND
    fi
    if [ "$kind" = KIND ] || [ "$kind" = NOEXPAND ]; then v=FAIL
    elif [ "$mtv" = "$refv" ]; then v=PASS; else v=FAIL; fi
    echo "$b $n $kind $v mt=[$mtv] ref=[$refv]" >> "$OUT/results.txt"
  done <<< "$NAMES"
done

[ "$(wc -l < "$OUT/results.txt")" = "$((NMACRO * 2))" ] \
  || die "scoring produced $(wc -l < "$OUT/results.txt") lines, expected $((NMACRO * 2))"

{
  echo "macros probed: $NMACRO   bases: $BASES"
  for b in $BASES; do
    echo "$b: PASS $(awk -v b=$b '$1==b && $4=="PASS"' "$OUT/results.txt" | wc -l)  \
FAIL $(awk -v b=$b '$1==b && $4=="FAIL"' "$OUT/results.txt" | wc -l)"
  done
  echo "by probe shape:"
  awk '{print $3}' "$OUT/results.txt" | sort | uniq -c
  echo "aarch64 failures by shape:"
  awk '$1=="aarch64" && $4=="FAIL" {print $3}' "$OUT/results.txt" | sort | uniq -c
  # THE AARCH64 PASS COLUMN, DECOMPOSED WHERE IT IS PRINTED, SO THE RAW NUMBER
  # CANNOT BE QUOTED ON ITS OWN.
  #
  # PRINCIPLES says "never quote the raw 8" and then has to explain, in
  # prose, in another file, that the 8 was 2 trusted plus 6 wrong-reason
  # flips.  A caveat that lives somewhere else is a caveat that gets dropped:
  # the raw number has been quoted at least twice after being warned about.
  #
  # A CONVERTED_NOARM macro is redirected by `defaults.h', and the probe's
  # base-B context does not define MULTI_TARGET_TARGETM_BASE, so BOTH sides
  # expand to the same `mt_*' call and the arm compares a redirect with
  # itself.  Every such PASS is untrusted BY CONSTRUCTION -- not suspected,
  # derived -- so the split can be computed rather than remembered.
  np_all=$(awk '$1=="aarch64" && $4=="PASS"' "$OUT/results.txt" | wc -l)
  np_noarm=$(awk -v L="$NOARM_LIST" 'BEGIN{n=split(L,a," "); for(i=1;i<=n;i++) s[a[i]]=1}
                $1=="aarch64" && $4=="PASS" && s[$2]' "$OUT/results.txt" | wc -l)
  echo "aarch64 PASS decomposition: $np_all total = \
$np_noarm redirect-vs-itself (CONVERTED_NOARM, UNTRUSTED BY CONSTRUCTION) \
+ $((np_all - np_noarm)) other.  NEVER QUOTE THE RAW $np_all."
  echo "PASS for aarch64 (expected to be rare -- each needs a reason):"
  awk -v L="$NOARM_LIST" 'BEGIN{n=split(L,a," "); for(i=1;i<=n;i++) s[a[i]]=1}
       $1=="aarch64" && $4=="PASS" {print "  " $2 " " $3 (s[$2] ? "  UNTRUSTED-redirect-vs-itself (CONVERTED_NOARM)" : "")}' \
    "$OUT/results.txt"
  echo "FAIL for i386 (expected NONE -- mt is the i386 header set today):"
  awk '$1=="i386" && $4=="FAIL" {print "  " $2 " " $3}' "$OUT/results.txt"
} > "$OUT/summary.txt"
cat "$OUT/summary.txt"
echo "results: $OUT/results.txt"
