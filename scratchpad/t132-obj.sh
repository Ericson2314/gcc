#!/bin/sh
# #132 ARM E -- BOTH-SIDED EVIDENCE AT THE OBJECT LEVEL.
# `index ($0, f)' and not `$0 ~ f': the demangled name ends in `()', which as a
# regex is an EMPTY GROUP and matches nothing -- #131 lost six arms to that.
# REFUSES on an empty cut.
set -u
B=${B:-/tmp/b132}
S=$(cd "$(dirname "$0")" && pwd)
fail=0
cut_fn () {  # $1 = object, $2 = demangled label
  objdump -dC "$1" | awk -v f="<$2>:" '
    index ($0, f) { on=1; print; next }
    on && /^$/ { exit }
    on { print }'
}
for base in i386 aarch64; do
  o="$B/gcc/target-cumargs-$base.o"
  [ -f "$o" ] || { echo "FAIL: no $o"; fail=1; continue; }
  for fn in mt_base_accumulate_outgoing_args mt_base_incoming_frame_sp_offset; do
    body=$(cut_fn "$o" "$fn()")
    if [ -z "$body" ]; then echo "FAIL: empty cut for $base $fn"; fail=1; continue; fi
    echo "---- $base  $fn ----"
    echo "$body" | sed 's/^/    /'
  done
done
echo
echo "== E2. does SHARED code bind the selector? =="
for o in calls.o expr.o function.o dce.o cselib.o builtins.o combine.o cfgcleanup.o \
         combine-stack-adj.o var-tracking.o targhooks.o; do
  n=$(nm -uC "$B/gcc/$o" 2>/dev/null | grep -c 'mt_accumulate_outgoing_args')
  printf '   %-24s %s undefined ref(s) to mt_accumulate_outgoing_args()\n' "$o" "$n"
done
echo "   -- and NO shared object may still reference an i386 symbol via this macro --"
nm -uC "$B/gcc/calls.o" | grep -i 'ix86' | sed 's/^/     /' || echo "     (none)"
echo
echo "== E3. non-vacuity: nm produced output at all =="
echo "   calls.o undefined symbols: $(nm -uC "$B/gcc/calls.o" | wc -l)"
exit $fail
