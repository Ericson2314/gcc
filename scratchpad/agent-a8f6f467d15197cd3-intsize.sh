#!/bin/sh
# agent-a8f6f467d15197cd3-intsize.sh -- is `int' the primary's width on every
# target?  `INT_TYPE_SIZE' is NOT redirected, and `tree.cc:9709' is
#
#     integer_type_node = make_signed_type (INT_TYPE_SIZE);
#
# in a SHARED translation unit.  If that reads the primary's 32, then msp430,
# rl78 and xstormy16 -- whose own headers say 16 -- get a 32-bit `int'.
#
# THE OBSERVABLE IS `sizeof', NOT A DUMP.  A `.size' directive on
# `char a[sizeof (int)]' is the front end's answer to the language question,
# downstream of `integer_type_node' and upstream of every codegen gate, which
# is what PRINCIPLES asks for ("find an observable downstream of the bound and
# upstream of every other gate").
#
# TWO ARMS, because one is not a measurement:
#   int     the quantity under test.
#   void *  THE CONTROL.  `POINTER_SIZE' IS already redirected on this branch,
#           so pointer width must already be per-target.  A run where `int' is
#           32 everywhere AND `void *' is also 8 everywhere means the target
#           was never selected and nothing here is evidence.  A run where
#           `void *' varies and `int' does not is the leak, isolated.
#
# usage: B=<builddir> agent-a8f6f467d15197cd3-intsize.sh <target>...
#        B=<builddir> MT_TARGET_FILE=<file> agent-a8f6f467d15197cd3-intsize.sh
# The file form exists so the whole 45-target list can be passed without a
# command substitution on the caller's line.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to a built build dir with target-specs run}
[ -x "$B/gcc/cc1" ] || { echo "FATAL: no $B/gcc/cc1"; exit 9; }
verof () { set -- "$1"/lib/gcc/*/; [ -d "$1" ] || return 1; basename "$1"; }
V=$(verof "$B") || { echo "FATAL: no $B/lib/gcc/<ver>/ -- target-specs has not run"; exit 9; }

W=$(mktemp -d); trap 'rm -rf "$W"' 0
printf 'char mt_int_width[sizeof (int)];\nchar mt_ptr_width[sizeof (void *)];\n' > "$W/in.c"

# `.size' is not universal (aout/mmix), so the width is read from whichever of
# `.size', `.comm' or `.zero'/`.space'/`.skip' the target emits, and a target
# from which NO width can be read is reported UNREADABLE rather than scored.
width () {   # width <file> <symbol>
  awk -v s="$2" '
    $0 ~ ("\\.size[ \t]+" s "[ \t]*,") { gsub(/.*,[ \t]*/, ""); print; found=1; exit }
    $0 ~ ("\\.comm[ \t]+" s "[ \t]*,") { split($0, a, ","); gsub(/[ \t]/, "", a[2]); print a[2]; found=1; exit }
  ' "$1"
}

if [ -n "${MT_TARGET_FILE:-}" ]; then
  [ -s "$MT_TARGET_FILE" ] || { echo "FATAL: MT_TARGET_FILE $MT_TARGET_FILE is empty"; exit 9; }
  set -- $(grep . "$MT_TARGET_FILE")
fi
[ $# -ge 1 ] || { echo "FATAL: name at least one target"; exit 9; }

printf '%-28s %8s %8s  %s\n' TARGET 'sizeof int' 'sizeof ptr' note
nint=0; nptr=0; nread=0
for T in "$@"; do
  F="$B/lib/gcc/$V/$T/specs-config"
  [ -f "$F" ] || { printf '%-28s %8s %8s  %s\n' "$T" - - 'no specs-config'; continue; }
  ( cd "$B/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$F" "$W/in.c" -o "$W/$T.s" ) \
    > "$W/$T.msg" 2>&1
  [ -s "$W/$T.s" ] || { printf '%-28s %8s %8s  %s\n' "$T" - - "$(head -1 "$W/$T.msg" | cut -c1-46)"; continue; }
  i=$(width "$W/$T.s" mt_int_width)
  p=$(width "$W/$T.s" mt_ptr_width)
  if [ -z "$i" ] || [ -z "$p" ]; then
    printf '%-28s %8s %8s  %s\n' "$T" "${i:--}" "${p:--}" 'UNREADABLE (no .size/.comm)'
    continue
  fi
  nread=$((nread + 1))
  echo "$i" >> "$W/ints"; echo "$p" >> "$W/ptrs"
  printf '%-28s %8s %8s\n' "$T" "$i" "$p"
done

echo
[ "$nread" -gt 0 ] || { echo "REFUSE: read ZERO targets -- no verdict here"; exit 9; }
nint=$(sort -u "$W/ints" | wc -l); nptr=$(sort -u "$W/ptrs" | wc -l)
echo "targets read: $nread   distinct sizeof(int): $nint   distinct sizeof(void*): $nptr"
echo "  sizeof(int)  values: $(sort -u "$W/ints" | tr '\n' ' ')"
echo "  sizeof(void*) values: $(sort -u "$W/ptrs" | tr '\n' ' ')"
if [ "$nptr" -le 1 ]; then
  echo "REFUSE: sizeof(void*) is CONSTANT across every target.  POINTER_SIZE is"
  echo "        already redirected, so that cannot be right -- the target was"
  echo "        probably never selected, and the int column is not evidence."
  exit 9
fi
if [ "$nint" -le 1 ]; then
  echo "FINDING: sizeof(void*) varies and sizeof(int) does NOT.  \`int' is one"
  echo "         width for every back end -- the primary's -- while at least"
  echo "         msp430, rl78 and xstormy16 ask for 16 in their own headers."
else
  echo "sizeof(int) varies across targets: INT_TYPE_SIZE is reaching per-base."
fi
