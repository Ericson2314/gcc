#!/bin/sh
# #131 -- guards for the three macros this task converted:
#   INCOMING_FRAME_SP_OFFSET, DEFAULT_INCOMING_FRAME_SP_OFFSET, FUNCTION_MODE.
#
# ARM 0 runs FIRST and asserts the CONTENT by name, because "the file changed"
# and "the build succeeded" both pass on a redirect that was never written.
# ARM 2 is the one that matters: it reads the VALUES out of the two per-base
# objects, both sides, so "everyone now gets the same new answer" is
# distinguishable from "each base gets its own".
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b131}
P=0; F=0
ok   () { P=$((P+1)); echo "PASS  $1"; }
bad  () { F=$((F+1)); echo "FAIL  $1"; }
chk  () { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1: got [$2] want [$3]"; fi; }
has  () { if grep -q "$2" "$3"; then ok "$1"; else bad "$1 -- not found: $2"; fi; }
hasnt() { if grep -q "$2" "$3"; then bad "$1 -- present: $2"; else ok "$1"; fi; }

echo "=== ARM 0: the redirects and thunks exist, BY NAME (runs first)"
D=$SRC/gcc/defaults.h
has "defaults.h #undef INCOMING_FRAME_SP_OFFSET"          '^#undef INCOMING_FRAME_SP_OFFSET$' "$D"
has "defaults.h redirect INCOMING_FRAME_SP_OFFSET"        '^#define INCOMING_FRAME_SP_OFFSET (mt_incoming_frame_sp_offset ())$' "$D"
has "defaults.h #undef DEFAULT_INCOMING_FRAME_SP_OFFSET"  '^#undef DEFAULT_INCOMING_FRAME_SP_OFFSET$' "$D"
has "defaults.h redirect DEFAULT_INCOMING_FRAME_SP_OFFSET" '^#define DEFAULT_INCOMING_FRAME_SP_OFFSET (mt_default_incoming_frame_sp_offset ())$' "$D"
has "defaults.h #undef FUNCTION_MODE"                     '^#undef FUNCTION_MODE$' "$D"
has "defaults.h redirect FUNCTION_MODE"                   '^#define FUNCTION_MODE (mt_function_mode ())$' "$D"
C=$SRC/gcc/target-cumargs.cc
has "per-base thunk incoming_frame_sp_offset"         'mt_base_incoming_frame_sp_offset' "$C"
has "per-base thunk default_incoming_frame_sp_offset" 'mt_base_default_incoming_frame_sp_offset' "$C"
has "per-base thunk function_mode"                    'mt_base_function_mode' "$C"
has "target-cumargs.cc includes function.h for cfun"  '^#include "function.h"$' "$C"

echo
echo "=== ARM 1: the ORDER of the three new members matches the table"
# A brace initialiser is positional.  Two function pointers of the same shape
# swapped here compile clean and answer each other's question -- #130 recorded
# the sibling failure where a `#define' silently renamed a struct member.
ord_h=$(grep -o '(\*[a-z_]*) (void);' "$SRC/gcc/target-frame.h" \
        | tr -d '(*);' | sed 's/ void//' \
        | grep -E '^(function_mode|incoming_frame_sp_offset|default_incoming_frame_sp_offset)$' | tr '\n' ' ')
# The INITIALISER, not the definitions: a brace initialiser is positional, and
# the order the thunks happen to be defined in says nothing about it.
ord_c=$(awk '/target_frame_desc mt_base_frame = \{/{f=1;next} f&&/^\};/{exit} f' "$C" \
        | grep -o 'mt_base_[a-z_]*' | sed 's/^mt_base_//' \
        | grep -E '^(function_mode|incoming_frame_sp_offset|default_incoming_frame_sp_offset)$' | tr '\n' ' ')
echo "  header order : $ord_h"
echo "  table order  : $ord_c"
chk "the initialiser order MATCHES the declaration order" "$ord_c" "$ord_h"
if [ -z "$ord_h" ] || [ -z "$ord_c" ]; then
  bad "ARM 1 read nothing from one side -- an all-empty read looks exactly like a match"
else
  ok "ARM 1 non-vacuity: both sides non-empty"
fi

echo
echo "=== ARM 2: THE VALUES, read out of the two per-base OBJECTS (both sides)"
# These thunks are `static', so the symbol is local and `objdump
# --disassemble=NAME' finds nothing -- an instrument that scores 0 for every
# arm looks exactly like "the leak is gone".  Hence: disassemble the whole
# object with -C and cut the block under each demangled label, and REFUSE to
# score when the cut is empty.
for base in i386 aarch64; do
  o=$B/gcc/target-cumargs-$base.o
  [ -f "$o" ] || { bad "no $o"; continue; }
  sh "$S/eb-shell.sh" "cd $B/gcc && objdump -dC $o" > "$B/t131-dis-$base.txt" 2> /dev/null
  for fn in incoming_frame_sp_offset default_incoming_frame_sp_offset function_mode; do
    dis=$(awk -v f="<mt_base_$fn()>:" 'index ($0, f) {g=1;next} g&&/^$/{exit} g' "$B/t131-dis-$base.txt" \
          | sed 's/^[^\t]*\t[^\t]*\t//' | tr '\n' ';')
    if [ -z "$dis" ]; then
      bad "$base $fn: the disassembly cut is EMPTY (non-vacuity floor)"
    else
      echo "  $base $fn -> $dis"
      P=$((P+1))
    fi
  done
done
# The two bases must not agree on function_mode, or this is "everyone now gets
# the same new answer" rather than "each base gets its own".
fm_i=$(awk -v f='<mt_base_function_mode()>:' 'index ($0, f) {g=1;next} g&&/^$/{exit} g' "$B/t131-dis-i386.txt"    | grep -o '\$0x[0-9a-f]*' | head -1)
fm_a=$(awk -v f='<mt_base_function_mode()>:' 'index ($0, f) {g=1;next} g&&/^$/{exit} g' "$B/t131-dis-aarch64.txt" | grep -o '\$0x[0-9a-f]*' | head -1)
# 0x18 = 24 = QImode and 0x1b = 27 = DImode in the UNIONED mode vocabulary,
# which is what these objects are compiled against -- not upstream's per-target
# numbering.  The first draft of this arm asserted 0x2 for QImode, from memory
# of a single-target build, and FAILED; the number is read from the union.
# What makes the pair non-vacuous is that they DIFFER.
chk "i386's FUNCTION_MODE thunk returns QImode (24)"    "$fm_i" '$0x18'
chk "aarch64's FUNCTION_MODE thunk returns DImode (27)" "$fm_a" '$0x1b'
if [ "$fm_i" = "$fm_a" ]; then
  bad "both bases return the SAME mode -- that is 'everyone gets one new answer'"
else
  ok "the two bases DISAGREE, which is the whole point ($fm_i vs $fm_a)"
fi
# And the sp offsets, both sides: aarch64's must be a constant zero, i386's
# must be a real computation over cfun.  A pair that both read 0 would be the
# union's answer leaking rather than each base's own.
for fn in incoming_frame_sp_offset default_incoming_frame_sp_offset; do
  a=$(awk -v f="<mt_base_$fn()>:" 'index ($0, f) {g=1;next} g&&/^$/{exit} g' "$B/t131-dis-aarch64.txt" | grep -c 'xor    %eax,%eax')
  i=$(awk -v f="<mt_base_$fn()>:" 'index ($0, f) {g=1;next} g&&/^$/{exit} g' "$B/t131-dis-i386.txt"    | grep -c 'add    \$0x8,%rax')
  chk "aarch64 $fn is a constant zero" "$a" "1"
  chk "i386 $fn still computes its own 8" "$i" "1"
done

echo
echo "=== ARM 3: THE EMITTED CFI (the artefact, not the exit status)"
A=$B/after2-add-aarch64-unknown-linux-gnu.s
X=$B/after2-add-x86_64-pc-linux-gnu.s
if [ ! -s "$A" ] || [ ! -s "$X" ]; then
  bad "ARM 3 has no corpus -- run t131-fn.sh after2 first"
else
  # The bug was an entry note between .cfi_startproc and the first insn.
  entry=$(awk '/\.cfi_startproc/{f=1;next} f&&/^\t[a-z]/{exit} f&&/\.cfi_def_cfa_offset/{print $2}' "$A")
  chk "aarch64: NO cfa offset note before the first instruction" "${entry:-none}" "none"
  chk "aarch64: cfa offset after the sub"    "$(grep -A1 'sub\s*sp' "$A" | grep cfi_def_cfa_offset | awk '{print $2}')" "16"
  chk "aarch64: cfa offset restored at exit" "$(grep -A1 'add\s*sp' "$A" | grep cfi_def_cfa_offset | awk '{print $2}')" "0"
  chk "x86_64 unmoved: its own entry note stays 16" \
      "$(grep -m1 cfi_def_cfa_offset "$X" | awk '{print $2}')" "16"
  CS=$B/after2-call-aarch64-unknown-linux-gnu.s
  if [ -s "$CS" ]; then
    chk "aarch64 emits two branch-and-link to f" "$(grep -c 'bl	f' "$CS")" "2"
    chk "aarch64 saves the link register"        "$(grep -c 'stp	x29, x30' "$CS")" "1"
  else
    bad "the fn-call arm produced no assembly at all"
  fi
fi

echo
echo "=== ARM 4: no shared object still binds the leaked spellings"
# These are MACROS, so `nm' cannot see them (PRINCIPLES: the symbol instrument
# is blind to macros that expand to option state, and to macros that expand to
# a constant it sees nothing at all).  What nm CAN see is the symbol i386's
# INCOMING_FRAME_SP_OFFSET used to drag in -- none, it is a struct field read
# -- so this arm is stated as UNMEASURABLE rather than run and scored green.
echo "  SKIP (stated, not scored): all three macros expand to constants or to"
echo "  a struct-field read, so no undefined symbol names them in any object."
echo "  The both-sided evidence for them is ARM 2, at the object level."

echo
echo "=== ARM 5: INJECTION -- the ARM 0 matcher must be able to FAIL"
# An unfired mitigation is indistinguishable from an absent one.
T=$(mktemp); cp "$D" "$T"
sed -i 's/^#define FUNCTION_MODE (mt_function_mode ())$/#define FUNCTION_MODE QImode/' "$D"
if grep -q '^#define FUNCTION_MODE QImode$' "$D"; then
  ok "5a injection produced the state intended (not merely exited 0)"
else
  bad "5a injection did NOT change the file -- every reading below is of the original"
fi
if grep -q '^#define FUNCTION_MODE (mt_function_mode ())$' "$D"; then
  bad "5b ARM 0's matcher still passes on the injected file -- it cannot fail"
else
  ok "5b ARM 0's matcher FAILS on the injected file, as it must"
fi
cp "$T" "$D"; rm -f "$T"
if grep -q '^#define FUNCTION_MODE (mt_function_mode ())$' "$D"; then
  ok "5z restored"
else
  bad "5z RESTORE FAILED -- defaults.h is left injected"
fi

echo
echo "===== $P PASS / $F FAIL"
[ "$F" = 0 ]
