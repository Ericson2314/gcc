#!/bin/sh
# agent-a260445cf27ba480a-eobjs-order.sh -- `extra_objs' IS FIRST-RECORD-WINS.
#
# The sibling of mt-cobjs-order.sh, which asks the same question of
# `c_target_objs' and is hardcoded to ia64.  This one takes the back end and
# the key from the caller, because the population is not one back end: sourcing
# config.gcc for all 191 triples in contrib/config-list.mk
# (agent-a260445cf27ba480a-langobjs.sh) shows `extra_objs' differing between
# two triples of ONE cpu_type for TWENTY back ends -- aarch64 alpha arc arm
# bfin csky frv pa i386 ia64 m68k microblaze mips or1k rs6000 s390 sh sparc vax
# xtensa -- and gen-multi-target-md.awk's flush() consumes `xobjs' only AFTER
# `if (seen[cpu]) { emit_triple(); reset(); return }'.  So the first record for
# a back end decides that back end's whole extra-object list, and the others
# are discarded with no diagnostic.
#
# WHAT IS AND IS NOT A DEFECT HERE, because the census flags more keys than
# this and most of them are FINE.  `tm_defines', `tm_p_file' and
# `tm_include_list' also differ between a back end's triples, and they are
# consumed inside emit_triple(), which runs for EVERY record -- that is the
# design, not the bug.  `extra_options' and `target_gtfiles' differ too and are
# explicitly UNIONED by gen-target-manifest.sh.  `out_file', `md_file',
# `extra_modes' and `common_out_file' are read first-record-wins and were
# MEASURED not to differ within any cpu_type across all 191 triples, so their
# first-record read is correct today.  `extra_objs' is the one that is both
# first-record-wins AND divergent.
#
# usage: agent-a260445cf27ba480a-eobjs-order.sh <builddir> [cpu]
#   the build dir must be configured with TWO triples of <cpu> whose
#   extra_objs differ, e.g. aarch64-elf,aarch64-linux-gnu.
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

D=${1:?build dir}
CPU=${2:-aarch64}
mt_assert_builddir "$D"
SRC=$(mt_src_of "$D") || exit 9
G=$D/gcc
M=$G/multi-target.manifest
[ -s "$M" ] || mt_die "$M absent or empty -- run 'make configure-gcc' first"
[ -s "$G/multi-target.multilib" ] || mt_die "$G/multi-target.multilib absent"

n=$(grep -c "^cpu_type $CPU\$" "$M")
[ "$n" = 2 ] || mt_die "$M names $n $CPU records, expected 2 -- the arm cannot fire"

# THE ARM MUST BE ABLE TO FIRE: the two records must actually DISAGREE about
# extra_objs.  Two identical records would give an identical generated file for
# a reason that has nothing to do with the defect, and that green is
# indistinguishable from a fixed generator.
a=$(awk -v c="$CPU" '/^cpu_type /{k=$2} /^extra_objs /{if(k==c) print}' "$M" | sort -u | wc -l)
[ "$a" = 2 ] || mt_die "the two $CPU records agree on extra_objs -- nothing to permute"
awk -v c="$CPU" '/^target /{t=$2} /^cpu_type /{k=$2} /^extra_objs /{if(k==c) print "  " t ": " $0}' "$M"

O=$D/eobjs-order-$CPU; mkdir -p "$O"
awk -v c="$CPU" 'BEGIN { RS = ""; FS = "\n" }
     { cpu = "";
       for (i = 1; i <= NF; i++) if ($i ~ /^cpu_type /) cpu = substr($i, 10);
       if (cpu == c) { mine[++nm] = $0 } else { other[++no] = $0 }
       order[NR] = (cpu == c) ? "mine" : "other" }
     END { j = 0; k = 0;
       for (r = 1; r <= NR; r++) {
	 if (order[r] == "mine") { print mine[nm - j]; j++ } else { print other[++k] }
	 print "" } }' "$M" > "$O/manifest.perm"

x=$(awk -v c="$CPU" '/^target /{t=$2} {if ($0 == "cpu_type " c) printf "%s ", t}' "$M")
y=$(awk -v c="$CPU" '/^target /{t=$2} {if ($0 == "cpu_type " c) printf "%s ", t}' "$O/manifest.perm")
echo "record order, original:  $x"
echo "record order, permuted:  $y"
[ "$x" != "$y" ] || mt_die "the permutation did NOT take"
sort "$M" > "$O/a.s"; sort "$O/manifest.perm" > "$O/b.s"
cmp -s "$O/a.s" "$O/b.s" || mt_die "the permutation changed CONTENT, not only order"

for t in orig perm; do
  case $t in orig) src=$M ;; perm) src=$O/manifest.perm ;; esac
  ( cd "$G" && awk -v srcdir="$SRC/gcc" -v multilib=multi-target.multilib \
      -f "$SRC/gcc/gen-multi-target-md.awk" "$src" > "$O/$t.mk" ) \
    || mt_die "$t: the generator failed"
  [ -s "$O/$t.mk" ] || mt_die "$O/$t.mk is empty"
  # NON-VACUITY, the same one mt-cobjs-order.sh records: without -v srcdir the
  # generator resolves no tmake rule and both sides agree on a run that did
  # none of the work under test.
  grep -q '^mt-i386/i386-c\.o:' "$O/$t.mk" || mt_die "$t: no mt-i386/i386-c.o rule"
done
echo "non-vacuity: mt-i386/i386-c.o rule present in both runs"

echo "== MULTI_TARGET_OBJS_$CPU"
for t in orig perm; do
  printf '  %-5s ' "$t"
  grep -h "^MULTI_TARGET_OBJS_$CPU *=" "$O/$t.mk" | tr '\n' '|'
  echo
done

echo "== lines present in ONE generated makefile and not the other (content, not position)"
sort "$O/orig.mk" > "$O/orig.s"; sort "$O/perm.mk" > "$O/perm.s"
comm -23 "$O/orig.s" "$O/perm.s" | grep . > "$O/only-orig" || true
comm -13 "$O/orig.s" "$O/perm.s" | grep . > "$O/only-perm" || true
echo "  only in orig: $(grep -c . "$O/only-orig" || echo 0)"
sed 's/^/    /' "$O/only-orig" | head -20
echo "  only in perm: $(grep -c . "$O/only-perm" || echo 0)"
sed 's/^/    /' "$O/only-perm" | head -20

if [ -s "$O/only-orig" ] || [ -s "$O/only-perm" ]; then
  echo "VERDICT: ORDER-DEPENDENT -- the generated build depends on which triple came first"
  exit 1
fi
echo "VERDICT: identical"
