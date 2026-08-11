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
# Write one target's multilib tables as spec-file stanzas.
#
# WHY.  The driver's multilib tables come from multilib.h, which genmultilib
# writes ONCE, from the MULTILIB_* variables in force at the top of
# gcc/Makefile.in.  A multi-target build includes no single target's
# tmake_file, so those are the PRIMARY target's -- and the driver then answers
# with i386's multilib set no matter which target was selected:
#
#     -print-multi-lib on every target:   .;  64;@m64  32;@m32
#     aarch64-unknown-linux-gnu really:   mabi=lp64
#     mips64el-st-linux-gnu really:       mabi=n32/mabi=32/mabi=64
#
# 128 of 188 configured targets have a multilib set of their own.  This is not
# a reporting defect: multilib_select drives multilib_dir and multilib_os_dir,
# which are appended to every library search path, so the driver looks for
# libraries in directories belonging to another target.  Plausible output, no
# diagnostic -- the family this project exists to remove.
#
# Delivery is already solved: multilib, multilib_matches, multilib_exclusions
# and multilib_reuse are registered static specs, and gcc.cc builds each of
# them by simple concatenation of the corresponding multilib.h array
# (build_multilib_strings, gcc.cc:8745).  So a spec file stanza whose value is
# that concatenation is exactly equivalent to compiling the array in.
#
# What was missing is that multilib_select is genmultilib's OUTPUT, not raw
# data.  So this script runs genmultilib once per target, with that target's
# own MULTILIB_* values out of multi-target.multilib, and reduces the result.
#
# Usage: gen-multilib-specs.sh SRCDIR MULTILIBFILE TARGET
# Writes the stanzas for TARGET on stdout.

set -e

srcdir=$1
mlfile=$2
target=$3

if test ! -f "$mlfile"; then
  echo "$0: $mlfile not found" >&2
  exit 1
fi

# One field of one target's stanza.  Prints nothing if absent, which is
# different from the field being empty only in that both are empty here -- the
# distinction does not matter to genmultilib, which treats an empty argument as
# "this target sets nothing".
field () {
  awk -v t="$target" -v k="$1" '
    $1 == "target" { in_t = ($2 == t); next }
    in_t && $1 == k { $1 = ""; sub(/^ /, ""); print; exit }
  ' "$mlfile"
}

if ! awk -v t="$target" '$1=="target" && $2==t { found=1 } END { exit !found }' \
     "$mlfile"; then
  echo "$0: no stanza for $target in $mlfile" >&2
  exit 1
fi

# A target whose fragments could not be evaluated has multilib_error set.
# Emitting an empty multilib set for it would say "this target has no
# multilibs" with confidence, which is the answer this whole area keeps
# getting wrong.  Say nothing instead and let the built-in default stand.
if test -n "`field multilib_error`"; then
  echo "# $target: multilib fragments could not be evaluated; no stanzas." >&2
  exit 0
fi

ml_options=`field multilib_options`
ml_dirnames=`field multilib_dirnames`
ml_matches=`field multilib_matches`
ml_exceptions=`field multilib_exceptions`
ml_extra_opts=`field multilib_extra_opts`
ml_exclusions=`field multilib_exclusions`
ml_required=`field multilib_required`
ml_reuse=`field multilib_reuse`
ml_osdirnames=`field multilib_osdirnames`

# THE MULTIARCH TRIPLETS COME OFF HERE, AND THAT IS DELIBERATE.
#
# gen-multilib-data.sh records MULTILIB_OSDIRNAMES with `if_multiarch' EXPANDED
# -- so entries look like `../lib64:x86_64-linux-gnu' -- because it is
# preserving the multilib->multiarch mapping as data.  Its comment says so, and
# says the decision is for later.  This is later.
#
# gcc/Makefile.in neuters if_multiarch (it expands to nothing), which is what
# reproduces the stock default: --enable-multiarch defaulted to `auto' and only
# an explicit --enable-multiarch ever turned it on, ENABLE_MULTIARCH is now a
# target-header macro, and NO target header raises it.  So the triplets must
# come off here too, or every target would silently acquire a Debian-style
# library layout its libraries were not installed under, and every library
# search would go to a directory that does not exist.
#
# That would be a bug wearing the costume of a fix: the data is present and the
# decision is absent, and connecting them is precisely the wrong move.  When
# ENABLE_MULTIARCH becomes selectable per target, this strip becomes
# conditional on it and MULTIARCH_DIRNAME below stops being empty.
ml_osdirnames=`printf '%s\n' "$ml_osdirnames" \
  | sed 's/\([^ 	][^ 	]*\):[^ 	:]*/\1/g'`

# MULTIARCH_DIRNAME is passed empty for the same reason, matching
# Makefile.in's `$(if $(MULTILIB_OSDIRNAMES),,$(MULTIARCH_DIRNAME))' when
# multiarch is off.  -print-multiarch stays empty, which is its correct answer.
ml_multiarch=

tmp=`mktemp -d`
trap 'rm -rf "$tmp"' 0

if ! "${CONFIG_SHELL-/bin/sh}" "$srcdir/genmultilib" \
       "$ml_options" "$ml_dirnames" "$ml_matches" "$ml_exceptions" \
       "$ml_extra_opts" "$ml_exclusions" "$ml_osdirnames" "$ml_required" \
       "$ml_multiarch" "$ml_reuse" false yes > "$tmp/mlib.h" 2> "$tmp/err"; then
  echo "$0: genmultilib failed for $target" >&2
  sed 's/^/  /' "$tmp/err" >&2
  exit 1
fi

# Reduce one of multilib.h's `static const char *const NAME[] = { ... };'
# arrays to the single string gcc.cc's build_multilib_strings would have built
# from it: the elements concatenated, in order, with nothing between them.
join_array () {
  awk -v name="$1" '
    $0 ~ ("^static const char \\*const " name "\\[\\] = \\{") { inside = 1; next }
    inside && /^\};/ { exit }
    inside {
      line = $0
      while (match (line, /"[^"]*"/)) {
	s = substr (line, RSTART + 1, RLENGTH - 2)
	out = out s
	line = substr (line, RSTART + RLENGTH)
      }
    }
    END { print out }
  ' "$tmp/mlib.h"
}

# multilib_extra is a plain string, not an array.
extra=`sed -n 's/^static const char \*multilib_extra = "\(.*\)";$/\1/p' \
	 "$tmp/mlib.h"`

printf '# Multilib tables for %s, from its own MULTILIB_* fragments.\n' "$target"
printf '# Generated by gen-multilib-specs.sh; do not edit.\n\n'

printf '*multilib:\n%s\n\n' "`join_array multilib_raw`"
printf '*multilib_matches:\n%s\n\n' "`join_array multilib_matches_raw`"
printf '*multilib_exclusions:\n%s\n\n' "`join_array multilib_exclusions_raw`"
printf '*multilib_reuse:\n%s\n\n' "`join_array multilib_reuse_raw`"
printf '*multilib_extra:\n%s\n\n' "$extra"
