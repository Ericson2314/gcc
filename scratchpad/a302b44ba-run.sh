#!/bin/sh
# a302b44ba-run.sh -- configure one tree with one --enable-targets list, top
# level then gcc/, and stop.
#
# CONFIGURE-ONLY IS THE RIGHT INSTRUMENT FOR "THE DELETED FILE WAS DEAD".
# Everything the deletion could possibly move is written by `gcc/configure' and
# `gen-target-manifest.sh': multi-target.manifest, multi-target-common.mk, the
# two generated registry headers, auto-host.h and gcc/Makefile.  A build is
# downstream of all of them, so byte-identity of that set is the stronger
# statement AND -- unlike a green build -- it names WHICH file moved when one
# does.  Compare two build dirs with
#
#   diff <(sed 's|src-base|SRC|g' A/gcc/Makefile) <(sed 's|src-new|SRC|g' B/gcc/Makefile)
#
# NORMALISE THE SRCDIR PATH BEFORE CONCLUDING ANYTHING.  Two snapshots live at
# different paths, so gcc/Makefile differs on 30 lines that are entirely that
# path.  Diffing raw reads as "the deletion changed the Makefile", which is the
# false-red twin of the false-greens this branch keeps paying for.
#
# `make configure-gcc' RATHER THAN THE TOP-LEVEL configure ALONE.  The check
# being exercised lives in gcc/configure, and the top level does not run it --
# it only derives `--enable-backends' and hands it down.  A top-level configure
# that returns 0 says nothing at all about the target check, and reading it as
# a pass is the "absent artefact vs absent mechanism" trap.
#
# NOT run through mt-conf.sh, deliberately: this runs in the SHARED main
# worktree, whose path is not `.../worktrees/agent-<hash>', so mt_assert_builddir
# correctly refuses every build dir here.  That guard is NOT overridden with
# MT_TAG, and the bars that depend on it are not claimed.
#
# usage: a302b44ba-run.sh <comma-separated-targets> <tag> <srcdir>
set -eu
W=/home/jcericson/src/gnu/gcc/mt-a302b
HDR=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
LIST=$1
TAG=$2
SRC=$3
D=$W/b-$TAG
rm -rf "$D"; mkdir -p "$D"
cd "$D"
set +e
"$SRC"/configure --disable-werror --disable-bootstrap --disable-nls \
  --enable-targets="$LIST" \
  --with-native-system-header-dir="$HDR" \
  --enable-languages=c,lto \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  > conf.out 2> conf.err
rc=$?
echo "top-level configure rc=$rc"
[ "$rc" = 0 ] || { tail -20 conf.err; exit "$rc"; }
make configure-gcc > mkconf.out 2> mkconf.err
rc=$?
echo "configure-gcc rc=$rc"
[ "$rc" = 0 ] || tail -30 mkconf.err
exit "$rc"
