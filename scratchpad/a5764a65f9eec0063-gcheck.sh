#!/bin/sh
# a5764a65f9eec0063 -- is the x86_64 `-g' output really unchanged?
#
# `mt-bars.sh' compiles `$SRC/scratchpad/big.c', i.e. a path inside the
# SNAPSHOT directory, and the snapshot is named after the build.  So
# `/tmp/snap-...-fix' and `/tmp/snap-...-fix3' differ by one character, that
# path is embedded in the debug info (DW_AT_name / DW_AT_comp_dir), and the
# `-g' md5 MUST differ for a reason that has nothing to do with the compiler.
# The `-O2' bar has no debug info and so is immune, which is why it matched.
#
# This compiles ONE constant absolute path with both compilers, so the only
# thing that can differ is the compiler.  If the md5s still differ, the change
# is real and the path story is wrong.
set -u
A=${A:?first build dir}
B=${B:?second build dir}
W=${W:-/tmp/w-a5764a65f9eec0063/gcheck}
SRCF=$(cd "$(dirname "$0")" && pwd)/big.c
MEMCAP=$(cd "$(dirname "$0")" && pwd)/tb1-memcap.sh
[ -f "$SRCF" ] || { echo "FATAL: no $SRCF"; exit 9; }
mkdir -p "$W"
T=x86_64-pc-linux-gnu

for tag in a b; do
  case $tag in a) D=$A ;; b) D=$B ;; esac
  CFG=$D/lib/gcc/17.0.0/$T/specs-config
  [ -f "$CFG" ] || { echo "FATAL: no specs-config in $D"; exit 9; }
  sh "$MEMCAP" 8000000 "$D/gcc/xgcc" -B"$D/gcc/" -ftarget-config="$CFG" \
     -O2 -g -S "$SRCF" -o "$W/$tag.s" > "$W/$tag.out" 2> "$W/$tag.err"
  r=$?
  [ "$r" = 0 ] || { echo "FATAL($tag): rc=$r"; sed -n 1,5p "$W/$tag.err"; exit 9; }
  [ -s "$W/$tag.s" ] || { echo "FATAL($tag): empty .s"; exit 9; }
done

ma=$(md5sum < "$W/a.s" | cut -c1-12)
mb=$(md5sum < "$W/b.s" | cut -c1-12)
echo "input (constant for both): $SRCF"
echo "  A=$A   -O2 -g  $(wc -c < "$W/a.s") bytes  md5 $ma"
echo "  B=$B   -O2 -g  $(wc -c < "$W/b.s") bytes  md5 $mb"
# THE INPUT PATH WAS NOT THE ONLY PATH, AND THIS SCRIPT'S HEADER WAS WRONG.
#
# "This compiles ONE constant absolute path with both compilers, so the only
# thing that can differ is the compiler."  It is not: the BUILD DIR is on the
# command line as `-ftarget-config=<builddir>/lib/gcc/.../specs-config', the
# whole command line lands in DW_AT_producer, and the two build dirs are
# exactly what this script is being asked to compare.  So it could NEVER
# return IDENTICAL for two differently-named build dirs, whatever the
# compiler did -- and INSTRUMENTS.md already records that the build dir lands
# in DW_AT_producer, one paragraph away from the input-path story.
#
# Measured tonight: it printed "DIFFERENT -- the change is real" for two
# compilers whose entire diff was that one string plus the `.LASF' renumbering
# its length change causes.  A false RED costs what a false green costs; the
# remedy it invites is reverting a correct change.
#
# So the VERDICT is taken after normalising that one path, and the raw md5 is
# kept and printed as informational.  The comparison is over SORTED lines
# because the producer string's length decides where it sorts into the `.LASF'
# table, so a pure textual diff still shows two moved lines when nothing
# differs.
norm () { sed 's|-ftarget-config=[^ "]*|-ftarget-config=<BUILDDIR>|' "$1" \
          | grep -v '^\.LASF[0-9]*:$' | sort; }

# NON-VACUITY.  Folding a path out of the comparison is exactly the kind of
# normalisation that can quietly fold out the signal too, and "the compilers
# agree" and "the comparison can no longer disagree" are the same IDENTICAL
# line.  MT_GCHECK_SELFTEST=1 perturbs one instruction in B's output and the
# script must then report DIFFERENT; run it whenever this normalisation is
# changed, and do not trust an IDENTICAL from a version that has not passed it.
if [ -n "${MT_GCHECK_SELFTEST:-}" ]; then
  echo "-- SELFTEST: injecting one instruction change into B"
  sed -i '0,/^\tret$/s//\tnop\n\tret/' "$W/b.s"
fi
na=$(norm "$W/a.s" | md5sum | cut -c1-12)
nb=$(norm "$W/b.s" | md5sum | cut -c1-12)
echo "  normalised (-ftarget-config= path folded, lines sorted): A=$na B=$nb"

if [ "$na" = "$nb" ]; then
  if [ "$ma" = "$mb" ]; then
    echo "IDENTICAL -- byte-for-byte, and the normalised form agrees."
  else
    echo "IDENTICAL AFTER NORMALISATION -- the raw md5 differs ONLY by the"
    echo "  build-dir path in DW_AT_producer and the .LASF renumbering it causes."
    echo "  This is NOT a codegen change.  Raw diff, for the record:"
    norm "$W/a.s" > "$W/a.norm"; norm "$W/b.s" > "$W/b.norm"
    diff "$W/a.s" "$W/b.s" | head -20
  fi
else
  echo "DIFFERENT -- a real difference survives normalisation; diff follows:"
  norm "$W/a.s" > "$W/a.norm"; norm "$W/b.s" > "$W/b.norm"
  diff "$W/a.norm" "$W/b.norm" | head -40
fi
