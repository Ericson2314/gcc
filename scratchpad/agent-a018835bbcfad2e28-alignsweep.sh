#!/bin/sh
# agent-a018835bbcfad2e28-alignsweep.sh -- the alignment leak is not riscv64's.
#
# `-align.sh' settles board item 7 on riscv64.  This asks the same question of
# the other three scored targets, because a fix to a macro read from the SHARED
# tm.h is a claim about all 47 bases and a one-target demonstration cannot
# support it.  It also keeps the primary in the sweep: x86_64 must be UNMOVED,
# since it is the base whose answers were leaking and it was already getting
# its own.
#
# Prints the `.align'/`.p2align' lines rather than an md5, because the finding
# is in the OPERAND and not in the fact that something changed: on aarch64 the
# pre-fix compiler emitted `.align 16' where the target wants `.align 4', and
# aarch64's `.align' is a LOG -- so every array was being aligned to 2**16
# bytes, not to 16.
#
# usage: BEFORE=<bd> AFTER=<bd> alignsweep.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
O=${O:-/tmp/w-a018835bbcfad2e28}
BEFORE=${BEFORE:?before build dir}
AFTER=${AFTER:?after build dir}
F=$O/al.c
[ -f "$F" ] || cat > "$F" <<'EOF'
int f (int x) { return x + 1; }
int g (int x) { return x * 3; }
int arr[64];
char c1 = 1;
EOF

for row in \
  "x86_64-pc-linux-gnu       /tmp/b-stock-agent-ab1900d5279ba137f-x86_64" \
  "aarch64-unknown-linux-gnu /tmp/b-stock-agent-a3464debf6893de84-aarch64" \
  "riscv64-unknown-linux-gnu /tmp/b-stock-agent-ab1900d5279ba137f-riscv64" \
  "s390x-ibm-linux-gnu       /tmp/b-stock-agent-a3464debf6893de84-s390x"
do
  t=${row%% *}; st=${row##* }
  [ -d "$st" ] || { echo "FATAL: no stock control at $st"; exit 9; }
  BEFORE=$BEFORE AFTER=$AFTER STOCK=$st \
    sh "$S/agent-a018835bbcfad2e28-bothsided.sh" "$t" "$F" -O2 || continue
  for s in before after stock; do
    printf '     %-7s %s\n' "$s" \
      "$(grep -E '\.align|\.p2align' "$O/bs/al.$t.$s.s" | tr -s ' \t' ' ' | paste -sd'|')"
  done
done
