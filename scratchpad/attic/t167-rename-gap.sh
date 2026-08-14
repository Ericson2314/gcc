#!/bin/sh
# #167 -- IS `MULTI_TARGET_RENAME_NAMES' COMPLETE FOR N BASES?
# Copy of t165-rename-gap.sh (itself a copy of t157's) with this worktree's
# build-dir assertion; see those files for the argument.
#
# ONE LINE OF ARM 1's COMMENTARY IS NOW STALE AND IS LEFT STANDING DELIBERATELY.
# It says the sixteen-base `tls_symbolic_operand' collision is a base-vs-SHARED
# case that arm 1 is blind to.  That was true of the tree it was written on and
# the MECHANISM it describes is still exactly right -- but the collision itself
# is gone at anchor 52, because a parallel branch's rename sweep put that name
# in MULTI_TARGET_RENAME_NAMES.  The paragraph is kept because it is the
# clearest worked example of arm 2's reason to exist, and rewriting it to use a
# live example would cost the example.  See gcc/Makefile.in for the dating.  The one substantive addition is the STAMP CHECK:
# this sweep reads objects, and a build that was still running when the objects
# were read is a partial object set, which is a partial collision set -- and a
# SMALLER collision count reads exactly like success (PRINCIPLES 4).
#
# usage: t167-rename-gap.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
case "$B" in
  */b-ae38239f92c500037*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
G="$B/gcc"

# THE STAMP.  Refuse to score objects from a build that has not returned.
[ -f "$B/make-cc1.rc" ] \
  || { echo "REFUSING TO SCORE: $B/make-cc1.rc absent -- the build has not returned"; exit 9; }
echo "arm 0a ok: build stamped rc=$(cat "$B/make-cc1.rc")"

bases=$(ls -d "$G"/mt-* 2>/dev/null | sed 's|.*/mt-||')
nb=$(printf '%s\n' "$bases" | grep -c . || true)
[ "$nb" -ge 2 ] || { echo "REFUSING TO SCORE: found $nb base dirs under $G"; exit 9; }
echo "arm 0b ok: $nb configured bases: $(printf '%s ' $bases)"

# THE OBJECT SET IS WIDENED TO `insn-*-<base>.o' AND `target-*-<base>.o', AND
# THAT WIDENING MOVED THE COLLISION COUNT BY ZERO.  Recorded rather than
# quietly dropped, because the zero refuted the story that motivated it
# (PRINCIPLES 4: "a fix that moves the count by ZERO has refuted your story,
# and that is a result").
#
# The story was: at SIXTEEN bases `ld' reported `multiple definition of
# tls_symbolic_operand(rtx_def*, machine_mode)' and this sweep did not list
# it, so the sweep must be missing the generated objects, which live in the
# build ROOT rather than in mt-<base>/.  Adding them took the per-base symbol
# counts up ~40x (i386 423 -> 16871) and the collision set from 10 to 10.
#
# THE REAL MECHANISM, measured with `nm' on the two objects `ld' named:
#
#     insn-preds.o    T tls_symbolic_operand(rtx_def*, machine_mode)
#     mt-sh/sh.o      T tls_symbolic_operand(rtx_def*, machine_mode)
#
# The per-base generated predicates are in fact namespaced correctly --
# `insn_i386::tls_symbolic_operand', `insn_ia64::tls_symbolic_operand' -- so
# the widening was looking for a defect that is not there.  The other definer
# is `insn-preds.o', the SINGULAR SHARED predicates object, which belongs to
# no base at all.
#
# So the blind spot is real and is NOT the one guessed: this sweep compares
# bases against EACH OTHER, and is blind by construction to a base colliding
# with SHARED code.  Arm 2 below is the arm that can see it.  The widening is
# kept because target-*-<base>.o really are per-base and really were outside
# the old set, but it is kept on completeness grounds, not on evidence -- it
# has never yet caught anything.
#
# And the header note inherited from t157 -- "the sweep is the authority; the
# linker is an UNDER-count of it" -- is therefore only half true. The two
# instruments have COMPLEMENTARY blind spots:
#
#   * the linker misses a collision between two archive members that nothing
#     happens to pull in (the twenty aarch_*/arm_* names of #157);
#   * a base-vs-base sweep misses a base colliding with shared code.
#
# Neither alone is complete.  Run both and reconcile by NAME; a count that
# agrees is not a set that agrees.
tot=0
for b in $bases; do
  sh "$S/eb-shell.sh" "cd $G && nm -C --defined-only mt-$b/*.o insn-*-$b.o insn-*-$b-*.o target-*-$b.o 2>/dev/null" \
    | awk '$2 ~ /^[TDBR]$/ { $1=""; $2=""; sub(/^  /,""); print }' \
    | sort -u > "$B/t167-syms-$b.txt"
  n=$(grep -c . "$B/t167-syms-$b.txt" || true)
  echo "  $b: $n global definitions"
  tot=$((tot + n))
done
[ "$tot" -gt 0 ] || { echo "REFUSING TO SCORE: nm read nothing (not in the shell?)"; exit 9; }

echo
echo "== names defined by MORE THAN ONE base (the collision set)"
cat "$B"/t167-syms-*.txt | sort | uniq -d > "$B/t167-collisions.txt"
nc=$(grep -c . "$B/t167-collisions.txt" || true)
echo "  $nc colliding names over $nb bases"
sed 's/^/    /' "$B/t167-collisions.txt"
echo
np=$(grep -c '^mt_probe_' "$B/t167-collisions.txt" || true)
echo "  of which $np are the deliberate MULTI_TARGET_REG_PROBES (mt_probe_*,"
echo "  compiled and never linked, so benign); REAL = $((nc - np))"
echo
echo "== ARM 2: names a base defines that SHARED code also defines"
# The blind spot arm.  A base-vs-base sweep cannot see `mt-sh/sh.o' colliding
# with `insn-preds.o', because insn-preds.o belongs to no base -- and that is a
# real link failure at sixteen bases.  The shared set is every .o in the build
# root that is NOT one of the per-base objects.
sh "$S/eb-shell.sh" "cd $G && nm -C --defined-only insn-preds.o insn-attrtab.o insn-emit.o insn-recog.o insn-opinit.o insn-output.o insn-extract.o insn-peep.o insn-modes.o insn-enums.o insn-automata.o insn-dfatab.o insn-latencytab.o 2>/dev/null" \
  | awk '$2 ~ /^[TDBR]$/ { $1=""; $2=""; sub(/^  /,""); print }' \
  | sort -u > "$B/t167-syms-SHARED.txt"
nsh=$(grep -c . "$B/t167-syms-SHARED.txt" || true)
if [ "$nsh" = 0 ]; then
  # Not fatal: which singular objects exist depends on the base count.  But say
  # so BY NAME, because an empty shared set makes arm 2 vacuously green and
  # that is indistinguishable from "no collisions" (PRINCIPLES 7).
  echo "  ARM 2 VACUOUS: no shared generated objects read; this arm proved NOTHING"
else
  echo "  shared generated objects: $nsh global definitions"
  cat "$B"/t167-syms-*.txt > "$B/t167-allbase.tmp"
  # A name is a base-vs-shared collision if it is in the shared set AND in some
  # base's set.  Exclude the SHARED file itself from the base side.
  for b in $bases; do cat "$B/t167-syms-$b.txt"; done | sort -u > "$B/t167-allbase.txt"
  comm -12 "$B/t167-syms-SHARED.txt" "$B/t167-allbase.txt" > "$B/t167-shared-collisions.txt"
  n2=$(grep -c . "$B/t167-shared-collisions.txt" || true)
  echo "  $n2 names defined by BOTH a base and shared generated code"
  sed 's/^/    /' "$B/t167-shared-collisions.txt"
fi
echo
echo "NOTE: ld reports only the subset whose archive members are both pulled"
echo "in, so it UNDER-counts arm 1.  Arm 1 compares bases against each other,"
echo "so it cannot see arm 2's population at all.  Use both."
