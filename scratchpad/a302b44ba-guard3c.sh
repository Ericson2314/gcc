#!/bin/sh
# a302b44ba-guard3c.sh -- SHOW THAT mtcheck.sh's ASSEMBLER GUARD CAN FAIL,
# AND FIND OUT WHICH CLAUSE OF IT IS ACTUALLY LOAD-BEARING.
#
# `8be9340191f' rewrote GUARD 3c after finding it RED at the tip: it had string
# compared the driver's resolved `as' against the UNPREFIXED `$ASDIR/as', and
# `3ff8b3f835c' makes the driver find the machine-prefixed name first.  The
# rewrite accepts EITHER name and then requires `readlink -f' to prove the
# resolved file is the same binary as the tools dir's own `$T-as'.
#
# A REWRITTEN GUARD THAT NOW PASSES IS EXACTLY WHAT THIS PROJECT HAS BEEN
# BURNED BY.  "It went green after I edited it" is equally consistent with "I
# loosened it until it stopped complaining".  So the claim tested is not "3c
# passes" -- every run today prints that -- but the one that can be wrong: THAT
# THE BLOCK STILL REFUSES A WRONG ASSEMBLER.
#
# WHERE THE FAULT HAS TO GO, learned by getting it wrong first.  The obvious
# injection -- repoint `$ASDIR/{as,$T-as}' at the host assembler -- PROVES
# NOTHING, because mtcheck.sh line 335 does `rm -rf "$ASDIR"' and rebuilds both
# links from `$TDIR' before the guard runs.  The injected fault is erased by
# the script under test and the guard then reports green on a tree that was
# tampered with.  Measured, not reasoned: that run printed
# `assembler is riscv64-unknown-linux-gnu's own' with both links pointing at
# the host `as' on disk at launch.
#
# SO THE FAULT GOES IN `$TDIR' -- the MT_TOOLS_<target> directory, which is the
# real upstream of both links and which mtcheck.sh does NOT rewrite.  A tools
# dir whose `$T-as' is the HOST assembler is precisely the "wrong assembler"
# scenario GUARD 3c names.
#
# AND THAT INJECTION ANSWERS THE SHARPER QUESTION.  With the fault at $TDIR:
#   line 399 (`case $got in $ASDIR/as|$ASDIR/$T-as')  -- PASSES, name is right
#   line 404-405 (`readlink -f $got' = `readlink -f $TDIR/$T-as') -- PASSES,
#       and it passes BY CONSTRUCTION: $ASDIR/$T-as is a symlink mtcheck.sh
#       itself created pointing at $TDIR/$T-as, so `readlink -f' of the two is
#       the same file for ANY content of $TDIR.  That clause cannot distinguish
#       a right assembler from a wrong one; it only re-checks the link the
#       script just made.
#   line 411 (assemble and read the ELF machine back) -- THIS is the clause
#       that has to catch it.
# If the run comes back rc=0, the guard block is decorative and every green run
# citing it is unsupported.
#
# ON A THROWAWAY COPY AND ON s390x, whose ELF machine the host assembler cannot
# accidentally produce -- injecting the host `as' on an x86_64 arm would pass
# the machine check for a real reason and prove nothing.
#
# usage: a302b44ba-guard3c.sh
set -u
export LC_ALL=C
S=$(cd "$(dirname "$0")" && pwd)
ORIG=/tmp/b-302b44ba-mt
T=s390x-ibm-linux-gnu
C=/tmp/b-302b44ba-g3c          # MUST match */b-302b44ba* or mt_assert_builddir
                               # refuses -- it did, on the first attempt.
GOODTOOLS=/tmp/tools-302b44ba/bin
BADTOOLS=/tmp/b-302b44ba-g3c-badtools
HOSTAS=$(command -v as) || { echo "FATAL: no host as"; exit 9; }

[ -d "$C" ] || cp -a "$ORIG" "$C" || { echo "FATAL: copy failed"; exit 9; }

run () {   # run <tools dir> <logfile>
  MT_TAG=b-302b44ba MT_COMPILE_ONLY=1 WANT_ANCHOR=55 \
    MT_TOOLS_s390x_ibm_linux_gnu="$1" \
    MT_RUNTESTFLAGS='dfp.exp' \
    sh "$S/mtcheck.sh" "$C" "$T" > "$2" 2>&1
}

# ---- ARM A: the real tools dir must PASS ----------------------------------
# Without this arm a FAIL in ARM B proves nothing: the copy could simply be
# broken, and "refused a broken tree" is not "detected a wrong assembler".
echo "== ARM A: real tools dir, guard must PASS"
run "$GOODTOOLS" "$C/armA.log"; rcA=$?
grep -E '^-- guard: (driver|assembler)' "$C/armA.log" | sed 's/^/   /' | cut -c1-190
echo "   ARM A rc=$rcA"

# ---- ARM B: a tools dir whose $T-as IS THE HOST ASSEMBLER -----------------
echo "== ARM B: \$TDIR/$T-as is the HOST assembler ($HOSTAS)"
rm -rf "$BADTOOLS"; mkdir -p "$BADTOOLS"
# Every other tool stays genuine, so the ONLY difference between the two arms
# is the assembler.  A wholesale-broken tools dir would fail for many reasons.
for f in "$GOODTOOLS"/$T-*; do ln -sf "$(readlink -f "$f")" "$BADTOOLS/$(basename "$f")"; done
ln -sf "$HOSTAS" "$BADTOOLS/$T-as"
echo "   $BADTOOLS/$T-as -> $(readlink -f "$BADTOOLS/$T-as")"
run "$BADTOOLS" "$C/armB.log"; rcB=$?
grep -E 'FATAL|^-- guard: (driver|assembler)' "$C/armB.log" | sed 's/^/   /' | cut -c1-190
echo "   ARM B rc=$rcB"

echo
if [ "$rcA" != 0 ]; then
  echo "GUARD3C: INCONCLUSIVE -- the UNMODIFIED copy already fails (rc=$rcA)."
  echo "  Nothing can be concluded about the injected fault.  See $C/armA.log."
  exit 9
fi
if [ "$rcB" = 0 ]; then
  echo "GUARD3C: FAIL -- the host assembler was ACCEPTED (ARM B rc=0)."
  echo "  The assembler guard does not detect a wrong assembler, and every green"
  echo "  run that cites it is unsupported.  See $C/armB.log."
  exit 1
fi
echo "GUARD3C: PASS -- the block passes a correct tools dir and REFUSES one whose"
echo "  \$T-as is the host assembler.  Note WHICH clause did it, printed above:"
echo "  the readlink identity clause passes in BOTH arms (it compares a symlink"
echo "  with its own target and cannot fail by construction); the ELF-machine"
echo "  check at mtcheck.sh:411 is the one carrying this guard."
exit 0
