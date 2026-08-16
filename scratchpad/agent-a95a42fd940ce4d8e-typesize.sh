#!/bin/sh
# agent-a95a42fd940ce4d8e-typesize.sh -- THE RESIDUAL, SIZED.
#
# avr's `string-large-1.c' is the only one of the 71 `recog.cc:2892' rows NOT
# explained by `STACK_SAVEAREA_MODE'.  Its unrecognizable insn is
#
#     (set (reg:HI 697) (const_int 2147483647 [0x7fffffff]))
#
# i.e. a 32-bit `INT_MAX' forced into avr's 16-bit `int' mode.  `INT_TYPE_SIZE'
# is `LEAK-PRIMARY' in the leak census (40 back ends define it, 8 shared files
# spell it) and i386's is 32.
#
# THIS SCRIPT DOES NOT FIX IT.  It measures how wide it is, because 2 FAIL rows
# on one back end badly understates a defect in the size of `int'.  The
# instrument is the compiler's OWN predefined macros, read per selected target
# -- not a grep of `config/', which cannot say which value reached cc1.
#
# THE CONTROL IS `__SIZEOF_POINTER__', and it is the point of the table.
# Pointer size is already converted (`Pmode' -> `mt_pmode ()'), so a back end
# showing a CORRECT pointer size beside a WRONG int size proves the target is
# genuinely selected and that the wrong value is this macro's own leak rather
# than "the target was never selected at all".  Without that column a wrong
# `__SIZEOF_INT__' is indistinguishable from a broken run.
set -u
D=${D:-/tmp/b-a95a42fd940ce4d8e}
SRC=$(cat "$D/MY-SRC"); V=$(cat "$SRC/gcc/BASE-VER")
O=${O:-/tmp/w-agent-a95a42fd940ce4d8e/typesize}
mkdir -p "$O"; printf 'int x;\n' > "$O/p.c"
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1"; exit 9; }

# Each back end's OWN INT_TYPE_SIZE, from its headers.  Absent => upstream's
# `defaults.h' default of 32, which is a real per-base answer for a back end
# that says nothing.
own_int () {
  b=$1
  v=$(grep -rhE "^[[:space:]]*#[[:space:]]*define[[:space:]]+INT_TYPE_SIZE\b" \
        "$SRC/gcc/config/$b"/*.h 2>/dev/null | head -1 \
      | sed 's/.*INT_TYPE_SIZE[[:space:]]*//; s|/\*.*||; s/[[:space:]]*$//')
  [ -n "$v" ] && echo "$v" || echo "32(default)"
}
printf '%-28s %-8s %-8s %-14s %s\n' TARGET cc1_INT own_INT cc1_POINTER VERDICT
nb=0; nw=0
for d in "$D"/lib/gcc/"$V"/*/; do
  t=$(basename "$d"); c="$d/specs-config"; [ -s "$c" ] || continue
  m=$("$D/gcc/cc1" -quiet -nostdinc -ftarget-config="$c" -dM -E "$O/p.c" 2>/dev/null)
  [ -n "$m" ] || { printf '%-28s %s\n' "$t" "NO-PREDEFINES (not a reading)"; continue; }
  si=$(printf '%s\n' "$m" | sed -n 's/^#define __SIZEOF_INT__ //p')
  sp=$(printf '%s\n' "$m" | sed -n 's/^#define __SIZEOF_POINTER__ //p')
  b=$(sed -n "s|^$t *||p" "$O/map" 2>/dev/null)
  [ -n "$b" ] || b=$(basename "$(dirname "$d")")
  oi=$(own_int "${t%%-*}")
  nb=$((nb+1))
  exp=$(echo "$oi" | sed 's/(default)//')
  got=$((si*8))
  # A NON-NUMERIC OWN VALUE IS `UNKNOWN', NEVER 32.  The first draft defaulted
  # it to 32, which scored avr -- whose header says
  # `(TARGET_INT8 ? 8 : 16)' -- as `ok' while cc1 was demonstrably giving it
  # 32.  That is this project's own false-green shape inside the instrument
  # written to find one: the case that cannot be evaluated was folded into the
  # case that passes.  It is now reported as UNKNOWN and counted separately, so
  # it can never be read as agreement.
  case "$exp" in
    ''|*[!0-9]*) v="UNKNOWN-OWN (cc1 says ${got}; header is an expression: ${oi})"
                 nu=$((${nu:-0}+1)) ;;
    *) if [ "$got" = "$exp" ]; then v=ok
       else v="WRONG (cc1 says ${got}, back end says ${exp})"; nw=$((nw+1)); fi ;;
  esac
  printf '%-28s %-8s %-8s %-14s %s\n' "$t" "$si" "$oi" "$sp" "$v"
done
echo
echo "targets read: $nb   WRONG: $nw   UNKNOWN-OWN: ${nu:-0}"
echo
echo "avr is the measured instance and it is UNKNOWN-OWN by this scan, not ok:"
echo "  avr.h says INT_TYPE_SIZE is (TARGET_INT8 ? 8 : 16); TARGET_INT8 is off"
echo "  by default, so avr's own answer is 16 and cc1 gives it 32."
echo "  Its cost in THIS task is 2 of the 71 rows; its real blast radius is the"
echo "  size of \`int' on every back end whose answer is not 32."
[ "$nb" -gt 0 ] || { echo "FATAL: read no targets at all"; exit 9; }
