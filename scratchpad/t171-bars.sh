#!/bin/sh
# #171 -- the two-base bars, and the evidence that a NON-i386 target pass now
# runs, both sides, in one run.
#
# ARM 0 IS THE NON-VACUITY ARM AND IT RUNS FIRST.  Everything below scores by
# comparing outputs of two compilers, and every failure mode of this harness --
# a missing cc1, a missing specs-config, a compiler that refuses everything --
# produces EMPTY or EQUAL output, which is exactly what "no change" and "no
# regression" look like.  So before any comparison, prove that each compiler
# ran, produced code, and can still FAIL: each is asked for a target it was not
# configured for and must refuse BY NAME.
#
# usage: t171-bars.sh <before build dir> <after build dir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
BEF=${1:?before build dir}
AFT=${2:?after build dir}
for D in "$BEF" "$AFT"; do
  case "$D" in
    */b-a0e5*) ;;
    *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
  esac
done
BIG=$S/big.c
[ -f "$BIG" ] || { echo "FATAL: no $BIG"; exit 9; }
O=/tmp/t171-bars; rm -rf $O; mkdir -p $O
T1=x86_64-pc-linux-gnu
T2=aarch64-unknown-linux-gnu

cc1_of () { echo "$1/gcc/cc1"; }
cfg_of () { echo "$1/lib/gcc/17.0.0/$2/specs-config"; }

run () { # <builddir> <target> <tag> <extra flags...>
  d=$1; t=$2; tag=$3; shift 3
  sh "$S/eb-shell.sh" "cd $O && $(cc1_of "$d") -quiet -nostdinc \
    -ftarget-config=$(cfg_of "$d" "$t") $* -o $O/$tag.s" \
    > "$O/$tag.out" 2> "$O/$tag.err"
  echo $? > "$O/$tag.rc"
}

echo "######## ARM 0 -- NON-VACUITY.  Nothing below is scored unless this passes."
fatal=0
for d in "$BEF" "$AFT"; do
  c=$(cc1_of "$d")
  [ -x "$c" ] || { echo "  FATAL: $c is not executable"; fatal=1; continue; }
  echo "  $c: $(wc -c < "$c") bytes"
  for t in $T1 $T2; do
    f=$(cfg_of "$d" "$t")
    [ -f "$f" ] || { echo "  FATAL: no $f -- target-specs did not run"; fatal=1; }
  done
done
[ "$fatal" = 0 ] || exit 9
# ... and each compiler must still be able to say no.  A cc1 that accepts
# anything, or that dies before parsing, would make every arm below quiet.
# THE BOGUS TRIPLE MUST BE ONE NO BUILD HERE CONFIGURES, and the first draft
# used `sparc64-unknown-linux-gnu' -- which IS configured in the eight-base
# build, so the compiler accepted it, compiled, and ICEd in `ehcleanup'.  The
# control then reported FATAL on a correct compiler.  A negative control whose
# validity depends on the configuration is the same defect this task is about,
# committed by its own harness.  `m68k' is in no base set used here.
sed 's/^target .*/target m68k-unknown-linux-gnu/' "$(cfg_of "$AFT" "$T1")" \
  > "$O/bogus-config"
sh "$S/eb-shell.sh" "cd $O && $(cc1_of "$AFT") -quiet -nostdinc \
  -ftarget-config=$O/bogus-config $BIG -o $O/bogus.s" \
  > "$O/bogus.out" 2> "$O/bogus.err"
echo "  negative control (a target this compiler was not configured for): rc=$?"
grep -m1 . "$O/bogus.err" | sed 's/^/    /'
grep -q 'not one of the targets' "$O/bogus.err" \
  || { echo "  FATAL: the compiler did not refuse an unconfigured target by name;"; \
       echo "  a harness whose only failure mode is silence cannot score anything."; \
       exit 9; }

echo
echo "######## ARM 1 -- x86_64 -O2 big.c.  MUST NOT MOVE."
echo "# i386's target passes still run for i386.  If this changes, the gate is"
echo "# refusing passes to their OWN back end."
for side in bef aft; do
  d=$BEF; [ $side = aft ] && d=$AFT
  run "$d" "$T1" "x86-$side" -O2 "$BIG"
  echo "  $side: rc=$(cat $O/x86-$side.rc)  $(wc -c < $O/x86-$side.s) bytes  md5=$(md5sum < $O/x86-$side.s | cut -c1-12)"
done
cmp -s "$O/x86-bef.s" "$O/x86-aft.s" && echo "  IDENTICAL" || echo "  CHANGED -- investigate"

echo
echo "######## ARM 2 -- aarch64 -O2 big.c.  EXPECTED TO MOVE."
echo "# aarch64's eight target passes were absent from pass-instances.def and"
echo "# are now present and selected, so a change here is the fix landing."
for side in bef aft; do
  d=$BEF; [ $side = aft ] && d=$AFT
  run "$d" "$T2" "a64-$side" -O2 "$BIG"
  echo "  $side: rc=$(cat $O/a64-$side.rc)  $(wc -c < $O/a64-$side.s) bytes  md5=$(md5sum < $O/a64-$side.s | cut -c1-12)"
done
cmp -s "$O/a64-bef.s" "$O/a64-aft.s" && echo "  IDENTICAL" || echo "  CHANGED"

echo
echo "######## ARM 3 -- BTI, the pass the brief names, in a COMPILED FUNCTION."
cat > "$O/bti.c" <<'EOF'
int f (int a) { return a + 1; }
int g (int a) { return f (a) + f (a + 1); }
EOF
for side in bef aft; do
  d=$BEF; [ $side = aft ] && d=$AFT
  run "$d" "$T2" "bti-$side" -O2 -mbranch-protection=standard "$O/bti.c"
  n=$(grep -c '\bbti\b\|\bpaciasp\b\|\bhint\b' "$O/bti-$side.s" || true)
  echo "  $side: rc=$(cat $O/bti-$side.rc)  bti/paciasp/hint lines=$n"
  grep -n '\bbti\b\|\bpaciasp\b\|\bhint\b\|^f:\|^g:' "$O/bti-$side.s" | sed 's/^/      /'
done

echo
echo "######## ARM 4 -- the pass tree the compiler actually built (-fdump-passes)."
echo "# Reads the RUNNING compiler rather than the generated file: 'the pass is"
echo "# in pass-instances.def' and 'the pass is in the tree and enabled' are two"
echo "# claims, and the second is the one that matters."
for side in bef aft; do
  d=$BEF; [ $side = aft ] && d=$AFT
  for t in $T1 $T2; do
    tag=$side-$(echo "$t" | cut -d- -f1)
    run "$d" "$t" "$tag" -O2 -fdump-passes "$O/bti.c"
    echo "  $side/$tag:"
    # `-fdump-passes' prints `  <name>  :  ON|OFF' per pass, so the names are
    # matched without anchors.  A pass that is not in the tree at all does not
    # appear -- which is why ABSENT and OFF have to be read as different
    # things: before this change aarch64's passes were absent, and an `OFF'
    # would have been the wrong conclusion from the same silence.
    grep -E '(stv|vzeroupper|apxnf|x86_cse|rpad|endbr|align_tight|bti|early_ra|fma_steering|speculation|ldp_fusion|narrow_gp|pstate)' \
      "$O/$tag.err" | sed 's/^ */      /' | sort -u
  done
done
