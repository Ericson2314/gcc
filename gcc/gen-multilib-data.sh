#! /bin/sh

# Copyright (C) 2026 Free Software Foundation, Inc.
# This file is part of GCC.
#
# GCC is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3, or (at your option) any later version.
#
# GCC is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along
# with GCC; see the file COPYING3.  If not see
# <http://www.gnu.org/licenses/>.

# Extract each target's multilib set into a sibling of multi-target.manifest.
#
# Why this is a shell script driving make, rather than more shell in
# configure: MULTILIB_OPTIONS, MULTILIB_MATCHES, MULTILIB_REUSE and
# MULTILIB_OSDIRNAMES are *make* variables.  Nothing in config.gcc assigns
# them; they are set by the config/*/t-* fragments named in each target's
# tmake_file, and a fragment can compute one from another or from
# TM_MULTILIB_CONFIG.  The only way to learn what a target's multilib set
# actually is, is to let make evaluate that target's fragments.
#
# It runs at configure/make time and not in target-specs/ on purpose: this
# data is derived from the source tree, not probed from an installed
# assembler or linker, so it is knowable without the target toolchain and
# belongs on this side of the split.
#
# The fragments are not self-contained: they use variables that gcc/Makefile.in
# supplies.  m68k/t-mlibs computes its multilib set by shelling out to $(AWK)
# over m68k-devices.def and then checks the answer against
# $(target_cpu_default), so a stub that omits either gets `make: BEGIN { FS=...
# }: No such file or directory' -- make trying to run the awk *program* as a
# command -- or a spurious "default cpu '' is not in multilib set ''".  Anything
# else a fragment turns out to need has to be passed in the same way.
#
# Usage: gen-multilib-data.sh MANIFEST SRCDIR MAKE AWK

set -e

manifest=$1
srcdir=$2
make=${3-make}
awk_prog=${4-awk}

if test ! -f "$manifest"; then
  echo "$0: no such manifest: $manifest" >&2
  exit 1
fi

tmp=tmp-multilib-stub.mk

echo "# Generated from $manifest; do not edit."
echo "# One stanza per target: the multilib set its tmake_file fragments define."

# Read the manifest one stanza at a time.  Blank line ends a stanza.
target= tmake= tmconf= tcd= seen_present=
emit () {
  test -n "$target" || return 0

  # A manifest written by a configure older than the tmake_file_present field
  # would leave $tmake empty, and an empty fragment list evaluates perfectly
  # happily to an empty multilib set -- "this target has no multilibs", stated
  # confidently, for all 188 of them.  Refuse instead: the field is not
  # optional, and a stale configure is exactly the window in which this would
  # otherwise pass silently.
  if test -z "$seen_present"; then
    echo "$0: $manifest has no tmake_file_present for $target;" >&2
    echo "  re-run configure -- the manifest predates that field." >&2
    exit 1
  fi

  # tmake_file_present is tmake_file with the fragments that do not exist
  # dropped -- tmake_file names some that do not (sh-unknown-elf asks for
  # sh/t-elf), and `include' of a missing file is a hard error in make.
  # configure already knows which exist, so it records the filtered list and
  # this script does not repeat the test.
  {
    echo "srcdir = $srcdir"
    echo "AWK = $awk_prog"
    echo "target_cpu_default = $tcd"
    echo "TM_MULTILIB_CONFIG = $tmconf"
    # Expand `$(call if_multiarch,:<triplet>)' to its argument, which is the
    # opposite of what gcc/Makefile.in does.  There it is neutered, because
    # whether to *use* multiarch paths was decided by wildcard-probing the
    # build machine's sysroot and a multi-target compiler has no single answer.
    # But the arguments at those call sites are the multilib -> multiarch
    # osdirname mapping itself -- real per-target data -- and that is precisely
    # what is being extracted here.  Neutered, MULTILIB_OSDIRNAMES comes out
    # stripped of every triplet and the mapping is lost; expanded, the data is
    # complete and whether to use it stays a decision for later.
    echo 'if_multiarch = $(1)'
    for f in $tmake; do
      echo "include \$(srcdir)/config/$f"
    done
    # Tab-indented recipe lines.
    echo 'multilib-show:'
    # All eight inputs genmultilib takes, not just the five the sysroot-suffix
    # work needed.  Running genmultilib per target -- which is what turns this
    # data into the driver's multilib tables -- needs the whole argument list,
    # and a fragment that sets only MULTILIB_DIRNAMES or MULTILIB_REQUIRED
    # would otherwise silently produce a different multilib set than the one
    # the target actually has.
    printf '\t@echo "multilib_options $(MULTILIB_OPTIONS)"\n'
    printf '\t@echo "multilib_dirnames $(MULTILIB_DIRNAMES)"\n'
    printf '\t@echo "multilib_matches $(MULTILIB_MATCHES)"\n'
    printf '\t@echo "multilib_exceptions $(MULTILIB_EXCEPTIONS)"\n'
    printf '\t@echo "multilib_extra_opts $(MULTILIB_EXTRA_OPTS)"\n'
    printf '\t@echo "multilib_exclusions $(MULTILIB_EXCLUSIONS)"\n'
    printf '\t@echo "multilib_required $(MULTILIB_REQUIRED)"\n'
    printf '\t@echo "multilib_reuse $(MULTILIB_REUSE)"\n'
    printf '\t@echo "multilib_osdirnames $(MULTILIB_OSDIRNAMES)"\n'
    printf '\t@echo "multiarch_dirname $(MULTIARCH_DIRNAME)"\n'
  } > $tmp

  echo ""
  echo "target $target"
  # A fragment that cannot be evaluated is reported rather than silently
  # yielding an empty multilib set, which would look like "this target has no
  # multilibs" -- the confidently-wrong answer this whole exercise keeps
  # running into.
  if ! "$make" -s -f $tmp multilib-show 2>/dev/null; then
    echo "multilib_error 1"
    echo "$0: could not evaluate multilib fragments for $target" >&2
  fi

  target= tmake= tmconf= tcd= seen_present=
}

while IFS= read -r line; do
  case $line in
    "target "*)             target=${line#target } ;;
    "tmake_file_present "*) tmake=${line#tmake_file_present }; seen_present=1 ;;
    "tm_multilib_config "*) tmconf=${line#tm_multilib_config } ;;
    "target_cpu_default "*) tcd=${line#target_cpu_default } ;;
    "")                     emit ;;
  esac
done < "$manifest"
emit

rm -f $tmp
