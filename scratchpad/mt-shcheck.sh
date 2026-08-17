#!/bin/sh
# mt-shcheck.sh -- `sh -n' every committed shell script, and separately report
# COMMENT LINES CARRYING AN ODD NUMBER OF BACKTICKS.
#
# WHY THIS EXISTS.  `multi-target-0' at a5cd237d9db could not run
# `configure-gcc' AT ALL: `gcc/gen-target-manifest.sh' had a hard shell syntax
# error, introduced by b1d30fa6d35, and it sat on the branch tip while every
# agent worktree inherited it.  The build failure it produces is
#
#   gen-target-manifest.sh: line 372: syntax error near unexpected token `('
#   make: *** [Makefile:4804: configure-gcc] Error 1
#
# with **zero `error:' lines** -- so mt-build.sh's summary reads
# "error: 0, multiple definition 0, undefined reference 0" and only the rc
# says anything is wrong.  That is the shape PRINCIPLES names repeatedly: a
# count-based scorer whose counts are all clean on a build that did nothing.
#
# THE MECHANISM IS WORTH KNOWING BECAUSE IT DEFEATS READING.  The file quotes
# identifiers GNU-style as `foo', i.e. ONE backtick per quotation.  At the top
# level that is harmless -- a `#' comment is discarded to end of line.  But
# `gen-target-manifest.sh:117' opens a MULTI-LINE command substitution
# (`gcc_mt_data=`...`) that spans two hundred lines, and while scanning for
# the closing backtick the shell does NOT honour `#' comments.  So two
# GNU-quoted words in comments at lines 219 and 221 silently re-paired the
# substitution boundaries, and the imbalance surfaced 150 lines later at the
# next comment backtick, naming a line that is *correct in itself*.  Reading
# line 372 tells you nothing; the fault is at 219.
#
# Hence TWO arms, deliberately not merged:
#
#   ARM 1  `sh -n' -- the verdict.  It is what the build would have said.
#   ARM 2  odd-backtick comment lines -- the LANDMINE census.  These are not
#          errors today; they are the lines that become one the moment any
#          multi-line backtick substitution grows past them.  A file can pass
#          arm 1 and be one edit from failing it.  Reported, never fatal, so
#          it cannot be "fixed" by deleting the check.
#
# Prefer `$(...)' over backticks in new code: `$(...)' nests properly and its
# scan DOES honour comments, so this class cannot occur inside one.
#
# usage: mt-shcheck.sh [srcdir]        (default: this script's worktree)
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=${1:-$(cd "$S/.." && pwd)}
SRC=$(cd "$SRC" && pwd)
cd "$SRC"

command -v sh > /dev/null 2>&1 || { echo "FATAL: no sh"; exit 9; }

# The population: committed shell scripts.  `git ls-files' rather than `find',
# so an uncommitted scratch file cannot fail the tree and a DELETED file
# cannot pass it by being absent.
git ls-files -- '*.sh' > /tmp/mt-shcheck-list.$$ 2>/dev/null \
  || { echo "FATAL: not a git tree ($SRC)"; exit 9; }
N=$(wc -l < /tmp/mt-shcheck-list.$$)
[ "$N" -ge 20 ] || { echo "REFUSE: only $N .sh files listed -- the scan read nothing"; rm -f /tmp/mt-shcheck-list.$$; exit 9; }

# NEGATIVE CONTROL, run BEFORE the population.  "sh -n found nothing" and
# "sh -n never ran" are the same silence; a file that MUST fail proves the arm
# can fail.  PRINCIPLES: an injection that does not fire is a finding.
printf 'if true; then\n' > /tmp/mt-shcheck-bad.$$
if sh -n /tmp/mt-shcheck-bad.$$ 2>/dev/null; then
  echo "FATAL: the negative control PASSED -- \`sh -n' is not checking anything"
  rm -f /tmp/mt-shcheck-bad.$$ /tmp/mt-shcheck-list.$$
  exit 9
fi
rm -f /tmp/mt-shcheck-bad.$$
echo "control ok: a deliberately unterminated \`if' is refused by \`sh -n'"
echo "population: $N committed .sh files under $SRC"
echo

fail=0
while read -r f; do
  if ! err=$(sh -n "$f" 2>&1); then
    fail=$((fail + 1))
    echo "SYNTAX-ERROR $f"
    printf '%s\n' "$err" | sed 's/^/    /'
  fi
done < /tmp/mt-shcheck-list.$$
echo "arm 1  sh -n: $fail of $N files fail"
echo

echo "arm 2  comment lines with an ODD number of backticks (landmines, not errors):"
odd=0
while read -r f; do
  n=$(awk '/^[ \t]*#/ { c = gsub(/`/, "`"); if (c % 2) print FILENAME ":" FNR }' "$f" | wc -l)
  [ "$n" = 0 ] && continue
  odd=$((odd + n))
  printf '  %-56s %s\n' "$f" "$n"
done < /tmp/mt-shcheck-list.$$
echo "arm 2  total: $odd odd-backtick comment lines"
rm -f /tmp/mt-shcheck-list.$$
[ "$fail" = 0 ] || exit 1
