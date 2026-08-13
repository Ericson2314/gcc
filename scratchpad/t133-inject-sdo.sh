#!/bin/sh
# #133 -- turn the STACK_DYNAMIC_OFFSET redirect OFF and back ON, in place, in
# the SAME build dir.  awk, not python3 (python3 is not in the dev shell and an
# injection that silently does nothing scores every downstream reading against
# the UNMODIFIED compiler).
#
# OFF restores exactly what function.cc used to do: the generic ladder,
# `#ifndef'-guarded, evaluated in function.cc's own translation unit -- i.e.
# with the PRIMARY's tm.h, which is the bug.
#
# Both directions ASSERT the state they produced rather than their exit status:
#   off  -> function.cc must spell STACK_DYNAMIC_OFFSET and must NOT spell
#           mt_stack_dynamic_offset
#   on   -> the exact reverse
# and each refuses to run twice or to restore with no saved original.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
F="$S/../gcc/function.cc"
SAVE="/tmp/t133-function.cc.orig"
CALL_ON='  return mt_stack_dynamic_offset (current_function_decl);'
CALL_OFF='  return STACK_DYNAMIC_OFFSET (current_function_decl);'
ANCHOR="/\* \`STACK_DYNAMIC_OFFSET' USED TO BE DEFINED HERE"

n_on ()  { grep -c 'return mt_stack_dynamic_offset' "$F" || true; }
n_off () { grep -c 'MT_INJECTED_OFF' "$F" || true; }

case "${1:-}" in
  off)
    [ -e "$SAVE" ] && { echo "REFUSE: $SAVE exists -- already injected"; exit 9; }
    [ "$(n_on)" -ge 1 ] || { echo "REFUSE: function.cc does not call mt_stack_dynamic_offset"; exit 9; }
    cp "$F" "$SAVE"
    awk -v anchor="$ANCHOR" -v call_on="$CALL_ON" -v call_off="$CALL_OFF" '
      index ($0, "STACK_DYNAMIC_OFFSET'"'"' USED TO BE DEFINED HERE") && !done_block {
        print "/* MT_INJECTED_OFF -- the pre-#133 shared ladder, restored verbatim. */";
        print "#ifndef STACK_DYNAMIC_OFFSET";
        print "#ifdef INCOMING_REG_PARM_STACK_SPACE";
        print "#define STACK_DYNAMIC_OFFSET(FNDECL)\t\\";
        print "((ACCUMULATE_OUTGOING_ARGS\t\t\t\t\t\t      \\";
        print "  ? (crtl->outgoing_args_size\t\t\t\t      \\";
        print "     + (OUTGOING_REG_PARM_STACK_SPACE ((!(FNDECL) ? NULL_TREE : TREE_TYPE (FNDECL))) ? 0 \\";
        print "\t\t\t\t\t       : INCOMING_REG_PARM_STACK_SPACE (FNDECL))) \\";
        print "  : 0) + (STACK_POINTER_OFFSET))";
        print "#else";
        print "#define STACK_DYNAMIC_OFFSET(FNDECL)\t\\";
        print "  ((ACCUMULATE_OUTGOING_ARGS ? crtl->outgoing_args_size : poly_int64 (0)) \\";
        print " + (STACK_POINTER_OFFSET))";
        print "#endif";
        print "#endif";
        done_block = 1;
      }
      $0 == call_on { print call_off; next }
      { print }
    ' "$SAVE" > "$F.tmp"
    mv "$F.tmp" "$F"
    [ "$(n_on)" -eq 0 ] || { echo "FAIL: mt_stack_dynamic_offset still present after off"; exit 9; }
    [ "$(n_off)" -eq 1 ] || { echo "FAIL: injected block not present exactly once"; exit 9; }
    grep -q "$CALL_OFF" "$F" || { echo "FAIL: macro call not installed"; exit 9; }
    echo "OFF installed: mt_ refs=$(n_on)  injected blocks=$(n_off)"
    ;;
  on)
    [ -e "$SAVE" ] || { echo "REFUSE: no $SAVE to restore from"; exit 9; }
    cp "$SAVE" "$F"; rm -f "$SAVE"
    [ "$(n_off)" -eq 0 ] || { echo "FAIL: injected block survived restore"; exit 9; }
    [ "$(n_on)" -ge 1 ] || { echo "FAIL: mt_stack_dynamic_offset absent after restore"; exit 9; }
    echo "ON restored: mt_ refs=$(n_on)  injected blocks=$(n_off)"
    ;;
  *) echo "usage: $0 off|on"; exit 2;;
esac
