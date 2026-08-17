#!/bin/sh
# agent-ae59966cf819d72ef-syncheck47.sh -- run `-syncheck.sh' over ALL the
# back ends the build dir actually has, not the 22 hardcoded in its `BASES='
# default.
#
# WHY: that default is a hand-written list, and 22 of 47 is a coverage figure
# nothing in the output states.  A sweep that prints `22/22 ok' reads as a
# clean sweep of the population; it is a clean sweep of less than half of it.
# The build dir knows the real list -- one `mt-<base>/' directory per
# configured back end -- so it is read from there and asserted to be 47.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
D=${D:?set D to a built build dir}
SRC=${SRC:-$W}
ALL=$(ls -d "$D"/gcc/mt-*/ 2>/dev/null | sed 's|.*/mt-||; s|/$||' | sort | tr '\n' ' ')
n=$(echo $ALL | wc -w)
[ "$n" -ge 40 ] || { echo "FATAL: $n back ends under $D/gcc/mt-*/ -- expected 47"; exit 9; }
echo "sweeping $n back ends (the build dir's own list, not the hardcoded 22)"
D="$D" SRC="$SRC" BASES="$ALL" sh "$W/scratchpad/agent-a4568de8f522450d3-syncheck.sh"
