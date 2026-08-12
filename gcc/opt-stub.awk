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
# The padding carries NO data.  A stub gets `Undocumented' and nothing else: no
# Var(), no Mask(), no Init(), no Alias().  That is deliberate -- Mask() bits
# are the half of the option container that must NOT be unioned (the union of
# every back end's masks overflows the 32-bit target_flags and opth-gen.awk
# says so with `#error too many target masks'), and Alias() or Ignore() would
# comment the enumerator out in one header and not the other, reintroducing an
# asymmetry at the level this is meant to remove it.
#
# A stub is thus a name and a code with no behaviour, which is exactly what a
# back end that is not the selected one should offer.
#
# AND A STUB DECLARES NO `struct gcc_options' MEMBER.  That is what the absence
# of `Target' above is for, and it is the whole of this file's second bug fix;
# the flag word used to read `Target Undocumented'.
#
# opt-functions.awk's needs_state_p() is `Target && !Alias && !Ignore', and
# static_var() gives every option that needs state without a Var() or a Mask()
# a private member named VAR_<sanitized name>.  A stub therefore used to
# fabricate a member -- a member DERIVED FROM THE STUB'S OWN FLAG WORD rather
# than from the real option's.  Both halves of the options machinery then read
# the same name off two different authorities, which is this branch's standing
# bug wearing an options-generator costume, and it surfaced from both sides:
#
#   * TYPE.  var_type() answers `const char *' for a Joined option with no
#     Var() and `int ' for a bare one.  rs6000 spells `mdebug=' as `Target
#     RejectNegative Joined', so its own part of gcc-options-union.list
#     declares VAR_mdebug_ as `const char *' while every other back end's stub
#     declared the same member as `int ' -- caught, by name, as
#       opth-gen.awk: gcc-options-union.list: member VAR_mdebug_ declared
#       twice, differently
#     Measured, both by configuring the pair and by re-running the pipeline
#     with this file at its previous revision: VAR_mdebug_ (x86_64 +
#     powerpc64le) and VAR_msilicon_errata_warn_ (x86_64 + msp430).  Any
#     Joined-without-Var option shared by two configured back ends reaches it,
#     so it spreads as more pairs configure.
#
#     NOT every "declared twice, differently" is this bug, and the difference
#     matters because the other kind is not fixable here.  x86_64 +
#     loongarch64 fails on `recip_mask', which is a `Variable' record in BOTH
#     i386.opt (`int recip_mask = RECIP_MASK_DEFAULT') and loongarch.opt
#     (`unsigned int recip_mask = 0') -- two real declarations by two real
#     back ends of one name with two types, with no placeholder involved at
#     all (this file reserves `Variable' and never emits one).  That is the
#     same family -- one name, several authorities -- but the authorities are
#     the .opt files, so the fix is to qualify the name there, and that is a
#     decision about which back end gets renamed rather than a generator bug.
#     The guard reporting it is working.
#
#   * EXISTENCE.  vxworks.opt spells `Bdynamic' as `Driver' -- no Target, so
#     no member at all -- and `mrtp' as `Target ... Mask(VXWORKS_RTP)
#     Var(vxworks_flags)', whose state is the Var, again no VAR_ member.  A
#     stub gave both of them one.  The shared options.cc is a POSITIONAL brace
#     initializer built from the shared optionlist, which is stubbed, while
#     options.h takes its layout from the union list; the stub-only members
#     VAR_Bdynamic and VAR_mrtp were in the initializer and not in the struct,
#     the initializer shifted, and an enum landed on a `const char *'.  That
#     one does not fail by name -- the two lists are compared by nobody --
#     which is why it had already happened in another build directory and gone
#     unremarked.
#
# Reproducing the real option's flag word instead is not the fix: the flags
# that determine a member's type are exactly the flags that carry data.
# Enum(x) resolves through enum_type[], which a stub's back end does not have
# -- that is how a stub once emitted a typeless `x_aarch64_early_ra;', a legal
# `int' -- and Mask()/Var() are the data this file exists not to copy.
#
# The member is not needed anyway, and that is the point.  `struct gcc_options'
# gets its layout from gcc-options-union.list, which already carries the real
# member from the one back end that really declares it; options-<base>.h emits
# every union member regardless of base.  A stub-declared member was therefore
# never anything but a duplicate of a member the union already had, differing
# from it in type or existing where the union had none.  Dropping `Target'
# removes the duplicate and changes no ordinal: liveness of the enumerator is
# decided by Ignore/Alias alone (see suppressed() below), not by Target.
#
# What a stub does lose with `Target' gone is its CL_TARGET bit, so find_opt()
# no longer matches it and `-mrtp' on an i386-selected compiler is diagnosed as
# unrecognised rather than silently accepted and dropped.  That is the better
# of the two behaviours and it is the one a back end that is not selected
# should offer.  An option with no Var, no Mask and no state is not a new shape
# for the consumers: every `Driver'-only option upstream already has it.

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

# True when opth-gen.awk would comment this option's enumerator out.  This is
# opth-gen.awk's own condition, kept in step with it deliberately; flag_set_p
# comes from opt-functions.awk, which the make rule loads before this file so
# that the two cannot drift apart in how a flag is recognised.
function suppressed(flags)
{
	if (flag_set_p("Ignore", flags))
		return 1
	if (flag_set_p("Alias.*", flags) && !flag_set_p("SeparateAlias", flags))
		return 1
	return 0
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
	if (is_option($1)) {
		vocabulary[$1] = 1
		# Accumulate the flags of every record with this name, the way
		# opth-gen.awk merges consecutive identical options.  Only one
		# thing is read back out of them: whether the name gets a live
		# enumerator.  See the END block.
		vflags[$1] = vflags[$1] " " $2
	}
	next
}

# Everything else: what this consumer already has.
{
	own[$1] = 1
	# Which C identifiers this consumer's OWN options already claim.  Two
	# different option names can sanitise to one identifier -- see the
	# collision note in the END block.
	claimed[opt_sanitized_name($1)] = 1
}

END {
	if (failed)
		exit 1
	# How many placeholders would want each C identifier.  `enum opt_code'
	# names are the option name with every non-alphanumeric character turned
	# into `_', so DIFFERENT options can want the SAME enumerator:
	# rs6000 spells one `-mlong-double-' and avr spells another
	# `-mlong-double=', and both become OPT_mlong_double_.  A single-target
	# build never sees both, so the clash has always been latent; padding
	# every header up to the union is what makes them meet.
	for (name in vocabulary)
		if (!(name in own))
			want[opt_sanitized_name(name)]++

	n = 0
	for (name in vocabulary)
		if (!(name in own)) {
			# LIVENESS IS PART OF THE VOCABULARY, not part of the
			# data, and a placeholder has to reproduce it.
			# opth-gen.awk gives no enumerator to an alias or an
			# Ignore-d option -- it emits the line commented out --
			# but the ordinal is still consumed, so this does not
			# move any number.  What it does prevent is a
			# REDEFINITION: v850 spells `-msda-' as
			# `Alias(msda=)', and both names sanitise to
			# `OPT_msda_'.  In v850's own header one of the pair is
			# a comment.  An unconditionally live placeholder made
			# both of them enumerators in the other 45 headers, and
			# `redefinition of OPT_msda_' is a compile error --
			# which is how another agent's build hit this before I
			# did.  Same for -Wlarger-than-, -Wshadow-local,
			# -finline-limit- and -ftemplate-depth-.
			#
			# The rule for a clash is the same one the rest of this
			# file follows: a placeholder never takes anything from
			# the back end that really owns the name.  If this
			# consumer already claims the identifier, or if two
			# placeholders want it, the placeholder gives it up.
			# The ordinal is still consumed either way -- that is
			# the whole point of suppression rather than omission --
			# so the numbering is untouched, and the enumerator ends
			# up live in exactly the header whose back end declares
			# the option.
			e = opt_sanitized_name(name)
			# No `Target': see the long note at the top.  With it,
			# needs_state_p() is true and static_var() fabricates a
			# VAR_<name> member whose type comes from the STUB's
			# flags rather than the real option's.
			flags = "Undocumented"
			if (suppressed(vflags[name]) || (e in claimed) || want[e] > 1)
				flags = flags " Ignore"
			print name SUBSEP flags
			n++
		}
	# The caller counts the lines it got; a silent zero here would be
	# indistinguishable from "nothing ran", which is the failure shape that
	# has cost this project real time.  See the `wc -l' in the make rules.
}
