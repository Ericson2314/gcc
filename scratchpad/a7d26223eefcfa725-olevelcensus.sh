#!/bin/sh
# THE ONE-LINE CENSUS AT THREE OPTIMISATION LEVELS, because the existing one
# runs at ONE and is blind in exactly the way it exists to prevent.
#
# `a7ee6ca7c923e4a58-onelinecensus.sh' and the scorer's DIED-FIRST-INPUT
# precondition both compile `int f(int x){return x+1;}' with `-S' and NO `-O'.
# That makes them blind to a back end that dies only under optimisation --
# and one does.  Measured here:
#
#     sparc64  -O0 -S   rc=0
#     sparc64  -O1 -S   ICE: 'only_leaf_regs_used' was called, but this
#                       compiler was built without 'LEAF_REGISTERS' reaching
#                       shared code  [T157-STUBS.md fail-by-name stub]
#
# So sparc passed the precondition, was sent to the suite, and was refused
# there by GUARD 3c -- which reported it as *"the target's own assembler
# rejected the compiler's output"*.  It is not an assembler problem at all.
# The precondition's whole purpose is that a back end dying on its first input
# contributes no FAIL rows and is invisible to a `.sum'-based ranking; a
# precondition that only probes `-O0' reproduces that blindness one level down.
#
# Most of `gcc.target' is compiled at `-O2' or above, so `-O0' is the LEAST
# representative single level that could have been chosen.
#
# NOT A REPLACEMENT -- an ADDITIONAL ARM.  `-O0' still matters: a back end
# dying there is dead on any input at all, which is a stronger statement.
set -u
B=${1:?build dir}
SRC=$(cat "$B/MY-SRC")
VER=$(cat "$SRC/gcc/BASE-VER")
S=$(cd "$(dirname "$0")" && pwd)
T=/tmp/olc2-$$.c
printf 'int mt_one (int x) { return x + 1; }\n' > "$T"

printf '%-30s %-22s %-22s %s\n' TARGET -O0 -O1 -O2
n0=0; n1=0; n2=0; nall=0
for row in $(cut -d: -f2 "$S/agent-acda89931a903ec27-backends.txt"); do
  CFG="$B/lib/gcc/$VER/$row/specs-config"
  [ -f "$CFG" ] || continue
  nall=$((nall+1))
  out=""
  for O in 0 1 2; do
    e=$("$B/gcc/xgcc" -B"$B/gcc/" -ftarget-config="$CFG" "-O$O" -S \
          -o /dev/null "$T" 2>&1)
    if [ -z "$e" ]; then
      r=ok
    else
      r=$(printf '%s' "$e" | sed -n 's/.*internal compiler error: //p' | head -1 \
          | cut -c1-20)
      [ -n "$r" ] || r=$(printf '%s' "$e" | sed -n 's/.*error: //p' | head -1 | cut -c1-20)
      [ -n "$r" ] || r=OTHER
      r="ICE:$r"
    fi
    eval "r$O=\$r"
    case "$O$r" in 0ok) n0=$((n0+1)) ;; 1ok) n1=$((n1+1)) ;; 2ok) n2=$((n2+1)) ;; esac
  done
  printf '%-30s %-22s %-22s %s\n' "$row" "$r0" "$r1" "$r2"
done
rm -f "$T"
echo
echo "of $nall targets with a specs-config:  -O0 ok=$n0   -O1 ok=$n1   -O2 ok=$n2"
echo "A target ok at -O0 and dead at -O1/-O2 is INVISIBLE to the existing"
echo "single-level precondition, and gcc.target is mostly compiled at -O2."
[ "$nall" -gt 0 ] || { echo "FATAL: nothing measured"; exit 9; }
