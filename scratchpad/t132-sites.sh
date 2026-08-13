#!/bin/sh
# #132 ARM B -- the SITES.  Position of use decides shape: a use on an
# `#if'/`#ifdef' line CANNOT become a runtime call.
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
cd "$G"

for m in ACCUMULATE_OUTGOING_ARGS ARG_POINTER_CFA_OFFSET FRAME_POINTER_CFA_OFFSET; do
  echo "######## $m ########"
  echo "-- definitions --"
  grep -rn "define $m" . --exclude-dir=testsuite --exclude-dir=doc --exclude=ChangeLog* --exclude=FSFChangeLog* | sed 's/^/   /'
  echo "-- uses OUTSIDE config/ (excluding ChangeLogs) --"
  grep -rnw "$m" . --exclude-dir=config --exclude-dir=testsuite --exclude-dir=doc --exclude-dir=po \
     --exclude=ChangeLog\* --exclude=FSFChangeLog\* \
   | awk -v m="$m" '{
       pre = $0; sub(/^[^:]*:[0-9]*:/,"",pre);
       tag = (pre ~ /^[ \t]*#[ \t]*(if|ifdef|ifndef|elif)/) ? "PREPROC" : "  code ";
       print "   " tag "  " $0 }'
  echo
done
