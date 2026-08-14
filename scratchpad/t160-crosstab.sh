#!/bin/sh
# Task #160: cross-tabulate the SOURCE-TEXT verdict (t160-need2.sh) against
# the BUILD verdict (t160-amputate.sh).  The interesting cell is
# CLEAR x FAIL: a file whose own text needs nothing and which still cannot be
# built without `tm.h', i.e. the transitive-header channel, which no
# text-reading instrument can see.
# usage: t160-crosstab.sh <amputate-output> <need2-output>
set -e
A=${1:?amputate output}
N=${2:?need2 output}
awk '/^(PASS|FAIL|SILENT)/ { print $2, $1 }' "$A" | sort > /tmp/t160-a.$$
awk '{ print $2, $1 }' "$N" | sort > /tmp/t160-n.$$
join /tmp/t160-n.$$ /tmp/t160-a.$$ | awk '{ print $2, $3 }' | sort | uniq -c
echo "--- CLEAR x FAIL, with the cause the build gave:"
join /tmp/t160-n.$$ /tmp/t160-a.$$ | awk '$2 == "CLEAR" && $3 == "FAIL" { print $1 }' \
  | while read f; do
      printf '  %-44s %s\n' "$f" \
        "$(grep -m1 -F " $f " "$A" | sed 's/^FAIL *[^ ]* *//')"
    done
rm -f /tmp/t160-a.$$ /tmp/t160-n.$$
