#!/bin/sh
# built-tree-audit.sh -- WHICH TREE DID EACH BUILD ACTUALLY USE?
#
# Written to answer the question `conf-audit.sh' cannot: that one scores the
# SCRIPTS as they stand today; this one scores the BUILDS that already
# happened.  After the FOREIGN-SRC finding (PRINCIPLES section 4) the live
# question was not "are the scripts fixed" but "which previously-reported
# greens were produced by a broken script, and therefore prove nothing?"
#
# THE INSTRUMENT IS INDEPENDENT OF THE SCRIPTS.  It reads each build dir's own
# `config.log', which records the absolute srcdir configure was invoked from.
# That is the build's own testimony about what it compiled; it does not depend
# on reading, trusting, or re-running any guard script, and it survives the
# script being edited afterwards -- which is exactly the case here, since the
# scripts were repaired after the builds were done.
#
# WHAT IT ESTABLISHED (2026-08-13):
#   95 config.logs read.  EVERY build dir was configured from the worktree of
#   the agent that OWNED that task number, at that task's own timestamp, and
#   the anchor is monotonic over time (23 -> 27 -> 28 -> 30 -> 37 -> 39).
#   So the hardcoded `SRC=' lines were HARDCODED-SELF WHEN WRITTEN, not
#   foreign: each author hardcoded its OWN absolute path.  They became foreign
#   only by being committed and inherited -- 485 inherited copies across ~50
#   worktrees against 21 authored ones.  The risk was real and large; it was
#   never fired.
#
# BLIND SPOTS, stated because a clean result from an unexamined instrument is
# worth very little:
#   * It can only see build dirs that STILL EXIST.  A build that was made,
#     measured and deleted leaves nothing.  Cross-check: every task number
#     appearing in STATE.md (45,77,78,92,106,107,108,111,112,113,116,117,119,
#     122-135) has a surviving build dir, so the gap is empty FOR THOSE.
#   * `config.log' records the LAST configure, not every one.
#   * Rows whose srcdir ends in `/gcc' are gcc-level configures; the anchor
#     path built here does not exist for them and prints GONE.  That is this
#     script's path construction, NOT a missing tree -- the agent id still
#     resolves.  Do not read GONE as a defect.
set -u

n=0; nowt=0
for d in /tmp/b*; do
  [ -d "$d" ] || continue
  L="$d/config.log"
  [ -f "$L" ] || continue
  n=$((n + 1))
  src=$(grep -m1 -oE '/[^ ]*/configure' "$L")
  case "$src" in
    "") printf '%-22s NO-SRCDIR-IN-LOG\n' "$(basename "$d")"; continue ;;
  esac
  wt=$(echo "$src" | grep -oE 'agent-[0-9a-f]+')
  if [ -z "$wt" ]; then
    wt="(not-a-worktree)"; nowt=$((nowt + 1))
  fi
  root=${src%/configure}
  if [ -f "$root/gcc/Makefile.in" ]; then
    a=$(grep -c MULTI_TARGET "$root/gcc/Makefile.in")
  else
    a=GONE
  fi
  when=$(stat -c %y "$L" 2>/dev/null | cut -c1-16)
  printf '%-22s %-26s anchor=%-5s %s\n' "$(basename "$d")" "$wt" "$a" "$when"
done

echo "---"
echo "config.logs read : $n"
echo "non-worktree src : $nowt   (/tmp clones: stock, diag, verify -- expected)"

# NON-VACUITY.  With no config.log found every line above is absent and the
# script exits 0 having proved nothing -- the all-empty read that PRINCIPLES
# section 7 says is indistinguishable from the hypothesis.
if [ "$n" -lt 20 ]; then
  echo "FATAL: only $n config.log found (expected >= 20)."
  echo "FATAL: the matcher is broken, not the corpus.  Refusing to score."
  exit 9
fi
exit 0
