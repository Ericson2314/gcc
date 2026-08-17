#!/bin/sh
# Both-sided: does __builtin_eh_return work on each scored target?
B=/tmp/b-a992b7e5fa4ffaaa7
for T in aarch64-unknown-linux-gnu s390x-ibm-linux-gnu \
         x86_64-pc-linux-gnu riscv64-unknown-linux-gnu; do
  printf '%-28s ' "$T"
  "$B/gcc/xgcc" -B"$B/asdir-$T/" -B"$B/gcc/" \
    -ftarget-config="$B/lib/gcc/17.0.0/$T/specs-config" \
    -S -O2 "$(dirname "$0")"/agent-a992b7e5fa4ffaaa7-ehreturn.c -o "/tmp/ehret-$T.s" 2> "/tmp/ehret-$T.err"
  printf 'rc=%s  %s\n' "$?" "$(head -1 "/tmp/ehret-$T.err")"
done
