#!/bin/sh
# agent-a018835bbcfad2e28-bothsided.sh -- did a change move a target TOWARD its
# own stock compiler, away from it, or not at all?
#
# WHY THIS AND NOT JUST "x86_64 IS BYTE-IDENTICAL".  The auto-inc change
# ENABLES auto-increment addressing for the 25 back ends that have it, so
# aarch64, arm, rs6000 and s390x are EXPECTED to move.  "unmoved" is the right
# acceptance test only for a target the change cannot reach; for one it does
# reach, the question is direction, and a one-sided before/after diff cannot
# answer it -- it says the output changed, not that it got better.
#
# So three compilers, not two: BEFORE, AFTER and that target's own STOCK.
# The verdict is a comparison of two distances:
#
#   TOWARD   after == stock, before != stock        (the change closed the gap)
#   AWAY     before == stock, after != stock        (the change opened one)
#   UNMOVED  before == after                        (the change did not reach it)
#   BOTH-DIFFER  neither matches stock, and they differ from each other
#
# BOTH-DIFFER is reported as its own verdict and NOT folded into TOWARD.  It is
# the honest answer for a target where some third difference dominates, and
# calling it an improvement because "it changed" is the reasoning this project
# keeps deleting.
#
# usage: BEFORE=<bd> AFTER=<bd> STOCK=<bd> bothsided.sh <triple> <file> [flags...]
set -u
O=${O:-/tmp/w-a018835bbcfad2e28}/bs
BEFORE=${BEFORE:?before build dir}
AFTER=${AFTER:?after build dir}
STOCK=${STOCK:?stock build dir}
T=${1:?triple}; shift
F=${1:?source file}; shift
# THE TRIPLE IS IN THE ARTEFACT NAME, and it was not on the first version of
# this script.  Running it for four targets in a row left one set of `.s'
# files, each overwritten by the next triple, and a diff of the survivors is
# empty -- which reads as "the change did nothing" rather than as "you are
# looking at another target's output".  Same shape INSTRUMENTS.md records for
# mtcheck.sh's gcc.sum, found here by the diff coming back empty when the md5s
# had just said it could not be.
N=$(basename "$F" .c).$T
mkdir -p "$O"

cfg () {
  d=$1
  v=$(basename "$(ls -d "$d"/lib/gcc/*/ 2>/dev/null | head -1)")
  echo "$d/lib/gcc/$v/$T/specs-config"
}

FLAGS="$*"
for pair in "before $BEFORE" "after $AFTER" "stock $STOCK"; do
  n=${pair%% *}; d=${pair#* }; c=$(cfg "$d")
  set -- $FLAGS
  # `$@' IN BOTH ARMS.  The first version of this omitted it from the `else'
  # branch, so the STOCK compiler -- which is single-target and has no
  # specs-config, and therefore always took that branch -- was invoked with no
  # `-O2'.  It produced clean, plausible, well-formed -O0 assembly, the script
  # printed BOTH-DIFFER and UNMOVED verdicts from it, and nothing looked wrong
  # until a diff showed stock spilling every variable to the stack.  A control
  # compiled with different flags from the arms it controls is not a control.
  if [ -f "$c" ]; then
    "$d/gcc/xgcc" -B"$d/gcc/" -ftarget-config="$c" -S "$@" -o "$O/$N.$n.s" "$F" \
      > "$O/$N.$n.err" 2>&1 || true
  else
    "$d/gcc/xgcc" -B"$d/gcc/" -S "$@" -o "$O/$N.$n.s" "$F" \
      > "$O/$N.$n.err" 2>&1 || true
  fi
done

for n in before after stock; do
  f=$O/$N.$n.s
  if [ ! -s "$f" ]; then
    echo "FATAL[$T $N]: $n produced no assembly -- refusing to compare"
    sed -n '1,6p' "$O/$N.$n.err"; exit 9
  fi
done

# Strip the .file line: it carries the source path, which differs by build dir
# and is the recorded reason the aarch64 -S bar was filename-sensitive.
norm () { grep -v '^\s*\.file' "$1"; }
bs=$(norm "$O/$N.before.s" | md5sum | cut -c1-12)
as=$(norm "$O/$N.after.s"  | md5sum | cut -c1-12)
st=$(norm "$O/$N.stock.s"  | md5sum | cut -c1-12)

if   [ "$bs" = "$as" ];                      then v=UNMOVED
elif [ "$as" = "$st" ];                      then v=TOWARD
elif [ "$bs" = "$st" ];                      then v=AWAY
else                                              v=BOTH-DIFFER
fi
printf '%-24s %-14s before %s  after %s  stock %s\n' "$T" "$v" "$bs" "$as" "$st"
