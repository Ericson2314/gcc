#!/bin/sh
# Install, PER TARGET, the generated headers that target's libgcc compiles
# against, into $(libdir)/gcc/$(version)/<target>/include -- beside the
# specs-config the driver already finds there (#96's layout).
#
#   $1  the gcc build directory (where the generated headers are)
#   $2  the gcc source directory
#   $3  gcc/multi-target.manifest
#   $4  the installed per-version directory, WITH $(DESTDIR) prefixed
#   $5  the same directory as the installed compiler will see it, WITHOUT
#       $(DESTDIR) -- printed, so the log names what a consumer will ask for
#   $6  $(MULTI_TARGET_GEN_HDRS), as ONE word-split argument.  May be empty in
#       a build whose back ends generate nothing; passed as its own positional
#       so that "empty list" and "caller forgot the argument" are different
#       things -- the script fails if it is absent, not if it is empty.
#   $7.. the target triples
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
# THE SECOND HALF: THE BACK-END GENERATED HEADERS THE *UNION* REACHES.
#
# The installed `options-<base>.h' is not one back end's.  opth-gen.awk emits,
# for every CONFIGURED back end, that back end's `HeaderInclude' headers -- 35
# of them across the tree, and not all named `*-opts.h' (config/arm/aarch-common.h
# and config/loongarch/loongarch-str.h are two).  So aarch64's libgcc opens
# config/arm/arm-opts.h, whether or not anything arm is in sight; measured, with
# aarch64+arm+i386 configured, `options-aarch64.h:14' is
# `#include "config/arm/arm-opts.h"'.
#
# Those headers are SOURCE files and libgcc already reaches them through
# -I$(srcdir)/../gcc.  What it cannot reach is what they in turn include that is
# GENERATED into the gcc build directory.  Re-derived by taking the transitive
# closure of quoted #includes from all 35 HeaderInclude roots and keeping the
# names that resolve nowhere under $(srcdir), the whole set is TWO files:
#
#     arm-isa.h   arm-cpu.h        (both from config/arm/arm-opts.h)
#
# and no other back end contributes one.  That closure is a fact about today's
# sources, so this script does NOT hardcode it: it installs everything the
# generator rules declare, $(MULTI_TARGET_GEN_HDRS), and then CHECKS the closure
# per base.  A hardcoded pair would go stale the first time a `*-opts.h' grows
# an include, and the symptom would again be a libgcc build failing on a name
# nothing in gcc mentions.
#
# gcc/Makefile.in already makes $(MULTI_TARGET_GEN_HDRS) a prerequisite of the
# in-build `options.h' for exactly this coupling.  This is the installed side of
# that same dependency; keep the two together.
set -eu

# Six fixed arguments before the triples.  Checked BY COUNT, because the
# generated-header list is allowed to be empty: without this, a caller that
# omitted it would have its first triple silently consumed as the list, and the
# install would proceed one target short and exit 0.
if [ $# -lt 6 ]; then
  echo "install-target-headers: usage: $0 builddir srcdir manifest destroot" >&2
  echo "  finalroot '<MULTI_TARGET_GEN_HDRS>' <target>..." >&2
  echo "  (got $# argument(s); the generated-header list is its own positional" >&2
  echo "   and must be passed even when empty)" >&2
  exit 1
fi

builddir=$1; shift
srcdir=$1; shift
manifest=$1; shift
dest_root=$1; shift
final_root=$1; shift
gen_hdrs=$1; shift

fail () { echo "install-target-headers: $*" >&2; exit 1; }

test -d "$srcdir/config" || fail "$srcdir does not look like gcc's source
  directory (no config/ under it); the generated-header closure below reads the
  back ends' HeaderInclude headers from there and would report every one of
  them missing."

test -f "$manifest" || fail "no $manifest.
  It carries each target's cpu_type, and without it there is no way to say
  WHICH back end's generated headers are this target's.  Build gcc first."

[ $# -gt 0 ] || fail "no targets named, so this would install nothing and
  exit 0 -- which is indistinguishable from a successful install.  Refusing."

ninst=0
checked_bases=
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

  # The back ends' generated headers -- see the note at the top.  The WHOLE of
  # $(MULTI_TARGET_GEN_HDRS) goes in, not the two the closure names today:
  # the list is the tree's own declaration of what its generator rules produce,
  # so it cannot undercount the way a hand-kept list does.  Files that are not
  # headers are skipped by extension: rs6000's fragment declares
  # `rs6000-builtins.cc' beside its two headers, and a .cc is compiled, never
  # included.
  for f in $gen_hdrs; do
    case $f in
      *.cc|*.c) continue ;;
    esac
    test -f "$builddir/$f" || fail "$t: $builddir/$f is absent, though
  \$(MULTI_TARGET_GEN_HDRS) names it.  A declared generator rule did not run;
  installing without it would leave an installation whose libgcc fails on
  \`$f: No such file or directory' from inside a back-end options header."
    cp "$builddir/$f" "$d/$f.tmp" && mv "$d/$f.tmp" "$d/$f"
  done

  # NON-VACUITY ON THE LIST ITSELF.  Everything above would pass with
  # $gen_hdrs empty, so close over the installed options header and require
  # every quoted #include it reaches to resolve either under $srcdir or in the
  # directory just written.  This is the check that fails BY NAME on
  # `arm-isa.h', which is how the defect was found from the other end.
  #
  # Done once per BASE, not per triple: the union header is the same file for
  # every triple on a back end, and 47 triples would be 47 identical closures.
  case " $checked_bases " in
    *" $cpu "*) ;;
    *)
      unresolved=`awk -v srcdir="$srcdir" -v instdir="$d" '
        function dirname(p,   i) {
          i = length(p); while (i > 0 && substr(p, i, 1) != "/") i--;
          return i > 0 ? substr(p, 1, i - 1) : ".";
        }
        function resolve(h, from,   c, i, cand) {
          cand[1] = dirname(from) "/" h;
          cand[2] = srcdir "/" h;
          cand[3] = srcdir "/config/" h;
          cand[4] = instdir "/" h;
          for (i = 1; i <= 4; i++)
            if ((getline junk < cand[i]) >= 0) { close(cand[i]); return cand[i]; }
          return "";
        }
        BEGIN {
          n = 1; work[1] = ARGV[1]; from[1] = "."; ARGV[1] = "";
          for (i = 1; i <= n; i++) {
            p = (from[i] == "." ? work[i] : resolve(work[i], from[i]));
            if (p == "") { bad[work[i]] = from[i]; continue; }
            if (seen[p]++) continue;
            while ((getline line < p) > 0)
              if (line ~ /^[ \t]*#[ \t]*include[ \t]*"/) {
                h = line; sub(/^[^"]*"/, "", h); sub(/".*$/, "", h);
                n++; work[n] = h; from[n] = p;
              }
            close(p);
          }
          for (h in bad) printf "%s (from %s)\n", h, bad[h];
        }' "$d/options-$cpu.h"`
      test -z "$unresolved" || fail "$t (base $cpu): the installed
  options-$cpu.h reaches headers that are in neither $srcdir nor $d:
$unresolved
  These are generated into the gcc build directory.  Either a back end's
  t-<cpu>-headers fragment does not declare them in \`generated_files +=' -- so
  \$(MULTI_TARGET_GEN_HDRS) never saw them -- or gcc/Makefile.in is not passing
  that variable to this script."
      checked_bases="$checked_bases $cpu"
      echo "install-target-headers: base $cpu union closure resolves"
      ;;
  esac

  ninst=`expr $ninst + 1`
  echo "install-target-headers: $t (base $cpu) -> $final_root/$t/include"
done

echo "install-target-headers: $ninst target(s)"
exit 0
