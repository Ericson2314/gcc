#!/bin/sh
# STOCK CONTROL, part B -- configure a PLAIN CROSS from the stock snapshot.
#
# usage: SRC=<stock snapshot> sc-conf.sh <builddir> <target-triple> <hdrdir>
#
# `--target' IS THE ONE LEGITIMATE USE.  The user's standing rule is to avoid
# it; the stated exception is the TOP LEVEL, which is the target dispatcher.
# This is a top-level configure of a cross compiler, which is precisely that
# case, and it is also the only way to obtain the control at all: the whole
# point of the control is that stock GCC has no --enable-backends.
#
# CONFIGURATION DIFFERENCES AGAINST THE MULTI-TARGET BOARD, ALL FORCED, ALL
# RECORDED (`scratchpad/taa-conf.sh' is the other side):
#
#   * --target=<T> vs --enable-targets=<list>.  Not a choice; it is the
#     difference being measured.
#   * --disable-multilib.  The branch deleted both multilib flags (multilib is
#     mandatory there).  Stock aarch64-linux has an empty multilib list anyway,
#     and `make all-gcc' builds no target library either way, so this cannot
#     move a compile-only test result.  Stated rather than hidden.
#   * --with-native-system-header-dir=<the TARGET's own glibc headers>, the
#     same store path taa-tools.sh hands the multi-target run for this target.
#     Same headers on both sides is the point; a host header dir here would
#     make every #include a different experiment.
#   * --with-sysroot is NOT passed on either side, so the header dir above is
#     used literally.
#
# Same on both sides: --enable-languages=c,lto, --disable-bootstrap,
# --disable-nls, --disable-werror, the same CC/CFLAGS, the same nix shell,
# `make all-gcc' only, and therefore the same absence of any target libgcc.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC to the stock snapshot}
SRC=$(cd "$SRC" && pwd)
D=${1:?build dir}
T=${2:?target triple}
HDR=${3:?target header dir}

# ANTI-ANCHOR: the control must be measuring UPSTREAM.  Exact, and inverted.
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = 0 ] || { echo "FATAL: $SRC anchor=$n, expected 0 -- that is not stock"; exit 9; }
[ -f "$SRC/STOCK-SHA" ] || { echo "FATAL: $SRC is not an sc-snap.sh snapshot"; exit 9; }
[ ! -w "$SRC/gcc/Makefile.in" ] || { echo "FATAL: $SRC is writable; the snapshot must be read-only"; exit 9; }
# The graft must be present, or MT_COMPILE_ONLY is inert on this side and the
# board picks up a link-FAIL floor the other side does not have.  This is G5,
# asserted at configure time as well as after the run.
[ -f "$SRC/gcc/testsuite/lib/multi-target.exp" ] \
  || { echo "FATAL: $SRC has no multi-target.exp; compile-only would be inert"; exit 9; }
grep -q '^load_lib multi-target.exp$' "$SRC/gcc/testsuite/lib/gcc-dg.exp" \
  || { echo "FATAL: $SRC/gcc/testsuite/lib/gcc-dg.exp does not load multi-target.exp"; exit 9; }
[ -d "$HDR" ] || { echo "FATAL: no target header dir $HDR"; exit 9; }
case "$D" in
  */b-stock-agent-a3464debf6893de84*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
echo "stock srcdir $SRC sha=$(cat "$SRC/STOCK-SHA") anchor=$n; target=$T"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && PATH=/tmp/tools-agent-a3464debf6893de84/bin:\$PATH $SRC/configure \
  --target=$T \
  --disable-werror \
  --disable-bootstrap --disable-nls --disable-multilib \
  --with-native-system-header-dir=$HDR \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
rc=$?
echo "configure rc=$rc"
[ -f "$D/Makefile" ] || { echo "FATAL: no Makefile"; tail -20 "$D/conf.err"; exit 9; }
echo "$SRC" > "$D/MY-SRC"
tail -3 "$D/conf.err" || true
