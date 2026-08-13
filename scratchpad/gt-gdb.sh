#!/bin/sh
# JOB 1, attribution arm -- WHERE does the aarch64 + forced-GC run fault?
#
# `gdb run <args>' REPLACES --args and silently drops -ftarget-config, which
# would make cc1 fail for an entirely different reason and look like a result.
# So --args is used, and the arm asserts that the run reached SIGSEGV rather
# than exiting for any other reason.
#
# cc1 here is built at -g0, so the backtrace is symbol-table names, not source
# lines.  That is sufficient for the claim being made -- which function is on
# the stack -- and the limitation is stated rather than worked around.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b-a2c4f72addc68d136-pair}
V=17.0.0
IN=${IN:-/tmp/gt-small.c}
T=${T:-aarch64-unknown-linux-gnu}
C=$B/lib/gcc/$V/$T/specs-config
got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$B/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $B configured from '$got', not $SRC"; exit 9; }
[ -s "$C" ] || { echo "FATAL: no specs-config at $C"; exit 9; }
sh "$S/eb-shell.sh" "cd $B/gcc && gdb -batch -q \
  -ex 'run' -ex 'bt 12' -ex 'info program' \
  --args ./cc1 -quiet -nostdinc -O2 -ftarget-config=$C \
  --param ggc-min-expand=0 --param ggc-min-heapsize=0 $IN -o /tmp/gt-gdb.s"
