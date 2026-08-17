#!/bin/sh
# THE SCOPE COLUMNS -- results one run produced and the other did not.
#
# A660907426E03E4E9-ARM-BOARD.md 4b is emphatic that the debt figure is a LOWER
# BOUND: "21,181 further results the stock run produced and the multi-target run
# did not are not in it".  Those are tests the multi-target run never ATTEMPTED,
# because `check_effective_target_*' is answered by the assembler and the
# assembler was refusing every `.type' directive.
#
# So a debt that falls while the scope gap stays put would be a bad result
# dressed as a good one, and the reverse -- newly attempted tests adding a few
# FAILs -- reads as a regression unless the scope is reported beside it.  Both
# columns, always, on the same multiset join `debtnames.sh` uses.
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
cut -f1 "$T/mt" > "$T/mtk"; cut -f1 "$T/st" > "$T/stk"
printf 'results in mt   : %s\n' "$(wc -l < "$T/mt")"
printf 'results in stock: %s\n' "$(wc -l < "$T/st")"
printf 'only in STOCK   : %s\n' "$(comm -13 "$T/mtk" "$T/stk" | wc -l)"
printf 'only in MT      : %s\n' "$(comm -23 "$T/mtk" "$T/stk" | wc -l)"
echo '-- only-in-stock, top directories:'
comm -13 "$T/mtk" "$T/stk" | sed 's/#[0-9]*$//' | sed 's|/[^/]*$||' \
  | sort | uniq -c | sort -rn | head -10
