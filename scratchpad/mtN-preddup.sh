#!/bin/sh
# BACK ENDS THAT HAND-DECLARE THEIR OWN GENERATED PREDICATES.
#
# genpreds emits one declaration per define_predicate into tm-preds-<cpu>.h,
# and on this branch that header is inside `namespace insn_<cpu>'.  A back end
# whose <cpu>-protos.h ALSO declares the same predicate at global scope now has
# two different functions with one name, and every use from the .md is
# `call of overloaded ... is ambiguous'.
#
# Upstream this is invisible: both declarations are global and identical, so
# the duplicate is redundant and harmless.  The namespace is what makes it a
# collision -- so this is not a pre-existing bug that was missed, it is a cost
# of the namespacing, and it has to be paid per back end that does it.
#
# Reports the DISTRIBUTION: which back ends, how many predicates each.  Run it
# before fixing any one of them.
#
# usage: mtN-preddup.sh <gcc-srcdir>
set -e
S=${1:-$(cd "$(dirname "$0")/../gcc" && pwd)}
[ -d "$S/config" ] || { echo "FATAL: $S/config is not a directory"; exit 9; }

tot=0; nbe=0
for md in "$S"/config/*/predicates.md; do
  [ -f "$md" ] || continue
  cpu=$(basename "$(dirname "$md")")
  protos="$S/config/$cpu/$cpu-protos.h"
  [ -f "$protos" ] || continue
  # Predicate names this back end defines.
  preds=$(sed -n 's/^[ \t]*(define\(_special\)\?_predicate[ \t]*"\([a-zA-Z_0-9]*\)".*/\2/p' "$md" | sort -u)
  [ -n "$preds" ] || continue
  hits=
  for p in $preds; do
    # Declared in <cpu>-protos.h as a function?  Match the name followed by
    # optional whitespace and an open paren, anywhere on the line.
    if grep -E "^[^/]*\b$p[ 	]*\(" "$protos" > /dev/null; then
      hits="$hits $p"
    fi
  done
  if [ -n "$hits" ]; then
    n=$(echo $hits | wc -w)
    nbe=$((nbe + 1)); tot=$((tot + n))
    printf '%-12s %2d  %s\n' "$cpu" "$n" "$hits"
  fi
done
echo
echo "$nbe back ends hand-declare $tot generated predicates in total"
[ "$nbe" -gt 0 ] || echo "NOTE: zero -- confirm the predicate extraction worked before believing it"
