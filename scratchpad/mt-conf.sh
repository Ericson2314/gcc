#!/bin/sh
# mt-conf.sh -- configure a build dir with a chosen base set.
#
# THE SURVIVOR OF 63 `*-conf.sh'.  They are one script; what forced the copies
# was the hardcoded per-worktree build-dir case and the hardcoded WANT_ANCHOR
# default (see mt-lib.sh).  Both are now derived or required from the caller,
# so this file needs no edit to serve the next task and carries no task number
# to collide on.
#
# WANT_ANCHOR is REQUIRED and asserted EXACTLY.  Do not relax it to `>=': the
# whole point is that a tree missing a landed change fails here rather than
# reporting a green for a compiler that is not this one.  The value moves in
# both directions; run the grep on the tree you are about to build.
#
# SRC may be an immutable `git archive' snapshot (SNAP-SHA, read-only) or a
# live git worktree; mt_assert_src_frozen dispatches on which.
#
# usage: SRC=<srcdir> WANT_ANCHOR=<n> mt-conf.sh <builddir> <comma-separated-triples>
#   MT_CONFIGURE_FLAGS   extra flags appended to configure
#   MT_HDR               --with-native-system-header-dir (has a default)
set -eu
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

SRC=${SRC:?set SRC to the srcdir (snapshot or worktree)}
SRC=$(cd "$SRC" && pwd)
D=${1:?build dir}
LIST=${2:?comma-separated triple list}
mt_assert_builddir "$D"

n=$(mt_assert_anchor "$SRC") || exit 9
kind=$(mt_assert_src_frozen "$SRC") || exit 9
# `--enable-targets' selects which back ends go INTO the binary (a host-side
# property of the artefact).  Assert the mapping exists rather than discover
# its absence as a mysterious single-base build.
grep -q 'gcc_backends_arg' "$SRC/configure" \
  || mt_die "$SRC/configure has no gcc_backends_arg mapping"
echo "srcdir $SRC anchor=$n $kind; list=$LIST"

HDR=${MT_HDR:-/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include}
rm -rf "$D"; mkdir -p "$D"
set +e
mt_shell "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=$LIST \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=$HDR \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto ${MT_CONFIGURE_FLAGS:-}" > "$D/conf.out" 2> "$D/conf.err"
rc=$?
set -e
echo "$rc" > "$D/conf.rc"
echo "configure rc=$rc"
[ "$rc" = 0 ] || { tail -20 "$D/conf.err"; exit "$rc"; }
# config.log's own record of the srcdir configure ran from -- the instrument
# that is independent of this script by construction, and the one that settled
# the 506-hardcoded-SRC question.  Stamped here, re-read by every later script.
grep -m1 'running configure' "$D/config.log" || true
echo "$SRC" > "$D/MY-SRC"
mt_assert_configured_from "$D" "$SRC"
tail -3 "$D/conf.err"
