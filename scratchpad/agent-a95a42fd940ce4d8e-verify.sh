#!/bin/sh
# agent-a95a42fd940ce4d8e-verify.sh -- the SAME cc1 invocation on the SAME 14
# testcases, PRE build dir vs POST build dir, printed BY TEST NAME.
#
# This is the targeted arm.  It exists beside the full `compile.exp' runs, not
# instead of them, and the division of labour is deliberate:
#
#   this script      does the `extract_insn' site go to zero on the tests that
#                    carried it?  14 files x 6 back ends, seconds.
#   score6.sh        did anything ELSE move?  ~15,000 results per back end,
#                    hours, and the only arm that can see a regression this
#                    one is blind to by construction.
#
# A targeted verification CANNOT show a fix is safe -- it only looks where the
# bug was.  Quoting it alone would be the "check that answers a different
# question than the one being settled" shape PRINCIPLES records three times in
# one session.  Both are reported, and this one is labelled as what it is.
#
# BOTH SIDES ARE RUN HERE rather than one side being read from the earlier
# board: the PRE and POST build dirs differ in the commit AND in their paths,
# and running both through one code path is what makes the comparison a
# difference of one variable.
set -u
PRE=${PRE:-/tmp/b-a95a42fd940ce4d8e}
POST=${POST:-/tmp/b-a95a42fd940ce4d8e-post}
O=${O:-/tmp/w-agent-a95a42fd940ce4d8e/verify}
mkdir -p "$O"
for d in "$PRE" "$POST"; do
  [ -x "$d/gcc/cc1" ] || { echo "FATAL: no $d/gcc/cc1"; exit 9; }
done
SIX="alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi
avr-unknown-elf mips64-unknown-elf or1k-unknown-elf"
# The tests that carried the site, per back end, from the scored board.
T_alpha="pr21728.c 20050122-2.c pr82337.c complex-6.c 20011029-1.c"
T_arc="pr21728.c 20050122-2.c"
T_arm="pr21728.c 20050122-2.c"
T_avr="pr21728.c string-large-1.c"
T_mips="pr21728.c 20050122-2.c"
T_or1k="pr21728.c 20050122-2.c"
# c-torture runs each file at these levels; the board's row counts are per
# (file, level) pair, which is why 14 files give 71 rows.
LEVELS="-O0 -O1 -O2 -Os -O3"

one () { # builddir target file opt -> prints ICE / ok / other
  d=$1; t=$2; f=$3; o=$4
  V=$(cat "$(cat "$d/MY-SRC")/gcc/BASE-VER")
  S=$(cat "$d/MY-SRC")
  c="$d/lib/gcc/$V/$t/specs-config"
  i="$S/gcc/testsuite/gcc.c-torture/compile/$f"
  [ -s "$c" ] || { echo NO-SPECS; return; }
  [ -s "$i" ] || { echo NO-INPUT; return; }
  w="$O/$(basename "$d")-$t-$f-$o"; rm -rf "$w"; mkdir -p "$w"; cp "$i" "$w/in.c"
  ( cd "$w" && "$d/gcc/cc1" -quiet -nostdinc $o -ftarget-config="$c" \
      in.c -o out.s ) > "$w/out" 2> "$w/err"
  if grep -q 'recog.cc:2892' "$w/err"; then echo ICE-2892
  elif grep -q 'internal compiler error' "$w/err"; then echo OTHER-ICE
  elif [ -s "$w/out.s" ]; then echo ok
  else echo NO-OUTPUT; fi
}

tests_for () {
  case $1 in
    alpha*) echo "$T_alpha";; arc*) echo "$T_arc";; arm*) echo "$T_arm";;
    avr*) echo "$T_avr";; mips*) echo "$T_mips";; or1k*) echo "$T_or1k";;
  esac
}

printf '%-26s %-18s %-4s %-10s %-10s %s\n' TARGET TEST OPT PRE POST MOVED
pre_ice=0; post_ice=0; n=0
for t in $SIX; do
  for f in $(tests_for "$t"); do
    for o in $LEVELS; do
      a=$(one "$PRE" "$t" "$f" "$o")
      b=$(one "$POST" "$t" "$f" "$o")
      n=$((n+1))
      [ "$a" = ICE-2892 ] && pre_ice=$((pre_ice+1))
      [ "$b" = ICE-2892 ] && post_ice=$((post_ice+1))
      m=''
      [ "$a" = ICE-2892 ] && [ "$b" != ICE-2892 ] && m='FIXED'
      [ "$a" != ICE-2892 ] && [ "$b" = ICE-2892 ] && m='*** NEW ICE ***'
      printf '%-26s %-18s %-4s %-10s %-10s %s\n' "$t" "$f" "$o" "$a" "$b" "$m"
    done
  done
done
echo
echo "pairs run: $n    recog.cc:2892  PRE $pre_ice  ->  POST $post_ice"
# NON-VACUITY: if the PRE side shows no ICEs at all, this harness is not
# reproducing the defect and its POST zero means nothing.
[ "$pre_ice" -gt 0 ] || { echo "FATAL: PRE side shows no ICE -- not a verification"; exit 9; }
