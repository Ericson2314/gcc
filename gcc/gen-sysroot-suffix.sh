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

# Produce a target's sysroot-suffix header from the multilib data extracted by
# gen-multilib-data.sh, replacing the empty placeholder that stood in while
# that data did not exist.
#
# Only the generic generator, config/print-sysroot-suffix.sh, can be run here,
# and the distinction is not cosmetic:
#
#   - The generic script is a pure transformation of MULTILIB_OSDIRNAMES,
#     _OPTIONS, _MATCHES and _REUSE.  Given the data it produces the same answer
#     anywhere, so it belongs on the build side.
#   - config/m68k/print-sysroot-suffix.sh and config/bfin/print-sysroot-suffix.sh
#     each `test -d "$sysroot/$dir"', probing the build machine's filesystem for
#     directories under a target sysroot.  A multi-target build has no single
#     sysroot to point them at, exactly as it has no answer for the multiarch
#     wildcard probe.  Those two have to be answered after the build, against a
#     real sysroot, which is target-specs/'s job -- so they are left empty here
#     rather than being fed a guess.
#
# Usage: gen-sysroot-suffix.sh TARGET MANIFEST MULTILIB SRCDIR

set -e

target=$1
manifest=$2
multilib=$3
srcdir=$4

field () {
  awk -v T="$target" -v K="$1" '
    $0 == "target " T { f = 1; next }
    /^target /        { f = 0 }
    f && $1 == K      { $1 = ""; sub(/^ /, ""); print; exit }
  ' "$2"
}

tmake=`field tmake_file "$manifest"`

case " $tmake " in
  *" t-sysroot-suffix "*) ;;
  *)
    echo "/* $target does not use config/t-sysroot-suffix.  If it has a"
    echo "   sysroot suffix at all it comes from a generator that probes the"
    echo "   filesystem, which this build cannot do; see gen-sysroot-suffix.sh."
    echo "   Empty is the honest answer here, not a placeholder.  */"
    exit 0
    ;;
esac

osdirnames=`field multilib_osdirnames "$multilib"`
options=`field multilib_options "$multilib"`
matches=`field multilib_matches "$multilib"`
reuse=`field multilib_reuse "$multilib"`

# Invoked through ${CONFIG_SHELL}, as t-sysroot-suffix does with $(SHELL):
# the script is not executable in the tree.
${CONFIG_SHELL-/bin/sh} "$srcdir/config/print-sysroot-suffix.sh" \
  "$osdirnames" "$options" "$matches" "$reuse"
