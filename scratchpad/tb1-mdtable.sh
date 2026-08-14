#!/bin/sh
# #163 -- the per-key TLS insn-condition table, read out of a build dir's
# generated insn-conditions-<key>.md.
#
# DELIBERATELY SEPARATE FROM tb1-mdcond.sh AND IT DOES NOT REQUIRE THE `.rc'
# STAMP.  It reads GENERATED ARTEFACTS, one file at a time, and each file is
# written atomically by move-if-change -- so an unfinished build shows FEWER
# keys, never a wrong count for a key it does show.  That is the one reading a
# truncated log cannot corrupt, and it is the reason this is not folded into
# the scorer: the scorer's arms are counts over the log and must refuse.
# It therefore prints how many keys it saw and leaves the judgement to the
# reader rather than returning a verdict.
set -u
D=${1:?build dir}
G="$D/gcc"
n=$(ls "$G"/insn-conditions-*.md 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "FATAL: no insn-conditions-*.md in $G"; exit 9; }
echo "$n insn-conditions-<key>.md present in $G"
echo
printf '%-40s %5s %5s\n' KEY COND "NON-CONST"
tot=0; ntot=0; keys=0
for f in "$G"/insn-conditions-*.md; do
  c=$(grep -cE 'HAVE_AS_TLS|TARGET_TLS' "$f" 2>/dev/null || true)
  [ "${c:-0}" = 0 ] && continue
  nc=$(grep -E 'HAVE_AS_TLS|TARGET_TLS' "$f" | grep -c '^ *(-1 ' || true)
  k=$(basename "$f" .md); k=${k#insn-conditions-}
  printf '%-40s %5s %5s\n' "$k" "$c" "$nc"
  tot=$((tot + c)); ntot=$((ntot + nc)); keys=$((keys + 1))
done
echo
echo "$keys keys carry TLS conditions: $tot total, $ntot non-constant (-1)"

# A FOLDED CONDITION IS NOT AUTOMATICALLY A LOSS, AND THE TWO CONSTANTS MEAN
# OPPOSITE THINGS.  `0' deletes the pattern from the compiler; `1' keeps it and
# merely decides it at build time instead of per target.  Printing the count
# alone would put those in one bucket, so print the lines.
if [ "$ntot" != "$tot" ]; then
  echo
  echo "the $((tot - ntot)) constant-folded conditions, verbatim:"
  grep -hE '^ *\((0|1) "(.*HAVE_AS_TLS|.*TARGET_TLS)' "$G"/insn-conditions-*.md \
    | sort | uniq -c | sed 's/^/    /'
  echo
  echo "    0 -> pattern deleted at build time;  1 -> pattern kept, condition"
  echo "    decided at build time rather than per target."
fi
