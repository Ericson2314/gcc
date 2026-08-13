#!/bin/sh
# #125 -- the redirect removed the ICE and left cc1 killed by SIGKILL on the
# same input.  `signal 9' on a 150-line file is not an honest OOM, so this
# finds out WHERE it is spinning rather than assuming.
#
# Two independent readings, because either alone is easy to misread:
#   1. a memory cap, so the runaway allocation fails by name with GCC's own
#      backtrace instead of being reaped by the kernel with none;
#   2. gdb attached, sampled while it spins, which does not depend on the
#      failure being an allocation at all.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b125}
IN=$B/big.c
CFG=/tmp/b125/lib/gcc/17.0.0
A64="-mlittle-endian -mabi=lp64 -ftarget-config=$CFG/aarch64-unknown-linux-gnu/specs-config"

echo "=== ARM 1: 4 GB cap, so the allocation fails by name ==="
sh "$S/eb-shell.sh" \
  "cd $B/gcc && ulimit -v 4000000 && ./cc1 -quiet -nostdinc $IN -o /dev/null $A64" \
  > "$B/hang1.out" 2> "$B/hang1.err"
echo "rc=$?"
head -30 "$B/hang1.err"

echo
echo "=== ARM 2: gdb sample while it spins ==="
cat > "$B/gdb-hang.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
run
EOF
sh "$S/eb-shell-gdb.sh" \
  "cd $B/gcc && timeout -s INT 25 gdb -q -batch -nx -x $B/gdb-hang.cmds -ex 'bt 25' --args ./cc1 -quiet -nostdinc $IN -o /dev/null $A64" \
  > "$B/hang2.out" 2>&1
echo "gdb rc=$?"
tail -35 "$B/hang2.out"

echo
echo "=== ARM 3: the allocation that fails, under the cap, with a backtrace ==="
cat > "$B/gdb-hang3.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break xmalloc_failed
run
bt 30
kill
quit
EOF
sh "$S/eb-shell-gdb.sh" \
  "cd $B/gcc && ulimit -v 4000000 && gdb -q -batch -nx -x $B/gdb-hang3.cmds --args ./cc1 -quiet -nostdinc $IN -o /dev/null $A64" \
  > "$B/hang3.out" 2>&1
echo "gdb rc=$?"
if grep -q 'Breakpoint 1,' "$B/hang3.out"; then
  tail -40 "$B/hang3.out"
else
  echo "NOT REACHED: xmalloc_failed never hit -- the exhaustion is not through xmalloc."
  tail -10 "$B/hang3.out"
fi

echo
echo "=== ARM 4: it is ggc-page.cc:735 (mmap), so break there ==="
cat > "$B/gdb-hang4.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break perror
run
bt 30
kill
quit
EOF
sh "$S/eb-shell-gdb.sh" \
  "cd $B/gcc && ulimit -v 4000000 && gdb -q -batch -nx -x $B/gdb-hang4.cmds --args ./cc1 -quiet -nostdinc $IN -o /dev/null $A64" \
  > "$B/hang4.out" 2>&1
echo "gdb rc=$?"
tail -40 "$B/hang4.out"

echo
echo "=== ARM 5: the COLUMN update_row_reg_save is asked to grow to ==="
# `column' is the second argument -> $esi.  A DWARF register number; aarch64's
# largest is around 100.  A reading in the millions is the out-of-bounds read
# of i386's `debugger64_register_map[FIRST_PSEUDO_REGISTER]' -- an array sized
# by i386's own count, indexed with the UNION width by shared code.
cat > "$B/gdb-hang5.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break update_row_reg_save if (unsigned) $esi > 1000
run
printf "MTCAUSE update_row_reg_save column=%u\n", (unsigned) $esi
bt 4
kill
quit
EOF
sh "$S/eb-shell-gdb.sh" \
  "cd $B/gcc && ulimit -v 4000000 && gdb -q -batch -nx -x $B/gdb-hang5.cmds --args ./cc1 -quiet -nostdinc $IN -o /dev/null $A64" \
  > "$B/hang5.out" 2>&1
echo "gdb rc=$?"
if grep -q 'Breakpoint 1,' "$B/hang5.out"; then
  grep -e MTCAUSE -e '^#' "$B/hang5.out" | head -8
else
  echo "NOT REACHED: no column over 1000 -- the growth is NOT an absurd column."
  tail -8 "$B/hang5.out"
fi
