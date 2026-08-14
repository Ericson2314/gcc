#!/bin/sh
# #157 -- build in a t157-conf.sh build dir.  $1 = build dir, $2 = make target.
# Re-asserts, at EVERY build, the snapshot this dir was configured from and
# that the snapshot is still clean and still at the anchor: a second agent
# reconfiguring this path, or a snapshot that turned out to be a live tree,
# are both things this catches by name.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
T=${2:-cc1}
case "$D" in
  */b-af23dd9b01f75c197*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/MY-SRC" ] || { echo "FATAL: $D has no MY-SRC"; exit 9; }
SRC=$(cat "$D/MY-SRC")
grep -q "^ *\$ $SRC/configure" "$D/config.log" \
  || grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D/config.log does not name $SRC"; exit 9; }
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:-48}" ] || { echo "FATAL: $SRC anchor=$n"; exit 9; }
( cd "$SRC" && git diff --quiet ) || { echo "FATAL: $SRC changed under the build"; exit 9; }
# The snapshot is re-pointed between builds (one build dir, several commits),
# so the commit is printed with every reading.  A build dir path is not an
# attribution; a sha is.
SHA=$(cd "$SRC" && git rev-parse --short HEAD)

if [ -d "$D/gcc" ]; then
  sh "$S/eb-shell.sh" "cd $D/gcc && make -k -j8 $T" \
    > "$D/make-$T.out" 2> "$D/make-$T.err"
else
  sh "$S/eb-shell.sh" "cd $D && make -k -j8 all-gcc" \
    > "$D/make-$T.out" 2> "$D/make-$T.err"
fi
rc=$?
echo "make $T rc=$rc  (srcdir $SRC at $SHA)"
echo "stderr lines: $(wc -l < "$D/make-$T.err")"
echo "error: lines: $(grep -c 'error:' "$D/make-$T.err" || true)"
echo "multiple definition lines: $(grep -c 'multiple definition' "$D/make-$T.err" || true)"
echo "undefined reference lines: $(grep -c 'undefined reference' "$D/make-$T.err" || true)"
