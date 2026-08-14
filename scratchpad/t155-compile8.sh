#!/bin/sh
# #155 -- A COMPILED FUNCTION PER BASE, and IS THE OUTPUT RIGHT.
#
# "WHERE DOES IT ICE IS NOT THE MEASUREMENT.  IS THE OUTPUT RIGHT IS."  A wall
# on this branch stopped ICEing and started emitting
#
#     str  x19, [x7, -32]!
#
# with matching wrong CFI and exit 0 -- i386's STACK_POINTER_REGNUM and
# FRAME_POINTER_REGNUM used as aarch64's.  An ICE-tracking harness records that
# as progress.  So each base is scored on WHAT IT EMITTED.
#
# TWO ARMS PER BASE, because either alone passes on an empty file:
#   OWN      the base's own registers/mnemonics must appear, many times;
#   FOREIGN  x86 registers must NOT appear in a non-x86 output.  This is the
#            exact shape the primary-leak produced before.
#
# `-S' is used deliberately: it needs no assembler, so a base with no cross
# binutils on this host is still fully scorable for CODEGEN, which is the thing
# under test.  (A real assembler is a stronger arm and is used by t150-asm.sh
# for the targets that have one; absence of `as' is not a reason to skip a base.)
#
# usage: t155-compile8.sh <builddir> <tag>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
TAG=${2:?tag}
case "$B" in
  */b-af064528c538fd406*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
IN="$S/big.c"
[ -s "$IN" ] || { echo "FATAL: $IN missing or empty"; exit 9; }

TARGETS="x86_64-pc-linux-gnu aarch64-unknown-linux-gnu powerpc64-linux-gnu \
m68k-elf microblaze-elf pdp11-aout vax-linux-gnu xtensa-elf"

own_pat () {
  case $1 in
    x86_64*)     echo '%r[a-d]x|%rsp|%rbp|movq|pushq' ;;
    aarch64*)    echo '\bx[0-9]+\b|\bw[0-9]+\b|\bstp\b|\bldp\b' ;;
    powerpc64*)  echo '\bmflr\b|\bstd\b|\bblr\b|\br[0-9]+\b' ;;
    m68k*)       echo '%d[0-7]\b|%a[0-7]\b|\bmove\.|\bjsr\b' ;;
    microblaze*) echo '\br[0-9]+\b|\baddik\b|\bswi\b|\bbrlid\b' ;;
    pdp11*)      echo '\br[0-7]\b|\bmov\b|\bjsr\b|\bsp\b' ;;
    vax*)        echo '\br[0-9]+\b|\bmovl\b|\bcalls\b|\bpushl\b' ;;
    xtensa*)     echo '\ba[0-9]+\b|\bl32r\b|\bentry\b|\bretw\b' ;;
  esac
}

echo "== arm 0: NON-VACUITY (a base that cannot diagnose is UNSCORABLE BY NAME)"
SCORABLE=""
for t in $TARGETS; do
  d="$B/gcc/$t-gcc"
  [ -x "$d" ] || { echo "  UNSCORABLE: no driver $d"; continue; }
  e=$(sh "$S/eb-shell.sh" \
        "cd $B/gcc && ./$t-gcc -S -nostdinc -o /dev/null $S/t155-vac.c" 2>&1 \
        > /dev/null || true)
  case "$e" in
    *"fatal error"*)
      echo "  UNSCORABLE BY NAME: $t fails before compiling:"
      echo "    [$(printf '%s' "$e" | head -1)]" ;;
    *"undeclared"*)
      echo "  ok: $t emits the diagnostic the input was written to provoke"
      SCORABLE="$SCORABLE $t" ;;
    *)
      echo "  UNSCORABLE BY NAME: $t gave no diagnostic for a known-bad input"
      echo "    [$(printf '%s' "$e" | head -1)]" ;;
  esac
done
n=$(printf '%s\n' $SCORABLE | grep -c . || true)
echo "  $n scorable bases"
[ "$n" -ge 3 ] || { echo "REFUSING TO SCORE: only $n scorable, the point is >2"; exit 9; }

echo
echo "== arm 1: compile and READ THE OUTPUT"
ok=0
for t in $SCORABLE; do
  o="$B/t155-$TAG-$t"
  rm -f "$o.s"
  sh "$S/eb-shell.sh" "cd $B/gcc && ./$t-gcc -O2 -S -nostdinc -o $o.s $IN" \
    > "$o.out" 2> "$o.err"
  rc=$?
  if grep -q 'internal compiler error' "$o.err"; then
    echo "  $t  ICE: $(grep -m1 'internal compiler error' "$o.err" | sed 's/.*internal compiler error: //')"
    continue
  fi
  if [ "$rc" != 0 ] || [ ! -f "$o.s" ]; then
    echo "  $t  rc=$rc FAIL-NO-ICE: $(head -2 "$o.err" | tr '\n' ' ')"
    continue
  fi
  own=$(grep -cE "$(own_pat "$t")" "$o.s" || true)
  case $t in
    x86_64*) foreign=0 ;;
    *) foreign=$(grep -cE '%r[a-d]x|\bpushq\b|\bleaq\b|%rsp' "$o.s" || true) ;;
  esac
  verdict=ok
  [ "$own" -gt 20 ] || verdict="SUSPECT(own=$own)"
  [ "$foreign" = 0 ] || verdict="SUSPECT(x86=$foreign)"
  [ "$verdict" = ok ] && ok=$((ok+1))
  printf '  %-28s %7s bytes  own %4s  x86 %3s  %s\n' \
    "$t" "$(wc -c < "$o.s")" "$own" "$foreign" "$verdict"
done
echo
echo "  $ok bases compiled and emitted their OWN target's code"
