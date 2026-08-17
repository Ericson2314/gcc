#!/bin/sh
# ATTRIBUTE EACH DEBT TEST TO A CAUSE, by reading the diagnostics DejaGnu
# printed for that test and nothing else.
#
# SC-BOARD.md records why this is not optional: crediting a directory's whole
# debt to its top diagnostic OVER-ATTRIBUTED aarch64's `extra_headers' fix by
# 80,264 results.  So the key is per-test, taken from the `Excess errors:'
# block that DejaGnu prints immediately after the `FAIL:' line it belongs to --
# which is the only place in a `.log' where a message is bound to a test name.
#
# The DEBT SET is supplied as a file of test names (`stock PASS -> mt NOT
# PASS'), so a test that fails on BOTH sides cannot enter any bucket here.
#
# usage: a660907426e03e4e9-attrib.sh <mt-gcc.log> <debt-names-file>
set -u
export LC_ALL=C
LOG=${1:?mt gcc.log}
DEBT=${2:?file of debt test names}
[ -f "$LOG" ] || { echo "FATAL: no $LOG"; exit 9; }
[ -s "$DEBT" ] || { echo "FATAL: $DEBT is empty -- an empty debt set buckets nothing and reads as a pass"; exit 9; }
T=$(mktemp -d) || exit 9
trap 'rm -rf "$T"' 0

# name <TAB> normalised message, one row per (test, message).
awk '
  /^FAIL: /   { name = substr($0, 7); inx = 0; next }
  /^Excess errors:/ { inx = 1; next }
  /^$/        { inx = 0; next }
  inx && name != "" { printf "%s\t%s\n", name, $0 }
' "$LOG" > "$T/pairs"
np=$(grep -c . "$T/pairs" || true)
[ "$np" -gt 100 ] || { echo "FATAL: only $np (test, message) pairs parsed from $LOG"; exit 9; }

sort -u "$DEBT" > "$T/debt"
sort -t"$(printf '\t')" -k1,1 "$T/pairs" > "$T/ps"
join -t"$(printf '\t')" -j1 "$T/debt" "$T/ps" > "$T/dp"
echo "== debt tests: $(grep -c . "$T/debt")   with a parsed diagnostic: $(cut -f1 "$T/dp" | sort -u | grep -c .)"
echo
echo "-- CAUSE BUCKETS over the DEBT SET, by distinct test name"
for pat in \
  'unrecognized symbol type:TYPE_OPERAND_FMT (`@object` where arm needs `%object`)' \
  'bad instruction .call mcount:FUNCTION_PROFILER (i386 text emitted for arm)' \
  'bad instruction .(addq|movq|pushq|setz|cfcmov|ccmp):an x86 INSTRUCTION emitted for arm' \
  'internal compiler error:ICE' \
  'selected architecture lacks an FPU:float-ABI / -march' \
  'unrecognized .march target: unset:-march unset (harness)' \
  'no target selected:harness (bare xgcc, no -ftarget-config=)' \
  'thumb conditional instruction should be in IT block:Thumb IT-block' \
  'selected processor does not support:-mcpu/-march feature' \
  'ld returned:LINK (not reached by the compile-only downgrade)' \
; do
  p=${pat%%:*}; lab=${pat#*:}
  n=$(awk -F'\t' -v p="$p" '$2 ~ p {print $1}' "$T/dp" | sort -u | grep -c . || true)
  printf '%8s  %s\n' "$n" "$lab"
done
echo
echo "-- the same debt tests, by their FIRST message, top 20 (nothing folded)"
awk -F'\t' '!seen[$1]++ {print $2}' "$T/dp" \
  | sed -e "s/'[^']*'/'X'/g" -e 's/^[^ ]*\.s:[0-9]*: //' -e 's/[0-9][0-9]*/N/g' \
  | sort | uniq -c | sort -rn | head -20
