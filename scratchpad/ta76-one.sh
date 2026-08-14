#!/bin/sh
# Compile ONE input for ONE configured back end and report rc, size and head.
# usage: ta76-one.sh <builddir> <canonical-triple> <input.c> <-O level>
set -u
D=${1:?build dir}; T=${2:?triple}; IN=${3:?input}; OPT=${4:--O2}
case "$D" in
  */b-a76e996f6ef44dca5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
CFG=$(ls "$D"/lib/gcc/*/"$T"/specs-config 2>/dev/null | head -1)
[ -n "$CFG" ] || { echo "FATAL: no specs-config for $T"; exit 9; }
O=$D/ta76-one; mkdir -p "$O"
tag=$T$(echo "$OPT" | tr -d ' -').$(basename "$IN" .c)
( cd "$D/gcc" && timeout 300s ./cc1 -quiet -nostdinc "$OPT" \
    -ftarget-config="$CFG" "$IN" -o "$O/$tag.s" ) \
    > "$O/$tag.out" 2> "$O/$tag.err"
rc=$?
echo "rc=$rc  (124 = TIMED OUT, i.e. still running after 300s)"
echo "bytes=$(wc -c < "$O/$tag.s" 2>/dev/null || echo 0)  md5=$(md5sum < "$O/$tag.s" 2>/dev/null | cut -c1-12)"
echo "--- stderr (first 6):"; sed -n 1,6p "$O/$tag.err"
echo "--- .s (first 25):";    sed -n 1,25p "$O/$tag.s" 2>/dev/null
echo "PATH: $O/$tag.s"
