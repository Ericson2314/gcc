#!/bin/sh
# #176 -- apply the ruled per-base form to a `gcc/config/' source:
#   #include "coretypes.h"          #include "coretypes.h"
#   #include "tm.h"           ->    #include "multi-target-base.h"
#                                   #include BASE_HEADER (tm.h)
#
# Refuses any file not matching that exact two-line shape, so a source with a
# different include order is reported rather than silently rewritten -- 8 bad
# include orders once amplified into 251 diagnostics from one cause.
set -e
cd "$(cd "$(dirname "$0")/.." && pwd)"
rc=0
for f in "$@"; do
  [ -f "$f" ] || { echo "MISSING  $f"; rc=1; continue; }
  if grep -q 'multi-target-base.h' "$f"; then
    echo "SKIP     $f (already names multi-target-base.h)"; continue
  fi
  n=$(grep -c '^#include "tm\.h"$' "$f" || true)
  [ "$n" = 1 ] || { echo "REFUSE   $f ($n bare tm.h lines, expected 1)"; rc=1; continue; }
  grep -B1 '^#include "tm\.h"$' "$f" | head -1 | grep -q '^#include "coretypes\.h"$' \
    || { echo "REFUSE   $f (tm.h not immediately after coretypes.h)"; rc=1; continue; }
  perl -0pi -e 's{^\#include "coretypes\.h"\n\#include "tm\.h"\n}'\
'{#include "coretypes.h"\n#include "multi-target-base.h"\n#include BASE_HEADER (tm.h)\n}m' "$f"
  grep -q '^#include BASE_HEADER (tm\.h)$' "$f" \
    || { echo "FAILED   $f (rewrite produced nothing)"; rc=1; continue; }
  echo "OK       $f"
done
exit $rc
