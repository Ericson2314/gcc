#!/bin/sh
# Compare two builds' `specs-config' files LINE BY LINE, not by md5.
#
# WHY.  PRINCIPLES says to quote the artefact's identity rather than a
# statistic about it, and an md5 is the right instrument for "is this the same
# file".  But when it says NO, an md5 says nothing about WHY -- and this
# project has twice built a story on a bar mismatch that turned out to be one
# environment-dependent line.  `mt-bars.sh''s `-g' arm is already known to be
# path-sensitive for exactly this reason.
#
# So: report the number of differing lines per target, and print them.  A
# one-line difference naming an absolute path is an environment fact; a
# many-line difference is a finding.
#
# usage: abe9f294136236fc8-specsdiff.sh <builddirA> <builddirB> <triple>...
set -u
A=${1:?build dir A}; B=${2:?build dir B}; shift 2
[ $# -ge 1 ] || { echo "FATAL: name at least one triple"; exit 9; }
VA=$(cat "$(cat "$A/MY-SRC")/gcc/BASE-VER")
VB=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
echo "A=$A ($VA)"
echo "B=$B ($VB)"
nsame=0; ndiff=0; nmiss=0
for t in "$@"; do
  fa="$A/lib/gcc/$VA/$t/specs-config"
  fb="$B/lib/gcc/$VB/$t/specs-config"
  if [ ! -f "$fa" ] || [ ! -f "$fb" ]; then
    printf '%-30s ABSENT on %s\n' "$t" \
      "$([ -f "$fa" ] || echo A)$([ -f "$fb" ] || echo B)"
    nmiss=$((nmiss+1)); continue
  fi
  d=$(diff "$fa" "$fb" | grep -c '^[<>]')
  if [ "$d" = 0 ]; then
    printf '%-30s IDENTICAL  (%s lines)\n' "$t" "$(wc -l < "$fa")"
    nsame=$((nsame+1))
  else
    printf '%-30s %s differing lines of %s:\n' "$t" "$d" "$(wc -l < "$fa")"
    diff "$fa" "$fb" | grep '^[<>]' | sed 's/^/    /'
    ndiff=$((ndiff+1))
  fi
done
echo "-- identical $nsame, differing $ndiff, absent $nmiss, of $#"
