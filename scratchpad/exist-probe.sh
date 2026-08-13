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
# Format: <macro>:<thunk symbol>:<i386>:<aarch64>:<discriminate?>
# A value of `?' means "no prediction registered -- report, do not score".
PREREG="\
REG_PARM_STACK_SPACE:mt_base_has_reg_parm_stack_space:1:0:yes \
PUSH_ROUNDING:mt_base_has_push_rounding:1:0:yes \
PUSH_ARGS_REVERSED:mt_base_push_args_reversed:1:0:yes \
FUNCTION_MODE:mt_base_function_mode:?:?:yes \
ACCUMULATE_OUTGOING_ARGS:mt_base_accumulate_outgoing_args:?:?:yes \
INCOMING_FRAME_SP_OFFSET:mt_base_incoming_frame_sp_offset:?:?:yes \
DEFAULT_INCOMING_FRAME_SP_OFFSET:mt_base_default_incoming_frame_sp_offset:?:?:no \
INCOMING_REG_PARM_STACK_SPACE:mt_base_incoming_reg_parm_stack_space:?:?:no \
STACK_DYNAMIC_OFFSET:mt_base_stack_dynamic_offset:?:?:no"

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
    "objdump -d '$BUILD/gcc/target-cumargs-$b.o'" > "$OUT/dis-$b.txt" 2> "$OUT/dis-$b.err" \
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
# ---------------------------------------------------------------------------
body () {                     # body <base> <symbol>
  awk -v sym="$2" '
    /^[0-9a-f]+ </ { inf = (index ($0, sym "v>:") > 0 || index ($0, sym "P9tree_node>:") > 0) }
    inf && /^ *[0-9a-f]+:/ { print }
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
strip_body () { sed -e 's/^ *[0-9a-f]*:\t//' -e 's/#.*//' -e 's/[0-9a-f]* <.*>//'; }

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

for e in $PREREG; do
  m=$(echo "$e" | cut -d: -f1)
  sym=$(echo "$e" | cut -d: -f2)
  w386=$(echo "$e" | cut -d: -f3)
  wa64=$(echo "$e" | cut -d: -f4)
  disc=$(echo "$e" | cut -d: -f5)
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

  printf '%-34s %-7s %s\n' "$m" "$distinct" "$verdict" | tee -a "$OUT/results.txt"
done

echo "---"
echo "macros examined            : $n_macro"
echo "PASS (value + discrimination): $n_pass"
echo "FAIL                       : $n_fail"
echo "unmeasurable / report-only : $n_unmeas"

# NON-VACUITY on the scoring itself.
[ "$n_macro" -ge 5 ] || die "only $n_macro macros scored; the table is not being read"
if [ "$n_pass" = 0 ] && [ "$n_fail" = 0 ]; then
  die "nothing was scored either way -- the classifier matched nothing.  \
Refusing to report this as a clean run."
fi
exit 0
