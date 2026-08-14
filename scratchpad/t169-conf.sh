#!/bin/sh
# #169 -- configure gcc/ ALONE with every back end, from an IMMUTABLE SNAPSHOT.
#
# WHY gcc/ ALONE.  The instrument this task needs (t169-guardsweep.sh) reads
# each back end's REAL header chain via `cpp -dM' on the generated
# `gcc/tm-<base>.h'.  Those are host-side artefacts of gcc/'s own configure;
# nothing about them needs the top level's per-TARGET trees, and asking the top
# level for 48 targets configures 48 libgcc trees for no gain.  Per PRINCIPLES
# section 2 the top level is the target dispatcher -- but this measurement is
# entirely inside gcc/, so `--enable-backends' (gcc/'s own spelling, host-side:
# which back ends go INTO the binary) is the right and only knob here.
#
# usage: SRC=<snapshot> t169-conf.sh <builddir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC to an immutable snapshot worktree}
SRC=$(cd "$SRC" && pwd)
D=${1:?build dir}
WANT=${WANT_ANCHOR:-50}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SRC" && git diff --quiet && git diff --cached --quiet ) \
  || { echo "FATAL: $SRC is not clean; a build whose sources can change under it measures nothing"; exit 9; }
case "$D" in
  */b-ab60dd*/gcc) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
echo "srcdir $SRC anchor=$n clean OK"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/gcc/configure \
  --disable-werror \
  --enable-backends=all \
  --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu \
  --target=x86_64-pc-linux-gnu \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c" > "$D/conf.out" 2> "$D/conf.err"
echo "configure rc=$?"
grep -m1 'running configure' "$D/config.log" || true
echo "$SRC" > "$D/MY-SRC"
tail -5 "$D/conf.err"

# BUILD-MACHINE libiberty.  `build/gen*' link against
# `../build-<build>/libiberty/libiberty.a', which the TOP LEVEL would normally
# supply.  Configuring gcc/ alone (see the header comment) means supplying it
# here; it is the build machine's libiberty, so it is configured --host=<build>
# and built with the build compiler.  Without it `make tm-<base>.h' dies with
#   No rule to make target '../build-.../libiberty/libiberty.a'
B=$(dirname "$D")/build-x86_64-pc-linux-gnu/libiberty
mkdir -p "$B"
sh "$S/eb-shell.sh" "cd $B && $SRC/libiberty/configure \
  --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu \
  CC=gcc CFLAGS='-O2 -g0' && make -j8" > "$B/mk.out" 2> "$B/mk.err"
echo "libiberty rc=$?"
[ -f "$B/libiberty.a" ] || { echo "FATAL: no libiberty.a"; exit 9; }
echo "libiberty.a OK"
