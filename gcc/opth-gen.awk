#  Copyright (C) 2003-2026 Free Software Foundation, Inc.
#  Contributed by Kelley Cook, June 2004.
#  Original code from Neil Booth, May 2003.
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

# This Awk script reads in the option records generated from 
# opt-gather.awk, combines the flags of duplicate options and generates a
# C header file.
#
# This program uses functions from opt-functions.awk and code from
# opt-read.awk.
# Usage: awk -f opt-functions.awk -f opt-read.awk -f opth-gen.awk \
#            < inputfile > options.h

# ---------------------------------------------------------------------
# THE SHARED `struct gcc_options' LAYOUT.
#
# There is exactly ONE `global_options' in the compiler, and until this it had
# the PRIMARY back end's layout while every other back end was compiled against
# its own options-<base>.h.  Measured in a two-target (i386 primary + aarch64)
# build dir before this change:
#
#     struct gcc_options members        i386 1709      aarch64 1861
#     identical leading run of names           0       (of 1709)
#	i386[0]    = x_ix86_stack_protector_guard_offset
#	aarch64[0] = x_selected_arch
#     shared member names                   1593, type disagreements 0
#     i386-only 116, aarch64-only 268, union 1977
#
# Not one field offset is shared -- the divergence starts at member ZERO -- so
# `aarch64_override_options' read `global_options+0x19e8' expecting
# `x_aarch64_branch_protection_string' and got an i386 field.  `sizeof' is
# 0x1c48, so the read is IN BOUNDS: nothing traps, it just xstrdup()s an
# integer.  There is no diagnostic available for that shape, which is why this
# has to be prevented by construction rather than caught.
#
# Two halves of this problem; only the second is new here.
#
#   * The option-name VOCABULARY -- which names exist, hence which `enum
#     opt_code' ordinal each gets -- was already unioned by optionlist-vocab
#     and opt-stub.awk.  `cl_options[]' and `enum opt_code' therefore ALREADY
#     agree between bases, and nothing below changes them.
#   * The STORAGE -- which members `struct gcc_options' has and in what order
#     -- did not agree, because a stub carries no Var() and so contributes an
#     `x_VAR_<option>' where the owning back end contributes its real
#     `x_aarch64_...'.  Both are real members of their own header; neither is
#     wrong; they simply sit at different offsets.
#
# So the union taken here is the union of the two MEMBER SETS, keeping both
# spellings.  It is emphatically NOT a union of the option DATA: no Mask() bit
# is ever moved between back ends (opt-stub.awk explains why -- the union of
# every back end's bare masks overflows a 32-bit `target_flags', and feeding
# the global vocabulary straight through this script produces an UNGUARDED
# `#error too many target masks').  A member costs storage and nothing else.
#
# Mechanics, the same three-flag shape as genconfig's insn-config.h union and
# genmodes' shared numbering:
#
#   -v list_mode=1 -v union_base=B    write this back end's member list
#   -v union_file=F -v union_base=B   read the union; emit ITS members, in ITS
#				      order, for every back end
#
# The union file is a concatenation of the per-base lists, primary first, and
# the order of first appearance is the layout.  That means the primary's own
# members keep their order and offsets and the other back ends' exclusive
# members are appended -- so this change costs the primary +268 members and
# moves none of them.
#
# ABSENCE IS NEVER AN ANSWER.  With -v union_file, this script FAILS if the
# union file does not name this back end, if it is empty, if it lacks a member
# this back end's own records require, or if two back ends declare the same
# member differently.  A `#ifndef'-style floor -- "emit my own member if the
# union has not got one" -- would turn every one of those into a silently
# divergent layout, which is precisely the bug being removed.
#
# In a single-target build no union file is passed, nothing below runs, and
# options.h is byte-identical to what it was.
#
# ----------------------------------------------------------------------------
# THE SAME DEFECT ONE LEVEL DOWN: `cl_optimization' AND `cl_target_option'
# ----------------------------------------------------------------------------
#
# Measured in the same two-target build dir, after `struct gcc_options' was
# unioned and while these two still were not:
#
#     cl_optimization    members   i386 544   aarch64 548
#     cl_target_option   members   i386  57   aarch64  26
#
# `cl_optimization' is the worse of the two: aarch64's is LARGER than the one
# the middle end allocates, so `cl_optimization_save' called from an aarch64
# translation unit writes PAST the end of the object.  `cl_target_option' is
# the in-bounds-but-wrong shape again, and it has a second edge the parent
# commit did not: `cl_target_option_save' calls `targetm.target_option.save',
# i.e. the back end writes into `ptr' through ITS header while options-save.cc
# reads it back through the primary's.
#
# THE INDEXING RELATION, because it is what makes this not the same one-move
# change as `struct gcc_options'.  Both structs end in
#
#     unsigned HOST_WIDE_INT explicit_mask[N];
#
# and NOTHING names a bit of it.  optc-save-gen.awk assigns bit (k,j) by
# WALKING its own category arrays -- var_opt_other, var_opt_int, var_opt_enum,
# var_opt_short, var_opt_char, var_opt_string, in that order, one bit per
# member, j wrapping into k every 64 -- in `cl_optimization_save', and repeats
# the identical walk in `cl_optimization_restore'.  So:
#
#   * the encoding is PRIVATE to options-save.cc.  Both ends of it are
#     generated from one optionlist in one file, so a change of walk order is
#     invisible as long as both ends change together.  It is not an ABI and
#     nothing outside that file may index it.
#   * what the two generators must agree on is the member SET, not the order:
#     this script sizes N from ITS list and optc-save-gen.awk fills k from ITS
#     list.  Sized here from the primary's list and filled there from a larger
#     one is an out-of-bounds write with no diagnostic.
#
# So positional indexing does not make the union unsafe -- it makes the union
# of the STRUCT ALONE insufficient.  Unioning the members here while
# options-save.cc still walks the primary's list would give every base one
# layout and then never save, restore, hash, compare or stream any other
# base's members: silently dropped state, which is a worse failure than the
# one being removed because it looks like it works.
#
# The fix is therefore in both scripts at once, off ONE list:
#
#   * the union list carries, in addition to the `struct gcc_options' member
#     records, the RAW option records (kind `R') of every option any base
#     flags Optimization, PerFunction or Save, the raw TargetSave declarations
#     (kind `D') and the TargetVariable names (kind `X').
#   * each consumer applies its OWN classification to those raw records, so
#     the two scripts cannot drift apart in how a type is bucketed -- which
#     they would if the list carried a category computed by one of them.
#   * extras append to the END of the category they fall in, so within a
#     category the primary's members keep their order.  Unlike `struct
#     gcc_options', the primary's OFFSETS in these two structs do move: the
#     members are printed category by category, so a category that grows
#     shifts every later one.  That is sound precisely because of the indexing
#     relation above -- nothing outside options-save.cc indexes these structs
#     positionally, and options-save.cc is regenerated from the same list in
#     the same build.  It is stated rather than hidden because it is the one
#     property this change does NOT inherit from `struct gcc_options'.
#   * optc-save-gen.awk emits a static assertion that its final k fits the N
#     sized here, so a divergence between the two is a compile error rather
#     than a stray write.
#
# `Init()' IS NOT CARRIED, DELIBERATELY.  A non-primary back end's members are
# zero in `global_options_init' because `optc-gen.awk' builds that initialiser
# from the primary's optionlist, where the other base's option is a stub with
# no Init().  That is a defect, it is the next one aarch64 hits, and it does
# NOT belong here: an Init() is DATA, not layout.  Carrying every base's
# Init() into the one `global_options_init' would give the primary compiler
# aarch64's defaults in aarch64's fields and i386's in i386's -- which is
# right only if the initialiser is per-base, i.e. only once there is a
# selector to choose one.  See the note in optc-gen.awk.

# Record one member of `struct gcc_options'.  KIND is V (a Variable or
# TargetVariable record), O (an option with Var()), S (a Target option with no
# Var(), which gets an x_VAR_<option> slot) or F (a SetByCombined
# frontend_set_ flag).  TEXT is the complete block of lines this member emits,
# newline-separated, so that a member is compared and reproduced as the exact
# thing it generates rather than as a description of it.
function add_member(kind, name, text,    key)
{
	# V, O and S all name a field `x_<name>' and a macro; they share one
	# namespace and a clash between them is a real conflict, not an
	# artefact of the encoding.  F names `frontend_set_<name>' instead.
	key = (kind == "F" ? "F" : "X") SUBSEP name
	if (key in member_text) {
		if (member_text[key] != text) {
			print "opth-gen.awk: two declarations of member " \
			      name ":" > "/dev/stderr"
			print member_text[key] > "/dev/stderr"
			print "and" > "/dev/stderr"
			print text > "/dev/stderr"
			exit 1
		}
		return
	}
	member_text[key] = text
	member_kind[key] = kind
	member_name[key] = name
	member_order[n_members++] = key
}

# Encode a member as one line of the union list.  Newlines inside TEXT become
# `\n' so that a member is one record; nothing else in the text is escaped
# because these blocks are generated C and contain no backslashes.
function member_line(key,    t)
{
	t = member_text[key]
	gsub(/\\/, "\\\\", t)
	gsub(/\n/, "\\n", t)
	return member_kind[key] "\t" member_name[key] "\t" t
}

function decode_text(t)
{
	gsub(/\\n/, "\n", t)
	gsub(/\\\\/, "\\", t)
	return t
}

function union_fail(msg)
{
	print "opth-gen.awk: " (union_file == "" ? "<no union file>" : union_file) \
	      ": " msg > "/dev/stderr"
	exit 1
}

# Read the union file into u_* arrays, and check it names this back end.
function read_union(   line, nf, f, key, n)
{
	if (union_base == "")
		union_fail("-v union_file needs -v union_base=<back end>")
	n_u_members = 0
	n_u_includes = 0
	n_bases = 0
	n_u_R = 0
	n_u_D = 0
	n_u_X = 0
	n_u_X_extra = 0
	while ((getline line < union_file) > 0) {
		if (line ~ /^base /) {
			sub(/^base /, "", line)
			u_base[line] = 1
			n_bases++
			continue
		}
		nf = split(line, f, "\t")
		if (nf == 0 || f[1] == "")
			continue
		if (f[1] == "I") {
			if (!(f[2] in u_include_seen)) {
				u_include_seen[f[2]] = 1
				u_include[n_u_includes++] = f[2]
			}
			continue
		}
		if (f[1] == "R") {
			# Kept in file order, duplicates included: the
			# consumers already refuse a second declaration of a
			# variable they have seen (var_opt_seen /
			# var_save_seen), and that is the same rule within a
			# base and across bases.  A type disagreement between
			# two bases for one variable cannot hide here -- an
			# Optimization or Save variable is also a `struct
			# gcc_options' member, so the V/O check above compares
			# its full declaration first.
			u_R[n_u_R++] = f[3]
			u_R_name[f[2]] = 1
			continue
		}
		if (f[1] == "D") {
			# `TargetSave' and `TargetVariable' declarations, kept
			# verbatim.  Two bases naming one field differently is
			# the shared-numbering failure again, so it is refused
			# rather than resolved: `arch' and `tune' are exactly
			# the sort of name two back ends both want.
			n = f[2]
			sub(/^.*[ *]/, "", n)
			sub(/\[.*\]$/, "", n)
			if (n in u_D_by_name) {
				if (u_D_by_name[n] != f[2])
					union_fail("two back ends declare" \
						   " cl_target_option field `" \
						   n "' differently:\n  " \
						   u_D_by_name[n] "\n  " f[2])
				continue
			}
			u_D_by_name[n] = f[2]
			u_D_seen[f[2]] = 1
			u_D[n_u_D++] = f[2]
			continue
		}
		if (f[1] == "X") {
			if (f[2] in u_X_type) {
				if (u_X_type[f[2]] != f[3])
					union_fail("two back ends declare" \
						   " target variable `" f[2] \
						   "' as `" u_X_type[f[2]] \
						   "' and `" f[3] "'")
				continue
			}
			u_X_type[f[2]] = f[3]
			u_X[n_u_X++] = f[2]
			continue
		}
		if (f[1] == "E") {
			# Merged into the global enum_type[] so that
			# var_type_struct() answers the same for a record no
			# matter which base is reading it.  enum_names[] is NOT
			# extended: that drives what this header DECLARES, and
			# another base's enum is declared by its own
			# <cpu>-opts.h, which the `I' records already pull in.
			if (f[2] in u_E_type) {
				if (u_E_type[f[2]] != f[3])
					union_fail("two back ends declare" \
						   " Enum `" f[2] "' with type" \
						   " `" u_E_type[f[2]] "' and `" \
						   f[3] "'")
				continue
			}
			u_E_type[f[2]] = f[3]
			if (!(f[2] in enum_type))
				enum_type[f[2]] = f[3]
			else if (enum_type[f[2]] != f[3])
				union_fail("Enum `" f[2] "' is `" \
					   enum_type[f[2]] "' here and `" f[3] \
					   "' in the union list")
			continue
		}
		if (f[1] == "H") {
			u_H_seen[f[2]] = 1
			if (host_wide_int[f[2]] == "")
				host_wide_int[f[2]] = "yes"
			continue
		}
		if (f[1] != "V" && f[1] != "O" && f[1] != "S" && f[1] != "F")
			union_fail("unknown record kind `" f[1] "'")
		key = (f[1] == "F" ? "F" : "X") SUBSEP f[2]
		if (key in u_text) {
			if (u_text[key] != f[3])
				union_fail("member " f[2] " declared twice," \
					   " differently")
			continue
		}
		u_text[key] = f[3]
		u_order[n_u_members++] = key
	}
	close(union_file)
	if (n_bases == 0)
		union_fail("no `base' line at all -- this is not a union list")
	if (!(union_base in u_base))
		union_fail("does not name back end `" union_base "'; the" \
			   " union would then be taken over the OTHER back" \
			   " ends and this one's members would be missing")
	if (n_u_members == 0)
		union_fail("no member records")
}

# Every member this back end's own records require must be in the union, with
# the same declaration.  This is the check that catches a stale union list --
# the failure that would otherwise be silent, because the member would simply
# not be there and every offset after it would shift.
function check_union_covers_self(   i, key)
{
	for (i = 0; i < n_members; i++) {
		key = member_order[i]
		if (!(key in u_text))
			union_fail("back end `" union_base "' declares member " \
				   member_name[key] " and the union list does" \
				   " not; the list is stale")
		if (decode_text(u_text[key]) != member_text[key])
			union_fail("back end `" union_base "' and the union" \
				   " list disagree about member " \
				   member_name[key])
	}
	for (i = 0; i < n_extra_h_includes; i++)
		if (!(extra_h_includes[i] in u_include_seen))
			union_fail("back end `" union_base "' includes " \
				   extra_h_includes[i] " and the union list" \
				   " does not; the union's members would not" \
				   " compile")
	# The same stale-list check for the save/restore half.  Without it a
	# list written before an option gained `Save' would silently produce a
	# cl_target_option missing that member in every OTHER back end's
	# header, which is the divergence this file exists to remove.
	for (i = 0; i < n_opts; i++) {
		if (!flag_set_p("(Optimization|PerFunction)", flags[i]) \
		    && !flag_set_p("Save", flags[i]))
			continue
		if (!(opts[i] in u_R_name))
			union_fail("back end `" union_base "' saves option `" \
				   opts[i] "' and the union list has no `R'" \
				   " record for it; the list is stale")
	}
	for (i = 0; i < n_target_save; i++)
		if (!(target_save_decl[i] in u_D_seen))
			union_fail("back end `" union_base "' declares" \
				   " cl_target_option field `" \
				   target_save_decl[i] "' and the union list" \
				   " does not; the list is stale")
	for (i = 0; i < n_extra_target_vars; i++)
		if (!(extra_target_vars[i] in u_X_type))
			union_fail("back end `" union_base "' declares target" \
				   " variable `" extra_target_vars[i] "' and" \
				   " the union list does not; the list is stale")
}

# Build the member list this back end's own records describe.  The four loops
# below are the ones that used to print directly into the struct, unchanged in
# what they select and in what order; only the destination moved, so that the
# same list can be written out (-v list_mode) as well as printed.
function collect_members(   i, var, orig_var, name, type, type_after, txt)
{
	for (i = 0; i < n_extra_vars; i++) {
		var = extra_vars[i]
		sub(" *=.*", "", var)
		orig_var = var
		name = var
		type = var
		type_after = var
		sub("^.*[ *]", "", name)
		sub("\\[.*\\]$", "", name)
		sub("\\[.*\\]$", "", type)
		sub(" *" name "$", "", type)
		sub("^.*" name, "", type_after)
		var_seen[name] = 1
		txt = "#ifdef GENERATOR_FILE\n" \
		      "extern " orig_var ";\n" \
		      "#else\n" \
		      "  " type " x_" name type_after ";\n" \
		      "#define " name " global_options.x_" name "\n" \
		      "#endif"
		add_member("V", name, txt)
	}

	for (i = 0; i < n_opts; i++) {
		if (flag_set_p("Save", flags[i]))
			have_save = 1;

		name = var_name(flags[i]);
		if (name == "")
			continue;

		if (name in var_seen)
			continue;

		var_seen[name] = 1;
		txt = "#ifdef GENERATOR_FILE\n" \
		      "extern " var_type(flags[i]) name ";\n" \
		      "#else\n" \
		      "  " var_type(flags[i]) "x_" name ";\n" \
		      "#define " name " global_options.x_" name "\n" \
		      "#endif"
		add_member("O", name, txt)
	}
	for (i = 0; i < n_opts; i++) {
		name = static_var(opts[i], flags[i]);
		if (name != "") {
			txt = "#ifndef GENERATOR_FILE\n" \
			      "  " var_type(flags[i]) "x_" name ";\n" \
			      "#define x_" name " do_not_use\n" \
			      "#endif"
			add_member("S", name, txt)
		}
	}
	for (i = 0; i < n_opts; i++) {
		if (flag_set_p("SetByCombined", flags[i])) {
			name = var_name(flags[i])
			txt = "#ifndef GENERATOR_FILE\n" \
			      "  bool frontend_set_" name ";\n" \
			      "#endif"
			add_member("F", name, txt)
		}
	}
}

# Dump out an enumeration into a .h file.
# Combine the flags of duplicate options.
END {
# Collect the members of `struct gcc_options' that THIS back end's records
# describe.  Done before anything is printed, because list mode prints these
# and nothing else.
collect_members()

if (list_mode != "") {
	if (union_base == "")
		union_fail("-v list_mode=1 needs -v union_base=<back end>")
	print "base " union_base
	for (i = 0; i < n_extra_h_includes; i++)
		print "I\t" extra_h_includes[i]
	for (i = 0; i < n_members; i++)
		print member_line(member_order[i])
	# The save/restore half of the list: RAW records, not derived members.
	# See the header note -- a category computed here and consumed there is
	# exactly the drift this avoids.
	for (i = 0; i < n_opts; i++)
		if (flag_set_p("(Optimization|PerFunction)", flags[i]) \
		    || flag_set_p("Save", flags[i]))
			print "R\t" opts[i] "\t" flags[i]
	for (i = 0; i < n_target_save; i++)
		print "D\t" target_save_decl[i]
	for (i = 0; i < n_extra_target_vars; i++)
		print "X\t" extra_target_vars[i] "\t" extra_target_var_types[i]
	# An `R' record is not self-contained: var_type_struct() resolves
	# Enum(name=X) through enum_type[] and UInteger through
	# host_wide_int[], both built from THIS back end's Enum and Variable
	# records.  Another base reading the raw record without them typed
	# `Enum(aarch64_early_ra_scope)' as the empty string and produced a
	# member with no type at all -- which is what made the first two
	# unioned headers differ, and it compiled as far as the diff.
	for (i = 0; i < n_enums; i++)
		print "E\t" enum_names[i] "\t" enum_type[enum_names[i]]
	for (i in host_wide_int)
		if (host_wide_int[i] == "yes")
			print "H\t" i
	exit 0
}

if (union_file != "") {
	read_union()
	check_union_covers_self()
}

# The record sets the two save/restore structs are built from.  With a union
# list this is the LIST's order, for every back end alike -- not this back
# end's records followed by the others'.  That distinction is the whole
# property: "own first, extras appended" gives each base a different order
# (its own members early, everyone else's late), which is a per-base layout
# again wearing a union's member count.  Measured that way before it was
# fixed: 551 members in both headers, `x_ix86_vect_compare_costs' at different
# offsets in each.  The list is primary-first and deduplicated by first
# appearance, so the primary's records still come first and keep their order.
n_sv = 0
if (union_file != "") {
	for (i = 0; i < n_u_R; i++)
		sv_flags[n_sv++] = u_R[i]
} else {
	for (i = 0; i < n_opts; i++)
		sv_flags[n_sv++] = flags[i]
}

# ABSENCE IS NEVER AN ANSWER, and this is the one place it could still get in.
# var_type_struct() returns `enum_type[en] " "' for an Enum option, i.e. the
# single space " " when the Enum record is missing -- and a missing Enum record
# is exactly what a union list without the `E' kind produces for every base but
# the owning one.  The member then reads `  x_aarch64_early_ra;', which is a
# legal C declaration of an int, in a header that otherwise looks right.
for (i = 0; i < n_sv; i++) {
	if (!flag_set_p("(Optimization|PerFunction)", sv_flags[i]) \
	    && !flag_set_p("Save", sv_flags[i]))
		continue
	if (var_name(sv_flags[i]) == "")
		continue
	if (var_type_struct(sv_flags[i]) ~ /^ *$/)
		union_fail("no type for `x_" var_name(sv_flags[i]) "': its" \
			   " Enum() has no `E' record in the union list, so" \
			   " the member would be declared with no type at all")
}

n_sd = 0
if (union_file != "") {
	for (i = 0; i < n_u_D; i++)
		sd_decl[n_sd++] = u_D[i]
} else {
	for (i = 0; i < n_target_save; i++)
		sd_decl[n_sd++] = target_save_decl[i]
}

# Only the COUNT of these is wanted here (it sizes cl_target_option's
# explicit_mask); `extra_target_vars' itself is left alone because
# `find_index' searches it when handing out target-variable mask bits, and
# lengthening that search would let another base's name answer for this one.
n_sx = (union_file != "" ? n_u_X : n_extra_target_vars)

# `have_save' was set by collect_members() from this back end's records alone;
# another base may be the one with Save options.
for (i = 0; i < n_sv; i++)
	if (flag_set_p("Save", sv_flags[i]))
		have_save = 1

print "/* This file is auto-generated by opth-gen.awk.  */"
print ""
# The include guard is per OUTPUT FILE, not per family.  All 45
# options-<base>.h used to share `OPTIONS_H' with the shared options.h, so a
# translation unit that reached for two of them silently got whichever came
# first and the rest were no-ops -- one name, several authorities, no
# diagnostic, one layer below the OPT_ ordinals.
#
# It is not theoretical: config/loongarch/loongarch-evolution.h includes
# "options.h", and in the tm.h path options-loongarch.h has already been
# included, so that line does nothing.  It works only because the per-base
# header happens to come first; where it does not, loongarch silently compiles
# against the primary target's options and loses OPTION_MASK_ISA_*.
#
# Distinct guards make including two of them a redefinition error instead --
# loud, and correct, because a translation unit may only ever have one.
#
# OPTIONS_H_INCLUDED is the companion: a family-wide marker meaning "some
# options header is already in this TU", so a header that needs one but does
# not know which can ask, rather than naming a particular file and being wrong
# on 44 targets out of 45.
guard = guard_name
if (guard == "")
	guard = "OPTIONS_H"
print "#ifndef " guard
print "#define " guard
print "#ifndef OPTIONS_H_INCLUDED"
print "#define OPTIONS_H_INCLUDED"
print "#endif"
print ""
print "#include \"flag-types.h\""
print ""

# With a union layout the members of the OTHER back ends are declared here
# too, so their types have to be visible: `enum aarch64_arch x_selected_arch'
# needs config/aarch64/aarch64-opts.h in a header i386 also reads.  The union
# list carries the HeaderInclude records of every back end for exactly this
# reason, and check_union_covers_self has already refused a list that is
# missing one of ours.
if (union_file != "") {
	for (i = 0; i < n_u_includes; i++)
		print "#include " quote u_include[i] quote
	if (n_u_includes > 0)
		print ""
}
else if (n_extra_h_includes > 0) {
	for (i = 0; i < n_extra_h_includes; i++) {
		print "#include " quote extra_h_includes[i] quote
	}
	print ""
}

print "#if !defined(IN_LIBGCC2) && !defined(IN_TARGET_LIBS) && !defined(IN_RTS)"
print "#ifndef GENERATOR_FILE"
print "#if !defined(IN_LIBGCC2) && !defined(IN_TARGET_LIBS)"
print "struct GTY(()) gcc_options"
print "#else"
print "struct gcc_options"
print "#endif"
print "{"
print "#endif"

# Either this back end's own members, or -- when a union list was given -- the
# union's, in the union's order, which is the same for every back end.  Note
# there is no third case and no fallback: read_union has already stopped the
# build if the list is unusable, so a missing answer cannot become a layout.
if (union_file != "") {
	for (i = 0; i < n_u_members; i++)
		print decode_text(u_text[u_order[i]])
}
else {
	for (i = 0; i < n_members; i++)
		print member_text[member_order[i]]
}
print "#ifndef GENERATOR_FILE"
print "};"
print "extern struct gcc_options global_options;"
# NOT const in a multi-target build.  There is one of these and it is the
# union layout, so a member belonging to a back end that is not the primary is
# value-initialised in optc-gen.awk's static initialiser -- an Init()
# argument is a macro from that back end's tm.h and cannot be spelled there.
# multi-target-select.cc calls global_options_init_<base> on this object at
# target selection, before toplev.cc calls init_options_struct, which is the
# only read that matters.  See the long note in optc-gen.awk.
if (union_file != "")
	print "extern struct gcc_options global_options_init;"
else
	print "extern const struct gcc_options global_options_init;"
print "extern struct gcc_options global_options_set;"
print "#define target_flags_explicit global_options_set.x_target_flags"
print "#endif"
print "#endif"
print ""

# All of the optimization switches gathered together so they can be saved and restored.
# This will allow attribute((cold)) to turn on space optimization.

# Change the type of normal switches from int to unsigned char to save space.
# Also, order the structure so that pointer fields occur first, then int
# fields, and then char fields to provide the best packing.

print "#if !defined(IN_LIBGCC2) && !defined(IN_TARGET_LIBS) && !defined(IN_RTS)"
print ""
print "/* Structure to save/restore optimization and target specific options.  */";
print "struct GTY(()) cl_optimization";
print "{";

n_opt_char = 4;
n_opt_short = 0;
n_opt_int = 0;
n_opt_enum = 0;
n_opt_other = 0;
n_opt_explicit = 4;
var_opt_char[0] = "unsigned char x_optimize";
var_opt_char[1] = "unsigned char x_optimize_size";
var_opt_char[2] = "unsigned char x_optimize_debug";
var_opt_char[3] = "unsigned char x_optimize_fast";

for (i = 0; i < n_sv; i++) {
	if (flag_set_p("(Optimization|PerFunction)", sv_flags[i])) {
		name = var_name(sv_flags[i])
		if(name == "")
			continue;

		if(name in var_opt_seen)
			continue;

		var_opt_seen[name]++;
		n_opt_explicit++;
		otype = var_type_struct(sv_flags[i]);
		if (otype ~ "^((un)?signed +)?int *$")
			var_opt_int[n_opt_int++] = otype "x_" name;

		else if (otype ~ "^((un)?signed +)?short *$")
			var_opt_short[n_opt_short++] = otype "x_" name;

		else if (otype ~ "^((un)?signed +)?char *$")
			var_opt_char[n_opt_char++] = otype "x_" name;

		else if (otype ~ ("^enum +[_" alnum "]+ *$"))
			var_opt_enum[n_opt_enum++] = otype "x_" name;

		else
			var_opt_other[n_opt_other++] = otype "x_" name;
	}
}

for (i = 0; i < n_opt_other; i++) {
	print "  " var_opt_other[i] ";";
}

for (i = 0; i < n_opt_int; i++) {
	print "  " var_opt_int[i] ";";
}

for (i = 0; i < n_opt_enum; i++) {
	print "  " var_opt_enum[i] ";";
}

for (i = 0; i < n_opt_short; i++) {
	print "  " var_opt_short[i] ";";
}

for (i = 0; i < n_opt_char; i++) {
	print "  " var_opt_char[i] ";";
}

print "  /* " n_opt_explicit " members */";
print "  unsigned HOST_WIDE_INT explicit_mask[" int ((n_opt_explicit + 63) / 64) "];";

print "};";
print "";

# Target and optimization save/restore/print functions.
print "/* Structure to save/restore selected target specific options.  */";
print "struct GTY(()) cl_target_option";
print "{";

n_target_char = 0;
n_target_short = 0;
n_target_int = 0;
n_target_enum = 0;
n_target_other = 0;
n_target_explicit = n_sx;
n_target_explicit_mask = 0;

for (i = 0; i < n_sd; i++) {
	if (sd_decl[i] ~ "^((un)?signed +)?int +[_" alnum "]+$")
		var_target_int[n_target_int++] = sd_decl[i];

	else if (sd_decl[i] ~ "^((un)?signed +)?short +[_" alnum "]+$")
		var_target_short[n_target_short++] = sd_decl[i];

	else if (sd_decl[i] ~ "^((un)?signed +)?char +[_ " alnum "]+$")
		var_target_char[n_target_char++] = sd_decl[i];

	else if (sd_decl[i] ~ ("^enum +[_" alnum "]+ +[_" alnum "]+$")) {
		var_target_enum[n_target_enum++] = sd_decl[i];
	}
	else
		var_target_other[n_target_other++] = sd_decl[i];
}

if (have_save) {
	for (i = 0; i < n_sv; i++) {
		if (flag_set_p("Save", sv_flags[i])) {
			name = var_name(sv_flags[i])
			if(name == "")
				name = "target_flags";

			if(name in var_save_seen)
				continue;

			var_save_seen[name]++;
			n_target_explicit++;
			otype = var_type_struct(sv_flags[i])

			if (opt_args("Mask", sv_flags[i]) != "" \
			    || opt_args("InverseMask", sv_flags[i]))
				var_target_explicit_mask[n_target_explicit_mask++] \
				    = otype "explicit_mask_" name;

			if (otype ~ "^((un)?signed +)?int *$")
				var_target_int[n_target_int++] = otype "x_" name;

			else if (otype ~ "^((un)?signed +)?short *$")
				var_target_short[n_target_short++] = otype "x_" name;

			else if (otype ~ "^((un)?signed +)?char *$")
				var_target_char[n_target_char++] = otype "x_" name;

			else if (otype ~ ("^enum +[_" alnum "]+ +[_" alnum "]+"))
				var_target_enum[n_target_enum++] = otype "x_" name;

			else
				var_target_other[n_target_other++] = otype "x_" name;
		}
	}
} else {
	var_target_int[n_target_int++] = "int x_target_flags";
	n_target_explicit++;
	var_target_explicit_mask[n_target_explicit_mask++] \
	    = "int explicit_mask_target_flags";
}

for (i = 0; i < n_target_other; i++) {
	print "  " var_target_other[i] ";";
}

for (i = 0; i < n_target_enum; i++) {
	print "  " var_target_enum[i] ";";
}

for (i = 0; i < n_target_int; i++) {
	print "  " var_target_int[i] ";";
}

for (i = 0; i < n_target_short; i++) {
	print "  " var_target_short[i] ";";
}

for (i = 0; i < n_target_char; i++) {
	print "  " var_target_char[i] ";";
}

print "  /* " n_target_explicit - n_target_explicit_mask " members */";
if (n_target_explicit > n_target_explicit_mask) {
	print "  unsigned HOST_WIDE_INT explicit_mask[" \
	  int ((n_target_explicit - n_target_explicit_mask + 63) / 64) "];";
}

for (i = 0; i < n_target_explicit_mask; i++) {
	print "  " var_target_explicit_mask[i] ";";
}

print "};";
print "";
print "";
print "/* Save optimization variables into a structure.  */"
print "extern void cl_optimization_save (struct cl_optimization *, struct gcc_options *, struct gcc_options *);";
print "";
print "/* Restore optimization variables from a structure.  */";
print "extern void cl_optimization_restore (struct gcc_options *, struct gcc_options *, struct cl_optimization *);";
print "";
print "/* Print optimization variables from a structure.  */";
print "extern void cl_optimization_print (FILE *, int, struct cl_optimization *);";
print "";
print "/* Print different optimization variables from structures provided as arguments.  */";
print "extern void cl_optimization_print_diff (FILE *, int, cl_optimization *ptr1, cl_optimization *ptr2);";
print "";
print "/* Save selected option variables into a structure.  */"
print "extern void cl_target_option_save (struct cl_target_option *, struct gcc_options *, struct gcc_options *);";
print "";
print "/* Restore selected option variables from a structure.  */"
print "extern void cl_target_option_restore (struct gcc_options *, struct gcc_options *, struct cl_target_option *);";
print "";
print "/* Print target option variables from a structure.  */";
print "extern void cl_target_option_print (FILE *, int, struct cl_target_option *);";
print "";
print "/* Print different target option variables from structures provided as arguments.  */";
print "extern void cl_target_option_print_diff (FILE *, int, cl_target_option *ptr1, cl_target_option *ptr2);";
print "";
print "/* Compare two target option variables from a structure.  */";
print "extern bool cl_target_option_eq (const struct cl_target_option *, const struct cl_target_option *);";
print "";
print "/* Free heap memory used by target option variables.  */";
print "extern void cl_target_option_free (struct cl_target_option *);";
print "";
print "/* Hash option variables from a structure.  */";
print "extern hashval_t cl_target_option_hash (const struct cl_target_option *);";
print "";
print "/* Hash optimization from a structure.  */";
print "extern hashval_t cl_optimization_hash (const struct cl_optimization *);";
print "";
print "/* Compare two optimization options.  */";
print "extern bool cl_optimization_option_eq (cl_optimization const *ptr1, cl_optimization const *ptr2);"
print "";
print "/* Free heap memory used by optimization options.  */";
print "extern void cl_optimization_option_free (cl_optimization *ptr1);"
print "";
print "/* Compare and report difference for a part of cl_optimization options.  */";
print "extern void cl_optimization_compare (gcc_options *ptr1, gcc_options *ptr2);";
print "";
print "/* Generator files may not have access to location_t, and don't need these.  */"
print "#if defined(UNKNOWN_LOCATION)"
print "bool                                                                  "
print "common_handle_option_auto (struct gcc_options *opts,                  "
print "                           struct gcc_options *opts_set,              "
print "                           const struct cl_decoded_option *decoded,   "
print "                           unsigned int lang_mask, int kind,          "
print "                           location_t loc,                            "
print "                           const struct cl_option_handlers *handlers, "
print "                           diagnostics::context *dc);                   "
for (i = 0; i < n_langs; i++) {
    lang_name = lang_sanitized_name(langs[i]);
    print "bool"
    print lang_name "_handle_option_auto (struct gcc_options *opts,"
    print "                           struct gcc_options *opts_set,"
    print "                           size_t scode, const char *arg,"
    print "                           HOST_WIDE_INT value,"
    print "                           unsigned int lang_mask, int kind,"
    print "                           location_t loc,"
    print "                           const struct cl_option_handlers *handlers,"
    print "                           diagnostics::context *dc);"
}
print "void cpp_handle_option_auto (const struct gcc_options * opts, size_t scode,"
print "                             struct cpp_options * cpp_opts);"
print "void init_global_opts_from_cpp(struct gcc_options * opts,      "
print "                               const struct cpp_options * cpp_opts);"    
print "#endif";
print "#endif";
print "";

for (i = 0; i < n_opts; i++) {
	name = opt_args("Mask", flags[i])
	if (name == "") {
		opt = opt_args("InverseMask", flags[i])
		if (opt ~ ",")
			name = nth_arg(0, opt)
		else
			name = opt
	}
	if (name != "" && mask_bits[name] == 0) {
		mask_bits[name] = 1
		vname = var_name(flags[i])
		mask = "MASK_"
		mask_1 = "1U"
		if (vname != "") {
			mask = "OPTION_MASK_"
			if (host_wide_int[vname] == "yes")
				mask_1 = "HOST_WIDE_INT_1U"
		} else
			extra_mask_bits[name] = 1
		print "#define " mask name " (" mask_1 " << " masknum[vname]++ ")"
	}
}
for (i = 0; i < n_extra_masks; i++) {
	if (extra_mask_bits[extra_masks[i]] == 0)
		print "#define MASK_" extra_masks[i] " (1U << " masknum[""]++ ")"
}

for (i = 0; i < n_target_vars; i++)
{
	if (find_index(target_vars[i], extra_target_vars, n_extra_target_vars) == n_extra_target_vars)
		continue
	for (j = 0; j < n_other_mask[i]; j++)
	{
		print "#define MASK_" other_masks[i "," j] " (1U << " other_masknum[i]++ ")"
	}
	if (other_masknum[i] > 32)
		print "#error too many target masks for" extra_target_vars[i]
}

for (var in masknum) {
	if (var != "" && host_wide_int[var] == "yes") {
		print "#if defined(HOST_BITS_PER_WIDE_INT) && " masknum[var] " > HOST_BITS_PER_WIDE_INT"
		print "#error too many masks for " var
		print "#endif"
	}
	else if (masknum[var] > 32) {
		if (var == "")
			print "#error too many target masks"
		else
			print "#error too many masks for " var
	}
}
for (i = 0; i < n_target_vars; i++)
{
	if (find_index(target_vars[i], extra_target_vars, n_extra_target_vars) == n_extra_target_vars)
		continue
	for (j = 0; j < n_other_mask[i]; j++)
	{
		print "#define TARGET_" other_masks[i "," j] \
		      " ((" target_vars[i] " & MASK_" other_masks[i "," j] ") != 0)"
		print "#define TARGET_" other_masks[i "," j] "_P(" target_vars[i] ")" \
		      " (((" target_vars[i] ") & MASK_" other_masks[i "," j] ") != 0)"
		print "#define TARGET_" other_masks[i "," j] "_OPTS_P(opts)" \
		      " (((opts->x_" target_vars[i] ") & MASK_" other_masks[i "," j] ") != 0)"
	}
}
print ""

for (i = 0; i < n_opts; i++) {
	name = opt_args("Mask", flags[i])
	if (name == "") {
		opt = opt_args("InverseMask", flags[i])
		if (opt ~ ",")
			name = nth_arg(0, opt)
		else
			name = opt
	}
	if (name != "" && mask_macros[name] == 0) {
		mask_macros[name] = 1
		vname = var_name(flags[i])
		mask = "OPTION_MASK_"
		if (vname == "") {
			vname = "target_flags"
			mask = "MASK_"
			extra_mask_macros[name] = 1
		}
		original_name = name
		gsub("ISA_", "", name)
		gsub("ISA2_", "", name)
		print "/* " original_name " mask */"
		print "#define TARGET_" name \
		      " ((" vname " & " mask original_name ") != 0)"
		print "#define TARGET_" name "_P(" vname ")" \
		      " (((" vname ") & " mask original_name ") != 0)"
		print "#define TARGET_" name "_OPTS_P(opts)" \
		      " (((opts->x_" vname ") & " mask original_name ") != 0)"
		print "#define TARGET_EXPLICIT_" name "_P(opts)" \
		      " ((opts->x_" vname "_explicit & " mask original_name ") != 0)"
		print "#define SET_TARGET_" name "(opts) opts->x_" vname " |= " mask original_name
	}
}
for (i = 0; i < n_extra_masks; i++) {
	if (extra_mask_macros[extra_masks[i]] == 0) {
		print "#define TARGET_" extra_masks[i] \
		      " ((target_flags & MASK_" extra_masks[i] ") != 0)"
		print "#define TARGET_" extra_masks[i] "_P(target_flags)" \
		      " (((target_flags) & " extra_masks[i] ") != 0)"
		print "#define TARGET_" extra_masks[i] "_OPTS_P(opts)" \
		      " (((opts->x_target_flags) & MASK_" extra_masks[i] ") != 0)"
	}
}
print ""

for (i = 0; i < n_opts; i++) {
	opt = opt_args("InverseMask", flags[i])
	if (opt ~ ",") {
		vname = var_name(flags[i])
		mask = "OPTION_MASK_"
		if (vname == "") {
			vname = "target_flags"
			mask = "MASK_"
		}
		print "#define TARGET_" nth_arg(1, opt) \
		      " ((" vname " & " mask nth_arg(0, opt) ") == 0)"
	}
}
print ""

for (i = 0; i < n_langs; i++) {
        macros[i] = "CL_" lang_sanitized_name(langs[i])
	s = substr("            ", length (macros[i]))
	print "#define " macros[i] s " (1U << " i ")"
    }
print "#define CL_LANG_ALL   ((1U << " n_langs ") - 1)"

print ""
print "enum opt_code"
print "{"
	
for (i = 0; i < n_opts; i++)
	back_chain[i] = "N_OPTS";

enum_value = 0
for (i = 0; i < n_opts; i++) {
	# Combine the flags of identical switches.  Switches
	# appear many times if they are handled by many front
	# ends, for example.
	while( i + 1 != n_opts && opts[i] == opts[i + 1] ) {
		flags[i + 1] = flags[i] " " flags[i + 1];
		i++;
	}

	len = length (opts[i]);
	enum = opt_enum(opts[i])
	enum_string = enum " = " enum_value ","

	# Aliases do not get enumeration names.
	if ((flag_set_p("Alias.*", flags[i]) \
	     && !flag_set_p("SeparateAlias", flags[i])) \
	    || flag_set_p("Ignore", flags[i])) {
		enum_string = "/* " enum_string " */"
	}

	# If this switch takes joined arguments, back-chain all
	# subsequent switches to it for which it is a prefix.  If
	# a later switch S is a longer prefix of a switch T, T
	# will be back-chained to S in a later iteration of this
	# for() loop, which is what we want.
	if (flag_set_p("Joined.*", flags[i])) {
		for (j = i + 1; j < n_opts; j++) {
			if (substr (opts[j], 1, len) != opts[i])
				break;
			back_chain[j] = enum;
		}
	}

	s = substr("                                          ",
		   length (enum_string))

	if (help[i] == "")
		hlp = "0"
	else
		hlp = "N_(\"" help[i] "\")";

	print "  " enum_string s "/* -" opts[i] " */"
	enum_value++
}

print "  N_OPTS,"
print "  OPT_SPECIAL_unknown,"
print "  OPT_SPECIAL_ignore,"
print "  OPT_SPECIAL_warn_removed,"
print "  OPT_SPECIAL_program_name,"
print "  OPT_SPECIAL_input_file"
print "};"
print ""
print "#ifdef GCC_C_COMMON_C"
print "/* Mapping from cpp message reasons to the options that enable them.  */"
print "#include <cpplib.h>"
print "struct cpp_reason_option_codes_t"
print "{"
print "  /* cpplib message reason.  */"
print "  const enum cpp_warning_reason reason;"
print "  /* gcc option that controls this message.  */"
print "  const int option_code;"
print "};"
print ""
print "static const struct cpp_reason_option_codes_t cpp_reason_option_codes[] = {"
for (i = 0; i < n_opts; i++) {
    # With identical flags, pick only the last one.  The
    # earlier loop ensured that it has all flags merged,
    # and a nonempty help text if one of the texts was nonempty.
    while( i + 1 != n_opts && opts[i] == opts[i + 1] ) {
        i++;
    }
    cpp_reason = nth_arg(0, opt_args("CppReason", flags[i]));
    if (cpp_reason != "") {
        cpp_reason = cpp_reason ",";
        printf("  {%-40s %s},\n", cpp_reason, opt_enum(opts[i]))
    }
}
printf("  {%-40s 0},\n", "CPP_W_NONE,")
print "};"
print "#endif"
print ""
print "#endif /* " guard " */"
}
