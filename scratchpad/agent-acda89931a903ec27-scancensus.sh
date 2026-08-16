#!/bin/sh
# Census of gcc.target/<dir>: how many tests need an ASSEMBLER, and how many
# are pure compile-to-.s + grep (`scan-assembler*`).
#
# WHY: the Stage 1 table scores 30 of 47 back ends NO-CROSS-AS and therefore
# unscorable.  A `scan-assembler` test compiles with -S and greps text; it
# needs no assembler.  This measures how much of each directory is in that
# class, so the 17/47 ceiling can be checked against the tests rather than
# against the harness.
#
# CLASSIFICATION, and its blind spots stated up front:
#   * `dg-do <what>` is read from the file text.  ABSENT means the default,
#     which for gcc.target is `compile' (gcc-dg.exp's dg-do-what-default).
#     Counted as COMPILE, and reported separately as DEFAULTED so the reader
#     can see how much rests on that assumption.
#   * A file may carry several `dg-do' lines (conditional variants).  The
#     STRONGEST (run > link > assemble > compile > preprocess) is taken, so
#     this OVERCOUNTS the assembler-needing class -- deliberately: this
#     instrument can only ever revoke a target's eligibility, never grant it.
#   * .exp driver files and non-test sources are excluded by extension.
#   * It cannot see `dg-do' supplied by an .exp harness for a whole directory.
#     Those exist (e.g. some torture harnesses) and are NOT scored here.
#
# NON-VACUITY: refuses to print a table if it read zero files, and refuses if
# the `scan-assembler' count is zero across ALL directories -- both of which
# are what a broken grep looks like.

set -e
T=${1:-gcc/testsuite}
[ -d "$T/gcc.target" ] || { echo "FATAL: no $T/gcc.target"; exit 9; }

TOT=0
SCANTOT=0
printf '%-12s %6s %6s %6s %6s %6s %6s %6s\n' \
  DIR TESTS COMPILE ASSEMB LINK RUN SCANASM SCANonC

for d in "$T"/gcc.target/*/; do
  b=$(basename "$d")
  n=0; nc=0; na=0; nl=0; nr=0; ns=0; nsc=0; ndef=0
  for f in $(find "$d" -type f \( -name '*.c' -o -name '*.C' -o -name '*.cc' \
             -o -name '*.f90' -o -name '*.cpp' \) | sort); do
    n=$((n+1))
    # strongest dg-do wins
    w=""
    grep -q 'dg-do[[:space:]]*run'      "$f" && w=run
    [ -z "$w" ] && grep -q 'dg-do[[:space:]]*link'     "$f" && w=link
    [ -z "$w" ] && grep -q 'dg-do[[:space:]]*assemble' "$f" && w=assemble
    [ -z "$w" ] && grep -q 'dg-do[[:space:]]*compile'  "$f" && w=compile
    [ -z "$w" ] && grep -q 'dg-do[[:space:]]*preprocess' "$f" && w=preprocess
    if [ -z "$w" ]; then w=compile; ndef=$((ndef+1)); fi
    case $w in
      run)      nr=$((nr+1)) ;;
      link)     nl=$((nl+1)) ;;
      assemble) na=$((na+1)) ;;
      compile)  nc=$((nc+1)) ;;
    esac
    if grep -q 'scan-assembler' "$f"; then
      ns=$((ns+1))
      [ "$w" = compile ] && nsc=$((nsc+1))
    fi
  done
  TOT=$((TOT+n)); SCANTOT=$((SCANTOT+nsc))
  printf '%-12s %6d %6d %6d %6d %6d %6d %6d   (defaulted dg-do: %d)\n' \
    "$b" "$n" "$nc" "$na" "$nl" "$nr" "$ns" "$nsc" "$ndef"
done

echo
echo "TOTAL tests read: $TOT   scan-assembler-on-dg-do-compile: $SCANTOT"
[ "$TOT" -gt 0 ]     || { echo "FATAL: read zero test files -- instrument dead"; exit 9; }
[ "$SCANTOT" -gt 0 ] || { echo "FATAL: zero scan-assembler anywhere -- grep dead"; exit 9; }
