#!/bin/sh
# agent-ad6a5c1d2539f5e18-vbitcensus.sh -- what does EACH back end's own header
# chain say about `TARGET_PTRMEMFUNC_VBIT_LOCATION'?
#
# WHY A CENSUS AND NOT A `git grep'.  Six back ends spell the macro; the other
# 41 take `defaults.h:1023's `FUNCTION_BOUNDARY'-derived answer, and
# `FUNCTION_BOUNDARY' itself may arrive through `elfos.h' or another shared
# header rather than from `config/<base>/'.  A directory grep answers "who
# spells it", which is a DIFFERENT question from "what does this base get",
# and it is the second one that decides the ABI.  So this asks the real
# preprocessor, over each base's real `tm-<base>.h', exactly as
# tgh-hdrmatrix.sh does for the targhook matrix.
#
# THE CENSUS IS INDEPENDENT OF THE FIX BY CONSTRUCTION, WHICH IS THE POINT.
# `multi-target-macros.h''s redirection block is skipped when `__cplusplus' is
# undefined, and this preprocesses a `.c'.  So it reads the SUPPLY side --
# what each base's headers say -- at both PRE and POST, and the two runs must
# agree.  A difference here would mean the fix changed what a back end asks
# for, which it must not; it changes only who answers.
#
# NULL-RESULT ARM.  "cpp produced nothing" and "the macro is absent" are the
# same empty grep, so a base whose dump is empty is UNREADABLE, counted
# separately, and makes the script exit nonzero.  A base that IS readable and
# yet yields no value for the macro is IMPOSSIBLE (defaults.h defines it
# unconditionally when nobody else has) and is reported as a FATAL finding
# rather than folded into a column.
#
# usage: agent-ad6a5c1d2539f5e18-vbitcensus.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
[ -d "$D/gcc" ] || { echo "FATAL: $D/gcc missing"; exit 9; }

BASES=""
for d in "$SRC"/gcc/config/*/; do
  b=$(basename "$d")
  ls "$d" | grep -q '\.md$' || continue
  [ -f "$D/gcc/tm-$b.h" ] && BASES="$BASES $b"
done
BASES=$(echo $BASES | tr ' ' '\n' | sort)
[ -n "$BASES" ] || { echo "FATAL: no tm-<base>.h in $D/gcc"; exit 9; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' 0

npfn=0; ndelta=0; nother=0; nunread=0; nbase=0
printf '%-12s %-22s %-8s %s\n' BASE VBIT FUNC_BND SPELLS-IT-ITSELF
for b in $BASES; do
  nbase=$((nbase + 1))
  : > "$WORK/e.c"
  cpp -dM -I"$D/gcc" -I"$SRC/gcc" -I"$SRC/gcc/config" -I"$SRC/include" \
      -I"$D/gcc/include" -DIN_GCC -imacros "$D/gcc/tm-$b.h" "$WORK/e.c" \
      > "$WORK/$b.m" 2> "$WORK/$b.err"
  if [ ! -s "$WORK/$b.m" ]; then
    printf '%-12s %-22s %-8s %s\n' "$b" UNREADABLE - -
    sed -n '1,3p' "$WORK/$b.err" | sed 's/^/    /'
    nunread=$((nunread + 1)); continue
  fi
  v=$(sed -n 's/^#define TARGET_PTRMEMFUNC_VBIT_LOCATION //p' "$WORK/$b.m")
  fb=$(sed -n 's/^#define FUNCTION_BOUNDARY //p' "$WORK/$b.m")
  own=no
  grep -rqw 'define TARGET_PTRMEMFUNC_VBIT_LOCATION' "$SRC/gcc/config/$b/" \
    2>/dev/null && own=yes
  case "$v" in
    *ptrmemfunc_vbit_in_pfn*ptrmemfunc_vbit_in_delta*)
      # defaults.h's conditional form, unresolved by `cpp -dM'.  Decide it from
      # this base's own FUNCTION_BOUNDARY -- the same arithmetic the compiler
      # does.  Printed as `via-FB' so it is never confused with a back end that
      # states its answer outright.
      #
      # EIGHT BACK ENDS HAVE AN OPTION-DEPENDENT `FUNCTION_BOUNDARY' (csky,
      # mcore, nds32, riscv, rx, sh, v850, and arm's `FUNCTION_BOUNDARY_P'),
      # and that is the case this arm exists to decide rather than to skip.
      # The macro's VALUE varies; the only thing that matters here is which
      # side of `2 * BITS_PER_UNIT' it lands on.  So take every integer literal
      # in the expression and ask whether they ALL agree.  If they do, the vbit
      # answer is invariant even though the boundary is not, which is exactly
      # the precondition target-cdata.h requires of a field.  If they do not,
      # that is a real finding and this refuses rather than picking one.
      case "$fb" in
        '') k="via-FB(?empty)"; nother=$((nother + 1)) ;;
        *[!0-9]*)
          # WORD-BOUNDED literals only.  A bare `tr -cs 0-9' scrapes the digits
          # out of IDENTIFIERS -- `RX100', `RX200', `CK801', `NDS32_ALIGN_P' --
          # and rx is the case that proves it matters: its real arms are 4 and
          # 8 (both `delta'), and the scraped 100/200 drag it across the 16
          # boundary and produce a mixed verdict from a correct expression.
          # Same substring family as `grep "define PRINT_OPERAND"' matching
          # `PRINT_OPERAND_ADDRESS'.
          lits=$(echo "$fb" | grep -oE '(^|[^A-Za-z0-9_])[0-9]+' \
                 | grep -oE '[0-9]+')
          hi=0; lo=0
          for L in $lits; do
            if [ "$L" -ge 16 ]; then hi=1; else lo=1; fi
          done
          if [ -z "$lits" ]; then k="via-FB(?no-literal:$fb)"; nother=$((nother + 1))
          elif [ "$hi$lo" = 10 ]; then k="via-FB pfn   [cond]"; npfn=$((npfn + 1))
          elif [ "$hi$lo" = 01 ]; then k="via-FB delta [cond]"; ndelta=$((ndelta + 1))
          else k="via-FB(?varies:$fb)"; nother=$((nother + 1)); fi ;;
        *) if [ "$fb" -ge 16 ]; then k="via-FB pfn"; npfn=$((npfn + 1))
           else k="via-FB delta"; ndelta=$((ndelta + 1)); fi ;;
      esac ;;
    *ptrmemfunc_vbit_in_pfn*)   k=pfn;   npfn=$((npfn + 1)) ;;
    *ptrmemfunc_vbit_in_delta*) k=delta; ndelta=$((ndelta + 1)) ;;
    '') echo "FATAL: $b is readable and defines no TARGET_PTRMEMFUNC_VBIT_LOCATION"
        echo "  (defaults.h defines it unconditionally; this cannot happen)"
        exit 9 ;;
    *) k="OTHER:$v"; nother=$((nother + 1)) ;;
  esac
  printf '%-12s %-22s %-8s %s\n' "$b" "$k" "${fb:--}" "$own"
done

echo
echo "bases=$nbase  pfn=$npfn  delta=$ndelta  other=$nother  unreadable=$nunread"
[ "$nunread" = 0 ] || { echo "FATAL: $nunread bases unreadable"; exit 9; }
[ "$nother" = 0 ] || { echo "FATAL: $nother bases with an unclassified value"; exit 9; }
# CONTROL.  If this census could not distinguish the two conventions it would
# print one column and look like agreement.  Both must be non-empty.
[ "$npfn" -gt 0 ] && [ "$ndelta" -gt 0 ] \
  || { echo "FATAL control: the census found only ONE convention over $nbase bases;
  it cannot tell agreement from a broken matcher"; exit 9; }
echo "control ok: both conventions present, so the matcher can tell them apart"
