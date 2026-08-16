#!/bin/sh
# agent-a95a42fd940ce4d8e-whichsix.sh -- WHY THOSE SIX AND NOT THE OTHER FOUR,
# and the control side's real both-sided evidence.
#
# `-bothsided.sh' reported the four controls UNCHANGED and MISMATCHING their
# own headers.  The MISMATCH half is an artefact of that script: it reads the
# mode of the MEM loaded into the stack pointer in the EXPAND dump, and for a
# back end with its own `restore_stack_nonlocal' expander that insn is the
# EXPANDER'S OUTPUT, not the save-area MEM.  So it cannot see those four back
# ends' save-area mode at all, and its `wanted CDI / OI / TI' column is asking
# a question the dump does not answer.
#
# A CORRECTION I MADE AND THEN CAUGHT, RECORDED BECAUSE IT IS THE SHAPE THIS
# PROJECT KEEPS PAYING FOR.  The first version of this header claimed s390x's
# offset "moved 8 -> 16 between PRE and POST", which would have shown the
# controls changing underneath an unchanged mode letter.  It is FALSE: the PRE
# dump is offset 16 as well.  The 8 was read off the *aarch64* PRE row several
# steps earlier and attributed to s390x -- attribution by proximity, in an
# instrument written to replace an attribution-by-proximity bug.  ARM B below
# is what actually settles the control side, and it says something weaker and
# true: their emitted code does not move at all.
#
# ARM A -- the structural claim, checked against the `.md' files.
#   `explow.cc:1235' picks `gen_restore_stack_nonlocal' when the back end has
#   one and falls back to `gen_move_insn' otherwise.  Only the fallback puts
#   the save-area mode directly against the stack pointer's, so ONLY back ends
#   WITHOUT the pattern can ICE.  If the six that ICEd are exactly the ones
#   lacking it, the causal story is closed; if not, it is not.
#
# ARM B -- the control side, measured as CODEGEN rather than as a mode letter.
#   For the four that never ICEd, the question "did their answer change" is
#   answered by diffing the emitted assembly PRE vs POST on the same input.
#   A back end reading its own `STACK_SAVEAREA_MODE' for the first time should
#   MOVE; one that does not move is either already correct or not reached, and
#   the two are distinguished by the offsets in the dump.
set -u
PRE=${PRE:-/tmp/b-a95a42fd940ce4d8e}
POST=${POST:-/tmp/b-a95a42fd940ce4d8e-post}
SRC=$(cat "$POST/MY-SRC")
O=${O:-/tmp/w-agent-a95a42fd940ce4d8e/whichsix}
mkdir -p "$O"

echo "== ARM A: which back ends define their own restore_stack_nonlocal"
HAVE=$(cd "$SRC/gcc/config" && grep -rl 'define_expand "restore_stack_nonlocal"' . \
       | sed 's|^\./||; s|/.*||' | sort -u | paste -sd' ')
echo "   HAVE: $HAVE"
echo "   the six that ICEd: alpha arc arm avr mips or1k"
bad=0
for b in alpha arc arm avr mips or1k; do
  case " $HAVE " in *" $b "*) echo "   *** $b HAS the pattern -- story broken"; bad=1 ;; esac
done
for b in i386 aarch64 riscv s390; do
  case " $HAVE " in *" $b "*) ;; *) echo "   *** $b LACKS it -- story broken"; bad=1 ;; esac
done
[ "$bad" = 0 ] && echo "   HOLDS: the six that ICE are exactly the ones with no such expander,
   and the four controls are exactly the ones that have one."

echo
echo "== ARM B: control-side codegen, PRE vs POST, same input"
printf '%-28s %-12s %-12s %s\n' TARGET PRE-md5 POST-md5 VERDICT
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu \
         riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  m=''
  for side in PRE POST; do
    eval "d=\$$side"
    V=$(cat "$(cat "$d/MY-SRC")/gcc/BASE-VER"); S=$(cat "$d/MY-SRC")
    c="$d/lib/gcc/$V/$t/specs-config"
    w="$O/$side-$t"; rm -rf "$w"; mkdir -p "$w"
    cp "$S/gcc/testsuite/gcc.c-torture/compile/pr21728.c" "$w/in.c"
    ( cd "$w" && "$d/gcc/cc1" -quiet -nostdinc -O1 -ftarget-config="$c" \
        in.c -o out.s ) > "$w/out" 2> "$w/err"
    if [ -s "$w/out.s" ]; then h=$(md5sum < "$w/out.s" | cut -c1-12); else h=NO-OUTPUT; fi
    m="$m $h"
  done
  set -- $m
  [ "$1" = "$2" ] && v='IDENTICAL -- no regression; does NOT prove its mode is right' \
                  || v='MOVED'
  printf '%-28s %-12s %-12s %s\n' "$t" "$1" "$2" "$v"
done
echo
echo "WHAT 'IDENTICAL' DOES AND DOES NOT ESTABLISH."
echo "  DOES: the fix regresses none of the four on this input, byte for byte."
echo "  DOES NOT: that their save-area mode is now correct.  Each consumes the"
echo "  MEM through its own restore_stack_nonlocal expander, which adjusts the"
echo "  address itself, so the incoming mode is largely inert there -- which is"
echo "  also why they never ICEd.  Establishing THEIR correctness needs a test"
echo "  that reads the save area's SIZE, and this input does not."
