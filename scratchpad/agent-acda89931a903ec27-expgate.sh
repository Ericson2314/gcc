#!/bin/sh
# Does each back end's TRIPLE match its own `<cpu>.exp' istarget gate?
#
# Every gcc.target/<cpu>/<cpu>.exp opens with
#     if ![istarget <pat>] then { return }
# and a triple that does not match makes the .exp return immediately: ZERO
# tests run, ZERO FAILs, and a `.sum' that looks exactly like a clean pass.
# That is this board's null-result shape arriving through the harness, so it
# is checked BEFORE the run rather than diagnosed afterwards from an empty
# board.
#
# Verified with a real glob match (`case'), not by eye.
set -u
S=$(cd "$(dirname "$0")" && pwd)
T=${1:-gcc/testsuite}
nok=0; nbad=0; nskip=0
while IFS=: read -r be trip ex; do
  [ -n "$ex" ] || { nskip=$((nskip+1)); continue; }
  d=$(echo "$ex" | sed 's/\.exp$//')
  # the directory is not always the exp stem (tic6x.exp lives in tic6x/)
  f=$(find "$T/gcc.target" -maxdepth 2 -name "$ex" | head -1)
  [ -n "$f" ] || { printf '%-12s %-30s NO-EXP-FILE %s\n' "$be" "$trip" "$ex"; nbad=$((nbad+1)); continue; }
  # EXTRACT EVERY istarget PATTERN, NOT ONE PER LINE.  The first version used
  # `sed -n "s/.*istarget \(...\).*/\1/p"', whose greedy `.*' keeps only the
  # LAST match on a line -- and the real gates are
  #     if { ![istarget m68k*-*-*]  && ![istarget fido*-*-*] }
  #     if { ![istarget powerpc*-*-*] && ![istarget rs6000-*-*] }
  # i.e. return only if NEITHER matches.  It therefore reported m68k and
  # rs6000 as MISMATCH when both match their first pattern, which would have
  # excluded the largest back end in the tree on an instrument bug.
  pats=$(grep -o 'istarget [^]}]*' "$f" | sed 's/istarget //' | tr -d '[]!' | head -8)
  [ -n "$pats" ] && ok=no || ok=nogate
  for p in $pats; do
    case "$trip" in
      $p) ok=yes; break ;;
    esac
  done
  case $ok in
    yes|nogate) printf '%-12s %-30s OK      %s\n' "$be" "$trip" "$(echo $pats)"; nok=$((nok+1)) ;;
    *) printf '%-12s %-30s MISMATCH gate=[%s] -- .exp would return, 0 tests, 0 FAILs\n' \
         "$be" "$trip" "$(echo $pats)"; nbad=$((nbad+1)) ;;
  esac
done < "$S/agent-acda89931a903ec27-backends.txt"
echo
echo "OK=$nok MISMATCH/MISSING=$nbad NO-EXP=$nskip"
