#!/bin/sh
# #176 -- rebuild ONE object with ITS OWN recipe, from the working tree.
#
# The amputation sweep borrowed `cfgexpand.o''s recipe for every file, and
# that is what mis-scored `c/gccspec.cc' (DELETE-CLEAN, then four
# `OPT_... was not declared' in the real build) and `rtl.cc' / `read-rtl.cc' /
# `print-rtl.cc' (DELETE-CLEAN, then 4272 diagnostics as generators).  One
# recipe is not every configuration a file is built in.
#
# This asks make for the recipe of the exact object under test instead.
# usage: t176-realrecipe.sh <builddir> <object> <source-abs-path>
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; O=${2:?object, e.g. c/gccspec.o}; SRCF=${3:?source path}
[ -f "$SRCF" ] || { echo "FATAL: no such source $SRCF"; exit 9; }
R=$(sh "$S/eb-shell.sh" "cd $D/gcc && make -n $O" | grep -m1 -- "-o $O")
[ -n "$R" ] || { echo "FATAL: make -n $O produced no compile line"; exit 9; }
CXX=$(printf '%s\n' "$R" | awk '{print $1}')
FLAGS=$(printf '%s\n' "$R" | sed -e "s| -o $O.*||" -e 's/^[^ ]* //')
W=$D/t176-real; mkdir -p "$W"
n=$(echo "$O" | tr '/' '_')
if sh "$S/eb-shell.sh" \
     "cd $D/gcc && $CXX $FLAGS -I$(dirname "$SRCF") -o $W/$n -c $SRCF" \
     > /dev/null 2> "$W/$n.err"; then
  echo "PASS  $O built from $SRCF with its own recipe"
else
  echo "FAIL  $O"; grep -m5 -E 'error:' "$W/$n.err"; exit 1
fi
