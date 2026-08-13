#!/bin/sh
# #113b -- the MAKE arms.  Run after t113b-conf.sh has produced /tmp/t113b/two.
set -u
S=$(cd "$(dirname "$0")" && pwd)
W=${W:-/tmp/t113b}
D="$W/two"
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
sh_run () {
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake perl flex bison gmp.dev mpfr.dev \
    libmpc texinfo --substituters 'https://cache.nixos.org/' --run "$1"
}

[ -f "$D/Makefile" ] || { echo "FATAL: no $D/Makefile; run t113b-conf.sh first"; exit 9; }
fail=0

echo "=============================================================="
echo "ARM F: the \$(eval) loop emitted a rule for EACH target"
echo "=============================================================="
sh_run "cd $D && make -p mtprobe_nonexistent_goal" > "$W/p.out" 2> "$W/p.err"
for t in "$T1" "$T2"; do
  if grep -q "^configure-target-specs-$t:" "$W/p.out"; then
    echo "  OK: rule configure-target-specs-$t exists"
  else
    echo "  FAIL: no rule for $t"; fail=1
  fi
done
# and they must be DISTINCT, not one rule serving both
a=$(grep -A20 "^configure-target-specs-$T1:" "$W/p.out" | grep -c "$T1/target-specs")
b=$(grep -A20 "^configure-target-specs-$T2:" "$W/p.out" | grep -c "$T2/target-specs")
echo "  $T1 recipe names its own dir $a time(s); $T2 names its own $b time(s)"
[ "$a" -ge 1 ] && [ "$b" -ge 1 ] || { echo "  FAIL: a recipe does not name its own subdir"; fail=1; }
if grep -A20 "^configure-target-specs-$T1:" "$W/p.out" | grep -q "$T2/target-specs"; then
  echo "  FAIL: $T1's recipe mentions $T2 -- cross-contamination"; fail=1
fi

echo
echo "=============================================================="
echo "ARM G (NEGATIVE): an EMPTY MT_TARGET_SUBDIRS must FAIL BY NAME"
echo "=============================================================="
# The bar: a loop that ran zero times must not score as a build.  Poison the
# substituted list in a COPY of the Makefile and require make to refuse.
sed 's/^MT_TARGET_SUBDIRS = .*/MT_TARGET_SUBDIRS =/' "$D/Makefile" > "$D/Makefile.empty"
sh_run "cd $D && make -f Makefile.empty configure-target-specs" \
  > "$W/empty.out" 2> "$W/empty.err"
rc=$?
if [ $rc = 0 ]; then
  echo "  FAIL: make SUCCEEDED with zero configured targets (rc=0)."
  echo "        The loop ran zero times and that scored as a build."
  fail=1
elif grep -q "MT_TARGET_SUBDIRS is empty" "$W/empty.err"; then
  echo "  OK: rc=$rc, failed by name:"
  grep "MT_TARGET_SUBDIRS is empty" "$W/empty.err" | head -2 | sed 's/^/      /'
else
  echo "  FAIL: rc=$rc but not by name:"; tail -5 "$W/empty.err" | sed 's/^/      /'; fail=1
fi

echo
echo "=============================================================="
echo "ARM H (NEGATIVE): a BROKEN \$(eval) loop must FAIL BY NAME"
echo "=============================================================="
# Distinct from arm G: here the target LIST is healthy but the loop that
# consumes it is sabotaged, so it emits nothing.  Without the
# MT_SPECS_EMITTED counter this produces a `configure-target-specs' with no
# prerequisites that succeeds instantly -- the false green in its purest form.
sed 's/^\$(foreach mt_t,\$(MT_TARGET_SUBDIRS),\\/$(foreach mt_t,,\\/' \
  "$D/Makefile" > "$D/Makefile.noloop"
if cmp -s "$D/Makefile" "$D/Makefile.noloop"; then
  echo "  FATAL: the sabotage changed nothing -- control is vacuous"; fail=1
else
  sh_run "cd $D && make -f Makefile.noloop configure-target-specs" \
    > "$W/noloop.out" 2> "$W/noloop.err"
  rc=$?
  if [ $rc = 0 ]; then
    echo "  FAIL: make SUCCEEDED with an empty loop (rc=0) -- false green"; fail=1
  elif grep -q "per-target instantiation ran" "$W/noloop.err"; then
    echo "  OK: rc=$rc, the counter caught it:"
    grep "per-target instantiation ran" "$W/noloop.err" | head -3 | sed 's/^/      /'
  else
    echo "  FAIL: rc=$rc but not by name:"; tail -5 "$W/noloop.err" | sed 's/^/      /'; fail=1
  fi
fi

echo
echo "=============================================================="
echo "ARM I: the old unsuffixed name FAILS BY NAME, not 'No rule'"
echo "=============================================================="
sh_run "cd $D && make all-target-specs" > "$W/old.out" 2> "$W/old.err"
rc=$?
if [ $rc = 0 ]; then
  echo "  FAIL: all-target-specs succeeded -- on whose target?"; fail=1
elif grep -q "is ambiguous in a multi-target build" "$W/old.err"; then
  echo "  OK: rc=$rc, refused by name and listed the alternatives:"
  head -5 "$W/old.err" | sed 's/^/      /'
else
  echo "  FAIL: rc=$rc but not by name:"; tail -5 "$W/old.err" | sed 's/^/      /'; fail=1
fi

echo
echo "=============================================================="
[ $fail = 0 ] && { echo "ALL MAKE ARMS PASS"; exit 0; }
echo "SOME MAKE ARMS FAILED"
exit 1
