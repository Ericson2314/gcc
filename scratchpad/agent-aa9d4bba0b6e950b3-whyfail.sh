#!/bin/sh
# agent-aa9d4bba0b6e950b3-whyfail.sh -- for the DEBT in one directory, what did
# the compiler actually SAY?
#
# `mt-debt-attribute.sh' answers "how much of the debt belongs to files hitting
# a KNOWN diagnostic".  This answers the prior question: for the debt whose
# rows are all `(test for excess errors)' and therefore name no diagnostic at
# all, what are the errors?  s390x's biggest directory is
# `gcc.c-torture/compile' at 2,408 with only 214 ICE siblings, so ~2,200 of it
# is something no ICE census can name.
#
# The `.sum' cannot answer this -- the diagnostic is in the `.log'.  So: derive
# the debt file list by name-join as mt-debt-attribute.sh does, then pull those
# files' error lines out of the log and rank them with literals normalised.
#
# NON-VACUITY: refuses if the debt is empty or if no error line is recovered
# for any debt file, because both produce the same silent short output as a
# clean directory.
#
# usage: whyfail.sh <mt-sum> <mt-log> <stock-sum> <directory-prefix>
set -u
export LC_ALL=C
MT=${1:?mt gcc.sum}; ML=${2:?mt gcc.log}; ST=${3:?stock gcc.sum}; DIR=${4:?dir prefix}
for f in "$MT" "$ML" "$ST"; do
  [ -f "$f" ] || { echo "FATAL: no $f" >&2; exit 9; }
done
grep -q '=== gcc Summary' "$MT" || { echo "FATAL: $MT truncated" >&2; exit 9; }
grep -q '=== gcc Summary' "$ST" || { echo "FATAL: $ST truncated" >&2; exit 9; }

TD=$(mktemp -d); trap 'rm -rf "$TD"' 0
key () {
  sed -n 's/^\(PASS\|FAIL\|XPASS\|XFAIL\|UNSUPPORTED\|UNRESOLVED\|ERROR\): \(.*\)$/\1\t\2/p' "$1" \
  | awk -F'\t' '{ n[$2]++; printf "%s#%d\t%s\n", $2, n[$2], $1 }' \
  | sort -t"$(printf '\t')" -k1,1
}
key "$MT" > "$TD/mt"; key "$ST" > "$TD/st"
join -t"$(printf '\t')" -j1 -o 0,1.2,2.2 "$TD/st" "$TD/mt" \
  | awk -F'\t' '$2=="PASS" && $3!="PASS" {print $1}' > "$TD/debt"

grep "^$DIR" "$TD/debt" | sed -e 's/#[0-9]*$//' -e 's/[ 	].*//' | sort -u > "$TD/files"
nd=$(grep -c "^$DIR" "$TD/debt" || true)
nf=$(wc -l < "$TD/files")
echo "-- debt rows under $DIR: $nd, over $nf distinct files"
[ "$nd" -gt 0 ] || { echo "FATAL: no debt under $DIR -- refusing to score" >&2; exit 9; }

# Error lines in the log whose path is one of the debt files.  The log spells
# the full source path, so match on the basename with a `/' in front.
sed 's|.*/||' "$TD/files" | sort -u > "$TD/base"
grep -F -f "$TD/base" "$ML" 2>/dev/null | grep -o 'error: .*' \
  | sed -e "s/'[^']*'/'X'/g" -e 's/[0-9][0-9]*/N/g' -e 's/ *$//' \
  | sort | uniq -c | sort -rn > "$TD/rank"
tot=$(awk '{s+=$1} END{print s+0}' "$TD/rank")
[ "$tot" -gt 0 ] || { echo "FATAL: recovered 0 error lines for $nf debt files -- the log match is broken, not the directory clean" >&2; exit 9; }
echo "-- $tot error lines recovered; top 20 shapes:"
head -20 "$TD/rank"
