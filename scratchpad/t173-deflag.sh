#!/bin/sh
# #173 -- the surviving prose names the FLAG where it means the FACT.
#
# "Compiled once per back end, with `-I<base>-inc' so every header it reaches
# is that back end's" is one true statement about the file and one incidental
# statement about how the build spells it.  Keep the first, drop the second:
# the fact stays true whichever flag supplies it, and `git grep -- '-I.*-inc'`
# becomes a check for the mechanism rather than a list of comments.
set -e
cd "$(dirname "$0")/.."
before=$(git grep -c -- '-I.*-inc\>' ':(exclude)scratchpad' | awk -F: '{s+=$2} END {print s}')

sed -i \
  -e "s|Compiled once per back end, with \`-I<base>-inc' so every header it reaches|Compiled once per back end, so every header it reaches|" \
  gcc/target-regs.cc gcc/target-cdata.cc gcc/target-cumargs.cc

sed -i \
  -e "s|Compiled once per back end, with \`-I<base>-inc' so that every \`tm.h',|Compiled once per back end, so that every \`tm.h',|" \
  gcc/target-addr.cc

sed -i \
  -e "s|compiled ONCE PER BACK END with \`-I<base>-inc'\.|compiled ONCE PER BACK END.|" \
  gcc/target-cdata-opt.h

sed -i \
  -e "s|translation unit compiled with \`-I<base>-inc', the spelling|translation unit compiled for one back end, the spelling|" \
  gcc/target-attr.h

sed -i \
  -e "s|The per-back-end runs are fine: each is compiled with -I<base>-inc, so|The per-back-end runs are fine: each is compiled for one back end, so|" \
  gcc/genpreds.cc

sed -i \
  -e "s|# Compiled with -I<base>-inc for the same reason options-init-<base>.cc is: an|# Compiled per back end for the same reason options-init-<base>.cc is: an|" \
  gcc/optc-gen.awk

after=$(git grep -c -- '-I.*-inc\>' ':(exclude)scratchpad' | awk -F: '{s+=$2} END {print s}')
echo "-I<...>-inc mentions outside scratchpad: $before -> $after"
