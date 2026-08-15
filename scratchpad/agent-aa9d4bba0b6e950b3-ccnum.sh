#!/bin/sh
# agent-aa9d4bba0b6e950b3-ccnum.sh -- LEAK or NUMBERING COLLISION?
#
# The ICE cannot tell those apart and they want different fixes, so this is the
# arm that separates them.
#
#   NUMBERING COLLISION would mean `CCZmode' is one number in a shared
#   translation unit and a different number in `config/s390/'.  The fix would
#   be in genmodes / the mode union.
#
#   LEAK would mean the numbering AGREES everywhere and shared code simply
#   called the wrong back end's selection function, so the number it produced
#   is a mode that genuinely belongs to another back end.  The fix is a
#   per-base redirect.
#
# So: extract every CC-class mode enumerator and its VALUE from the shared
# `insn-modes.h' and from each per-base one, and compare.
#
# NON-VACUITY, and it is not decoration here: "no disagreements" is exactly
# what a broken extractor prints.  The script therefore asserts it found a
# minimum number of CC enumerators in each file before it is allowed to report
# agreement, and it prints the counts it compared.
#
# usage: agent-aa9d4bba0b6e950b3-ccnum.sh <builddir>
set -eu
# `sort' and `join' MUST agree on collation.  Without this, `sort' used the
# locale's rules (where `CC_Fmode' sorts among the `CCF*' names) while `join'
# assumed byte order, and `join' printed `input is not in sorted order' and
# SILENTLY DROPPED matching lines -- an undercount, in the direction that makes
# the leak look smaller.  A warning on stderr beside a plausible number is
# exactly the shape PRINCIPLES says never to wave through.
export LC_ALL=C
D=${1:?build dir}
G=$D/gcc
TD=$(mktemp -d); trap 'rm -rf "$TD"' 0

# THE ENUMERATORS CARRY NO `= N'.  genmodes emits a bare `E_CCZmode,' list, so
# the mode NUMBER is the ordinal position in the enum -- which is exactly the
# number the compiler uses.  The first version of this script matched
# `E_<name>mode = <n>,' and found ZERO, and that is why the non-vacuity floor
# below is not decoration: without it this script would have printed "0
# disagreements" from an extractor that read nothing, i.e. the answer that
# says "no collision" arrived from an instrument that could not have found one.
extract () {
  awk '/^[[:space:]]*E_[A-Za-z0-9_]*mode,/ {
         name = $1; sub(/^E_/, "", name); sub(/,$/, "", name);
         print name, n++;
       }' "$1" \
  | grep '^CC' | sort
}

# Which back end's modes file each mode came from -- genmodes writes the origin
# in a trailing comment, so the union can be attributed without guessing.
origins () {
  awk '/^[[:space:]]*E_[A-Za-z0-9_]*mode,/ {
         name = $1; sub(/^E_/, "", name); sub(/,$/, "", name);
         o = "<none>";
         if (match($0, /\/\* [^ ]+ \*\//)) { o = substr($0, RSTART+3, RLENGTH-6); }
         print name, o;
       }' "$1" | grep '^CC' | sort
}

[ -f "$G/insn-modes.h" ] || { echo "FATAL: no $G/insn-modes.h" >&2; exit 9; }
extract "$G/insn-modes.h" > "$TD/shared"
ns=$(wc -l < "$TD/shared")
# A file with no CC enumerators means the extractor is wrong, not that the
# compiler has no CC modes.
[ "$ns" -ge 10 ] || { echo "FATAL: only $ns CC enumerators in the shared header -- extractor broken, refusing to score" >&2; exit 9; }
echo "shared insn-modes.h: $ns CC-mode enumerators"
echo

for b in i386 s390 aarch64 riscv rs6000; do
  f=$G/insn-modes-$b.h
  [ -f "$f" ] || { echo "$b: ABSENT ($f)"; continue; }
  extract "$f" > "$TD/$b"
  nb=$(wc -l < "$TD/$b")
  [ "$nb" -ge 10 ] || { echo "$b: only $nb CC enumerators -- refusing to score"; continue; }
  d=$(join "$TD/shared" "$TD/$b" | awk '$2 != $3 { print }' | wc -l)
  c=$(join "$TD/shared" "$TD/$b" | wc -l)
  echo "$b: $nb CC enumerators; $c share a name with the shared header; $d DISAGREE on the value"
  [ "$d" = 0 ] || join "$TD/shared" "$TD/$b" | awk '$2 != $3 { printf "    %s shared=%s %s=%s\n", $1, $2, "'"$b"'", $3 }'
done

echo
echo "-- where the union's CC modes COME FROM (genmodes records the origin):"
origins "$G/insn-modes.h" | awk '{print $2}' | sort | uniq -c | sort -rn

echo
echo "-- the CC modes i386 CONTRIBUTES, i.e. what ix86_cc_mode can return:"
origins "$G/insn-modes.h" | awk '$2 ~ /i386/ {print $1}' | sort > "$TD/i386own"
join "$TD/i386own" "$TD/shared" | awk '{printf "%s(%s) ", $1, $2}' | fold -s -w 74
echo
# THE ARM THAT WAS VACUOUS, RECORDED RATHER THAN QUIETLY REPLACED.
#
# The obvious question is "which CC modes does s390 not have", and asking
# `insn-modes-s390.h' answers it 0 BY CONSTRUCTION: the mode VOCABULARY is
# unioned, so every base's header declares all 110 CC modes and the set
# difference against i386's contribution is necessarily empty.  It printed
# `count: 0', which reads as "nothing can leak" -- the exact opposite of the
# truth, from a comparison that could not have said anything else.
#
# The set that actually matters is not a property of a header at all.  It is
# the list of `case E_CC...mode:' labels in `s390_match_ccmode_set' itself: the
# modes that function is willing to see.  Everything else reaches its
# `default: gcc_unreachable ()'.  Read from the source, which is the authority.
SRCDIR=$(cat "$D/MY-SRC")
S390CC=$SRCDIR/gcc/config/s390/s390.cc
[ -f "$S390CC" ] || { echo "FATAL: no $S390CC" >&2; exit 9; }

# the switch body of s390_match_ccmode_set, between the function and its
# `default:' arm
awk '/^s390_match_ccmode_set/,/gcc_unreachable/' "$S390CC" \
  | sed -n 's/^[[:space:]]*case E_\([A-Za-z0-9_]*mode\):.*$/\1/p' | sort -u > "$TD/accepts"
na=$(wc -l < "$TD/accepts")
[ "$na" -ge 5 ] || { echo "FATAL: only $na case labels found in s390_match_ccmode_set -- extractor broken" >&2; exit 9; }

echo
echo "-- the CC modes s390_match_ccmode_set ACCEPTS ($na 'case' labels in s390.cc):"
join "$TD/accepts" "$TD/shared" | awk '{printf "%s(%s) ", $1, $2}' | fold -s -w 74
echo
echo
echo "-- i386-contributed CC modes with NO case label there.  ix86_cc_mode"
echo "   returning any of these reaches 'default: gcc_unreachable ()':"
comm -23 "$TD/i386own" "$TD/accepts" > "$TD/leakable"
join "$TD/leakable" "$TD/shared" | awk '{printf "%s(%s) ", $1, $2}' | fold -s -w 74
echo
echo "   count: $(wc -l < "$TD/leakable") of $(wc -l < "$TD/i386own") modes i386 can return"
