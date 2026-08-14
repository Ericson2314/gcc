#!/bin/sh
# #176 -- for each `gcc/config/' source still spelling a bare `tm.h' include,
# ask what the BUILD actually names its object, and whether that object is
# given `-DMT_BASE'.
#
# The ruling is `BASE_HEADER (tm.h)' wherever the include survives, and
# BASE_HEADER expands through MT_BASE -- so a source whose object never
# receives MT_BASE cannot take the ruled form.  Reading config.gcc is not
# enough to tell: `c_target_objs' and `extra_gcc_objs' are rewritten per back
# end by gen-multi-target-md.awk, while the `x-<cpu>' host fragments are not.
# Ask the generated make fragments, not the directory layout.
set -e
D=${1:?build dir}
cd "$D/gcc"
for f in multi-target-md.mk multi-target-common.mk; do
  [ -f "$f" ] || { echo "FATAL: $D/gcc/$f missing -- build never configured"; exit 9; }
done
printf '%-24s %-34s %s\n' SOURCE OBJECTS MT_BASE
for o in driver-i386 driver-aarch64 driver-arm driver-alpha \
         darwin-driver vxworks-driver sol2-c vms-c gen-avr-mmcu-specs \
         arm-d mips-d rs6000-d s390-d sparc-d freebsd-d; do
  objs=$(grep -ho "[A-Za-z0-9/_-]*\\b$o\.o" multi-target-md.mk multi-target-common.mk \
         ../Makefile 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')
  [ -n "$objs" ] || objs='(none)'
  # does ANY of those objects appear on a MULTI_TARGET_BASE_DEF line?
  if grep -q "$o\.o.*MULTI_TARGET_BASE_DEF\|MT_.*OBJS.*$o\.o" \
       multi-target-md.mk multi-target-common.mk 2>/dev/null; then b=YES; else b=no; fi
  printf '%-24s %-34s %s\n' "$o" "$(echo "$objs" | cut -c1-34)" "$b"
done
