#!/bin/sh
# #163 -- did every EDITED back end's own object actually get built?
#
# WHY THIS IS NOT COVERED BY "the build succeeded".  Under `-k' a failed object
# is a line in the log and the build carries on; and PRINCIPLES section 4's
# rule stands -- "never attempted" and "passed" are the same silence.  The 18
# unwrapped hook-table guards and the 7 `TARGET_HAVE_TLS HAVE_AS_TLS' -> `true'
# conversions live in exactly these objects, and the failure they would produce
# is at a back end's TARGET_INITIALIZER line, naming a macro nowhere near the
# edit.  So: name the file that was edited, and require the object.
#
# Reads the FILESYSTEM as the second instrument, per the same rule.
set -u
D=${1:?build dir}
case "$D" in
  */b-agent-aab545de8b02de843*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/make-top.rc" ] || { echo "FATAL: $D/make-top.rc absent -- unstamped log"; exit 9; }
G="$D/gcc"

# cpu:object -- the back end whose .cc or .h #163 edited, and the object that
# compiles it.  pa and ia64 and rs6000/xcoff were HEADER edits, so the object
# named is the one that reads the header.
EDITED="aarch64:aarch64 alpha:alpha arc:arc arm:arm frv:frv i386:i386 \
ia64:ia64 loongarch:loongarch m68k:m68k microblaze:microblaze mips:mips \
nds32:nds32-md-auxiliary or1k:or1k pa:pa riscv:riscv rs6000:rs6000 \
s390:s390 sh:sh sparc:sparc xtensa:xtensa"

ok=0; miss=0; absent=0
for e in $EDITED; do
  cpu=${e%%:*}; obj=${e##*:}
  if [ ! -d "$G/mt-$cpu" ]; then
    printf '  %-12s %-24s (back end not configured in this build)\n' "$cpu" "$obj"
    absent=$((absent + 1)); continue
  fi
  if [ -f "$G/mt-$cpu/$obj.o" ]; then
    printf '  %-12s %-24s OK\n' "$cpu" "$obj.o"
    ok=$((ok + 1))
  else
    printf '  %-12s %-24s *** NOT BUILT ***\n' "$cpu" "$obj.o"
    miss=$((miss + 1))
  fi
done
echo
echo "edited back ends: $ok built, $miss missing, $absent not configured here"
[ "$ok" -ge 10 ] || { echo "FATAL: only $ok objects read; this build is too small to score"; exit 9; }
[ "$miss" = 0 ] || { echo "FATAL: $miss edited back ends produced no object"; exit 9; }
