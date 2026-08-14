#!/bin/sh
# mtcheck.sh -- run the gcc testsuite ONCE PER CONFIGURED TARGET.
#
# `gcc/testsuite/lib/multi-target.exp' (commit dbd2c1e5843) is the half of this
# harness that runs INSIDE runtest, and its own comments say it is "what the
# mtnix board and mtcheck.sh do".  NEITHER OF THOSE FILES HAS EVER EXISTED IN
# THE TREE.  That commit added the .exp and a `load_lib' line and nothing else;
# its message describes four guards that live in a file nobody committed.  This
# is the file, written against that description, and PRINCIPLES 4 applies to it
# in full: a comment naming a guard reads as evidence the guard ran.
#
# usage: mtcheck.sh <builddir> <triple> [<triple> ...]
#   MT_RUNTESTFLAGS  extra runtest flags (e.g. "dg.exp=pr*" to take a subset)
#   MT_COMPILE_ONLY  non-empty => downgrade dg-do run/link/assemble to compile
#
# WHAT IS SINGULAR IN THE STOCK HARNESS, which is what this script works around:
#
#   1. site.exp's `target_triplet'/`target_alias' come from $(TEST_TARGET)
#      (gcc/Makefile.in:678), one triple per make invocation.
#   2. AND site.exp DOES NOT DEPEND ON TEST_TARGET.  Its prerequisites are
#      `./config.status Makefile testsuite/et-static.exp'.  So a second `make
#      check-gcc TEST_TARGET=<other>' finds site.exp up to date and REUSES THE
#      FIRST TARGET'S TRIPLE.  That is not a visible error; it is a clean run
#      attributed to the wrong target -- exactly the failure multi-target.exp
#      section 1 exists to catch.  Hence the `rm -f site.exp' below, and hence
#      the POST-CONDITION check that reads the triple back out of the generated
#      per-run site.exp rather than trusting that make did what was asked.
#   3. TESTSUITEDIR defaults to `testsuite', so every target writes the same
#      gcc.sum/gcc.log and the same tmpdir.  Made per-target here.
#   4. GCC_UNDER_TEST defaults to [find_gcc] (a libgloss proc), which yields a
#      bare `xgcc' carrying no -ftarget-config=.  With no target selected cc1
#      dies in option_init_struct.  Set explicitly; every in-tree site that
#      calls find_gcc is guarded by `if ![info exists GCC_UNDER_TEST]', so a
#      command-line assignment wins.
set -u

B=${1:?build dir}; shift
[ $# -ge 1 ] || { echo "FATAL: name at least one target triple"; exit 9; }

case "$B" in
  */b-a78a*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree (PRINCIPLES 5)"; exit 9 ;;
esac
[ -f "$B/MY-SRC" ] || { echo "FATAL: $B has no MY-SRC stamp"; exit 9; }
SRC=$(cat "$B/MY-SRC")
grep -q "$SRC/configure" "$B/config.log" \
  || { echo "FATAL: $B/config.log does not name $SRC"; exit 9; }
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:?set WANT_ANCHOR}" ] \
  || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT_ANCHOR"; exit 9; }
( cd "$SRC" && git diff --quiet ) \
  || { echo "FATAL: $SRC changed under the build"; exit 9; }
[ -x "$B/gcc/xgcc" ] || { echo "FATAL: no $B/gcc/xgcc"; exit 9; }
[ -x "$B/gcc/cc1" ]  || { echo "FATAL: no $B/gcc/cc1"; exit 9; }

S=$(cd "$(dirname "$0")" && pwd)
VER=$(cat "$B/gcc/BASE-VER")
RTF=${MT_RUNTESTFLAGS:-}
echo "== mtcheck: srcdir $SRC anchor=$n  gcc $VER  targets: $*"
echo "== runtestflags: [$RTF]  compile-only: [${MT_COMPILE_ONLY:-}]"

for T in "$@"; do
  echo
  echo "################ $T"
  CFG="$B/lib/gcc/$VER/$T/specs-config"

  # GUARD 1 -- the spec file must EXIST, and the diagnostic must name the real
  # cause.  `target-specs' silently SKIPs a target whose <triple>-as/-ld is off
  # PATH; without this the symptom surfaces three layers away as a cc1 error
  # about option_init_struct.  Not `test -s': a truncated specs file is
  # non-empty (PRINCIPLES 4 -- this machinery once shipped 39 lines of 101).
  if [ ! -f "$CFG" ]; then
    echo "FATAL[$T]: no $CFG"
    echo "  cause: target-specs was not run for $T, or it SKIPped because"
    echo "         $T-as / $T-ld were not on PATH when it ran."
    exit 9
  fi
  echo "-- specs-config: wc -l $(wc -l < "$CFG")  md5 $(md5sum < "$CFG" | cut -c1-12)"

  # GUARD 2 -- cc1 must NAME THE TARGET BACK.  A config file naming some other
  # triple, or one describing x86_64 while called <other>, is FATAL rather than
  # a pass.  Read the target out of the RUNNING compiler, not out of the
  # filename: a file NAMING a target while DESCRIBING x86_64 passes every
  # name- and path-based check there is (PRINCIPLES 5).
  echo 'int mt_probe;' > "$B/mt-probe-$T.c"
  got=$("$B/gcc/xgcc" -B"$B/gcc/" -ftarget-config="$CFG" \
          -dumpmachine "$B/mt-probe-$T.c" 2>"$B/mt-probe-$T.err")
  if [ "$got" != "$T" ]; then
    echo "FATAL[$T]: the compiler reports its target as '$got', not '$T'"
    sed -n '1,5p' "$B/mt-probe-$T.err"
    exit 9
  fi
  echo "-- guard: compiler names the target back: $got"

  # GUARD 3 -- NON-VACUITY.  The flag must be load-bearing ON `xgcc'
  # SPECIFICALLY.  #38's first harness tested a <triple>-gcc driver, which
  # resolves its target from its OWN NAME (gcc.cc:8722), so removing the flag
  # from that line proves nothing and the arm passed vacuously.  `xgcc' carries
  # no triple, so with the flag gone it MUST fail.  If it does not, this whole
  # run is measuring a compiler that chose its own target and every number
  # below is about an unknown target.
  if "$B/gcc/xgcc" -B"$B/gcc/" -S -o /dev/null "$B/mt-probe-$T.c" \
       > "$B/mt-vac-$T.out" 2>&1; then
    echo "FATAL[$T]: xgcc compiled with NO -ftarget-config= at all."
    echo "  The flag is not selecting anything; this run would measure an"
    echo "  unknown target.  Refusing to report a result."
    exit 9
  fi
  echo "-- guard: non-vacuity OK (bare xgcc refuses to compile without the flag)"

  # ---- the run itself ----
  TSD="testsuite.$T"
  # See note 2 in the header: site.exp does not depend on TEST_TARGET.
  rm -f "$B/gcc/site.exp"
  rm -rf "$B/gcc/$TSD"

  # MT_TARGET_NAME / MT_TARGET_CONFIG / MT_COMPILE_ONLY are read by
  # gcc/testsuite/lib/multi-target.exp (commit dbd2c1e5843), which gcc-dg.exp
  # already load_lib's.  That file is NOT re-implemented here: it supplies the
  # attribution stamp, the compile-only downgrade and the version-banner fix
  # from inside runtest, and it is INERT until these three reach the
  # environment.  Exported in the shell rather than passed only as make
  # variables, so that reaching runtest's environment does not depend on
  # GNU make's command-line-variable export rule.
  ( cd "$B/gcc" && sh "$S/eb-shell-dj.sh" "cd $B/gcc && \
      MT_TARGET_NAME=$T \
      MT_TARGET_CONFIG=$CFG \
      MT_COMPILE_ONLY='${MT_COMPILE_ONLY:-}' \
      export MT_TARGET_NAME MT_TARGET_CONFIG MT_COMPILE_ONLY; \
      make check-gcc \
        TEST_TARGET=$T \
        TESTSUITEDIR=$TSD \
        RUNTESTFLAGS=\"GCC_UNDER_TEST='$B/gcc/xgcc -B$B/gcc/ -ftarget-config=$CFG' $RTF\"" \
  ) > "$B/check-$T.out" 2> "$B/check-$T.err"
  rc=$?
  # Stamp the exit, and let the scorer refuse a run with no stamp: a log being
  # written looks exactly like a log that finished (PRINCIPLES 4).
  echo "$rc" > "$B/check-$T.rc"
  echo "-- make check-gcc rc=$rc"

  # POST-CONDITION -- read the triple back out of the site.exp the run actually
  # used.  This is the arm that catches note 2 above, and it is deliberately a
  # READ of the generated artefact rather than a belief about make.
  SE=$(find "$B/gcc/$TSD" -name site.exp | head -1)
  if [ -z "$SE" ]; then
    echo "FATAL[$T]: no site.exp under $B/gcc/$TSD -- the run did not happen"
    exit 9
  fi
  saw=$(sed -n 's/^set target_triplet //p' "$SE" | head -1)
  if [ "$saw" != "$T" ]; then
    echo "FATAL[$T]: the run's site.exp says target_triplet=$saw, not $T."
    echo "  This is the stale-site.exp trap: the suite ran, cleanly, and"
    echo "  attributed its results to the wrong target."
    exit 9
  fi
  echo "-- guard: run's site.exp attributes to $saw"

  # GUARD 4 -- multi-target.exp MUST HAVE BEEN REACHED.  That file is inert
  # unless MT_TARGET_NAME is in runtest's environment, and an inert run looks
  # exactly like a working one: same test names, same counts, no stamp saying
  # which target produced them.  Its section-1 banner is the only evidence the
  # environment arrived, so read it back out of the log.  Without this arm the
  # `mechanism-present-but-never-invoked' shape survives the whole harness.
  LOG=$(find "$B/gcc/$TSD" -name 'gcc.log' | head -1)
  if [ -z "$LOG" ] || ! grep -q "MULTI-TARGET RUN: target = $T" "$LOG"; then
    echo "FATAL[$T]: gcc.log carries no 'MULTI-TARGET RUN: target = $T' banner."
    echo "  multi-target.exp did not see MT_TARGET_NAME, so it was INERT:"
    echo "  no attribution stamp and no compile-only downgrade.  The counts"
    echo "  would be real but unattributed.  Refusing."
    exit 9
  fi
  echo "-- guard: multi-target.exp banner present (the .exp was reached)"
done

echo
sh "$S/mtscore.sh" "$B" "$@"
