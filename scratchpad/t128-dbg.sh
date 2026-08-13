#!/bin/sh
# #128 -- cc1 here is built `-O1 -g0', so gdb cannot read `recog_data' at all
# ("No symbol table is loaded"), and #126 recorded that exact error being
# scored as a passing result.  Rebuild ONLY recog.o with `-g' and relink.
# It changes NO SOURCE.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b128}
touch "$SRC/gcc/recog.cc"
sh "$S/eb-shell.sh" "cd $B/gcc && make cc1 CXXFLAGS='-O1 -g -Wno-error=format-security'" \
  > "$B/dbg.out" 2> "$B/dbg.err"
echo "rc=$?"
echo "stderr lines: $(wc -l < "$B/dbg.err")"
sh "$S/eb-shell.sh" "cd $B/gcc && nm cc1 | grep -c ' [tT] '" || true
tail -3 "$B/dbg.err"
