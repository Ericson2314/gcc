#!/bin/sh
# The x86_64 target-specs probe -- the BOTH-SIDED CONTROL for the mips64 and
# ia64 readings.  x86_64 is recorded STABLE 5/5 on this input; if it is
# unstable in THIS build then the instability is a property of the ASAN build
# or of the machine, not of those two back ends.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
case "$D" in
  */b-agent-ab1fcb485731b7a4d*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
HOSTBIN=${2:-/tmp/tools-a76e99/x86_64-pc-linux-gnu}
HDRX=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
sh "$S/eb-shell.sh" "cd $D && ASAN_OPTIONS=detect_leaks=0 \
  make configure-target-specs-x86_64-pc-linux-gnu \
  TOOLS_DIR_FOR_x86_64-pc-linux-gnu=$HOSTBIN \
  TARGET_SPECS_FLAGS_FOR_x86_64-pc-linux-gnu='--with-native-system-header-dir=$HDRX'" \
  > "$D/tab1-specs/x86.out" 2>&1
echo "rc=$?"
f=$(ls "$D"/lib/gcc/*/x86_64-pc-linux-gnu/specs-config 2>/dev/null | head -1)
if [ -n "$f" ]; then
  echo "  x86_64: wc -l $(wc -l < "$f")  grep -c . $(grep -c . "$f")  md5 $(md5sum < "$f" | cut -c1-12)"
else
  echo "  x86_64: ABSENT"
fi
