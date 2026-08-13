#!/bin/sh
# #141 -- POSITION CLASSIFICATION for the option-state family.
#
# The brief's rule: a macro on a `#if'/`#ifdef' line cannot always become a
# call, so classify sites by POSITION before converting any.  This script
# prints, per macro, the sites that are NOT ordinary run-time expressions:
# preprocessor lines, `case' labels, array bounds and static initialisers.
#
# CONTROLS, because an all-empty read is indistinguishable from "no dangerous
# sites" -- the exact shape PRINCIPLES section 7 names:
#   positive -- UNITS_PER_WORD must have >= 200 total shared hits
#   negative -- a name that does not exist must total 0
#   positive on the CLASSIFIER itself -- the pp pattern is run over lines this
#     script GENERATES, not over a macro in the tree.  The first draft anchored
#     it on `FIRST_PSEUDO_REGISTER' at hard-reg-set.h:45 and the control fired:
#     that site now reads MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER, so 0 is the
#     TRUE reading and the control had an expiry date -- PRINCIPLES section 6.
#     A self-generated fixture cannot expire.  It carries a real tab, because
#     `[ \t]' in an ERE bracket is backslash-and-t and would score every macro
#     as having no preprocessor sites.
set -u
SRC=$(cd "$(dirname "$0")/.." && pwd)
cd "$SRC" || exit 9

[ "$(grep -c MULTI_TARGET gcc/Makefile.in)" -ge 43 ] || {
  echo "FATAL: wrong tree (anchor $(grep -c MULTI_TARGET gcc/Makefile.in), want >= 43)"; exit 9; }

hits () {
  grep -rn "\\b$1\\b" gcc --include='*.cc' --include='*.h' --include='*.c' \
    | grep -v '^gcc/config/' | grep -v testsuite | grep -v '^gcc/ada/'
}
# A preprocessor conditional line naming the macro.  Tab written as a real
# character class via [[:blank:]] -- `[ \t]' in an ERE is backslash-and-t.
PP_RE=':[[:blank:]]*#[[:blank:]]*(if|elif|ifdef|ifndef)\b'
pp () { hits "$1" | grep -E "$PP_RE"; }
caselab () { hits "$1" | grep -E ':[[:blank:]]*case\b'; }

# Self-generated fixture for the pp pattern: three lines that MUST match (one
# with a leading tab, one with spaces before the `#', one `#ifdef') and one
# that must NOT (an ordinary use).  Written with printf so the tab is a tab.
ppfix () {
  printf 'a.h:1:#if ZZFIX > 0\n'
  printf 'a.h:2:\t# ifdef ZZFIX\n'
  printf 'a.h:3:   #elif ZZFIX == 1\n'
  printf 'a.h:4:  int x = ZZFIX;\n'
}

pos=$(hits UNITS_PER_WORD | wc -l)
neg=$(hits ZZ_NO_SUCH_MACRO_ZZ | wc -l)
ctl=$(ppfix | grep -Ec "$PP_RE")
echo "control positive UNITS_PER_WORD hits=$pos"
echo "control negative ZZ_NO_SUCH_MACRO_ZZ hits=$neg"
echo "control classifier pp-pattern on generated fixture=$ctl (want exactly 3)"
[ "$pos" -ge 200 ] || { echo "FATAL: positive control $pos"; exit 9; }
[ "$neg" -eq 0 ]   || { echo "FATAL: negative control $neg"; exit 9; }
[ "$ctl" -eq 3 ]   || { echo "FATAL: pp classifier scored $ctl/3 on its own fixture"; exit 9; }

for m in "$@"; do
  echo
  echo "===== $m   total=$(hits "$m" | wc -l)"
  echo "--- preprocessor-conditional sites ($(pp "$m" | wc -l))"
  pp "$m"
  echo "--- case-label sites ($(caselab "$m" | wc -l))"
  caselab "$m"
done
