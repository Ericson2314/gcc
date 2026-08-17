#!/bin/sh
# a302b44ba-icebuild.sh -- build ONE tree and ask it a single yes/no question:
# does `gcc.target/i386/pr78671.c' ICE in reload?
#
# WHY THIS EXISTS.  The x86_64 row moved debt 67 -> 70 and the three new names
# are genuine PASS -> FAIL regressions in `gcc.target/i386', none of them
# decimal float.  An unattributed delta is not a measurement, and the
# introducing commit is somewhere in the 150 between `e1f0cad1c2c' (the last
# board on which all three PASS) and `7b39423abba' (this build).  Reading the
# diffs produced a plausible suspect and did not settle it, so this is the
# instrument for a bisect.
#
# THE TEST IS SECONDS; THE BUILD IS THE COST.  `pr78671.c' reproduces standalone
# off the built `xgcc' in about a second, so the only expensive part is `make
# all-gcc'.  That is why this script exists at a SMALL BASE COUNT: if the ICE
# still fires with two bases, every bisect step is a two-base build instead of
# a 47-base one.
#
# AND THE BASE COUNT IS ITSELF A RESULT.  If the ICE does NOT reproduce at two
# bases it must not be reported as "fixed" -- it means the fault needs the
# wider union, which is information about the mechanism (shared mode/register
# numbering across 47 bases) and forces the bisect back to 47-base builds.
# Those two outcomes are printed differently and neither is silent.
#
# usage: a302b44ba-icebuild.sh <builddir> <srcdir> [<comma-list>]
set -u
export LC_ALL=C
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}          # MUST contain b-302b44ba or the harness refuses
SRC=${2:?srcdir}
LIST=${3:-x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu}
HDR=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
T=/tmp/snap-multi-target-7b39423abba/gcc/testsuite/gcc.target/i386/pr78671.c
[ -f "$T" ] || { echo "FATAL: no $T"; exit 9; }

rm -rf "$D"; mkdir -p "$D"
( cd "$D" && "$SRC"/configure --disable-werror --disable-bootstrap --disable-nls \
    --enable-targets="$LIST" --with-native-system-header-dir="$HDR" \
    --enable-languages=c CC=gcc CXX=g++ \
    CFLAGS='-O2 -g0' CXXFLAGS='-O2 -g0' > conf.out 2> conf.err )
rc=$?
[ "$rc" = 0 ] || { echo "FATAL: configure rc=$rc"; tail -15 "$D/conf.err"; exit 9; }
( cd "$D" && make -j16 all-gcc > build.out 2> build.err )
rc=$?
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1 (make rc=$rc)"; tail -20 "$D/build.err"; exit 9; }

CFG=$(ls "$D"/lib/gcc/*/x86_64-pc-linux-gnu/specs-config 2>/dev/null | head -1)
if [ -z "$CFG" ]; then
  echo "FATAL: no x86_64 specs-config in $D -- cannot ask this build anything."
  echo "  REFUSING to read a missing artefact as a passing test."
  exit 9
fi

out=$("$D/gcc/xgcc" -B"$D/gcc/" -ftarget-config="$CFG" "$T" \
        -march=skylake-avx512 -Og -S -o /dev/null 2>&1)

# THE ARM THAT CAN FAIL BOTH WAYS.  "No ICE" is only meaningful if the compiler
# actually compiled something; a build that refuses every input also prints no
# ICE.  So a clean run must ALSO have produced assembly.
if printf '%s' "$out" | grep -q 'insn does not satisfy its constraints'; then
  echo "ICE: YES  ($D, bases=$(printf '%s' "$LIST" | tr ',' '\n' | grep -c .))"
  exit 1
fi
if ! "$D/gcc/xgcc" -B"$D/gcc/" -ftarget-config="$CFG" "$T" \
       -march=skylake-avx512 -Og -S -o "$D/probe.s" 2>/dev/null \
   || [ ! -s "$D/probe.s" ]; then
  echo "ICE: INCONCLUSIVE -- no ICE, but the compiler produced no assembly either."
  echo "  'did not ICE' and 'did not compile' are the same silence; refusing to"
  echo "  score this as a pass.  Output was:"
  printf '%s\n' "$out" | head -5
  exit 9
fi
echo "ICE: NO   ($D, bases=$(printf '%s' "$LIST" | tr ',' '\n' | grep -c .), and it DID emit $(wc -l < "$D/probe.s") lines of asm)"
exit 0
