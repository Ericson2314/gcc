#!/bin/sh
# #169 / #162 ARM 5 -- THE INJECTION.  Flip aarch64's `auto_inc_dec' byte back
# to 0 IN THE OBJECT, relink cc1, and require aarch64's output to change.
#
# WHY AN OBJECT PATCH AND NOT A SOURCE EDIT.  PRINCIPLES section 4 requires an
# injection to be shown to have produced the state intended, and a source edit
# here would rebuild the header that DECLARES the field, so a mistake could
# quietly change the struct layout instead of the value.  One byte at
# `mt_base_insn + 11' can only mean one thing.  It is also the exact byte ARM 3
# reads, so ARM 3 and ARM 5 are the same claim measured from two sides.
#
# AN INJECTION THAT DOES NOT FIRE IS A FINDING (PRINCIPLES section 4): if the
# aarch64 output is byte-identical with the flag forced to 0, then nothing on
# this input reads it, and the honest report is "the flag is per-base and
# correct in the data, and this input does not exercise it" -- NOT "fixed".
#
# usage: t169-inject.sh <builddir>
set -u
D=${1:?build dir}
V=17.0.0
OUT=$D/t169-inject; mkdir -p "$OUT"
O=$D/gcc/target-cumargs-aarch64.o
[ -f "$O" ] || { echo "FATAL: $O missing"; exit 9; }
[ -f "$D/gcc/cc1" ] || { echo "FATAL: no cc1"; exit 9; }
C=$D/lib/gcc/$V/aarch64-unknown-linux-gnu/specs-config
[ -s "$C" ] || { echo "FATAL: no aarch64 specs-config"; exit 9; }
IN=${2:?input .c}

# THE OBSERVABLE IS THE PASS GATE, NOT THE CODEGEN.  Measured first: at -O2 on
# this input aarch64 emits BYTE-IDENTICAL assembly whether the flag is 1 or 0,
# because the pass runs and finds nothing profitable.  An arm watching the .s
# would therefore have reported "injection did not fire" on a working
# conversion -- the exact false negative PRINCIPLES section 4 warns about, and
# it did report it, which is why this arm was rewritten.
probe () { # $1 tag -> prints 1 if auto-inc-dec.cc's pass ran
  dd=$OUT/$1; rm -rf "$dd"; mkdir -p "$dd"
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -fdump-rtl-auto_inc_dec \
      -dumpbase "$dd/t" -ftarget-config="$C" "$IN" -o "$dd/x.s" ) \
      > "$dd/out" 2> "$dd/err"
  [ -s "$dd/x.s" ] || { echo "FATAL: $1 emitted nothing; a missing dump would"
                        echo "       then mean 'the compile failed'"; exit 9; }
  if [ -n "$(find "$dd" -name '*auto_inc_dec*' -print -quit)" ]; then echo 1
  else echo 0; fi
}
B=$(probe before)
echo "before: auto_inc_dec pass ran = $B"
[ "$B" = 1 ] || { echo "FATAL: the pass is already off before injecting -- there"
                  echo "       is nothing for the injection to turn off"; exit 9; }

# --- flip the byte
SYM=$(nm "$O" | awk '$3 ~ /mt_base_insn$/ { print $1 }')
[ -n "$SYM" ] || { echo "FATAL: no mt_base_insn"; exit 9; }
SECOFF=$(objdump -h "$O" | awk '$2 == ".rodata" { print $6 }')
[ -n "$SECOFF" ] || { echo "FATAL: no .rodata file offset"; exit 9; }
POS=$(( $(printf '%d' "0x$SYM") + 11 + $(printf '%d' "0x$SECOFF") ))
cp "$O" "$OUT/orig.o"
old=$(od -An -tx1 -j "$POS" -N 1 "$O" | tr -d ' ')
[ "$old" = "01" ] || { echo "FATAL: byte at mt_base_insn+11 is 0x$old, expected 01;"
                       echo "       the layout assumption is wrong and this would"
                       echo "       have corrupted an unrelated field"; exit 9; }
printf '\000' | dd of="$O" bs=1 seek="$POS" conv=notrunc status=none
new=$(od -An -tx1 -j "$POS" -N 1 "$O" | tr -d ' ')
[ "$new" = "00" ] || { echo "FATAL: injection did not take (byte is 0x$new)"; exit 9; }
echo "injected: mt_base_insn+11  0x$old -> 0x$new"

# --- relink and re-measure
cp "$D/gcc/cc1" "$OUT/cc1.orig"
( cd "$D/gcc" && make cc1 ) > "$OUT/relink.out" 2> "$OUT/relink.err"
r=$?
echo "relink rc=$r"
cmp -s "$OUT/cc1.orig" "$D/gcc/cc1" \
  && { echo "FATAL: cc1 is byte-identical after relinking -- the object was not"
       echo "       re-used, so this measures the OLD binary"; }

A=$(probe after)
echo "after:  auto_inc_dec pass ran = $A"
if [ "$A" = 0 ]; then
  echo "INJECTION FIRED: forcing aarch64's auto_inc_dec byte to 0 turns the"
  echo "auto-inc-dec pass off.  The byte ARM 3 reads is the byte the compiler"
  echo "reads."
else
  echo "INJECTION DID NOT FIRE: the pass still runs with the flag forced to 0,"
  echo "so something other than mt_auto_inc_dec () is gating it.  That is a"
  echo "finding, not a pass."
fi

# --- restore, and PROVE the restore
cp "$OUT/orig.o" "$O"
back=$(od -An -tx1 -j "$POS" -N 1 "$O" | tr -d ' ')
[ "$back" = "01" ] || { echo "FATAL: restore failed, byte is 0x$back"; exit 9; }
( cd "$D/gcc" && make cc1 ) > "$OUT/relink2.out" 2> "$OUT/relink2.err"
echo "restored and relinked rc=$?"
R=$(probe restored)
echo "restored: auto_inc_dec pass ran = $R"
[ "$R" = 1 ] || { echo "FATAL: restore did not reproduce the before state"; exit 9; }
echo "restore verified"
exit 0
