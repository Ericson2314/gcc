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
	exit 0
}

if (union_file != "") {
	read_union()
	check_union_covers_self()
}

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

for (i = 0; i < n_opts; i++) {
	if (flag_set_p("(Optimization|PerFunction)", flags[i])) {
		name = var_name(flags[i])
		if(name == "")
			continue;

		if(name in var_opt_seen)
			continue;

		var_opt_seen[name]++;
		n_opt_explicit++;
		otype = var_type_struct(flags[i]);
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
n_target_explicit = n_extra_target_vars;
n_target_explicit_mask = 0;

for (i = 0; i < n_target_save; i++) {
	if (target_save_decl[i] ~ "^((un)?signed +)?int +[_" alnum "]+$")
		var_target_int[n_target_int++] = target_save_decl[i];

	else if (target_save_decl[i] ~ "^((un)?signed +)?short +[_" alnum "]+$")
		var_target_short[n_target_short++] = target_save_decl[i];

	else if (target_save_decl[i] ~ "^((un)?signed +)?char +[_ " alnum "]+$")
		var_target_char[n_target_char++] = target_save_decl[i];

	else if (target_save_decl[i] ~ ("^enum +[_" alnum "]+ +[_" alnum "]+$")) {
		var_target_enum[n_target_enum++] = target_save_decl[i];
	}
	else
		var_target_other[n_target_other++] = target_save_decl[i];
}

if (have_save) {
	for (i = 0; i < n_opts; i++) {
		if (flag_set_p("Save", flags[i])) {
			name = var_name(flags[i])
			if(name == "")
				name = "target_flags";

			if(name in var_save_seen)
				continue;

			var_save_seen[name]++;
			n_target_explicit++;
			otype = var_type_struct(flags[i])

			if (opt_args("Mask", flags[i]) != "" \
			    || opt_args("InverseMask", flags[i]))
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
