#!/bin/sh
# #133 -- compile fn-clash.c for both bases and record the artefact.
# $1 = tag.  Refuses if the compile produced no .s at all, and refuses if the
# driver is missing, so an absent compiler cannot score as "no difference".
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b133}
TAG=${1:-clash}
cp "$S/fn-clash.c" "$B/fn-clash.c" || exit 9
for t in aarch64-unknown-linux-gnu x86_64-pc-linux-gnu; do
  [ -x "$B/gcc/$t-gcc" ] || { echo "FATAL: no driver $B/gcc/$t-gcc"; exit 9; }
  out="$B/$TAG-clash-$t.s"
  rm -f "$out"
  sh "$S/eb-shell.sh" "cd $B/gcc && ./$t-gcc -S -O2 -fstack-clash-protection -nostdinc -o $out $B/fn-clash.c" \
    > "$B/$TAG-clash-$t.out" 2> "$B/$TAG-clash-$t.err"
  rc=$?
  if [ ! -s "$out" ]; then
    echo "$t rc=$rc  NO OUTPUT"; head -5 "$B/$TAG-clash-$t.err"; continue
  fi
  echo "$t rc=$rc bytes=$(wc -c < "$out") md5=$(md5sum < "$out" | cut -c1-12) stderr=$(wc -l < "$B/$TAG-clash-$t.err")"
done
