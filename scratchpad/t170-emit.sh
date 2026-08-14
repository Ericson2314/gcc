#!/bin/sh
# #170 -- turn "links" into "emits real code a real assembler accepts".
#
# For each of the eleven configured back ends, four separate questions, scored
# INDEPENDENTLY because they fail for different reasons and a single verdict
# would hide which:
#
#   1 emits?    does cc1 exit 0 and write a non-empty .s
#   2 x86-leak? does that .s contain x86 register/mnemonic tokens
#   3 asm?      does THAT TARGET'S OWN real assembler accept it
#   4 machine?  is the resulting object's ELF machine the right one
#
# Arm 2 is the one this task exists for.  PRINCIPLES records that i386's
# register allocation order, DWARF numbering, Pmode and pointer regnums all
# reached aarch64 silently -- "str x19, [x7, -32]!", i386's regnums 7 and 19
# used as aarch64's stack and frame pointers, compiled and exited 0.  A back
# end emitting x86 under another name is the finding, not a footnote, so it is
# tested by TOKEN CONTENT and not only by whether the assembler complained:
# a cross assembler rejecting %rsp and a back end that never emitted it are
# different results and arms 2 and 3 keep them apart.
#
# `-nostdinc' throughout; cc1 is driven DIRECTLY with -ftarget-config= rather
# than through the driver, because the riscv driver segfaults (#154) and
# -march=native/driver behaviour is i386's (host_detect_local_cpu, 8 bare
# definers) -- neither is this task's subject and both would attribute a driver
# defect to a back end.
#
# usage: t170-emit.sh <builddir> <snapshot-srcdir> <toolroot>
set -u
D=${1:?build dir}
SRC=${2:?snapshot srcdir}
ROOT=${3:?tool root}
S=$(cd "$(dirname "$0")" && pwd)
case "$D" in
  */b-a697b5bfd5294f5e8*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D not configured from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "${WANT_ANCHOR:-50}" ] \
  || { echo "FATAL: snapshot anchor is not ${WANT_ANCHOR:-50}"; exit 9; }
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1"; exit 9; }

OUT=$D/t170-emit; mkdir -p "$OUT"
TRIPLES=$(grep -v '^#' "$S/t170-bases11.txt" | awk 'NF{print $2}')   # canonical

printf '%-28s %-6s %-7s %-9s %-7s %s\n' TARGET EMITS X86LEAK ASSEMBLES MACHINE INPUT
: > "$OUT/TABLE"
for t in $TRIPLES; do
  cfg=$(ls "$D"/lib/gcc/*/"$t"/specs-config 2>/dev/null | head -1)
  if [ -z "$cfg" ]; then
    printf '%-28s %-6s %-7s %-9s %-7s %s\n' "$t" NO-CFG - - - "no specs-config"
    echo "$t|NO-CFG|-|-|-|no specs-config" >> "$OUT/TABLE"
    continue
  fi
  # big.c first; the portable file only if big.c does not fit this back end.
  emit=FAIL; input=; sfile=
  for in in "$SRC/scratchpad/big.c" "$SRC/scratchpad/t170-small.c"; do
    tag=$t.$(basename "$in" .c)
    ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$cfg" \
        "$in" -o "$OUT/$tag.s" ) > "$OUT/$tag.out" 2> "$OUT/$tag.err"
    r=$?
    if [ $r = 0 ] && [ -s "$OUT/$tag.s" ]; then
      emit=OK; input=$(basename "$in"); sfile=$OUT/$tag.s; break
    fi
  done
  if [ "$emit" != OK ]; then
    c=$(head -3 "$OUT/$t.t170-small.err" | tr '\n' ' ' | cut -c1-90)
    printf '%-28s %-6s %-7s %-9s %-7s %s\n' "$t" FAIL - - - "$c"
    echo "$t|FAIL|-|-|-|$c" >> "$OUT/TABLE"
    continue
  fi

  # ARM 2 -- x86 tokens in a non-x86 target's output.  Deliberately over-broad
  # (an instrument that can only ACCUSE should be too eager; one that can
  # ABSOLVE must be exact -- PRINCIPLES section 4).  A hit is a finding to
  # investigate, not a verdict on its own.
  if [ "$t" = x86_64-pc-linux-gnu ]; then
    leak=n/a
  elif grep -Eqw '%rsp|%rbp|%rax|%eax|%edi|leaq|movq|pushq' "$sfile"; then
    leak=YES
  else
    leak=no
  fi

  d="$ROOT/$t"
  if [ ! -x "$d/$t-as" ]; then
    printf '%-28s %-6s %-7s %-9s %-7s %s\n' "$t" OK "$leak" NO-AS UNKNOWN "$input"
    echo "$t|OK|$leak|NO-AS|UNKNOWN|$input" >> "$OUT/TABLE"
    continue
  fi
  if "$d/$t-as" -o "$OUT/$t.o" "$sfile" > "$OUT/$t.asout" 2> "$OUT/$t.aserr"; then
    asm=OK
    mach=$("$d/$t-readelf" -h "$OUT/$t.o" | sed -n 's/^ *Machine: *//p')
    "$d/$t-readelf" --debug-dump=frames "$OUT/$t.o" > "$OUT/$t.frames" 2>&1 || true
  else
    asm=FAIL; mach=-
  fi
  printf '%-28s %-6s %-7s %-9s %-7s %s\n' "$t" OK "$leak" "$asm" "$mach" "$input"
  echo "$t|OK|$leak|$asm|$mach|$input" >> "$OUT/TABLE"
done

echo
echo "== sizes / md5 of each .s (quote WITH the input path; -S emits .file)"
for f in "$OUT"/*.s; do
  [ -f "$f" ] || continue
  echo "  $(basename "$f")  $(wc -c < "$f") bytes  md5 $(md5sum < "$f" | cut -c1-12)"
done
