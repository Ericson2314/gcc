#!/bin/sh
# a446b256f0b8bb99c-repro.sh -- the two reproducers for this task, run against
# whichever build dir is named.  BEFORE and AFTER differ only in the compiler.
#
# ARM 1  CASE_VECTOR_MODE      aarch64 under -fPIC gets i386's flag_pic answer.
#        The discriminator is the MODE OF THE JUMP TABLE in the RTL, not the
#        assembly: read `addr_diff_vec'/`addr_vec' out of -fdump-rtl-final.
#        Anchored greps -- `addr_vec' is a SUBSTRING of `addr_diff_vec', and an
#        unanchored count scores the fixed case as broken (the sibling task
#        recorded exactly that trap).
#
# ARM 2  INCOMING_RETURN_ADDR_RTX   gcc.dg/shrink-wrap-sibcall.c at -O2 -g,
#        which ICEs at dwarf2cfi.cc:2606 `Inconsistent CFI state'.
#
# BOTH-SIDED BY CONSTRUCTION: every arm runs for x86_64 as well as aarch64, and
# x86_64 is the control -- an aarch64 fix that moves x86_64 is a regression.
set -eu
D=${1:?build dir}
S=${2:?scratchpad dir with the .c files}
CC1=$D/gcc/cc1
[ -x "$CC1" ] || { echo "FATAL: no cc1 at $CC1"; exit 9; }
O=${3:-/tmp/repro-out.$$}
mkdir -p "$O"

V=$(cat "$S/../gcc/BASE-VER" 2>/dev/null || cat "$(cat "$D/MY-SRC")/gcc/BASE-VER")
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  # Same path mt-bars.sh uses; the per-target spec lands in the install-shaped
  # tree, NOT beside cc1.
  cfg=$D/lib/gcc/$V/$t/specs-config
  [ -s "$cfg" ] || { echo "FATAL: no specs-config at $cfg (run mt-specs.sh)"; exit 9; }
  short=$(echo "$t" | cut -d- -f1)

  # ---- ARM 1: CASE_VECTOR_MODE, with and without PIC.
  for pic in "" "-fPIC"; do
    tag="$short${pic:+-pic}"
    set +e
    "$CC1" -quiet -nostdinc -O1 $pic -ftarget-config="$cfg" \
      -fdump-rtl-final="$O/cv-$tag.rtl" \
      "$S/a446b256f0b8bb99c-casevec.c" -o "$O/cv-$tag.s" \
      > "$O/cv-$tag.out" 2> "$O/cv-$tag.err"
    rc=$?
    set -e
    # The mode of the jump table, read from the RTL dump.  Anchored on `(' so
    # `addr_vec' cannot match inside `addr_diff_vec'.
    if [ -f "$O/cv-$tag.rtl" ]; then
      dv=$(grep -c '(addr_diff_vec' "$O/cv-$tag.rtl" || true)
      av=$(grep -c '(addr_vec' "$O/cv-$tag.rtl" || true)
      mode=$(grep -oE '\(addr_(diff_)?vec:[A-Z0-9]+' "$O/cv-$tag.rtl" \
             | head -1 | sed 's/.*://')
    else
      dv=-; av=-; mode="NO-DUMP"
    fi
    printf 'ARM1 %-14s rc=%s  addr_diff_vec=%-3s addr_vec=%-3s TABLE MODE=%s\n' \
      "$tag" "$rc" "$dv" "$av" "${mode:-none}"
  done

  # ---- ARM 2: the CFI reproducer.
  set +e
  "$CC1" -quiet -nostdinc -O2 -g -ftarget-config="$cfg" \
    "$S/a446b256f0b8bb99c-cfi.c" -o "$O/cfi-$short.s" \
    > "$O/cfi-$short.out" 2> "$O/cfi-$short.err"
  rc=$?
  set -e
  ice=$(grep -c 'internal compiler error' "$O/cfi-$short.err" || true)
  where=$(grep -oE 'in [a-z_]+, at [a-z0-9/.]+:[0-9]+' "$O/cfi-$short.err" | head -1)
  printf 'ARM2 %-14s rc=%s  ICE=%s  %s\n' "$short" "$rc" "$ice" "${where:-(none)}"
done
echo "output in $O"
