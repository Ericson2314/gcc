#!/bin/sh
# Both-sided header read for a list of macro names: shared tm.h vs
# <base>-inc/tm.h, with -DIN_GCC (without it the whole back-end chain is
# skipped and every arm reads the floor -- the reading that refutes every
# finding at once).
#
# A name whose shared value EQUALS a dissenting base's value is either
# converted or genuinely neutral; a name where they DIFFER is a live leak for
# that base.
set -u
B=/tmp/b-a992b7e5fa4ffaaa7/gcc
S=/tmp/snap-agent-a992b7e5fa4ffaaa7/gcc
cd "$B" || exit 9
INC="-I. -I$S -I$S/../include -I$S/../libcpp/include"

for base in "" aarch64 i386 riscv s390; do
  if [ -z "$base" ]; then
    echo '#include "tm.h"' > /tmp/fc.cc; F=""
    tag=SHARED
  else
    echo "#include \"$base-inc/tm.h\"" > /tmp/fc.cc; F="-DMT_BASE=$base-inc"
    tag=$base
  fi
  g++ -E -dM -DIN_GCC -DHAVE_CONFIG_H $F $INC /tmp/fc.cc > "/tmp/fc-$tag.out" 2> "/tmp/fc-$tag.err"
  [ -s "/tmp/fc-$tag.out" ] || { echo "FATAL: empty preprocess for $tag"; head -3 "/tmp/fc-$tag.err"; exit 9; }
done

printf '%-34s %-24s %-24s %-24s %-24s %s\n' NAME SHARED aarch64 i386 riscv s390
for n in "$@"; do
  out=""
  for tag in SHARED aarch64 i386 riscv s390; do
    v=$(sed -n "s/^#define $n \(.*\)$/\1/p" "/tmp/fc-$tag.out" | head -1)
    [ -n "$v" ] || v="(undef)"
    v=$(printf '%.22s' "$v")
    out="$out|$v"
  done
  printf '%-34s %s\n' "$n" "$(printf '%s' "$out" | tr '|' '\t')"
done
