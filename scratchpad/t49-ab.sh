#!/bin/sh
# #49 -- A/B the mkconfig.sh change across two 48-back-end builds.
#
# FOUR ARMS, and the fourth is the one that makes the other three mean
# anything (PRINCIPLES: "ask what would have had to change for your comparison
# to mean anything, then show it did"):
#
#   1. MUST-NOT-MOVE  the set of failing make rules is identical.
#   2. MUST-NOT-MOVE  the object count is identical.
#   3. MUST-MOVE      tm-rs6000.h gains the two #ifndef blocks AND the guarded
#                     symbols flip.
#   4. MUST-MOVE      an rs6000 OBJECT differs.  If every object were
#                     byte-identical the change would be provably inert, and a
#                     green on arms 1-3 would be a green on nothing.  A
#                     "no regressions" result with no movement anywhere is the
#                     shape a no-op produces.
#
# Both build logs must carry their .rc stamp; an unstamped log is REFUSED,
# because a truncated log is non-empty and greps clean.
#
# usage: t49-ab.sh <baseline-builddir> <baseline-tag> <patched-builddir> <patched-tag>
set -u
A=${1:?baseline build dir}; AT=${2:?baseline tag}
B=${3:?patched build dir};  BT=${4:?patched tag}
for p in "$A/$AT" "$B/$BT"; do
  [ -f "$p.rc" ] || { echo "FATAL: $p.rc absent -- refusing to score an unstamped log"; exit 9; }
done
echo "baseline $A/$AT rc=$(cat "$A/$AT.rc")"
echo "patched  $B/$BT rc=$(cat "$B/$BT.rc")"
echo

fails () { grep -oE "\[[^]]*: [^]]*\] Error [0-9]+" "$1" | sed 's/.*: //' | sort; }
grep -oE '\*\*\* \[[^]]*\] Error [0-9]+' "$A/$AT.err" | sed 's/.*\[//;s/\].*//' | sort > /tmp/t49ab-a.txt
grep -oE '\*\*\* \[[^]]*\] Error [0-9]+' "$B/$BT.err" | sed 's/.*\[//;s/\].*//' | sort > /tmp/t49ab-b.txt
na=$(grep -c . /tmp/t49ab-a.txt || true); nb=$(grep -c . /tmp/t49ab-b.txt || true)
echo "== arm 1  failing make rules: baseline $na, patched $nb"
if diff -q /tmp/t49ab-a.txt /tmp/t49ab-b.txt >/dev/null; then
  echo "   IDENTICAL set:"; sed 's/^/     /' /tmp/t49ab-a.txt
else
  echo "   DIFFERS:"; diff /tmp/t49ab-a.txt /tmp/t49ab-b.txt | sed 's/^/     /'
fi

oa=$(find "$A/gcc" -name '*.o' | wc -l); ob=$(find "$B/gcc" -name '*.o' | wc -l)
echo
echo "== arm 2  objects: baseline $oa, patched $ob"
[ "$oa" = "$ob" ] && echo "   IDENTICAL" || echo "   DIFFERS by $((ob-oa))"

echo
echo "== arm 3  tm-rs6000.h (MUST MOVE)"
for d in "$A" "$B"; do
  h="$d/gcc/tm-rs6000.h"
  [ -f "$h" ] || { echo "FATAL: $h missing"; exit 9; }
  printf '   %-46s HAVE_LD_LARGE_TOC block: %s\n' "$d" \
    "$(grep -c 'HAVE_LD_LARGE_TOC' "$h")"
done

echo
echo "== arm 4  an rs6000 object MUST DIFFER (else the change is inert)"
moved=0; same=0; missing=0
for o in mt-rs6000/rs6000.o mt-rs6000/rs6000-logue.o mt-rs6000/rs6000-call.o; do
  if [ -f "$A/gcc/$o" ] && [ -f "$B/gcc/$o" ]; then
    if cmp -s "$A/gcc/$o" "$B/gcc/$o"; then
      same=$((same+1)); printf '   SAME     %s\n' "$o"
    else
      moved=$((moved+1)); printf '   DIFFERS  %s  (%s vs %s bytes)\n' "$o" \
        "$(wc -c < "$A/gcc/$o")" "$(wc -c < "$B/gcc/$o")"
    fi
  else
    missing=$((missing+1)); printf '   ABSENT   %s (one side did not build it)\n' "$o"
  fi
done
echo
if [ "$moved" -gt 0 ]; then
  echo "== arm 4 PASS: $moved rs6000 object(s) moved -- the change is not inert"
elif [ "$missing" -gt 0 ]; then
  echo "== arm 4 CANNOT SCORE: $missing object(s) absent on one side."
  echo "   This is NOT a pass.  Say so rather than banking arms 1-3."
else
  echo "== arm 4 FAIL: every rs6000 object byte-identical -- the change did NOT"
  echo "   reach any object, so arms 1-3 are green on nothing."
fi
