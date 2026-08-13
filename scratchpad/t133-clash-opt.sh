#!/bin/sh
# #133 -- fn-clash.c on aarch64 at several -O levels, to find one at which
# -fstack-clash-protection reaches assembly at all.  Prints the FIRST error
# line so a wall is named rather than scored as "no output".
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b133}
TAG=${1:-opt}
cp "$S/fn-clash.c" "$B/fn-clash.c" || exit 9
for o in 0 1 2; do
  out="$B/$TAG-O$o.s"
  rm -f "$out"
  sh "$S/eb-shell.sh" "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -O$o -fstack-clash-protection -nostdinc -o $out $B/fn-clash.c" \
    > "$B/$TAG-O$o.out" 2> "$B/$TAG-O$o.err"
  rc=$?
  if [ -s "$out" ]; then
    echo "O$o rc=$rc bytes=$(wc -c < "$out") md5=$(md5sum < "$out" | cut -c1-12)"
  else
    echo "O$o rc=$rc NO OUTPUT: $(sed -n 2p "$B/$TAG-O$o.err")"
  fi
done
