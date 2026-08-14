#!/bin/sh
# #173 -- classify every gcc/config/ file that spells plain `#include "tm.h"'
# by THE GENERATED MAKEFILE, not by filename.
#
#   A  its object appears in a MULTI_TARGET_OBJS_<cpu> / MT_C_OBJS_<cpu> /
#      MT_GCC_OBJS_<cpu> list, i.e. it is compiled once PER BACK END and gets
#      `-DMT_BASE' and (today) `-I<base>-inc'.  BASE_HEADER is the answer.
#   B  it is compiled, but not by any of those rules -- one object, no base,
#      no -I.  BASE_HEADER is NOT the answer; it needs a design decision.
#   N  no rule mentions it at all in this configuration: never compiled here.
#
# The `-I' is what makes A work today.  B files are getting the SHARED tm.h,
# which is the primary back end's header chain under a neutral name.
#
# usage: t173-classify.sh <builddir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRCTREE=$(cd "$S/.." && pwd)
D=${1:?build dir}
MK="$D/gcc/multi-target-md.mk"
[ -f "$MK" ] || { echo "FATAL: no $MK"; exit 9; }
[ -f "$D/gcc/Makefile" ] || { echo "FATAL: no $D/gcc/Makefile"; exit 9; }

# Non-vacuity: the instrument must be able to see per-base object lists at all.
# MINLIST is the number of back ends this build dir was configured with; the
# guard exists so that an EMPTY or truncated makefile cannot score every file
# as N, which is the reading that looks like "nothing is per-base".
nlist=$(grep -c '^MULTI_TARGET_OBJS_[a-z0-9_]* =' "$MK" || true)
[ "$nlist" -ge "${MINLIST:-40}" ] \
  || { echo "FATAL: only $nlist MULTI_TARGET_OBJS_ lists in $MK (want >= ${MINLIST:-40})"; exit 9; }
echo "# $MK: $nlist per-back-end object lists"

# The per-base object namespace, flattened once.
grep -h '^MULTI_TARGET_OBJS_[a-z0-9_]* =\|^MT_C_OBJS_[a-z0-9_]* =\|^MT_GCC_OBJS_[a-z0-9_]* =' \
  "$MK" | tr ' ' '\n' | grep '\.o$' | sort -u > "$D/perbase-objs.txt"
# Everything any rule in either makefile names as a target or prerequisite.
cat "$MK" "$D/gcc/Makefile" > "$D/allmk.txt"

printf '%-46s %s\n' FILE CLASS
cd "$SRCTREE"
for f in $(git grep -l '#include "tm\.h"' -- gcc/config | sed 's|^gcc/config/||' | sort); do
  stem=$(basename "$f" .cc)
  # ANCHORED, NOT SUBSTRING.  `grep arc-c\.o' also matches `sparc-c.o', which
  # scored arc-c.cc as compiled in a build with no arc back end at all --
  # the substring trap this project has met before.  A name is either the
  # whole line or follows a `/'.
  if grep -qE "(^|/)$stem(-[a-z0-9_]+)?\.o\$" "$D/perbase-objs.txt"; then
    c=A
  elif grep -qE "(^|[ /:=])$stem\.o([ :]|\$)" "$D/allmk.txt"; then
    c=B
  else
    c=N
  fi
  printf '%-46s %s\n' "$f" "$c"
done
