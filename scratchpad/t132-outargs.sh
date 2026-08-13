#!/bin/sh
# #132 -- compile fn-outargs.c for both bases and record the artefact.
# $1 = tag.  Refuses if the compile produced no .s at all.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b132}
TAG=${1:-outargs}
cp "$S/fn-outargs.c" "$B/fn-outargs.c" || exit 9
for t in aarch64-unknown-linux-gnu x86_64-pc-linux-gnu; do
  out="$B/$TAG-outargs-$t.s"
  rm -f "$out"
  sh "$S/eb-shell.sh" "cd $B/gcc && ./$t-gcc -S -O1 -fstack-clash-protection -nostdinc -o $out $B/fn-outargs.c" \
    > "$B/$TAG-outargs-$t.out" 2> "$B/$TAG-outargs-$t.err"
  rc=$?
  if [ ! -s "$out" ]; then
    echo "$t rc=$rc  NO OUTPUT"; head -3 "$B/$TAG-outargs-$t.err"; continue
  fi
  echo "$t rc=$rc bytes=$(wc -c < "$out") md5=$(md5sum < "$out" | cut -c1-12)"
done
