#!/bin/sh
# #133 -- OBJECT-LEVEL, BOTH-SIDED reading of mt_base_stack_dynamic_offset.
#
# This arm exists because the CODEGEN arm cannot run on aarch64: the macro's
# aarch64 arm needs `flag_stack_clash_protection && cfun->calls_alloca', and
# that exact combination walls in `insn-emit' (see t133-alloca-wall.sh), which
# the brief puts out of scope.  So the evidence that the two bases now answer
# DIFFERENTLY is taken here instead.
#
# `index ($0, f)' and NOT `awk '$0 ~ f'': the demangled name carries `()',
# which is an EMPTY REGEX GROUP and matches nothing.
#
# Non-vacuity floors, run FIRST, because a missing tool piped into grep -c
# scores 0 in the direction that makes everything look clean.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b133}
SYM=mt_base_stack_dynamic_offset

echo "=== ARM 0: the tools and the objects exist ==="
sh "$S/eb-shell.sh" "cd $B/gcc && nm --version | head -1" > "$B/t133-nm-ver" 2>&1
cat "$B/t133-nm-ver"
grep -qi 'GNU nm' "$B/t133-nm-ver" || { echo "FATAL: no nm"; exit 9; }

for base in i386 aarch64; do
  o="$B/gcc/target-cumargs-$base.o"
  
  [ -n "$o" ] && [ -f "$o" ] || { echo "FATAL: no per-base target-cumargs.o for $base"; ls "$B"/gcc/mt-* 2>&1 | head; exit 9; }
  echo "$base -> $o"
done

echo
echo "=== ARM 1: the symbol is DEFINED once per base, and is LOCAL (static) ==="
for base in i386 aarch64; do
  o="$B/gcc/target-cumargs-$base.o"
  sh "$S/eb-shell.sh" "nm -C --defined-only $o" > "$B/t133-nm-$base.txt" 2>&1
  n=$(wc -l < "$B/t133-nm-$base.txt")
  [ "$n" -gt 5 ] || { echo "FATAL: nm on $o gave $n lines"; exit 9; }
  c=$(awk -v f="$SYM" 'index ($0, f) { print }' "$B/t133-nm-$base.txt" | wc -l)
  echo "$base: nm lines=$n  $SYM definitions=$c"
  awk -v f="$SYM" 'index ($0, f) { print "   " $0 }' "$B/t133-nm-$base.txt"
done

echo
echo "=== ARM 2: THE BODIES.  They must DIFFER -- that is the whole point ==="
for base in i386 aarch64; do
  o="$B/gcc/target-cumargs-$base.o"
  sh "$S/eb-shell.sh" "objdump -d -C $o" > "$B/t133-dis-$base.txt" 2>&1
  n=$(wc -l < "$B/t133-dis-$base.txt")
  [ "$n" -gt 100 ] || { echo "FATAL: objdump on $o gave $n lines"; exit 9; }
  awk -v f="$SYM" '
    index ($0, f) && index ($0, ">:") { on = 1 }
    on { print }
    on && /^$/ { exit }
  ' "$B/t133-dis-$base.txt" > "$B/t133-body-$base.txt"
  bl=$(wc -l < "$B/t133-body-$base.txt")
  echo "--- $base  ($bl lines)"
  [ "$bl" -gt 2 ] || { echo "FATAL: empty cut for $base -- refusing to score"; exit 9; }
  sed -n '1,40p' "$B/t133-body-$base.txt"
done

echo
echo "=== ARM 3: the selector is bound by shared objects ==="
sh "$S/eb-shell.sh" "cd $B/gcc && nm -uC *.o" > "$B/t133-undef.txt" 2>&1
u=$(wc -l < "$B/t133-undef.txt")
[ "$u" -gt 1000 ] || { echo "FATAL: nm -uC gave $u lines"; exit 9; }
echo "nm -uC lines over shared objects: $u"
sh "$S/eb-shell.sh" "cd $B/gcc && nm -uC --print-file-name *.o" \
  > "$B/t133-undef-f.txt" 2>&1
awk 'index ($0, "mt_stack_dynamic_offset") { print "   " $0 }' "$B/t133-undef-f.txt"
echo "objects binding mt_stack_dynamic_offset: $(awk 'index ($0, "mt_stack_dynamic_offset")' "$B/t133-undef-f.txt" | wc -l)"

echo
echo "=== ARM 4: function.o must no longer bind anything from the old ladder ==="
awk 'index ($0, "function.o") && (index ($0, "ix86_reg_parm_stack_space") || index ($0, "ix86_function_type_abi")) { print "   " $0 }' "$B/t133-undef-f.txt"
