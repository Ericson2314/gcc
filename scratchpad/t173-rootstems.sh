#!/bin/sh
# #173 -- WHICH of the per-back-end stems also exist under their PLAIN name in
# the build root.
#
# This is the question that decides whether deleting `-I<base>-inc' fails
# loudly or silently.  A stem with no plain copy in the build root becomes a
# `No such file' the moment the -I goes -- that is the loud, wanted case.  A
# stem that DOES have a plain copy there is the dangerous one: the per-base
# object silently starts reading the build root's version, which is either the
# union (fine) or the primary back end's (the bug this branch exists to
# remove), and nothing says which.
set -e
D=${1:?build dir}
cd "$D/gcc"
printf '%-22s %s\n' stem 'plain copy in build root'
for s in tm tm_p tm-preds tm-constrs options insn-constants insn-attr \
	 insn-attr-common insn-codes insn-config insn-flags insn-modes \
	 insn-modes-inline insn-opinit insn-recog insn-target-def; do
  if [ -f "$s.h" ]; then
    printf '%-22s PRESENT  (%s bytes)\n' "$s.h" "$(wc -c < "$s.h")"
  else
    printf '%-22s absent\n' "$s.h"
  fi
done
