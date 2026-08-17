#!/bin/sh
# Both-sided header read for a list of macro names: the SHARED tm.h against
# each <base>-inc/tm.h, over any set of bases.
#
# MUST BE RUN WITH -DIN_GCC.  The back-end header chain sits inside
# `#ifdef IN_GCC', so without it every arm reads the floor, every row looks
# converted, and the instrument refutes all findings at once while looking
# clean.  That mistake has been made and caught here.
#
# A name whose shared value EQUALS a base's value is either converted or
# genuinely neutral; a name where they DIFFER is a live leak for that base.
#
# THIS SCRIPT HARDCODED `B=/tmp/b-a992b7e5fa4ffaaa7/gcc' AND
# `S=/tmp/snap-agent-a992b7e5fa4ffaaa7' -- another worktree's build dir and
# snapshot.  PRINCIPLES sizes that population at 485 of 506 scripts: the line
# is correct when written and becomes foreign the moment the file is committed
# and inherited.  Run from a later worktree it measures a compiler that is not
# the one under test, or -- once those directories are cleaned up -- reports
# every arm as `(undef)', which reads as "the macro is nowhere" rather than as
# "nothing was preprocessed".  The build dir is now a REQUIRED argument with no
# default, and the srcdir is read from the build dir's own MY-SRC stamp rather
# than guessed.
#
# It also fixed the base list to five names.  MT_BASES now defaults to every
# `<base>-inc' directory the build dir actually has, so a census means all 47
# rather than the pair whoever wrote it was thinking about -- which is
# PRINCIPLES' "two back ends cannot tell" written into an instrument.
#
# RUN IT INSIDE THE DEV SHELL.  `g++' is not on PATH outside it, and
# `command not found' piped into the define count is a 0 -- i.e. exactly the
# reading the non-vacuity arm below refuses.  (It does refuse it, verified by
# running outside the shell on purpose.)
#
# usage: [MT_BASES='aarch64 i386 ...'] \
#          sh eb-shell.sh "sh agent-a992b7e5fa4ffaaa7-floorread.sh <builddir> <NAME>..."
set -u
D=${1:?build dir (NOT defaulted -- see the header)}; shift
[ -r "$D/MY-SRC" ] || { echo "FATAL: no $D/MY-SRC -- cannot say which tree this is"; exit 9; }
S=$(cat "$D/MY-SRC")/gcc
B=$D/gcc
[ -d "$B" ] || { echo "FATAL: no $B"; exit 9; }
[ -d "$S" ] || { echo "FATAL: no $S (from MY-SRC)"; exit 9; }
[ "$#" -gt 0 ] || { echo "FATAL: no macro names given"; exit 9; }
cd "$B" || exit 9

if [ -n "${MT_BASES:-}" ]; then
  BASES=$MT_BASES
else
  BASES=$(ls -d ./*-inc 2>/dev/null | sed -e 's|^\./||' -e 's|-inc$||' | sort | tr '\n' ' ')
fi
[ -n "$BASES" ] || { echo "FATAL: no <base>-inc directories in $B"; exit 9; }
echo "build $D"
echo "src   $(cat "$D/MY-SRC")"
echo "bases $(printf '%s' "$BASES" | wc -w): $BASES"

INC="-I. -I$S -I$S/../include -I$S/../libcpp/include"
T=$(mktemp -d) || exit 9
trap 'rm -rf "$T"' 0

read_one () {  # read_one <tag> <extra-cpp-flags> <include-line>
  printf '%s\n' "$3" > "$T/fc.cc"
  # shellcheck disable=SC2086
  g++ -E -dM -DIN_GCC -DHAVE_CONFIG_H $2 $INC "$T/fc.cc" > "$T/fc-$1.out" 2> "$T/fc-$1.err"
  # NON-VACUITY: an empty preprocess and "the macro is undefined everywhere"
  # are the same table.
  n=$(grep -c '^#define ' "$T/fc-$1.out" 2>/dev/null)
  [ -n "$n" ] || n=0
  [ "$n" -ge 1000 ] || {
    echo "FATAL: $1 preprocessed to $n defines -- the arm read nothing."
    head -3 "$T/fc-$1.err"; exit 9; }
}

read_one SHARED "" '#include "tm.h"'
for base in $BASES; do
  read_one "$base" "-DMT_BASE=$base-inc" "#include \"$base-inc/tm.h\""
done

val () { sed -n "s/^#define $2 \(.*\)$/\1/p" "$T/fc-$1.out" | head -1; }

for n in "$@"; do
  s=$(val SHARED "$n"); [ -n "$s" ] || s="(undef)"
  echo
  echo "== $n"
  printf '  %-12s %s\n' SHARED "$s"
  agree=0; differ=0; undef=0
  for base in $BASES; do
    v=$(val "$base" "$n"); [ -n "$v" ] || v="(undef)"
    if [ "$v" = "(undef)" ]; then undef=$((undef+1))
    elif [ "$v" = "$s" ]; then agree=$((agree+1))
    else differ=$((differ+1)); printf '  %-12s %s   <- DIFFERS\n' "$base" "$v"
    fi
  done
  printf '  %-12s agree %s   differ %s   undefined %s\n' '' "$agree" "$differ" "$undef"
done
