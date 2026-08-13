#!/bin/sh
# #126 -- cc1 here is built with `-g0', so #125 had to read raw registers and
# the rtx byte layout, and got a plausible-looking garbage reading for its
# trouble (PRINCIPLES section 4 rule 5 / #125 section 5a).
#
# This rebuilds ONE object -- dwarf2cfi.o, the file under test -- with `-g' and
# relinks, so the diagnosis can be read by NAME.  It changes no source, and the
# byte-invariance arms are re-taken afterwards against a cc1 built this way, so
# a debug-info difference cannot be mistaken for a code difference.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b126}
touch "$SRC/gcc/dwarf2cfi.cc" "$SRC/gcc/target-cumargs-select.cc"
sh "$S/eb-shell.sh" "cd $B/gcc && make cc1 CXXFLAGS='-O1 -g -Wno-error=format-security'" \
  > "$B/dbg.out" 2> "$B/dbg.err"
echo "rc=$?"
echo "stderr lines: $(wc -l < "$B/dbg.err")"
tail -3 "$B/dbg.err"
