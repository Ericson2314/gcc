#!/bin/sh
# #160 -- VALIDATE THE PREDICTOR AGAINST A REAL 3-BASE BUILD.
#
# t160-map.sh predicts, from ONE 48-base build, what would happen at the cc1
# link for {i386, aarch64, X}.  A predictor nobody checked is worth less than
# nothing, so this arm builds the triple for real and compares.
#
# It scores the REAL build on three things, in this order:
#   1. does cc1 exist?                     (the artefact, not the exit status)
#   2. what did ld actually say?           (multiple definition / undefined)
#   3. do those names match the prediction? (by NAME, not by count -- a count
#      is the weakest evidence available, PRINCIPLES section 7)
#
# usage: t160-validate.sh <3-base-builddir> <tag> <base> <48-build t160 dir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?3-base build dir}
TAG=${2:?tag}
X=${3:?the third base, as a cpu_type}
O=${4:?the t160 artefact dir of the 48-base map}

[ -f "$D/build-$TAG.rc" ] || { echo "REFUSING TO SCORE: no $D/build-$TAG.rc stamp"; exit 9; }
[ -f "$O/TABLE.txt" ] || { echo "REFUSING TO SCORE: no prediction at $O/TABLE.txt"; exit 9; }
pred=$(awk -v b="$X" '$1==b {sub(/^[^ ]+ +([0-9]+ +){4}/,""); print}' "$O/TABLE.txt")
[ -n "$pred" ] || { echo "REFUSING TO SCORE: $X has no row in $O/TABLE.txt"; exit 9; }

echo "base            : $X"
echo "predicted       : $pred"
echo "real make rc    : $(cat "$D/build-$TAG.rc")"
if [ -x "$D/gcc/cc1" ]; then
  echo "real cc1        : LINKED ($(stat -c%s "$D/gcc/cc1") bytes)"
else
  echo "real cc1        : ABSENT"
fi

echo "--- ld says (real build) ---"
grep -E 'multiple definition|undefined reference|DSO missing' "$D/build-$TAG.err" \
  | sed 's/.*multiple definition of /MULTI  /; s/.*undefined reference to /UNDEF  /' \
  | tr -d "\`'" | sort -u > "$D/t160-ldsays.txt"
n=$(grep -c . "$D/t160-ldsays.txt" || true)
echo "$n distinct linker complaints"
head -40 "$D/t160-ldsays.txt" | sed 's/^/  /'

echo "--- failing make rules (real build) ---"
grep -E '^make.*\*\*\* \[' "$D/build-$TAG.err" | sed 's/.*\[//' | sort -u | sed 's/^/  /'

echo
echo "--- predictor's named symbols for $X ---"
for f in "$O/missing-$X.txt" "$O/multi-$X.txt" "$O/undef-$X.txt"; do
  [ -s "$f" ] || continue
  echo "  $(basename "$f"):"
  sh "$S/eb-shell.sh" "c++filt < $f" | sed 's/^/    /'
done
echo
echo "COMPARE THE NAMES ABOVE BY HAND.  A count match with a name mismatch is"
echo "not a validation -- two errors cancel (PRINCIPLES section 7)."
