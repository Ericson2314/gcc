#!/bin/sh
# TASK #112 -- of arm D's SILENT actionable set, which macros does AARCH64
# itself define?  That is the highest-value slice: aarch64 has a real answer,
# shared code is compiled against i386 which does not, so the answer is never
# asked for and NO CODE IS EMITTED.
#
# Reads t112-armD2.sh's artefacts.  Cross-checks against the preprocessor
# confirmation (t112-armD-verify.sh) when it has been run, so a text-only
# false positive cannot enter the list silently.
set -u
A=${A:-/tmp/t112-armD2}
V=${V:-/tmp/t112-verify}
[ -s "$A/silent.txt" ]   || { echo "FATAL: no $A/silent.txt -- run t112-armD2.sh"; exit 9; }
[ -s "$A/defines.txt" ]  || { echo "FATAL: no $A/defines.txt"; exit 9; }

# NON-VACUITY: aarch64 must be a back end the defines table knows about at all.
n64=$(awk '$2=="aarch64"' "$A/defines.txt" | grep -c .)
[ "$n64" -gt 100 ] || { echo "FATAL: only $n64 aarch64 defines -- table wrong"; exit 9; }
echo "aarch64 #defines seen in config/aarch64/*.h: $n64"

awk '$2=="aarch64" {print $1}' "$A/defines.txt" | sort -u > "$A/a64-names.txt"
cut -f1 "$A/silent.txt" | sort -u > "$A/silent-names.txt"
comm -12 "$A/silent-names.txt" "$A/a64-names.txt" > "$A/a64-silent.txt"

if [ -s "$V/confirmed.txt" ]; then
  comm -12 "$A/a64-silent.txt" "$V/confirmed.txt" > "$A/a64-silent-confirmed.txt"
  echo "preprocessor confirmation IS available ($V/confirmed.txt)"
else
  cp "$A/a64-silent.txt" "$A/a64-silent-confirmed.txt"
  echo "WARNING: no $V/confirmed.txt -- TEXT ONLY, upper bound"
fi

echo
echo "SILENT actionable macros: $(wc -l < "$A/silent-names.txt")"
echo "  of which aarch64 defines: $(wc -l < "$A/a64-silent.txt")"
echo "  and confirmed absent by the preprocessor: $(wc -l < "$A/a64-silent-confirmed.txt")"
echo
printf '%-34s %4s  %s\n' MACRO nbe SITES
while read -r m; do
  awk -F'\t' -v m="$m" '$1==m {printf "%-34s %4s  %s\n", $1, $2, $6}' "$A/silent.txt"
done < "$A/a64-silent-confirmed.txt"
echo
echo "=== dropped by the preprocessor cross-check (text said yes, build says defined) ==="
comm -23 "$A/a64-silent.txt" "$A/a64-silent-confirmed.txt" | tr '\n' ' '; echo
