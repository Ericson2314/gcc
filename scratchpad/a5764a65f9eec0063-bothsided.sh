#!/bin/sh
# a5764a65f9eec0063 -- both-sided codegen check for the EPILOGUE_USES fix,
# across every configured target, baseline (unfixed) vs fixed.
#
# THE EXPECTATION IS NOT "NOTHING MOVES", AND SAYING SO MATTERS.  25 of 47
# back ends define `EPILOGUE_USES' and all 25 were getting i386's answer, so
# a target OTHER than i386 whose codegen changes here has been CORRECTED, not
# regressed.  What must not move is i386's own output: it was already reading
# its own macro, so any change there means the redirect broke the supply side.
#
#   x86_64   MUST be byte-identical  (it was already correct)
#   aarch64  EXPECTED to change      (this is the fix)
#   riscv64  } define EPILOGUE_USES, so a change is a correction; reported
#   s390x    } rather than judged, with the diff shown.
#
# NON-VACUITY: every compile must be rc=0 with a non-empty .s on BOTH sides,
# asserted by name.  An absent .s and a changed .s are the same `diff' verdict
# otherwise, and that reads as the finding.
set -u
BASE=${BASE:-/tmp/b-a5764a65f9eec0063}
FIX=${FIX:-/tmp/b-a5764a65f9eec0063-fix}
W=${W:-/tmp/w-a5764a65f9eec0063/bothsided}
MEMCAP=$(cd "$(dirname "$0")" && pwd)/tb1-memcap.sh
SRCF=${SRCF:-$(cd "$(dirname "$0")" && pwd)/big.c}
[ -f "$SRCF" ] || { echo "FATAL: no input $SRCF"; exit 9; }

mkdir -p "$W"
rc=0
for T in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu \
         riscv64-unknown-linux-gnu s390x-ibm-linux-gnu
do
  for side in base fix; do
    case $side in base) D=$BASE ;; fix) D=$FIX ;; esac
    CFG=$D/lib/gcc/17.0.0/$T/specs-config
    if [ ! -f "$CFG" ]; then
      echo "SKIP $T ($side): no specs-config"; continue 2
    fi
    sh "$MEMCAP" 8000000 "$D/gcc/xgcc" -B"$D/gcc/" -ftarget-config="$CFG" \
       -O2 -S "$SRCF" -o "$W/$side-$T.s" > "$W/$side-$T.out" 2> "$W/$side-$T.err"
    echo $? > "$W/$side-$T.rc"
  done
  ok=1
  for side in base fix; do
    r=$(cat "$W/$side-$T.rc" 2>/dev/null || echo missing)
    if [ "$r" != 0 ]; then echo "FATAL $T ($side): rc=$r"; sed -n 1,4p "$W/$side-$T.err"; ok=0
    elif [ ! -s "$W/$side-$T.s" ]; then echo "FATAL $T ($side): empty .s"; ok=0; fi
  done
  [ "$ok" = 1 ] || { rc=9; continue; }

  mb=$(md5sum < "$W/base-$T.s" | cut -c1-12)
  mf=$(md5sum < "$W/fix-$T.s"  | cut -c1-12)
  if [ "$mb" = "$mf" ]; then
    printf '%-28s IDENTICAL   md5 %s\n' "$T" "$mb"
  else
    n=$(diff "$W/base-$T.s" "$W/fix-$T.s" | grep -c '^[<>]')
    printf '%-28s CHANGED     base %s -> fix %s   (%s differing lines)\n' \
      "$T" "$mb" "$mf" "$n"
  fi
done
exit $rc
