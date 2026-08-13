#!/bin/sh
# Configure a build dir with an ARBITRARY target list, for the "how many back
# ends can be configured and built" census.
#
# Derived from t139-conf.sh / t140-conf.sh.  Two deliberate differences:
#
#  * the list is an argument, because the whole point is to vary it;
#  * ONLY --enable-targets is passed.  --enable-backends is NOT passed.
#
# That second point is the arm.  Before this task the top level accepted
# --enable-targets, never mapped it to --enable-backends for gcc/, and a cold
# build died in the gcc/ subdirectory with
#
#     configure: error: --enable-backends=LIST is required
#
# Every existing build dir worked around it by passing --enable-backends to
# the top level by hand, where autoconf's auto-accept of unrecognised
# --enable-* carried it down through HOST_CONFIGARGS.  This script deliberately
# does NOT do that, so that a regression in the mapping fails here rather than
# being masked by the workaround.  Its negative control is
# mtN-conf-nomap-ctl.sh.
#
# SRC is derived from $0 (this script's own tree) and the MULTI_TARGET anchor
# is asserted, per PRINCIPLES section 4.
#
# usage: mtN-conf.sh <builddir> <comma-separated-triples | file-of-triples>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
LIST=${2:?comma-separated triple list, or a file with one triple per line}
if [ -f "$LIST" ]; then
  LIST=$(grep -v '^#' "$LIST" | grep . | tr '\n' ',' | sed 's/,$//')
fi
[ -n "$LIST" ] || { echo "FATAL: empty triple list"; exit 9; }
# 45, not the 43 this branch recorded: the MULTI_TARGET_GEN_HDRS dependency
# added to the s-options-h rule and its comment add two hits.  An EXACT value
# is asserted, not a `>=', so that a tree missing the change fails here rather
# than building and reporting a green for a compiler that is not this one.
WANT=${WANT_ANCHOR:-45}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
grep -q 'gcc_backends_arg' "$SRC/configure" \
  || { echo "FATAL: $SRC/configure has no gcc_backends_arg mapping"; exit 9; }
case "$D" in
  */b-a8666b938c097bb2f*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
echo "srcdir $SRC anchor=$n OK; list=$LIST"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=$LIST \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto"
