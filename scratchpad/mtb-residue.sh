#!/bin/sh
# GROUP A `make -k all-gcc' LOG BY CAUSE, AND ATTRIBUTE FAILURES THE ONLY WAY
# THAT IS VALID UNDER -j.
#
# Two things this deliberately does NOT do:
#
#  * It does not attribute a diagnostic to a back end by the nearest preceding
#    compile line.  Under `-j8' the i386 compile command is followed by
#    visium's errors, from a different job.  That method produced a plausible
#    and WRONG per-CPU table on this branch already.  Back-end attribution
#    comes only from make's own `*** [<target>] Error' lines, whose target
#    path names the back end.
#
#  * It does not treat silence as success.  Under `-k' an object whose
#    prerequisite died is never attempted, and that reads exactly like a pass;
#    the filesystem is read as a second, independent instrument.
#
# usage: mtb-residue.sh <logfile> [builddir] [cpu-list-file]
set -u
LOG=${1:?log}
D=${2:-}
BE=${3:-}
[ -s "$LOG" ] || { echo "FATAL: $LOG empty or missing"; exit 9; }

tot=$(grep -c 'error:' "$LOG")
echo "total 'error:' lines: $tot"
echo
echo "== diagnostics by message shape (over-broad on purpose; an upper bound)"
grep 'error:' "$LOG" \
  | sed 's/.*error: //' \
  | sed "s/'[^']*'/'X'/g; s/\"[^\"]*\"/\"X\"/g; s/[0-9][0-9]*/N/g" \
  | sort | uniq -c | sort -rn | head -40
echo
echo "== undeclared-identifier names, with the object count each appears in"
grep -oE "error: '[A-Za-z_][A-Za-z0-9_]*' (was not declared|has not been declared|undeclared)" "$LOG" \
  | grep -oE "'[A-Za-z_][A-Za-z0-9_]*'" | tr -d "'" | sort | uniq -c | sort -rn
echo
echo "== source files carrying the diagnostics (file, not back end)"
grep 'error:' "$LOG" | sed 's/:[0-9].*//' | sed 's|.*/gcc/||' | sort | uniq -c | sort -rn | head -25
echo
echo "== FAILING TARGETS, from make's own lines (the only valid attribution)"
grep -E '^make(\[[0-9]+\])?: \*\*\* \[' "$LOG" \
  | sed 's/.*\[//; s/\] Error.*//; s/.*: //' | sort -u > /tmp/mtb-failtargets.$$
wc -l < /tmp/mtb-failtargets.$$ | sed 's/^/failing targets: /'
sed 's/mt-[a-z0-9_]*\///; s/-[a-z0-9_]*\.o$/.o/' /tmp/mtb-failtargets.$$ \
  | sort | uniq -c | sort -rn
echo
echo "-- per back end (from those target paths only)"
# The back end is matched against a KNOWN LIST, never scraped with a trailing
# `-\([a-z0-9]*\)\.o' pattern: `insn-recog-avr-3.o' ends in `-3', and a
# scraping version of this reported back ends named "3", "8" and "10".  A
# plausible-looking table of nonexistent back ends is worse than no table.
if [ -n "$BE" ] && [ -s "$BE" ]; then
  for b in $(grep -v '^#' "$BE" | grep .); do
    c=$(grep -c -e "mt-$b/" -e "-$b\.o" -e "-$b-[0-9]*\.o" /tmp/mtb-failtargets.$$)
    [ "$c" = 0 ] || printf '%7s %s\n' "$c" "$b"
  done | sort -rn
else
  echo "   (no cpu list given -- refusing to guess back-end names from target paths)"
fi
if [ -n "$D" ]; then
  echo
  echo "== FILESYSTEM ARM: does each failing target exist on disk?"
  ex=0; miss=0
  while read -r t; do
    if [ -e "$D/gcc/$t" ]; then ex=$((ex+1)); else miss=$((miss+1)); fi
  done < /tmp/mtb-failtargets.$$
  echo "of the failing targets: $ex exist on disk, $miss absent"
fi
rm -f /tmp/mtb-failtargets.$$
