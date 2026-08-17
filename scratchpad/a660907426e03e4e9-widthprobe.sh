#!/bin/sh
# THE AXIS NO BOARD HAS EVER BEEN ABLE TO SEE: pointer width, word size, Pmode.
#
# Every target this project has scored against a stock control -- x86_64,
# aarch64, riscv64, s390x -- is LP64.  They agree about `sizeof(void *)',
# `__SIZEOF_LONG__', `__SIZEOF_SIZE_T__', `__INTPTR_WIDTH__' and the ELF class
# of everything they emit, so a primary's answer leaking on any of those axes
# is invisible to all four AT ONCE.  This probe compiles the same six-line
# translation unit with the multi-target compiler and with the stock control
# and requires them to AGREE WITH EACH OTHER and with the target's real ABI.
#
# It is a `-S' + `_Static_assert' probe rather than a `-dM' grep on purpose.
# A `-dM' dump is a text file: a compiler that dies produces an empty one and
# `grep -c' scores 0, which reads as "the macro is absent" rather than "nothing
# ran".  `_Static_assert' makes the WRONG answer a named diagnostic and the
# absent answer a compile failure, and the script requires the object to exist.
# The negative control below then requires the deliberately-wrong assertion to
# FIRE, so "no diagnostic" cannot mean "the probe never compiled".
#
# usage: MTCC='<xgcc -B... -ftarget-config=...>' STCC='<xgcc -B...>' \
#        a660907426e03e4e9-widthprobe.sh <bytes-per-pointer> <bytes-per-long> <label>
set -u
MTCC=${MTCC:?set MTCC to the multi-target compiler command}
STCC=${STCC:?set STCC to the stock control compiler command}
P=${1:?bytes per pointer}
L=${2:?bytes per long}
LAB=${3:?label}
TD=$(mktemp -d) || exit 9
trap 'rm -rf "$TD"' 0

mk () {  # $1 = expected pointer size
  cat > "$TD/w.c" <<EOF
_Static_assert (sizeof (void *) == $1, "pointer width");
_Static_assert (sizeof (long) == $L, "long width");
_Static_assert (__SIZEOF_POINTER__ == $1, "__SIZEOF_POINTER__");
_Static_assert (__INTPTR_WIDTH__ == $1 * 8, "__INTPTR_WIDTH__");
_Static_assert (sizeof (int) == 4, "int width");
int w_probe;
EOF
}

fails=0
run () {   # $1 = label, $2 = compiler command
  rm -f "$TD/o.s"
  if $2 -S -o "$TD/o.s" "$TD/w.c" > "$TD/e" 2>&1 && [ -s "$TD/o.s" ]; then
    echo "  $1: PASS"
  else
    echo "  $1: FAIL"
    sed -n '1,6p' "$TD/e" | sed 's/^/      /'
    fails=$((fails+1))
  fi
}

echo "== widthprobe [$LAB]: pointer $P bytes, long $L bytes"
mk "$P"
run "multi-target" "$MTCC"
run "stock       " "$STCC"

# NEGATIVE CONTROL.  Without it a compiler that cannot run at all would give
# two clean-looking greens above only if `-s o.s' were omitted, and a compiler
# that ignores `_Static_assert' would give two real ones.  Demand the WRONG
# width be named, on BOTH sides, or every line above is void.
echo "-- negative control: the same probe with the wrong width MUST fail"
mk "$((P == 4 ? 8 : 4))"
neg=0
for c in "$MTCC" "$STCC"; do
  if $c -S -o "$TD/n.s" "$TD/w.c" > "$TD/ne" 2>&1; then
    echo "  NEGATIVE CONTROL DID NOT FIRE for: $c"
  else
    grep -q 'pointer width' "$TD/ne" || {
      echo "  it failed, but NOT on the assertion -- that is not a control:"
      sed -n '1,4p' "$TD/ne" | sed 's/^/      /'; continue; }
    neg=$((neg+1))
  fi
done
[ "$neg" = 2 ] || { echo "FATAL: negative control fired $neg/2 times; the passes above are VOID"; exit 9; }
echo "  negative control fired on both sides"
[ "$fails" = 0 ] || { echo "WIDTHPROBE [$LAB]: $fails/2 sides FAILED"; exit 1; }
echo "WIDTHPROBE [$LAB]: both sides agree with the target ABI"
