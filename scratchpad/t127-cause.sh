#!/bin/sh
# #127 -- THE DIVERGENCE, read in the RUNNING cc1.
#
# ONE BREAKPOINT PER RUN, and the breakpoint gdb ITSELF reports is printed and
# matched against the function under test before any value is scored.  #125
# lost three readings to three breakpoints in one run all firing in the wrong
# order, and one of those arms PASSED because 0/1 happened to be what it read.
#
# Two things are read, and they are different claims:
#
#   (1) THE FOUR REGNUMS, which is the leak: shared `emit-rtl.cc' builds the
#       four pointer rtxes, and before this change it built them all from
#       i386's numbers whatever the target.
#
#   (2) THE FOUR RTX POINTERS, which is the INVARIANT rtl.h used to enforce
#       through the SHAPE of `enum global_rtl_index' and now enforces through
#       the DATA in `init_emit_regs'.  rtl.h's comment requires that the
#       pointers be the SAME OBJECT when they name the same register.  Both
#       configured bases have all three pointers distinct, so what this arm can
#       show is the `!=' half on both sides; the `==' half is forced and read
#       separately by t127-guards.sh ARM 6, because no configured base aliases.
#
# The line the breakpoint goes on is LOCATED BY CONTENT, not hard-coded: a line
# number in a script is a fact about a file that moves under you.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b127}
fail=0

LN=$(grep -n '^  virtual_cfa_rtx = gen_raw_REG' "$SRC/gcc/emit-rtl.cc" | cut -d: -f1)
case "$LN" in
  ''|*[!0-9]*) echo "FATAL: could not locate the breakpoint line by content"; exit 9;;
esac
echo "breakpoint line located by content: emit-rtl.cc:$LN"

printf 'int x = 1;\n' > "$B/cause.c"

run () {         # $1 = cpu triple, $2 = tag
  cpu=$1; tag=$2
  cat > "$B/cause-$tag.gdb" <<EOF
set confirm off
set pagination off
break emit-rtl.cc:$LN
# BARE \`run'.  Giving it arguments REPLACES the ones \`--args' set, which
# silently drops \`-ftarget-config' -- and cc1 then dies with "no target
# configuration was selected" before ever reaching the breakpoint.  The
# non-vacuity check below is what caught that; it looked exactly like
# "the breakpoint is in dead code".
run
info breakpoints
frame
# READ OUT OF THE BUILT RTXES, NOT OUT OF THE LOCALS.  cc1 is built -O1 and
# the locals are "optimized out"; more to the point, the rtx is what every
# consumer in shared code actually sees, so this reads the artefact rather
# than an intermediate that a compiler is free to discard.
printf "MT127 $tag sp_regno=%u\n",  this_target_rtl->x_global_rtl[0]->u.reg.regno
printf "MT127 $tag fp_regno=%u\n",  this_target_rtl->x_global_rtl[1]->u.reg.regno
printf "MT127 $tag hfp_regno=%u\n", this_target_rtl->x_global_rtl[2]->u.reg.regno
printf "MT127 $tag ap_regno=%u\n",  this_target_rtl->x_global_rtl[3]->u.reg.regno
printf "MT127 $tag p_sp=%p\n",  this_target_rtl->x_global_rtl[0]
printf "MT127 $tag p_fp=%p\n",  this_target_rtl->x_global_rtl[1]
printf "MT127 $tag p_hfp=%p\n", this_target_rtl->x_global_rtl[2]
printf "MT127 $tag p_ap=%p\n",  this_target_rtl->x_global_rtl[3]
printf "MT127 $tag fp_eq_ap=%d\n", \
  (this_target_rtl->x_global_rtl[1] == this_target_rtl->x_global_rtl[3])
printf "MT127 $tag fp_eq_hfp=%d\n", \
  (this_target_rtl->x_global_rtl[1] == this_target_rtl->x_global_rtl[2])
printf "MT127 $tag REACHED_BREAKPOINT\n"
kill
quit
EOF
  sh "$S/eb-shell-gdb.sh" \
    "cd $B/gcc && gdb -batch -x $B/cause-$tag.gdb --args ./cc1 -quiet -nostdinc \
       -ftarget-config=$B/lib/gcc/17.0.0/$cpu/specs-config -o /dev/null $B/cause.c" \
    > "$B/cause-$tag.out" 2> "$B/cause-$tag.err"
  echo "--- $tag ($cpu) gdb rc=$?"
}

# ------------------------------------------------------------------ run 1
run aarch64-unknown-linux-gnu a64
# ------------------------------------------------------------------ run 2
run x86_64-pc-linux-gnu x86

for tag in a64 x86; do
  o="$B/cause-$tag.out"
  # NON-VACUITY FIRST.  "no reading" and "no divergence" look identical, and
  # #126 printed a clean verdict while gdb had never started at all.
  if ! grep -q "MT127 $tag REACHED_BREAKPOINT" "$o"; then
    echo "FAIL $tag: the breakpoint never fired -- nothing was measured"
    echo "  gdb said: $(head -5 "$B/cause-$tag.err" | tr '\n' ' ')"
    fail=1; continue
  fi
  # And match gdb's OWN report of where it stopped against the function under
  # test, rather than trusting that the address we asked for is the one it used.
  if ! grep -q 'in init_emit_regs' "$o"; then
    echo "FAIL $tag: gdb did not report stopping in init_emit_regs"
    grep -m3 'Breakpoint\|#0' "$o"
    fail=1; continue
  fi
  echo "$tag stopped in: $(grep -m1 'init_emit_regs' "$o")"
  grep "MT127 $tag" "$o" | grep -v REACHED_BREAKPOINT
done

echo "--- the divergence, both-sided (a count is not the divergence; these are contents)"
for k in sp_regno fp_regno hfp_regno ap_regno; do
  a=$(grep -m1 "MT127 a64 $k=" "$B/cause-a64.out" | sed 's/.*=//')
  x=$(grep -m1 "MT127 x86 $k=" "$B/cause-x86.out" | sed 's/.*=//')
  if [ -z "$a" ] || [ -z "$x" ]; then
    echo "FAIL $k: one side read empty (a64='$a' x86='$x')"; fail=1; continue
  fi
  if [ "$a" = "$x" ]; then
    echo "FAIL $k: both bases answered $a -- either still leaking, or everyone got the same NEW answer"
    fail=1
  else
    echo "ok  $k: aarch64=$a  x86_64=$x  (differ)"
  fi
done

echo "--- the rtl.h invariant, the '!=' half, on both bases"
for tag in a64 x86; do
  for k in fp_eq_ap fp_eq_hfp; do
    v=$(grep -m1 "MT127 $tag $k=" "$B/cause-$tag.out" | sed 's/.*=//')
    if [ "$v" != 0 ]; then
      echo "FAIL $tag $k=$v: these two registers differ on this base, so the rtxes must be distinct objects"
      fail=1
    else
      echo "ok  $tag $k=0 (distinct registers -> distinct rtx objects, as required)"
    fi
  done
done

echo "t127-cause.sh: $( [ $fail = 0 ] && echo PASS || echo FAIL )"
exit $fail
