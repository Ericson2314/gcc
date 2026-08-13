#!/bin/sh
#
# EXIST -- THE FIFTH PROBE SHAPE, for macros whose per-base answer is an
# EXISTENCE bit or a nullary constant, and which therefore have no arm today.
#
# ---------------------------------------------------------------------------
# WHY THE EXISTING TWO SHAPES CANNOT COVER THESE
#
#   macro-probe.sh (header) measures the preprocessor context a TU is compiled
#   in.  For these macros defaults.h either `#undef's the name outright
#   (REG_PARM_STACK_SPACE) or redirects it so BOTH the shared and the base-B
#   contexts expand to the same call (PUSH_ARGS_REVERSED).  The arm then
#   compares a redirect with itself and flips green saying nothing.  That is
#   wrong-reason shape 2 and shape 5 in PRINCIPLES, and this file exists so
#   those flips can be RETIRED into something that measures instead of being
#   banked.
#
#   tab-probe.sh (runtime plugin) reads CONSTANTS out of slots in the linked
#   cc1.  These macros are CALLS.  Worse, tab-probe's plugin runs inside ONE
#   cc1 selection, so the UNSELECTED base's thunks read the SELECTED base's
#   option storage -- that is the CDATA_NUM_OPTSTATE blindness already recorded
#   there, and it is why six endianness arms stay FAIL.  Any arm built on that
#   plugin inherits the same blindness.
#
# WHAT THIS SHAPE MEASURES INSTEAD, AND WHY IT IS NOT SUBJECT TO THAT BLINDNESS
#
#   The per-base thunks live in target-cumargs.cc, which is compiled ONCE PER
#   BACK END with that back end's `tm.h' and `MULTI_TARGET_TARGETM_BASE'
#   defined.  Both objects -- target-cumargs-i386.o and
#   target-cumargs-aarch64.o -- exist SIMULTANEOUSLY in one build tree.  So the
#   two bases' answers can be read side by side WITHOUT selecting either one,
#   and no `*_option_override' has to have run.  There is no unselected base
#   here, which is exactly the property the plugin cannot have.
#
#   An existence predicate is the best-behaved case there is:
#
#       static bool mt_base_has_push_rounding (void)
#       { #ifdef PUSH_ROUNDING  return true; #else return false; #endif }
#
#   nullary, `#ifdef'-derived, reading no option variable.  It compiles to a
#   constant return, and the two bases' constants are 1 and 0 -- a REAL
#   discriminator, in exactly the place the VALUE arm has none.  That is the
#   whole point: STATE.md records that a value arm on these cannot tell i386
#   from aarch64, because `ix86_reg_parm_stack_space' returns 0 for SysV and
#   aarch64's absence also produces 0 -- "correct by luck".  The EXISTENCE bit
#   is 1 vs 0 and is not luck.
#
# ---------------------------------------------------------------------------
# THE TWO PROPERTIES THIS SCRIPT SCORES, AND WHY THERE ARE TWO
#
#   A. VALUE.  Only when BOTH bases' thunks compiled to a constant return.
#      Scored against a PRE-REGISTERED table below, hand-derived from the back
#      ends' headers BEFORE any disassembly was read.  If a verdict disagrees
#      with the table, re-read the header -- do not edit the table.  Editing it
#      to match turns an independent check into a restatement of what the
#      mechanism already said.
#
#   B. DISTINCTNESS.  The two bases' thunk BODIES differ.  This is scoreable
#      for every macro here INCLUDING the ones property A cannot reach, and it
#      is the direct answer to "does a per-base copy actually exist, and does
#      it actually differ".  A macro whose two thunks are byte-identical has
#      not been shown to be per-base at all.
#
#   THE HONEST THIRD VERDICT.  Some thunks are NOT constant returns -- i386's
#   `ACCUMULATE_OUTGOING_ARGS' is `TARGET_ACCUMULATE_OUTGOING_ARGS', an option
#   read, and it compiles to a `testb' against a flag word.  For those, this
#   script reports OPTSTATE and scores property A as UNMEASURABLE-BY-THIS-ARM,
#   naming the reason.  It does NOT score them PASS.  PRINCIPLES: "a measured
#   'still cannot be checked, because X' is a useful result; an unexamined pass
#   is not."  Note that OPTSTATE is still informative for property B -- one base
#   reading option state while the other returns a constant IS a demonstrated
#   difference between the two compiled copies.
#
# ---------------------------------------------------------------------------
# BLIND SPOTS OF THIS INSTRUMENT, STATED UP FRONT
#
#   * It reads x86-64 host instructions.  The aarch64 thunk is HOST code
#     compiled for the build machine -- it is aarch64's ANSWER, not aarch64
#     code -- so `xor %eax,%eax' in target-cumargs-aarch64.o is correct and
#     expected.  Anyone reading this output as "aarch64 object contains x86
#     instructions, something is wrong" has misread it.
#   * It recognises a narrow set of constant-return idioms (`mov $k,%eax; ret'
#     and `xor %eax,%eax; ret').  A thunk that returns a constant by some other
#     encoding is reported UNRECOGNISED, never silently treated as 0 -- a
#     defaulted 0 would agree with aarch64's real answer for several of these
#     macros and would be indistinguishable from a pass.
#   * It says nothing about whether anything CALLS the thunk.  That is a
#     separate arm (PRINCIPLES: data and selection are separate arms).
#
# USAGE
#   scratchpad/exist-probe.sh [builddir]      default /tmp/b-a7c-t108
set -u

BUILD=${1:-/tmp/b-a7c-t108}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/.." && pwd)/gcc
OUT=${OUT:-/tmp/exist-out}

die () { echo "FATAL: $*" >&2; exit 9; }

mkdir -p "$OUT" || die "cannot create $OUT"

BASES="i386 aarch64"

# ---------------------------------------------------------------------------
# THE PRE-REGISTERED TABLE.  Derived by hand from the back ends' own headers,
# by asking which of them defines the macro at all:
#
#   grep -l 'define REG_PARM_STACK_SPACE' config/i386/*.h config/aarch64/*.h
#       -> config/i386/i386.h only
#   grep -l 'define PUSH_ROUNDING'        config/i386/*.h config/aarch64/*.h
#       -> config/i386/i386.h only
#
# so both existence bits are 1 for i386 and 0 for aarch64.  Written down here
# BEFORE the objects were disassembled.
#
# Format: <macro>:<thunk symbol>:<i386>:<aarch64>:<discriminate?>:<distinctness>
# A value of `?' means "no prediction registered -- report, do not score".
#
# ---------------------------------------------------------------------------
# THE SIXTH FIELD, ADDED 2026-08-13, AND WHY IT IS NOT DECORATION.
#
# Before it, DISTINCTNESS was PRINTED and never SCORED: the run could not fail
# on it.  That made it useless for exactly the macros this shape was extended
# to cover -- the ones whose thunks read option state, where property A is
# UNMEASURABLE and distinctness is the ONLY proposition left.  An arm that can
# only print is not an arm (PRINCIPLES: `mechanism present but never invoked',
# aimed at the instrument).  The field is the PRE-REGISTERED distinctness, and
# a measured distinctness that disagrees with it is a FAIL.
#
# It is derivable from the headers alone, without disassembling anything:
# if the two back ends define the macro differently, or one defines it and the
# other falls to `defaults.h', the two thunks must compile to different
# bodies.  If NEITHER base defines it, both get the same generic definition and
# the bodies must be the SAME -- and that is an honest negative, recorded as
# such, not a macro this pair can demonstrate anything about.
#
# ---------------------------------------------------------------------------
# THE 2026-08-13 EXTENSION: 28 MACROS OFF THE `CONVERTED_NOARM' COLUMN.
#
# Twenty-eight of the macros in the table below were `CONVERTED_NOARM' --
# converted in the compiler and measured by NOTHING.  The only arm any of them
# had was a header arm comparing a redirect with itself.  All 28 ALREADY had a
# per-base thunk in `target-cumargs.cc'; NO COMPILER SOURCE CHANGED to give
# them an arm, only this instrument.  That is worth stating plainly: the debt
# was never missing machinery, it was a missing measurement.
#
# THE VALUE PREDICTIONS WERE DERIVED FROM THE BACK ENDS' OWN HEADERS BEFORE ANY
# DISASSEMBLY WAS READ, and the derivation is written out so it can be checked
# rather than trusted:
#
#   i386.h:1257,1260,1263,1264   ARG_POINTER_REGNUM  = ARGP_REG
#                                STACK_POINTER_REGNUM = SP_REG
#                                FRAME_POINTER_REGNUM = FRAME_REG
#                                HARD_FRAME_POINTER_REGNUM = BP_REG
#   i386.md:435,438              ARGP_REG 16, FRAME_REG 19
#                                (SP_REG 7 and BP_REG 6 from i386.h's reg enum)
#   aarch64.h:766-769 + aarch64.md:74,76,110
#                                R29_REGNUM 29, SP_REGNUM 31, SFP_REGNUM 64,
#                                AP_REGNUM 65
#   i386.h:997                   DWARF_FRAME_REGISTERS 17
#   aarch64.h:819,820,827,832    AARCH64_DWARF_V0 64 + 32 V registers + 1 = 97
#   i386.h:850                   MAX_STACK_ALIGNMENT = MAX_OFILE_ALIGNMENT,
#   elfos.h:63                   which is ((1u << 28) * 8) = 2147483648
#   defaults.h:1249              i386 defines MAX_STACK_ALIGNMENT, so
#                                MAX_SUPPORTED_STACK_ALIGNMENT is the same
#   defaults.h:1252-1253         aarch64 defines neither, so
#                                MAX_STACK_ALIGNMENT = STACK_BOUNDARY = 128
#                                (aarch64.h:91) and
#                                MAX_SUPPORTED_STACK_ALIGNMENT =
#                                PREFERRED_STACK_BOUNDARY = STACK_BOUNDARY = 128
#                                (defaults.h:939, aarch64 defines no
#                                PREFERRED_STACK_BOUNDARY)
#   target-cumargs.cc:586-598    NEITHER base defines
#                                HARD_FRAME_POINTER_IS_{FRAME,ARG}_POINTER, so
#                                both fall to rtl.h's comparison and both are
#                                false -> 0/0, SAME.  These two are the only
#                                predicted-SAME entries in the table and they
#                                are what makes SAME reachable in the SCORED
#                                population rather than only in the control.
#
# The other NINETEEN are registered `?/?' ON PURPOSE and their verdict will be
# UNMEASURABLE-BY-THIS-ARM.  That is not a gap being papered over, it is the
# gap being named: their thunks read OPTION STATE (i386's MOVE_MAX is a chain
# over TARGET_AVX512F / ix86_move_max / ix86_tune_features; i386's MOVE_RATIO
# reads `ix86_cost'; `Pmode' is `ix86_pmode', the silent-default trap itself),
# or they take arguments and dispatch to a back-end function.  For those,
# DISTINCTNESS is the whole arm, and with the sixth field it is an arm that can
# fail.
#
# WHAT THIS SHAPE STILL CANNOT REACH, stated rather than left silent:
# `ELIMINABLE_REGS' and `RELOAD_ELIMINABLE_REGS' are `.rodata' TABLES, not
# functions, so `objdump -d' cannot see them at all -- they need a data-section
# comparison, a seventh shape.  `ALL_REGS', `GENERAL_REGS' and
# `LIM_REG_CLASSES' are register-class ENUMERATORS handled by the
# CONVERTED_REGS union and have no thunk here.  Those five stay
# CONVERTED_NOARM, and they are the honest remainder.
#
# MEASURED 2026-08-13 against /tmp/b-a7c-t108: 37 macros, VALUE 12 PASS /
# 0 FAIL / 25 unmeasurable-or-report-only, DISTINCT 37 ok / 0 FAIL,
# 35 DIFFER + 2 SAME.  All nine pre-existing verdicts are BYTE-IDENTICAL to the
# run before this change, which is the regression control for the rewritten
# `body ()' and `strip_body ()'.
#
# ALL NINE NEW VALUE PREDICTIONS WERE CONFIRMED EXACTLY, including
# 2147483648/128 -- the one that could most easily have been arithmetic done
# wrong -- and none of the fourteen macros that turned out to be OPTSTATE was
# quietly promoted to a pass.  Nineteen of the twenty-eight can be measured for
# DISTINCTNESS ONLY, and that is what they are scored on.
#
# THE BUILD DIRECTORY IS NOT THIS WORKTREE'S, and that is checked rather than
# assumed: /tmp/b-a7c-t108 was configured from worktree agent-a7c243ba5c0d4dfb9
# (its `gcc/config.log' says so).  The four files that decide the CONTENT of
# `target-cumargs-{i386,aarch64}.o' -- `target-cumargs.cc', `target-frame.h',
# `defaults.h', `config/i386/i386.h' and `config/aarch64/aarch64.h' -- are
# BYTE-IDENTICAL between that tree and this one, measured with `diff -q'.  So
# the objects are a valid reading OF THIS TREE'S SOURCE.  PRINCIPLES says a
# harness must assert which tree it measures; this is that assertion, and it is
# an equality of inputs rather than an equality of paths.
PREREG="\
REG_PARM_STACK_SPACE:mt_base_has_reg_parm_stack_space:1:0:yes:DIFFER \
PUSH_ROUNDING:mt_base_has_push_rounding:1:0:yes:DIFFER \
PUSH_ARGS_REVERSED:mt_base_push_args_reversed:1:0:yes:DIFFER \
FUNCTION_MODE:mt_base_function_mode:?:?:yes:DIFFER \
ACCUMULATE_OUTGOING_ARGS:mt_base_accumulate_outgoing_args:?:?:yes:DIFFER \
INCOMING_FRAME_SP_OFFSET:mt_base_incoming_frame_sp_offset:?:?:yes:DIFFER \
DEFAULT_INCOMING_FRAME_SP_OFFSET:mt_base_default_incoming_frame_sp_offset:?:?:no:DIFFER \
INCOMING_REG_PARM_STACK_SPACE:mt_base_incoming_reg_parm_stack_space:?:?:no:DIFFER \
STACK_DYNAMIC_OFFSET:mt_base_stack_dynamic_offset:?:?:no:DIFFER \
STACK_POINTER_REGNUM:mt_base_stack_pointer_regnum:7:31:yes:DIFFER \
FRAME_POINTER_REGNUM:mt_base_frame_pointer_regnum:19:64:yes:DIFFER \
HARD_FRAME_POINTER_REGNUM:mt_base_hard_frame_pointer_regnum:6:29:yes:DIFFER \
ARG_POINTER_REGNUM:mt_base_arg_pointer_regnum:16:65:yes:DIFFER \
DWARF_FRAME_REGISTERS:mt_base_dwarf_frame_registers:17:97:yes:DIFFER \
MAX_STACK_ALIGNMENT:mt_base_max_stack_alignment:2147483648:128:yes:DIFFER \
MAX_SUPPORTED_STACK_ALIGNMENT:mt_base_max_supported_stack_alignment:2147483648:128:yes:DIFFER \
HARD_FRAME_POINTER_IS_FRAME_POINTER:mt_base_hard_frame_pointer_is_frame_pointer:0:0:no:SAME \
HARD_FRAME_POINTER_IS_ARG_POINTER:mt_base_hard_frame_pointer_is_arg_pointer:0:0:no:SAME \
STACK_BOUNDARY:mt_base_stack_boundary:?:?:no:DIFFER \
PREFERRED_STACK_BOUNDARY:mt_base_preferred_stack_boundary:?:?:no:DIFFER \
INCOMING_STACK_BOUNDARY:mt_base_incoming_stack_boundary:?:?:no:DIFFER \
SUPPORTS_STACK_ALIGNMENT:mt_base_supports_stack_alignment:?:?:no:DIFFER \
Pmode:mt_base_pmode:?:?:no:DIFFER \
MOVE_MAX:mt_base_move_max:?:?:no:DIFFER \
MOVE_MAX_PIECES:mt_base_move_max_pieces:?:?:no:DIFFER \
STORE_MAX_PIECES:mt_base_store_max_pieces:?:?:no:DIFFER \
COMPARE_MAX_PIECES:mt_base_compare_max_pieces:?:?:no:DIFFER \
MOVE_RATIO:mt_base_move_ratio:?:?:no:DIFFER \
CLEAR_RATIO:mt_base_clear_ratio:?:?:no:DIFFER \
SET_RATIO:mt_base_set_ratio:?:?:no:DIFFER \
MINIMUM_ALIGNMENT:mt_base_minimum_alignment:?:?:no:DIFFER \
STACK_SLOT_ALIGNMENT:mt_base_stack_slot_alignment:?:?:no:DIFFER \
OUTGOING_REG_PARM_STACK_SPACE:mt_base_outgoing_reg_parm_stack_space:?:?:no:DIFFER \
FUNCTION_ARG_REGNO_P:mt_base_function_arg_regno_p:?:?:no:DIFFER \
DEBUGGER_REGNO:mt_base_debugger_regno:?:?:no:DIFFER \
DWARF_FRAME_REGNUM:mt_base_dwarf_frame_regnum:?:?:no:DIFFER \
INITIAL_ELIMINATION_OFFSET:mt_base_initial_elimination_offset:?:?:no:DIFFER"

# ---------------------------------------------------------------------------
# THE MACHINE-READABLE ARM LIST, read by `macro-probe.sh'.
#
# `tab-probe.sh' exports `TAB_MACROS' on one line so that macro-probe.sh's
# anti-floor gate can check, mechanically, that no macro moved to a
# CONVERTED_* status without acquiring an arm.  This line is the same contract
# for the EXIST shape, and it is deliberately a SEPARATE name from TAB_MACROS:
# the two shapes measure different propositions, and a board that added them
# into one number would let an EXISTENCE arm be read as a VALUE arm.  A macro
# marked CONVERTED_EXIST in macro-status.txt must appear here; one marked
# CONVERTED_{GONE,SUPPLY,CDATA,REGS} must appear in TAB_MACROS.  Neither list
# satisfies the other's requirement.
#
# Read with  sed -n 's/^EXIST_MACROS="\(.*\)"$/\1/p'  -- keep it one line.
EXIST_MACROS="REG_PARM_STACK_SPACE PUSH_ROUNDING PUSH_ARGS_REVERSED FUNCTION_MODE ACCUMULATE_OUTGOING_ARGS INCOMING_FRAME_SP_OFFSET DEFAULT_INCOMING_FRAME_SP_OFFSET INCOMING_REG_PARM_STACK_SPACE STACK_DYNAMIC_OFFSET STACK_POINTER_REGNUM FRAME_POINTER_REGNUM HARD_FRAME_POINTER_REGNUM ARG_POINTER_REGNUM DWARF_FRAME_REGISTERS MAX_STACK_ALIGNMENT MAX_SUPPORTED_STACK_ALIGNMENT HARD_FRAME_POINTER_IS_FRAME_POINTER HARD_FRAME_POINTER_IS_ARG_POINTER STACK_BOUNDARY PREFERRED_STACK_BOUNDARY INCOMING_STACK_BOUNDARY SUPPORTS_STACK_ALIGNMENT Pmode MOVE_MAX MOVE_MAX_PIECES STORE_MAX_PIECES COMPARE_MAX_PIECES MOVE_RATIO CLEAR_RATIO SET_RATIO MINIMUM_ALIGNMENT STACK_SLOT_ALIGNMENT OUTGOING_REG_PARM_STACK_SPACE FUNCTION_ARG_REGNO_P DEBUGGER_REGNO DWARF_FRAME_REGNUM INITIAL_ELIMINATION_OFFSET"

# DRIFT CHECK, and it is not decoration.  If EXIST_MACROS and PREREG can
# disagree, the board can claim an arm this script does not run -- which is the
# `mechanism present but never invoked' shape, aimed at the instrument itself.
# Compared as SETS, by name, in both directions.
_pre=$(for e in $PREREG; do echo "$e" | cut -d: -f1; done | sort)
_exp=$(for m in $EXIST_MACROS; do echo "$m"; done | sort)
if [ "$_pre" != "$_exp" ]; then
  echo "PREREG: $_pre" >&2
  echo "EXIST_MACROS: $_exp" >&2
  die "EXIST_MACROS and the PREREG table name different macros.  The board \
would then advertise an arm that is not scored here, or score an arm the \
board does not know about.  Fix the list, do not silence this."
fi

# THE DISTINCTNESS CONTROL, and it is not optional.
#
# Every macro in the table above scores DIFFER.  An instrument that has only
# ever returned one of its two answers has not been shown able to return the
# other -- PRINCIPLES calls this the EXP lesson, and it is exactly how the
# address-stripping bug below would have hidden: without stripping, the two
# objects lay their functions out at different offsets and EVERYTHING scores
# DIFFER vacuously.
#
# THE FIRST CONTROL CHOSEN FOR THIS JOB WAS WRONG, AND THE CONTROL CAUGHT IT
# RATHER THAN THE OTHER WAY ROUND -- worth recording, because it is the good
# outcome.  `mt_base_stack_boundary' was picked on the belief that
# STACK_BOUNDARY is 128 on both bases.  It scored DIFFER and the run aborted.
# Re-reading rather than editing the check: i386's STACK_BOUNDARY is
# OPTION-DEPENDENT (it compiles to `testb $0x2,...' then 0x20/0x40/0x80),
# while aarch64's is a flat `mov $0x80'.  The prediction was wrong; the
# instrument was right.  PRINCIPLES: re-read the header, do not edit the table.
#
# The control actually used is `HARD_FRAME_POINTER_IS_FRAME_POINTER', and its
# justification is already written down in target-cumargs.cc:586-588: NEITHER
# i386 nor aarch64 defines it, so both fall to rtl.h's comparison and both are
# false.  Two thunks that must compile to the same constant return, for a
# reason stated in the source rather than assumed here.
#
# If this control scores DIFFER, the distinctness test is measuring object
# layout rather than content -- the two objects place functions at different
# offsets, so WITHOUT the address stripping in strip_body() everything scores
# DIFFER vacuously.  Scored FIRST, and fatal.
CONTROL_SAME="mt_base_hard_frame_pointer_is_frame_pointer"

# ---------------------------------------------------------------------------
# 0.  Tools and inputs.  A tool that is missing pipes into grep as 0 matches,
#     in the direction that makes everything look absent-and-therefore-equal.
# ---------------------------------------------------------------------------
command -v nix-shell >/dev/null || die "no nix-shell"
for b in $BASES; do
  [ -f "$BUILD/gcc/target-cumargs-$b.o" ] \
    || die "no $BUILD/gcc/target-cumargs-$b.o -- build 'multi-target-objs' in $BUILD/gcc first"
done

# One nix-shell for all the binutils work; `nm'/`objdump' are not on PATH
# outside it (DEVSHELL.md).
for b in $BASES; do
  nix-shell -I "nixpkgs=$NP" -p binutils --run \
    "objdump -dr '$BUILD/gcc/target-cumargs-$b.o'" > "$OUT/dis-$b.txt" 2> "$OUT/dis-$b.err" \
    || { cat "$OUT/dis-$b.err"; die "objdump failed for $b"; }
  [ -s "$OUT/dis-$b.txt" ] || die "empty disassembly for $b"
  # NON-VACUITY.  An empty or truncated disassembly makes every lookup below
  # return "not found", which reads as "no per-base copy exists" -- the exact
  # inversion PRINCIPLES records for `awk '$0 ~ f''.
  n=$(grep -c '^0*[0-9a-f]* <' "$OUT/dis-$b.txt")
  [ "$n" -gt 50 ] || die "only $n functions in $b disassembly; refusing to score"
  echo "ok: $b disassembly has $n functions"
done

# ---------------------------------------------------------------------------
# Extract a thunk's body.  Matched on the MANGLED name CONTAINING the symbol,
# via index() semantics -- `grep -F' -- never a regex over a demangled name.
# PRINCIPLES: `awk '$0 ~ f'' on `foo(rtx_insn*)' matches NOTHING because `()'
# is an empty group, and six arms once scored EMPTY reading as "absent".
#
# MATCHED ON THE ITANIUM LENGTH PREFIX, `_ZL<len><name>', AND NOT ON A LIST OF
# ARGUMENT SUFFIXES.  The old form spelled the mangled parameter list out
# (`sym "v>:"', `sym "P9tree_node>:"'), which is fine for nine nullary
# predicates and silently returns NOTHING for a thunk taking `bool' or `int' --
# an empty body reads as "no per-base copy exists", the same inversion this
# comment block warns about, one level up.  The length prefix is EXACT and
# suffix-agnostic at once: `_ZL16mt_base_move_maxv' and
# `_ZL23mt_base_move_max_pieces' cannot be confused, because the second's name
# is 23 characters and so is never introduced by `_ZL16'.  A plain substring
# match on `mt_base_move_max' WOULD confuse them, and that is the bug this
# avoids rather than a hypothetical.
#
# `.cold' FRAGMENTS ARE EXCLUDED.  gcc splits `mt_base_pmode's assert path out
# into `_ZL13mt_base_pmodev.cold', whose header line contains the same prefix;
# without this the two chunks concatenate into one body and the classifier
# reads instructions from a path that is not the function's.
body () {                     # body <base> <symbol>
  awk -v sym="$2" '
    BEGIN { pfx = "_ZL" length (sym) sym }
    /^[0-9a-f]+ </ { inf = (index ($0, pfx) > 0 && index ($0, ".cold") == 0) }
    inf && /^[ \t]*[0-9a-f]+:/ { print }
  ' "$OUT/dis-$1.txt"
}

# Classify a body: print "CONST <k>", "OPTSTATE", or "UNRECOGNISED".
classify () {                 # classify <bodytext>
  echo "$1" | awk '
    NR==1 {
      if ($0 ~ /mov +\$0x[0-9a-f]+,%eax/) { k=$0; sub(/.*mov +\$0x/,"",k); sub(/,%eax.*/,"",k); c="0x" k; next }
      if ($0 ~ /xor +%eax,%eax/)          { c="0x0"; next }
      c=""; next
    }
    NR==2 {
      if (c != "" && $0 ~ /ret/) { printf "CONST %d\n", strtonum(c); found=1; exit }
      # Not a two-instruction constant return.  Is it reading option state?
      exit
    }
    END { if (!found) print "NOTCONST" }
  '
}

# Distinguish OPTSTATE from UNRECOGNISED by looking for a memory read in the
# body.  Stated as a heuristic rather than dressed up as a proof.
kind () {                     # kind <bodytext>
  c=$(classify "$1")
  case "$c" in CONST*) echo "$c"; return;; esac
  case "$1" in
    *"(%rip)"*|*"testb"*|*"0x"*"(%r"*) echo "OPTSTATE" ;;
    *) echo "UNRECOGNISED" ;;
  esac
}

# Strip the per-object noise from a body so DISTINCTNESS compares CONTENT.
# The two objects lay functions out at different offsets, so without this
# every macro scores DIFFER vacuously -- see CONTROL_SAME above.
# The leading-offset strip must cover RELOCATION lines too (`objdump -dr'
# prints them indented with tabs as `\t\t\t23: R_X86_64_PC32\tsym+0x2c'); a
# form anchored on `^ *' leaves their offsets in, and those offsets differ
# between the two objects, so EVERY macro would score DIFFER vacuously -- the
# exact failure CONTROL_SAME exists to catch, reintroduced by the `-r'.
#
# `-r' IS WHAT MAKES DISTINCTNESS MEAN ANYTHING FOR A DISPATCHING THUNK.
# Without it, i386's `FUNCTION_ARG_REGNO_P' body is `jmp <ix86_...>' and
# aarch64's is `jmp <aarch64_...>'; the `<...>' strip below erases both callee
# names and the two bodies compare EQUAL.  That is a false SAME -- a green
# turning red for the wrong reason, which is the same disease as a red turning
# green for the wrong reason.  With `-r' the callee's name survives on the
# relocation line and the comparison is about content again.
strip_body () { sed -e 's/^[ \t]*[0-9a-f]*:[ \t]*//' -e 's/#.*//' -e 's/[0-9a-f]* <.*>//'; }

# ---------------------------------------------------------------------------
# THE DISTINCTNESS CONTROL.  Runs BEFORE any verdict is issued.
# ---------------------------------------------------------------------------
c386=$(body i386    "$CONTROL_SAME" | strip_body)
ca64=$(body aarch64 "$CONTROL_SAME" | strip_body)
[ -n "$c386" ] && [ -n "$ca64" ] \
  || die "distinctness control $CONTROL_SAME not found in both objects; \
refusing to score -- an absent control is not a passing control"
if [ "$c386" = "$ca64" ]; then
  echo "ok: distinctness control ($CONTROL_SAME -- HARD_FRAME_POINTER_IS_FRAME_POINTER, false on both bases) scores SAME"
else
  echo "$c386" > "$OUT/ctl-i386.txt"; echo "$ca64" > "$OUT/ctl-aarch64.txt"
  die "distinctness control $CONTROL_SAME scored DIFFER.  The test is \
measuring object layout, not content, and EVERY 'DIFFER' this script would \
print is vacuous.  Bodies in $OUT/ctl-*.txt"
fi

# ---------------------------------------------------------------------------
# Score.
# ---------------------------------------------------------------------------
: > "$OUT/results.txt"
n_pass=0 n_fail=0 n_unmeas=0 n_macro=0
n_dpass=0 n_dfail=0 n_dsame=0 n_ddiff=0

for e in $PREREG; do
  m=$(echo "$e" | cut -d: -f1)
  sym=$(echo "$e" | cut -d: -f2)
  w386=$(echo "$e" | cut -d: -f3)
  wa64=$(echo "$e" | cut -d: -f4)
  disc=$(echo "$e" | cut -d: -f5)
  wdist=$(echo "$e" | cut -d: -f6)
  n_macro=$((n_macro + 1))

  b386=$(body i386 "$sym")
  ba64=$(body aarch64 "$sym")

  if [ -z "$b386" ] || [ -z "$ba64" ]; then
    printf '%-34s NOTFOUND  (i386:%s aarch64:%s) -- symbol absent from an object; NOT scored as equal\n' \
      "$m" "$([ -n "$b386" ] && echo y || echo n)" "$([ -n "$ba64" ] && echo y || echo n)" \
      | tee -a "$OUT/results.txt"
    n_fail=$((n_fail + 1))
    continue
  fi

  k386=$(kind "$b386")
  ka64=$(kind "$ba64")

  # PROPERTY B -- DISTINCTNESS.  Compare the instruction TEXT with the leading
  # addresses stripped: the two objects lay functions out at different
  # offsets, so raw bodies always differ and a raw compare would pass
  # vacuously for everything.  That is a wrong-reason green and it is removed
  # here rather than discovered later.
  s386=$(echo "$b386" | strip_body)
  sa64=$(echo "$ba64" | strip_body)
  if [ "$s386" = "$sa64" ]; then distinct=SAME; else distinct=DIFFER; fi
  if [ "$distinct" = SAME ]; then n_dsame=$((n_dsame + 1)); else n_ddiff=$((n_ddiff + 1)); fi

  # ...AND IT IS SCORED, against the sixth field.  Printing it was not an arm.
  dverd=
  case "$wdist" in
    '?') dverd="dist:REPORT-ONLY" ;;
    "$distinct") dverd="dist:ok"; n_dpass=$((n_dpass + 1)) ;;
    *) dverd="dist:FAIL measured $distinct, pre-registered $wdist"
       n_dfail=$((n_dfail + 1)) ;;
  esac

  # PROPERTY A -- VALUE.
  verdict=
  case "$k386:$ka64" in
    CONST*:CONST*)
      v386=${k386#CONST }; va64=${ka64#CONST }
      if [ "$w386" = '?' ]; then
        verdict="REPORT-ONLY i386=$v386 aarch64=$va64 (no prediction registered)"
        n_unmeas=$((n_unmeas + 1))
      elif [ "$v386" = "$w386" ] && [ "$va64" = "$wa64" ]; then
        if [ "$disc" = yes ] && [ "$v386" = "$va64" ]; then
          verdict="FAIL both bases returned $v386; this macro was predicted to DISCRIMINATE"
          n_fail=$((n_fail + 1))
        else
          verdict="PASS i386=$v386 aarch64=$va64 (predicted $w386/$wa64)"
          n_pass=$((n_pass + 1))
        fi
      else
        verdict="FAIL measured $v386/$va64 but PRE-REGISTERED $w386/$wa64 -- re-read the header, do not edit the table"
        n_fail=$((n_fail + 1))
      fi
      ;;
    *)
      verdict="UNMEASURABLE-BY-THIS-ARM i386=$k386 aarch64=$ka64 -- a thunk that is not a constant return reads OPTION STATE, which this arm cannot evaluate for a base without selecting it.  NOT a pass."
      n_unmeas=$((n_unmeas + 1))
      ;;
  esac

  printf '%-36s %-7s %-11s %s\n' "$m" "$distinct" "$dverd" "$verdict" \
    | tee -a "$OUT/results.txt"
done

echo "---"
echo "macros examined              : $n_macro"
echo "VALUE  PASS                  : $n_pass"
echo "VALUE  FAIL                  : $n_fail"
echo "VALUE  unmeasurable/report   : $n_unmeas"
echo "DISTINCT ok                  : $n_dpass"
echo "DISTINCT FAIL                : $n_dfail"
echo "distinctness measured        : $n_ddiff DIFFER, $n_dsame SAME"

# NON-VACUITY on the scoring itself.
[ "$n_macro" -ge 5 ] || die "only $n_macro macros scored; the table is not being read"
if [ "$n_pass" = 0 ] && [ "$n_fail" = 0 ]; then
  die "nothing was scored either way -- the classifier matched nothing.  \
Refusing to report this as a clean run."
fi

# NON-VACUITY ON THE DISTINCTNESS ARM SPECIFICALLY, and it is the one that
# matters most: distinctness is the ONLY proposition scored for the fourteen
# option-state thunks, so an instrument that can only ever answer DIFFER would
# pass all fourteen while proving nothing.  The table pre-registers two SAME
# entries (the two HARD_FRAME_POINTER_IS_* predicates, false on both bases for
# a reason written down in target-cumargs.cc), so a run in which SAME never
# occurs among the scored macros means the comparison has stopped comparing
# content -- the vacuous-DIFFER failure, now checked inside the scored
# population and not only in the control.
[ "$n_dsame" -gt 0 ] || die "every scored macro came out DIFFER, including the \
ones pre-registered SAME.  The distinctness test is measuring layout, not \
content; every DIFFER above is vacuous."
[ "$n_ddiff" -gt 0 ] || die "every scored macro came out SAME.  The bodies are \
not being extracted -- an empty body equals an empty body."
[ "$n_dfail" = 0 ] || echo "NOTE: $n_dfail distinctness predictions failed; \
re-read the headers, do not edit the table."
exit 0
