#!/bin/sh
# #150 -- does `add_clobbers' answer for the base in force?
#
# THE NON-VACUITY ARM RUNS FIRST AND THE SCRIPT REFUSES TO SCORE WITHOUT IT.
# PRINCIPLES section 7: "when every arm of your probe reads empty, that looks
# exactly like `branch not taken'".  Here the failure mode is sharper still --
# a missing driver, or a cc1 that was never linked, makes every target read
# "no ICE", which is the shape of SUCCESS.  So arm 0 requires each driver to
# exist AND to be able to produce a diagnostic at all.
#
# usage: t150-ice.sh <builddir> <tag>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
TAG=${2:?tag, e.g. before / after}
case "$B" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
grep -q 'worktrees/agent-ad0e44242408b7fde/configure' "$B/config.log" \
  || { echo "FATAL: $B/config.log does not name this worktree"; exit 9; }

# The four instrument bases, and why these four:
#   x86_64  the PRIMARY -- the authority that was leaking.  Its arm is the
#           both-sided half: it must still get its OWN answer, or the fix has
#           merely given everyone a new single answer.
#   aarch64 the reproducer #150 names.
#   powerpc64 a third base, because two back ends is a habit and not a check.
#           rs6000 is the back end that has already broken the i386+aarch64
#           pair once on this branch (six ELIMINABLE_REGS pairs vs four).
#   s390x   a fourth, and big-endian, so a divergence that happens to agree on
#           three little-endian bases still has somewhere to show.
#
# THE FOURTH BASE WAS TRIED AND WITHDRAWN, WHICH IS ITSELF THE RESULT.
# powerpc64 + s390x, and separately mips64, were configured first.  Neither
# set links at HEAD, each for its own PRE-EXISTING reason:
#   rs6000/s390 -- print_operand, print_operand_address,
#                  legitimate_pic_operand_p, legitimize_pic_address,
#                  regclass_map all multiply defined
#   mips        -- insn_mips::unspecv_strings{,_len} undefined
#   riscv       -- extract_base_offset_in_addr, FIXED in this branch so that
#                  three bases became possible at all
# So the base set below is three, and the reason it is not four is measured
# and named rather than habitual.  See scratchpad/t150-rename-gap.sh.
TARGETS="x86_64-pc-linux-gnu aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu"
IN=$(cd "$S" && pwd)/big.c
[ -f "$IN" ] || { echo "FATAL: input $IN missing"; exit 9; }

echo "== arm 0: NON-VACUITY (must pass before anything is scored)"
#
# A target that fails HERE is reported as UNSCORABLE BY NAME and excluded from
# arm 1.  It is NOT silently dropped, and the exclusion is not a way of making
# a red column disappear: a cc1 that dies before parsing reads as "no ICE" in
# BOTH the before and after columns, i.e. as success, so naming it is the only
# honest option.  PRINCIPLES section 7: a measured "still cannot be checked,
# because X" is a useful result; an unexamined pass is not.
#
# The script still refuses to score unless BOTH of these hold:
#   * aarch64 is scorable -- it is the reproducer, and without it there is no
#     measurement at all, only a control;
#   * x86_64 is scorable -- it is the both-sided half.  Showing aarch64 gets
#     aarch64's answer proves nothing unless the primary still gets its own.
SCORABLE=""
for t in $TARGETS; do
  d="$B/gcc/$t-gcc"
  if [ ! -x "$d" ]; then
    echo "  UNSCORABLE: no driver $d"; continue
  fi
  # Can this driver emit a diagnostic at all?
  e=$(sh "$S/eb-shell.sh" \
        "cd $B/gcc && ./$t-gcc -S -nostdinc -o /dev/null $B/t150-vac.c" 2>&1 \
        > /dev/null || true)
  # `undeclared' AND NOT `fatal error', deliberately.  The first draft of this
  # arm accepted any line containing "error", and x86_64 and aarch64 both
  # PASSED it while being unable to compile anything at all: the string it
  # matched was the driver's own
  #     fatal error: no configuration file for target `x86_64-pc-linux-gnu'
  # from target-specs never having been run.  A check that accepts the wrong
  # error is the same defect as a check that accepts an empty read -- it was
  # caught only because arm 1 then failed loudly on both targets.
  #
  # So the arm now requires the diagnostic the input was WRITTEN to provoke,
  # by name, and rejects any driver-level fatal error outright.
  case "$e" in
    *"fatal error"*)
      echo "  UNSCORABLE BY NAME: $t fails before compiling:"
      echo "    [$(printf '%s' "$e" | head -1)]" ;;
    *"undeclared"*)
      echo "  ok: $t emits the expected compile diagnostic"
      SCORABLE="$SCORABLE $t" ;;
    *)
      echo "  UNSCORABLE BY NAME: $t produced no diagnostic for a known-bad"
      echo "    input, so a clean arm-1 reading from it would be meaningless:"
      echo "    [$e]" ;;
  esac
done
case "$SCORABLE" in
  *aarch64*) ;;
  *) echo "REFUSING TO SCORE: aarch64 is the reproducer and is unscorable"; exit 9 ;;
esac
case "$SCORABLE" in
  *x86_64*) ;;
  *) echo "REFUSING TO SCORE: x86_64 is the both-sided control and is unscorable"; exit 9 ;;
esac
TARGETS="$SCORABLE"

echo
echo "== arm 1: $IN, per base"
for t in $TARGETS; do
  o="$B/t150-$TAG-$t"
  rm -f "$o.s"
  sh "$S/eb-shell.sh" \
    "cd $B/gcc && ./$t-gcc -O2 -S -nostdinc -o $o.s $IN" \
    > "$o.out" 2> "$o.err"
  rc=$?
  if grep -q 'internal compiler error' "$o.err"; then
    site=$(grep -m1 'internal compiler error' "$o.err" \
           | sed 's/.*internal compiler error: //')
    echo "  $t  rc=$rc  ICE: $site"
  elif [ "$rc" != 0 ]; then
    echo "  $t  rc=$rc  FAIL-NO-ICE: $(head -2 "$o.err" | tr '\n' ' ')"
  else
    echo "  $t  rc=$rc  COMPILED  bytes=$(wc -c < "$o.s")  md5=$(md5sum < "$o.s" | cut -c1-12)"
  fi
done
