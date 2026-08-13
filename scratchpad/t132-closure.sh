#!/bin/sh
# #132 ARM G -- THE CLOSURE around ACCUMULATE_OUTGOING_ARGS: which of the
# guards over its use sites are answered by the PRIMARY, and are they already
# redirected?
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
cd "$G"
for m in PUSH_ROUNDING REG_PARM_STACK_SPACE INCOMING_REG_PARM_STACK_SPACE \
         STACK_DYNAMIC_OFFSET OUTGOING_REG_PARM_STACK_SPACE ACCUMULATE_OUTGOING_ARGS; do
  i=$(grep -c "define $m" config/i386/i386.h)
  a=$(grep -c "define $m" config/aarch64/aarch64.h)
  d=$(grep -c "define $m" defaults.h)
  r=$(grep -c "mt_$(echo $m | tr A-Z a-z)" defaults.h)
  printf '%-32s i386:%s aarch64:%s defaults.h:%s  mt-redirected:%s\n' "$m" "$i" "$a" "$d" "$r"
done
echo
echo "== G2. which back ends define PUSH_ROUNDING =="
grep -rl 'define PUSH_ROUNDING' config/ | sed 's/^/   /'
