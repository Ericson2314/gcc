#!/bin/sh
# mt-rename-sweep.sh -- IS `MULTI_TARGET_RENAME_NAMES' COMPLETE FOR N BASES?
#
# THE SURVIVOR OF SIX.  gcc/Makefile.in's MULTI_TARGET_RENAME_NAMES comment
# says its authority is "an `nm' sweep over the object SETS, never the linker".
# That sentence has named, in order: `scratchpad/sweep.sh' (which did not
# exist), then t150-, t155-, t157-, t165- and t167-rename-gap.sh -- six files
# for one job, each written because the previous "was inadequate", which was
# true when said and stopped being true.  One name, several authorities, no
# diagnostic: this branch's own root bug, in its own tooling.
#
# THIS FILE IS NOT THE LATEST OF THE SIX.  It is the union of their arms,
# because later was NOT automatically better -- three of them dropped guards
# their predecessors had.  What came from where:
#
#   sweep.sh   * `nm'/`ar' must be ON PATH.  A tool that is not found pipes
#                into `grep -c' as 0 -- in the direction that looks clean.
#              * THE libbackend.a MEMBERSHIP FILTER.  Only objects that are
#                actually linked are compared.  Without it 21 of 22 hits were
#                `mt_probe_*' from the macro-probe fixture, which is in no
#                archive and no link; a check that is 95% noise is a check
#                nobody reads.  Every exclusion is PRINTED, never silent.
#              * per-base "contributed 0 objects" FATAL.  Two earlier guesses
#                at the member-path spelling each excluded ALL 64 aarch64
#                objects, and with every object excluded the sweep compares
#                empty sets and reports a clean pass.  This assertion was the
#                only thing between that and a false green.
#              * NAMES THE PAIR AND THE TWO OBJECTS for each collision.  A
#                check that cannot say WHICH thing disagrees is most of a
#                check.
#              * A NONZERO EXIT on failure.  t150/t155/t157/t165/t167 all exit
#                0 whatever they find, so a caller cannot gate on them.
#   t167       * THE `.rc' STAMP CHECK.  This reads objects; a build still
#                running is a partial object set, i.e. a partial collision
#                set, and a SMALLER count reads exactly like success.
#              * ARM 2, base-vs-SHARED.  A base-vs-base sweep is blind by
#                construction to `mt-sh/sh.o' colliding with `insn-preds.o',
#                which belongs to no base -- and that was a real link failure
#                at sixteen bases.  With its VACUITY call-out: an empty shared
#                set makes arm 2 green while proving nothing.
#   t155       * hand-written and generated objects reported SEPARATELY.  "the
#                generated code is already namespaced" is a written invariant
#                and a written invariant is not a checked one; averaging the
#                two hides the worse finding inside the expected one.
#              * per name, HOW MANY bases define it and WHICH.  A name in three
#                bases and a name in two are the same line to `uniq -d' and are
#                not the same problem.
#              * the EMPTY-BASE call-out.  Under `make -k' a base that never
#                built contributes no symbols, which reads identically to a
#                base that collides with nothing.
#   t150       * (nothing unique; it is the ancestor of t155/t157.)
#
# BLIND SPOTS, stated because a clean result from an instrument with unexamined
# ones is worth very little:
#   * WEAK/COMDAT symbols are excluded by the T/D/B/R filter.  A strong-symbol
#     sweep on this branch has already hidden a COMDAT defect (`optab_handler').
#   * A macro expanding to option state (global_options.x_*) is invisible to
#     `nm' by construction.  Different bug class, not this one.
#   * `ld' and this sweep have COMPLEMENTARY blind spots: the linker misses a
#     collision between two archive members nothing happens to pull in (the
#     twenty aarch_*/arm_* names of #157); a base-vs-base sweep misses a base
#     colliding with shared code (arm 2 exists for that).  Run both and
#     reconcile BY NAME -- a count that agrees is not a set that agrees.
#
# usage: WANT_ANCHOR=<n> mt-rename-sweep.sh <builddir>
#   MT_STAMP  name of the build stamp to require (default make-cc1.rc)
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

B=${1:?build dir}
mt_assert_builddir "$B"
G="$B/gcc"
[ -d "$G" ] || mt_die "no $G"

SRC=$(mt_src_of "$B") || exit 9
mt_assert_configured_from "$B" "$SRC"
n=$(mt_assert_anchor "$SRC") || exit 9
# NOT inline in the echo: a `$(mt_...)' that dies exits only the SUBSHELL, so
# the FATAL prints and the script carries on to score anyway.
kind=$(mt_assert_src_frozen "$SRC") || exit 9
echo "arm 0a ok: srcdir $SRC anchor=$n $kind"

STAMP=${MT_STAMP:-make-cc1.rc}
st=$(mt_assert_stamped "$B/$STAMP") || exit 9
echo "arm 0b ok: build stamped $st"

command -v nm > /dev/null || mt_die "no nm on PATH (run under eb-shell.sh; a
  tool-not-found piped into grep -c scores 0, which looks clean)"
command -v ar > /dev/null || mt_die "no ar on PATH"

bases=$(ls -d "$G"/mt-* 2>/dev/null | sed 's|.*/mt-||')
nb=$(printf '%s\n' "$bases" | grep -c . || true)
[ "$nb" -ge 2 ] || mt_die "found $nb base dirs under $G -- scoring nothing, not 'no collisions'"
echo "arm 0c ok: $nb configured bases: $(printf '%s ' $bases)"

# THE LINKED SET.  `ar t' on a missing archive prints nothing and exits
# non-zero, and an empty member list would exclude EVERY object and report a
# clean sweep -- the false-green direction -- so it is checked, not assumed.
work=$B/mt-rename-sweep; rm -rf "$work"; mkdir -p "$work"
ar t "$G/libbackend.a" > "$work/members" 2>/dev/null \
  || mt_die "cannot read $G/libbackend.a; build it before sweeping"
nmem=$(grep -c . "$work/members" || true)
[ "$nmem" -gt 100 ] || mt_die "libbackend.a lists only $nmem members; that is not a built archive"
echo "arm 0d ok: libbackend.a has $nmem members"

# libbackend.a is a THIN archive (`ar rcT') named by an absolute path, so `ar
# t' yields absolute member paths and $o compares as it stands.  Two wrong
# guesses preceded this -- basename, and path relative to <objdir>/gcc -- and
# both excluded every aarch64 object, i.e. both failed toward a clean pass.
collect () {           # collect <base> <kind> <object...>
  _b=$1; _k=$2; shift 2
  : > "$work/$_k-$_b.objs"; : > "$work/$_k-$_b.skipped"
  for o in "$@"; do
    [ -f "$o" ] || continue
    if grep -qxF "$o" "$work/members"
      then echo "$o" >> "$work/$_k-$_b.objs"
      else echo "$o" >> "$work/$_k-$_b.skipped"
    fi
  done
  # Materialised in THIS shell, not counted inside a `for ... | sort' pipeline:
  # the loop body there runs in a SUBSHELL, so an earlier version reported "0
  # objects" beside 22607 definitions it had just read from them.
  while IFS= read -r o; do
    nm -C -g --defined-only "$o" 2>/dev/null \
      | awk -v o="$o" '$2 ~ /^[TDBR]$/ { $1=""; $2=""; sub(/^  /,""); print $0 "\t" o }'
  done < "$work/$_k-$_b.objs" | LC_ALL=C sort -u > "$work/$_k-$_b.syms"
}

tot=0; empty=""
for b in $bases; do
  collect "$b" hand "$G/mt-$b"/*.o
  collect "$b" gen $(ls "$G"/insn-*-"$b".o "$G"/insn-*-"$b"-[0-9]*.o \
                        "$G"/target-*-"$b".o 2>/dev/null)
  oh=$(grep -c . "$work/hand-$b.objs" || true); h=$(grep -c . "$work/hand-$b.syms" || true)
  og=$(grep -c . "$work/gen-$b.objs"  || true); g=$(grep -c . "$work/gen-$b.syms"  || true)
  printf '  %-12s hand %3d obj / %6d defs   generated %3d obj / %6d defs\n' "$b" "$oh" "$h" "$og" "$g"
  for k in hand gen; do
    ns=$(grep -c . "$work/$k-$b.skipped" || true)
    [ "$ns" = 0 ] || echo "      $k: excluded $ns object(s) not in libbackend.a: $(tr '\n' ' ' < "$work/$k-$b.skipped")"
  done
  [ "$oh" -gt 0 ] || empty="$empty $b"
  tot=$((tot + h + g))
done
[ "$tot" -gt 0 ] || mt_die "nm read 0 definitions in total"
if [ -n "$empty" ]; then
  echo "  NOTE: these bases contributed NO hand-written linked objects, so they are"
  echo "        ABSENT from the collision set rather than clean:$empty"
fi

fail=0

# ---- ARM 0e: THE COLLISION TEST MUST BE ABLE TO REPORT NON-ZERO ------------
#
# Run on EVERY invocation, before any real reporting, because this arm's whole
# job is to make "0 colliding names" mean something.  A null result must be
# impossible to confuse with a pass, and this instrument spent an unknown
# period reporting 51 FALSE collisions -- so the corrected version reporting 0
# is exactly the reading a reader would most like to believe and least be able
# to check.
#
# The fixture is the two shapes that must be told apart, and they are the two
# real ones this arm got wrong:
#
#   MUST NOT REPORT  two C++ OVERLOADS of one name, in ONE base
#                    (the 51 false positives were all of this shape)
#   MUST REPORT      one name defined bare by TWO bases
#                    (the shape MULTI_TARGET_RENAME_NAMES exists for)
#
# It exercises the awk that classifies, which is the part that was wrong;
# `nm' and the object enumeration are covered by arms 0c/0d and by the
# non-zero definition counts printed above.
sweep_selftest () {
  _t=$(mktemp -d) || return 1
  printf 'ov(machine_mode, bool, int)\t/x/a.o\nov(machine_mode, int)\t/x/a.o\nboth(int)\t/x/a.o\n' > "$_t/A"
  printf 'both(int)\t/y/b.o\nonlyb(void)\t/y/b.o\n'                                                  > "$_t/B"
  for _b in A B; do
    cut -f1 "$_t/$_b" | awk -v b="$_b" -F'\t' '{ print $0 "\t" b }'
  done \
    | awk -F'\t' '{ if (!(($1 SUBSEP $2) in seen)) { seen[$1 SUBSEP $2]=1;
                                                     c[$1]++; d[$1] = d[$1] " " $2 } }
                  END { for (n in c) if (c[n] > 1) printf "%3d\t%s\t%s\n", c[n], n, d[n] }' \
    | LC_ALL=C sort -rn > "$_t/out"
  _got=$(grep -c . "$_t/out" || true)
  _name=$(cut -f2 "$_t/out" | head -1)
  rm -rf "$_t"
  [ "$_got" = 1 ] || { echo "  self-test reported $_got rows, expected exactly 1"; return 1; }
  [ "$_name" = "both(int)" ] || { echo "  self-test named '$_name', expected 'both(int)'"; return 1; }
  return 0
}
if sweep_selftest; then
  echo "arm 0e ok: the collision test reports the two-base name and NOT the overload pair"
else
  mt_die "arm 0e FAILED: the collision test cannot distinguish a real two-base
  collision from a C++ overload set in one base.  Every '0 colliding names'
  below would be unfalsifiable.  REFUSING to report a sweep result."
fi

report () {            # report <kind> <headline>
  _k=$1; _h=$2
  echo
  echo "== $_h: names defined by MORE THAN ONE base"
  # TWO DEFECTS FIXED HERE, AND THEY COMPOUNDED INTO A FALSE RED OF 51.
  #
  # This was `cut -f1 ... | awk '{ c[$1]++; d[$1] = d[$1] " " $2 }'', i.e. the
  # key was `$1' -- THE FIRST WHITESPACE TOKEN OF A DEMANGLED C++ SIGNATURE.
  # `riscv_v_adjust_nunits(machine_mode, bool, int, int)' and
  # `riscv_v_adjust_nunits(machine_mode, int)' are two OVERLOADS, two distinct
  # symbols, in ONE object in ONE base -- and both truncate to the key
  # `riscv_v_adjust_nunits(machine_mode,'.  PRINCIPLES section 7 already
  # records this family ("a demangled C++ name" defeating a name-matching
  # instrument); it arrived here through the KEY rather than through the regex.
  #
  # And the count was of OCCURRENCES, not of BASES, so even with a correct key
  # a name defined in two objects of the SAME base scored as a collision.  The
  # arm's own headline says "defined by MORE THAN ONE base", which is the
  # question; it was not the one being asked.
  #
  # Measured at four bases before the fix: `SWEEP FAILS: 51 colliding entries',
  # every one of them an overload set inside a single base, against a `cc1'
  # that links with ZERO `multiple definition'.  A false RED is as expensive as
  # a false green here and worse in one way: the remedy it prints is to add 51
  # names to MULTI_TARGET_RENAME_NAMES, which would be a real edit made for no
  # reason.
  #
  # The key is now the WHOLE tab-delimited name field and the count is of
  # DISTINCT bases.
  for b in $bases; do
    cut -f1 "$work/$_k-$b.syms" | awk -v b="$b" -F'\t' '{ print $0 "\t" b }'
  done \
    | awk -F'\t' '{ if (!(($1 SUBSEP $2) in seen)) { seen[$1 SUBSEP $2]=1;
                                                     c[$1]++; d[$1] = d[$1] " " $2 } }
                  END { for (n in c) if (c[n] > 1) printf "%3d\t%s\t%s\n", c[n], n, d[n] }' \
    | LC_ALL=C sort -rn > "$work/collide-$_k.txt"
  _n=$(grep -c . "$work/collide-$_k.txt" || true)
  echo "  $_n colliding names"
  sed 's/^/    /' "$work/collide-$_k.txt"
  # Name the defining object for each, per base.  A collision with no object
  # named sends the reader back to the archive by hand.
  # The rows are now TAB-delimited (count, name, bases), so the name is field 2
  # verbatim -- it used to be reconstructed by deleting the first and last
  # WHITESPACE tokens, which mangles any demangled signature it is handed.
  while IFS= read -r line; do
    nm_=$(printf '%s\n' "$line" | cut -f2)
    for b in $bases; do
      awk -F'\t' -v s="$nm_" '$1 == s { print "        " FILENAME ": " $2 }' "$work/$_k-$b.syms"
    done
  done < "$work/collide-$_k.txt" > "$work/where-$_k.txt" 2>/dev/null || true
  fail=$((fail + _n))
}
report hand "HAND-WRITTEN config/ objects"
report gen  "GENERATED per-base objects (expected: ZERO -- they are namespaced)"

echo
echo "== ARM 2: names a base defines that SHARED generated code also defines"
# The blind-spot arm.  The shared set is the SINGULAR generated objects, which
# belong to no base at all, so a base-vs-base comparison cannot reach them.
sh_objs=$(ls "$G"/insn-preds.o "$G"/insn-attrtab.o "$G"/insn-emit.o "$G"/insn-recog.o \
             "$G"/insn-opinit.o "$G"/insn-output.o "$G"/insn-extract.o "$G"/insn-peep.o \
             "$G"/insn-modes.o "$G"/insn-enums.o "$G"/insn-automata.o "$G"/insn-dfatab.o \
             "$G"/insn-latencytab.o 2>/dev/null)
: > "$work/SHARED.syms"
for o in $sh_objs; do
  nm -C -g --defined-only "$o" 2>/dev/null \
    | awk -v o="$o" '$2 ~ /^[TDBR]$/ { $1=""; $2=""; sub(/^  /,""); print $0 "\t" o }'
done | LC_ALL=C sort -u > "$work/SHARED.syms"
nsh=$(grep -c . "$work/SHARED.syms" || true)
if [ "$nsh" = 0 ]; then
  # Not fatal -- which singular objects exist depends on the base count.  But
  # say so BY NAME: an empty shared set makes this arm vacuously green, which
  # is indistinguishable from "no collisions".
  echo "  ARM 2 VACUOUS: no shared generated objects read; THIS ARM PROVED NOTHING"
else
  echo "  shared generated objects: $nsh global definitions"
  for b in $bases; do cut -f1 "$work/hand-$b.syms" "$work/gen-$b.syms"; done \
    | LC_ALL=C sort -u > "$work/allbase.txt"
  cut -f1 "$work/SHARED.syms" | LC_ALL=C sort -u > "$work/shared.txt"
  LC_ALL=C comm -12 "$work/shared.txt" "$work/allbase.txt" > "$work/collide-shared.txt"
  n2=$(grep -c . "$work/collide-shared.txt" || true)
  echo "  $n2 names defined by BOTH a base and shared generated code"
  sed 's/^/    /' "$work/collide-shared.txt"
  fail=$((fail + n2))
fi

echo
echo "NOTE: ld reports only the subset whose archive members are both pulled"
echo "in -- it once reported 7 of 40 -- so it UNDER-counts arm 1.  Never size"
echo "this set with the linker.  Working files: $work"
if [ "$fail" -gt 0 ]; then
  echo
  echo "SWEEP FAILS: $fail colliding entries.  Each is a name two authorities"
  echo "define bare.  The fix is the sanctioned one: add the name to"
  echo "MULTI_TARGET_RENAME_NAMES in gcc/Makefile.in, so each base is compiled"
  echo "with -D<name>=<name>_<base>.  Do NOT make one definition static --"
  echo "that edits config/<cpu>/ sources, which this project does not do, and"
  echo "it silently changes that back end's linkage."
  exit 1
fi
echo "SWEEP PASSES: no strong-symbol collisions, base-vs-base or base-vs-shared."
echo "(Weak/COMDAT definitions are NOT compared -- see the header.)"
