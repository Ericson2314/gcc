#!/bin/sh
# #121 -- read a mode's OWN row out of each base's OWN generated mode tables.
#
# This is the measurement the selftest failure is about.  The tables are
# positional initialisers in shared-enum order and every entry carries a
# `/* <modename> */' tag, so the row is found by NAME rather than by counting
# commas -- the only way to be sure the row belongs to the mode being asked
# about.  The VALUE is printed verbatim (entries are `{ 48 * BITS_PER_UNIT, 0 }'
# poly pairs, not bare integers, so picking a field yields `{').
#
# What is being tested: for a base that does NOT define the mode, is it
# nevertheless classed MODE_INT -- making SCALAR_INT_MODE_P true -- while
# carrying precision 0?  That combination is the "one name, several
# authorities" shape: the class says the mode is a usable scalar integer, the
# precision says the mode does not exist here, and both come out of the same
# table for the same base.
set -u
D=${1:-/tmp/b-abeb4d62}
M=${MODE:-CI}

found=0
for f in "$D"/gcc/mt-*/insn-modes-*.cc; do
  test -f "$f" || continue
  b=$(basename "$f" .cc); b=${b#insn-modes-}
  found=$((found + 1))
  org=$(grep "^  E_${M}mode," "$D/gcc/insn-modes-$b.h" | sed 's/.*\/\* //; s/ \*\///')
  echo "=== $b : ${M}mode defined-by=$org"
  # Each generated table is `<decl> {' ... `};'.  Name the table from the decl
  # line so the row can be attributed; print only the tagged row.
  awk -v m="$M" '
    /^(const )?(unsigned char|poly_uint16|unsigned short|unsigned char|const char|[A-Za-z_]+) [a-z_]+\[/ { tab = $0; sub(/\[.*/, "", tab); sub(/.* /, "", tab) }
    index($0, "/* " m " */") { printf "    %-22s %s\n", tab, $0 }
  ' "$f"
done

[ "$found" -gt 0 ] || { echo "FATAL: found no $D/gcc/mt-*/insn-modes-*.cc -- scoring nothing, not 'no divergence'"; exit 9; }
echo "read $found per-base mode tables"
