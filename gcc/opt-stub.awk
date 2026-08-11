#  Copyright (C) 2026 Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING3.  If not see
# <http://www.gnu.org/licenses/>.

# Emit placeholder option records for every option name that is in the
# VOCABULARY list but not in the consumer's own list.
#
# Usage: awk -f opt-stub.awk -v vocab=FILE FILE own-optionlist > stubs
#
# The vocabulary file is named explicitly rather than being inferred from
# `FNR == NR'.  That idiom silently inverts the two roles when the first file
# is empty -- awk never opens it, so the SECOND file is the one where FNR ==
# NR -- and the result is that every option the consumer has is emitted as a
# stub.  An empty vocabulary is exactly what a mis-set make variable produces,
# so the failure would have been both easy to reach and hard to read.
#
# Why this exists.  `enum opt_code' is generated from whatever .opt files the
# consumer was handed, and its ordinals are simply the rank of each option name
# in the sorted list -- an alias, which opth-gen.awk emits commented out, still
# consumes an ordinal, so the ordinals depend on the SET OF NAMES and on
# nothing else.  A build that generates more than one such header therefore
# gets more than one numbering, and a value produced against one and consumed
# against another silently means a different option.  In a multi-target build
# the shared options.h is generated from the primary target's extra_opt_files
# while each options-<base>.h is generated from its own back end's, so every
# back end's `option_optimization_table' -- built against options-<base>.h and
# read by opts.cc, built against options.h -- was mis-decoded.
#
# The fix is the same one used for machine modes: union the vocabulary, keep
# the data per configuration.  Every consumer is padded up to the union of all
# names, so one option name has one code everywhere.
#
# The padding carries NO data.  A stub gets `Target Undocumented' and nothing
# else: no Var(), no Mask(), no Init(), no Alias().  That is deliberate --
# Mask() bits are the half of the option container that must NOT be unioned
# (the union of every back end's masks overflows the 32-bit target_flags and
# opth-gen.awk says so with `#error too many target masks'), and Alias() or
# Ignore() would comment the enumerator out in one header and not the other,
# reintroducing an asymmetry at the level this is meant to remove it.
#
# A stub is thus a name and a code with no behaviour, which is exactly what a
# back end that is not the selected one should offer.

BEGIN {
	FS = SUBSEP
	# No `print > "/dev/stderr"' anywhere in here.  $(AWK) is whichever awk
	# configure found, and that redirection is not universally available;
	# the count that matters is taken with `wc -l' by the make rule, which
	# also distinguishes "zero stubs" from "the script never ran".
	if (vocab == "") {
		print "; opt-stub.awk: -v vocab=FILE is required"
		failed = 1
		exit 1
	}
}

BEGIN {
	# An optionlist holds more than options.  opt-read.awk dispatches on the
	# first field: these words introduce a declaration, and a record whose
	# first field is `Mask(X)' (or `InverseMask(X)') declares a mask bit with
	# no option attached to it.  NONE of them takes an `enum opt_code'
	# ordinal, so leaving them out cannot perturb the numbering -- and
	# putting them IN is actively destructive:
	#
	#   * a `Mask(X)' placeholder allocates a target_flags bit in a back end
	#     that never asked for one.  Stubbing every back end's bare masks
	#     into every header took options.h from 2 guarded #errors to a
	#     3rd, UNGUARDED `#error too many target masks`, with sparc's
	#     MASK_V9 sitting at bit 48 of a 32-bit word -- i.e. it performed
	#     exactly the union of the DATA that this whole design forbids.
	#   * a `TargetVariable' placeholder would declare a variable named
	#     after the placeholder's own flag text.
	reserved["Language"] = 1
	reserved["TargetSave"] = 1
	reserved["Variable"] = 1
	reserved["TargetVariable"] = 1
	reserved["HeaderInclude"] = 1
	reserved["SourceInclude"] = 1
	reserved["Enum"] = 1
	reserved["EnumValue"] = 1
}

function is_option(name)
{
	if (name in reserved)
		return 0
	if (name ~ /^Mask\(/ || name ~ /^InverseMask\(/)
		return 0
	return 1
}

FNR == 1 { nfile++ }

# The vocabulary is the first file AND the one named by -v vocab=.  Both
# conditions are needed: the position alone is wrong when the vocabulary file
# is empty (awk never opens it, so the consumer's file becomes the first one
# seen), and the name alone is wrong when the same path is passed twice.
nfile == 1 && FILENAME == vocab {
	if (is_option($1))
		vocabulary[$1] = 1
	next
}

# Everything else: what this consumer already has.
{ own[$1] = 1 }

END {
	if (failed)
		exit 1
	n = 0
	for (name in vocabulary)
		if (!(name in own)) {
			print name SUBSEP "Target Undocumented"
			n++
		}
	# The caller counts the lines it got; a silent zero here would be
	# indistinguishable from "nothing ran", which is the failure shape that
	# has cost this project real time.  See the `wc -l' in the make rules.
}
