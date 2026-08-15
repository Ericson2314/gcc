#!/bin/sh
# agent-aa9d4bba0b6e950b3-hashtab.sh -- s390x's THIRD cause, handed over with a
# reproducer rather than investigated.
#
#   internal compiler error: in hashtab_chk_error, at hash-table.cc:126
#   "hash table checking failed: equal operator returns true for a pair of
#    values with a different hash value"
#   during RTL pass: reload
#   hashtab_chk_error <- force_const_mem <- curr_insn_transform <- lra_constraints
#
# 60 FAILs over 24 files on the 47-base board (bitint-*, builtin-arith-overflow-*,
# pr109938, pr109986, embed-21, pr88598-4).  The table is varasm.cc's CONSTANT
# POOL (`const_rtx_desc_hasher', varasm.cc:4075-4087): `equal' is
# `x->mode == y->mode && rtx_equal_p (x->constant, y->constant)' and `hash' is
# the `const_rtx_hash' (varasm.cc:4168) stored at insertion.  So two constants
# that `rtx_equal_p' calls equal are hashing differently -- i.e. the hash reads
# something the comparison ignores, or one of the two was hashed under a
# different answer to a per-base question.
#
# WHY IT IS FILED SEPARATELY FROM THE OTHER TWO.  It is NOT the CC-mode leak
# (that is `combine', and its ICE names s390_match_ccmode_set) and NOT the
# return-address-pointer one (that is `expand', and its ICE is a bare SIGSEGV
# in make_tree).  This is `reload'.  Three passes, three causes; the board's
# "gcc.c-torture/compile is something the ICE census does not name" is partly
# this.
#
# The both-sided arm is the first thing to run: if it fires on every target it
# is not a leak at all and belongs upstream, and that is a different search.
#
# usage: agent-aa9d4bba0b6e950b3-hashtab.sh <builddir>
set -u
D=${1:?build dir}
SRC=$(cat "$D/MY-SRC")
V=$(cat "$SRC/gcc/BASE-VER")
IN=$SRC/gcc/testsuite/gcc.c-torture/execute/pr109938.c
[ -s "$IN" ] || { echo "FATAL: no $IN" >&2; exit 9; }

for T in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu \
         riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  CFG="$D/lib/gcc/$V/$T/specs-config"
  [ -s "$CFG" ] || { printf '%-28s NO specs-config -- refusing to score\n' "$T"; continue; }
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$CFG" \
      "$IN" -o /tmp/ht-$$.s ) > /dev/null 2> /tmp/ht-err-$$.txt
  rc=$?
  if grep -q 'internal compiler error' /tmp/ht-err-$$.txt; then
    printf '%-28s rc=%-3s %s\n' "$T" "$rc" \
      "$(grep -m1 'internal compiler error' /tmp/ht-err-$$.txt | sed 's/^.*internal/internal/')"
  else
    printf '%-28s rc=%-3s ok, %s bytes\n' "$T" "$rc" "$(wc -c < /tmp/ht-$$.s 2>/dev/null || echo 0)"
  fi
done
rm -f /tmp/ht-$$.s /tmp/ht-err-$$.txt
