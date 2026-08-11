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
# Fail if a spec file names a spec the driver never consults.
#
# WHY.  Three times now a spec has been emitted into every per-target spec file
# with nothing in the driver to read it, and each time the symptom was silence:
#
#   *link_eh            emitted for a while before LINK_COMMAND_SPEC referred to it
#   *link_as_needed     written by target-specs, no slot in the driver at all
#   *link_no_as_needed  likewise
#
# A spec file entry for an unknown name is not an error in read_specs -- it
# creates the spec and waits for someone to ask.  That is the right behaviour
# for a user's -specs= file and the wrong one for a file WE generate, where
# nobody asking means the value we worked out is thrown away.  A wrong value is
# eventually noticed; a value that goes nowhere is not.
#
# HOW A SPEC IS CONSUMED, which is the part that makes a naive check useless.
# There are THREE ways, and only one of them is a %(name) reference in gcc.cc:
#
#   1. %(name) from a driver spec string.       -- link_eh, asm_v, libgcc_nonstatic
#   2. the C variable it is registered against.  -- link_spec via %l, lib_spec via
#      %L, libgcc_spec via %G, sysroot_spec read directly by set_up_specs, ...
#   3. %(name) from a spec string in a SPEC FILE.  This is what EXTRA_SPECS is
#      for: mips declares `asm_abi_default_spec' and refers to it from its own
#      ASM_SPEC, i386 declares `cc1_cpu' and refers to it from its own CC1_SPEC.
#      Nothing in gcc.cc has heard of either.
#
# Checking only (1) flags some thirty live specs; adding (2) still flagged
# 90-odd EXTRA_SPECS names.  Getting the CORPUS right mattered more here than
# getting the pattern right.
#
# (2) is derived from gcc.cc rather than from a hand-written allowlist -- a list
# would go stale exactly the way the thing it is checking went stale.
#
# THE REFERENCE SET IS TREE-WIDE, NOT PER FILE, and that is a deliberate
# weakening.  sparc.h publishes `asm_relax' and refers to it from the ASM_SPEC
# of sparc-linux but not of sparc-elf, so a per-file rule calls it dead on four
# triples.  It is not dead: EXTRA_SPECS is a published vocabulary and a name a
# target declares may legitimately go unused on one of its triples.  The bug
# this check exists for has a sharper shape than that -- a name emitted into
# EVERY spec file and referred to from NOWHERE IN THE TREE.  All three real
# instances are of that shape.  Flagging the softer one would bury them.
#
# TWO KINDS OF NAME, AND THEY DESERVE DIFFERENT VERDICTS.  A spec we invent as
# a delivery mechanism (link_as_needed, link_eh, libgcc_nonstatic) is ours, and
# one that nothing reads is a bug in our plumbing -- an error.  A name that came
# out of a target header's EXTRA_SPECS is that target's published vocabulary,
# copied through verbatim; several are unreferenced in the tree today and that
# is the header's business, not the delivery mechanism's.  Those are reported as
# warnings.  gen-target-specs marks which is which with a `# EXTRA_SPECS:' line,
# so the classification comes from the producer rather than from a list here
# that would rot.
#
# Usage: check-spec-refs.sh GCC_CC TARGET_SPECS_AC SPECFILE...
#
# TARGET_SPECS_AC is target-specs/configure.ac, which is a reference source and
# not a checked file: it emits spec TEXT of its own (`*link_arch:' is written as
# %(link_arch_sun)), so a name can be live purely because target-specs refers to
# it.  Leaving it out of the corpus made sol2.h's link_arch_sun look dead.

set -e

gcc_cc=$1
shift
ts_ac=$1
shift

if test ! -f "$gcc_cc"; then
  echo "check-spec-refs: $gcc_cc not found" >&2
  exit 1
fi

work=`mktemp -d`
trap 'rm -rf "$work"' 0

# The name -> variable table, from the one place that defines it.
sed -n 's/^[ \t]*INIT_STATIC_SPEC[ \t]*(\"\([a-z_0-9]*\)\"[ \t]*,[ \t]*&\([a-zA-Z_0-9]*\)).*/\1 \2/p' \
  "$gcc_cc" > "$work"/table

if test ! -s "$work"/table; then
  echo "check-spec-refs: parsed no INIT_STATIC_SPEC entries from $gcc_cc;" \
       "the extraction is broken, not the tree" >&2
  exit 1
fi

# gcc.cc with the registration table and the variable DEFINITIONS removed, so
# that what is left is uses.  A declaration is not a use: link_as_needed was
# declared and registered and read by nothing, and that is the case to catch.
sed -e '/INIT_STATIC_SPEC/d' \
    -e 's/^static const char \*[ \t]*$//' \
    -e 's/^static const char \*\([a-zA-Z_0-9]*\)[ \t]*\(=.*\)\{0,1\}$//' \
    -e 's/^[ \t]*= .*//' \
    "$gcc_cc" > "$work"/uses

# Every %(name) written anywhere in the corpus -- the driver plus every spec
# file we are checking.  Built once; the check is then a set membership test.
#
# COMMENTS ARE STRIPPED FIRST, and that is not fastidiousness.  The comment on
# libgcc_nonstatic in gcc.cc explains itself with the words "%(link_as_needed)",
# and while that comment counted as a reference the check reported link_as_needed
# live no matter what the code did.  A prose mention of a spec is the single most
# likely thing to be written about a spec that nothing uses yet -- so counting
# comments makes the check weakest exactly where the bug lives.  Caught by a
# must-MISS that failed: link_eh calibrated correctly both ways and
# link_as_needed did not, and the asymmetry was one stray comment.
strip_comments () {
  awk '{
	 line = ""
	 while (1) {
	   if (inc) {
	     i = index($0, "*/")
	     if (i == 0) { $0 = ""; break }
	     $0 = substr($0, i + 2); inc = 0
	   }
	   i = index($0, "/*")
	   if (i == 0) { line = line $0; break }
	   line = line substr($0, 1, i - 1)
	   $0 = substr($0, i + 2); inc = 1
	 }
	 sub(/\/\/.*/, "", line)
	 print line
       }' "$1"
}

# Comment syntax is per language, and guessing wrong is worse than not
# stripping at all.  configure.ac line 495 is `/*) target_config_path=...' -- a
# shell CASE PATTERN -- and running the C stripper over it opened a comment that
# never closed, swallowing the rest of the file including the one reference to
# link_arch_sun.  The symptom was the warning list growing by exactly one name
# between two runs, which is the sort of anomaly worth stopping for.
refs_from () {
  for _rf in "$@"; do
    test -f "$_rf" || continue
    case $_rf in
      *.cc|*.h)  strip_comments "$_rf" ;;		# C: /* */ and //
      *.ac|*.m4) sed 's/\(^\|[ \t]\)dnl .*//' "$_rf" ;;	# autoconf: dnl
      *)         sed 's/^#.*//' "$_rf" ;;		# spec files: leading #
    esac
  done | grep -oh '%([a-z_0-9]*)' 2>/dev/null | sed 's/^%(//; s/)$//'
}

# reachable NAME -- true if anything in the corpus says %(NAME), or C code reads
# the variable NAME is registered against, or read_specs special-cases the name.
reachable () {
  _n=$1
  if grep -qx -- "$_n" "$work"/refs; then return 0; fi
  _v=`awk -v n="$_n" '$1==n{print $2; exit}' "$work"/table`
  if test -n "$_v" && grep -qw -- "$_v" "$work"/uses; then return 0; fi
  # read_specs handles `*link_command' by name rather than through the table
  # (gcc.cc: `if (! strcmp (suffix, "*link_command"))'), so a literal "*NAME"
  # in the driver is a fourth way of being consumed.  Without this, the one
  # spec whose whole job is to replace the link command reads as dead.
  if grep -q -- "\"\\*$_n\"" "$gcc_cc"; then return 0; fi
  return 1
}

# The reference set: the driver, target-specs' own emitted spec text, and every
# spec file being checked.
refs_from "$gcc_cc" > "$work"/refs
test -f "$ts_ac" && refs_from "$ts_ac" >> "$work"/refs
for f in "$@"; do
  test -f "$f" && refs_from "$f"
done >> "$work"/refs
sort -u "$work"/refs -o "$work"/refs

# --- Calibration.  Two-sided, and it runs before any verdict is issued. ------
# must-MISS: `link' is consumed through its C variable and no %(link), so it
#   exercises path 2; `linker' is consumed as %(linker), exercising path 1.
# must-HIT: a name nothing could possibly refer to.
for live in link linker; do
  if ! reachable "$live"; then
    echo "check-spec-refs: CALIBRATION FAILED -- '$live' is consumed by the" \
         "driver but this check calls it dead.  Refusing to report." >&2
    exit 1
  fi
done
if reachable spec_that_does_not_exist_xyzzy; then
  echo "check-spec-refs: CALIBRATION FAILED -- a nonexistent spec is called" \
       "reachable, so the check cannot fail.  Refusing to report." >&2
  exit 1
fi

# Path 3 gets its own two-sided calibration, because it is the path the spec
# files exercise and gcc.cc cannot: an EXTRA_SPECS name is defined and referred
# to only from spec files.  Without this, a bug that dropped the spec files from
# the reference set would pass everything above and then call every EXTRA_SPECS
# name dead -- which is how the first version of this check behaved.
printf '*zzz_user:\nsomething %%(zzz_calib_live) more\n\n' > "$work"/calib
refs_from "$work"/calib >> "$work"/refs
if ! reachable zzz_calib_live; then
  echo "check-spec-refs: CALIBRATION FAILED -- a spec referred to from a spec" \
       "file is called dead, so EXTRA_SPECS names cannot be judged." >&2
  exit 1
fi
if reachable zzz_calib_dead; then
  echo "check-spec-refs: CALIBRATION FAILED -- a spec referred to from nowhere" \
       "is called reachable.  Refusing to report." >&2
  exit 1
fi

# --- The actual check -------------------------------------------------------
: > "$work"/dead
: > "$work"/dead_extra
files=0
for f in "$@"; do
  test -f "$f" || continue
  files=`expr $files + 1`
  sed -n 's/^# EXTRA_SPECS: \([a-z_0-9]*\).*/\1/p' "$f" | sort -u > "$work"/extra
  sed -n 's/^\*\([a-z_0-9]*\):[ \t]*$/\1/p' "$f" | sort -u > "$work"/names
  while read -r n; do
    test -n "$n" || continue
    if ! reachable "$n"; then
      if grep -qx -- "$n" "$work"/extra; then
	echo "$n $f" >> "$work"/dead_extra
      else
	echo "$n $f" >> "$work"/dead
      fi
    fi
  done < "$work"/names
done

if test "$files" -eq 0; then
  echo "check-spec-refs: no spec files given; nothing checked" >&2
  exit 1
fi

if test -s "$work"/dead_extra; then
  echo "check-spec-refs: warning: EXTRA_SPECS names no spec refers to." \
       "These are published by the target header and copied through, so this" \
       "is that header's business, not the spec file's:" >&2
  awk '{print $1}' "$work"/dead_extra | sort -u | sed 's/^/  */' >&2
fi

if test -s "$work"/dead; then
  echo "check-spec-refs: spec(s) emitted that nothing consults:" >&2
  awk '{print "  *" $1 "  (first seen in " $2 ")"}' "$work"/dead \
    | sort -u >&2
  echo "check-spec-refs: add a %(name) reference, or read the registered" \
       "variable, or stop emitting it.  A generated spec nobody asks for is" \
       "a value thrown away silently." >&2
  exit 1
fi

echo "check-spec-refs: $files spec file(s), every name consulted by the driver"
