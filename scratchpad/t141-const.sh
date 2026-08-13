#!/bin/sh
# #141 -- CONSTANT-EXPRESSION CONTEXTS for the option-state family and its
# whole derived closure.  A `#if' site is not the only thing a call-valued
# macro cannot serve: an array bound, a `static'/namespace-scope initialiser,
# a `static_assert' and an enumerator all need an integral constant expression
# too, and unlike a `#if' they fail at COMPILE time in a file that may not be
# built for every base.
#
# CONTROLS -- an empty read here is the dangerous read, so both directions are
# checked and the script refuses to score if either fails:
#   positive: MIN_UNITS_PER_WORD MUST show a bracket site.  caller-save.cc:55
#     and reload.h:179 size `regno_save_mem[..][MAX_MOVE_MAX /
#     MIN_UNITS_PER_WORD + 1]', which is the known array bound this family
#     turns on.  This control is NOT calibrated on a number -- it asserts a
#     site that must exist for the analysis to be about anything at all.
#   negative: a nonexistent name must read 0.
set -u
SRC=$(cd "$(dirname "$0")/.." && pwd)
cd "$SRC" || exit 9

[ "$(grep -c MULTI_TARGET gcc/Makefile.in)" -ge 43 ] || { echo "FATAL: wrong tree"; exit 9; }

hits () {
  grep -rn "\\b$1\\b" gcc --include='*.cc' --include='*.h' --include='*.c' \
    | grep -v '^gcc/config/' | grep -v testsuite | grep -v '^gcc/ada/'
}
# A subscript or array bound: the name appears inside [ ].
brack () { hits "$1" | grep -E "\[[^]]*\b$1\b"; }
# static_assert / enum / namespace-scope-looking initialiser.
constctx () { hits "$1" | grep -E 'static_assert|^[^:]*:[0-9]+:(static|const|enum)\b'; }

pos=$(brack MIN_UNITS_PER_WORD | wc -l)
neg=$(brack ZZ_NO_SUCH_MACRO_ZZ | wc -l)
echo "control positive  brack MIN_UNITS_PER_WORD=$pos (caller-save.cc + reload.h)"
echo "control negative  brack ZZ_NO_SUCH_MACRO_ZZ=$neg"
[ "$pos" -ge 2 ] || { echo "FATAL: positive control $pos, bracket classifier is broken"; exit 9; }
[ "$neg" -eq 0 ] || { echo "FATAL: negative control $neg"; exit 9; }

for m in "$@"; do
  b=$(brack "$m" | wc -l); c=$(constctx "$m" | wc -l)
  echo
  echo "===== $m   total=$(hits "$m" | wc -l)  bracket=$b  const-ctx=$c"
  brack "$m" | sed 's/^/  BRACKET  /'
  constctx "$m" | sed 's/^/  CONSTCTX /'
done
