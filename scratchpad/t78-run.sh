#!/bin/sh
# #78: does the driver pass -ftarget-config= down on EVERY path?
#
# Measured by RUNNING each path, not by reading specs.  Two instruments,
# because no single one can see every hop:
#
#   `-###'        shows the argv of every process the DRIVER spawns
#                 (cc1, collect2, ld).  It cannot show lto-wrapper's argv:
#                 lto-wrapper is spawned by collect2 or by the linker's LTO
#                 plugin, and neither argv comes from spec text.
#   a SHIM        named `lto-wrapper' on a -B directory, which the driver
#                 finds via find_a_program and puts in COLLECT_LTO_WRAPPER.
#                 It records its own argv and COLLECT_GCC_OPTIONS, then execs
#                 the real lto-wrapper so the link still completes.
#
# Both are needed: a path can fail to forward on the argv and still carry the
# value in the environment, and lto-wrapper's main() scans ONLY argv while its
# run_gcc() decodes COLLECT_GCC_OPTIONS.  Reporting one without the other would
# call the same path forwarded and not-forwarded.
#
# TWO ENVIRONMENTAL FACTS, recorded rather than worked around silently:
#   * the driver must be invoked under its TRIPLE-PREFIXED name.  `./xgcc' has
#     no triple in argv[0], there is no `default-target' file (by design --
#     PRINCIPLES 2, no primary), so it selects no target and fails by name.
#     That is correct behaviour and it is why every path below uses
#     ./x86_64-pc-linux-gnu-gcc.
#   * this build has no libgcc and no crt files, so a full hosted link cannot
#     be done here.  -nostdlib -nostartfiles is used instead: it still drives
#     ld, still loads the LTO plugin, still runs lto-wrapper and lto1, and the
#     only thing it drops is the part of the link that has nothing to do with
#     #78.  `-nostdinc' likewise, or cc1 dies on stdc-predef.h first.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b78}
T=${T:-x86_64-pc-linux-gnu}
WORK=${WORK:-/tmp/t78}
SHIM=$WORK/shim
G=$D/gcc
DRV=./$T-gcc
CFL="-nostdinc"
LFL="-nostdlib -nostartfiles"

[ -x "$G/$T-gcc" ] || { echo "FATAL: no $G/$T-gcc"; exit 9; }
[ -s "$G/specs-$T-config" ] || { echo "FATAL: no $G/specs-$T-config -- run t78-specs.sh"; exit 9; }
[ -x "$G/lto-wrapper" ] || { echo "FATAL: no real lto-wrapper"; exit 9; }
[ -x "$SHIM/lto-wrapper" ] || { echo "FATAL: no shim at $SHIM/lto-wrapper"; exit 9; }

export T78_REAL="$G/lto-wrapper"
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"

say () { echo; echo "############ $*"; }

# scan <label> <file> -- report whether a REAL -ftarget-config= switch appears.
#
# FALSE GREEN FIXED IN THE FIRST RUN: a bare `grep -c -- -ftarget-config='
# scored 1 on every path, including paths where the driver had selected no
# target at all -- because the driver's own FAILURE message advertises the
# option ("-ftarget-config=FILE  name a target's configuration file
# explicitly").  The instrument was counting the diagnostic that says the value
# is ABSENT as evidence that it is PRESENT.  A forwarded switch always names an
# absolute path, so require the `=/'; the help-text count is printed beside it
# so the two can never be confused again.
scan () {
  n=$(grep -c -- '-ftarget-config=/' "$2" || true)
  h=$(grep -c -- '-ftarget-config=FILE' "$2" || true)
  echo "  [$1] real -ftarget-config=<path>: ${n:-0}   (help-text mentions, NOT evidence: ${h:-0})"
}

# nline <label> <file> <pattern> -- count lines matching, 0 when none.
nline () { c=$(grep -c "$3" "$2" || true); echo "  $1: ${c:-0}"; }

run_shell () {
  nix-shell -I "nixpkgs=$NP" \
    -p gcc gnumake perl binutils coreutils \
    --substituters 'https://cache.nixos.org/' --run "$1"
}

rm -f "$WORK"/*.txt "$WORK"/wrap-*.log "$WORK"/*.o "$WORK"/*.exe
cd "$G" || exit 9

################################################################ A: -c, no LTO
say "PATH A  plain -c   (driver -> cc1)"
run_shell "cd $G && $DRV -B$SHIM/ -B./ -### $CFL -c $WORK/a.c -o $WORK/a.o" \
  > "$WORK"/A.txt 2>&1
scan "A driver -###" "$WORK"/A.txt
grep -o -- '-ftarget-config=[^" ]*' "$WORK"/A.txt | sort -u | sed 's/^/      /'

############################################################ B: -flto -c
say "PATH B  -flto -c   (driver -> cc1, writing LTO IL)"
run_shell "cd $G && $DRV -B$SHIM/ -B./ -### $CFL -flto -c $WORK/a.c -o $WORK/a.o" \
  > "$WORK"/B.txt 2>&1
scan "B driver -###" "$WORK"/B.txt

############################################ produce real LTO objects for C-E
say "producing real -flto objects"
run_shell "cd $G && $DRV -B$SHIM/ -B./ $CFL -flto -c $WORK/a.c -o $WORK/a.o && \
                    $DRV -B$SHIM/ -B./ $CFL -flto -c $WORK/b.c -o $WORK/b.o" \
  > "$WORK"/objs.txt 2>&1
rc=$?
echo "  rc=$rc  a.o=$(test -s $WORK/a.o && echo yes || echo NO)  b.o=$(test -s $WORK/b.o && echo yes || echo NO)"
[ -s "$WORK/a.o" ] && [ -s "$WORK/b.o" ] || {
  echo "  FATAL: no LTO objects -- paths C/D/E would prove NOTHING"; tail -5 "$WORK"/objs.txt | sed 's/^/      /'; exit 9; }
run_shell "cd $WORK && readelf -S a.o | grep -c gnu.lto" > "$WORK"/ltosec.txt 2>&1
echo "  .gnu.lto_ sections in a.o: $(tail -1 $WORK/ltosec.txt)  (0 would mean these are not LTO objects)"

######################################## C: -flto link, default (plugin)
say "PATH C  -flto link, DEFAULT route (this ld has -plugin support = 2)"
run_shell "cd $G && $DRV -B$SHIM/ -B./ -### $LFL -flto $WORK/a.o $WORK/b.o -o $WORK/c.exe" \
  > "$WORK"/C.txt 2>&1
scan "C driver -###" "$WORK"/C.txt
nline "collect2 argv carries it" "$WORK"/C.txt 'collect2.*-ftarget-config=/'
nline "-plugin-opt=-ftarget-config= present" "$WORK"/C.txt 'plugin-opt=-ftarget-config='
nline "-plugin passed to ld" "$WORK"/C.txt '\-plugin '
export T78_LOG="$WORK"/wrap-C.log T78_TAG=C
run_shell "cd $G && $DRV -B$SHIM/ -B./ $LFL -flto $WORK/a.o $WORK/b.o -o $WORK/c.exe" \
  > "$WORK"/Crun.txt 2>&1
echo "  actual link rc=$?  c.exe=$(test -s $WORK/c.exe && echo yes || echo NO)"
tail -6 "$WORK"/Crun.txt | sed 's/^/      /'

##################################### D: -flto link, -fno-use-linker-plugin
say "PATH D  -flto link, -fno-use-linker-plugin (collect2 runs lto-wrapper)"
run_shell "cd $G && $DRV -B$SHIM/ -B./ -### $LFL -flto -fno-use-linker-plugin $WORK/a.o $WORK/b.o -o $WORK/d.exe" \
  > "$WORK"/D.txt 2>&1
scan "D driver -###" "$WORK"/D.txt
nline "collect2 argv carries it" "$WORK"/D.txt 'collect2.*-ftarget-config=/'
export T78_LOG="$WORK"/wrap-D.log T78_TAG=D
run_shell "cd $G && $DRV -B$SHIM/ -B./ $LFL -flto -fno-use-linker-plugin $WORK/a.o $WORK/b.o -o $WORK/d.exe" \
  > "$WORK"/Drun.txt 2>&1
echo "  actual link rc=$?  d.exe=$(test -s $WORK/d.exe && echo yes || echo NO)"
tail -6 "$WORK"/Drun.txt | sed 's/^/      /'

##################################### E: explicit -fuse-linker-plugin
say "PATH E  -flto link, explicit -fuse-linker-plugin"
run_shell "cd $G && $DRV -B$SHIM/ -B./ -### $LFL -flto -fuse-linker-plugin $WORK/a.o $WORK/b.o -o $WORK/e.exe" \
  > "$WORK"/E.txt 2>&1
scan "E driver -###" "$WORK"/E.txt
export T78_LOG="$WORK"/wrap-E.log T78_TAG=E
run_shell "cd $G && $DRV -B$SHIM/ -B./ $LFL -flto -fuse-linker-plugin $WORK/a.o $WORK/b.o -o $WORK/e.exe" \
  > "$WORK"/Erun.txt 2>&1
echo "  actual link rc=$?  e.exe=$(test -s $WORK/e.exe && echo yes || echo NO)"
tail -6 "$WORK"/Erun.txt | sed 's/^/      /'

############################################ F: non-LTO link (collect2 only)
say "PATH F  plain link, no LTO (driver -> collect2 -> ld)"
run_shell "cd $G && $DRV -B$SHIM/ -B./ -### $CFL $LFL $WORK/a.c $WORK/b.c -o $WORK/f.exe" \
  > "$WORK"/F.txt 2>&1
scan "F driver -###" "$WORK"/F.txt
nline "collect2 argv carries it" "$WORK"/F.txt 'collect2.*-ftarget-config=/'

########################################################## the shim's evidence
say "WHAT lto-wrapper ACTUALLY RECEIVED  (the decisive arm)"
for t in C D E; do
  f="$WORK"/wrap-$t.log
  if [ -s "$f" ]; then
    echo "--- $t"
    grep -E '^--- (argv|env) +has|^=== ' "$f" | sed 's/^/    /'
  else
    echo "--- $t: lto-wrapper WAS NEVER INVOKED (no shim log) -- this path is unmeasured, not clean"
  fi
done

say "NEGATIVE CONTROL: the shim must be able to report an ABSENCE"
echo "  (run the wrapper by hand with no -ftarget-config= and confirm it says 0)"
T78_LOG="$WORK"/wrap-N.log T78_TAG=N "$SHIM"/lto-wrapper --help > /dev/null 2>&1
grep -E '^--- (argv|env) +has' "$WORK"/wrap-N.log | sed 's/^/    /'
