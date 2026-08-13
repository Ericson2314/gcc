#!/bin/sh
# Install one target's spec file and capability config into the directory the
# installed driver searches: $(libdir)/gcc/$(version)/<target>/.
#
#   $1  the build tree's copy of that directory
#   $2  the installed directory, WITH $(DESTDIR) already prefixed
#   $3  the same directory as the installed compiler will see it, i.e. WITHOUT
#       $(DESTDIR) -- this is what has to appear inside the spec file
#   $4  the target triple
#
# WHY THE REWRITE.  target-specs writes an ABSOLUTE path into the spec file
# (*cc1_target_config and *link_target_config are `-ftarget-config=<path>'),
# because the driver's working directory is not the spec file's directory.
# Copied unchanged into an installation, that path names the build tree, which
# on the deployed machine is somewhere between wrong and absent.
#
# The cc1 side survives it by accident: gcc.cc prefers the file it found for
# itself over the spec's text.  The LINK side does not -- collect2 gets
# %(link_target_config) from LINK_COMMAND_SPEC and there is no such preference
# -- and read_target_caps treats a missing file as "the built-in defaults
# stand" and returns QUIETLY.  So an unrewritten path does not fail; it makes
# the linker silently use defaults for a target it has a probed answer for.
# That is this branch's signature shape, so the rewrite is checked, not
# assumed: both directions are counted and a count of zero on either is fatal.

set -u

src=$1
dst=$2
final=$3
triple=$4

fail () { echo "mt-install-config: $triple: $*" >&2; exit 1; }

test -f "$src/specs-config" || fail "no $src/specs-config.
  Nothing has probed $triple in this build tree.  Run
      make configure-target-specs-$triple
  first; there is nothing to install and no default to install instead."

mkdir -p "$dst" || fail "cannot create $dst"

cp "$src/specs-config" "$dst/specs-config.tmp" || fail "cannot copy specs-config"
mv "$dst/specs-config.tmp" "$dst/specs-config" || fail "cannot install specs-config"

if test -f "$src/specs"; then
  # Rewrite every reference to the build-tree directory into the installed one.
  sed "s|$src/|$final/|g" "$src/specs" > "$dst/specs.tmp" \
    || fail "cannot rewrite $src/specs"

  # BOTH DIRECTIONS, because either alone passes while the other is broken.
  before=`grep -F -c -e "$src/" "$src/specs"` || before=0
  after=`grep -F -c -e "$final/" "$dst/specs.tmp"` || after=0
  left=`grep -F -c -e "$src/" "$dst/specs.tmp"` || left=0

  if test "$before" -eq 0; then
    fail "$src/specs contains no reference to $src/ at all, so the rewrite had
  nothing to do.  Either target-specs stopped embedding the path -- in which
  case this check is obsolete and should be retired deliberately -- or it was
  handed a different --with-specs-file than the one installed here.  Refusing
  to score a rewrite that cannot have happened."
  fi
  if test "$after" -lt "$before"; then
    fail "rewrote $after of $before references to the installed path"
  fi
  if test "$left" -ne 0; then
    fail "$left reference(s) to the build tree survive in the installed spec
  file, so an installed compiler would read $src, which will not be there."
  fi

  mv "$dst/specs.tmp" "$dst/specs" || fail "cannot install specs"
  echo "mt-install-config: $triple: specs ($before path reference(s) rewritten) and specs-config -> $final"
else
  echo "mt-install-config: $triple: specs-config -> $final (no spec file: target-specs skipped it because nothing was probed)" >&2
fi
exit 0
