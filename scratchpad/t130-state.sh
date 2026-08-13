#!/bin/sh
# #124 -- record where aarch64 gets to, and the `int x = 1;' artefact, in ONE
# place so the pre-edit and post-edit readings are taken the same way.
#
# `NO-ICE' and `OTHER-STDERR' are distinguished from an ICE, and both ICE
# spellings are matched: #122 lost an arm to a matcher written against the old
# shape of the thing under test.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b130}
TAG=${1:-state}
cp "$S/big.c" "$B/big.c" || exit 9
printf 'int x = 1;\n' > "$B/small.c"

sh "$S/eb-shell.sh" "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o /dev/null $B/big.c" \
  > "$B/$TAG-big.out" 2> "$B/$TAG-big.err"
echo "big.c rc=$?"
if grep -q 'internal compiler error' "$B/$TAG-big.err"; then
  echo "big.c site: $(grep -m1 'internal compiler error' "$B/$TAG-big.err" | sed 's/.*internal compiler error: //')"
elif [ -s "$B/$TAG-big.err" ]; then
  echo "big.c site: OTHER-STDERR"; head -5 "$B/$TAG-big.err"
else
  echo "big.c site: NO-ICE"
fi

rm -f "$B/$TAG-small.s"
sh "$S/eb-shell.sh" "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o $B/$TAG-small.s $B/small.c" \
  > "$B/$TAG-small.out" 2> "$B/$TAG-small.err"
rc=$?
sz=0; [ -f "$B/$TAG-small.s" ] && sz=$(wc -c < "$B/$TAG-small.s")
echo "int x = 1;  rc=$rc  bytes=$sz  stderr_bytes=$(wc -c < "$B/$TAG-small.err")  md5=$( [ -f "$B/$TAG-small.s" ] && md5sum < "$B/$TAG-small.s" | cut -c1-12 )"

# The x86_64 arm that must not move, measured in THIS build dir on both sides.
sh "$S/eb-shell.sh" "cd $B/gcc && ./x86_64-pc-linux-gnu-gcc -S -O2 -nostdinc -o $B/$TAG-x86-O2.s $B/big.c" \
  > "$B/$TAG-x86.out" 2> "$B/$TAG-x86.err"
echo "x86_64 -O2 rc=$?  bytes=$( [ -f "$B/$TAG-x86-O2.s" ] && wc -c < "$B/$TAG-x86-O2.s" )  md5=$( [ -f "$B/$TAG-x86-O2.s" ] && md5sum < "$B/$TAG-x86-O2.s" | cut -c1-12 )"
