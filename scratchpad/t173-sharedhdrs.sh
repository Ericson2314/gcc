#!/bin/sh
# #173 -- the TRANSITIVE channel, sized.
#
# The `-I' survives because shared code reaches per-back-end headers without
# naming them.  Only shared *headers* matter for that: a shared .cc is one
# translation unit compiled once, with no MT_BASE, and it correctly wants the
# build root's copy.  A shared HEADER is different -- it is textually included
# into per-back-end translation units too, and there its plain include is
# resolved by the `-I'.
#
# So this counts, per stem, the shared HEADERS that include it.  That number
# is the size of the remaining job.
set -e
cd "$(dirname "$0")/.."
printf '%-22s %8s  %s\n' stem headers files
for s in tm_p tm-preds tm-constrs options insn-constants insn-attr \
	 insn-attr-common insn-codes insn-config insn-flags insn-modes \
	 insn-modes-inline insn-opinit insn-target-def; do
  f=$(git grep -l "#include \"$s\.h\"" -- 'gcc/*.h' 'gcc/*/*.h' \
	':!gcc/config' | sort)
  n=$(printf '%s' "$f" | grep -c . || true)
  [ "$n" = 0 ] && continue
  printf '%-22s %8s  %s\n' "$s.h" "$n" "$(printf '%s' "$f" | tr '\n' ' ')"
done
echo
echo "coretypes.h reaches insn-modes.h through a macro, not a plain include:"
grep -n 'INSN_MODES_H\|INSN_MODES_INLINE_H' gcc/coretypes.h
