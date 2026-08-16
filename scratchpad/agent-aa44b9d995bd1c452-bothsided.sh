#!/bin/sh
# BOTH-SIDED, EVERY CONFIGURED TARGET, AT -O0 AND AT -O2.
#
# Settles the question the one-line census CANNOT settle: the census reads
# "3 LOUD / 8 UNVERIFIED", and "compiled cleanly" is not "unaffected".  A pass
# writing through another back end's `machine_function' segfaults only when the
# offset lands outside the allocation; a back end whose struct is merely large
# enough takes the write SILENTLY.  The only instrument that sees that is the
# emitted assembly, compared against a compiler with the defect fixed.
#
# WHY -O2 IS NOT OPTIONAL, AND WHY AN -O0-ONLY BOARD IS AN UNDERCOUNT BY
# CONSTRUCTION.  The three passes that lose their owner on `clone ()' are
#
#   avr      avr_pass_fuse_add   writes func->machine BEFORE any test, so it
#                                acts at -O0 -- this is the crash
#   i386     pass_stv            gates on TARGET_STV && TARGET_SSE2, i386
#                                option state, 0 for a base that never set it
#   aarch64  pass_ldp_fusion     gates on flag_aarch64_late_ldp_fusion, which
#                                is `Init (1)' in aarch64.opt -- i.e. ON for
#                                EVERY back end -- but only when `optimize'
#
# so ldp_fusion is invisible at -O0 and live at -O2.  A board taken with the
# census's `-S' no-`-O' input would report the avr crash fixed and say NOTHING
# about an aarch64 RTL transform running on all 47 back ends.
#
# NON-VACUITY, AND IT IS BUILT IN RATHER THAN ASSERTED.  A null result here --
# "every target unchanged" -- is exactly what a broken harness prints: no
# specs-config, no compiler, a mistyped path.  Two independent guards:
#
#   1. the script FAILS (rc=9) if it compared 0 targets, and prints the count
#      it did compare, so "nothing ran" can never read as "nothing changed";
#   2. the three LOUD targets (microblaze, rx, sh) are a POSITIVE CONTROL on
#      the same run: they ICE in PRE and must not in POST.  If they come back
#      "unchanged", the harness is measuring one compiler twice -- which is the
#      failure mode a same-run control catches and a separate one does not.
#
# usage: PRE=<builddir> POST=<builddir> agent-aa44b9d995bd1c452-bothsided.sh
set -u
PRE=${PRE:?set PRE to the unfixed build dir}
POST=${POST:?set POST to the fixed build dir}
OUT=${OUT:-/tmp/bothsided-aa44b9d995bd1c452}

for B in "$PRE" "$POST"; do
  [ -x "$B/gcc/xgcc" ] || { echo "FATAL: no $B/gcc/xgcc"; exit 9; }
  [ -f "$B/MY-SRC" ]   || { echo "FATAL: no $B/MY-SRC"; exit 9; }
done
# The two build dirs must NOT be the same tree, or every row is unchanged by
# construction and the board is a tautology.
a=$(cat "$PRE/MY-SRC"); b=$(cat "$POST/MY-SRC")
[ "$a" != "$b" ] || { echo "FATAL: PRE and POST were configured from the SAME srcdir ($a)"; exit 9; }
echo "PRE  srcdir $a"
echo "POST srcdir $b"

VER=$(cat "$a/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }
rm -rf "$OUT"; mkdir -p "$OUT"
IN=$OUT/f.c
printf 'int f(int x){return x+1;}\n' > "$IN"

# A second, richer input for the -O2 arm.  `x+1' has no loads or stores at all,
# so a load/store-pair fusion pass has nothing to look at even when it runs --
# an input that cannot express the defect would report every target unchanged
# and look like a clean board.
IN2=$OUT/g.c
cat > "$IN2" <<'EOF'
struct s { long a, b, c, d; };
void g (struct s *p, struct s *q)
{
  p->a = q->a; p->b = q->b; p->c = q->c; p->d = q->d;
}
long h (long *p, int n)
{
  long t = 0;
  for (int i = 0; i < n; i++)
    t += p[i] + p[i + 1];
  return t;
}
EOF

run () {   # run <builddir> <cfg> <flags> <input> <outfile>
  "$1/gcc/xgcc" -B"$1/gcc/" -ftarget-config="$2" $3 -S -o "$5" "$4" \
      > "$5.msg" 2>&1
  echo $? > "$5.rc"
}

ncmp=0; nsame=0; ndiff=0; nfixed=0; nskip=0
printf '%-26s %-10s %-10s %s\n' TARGET ARM PRE POST
printf '%s\n' "-------------------------------------------------------------"

for d in "$PRE"/lib/gcc/"$VER"/*/; do
  T=$(basename "$d")
  CFG_PRE="$d/specs-config"
  CFG_POST="$POST/lib/gcc/$VER/$T/specs-config"
  if [ ! -f "$CFG_PRE" ] || [ ! -f "$CFG_POST" ]; then
    nskip=$((nskip + 1)); continue
  fi
  for arm in O0 O2; do
    case $arm in
      O0) fl=""    ; src=$IN  ;;
      O2) fl="-O2" ; src=$IN2 ;;
    esac
    p=$OUT/$T.$arm.pre.s; q=$OUT/$T.$arm.post.s
    run "$PRE"  "$CFG_PRE"  "$fl" "$src" "$p"
    run "$POST" "$CFG_POST" "$fl" "$src" "$q"
    rp=$(cat "$p.rc"); rq=$(cat "$q.rc")
    ncmp=$((ncmp + 1))
    # Classify by (rc, bytes).  An ICE leaves no .s, so compare rc first --
    # otherwise two missing files hash equal and score IDENTICAL, which is the
    # absent-artefact-as-a-pass shape this project keeps meeting.
    if [ "$rp" != 0 ] && [ "$rq" = 0 ]; then
      printf '%-26s %-10s %-10s %s\n' "$T" "$arm" "rc=$rp" "rc=0  FIXED"
      nfixed=$((nfixed + 1)); continue
    fi
    if [ "$rp" != "$rq" ]; then
      printf '%-26s %-10s %-10s %s\n' "$T" "$arm" "rc=$rp" "rc=$rq  RC-DIFF"
      ndiff=$((ndiff + 1)); continue
    fi
    if [ "$rp" != 0 ]; then
      printf '%-26s %-10s %-10s %s\n' "$T" "$arm" "rc=$rp" "rc=$rq  BOTH-FAIL"
      continue
    fi
    ha=$(md5sum < "$p" | cut -c1-12); hb=$(md5sum < "$q" | cut -c1-12)
    if [ "$ha" = "$hb" ]; then
      nsame=$((nsame + 1))
    else
      printf '%-26s %-10s %-10s %s\n' "$T" "$arm" "$ha" "$hb  CHANGED"
      ndiff=$((ndiff + 1))
    fi
  done
done

echo
echo "compared=$ncmp identical=$nsame changed=$ndiff fixed=$nfixed skipped(no specs-config)=$nskip"
[ "$ncmp" -gt 0 ] || { echo "FATAL: compared 0 targets -- nothing was measured."; exit 9; }
# POSITIVE CONTROL on this same run.
if [ "$nfixed" = 0 ]; then
  echo "FATAL: not one target went from failing to compiling.  The three LOUD"
  echo "  targets (microblaze, rx, sh) must do so; that none did means PRE and"
  echo "  POST are the same compiler and every IDENTICAL row above is vacuous."
  exit 9
fi
echo "positive control: $nfixed target/arm rows went rc!=0 -> rc=0."
