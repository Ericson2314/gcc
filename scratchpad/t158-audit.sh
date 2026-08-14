#!/bin/sh
# #158 -- AUDIT: which build dirs on this machine were configured with the
# LOSING spelling of the back-end list?
#
# The defect: the top level appends its DERIVED --enable-backends AFTER
# $(HOST_CONFIGARGS), which is where a user's hand-passed --enable-backends
# lands.  gcc/configure takes the last, so the user's value is silently
# discarded.  A build dir that hit this has BOTH spellings in gcc/config.log
# and came up with the derived list.
#
# INSTRUMENT: gcc/config.log's own record of the argv gcc/configure was run
# with -- independent of the scripts by construction (PRINCIPLES section 4),
# and it survives the scripts being repaired afterwards.
#
# BLIND SPOT, stated: this can only see build dirs that still exist and that
# got as far as running gcc/configure.  A dir deleted, or one whose top-level
# configure ran but whose `make' never reached configure-gcc, is invisible.
# So the output is a LOWER BOUND on the exposure, not the exposure.
set -e
found=0
seen=0
for f in /tmp/*/gcc/config.log; do
  [ -f "$f" ] || continue
  seen=$((seen + 1))
  d=$(dirname "$(dirname "$f")")
  n=$(tr ' ' '\n' < "$f" | grep -c '^--enable-backends=' || true)
  v=$(tr ' ' '\n' < "$f" | grep '^--enable-backends=' | tr '\n' ' ')
  # THE QUESTION IS NOT "were there two spellings" BUT "did they DISAGREE".
  # Two identical --enable-backends= values are the harmless case: last-wins
  # picks the same list, so the build got what the user asked for.  A dir where
  # the DISTINCT values differ is one whose measurements were taken on a
  # different back-end set than the person believed.
  u=$(tr ' ' '\n' < "$f" | grep '^--enable-backends=' | sort -u | tr '\n' ' ')
  nu=$(tr ' ' '\n' < "$f" | grep '^--enable-backends=' | sort -u | grep -c . || true)
  if [ "$nu" -gt 1 ]; then
    found=$((found + 1))
    echo "DISAGREE n=$n distinct=$nu  $d"
    echo "          $u"
  elif [ "$n" -gt 1 ]; then
    echo "dup      n=$n (identical, harmless)  $d"
  else
    echo "ok       n=$n  $d"
  fi
done
# NON-VACUITY, first: if no config.log was read at all, this script proves
# nothing and must not report a clean audit.  An all-empty read looks exactly
# like "no build dir was affected", which is the answer it is trying to
# establish (PRINCIPLES section 7).
[ "$seen" -gt 0 ] || { echo "FATAL: read no gcc/config.log at all; audit is vacuous"; exit 9; }
echo "--- $seen build dirs read, $found with DISAGREEING values ---"
