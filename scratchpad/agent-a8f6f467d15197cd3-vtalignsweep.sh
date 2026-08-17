#!/bin/sh
# agent-a8f6f467d15197cd3-vtalignsweep.sh -- BOTH-SIDED over the 45 targets
# with a real cross assembler: did `TARGET_VTABLE_ENTRY_ALIGN' stop being the
# primary's?
#
# THE PREDICTION IS WRITTEN DOWN BEFORE THE RUN, AND IT IS NOT "3 TARGETS
# CHANGE".  That is the obvious expectation and it is wrong, for a reason that
# is the whole point of this conversion:
#
#   PRE  every base gets `defaults.h:972's `POINTER_SIZE', which on this
#        branch is ALREADY `mt_pointer_size ()' -- the SELECTED base's own
#        pointer size, not i386's.  So PRE is not "i386's answer for
#        everyone"; it is "every base's own POINTER_SIZE".
#   POST a definer gets its own literal; a non-definer still gets
#        `POINTER_SIZE'.
#
# so a target only moves if its literal DIFFERS from its own POINTER_SIZE:
#
#   ia64      defines 64, POINTER_SIZE 64 (TARGET_ILP32 is 0 for ia64-elf)
#             -> EQUAL, must NOT move
#   msp430    defines 16, POINTER_SIZE 16 without `-mlarge' (20 with it)
#             -> EQUAL at default options, must NOT move here
#   avr       defines  8, POINTER_SIZE 16
#             -> DIFFERS, must move.  THE ONLY EXPECTED MOVER.
#
# A run in which ia64 or msp430 moves at default options is a FINDING, not a
# success -- it would mean the conversion changed an answer that was already
# right.  A run in which avr does NOT move means the conversion did nothing.
# Both are named below so neither can be read as a pass.
#
# msp430's `-mlarge' arm is run SEPARATELY and is where msp430's defect is
# actually observable: PRE gives 20 (its own comment says so, and 20 is not an
# alignment), POST gives 16.
#
# THREE ARMS, and the second and third are what make the first mean anything:
#  1. PRE vs POST on the whole `.s'.
#  2. THE CONTROL OBJECT `mt_va_control' -- no vtable, so its directives must
#     be identical PRE and POST on EVERY target.  If it moves, VOID.
#  3. THE PREDICTION -- each target is scored against the table above, not
#     against "it moved".  Arm 1 alone would accept a move to a wrong value.
#
# NULL-RESULT ARM, FIRST AND FATAL.  A missing `cc1plus', a target with no
# specs-config, an empty `.s' and a compiler that emitted nothing produce the
# same empty grep.  Each fails BY NAME, and the script refuses to print a
# verdict if it scored zero targets.
#
# usage: PRE=<dir> POST=<dir> agent-a8f6f467d15197cd3-vtalignsweep.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
PRE=${PRE:?PRE build dir}
POST=${POST:?POST build dir}
IN=$S/agent-a8f6f467d15197cd3-vtalign.cc
[ -s "$IN" ] || { echo "FATAL: no $IN"; exit 9; }

for D in "$PRE" "$POST"; do
  [ -x "$D/gcc/cc1plus" ] || { echo "FATAL: no $D/gcc/cc1plus.  A language never
  enabled and a language passing everything give the same empty failure list,
  so this refuses rather than scoring zero."; exit 9; }
done

verof () { set -- "$1"/lib/gcc/*/; [ -d "$1" ] || return 1; basename "$1"; }
VPRE=$(verof "$PRE")   || { echo "FATAL: no $PRE/lib/gcc/<ver>/ -- target-specs has not run"; exit 9; }
VPOST=$(verof "$POST") || { echo "FATAL: no $POST/lib/gcc/<ver>/ -- target-specs has not run"; exit 9; }
echo "PRE  $PRE (gcc $VPRE)"
echo "POST $POST (gcc $VPOST)"

W=$(mktemp -d); trap 'rm -rf "$W"' 0
ls "$PRE/lib/gcc/$VPRE"   > "$W/pre.t"  2>/dev/null || : > "$W/pre.t"
ls "$POST/lib/gcc/$VPOST" > "$W/post.t" 2>/dev/null || : > "$W/post.t"
BOTH=$(comm -12 "$W/pre.t" "$W/post.t")
ONLY=$(comm -3 "$W/pre.t" "$W/post.t" | tr -d '\t' | grep . || true)
[ -z "$ONLY" ] || echo "WARNING: targets in only one build dir: $ONLY"

emit () {   # emit <builddir> <ver> <target> <out> <extraflags>
  ( cd "$1/gcc" && ./cc1plus -quiet -nostdinc -O2 $5 \
      -ftarget-config="$1/lib/gcc/$2/$3/specs-config" "$IN" -o "$4" ) \
    > "$4.msg" 2>&1
}

# The alignment directive in front of a named object.  Directive names are NOT
# a closed set here either (`.align', `.p2align', `.balign', and ia64 uses
# `.align' with a byte count while x86 uses `.p2align' with a log2), so the
# extractor takes EVERY directive line between the previous label and the
# object's own label rather than matching a name it guessed.
prologue () {   # prologue <file> <symbol>
  awk -v sym="$2" '
    $0 ~ ("^[ \t]*" sym ":") { print "LABEL"; for (i = 1; i <= n; i++) print buf[i]; exit }
    /^[ \t]*\./ { buf[++n] = $0; next }
    { n = 0 }
  ' "$1"
}

EXTRA=${MT_VA_FLAGS:-}
LBL=${MT_VA_LABEL:-default}
printf '%-28s %-9s %s\n' TARGET VERDICT 'note'
nscored=0; nchanged=0; nsame=0; nfail=0; nvoid=0
: > "$W/changed"
for T in $BOTH; do
  emit "$PRE"  "$VPRE"  "$T" "$W/$T.pre.s"  "$EXTRA"
  emit "$POST" "$VPOST" "$T" "$W/$T.post.s" "$EXTRA"
  if [ ! -s "$W/$T.pre.s" ] || [ ! -s "$W/$T.post.s" ]; then
    m=$(head -1 "$W/$T.pre.s.msg" 2>/dev/null | cut -c1-60)
    printf '%-28s %-9s %s\n' "$T" CC1PLUS-FAIL "$m"
    nfail=$((nfail + 1)); continue
  fi
  nscored=$((nscored + 1))
  # ARM 2, the control, FIRST: if it moved, this target's verdict is void.
  prologue "$W/$T.pre.s"  mt_va_control > "$W/c.pre"
  prologue "$W/$T.post.s" mt_va_control > "$W/c.post"
  if ! cmp -s "$W/c.pre" "$W/c.post"; then
    printf '%-28s %-9s %s\n' "$T" VOID 'CONTROL MOVED -- not measuring this macro'
    nvoid=$((nvoid + 1)); continue
  fi
  if cmp -s "$W/$T.pre.s" "$W/$T.post.s"; then
    printf '%-28s %-9s\n' "$T" identical
    nsame=$((nsame + 1))
  else
    d=$(diff "$W/$T.pre.s" "$W/$T.post.s" | grep -c '^[<>]')
    printf '%-28s %-9s %s\n' "$T" CHANGED "$d differing lines"
    diff "$W/$T.pre.s" "$W/$T.post.s" | grep '^[<>]' | head -6 | sed 's/^/      /'
    echo "$T" >> "$W/changed"
    nchanged=$((nchanged + 1))
  fi
done

echo
echo "arm=$LBL flags='$EXTRA'"
echo "targets scored: $nscored   changed=$nchanged  byte-identical=$nsame  cc1plus-failed=$nfail  VOID=$nvoid"
[ "$nscored" -gt 0 ] || { echo "REFUSE: scored ZERO targets -- there is no verdict here"; exit 9; }

# ARM 3: the prediction, checked by name in BOTH directions.
echo
echo "-- the prediction, checked by name:"
CHANGED=$(cat "$W/changed" 2>/dev/null | tr '\n' ' ')
check () {   # check <target> <must-move: yes|no> <why>
  case " $CHANGED " in
    *" $1 "*) got=moved ;;
    *)        got=still ;;
  esac
  want=$([ "$2" = yes ] && echo moved || echo still)
  if [ "$got" = "$want" ]; then printf '   OK      %-28s %s (%s)\n' "$1" "$got" "$3"
  else printf '   FINDING %-28s %s, predicted %s (%s)\n' "$1" "$got" "$want" "$3"; fi
}
if [ "$LBL" = default ]; then
  check avr-unknown-elf      yes 'defines 8, its POINTER_SIZE is 16 -- the only expected mover'
  check ia64-unknown-elf     no  'defines 64 and its POINTER_SIZE is 64 -- already right'
  check msp430-unknown-elf   no  'defines 16 and its POINTER_SIZE is 16 without -mlarge'
else
  check msp430-unknown-elf   yes 'defines 16, POINTER_SIZE is 20 under -mlarge -- 20 is not an alignment'
fi
[ "$nvoid" = 0 ] || { echo "EXIT 9: $nvoid target(s) VOID"; exit 9; }
