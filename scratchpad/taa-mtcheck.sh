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
  */b-aa99*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree (PRINCIPLES 5)"; exit 9 ;;
esac
[ -f "$B/MY-SRC" ] || { echo "FATAL: $B has no MY-SRC stamp"; exit 9; }
SRC=$(cat "$B/MY-SRC")
grep -q "$SRC/configure" "$B/config.log" \
  || { echo "FATAL: $B/config.log does not name $SRC"; exit 9; }
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:?set WANT_ANCHOR}" ] \
  || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT_ANCHOR"; exit 9; }
[ -f "$SRC/SNAP-SHA" ] || { echo "FATAL: $SRC has no SNAP-SHA"; exit 9; }
[ ! -w "$SRC/gcc/Makefile.in" ] || { echo "FATAL: $SRC is writable"; exit 9; }
[ -x "$B/gcc/xgcc" ] || { echo "FATAL: no $B/gcc/xgcc"; exit 9; }
[ -x "$B/gcc/cc1" ]  || { echo "FATAL: no $B/gcc/cc1"; exit 9; }

S=$(cd "$(dirname "$0")" && pwd)
VER=$(cat "$SRC/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }
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
  # AND CLEAR THE STAMP BEFORE THE RUN, NOT ONLY WRITE IT AFTER.  A `.rc' left
  # by an EARLIER invocation is indistinguishable from this one's, so the
  # scorer read a finished-looking stamp beside a still-running suite and
  # printed the previous run's numbers.  That is the "a log being written looks
  # exactly like a log that finished" trap arriving through the very stamp
  # written to prevent it: the stamp has to be absent while the run is in
  # flight, or it certifies the wrong run.  Measured live, not reasoned about.
  rm -f "$B/check-$T.rc"

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
      make ${MT_MAKEFLAGS:-} check-gcc \
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
  # EVERY site.exp the run used, not one of them.  Under -j there is one per
  # parallel slot; checking a single arbitrary slot would leave the other 127
  # unexamined, and it is precisely a per-slot disagreement that this trap
  # would produce.
  nse=0; bad=0
  for SE in $(find "$B/gcc/$TSD" -name site.exp); do
    nse=$((nse+1))
    saw=$(sed -n 's/^set target_triplet //p' "$SE" | head -1)
    if [ "$saw" != "$T" ]; then
      echo "FATAL[$T]: $SE says target_triplet=$saw, not $T."
      echo "  This is the stale-site.exp trap: the suite ran, cleanly, and"
      echo "  attributed its results to the wrong target."
      bad=$((bad+1))
    fi
  done
  [ "$bad" = 0 ] || exit 9
  # Non-vacuity: zero site.exp files would pass the loop above by never
  # entering it, which reads as a green and means the run did not happen.
  [ "$nse" -gt 0 ] || { echo "FATAL[$T]: no site.exp under $B/gcc/$TSD -- the run did not happen"; exit 9; }
  echo "-- guard: all $nse site.exp files attribute to $T"

  # GUARD 4 -- multi-target.exp MUST HAVE BEEN REACHED.  That file is inert
  # unless MT_TARGET_NAME is in runtest's environment, and an inert run looks
  # exactly like a working one: same test names, same counts, no stamp saying
  # which target produced them.  Its section-1 banner is the only evidence the
  # environment arrived, so read it back out of the log.  Without this arm the
  # `mechanism-present-but-never-invoked' shape survives the whole harness.
  # The MERGED log, by exact path -- see mtscore.sh: under -j the slot dirs
  # each hold their own gcc.log and `head -1' picks one of 128 at random.
  LOG="$B/gcc/$TSD/gcc/gcc.log"
  if [ -z "$LOG" ] || ! grep -q "MULTI-TARGET RUN: target = $T" "$LOG"; then
    echo "FATAL[$T]: gcc.log carries no 'MULTI-TARGET RUN: target = $T' banner."
    echo "  multi-target.exp did not see MT_TARGET_NAME, so it was INERT:"
    echo "  no attribution stamp and no compile-only downgrade.  The counts"
    echo "  would be real but unattributed.  Refusing."
    exit 9
  fi
  echo "-- guard: multi-target.exp banner present (the .exp was reached)"

  # GUARD 5 -- THE COMPILE-ONLY DOWNGRADE MUST HAVE INSTALLED ITSELF.  NEW
  # HERE, and it is the arm the two-target harness was missing.
  #
  # multi-target.exp installs the downgrade only if `[info procs dg-do]' is
  # non-empty AT THE MOMENT gcc-dg.exp load_lib's it.  That is a load-order
  # condition, not a flag: if dg.exp has not been read yet the rename is
  # SKIPPED, MT_COMPILE_ONLY is silently inert, every `dg-do run' links, and
  # the whole board acquires a uniform "no target libgcc here" FAIL floor that
  # looks like a back-end result.  Guard 4 cannot see it -- section 1's banner
  # is printed unconditionally from a different `if'.  So read section 2's own
  # banner back, and only when compile-only was actually asked for.
  if [ -n "${MT_COMPILE_ONLY:-}" ] \
     && ! grep -q 'MULTI-TARGET RUN: compile-only' "$LOG"; then
    echo "FATAL[$T]: MT_COMPILE_ONLY was set and the downgrade did NOT install."
    echo "  multi-target.exp section 2 is guarded on [info procs dg-do]; the"
    echo "  run linked its dg-do run tests and the FAIL column is a floor."
    exit 9
  fi
  [ -z "${MT_COMPILE_ONLY:-}" ] \
    || echo "-- guard: compile-only downgrade installed (section 2 banner)"
done

# GUARD 6 -- THE SPEC FILES MUST NOT BE THE SAME FILE UNDER N NAMES.
# #113b: with the cross assembler off PATH, target-specs falls back to the
# build machine's `as' and writes a file that NAMES the target while
# DESCRIBING x86_64.  Guard 1 checks existence and guard 2 asks the compiler
# its name; neither can see two targets sharing one probe's answer.  At two
# targets a human noticed the md5s differed; at N nobody will.  Compared by
# md5 across the whole run, refused by name.
dup=$(for T in "$@"; do
        md5sum < "$B/lib/gcc/$VER/$T/specs-config" | cut -d' ' -f1
      done | sort | uniq -d)
if [ -n "$dup" ]; then
  echo "FATAL: two targets in this run have byte-identical specs-config files."
  for T in "$@"; do
    printf '  %-30s %s\n' "$T" "$(md5sum < "$B/lib/gcc/$VER/$T/specs-config" | cut -c1-12)"
  done
  echo "  cause: target-specs probed the same tools twice -- a file NAMING one"
  echo "         target while DESCRIBING another (#113b)."
  exit 9
fi
echo "-- guard: all $# specs-config files are distinct"

echo
# MT_SCORER lets a caller that copied these scripts elsewhere (to keep an
# in-flight run safe from edits to the originals) name the copy.  Refuse by
# name rather than let the run end with a bare "No such file": the suite has
# already cost an hour by that point and a missing scorer would otherwise
# discard it.
SCORER=${MT_SCORER:-$S/taa-mtscore.sh}
[ -f "$SCORER" ] || { echo "FATAL: no scorer at $SCORER (set MT_SCORER)"; exit 9; }
sh "$SCORER" "$B" "$@"
