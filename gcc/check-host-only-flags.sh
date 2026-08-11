#!/bin/sh
# Copyright (C) 2026 Free Software Foundation, Inc.
#
# This file is part of GCC.
#
# GCC is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# GCC is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with GCC; see the file COPYING3.  If not see
# <http://www.gnu.org/licenses/>.
#
# Fail if gcc/configure.ac grows a --with-* or --enable-* that is about a
# TARGET.
#
# THE RULE, and it is the whole design in one line:
#
#   Every --with and --enable in gcc/configure.ac is about the HOST (or, rarely,
#   the BUILD).  Never about a target.
#
# gcc/configure runs once, before any target is chosen; a multi-target compiler
# serves 183 of them.  An option that decides something about a target
# therefore decides it for all 183 at once, from an answer obtained by asking
# about none of them.  That is not a bug that shows up as a build failure --
# the option takes its default, the default is somebody's target, and every
# other target silently gets an answer that was never about it.  Options of
# that shape belong in target-specs/configure.ac, which runs per target, after
# the build, when the triple and the toolchain are both known.
#
# WHY A CHECK AND NOT A REVIEW NOTE.  The file was cut from 7982 lines to under
# 4000 by moving exactly this class of thing out.  Nothing stops it refilling,
# and a target-shaped option added tomorrow looks locally reasonable -- it is
# only wrong with respect to a rule that lives in someone's head.  This puts
# the rule in the tree.
#
# WHAT IT LOOKS AT.  Each AC_ARG_WITH/AC_ARG_ENABLE invocation, bounded by its
# own parentheses -- its help string and its action, and nothing after them --
# and reports the option if that text mentions the target: $target,
# $target_os, $target_cpu, $target_alias, $target_header_dir, $cpu_type, or a
# triple glob like `*-*-linux*'.
#
# A REAL must-hit, in addition to the synthetic ones below: run this against
# target-specs/configure.ac and it reports several options, correctly, because
# that file is ENTIRELY about targets.  Two files, opposite expected answers,
# one scanner.  That is the pair rule 17 asks for -- the interesting case and
# the uninteresting one, constructed before either was run.
#
#   sh gcc/check-host-only-flags.sh gcc/configure.ac            # expect ok
#   sh gcc/check-host-only-flags.sh target-specs/configure.ac   # expect hits
#
# WHAT IT CANNOT SEE, said plainly so nobody reads a pass as more than it is:
# an option whose target logic is elsewhere -- it sets a plain variable here
# and a `case $target' 400 lines down consumes it.  This finds the shape, not
# the semantics.  A green run means "no option in this file names a target
# near itself", which is a lower bound on cleanliness, not a proof of it.

set -e

configure_ac=${1:-`dirname "$0"`/configure.ac}

if test ! -f "$configure_ac"; then
  echo "check-host-only-flags: $configure_ac: not found" >&2
  exit 2
fi

# The scanner, as a function, so the controls below run the SAME code as the
# real corpus rather than a re-derivation of it.  A control that exercises a
# copy of the checker is a control over the copy.
scan () {
  awk '
    # The body of an option is its own AC_ARG_* invocation -- help string and
    # action -- and NOTHING else.  An earlier version took "everything up to
    # the next AC_ARG_*", which swallowed hundreds of unrelated lines and
    # reported eleven options of which zero were defects: --shared was blamed
    # for a case over $target six hundred lines below it.  A window that wide
    # reports the FILE, not the option.
    #
    # The end of the invocation is found by counting parentheses from the
    # opening one, not by looking for a literal close-bracket-paren or the
    # next blank line: those are rules for deriving an extent, and a
    # derivation rule is code that can be wrong in ways nothing else here
    # would notice.
    /AC_ARG_WITH[[(]|AC_ARG_ENABLE[[(]/ && depth == 0 {
      line = NR
      opt = $0
      sub(/.*AC_ARG_(WITH|ENABLE)[[(]+/, "", opt)
      sub(/[],)].*/, "", opt)
      body = ""
      depth = 0
      rest = $0
      sub(/.*AC_ARG_(WITH|ENABLE)/, "", rest)
      collect(rest)
      next
    }
    depth > 0 { collect($0) }
    END { if (depth > 0) emit() }

    function collect(s,   i, c) {
      body = body "\n" s
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "(") depth++
        else if (c == ")") {
          depth--
          if (depth <= 0) { emit(); depth = 0; return }
        }
      }
    }

    function emit(   why) {
      why = ""
      if (body ~ /\$\{?target(_os|_cpu|_alias|_header_dir)?\}?[^a-zA-Z_]/) why = "names $target"
      else if (body ~ /\$\{?cpu_type\}?[^a-zA-Z_]/)                       why = "names $cpu_type"
      else if (body ~ /\*-\*-/)                                           why = "matches a target triple"
      if (why != "") printf "%s:%d: --%s: %s\n", FILENAME, line, opt, why
      opt = ""
    }
  ' "$1"
}

# --- Controls.  Two-sided, and BOTH drawn from outside the corpus, because a
# control taken from gcc/configure.ac can only ever exhibit the failure mode
# that file happens to have.  The must-miss matters more than the must-hit
# here: the cheap way to write this check is a grep for the word "target",
# which fires on every option whose help text merely mentions targets in prose,
# and a checker that cries wolf gets switched off.
ctl=`mktemp -d`
trap 'rm -rf "$ctl"' 0

cat > "$ctl"/must-hit.ac <<'EOF'
AC_ARG_WITH(fictional-thing,
[AS_HELP_STRING([--with-fictional-thing=X], [pick a thing])],
[case $target in
   powerpc*-*-*) fictional=$withval ;;
 esac])
EOF

cat > "$ctl"/must-miss.ac <<'EOF'
AC_ARG_ENABLE(fictional-host-thing,
[AS_HELP_STRING([--enable-fictional-host-thing],
   [build the host compiler with the thing, for every target it serves])],
[fictional_host_thing=$enableval], [fictional_host_thing=no])
if test x"$fictional_host_thing" = xyes; then
  AC_DEFINE(FICTIONAL, 1, [Define if the host has the thing.])
fi
EOF

hit=`scan "$ctl"/must-hit.ac`
miss=`scan "$ctl"/must-miss.ac`

status=0
if test -z "$hit"; then
  echo "check-host-only-flags: CONTROL FAILED: the must-hit fixture was not reported." >&2
  echo "  The checker cannot see the defect it exists to find; a pass below means nothing." >&2
  status=2
fi
if test -n "$miss"; then
  echo "check-host-only-flags: CONTROL FAILED: the must-miss fixture was reported:" >&2
  echo "$miss" >&2
  echo "  A host option whose PROSE mentions targets must not trip this." >&2
  status=2
fi
test $status -eq 0 || exit $status

# --- The real corpus.
bad=`scan "$configure_ac"`

if test -n "$bad"; then
  echo "$bad" >&2
  echo "" >&2
  echo "check-host-only-flags: the options above are about a TARGET." >&2
  echo "  gcc/configure.ac is host (and build) configuration only.  A question" >&2
  echo "  about a target's toolchain, triple or C library belongs in" >&2
  echo "  target-specs/configure.ac, which runs once per target after the build." >&2
  echo "  If one of these really is a host question that merely mentions a" >&2
  echo "  triple, say so in a comment beside it and widen the must-miss fixture" >&2
  echo "  in this script to cover the shape -- do not just delete the report." >&2
  exit 1
fi

echo "check-host-only-flags: ok -- no --with/--enable in $configure_ac names a target."
exit 0
