#!/bin/bash
# bash, not sh: the comparison uses process substitution.
# a76a331dcb554f700 -- BOTH-SIDED: every target, every corpus input, two build
# dirs, and the answer is "N changed, M byte-identical, K differ".
#
# WHAT MAKES THIS NON-VACUOUS.  A run where NOTHING assembles and a run where
# everything is identical both print "0 differ".  So it refuses unless it saw
# a minimum number of comparable pairs, AND it reports the three populations
# separately: pairs where both sides produced a `.s' (comparable), pairs where
# only one did (that is the MOVEMENT -- a target that used to ICE), and pairs
# where neither did.
#
# The `.s' files are compared after stripping the two lines that carry a PATH
# (`.file' and any `-ftarget-config=' echoed into a comment), because the two
# build dirs have different names and INSTRUMENTS.md records that costing a
# false RED twice.
set -u
A=${A:?PRE build dir}
Bd=${B:?POST build dir}
OPT=${OPT:--O2}
C=/tmp/bs-a76a331dcb554f700
rm -rf $C; mkdir -p $C/a $C/b
VERA=$(cat "$(cat "$A/MY-SRC")/gcc/BASE-VER")
VERB=$(cat "$(cat "$Bd/MY-SRC")/gcc/BASE-VER")
SRC=/tmp/corpus-a76a331dcb554f700
ls $SRC/*.c > /dev/null 2>&1 || { echo "FATAL: run -corpus.sh first ($SRC)"; exit 9; }

norm () { sed -e '/\.file/d' -e '/target-config/d' "$1"; }

same=0; diff_=0; onlyA=0; onlyB=0; neither=0; comparable=0
movers=""; differs=""
for d in "$Bd"/lib/gcc/"$VERB"/*/; do
  T=$(basename "$d")
  # amdgcn/nvptx have no probed specs-config; excluded BY NAME from this arm
  # because their configs are synthesised and their flags differ.
  case "$T" in amdgcn*|nvptx*) continue ;; esac
  CA="$A/lib/gcc/$VERA/$T/specs-config"
  CB="$Bd/lib/gcc/$VERB/$T/specs-config"
  [ -f "$CA" ] && [ -f "$CB" ] || continue
  for f in $SRC/*.c; do
    n=$(basename "$f" .c)
    ra=1; rb=1
    "$A/gcc/xgcc" -B"$A/gcc/" -ftarget-config="$CA" $OPT -S -o "$C/a/$T-$n.s" "$f" \
      >/dev/null 2>&1 && ra=0
    "$Bd/gcc/xgcc" -B"$Bd/gcc/" -ftarget-config="$CB" $OPT -S -o "$C/b/$T-$n.s" "$f" \
      >/dev/null 2>&1 && rb=0
    if [ $ra = 0 ] && [ $rb = 0 ]; then
      comparable=$((comparable+1))
      if norm "$C/a/$T-$n.s" | cmp -s - <(norm "$C/b/$T-$n.s"); then
        same=$((same+1))
      else
        diff_=$((diff_+1)); differs="$differs $T/$n"
      fi
    elif [ $ra != 0 ] && [ $rb = 0 ]; then
      onlyB=$((onlyB+1)); movers="$movers $T/$n"
    elif [ $ra = 0 ] && [ $rb != 0 ]; then
      onlyA=$((onlyA+1)); differs="$differs REGRESSED:$T/$n"
    else
      neither=$((neither+1))
    fi
  done
done
echo
echo "PRE  = $A"
echo "POST = $Bd"
echo "level=$OPT"
echo "comparable pairs (both compiled): $comparable"
echo "  byte-identical after path normalisation: $same"
echo "  DIFFER:                                 $diff_"
echo "NEW in POST (PRE failed, POST compiled):  $onlyB"
echo "LOST in POST (PRE compiled, POST failed): $onlyA   <- must be 0"
echo "neither side compiled:                    $neither"
[ -z "$movers" ] || { echo; echo "moved:"; for m in $movers; do echo "  + $m"; done; }
[ -z "$differs" ] || { echo; echo "differ / regressed:"; for m in $differs; do echo "  ! $m"; done; }
echo
[ "$comparable" -ge 100 ] || { echo "FATAL: only $comparable comparable pairs; a small population makes '0 differ' meaningless"; exit 9; }
[ "$onlyA" = 0 ] || exit 9
