#!/bin/sh
# #137 -- the codegen bars, run in ONE build dir before and after the change.
# $1 = build dir, $2 = tag (before/after).  Nothing here is compared against a
# remembered number: the two runs are compared with each other, and the
# recorded branch figures are printed alongside for reference only.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}; TAG=${2:?tag}
G=$B/gcc
D=$B/t137-$TAG; rm -rf "$D"; mkdir -p "$D" || exit 9
[ "$(grep -c MULTI_TARGET "$G/Makefile")" -ge 39 ] || { echo "FATAL: stale build dir"; exit 9; }
[ -s "$S/big.c" ] || { echo "FATAL: no big.c"; exit 9; }

echo "int x = 1;" > "$D/one.c"

# x86_64 -O2 on big.c, and aarch64 on the one-liner.  Absolute input paths: a
# relative one has already produced a false green on this branch.
sh "$S/eb-shell.sh" "cd $G && ./x86_64-pc-linux-gnu-gcc -O2 -S -o $D/big.s $S/big.c" \
   > "$D/x86.out" 2> "$D/x86.err"; rcx=$?
sh "$S/eb-shell.sh" "cd $G && ./aarch64-unknown-linux-gnu-gcc -O2 -S -o $D/one.s $D/one.c" \
   > "$D/a64.out" 2> "$D/a64.err"; rca=$?

for f in "$D/big.s" "$D/one.s"; do
  [ -s "$f" ] || { echo "$TAG: FATAL: $f empty or missing -- refusing to score"; exit 9; }
done
# THE aarch64 BAR IS SENSITIVE TO THE NAME OF ITS OWN INPUT FILE, which is why
# the input basename is PINNED to `one.c' here and stated in the output.
#
# `-S' emits a `.file "<basename>"' directive, so both the byte count and the
# md5 of the `.s' move when the scratch file is renamed -- with the compiler,
# the flags and the source text all identical.  Measured in one build dir:
#     x.c      369 bytes
#     one.c    371 bytes   md5 84b06d9df5d2
#     mtbar.c  373 bytes   md5 4b06c278c6ca
# The branch record quotes "373 bytes / b01d9157fdc1".  The 373 is reproduced
# exactly by any SEVEN-character basename, so the recorded size is evidence
# about a filename and not about codegen; the md5 differs again because it
# depends on the filename's CONTENT, not just its length.
#
# So "aarch64 373 / b01d9157fdc1" is not quotable between agents unless the
# input path is quoted with it, and no brief states one.  An agent whose
# scratch file happens to be named differently reads a MOVED bar and goes
# hunting a codegen regression that never happened -- and the converse is
# worse, since a wrong compiler could match 373 by choosing a filename.
# The x86_64 bar does not have this problem here only because `big.c' is a
# fixed file in scratchpad/ that everyone passes by the same name.
echo "$TAG x86_64 -O2 scratchpad/big.c   rc=$rcx  $(wc -c < "$D/big.s") bytes  md5=$(md5sum < "$D/big.s" | cut -c1-12)  (branch record: 378fc33c1e70 / 12369)"
echo "$TAG aarch64 -O2 'int x = 1;' as one.c   rc=$rca  $(wc -c < "$D/one.s") bytes  md5=$(md5sum < "$D/one.s" | cut -c1-12)  (branch record 373/b01d9157fdc1 is NOT comparable: different input basename)"
echo "$TAG stderr: x86 $(wc -l < "$D/x86.err") lines, aarch64 $(wc -l < "$D/a64.err") lines"
