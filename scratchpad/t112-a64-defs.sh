#!/bin/sh
# Show, for each of the 12, the aarch64 definition text and the i386 one (if
# any).  Both-sided by construction: the point is that aarch64 HAS an answer
# and i386 has none, so shared code compiled against i386 emits no code.
set -u
G=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa0b6da0fbac13315/gcc
A=${A:-/tmp/t112-armD2}
[ -s "$A/a64-silent-confirmed.txt" ] || { echo "FATAL: run t112-a64.sh"; exit 9; }
while read -r m; do
  echo "=== $m"
  echo "  aarch64:"
  grep -rn "^[ \t]*#[ \t]*define[ \t][ \t]*$m\b" "$G"/config/aarch64/*.h | sed 's/^/    /'
  echo "  i386:"
  grep -rn "^[ \t]*#[ \t]*define[ \t][ \t]*$m\b" "$G"/config/i386/*.h | sed 's/^/    /'
  echo "  shared-header floor (defaults.h etc):"
  grep -rn "^[ \t]*#[ \t]*define[ \t][ \t]*$m\b" "$G"/*.h | sed 's/^/    /'
done < "$A/a64-silent-confirmed.txt"
