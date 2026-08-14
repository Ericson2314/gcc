#!/bin/sh
# UR task -- score the LINK wall of a multi-back-end build.
#
# Three refusals, in this order, before any number is printed:
#
#  1. NO STAMP, NO SCORE.  <tag>.rc is written only after make returns
#     (ur-build.sh).  A truncated log is non-empty, contains real compile
#     lines and greps clean -- PRINCIPLES section 4.
#  2. NON-VACUITY FIRST.  If the log contains no `ld:' / collect2 line at all
#     we cannot tell "the link succeeded" from "the link was never attempted"
#     from "my grep is wrong".  Refuse rather than print 0.
#  3. The build dir must be this worktree's.
#
# What it scores: the UNDEFINED REFERENCE population, grouped by SYMBOL (a
# symbol referenced from twelve objects is ONE cause, not twelve lines), and
# the `multiple definition' population separately because another agent owns
# it and the two must not be conflated.
#
# usage: ur-score.sh <builddir> <tag>
set -e
D=${1:?build dir}
TAG=${2:?tag}
case "$D" in
  */b-a6af2c465ae8845f3*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
L="$D/build-$TAG.err"
[ -f "$D/build-$TAG.rc" ] || { echo "FATAL: $D/build-$TAG.rc missing -- log is unstamped, refusing to score"; exit 9; }
[ -f "$L" ] || { echo "FATAL: no $L"; exit 9; }

nld=$(grep -c 'undefined reference to\|multiple definition of\|collect2' "$L" || true)
[ "$nld" -gt 0 ] || {
  echo "FATAL(non-vacuity): $L has no linker line at all."
  echo "  Cannot distinguish 'link clean' from 'link never attempted'."
  exit 9
}
echo "non-vacuity OK: $nld linker lines in $L"
echo "make rc stamp: $(cat "$D/build-$TAG.rc")"
echo

echo "=== UNDEFINED REFERENCES, grouped by symbol (mine) ==="
sed -n "s/.*undefined reference to \`\([^']*\)'.*/\1/p" "$L" \
  | sort | uniq -c | sort -rn > "$D/ur-$TAG-undef.txt"
echo "distinct symbols: $(wc -l < "$D/ur-$TAG-undef.txt")   raw lines: $(grep -c 'undefined reference to' "$L" || true)"
cat "$D/ur-$TAG-undef.txt"
echo

echo "=== MULTIPLE DEFINITION, grouped by symbol (NOT mine -- reported only) ==="
sed -n "s/.*multiple definition of \`\([^']*\)'.*/\1/p" "$L" \
  | sort | uniq -c | sort -rn > "$D/ur-$TAG-multi.txt"
echo "distinct symbols: $(wc -l < "$D/ur-$TAG-multi.txt")   raw lines: $(grep -c 'multiple definition of' "$L" || true)"
head -40 "$D/ur-$TAG-multi.txt"
