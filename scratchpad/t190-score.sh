#!/bin/sh
# #190 -- score one build dir for the cxx_target_objs fix.
#
# ARMS, in the order PRINCIPLES asks for them:
#
#   0  NON-VACUITY FIRST.  Refuse to score a build with no `.rc' stamp (a log
#      being written looks exactly like a log that finished), refuse if the
#      tools are missing (a missing tool piped into `grep -c' reads 0 in the
#      direction that makes the reference look right), and refuse if `nm' can
#      see no symbols at all in the binary under test.
#   1  the GENERATED TEXT -- MT_CXX_OBJS_MOVED / MT_CXX_TARGET_OBJS in
#      multi-target-md.mk.
#   2  the EXECUTED result -- does cc1plus exist, i.e. did the link run.  #189
#      is the reason these are two arms: correct generated text failed only
#      when a shell read it.
#   3  BOTH-SIDED.  aarch64_target_macros must be DEFINED in cc1plus, and
#      ix86_target_macros must STILL be defined.  One-sided evidence cannot
#      tell "fixed" from "everyone now gets the same new answer".
#   4  the CONTROL -- cc1 must be unaffected.
set -u
D=${1:?build dir}
G=$D/gcc
for t in nm grep awk; do
  command -v $t > /dev/null || { echo "FATAL: $t not found"; exit 9; }
done
[ -f "$D/make-top.rc" ] || { echo "FATAL: $D has no make-top.rc stamp"; exit 9; }
echo "make rc=$(cat "$D/make-top.rc")"

echo "--- arm 1: generated text"
if [ -f "$G/multi-target-md.mk" ]; then
  grep -n 'MT_CXX_OBJS_MOVED\|MT_CXX_TARGET_OBJS =\|MT_CXX_OBJS_[a-z]' \
    "$G/multi-target-md.mk" || echo "  (no MT_CXX_* lines -- this is the BEFORE tree)"
else
  echo "  FATAL: no multi-target-md.mk"; exit 9
fi

echo "--- arm 2: did the link run"
for b in cc1 cc1plus; do
  if [ -f "$G/$b" ]; then echo "  $b PRESENT $(wc -c < "$G/$b") bytes"
  else echo "  $b ABSENT"; fi
done
echo "  cc1plus link diagnostics in make-top.err:"
grep -c 'cc1plus' "$D/make-top.err" 2>/dev/null || true
grep 'undefined reference' "$D/make-top.err" 2>/dev/null | sed 's/^.*undefined reference/undefined reference/' \
  | sort | uniq -c | sort -rn | head -20

echo "--- arm 3: both-sided symbol arm"
for b in cc1 cc1plus; do
  [ -f "$G/$b" ] || { echo "  $b: not built, cannot score"; continue; }
  tot=$(nm -C "$G/$b" 2>/dev/null | grep -c .)
  if [ "$tot" -lt 1000 ]; then
    echo "  FATAL: nm read $tot symbols from $b -- the instrument did not run"
    exit 9
  fi
  echo "  $b: $tot symbols"
  # `aarch64_target_macros' is NOT in this list and the first draft had it:
  # aarch64 spells its TARGET_CPU_CPP_BUILTINS entry point
  # `aarch64_cpu_cpp_builtins', so the arm read `defined=0' on a cc1 that
  # demonstrably contains aarch64-c.o -- a zero that was a claim about my
  # spelling, not about the binary.  `targetm_c_ops_<base>' is the name every
  # back end has by construction (gen-multi-target-md.awk emits the table), so
  # it is the one an arm can rely on.
  for s in ix86_target_macros aarch64_cpu_cpp_builtins \
           ix86_pragma_target_parse aarch64_pragma_target_parse \
           targetm_c_ops_i386 targetm_c_ops_aarch64 target_c_ops_for; do
    # `grep -w' on the DEMANGLED name: an anchored or `()'-bearing pattern
    # scores 0 for reasons that are about the pattern, not the binary.
    d=$(nm -C "$G/$b" 2>/dev/null | grep -w "$s" | awk '$2 ~ /^[TDBRVWtdbrvw]$/' | grep -c .)
    u=$(nm -C "$G/$b" 2>/dev/null | grep -w "$s" | awk '$2 == "U"' | grep -c .)
    echo "    $s: defined=$d undefined=$u"
  done
done

echo "--- arm 4: control -- objects the C side already had"
grep -n 'C_TARGET_OBJS' "$G/Makefile" 2>/dev/null | head -4
