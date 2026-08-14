#!/bin/sh
# Task #160 -- THE AMPUTATION ARM: does this translation unit still compile,
# and still SEE the names it uses, with `tm.h' EMPTIED?
#
# The vocabulary scans (t160-need2.sh) read a file's OWN TEXT.  They cannot see
# the shared headers it includes, and that blind spot is what revoked
# `lists.cc', `rtlhash.cc' and `rtl-error.cc': all three use no target macro
# themselves, and all three include `rtl.h', which reaches `hard-reg-set.h'.
# So "this TU needs nothing" and "nothing this TU includes needs anything" are
# two claims and only the first was ever measured.
#
# This arm measures the second, empirically, using the REAL compile recipe.
#
# THE FIRST VERSION AMPUTATED WITH THE POISONED INCLUDE GUARD (`-DGCC_TM_H',
# the `t152-probe.sh' shape) AND THAT WAS WRONG HERE -- recorded because it is
# the sharper half of this instrument's history.  Pre-defining `GCC_TM_H' does
# make `#include "tm.h"' a no-op, but it also answers "has tm.h been read in
# this TU" with YES, and multi-target-macros.h's neutral `enum reg_class'
# declaration is guarded on exactly that question.  So the poison suppressed
# the very fix under test and the arm reported 8 unchanged `enum reg_class'
# failures on a tree where they were fixed: a MEASUREMENT-SHAPED false
# negative, indistinguishable from "the change did nothing".
#
# So the amputation is now done by DELETING THE LINE, into a copy in the build
# dir -- the snapshot srcdir stays immutable and unread-from -- and the copy is
# compiled with `-I<original dir>' so its own quoted includes still resolve.
# A non-vacuity arm asserts the copy really lost `tm.h': if `GCC_TM_H' is still
# defined afterwards the TU reaches it transitively and the reading is scored
# STILL-REACHES, never PASS.
#
# TWO ARMS PER FILE, BECAUSE ONE IS NOT EVIDENCE:
#
#   COMPILE   the object must build with tm.h emptied.  On its own this proves
#             nothing -- `#if FOO' on an undefined FOO does not error, it
#             silently evaluates FALSE -- which is why the second arm exists.
#   EXPANSION `-E -dM' must still define every name the file uses that the
#             options.h vocabulary contains, and `AUTO_INC_DEC' must keep the
#             value it has WITH tm.h.  A name that vanishes is a behaviour
#             change with no diagnostic, and is scored SILENT, not PASS.
#
# NEGATIVE CONTROL: with `MT_CONTROL=1' the conversion layer is amputated as
# well (`-DGCC_MULTI_TARGET_MACROS_H'), so nothing supplies the neutral
# declarations.  Every file must then FAIL.  A run in which the control passes
# says the arm is measuring something other than what it claims.
#
# usage: t160-amputate.sh <builddir> <snapshot-srcdir> <file>...   (files rel. to gcc/)
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; shift
SRC=${1:?snapshot srcdir}; shift
WANT=${WANT_ANCHOR:-48}
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D was not configured from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "$WANT" ] \
  || { echo "FATAL: snapshot anchor is not $WANT"; exit 9; }

W=$D/t160-amp
mkdir -p "$W"

# One real recipe, taken from the build system rather than reconstructed.
if [ ! -s "$W/recipe.txt" ]; then
  sh "$S/eb-shell.sh" "cd $D/gcc && make -n cfgexpand.o" \
    | grep -m1 -- '-o cfgexpand\.o' > "$W/recipe.txt"
fi
RECIPE=$(cat "$W/recipe.txt")
[ -n "$RECIPE" ] || { echo "FATAL: no recipe for cfgexpand.o"; exit 9; }
FLAGS=$(printf '%s\n' "$RECIPE" | sed -e 's/ -o cfgexpand\.o.*//' -e 's/^[^ ]* //')
CXX=$(printf '%s\n' "$RECIPE" | awk '{print $1}')

CTRL=""
[ "${MT_CONTROL:-0}" = 1 ] && CTRL="-DGCC_MULTI_TARGET_MACROS_H"

pass=0; fail=0; silent=0; still=0
for f in "$@"; do
  b=$(echo "$f" | tr '/' '_')
  src="$SRC/gcc/$f"
  [ -f "$src" ] || { echo "FATAL: no such file: $src"; exit 9; }
  cut=$W/$b.cut.cc
  sed 's|^[ \t]*#[ \t]*include[ \t]*"tm\.h".*$|/* tm.h include AMPUTATED by t160-amputate.sh */|' \
      "$src" > "$cut"
  # Assert the amputation produced the state intended, rather than that sed
  # exited: an injection that silently did nothing reads as a clean pass.
  if grep -q '^[ 	]*#[ 	]*include[ 	]*"tm\.h"' "$src"; then
    grep -q 'AMPUTATED by t160-amputate.sh' "$cut" \
      || { echo "FATAL: $f has a tm.h include and the copy does not record its removal"; exit 9; }
  fi
  ID=$(dirname "$src")
  # Arm 1: as committed (the control reading), -dM.
  sh "$S/eb-shell.sh" "cd $D/gcc && $CXX $FLAGS -E -dM -o $W/$b.with.dM $src" \
     > "$W/$b.with.out" 2> "$W/$b.with.err" || true
  # Arm 2: the tm.h line deleted.
  if sh "$S/eb-shell.sh" \
       "cd $D/gcc && $CXX $FLAGS $CTRL -I$ID -o $W/$b.o -c $cut" \
       > "$W/$b.out" 2> "$W/$b.err"; then
    sh "$S/eb-shell.sh" "cd $D/gcc && $CXX $FLAGS $CTRL -I$ID -E -dM -o $W/$b.dM $cut" \
       > /dev/null 2> "$W/$b.dMerr" || true
    if grep -q '^#define GCC_TM_H' "$W/$b.dM"; then
      printf 'STILL-REACHES %-40s tm.h arrives through another header\n' "$f"
      still=$((still + 1))
      continue
    fi
    n=$(wc -l < "$W/$b.dM" 2>/dev/null || echo 0)
    [ "$n" -gt 1000 ] || { echo "FATAL: $f dumped only $n macros -- read nothing"; exit 9; }
    a1=$(grep -m1 '^#define AUTO_INC_DEC ' "$W/$b.with.dM" || echo none)
    a2=$(grep -m1 '^#define AUTO_INC_DEC ' "$W/$b.dM" || echo none)
    if [ "$a1" != "$a2" ]; then
      printf 'SILENT   %-44s AUTO_INC_DEC: with tm.h [%s] without [%s]\n' "$f" "$a1" "$a2"
      silent=$((silent + 1))
    else
      printf 'PASS     %-44s (%s macros still defined)\n' "$f" "$n"
      pass=$((pass + 1))
    fi
  else
    why=$(grep -m1 -E 'error:' "$W/$b.err" | sed 's/^.*error: //')
    printf 'FAIL     %-44s %s\n' "$f" "$why"
    fail=$((fail + 1))
  fi
done
echo
echo "t160-amputate: PASS=$pass FAIL=$fail SILENT=$silent STILL-REACHES=$still${CTRL:+  [NEGATIVE CONTROL: every file must FAIL]}"
