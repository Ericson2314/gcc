#!/bin/sh
# #169 step 1 -- dump each back end's REAL target-macro set, one file per base.
#
# METHOD, and why it is not a directory grep.  PRINCIPLES section 4 records
# `mta7-targhook-matrix.sh' scoring 66 of 87 "silent" pairs wrong because it
# asked "does gcc/config/<be>/ contain a #define?"  `elfos.h', `tm-dwarf2.h',
# `darwin.h' and `vx-common.h' all sit ABOVE the back-end directory and are in
# nearly every target's chain.  So this asks the compiler: `cpp -dM' over the
# generated `tm-<base>.h', which IS the chain cc1 reads for that base.
#
# TWO SUBTRACTIONS, both necessary:
#
#  - A NEUTRAL BASELINE.  `cpp -dM' also dumps the host compiler's own ~400
#    builtins (`__GNUC__', `__x86_64__', ...).  Those are identical for all 48
#    bases, so leaving them in would put ~400 macros in the "defined by 48/48
#    back ends" bucket and drown the signal.  `neutral.m' is the same command
#    with no `-imacros', and every base's set is the difference.
#
#  - `-x c++'.  PRINCIPLES: `multi-target-macros.h:164' guards this branch's
#    redirects on `|| !defined (__cplusplus)', so preprocessing as C switches
#    EVERY redirect off and an agent concluded `Pmode' was unconverted that
#    way.  cc1 is compiled as C++; the dump must be too.
#
# usage: t169-dump.sh <builddir/gcc> <outdir>
set -u
D=${1:?build dir (the gcc/ one)}
O=${2:?output dir}
WANT=${WANT_ANCHOR:-50}

[ -d "$D" ] || { echo "FATAL: $D missing"; exit 9; }
# THE SRCDIR COMES FROM THE BUILD DIR'S OWN TESTIMONY, not from $0's location.
# Deriving it from $(dirname $0)/.. put the LIVE WORKTREE's gcc/defaults.h on
# the include path of a dump of an IMMUTABLE SNAPSHOT's build dir -- two trees
# in one measurement, and the only reason it was caught is that the worktree
# had not generated multi-target-reg-widths.h.  Had both trees been complete it
# would have produced a plausible dump of neither.
SRC=$(cat "$D/MY-SRC" 2>/dev/null)
[ -n "$SRC" ] && [ -d "$SRC/gcc" ] || { echo "FATAL: $D/MY-SRC does not name a srcdir"; exit 9; }
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
echo "measuring build dir $D against srcdir $SRC (anchor $n)"

mkdir -p "$O"
: > "$O/bases"
echo > "$O/empty.c"

CPP="cpp -x c++ -dM -I$D -I$SRC/gcc -I$SRC/gcc/config -I$SRC/include -I$D/include -DIN_GCC"

$CPP "$O/empty.c" > "$O/neutral.m" 2> "$O/neutral.err"
NEU=$(grep -c '^#define' "$O/neutral.m" || echo 0)
[ "$NEU" -gt 100 ] || { echo "FATAL: neutral baseline has $NEU macros -- cpp is not running"; exit 9; }
sed -n 's/^#define \([A-Za-z_][A-Za-z_0-9]*\).*/\1/p' "$O/neutral.m" | sort -u > "$O/neutral.names"

# THE BASES ARE THE 48 cpu_type KEYS, NOT EVERY tm-*.h.  The build dir also
# holds a tm-<triple>.h per configured TARGET (334 files here) plus
# tm-preds.h/tm-constrs.h.  Counting those as "back ends" would inflate every
# definer count by the triples of whichever cpus happen to be configured.  The
# authority for the 48 is multi-target-common.mk, which configure wrote.
[ -f "$D/multi-target-common.mk" ] || { echo "FATAL: no multi-target-common.mk in $D"; exit 9; }
BASES=$(grep -o '^tm-[a-z0-9_]*[.]h' "$D/multi-target-common.mk" \
        | sed 's/^tm-//; s/[.]h$//' | sort -u)
NB=$(echo "$BASES" | grep -c .)
echo "bases from multi-target-common.mk: $NB"
[ "$NB" -ge 40 ] || { echo "FATAL: only $NB bases named"; exit 9; }

NOK=0; NBAD=0
for b in $BASES; do
  f="$D/tm-$b.h"
  [ -f "$f" ] || { echo "FATAL: $f missing"; exit 9; }
  $CPP -imacros "$f" "$O/empty.c" > "$O/$b.raw" 2> "$O/$b.err"
  # name<TAB>value, target-chain macros only.
  sed -n 's/^#define \([A-Za-z_][A-Za-z_0-9]*\)(\(.*\)$/\1\t(\2/p; s/^#define \([A-Za-z_][A-Za-z_0-9]*\) \(.*\)$/\1\t\2/p; s/^#define \([A-Za-z_][A-Za-z_0-9]*\)$/\1\t/p' \
      "$O/$b.raw" | sort -u > "$O/$b.all"
  awk -v N="$O/neutral.names" 'BEGIN{while((getline l<N)>0)s[l]=1}
       {split($0,a,"\t"); if(!(a[1] in s)) print}' "$O/$b.all" > "$O/$b.m"
  c=$(grep -c . "$O/$b.m" || true)
  [ -n "$c" ] || c=0
  if [ "$c" -gt 50 ]; then
    NOK=$((NOK+1)); echo "$b" >> "$O/bases"
  else
    NBAD=$((NBAD+1)); echo "UNREADABLE $b ($c target macros); first stderr:"; head -2 "$O/$b.err"
  fi
done

# NON-VACUITY, FIRST.  An all-empty read is indistinguishable from "no back end
# defines anything", which is the reading that scores every guard clean.
echo "non-vacuity: $NOK bases dumped, $NBAD unreadable; neutral baseline $NEU macros"
[ "$NOK" -ge 40 ] || { echo "FATAL: only $NOK bases dumped"; exit 9; }
[ "$NBAD" = 0 ] || { echo "FATAL: $NBAD bases unreadable -- a missing base reads as 'does not define', the wrong direction"; exit 9; }
# Positive control: a macro every ELF target gets from elfos.h, ABOVE the back
# end dir, and one only sparc defines.  Both must read as expected or the
# instrument is measuring the wrong thing.
g=$(grep -lc '^DWARF2_DEBUGGING_INFO	' "$O"/*.m 2>/dev/null | wc -l)
s=$(grep -l '^LEAF_REGISTERS	' "$O"/*.m 2>/dev/null | wc -l)
echo "control: DWARF2_DEBUGGING_INFO in $g bases (elfos.h, above the be dir); LEAF_REGISTERS in $s"
[ "$g" -gt 20 ] || { echo "FATAL: elfos.h control failed -- chain not being read"; exit 9; }
[ "$s" -ge 1 ] || { echo "FATAL: LEAF_REGISTERS control failed"; exit 9; }
echo OK
