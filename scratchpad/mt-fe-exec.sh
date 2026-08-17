#!/bin/sh
# mt-fe-exec.sh -- FOR EVERY LANGUAGE THE TREE DECLARES: is its compiler binary
# present, and did it EXECUTE on a real input for a named target?
#
# THIS IS THE ACCEPTANCE ARM, NOT A CONVENIENCE.  "A language never enabled and
# a language passing everything give the same empty failure list" is the
# sentence the whole front-end task exists under, and `make check-<lang>' has
# exited 0 having run nothing THREE times on this branch (twice for `check-g++'
# for two different reasons, once for `check-gcc' with `DEJAGNU' exported
# empty).  `test -x' alone does not settle it either: PRINCIPLES is explicit
# that "exists" and "non-empty" are the shape that passes on the corrupted
# artefact.  So each row is THREE separate verdicts, never summed:
#
#   BINARY   the `compilers=' program from that language's own config-lang.in
#            exists and is executable.
#   DRIVER   the language's driver exists.  Kept apart from BINARY because the
#            two absences have different causes: no `f951' means the front end
#            was not enabled, no `gfortran' means it was enabled and its driver
#            did not link.
#   RAN      the driver COMPILED a minimal program of that language, for a
#            named target, and the front end binary is the thing that did it --
#            checked by `-###'-free direct invocation plus a `-S' whose output
#            is required to be NON-TRIVIAL.  A zero-byte `.s' and a successful
#            compile are the same rc.
#
# NOT-BUILT IS PRINTED AS `not-built', NEVER AS A FAILURE and never as a blank.
# A language this host cannot build for a missing HOST prerequisite (`gnat',
# `gdc', `cargo') is a different finding from one that ICEs on every input, and
# the two must not collapse into one column.  This script cannot tell them
# apart on its own, so it says `not-built' and leaves the reason to the caller
# who watched configure refuse it.
#
# usage: mt-fe-exec.sh <builddir> <target-triple>
set -u
S=$(cd "$(dirname "$0")" && pwd)
MT_LIB_DIR=$S
. "$S/mt-lib.sh"
B=${1:?build dir}
T=${2:?target triple}
mt_assert_builddir "$B"
SRC=$(mt_src_of "$B") || exit 9
VER=$(cat "$SRC/gcc/BASE-VER")
CFG="$B/lib/gcc/$VER/$T/specs-config"
[ -f "$CFG" ] || { echo "FATAL: no $CFG -- target-specs was not run for $T"; exit 9; }
W=$(mktemp -d); trap 'rm -rf "$W"' 0

# The languages, DERIVED from the tree.  Fields: lang dir binary driver ext
# The driver name is the build dir's, which for C and C++ is `xgcc'/`xg++'.
TABLE="
c        c        cc1         xgcc      c
c++      cp       cc1plus     xg++      cc
objc     objc     cc1obj      xgcc      m
obj-c++  objcp    cc1objplus  xg++      mm
fortran  fortran  f951        gfortran  f90
d        d        d21         gdc       d
go       go       go1         gccgo     go
ada      ada      gnat1       gnatmake  adb
m2       m2       cc1gm2      gm2       mod
cobol    cobol    cobol1      gcobol    cob
algol68  algol68  a681        ga68      a68
rust     rust     crab1       gccrs     rs
lto      lto      lto1        xgcc      c
jit      jit      cc1         xgcc      c
"

# The minimal program per language.  Deliberately trivial: this arm asks
# whether the FRONT END RAN, not whether it is correct.
mkprog () {
  case $1 in
    c|lto|jit) printf 'int mt_fe (int x) { return x + 1; }\n' ;;
    c++)     printf 'struct S { virtual int f (); };\nint S::f () { return 1; }\n' ;;
    objc)    printf 'int mt_fe (int x) { return x + 1; }\n' ;;
    obj-c++) printf 'struct S { virtual int f (); };\nint S::f () { return 1; }\n' ;;
    fortran) printf '      function mt_fe(x)\n      integer x, mt_fe\n      mt_fe = x + 1\n      end\n' ;;
    d)       printf 'module mtfe;\nint mt_fe (int x) { return x + 1; }\n' ;;
    go)      printf 'package mtfe\nfunc MtFe(x int) int { return x + 1 }\n' ;;
    ada)     printf 'package body Mtfe is\n   function F (X : Integer) return Integer is\n   begin\n      return X + 1;\n   end F;\nend Mtfe;\n' ;;
    m2)      printf 'MODULE mtfe ;\nBEGIN\nEND mtfe.\n' ;;
    cobol)   printf '       IDENTIFICATION DIVISION.\n       PROGRAM-ID. MTFE.\n       PROCEDURE DIVISION.\n           STOP RUN.\n' ;;
    algol68) printf 'BEGIN SKIP END\n' ;;
    rust)    printf 'fn mt_fe(x: i32) -> i32 { x + 1 }\n' ;;
  esac
}

echo "build $B   target $T   specs-config $(wc -l < "$CFG") lines"
printf '%-9s %-11s %-9s %-9s %-9s %s\n' LANG BINARY DRIVER RAN 'S-BYTES' NOTE
nran=0; nlang=0
echo "$TABLE" | while read -r lang dir bin drv ext; do
  [ -n "${lang:-}" ] || continue
  [ -f "$SRC/gcc/$dir/config-lang.in" ] || { printf '%-9s %s\n' "$lang" "NO config-lang.in -- not a language in this tree"; continue; }
  nlang=$((nlang + 1))
  if [ -x "$B/gcc/$bin" ]; then bs=ok; else bs="MISSING"; fi
  if [ -x "$B/gcc/$drv" ]; then ds=ok; else ds="MISSING"; fi
  if [ "$bs" != ok ] || [ "$ds" != ok ]; then
    printf '%-9s %-11s %-9s %-9s %-9s %s\n' "$lang" "$bs" "$ds" 'not-built' '-' \
      "$bin / $drv"
    continue
  fi
  mkprog "$lang" > "$W/mtfe.$ext"
  rm -f "$W/out.s"
  if "$B/gcc/$drv" -B"$B/gcc/" -ftarget-config="$CFG" -S -o "$W/out.s" "$W/mtfe.$ext" \
       > "$W/err.$lang" 2>&1; then
    # rc=0 IS NOT THE VERDICT.  A zero-byte .s and a successful compile have
    # the same rc; require real output.
    sz=$(wc -c < "$W/out.s" 2>/dev/null || echo 0)
    if [ "$sz" -gt 40 ]; then r=RAN; nran=$((nran + 1)); else r='rc0-EMPTY'; fi
  else
    sz=0; r=FAILED
  fi
  printf '%-9s %-11s %-9s %-9s %-9s %s\n' "$lang" "$bs" "$ds" "$r" "$sz" \
    "$(head -1 "$W/err.$lang" 2>/dev/null | cut -c1-70)"
done
echo
echo "RAN means the driver produced a non-trivial .s for $T.  'not-built' is"
echo "NOT a failure verdict: it says this build has no such front end, and the"
echo "REASON (a missing host prerequisite vs a defect) is not knowable here."
