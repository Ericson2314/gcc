#!/bin/sh
# agent-a95a42fd940ce4d8e-rows.sh -- the FAIL ROWS naming recog.cc:2892, by
# back end and by test, taken from the ICE line ITSELF rather than from
# surrounding context.
#
# The first draft of this used `grep -B40' and guessed the testcase from the
# nearest preceding path.  That is the same shape PRINCIPLES bans for
# attributing a diagnostic to a back end by the nearest preceding compile line,
# and it is wrong for the same reason: gcc.log interleaves.  The `FAIL:' row
# NAMES its own test and its own optimisation level, so it is read directly and
# no proximity is involved.
set -u
B=${B:-/tmp/b-a7ee6ca7c923e4a58/gcc}
SITE=${SITE:-recog.cc:2892}
O=${O:-/tmp/w-agent-a95a42fd940ce4d8e}
mkdir -p "$O"
tot=0
for t in alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi \
         avr-unknown-elf mips64-unknown-elf or1k-unknown-elf; do
  L="$B/testsuite.$t/gcc/gcc.log"
  [ -r "$L" ] || { echo "== $t  NOLOG"; continue; }
  grep -h "$SITE" "$L" | grep '^FAIL' | sed 's/^FAIL: //; s/ *(internal.*//' \
    | sed 's/  */ /g' | sort > "$O/rows.$t"
  n=$(wc -l < "$O/rows.$t")
  tot=$((tot+n))
  echo "== $t   $n rows"
  awk '{print $1}' "$O/rows.$t" | sort | uniq -c | sort -rn | sed 's/^/     /'
done
echo
echo "TOTAL FAIL rows naming $SITE over the six: $tot   (board published 71)"
# The board's 71 is the number this must reproduce.  It is the only independent
# check available that these logs still belong to the run that was scored.
[ "$tot" = 71 ] && echo "MATCHES the published 71 -- these logs are that run's" \
                || echo "DOES NOT match 71 -- do not treat these logs as the scored run"
echo
echo "== tests carrying the site on MORE THAN ONE back end (the shared-cause candidates)"
awk '{print $1}' "$O"/rows.* | sort -u > "$O/allt"
while read -r c; do
  bes=$(grep -l "^$c " "$O"/rows.* | sed 's|.*/rows\.||' | paste -sd,)
  k=$(grep -l "^$c " "$O"/rows.* | wc -l)
  printf '%2s  %-42s %s\n' "$k" "$c" "$bes"
done < "$O/allt" | sort -rn
