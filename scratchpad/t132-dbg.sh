#!/bin/sh
# #131 -- cc1 here is built `-O1 -g0', so gdb cannot read anything ("No symbol
# table is loaded"), and #126 recorded that exact error being scored as a
# passing result.  Rebuild ONLY the objects this task reads through with `-g'
# and relink.  It changes NO SOURCE.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b132}
touch "$SRC/gcc/dwarf2cfi.cc" "$SRC/gcc/target-cumargs-select.cc"
sh "$S/eb-shell.sh" "cd $B/gcc && make cc1 CXXFLAGS='-O1 -g3 -Wno-error=format-security'" \
  > "$B/dbg.out" 2> "$B/dbg.err"
echo "rc=$?"
echo "stderr lines: $(wc -l < "$B/dbg.err")"
tail -3 "$B/dbg.err"
