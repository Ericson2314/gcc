#!/bin/sh
# TWO-SIDED CHECK on the DTPREL probe added to target-specs/configure.ac.
#
# A one-sided run cannot tell the fix from its sign-flipped twin.  Turning the
# key off for EVERY target would make aarch64 pass and would be the same defect
# with the sign reversed -- a constant answer in the one file whose job is
# recording what a SPECIFIC assembler can do.  So this asserts BOTH:
#
#   aarch64 (gas 2.46, rejects `%dtprel(')          => as_dtprel_reloc 0
#   x86_64  (native gas, accepts `sym@dtpoff')      => as_dtprel_reloc 1
#
# and FAILS if the two agree, in either direction.
#
# The probe inside configure.ac has its own non-vacuity control (a plain-symbol
# fragment that must assemble); this script is the outer check that the control
# is not itself masking everything.
set -u
S=$(cd "$(dirname "$0")/.." && pwd)
W=${W:-/tmp/t252-bothsided}
AARCH64_TOOLS=${AARCH64_TOOLS:-/home/jcericson/src/gnu/gcc/t246-a7b00/aarch64}
rm -rf "$W"; mkdir -p "$W/a/b" "$W/a/out" "$W/x/b" "$W/x/out"

run () {
  # $1 build subdir, $2 triple, $3 tools bin dir, $4 cpu_type
  ( cd "$W/$1/b" && CONFIG_SITE=no-such-file sh "$S/target-specs/configure" \
      --srcdir="$S/target-specs" --build=x86_64-pc-linux-gnu \
      --host="$2" --with-target="$2" --with-tools-dir="$3" \
      --with-specs-file="$W/$1/out/specs" --with-cpu-type="$4" \
      --with-option-defaults= --with-decimal-float=0 \
      --with-decimal-bid-format=0 ) > "$W/$1/conf.out" 2>&1
  test -f "$W/$1/out/specs-config" || { echo "FATAL: $2 wrote no specs-config"; exit 9; }
  awk '$1 == "as_dtprel_reloc" { print $2 }' "$W/$1/out/specs-config"
}

command -v "$AARCH64_TOOLS/as" > /dev/null 2>&1 || {
  echo "FATAL: no aarch64 as at $AARCH64_TOOLS -- this check would be vacuous"; exit 9; }

A=$(run a aarch64-unknown-linux-gnu "$AARCH64_TOOLS" aarch64)
X=$(run x x86_64-pc-linux-gnu "$(dirname "$(command -v as)")" i386)

echo "aarch64 as_dtprel_reloc = ${A:-<absent>}"
echo "x86_64  as_dtprel_reloc = ${X:-<absent>}"
rc=0
[ "$A" = 0 ] || { echo "FAIL: aarch64 gas rejects %dtprel( but the key says $A"; rc=1; }
[ "$X" = 1 ] || { echo "FAIL: x86_64 gas accepts sym@dtpoff but the key says $X"; rc=1; }
[ "$A" != "$X" ] || { echo "FAIL: both targets agree -- the probe is a constant"; rc=1; }
[ "$rc" = 0 ] && echo "PASS: two targets, two answers, each matching its own assembler"
exit "$rc"
