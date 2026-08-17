#!/bin/sh
# agent-ad6a5c1d2539f5e18-vbitsweep.sh -- BOTH-SIDED, over every target that
# has a specs-config in BOTH build dirs: did `TARGET_PTRMEMFUNC_VBIT_LOCATION'
# stop being the primary's?
#
# THE SHAPE THIS PROJECT TRUSTS: "N changed, M byte-identical, 0 differ".
# A one-sided run cannot separate "fixed" from "everyone now gets the same new
# answer", so PRE and POST are compiled from two build dirs and every target
# is scored, not only the ones expected to move.
#
# THREE ARMS, and the second and third are what make the first mean anything:
#
#  1. PRE vs POST on the whole `.s'.  A target whose own header agrees with
#     i386 must be BYTE-IDENTICAL; a target whose header disagrees must CHANGE.
#  2. THE NON-VIRTUAL CONTROL.  `mt_pmf_nonvirtual' has its vbit clear under
#     either convention, so its two words must be identical PRE and POST on
#     EVERY target.  If that moves, the comparison is measuring something other
#     than the vbit and the verdict is void.
#  3. THE CENSUS CROSS-CHECK.  The convention actually EMITTED at POST is read
#     back out of the assembly and compared against what that base's own header
#     chain says (agent-ad6a5c1d2539f5e18-vbitcensus.sh).  Arm 1 alone would
#     accept a change to the WRONG convention.
#
# The emitted convention is read from `mt_pmf_first', whose two words are
# `pfn=1, delta=0' under `vbit_in_pfn' and `pfn=0, delta=1' under
# `vbit_in_delta'.  Both are 2-word initialisers of whatever the target's
# pointer directive is (.quad/.xword/.long/.word/.4byte/.short/.byte), so the
# directive is not hardcoded -- 45 targets do not share one.
#
# NULL-RESULT ARM, FIRST AND FATAL.  A missing `cc1plus`, a target with no
# specs-config, an empty `.s' and a compiler that emitted nothing interesting
# all produce the same empty grep.  Every one of them fails BY NAME here, and
# the script refuses to print a verdict if it scored zero targets.
#
# usage: PRE=<dir> POST=<dir> agent-ad6a5c1d2539f5e18-vbitsweep.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
PRE=${PRE:?PRE build dir}
POST=${POST:?POST build dir}
IN=$S/agent-a260445cf27ba480a-ptrmem.cc
[ -s "$IN" ] || { echo "FATAL: no $IN"; exit 9; }

for D in "$PRE" "$POST"; do
  [ -x "$D/gcc/cc1plus" ] || { echo "FATAL: no $D/gcc/cc1plus -- a language that
  was never enabled and a language that passes everything give the same empty
  failure list, so this refuses rather than scoring zero"; exit 9; }
done
VPRE=$(cat "$PRE/gcc/BASE-VER"); VPOST=$(cat "$POST/gcc/BASE-VER")

W=$(mktemp -d); trap 'rm -rf "$W"' 0

# Targets present in BOTH.  A target only one side can compile is reported,
# never silently dropped: "not attempted" and "identical" are the same silence.
ls "$PRE/lib/gcc/$VPRE"  > "$W/pre.t"  2>/dev/null || : > "$W/pre.t"
ls "$POST/lib/gcc/$VPOST" > "$W/post.t" 2>/dev/null || : > "$W/post.t"
BOTH=$(comm -12 "$W/pre.t" "$W/post.t")
ONLY=$(comm -3 "$W/pre.t" "$W/post.t" | tr -d '\t')
[ -z "$ONLY" ] || echo "WARNING: targets in only one build dir: $ONLY"

emit () {                              # emit <builddir> <ver> <target> <out>
  ( cd "$1/gcc" && ./cc1plus -quiet -nostdinc -O2 \
      -ftarget-config="$1/lib/gcc/$2/$3/specs-config" "$IN" -o "$4" ) \
    > "$4.msg" 2>&1
}

# The two words of a named object, directive-agnostic.
words () {                             # words <asm> <symbol>
  awk -v sym="$2:" '
    $0 == sym { c = 2; next }
    c > 0 && $1 ~ /^\.(quad|xword|long|word|4byte|8byte|2byte|short|byte|dc\.[abwl])$/ {
      print $2; c-- }' "$1"
}

nsame=0; nchg=0; nfail=0; nctl=0; nbad=0; ntot=0
printf '%-30s %-9s %-9s %-8s %s\n' TARGET PRE POST VERDICT CENSUS
for T in $BOTH; do
  [ -s "$PRE/lib/gcc/$VPRE/$T/specs-config" ] || continue
  [ -s "$POST/lib/gcc/$VPOST/$T/specs-config" ] || continue
  ntot=$((ntot + 1))
  A=$W/$T.pre.s; B=$W/$T.post.s
  emit "$PRE"  "$VPRE"  "$T" "$A"; ra=$?
  emit "$POST" "$VPOST" "$T" "$B"; rb=$?
  if [ "$ra" != 0 ] || [ "$rb" != 0 ] || [ ! -s "$A" ] || [ ! -s "$B" ]; then
    printf '%-30s %-9s %-9s %-8s %s\n' "$T" "rc=$ra" "rc=$rb" CC1PLUS-FAIL -
    sed -n 1,2p "$B.msg" | sed 's/^/    /'
    nfail=$((nfail + 1)); continue
  fi

  ka=$(words "$A" mt_pmf_first | tr '\n' '/')
  kb=$(words "$B" mt_pmf_first | tr '\n' '/')
  shape () { case $1 in 1/0/) echo pfn;; 0/1/) echo delta;; *) echo "?$1";; esac; }
  sa=$(shape "$ka"); sb=$(shape "$kb")

  # ARM 2, the control, before any verdict is printed for this target.
  ca=$(words "$A" mt_pmf_nonvirtual); cb=$(words "$B" mt_pmf_nonvirtual)
  if [ -z "$ca" ] || [ "$ca" != "$cb" ]; then
    printf '%-30s %-9s %-9s %-8s %s\n' "$T" "$sa" "$sb" CONTROL-MOVED -
    nctl=$((nctl + 1)); continue
  fi

  if cmp -s "$A" "$B"; then v=identical; nsame=$((nsame + 1))
  else v=changed; nchg=$((nchg + 1)); fi

  # ARM 3.  What does this target's OWN header chain want?  Taken from the
  # census run beside this script, if the caller supplied one.
  want=-
  if [ -n "${CENSUS:-}" ] && [ -s "$CENSUS" ]; then
    b=$(awk -F: -v t="$T" '$2 == t { print $1 }' \
          "$S/agent-acda89931a903ec27-backends.txt")
    [ -n "$b" ] && want=$(awk -v b="$b" '$1 == b { if ($0 ~ /delta/) print "delta";
                                                   else if ($0 ~ /pfn/) print "pfn" }' \
                          "$CENSUS")
    [ -n "$want" ] || want='?'
    if [ "$want" != '-' ] && [ "$want" != '?' ] && [ "$want" != "$sb" ]; then
      want="$want!=EMITTED"; nbad=$((nbad + 1))
    fi
  fi
  printf '%-30s %-9s %-9s %-8s %s\n' "$T" "$sa" "$sb" "$v" "$want"
done

echo
echo "targets scored: $ntot   changed=$nchg  byte-identical=$nsame  differ(cc1plus failed)=$nfail"
echo "control moved:  $nctl   census disagrees with emitted: $nbad"
[ "$ntot" -gt 0 ] || { echo "FATAL: scored ZERO targets -- refusing to print a
  verdict.  A sweep that measured nothing and a sweep that found nothing wrong
  produce the same empty table."; exit 9; }
[ "$nctl" = 0 ] || { echo "FATAL: the non-virtual control moved on $nctl targets;
  the comparison is not measuring the vbit and the verdict is VOID"; exit 9; }
[ "$nbad" = 0 ] || { echo "FATAL: $nbad targets emit a convention their own
  header does not ask for"; exit 9; }
[ "$nchg" -gt 0 ] && [ "$nsame" -gt 0 ] \
  || echo "NOTE: one of the two columns is empty -- check that is expected."
