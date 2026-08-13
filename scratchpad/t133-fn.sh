#!/bin/sh
# #127 -- THE REAL PRIZE: does a FUNCTION BODY compile for aarch64?
#
# #126 left three inputs, each dying in a different place, and they are kept
# separate because "it moved" is not a result unless you can say WHICH one
# moved and to WHERE.  Filenames are FIXED and identical on both sides of the
# comparison: #125 lost an arm because `g-small.c' and `small.c' differ by two
# characters that land in the .file directive of a byte-exact invariant.
#
# The x86_64 arm of each input is a NON-VACUITY control: if x86_64 also fails,
# the input is broken and an aarch64 failure says nothing about back ends.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b133}
TAG=${1:-fn}

printf 'int g (int a) { return a + 1; }\n'          > "$B/fn-add.c"
printf 'int f (int);\nint g (int a) { return f (a) + f (a + 1); }\n' > "$B/fn-call.c"
printf 'int x = 1;\n'                                > "$B/fn-data.c"

for t in add call data; do
  for cpu in aarch64-unknown-linux-gnu x86_64-pc-linux-gnu; do
    o="$B/$TAG-$t-$cpu"
    rm -f "$o.s"
    sh "$S/eb-shell.sh" \
      "cd $B/gcc && ./$cpu-gcc -S -nostdinc -o $o.s $B/fn-$t.c" \
      > "$o.out" 2> "$o.err"
    rc=$?
    if grep -q 'internal compiler error' "$o.err"; then
      site=$(grep -m1 'internal compiler error' "$o.err" \
             | sed 's/.*internal compiler error: //')
      echo "$t  $cpu  rc=$rc  ICE: $site"
    elif [ "$rc" != 0 ]; then
      echo "$t  $cpu  rc=$rc  FAIL-NO-ICE: $(head -2 "$o.err" | tr '\n' ' ')"
    elif [ -s "$o.err" ]; then
      echo "$t  $cpu  rc=$rc  COMPILED-WITH-STDERR: $(head -2 "$o.err" | tr '\n' ' ')"
    else
      echo "$t  $cpu  rc=$rc  COMPILED  bytes=$(wc -c < "$o.s")  md5=$(md5sum < "$o.s" | cut -c1-12)"
    fi
  done
done
