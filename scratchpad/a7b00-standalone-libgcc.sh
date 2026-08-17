#!/bin/sh
# ACCEPTANCE ARM 1: configure and build libgcc for a CROSS target with
#   * --host=<the library's machine>, and NO --target;
#   * NO sibling gcc/ build directory anywhere above the build dir;
#   * an INSTALL PREFIX as the only thing pointing at a compiler.
#
# THE BUILD DIR IS DELIBERATELY NOWHERE NEAR THE gcc BUILD TREE.  libgcc's
# `gcc_objdir' is `../../<host_subdir>/gcc' -- a RELATIVE path -- so a build dir
# placed two levels under the old top level would find the sibling by accident
# and the whole arm would prove nothing while passing.  It is put under /tmp.
#
# usage: a7b00-standalone-libgcc.sh <builddir> <install-prefix> <triple> <tools-bin> [extra configure args]
set -u
D=${1:?build dir}; PFX=${2:?install prefix}; T=${3:?triple}; TOOLS=${4:?tools bin dir}
shift 4

SRCDIR=$(cd "$(dirname "$0")/../libgcc" && pwd)

# NON-VACUITY ON THE SETUP ITSELF: assert there is no sibling gcc build dir on
# the relative path libgcc would use, so a pass cannot be that path working.
case "$D" in
  /tmp/*) ;;
  *) echo "FATAL: $D is not under /tmp; refusing -- see the header"; exit 9 ;;
esac
rm -rf "$D"; mkdir -p "$D"
if [ -e "$D/../../gcc" ] || [ -e "$D/../.././gcc" ]; then
  echo "FATAL: a sibling gcc/ exists at $D/../../gcc -- this arm would be vacuous"
  exit 9
fi

export PATH="$PFX/bin:$TOOLS:$PATH"
CCV="$T-gcc"
command -v "$CCV" > /dev/null || { echo "FATAL: no $CCV on PATH"; exit 9; }
echo "CC: $(command -v $CCV)"
echo "as: $(command -v $T-as)"

set +e
( cd "$D" && "$SRCDIR/configure" --host="$T" --build="$(sh "$SRCDIR/../config.guess")" \
    --prefix="$PFX" --disable-multilib \
    CC="$CCV" AR="$T-ar" RANLIB="$T-ranlib" NM="$T-nm" STRIP="$T-strip" \
    "$@" ) > "$D/conf.out" 2> "$D/conf.err"
rc=$?
set -e
echo "configure rc=$rc"
grep -E 'generated headers|C library is available' "$D/conf.out" || true
if [ "$rc" != 0 ]; then tail -20 "$D/conf.err"; tail -20 "$D/conf.out"; exit "$rc"; fi

# ASSERT THE ROUTE, not merely that configure passed.  `libgcc_standalone=no'
# with a working build would mean it found a sibling gcc after all.
grep -q '^libgcc_standalone = yes' "$D/Makefile" || {
  echo "FATAL: libgcc_standalone is not yes in $D/Makefile -- this build is"
  echo "  not exercising the installed-headers route at all."
  grep -n 'libgcc_standalone\|gcc_target_incdir' "$D/Makefile"; exit 9; }
grep -n '^gcc_target_incdir' "$D/Makefile"

set +e
( cd "$D" && make -j"${J:-16}" ${MT_MAKEVARS:-} ) > "$D/make.out" 2> "$D/make.err"
mrc=$?
set -e
echo "make rc=$mrc"
if [ "$mrc" != 0 ]; then
  echo "--- first errors:"
  grep -m8 -E 'error|Error|No such file' "$D/make.err"
  exit "$mrc"
fi
ls -l "$D/libgcc.a" "$D/libgcov.a" 2>/dev/null
# The library must be for the RIGHT machine.  A libgcc.a full of x86_64 objects
# under an aarch64 name is exactly the shape this branch keeps finding.
m=$("$TOOLS/$T-readelf" -h "$D/_muldi3.o" | sed -n 's/.*Machine: *//p')
echo "libgcc objects' machine: $m"
