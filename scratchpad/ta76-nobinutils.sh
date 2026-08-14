#!/bin/sh
# #170 -- the FOUR back ends with no cross binutils anywhere in this nixpkgs:
# sparc64, ia64, visium, xtensa.  Measured: of 27,157 top-level nixpkgs
# attributes, ZERO match sparc, ia64, visium or xtensa -- against aarch64=1 and
# riscv=2 as the non-vacuity control, so the zero is the package set's and not
# the query's.
#
# WHAT THIS SCRIPT DELIBERATELY DOES, AND WHY IT IS NOT THE SECTION-5 TRAP.
# It runs the target-specs probe for these four against the BUILD MACHINE'S own
# `as' -- which is precisely the fallback PRINCIPLES section 5 says produces a
# file that NAMES the target while DESCRIBING x86_64, and passes every name-
# and path-based check.  The difference is that here it is asked for on
# purpose, by an explicit --with-as, and the resulting config is used to answer
# EXACTLY ONE question:
#
#     does cc1 reach codegen for this back end at all, or does it ICE first?
#
# The config's ANSWERS are x86_64's and are not trusted for anything.  What it
# supplies is a well-formed config file, so that "cc1 refuses to start without
# -ftarget-config=" cannot be mistaken for "this back end cannot compile".
# ASSEMBLES and MACHINE stay UNKNOWN for all four and no amount of output here
# can promote them: there is no assembler to be right about.
#
# The x86-token arm IS meaningful under a fallback config, because the config
# describes assembler capabilities, not the instruction set: if visium's output
# contains %rsp that is the back end, not the probe.
#
# usage: t170-nobinutils.sh <builddir> <snapshot> <toolroot>
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; SRC=${2:?snapshot}; ROOT=${3:?tool root}
case "$D" in
  */b-a76e996f6ef44dca5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
HOSTBIN=$ROOT/x86_64-pc-linux-gnu
[ -x "$HOSTBIN/as" ] || { echo "FATAL: no host as at $HOSTBIN"; exit 9; }
OUT=$D/ta9f-nobin; mkdir -p "$OUT"
IN=$SRC/scratchpad/t170-small.c

for t in sparc64-unknown-linux-gnu ia64-unknown-elf visium-unknown-elf xtensa-unknown-elf; do
  echo "=== $t  (FALLBACK CONFIG -- x86_64's answers under $t's name)"
  sh "$S/eb-shell.sh" "cd $D && make configure-target-specs-$t \
      TOOLS_DIR_FOR_$t=$HOSTBIN \
      TARGET_SPECS_FLAGS_FOR_$t='--with-as=$HOSTBIN/as --with-ld=$HOSTBIN/ld \
        --with-nm=$HOSTBIN/nm --with-objdump=$HOSTBIN/objdump \
        --with-readelf=$HOSTBIN/readelf'" > "$OUT/$t.mk" 2>&1
  cfg=$(ls "$D"/lib/gcc/*/"$t"/specs-config 2>/dev/null | head -1)
  if [ -z "$cfg" ]; then
    echo "  no specs-config even with the fallback: $(grep -m1 'Error\|error' "$OUT/$t.mk" | cut -c1-100)"
    continue
  fi
  for O in -O0 -O2; do
    ( cd "$D/gcc" && ./cc1 -quiet -nostdinc $O -ftarget-config="$cfg" \
        "$IN" -o "$OUT/$t$O.s" ) > /dev/null 2> "$OUT/$t$O.err"
    r=$?
    if [ $r = 0 ] && [ -s "$OUT/$t$O.s" ]; then
      if grep -Eqw '%rsp|%rbp|%rax|%eax|%edi|leaq|movq|pushq' "$OUT/$t$O.s"; then
        leak="X86-TOKENS-PRESENT"
      else
        leak="no x86 tokens"
      fi
      echo "  $O: EMITS $(wc -c < "$OUT/$t$O.s") bytes, $leak; ASSEMBLES/MACHINE stay UNKNOWN (no $t assembler exists)"
    else
      echo "  $O: rc=$r  $(grep -m1 'internal compiler error\|error:' "$OUT/$t$O.err" | cut -c1-110)"
    fi
  done
done
