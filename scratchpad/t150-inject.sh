#!/bin/sh
# #150 -- CAN THE FIX FAIL?  Inject the exact fault it removes and require the
# tree to notice.  PRINCIPLES section 4: "an unfired mitigation is
# indistinguishable from an absent one, and reads as protection."
#
# The fault injected is the state before this task: genemit's un-namespaced run
# emits the bare `add_clobbers' / `added_clobbers_hard_reg_p' again.
#
# TWO ARMS, AND THE FIRST IS THE DECISIVE ONE.
#
#  ARM A -- CONTENT.  Regenerate and read `insn-emit-*.cc'.  This is the arm
#    that matters, because PRINCIPLES section 4 records a GENERATOR that ran,
#    exited 0 and changed nothing: the header came out byte-identical,
#    `move-if-change' therefore kept the old one, and make reported success.
#    Exit status, existence, timestamp and non-emptiness ALL pass on that.  So
#    this asserts on the text by name, in BOTH directions.
#
#  ARM B -- LINK.  With both definitions present the link should fail naming
#    `add_clobbers'.  Reported honestly either way and NOT relied on, because
#    libbackend.a is an ARCHIVE: a duplicate definition is diagnosed only when
#    both members are pulled in for other reasons, and `ld' once reported 7 of
#    40 on this branch.  If arm B does NOT fire that is a finding -- it means
#    the linker would silently keep one of the two bodies, by link order.
#
# usage: t150-inject.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${1:?build dir}
case "$B" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
G="$SRC/gcc/genemit.cc"
BK=/tmp/t150-genemit.cc.orig

bare_count () {
  # The bare definition is the one with no `insn_<base>::' qualification;
  # genemit writes it as a line starting `add_clobbers (rtx pattern'.
  grep -l '^add_clobbers (rtx pattern' "$B"/gcc/insn-emit-[0-9]*.cc 2>/dev/null \
    | grep -c . || true
}

echo "== state with the fix in place"
n0=$(bare_count)
echo "  singular insn-emit-*.cc defining a BARE add_clobbers: $n0  (want 0)"
[ "$n0" = 0 ] || { echo "FATAL: the fix is not in this build dir; nothing to inject"; exit 9; }

echo
echo "== injecting: remove genemit's suppression guard"
cp "$G" "$BK"
# Delete the guard line and its braces.  Then ASSERT the injection produced
# the state intended -- PRINCIPLES section 7: an injection that merely "ran"
# is not evidence, and one that deleted half a hunk produced a third state
# nobody was testing.
awk '
  /if \(!gen_multi_target_p \(\) \|\| gen_target_ns \(\) != NULL\)/ { skip=1; next }
  skip==1 && /^    \{$/ { skip=2; next }
  skip==2 && /^    \}$/ { skip=0; next }
  { print }
' "$BK" > "$G.tmp" && mv "$G.tmp" "$G"

if grep -q 'gen_multi_target_p () || gen_target_ns () != NULL' "$G"; then
  echo "FATAL: injection did not remove the guard"; cp "$BK" "$G"; exit 9
fi
if ! grep -q 'output_add_clobbers (file);' "$G"; then
  echo "FATAL: injection removed the CALL as well as the guard -- that is a"
  echo "third state, not the one under test"; cp "$BK" "$G"; exit 9
fi
echo "  ok: guard gone, output_add_clobbers call intact"

echo
echo "== ARM A: regenerate and read the artefact"
sh "$S/eb-shell.sh" "cd $B/gcc && make -j8 s-tmp-emit" > "$B/t150-inj-gen.out" 2>&1
echo "  regen rc=$?"
n1=$(bare_count)
echo "  singular insn-emit-*.cc defining a BARE add_clobbers: $n1  (want 1)"
if [ "$n1" -ge 1 ]; then echo "  ARM A: FIRED (the guard is load-bearing)"
else echo "  ARM A: DID NOT FIRE -- the suppression is not what removes the"
     echo "         bare definition, and the story for this fix is wrong"; fi

echo
echo "== ARM B: link"
sh "$S/eb-shell.sh" "cd $B/gcc && make -j8 cc1" > "$B/t150-inj-link.out" 2> "$B/t150-inj-link.err"
rc=$?
echo "  make cc1 rc=$rc"
if grep -q 'multiple definition.*add_clobbers' "$B/t150-inj-link.err"; then
  echo "  ARM B: FIRED, by name:"
  grep -m2 'multiple definition.*add_clobbers' "$B/t150-inj-link.err" | sed 's/^/    /'
else
  echo "  ARM B: no multiple-definition diagnostic naming add_clobbers."
  echo "  That is the ARCHIVE behaviour PRINCIPLES warns about, not a pass."
  tail -5 "$B/t150-inj-link.err" | sed 's/^/    /'
fi

echo
echo "== restoring"
cp "$BK" "$G"
grep -q 'gen_multi_target_p () || gen_target_ns () != NULL' "$G" \
  && echo "  ok: guard restored" || echo "  FATAL: restore failed"
sh "$S/eb-shell.sh" "cd $B/gcc && make -j8 s-tmp-emit cc1" \
  > "$B/t150-inj-restore.out" 2>&1
echo "  rebuild rc=$?  bare now: $(bare_count) (want 0)"
