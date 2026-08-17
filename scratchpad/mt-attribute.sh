#!/bin/sh
# mt-attribute.sh -- split a `.sum''s FAILs into HARNESS and RESIDUAL.
#
# WHY THIS IS THE FIRST THING TO RUN ON A NEW FRONT END'S BOARD.  The C++
# board's 9,529 FAILs contained 1,176 test files failing on
# `fatal error: <hdr>: No such file' -- no libstdc++, because a multi-target
# build has no target libraries -- and the residual after attribution was ~450
# lines, not 9,529.  A raw FAIL total for a front end nobody has run before is
# a number about the harness at least as much as about the compiler, and
# quoting it as debt is how a front end acquires a reputation it has not
# earned.
#
# THE TWO HARNESS CAUSES ARE DIFFERENT AND ARE NOT SUMMED:
#
#   NO-TARGET   `xgcc: fatal error: no target selected'.  A DejaGnu path that
#               reached the driver WITHOUT `-ftarget-config='.  Not a compiler
#               defect -- the refusal is correct behaviour (PRINCIPLES 2a: "a
#               bare gcc failing by name when no target is selected is correct
#               behaviour, not a bug to fix").  It is a gap in the harness.
#   NO-RUNTIME  `fatal error: <header>: No such file'.  A target library that a
#               multi-target build does not have.
#
#   RESIDUAL    everything else.  This is the only column that is a claim about
#               the compiler, and it is the one to investigate.
#
# NON-VACUITY: the run refuses if the `.sum' has no `# of' summary block, which
# is what a truncated or foreign `.sum' looks like, and prints the counted
# total beside the summary's own so a disagreement is visible rather than
# reconciled by a story.
#
# usage: mt-attribute.sh <tool>.sum <tool>.log
set -u
SUM=${1:?sum file}
LOG=${2:?log file}
[ -f "$SUM" ] || { echo "FATAL: no $SUM"; exit 9; }
[ -f "$LOG" ] || { echo "FATAL: no $LOG"; exit 9; }
grep -q '^# of ' "$SUM" || { echo "FATAL: $SUM has no '# of' summary -- truncated or not a .sum"; exit 9; }

W=$(mktemp -d); trap 'rm -rf "$W"' 0
grep '^FAIL: ' "$SUM" > "$W/fail" || true
NF=$(wc -l < "$W/fail")
SUMF=$(sed -n 's/^# of unexpected failures[ \t]*//p' "$SUM")
echo "$SUM"
echo "  FAIL lines counted: $NF     .sum summary says: ${SUMF:-<none>}"
[ "$NF" = "${SUMF:-$NF}" ] || echo "  NOTE: the two disagree -- report both, do not pick one"

# ATTRIBUTION IS PER RESULT LINE, USING THE LOG BLOCK THAT PRODUCED IT.
#
# The first version of this script grepped for lines containing BOTH the test
# basename AND the error text.  They never co-occur -- DejaGnu writes the
# command on one line and the diagnostic on the next -- so NO-TARGET read 0 on
# a log holding 958 `no target selected' errors, and every failure landed in
# RESIDUAL, i.e. was attributed to the COMPILER.  That is the wrong direction
# to be wrong in: it manufactures compiler defects out of a harness gap.
#
# A DejaGnu log is blocks: the compiler invocation and its output, terminated
# by a `PASS:'/`FAIL:'/... line.  So accumulate, and classify each FAIL by what
# its OWN block said.
# THE BLOCK BOUNDARY IS `Executing on host:', NOT THE RESULT LINE.  The second
# version reset the buffer at every result line, so in a block where ONE failed
# compilation produces EIGHTY `FAIL: ... (test for warnings, line N)' lines --
# which is the normal shape for a `dg-warning'-heavy test -- only the first
# saw the diagnostic and the other seventy-nine were scored RESIDUAL, i.e.
# blamed on the compiler.  `objc.dg/class-protocol-1.m' alone contributed 80.
# Each FAIL is attributed to the most recent COMMAND, which is what produced
# it.
awk '
  /^(Executing on host:|spawn )/ { if ($0 ~ /^Executing on host:/) buf = $0; next }
  /^FAIL: / {
    if (buf ~ /no target selected/)              k = "NO-TARGET";
    else if (buf ~ /No such file or directory/)  k = "NO-RUNTIME";
    else                                         k = "RESIDUAL";
    line = $0; sub(/^FAIL: /, "", line);
    print k "\t" line; next;
  }
  { buf = buf "\n" $0 }
' "$LOG" > "$W/attr"

NA=$(wc -l < "$W/attr")
# NON-VACUITY: the block walker must have found the same FAILs the .sum has.
# A log whose blocks do not terminate the way this awk expects yields 0 here,
# which would read as "no failures to attribute".
[ "$NA" -gt 0 ] || { echo "  FATAL: the log block-walker attributed 0 FAILs; the .sum has $NF"; exit 9; }
echo "  attributed from the log: $NA (the .sum has $NF)"
[ "$NA" = "$NF" ] || echo "  NOTE: the two differ -- a .log and .sum from different runs, or"
[ "$NA" = "$NF" ] || echo "        parallel slot logs; report both rather than picking one"
for k in NO-TARGET NO-RUNTIME RESIDUAL; do
  n=$(awk -F'\t' -v k="$k" '$1 == k' "$W/attr" | wc -l)
  case $k in
    RESIDUAL) printf '    %-12s %s   <- the only column that is a claim about the compiler\n' "$k" "$n" ;;
    *)        printf '    %-12s %s\n' "$k" "$n" ;;
  esac
done
echo "  residual, by test file (top 25):"
awk -F'\t' '$1 == "RESIDUAL" {sub(/[ \t].*/, "", $2); print $2}' "$W/attr" \
  | sort | uniq -c | sort -rn | head -25 | sed 's/^/      /'
