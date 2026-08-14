#!/bin/sh
# mt-cobjs-order.sh -- IS THE GENERATED MAKE TEXT A FUNCTION OF THE BACK END
# SET, OR OF THE ORDER THE RECORDS APPEAR IN?
#
# WHY THE ARM PERMUTES THE MANIFEST AND NOT THE COMMAND LINE.  The brief for
# this task said `MT_C_OBJS_<cpu>' "depends on the order back ends were named
# on the command line".  MEASURED, that is FALSE for the supported path:
# configure.ac:236 sorts and deduplicates `--enable-targets' before deriving
# `--enable-backends', with a comment saying why -- "Sorting is not tidiness:
# it is the enforcement mechanism for no primary.  The build must be identical
# for any permutation of the input".  Two build dirs configured with the two
# ia64 triples in opposite command-line orders produce BYTE-IDENTICAL
# manifests.
#
# So the command line cannot express the defect, and the invariant the top
# level ASSERTS by sorting is exactly the one this script tests directly:
# permute the manifest records and require the generated make text to be
# identical.  That is a stronger arm than the command-line one would have
# been, and it is the one the sort comment asks for.
#
# THE DEFECT IT LOOKS FOR.  `c_target_objs' is set by TRIPLE, not by back end:
# only `ia64*-*-hpux*' names `ia64-c.o'; `ia64-elf' names none.
# gen-multi-target-md.awk reads it on the FIRST record for a cpu_type, so
# which of a back end's triples comes first decides whether its C-family
# object is built at all.  One name, several authorities, no diagnostic.
#
# NON-VACUITY, AND IT IS NOT DECORATION -- THE FIRST VERSION OF THIS SCRIPT
# SCORED A FALSE "IDENTICAL" BECAUSE OF IT.  It ran the generator without
# `-v srcdir=', which gcc/Makefile.in:1497 passes.  `frag_source_for' then
# opened `/config/ia64/t-ia64', found nothing, and EVERY back end's
# `<cpu>-c.o' vanished from both sides -- so the two runs agreed, on a
# generator that had done none of the work under test.  The arm below requires
# a known-good rule to be present before any comparison is scored.
#
# usage: mt-cobjs-order.sh <builddir>
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

D=${1:?build dir}
mt_assert_builddir "$D"
SRC=$(mt_src_of "$D") || exit 9
G=$D/gcc
M=$G/multi-target.manifest
[ -s "$M" ] || mt_die "$M absent or empty -- run 'make configure-gcc' first"
[ -s "$G/multi-target.multilib" ] || mt_die "$G/multi-target.multilib absent"

n=$(grep -c '^cpu_type ia64$' "$M")
[ "$n" = 2 ] || mt_die "$M names $n ia64 records, expected 2 -- the arm cannot fire.
  Configure with two ia64 triples, e.g. ia64-elf,ia64-hp-hpux11.23"

O=$D/cobjs-order; mkdir -p "$O"

# The permutation: reverse the order of the two ia64 records, everything else
# untouched.  Records are blank-line separated.
awk 'BEGIN { RS = ""; FS = "\n" }
     {
       cpu = "";
       for (i = 1; i <= NF; i++) if ($i ~ /^cpu_type /) { cpu = substr($i, 10) }
       if (cpu == "ia64") { ia[++nia] = $0 } else { other[++no] = $0 }
       order[NR] = (cpu == "ia64") ? "ia64" : "other";
     }
     END {
       j = 0; k = 0;
       for (r = 1; r <= NR; r++) {
	 if (order[r] == "ia64") { print ia[nia - j]; j++ } else { print other[++k] }
	 print "";
       }
     }' "$M" > "$O/manifest.perm"

[ -s "$O/manifest.perm" ] || mt_die "the permutation produced an empty manifest"
# ASSERT THE PERMUTATION PRODUCED THE STATE INTENDED, in both directions.
a=$(awk '/^target /{t=$2} /^cpu_type ia64$/{printf "%s ", t}' "$M")
b=$(awk '/^target /{t=$2} /^cpu_type ia64$/{printf "%s ", t}' "$O/manifest.perm")
echo "ia64 record order, original:  $a"
echo "ia64 record order, permuted:  $b"
[ "$a" != "$b" ] || mt_die "the permutation did NOT take -- both orders are '$a',
  so every comparison below would be of one manifest against itself"
# ... and that nothing else moved.
sort "$M" > "$O/a.sorted"; sort "$O/manifest.perm" > "$O/b.sorted"
cmp -s "$O/a.sorted" "$O/b.sorted" \
  || mt_die "the permutation changed the CONTENT and not only the order"

for t in orig perm; do
  case $t in
    orig) src=$M ;;
    perm) src=$O/manifest.perm ;;
  esac
  ( cd "$G" && awk -v srcdir="$SRC/gcc" -v multilib=multi-target.multilib \
      -f "$SRC/gcc/gen-multi-target-md.awk" "$src" > "$O/$t.mk" ) \
    || mt_die "$t: the generator failed"
  [ -s "$O/$t.mk" ] || mt_die "$O/$t.mk is empty"
done

# NON-VACUITY: the generator must have actually resolved a tmake rule.  i386 is
# the control -- `i386-c.o' is claimed by config/i386/t-i386 and must be found.
for t in orig perm; do
  grep -q '^mt-i386/i386-c\.o:' "$O/$t.mk" \
    || mt_die "$t: no mt-i386/i386-c.o rule -- frag_source_for resolved nothing,
  so this run proves nothing about ordering (did -v srcdir reach the generator?)"
done
echo "non-vacuity: mt-i386/i386-c.o rule present in both runs"

echo "== MT_C_OBJS_ia64 / MT_CXX_OBJS_ia64"
for t in orig perm; do
  printf '  %-5s ' "$t"
  grep -hE '^MT_C(XX)?_OBJS_ia64 =' "$O/$t.mk" | tr '\n' '|'
  echo
done
echo "== mt-ia64/ia64-c.o recipes"
for t in orig perm; do
  printf '  %-5s %s\n' "$t" "$(grep -c '^mt-ia64/ia64-c\.o:' "$O/$t.mk")"
done
echo "== the generator's own warning about an unclaimed c_target_obj"
for t in orig perm; do
  printf '  %-5s %s\n' "$t" "$(grep -c 'in c_target_objs but no tmake fragment' "$O/$t.mk")"
done

# THE ACCEPTANCE ARM IS ON CONTENT, NOT ON POSITION, AND THE DISTINCTION IS
# LOAD-BEARING RATHER THAN A RELAXATION.
#
# The per-TRIPLE blocks -- tm-<triple>.h, tm_p-<triple>.h, the genconditions
# rules -- are emitted once per record, so permuting the records permutes those
# blocks in the output.  That is position and not content: the same rules for
# the same triples, in a different order, and make does not care.  The defect
# under test is that a LINE PRESENT in one output is ABSENT from the other,
# which is what the sorted comparison sees and a positional diff cannot
# distinguish from a reshuffle.
#
# Reported both ways so neither reading is hidden.
echo "== positional diff (informational -- per-triple blocks move)"
if diff "$O/orig.mk" "$O/perm.mk" > "$O/order.diff" 2>&1; then
  echo "  byte-identical"
else
  echo "  $(grep -c '^[<>]' "$O/order.diff") differing lines"
fi

echo "== WHOLE-FILE content comparison (informational, with its residual named)"
sort "$O/orig.mk" > "$O/orig.sorted"
sort "$O/perm.mk" > "$O/perm.sorted"
if diff "$O/orig.sorted" "$O/perm.sorted" > "$O/content.diff" 2>&1; then
  echo "  IDENTICAL -- no line appears in one output and not the other"
else
  echo "  $(grep -c '^[<>]' "$O/content.diff") lines present in one output only:"
  grep '^[<>]' "$O/content.diff" | cut -c1-120 | head -20
  echo "  (these are LINE-INTERNAL list orderings -- the same triples in a"
  echo "   different order inside one variable or one prerequisite list.  Three"
  echo "   pairs are known and are NOT what this task fixed:"
  echo "   insn-conditions-<cpu>.md's two prerequisites and the awk arguments"
  echo "   that intersect them -- set intersection, commutative -- and"
  echo "   MULTI_TARGET_SOURCE_SPECS.  Named rather than filtered out, because a"
  echo "   filter would also hide a fourth.)"
fi

# THE ACCEPTANCE ARM, scoped to the C-family lines this task is about, and
# STRICT on them: a defect here is a line present on one side and absent on the
# other, which is the shape the whole exercise is about.
echo "== ACCEPTANCE: the C-family lines, content-identical?"
for t in orig perm; do
  grep -E '^(MT_C_OBJS_|MT_CXX_OBJS_|MT_C_TARGET_OBJS|MT_CXX_TARGET_OBJS|MT_C_OBJS_MOVED|MT_CXX_OBJS_MOVED|mt-[a-z0-9_]+/[a-z0-9_]+-c\.o:)' \
       "$O/$t.mk" | sort > "$O/$t.cfam"
done
# NON-VACUITY: the arm must have something to compare.
c=$(grep -c . "$O/orig.cfam")
[ "$c" -ge 4 ] || mt_die "only $c C-family lines matched -- the acceptance arm is vacuous"
echo "  comparing $c C-family lines"
if diff "$O/orig.cfam" "$O/perm.cfam" > "$O/cfam.diff" 2>&1; then
  echo "IDENTICAL -- MT_C_OBJS_<cpu> is a function of the back end, not of record order"
  exit 0
else
  echo "DIFFERS -- $(grep -c '^[<>]' "$O/cfam.diff") lines:"
  grep '^[<>]' "$O/cfam.diff" | head -20
  exit 1
fi
