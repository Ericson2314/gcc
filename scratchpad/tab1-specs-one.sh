#!/bin/sh
# One target's target-specs probe, against a named tool directory.
# usage: tab1-specs-one.sh <builddir> <canonical-triple> [toolsdir]
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; T=${2:?triple}
case "$D" in
  */b-agent-ab1fcb485731b7a4d*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
BIN=${3:-/tmp/tools-a76e99/$T}
[ -x "$BIN/as" ] || { echo "FATAL: no as at $BIN"; exit 9; }
mkdir -p "$D/tab1-specs"
sh "$S/eb-shell.sh" "cd $D && ASAN_OPTIONS=detect_leaks=0 \
  make configure-target-specs-$T TOOLS_DIR_FOR_$T=$BIN" \
  > "$D/tab1-specs/$T.out" 2>&1
echo "rc=$?"
f=$(ls "$D"/lib/gcc/*/"$T"/specs-config 2>/dev/null | head -1)
if [ -n "$f" ]; then
  echo "  $T: wc -l $(wc -l < "$f")  grep -c . $(grep -c . "$f")  md5 $(md5sum < "$f" | cut -c1-12)"
else
  echo "  $T: ABSENT"
fi
