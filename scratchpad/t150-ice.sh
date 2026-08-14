#!/bin/sh
# #150 -- does `add_clobbers' answer for the base in force?
#
# THE NON-VACUITY ARM RUNS FIRST AND THE SCRIPT REFUSES TO SCORE WITHOUT IT.
# PRINCIPLES section 7: "when every arm of your probe reads empty, that looks
# exactly like `branch not taken'".  Here the failure mode is sharper still --
# a missing driver, or a cc1 that was never linked, makes every target read
# "no ICE", which is the shape of SUCCESS.  So arm 0 requires each driver to
# exist AND to be able to produce a diagnostic at all.
#
# usage: t150-ice.sh <builddir> <tag>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
TAG=${2:?tag, e.g. before / after}
case "$B" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
grep -q 'worktrees/agent-ad0e44242408b7fde/configure' "$B/config.log" \
  || { echo "FATAL: $B/config.log does not name this worktree"; exit 9; }

# The four instrument bases, and why these four:
#   x86_64  the PRIMARY -- the authority that was leaking.  Its arm is the
#           both-sided half: it must still get its OWN answer, or the fix has
#           merely given everyone a new single answer.
#   aarch64 the reproducer #150 names.
#   powerpc64 a third base, because two back ends is a habit and not a check.
#           rs6000 is the back end that has already broken the i386+aarch64
#           pair once on this branch (six ELIMINABLE_REGS pairs vs four).
#   s390x   a fourth, and big-endian, so a divergence that happens to agree on
#           three little-endian bases still has somewhere to show.
TARGETS="x86_64-pc-linux-gnu aarch64-unknown-linux-gnu powerpc64-linux-gnu s390x-linux-gnu"
IN=$(cd "$S" && pwd)/big.c
[ -f "$IN" ] || { echo "FATAL: input $IN missing"; exit 9; }

echo "== arm 0: NON-VACUITY (must pass before anything is scored)"
vac=0
for t in $TARGETS; do
  d="$B/gcc/$t-gcc"
  if [ ! -x "$d" ]; then
    echo "  VACUOUS: no driver $d"; vac=1; continue
  fi
  # Can this driver emit a diagnostic at all?  A cc1 that dies before parsing
  # would otherwise make every real arm read clean.
  e=$(sh "$S/eb-shell.sh" \
        "cd $B/gcc && ./$t-gcc -S -nostdinc -o /dev/null $B/t150-vac.c" 2>&1 \
        > /dev/null || true)
  case "$e" in
    *"undeclared"*|*"error"*) echo "  ok: $t emits diagnostics" ;;
    *) echo "  VACUOUS: $t produced no diagnostic for a known-bad input:"
       echo "    [$e]"; vac=1 ;;
  esac
done
[ "$vac" = 0 ] || { echo "REFUSING TO SCORE: non-vacuity arm failed"; exit 9; }

echo
echo "== arm 1: $IN, per base"
for t in $TARGETS; do
  o="$B/t150-$TAG-$t"
  rm -f "$o.s"
  sh "$S/eb-shell.sh" \
    "cd $B/gcc && ./$t-gcc -O2 -S -nostdinc -o $o.s $IN" \
    > "$o.out" 2> "$o.err"
  rc=$?
  if grep -q 'internal compiler error' "$o.err"; then
    site=$(grep -m1 'internal compiler error' "$o.err" \
           | sed 's/.*internal compiler error: //')
    echo "  $t  rc=$rc  ICE: $site"
  elif [ "$rc" != 0 ]; then
    echo "  $t  rc=$rc  FAIL-NO-ICE: $(head -2 "$o.err" | tr '\n' ' ')"
  else
    echo "  $t  rc=$rc  COMPILED  bytes=$(wc -c < "$o.s")  md5=$(md5sum < "$o.s" | cut -c1-12)"
  fi
done
