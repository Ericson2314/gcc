#!/bin/sh
# #163 -- DID ANYTHING ELSE MOVE?  x86_64 -O2 on scratchpad/big.c, the branch's
# strongest regression detector, run on a PRE-#163 and a POST-#163 cc1 with the
# same input and the same target config.
#
# NOT THE RECORDED 12369 / 378fc33c1e70 BAR, AND SAYING SO MATTERS.  That bar
# is taken with the real per-target `specs-config' from target-specs/configure;
# this runs from a two-line hand-written config, so the absolute number is a
# different quantity and must not be compared against it (PRINCIPLES section 4:
# quote every bar with the command that produced it).  What IS comparable is
# the two sides of THIS run against each other, because everything except the
# compiler is held fixed.
#
# The default must be unchanged: `as_tls' defaults to true, which is the
# unconditional 1 the old AC_DEFINE gave, so identical output is the PASS here
# -- the opposite of tb1-tls.sh, where identical output is the failure.  Both
# scripts are needed for that reason.
#
# usage: tb1-nochange.sh <before-builddir> <after-builddir>
set -u
A=${1:?before build dir}
B=${2:?after build dir}
for D in "$A" "$B"; do
  case "$D" in
    */b-agent-aab545de8b02de843*) ;;
    *) echo "FATAL: $D is not named for this worktree"; exit 9 ;;
  esac
  [ -f "$D/make-top.rc" ] || { echo "FATAL: $D/make-top.rc absent -- unstamped log"; exit 9; }
  [ -x "$D/gcc/cc1" ] || { echo "FATAL: no $D/gcc/cc1"; exit 9; }
done

S=$(cd "$(dirname "$0")" && pwd)
IN="$S/big.c"
[ -s "$IN" ] || { echo "FATAL: input missing: $IN"; exit 9; }
T=x86_64-pc-linux-gnu
OUT=$B/nochange; rm -rf "$OUT"; mkdir -p "$OUT"
printf 'target %s\n' "$T" > "$OUT/cfg"

# NON-VACUITY: the two cc1 binaries must not be the same file.
if cmp -s "$A/gcc/cc1" "$B/gcc/cc1"; then
  echo "FATAL: the two cc1 binaries are identical; nothing is being compared"; exit 9
fi
echo "arm 0  the two cc1 binaries differ ($(wc -c < "$A/gcc/cc1") vs $(wc -c < "$B/gcc/cc1") bytes)"
echo "input: $IN   target-config: target $T only"
echo

for tag in before after; do
  case $tag in before) D=$A ;; after) D=$B ;; esac
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$OUT/cfg" \
      "$IN" -o "$OUT/$tag.s" ) > "$OUT/$tag.out" 2> "$OUT/$tag.err"
  r=$?
  if [ "$r" != 0 ] || [ ! -s "$OUT/$tag.s" ]; then
    echo "FATAL: $tag cc1 rc=$r"; sed -n 1,10p "$OUT/$tag.err"; exit 9
  fi
  printf '  %-7s %s bytes  md5 %s   (%s)\n' "$tag" \
    "$(wc -c < "$OUT/$tag.s")" "$(md5sum < "$OUT/$tag.s" | cut -c1-12)" "$D"
done

echo
if cmp -s "$OUT/before.s" "$OUT/after.s"; then
  echo "RESULT: BYTE-IDENTICAL -- the default answer did not move."
else
  echo "RESULT: DIFFER -- #163 changed x86_64 -O2 codegen; investigate."
  diff "$OUT/before.s" "$OUT/after.s" | head -20
  exit 1
fi
