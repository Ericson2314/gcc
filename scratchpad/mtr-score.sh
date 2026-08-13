#!/bin/sh
# The score for the options.h vocabulary-leak task: `error:' totals, a
# per-cause histogram, and HOW MANY BACK ENDS each cause covers.
#
# Sibling of mtO-score.sh, with three differences that are the point:
#
#  * it attributes each diagnostic to a back end by the SOURCE PATH in the
#    diagnostic (config/<dir>/...), never by the nearest preceding compile
#    line -- PRINCIPLES section 1 says the latter is invalid under -j8, and
#    this build is -j8.
#  * it reports back ends per cause, not lines per cause.  A count is not a
#    population.
#  * NON-VACUITY RUNS FIRST and is FATAL: if the log is missing, or has no
#    compile lines at all, or the build dir was configured from another tree,
#    it refuses to score.  An empty grep reads exactly like `fixed'.
#
# usage: mtr-score.sh <builddir> <logfile>
set -eu
D=${1:?build dir}
LOG=${2:?log}

# --- non-vacuity, first -----------------------------------------------------
[ -d "$D/gcc" ] || { echo "FATAL: $D/gcc is not a directory"; exit 9; }
[ -s "$LOG" ]   || { echo "FATAL: $LOG is empty or missing"; exit 9; }
grep -q 'agent-ab86cbfa7618c4301' "$D/config.log" \
  || { echo "FATAL: $D/config.log does not name this worktree"; exit 9; }
ncc=$(grep -c ' -o mt-' "$LOG" || true)
[ "$ncc" -gt 0 ] \
  || { echo "FATAL: $LOG has no per-back-end compile lines; nothing was scored"; exit 9; }
echo "non-vacuity: $ncc per-back-end compile lines in $LOG, srcdir asserted"
echo

nerr=$(grep -c 'error:' "$LOG" || true)
echo "error: lines:  $nerr"
echo "log lines:     $(wc -l < "$LOG")"
echo

# --- objects per back end ---------------------------------------------------
nb=0; nd=0
for d in "$D"/gcc/mt-*/; do
  [ -d "$d" ] || continue
  nd=$((nd + 1))
  n=$(ls "$d"*.o 2>/dev/null | wc -l)
  [ "$n" -gt 0 ] && nb=$((nb + 1))
done
echo "mt-<cpu> directories:           $nd"
echo "back ends with at least one .o: $nb"
echo

# --- causes -----------------------------------------------------------------
# Each cause is a grep over the diagnostic text.  Reported as (lines, back
# ends), where the back end is read from the config/<dir>/ component of the
# path the diagnostic names.  `-' means the file is not under config/.
cause() {
  tag=$1; pat=$2
  n=$(grep -c -- "$pat" "$LOG" || true)
  b=$(grep -- "$pat" "$LOG" \
      | sed -n 's|.*/config/\([^/]*\)/.*|\1|p' | sort -u | tr '\n' ' ')
  [ -n "$b" ] || b='-'
  printf '%-34s lines %-5s back ends: %s\n' "$tag" "$n" "$b"
}

echo "=== causes"
cause "loop-enumerator (parse)"      "loop \*loop"
cause "arm_mve_loop_valid_for_dlstp" "arm_mve_loop_valid_for_dlstp"
cause "selected_arch"                "selected_arch"
cause "poly_int"                     "poly_int"
cause "gt-*.h missing"               "gt-"
echo

echo "=== error texts, most frequent first"
grep 'error:' "$LOG" | sed 's/.*error: //' | sort | uniq -c | sort -rn | head -30
echo

echo "=== back ends with at least one error:, by source path"
grep 'error:' "$LOG" | sed -n 's|.*/config/\([^/]*\)/.*|\1|p' | sort | uniq -c | sort -rn
echo "distinct back-end directories with an error: $(grep 'error:' "$LOG" | sed -n 's|.*/config/\([^/]*\)/.*|\1|p' | sort -u | wc -l)"
