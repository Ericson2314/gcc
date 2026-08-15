#!/bin/sh
# a5764a65f9eec0063 -- walk the RTL dumps in pass order and report, per side,
# whether the SME ZA unspec insn is still present.  The pass where the two
# sides first disagree is the one that deleted it.
#
# NON-VACUITY: the pattern is matched against BOTH the symbolic spelling
# (`UNSPEC_SME_ADD_WRITE', which stock prints) and the numeric one (`] 652)',
# which multi-target prints because its shared unspec-name table is the
# primary's.  Matching only the symbolic name would score every multi-target
# dump as ABSENT and "find" a deletion in the first pass -- a null result
# indistinguishable from the answer.  The counts below prove both spellings
# are seen at least once, or the script refuses.
set -u
W=${W:-/tmp/w-a5764a65f9eec0063}
PAT='UNSPEC_SME_ADD_WRITE|\] 652)'

seen_sym=0; seen_num=0
for f in "$W"/st/min.c.*r.*; do
  grep -qE 'UNSPEC_SME_ADD_WRITE' "$f" 2>/dev/null && seen_sym=1
done
for f in "$W"/mt/min.c.*r.*; do
  grep -qE '\] 652\)' "$f" 2>/dev/null && seen_num=1
done
[ "$seen_sym" = 1 ] || { echo "FATAL: symbolic spelling never seen on stock side"; exit 9; }
[ "$seen_num" = 1 ] || { echo "FATAL: numeric spelling never seen on mt side"; exit 9; }
echo "non-vacuity OK: both spellings observed"
echo
printf '%-34s %6s %6s\n' PASS STOCK MT
for f in "$W"/st/min.c.*r.*; do
  b=$(basename "$f")
  m="$W/mt/$b"
  [ -f "$m" ] || continue
  s=$(grep -cE "$PAT" "$f" 2>/dev/null || true)
  t=$(grep -cE "$PAT" "$m" 2>/dev/null || true)
  mark=''
  [ "$s" != 0 ] && [ "$t" = 0 ] && mark='   <<<< DIVERGES'
  printf '%-34s %6s %6s%s\n' "${b#min.c.}" "$s" "$t" "$mark"
done
