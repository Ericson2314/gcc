#!/bin/sh
# agent-acf1cacfef7c17c69-fmvdiff.sh -- the BOARD MOVEMENT for the FMV fix, by
# test name, over exactly the files the leak can touch.
#
# THE OLD SIDE IS THE FOUR-TARGET BOARD'S OWN PRESERVED aarch64 SUM, subset to
# the "*mv*.c" files.  That board ran at e1f0cad1c2c; this compiler is 37
# commits later, so the comparison is NOT clean by construction and the caveat
# travels with the number: three of those commits touch the compiler
# (TARGET_VTABLE_ENTRY_ALIGN, a use_gcc_stdint manifest key, a cxx_target_objs
# fix).  None is FMV-shaped and none of the moved names is outside this
# population -- but a reader is entitled to know the base differs.
#
# A CLEAN PRE WOULD NEED A SECOND 47-BASE BUILD OF THE PARENT COMMIT, AND THE
# PARENT COMMIT DOES NOT CONFIGURE: gen-target-manifest.sh is a syntax error at
# the tip of multi-target-0 (see commit abad5d977ea).  The nearest BUILDABLE
# ancestor is the board's own snapshot.  Stated rather than papered over.
#
# NOTE ON THIS FILE'S OWN COMMENT STYLE: no backquote quoting anywhere in it.
# That is the bug abad5d977ea fixed in gen-target-manifest.sh, and writing this
# script reproduced it once -- a lone backquote in a comment inside a shell
# function shifted the parity and the file died on an unrelated awk line.
#
# usage: agent-acf1cacfef7c17c69-fmvdiff.sh <old-full.sum> <new-subset.sum>
set -u
OLD=${1:?old full gcc.sum (the boards preserved aarch64 sum)}
NEW=${2:?new subset gcc.sum}
W=$(cd "$(dirname "$0")" && pwd)
for f in "$OLD" "$NEW"; do
  [ -f "$f" ] || { echo "FATAL: no $f"; exit 9; }
done

T=/tmp/fmvdiff-acf1cacfef7c17c69
rm -rf "$T"; mkdir -p "$T"

# Subset BOTH sides to the same population, by test FILE, so the comparison is
# over one set of names rather than over two different suites.  mt-namediff.sh
# refuses a sum with no "=== gcc Summary", so the trailer is rebuilt too.
sub () {
  grep -E '^(PASS|FAIL|XPASS|XFAIL|UNSUPPORTED|UNRESOLVED|ERROR): gcc\.target/aarch64/(f?mv|mvc)[-0-9a-zA-Z]*\.c' "$1" > "$2"
  printf '\n\t\t=== gcc Summary ===\n\n' >> "$2"
}
sub "$OLD" "$T/old.sum"
sub "$NEW" "$T/new.sum"

no=$(grep -cE '^[A-Z]+: ' "$T/old.sum")
nn=$(grep -cE '^[A-Z]+: ' "$T/new.sum")
echo "population  old $no result lines   new $nn result lines"
# NON-VACUITY.  An empty subset on either side reads as "nothing moved".
[ "$no" -ge 20 ] && [ "$nn" -ge 20 ] \
  || { echo "FATAL: old $no / new $nn -- the subset read nothing. REFUSING."; exit 9; }

echo
echo "-- old side, by outcome:"
sed -n 's/^\([A-Z]*\): .*/\1/p' "$T/old.sum" | sort | uniq -c
echo "-- new side, by outcome:"
sed -n 's/^\([A-Z]*\): .*/\1/p' "$T/new.sum" | sort | uniq -c

echo
echo "-- results per TEST FILE, old -> new."
echo "   This is the load-bearing arm: a test that died as ONE UNRESOLVED"
echo "   becomes ~20 scan-assembler results once it compiles, so a column"
echo "   total cannot tell a fix from a regression."
card () { sed -n 's/^[A-Z]*: \([^ 	]*\).*/\1/p' "$1" | sort | uniq -c \
          | awk '{print $2, $1}' | sort ; }
card "$T/old.sum" > "$T/old.card"
card "$T/new.sum" > "$T/new.card"
join -a1 -a2 -e0 -o 0,1.2,2.2 "$T/old.card" "$T/new.card" \
  | awk '$2 != $3 { printf "  %-50s %4s -> %4s\n", $1, $2, $3 }'

echo
echo "-- mt-namediff.sh (the committed instrument):"
sh "$W/mt-namediff.sh" "$T/old.sum" "$T/new.sum" fmv
