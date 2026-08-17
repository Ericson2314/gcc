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
#   MT_CHECK_TOOL    `gcc' (default) or `g++'
#
# MT_CHECK_TOOL EXISTS BECAUSE `check-gcc' WAS HARDCODED HERE, AND THAT IS HALF
# THE REASON NO C++ RESULT HAS EVER BEEN MEASURED ON THIS BRANCH (the other
# half was `--enable-languages=c,lto' hardcoded in mt-conf.sh).  A whole front
# end was outside the harness with nothing saying so.
#
# THE ASSERTION THAT MAKES A C++ FIGURE MEAN ANYTHING IS BELOW, AND IT IS THE
# POINT: a language that was never enabled and a language that passes
# everything produce THE SAME EMPTY FAILURE LIST.  So `cc1plus' and `xg++' are
# required to EXIST before the run, and `g++.sum' is required to exist after
# it.  `g++-dg.exp' load_lib's `gcc-dg.exp', which load_lib's
# `multi-target.exp', so GUARD 4's banner arm fires for g++ unchanged -- that
# was checked, not assumed.
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
S=$(cd "$(dirname "$0")" && pwd)
MT_LIB_DIR=$S
. "$S/mt-lib.sh"

B=${1:?build dir}; shift
[ $# -ge 1 ] || { echo "FATAL: name at least one target triple"; exit 9; }

# THE BUILD-DIR GUARD IS DERIVED, NOT HARDCODED.  It used to read `*/b-a78a*',
# this worktree's hash, which is why `t175-mtcheck.sh' exists: the next agent
# could not run this file and copied it under a task number.  Same guard, no
# edit needed per worktree, no task number to collide on.  See mt-lib.sh.
mt_assert_builddir "$B"
SRC=$(mt_src_of "$B") || exit 9
mt_assert_configured_from "$B" "$SRC"
n=$(mt_assert_anchor "$SRC") || exit 9
# BOTH freeze arms.  This file asserted `git diff --quiet' (live worktree) and
# t175-mtcheck.sh asserted SNAP-SHA + read-only (immutable snapshot); each is
# wrong for the other's srcdir -- `git diff' in a `git archive' extraction has
# no repository and walks UP, turning the check into an error.
kind=$(mt_assert_src_frozen "$SRC") || exit 9
[ -x "$B/gcc/xgcc" ] || { echo "FATAL: no $B/gcc/xgcc"; exit 9; }
[ -x "$B/gcc/cc1" ]  || { echo "FATAL: no $B/gcc/cc1"; exit 9; }

# The tool under test, and the four things that are a function of it.
TOOL=${MT_CHECK_TOOL:-gcc}
case "$TOOL" in
  gcc) DRIVER=xgcc; UTVAR=GCC_UNDER_TEST; SUMDIR=gcc; SUM=gcc ;;
  g++) DRIVER=xg++; UTVAR=GXX_UNDER_TEST; SUMDIR=g++; SUM=g++
       # SETTING `GXX_UNDER_TEST' ALONE IS NOT ENOUGH, MEASURED.  `g++.exp'
       # still reaches `GCC_UNDER_TEST' -- `gcc-defs.exp' and the libstdc++
       # probing in `g++_init' run the C driver -- and that default is a bare
       # `xgcc' with no `-ftarget-config=', so on a compiler with no default
       # target every one of those invocations dies with
       #
       #   xgcc: fatal error: no target selected
       #
       # and runtest exits having written a ZERO-BYTE `g++.sum'.  `make
       # check-g++' STILL RETURNS 0.  So the whole suite "passed" in 40
       # seconds with an empty failure list -- the exact null-result-as-a-pass
       # shape this file's header names -- and the only thing that caught it
       # was GUARD 4's banner arm.  Both variables are set below.
       #
       # THE NULL-RESULT ARM.  Without these two lines a build configured
       # `c,lto' runs `make check-g++', which has no rule, prints nothing, and
       # produces an EMPTY failure list -- indistinguishable from a front end
       # that passes everything.  Refuse by name instead.
       [ -x "$B/gcc/cc1plus" ] || { echo "FATAL: no $B/gcc/cc1plus -- the C++ front end was never built, and an unbuilt language and a passing language give the same empty failure list"; exit 9; }
       [ -x "$B/gcc/xg++" ]    || { echo "FATAL: no $B/gcc/xg++"; exit 9; } ;;

  # ---- THE OTHER NINE FRONT ENDS ---------------------------------------
  #
  # `gcc' and `g++' were the whole table, and the reason is the same one that
  # made `--enable-languages=c,lto' the whole build: a hardcoded pair decided,
  # silently, which languages could ever be measured.  The tree declares
  # FOURTEEN languages (gcc/*/config-lang.in) and `lang_checks' names ten
  # `check-*' targets; a front end absent from this `case' was refused by name,
  # which is the right failure, but nobody could get past it.
  #
  # EACH ARM ASSERTS THE FRONT END'S OWN cc1-LIKE BINARY *AND* ITS DRIVER, by
  # name, before the run.  That is not belt-and-braces: the two absences have
  # different causes and different fixes -- a missing `f951' means the front
  # end was not enabled, a missing `gfortran' means it was enabled and its
  # driver did not link -- and collapsing them into one message loses the
  # distinction the whole task turns on.  The binary names are taken from each
  # `config-lang.in''s own `compilers=' line rather than guessed.
  #
  # SUMDIR/SUM ARE THE DEJAGNU TOOL NAME, NOT THE LANGUAGE NAME, and they come
  # apart: `check-d' is a `check-gdc' alias writing `gdc.sum', `check-m2' is a
  # `check-gm2' alias writing `gm2.sum'.  Keying on the language would look for
  # a `.sum' that is never written, and GUARD 4 would then report the run
  # inert -- a false RED costing exactly what a false green costs.
  # THE `<TOOL>_UNDER_TEST' VARIABLE IS NOT DERIVABLE FROM THE TOOL NAME, AND
  # GUESSING IT PRODUCES A BOARD THAT MEASURES NOTHING WHILE LOOKING FULL.
  # The first version of this table guessed, and four of nine were wrong:
  # `GCC_UNDER_TEST' for objc (it is `OBJC_UNDER_TEST', lib/objc.exp:115),
  # `GXX_UNDER_TEST' for obj-c++ (`OBJCXX_UNDER_TEST'), `GCCGO_UNDER_TEST' for
  # go (`GOC_UNDER_TEST'), `GCCRS_UNDER_TEST' for rust (`RUST_UNDER_TEST').
  # The `.exp' then falls back to `[find_gcc]' -- a bare `xgcc' carrying no
  # `-ftarget-config=' -- which refuses by name, CORRECTLY, once per test.  The
  # result is a full-looking board: objc 16 PASS / 1470 FAIL, go 0 / 3813, and
  # every one of those FAILs is the harness, not the compiler.  Each name below
  # is read out of that tool's own `lib/<tool>.exp'.
  objc)     DRIVER=xgcc; UTVAR=OBJC_UNDER_TEST;  SUMDIR=objc;     SUM=objc
            [ -x "$B/gcc/cc1obj" ] || { echo "FATAL: no $B/gcc/cc1obj -- objc was never built"; exit 9; } ;;
  obj-c++)  DRIVER=xg++; UTVAR=OBJCXX_UNDER_TEST; SUMDIR=obj-c++;  SUM=obj-c++
            [ -x "$B/gcc/cc1objplus" ] || { echo "FATAL: no $B/gcc/cc1objplus -- obj-c++ was never built"; exit 9; }
            [ -x "$B/gcc/xg++" ]       || { echo "FATAL: no $B/gcc/xg++"; exit 9; } ;;
  gfortran) DRIVER=gfortran; UTVAR=GFORTRAN_UNDER_TEST; SUMDIR=gfortran; SUM=gfortran
            [ -x "$B/gcc/f951" ]     || { echo "FATAL: no $B/gcc/f951 -- fortran was never built"; exit 9; }
            [ -x "$B/gcc/gfortran" ] || { echo "FATAL: no $B/gcc/gfortran driver"; exit 9; } ;;
  go)       DRIVER=gccgo; UTVAR=GOC_UNDER_TEST; SUMDIR=go; SUM=go
            [ -x "$B/gcc/go1" ]   || { echo "FATAL: no $B/gcc/go1 -- go was never built"; exit 9; }
            [ -x "$B/gcc/gccgo" ] || { echo "FATAL: no $B/gcc/gccgo driver"; exit 9; } ;;
  gdc)      DRIVER=gdc; UTVAR=GDC_UNDER_TEST; SUMDIR=gdc; SUM=gdc
            [ -x "$B/gcc/d21" ] || { echo "FATAL: no $B/gcc/d21 -- d was never built"; exit 9; }
            [ -x "$B/gcc/gdc" ] || { echo "FATAL: no $B/gcc/gdc driver"; exit 9; } ;;
  gm2)      DRIVER=gm2; UTVAR=GCC_UNDER_TEST; SUMDIR=gm2; SUM=gm2
            [ -x "$B/gcc/cc1gm2" ] || { echo "FATAL: no $B/gcc/cc1gm2 -- m2 was never built"; exit 9; }
            [ -x "$B/gcc/gm2" ]    || { echo "FATAL: no $B/gcc/gm2 driver"; exit 9; } ;;
  cobol)    DRIVER=gcobol; UTVAR=COBOL_UNDER_TEST; SUMDIR=cobol; SUM=cobol
            [ -x "$B/gcc/cobol1" ] || { echo "FATAL: no $B/gcc/cobol1 -- cobol was never built"; exit 9; }
            [ -x "$B/gcc/gcobol" ] || { echo "FATAL: no $B/gcc/gcobol driver"; exit 9; } ;;
  algol68)  DRIVER=ga68; UTVAR=ALGOL68_UNDER_TEST; SUMDIR=algol68; SUM=algol68
            [ -x "$B/gcc/a681" ] || { echo "FATAL: no $B/gcc/a681 -- algol68 was never built"; exit 9; }
            [ -x "$B/gcc/ga68" ] || { echo "FATAL: no $B/gcc/ga68 driver"; exit 9; } ;;
  rust)     DRIVER=gccrs; UTVAR=RUST_UNDER_TEST; SUMDIR=rust; SUM=rust
            [ -x "$B/gcc/crab1" ] || { echo "FATAL: no $B/gcc/crab1 -- rust was never built"; exit 9; }
            [ -x "$B/gcc/gccrs" ] || { echo "FATAL: no $B/gcc/gccrs driver"; exit 9; } ;;
  *) echo "FATAL: MT_CHECK_TOOL=$TOOL is not one of:"
     echo "         gcc g++ objc obj-c++ gfortran go gdc gm2 cobol algol68 rust"
     echo "       (the DejaGnu TOOL name, i.e. the suffix of a \`lang_checks'"
     echo "        entry -- \`gdc' not \`d', \`gm2' not \`m2'.)"
     exit 9 ;;
esac
echo "== tool: $TOOL  (driver $DRIVER, $UTVAR, $SUM.sum)"

VER=$(cat "$SRC/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }
RTF=${MT_RUNTESTFLAGS:-}
echo "== mtcheck: srcdir $SRC $kind anchor=$n  gcc $VER  targets: $*"
echo "== runtestflags: [$RTF]  compile-only: [${MT_COMPILE_ONLY:-}]"

# ---- PRE-FLIGHT: THE RENAME SWEEP, ONCE, BEFORE ANY TARGET ------------------
#
# A strong-symbol collision between two bases is a property of the BUILD, not
# of a target, so it runs once here rather than inside the loop.
#
# WHY IT IS WIRED IN AT ALL.  `mt-rename-sweep.sh' spent an unknown period
# reporting collisions against a `cc1' that links with ZERO `multiple
# definition' -- 51 of them at four bases, every one a C++ OVERLOAD set inside
# a single base, because the awk keyed on `$1' of a demangled signature and
# counted OCCURRENCES rather than BASES.  An agent read a version of that
# output as "identical pre-fix, therefore pre-existing" and moved on; it was
# reasoning about an instrument that was wrong in the same way on both sides of
# its comparison.  A false RED costs what a false green costs, and the remedy
# it prints -- add N names to MULTI_TARGET_RENAME_NAMES -- is a real edit made
# for no reason.  Running it here means nobody meets it cold again.
#
# The sweep carries its own ARM 0e, which refuses unless it can still tell a
# real two-base collision from an overload set, so a `0' from it is falsifiable.
#
# THE STAMP IS DETECTED, NOT ASSUMED.  The sweep requires the build stamp
# `mt-build.sh' wrote and defaults to `make-cc1.rc'; a caller that built with a
# different tag gets a refusal that reads as a broken tree.  Both known tags
# are looked for and the ABSENCE of either is a REFUSAL, never a skip: "the
# sweep did not run" and "the sweep found nothing" must not be the same output.
if [ -z "${MT_SKIP_SWEEP:-}" ]; then
  SWEEPSTAMP=
  for s in all-gcc.rc make-cc1.rc; do
    [ -f "$B/$s" ] && { SWEEPSTAMP=$s; break; }
  done
  if [ -z "$SWEEPSTAMP" ]; then
    echo "FATAL: no build stamp in $B (looked for all-gcc.rc, make-cc1.rc)."
    echo "  The rename sweep cannot certify this build, and a skipped sweep"
    echo "  reads exactly like a clean one.  Build with mt-build.sh, or set"
    echo "  MT_SKIP_SWEEP=1 to state deliberately that it was not run."
    exit 9
  fi
  # `nm' is not on PATH outside the nix-shell, and a tool-not-found piped into
  # `grep -c' scores 0 -- in the direction that looks clean.  Hence mt_shell.
  if mt_shell "WANT_ANCHOR=$n MT_STAMP=$SWEEPSTAMP sh $S/mt-rename-sweep.sh $B" \
       > "$B/sweep.out" 2>&1; then
    echo "-- guard: $(grep -E '^arm 0e ok' "$B/sweep.out")"
    echo "-- guard: $(grep -E '^SWEEP ' "$B/sweep.out")"
  else
    echo "FATAL: mt-rename-sweep.sh failed against this build."
    grep -E '^arm 0e|^SWEEP|colliding names|^FATAL' "$B/sweep.out" | sed 's/^/    /'
    echo "  Full log: $B/sweep.out"
    exit 9
  fi
fi

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

  # GUARD 3b -- THE TARGET'S OWN SPEC FILE MUST ACTUALLY BE READ.
  #
  # Guards 1-3 establish that a specs-CONFIG exists and that the flag selects a
  # target.  None of them establishes that `dirname(cfg)/specs' -- where the
  # target's *option_defaults, *self_spec, *asm and *link live -- was opened.
  # It was not: an explicit `-ftarget-config=FILE' left `found_target_config'
  # NULL, and `set_up_specs' derives that path from it.  This script drives
  # exactly that flag, on `xgcc', which carries no triple, so EVERY board this
  # project recorded through this file -- TAA-BOARD.md, SC-BOARD.md's
  # multi-target column, every per-target score -- was taken on a compiler
  # whose target had contributed nothing to the spec set.
  #
  # It is a PRECONDITION and not a note, because the two states are
  # indistinguishable downstream: a compiler that read no spec file and one
  # whose spec file says nothing emit identical output and identical
  # diagnostics.  mt-specsread.sh carries its own negative control.
  if ! sh "$S/mt-specsread.sh" "$B" "$T" > "$B/specsread-$T.out" 2>&1; then
    echo "FATAL[$T]: the target's own spec file is not reaching the compiler."
    sed -n '/^FAIL\|^SPECSREAD/p' "$B/specsread-$T.out" | sed 's/^/    /'
    echo "  Full log: $B/specsread-$T.out"
    exit 9
  fi
  echo "-- guard: mt-specsread PASSES ($(grep -c '^-- ARM' "$B/specsread-$T.out") arms)"

  # GUARD 3c -- THE ASSEMBLER MUST BE THIS TARGET'S, AND IT WAS NOT.
  #
  # SC-BOARD.md section 0 records this defect and FIXED IT ON THE STOCK SIDE
  # ONLY.  The multi-target side has carried it in every board this project
  # has taken.  `<builddir>/gcc/as' is a libtool-style shim whose
  # ORIGINAL_AS_FOR_TARGET is the nixpkgs gcc-wrapper's `as' -- the HOST x86
  # assembler -- and `-print-prog-name=as' returns THE SAME FILE for all four
  # targets.  So every `dg-do assemble' and every `-c' compilation in
  # `gcc.c-torture/compile' fed s390x and aarch64 assembly to an x86
  # assembler.
  #
  # Measured cost: `invalid -march= option: `z900'' 9,184 times on s390x, and
  # ~10,114 of that target's 14,256 "debt" -- 71% of it -- plus ~10,142 of
  # aarch64's.  It is NOT a compiler defect: the same compiler's `.s' output
  # assembles cleanly with the real cross assembler into a correct
  # ELF64 / IBM S/390 object.
  #
  # THE FIX IS A PER-TARGET DIRECTORY HOLDING A PLAIN `as'.  `-B<tools>/'
  # alone does NOT work: the tools are named `<triple>-as' and the driver
  # searches for `as', so it falls through to the build dir's shim.  A
  # directory containing `as' -> `<triple>-as' and passed FIRST is what the
  # driver actually honours.
  #
  # MT_TOOLS_<triple-with-dashes-as-underscores> names that target's binutils
  # bin directory (taa-tools.sh output).  Absent, the run REFUSES rather than
  # silently assembling with the host tool -- "cannot tell" is not "fine",
  # and this whole guard exists because a silent wrong assembler looked like
  # a compiler bug for the entire life of the project.
  TVAR=MT_TOOLS_$(printf '%s' "$T" | tr - _)
  eval "TDIR=\${$TVAR:-}"
  if [ -z "$TDIR" ]; then
    echo "FATAL[$T]: no $TVAR set."
    echo "  Without this target's binutils the driver resolves \`as' to"
    echo "  $B/gcc/as, a shim around the HOST assembler, and every"
    echo "  assemble-shaped test fails for a reason that is not the compiler."
    echo "  Run scratchpad/taa-tools.sh and pass $TVAR=<its bin dir>."
    echo "  Set MT_ALLOW_HOST_AS=1 to state deliberately that you accept it."
    [ -n "${MT_ALLOW_HOST_AS:-}" ] || exit 9
    ASDIR=
  else
    ASDIR="$B/asdir-$T"; rm -rf "$ASDIR"; mkdir -p "$ASDIR"
    for tool in as ld nm ar ranlib objcopy objdump strip readelf; do
      [ -x "$TDIR/$T-$tool" ] || continue
      ln -sf "$TDIR/$T-$tool" "$ASDIR/$tool"
      # ... AND UNDER THE PREFIXED NAME TOO, WITH $ASDIR ON PATH BELOW.
      #
      # The unprefixed link is what `-B$ASDIR/' needs and it is all this
      # harness used to make.  The TESTSUITE asks a different question:
      # `find_binutils_prog objdump' returns `<target>-objdump', spawned by
      # NAME through PATH, and nothing put the target's tools there -- while
      # `sc-check.sh' (the CONTROL) runs its `make check' with
      # `PATH=$TOOLS:$PATH'.  So the two sides of the board did not have the
      # same tools visible, on the side that is supposed to differ only in
      # the compiler.
      #
      # MEASURED on the i686 row, and it is invisible in the debt column by
      # construction.  `lib/file-format.exp' compiles a TU and objdumps it;
      # with no `<target>-objdump' the spawn fails, `gcc_target_object_format'
      # returns `unknown', and `hidden-scan-for' (lib/scanasm.exp:156) falls
      # through its switch to `return ""'.  An EMPTY regexp then goes into
      # both the scan and the TEST NAME: the multi-target side wrote
      #
      #    FAIL: gcc.dg/visibility-d.c scan-not-hidden
      #
      # where the control wrote
      #
      #    PASS: gcc.dg/visibility-d.c scan-not-hidden hidden[ \t_]*foo00
      #
      # -- 30 FAILs that are the harness, and because the NAMES differ they
      # do not join, so they land in the only-in columns and NOT in `stock
      # PASS -> mt not PASS'.  A debt figure alone would have reported this
      # row cleaner than it was, in exactly the direction that flatters us.
      ln -sf "$TDIR/$T-$tool" "$ASDIR/$T-$tool"
    done
    [ -x "$ASDIR/as" ] || { echo "FATAL[$T]: no $TDIR/$T-as to link"; exit 9; }
    [ -x "$ASDIR/$T-objdump" ] \
      || echo "WARNING[$T]: no $T-objdump; gcc_target_object_format will say \`unknown'"

    # NON-VACUITY, and it is the arm SC-BOARD's S4 already prescribes: ask the
    # RUNNING driver, then ASSEMBLE A REAL FUNCTION and require the target's
    # own readelf to name the machine.  A host `as' accepts an empty file, so
    # "no complaint" would be another way to see nothing.
    got=$("$B/gcc/xgcc" -B"$ASDIR/" -B"$B/gcc/" -ftarget-config="$CFG" \
            -print-prog-name=as)
    # EITHER NAME IN $ASDIR IS CORRECT, AND WHICH ONE IS NOT THIS GUARD'S
    # BUSINESS.  Until 3ff8b3f835c ("driver: set `just_machine_prefix' from the
    # resolved target") the driver returned `$ASDIR/as'; since it landed the
    # driver finds `$ASDIR/$T-as' FIRST, because it now has a machine prefix to
    # search for.  This case arm still named only the unprefixed spelling, so
    # `mtcheck.sh' has refused EVERY target at the tip since that commit --
    # which is after the i686 row, the last row taken, so nothing had run it.
    #
    # The guard is kept and its QUESTION is kept: what must be true is that the
    # driver resolved to a file IN $ASDIR (not `$B/gcc/as', the shim around the
    # host assembler, which is the whole point of GUARD 3c above).  What must
    # NOT be asserted is which of the two names it picked -- `mtcheck.sh' itself
    # links both, to the same file, forty lines up.
    #
    # So: accept either name, and then require that the thing it resolved to is
    # REALLY the same binary as the target tools dir's own `$T-as', through
    # `readlink -f'.  That is strictly STRONGER than the old string compare: a
    # `$ASDIR/as' that had somehow come to point at the host assembler would
    # have satisfied the old arm and fails this one.
    case "$got" in
      "$ASDIR/as"|"$ASDIR/$T-as") ;;
      *) echo "FATAL[$T]: driver resolves \`as' to $got, which is not in $ASDIR."
         echo "  It is most likely $B/gcc/as, the shim around the HOST"
         echo "  assembler -- see GUARD 3c above for what that costs."; exit 9 ;;
    esac
    _gotreal=$(readlink -f "$got")
    _wantreal=$(readlink -f "$TDIR/$T-as")
    [ -n "$_gotreal" ] && [ "$_gotreal" = "$_wantreal" ] \
      || { echo "FATAL[$T]: driver's \`as' ($got) really is $_gotreal,"
           echo "  but $T's own assembler is $_wantreal.  Different binaries."; exit 9; }
    echo "-- guard: driver's \`as' is $got -> $_gotreal (= $T's own)"
    printf 'int mt_as_probe (int x) { return x + 1; }\n' > "$B/mt-as-$T.c"
    if ! "$B/gcc/xgcc" -B"$ASDIR/" -B"$B/gcc/" -ftarget-config="$CFG" \
           -O1 -w -c -o "$B/mt-as-$T.o" "$B/mt-as-$T.c" 2> "$B/mt-as-$T.err"; then
      echo "FATAL[$T]: the target's own assembler rejected the compiler's output:"
      sed -n '1,5p' "$B/mt-as-$T.err"
      exit 9
    fi
    mach=$("$TDIR/$T-readelf" -h "$B/mt-as-$T.o" 2>/dev/null \
             | sed -n 's/.*Machine: *//p')
    [ -n "$mach" ] || { echo "FATAL[$T]: $T-readelf named no machine"; exit 9; }
    echo "-- guard: assembler is $T's own, and it produces: $mach"
  fi

  # ---- g++_init NEEDS A COMPILER IT CAN RUN WITH NO FLAGS ---------------
  #
  # `g++.exp:g++_init' calls `get_multilibs' unconditionally on a local host,
  # and `get_multilibs' (dejagnu libgloss.exp:418) does NOT use
  # GCC_UNDER_TEST: it takes `[board_info <board> compiler]', falling back to
  # `[find_gcc]', and then `regexp "/.* " $compiler compiler' TRIMS EVERYTHING
  # AFTER THE FIRST SPACE.  So even a GCC_UNDER_TEST carrying
  # `-ftarget-config=' would arrive stripped.  It then runs
  # `xgcc --print-multi-lib', which on a compiler with no default target is
  # `fatal error: no target selected' -- a tcl error inside `g++_init', so the
  # ENTIRE .exp aborts before one test runs, and `make check-g++' still exits
  # 0 beside a zero-byte g++.sum.
  #
  # The refusal is CORRECT and must not be softened: PRINCIPLES 2a, "a bare
  # gcc failing by name when no target is selected is correct behaviour, not a
  # bug to fix".  What is needed is a compiler NAME that carries its target,
  # and this branch already has one -- the driver's own error message offers
  # `<triple>-xgcc' as a supported invocation.  So the board is given that
  # name, which is a single word and survives the regexp.
  #
  # Set through $DEJAGNU rather than site.exp: site.exp is generated by make
  # and rewritten per run, and `board_info' is a plain global array the site
  # config can assign before any board file is read.
  #
  # AND IT IS NOT A g++ PROPERTY.  `get_multilibs' is called by every
  # `<tool>_init' that goes through `libgloss.exp', which is all of them except
  # `gcc.exp' -- objc, obj-c++, gfortran, go, gdc, gm2, cobol and algol68 each
  # abort inside their own `_init' the same way, with the same exit 0 beside a
  # zero-byte `.sum'.  The condition was `= g++' only because g++ was the only
  # other tool this file could run; keying it on "not the C driver" is what the
  # reasoning above actually says.
  if [ "$TOOL" != gcc ]; then
    ln -sf xgcc "$B/gcc/$T-xgcc"
    "$B/gcc/$T-xgcc" --print-multi-lib > "$B/multilib-$T.out" 2>&1 \
      || { echo "FATAL[$T]: $T-xgcc --print-multi-lib failed:"; \
           sed -n 1,3p "$B/multilib-$T.out"; exit 9; }
    echo "-- guard: $T-xgcc answers --print-multi-lib ($(grep -c . "$B/multilib-$T.out") lines)"
    DJ="$B/dejagnu-$T.exp"
    printf 'set board_info(unix,compiler) "%s"\n' "$B/gcc/$T-xgcc" > "$DJ"
    export DEJAGNU="$DJ"
  fi

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
  # THE ADDRESS-SPACE CAP, INHERITED BY EVERY cc1 THE SUITE RUNS.
  #
  # `gcc.target/riscv/pr117506.c' took cc1 to 20.8 GB RSS on a four-line
  # testcase and caused visible memory pressure on the user's machine.  There
  # is no seam at which to wrap an individual cc1 here -- DejaGnu execs
  # GCC_UNDER_TEST directly -- so the limit is set once on the shell that
  # launches runtest and inherited by the whole process tree.  RLIMIT_AS is
  # per-process, so this caps each cc1 at MT_MEMCAP_KB rather than capping
  # their sum, which is what is wanted: a compilation needing 20 GB is not one
  # that is going to pass, and it must die in seconds and be recorded as a
  # failure instead of taking the box.
  #
  # `-v' and not `-m': Linux does not enforce RLIMIT_RSS, so `-m' is accepted
  # and does nothing -- the "mitigation that cannot fire" shape.  Same reasoning
  # as tb1-memcap.sh, which is the single-command form of this.
  #
  # NON-VACUITY: the cap is read back and the run REFUSES if it did not take.
  # Set in THIS subshell, before anything is exec'd, rather than inside the
  # nix-shell --run string: that string is re-quoted twice on its way in, and a
  # cap that failed to parse would be silently absent -- the one outcome that
  # must not be possible.  Here it is plain shell and is read back immediately.
  CAP=${MT_MEMCAP_KB:-8388608}
  # `DEJAGNU' IS SET ONLY FOR g++, AND EXPORTING IT EMPTY BREAKS check-gcc.
  #
  # This line used to be an unconditional `DEJAGNU='${DEJAGNU:-}'' beside the
  # other three.  For `MT_CHECK_TOOL=gcc' nothing above sets `DEJAGNU', so that
  # exported it as the EMPTY STRING -- and DejaGnu tests `[info exists
  # env(DEJAGNU)]', which is TRUE for an empty value, then tries to source a
  # file named "".  Every parallel job then prints
  #
  #     ERROR: global config file  not found.
  #
  # (note the doubled space: that is the empty filename) and runtest exits
  # having written a ZERO-BYTE `gcc.sum'.  `make check-gcc' still exits **0**,
  # because the check-% recipe is wrapped in `-(...)'.
  #
  # So the harness's `gcc' arm has been dead since `32dbd04da25' -- the commit
  # that fixed the SAME failure shape for `g++' introduced it for `gcc', and no
  # four-target board has been taken since, so nothing scored it.  Exactly the
  # `one name, several authorities' shape, with the two authorities being the
  # two values of `MT_CHECK_TOOL'.
  #
  # `unset' is NOT available across this quoting boundary in a useful way, so
  # the assignment and the `export' are BOTH conditional: an unset DEJAGNU
  # stays unset, which is what DejaGnu's own `info exists' arm is written for.
  # GUARD 4 caught it -- the run produced no banner - which is that guard doing
  # its job on a live event rather than a historical one.
  if [ -n "${DEJAGNU:-}" ]; then
    DJSET="DEJAGNU='$DEJAGNU'; export DEJAGNU;"
  else
    DJSET=""
  fi
  ( ulimit -v "$CAP" || exit 9
    [ "$(ulimit -v)" = "$CAP" ] || { echo "FATAL: ulimit -v $CAP did not take"; exit 9; }
    cd "$B/gcc" && sh "$S/eb-shell-dj.sh" "cd $B/gcc && \
      ${ASDIR:+PATH=$ASDIR:\$PATH; export PATH; } \
      $DJSET \
      MT_TARGET_NAME=$T \
      MT_TARGET_CONFIG=$CFG \
      MT_COMPILE_ONLY='${MT_COMPILE_ONLY:-}' \
      export MT_TARGET_NAME MT_TARGET_CONFIG MT_COMPILE_ONLY; \
      make ${MT_MAKEFLAGS:-} check-$TOOL \
        TEST_TARGET=$T \
        TESTSUITEDIR=$TSD \
        RUNTESTFLAGS=\"$UTVAR='$B/gcc/$DRIVER ${ASDIR:+-B$ASDIR/ }-B$B/gcc/ -ftarget-config=$CFG' GCC_UNDER_TEST='$B/gcc/xgcc ${ASDIR:+-B$ASDIR/ }-B$B/gcc/ -ftarget-config=$CFG' $RTF\"" \
  ) > "$B/check-$T.out" 2> "$B/check-$T.err"
  rc=$?
  # Stamp the exit, and let the scorer refuse a run with no stamp: a log being
  # written looks exactly like a log that finished (PRINCIPLES 4).
  echo "$rc" > "$B/check-$T.rc"
  echo "-- make check-$TOOL rc=$rc"

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
  LOG="$B/gcc/$TSD/$SUMDIR/$SUM.log"
  if [ -z "$LOG" ] || ! grep -q "MULTI-TARGET RUN: target = $T" "$LOG"; then
    echo "FATAL[$T]: $LOG carries no 'MULTI-TARGET RUN: target = $T' banner."
    echo "  multi-target.exp did not see MT_TARGET_NAME, so it was INERT:"
    echo "  no attribution stamp and no compile-only downgrade.  The counts"
    echo "  would be real but unattributed.  Refusing."
    exit 9
  fi
  echo "-- guard: multi-target.exp banner present (the .exp was reached)"
done

echo
# MT_SCORER lets a caller that copied these scripts elsewhere (to keep an
# in-flight run safe from edits to the originals) name the copy.  Refuse by
# name rather than let the run end with a bare "No such file": the suite has
# already cost an hour by that point and a missing scorer would otherwise
# discard it.
SCORER=${MT_SCORER:-$S/mtscore.sh}
[ -f "$SCORER" ] || { echo "FATAL: no scorer at $SCORER (set MT_SCORER)"; exit 9; }
MT_CHECK_TOOL=$TOOL sh "$SCORER" "$B" "$@"
