#! /bin/sh

# Copyright (C) 2001-2026 Free Software Foundation, Inc.
# This file is part of GCC.

# GCC is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.

# GCC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with GCC; see the file COPYING3.  If not see
# <http://www.gnu.org/licenses/>.  


# Generate gcc's various configuration headers:
# config.h, tconfig.h, bconfig.h, tm.h, libgcc_tm.h, and tm_p.h.
# $1 is the file to generate.  DEFINES, HEADERS, and possibly
# TARGET_CPU_DEFAULT are expected to be set in the environment.  A tm-*.h
# output additionally requires INSN_BASE, the back end whose insn-flags and
# insn-modes headers it should include; see the case on $output below.

if [ -z "$1" ]; then
    echo "Usage: DEFINES='list' HEADERS='list' \\" >&2
    echo "  [TARGET_CPU_DEFAULT='default'] mkconfig.sh FILE" >&2
    exit 1
fi

output=$1
rm -f ${output}T

# This converts a file name into header guard macro format.
hg_sed_expr='y,abcdefghijklmnopqrstuvwxyz./-,ABCDEFGHIJKLMNOPQRSTUVWXYZ___,'
header_guard=GCC_`echo ${output} | sed -e ${hg_sed_expr}`

# Add multiple inclusion protection guard, part one.
echo "#ifndef ${header_guard}" >> ${output}T
echo "#define ${header_guard}" >> ${output}T

# A special test to ensure that build-time files don't blindly use
# config.h.
if test x"$output" = x"config.h"; then
  echo "#ifdef GENERATOR_FILE" >> ${output}T
  echo "#error config.h is for the host, not build, machine." >> ${output}T
  echo "#endif" >> ${output}T
fi

# Define TARGET_CPU_DEFAULT if the system wants one.
# This substitutes for lots of *.h files.
if [ "$TARGET_CPU_DEFAULT" != "" ]; then
    echo "#define TARGET_CPU_DEFAULT ($TARGET_CPU_DEFAULT)" >> ${output}T
fi

# Provide defines for other macros set in config.gcc for this file.
for def in $DEFINES; do
    echo "#ifndef $def" | sed 's/=.*//' >> ${output}T
    echo "# define $def" | sed 's/=/ /' >> ${output}T
    echo "#endif" >> ${output}T
done

# Linker capabilities that target headers test with #ifdef while composing
# spec strings.  These used to come from configure probes of one linker, via
# auto-host.h, which is included before any target header.  A multi-target
# compiler has no such linker to probe, and with the macros simply gone every
# one of those guards was silently false -- config/freebsd.h, netbsd.h,
# netbsd-elf.h, openbsd.h, dragonfly.h, sol2.h, alpha/elf.h, alpha/linux.h,
# arm/uclinux-elf.h, rs6000/freebsd64.h and i386/linux-common.h between them
# dropped --eh-frame-hdr, --as-needed, -Bstatic/-Bdynamic, -pie and
# --push-state from their link specs, with no diagnostic anywhere.
#
# The guards run while this header is being processed, long before defaults.h,
# so they cannot be defaulted there; they are emitted here instead, ahead of
# the target headers, which is where auto-host.h used to supply them.
#
# Every linker these targets can be linked by has these features.  A linker
# that does not, or spells an option differently, is answered by
# target-specs/configure probing the real linker and overriding the resulting
# spec -- not by the driver silently omitting the option.
#
# THE LIST ABOVE WAS NOT THE WHOLE POPULATION, and the two names added below
# are not spec strings -- they select CODEGEN.  Measured in a 48-back-end build
# (/tmp/b-ad1798a2b26398cc6-48) by preprocessing the REAL chain, not by reading
# the sources, `cpp -dM -DIN_GCC' on the generated `tm-rs6000.h':
#
#     #define TARGET_CMODEL RS6000_CMODEL_SMALL      <- the #else branch
#     #define SET_CMODEL(opt) do {} while (0)        <- the #else branch
#     #define DOT_SYMBOLS 1                          <- the #else branch
#     #define HAVE_LD_LARGE_TOC (targ_caps.ld_large_toc)
#     #define HAVE_LD_NO_DOT_SYMS (targ_caps.ld_no_dot_syms)
#
# The last two lines are the trap: defaults.h DOES redirect both to their
# runtime `targ_caps' values, so a reader who greps for the conversion finds it
# present and correct.  But defaults.h is appended LAST, and
# `config/rs6000/linux64.h:66' tests `#ifdef HAVE_LD_LARGE_TOC' while the chain
# is still being read -- so the guard had already been taken the other way.
# The conversion is real, and it lands too late to be seen.
#
# Consequence, powerpc64: `SET_CMODEL' discards its argument, so `-mcmodel='
# is silently a no-op, and `TARGET_CMODEL' is frozen at RS6000_CMODEL_SMALL
# rather than following `rs6000_current_cmodel' -- which exists, is a real
# option variable (`global_options.x_rs6000_current_cmodel'), and is now both
# never written and never read.  `DOT_SYMBOLS' likewise loses the ELFv2 local
# entry-point form.
#
# INVISIBLE TO EVERY MEASUREMENT THIS BRANCH HAS TAKEN: `tm-i386.h' contains
# ZERO occurrences of HAVE_LD_LARGE_TOC, and aarch64 none either, so the
# configured pair cannot express the bug.  This is the `correct by luck on
# i386 + aarch64' class named in PRINCIPLES section 1, caught only by building
# a third back end that has the guard.
#
# WHOSE ANSWER IS THIS FLOOR?  (PRINCIPLES section 2a requires stating it.)
# Upstream's own, for rs6000 standing alone: both features have been in every
# binutils that can link powerpc64 for many years, and upstream's configure
# probe returns yes for them on any such linker.  It is NOT the primary's
# answer -- i386 has no opinion on either macro and never tests them.  A
# linker that genuinely lacks them is answered the same way the four above
# are: target-specs/configure probes the real linker, and defaults.h's
# redirect -- which survives this, exactly as HAVE_LD_PIE's does -- carries
# that answer to every consumer that reads the macro as a VALUE rather than as
# an `#ifdef'.
case $output in
    tm.h | tm-*.h )
	cat >> ${output}T <<EOF
#ifndef HAVE_LD_EH_FRAME_HDR
# define HAVE_LD_EH_FRAME_HDR 1
#endif
#ifndef HAVE_LD_AS_NEEDED
# define HAVE_LD_AS_NEEDED 1
#endif
#ifndef HAVE_LD_PIE
# define HAVE_LD_PIE 1
#endif
#ifndef HAVE_LD_PUSHPOPSTATE_SUPPORT
# define HAVE_LD_PUSHPOPSTATE_SUPPORT 1
#endif
#ifndef HAVE_LD_LARGE_TOC
# define HAVE_LD_LARGE_TOC 1
#endif
#ifndef HAVE_LD_NO_DOT_SYMS
# define HAVE_LD_NO_DOT_SYMS 1
#endif
EOF
    ;;
esac

# The first entry in HEADERS may be auto-FOO.h ;
# it wants to be included even when not -DIN_GCC.
# Postpone including defaults.h until after the insn-*
# headers, so that the HAVE_* flags are available
# when defaults.h gets included.
postpone_defaults_h="no"
if [ -n "$HEADERS" ]; then
    set $HEADERS
    case "$1" in auto-* )
	echo "#include \"$1\"" >> ${output}T
	shift
	;;
    esac
    if [ $# -ge 1 ]; then
	echo '#ifdef IN_GCC' >> ${output}T
	for file in "$@"; do
	    if test x"$file" = x"defaults.h"; then
		postpone_defaults_h="yes"
	    else
		echo "# include \"$file\"" >> ${output}T
	    fi
	done
	echo '#endif' >> ${output}T
    fi
fi

# If this is a tm header, now include insn-flags.h only if IN_GCC is defined
# but neither GENERATOR_FILE nor USED_FOR_TARGET is defined.  (Much of this
# is temporary.)
#
# Multi-target: the per-back-end copies are called tm-<base>.h, and they need
# the same tail as tm.h -- otherwise they are not drop-in replacements for it
# and anything compiled against one is missing the insn-* declarations.  The
# files named have to be that back end's own: insn-flags.h and insn-modes.h
# are generated from a machine description, so the copies in the build root
# describe whichever target the build was configured for.  Naming those from a
# tm-<base>.h would hand every back end but one the wrong HAVE_* and the wrong
# mode enum.  It is only because the generators define GENERATOR_FILE, and so
# skip both, that this has not bitten yet.

case $output in
    tm.h )
	insn_flags_h=insn-flags.h
	insn_modes_h=insn-modes.h
	;;
    tm-*.h )
	# insn-flags and insn-modes are generated from a machine description, so
	# they exist once per BACK END.  The output name here is not always the
	# back end: gen-multi-target-md.awk also emits tm-<triple>.h, one per
	# configured triple, and deriving the base from the file name gave those
	# `insn-flags-x86_64_pc_linux_gnu.h' -- a file nothing generates and
	# nothing ever will.  It went unnoticed only because tm-<triple>.h has so
	# far been read exclusively by generators, which define GENERATOR_FILE and
	# skip both includes; the first ordinary object compiled against one dies
	# on a missing header.
	#
	# So the caller states the base, exactly as it already rewrites options.h
	# and insn-constants.h to the <base> names before calling us.  Inferring it
	# here cannot work: nothing in `tm-x86_64_pc_linux_gnu.h' says `i386'.
	if test x"$INSN_BASE" = x; then
	    echo "mkconfig.sh: ${output}: INSN_BASE is not set." >&2
	    echo "  A tm-*.h needs the BACK END it belongs to, which the file name" >&2
	    echo "  does not carry for per-triple headers.  Set INSN_BASE to the" >&2
	    echo "  back end (the same value used for options-<base>.h)." >&2
	    exit 1
	fi
	insn_flags_h=insn-flags-${INSN_BASE}.h
	insn_modes_h=insn-modes-${INSN_BASE}.h
	;;
    * )
	insn_flags_h=
	;;
esac

if test x"$insn_flags_h" != x; then
    cat >> ${output}T <<EOF
#if defined IN_GCC && !defined GENERATOR_FILE && !defined USED_FOR_TARGET
# include "${insn_flags_h}"
#endif
#if defined IN_GCC && !defined GENERATOR_FILE
# include "${insn_modes_h}"
#endif
EOF
fi

# A tm header is not usable without defaults.h -- it is where TARGET_UNIT and
# friends come from -- and it has to come last, after the insn-* headers.  The
# single-target tm_include_list ends with it; the per-back-end lists do not, so
# supply it here rather than let each caller remember.
case $output in
    tm.h | tm-*.h ) postpone_defaults_h="yes" ;;
esac

# If we postponed including defaults.h, add the #include now.
if test x"$postpone_defaults_h" = x"yes"; then
    echo "# include \"defaults.h\"" >> ${output}T
fi

# Add multiple inclusion protection guard, part two.
echo "#endif /* ${header_guard} */" >> ${output}T

# Avoid changing the actual file if possible.
if [ -f $output ] && cmp ${output}T $output >/dev/null 2>&1; then
    echo $output is unchanged >&2
    rm -f ${output}T
else
    mv -f ${output}T $output
fi

# Touch a stamp file for Make's benefit.
rm -f cs-$output
echo timestamp > cs-$output
