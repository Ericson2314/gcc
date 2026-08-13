#!/bin/sh
# #139 -- assert the COUNTING compiler is value-identical to HEAD.
#
# The counting build redefines `UNITS_PER_WORD' to i386's own expression with a
# counter bolted on.  The claim is that this changes no value, only adds a side
# effect.  That claim is worth exactly nothing unasserted: if the redefinition
# had changed the value, every count in the report would be a count taken from
# a different compiler, and nothing else would have noticed.
#
# So: same corpus, same flags, output compared byte for byte against HEAD's.
# usage: t139-count-ident.sh <countbuild> <headbuild> <corpus> <cfg>
set -u
BC=${1:?count build}; BH=${2:?head build}; CORPUS=${3:?corpus}; CFG=${4:?cfg}
D=/tmp/a3ab/identchk; rm -rf $D; mkdir -p $D/c $D/h || exit 9
[ -s "$CFG" ] || { echo "FATAL: no config $CFG"; exit 9; }

n=0; same=0; diffc=0; bad=0
for f in "$CORPUS"/*.i; do
  b=$(basename "$f" .i); n=$((n+1))
  "$BC/gcc/cc1" -quiet -nostdinc -std=gnu17 -O2 -ftarget-config="$CFG" "$f" -o $D/c/$b.s 2> $D/c/$b.err
  "$BH/gcc/cc1" -quiet -nostdinc -std=gnu17 -O2 -ftarget-config="$CFG" "$f" -o $D/h/$b.s 2> $D/h/$b.err
  # The counting build writes its T139COUNT dump to stderr; strip it before
  # anything is compared, and assert it was actually there -- a run with no
  # dump is a run whose counts came from somewhere else.
  grep -q '^T139COUNT' $D/c/$b.err || { echo "FATAL: no counter dump for $b"; exit 9; }
  if [ ! -s $D/c/$b.s ] || [ ! -s $D/h/$b.s ] || [ "$(wc -l < $D/h/$b.s)" -lt 20 ]; then
    echo "  unscorable $b"; bad=$((bad+1)); continue
  fi
  if cmp -s $D/c/$b.s $D/h/$b.s; then same=$((same+1)); else diffc=$((diffc+1)); echo "  DIFFERS $b"; fi
done
echo "counting build vs HEAD: $same identical, $diffc differ, $bad unscorable, of $n TUs"
[ "$diffc" -eq 0 ] || { echo "FATAL: the counting build is not value-identical to HEAD"; exit 1; }
[ "$same" -ge 15 ] || { echo "FATAL: only $same TUs scored"; exit 1; }
