#!/bin/sh
# agent-a260445cf27ba480a-cxxkinds.sh -- WHAT IS IN THE C++ FAIL COLUMN?
#
# PRINCIPLES: "ask whether the FAIL column is compile failures or wrong code
# before investigating anything -- they are different searches and the column
# does not say."  For the first C++ board there is a third category that
# dominates and is neither: the run has **no libstdc++**, because a
# multi-target build has no target libraries at all, so every test that
# includes a standard header fails with `fatal error: <meta>: No such file or
# directory'.  That is a property of the harness, not of the compiler, and a
# raw FAIL total that does not separate it is not a work-list.
#
# It is REPORTED, not subtracted.  A failure floor deleted the signal on this
# branch once and hid 1447 real regressions.
#
# usage: agent-a260445cf27ba480a-cxxkinds.sh <builddir> <triple>
set -u
B=${1:?build dir}
T=${2:?triple}
SUM=$B/gcc/testsuite.$T/g++/g++.sum
LOG=$B/gcc/testsuite.$T/g++/g++.log
[ -f "$B/check-$T.rc" ] || { echo "REFUSE: no check-$T.rc stamp"; exit 9; }
for f in "$SUM" "$LOG"; do
  [ -s "$f" ] || { echo "REFUSE: $f absent or empty"; exit 9; }
done
grep -q '=== g++ Summary' "$SUM" || { echo "REFUSE: $SUM has no summary -- truncated"; exit 9; }

p=$(grep -c '^PASS: ' "$SUM" || true)
f=$(grep -c '^FAIL: ' "$SUM" || true)
[ "$p" -gt 1000 ] || { echo "REFUSE: only $p PASS -- the run did not happen"; exit 9; }

# The tests whose log records a missing standard header.  Attributed by the
# `FAIL:' line that FOLLOWS the diagnostic in the merged log, so a test with a
# real failure and no missing header is not swept in.
grep -E '^(FAIL|PASS|UNSUPPORTED|UNRESOLVED|XFAIL|XPASS): |fatal error: [A-Za-z_0-9]+: No such file' "$LOG" \
  | awk '/fatal error: .*No such file/ { hdr = 1; next }
         /^FAIL: / { if (hdr) print $2; hdr = 0; next }
         { hdr = 0 }' | sort -u > /tmp/cxxkinds-$T.nolibstdcxx
nl=$(grep -c . /tmp/cxxkinds-$T.nolibstdcxx || true)

echo "== $T"
printf '  PASS %8s   FAIL %8s\n' "$p" "$f"
printf '  distinct test FILES whose FAIL follows a missing standard header: %s\n' "$nl"
echo
echo "  FAIL lines by directory, MINUS those files:"
grep '^FAIL: ' "$SUM" | awk '{print $2}' > /tmp/cxxkinds-$T.failfiles
grep -vxF -f /tmp/cxxkinds-$T.nolibstdcxx /tmp/cxxkinds-$T.failfiles \
  | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | head -20
echo
echo "  ... and the same for the files that DID hit a missing header (harness gap):"
grep -xF -f /tmp/cxxkinds-$T.nolibstdcxx /tmp/cxxkinds-$T.failfiles \
  | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | head -10
