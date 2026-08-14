#!/bin/sh
# #171 -- build in a t171-conf.sh build dir.  $1 = build dir, $2 = make target.
# Derived from t165-build.sh.  Re-asserts the snapshot at EVERY build, and
# writes the `.rc' STAMP only after make returns (PRINCIPLES 4: a log being
# written looks exactly like a log that finished).
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
T=${2:-cc1}
case "$D" in
  */b-a0e5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/MY-SRC" ] || { echo "FATAL: $D has no MY-SRC"; exit 9; }
SRC=$(cat "$D/MY-SRC")
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D/config.log does not name $SRC"; exit 9; }
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:-50}" ] || { echo "FATAL: $SRC anchor=$n"; exit 9; }
( cd "$SRC" && git diff --quiet ) || { echo "FATAL: $SRC changed under the build"; exit 9; }
SHA=$(cd "$SRC" && git rev-parse --short HEAD)

J=${MT_JOBS:-8}
rm -f "$D/make-$T.rc"
echo "load before build: $(uptime | sed 's/.*load average/load average/')  (-j$J)"
if [ -d "$D/gcc" ]; then
  sh "$S/eb-shell.sh" "cd $D/gcc && make -k -j$J $T" \
    > "$D/make-$T.out" 2> "$D/make-$T.err"
else
  sh "$S/eb-shell.sh" "cd $D && make -k -j$J all-gcc" \
    > "$D/make-$T.out" 2> "$D/make-$T.err"
fi
rc=$?
# THE STAMP.  After make returned, and only then.
echo "$rc" > "$D/make-$T.rc"
echo "make $T rc=$rc  (srcdir $SRC at $SHA)"
echo "stderr lines: $(wc -l < "$D/make-$T.err")"
echo "error: lines: $(grep -c 'error:' "$D/make-$T.err" || true)"
echo "multiple definition: $(grep -c 'multiple definition' "$D/make-$T.err" || true)"
echo "undefined reference: $(grep -c 'undefined reference' "$D/make-$T.err" || true)"
