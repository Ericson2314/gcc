#!/bin/sh
# Run the installed `mkheaders' for ONE target, so that the installation
# actually has a fixed-header directory for it.
#
#   $1  the target triple
#   $2  that target's specs-config, as written by configure-target-specs-<t>
#   $3  the install-tools directory (fixincl, fixinc.sh, mkheaders, mkinstalldirs)
#   $4  the install-tools DATA directory (fixinc_list, gsyslimits.h, limits.h)
#   $5  the output directory, WITH $(DESTDIR) already prefixed
#   $6  the same directory as the installed compiler will see it, WITHOUT DESTDIR
#   $7  the driver to ask for this target's predefined macros
#   $8+ extra mkheaders options (MKHEADERS_FLAGS_FOR_<triple>)
#
# WHY THIS EXISTS.  `fixincludes/mkheaders.in' says of itself "THIS IS NOW THE
# ONLY THING THAT RUNS fixincludes", and until this rule NOTHING RAN IT.  The
# old caller was gcc/Makefile.in's `stmp-fixinc', deleted when gcc/ stopped
# having a target of its own, and no replacement caller was added; what stayed
# behind was `install-mkheaders', which installs mkheaders' INPUT DATA and then
# nothing consumes it.  A self-contained `make install' therefore produced no
# include-fixed for any target, while every piece of the machinery for doing so
# was present and correct.  Mechanism present, never invoked.
#
# WHERE `--headers' COMES FROM, WHICH IS THE ONE REAL DESIGN QUESTION.
# The top level ASKS target-specs; it is not told separately.  target-specs is
# the component that knows -- its configure.ac has --with-native-system-header-dir
# (with a per-triple table of defaults behind it), and it writes the answer
# UNCONDITIONALLY into the per-target config file as `native_system_header_dir'.
# So that file is read here.  The alternative -- a second top-level knob such as
# HEADERS_FOR_<triple> -- would create two authorities for one path, which is
# the exact shape that put fixincludes' output and gcc's install-mkheaders data
# in different directories with both halves exiting 0.  Users who need a
# different directory override it where it is decided:
#     make configure-target-specs-<t> \
#       TARGET_SPECS_FLAGS_FOR_<t>=--with-native-system-header-dir=DIR
# and this rule then follows it, because it reads the result rather than
# re-deciding.
#
# AND THERE IS NO DEFAULT HERE, deliberately, mirroring mkheaders itself.  A
# guessed header directory does not fail; it fixes SOME OTHER MACHINE's headers
# under this target's name, which no later check can detect.

set -u

triple=$1
cfg=$2
itoolsdir=$3
itoolsdatadir=$4
incdir=$5
final_incdir=$6
gcc_cmd=$7
shift 7

fail () { echo "mt-fix-headers: $triple: $*" >&2; exit 1; }

test -f "$cfg" || fail "no $cfg.
  That file carries this target's \`native_system_header_dir', which is the
  directory whose headers are about to be fixed.  Nothing has probed $triple
  in this build tree, so run
      make configure-target-specs-$triple
  first.  There is no default header directory: a wrong one silently fixes
  another machine's headers under $triple's name."

test -x "$itoolsdir/mkheaders" || fail "no $itoolsdir/mkheaders.
  fixincludes installs it there.  Run \`make install' (or install-fixincludes)
  before this goal."

# A key with an empty value is written as its name followed by a space, and an
# empty `native_system_header_dir' is a REAL ANSWER from target-specs meaning
# "this target has no system header directory".  Distinguish that from the key
# being absent: the first is a target that must be skipped by name, the second
# is a config file written by something older than this rule.
if grep -q "^native_system_header_dir\([ 	]\|$\)" "$cfg"; then
  :
else
  fail "$cfg has no \`native_system_header_dir' line.
  target-specs writes that key unconditionally, so a config file without it was
  not written by this tree's target-specs.  Re-run
      make configure-target-specs-$triple"
fi
sysheaders=`sed -n 's/^native_system_header_dir[ 	]*//p' "$cfg" | sed -n 1p`

if test -z "$sysheaders"; then
  fail "target-specs says $triple has NO system header directory
  (\`native_system_header_dir' is empty in $cfg).  There is nothing to fix, and
  this rule will not invent a directory to fix instead.  If that is wrong, say
  so where it is decided:
      make configure-target-specs-$triple \\
        TARGET_SPECS_FLAGS_FOR_$triple=--with-native-system-header-dir=DIR"
fi

# DELIBERATE BELT-AND-BRACES DUPLICATE OF A CHECK mkheaders NOW MAKES ITSELF.
# This is NOT a second authority: mkheaders is the authority, and the identical
# check there (see "THE HEADER DIRECTORY MUST ACTUALLY BE READ" in
# fixincludes/mkheaders.in) is the one that protects every OTHER caller -- a
# distro, cc-wrapper, a per-target nix derivation.  It is repeated here only so
# the diagnostic can name $triple and the config file the path came out of,
# which mkheaders cannot know.  If the two ever disagree, mkheaders wins; do
# not relax it there on the strength of this one.
#
# Measured, before mkheaders had the check: pointed at a directory containing
# no headers it exits 0 and installs a perfectly ordinary-looking include-fixed
# holding only limits.h and syslimits.h, which it copies from itoolsdatadir
# without consulting the header directory at all.  So "fixed nothing" and
# "fixed a directory that does not exist" were indistinguishable from its exit
# status and nearly indistinguishable from its output.
test -d "$sysheaders" || fail "$sysheaders does not exist.
  That is the directory target-specs recorded as $triple's system headers.
  Fixing it would produce an include-fixed holding only the copied limits.h and
  syslimits.h -- which looks like a successful run and is not one."
if test -z "`find "$sysheaders" -name '*.h' -print 2>/dev/null | sed -n 1p`"; then
  fail "$sysheaders contains no headers.
  Same reason as above: the run would succeed and produce nothing derived from
  $triple's headers."
fi

test -x "$gcc_cmd" || fail "no driver $gcc_cmd.
  mkheaders needs $triple's predefined macros (\`-E -dM') so fixinc.sh does not
  rename one of them; an empty list reads as \"nothing is predefined\" and
  changes which fixes fire."

echo "Fixing $triple's headers from $sysheaders"
echo "  into $final_incdir"

mkdir -p "$incdir" || fail "cannot create $incdir"

"$itoolsdir/mkheaders" \
  --target="$triple" \
  --headers="$sysheaders" \
  --itoolsdir="$itoolsdir" \
  --itoolsdatadir="$itoolsdatadir" \
  --incdir="$incdir" \
  --gcc="$gcc_cmd" \
  ${1+"$@"} || fail "mkheaders failed"

# A RULE THAT RUNS AND PRODUCES NOTHING MUST FAIL -- BUT "PRODUCES NOTHING" IS
# NOT "FIXED NOTHING", AND CONFLATING THEM WAS MEASURABLY WRONG.
#
# The first version of this check required more than the two files mkheaders
# copies out of itoolsdatadir, on the theory that anything less meant the run
# had not really happened.  Measured, that check FAILED A CORRECT RUN: armv6l
# glibc 2.42 needs no fixincludes hacks at all, so its include-fixed is exactly
# limits.h + syslimits.h + README, while aarch64 musl 1.2.5 gets a fixed
# stdio.h on top.  Zero fixes is a legitimate answer for a modern libc, and a
# check that reddens on it is a false alarm that gets the check deleted.
#
# What DOES distinguish "the rule ran" from "no rule exists" is mkheaders'
# UNCONDITIONAL output: the directory, and limits.h/syslimits.h in it, which it
# writes for every multilib whether or not any hack fired.  Absence of those
# cannot be produced by a successful run, and their presence cannot be produced
# by a missing caller -- which is exactly the discrimination this rule owes.
# The fix count is then PRINTED rather than asserted, so that "fixed nothing"
# is a visible number instead of an unremarkable directory.
test -d "$incdir" || fail "mkheaders exited 0 but $final_incdir does not exist."
for f in limits.h syslimits.h; do
  test -f "$incdir/$f" || fail "mkheaders exited 0 but $final_incdir/$f is missing.
  mkheaders writes that file for every multilib regardless of whether any
  fixincludes hack fired, so its absence means the run did not complete -- not
  that $triple needed no fixes.  Reported as a failure because an incomplete
  directory here is indistinguishable from the missing caller this rule
  replaced."
done
n=`find "$incdir" -name '*.h' -print | wc -l`
nfixed=`find "$incdir" -name '*.h' ! -name limits.h ! -name syslimits.h -print | wc -l`
echo "  $n headers in $final_incdir ($nfixed fixed from $sysheaders, \
`expr $n - $nfixed` copied from $itoolsdatadir)"

# Nothing SEARCHES them until $triple's config file says so, and target-specs is
# the single writer of that file.  Say it here rather than leaving the operator
# to discover that a correct include-fixed is invisible to the compiler.
if grep -q "^fixed_include_dir[ 	]*$final_incdir$" "$cfg"; then
  :
else
  echo "mt-fix-headers: $triple: note: nothing searches these yet."
  echo "  $cfg has no \`fixed_include_dir $final_incdir'.  Give it one via the"
  echo "  one program that writes that file, then re-install it:"
  echo "      make configure-target-specs-$triple \\"
  echo "        TARGET_SPECS_FLAGS_FOR_$triple=--with-fixed-include-dir=$final_incdir"
  echo "      make install-target-specs-$triple"
fi
