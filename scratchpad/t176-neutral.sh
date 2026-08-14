#!/bin/sh
# #176 -- replace a shared TU's `tm.h' include with the ONE target-neutral
# header it actually wanted, as scored by t176-amp3.sh.
#
#   NEUTRAL-OPTS   -> options.h              (generated from EVERY configured
#                                             back end; no primary's answer)
#   NEUTRAL-LAYER  -> multi-target-macros.h  (this branch's conversion layer;
#                                             names no back end)
#
# Each replacement was verified by REBUILDING the object with exactly this
# text and requiring `GCC_TM_H' to be undefined afterwards, so the TU has
# genuinely left the tm.h channel rather than reached it another way.
#
# Refuses a file that does not have the bare line, so a drifted list fails by
# name.
set -e
cd "$(cd "$(dirname "$0")/.." && pwd)"
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
rc=0
apply () { # $1 = verdict tag, $2 = replacement line
  for f in $(awk -v t="$1" '$1 == t {print $2}' "$W/amp3-all.txt"); do
    p=gcc/$f
    grep -q '^[ \t]*#[ \t]*include[ \t]*"tm\.h"' "$p" \
      || { echo "REFUSE  $p (no bare tm.h include)"; rc=1; continue; }
    perl -pi -e "s|^[ \t]*\#[ \t]*include[ \t]*\"tm\.h\".*\$|$2|" "$p"
    grep -q "^$2\$" "$p" || { echo "FAILED  $p"; rc=1; continue; }
    echo "$1 -> $p"
  done
}
apply NEUTRAL-OPTS  '#include "options.h"'
apply NEUTRAL-LAYER '#include "multi-target-macros.h"'
exit $rc
