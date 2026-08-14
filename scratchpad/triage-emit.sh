#!/bin/sh
# Is #170's measurement commit in HEAD, and are its named C1 slots still empty?
set -u
cd "$(dirname "$0")/.." || exit 1
for s in 8e87bbadcc8 a697b5bfd5294f5e8; do
  git cat-file -e "${s}^{commit}" 2>/dev/null || { echo "not a commit here: $s"; continue; }
  git merge-base --is-ancestor "$s" HEAD 2>/dev/null && echo "IN-HEAD $s" || echo "NOT-ANCESTOR $s"
done
echo "--- C1 named entry points, current tree ---"
for f in insn_has_dfa_reservation_p state_transition optimize_mode_switching; do
  printf '%s: %s hits\n' "$f" "$(grep -rl "$f" gcc --include=*.cc --include=*.h --include=*.in 2>/dev/null | wc -l)"
done
echo "--- is OPTIMIZE_MODE_SWITCHING gated per base yet? ---"
grep -rn 'OPTIMIZE_MODE_SWITCHING' gcc/mode-switching.cc gcc/defaults.h gcc/multi-target-macros.h 2>/dev/null | head
