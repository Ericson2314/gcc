#!/bin/sh
# INJECT THE EXACT FAULT THE NON-VACUITY CHECK NAMES, AND REQUIRE IT TO FIRE.
#
# PRINCIPLES section 4: an unfired mitigation is indistinguishable from an
# absent one, and reads as protection.  The check in opth-gen.awk says
#
#   "the union spans N back ends and not one option accessor macro was scoped
#    out; the own-set test or the member text has changed shape and this block
#    has silently become a no-op"
#
# so the fault to inject is exactly that: make the own-set test match every
# member, which is what a renamed key or a changed member text would do.  The
# header would still compile -- that is the point, and it is why "did it
# build?" cannot be the arm.
#
# THREE ARMS, and arm 0 runs first:
#
#   0  CONTROL      unmodified generator, real optionlist + real union list,
#                   must produce a header WITH accessor undefs.  Without this,
#                   a broken invocation makes arms 1 and 2 fail for the wrong
#                   reason and the run still reads as a pass.
#   1  INJECT       own-set test always true -> zero undefs -> must FAIL rc!=0
#                   with the message naming itself.
#   2  ASSERT       the injection really changed the generator (both halves),
#                   because a sed that matched nothing exits 0 and leaves arm 1
#                   measuring the unmodified file.
#
# usage: mtr-inject.sh <builddir>/gcc
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/../gcc" && pwd)
D=${1:?builddir/gcc}
B=aarch64

for f in "$D/optionlist-$B" "$D/gcc-options-union.list" "$SRC/opth-gen.awk" \
         "$SRC/opt-functions.awk" "$SRC/opt-read.awk"; do
  [ -s "$f" ] || { echo "FATAL: missing or empty input $f"; exit 9; }
done

T=$(mktemp -d)
trap 'rm -rf "$T"' 0

run() {
  awk -f "$SRC/opt-functions.awk" -f "$SRC/opt-read.awk" \
      -v guard_name=OPTIONS_INJ_H \
      -v union_file="$D/gcc-options-union.list" -v union_base="$B" \
      -f "$1" < "$D/optionlist-$B" > "$T/out.h" 2> "$T/err"
}

echo "=== ARM 0  CONTROL: unmodified generator"
run "$SRC/opth-gen.awk"; rc0=$?
n0=$(awk '/Option accessor macros belonging/,0' "$T/out.h" | grep -c '^#undef ' || true)
echo "rc=$rc0  accessor undefs=$n0  stderr=$(wc -c < "$T/err") bytes"
[ "$rc0" = 0 ] || { echo "FATAL: control run failed; arms 1-2 would be meaningless"; cat "$T/err"; exit 9; }
[ "$n0" -gt 0 ] || { echo "FATAL: control produced ZERO accessor undefs"; exit 9; }

echo
echo "=== ARM 2  ASSERT THE INJECTION LANDED"
sed 's/^\t\tif (key in member_text)$/\t\tif (1) # INJECTED/' \
    "$SRC/opth-gen.awk" > "$T/inj.awk"
have=$(grep -c '^		if (1) # INJECTED$' "$T/inj.awk" || true)
gone=$(grep -c '^		if (key in member_text)$' "$T/inj.awk" || true)
echo "injected lines: $have   original lines remaining: $gone"
[ "$have" = 1 ] && [ "$gone" = 0 ] \
  || { echo "FATAL: injection did not produce the intended state"; exit 9; }

echo
echo "=== ARM 1  INJECT: the block becomes a no-op; the check must FIRE"
run "$T/inj.awk"; rc1=$?
echo "rc=$rc1"
sed -n 1,3p "$T/err"
[ "$rc1" != 0 ] \
  || { echo "FATAL: injected generator exited 0 -- the mitigation did NOT fire"; exit 9; }
grep -q 'not one option accessor macro was scoped out' "$T/err" \
  || { echo "FATAL: it failed, but not by the name it promised"; exit 9; }
echo
echo "MITIGATION FIRED, by name."
