#!/bin/sh
# #127 -- cc1 here is built with `-g0', so `break f if x > N' fails with
# "No symbol table is loaded" and #126 scored that as a passing result while
# gdb had never started.  This rebuilds the TWO objects this task reads --
# emit-rtl.o (where the rtxes are built and the aliasing is done) and
# target-cumargs-select.o (the selectors) -- with `-g', and relinks.
#
# It changes NO SOURCE.  The byte-invariance arms are re-taken afterwards
# against a cc1 built this way, so a debug-info difference cannot be mistaken
# for a code difference.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b127}
touch "$SRC/gcc/emit-rtl.cc" "$SRC/gcc/target-cumargs-select.cc"
sh "$S/eb-shell.sh" "cd $B/gcc && make cc1 CXXFLAGS='-O1 -g -Wno-error=format-security'" \
  > "$B/dbg.out" 2> "$B/dbg.err"
echo "rc=$?"
echo "stderr lines: $(wc -l < "$B/dbg.err")"
tail -3 "$B/dbg.err"
