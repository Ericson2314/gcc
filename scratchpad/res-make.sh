#!/bin/sh
# usage: res-make.sh <tag>   -- incremental `make -k -j8 all-gcc' in this
# task's build dir, capturing stdout/stderr to <builddir>/<tag>.{out,err}.
# Build dir is named for this worktree per PRINCIPLES section 5.
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=/tmp/b-af73bc3169a097677
TAG=${1:?tag}
# The build dir must have been configured from THIS tree (PRINCIPLES s5).
# NOTE: gcc/Makefile does not exist until the first make, so it is NOT the
# guard here; config.log is written by configure and is the right instrument.
[ -f "$D/config.log" ] || { echo "FATAL: $D/config.log missing"; exit 9; }
SRC=$(cd "$S/.." && pwd)
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D was not configured from $SRC"; exit 9; }
sh "$S/eb-shell.sh" "cd $D && make -k -j8 all-gcc" > "$D/$TAG.out" 2> "$D/$TAG.err"
echo "rc=$? tag=$TAG"
