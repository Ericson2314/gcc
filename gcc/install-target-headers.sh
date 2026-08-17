#!/bin/sh
# Install, PER TARGET, the generated headers that target's libgcc compiles
# against, into $(libdir)/gcc/$(version)/<target>/include -- beside the
# specs-config the driver already finds there (#96's layout).
#
#   $1  the gcc build directory (where the generated headers are)
#   $2  gcc/multi-target.manifest
#   $3  the installed per-version directory, WITH $(DESTDIR) prefixed
#   $4  the same directory as the installed compiler will see it, WITHOUT
#       $(DESTDIR) -- printed, so the log names what a consumer will ask for
#   $5.. the target triples
#
# WHY THIS EXISTS.  libgcc is ONE MACHINE'S LIBRARY and must see that machine's
# `tm.h'.  In an in-tree build it gets it from `libgcc/Makefile.in:284's
# `-I$(gcc_objdir)' -- the sibling gcc BUILD directory -- and there is no
# sibling build directory in an installation, which is what every packaging
# attempt so far has had to reach around.
#
# THE LIST IS MEASURED, NOT GUESSED.  Building libgcc in-tree with the compiler
# writing `.dep' files and collecting every path under the gcc build directory
# gives exactly SEVEN generated headers, across 359 translation units:
#
#     tconfig.h  auto-host.h  tm.h  options.h  insn-constants.h
#     insn-modes.h  version.h
#
# and nothing else.  In particular `tm_p.h' is NOT among them -- it is a
# compiler-internal header, it was on every guessed list, and installing it
# would have been a file nothing opens.  `insn-flags.h' is not either: tm.h
# guards it with `!defined USED_FOR_TARGET', and tconfig.h defines
# USED_FOR_TARGET.  Both absences are load-bearing; re-measure before adding.
#
# (The other 47 files a libgcc compile opens from the build tree -- `include/'
# and `include-<cpu>/' -- are the COMPILER's own headers.  They already install
# under $(libsubdir) and reach libgcc through the driver's built-in include
# path, not through -I$(gcc_objdir), so they are not this script's business.)
#
# THE TRAP THIS AVOIDS.  The gcc build directory's top-level `tm.h',
# `options.h', `insn-modes.h' and `insn-constants.h' are the PRIMARY back end's
# -- measured: the two-base build's `gcc/tm.h' includes config/i386/i386.h,
# config/i386/x86-64.h and config/i386/linux64.h, and `gcc/insn-modes.h' says
# "Generated automatically from machmode.def and config/i386/i386-modes.def".
# `-I$(gcc_objdir)' therefore already serves i386's tm.h to EVERY target's
# libgcc; it only looks correct because the target that gets built in-tree is
# the primary.  Installing "the" tm.h would reproduce that for all 47.  So each
# target gets ITS OWN directory holding ITS OWN headers, and the per-triple
# `tm-<key>.h' is the authority -- not the per-base `<cpu>-inc/tm.h', because
# two triples on one back end can differ (glibc vs musl, ILP32 vs LP64).
set -eu

builddir=$1; shift
manifest=$1; shift
dest_root=$1; shift
final_root=$1; shift

fail () { echo "install-target-headers: $*" >&2; exit 1; }

test -f "$manifest" || fail "no $manifest.
  It carries each target's cpu_type, and without it there is no way to say
  WHICH back end's generated headers are this target's.  Build gcc first."

[ $# -gt 0 ] || fail "no targets named, so this would install nothing and
  exit 0 -- which is indistinguishable from a successful install.  Refusing."

ninst=0
for t in "$@"; do
  key=`echo "$t" | sed 's/[^A-Za-z0-9_]/_/g'`
  cpu=`awk -v t="$t" '$1 == "target" { seen = ($2 == t) }
                      seen && $1 == "cpu_type" { print $2; exit }' "$manifest"`
  test -n "$cpu" || fail "$t: $manifest has no cpu_type line for it, so the
  back end whose generated headers are this target's is unknown.  Stopping
  rather than installing the primary's, which is the defect being removed."

  d=$dest_root/$t/include
  mkdir -p "$d" || fail "$t: cannot create $d"

  # The per-target files, under the name that back end generated them with.
  for f in tm-$key.h options-$cpu.h insn-constants-$cpu.h insn-modes-$cpu.h; do
    test -f "$builddir/$f" || fail "$t: $builddir/$f is absent.
  This is the per-target half of the header set and it cannot be substituted
  by the top-level $builddir/`echo $f | sed -e "s/-$key//" -e "s/-$cpu//"`,
  which is the PRIMARY back end's."
    cp "$builddir/$f" "$d/$f.tmp" && mv "$d/$f.tmp" "$d/$f"
  done

  # The target-independent files.  auto-host.h reaches libgcc through
  # tconfig.h and is gcc's HOST configuration -- a fact about the machine gcc
  # RUNS on, handed to a library for another machine.  That inversion is real
  # and is recorded as such; it is installed here because it is what libgcc
  # opens TODAY, and removing it is a separate measured change, not something
  # to do silently by omitting a file and seeing what breaks.
  for f in tconfig.h auto-host.h version.h; do
    test -f "$builddir/$f" || fail "$t: $builddir/$f is absent"
    cp "$builddir/$f" "$d/$f.tmp" && mv "$d/$f.tmp" "$d/$f"
  done

  # The plain names libgcc's sources actually write.  One line each, so there
  # is exactly one copy of every header and a shim cannot go stale against the
  # file it names.  Same shape as the build tree's own `<cpu>-inc/'.
  echo "#include \"tm-$key.h\""                 > "$d/tm.h"
  echo "#include \"options-$cpu.h\""            > "$d/options.h"
  echo "#include \"insn-constants-$cpu.h\""     > "$d/insn-constants.h"
  echo "#include \"insn-modes-$cpu.h\""         > "$d/insn-modes.h"

  # NON-VACUITY, per target: the installed tm.h must reach THIS target's back
  # end.  A copy of the wrong file is the failure this script exists to
  # prevent, and it is invisible by name -- every file above would be present
  # and correctly named.  So look at the body: the triple header names its own
  # base's options header, and mkconfig.sh emits that line unconditionally.
  grep -q "options-$cpu\\.h" "$d/tm-$key.h" || fail "$t: the installed
  tm-$key.h does not include options-$cpu.h, so it is not $cpu's.  Either the
  manifest and the header disagree about this target's back end, or the wrong
  file was copied."
  ninst=`expr $ninst + 1`
  echo "install-target-headers: $t (base $cpu) -> $final_root/$t/include"
done

echo "install-target-headers: $ninst target(s)"
exit 0
