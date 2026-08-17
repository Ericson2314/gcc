#!/bin/sh
# RANK THE RESIDUAL BY CAUSE, BOTH-SIDED.
#
# A ranking of the multi-target log's diagnostics alone answers the wrong
# question: upstream GCC in a compile-only run with no target libgcc emits
# plenty of its own, and SC-BOARD.md §4 is explicit that a failure present on
# BOTH sides is not this project's debt.  So every normalised message is
# printed with the STOCK count beside it, and the ranking key is the
# DIFFERENCE.  A message whose two columns match is upstream's behaviour, no
# matter how large the number.
#
# NORMALISATION, and what must NOT be normalised (`a7d26223eefcfa725-causes2.sh'
# pays for each of these):
#   * paths and line/column numbers -> squashed, but only AFTER quoted names
#     are removed, because digit-squashing turns `xstormy16' into `xstormyN'.
#   * a diagnostic that NAMES ITS TARGET keys as one cause per target and so
#     can never rank; the triple and the back-end name are folded out.
#   * a quoted MACRO or SYMBOL name is DEFECT-varying, not target-varying, and
#     is left alone -- folding it would hide a second defect behind a first.
#
# usage: a660907426e03e4e9-causes.sh <mt-gcc.log> <stock-gcc.log>
set -u
export LC_ALL=C
MT=${1:?multi-target gcc.log}
ST=${2:?stock gcc.log}
for f in "$MT" "$ST"; do
  [ -f "$f" ] || { echo "FATAL: no $f"; exit 9; }
done
T=$(mktemp -d) || exit 9
trap 'rm -rf "$T"' 0

norm () {
  grep -hoE '(internal compiler error|error|fatal error|Error|sorry, unimplemented): .*' "$1" \
  | sed -e "s/'[^']*'/'X'/g" \
        -e 's/\xe2\x80\x98[^\xe2]*\xe2\x80\x99/QQ/g' \
        -e 's/arm-unknown-linux-gnueabihf/TRIPLE/g' \
        -e 's/[0-9][0-9]*/N/g' \
        -e 's/[ \t][ \t]*/ /g' \
  | sort | uniq -c | awk '{n=$1; $1=""; sub(/^ /,""); printf "%s\t%d\n", $0, n}' \
  | sort -t"$(printf '\t')" -k1,1
}
norm "$MT" > "$T/m"
norm "$ST" > "$T/s"
nm=$(grep -c . "$T/m"); ns=$(grep -c . "$T/s")
# NON-VACUITY.  A log this instrument cannot parse gives an EMPTY ranking,
# which reads as "no causes" -- the exact null-result-as-a-pass shape.  A real
# multi-target compile-only run of the whole suite always has diagnostics.
[ "$nm" -gt 5 ] || { echo "FATAL: only $nm distinct messages in $MT; the parse failed"; exit 9; }
echo "== distinct normalised messages:  multi-target $nm   stock $ns"
echo
printf '%9s %9s %9s  %s\n' MT STOCK EXCESS MESSAGE
join -t"$(printf '\t')" -a1 -e0 -o 0,1.2,2.2 "$T/m" "$T/s" \
  | awk -F'\t' '{d=$2-$3; if (d>0) printf "%9d %9d %9d  %s\n", $2, $3, d, substr($1,1,150)}' \
  | sort -k3,3nr | head -40
echo
echo "-- present on BOTH sides in comparable numbers (NOT this project's debt):"
join -t"$(printf '\t')" -j1 -o 0,1.2,2.2 "$T/m" "$T/s" \
  | awk -F'\t' '$3>0 && $2-$3 < $3*0.1 {printf "%9d %9d  %s\n", $2, $3, substr($1,1,110)}' \
  | sort -rn | head -10
