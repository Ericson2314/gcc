#!/bin/sh
# INJECTION ARMS for the target_* layout sweep.
#
# An unfired mitigation is indistinguishable from an absent one, so each arm
# below puts back the exact defect the change removes and REQUIRES the witness
# to fire BY NAME.  Every arm asserts that its edit produced the state it
# intended (a `sed' that matched nothing exits 0 and leaves the fixed
# compiler in place, which reads as a pass), and every arm restores the tree
# and reconfirms the green afterwards.
#
# usage: mtsw-inject.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
V=17.0.0
IN=$SRC/scratchpad/big.c
CFG=$D/lib/gcc/$V/x86_64-pc-linux-gnu/specs-config
# `init_reg_sets' checks the SELECTED back end's numbers, so an injection into
# aarch64's headers is only observable when compiling FOR aarch64.  Injecting
# into the primary instead would prove nothing: shared translation units read
# the primary's tm.h, so both sides would move together and agree.
CFG_AA=$D/lib/gcc/$V/aarch64-unknown-linux-gnu/specs-config
# A SEPARATE INPUT FOR THE aarch64 ARMS, AND THE REASON IS A PRE-EXISTING BUG
# THAT IS NOT THIS CHANGE'S.  `big.c' through the aarch64 configuration ICEs in
# `add_clobbers, at config/i386/sync.md:2483' -- the primary's generated
# `add_clobbers' answering for every base, one more instance of the
# one-name-several-authorities shape.  Measured on the RESTORED tree, so it is
# a property of the branch and not of the injection; using `big.c' here would
# have made every aarch64 arm fail for a reason unrelated to what it tests.
IN_AA=$SRC/scratchpad/mtsw-small.c
LOG=$D/mtsw-inject
mkdir -p "$LOG"

got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$D/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $D configured from '$got', not $SRC"; exit 9; }
[ -s "$CFG" ] || { echo "FATAL: no specs-config at $CFG"; exit 9; }
[ -s "$CFG_AA" ] || { echo "FATAL: no specs-config at $CFG_AA"; exit 9; }

AA=$SRC/gcc/config/aarch64/aarch64.h
EX=$SRC/gcc/expmed.h
LS=$SRC/gcc/lower-subreg.h
TR=$SRC/gcc/target-regs.cc

restore () { (cd "$SRC" && git checkout -- gcc/config/aarch64/aarch64.h \
		gcc/expmed.h gcc/lower-subreg.h gcc/target-regs.cc); }
trap 'restore' EXIT INT TERM

build () { # <tag>  -> rc of make, log kept
  sh "$S/eb-shell.sh" "cd $D/gcc && make -j8 multi-target-objs cc1" \
    > "$LOG/$1.build" 2>&1
  echo $?
}

runcc1 () { # <tag> [config] [input] -> rc, output in $LOG/<tag>.err
  cfg=${2:-$CFG}
  in=${3:-$IN}
  (cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$cfg" \
     "$in" -o "$LOG/$1.s") > "$LOG/$1.out" 2> "$LOG/$1.err"
  echo $?
}

say () { echo; echo "=== $*"; }

# ---------------------------------------------------------------- ARM 0
say "ARM 0  baseline: fixed tree must compile big.c and the witness stay quiet"
rc=$(build base)
[ "$rc" = 0 ] || { echo "FATAL: baseline build rc=$rc"; tail -20 "$LOG/base.build"; exit 1; }
rc=$(runcc1 base)
[ "$rc" = 0 ] || { echo "FATAL: baseline cc1 rc=$rc"; sed -n 1,5p "$LOG/base.err"; exit 1; }
echo "ARM 0 PASS: $(wc -c < "$LOG/base.s") bytes  md5 $(md5sum < "$LOG/base.s" | cut -c1-12)"

# ---------------------------------------------------------------- ARM 1
# The pair agrees on MAX_BITS_PER_WORD (every configured base says 64), so the
# divergence has to be SUPPLIED.  Giving aarch64 a 32-bit word makes
# `mt-aarch64/*.o' compute what xtensa or m68k would compute, while shared code
# keeps the primary's 64 -- the real defect, with a back end this build has.
say "ARM 1a  inject: aarch64 MAX_BITS_PER_WORD 64 -> 32, WITH the union fix"
sed -i 's/^#define MAX_BITS_PER_WORD\t64$/#define MAX_BITS_PER_WORD\t32/' "$AA"
grep -q '^#define MAX_BITS_PER_WORD	32$' "$AA" \
  || { echo "FATAL: injection did not take in $AA"; exit 1; }
rc=$(build inj1a)
[ "$rc" = 0 ] || { echo "FATAL: build rc=$rc with fix present"; tail -20 "$LOG/inj1a.build"; exit 1; }
# NON-VACUITY: the injection must actually have changed a measured value.
# Without this, an arm that silently failed to inject looks exactly like the
# fix working.
w=$(grep 'define MULTI_TARGET_UNION_MAX_BITS_PER_WORD' "$D/gcc/multi-target-reg-widths.h" | awk '{print $3}')
[ "$w" = 64 ] || { echo "FATAL: union width is $w, expected 64 (max of 64 and 32)"; exit 1; }
p=$(sh "$S/eb-shell.sh" "nm -S $D/gcc/mt-aarch64/reg-probe.o" \
    | awk '$4 == "mt_probe_max_bits_per_word" { print strtonum("0x" $2) - 1 }')
[ "$p" = 32 ] || { echo "FATAL: aarch64 probe measured '$p', expected 32; the injection did not reach the probe"; exit 1; }
echo "  aarch64's own MAX_BITS_PER_WORD is now 32, the union width is still 64"
rc=$(runcc1 inj1a "$CFG_AA" "$IN_AA")
[ "$rc" = 0 ] || { echo "FAIL: witness fired WITH the fix present:"; sed -n 1,5p "$LOG/inj1a.err"; exit 1; }
echo "ARM 1a PASS: divergence supplied, union absorbs it, cc1 clean"

say "ARM 1b  revert the fix (bounds back to the plain name) and require a FIRING"
for f in "$EX" "$LS"; do
  sed -i 's|^#include "multi-target-reg-widths.h"$|#include "multi-target-reg-widths.h"\n#undef MULTI_TARGET_UNION_MAX_BITS_PER_WORD\n#define MULTI_TARGET_UNION_MAX_BITS_PER_WORD MAX_BITS_PER_WORD|' "$f"
  grep -q '^#define MULTI_TARGET_UNION_MAX_BITS_PER_WORD MAX_BITS_PER_WORD$' "$f" \
    || { echo "FATAL: revert did not take in $f"; exit 1; }
done
rc=$(build inj1b)
[ "$rc" = 0 ] || { echo "FATAL: build rc=$rc"; tail -20 "$LOG/inj1b.build"; exit 1; }
rc=$(runcc1 inj1b "$CFG_AA" "$IN_AA")
if [ "$rc" = 0 ]; then
  echo "FAIL: the witness did NOT fire on a reverted bound -- it is not checking this."
  exit 1
fi
grep -q "back end 'aarch64' computes 'sizeof (struct target_expmed)'" "$LOG/inj1b.err" \
  || { echo "FAIL: it failed, but not by naming target_expmed and aarch64:"; \
       sed -n 1,3p "$LOG/inj1b.err"; exit 1; }
echo "ARM 1b PASS, by name:"
sed -n 1p "$LOG/inj1b.err"
restore

# ---------------------------------------------------------------- ARM 2
# The eleven entries added to the witness must be WIRED, not merely present:
# the descriptor initialiser is positional, so a mis-ordered field would
# compare two different structs' sizes and say nothing.  Perturb one reported
# size and require the diagnostic to name THAT struct.
for st in target_flag_state target_optabs; do
  say "ARM 2/$st  perturb only this struct's reported size; the message must name it"
  case $st in
    target_flag_state) pat="sizeof (class $st)";;
    *)                 pat="sizeof (struct $st)";;
  esac
  sed -i "s|^  $pat,$|  $pat + 8,|" "$TR"
  grep -q "^  $pat + 8,$" "$TR" \
    || { echo "FATAL: perturbation did not take in $TR"; exit 1; }
  rc=$(build "inj2-$st")
  [ "$rc" = 0 ] || { echo "FATAL: build rc=$rc"; tail -20 "$LOG/inj2-$st.build"; exit 1; }
  rc=$(runcc1 "inj2-$st")
  [ "$rc" != 0 ] || { echo "FAIL: no firing for $st -- that entry is inert"; exit 1; }
  grep -q "computes 'sizeof (struct $st)'" "$LOG/inj2-$st.err" \
    || { echo "FAIL: fired, but did not name $st:"; sed -n 1,3p "$LOG/inj2-$st.err"; exit 1; }
  echo "ARM 2/$st PASS, by name:"
  sed -n 1p "$LOG/inj2-$st.err"
  restore
done

# ---------------------------------------------------------------- ARM 3
say "ARM 3  restore everything and reconfirm the green"
restore
(cd "$SRC" && git diff --quiet -- gcc/config/aarch64/aarch64.h gcc/expmed.h \
   gcc/lower-subreg.h gcc/target-regs.cc) \
  || { echo "FATAL: the injected files are still modified after restore"; exit 1; }
rc=$(build final)
[ "$rc" = 0 ] || { echo "FATAL: final build rc=$rc"; tail -20 "$LOG/final.build"; exit 1; }
rc=$(runcc1 final)
[ "$rc" = 0 ] || { echo "FATAL: final cc1 rc=$rc"; sed -n 1,5p "$LOG/final.err"; exit 1; }
a=$(md5sum < "$LOG/base.s"); b=$(md5sum < "$LOG/final.s")
[ "$a" = "$b" ] || { echo "FATAL: output changed across the injection cycle"; exit 1; }
echo "ARM 3 PASS: restored, $(wc -c < "$LOG/final.s") bytes, md5 unchanged from ARM 0"
