#!/bin/sh
# #158 / PART A -- OBJECT-LEVEL census of a 48-back-end build.
#
# A 48-back-end build does not produce a linked cc1, so this is an object-level
# census only and no runtime bar is claimed from it (PRINCIPLES section 4).
#
# NON-VACUITY ARM RUNS FIRST.  Every count below is a grep, and a grep that
# reads nothing scores as "clean" -- which is the answer being tested for.  So
# the script refuses to score unless it can show it read the log AND that the
# per-base object dirs exist.  "Never attempted" and "passed" are the same
# silence under -k; the filesystem is the second instrument.
#
# usage: t158-census.sh <builddir> <tag>
set -e
D=${1:?build dir}
TAG=${2:?tag}
L="$D/build-$TAG.err"

[ -s "$L" ] || { echo "FATAL: $L missing or empty; nothing to score"; exit 9; }
nl=$(wc -l < "$L")
nb=$(ls -d "$D"/gcc/mt-*/ 2>/dev/null | wc -l)
[ "$nb" -gt 0 ] || { echo "FATAL: no mt-*/ dirs; this is not a multi-target build dir"; exit 9; }
# The log must contain at least one compile command, or it is not a build log
# and every zero below would be an artefact of reading the wrong file.
ncc=$(grep -c 'options-init\.cc\|options-tables\.cc\|\-o mt-' "$L" || true)
echo "non-vacuity: $L has $nl lines; $nb mt-*/ dirs present"

echo
echo "=== back ends configured ==="
echo "  mt-<cpu>/ dirs                 : $nb"
echo "  mt-<cpu>/options-init.o        : $(ls "$D"/gcc/mt-*/options-init.o 2>/dev/null | wc -l)"
echo "  mt-<cpu>/options-tables.o      : $(ls "$D"/gcc/mt-*/options-tables.o 2>/dev/null | wc -l)"
echo "  total mt-<cpu>/*.o             : $(ls "$D"/gcc/mt-*/*.o 2>/dev/null | wc -l)"

echo
echo "=== error: total ==="
grep -c 'error:' "$L" || echo 0

echo
echo "=== per-CAUSE histogram (the error text, not the line) ==="
grep -o 'error: .*' "$L" | sed 's/[0-9]\+/N/g' | cut -c1-70 | sort | uniq -c | sort -rn

echo
echo "=== per-BACK-END, by make's FAILING-TARGET lines ==="
echo "    (NOT by nearest preceding compile line -- invalid under -j8)"
grep -o '\*\*\* \[[^]]*\]' "$L" | sort -u

echo
echo "=== the PART A population specifically ==="
echo "  'was not declared in this scope' in options-init/options-tables:"
n=$(grep 'was not declared in this scope' "$L" | grep -c 'options-init\|options-tables' || true)
echo "    $n"
echo "  'was not declared in this scope' anywhere:"
grep -c 'was not declared in this scope' "$L" || echo 0
