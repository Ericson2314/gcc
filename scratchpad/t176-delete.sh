#!/bin/sh
# #176 -- delete a verified-unnecessary `tm.h' include from a shared TU.
#
# Only ever run on files the amputation sweep scored DELETE-CLEAN,
# DELETE-VIALAYER or STILL-REACHES -- i.e. files whose object was REBUILT
# without the line.  "It still compiles" is not sufficient evidence on its own
# and is not what authorises this: the sweep also required the TU to have
# genuinely lost `tm.h' (`GCC_TM_H' undefined under `-E -dM'), which is the arm
# that catches a file whose only use of a target macro is on an `#if' line.
#
# Refuses a file with no such line, so a list that has drifted from the sweep
# fails by name instead of silently doing nothing.
set -e
cd "$(cd "$(dirname "$0")/.." && pwd)"
rc=0; n=0
for f in "$@"; do
  p=gcc/$f
  [ -f "$p" ] || { echo "MISSING $p"; rc=1; continue; }
  grep -q '^[ \t]*#[ \t]*include[ \t]*"tm\.h"' "$p" \
    || { echo "REFUSE  $p (no bare tm.h include)"; rc=1; continue; }
  perl -ni -e 'print unless /^[ \t]*#[ \t]*include[ \t]*"tm\.h"/' "$p"
  grep -q '^[ \t]*#[ \t]*include[ \t]*"tm\.h"' "$p" \
    && { echo "FAILED  $p (line survived)"; rc=1; continue; }
  n=$((n + 1))
done
echo "deleted from $n files"
exit $rc
