#!/bin/sh
# agent-a018835bbcfad2e28-size.sh -- size riscv64's debt by SOURCE FILE.
#
# The debt is `stock PASS -> multi-target NOT PASS', keyed on (name,occurrence)
# so a test name appearing N times is N results, which is how the board counts.
# Grouped by the source file the test name starts with, because a CAUSE lives
# in a file, not in a directory (mt-debt-attribute.sh's own reasoning) and not
# in a diagnostic string (grepping the debt for an ICE returns 0 where that ICE
# is dominant -- stock emits no such line, so the name does not carry it).
#
# usage: size.sh <mt.sum> <stock.sum> [filter-regex]
set -u
export LC_ALL=C
MT=${1:?mt sum}; ST=${2:?stock sum}; F=${3:-.}
O=${O:-/tmp/w-a018835bbcfad2e28}
mkdir -p "$O"

for f in "$MT" "$ST"; do
  [ -f "$f" ] || { echo "FATAL: no $f"; exit 9; }
  grep -q '=== gcc Summary' "$f" || { echo "FATAL: $f has no gcc Summary marker"; exit 9; }
done

# name+occurrence key, exactly as the board does it
key () {
  sed -n 's/^\(PASS\|FAIL\|XPASS\|XFAIL\|UNSUPPORTED\|UNRESOLVED\|ERROR\): \(.*\)$/\1\t\2/p' "$1" \
  | awk -F'\t' '{ n[$2]++; printf "%s|%d\t%s\n", $2, n[$2], $1 }' | sort
}
key "$ST" > "$O/st.k"; key "$MT" > "$O/mt.k"
echo "stock results $(wc -l < "$O/st.k")   mt results $(wc -l < "$O/mt.k")"

# debt: stock PASS, mt present and NOT PASS
join -t'	' "$O/st.k" "$O/mt.k" \
| awk -F'\t' '$2=="PASS" && $3!="PASS"' > "$O/debt.all"
echo "DEBT (all): $(wc -l < "$O/debt.all")"

# NON-VACUITY: the same pipeline must be able to report the opposite
echo "control, stock PASS -> mt PASS: $(join -t'	' "$O/st.k" "$O/mt.k" | awk -F'\t' '$2=="PASS" && $3=="PASS"' | wc -l)"

grep -E "$F" "$O/debt.all" > "$O/debt.f" || true
echo "DEBT (filter /$F/): $(wc -l < "$O/debt.f")"
echo
echo "-- by source file, top 40:"
sed 's/|[0-9]*\t.*//' "$O/debt.f" \
| sed 's/^\([^ ]*\.[cCS]\).*/\1/' \
| sort | uniq -c | sort -rn | head -40
