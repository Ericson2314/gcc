#!/usr/bin/env bash
#
# ARM 5 -- IS THE SELECTION MECHANISM ACTUALLY INVOKED?
#
# WHY THIS EXISTS.  `targetm_asm_ops' is a per-back-end table pointer.  Both
# tables were built, both were correct, and TAB scored GLOBAL_ASM_OP PASS for
# both bases -- because TAB reads the TABLES.  Nothing ever pointed
# `targetm_asm_ops' at the selected base: it was constant-initialised with the
# primary's table and assigned nowhere, and `target_asm_ops_for ()' -- the
# lookup written for exactly this purpose -- had no caller anywhere in the
# tree.
#
# That was not a harmless no-op.  `init_targetm_asm_ops' COPIES
# `*targetm_asm_ops' into `targetm.asm_out' during backend_init, so the stuck
# pointer overwrote the selected back end's own correct directives with the
# primary's.  Measured in the linked cc1 before the fix, under a real
# `-ftarget-config=':
#
#     targetm_asm_ops == &targetm_asm_ops_i386      (1)
#     targetm.asm_out.global_op ()  = "\t.globl\t"
#     targetm_asm_ops_aarch64.global_op () = "\t.global\t"
#
# `.globl' and `.global' assemble identically, so nothing downstream of this
# would have said a word.
#
# WHAT THIS ARM MEASURES, AND WHY IT IS NOT A GREP FOR A CALL.  "Presence of a
# mechanism is not evidence anything invokes it" -- so a grep for the call in
# the source is the same class of evidence that failed here.  This asks the
# LINKED OBJECT instead: does `multi-target-select.o' carry an UNDEFINED
# reference to each selector?  A call that was deleted, ifdef'd out, or
# constant-folded away leaves no relocation, and the arm goes red.
#
# THE CONTROLS, both required, because a checker that can only report one
# answer has not been shown able to report the other:
#
#   POSITIVE  a function multi-target-select.cc demonstrably calls
#             (`internal_error') must be found.  Without it, a broken `nm'
#             invocation would report every selector missing -- red for no
#             reason, indistinguishable from red for the right reason.
#   NEGATIVE  a real function it does NOT call (`fancy_abort' is not enough --
#             gcc_assert expands to it; `warning_at' is) must NOT be found.
#             Without it, a check that answered "present" unconditionally would
#             pass on everything.
#
# USAGE:  scratchpad/select-arm.sh [builddir]      default /tmp/b-objs
#         needs binutils; run it under the same nix-shell as the other probes.

set -o pipefail
BUILD=${1:-/tmp/b-objs}
OUT=${OUT:-/tmp/sel-arm}

die () { echo "FATAL: $*" >&2; exit 9; }
for t in nm grep awk; do
  command -v "$t" >/dev/null || die "missing tool: $t (inside the nix-shell?)"
done
OBJ="$BUILD/gcc/multi-target-select.o"
[ -f "$OBJ" ] || die "no $OBJ -- nothing to measure, and an absent object must \
not read as a clean run"
mkdir -p "$OUT" || die "cannot create $OUT"

# `nm -u' lists undefined symbols, i.e. exactly the things this object calls
# and does not define.  Never piped into `grep -q': grep -q exits at the first
# match, nm dies of SIGPIPE, and under `set -o pipefail' the SUCCESSFUL case
# reports failure.  That has cost this project a debugging round already.
nm -u -C "$OBJ" > "$OUT/undef.txt" 2> "$OUT/nm.err" \
  || { cat "$OUT/nm.err"; die "nm -u failed on $OBJ"; }
[ -s "$OUT/nm.err" ] && { cat "$OUT/nm.err"; die "nm -u wrote to stderr"; }
n=$(wc -l < "$OUT/undef.txt")
[ "$n" -gt 20 ] || die "multi-target-select.o has only $n undefined symbols; \
that is not a real symbol table and every verdict below would be vacuous"
echo "multi-target-select.o: $n undefined symbols"

has () { grep -qw -- "$1" "$OUT/undef.txt"; }

fail=0
# ---- controls first, before any verdict is issued -------------------------
if has "internal_error(char const*, ...)"; then
  echo "control POSITIVE: OK -- a known callee (internal_error) is found"
else
  # Fall back to a name match, since the demangled spelling can vary by
  # binutils version.  Still a REAL callee, still a real control.
  grep -q 'internal_error' "$OUT/undef.txt" \
    && echo "control POSITIVE: OK -- internal_error is found" \
    || { echo "control POSITIVE: FAILED -- multi-target-select.o does not \
reference internal_error, which it demonstrably calls.  This check is not \
working and nothing below means anything."; fail=1; }
fi
if grep -q 'warning_at' "$OUT/undef.txt"; then
  echo "control NEGATIVE: FAILED -- warning_at reported present, but \
multi-target-select.cc never calls it.  The check answers yes to everything."
  fail=1
else
  echo "control NEGATIVE: OK -- a function it does not call is not reported"
fi
[ "$fail" = 0 ] || { echo "OVERALL rc=9 (controls)"; exit 9; }

# ---- the verdicts ---------------------------------------------------------
for s in target_asm_ops_for target_addr_for target_cdata_refresh_for; do
  if grep -q "$s" "$OUT/undef.txt"; then
    echo "$s: PASS -- multi-target-select.o references it, so the selection \
runs"
  else
    echo "$s: FAIL -- multi-target-select.o does NOT reference $s.  The table \
exists, the lookup exists, and nothing calls it: whichever table the pointer \
was initialised with answers for every base."
    fail=1
  fi
done


# ---- (c-DATA) HAS THREE STEPS AND THE ABOVE WATCHES ONLY THE FIRST ---------
#
# `target_cdata_refresh_for' being referenced proves the SELECTOR looks the
# base up.  It does not prove:
#
#   step 2  that anything CALLS `init_targetm_cdata ()' to run the refresh
#           function the selector stored.  If nothing does, every slot keeps
#           the poison -- loud -- but a future change that seeded the slots
#           with the primary's values instead would be exactly the
#           `targetm_asm_ops' bug again, and silent.
#   step 3  that the REDIRECT in defaults.h actually reaches the middle end.
#           The redirect is guarded on three -D flags now.  If a fourth
#           category of TU appeared, or the guard were inverted, the macros
#           would quietly go back to expanding to the primary's expressions in
#           libbackend and every per-base slot would be written, correct, and
#           read by nobody.  `targetm_cdata' appearing as an UNDEFINED symbol
#           in a target-independent object is the evidence that some middle-end
#           code really does load it.
#
# This is the `targetm_asm_ops' lesson applied to our own new mechanism: a
# green arm on per-base DATA proves nothing about whether the data is selected,
# and a green arm on SELECTION proves nothing about whether anyone reads it.
echo
for spec in "toplev.o:init_targetm_cdata:calls the refresh"; do
  o=${spec%%:*}; rest=${spec#*:}; sym=${rest%%:*}; what=${rest#*:}
  f="$BUILD/gcc/$o"
  if [ ! -f "$f" ]; then
    echo "$o: FAIL -- not built; an absent object is not a passing arm"; fail=1
    continue
  fi
  nm -u "$f" > "$OUT/undef-$o.txt" 2> "$OUT/nm-$o.err" \
    || { cat "$OUT/nm-$o.err"; die "nm -u failed on $f"; }
  if grep -q "$sym" "$OUT/undef-$o.txt"; then
    echo "$o -> $sym: PASS -- $what"
  else
    echo "$o -> $sym: FAIL -- $o does not reference $sym, so the refresh \
never runs and every (c-DATA) slot keeps whatever it was initialised with"
    fail=1
  fi
done

# Step 3.  Read a real middle-end object -- one that spells a redirected macro
# -- and require it to load `targetm_cdata'.  varasm.o uses BITS_PER_WORD and
# ASM_COMMENT_START; expmed.o uses BITS_PER_WORD.  Two objects, because one
# could stop using its macro for an unrelated reason and that must not read as
# a broken redirect.
#
# THE CONTROL FOR THIS ARM is a target-independent object that spells NO
# redirected macro and must therefore NOT reference targetm_cdata.  Without it,
# "the symbol is undefined here" could be true of every object for reasons
# having nothing to do with the redirect.
for o in varasm.o expmed.o; do
  f="$BUILD/gcc/$o"
  [ -f "$f" ] || { echo "$o: FAIL -- not built"; fail=1; continue; }
  nm -u "$f" > "$OUT/undef-$o.txt" 2> /dev/null
  if grep -q 'targetm_cdata' "$OUT/undef-$o.txt"; then
    echo "$o -> targetm_cdata: PASS -- the defaults.h redirect is live in \
libbackend, so a middle-end read really does go through the per-config slot"
  else
    echo "$o -> targetm_cdata: FAIL -- $o spells a redirected macro but does \
not load targetm_cdata.  The redirect did not reach this TU: the macros are \
still expanding to the PRIMARY's expressions here."
    fail=1
  fi
done
f="$BUILD/gcc/bitmap.o"
if [ -f "$f" ]; then
  nm -u "$f" > "$OUT/undef-bitmap.txt" 2> /dev/null
  if grep -q 'targetm_cdata' "$OUT/undef-bitmap.txt"; then
    echo "control REDIRECT: FAILED -- bitmap.o spells no redirected macro yet \
references targetm_cdata.  The two PASSes above prove nothing."
    fail=1
  else
    echo "control REDIRECT: OK -- an object with no redirected macro does not \
reference targetm_cdata"
  fi
else
  echo "control REDIRECT: FAILED -- bitmap.o absent, so the arm above is \
unchecked"; fail=1
fi

echo "OVERALL rc=$fail"
exit $fail
