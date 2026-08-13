#!/bin/sh
# What the accessor-macro block actually removed, per back end, BOTH-SIDED.
#
# One-sided evidence -- "arm no longer defines selected_arch" -- cannot tell
# "scoped correctly" from "removed from everybody", so every arm here reads
# the owner and a non-owner of the same name.
#
# NON-VACUITY FIRST: refuses to score if the generated headers are missing, if
# the block's marker comment is absent from a per-base header (which is what a
# silently-disabled block looks like), or if any per-base header removed
# nothing at all.
#
# usage: mtr-undefcheck.sh <builddir>/gcc
set -eu
D=${1:?builddir/gcc}
MARK='Option accessor macros belonging'
[ -d "$D" ] || { echo "FATAL: $D is not a directory"; exit 9; }

n_hdr=0
for f in "$D"/options-*.h; do
  [ -f "$f" ] || continue
  n_hdr=$((n_hdr + 1))
done
[ "$n_hdr" -gt 1 ] \
  || { echo "FATAL: $n_hdr per-base options headers in $D; nothing to compare"; exit 9; }
echo "non-vacuity: $n_hdr per-base options headers found"

bad=
tot=0
for f in "$D"/options-*.h; do
  b=${f##*/options-}; b=${b%.h}
  grep -q "$MARK" "$f" || { bad="$bad $b(no-block)"; continue; }
  n=$(awk -v m="$MARK" 'index($0,m){f=1} f && /^#undef /' "$f" | wc -l)
  [ "$n" -gt 0 ] || bad="$bad $b(empty)"
  tot=$((tot + n))
  printf '%-12s accessor macros scoped out: %s\n' "$b" "$n"
done
echo
echo "per-base headers: $n_hdr   accessor undefs total: $tot"
[ -z "$bad" ] || { echo "FATAL: headers with no block or an empty one:$bad"; exit 9; }

echo
echo "=== both-sided, per name: OWNER keeps it, NON-OWNER loses it"
# name : owner(s) : a non-owner
check() {
  nm=$1; own=$2; foreign=$3
  o=$(grep -c "^#undef $nm\$" "$D/options-$own.h" || true)
  g=$(grep -c "^#undef $nm\$" "$D/options-$foreign.h" || true)
  od=$(grep -c "^#define $nm global_options.x_$nm\$" "$D/options-$own.h" || true)
  printf '%-24s owner %-9s undef=%s define=%s   non-owner %-9s undef=%s\n' \
         "$nm" "$own" "$o" "$od" "$foreign" "$g"
  [ "$o" = 0 ] && [ "$od" = 1 ] && [ "$g" = 1 ] && return 0
  echo "  MISMATCH: expected owner undef=0 define=1, non-owner undef=1"
  return 1
}
rc=0
check selected_arch      aarch64 arm    || rc=1
check ix86_stringop_alg  i386    arm    || rc=1
check arm_pic_data_is_text_relative arm i386 || rc=1
[ "$rc" = 0 ] || { echo "FATAL: a both-sided arm failed"; exit 9; }

echo
echo "=== the Mask/Var overlap that decided this block's POSITION"
echo "TARGET_FDPIC is Mask(FDPIC) in arm.opt and Var(TARGET_FDPIC) in bfin.opt."
echo "arm must end up with its own Mask expression, not with nothing:"
grep -n '^#define TARGET_FDPIC \|^#undef TARGET_FDPIC$' "$D/options-arm.h"
last=$(grep -n '^#define TARGET_FDPIC \|^#undef TARGET_FDPIC$' "$D/options-arm.h" | tail -1)
case "$last" in
  *'#define TARGET_FDPIC ((target_flags'*) echo "OK: arm's Mask definition is last" ;;
  *) echo "FATAL: arm's last word on TARGET_FDPIC is: $last"; exit 9 ;;
esac
