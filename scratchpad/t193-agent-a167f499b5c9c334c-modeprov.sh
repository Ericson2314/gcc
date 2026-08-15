#!/bin/sh
# #193 -- IS THE ONLY DIVERGENCE THE PROVENANCE COMMENT?
#
# The sibling script's stripper cannot remove the leading two-line block
# comment (`/* Generated automatically from machmode.def and
# config/<be>/<be>-modes.def\n   by genmodes.  */'), because its regex is
# single-line.  That comment names the back end, so EVERY base's file differs
# from every other's on it and a distinct-md5 count over the stripped files
# reproduces the number of distinct modes.def paths rather than the number of
# distinct mode vocabularies.
#
# This drops the first two lines and re-counts.  If the answer is 1, the mode
# header is UNIONED and the build root's copy leaks nothing but a comment.
#
# NEGATIVE CONTROL: the same count is taken over `insn-flags-<base>.h', which
# is per-back-end by construction (its content is that back end's `HAVE_*'
# insn predicates).  If THAT also came back 1, the counter is broken.
set -u
G=${1:?build dir}/gcc
# Drop the two-line leading block comment AND every single-line /* ... */,
# which is the per-enumerator `/* config/<be>/<be>-modes.def:NN */' provenance
# stamp -- a mode this back end does not define is stamped `/* <unknown>:0 */'
# instead, so that comment differs for every base while the C does not.
body () { tail -n +3 "$1" | sed -e 's,/\*[^*]*\*/,,g' -e 's/[[:space:]]*$//' \
          | md5sum | cut -c1-12; }

for stem in insn-modes insn-modes-inline insn-flags; do
  f=$(ls "$G"/$stem-*.h 2>/dev/null | head -1)
  [ -n "$f" ] || { echo "$stem: no per-base files"; continue; }
  : > /tmp/t193-prov-$$.txt
  n=0
  for p in "$G"/$stem-*.h; do
    case "$p" in *-inline-*) [ "$stem" = insn-modes-inline ] || continue ;; esac
    [ "$stem" = insn-modes ] && case "$p" in *insn-modes-inline-*) continue ;; esac
    body "$p" >> /tmp/t193-prov-$$.txt
    n=$((n + 1))
  done
  d=$(sort -u /tmp/t193-prov-$$.txt | wc -l)
  rm -f /tmp/t193-prov-$$.txt
  printf '%-20s %3d files, %3d distinct bodies (first 2 lines dropped)\n' "$stem" "$n" "$d"
done
echo
echo "insn-flags is the negative control: it MUST be >1, or this counter is broken."
