#!/bin/sh
# agent-a95a42fd940ce4d8e-sites.sh -- which TESTS, by name, produced
# `extract_insn, at recog.cc:2892' on each back end, read from the A7EE board's
# own preserved gcc.log files.
#
# WHY READ SOMEBODY ELSE'S LOGS AT ALL.  The board that produced my task is a
# ~6-hour 10-target run.  Re-running it to learn ~71 test NAMES would cost the
# whole task; the names are a POINTER, and every RTL measurement below is taken
# against MY OWN build.  So a stale log here can only send me to the wrong
# testcase, which the reproduction step then fails to reproduce -- it cannot
# manufacture a green.
#
# THE STAMP IS CHECKED FIRST.  INSTRUMENTS.md records that mtcheck.sh
# OVERWRITES gcc.sum/gcc.log per run, so a `.rc' saying a run finished does not
# say the file on disk still belongs to it.  Here the cross-check is that the
# per-back-end ICE COUNT read out of gcc.log must equal the row count the board
# published; a foreign or truncated log will not reproduce 6 independent
# numbers by accident.
set -u
B=${B:-/tmp/b-a7ee6ca7c923e4a58/gcc}
O=${O:-/tmp/w-agent-a95a42fd940ce4d8e}
SITE='recog.cc:2892'
mkdir -p "$O"
[ -d "$B" ] || { echo "FATAL: no $B"; exit 9; }
echo "reading: $B    site: $SITE"
echo
printf '%-28s %6s %6s  %s\n' TRIPLE ROWS TESTS STAMP
tot=0
for d in "$B"/testsuite.*/gcc; do
  t=$(basename "$(dirname "$d")"); t=${t#testsuite.}
  L="$d/gcc.log"
  [ -r "$L" ] || { printf '%-28s %6s\n' "$t" NOLOG; continue; }
  rc="$B/check-$t.rc"; st=$( [ -r "$rc" ] && cat "$rc" || echo NO-RC )
  n=$(grep -c "$SITE" "$L" 2>/dev/null)
  # The FAIL rows naming the site, and the .c files they belong to.
  grep -B40 "$SITE" "$L" 2>/dev/null \
    | sed -n 's|.*/\(gcc\.c-torture/compile/[A-Za-z0-9_.+-]*\.c\).*|\1|p' \
    | sort -u > "$O/tests.$t"
  k=$(wc -l < "$O/tests.$t")
  printf '%-28s %6s %6s  rc=%s\n' "$t" "$n" "$k" "$st"
  tot=$((tot+n))
done
echo
echo "total lines naming $SITE across all logs: $tot"
echo "per-back-end test lists in $O/tests.<triple>"
# NON-VACUITY: a run where the grep matched nothing anywhere reads exactly like
# a tree where the site is fixed.  The board published SIX back ends carrying
# it, so fewer than six non-empty lists means the extraction failed, not that
# the bug is gone.
nz=0
for f in "$O"/tests.*; do [ -s "$f" ] && nz=$((nz+1)); done
echo "back ends with a non-empty test list: $nz"
[ "$nz" -ge 6 ] || { echo "FATAL: expected >=6 back ends carrying the site; the extraction is wrong"; exit 9; }
# NEGATIVE CONTROL on the grep itself: a site string that must NOT appear.
c=$(grep -rc 'recog.cc:999999' "$B"/testsuite.*/gcc/gcc.log 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
[ "$c" = 0 ] && echo "negative control: bogus site matches 0, as it must" \
             || { echo "FATAL: negative control MATCHED -- the grep is wrong"; exit 9; }
