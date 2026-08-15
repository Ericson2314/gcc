#!/bin/sh
# aa1e1db1aead2bffb -- run one .exp through mtcheck.sh and PRESERVE its
# gcc.sum/gcc.log under a run-specific name before anything can overwrite them.
#
# Same job as a5764a65f9eec0063-score.sh; that script hardcodes ANOTHER
# worktree's tools dir (/tmp/tools-a5764a65f9eec0063/bin) and output dir, which
# is the one line INSTRUMENTS.md names as what forced 63 copies.  Here both are
# taken from the environment and ASSERTED to exist, so a missing cross
# assembler fails by name rather than silently feeding aarch64 assembly to the
# host x86 `as' (GUARD 3c, worth ~10,000 results per target).
#
# usage: TOOLS=<dir> OUT=<dir> sh aa1e1db1aead2bffb-score.sh <builddir> <tag> <exp>...
set -eu
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}; shift
TAG=${1:?tag}; shift
T=aarch64-unknown-linux-gnu
TOOLS=${TOOLS:?set TOOLS to the cross-tools bin dir}
OUT=${OUT:?set OUT}
[ -x "$TOOLS/$T-as" ] || { echo "FATAL: no $TOOLS/$T-as (GUARD 3c would fall back to the host as)"; exit 9; }
mkdir -p "$OUT"

for exp in "$@"; do
  echo "########## $TAG / $exp"
  WANT_ANCHOR=${WANT_ANCHOR:?} \
  MT_TOOLS_aarch64_unknown_linux_gnu="$TOOLS" \
  MT_COMPILE_ONLY=1 \
  MT_RUNTESTFLAGS="$exp" \
  sh "$S/mtcheck.sh" "$B" "$T" > "$OUT/$TAG-$exp.mtlog" 2>&1 || true

  rc=$(cat "$B/check-$T.rc" 2>/dev/null || echo missing)
  echo "  mtcheck rc stamp: $rc"
  [ "$rc" = 0 ] || { echo "  REFUSING to score: no rc=0 stamp"; continue; }

  src=$B/gcc/testsuite.$T/gcc
  cp "$src/gcc.sum" "$OUT/$TAG-$exp.sum"
  cp "$src/gcc.log" "$OUT/$TAG-$exp.log"
  n=$(grep -c '^\(PASS\|FAIL\)' "$OUT/$TAG-$exp.sum" || true)
  [ "$n" -gt 0 ] || { echo "  FATAL: preserved sum has no PASS/FAIL lines"; exit 9; }
  echo "  preserved $OUT/$TAG-$exp.sum  ($n result lines)"
  echo "  KILLED: $(grep -c 'internal compiler error: Killed\|terminated by signal 9' "$OUT/$TAG-$exp.log" || true)  <- never subtracted"
  echo "  load: $(cut -d' ' -f1-3 /proc/loadavg)"
done
