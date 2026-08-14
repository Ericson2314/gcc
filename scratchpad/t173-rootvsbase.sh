#!/bin/sh
# #173 -- for each per-back-end stem, is the BUILD ROOT's plain copy the same
# file as a base's own, and do two bases differ from each other?
#
# Three outcomes and they mean different things:
#
#   root == every base      the stem is unioned; the -I decides nothing and
#                           deleting it is safe for that stem.
#   root == ONE base only   the build root holds the PRIMARY's copy; deleting
#                           the -I silently gives every other base i386's
#                           answer.  This is the bug the branch exists to
#                           remove, reintroduced.
#   bases differ            the stem is genuinely per base, so SOMETHING must
#                           keep selecting it.
#
# Prints md5s rather than a verdict word, because "differs" is a claim about
# two files and the reader should be able to check it.
set -e
D=${1:?build dir}
A=${2:-i386}
B=${3:-aarch64}
cd "$D/gcc"
printf '%-22s %-14s %-14s %-14s %s\n' stem "root" "$A-inc" "$B-inc" verdict
for s in tm tm_p tm-preds tm-constrs options insn-constants insn-attr \
	 insn-attr-common insn-codes insn-config insn-flags insn-modes \
	 insn-modes-inline insn-opinit insn-target-def; do
  r=$([ -f "$s.h" ] && md5sum "$s.h" | cut -c1-12 || echo -)
  # <base>-inc/<stem>.h is a one-line forwarder; follow it to the real file.
  a=$([ -f "$A-inc/$s.h" ] && md5sum "$s-$A.h" 2>/dev/null | cut -c1-12 || echo -)
  b=$([ -f "$B-inc/$s.h" ] && md5sum "$s-$B.h" 2>/dev/null | cut -c1-12 || echo -)
  if [ "$a" = "$b" ] && [ "$r" = "$a" ]; then v="unioned; -I decides nothing"
  elif [ "$a" = "$b" ]; then v="bases agree, root DIFFERS"
  elif [ "$r" = "$a" ]; then v="root is $A's -- PRIMARY LEAK"
  elif [ "$r" = "$b" ]; then v="root is $B's -- PRIMARY LEAK"
  else v="per base, root is neither"
  fi
  printf '%-22s %-14s %-14s %-14s %s\n' "$s.h" "$r" "$a" "$b" "$v"
done
