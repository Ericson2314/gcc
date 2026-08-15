#!/bin/sh
# Read the __intN registration OUT OF A RUNNING COMPILER, per back end.
#
# WHY NOT READ THE SOURCE, AND WHY NOT READ insn-modes-<base>.h.  The defect
# this arm witnesses is not "the header says 2".  Every header already said 2
# before the fix -- `insn-modes-avr.h' has said `NUM_INT_N_ENTS 2' the whole
# time.  What was broken is that no shared loop ever REACHED index 1, because
# every one of them was bounded by the PRIMARY's 1.  A build that merely
# compiles proves nothing about that, and neither does the generated header.
#
# THE FIRST OBSERVABLE THIS SCRIPT TRIED WAS WRONG, AND IT IS RECORDED RATHER
# THAN QUIETLY REPLACED, because it is the more instructive half.
#
# It asserted that avr would gain `__SIZEOF_INT128__' among its predefines,
# since c-cppbuiltin.cc:1710 walks the entries and defines
# `__SIZEOF_INT<bitsize>__' for each.  It does not, and MUST not: that loop is
# guarded by `int_n_enabled_p[i]', which toplev.cc:2218 sets from
# `targetm.scalar_mode_supported_p (int_n_data[i].m)' -- and avr does not
# support TImode.  So the absence is upstream-correct behaviour and the arm was
# measuring the wrong thing.  Had it been believed, a WORKING fix would have
# been scored as broken.  The predefine arm is kept below, with that absence
# asserted rather than lamented.
#
# THE OBSERVABLE THAT ACTUALLY DISCRIMINATES is the KEYWORD, because
# c-parser.cc's registration loop creates the identifiers unconditionally --
# its own comment says "We always create the symbols but they aren't always
# supported".  So:
#
#   index 1 NOT registered  ->  `__int128' is not a keyword at all
#                               "error: unknown type name '__int128'"
#   index 1 registered, mode unsupported
#                           ->  "error: '__int128' is not supported on this
#                                target"   (c-decl.cc:12705, int_n_enabled_p)
#
# Two different diagnostics, and only the second is reachable if the loop got
# to index 1.  Before this fix avr and msp430 produced the first.
#
# THE CONTROL, so that the two messages are known to be distinguishable on THIS
# compiler rather than assumed: `__int24' on x86_64 and on msp430 must give the
# "unknown type name" form.  If that came back saying "not supported" too, the
# arm above would be reading one message under two names and proving nothing.
#
# BOTH-SIDED: x86_64 and aarch64 must still ACCEPT `__int128' and still REJECT
# `__int24'.  One-sided evidence cannot tell "fixed" from "everyone now gets
# the same new answer" -- and the wrong fix here (making NUM_INT_N_ENTS the
# union maximum everywhere) would have given all 45 single-entry back ends a
# read past the end of a one-element table.
#
# usage: agent-a3cea52a56e315ee4-intn.sh <builddir>
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

D=${1:?build dir}
mt_assert_builddir "$D"
SRC=$(mt_src_of "$D") || exit 9
mt_assert_configured_from "$D" "$SRC"
n=$(mt_assert_anchor "$SRC") || exit 9
V=$(cat "$SRC/gcc/BASE-VER")
OUT="$D/intn"; mkdir -p "$OUT"
[ -x "$D/gcc/cc1" ] || mt_die "no $D/gcc/cc1"

printf '__int128 x;\n' > "$OUT/i128.c"
printf '__int24 x;\n'  > "$OUT/i24.c"
printf '__int20 x;\n'  > "$OUT/i20.c"
: > "$OUT/empty.c"
fail=0

cfg () { echo "$D/lib/gcc/$V/$1/specs-config"; }

# compile <triple> <src> <tag>; leaves the diagnostic in $OUT/<triple>.<tag>
compile () {
  c=$(cfg "$1")
  [ -s "$c" ] || { echo "$1: NO specs-config at $c -- arm did not run"
                   fail=1; return 1; }
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -ftarget-config="$c" \
      "$OUT/$2.c" -o /dev/null ) > "$OUT/$1.$3.out" 2> "$OUT/$1.$3"
  return 0
}

# want_msg <triple> <src> <tag> <substring or the word ACCEPTED>
want_msg () {
  compile "$1" "$2" "$3" || return
  got=$(head -1 "$OUT/$1.$3")
  if [ "$4" = ACCEPTED ]; then
    if [ -s "$OUT/$1.$3" ]; then
      echo "  $1 $2: expected it to COMPILE, got: $got"; fail=1
    else
      echo "  $1 $2: accepted"
    fi
  elif echo "$got" | grep -qF "$4"; then
    echo "  $1 $2: $got"
  else
    echo "  $1 $2: expected \"$4\", got: ${got:-<no diagnostic at all>}"
    fail=1
  fi
}

echo "anchor=$n srcdir=$SRC"

echo "THE FIX -- index 1 is registered, so the keyword exists and the"
echo "diagnostic is about the MODE, not about the name:"
want_msg avr-unknown-elf    i128 k "'__int128' is not supported on this target"
want_msg msp430-unknown-elf i128 k "'__int128' is not supported on this target"

echo "THE CONTROL -- an UNregistered __intN gives the OTHER message, so the"
echo "two are known to be distinguishable on this compiler:"
want_msg x86_64-pc-linux-gnu i24 c "unknown type name '__int24'"
want_msg msp430-unknown-elf  i24 c "unknown type name '__int24'"

echo "BOTH-SIDED -- the 45 one-entry back ends are unchanged:"
want_msg x86_64-pc-linux-gnu      i128 k ACCEPTED
want_msg aarch64-unknown-linux-gnu i128 k ACCEPTED

echo "AND index 0 still works where it should:"
want_msg avr-unknown-elf    i24 a ACCEPTED
want_msg msp430-unknown-elf i20 a ACCEPTED

# THE PREDEFINE ARM, with the absence asserted.  See the header: avr has a
# second entry and must NOT get __SIZEOF_INT128__, because TImode is not a mode
# avr supports.  Asserting the absence is what turns the first version's
# mistake into a check.
echo "PREDEFINES -- enabled entries only:"
pre () {
  t=$1; want=$2; unwant=$3
  c=$(cfg "$t")
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -E -dM -ftarget-config="$c" \
      "$OUT/empty.c" -o "$OUT/$t.dM" ) > "$OUT/$t.dM.out" 2> "$OUT/$t.dM.err"
  # NON-VACUITY: without this, every grep below is a question about an empty
  # file and an all-absent read looks exactly like the thing being proved.
  grep -q '^#define __SIZEOF_LONG__ ' "$OUT/$t.dM" || {
    echo "  $t: FATAL: not a predefine dump; the readings below prove nothing"
    fail=1; return; }
  echo "  $t: [$(grep -o '__SIZEOF_INT[0-9][0-9]*__' "$OUT/$t.dM" | sort -u | tr '\n' ' ')]"
  for w in $want; do
    grep -q "^#define $w " "$OUT/$t.dM" || { echo "    MISSING $w"; fail=1; }
  done
  for u in $unwant; do
    grep -q "^#define $u " "$OUT/$t.dM" && { echo "    UNEXPECTED $u"; fail=1; }
  done
  return 0
}
pre avr-unknown-elf            "__SIZEOF_INT24__"  "__SIZEOF_INT128__"
pre msp430-unknown-elf         "__SIZEOF_INT20__"  "__SIZEOF_INT128__"
pre x86_64-pc-linux-gnu        "__SIZEOF_INT128__" "__SIZEOF_INT24__ __SIZEOF_INT20__"
pre aarch64-unknown-linux-gnu  "__SIZEOF_INT128__" "__SIZEOF_INT24__ __SIZEOF_INT20__"

if [ "$fail" = 0 ]; then echo "int_n registration: OK"; else
  echo "int_n registration: FAILED"; fi
exit "$fail"
