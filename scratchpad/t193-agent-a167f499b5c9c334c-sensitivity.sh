#!/bin/sh
# #193 -- SENSITIVITY.  "812 shared objects OPEN insn-modes.h" and "579 OPEN
# options.h" are counts of an INCLUDE, not of a dependence on anything that
# differs.  A header can be opened by everyone and still be target-neutral in
# every name the reader uses.
#
# So: given the set of names that actually DIVERGE between bases (computed by
# the sibling optionsclass.sh / modediff.sh runs), which SHARED sources spell
# one of them?  That is the population a conversion would have to touch, and
# it is the honest denominator.
#
# The scan is over the SOURCE, deliberately over-broad (a name inside a
# comment or a string counts), because this instrument can only ADD files to
# the population, never remove one -- PRINCIPLES 4, "when an instrument can
# only take away, make it too eager; when it can grant, make it exact".  It
# grants nothing.
#
# usage: NAMES=<file of names> t193-...-sensitivity.sh <srcdir>
set -u
SRC=${1:?srcdir}
N=${NAMES:?set NAMES to a file of identifiers, one per line}
[ -s "$N" ] || { echo "FATAL: $N is empty -- a zero hit count would be unreadable"; exit 9; }
echo "names: $(wc -l < "$N")"

# Shared = under gcc/, NOT under gcc/config/.  This is a SOURCE-side
# approximation and it is stated as one: 221 sources at gcc/ are compiled once
# per base (t187 arm 1 settles that properly from the makefile).  It is used
# here only to size a population, never to certify one.
pat=$(paste -sd'|' "$N")
hits=$( (cd "$SRC/gcc" && grep -rlwE "$pat" --include='*.cc' --include='*.h' --include='*.c' . 2>/dev/null) \
        | grep -v '^\./config/' | grep -v ChangeLog | sort -u )
nh=$(printf '%s\n' "$hits" | grep -c . || true)
echo "shared-ish sources spelling at least one: $nh"
printf '%s\n' "$hits" | head -40 | sed 's/^/  /'

# CONTROL: a name that cannot be there must score 0, and a name that must be
# there must score >0.  Both, because either alone is satisfied by a broken
# scan.
z=$( (cd "$SRC/gcc" && grep -rlwE 'MT_NO_SUCH_IDENTIFIER_ZZZ' --include='*.cc' . 2>/dev/null) | wc -l)
o=$( (cd "$SRC/gcc" && grep -rlwE 'gcc_unreachable' --include='*.cc' . 2>/dev/null) | wc -l)
echo "control: impossible name -> $z files (want 0); 'gcc_unreachable' -> $o files (want >0)"
[ "$z" = 0 ] || { echo "FATAL: impossible name matched"; exit 9; }
[ "$o" -gt 0 ] || { echo "FATAL: the scan found nothing at all -- it is not running"; exit 9; }
