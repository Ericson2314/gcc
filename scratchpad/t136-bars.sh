#!/bin/sh
# #136 -- the two-base bars, and the DIFF that says what changed.
#
# x86_64 must be byte-identical to `89883e54f02': 12369 bytes, md5 378fc33c1e70.
# aarch64 is EXPECTED to change -- that is the fix landing -- so the bar for it
# is not a checksum but the diff itself, printed in full, against the same file
# from the before build.
#
# usage: t136-bars.sh <before-build> <after-build>
set -u
BEF=${1:?before build dir}
AFT=${2:?after build dir}
for B in "$BEF" "$AFT"; do
  case "$B" in
    */b-a5cf4*) ;;
    *) echo "FATAL: $B is not named for this worktree"; exit 9 ;;
  esac
done
S=$(cd "$(dirname "$0")" && pwd)
[ -f "$S/big.c" ] || { echo "FATAL: no $S/big.c"; exit 9; }

for B in "$BEF" "$AFT"; do
  W=$B/t136-bars; rm -rf "$W"; mkdir -p "$W"
  for t in x86_64-pc-linux-gnu:i386 aarch64-unknown-linux-gnu:aarch64; do
    tgt=${t%:*}; base=${t#*:}
    cfg=$B/lib/gcc/17.0.0/$tgt/specs-config
    [ -f "$cfg" ] || { echo "FATAL: $B has no specs-config for $tgt"; exit 9; }
    ( cd "$W" && "$B/gcc/cc1" -quiet -nostdinc -O2 -ftarget-config="$cfg" \
	"$S/big.c" -o "$base.s" ) 2> "$W/$base.err"
    echo "$B $base: rc=$? bytes $(wc -c < "$W/$base.s") md5 $(md5sum < "$W/$base.s" | cut -c1-12)"
  done
done

echo
echo "== x86_64: before vs after (expected identical)"
diff "$BEF/t136-bars/i386.s" "$AFT/t136-bars/i386.s" && echo "   identical"
echo
echo "== aarch64: before vs after (expected to CHANGE, and only where blockage lands)"
diff "$BEF/t136-bars/aarch64.s" "$AFT/t136-bars/aarch64.s" || true
