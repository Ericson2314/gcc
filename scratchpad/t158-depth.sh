#!/bin/sh
# #158 / PART A -- how DEEP did the 48-back-end build get?
#
# The error total alone cannot answer this.  Under `make -k', "never attempted"
# and "passed" are the same silence (PRINCIPLES section 1), so a low error count
# is consistent with a build that stopped early.  Read the filesystem as the
# second instrument: what objects exist, per base and in total.
#
# usage: t158-depth.sh <builddir>
set -e
D=${1:?build dir}
G="$D/gcc"
[ -d "$G" ] || { echo "FATAL: no $G"; exit 9; }

echo "cc1              : $( [ -f "$G/cc1" ] && echo present || echo ABSENT )"
echo "shared *.o in gcc/: $(ls "$G"/*.o 2>/dev/null | wc -l)"
echo "mt-*/ dirs        : $(ls -d "$G"/mt-*/ 2>/dev/null | wc -l)"
echo "mt-*/*.o total    : $(ls "$G"/mt-*/*.o 2>/dev/null | wc -l)"
echo
echo "distinct object BASENAMES under mt-*/ (what each back end gets):"
ls "$G"/mt-*/*.o 2>/dev/null | sed 's|.*/||' | sort | uniq -c | sort -rn
echo
echo "back ends with FEWER objects than the mode (i.e. something missing):"
ls "$G"/mt-*/*.o 2>/dev/null | sed 's|/[^/]*$||' | sort | uniq -c | sort -n | head -6
