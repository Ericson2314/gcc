#!/bin/sh
# For each back end that had a FAILING per-base back-end object in the BEFORE
# build, say whether that object now EXISTS in the build dir.
#
# This is the arm that distinguishes "fixed" from "never attempted".  Under
# `make -k' an object whose prerequisite failed is silently absent, and absence
# reads identically to success in a log-based count.  So the verdict here is
# taken from the filesystem, not from the log.
#
# usage: poly-verify.sh <builddir> <list-of-mt-<cpu>/<obj>.o, one per line>
set -e
D=${1:?build dir}
L=${2:?failing-object list}
[ -d "$D/gcc" ] || { echo "FATAL: $D/gcc is not a build dir"; exit 9; }
[ -s "$L" ] || { echo "FATAL: $L empty or missing"; exit 9; }

built=0; missing=0
echo "obj                                   state"
while read -r o; do
  [ -n "$o" ] || continue
  if [ -f "$D/gcc/$o" ]; then
    built=$((built+1)); st=BUILT
  else
    missing=$((missing+1)); st="ABSENT (failed or never attempted)"
  fi
  printf '%-38s %s\n' "$o" "$st"
done < "$L"
echo
echo "BUILT=$built  ABSENT=$missing  of $(grep -c . "$L")"
