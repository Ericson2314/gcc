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
#   * The TARGET's own glibc headers -- the same store path taa-tools.sh hands
#     the multi-target run, which reads it at run time out of specs-config as
#     `native_system_header_dir'.  Same headers on both sides is the point.
#
#     AND THE FIRST ATTEMPT AT THIS GOT IT WRONG IN A WAY THAT LOOKED LIKE A
#     RESULT.  `--with-native-system-header-dir=<dir>' ALONE is inert for a
#     cross: cppdefault.cc flags that entry `cross_include', so the driver
#     drops it, and the only directories left are the build dir's own
#     gcc/include and gcc/include-fixed.  GCC's own stdint.h is a
#     `#include_next' wrapper, so with no system directory behind it every
#     translation unit that includes <stdint.h> dies with
#
#         gcc/include/stdint.h:11:16: fatal error: stdint.h: No such file
#
#     -- 66,883 occurrences, the top cause of the whole stock run, and the
#     board it produced (84,572 PASS / 98,093 FAIL) was WITHIN 0.1% OF THE
#     MULTI-TARGET BOARD'S FAIL COLUMN.  Two unrelated missing-header floors
#     of similar size read as parity.  That is the shape this project keeps
#     finding: the control has to be checked for its OWN defects before its
#     agreement with the thing under test means anything.
#
#     The fix is to give the same directory through the sysroot, which is not
#     dropped for a cross: --with-sysroot=<store path> plus
#     --with-native-system-header-dir=/include, which resolves to exactly the
#     directory the multi-target side names.  Verified by -v: the search list
#     must contain that path.
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
# The sysroot is the parent of the header dir, and the header dir must be
# literally <sysroot>/include or the substitution below is a lie.
SYSROOT=${HDR%/include}
[ "$SYSROOT/include" = "$HDR" ] \
  || { echo "FATAL: header dir $HDR is not <something>/include; the sysroot form does not apply"; exit 9; }

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
  --with-sysroot=$SYSROOT \
  --with-native-system-header-dir=/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
rc=$?
echo "configure rc=$rc"
[ -f "$D/Makefile" ] || { echo "FATAL: no Makefile"; tail -20 "$D/conf.err"; exit 9; }
echo "$SRC" > "$D/MY-SRC"
echo "$HDR" > "$D/TARGET-HDR"	# sc-check.sh guard S3 reads this back
tail -3 "$D/conf.err" || true
