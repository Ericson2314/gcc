#!/bin/sh
# Everything that has to be true of one 47-base build dir, in one run.
#
# Ordered so a failure stops before it can be misread: the specs probe is a
# PRECONDITION for the census (no specs-config means no target can be
# selected, and `xgcc' then says "no target selected" rather than ICEing --
# which reads as a FIXED compiler, the exact null-result-as-a-pass shape this
# task exists to remove).
#
# usage: TOOLS=<dir with <triple>-as> a98009045f7229938-measure.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
TOOLS=${TOOLS:?dir holding <triple>-as}
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")

echo "############ 0. WHAT WAS BUILT"
echo "srcdir     $(cat "$B/MY-SRC")"
echo "snap sha   $(cat "$(cat "$B/MY-SRC")/SNAP-SHA" 2>/dev/null || echo NONE)"
echo "anchor     $(grep -c MULTI_TARGET "$(cat "$B/MY-SRC")/gcc/Makefile.in")"
echo "all-gcc rc $(cat "$B/all-gcc.rc" 2>/dev/null || echo NO-STAMP)"
# `error:' and not `Error' -- and counted from the STAMPED log only, because a
# log being written looks exactly like a log that finished.
[ -f "$B/all-gcc.rc" ] || { echo "FATAL: no all-gcc.rc stamp; refusing to
score a log that may still be being written."; exit 9; }
echo "error:     $(grep -c 'error:' "$B/all-gcc.err" 2>/dev/null || echo 0)"
echo "cc1        $(ls -la "$B/gcc/cc1" 2>/dev/null | awk '{print $5}' || echo MISSING)"
echo "mt- dirs   $(ls -d "$B"/gcc/mt-*/ 2>/dev/null | wc -l)"

echo
echo "############ 1. WHICH BACK ENDS HAVE AN AUTOMATON (from the generated headers)"
G="$B/gcc" sh "$S/a98009045f7229938-dfacensus.sh" "$B/gcc"

echo
echo "############ 2. specs-config for every target with a verified cross as"
B="$B" TOOLS="$TOOLS" sh "$S/a7d26223eefcfa725-runspecs.sh" 2>&1 | tail -60

echo
echo "############ 3. THE ONE-LINE CENSUS AT -O2 (the level the defect lives at)"
OPT=-O2 sh "$S/a7ee6ca7c923e4a58-onelinecensus.sh" "$B"

echo
echo "############ 3b. THE SAME CENSUS AT -O0, as the control"
# Not decoration: -O0 ok=38 / -O2 ok=28 is the finding that -O0 is the least
# representative level.  Printing both keeps the pair together so neither can
# be quoted alone.
OPT=-O0 sh "$S/a7ee6ca7c923e4a58-onelinecensus.sh" "$B" | tail -3

echo
echo "############ 4. THE x86_64 BAR -- 12369 bytes / md5 378fc33c1e70"
sh "$S/mt-bars.sh" "$B" 2>&1 | tail -20

echo
echo "############ 5. specs-config LINE COUNT (232), NOT the md5"
# PRINCIPLES: the md5 is a function of the probing toolchain's PATHS, so two
# correct builds give different md5s and quoting one scores a correct build as
# failed.  Printed here to show it varies, never asserted.
n232=0; nother=0
for f in "$B"/lib/gcc/"$VER"/*/specs-config; do
  [ -f "$f" ] || continue
  L=$(wc -l < "$f")
  if [ "$L" = 232 ]; then n232=$((n232+1)); else
    nother=$((nother+1)); echo "  NOT 232: $f -> $L"
  fi
done
echo "specs-config at 232 lines: $n232   at some other count: $nother"
[ "$n232" -gt 0 ] || { echo "FATAL: ZERO specs-config files at 232 lines --
which is also what 'the glob matched nothing' prints.  Refusing."; exit 9; }
echo "md5s (PRINTED, NOT ASSERTED -- they encode this build dir's paths):"
for f in "$B"/lib/gcc/"$VER"/*/specs-config; do
  [ -f "$f" ] && printf '  %-32s %s\n' \
    "$(basename "$(dirname "$f")")" "$(md5sum < "$f" | cut -c1-12)"
done | head -6
echo "  ... $(ls "$B"/lib/gcc/"$VER"/*/specs-config 2>/dev/null | wc -l) in total, \
$(for f in "$B"/lib/gcc/"$VER"/*/specs-config; do [ -f "$f" ] && md5sum < "$f"; done \
  | sort -u | wc -l) distinct"
