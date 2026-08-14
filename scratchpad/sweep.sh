#!/bin/sh
# THE `nm' SWEEP THAT gcc/Makefile.in's MULTI_TARGET_RENAME_NAMES COMMENT
# PRESCRIBES -- WHICH DID NOT EXIST UNTIL NOW.
#
# That comment says, of the list of hand-written back-end names that must be
# renamed per base:
#
#   THE LIST IS ONE AUTHORITY AND IT IS NOT SELF-MAINTAINING.  A name added to
#   some back end later collides silently: libbackend.a is an archive, so a
#   duplicate is diagnosed only when both members happen to be pulled in for
#   other reasons -- `ld' once reported 7 of 40.  The check is an `nm' sweep
#   over the two object SETS (scratchpad/sweep.sh), never the linker.
#
# There was no `scratchpad/sweep.sh'.  The invariant was written down and never
# run (PRINCIPLES section 4: a written invariant is not evidence anyone ran it),
# and the consequence was measured: with i386 + aarch64 + riscv configured, the
# link of cc1 failed on `extract_base_offset_in_addr', defined bare by BOTH
# aarch64.cc and riscv.cc.  The i386 + aarch64 pair everything on this branch is
# built with cannot see it -- i386 does not define that name.
#
# WHY THE LINKER IS NOT THE CHECK, restated because it is the whole point: the
# linker reports whichever duplicates it happens to pull in, and stops at the
# first failed link.  This sweep compares the object SETS directly, so it names
# EVERY colliding symbol in one run, for every pair of bases, before any link.
#
# WHAT THIS CANNOT SEE.  Only STRONG definitions (nm types T D B R) are
# compared.  Weak and COMDAT symbols (V W u v w) are legal to define in several
# objects -- inline functions and template instantiations are all of them -- so
# including them would bury the real collisions in thousands of false ones.
# That is a real blind spot and it is the same one PRINCIPLES records as
# "the T D B R filter hid COMDAT": a back-end function that collides only in a
# COMDAT body will NOT be reported here.  Stated so the pass is not read as
# broader than it is.
set -u
D=${1:-/tmp/b-abeb4d62}
G=$D/gcc

command -v nm > /dev/null || { echo "FATAL: no nm on PATH (DEVSHELL.md: nm is not there outside the nix-shell, and a tool-not-found piped into grep -c scores 0 -- in the direction that makes this look clean)"; exit 9; }
test -d "$G" || { echo "FATAL: no $G"; exit 9; }

bases=$(ls -d "$G"/mt-* 2>/dev/null | sed 's,.*/mt-,,')
[ -n "$bases" ] || { echo "FATAL: no $G/mt-* directories -- scoring nothing, not 'no collisions'"; exit 9; }
echo "bases: $(echo $bases | tr '\n' ' ')"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The set of objects that really are linked, read from the archive itself.
# `ar t' on a missing archive prints nothing and exits non-zero, and an empty
# member list would exclude EVERY object and report a clean sweep -- the
# false-green direction -- so it is checked rather than assumed.
command -v ar > /dev/null || { echo "FATAL: no ar on PATH"; exit 9; }
ar t "$G/libbackend.a" > "$tmp/members" 2>/dev/null \
  || { echo "FATAL: cannot read $G/libbackend.a; build it before sweeping"; exit 9; }
nm_members=$(wc -l < "$tmp/members")
[ "$nm_members" -gt 100 ] || { echo "FATAL: libbackend.a lists only $nm_members members; that is not a built archive"; exit 9; }
echo "libbackend.a: $nm_members members"

nobj=0
for b in $bases; do
  # A base's object set is its mt-<base>/ directory plus the generated
  # per-base objects that live in the build root under a -<base> suffix.
  set -- "$G/mt-$b"/*.o
  ls "$G"/*-"$b".o "$G"/*-"$b"-[0-9]*.o > /dev/null 2>&1 \
    && set -- "$@" $(ls "$G"/*-"$b".o "$G"/*-"$b"-[0-9]*.o 2>/dev/null)
  # The object list is materialised FIRST, in this shell.  An earlier version
  # counted inside a `for ... done | sort' pipeline, where the loop body runs
  # in a SUBSHELL, so the count came back 0 while the symbol file was correctly
  # populated -- a FATAL that said "base contributed 0 objects" next to 22607
  # definitions it had just read from those objects.
  : > "$tmp/$b.objs"
  : > "$tmp/$b.skipped"
  for o in "$@"; do
    test -f "$o" || continue
    # ONLY OBJECTS THAT ARE ACTUALLY LINKED.  A collision between two objects
    # that never meet in a link is not a defect, and reporting it is worse than
    # not reporting it: measured here, 21 of 22 hits were `mt_probe_*' from
    # `mt-<base>/reg-probe.o', the macro-probe harness's own per-base fixture,
    # which is built for all three bases and is in NO archive and NO link.  A
    # check that is 95% noise is a check nobody reads.
    #
    # Membership of libbackend.a is the filter rather than a hand-written
    # exclusion list, so a harness object added later is excluded for the
    # RIGHT reason and a back-end object added later is never excluded by
    # accident.  Every exclusion is recorded and printed, never silent.
    # libbackend.a is a THIN archive (`ar rcT'), and `ar t' resolves member
    # paths RELATIVE TO THE ARCHIVE when the archive is named by an absolute
    # path -- so the member list here is absolute and `$o' can be compared as
    # it stands.  Two wrong guesses preceded this, and both failed in the same
    # dangerous direction: matching on the basename, and matching on the path
    # relative to <objdir>/gcc, each excluded ALL 64 aarch64 objects.  With
    # every object excluded the sweep compares empty sets and reports a clean
    # pass, so only the "contributed 0 objects" assertion below stood between
    # this script and a false green.  That is why the assertion is there.
    if grep -qxF "$o" "$tmp/members"; then
      echo "$o" >> "$tmp/$b.objs"
    else
      echo "$o" >> "$tmp/$b.skipped"
    fi
  done
  n=$(wc -l < "$tmp/$b.objs")
  ns=$(wc -l < "$tmp/$b.skipped")
  [ "$ns" = 0 ] || echo "  $b: excluded $ns object(s) not in libbackend.a: $(tr '\n' ' ' < "$tmp/$b.skipped")"
  while IFS= read -r o; do
    nm -g --defined-only "$o" 2>/dev/null \
      | awk -v o="$o" '$2 ~ /^[TDBR]$/ { $1=""; $2=""; sub(/^  /,""); print $0 "\t" o }'
  done < "$tmp/$b.objs" | LC_ALL=C sort -u > "$tmp/$b.syms"
  nobj=$((nobj + n))
  echo "  $b: $n objects, $(wc -l < "$tmp/$b.syms") strong definitions"
  [ "$n" -gt 0 ] || { echo "FATAL: base $b contributed 0 objects"; exit 9; }
done

[ "$nobj" -gt 0 ] || { echo "FATAL: read 0 objects in total"; exit 9; }

# Every unordered pair of bases, compared by symbol NAME.  Named individually
# rather than counted: a check that cannot say WHICH symbol collides is most of
# a check.
echo
fail=0
for a in $bases; do
  for b in $bases; do
    # Unordered: only report each pair once.
    [ "$a" \< "$b" ] || continue
    cut -f1 "$tmp/$a.syms" | LC_ALL=C sort -u > "$tmp/a.n"
    cut -f1 "$tmp/$b.syms" | LC_ALL=C sort -u > "$tmp/b.n"
    LC_ALL=C comm -12 "$tmp/a.n" "$tmp/b.n" > "$tmp/dup"
    n=$(wc -l < "$tmp/dup")
    if [ "$n" = 0 ]; then
      echo "$a vs $b: no strong-symbol collisions"
    else
      fail=$((fail + n))
      echo "$a vs $b: $n COLLIDING STRONG SYMBOLS"
      while IFS= read -r s; do
        oa=$(awk -F'\t' -v s="$s" '$1 == s { print $2 }' "$tmp/$a.syms" | head -1)
        ob=$(awk -F'\t' -v s="$s" '$1 == s { print $2 }' "$tmp/$b.syms" | head -1)
        echo "    $s"
        echo "        $oa"
        echo "        $ob"
      done < "$tmp/dup"
    fi
  done
done

echo
if [ "$fail" -gt 0 ]; then
  echo "SWEEP FAILS: $fail colliding symbol/pair entries."
  echo "Each is a name two back ends define bare.  The fix is the sanctioned"
  echo "one: add the name to MULTI_TARGET_RENAME_NAMES in gcc/Makefile.in, so"
  echo "each base is compiled with -D<name>=<name>_<base>.  Do NOT make one"
  echo "definition static -- that edits config/<cpu>/ sources, which this"
  echo "project does not do, and it silently changes that back end's linkage."
  exit 1
fi
echo "SWEEP PASSES: no strong-symbol collisions between any pair of bases."
echo "(Weak/COMDAT definitions are NOT compared -- see the header.)"
