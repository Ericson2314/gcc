#!/bin/sh
# #145 -- BOTH-SIDED arm arm.  The fix converts one site in `arm.h', which is
# read in two contexts with OPPOSITE settings of `TARGET_POLY_AWARE':
#
#   target-addr-arm.o   TARGET_POLY_AWARE undefined  (the object that failed)
#   mt-arm/arm.o        TARGET_POLY_AWARE 1          (arm's own sources)
#
# Showing the first now compiles proves nothing unless the second still does.
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${D:-/tmp/b-a88fe2f04579b6092}
sh "$S/eb-shell.sh" "cd $D/gcc && make mt-arm/arm.o target-cumargs-arm.o target-cdata-arm.o target-addr-arm.o" \
  > "$D/arm2.out" 2> "$D/arm2.err" || true
echo "error: lines: $(grep -c 'error:' "$D/arm2.err" || true)"
for o in mt-arm/arm.o target-cumargs-arm.o target-cdata-arm.o target-addr-arm.o; do
  [ -f "$D/gcc/$o" ] && echo "  present: $o" || { echo "  MISSING: $o"; exit 9; }
done
