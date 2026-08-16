#!/bin/sh
# agent-a260445cf27ba480a-ptrmem.sh -- BOTH-SIDED: does the C++ front end read
# THIS target's `TARGET_PTRMEMFUNC_VBIT_LOCATION', or the primary's?
#
# See the .cc beside this file for what the two layouts are.  The arm is
# both-sided by construction: x86_64 must keep the `vbit_in_pfn' form (pfn odd,
# delta 0) and aarch64 must show the `vbit_in_delta' form (pfn even, delta
# odd).  Showing only that aarch64 is wrong proves nothing -- one side alone
# cannot separate "leaked" from "both got a new common answer".
#
# The NON-VIRTUAL pointer-to-member is the control: its vbit is clear under
# either convention, so it must be identical on both targets.  If it differs,
# the comparison is measuring something else and the verdict is void.
#
# usage: agent-a260445cf27ba480a-ptrmem.sh <builddir>
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"
S=$MT_LIB_DIR

B=${1:?build dir}
mt_assert_builddir "$B"
SRC=$(mt_src_of "$B") || exit 9
V=$(cat "$SRC/gcc/BASE-VER")
# THE NULL-RESULT ARM.  A missing cc1plus and a cc1plus that emits nothing
# interesting produce the same empty grep.
[ -x "$B/gcc/cc1plus" ] || { echo "FATAL: no $B/gcc/cc1plus"; exit 9; }
IN=$S/agent-a260445cf27ba480a-ptrmem.cc
[ -s "$IN" ] || { echo "FATAL: no $IN"; exit 9; }

for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  CFG=$B/lib/gcc/$V/$t/specs-config
  [ -s "$CFG" ] || { echo "FATAL: no specs-config for $t"; exit 9; }
  O=/tmp/pm-a260445cf27ba480a-$t.s
  ( cd "$B/gcc" && ./cc1plus -quiet -nostdinc -O2 -ftarget-config="$CFG" \
      "$IN" -o "$O" ) > /tmp/pm-a260445cf27ba480a-$t.out 2>&1
  rc=$?
  if [ "$rc" != 0 ] || [ ! -s "$O" ]; then
    echo "FATAL[$t]: cc1plus rc=$rc"; sed -n 1,10p /tmp/pm-a260445cf27ba480a-$t.out; exit 9
  fi
  echo "== $t  ($(wc -c < "$O") bytes)"
  awk '/^mt_pmf_(first|second|nonvirtual):/ { n=$0; c=3; print "  " n; next }
       c > 0 && /\.(quad|xword|word|long)/ { print "    " $0; c-- }' "$O"
done
