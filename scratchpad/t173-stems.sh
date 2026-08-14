#!/bin/sh
# #173 -- for each MULTI_TARGET_INC_STEM, how many gcc/config/ files and how
# many SHARED files spell the plain `#include "<stem>.h"'.  A stem with shared
# includers cannot be converted to BASE_HEADER: a shared header cannot name a
# base.  That is the population the -I was actually serving.
set -e
cd "$(dirname "$0")/.."
printf '%-20s %8s %8s %8s\n' stem config shared BASE_HDR
for s in tm tm_p tm-preds tm-constrs options insn-constants insn-attr \
	 insn-attr-common insn-codes insn-config insn-flags insn-modes \
	 insn-modes-inline insn-opinit insn-recog insn-target-def; do
  c=$(git grep -l "#include \"$s\.h\"" -- gcc/config | wc -l)
  h=$(git grep -l "#include \"$s\.h\"" -- gcc ':!gcc/config' | wc -l)
  b=$(git grep -l "BASE_HEADER ($s\.h)" -- gcc | wc -l)
  printf '%-20s %8s %8s %8s\n' "$s" "$c" "$h" "$b"
done
