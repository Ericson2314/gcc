#!/bin/sh
# mta7-targhook-matrix2.sh -- the targhook matrix, with the two arms
# `mta7-targhook-matrix.sh' lacks.
#
# The original instrument answers ONE question: "does this back end #define the
# macro that a `targhooks.cc' `#ifdef' reads?"  That over-counts in two
# independent ways, and both were measured rather than reasoned about:
#
#   1. SUBSTRING.  `grep "define PRINT_OPERAND"' matches
#      `#define PRINT_OPERAND_ADDRESS' and `#define PRINT_OPERAND_PUNCT_VALID_P'.
#      Every back end defining only the longer name was scored as a definer of
#      the shorter one.  Fixed with a word boundary.
#
#   2. NO HOOK ARM.  A back end that defines the macro AND already supplies the
#      corresponding `targetm' hook has no bug: shared code calls its hook and
#      never reaches the `targhooks.cc' `#else'.  rs6000 after `d65b829e7a8' is
#      exactly this shape, and the original matrix still lists all seven of its
#      pairs.  Without this arm the matrix cannot show its own fixes landing.
#
# So a pair is ACTIONABLE only when the back end defines the macro and supplies
# no hook.  Both arms only ever REMOVE pairs from the list, so over-eagerness
# on the definer side stays the safe direction.
#
# The hook-supply grep is deliberately over-broad in the same direction: any
# `#define TARGET_<HOOK>' anywhere under the back end's directory counts as
# supplied.  That can only move a pair OUT of the actionable set, i.e. it can
# under-report work to do but never invent work that is already done.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
cd "$SRC" || exit 9

WANT_ANCHOR=${WANT_ANCHOR:-47}
GOT=$(grep -c MULTI_TARGET gcc/Makefile.in)
[ "$GOT" = "$WANT_ANCHOR" ] || {
  echo "FATAL: anchor mismatch: gcc/Makefile.in has $GOT MULTI_TARGET, want $WANT_ANCHOR"
  exit 9
}

# macro -> the targetm hook that makes the `#ifdef' unreachable for a base.
# Derived by reading each `#ifdef' site in targhooks.cc, not from memory.
hook_for () {
  case $1 in
    GO_IF_LEGITIMATE_ADDRESS)      echo TARGET_LEGITIMATE_ADDRESS_P ;;
    ASM_OUTPUT_EXTERNAL_LIBCALL)   echo TARGET_ASM_EXTERNAL_LIBCALL ;;
    PRINT_OPERAND)                 echo TARGET_PRINT_OPERAND ;;
    PRINT_OPERAND_ADDRESS)         echo TARGET_PRINT_OPERAND_ADDRESS ;;
    PRINT_OPERAND_PUNCT_VALID_P)   echo TARGET_PRINT_OPERAND_PUNCT_VALID_P ;;
    FUNCTION_VALUE)                echo TARGET_FUNCTION_VALUE ;;
    LIBCALL_VALUE)                 echo TARGET_LIBCALL_VALUE ;;
    FUNCTION_VALUE_REGNO_P)        echo TARGET_FUNCTION_VALUE_REGNO_P ;;
    SECONDARY_INPUT_RELOAD_CLASS)  echo TARGET_SECONDARY_RELOAD ;;
    SECONDARY_OUTPUT_RELOAD_CLASS) echo TARGET_SECONDARY_RELOAD ;;
    MOVE_RATIO)                    echo '-' ;;   # no hook; read via get_move_ratio
    PROFILE_BEFORE_PROLOGUE)       echo TARGET_PROFILE_BEFORE_PROLOGUE ;;
    PREFERRED_RELOAD_CLASS)        echo TARGET_PREFERRED_RELOAD_CLASS ;;
    CLASS_MAX_NREGS)               echo TARGET_CLASS_MAX_NREGS ;;
    DWARF2_FRAME_INFO)             echo TARGET_DEBUG_UNWIND_INFO ;;
    DWARF2_DEBUGGING_INFO)         echo TARGET_DEBUG_UNWIND_INFO ;;
    *)                             echo '?' ;;
  esac
}

MACROS=$(sed -n 's/^#ifdef \([A-Z_][A-Z_0-9]*\)$/\1/p' gcc/targhooks.cc \
         | grep -v '^HAVE_' | sort -u)
[ -n "$MACROS" ] || { echo "FATAL: read no #ifdef macros from targhooks.cc"; exit 9; }

# NON-VACUITY, RUN FIRST.  Every macro must map to a known hook (or the
# explicit '-'), and the definer grep must find SOMETHING for at least one
# macro.  An all-empty read is otherwise indistinguishable from "no risk".
for m in $MACROS; do
  h=$(hook_for "$m")
  [ "$h" = '?' ] && { echo "FATAL: no hook mapping for $m -- targhooks.cc grew a new #ifdef"; exit 9; }
done

BES=$(for d in gcc/config/*/; do
        b=$(basename "$d")
        ls "$d" | grep -q '\.md$' && echo "$b"
      done | sort)
[ -n "$BES" ] || { echo "FATAL: found no back-end directories"; exit 9; }

defines () {  # $1 = back end dir, $2 = macro; word-bounded
  grep -rlE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$2\>" "gcc/config/$1/" > /dev/null
}
supplies () {  # $1 = back end dir, $2 = hook
  [ "$2" = '-' ] && return 1
  grep -rlE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$2\>" "gcc/config/$1/" > /dev/null
}

TOTDEF=0
for m in $MACROS; do
  for b in $BES; do
    defines "$b" "$m" && TOTDEF=$((TOTDEF + 1))
  done
done
[ "$TOTDEF" -gt 0 ] || { echo "FATAL: definer grep read NOTHING across $(echo $BES|wc -w) back ends"; exit 9; }
echo "non-vacuity: $TOTDEF (back end, macro) definitions read; anchor $GOT"
echo "macros: $(echo $MACROS | wc -w)   back ends: $(echo $BES | wc -w)"
echo

prim_def () { defines i386 "$1" || defines aarch64 "$1"; }

echo "=== ICE RISK (actionable): base defines macro, NEITHER primary does, base supplies NO hook"
for m in $MACROS; do
  prim_def "$m" && continue
  h=$(hook_for "$m")
  for b in $BES; do
    defines "$b" "$m" || continue
    supplies "$b" "$h" && continue
    echo "$b $m $h"
  done
done

echo
echo "=== ICE RISK (already answered): base defines macro, no primary does, but base HAS the hook"
for m in $MACROS; do
  prim_def "$m" && continue
  h=$(hook_for "$m")
  for b in $BES; do
    defines "$b" "$m" || continue
    supplies "$b" "$h" && echo "$b $m $h"
  done
done

echo
echo "=== SILENT RISK (actionable): a primary defines macro, base does NOT, base supplies NO hook"
for m in $MACROS; do
  prim_def "$m" || continue
  h=$(hook_for "$m")
  for b in $BES; do
    defines "$b" "$m" && continue
    supplies "$b" "$h" && continue
    echo "$b $m $h"
  done
done
