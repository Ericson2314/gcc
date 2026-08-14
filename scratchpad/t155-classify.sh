#!/bin/sh
# #155 -- APPLY THE DECISION RULE to every name, mechanically.
#
# gcc/Makefile.in's MULTI_TARGET_RENAME_NAMES comment states the rule:
#
#   * NO shared translation unit names the symbol  -> each back end keeps its
#     own function and a BARE RENAME suffices.  No selector, no dispatch.
#   * A shared TU DOES name it -> the middle end genuinely has to choose, and
#     it needs a SELECTOR.  A rename would only move the failure.
#
# So the question this script answers is exactly one thing: does anything
# OUTSIDE gcc/config/ spell the bare name?  It must not be guessed from the
# name -- print_operand looks like the middle end's business and is not.
#
# THREE EXCLUSIONS, each measured rather than assumed:
#
#   genmatch.cc, gengtype*.cc, gen*.cc   build-time GENERATORS.  They are
#       separate programs; their symbols never enter cc1, so a name they
#       define is not a collision with a back end's.  genmatch.cc really does
#       define its own print_operand and it is irrelevant here.
#   a comment                            targhooks.cc's only occurrence of
#       print_operand is the word inside a comment describing the hook.
#   targetm.asm_out.print_operand        a STRUCT MEMBER, not the bare symbol.
#       final.cc:3679 reaches the back end THROUGH the hook, which is why
#       print_operand needs no selector despite final.cc naming it.
#
# The output marks each name RENAME or SELECTOR-CANDIDATE and prints the
# evidence, so the classification can be checked rather than trusted.
#
# usage: t155-classify.sh <name>...
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
[ -d "$G/config" ] || { echo "FATAL: $G/config missing"; exit 9; }

for n in "$@"; do
  hits=$(grep -rnw "$n" "$G" --include='*.cc' --include='*.c' --include='*.h' 2>/dev/null \
    | grep -v "^$G/config/" \
    | grep -v '/testsuite/' \
    | grep -v "^$G/gen[a-z-]*\.cc:" \
    | grep -v "^$G/multi-target" \
    | grep -v "[.>]$n\b" )
  # Drop prose.  GNU comments quote an identifier as backtick-name-quote, and
  # that spelling accounted for EVERY apparent hit on the first run -- three
  # names scored SELECTOR? purely on their own explanatory comments, including
  # print_operand on targhooks.cc's description of the hook.  A classifier that
  # cannot tell a mention from a use classifies documentation.
  bq=$(printf '\140')       # backtick, by code: a literal one here would be
                            # command substitution inside the double quotes.
  real=$(printf '%s\n' "$hits" | grep . \
    | grep -v ':[ \t]*[*/]' \
    | grep -v "$bq$n'")
  if [ -z "$real" ]; then
    echo "RENAME    $n   (no shared TU names the bare symbol)"
  else
    echo "SELECTOR? $n"
    printf '%s\n' "$real" | sed "s|^$G/|            |"
  fi
done
