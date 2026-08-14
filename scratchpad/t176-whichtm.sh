#!/bin/sh
# #176 -- WHICH base's `tm.h' does a converted source actually open?
#
# THE REASON THIS ARM EXISTS.  None of the ten `config/' sources converted in
# this task is compiled by a `c,lto' build: the six `*-d.cc' need the D front
# end, and `sol2-c.cc' / `vms-c.cc' / `darwin-driver.cc' / `vxworks-driver.cc'
# need a Solaris / VMS / Darwin / VxWorks target.  So "the build stayed green"
# says nothing whatever about them, and saying so is the point -- an all-clear
# is only worth stating when the instrument could have said otherwise.
#
# What CAN be measured without those front ends is the only thing the edit
# changed: which file the include resolves to.  `cpp -H' names every header
# opened, so the question is answered directly rather than inferred.
#
# BOTH-SIDED BY CONSTRUCTION.  Each file is preprocessed twice, under two
# different `-DMT_BASE'.  A pass requires the opened `tm.h' to FOLLOW the flag
# in both runs.  A file that hardcoded a path, or that fell back to the build
# root's own `tm.h' (the primary's), would open the SAME file both times --
# which is precisely the silent failure `-I' shadowing used to produce, and it
# cannot pass this arm.
#
# usage: t176-whichtm.sh <base-a> <base-b> <config-source>...
set -e
S=$(cd "$(dirname "$0")" && pwd)
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
D=$W/b-a7cee-before
# The sources under test are the CONVERTED ones, so this arm reads a snapshot
# of the tree WITH the change -- set MT_SRC.  It only preprocesses; the build
# dir it borrows flags from is never written to.
SRC=${MT_SRC:-$W/snap-after}
A=${1:?base a}; shift
B=${1:?base b}; shift
for b in "$A" "$B"; do
  [ -f "$D/gcc/$b-inc/tm.h" ] || { echo "FATAL: no $D/gcc/$b-inc/tm.h"; exit 9; }
done
[ "$A" != "$B" ] || { echo "FATAL: the two bases must differ"; exit 9; }

O=$D/t176-which; mkdir -p "$O"
if [ ! -s "$O/recipe.txt" ]; then
  sh "$S/eb-shell.sh" "cd $D/gcc && make -n cfgexpand.o" \
    | grep -m1 -- '-o cfgexpand\.o' > "$O/recipe.txt"
fi
R=$(cat "$O/recipe.txt")
FLAGS=$(printf '%s\n' "$R" | sed -e 's/ -o cfgexpand\.o.*//' -e 's/^[^ ]* //' -e 's/-DMT_BASE=[^ ]*//g')
CXX=$(printf '%s\n' "$R" | awk '{print $1}')

pass=0; fail=0
for f in "$@"; do
  n=$(echo "$f" | tr '/' '_')
  src=$SRC/gcc/$f
  [ -f "$src" ] || { echo "FATAL: no such file $src"; exit 9; }
  got=""
  for b in "$A" "$B"; do
    sh "$S/eb-shell.sh" \
      "cd $D/gcc && $CXX $FLAGS -DMT_BASE=$b-inc -I$(dirname "$src") -H -E -o /dev/null $src" \
      > /dev/null 2> "$O/$n.$b.H" || true
    # The FIRST tm.h opened is the one the directive resolved to.
    t=$(grep -o '[A-Za-z0-9_-]*-inc/tm\.h' "$O/$n.$b.H" | head -1)
    [ -n "$t" ] || t=$(grep -o '[^ ]*tm\.h' "$O/$n.$b.H" | head -1)
    got="$got $b=>${t:-NONE}"
  done
  ea="$A-inc/tm.h"; eb="$B-inc/tm.h"
  if [ "$got" = " $A=>$ea $B=>$eb" ]; then
    printf 'PASS  %-32s %s\n' "$f" "$got"; pass=$((pass + 1))
  else
    printf 'FAIL  %-32s %s   (wanted %s / %s)\n' "$f" "$got" "$ea" "$eb"; fail=$((fail + 1))
  fi
done
echo
echo "t176-whichtm: PASS=$pass FAIL=$fail  (bases $A / $B)"
[ "$fail" = 0 ]
