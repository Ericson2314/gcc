#!/bin/sh
# TOP-LEVEL `all-gcc' from an immutable snapshot, with an exit stamp.
#
# TOP LEVEL, not `make cc1' in $D/gcc: that test ("does $D/gcc exist") is wrong
# on every t<NNN>-build.sh on this branch and costs a build -- libcpp.a is never
# made and the link fails with `No rule to make target ../libcpp/libcpp.a',
# which reads as a broken tree.
#
# `<tag>.rc' IS WRITTEN ONLY AFTER make RETURNS.  A log being written looks
# exactly like a log that finished, and an agent has already withdrawn two
# figures read from mid-build logs.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
case "$D" in
  */b-agent-ab1fcb485731b7a4d*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/MY-SRC" ] || { echo "FATAL: $D has no MY-SRC"; exit 9; }
SRC=$(cat "$D/MY-SRC")
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D/config.log does not name $SRC"; exit 9; }
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:-49}" ] || { echo "FATAL: $SRC anchor=$n"; exit 9; }
( cd "$SRC" && git diff --quiet ) || { echo "FATAL: $SRC changed under the build"; exit 9; }
SHA=$(cd "$SRC" && git rev-parse --short HEAD)
J=${MT_JOBS:-4}
rm -f "$D/make-top.rc"
# detect_leaks=0 IS NOT A WEAKENED CHECK, IT IS THE ONLY WAY THIS BUILD RUNS.
# GCC's generators (genhooks, genmodes, gengtype, ...) leak by design -- they
# exit without freeing -- so LeakSanitizer makes every one of them exit 23 and
# `s-target-hooks-def-h', `rs6000-builtins.cc' and `modes-union.list' all fail.
# We are hunting an out-of-bounds write, which is ASAN's other half and stays on.
sh "$S/eb-shell.sh" "cd $D && ASAN_OPTIONS=detect_leaks=0 make -k -j$J all-gcc" \
  > "$D/make-top.out" 2> "$D/make-top.err"
rc=$?
echo "$rc" > "$D/make-top.rc"
echo "make all-gcc rc=$rc  (srcdir $SRC at $SHA anchor=$n flags $(cat "$D/MY-FLAGS"))"
echo "stderr lines: $(wc -l < "$D/make-top.err")"
echo "error: lines: $(grep -c 'error:' "$D/make-top.err" || true)"
echo "multiple definition: $(grep -c 'multiple definition' "$D/make-top.err" || true)"
echo "undefined reference: $(grep -c 'undefined reference' "$D/make-top.err" || true)"
ls -l "$D/gcc/cc1" 2>&1
