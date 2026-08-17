#!/bin/sh
# Emit the DEBT SET as bare test names: `stock PASS -> multi-target NOT PASS'.
# Same multiset join sc-diff.sh uses (name + occurrence index), so a name that
# appears twice cannot land in the debt set by accident of `sort -u'.
set -u
export LC_ALL=C
MT=${1:?mt gcc.sum}
ST=${2:?stock gcc.sum}
T=$(mktemp -d) || exit 9
trap 'rm -rf "$T"' 0
key () {
  sed -n 's/^\(PASS\|FAIL\|XPASS\|XFAIL\|UNSUPPORTED\|UNRESOLVED\|ERROR\): \(.*\)$/\1\t\2/p' "$1" \
  | awk -F'\t' '{ n[$2]++; printf "%s#%d\t%s\n", $2, n[$2], $1 }' | sort -t"$(printf '\t')" -k1,1
}
key "$MT" > "$T/mt"; key "$ST" > "$T/st"
join -t"$(printf '\t')" -j1 -o 0,1.2,2.2 "$T/st" "$T/mt" \
  | awk -F'\t' '$2=="PASS" && $3!="PASS" {sub(/#[0-9]+$/,"",$1); print $1}' | sort -u
