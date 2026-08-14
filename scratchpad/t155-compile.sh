#!/bin/sh
# #155 -- DOES EACH BASE COMPILE, not merely does cc1 link?
#
# "WHERE DOES IT ICE IS NOT THE MEASUREMENT.  IS THE OUTPUT RIGHT IS."  A wall
# on this branch stopped ICEing and started emitting
#
#     str  x19, [x7, -32]!
#
# -- i386's STACK_POINTER_REGNUM and FRAME_POINTER_REGNUM used as aarch64's,
# with matching wrong CFI, exit 0.  An ICE-tracking harness records that as
# progress.  So each base is scored on WHAT IT EMITTED, and the discriminator
# is whether another base's registers appear in it.
#
# ARM 0 IS NON-VACUITY AND RUNS FIRST.  A missing driver, or a cc1 that was
# never linked, makes every base read "no ICE" -- the shape of SUCCESS.  A base
# that cannot be scored is named as UNSCORABLE, never silently dropped: a base
# that dies before parsing reads clean in both columns.
#
# usage: t155-compile.sh <builddir> <tag>
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

TARGETS="x86_64-pc-linux-gnu aarch64-unknown-linux-gnu powerpc64-linux-gnu s390x-linux-gnu"

# Per base, a pattern of ITS OWN registers and a pattern of a FOREIGN one.
# Both are needed: "it emitted something" is not evidence, and "it emitted no
# x86" is satisfied by an empty file.
own_pat () {
  case $1 in
    x86_64*)  echo '%r[a-d]x|%rsp|%rbp|movq|pushq' ;;
    aarch64*) echo '\bx[0-9]+\b|\bw[0-9]+\b|\bsp\b' ;;
    powerpc*) echo '\b[0-9]+\(1\)|\bmflr\b|\bstd\b|\br[0-9]+\b' ;;
    s390x*)   echo '\b%r[0-9]+\b|\bstmg\b|\blgr\b|\bbrasl\b' ;;
  esac
}

echo "== arm 0: NON-VACUITY"
SCORABLE=""
for t in $TARGETS; do
  d="$B/gcc/$t-gcc"
  [ -x "$d" ] || { echo "  UNSCORABLE: no driver $d"; continue; }
  e=$(sh "$S/eb-shell.sh" \
        "cd $B/gcc && ./$t-gcc -S -nostdinc -o /dev/null $S/t155-vac.c" 2>&1 \
        > /dev/null || true)
  case "$e" in
    *"fatal error"*)
      # Deliberately rejected rather than accepted.  A first draft of this arm
      # matched any line containing "error" and PASSED on the driver's own
      # "no configuration file for target", i.e. on a driver that could not
      # compile anything at all.
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
[ "$n" -ge 2 ] || { echo "REFUSING TO SCORE: only $n scorable bases"; exit 9; }

echo
echo "== arm 1: compile $IN, per base, and READ THE OUTPUT"
for t in $SCORABLE; do
  o="$B/t155-$TAG-$t"
  rm -f "$o.s"
  sh "$S/eb-shell.sh" "cd $B/gcc && ./$t-gcc -O2 -S -nostdinc -o $o.s $IN" \
    > "$o.out" 2> "$o.err"
  rc=$?
  if grep -q 'internal compiler error' "$o.err"; then
    echo "  $t  rc=$rc  ICE: $(grep -m1 'internal compiler error' "$o.err" | sed 's/.*internal compiler error: //')"
    continue
  fi
  if [ "$rc" != 0 ] || [ ! -f "$o.s" ]; then
    echo "  $t  rc=$rc  FAIL-NO-ICE: $(head -2 "$o.err" | tr '\n' ' ')"
    continue
  fi
  own=$(grep -cE "$(own_pat "$t")" "$o.s" || true)
  # The foreign discriminator: x86 mnemonics in a non-x86 output is the exact
  # shape the leak produced before.
  case $t in
    x86_64*) foreign=0 ;;
    *) foreign=$(grep -cE '%r[a-d]x|\bpushq\b|\bleaq\b' "$o.s" || true) ;;
  esac
  printf '  %-28s rc=%s  %6s bytes  own-reg lines %4s  x86 lines %s\n' \
    "$t" "$rc" "$(wc -c < "$o.s")" "$own" "$foreign"
done
