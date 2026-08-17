#!/bin/sh
# a302b44ba-stockctl.sh -- THE STOCK CONTROL FOR `3241754cf12'.
#
# "The bisect names this commit on the branch" is NOT the claim "this commit is
# a regression".  `ira.cc' has already been made per-base by this branch in
# several places (#123 i386's `ELIMINABLE_REGS' reaching every back end, #205
# `init_reg_class_start_regs' compiled to an empty body), so a branch-specific
# interaction is entirely plausible -- and the difference between "fix our bug"
# and "inherit upstream's behaviour change" is exactly what a control decides.
#
# THE ASKED-FOR CONTROL WAS "BUILD STOCK AT `3241754cf12' AND AT ITS PARENT".
# Measured first, because that turns out not to be two trees:
#
#   git merge-base <rev> c31b7a09eea  ==  c31b7a09eea  for ALL of
#     e1f0cad1c2c, 3241754cf12^, 3241754cf12, 7b39423abba
#   git log -1 --format=%p 3241754cf12  ==  f1c3095db2c   (ONE parent, not a merge)
#   and `3241754cf12' is authored on this branch, not merged from upstream.
#
# So the upstream content is BYTE-IDENTICAL either side of the boundary: there
# is no stock boundary to cross, and "stock regressed across it too" is not a
# possibility that the evidence leaves open.  `3241754cf12' is ours.
#
# THAT IS AN ANCESTRY ARGUMENT, AND ANCESTRY ARGUMENTS HAVE BEEN WRONG HERE
# BEFORE, so it is not left as the whole answer.  The positive half is this
# script: the STOCK control is asked the three questions directly, with the
# reload ICE compiled rather than read out of a `.sum'.  If stock ICEs too, the
# multi-target build merely inherits an upstream bug and `3241754cf12' is not
# the cause, whatever the bisect says.
#
# THE CONTROL IS NAMED, WITH ITS OWN FIGURES, because a control whose
# provenance is not stated has been the recurring way a green here proves
# nothing:
#
#   /tmp/b-stock-agent-302b44ba-x86_64-pc-linux-gnu
#   srcdir /tmp/snap-stock-302b44ba, upstream merge-base c31b7a09eea, anchor 0
#   full-suite score PASS 163816 / FAIL 16223  -- which is, to the unit, the
#   figure A992B7E5FA4FFAAA7-BOARD.md:281 records for the stock x86_64 control
#   of the board that produced the recorded debt of 67.
#
# usage: a302b44ba-stockctl.sh
set -u
export LC_ALL=C
D=/tmp/b-stock-agent-302b44ba-x86_64-pc-linux-gnu
SUM=$D/gcc/testsuite.x86_64-pc-linux-gnu/gcc/gcc.sum
SRC=/tmp/snap-stock-302b44ba/gcc/testsuite/gcc.target/i386
T=$SRC/pr78671.c
for f in "$D/gcc/xgcc" "$SUM" "$T"; do
  [ -e "$f" ] || { echo "FATAL: no $f"; exit 9; }
done

echo "== STOCK CONTROL: $D"
echo "   srcdir /tmp/snap-stock-302b44ba  (upstream merge-base c31b7a09eea, anchor 0)"
printf '   full-suite score: PASS %s  FAIL %s\n' \
  "$(grep -c '^PASS: ' "$SUM")" "$(grep -c '^FAIL: ' "$SUM")"

echo
echo "== the three names, as the stock control scored them"
for n in 'gcc.target/i386/pr43644.c scan-assembler-times movq 2' \
         'gcc.target/i386/pr78671.c (test for excess errors)' \
         'gcc.target/i386/zext-sse-2.c check-function-bodies func2'; do
  printf '   %-58s %s\n' "$n" "$(grep -F ": $n" "$SUM" | sed 's/:.*//' | tr '\n' ' ')"
done

echo
echo "== and the ICE asked DIRECTLY of the stock compiler, not read from a .sum"
out=$("$D/gcc/xgcc" -B"$D/gcc/" "$T" -march=skylake-avx512 -Og -S -o /tmp/stockctl-302b44ba.s 2>&1)
if printf '%s' "$out" | grep -q 'insn does not satisfy its constraints'; then
  echo "   STOCK ICEs TOO."
  echo "STOCKCTL: the fault is UPSTREAM's and this branch inherited it."
  echo "  \`3241754cf12' is not the cause and no fix effort belongs there."
  exit 1
fi
# "No ICE" must not be the same silence as "did not compile".
if [ ! -s /tmp/stockctl-302b44ba.s ]; then
  echo "   no ICE, but NO ASSEMBLY EITHER.  Output was:"
  printf '%s\n' "$out" | head -5
  echo "STOCKCTL: INCONCLUSIVE -- refusing to score a compiler that emitted"
  echo "  nothing as 'clean'; that is the absent-artefact trap."
  exit 9
fi
echo "   stock compiled it cleanly: $(wc -l < /tmp/stockctl-302b44ba.s) lines of asm, no ICE."
echo
echo "STOCKCTL: STOCK IS CLEAN ACROSS THE BOUNDARY."
echo "  Upstream is byte-identical either side of \`3241754cf12' (same merge-base"
echo "  c31b7a09eea, single non-merge parent, branch-authored), AND the stock"
echo "  compiler built from that base compiles the ICE case without complaint."
echo "  So the branch regresses where stock does not: \`3241754cf12' is"
echo "  interacting with THIS BRANCH's per-base \`ira.cc' work, and the defect"
echo "  is OURS to fix.  The hunk isolation says which half."
exit 0
