#!/bin/sh
# #170 -- causes for the back ends t170-emit.sh scored FAIL.
#
# Two arms, because "it ICEs at -O2" and "it cannot compile a function at all"
# are different results and the table should not merge them:
#
#   A  the same input at -O0, so an optimisation-dependent wall is separated
#      from a wall in the target's basic setup
#   B  a gdb backtrace, because cc1's own backtrace prints `???:0' for the
#      frames that matter and for riscv and mips it stops at crash_signal --
#      i.e. the built-in instrument reports the SIGNAL and not the site.
#      ONE breakpoint per run (PRINCIPLES section 4: an arm that set three in
#      one run read the same function's return value three times under three
#      names).
#
# usage: t170-cause.sh <builddir> <snapshot> <triple>...
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; SRC=${2:?snapshot}; TOOLROOT=${3:?tool root}; shift 3
case "$D" in
  */b-a9f631a78e8fb27d2*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
OUT=$D/ta9f-cause; mkdir -p "$OUT"
IN=$SRC/scratchpad/t170-small.c
[ -s "$IN" ] || { echo "FATAL: no input $IN"; exit 9; }

for t in "$@"; do
  cfg=$(ls "$D"/lib/gcc/*/"$t"/specs-config 2>/dev/null | head -1)
  [ -n "$cfg" ] || { echo "$t: NO-CFG"; continue; }
  for O in -O0 -O1 -O2; do
    ( cd "$D/gcc" && ./cc1 -quiet -nostdinc $O -ftarget-config="$cfg" \
        "$IN" -o "$OUT/$t$O.s" ) > /dev/null 2> "$OUT/$t$O.err"
    r=$?
    if [ $r = 0 ] && [ -s "$OUT/$t$O.s" ]; then
      echo "$t $O: EMITS $(wc -c < "$OUT/$t$O.s") bytes"
    else
      echo "$t $O: rc=$r  $(grep -m1 'internal compiler error\|error:' "$OUT/$t$O.err" | cut -c1-110)"
    fi
  done
  echo "  -- gdb backtrace at -O2 --"
  sh "$S/eb-shell.sh" "cd $D/gcc && gdb -batch -ex run -ex bt \
     --args ./cc1 -quiet -nostdinc -O2 -ftarget-config=$cfg $IN -o /dev/null" \
     > "$OUT/$t.gdb" 2>&1
  grep -E '^#[0-9]+ ' "$OUT/$t.gdb" | head -12 | sed 's/^/    /'
  # A back end that ICEs at -O2 may still emit assemblable code at -O0, and
  # "compiles nothing" and "compiles, and a real assembler takes it" are the
  # two ends of this task's question.  So every .s this arm produced is put
  # through that target's own `as' -- an -O0 object of the right ELF machine
  # is a weaker result than an -O2 one and a far stronger one than an ICE.
  d=${3:-}; d=$TOOLROOT/$t
  for O in -O0 -O1 -O2; do
    s=$OUT/$t$O.s
    [ -s "$s" ] || continue
    [ -x "$d/$t-as" ] || { echo "  $t $O: assemble UNKNOWN (no as)"; continue; }
    if "$d/$t-as" -o "$OUT/$t$O.o" "$s" 2> "$OUT/$t$O.aserr"; then
      echo "  $t $O: ASSEMBLES  Machine: $("$d/$t-readelf" -h "$OUT/$t$O.o" | sed -n 's/^ *Machine: *//p')"
    else
      echo "  $t $O: as FAILS  $(grep -m1 Error "$OUT/$t$O.aserr" | cut -c1-100)"
    fi
  done
done
