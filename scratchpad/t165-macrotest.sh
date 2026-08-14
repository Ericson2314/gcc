#!/bin/sh
# #165 -- THE MACRO TEST, applied to the twenty colliding names that `ld' did
# not diagnose (T157-STUBS.md, "TWENTY COLLIDING NAMES").
#
# The rule this implements is `gcc/Makefile.in''s, established by
# `legitimate_pic_operand_p' and `constant_address_p' failing it silently:
#
#   before concluding a bare rename suffices, ask what the PRIMARY's `tm.h'
#   expands the corresponding MACRO to, not only whether shared code spells
#   the symbol.
#
# So there are TWO arms per name and they answer different questions:
#
#   arm S  does any SHARED TU (outside config/) spell the bare symbol?
#          This is the arm that was reassuring and wrong twice.
#   arm M  does any `#define' ANYWHERE under config/ have this name in its
#          BODY?  Deliberately over-broad -- it can only REVOKE a rename,
#          never authorise one (PRINCIPLES 4: "when an instrument can only
#          take away, make it too eager").  A hit here means shared code may
#          reach the symbol through a macro whose name is not the symbol's,
#          which is precisely the case a symbol grep reports as safe.
#
# A name is rename-safe only if BOTH arms are empty.  Arm M hits are printed
# with the defining macro so the next reader can judge rather than re-derive.
#
# usage: t165-macrotest.sh            (run from anywhere; reads the worktree)
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
cd "$G" || exit 9

NAMES="aarch_accumulator_forwarding aarch_mm_needs_acquire aarch_mm_needs_release
aarch_rev16_p aarch_rev16_shleft_mask_imm_p aarch_rev16_shright_mask_imm_p
aarch_validate_mbranch_protection make_pass_insert_bti
arm_early_load_addr_dep arm_early_load_addr_dep_ptr arm_early_store_addr_dep
arm_early_store_addr_dep_ptr arm_mac_accumulator_is_mul_result
arm_mac_accumulator_is_result arm_md_asm_adjust arm_no_early_alu_shift_dep
arm_no_early_alu_shift_value_dep arm_no_early_mul_dep
arm_no_early_store_addr_dep arm_rtx_shift_left_p"

# Non-vacuity: the harness must refuse to score if it cannot show it read
# anything at all (PRINCIPLES 7).  A positive control -- `constant_address_p'
# is KNOWN to be macro-reached (i386.h defines CONSTANT_ADDRESS_P as a call to
# it), so arm M must find it.  If it does not, the instrument is broken and
# every "safe" verdict below is a false green of the exact shape this test
# exists to catch.
ctl=$(grep -rn '^[[:space:]]*#[[:space:]]*define' config/ | grep -c 'constant_address_p' || true)
[ "$ctl" -gt 0 ] || { echo "REFUSING TO SCORE: positive control constant_address_p not found by arm M"; exit 9; }
echo "arm M positive control ok: constant_address_p appears in $ctl #define bodies under config/"
nfile=$(find . -name '*.cc' | wc -l)
[ "$nfile" -gt 100 ] || { echo "REFUSING TO SCORE: only $nfile .cc files; wrong directory?"; exit 9; }
echo "arm S corpus ok: $nfile .cc files under $G"
echo

for n in $NAMES; do
  m=$(grep -rn '^[[:space:]]*#[[:space:]]*define' config/ | grep -w "$n" || true)
  s=$(grep -rlw "$n" --include='*.cc' --include='*.h' --include='*.def' . \
      | grep -v '^./config/' || true)
  nm=$(printf '%s' "$m" | grep -c . || true)
  ns=$(printf '%s' "$s" | grep -c . || true)
  if [ "$nm" = 0 ] && [ "$ns" = 0 ]; then
    v=RENAME-SAFE
  else
    v=REVOKED
  fi
  printf '%-36s M=%s S=%s  %s\n' "$n" "$nm" "$ns" "$v"
  [ "$nm" = 0 ] || printf '%s\n' "$m" | sed 's/^/      M: /'
  [ "$ns" = 0 ] || printf '%s\n' "$s" | sed 's/^/      S: /'
done
