#!/bin/sh
# mt-build.sh -- run make in a build dir configured by mt-conf.sh, and STAMP.
#
# THE SURVIVOR OF 54 `*-build.sh' AND 6 `*-topbuild.sh'.  Three things it
# carries that most of them did not:
#
#   * IT ALWAYS RUNS `make' IN $D, NEVER IN $D/gcc.  Nearly every
#     t<NNN>-build.sh had `if [ -d $D/gcc ]; then cd $D/gcc; fi', and that test
#     IS WRONG AND IT COST A BUILD: `configure-gcc' having been run for some
#     other reason makes the directory exist before anything in it does, so the
#     top level is skipped, libiberty.a/libcpp.a/libdecnumber.a/libbacktrace.a
#     are never built, and the link fails with `No rule to make target
#     ../libcpp/libcpp.a' -- which reads as a broken tree.  Pass the make
#     target you want (`all-gcc', `cc1', ...); the directory is not guessed.
#
#   * THE SRCDIR ASSERTIONS, all four: MY-SRC exists, config.log NAMES it, the
#     anchor matches EXACTLY, and the tree is frozen.  23 `t<NNN>-build.sh'
#     scripts had SRC= hardcoded to a tree with a DIFFERENT anchor (23, 27, 28
#     or 39 against 39): they configure, build and pass, against a compiler
#     missing eleven landed changes, with no diagnostic anywhere.
#
#   * THE `.rc' STAMP, written only after make RETURNS, and cleared BEFORE the
#     run.  An `.rc' left by an earlier invocation is indistinguishable from
#     this one's -- measured live: a scorer read a finished-looking stamp
#     beside a still-running build and printed the previous run's numbers.
#
#   * KILLED COUNTING.  An OOM-killed job is not a build failure and not a
#     pass; it is contamination, and it is printed rather than netted out.
#
# usage: WANT_ANCHOR=<n> mt-build.sh <builddir> <tag> <make-target...>
#   MT_JOBS   -j (default 8)
#   MT_MAKE   extra make flags (e.g. -k)
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

D=${1:?build dir}; shift
TAG=${1:?tag (names the .log/.err/.rc triple)}; shift
[ $# -ge 1 ] || mt_die "name at least one make target"
mt_assert_builddir "$D"
SRC=$(mt_src_of "$D") || exit 9
mt_assert_configured_from "$D" "$SRC"
n=$(mt_assert_anchor "$SRC") || exit 9
kind=$(mt_assert_src_frozen "$SRC") || exit 9
J=${MT_JOBS:-8}

rm -f "$D/$TAG.rc"
mt_shell "cd $D && make ${MT_MAKE:-} -j$J $*" > "$D/$TAG.log" 2> "$D/$TAG.err"
rc=$?
echo "$rc" > "$D/$TAG.rc"
echo "$TAG rc=$rc  (srcdir $SRC $kind anchor=$n)"
echo "  stderr lines:         $(wc -l < "$D/$TAG.err")"
echo "  error: lines:         $(grep -c 'error:' "$D/$TAG.err" || true)"
echo "  multiple definition:  $(grep -c 'multiple definition' "$D/$TAG.err" || true)"
echo "  undefined reference:  $(grep -c 'undefined reference' "$D/$TAG.err" || true)"
echo "  Killed / signal 9:    $(grep -c 'Killed\|signal 9' "$D/$TAG.err" || true)  <- contamination, NOT a result"
tail -5 "$D/$TAG.err"
exit "$rc"
