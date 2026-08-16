#!/bin/sh
# Re-derive KILLED and the SCORING-TIME load from each target's own
# `check-<be>.out', because the scorer's own two arms are both wrong.
#
# DEFECT 1 -- KILLED IS A CONSTANT 1 AND MEANS NOTHING.
# `agent-acda89931a903ec27-score.sh:107' counts kills with
#
#     k=$(grep -ci 'killed\|Killed' "$OUT/check-$be.out")
#
# and `mtcheck.sh' prints a SECTION LABEL reading
#
#     == KILLED (compiler killed, NOT a test result -- machine contamination)
#       aarch64-unknown-linux-gnu    0
#
# so the grep matches the label on every target and the column reads 1
# whether or not anything was killed.  This is the test-harness-floor shape
# PRINCIPLES refuses, arriving by accident rather than by edit: **a constant in
# a column deletes the signal rather than offsetting it.**  A target that
# really killed three compilers would also read 1.  The real count is the
# NUMBER on the following line.
#
# DEFECT 2 -- THE PROVISIONAL GATE READS THE 15-MINUTE LOAD.
# score.sh records `cut -d' ' -f3 /proc/loadavg' (the 15-minute average) and
# marks a row PROVISIONAL above 25.  aarch64 scored with a 1-minute load of
# **43.22** and a 15-minute load of 18.53, so it was NOT marked -- while the
# machine was in fact more than twice as loaded as the threshold.  The
# 15-minute average is the wrong instrument for a run that takes minutes: it is
# still reporting the quiet period before the run started.  Both figures are
# printed here and the gate is applied to the 1-minute one.
set -u
OUT=${OUT:?dir holding check-<be>.out and rows.txt}
ROWS="$OUT/rows.txt"
[ -f "$ROWS" ] || { echo "FATAL: no $ROWS"; exit 9; }

printf '%-12s %-30s %-16s %7s %7s %7s %7s %s\n' \
  BACKEND TRIPLE VERDICT PASS FAIL KILLED LOAD1 NOTE
tot=0; totk=0
while read -r be tr verdict pass fail l15 k rest; do
  case "$be" in '#'*) continue ;; esac
  f="$OUT/check-$be.out"
  rk=-; l1=-
  if [ -f "$f" ]; then
    # the number on the line AFTER the KILLED label, not the label itself
    rk=$(awk '/^== KILLED/{getline; print $2; exit}' "$f")
    [ -n "$rk" ] || rk=0
    l1=$(sed -n 's/.*load at scoring time: load average: \([0-9.]*\),.*/\1/p' "$f" | head -1)
    [ -n "$l1" ] || l1=-
  fi
  note="$rest"
  case "$l1" in
    -) ;;
    *) awk -v l="$l1" 'BEGIN{exit !(l>25)}' && note="PROVISIONAL(load1=$l1) $rest" ;;
  esac
  printf '%-12s %-30s %-16s %7s %7s %7s %7s %s\n' \
    "$be" "$tr" "$verdict" "$pass" "$fail" "$rk" "$l1" "$note"
  tot=$((tot+1))
  case "$rk" in ''|-|*[!0-9]*) ;; *) totk=$((totk+rk)) ;; esac
done < "$ROWS"
echo
echo "rows=$tot  TOTAL REAL KILLED=$totk   (never subtracted from any PASS/FAIL)"
