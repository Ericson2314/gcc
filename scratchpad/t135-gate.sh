#!/bin/sh
# #135 -- THE BEHAVIOURAL ARM FOR `PUSH_ROUNDING', and specifically for
# `combine-stack-adj.cc''s pass GATE, which is the one site in the family
# whose conversion changes pass behaviour rather than a value.
#
# Before: the gate is `#ifndef PUSH_ROUNDING', so with i386 as the primary the
# early return is COMPILED OUT for every target and the pass runs everywhere.
# After: the 38 back ends with no push insns take the early return again when
# ACCUMULATE_OUTGOING_ARGS -- aarch64 among them, so it is observable HERE.
#
# `-fdump-rtl-csa' names the pass in its own output, so this reads the
# COMPILER'S report of whether the pass ran rather than inferring it from the
# assembly.  A dump file that does not exist and a dump file that exists and
# says nothing are distinguished; both are refusals, not "no difference".
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b135}
TAG=${1:-gate}
D=$B/$TAG-dumps
rm -rf "$D"; mkdir -p "$D" || exit 9

# An input with a call, so that ACCUMULATE_OUTGOING_ARGS and the stack
# adjustments the pass exists to combine are both in play.
cat > "$B/csa.c" <<'EOF'
extern int h (int, int, int, int, int, int, int, int, int);
int t (int a)
{
  return h (a, a + 1, a + 2, a + 3, a + 4, a + 5, a + 6, a + 7, a + 8)
	 + h (a, 1, 2, 3, 4, 5, 6, 7, 8);
}
EOF
[ -s "$B/csa.c" ] || { echo "FATAL: input not written"; exit 9; }

for cpu in aarch64-unknown-linux-gnu x86_64-pc-linux-gnu; do
  [ -x "$B/gcc/$cpu-gcc" ] || { echo "FATAL: no driver $cpu-gcc"; exit 9; }
  # The driver must run from `$B/gcc': that is where it finds `cc1'.  Running
  # it from the dump directory gives `cannot execute cc1', which reads like a
  # broken build rather than a wrong cwd.  `-dumpdir' puts the dumps where we
  # want them anyway.
  sh "$S/eb-shell.sh" \
      "cd $B/gcc && ./$cpu-gcc -O2 -S -nostdinc -fdump-rtl-csa \
         -dumpdir $D/ -o $D/$cpu.s $B/csa.c" > "$D/$cpu.out" 2> "$D/$cpu.err"
  rc=$?
  dump=$(ls -1 "$D"/$cpu.c.*csa* 2>/dev/null | head -1)
  if [ "$rc" != 0 ]; then
    echo "$cpu  rc=$rc  FAILED: $(head -2 "$D/$cpu.err" | tr '\n' ' ')"
  elif [ -z "$dump" ]; then
    echo "$cpu  rc=0  NO CSA DUMP FILE -- pass did not run (gate returned false)"
  elif [ ! -s "$dump" ]; then
    echo "$cpu  rc=0  CSA DUMP EMPTY: $dump -- REFUSING to score"
  else
    echo "$cpu  rc=0  csa dump present: $(basename $dump)  $(wc -l < $dump) lines" \
         " asm md5=$(md5sum < $D/$cpu.s | cut -c1-12)"
  fi
  mv -f "$D"/$cpu.c.*csa* "$D/$cpu.csadump" 2>/dev/null
done
