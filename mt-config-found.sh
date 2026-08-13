#!/bin/sh
# Does the driver, invoked as an ordinary compiler with NO -B and NO
# -ftarget-config=, find the per-target configuration that was just written?
#
# WHY THIS EXISTS.  The failure this whole rule fixes is "a mechanism that
# reads a file no rule produces".  Writing the file is not the fix; writing it
# WHERE THE DRIVER LOOKS is.  Those two are indistinguishable from the
# producer's exit status, and getting the directory wrong leaves a perfectly
# good file one directory away from anything that reads it -- the same bug,
# moved.  So the producer is not believed: the consumer is asked.
#
# The driver's search is by RELATIVE POSITION (make_relative_prefix from its
# own argv[0] through the bindir -> libdir/gcc relation), which the makefile
# reproduces arithmetically.  That reproduction is exactly the kind of thing
# that is right on this host and wrong on the next one, and it fails silently.
#
#   $1  the directory holding the build tree's drivers (<objdir>/gcc)
#   $2  the target triple
#   $3  the config file that should have been written
#
# Two arms, and the second one is the point:
#
#   AFFIRMATIVE  the driver, run as <triple>-gcc with no -B, passes
#                -ftarget-config=$3 to cc1 -- the exact path, not merely some
#                path and not merely "it worked".
#   NEGATIVE     with $3 moved aside, the same command must FAIL and must name
#                the path it wanted.  Without this the affirmative arm cannot
#                tell "found our file" from "found somebody else's, or needed
#                none"; an unfired mitigation reads as protection.
#
# WHAT THIS CANNOT SEE.  It checks WHERE the file is and WHICH target it names.
# It does not check that the file's CONTENT describes that target -- a probe
# run against the wrong assembler writes a file that names one target and
# describes another, and every path- and name-based check passes.  That is a
# content diff between two targets' files and it belongs to the harness, not
# here.  Stated so the pass is not read as broader than it is.

set -u

gccdir=$1
triple=$2
cfg=$3

drv="$gccdir/$triple-gcc"

fail () { echo "mt-config-found: $triple: $*" >&2; exit 1; }

test -d "$gccdir" || fail "no such directory $gccdir"
test -x "$drv" || fail "no driver $drv.
  The driver's own NAME is the only thing that tells it which target it is
  (gcc.cc's target_from_progname), so without a copy under this name there is
  no way to ask this build tree for $triple the way an installed compiler is
  asked.  \`make all-gcc' builds one per configured target."
test -f "$cfg" || fail "no config file $cfg -- nothing to look for"

# The file must at least say it is for this target; a per-target directory
# holding another target's configuration is the "one name, several
# authorities" shape and the driver rejects it, but say so here too, because
# the diagnostic from three layers down names neither rule.
said=`sed -n 's/^target[	 ][	 ]*//p' "$cfg" | sed -n 1p`
test x"$said" = x"$triple" || fail "$cfg says its target is \`$said', not \`$triple'"

tmpd=`mktemp -d` || fail "mktemp failed"
trap 'rm -rf "$tmpd"' 0
echo 'int mt_probe;' > "$tmpd/c.c" || fail "cannot write probe source"

# THE OTHER SUPPLIER HAS TO BE OUT OF THE WAY OR NEITHER ARM MEANS ANYTHING.
#
# A spec file can also carry the switch: target-specs writes
# `*cc1_target_config: -ftarget-config=<path>' into it, and
# carry_target_config_as_switch falls back to that when its own search found
# nothing.  Both routes then produce the SAME path string, so from outside the
# driver they are indistinguishable -- and the spec route does not check that
# the file exists, so it answers happily with the file deleted.
#
# Measured, not reasoned: the first version of this script had no such stash,
# and the moment the build tree grew a `gcc/specs-<triple>' the negative arm
# reported "NEGATIVE CONTROL DID NOT FIRE".  It was right.  Everything the
# affirmative arm had been scoring could have come from the spec file.
#
# So the build tree's spec files are moved aside for the duration of both arms
# and restored afterwards, whatever happens.  What is left is exactly the
# question this script asks: does the TARGET-KEYED SEARCH find the file.
stash=
restore () {
  for f in $stash; do
    test -f "$f.mt-stash" && mv "$f.mt-stash" "$f"
  done
}
trap 'restore; rm -rf "$tmpd"' 0
for f in "$gccdir/specs" "$gccdir/specs-$triple" "$gccdir/specs-$triple-config"; do
  if test -f "$f"; then
    mv "$f" "$f.mt-stash" || fail "cannot stash $f"
    stash="$stash $f"
  fi
done

# -### prints the commands instead of running them, so this needs no
# assembler and no cc1: the question is what the DRIVER decided, and the
# driver has decided it by the time it prints.  Both streams are captured
# because the answer is on stderr and the diagnostics are too.
run () { ( cd "$tmpd" && "$drv" -### -c c.c ) > "$tmpd/out" 2>&1; }

run
# Non-vacuity: an empty transcript would make every grep below score "absent",
# which is the direction that flatters.  Refuse to score instead.
test -s "$tmpd/out" || fail "the driver printed nothing at all for \`-### -c c.c';
  every check below would read as \"not found\" for want of any input"

if grep -F -e "-ftarget-config=$cfg" "$tmpd/out" > /dev/null; then
  :
else
  echo "mt-config-found: $triple: AFFIRMATIVE ARM FAILED." >&2
  echo "  \`$drv -### -c c.c', with no -B and no -ftarget-config=, did not pass" >&2
  echo "  -ftarget-config=$cfg" >&2
  echo "  to the compiler proper.  The file was written; the driver does not" >&2
  echo "  look there.  What it said:" >&2
  sed 's/^/    /' "$tmpd/out" >&2
  exit 1
fi

# NEGATIVE ARM.  Move the file aside and require the same command to fail.
mv "$cfg" "$cfg.mt-absent" || fail "cannot move $cfg aside for the negative arm"
run
rc=$?
mv "$cfg.mt-absent" "$cfg" || fail "FAILED TO RESTORE $cfg -- the tree is now
  missing the file this rule just wrote; re-run this goal"

# THE ANSWER MUST HAVE CHANGED.  Two outcomes are accepted, and they are two
# different true states of the world rather than a relaxation of one bar:
#
#   * the driver FAILS, naming the path -- nothing else could supply one;
#   * the driver succeeds naming a DIFFERENT file.  find_target_config searches
#     $GCC_EXEC_PREFIX, then this binary's own relative position, then the
#     configured-in STANDARD_EXEC_PREFIX -- so once this compiler has been
#     INSTALLED, the third authority is a real and correct answer.  Measured:
#     after `make install' the build-tree driver falls through to
#     $(libdir)/gcc/<version>/<target>/specs-config and exits 0.  Requiring a
#     hard failure here would have made this check pass only on machines where
#     the compiler had never been installed, which is a check that stops
#     working the moment the thing it checks starts being used.
#
# What is refused is the answer STAYING THE SAME, because that is the only
# outcome under which the affirmative arm was not about this file.
if grep -F -e "-ftarget-config=$cfg" "$tmpd/out" > /dev/null; then
  echo "mt-config-found: $triple: NEGATIVE CONTROL DID NOT FIRE." >&2
  echo "  With $cfg moved aside the driver STILL named it (rc=$rc), so the" >&2
  echo "  affirmative arm proves nothing about that file -- the path is coming" >&2
  echo "  from somewhere that never checked whether it exists." >&2
  sed 's/^/    /' "$tmpd/out" >&2
  exit 1
fi
if test $rc -eq 0; then
  other=`sed -n "s/.*-ftarget-config=\\([^ ']*\\).*/\\1/p" "$tmpd/out" | sed -n 1p`
  if test -z "$other"; then
    echo "mt-config-found: $triple: with $cfg absent the driver SUCCEEDED and" >&2
    echo "  passed no -ftarget-config= at all, so cc1 would have been run" >&2
    echo "  having been told nothing.  That is the failure this mechanism" >&2
    echo "  exists to remove; it must fail loudly instead." >&2
    exit 1
  fi
  echo "mt-config-found: $triple: driver finds $cfg with no -B; with it removed the answer CHANGES to"
  echo "  $other (a different authority -- an installed tree -- not this file)"
  exit 0
fi
if grep -F -e "$cfg" "$tmpd/out" > /dev/null; then
  :
else
  echo "mt-config-found: $triple: the negative arm failed for the wrong reason." >&2
  echo "  The driver did fail with $cfg absent, but did not name it, so the" >&2
  echo "  failure cannot be attributed to that file:" >&2
  sed 's/^/    /' "$tmpd/out" >&2
  exit 1
fi

echo "mt-config-found: $triple: driver finds $cfg with no -B, and fails naming it when it is absent"
exit 0
