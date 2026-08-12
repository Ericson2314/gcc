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
# C file.
#

# This program uses functions from opt-functions.awk and code from
# opt-read.awk.
#
# Usage: awk -f opt-functions.awk -f opt-read.awk -f optc-save-gen.awk \
#            [-v header_name=header.h] < inputfile > options-save.cc

# MULTI-TARGET: -v union_file=F -v union_base=B
#
# There is exactly ONE options-save.cc in the compiler and it used to be built
# from the PRIMARY back end's optionlist alone, while `cl_optimization' and
# `cl_target_option' were per-back-end (i386 544/57 members against aarch64
# 548/26).  opth-gen.awk now gives those two structs one layout taken over
# every base; this script has to be built from the SAME set, and the reason it
# is not optional is the explicit_mask relation.
#
# Neither struct names a bit of `explicit_mask[]'.  The bit for a member is its
# ORDINAL in the walk below -- var_opt_other, var_opt_int, var_opt_enum,
# var_opt_short, var_opt_char, var_opt_string, one bit each, wrapping every 64
# -- performed identically by `cl_optimization_save' and
# `cl_optimization_restore', and by the cl_target_option pair over the target
# arrays.  Both ends of the encoding are emitted here, from one list, so the
# WALK ORDER is private and may change freely.  What may NOT differ is the
# member SET: opth-gen.awk sizes `explicit_mask[N]' from its list and this
# script fills k from its list, and a k past N is a write off the end of the
# struct with nothing to catch it.  So the two read one file, and the tail of
# this script emits a static assertion tying k back to N.
#
# The records are consumed RAW -- the union list carries option records (`R'),
# TargetSave declarations (`D') and TargetVariable names (`X'), not members --
# so this script's own classification decides which bucket a type lands in,
# and cannot disagree with opth-gen.awk about a type it never sees.
#
# In a single-target build no union file is passed, n_sv == n_opts, and the
# output is byte-identical to what it was.

function save_union_fail(msg)
{
	print "optc-save-gen.awk: " union_file ": " msg > "/dev/stderr"
	exit 1
}

# Read the R/D/X half of the union list.  The member records opth-gen.awk uses
# are skipped here; a kind this script does not know is NOT an error, because
# the two scripts consume different halves of one file.  What IS an error is a
# list that does not name this build's back end, or that is missing something
# this build's own records require.
function read_save_union(   line, nf, f, n)
{
	if (union_base == "")
		save_union_fail("-v union_file needs -v union_base=<back end>")
	n_u_R = 0
	n_u_D = 0
	n_u_X = 0
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
		if (f[1] == "R") {
			u_R[n_u_R++] = f[3]
			u_R_name[f[2]] = 1
			continue
		}
		if (f[1] == "D") {
			n = f[2]
			sub(/^.*[ *]/, "", n)
			sub(/\[.*\]$/, "", n)
			if (n in u_D_by_name) {
				if (u_D_by_name[n] != f[2])
					save_union_fail("two back ends declare" \
						" cl_target_option field `" n \
						"' differently:\n  " \
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
					save_union_fail("two back ends declare" \
						" target variable `" f[2] \
						"' as `" u_X_type[f[2]] \
						"' and `" f[3] "'")
				continue
			}
			u_X_type[f[2]] = f[3]
			u_X[n_u_X++] = f[2]
			continue
		}
		# An `R' record is not self-contained: var_type_struct() reads
		# enum_type[] and host_wide_int[], which opt-read.awk fills
		# from THIS back end's Enum and Variable records.  Without
		# these two kinds another base's Enum option types as the empty
		# string -- a member with no type, in a header that still
		# parsed far enough to look right.
		if (f[1] == "E") {
			if (f[2] in u_E_type) {
				if (u_E_type[f[2]] != f[3])
					save_union_fail("two back ends declare" \
						" Enum `" f[2] "' with type `" \
						u_E_type[f[2]] "' and `" f[3] "'")
				continue
			}
			u_E_type[f[2]] = f[3]
			if (!(f[2] in enum_type))
				enum_type[f[2]] = f[3]
			else if (enum_type[f[2]] != f[3])
				save_union_fail("Enum `" f[2] "' is `" \
						enum_type[f[2]] "' here and `" \
						f[3] "' in the union list")
			continue
		}
		if (f[1] == "H") {
			if (host_wide_int[f[2]] == "")
				host_wide_int[f[2]] = "yes"
			continue
		}
	}
	close(union_file)
	if (n_bases == 0)
		save_union_fail("no `base' line at all -- this is not a union list")
	if (!(union_base in u_base))
		save_union_fail("does not name back end `" union_base "'; the" \
				" union would then be taken over the OTHER" \
				" back ends and this one's members missing")
	if (n_u_R == 0 && n_u_D == 0 && n_u_X == 0)
		save_union_fail("no `R', `D' or `X' records at all;" \
				" options-save.cc would be built from this" \
				" back end alone, which is the divergence" \
				" this file exists to remove")
	# The stale-list check, in both directions of the same relation as
	# opth-gen.awk's: a list written before this back end gained an option
	# would silently drop it from save/restore.
	for (i = 0; i < n_opts; i++) {
		if (!flag_set_p("(Optimization|PerFunction)", flags[i]) \
		    && !flag_set_p("Save", flags[i]))
			continue
		if (!(opts[i] in u_R_name))
			save_union_fail("back end `" union_base "' saves" \
					" option `" opts[i] "' and the union" \
					" list has no `R' record for it; the" \
					" list is stale")
	}
	for (i = 0; i < n_target_save; i++)
		if (!(target_save_decl[i] in u_D_seen))
			save_union_fail("back end `" union_base "' declares" \
					" cl_target_option field `" \
					target_save_decl[i] "' and the union" \
					" list does not; the list is stale")
	for (i = 0; i < n_extra_target_vars; i++)
		if (!(extra_target_vars[i] in u_X_type))
			save_union_fail("back end `" union_base "' declares" \
					" target variable `" \
					extra_target_vars[i] "' and the union" \
					" list does not; the list is stale")
}

# Dump that array of options into a C file.
END {
if (union_file != "")
	read_save_union()
else if (union_base != "")
	save_union_fail("-v union_base needs -v union_file=<list>")

# The record set everything below is built from.  With a union list it is the
# LIST's order -- the same for every back end -- and NOT this back end's
# records followed by the others'; see the matching note in opth-gen.awk, which
# has to make the identical choice or the struct and the code that walks it
# disagree about which member is which.  The list is primary-first and
# deduplicated by first appearance, so the primary's records keep their order
# and lead.
n_sv = 0
if (union_file != "") {
	for (i = 0; i < n_u_R; i++)
		sv_flags[n_sv++] = u_R[i]
	n_target_save = 0
	for (i = 0; i < n_u_D; i++)
		target_save_decl[n_target_save++] = u_D[i]
	n_extra_target_vars = 0
	for (i = 0; i < n_u_X; i++) {
		extra_target_var_types[n_extra_target_vars] = u_X_type[u_X[i]]
		extra_target_vars[n_extra_target_vars++] = u_X[i]
	}
} else {
	for (i = 0; i < n_opts; i++)
		sv_flags[n_sv++] = flags[i]
}

# The same guard opth-gen.awk carries: a missing `E' record makes
# var_type_struct() answer " " rather than answering nothing, and " " is a
# usable type everywhere it is spliced.
for (i = 0; i < n_sv; i++) {
	if (!flag_set_p("(Optimization|PerFunction)", sv_flags[i]) \
	    && !flag_set_p("Save", sv_flags[i]))
		continue
	if (var_name(sv_flags[i]) == "")
		continue
	if (var_type_struct(sv_flags[i]) ~ /^ *$/)
		save_union_fail("no type for `x_" var_name(sv_flags[i]) "':" \
				" its Enum() has no `E' record in the union" \
				" list, so the member would be declared with" \
				" no type at all")
}

print "/* This file is auto-generated by optc-save-gen.awk.  */"
print ""
print "#define INCLUDE_MEMORY"
n_headers = split(header_name, headers, " ")
for (i = 1; i <= n_headers; i++)
	print "#include " quote headers[i] quote
print "#include " quote "opts.h" quote
print "#include " quote "intl.h" quote
print ""
print "#include " quote "flags.h" quote
print "#include " quote "target.h" quote
print "#include " quote "inchash.h" quote
print "#include " quote "hash-set.h" quote
print "#include " quote "vec.h" quote
print "#include " quote "input.h" quote
print "#include " quote "alias.h" quote
print "#include " quote "symtab.h" quote
print "#include " quote "inchash.h" quote
print "#include " quote "tree.h" quote
print "#include " quote "fold-const.h" quote
print "#include " quote "tree-ssa-alias.h" quote
print "#include " quote "is-a.h" quote
print "#include " quote "predict.h" quote
print "#include " quote "function.h" quote
print "#include " quote "basic-block.h" quote
print "#include " quote "gimple-expr.h" quote
print "#include " quote "gimple.h" quote
print "#include " quote "data-streamer.h" quote
print "#include " quote "ipa-ref.h" quote
print "#include " quote "cgraph.h" quote
print ""

if (n_extra_c_includes > 0) {
	for (i = 0; i < n_extra_c_includes; i++) {
		print "#include " quote extra_c_includes[i] quote
	}
	print ""
}

have_save = 0;
if (n_extra_target_vars)
	have_save = 1

for (i = 0; i < n_sv; i++) {
	if (flag_set_p("Save", sv_flags[i]))
		have_save = 1;
}

print "/* Save optimization variables into a structure.  */"
print "void";
print "cl_optimization_save (struct cl_optimization *ptr, struct gcc_options *opts,";
print "		      struct gcc_options *opts_set)";
print "{";

n_opt_char = 4;
n_opt_short = 0;
n_opt_int = 0;
n_opt_enum = 0;
n_opt_string = 0;
n_opt_other = 0;
var_opt_char[0] = "optimize";
var_opt_char[1] = "optimize_size";
var_opt_char[2] = "optimize_debug";
var_opt_char[3] = "optimize_fast";
var_opt_range["optimize"] = "0, 255";
var_opt_range["optimize_size"] = "0, 2";
var_opt_range["optimize_debug"] = "0, 1";
var_opt_range["optimize_fast"] = "0, 1";

# Sort by size to mimic how the structure is laid out to be friendlier to the
# cache.

for (i = 0; i < n_sv; i++) {
	if (flag_set_p("(Optimization|PerFunction)", sv_flags[i])) {
		name = var_name(sv_flags[i])
		if(name == "")
			continue;

		if(name in var_opt_seen)
			continue;

		var_opt_seen[name]++;
		otype = var_type_struct(sv_flags[i]);
		if (otype ~ "^((un)?signed +)?int *$")
			var_opt_int[n_opt_int++] = name;

		else if (otype ~ "^((un)?signed +)?short *$")
			var_opt_short[n_opt_short++] = name;

		else if (otype ~ ("^enum +[_" alnum "]+ *")) {
			var_opt_enum_type[n_opt_enum] = otype;
			var_opt_enum[n_opt_enum++] = name;
		}
		else if (otype ~ "^((un)?signed +)?char *$") {
			var_opt_char[n_opt_char++] = name;
			if (otype ~ "^unsigned +char *$")
				var_opt_range[name] = "0, 255"
			else if (otype ~ "^signed +char *$")
				var_opt_range[name] = "-128, 127"
		}
		else if (otype ~ "^const char \\**$") {
			var_opt_string[n_opt_string++] = name;
			string_options_names[name]++
		}
		else
			var_opt_other[n_opt_other++] = name;
	}
}

for (i = 0; i < n_opt_char; i++) {
	name = var_opt_char[i];
	if (var_opt_range[name] != "")
		print "  gcc_assert (IN_RANGE (opts->x_" name ", " var_opt_range[name] "));";
}

print "";
for (i = 0; i < n_opt_other; i++) {
	print "  ptr->x_" var_opt_other[i] " = opts->x_" var_opt_other[i] ";";
}

for (i = 0; i < n_opt_int; i++) {
	print "  ptr->x_" var_opt_int[i] " = opts->x_" var_opt_int[i] ";";
}

for (i = 0; i < n_opt_enum; i++) {
	print "  ptr->x_" var_opt_enum[i] " = opts->x_" var_opt_enum[i] ";";
}

for (i = 0; i < n_opt_short; i++) {
	print "  ptr->x_" var_opt_short[i] " = opts->x_" var_opt_short[i] ";";
}

for (i = 0; i < n_opt_char; i++) {
	print "  ptr->x_" var_opt_char[i] " = opts->x_" var_opt_char[i] ";";
}

for (i = 0; i < n_opt_string; i++) {
	print "  ptr->x_" var_opt_string[i] " = opts->x_" var_opt_string[i] ";";
}

print "";
print "  unsigned HOST_WIDE_INT mask = 0;";

j = 0;
k = 0;
for (i = 0; i < n_opt_other; i++) {
	print "  if (opts_set->x_" var_opt_other[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_opt_int; i++) {
	print "  if (opts_set->x_" var_opt_int[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_opt_enum; i++) {
	print "  if (opts_set->x_" var_opt_enum[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_opt_short; i++) {
	print "  if (opts_set->x_" var_opt_short[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_opt_char; i++) {
	print "  if (opts_set->x_" var_opt_char[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_opt_string; i++) {
	print "  if (opts_set->x_" var_opt_string[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

if (j != 0) {
	print "  ptr->explicit_mask[" k "] = mask;";
}

print "}";

# THE ONE THING THE TWO GENERATORS MUST AGREE ON, CHECKED BY THE COMPILER.
# opth-gen.awk sizes `explicit_mask[N]' from its member set; the walk above
# fills element k from this script's.  Built from one union list they match;
# built from two they do not, and the symptom would be a store past the end of
# a GC-allocated struct -- no diagnostic, and not reproducible from the source.
# So it is asserted here rather than argued anywhere.
print "";
print "static_assert (" (j != 0 ? k + 1 : k) " <= (int) (sizeof (((cl_optimization *) 0)->explicit_mask)";
print "                    / sizeof (((cl_optimization *) 0)->explicit_mask[0])),";
print "               \"cl_optimization::explicit_mask is shorter than the walk\"";
print "               \" optc-save-gen.awk generated; options.h and\"";
print "               \" options-save.cc were built from different option sets\");";

print "";
print "/* Restore optimization options from a structure.  */";
print "void";
print "cl_optimization_restore (struct gcc_options *opts, struct gcc_options *opts_set,";
print "			 struct cl_optimization *ptr)";
print "{";

for (i = 0; i < n_opt_other; i++) {
	print "  opts->x_" var_opt_other[i] " = ptr->x_" var_opt_other[i] ";";
}

for (i = 0; i < n_opt_int; i++) {
	print "  opts->x_" var_opt_int[i] " = ptr->x_" var_opt_int[i] ";";
}

for (i = 0; i < n_opt_enum; i++) {
	print "  opts->x_" var_opt_enum[i] " = ptr->x_" var_opt_enum[i] ";";
}

for (i = 0; i < n_opt_short; i++) {
	print "  opts->x_" var_opt_short[i] " = ptr->x_" var_opt_short[i] ";";
}

for (i = 0; i < n_opt_char; i++) {
	print "  opts->x_" var_opt_char[i] " = ptr->x_" var_opt_char[i] ";";
}

for (i = 0; i < n_opt_string; i++) {
	print "  opts->x_" var_opt_string[i] " = ptr->x_" var_opt_string[i] ";";
}

print "";
print "  unsigned HOST_WIDE_INT mask;";

j = 64;
k = 0;
for (i = 0; i < n_opt_other; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_opt_other[i] " = (mask & 1) != 0;";
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_opt_int; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_opt_int[i] " = (mask & 1) != 0;";
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_opt_enum; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_opt_enum[i] " = static_cast<" var_opt_enum_type[i] ">((mask & 1) != 0);";
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_opt_short; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_opt_short[i] " = (mask & 1) != 0;";
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_opt_char; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_opt_char[i] " = (mask & 1) != 0;";
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_opt_string; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_opt_string[i] " = (mask & 1) ? \"\" : nullptr;";
	print "  mask >>= 1;"
	j++;
}

print "  targetm.override_options_after_change ();";
print "}";

print "";
print "/* Print optimization options from a structure.  */";
print "void";
print "cl_optimization_print (FILE *file,";
print "                       int indent_to,";
print "                       struct cl_optimization *ptr)";
print "{";

print "  fputs (\"\\n\", file);";
for (i = 0; i < n_opt_other; i++) {
	print "  if (ptr->x_" var_opt_other[i] ")";
	print "    fprintf (file, \"%*s%s (%#lx)\\n\",";
	print "             indent_to, \"\",";
	print "             \"" var_opt_other[i] "\",";
	print "             (unsigned long)ptr->x_" var_opt_other[i] ");";
	print "";
}

for (i = 0; i < n_opt_int; i++) {
	print "  if (ptr->x_" var_opt_int[i] ")";
	print "    fprintf (file, \"%*s%s (%#x)\\n\",";
	print "             indent_to, \"\",";
	print "             \"" var_opt_int[i] "\",";
	print "             ptr->x_" var_opt_int[i] ");";
	print "";
}

for (i = 0; i < n_opt_enum; i++) {
	print "  fprintf (file, \"%*s%s (%#x)\\n\",";
	print "           indent_to, \"\",";
	print "           \"" var_opt_enum[i] "\",";
	print "           (int) ptr->x_" var_opt_enum[i] ");";
	print "";
}

for (i = 0; i < n_opt_short; i++) {
	print "  if (ptr->x_" var_opt_short[i] ")";
	print "    fprintf (file, \"%*s%s (%#x)\\n\",";
	print "             indent_to, \"\",";
	print "             \"" var_opt_short[i] "\",";
	print "             ptr->x_" var_opt_short[i] ");";
	print "";
}

for (i = 0; i < n_opt_char; i++) {
	print "  if (ptr->x_" var_opt_char[i] ")";
	print "    fprintf (file, \"%*s%s (%#x)\\n\",";
	print "             indent_to, \"\",";
	print "             \"" var_opt_char[i] "\",";
	print "             ptr->x_" var_opt_char[i] ");";
	print "";
}

for (i = 0; i < n_opt_string; i++) {
	print "  if (ptr->x_" var_opt_string[i] ")";
	print "    fprintf (file, \"%*s%s (%s)\\n\",";
	print "             indent_to, \"\",";
	print "             \"" var_opt_string[i] "\",";
	print "             ptr->x_" var_opt_string[i] ");";
	print "";
}

print "}";

print "";
print "/* Print different optimization variables from structures provided as arguments.  */";
print "void";
print "cl_optimization_print_diff (FILE *file,";
print "                            int indent_to,";
print "                            struct cl_optimization *ptr1,";
print "                            struct cl_optimization *ptr2)";
print "{";

print "  fputs (\"\\n\", file);";
for (i = 0; i < n_opt_other; i++) {
	print "  if (ptr1->x_" var_opt_other[i] " != ptr2->x_" var_opt_other[i] ")";
	print "    fprintf (file, \"%*s%s (%#lx/%#lx)\\n\",";
	print "             indent_to, \"\",";
	print "             \"" var_opt_other[i] "\",";
	print "             (unsigned long)ptr1->x_" var_opt_other[i] ",";
	print "             (unsigned long)ptr2->x_" var_opt_other[i] ");";
	print "";
}

for (i = 0; i < n_opt_int; i++) {
	print "  if (ptr1->x_" var_opt_int[i] " != ptr2->x_" var_opt_int[i] ")";
	print "    fprintf (file, \"%*s%s (%#x/%#x)\\n\",";
	print "             indent_to, \"\",";
	print "             \"" var_opt_int[i] "\",";
	print "             ptr1->x_" var_opt_int[i] ",";
	print "             ptr2->x_" var_opt_int[i] ");";
	print "";
}

for (i = 0; i < n_opt_enum; i++) {
	print "  if (ptr1->x_" var_opt_enum[i] " != ptr2->x_" var_opt_enum[i] ")";
	print "  fprintf (file, \"%*s%s (%#x/%#x)\\n\",";
	print "           indent_to, \"\",";
	print "           \"" var_opt_enum[i] "\",";
	print "           (int) ptr1->x_" var_opt_enum[i] ",";
	print "           (int) ptr2->x_" var_opt_enum[i] ");";
	print "";
}

for (i = 0; i < n_opt_short; i++) {
	print "  if (ptr1->x_" var_opt_short[i] " != ptr2->x_" var_opt_short[i] ")";
	print "    fprintf (file, \"%*s%s (%#x/%#x)\\n\",";
	print "             indent_to, \"\",";
	print "             \"" var_opt_short[i] "\",";
	print "             ptr1->x_" var_opt_short[i] ",";
	print "             ptr2->x_" var_opt_short[i] ");";
	print "";
}

for (i = 0; i < n_opt_char; i++) {
	print "  if (ptr1->x_" var_opt_char[i] " != ptr2->x_" var_opt_char[i] ")";
	print "    fprintf (file, \"%*s%s (%#x/%#x)\\n\",";
	print "             indent_to, \"\",";
	print "             \"" var_opt_char[i] "\",";
	print "             ptr1->x_" var_opt_char[i] ",";
	print "             ptr2->x_" var_opt_char[i] ");";
	print "";
}

for (i = 0; i < n_opt_string; i++) {
	name = var_opt_string[i]
	print "  if (ptr1->x_" name " != ptr2->x_" name "";
	print "      && (!ptr1->x_" name" || !ptr2->x_" name
	print "          || strcmp (ptr1->x_" name", ptr2->x_" name ")))";
	print "    fprintf (file, \"%*s%s (%s/%s)\\n\",";
	print "             indent_to, \"\",";
	print "             \"" name "\",";
	print "             ptr1->x_" name " ? ptr1->x_" name " : \"(null)\",";
	print "             ptr2->x_" name " ? ptr2->x_" name " : \"(null)\");";
	print "";
}

print "}";


print "";
print "/* Save selected option variables into a structure.  */"
print "void";
print "cl_target_option_save (struct cl_target_option *ptr, struct gcc_options *opts,";
print "		       struct gcc_options *opts_set)";
print "{";

n_target_char = 0;
n_target_short = 0;
n_target_int = 0;
n_target_enum = 0;
n_target_string = 0;
n_target_other = 0;

if (have_save) {
	for (i = 0; i < n_sv; i++) {
		if (flag_set_p("Save", sv_flags[i])) {
			name = var_name(sv_flags[i])
			if(name == "")
				name = "target_flags";

			if(name in var_save_seen)
				continue;

			var_save_seen[name]++;
			otype = var_type_struct(sv_flags[i])
			if (opt_args("Mask", sv_flags[i]) != "" \
			    || opt_args("InverseMask", sv_flags[i]))
				var_target_explicit_mask[name] = 1;

			if (otype ~ "^((un)?signed +)?int *$")
				var_target_int[n_target_int++] = name;

			else if (otype ~ "^((un)?signed +)?short *$")
				var_target_short[n_target_short++] = name;

			else if (otype ~ ("^enum +[_" alnum "]+ *$")) {
				var_target_enum_type[n_target_enum] = otype;
				var_target_enum[n_target_enum++] = name;
			}
			else if (otype ~ "^((un)?signed +)?char *$") {
				var_target_char[n_target_char++] = name;
				if (otype ~ "^unsigned +char *$")
					var_target_range[name] = "0, 255"
				else if (otype ~ "^signed +char *$")
					var_target_range[name] = "-128, 127"
				if (otype == var_type(sv_flags[i]))
					var_target_range[name] = ""
			}
			else if (otype ~ "^const char \\**$") {
				var_target_string[n_target_string++] = name;
				string_options_names[name]++
			}
			else
				var_target_other[n_target_other++] = name;
		}
	}
} else {
	var_target_int[n_target_int++] = "target_flags";
	var_target_explicit_mask["target_flags"] = 1;
}

have_assert = 0;
for (i = 0; i < n_target_char; i++) {
	name = var_target_char[i];
	if (var_target_range[name] != "") {
		have_assert = 1;
		print "  gcc_assert (IN_RANGE (opts->x_" name ", " var_target_range[name] "));";
	}
}

if (have_assert)
	print "";

print "  if (targetm.target_option.save)";
print "    targetm.target_option.save (ptr, opts, opts_set);";
print "";

for (i = 0; i < n_extra_target_vars; i++) {
	print "  ptr->x_" extra_target_vars[i] " = opts->x_" extra_target_vars[i] ";";
}

for (i = 0; i < n_target_other; i++) {
	print "  ptr->x_" var_target_other[i] " = opts->x_" var_target_other[i] ";";
}

for (i = 0; i < n_target_enum; i++) {
	print "  ptr->x_" var_target_enum[i] " = opts->x_" var_target_enum[i] ";";
}

for (i = 0; i < n_target_int; i++) {
	print "  ptr->x_" var_target_int[i] " = opts->x_" var_target_int[i] ";";
}

for (i = 0; i < n_target_short; i++) {
	print "  ptr->x_" var_target_short[i] " = opts->x_" var_target_short[i] ";";
}

for (i = 0; i < n_target_char; i++) {
	print "  ptr->x_" var_target_char[i] " = opts->x_" var_target_char[i] ";";
}

for (i = 0; i < n_target_string; i++) {
	print "  ptr->x_" var_target_string[i] " = opts->x_" var_target_string[i] ";";
}

print "";

j = 0;
k = 0;
for (i = 0; i < n_extra_target_vars; i++) {
	if (j == 0 && k == 0) {
		print "  unsigned HOST_WIDE_INT mask = 0;";
	}
	print "  if (opts_set->x_" extra_target_vars[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_target_other; i++) {
	if (var_target_other[i] in var_target_explicit_mask) {
		print "  ptr->explicit_mask_" var_target_other[i] " = opts_set->x_" var_target_other[i] ";";
		continue;
	}
	if (j == 0 && k == 0) {
		print "  unsigned HOST_WIDE_INT mask = 0;";
	}
	print "  if (opts_set->x_" var_target_other[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_target_enum; i++) {
	if (j == 0 && k == 0) {
		print "  unsigned HOST_WIDE_INT mask = 0;";
	}
	print "  if (opts_set->x_" var_target_enum[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_target_int; i++) {
	if (var_target_int[i] in var_target_explicit_mask) {
		print "  ptr->explicit_mask_" var_target_int[i] " = opts_set->x_" var_target_int[i] ";";
		continue;
	}
	if (j == 0 && k == 0) {
		print "  unsigned HOST_WIDE_INT mask = 0;";
	}
	print "  if (opts_set->x_" var_target_int[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_target_short; i++) {
	if (j == 0 && k == 0) {
		print "  unsigned HOST_WIDE_INT mask = 0;";
	}
	print "  if (opts_set->x_" var_target_short[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_target_char; i++) {
	if (j == 0 && k == 0) {
		print "  unsigned HOST_WIDE_INT mask = 0;";
	}
	print "  if (opts_set->x_" var_target_char[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

for (i = 0; i < n_target_string; i++) {
	if (j == 0 && k == 0) {
		print "  unsigned HOST_WIDE_INT mask = 0;";
	}
	print "  if (opts_set->x_" var_target_string[i] ") mask |= HOST_WIDE_INT_1U << " j ";";
	j++;
	if (j == 64) {
		print "  ptr->explicit_mask[" k "] = mask;";
		print "  mask = 0;";
		j = 0;
		k++;
	}
}

if (j != 0) {
	print "  ptr->explicit_mask[" k "] = mask;";
}
has_target_explicit_mask = 0;
if (j != 0 || k != 0) {
	has_target_explicit_mask = 1;
}

print "}";

# The cl_target_option half of the same assertion; see the cl_optimization one.
if (has_target_explicit_mask) {
	print "";
	print "static_assert (" (j != 0 ? k + 1 : k) " <= (int) (sizeof (((cl_target_option *) 0)->explicit_mask)";
	print "                    / sizeof (((cl_target_option *) 0)->explicit_mask[0])),";
	print "               \"cl_target_option::explicit_mask is shorter than the\"";
	print "               \" walk optc-save-gen.awk generated; options.h and\"";
	print "               \" options-save.cc were built from different option sets\");";
}

print "";
print "/* Restore selected current options from a structure.  */";
print "void";
print "cl_target_option_restore (struct gcc_options *opts, struct gcc_options *opts_set,";
print "			  struct cl_target_option *ptr)";
print "{";

for (i = 0; i < n_extra_target_vars; i++) {
	print "  opts->x_" extra_target_vars[i] " = ptr->x_" extra_target_vars[i] ";";
}

for (i = 0; i < n_target_other; i++) {
	print "  opts->x_" var_target_other[i] " = ptr->x_" var_target_other[i] ";";
}

for (i = 0; i < n_target_enum; i++) {
	print "  opts->x_" var_target_enum[i] " = ptr->x_" var_target_enum[i] ";";
}

for (i = 0; i < n_target_int; i++) {
	print "  opts->x_" var_target_int[i] " = ptr->x_" var_target_int[i] ";";
}

for (i = 0; i < n_target_short; i++) {
	print "  opts->x_" var_target_short[i] " = ptr->x_" var_target_short[i] ";";
}

for (i = 0; i < n_target_char; i++) {
	print "  opts->x_" var_target_char[i] " = ptr->x_" var_target_char[i] ";";
}

for (i = 0; i < n_target_string; i++) {
	print "  opts->x_" var_target_string[i] " = ptr->x_" var_target_string[i] ";";
}

print "";
if (has_target_explicit_mask) {
	print "  unsigned HOST_WIDE_INT mask;";
}

j = 64;
k = 0;
for (i = 0; i < n_extra_target_vars; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	if (extra_target_var_types[i] ~ ("^enum +[_" alnum "]+ *$")) {
		print "  opts_set->x_" extra_target_vars[i] " = static_cast<" extra_target_var_types[i] ">((mask & 1) != 0);";
	}
	else if (extra_target_var_types[i] ~ "^const char \\**$") {
		print "  opts_set->x_" extra_target_vars[i] " = (mask & 1) ? \"\" : nullptr;";
	}
	else {
		print "  opts_set->x_" extra_target_vars[i] " = (mask & 1) != 0;";
	}
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_target_other; i++) {
	if (var_target_other[i] in var_target_explicit_mask) {
		print "  opts_set->x_" var_target_other[i] " = ptr->explicit_mask_" var_target_other[i] ";";
		continue;
	}
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_target_other[i] " = (mask & 1) != 0;";
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_target_enum; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_target_enum[i] " = static_cast<" var_target_enum_type[i] ">((mask & 1) != 0);";
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_target_int; i++) {
	if (var_target_int[i] in var_target_explicit_mask) {
		print "  opts_set->x_" var_target_int[i] " = ptr->explicit_mask_" var_target_int[i] ";";
		continue;
	}
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_target_int[i] " = (mask & 1) != 0;";
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_target_short; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_target_short[i] " = (mask & 1) != 0;";
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_target_char; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_target_char[i] " = (mask & 1) != 0;";
	print "  mask >>= 1;"
	j++;
}

for (i = 0; i < n_target_string; i++) {
	if (j == 64) {
		print "  mask = ptr->explicit_mask[" k "];";
		k++;
		j = 0;
	}
	print "  opts_set->x_" var_target_string[i] " = (mask & 1) ? \"\" : nullptr;";
	print "  mask >>= 1;"
	j++;
}

# This must occur after the normal variables in case the code depends on those
# variables.
print "";
print "  if (targetm.target_option.restore)";
print "    targetm.target_option.restore (opts, opts_set, ptr);";

print "}";

print "";
print "/* Print optimization options from a structure.  */";
print "void";
print "cl_target_option_print (FILE *file,";
print "                        int indent,";
print "                        struct cl_target_option *ptr)";
print "{";

print "  fputs (\"\\n\", file);";
for (i = 0; i < n_target_other; i++) {
	print "  if (ptr->x_" var_target_other[i] ")";
	hwi = host_wide_int[var_target_other[i]]
	if (hwi == "yes")
		print "    fprintf (file, \"%*s%s (%#\" HOST_WIDE_INT_PRINT \"x)\\n\",";
	else
		print "    fprintf (file, \"%*s%s (%#lx)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_other[i] "\",";
	if (hwi == "yes")
		print "             ptr->x_" var_target_other[i] ");";
	else
		print "             (unsigned long)ptr->x_" var_target_other[i] ");";
	print "";
}

for (i = 0; i < n_target_enum; i++) {
	print "  if (ptr->x_" var_target_enum[i] ")";
	print "    fprintf (file, \"%*s%s (%#x)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_enum[i] "\",";
	print "             ptr->x_" var_target_enum[i] ");";
	print "";
}

for (i = 0; i < n_target_int; i++) {
	print "  if (ptr->x_" var_target_int[i] ")";
	print "    fprintf (file, \"%*s%s (%#x)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_int[i] "\",";
	print "             ptr->x_" var_target_int[i] ");";
	print "";
}

for (i = 0; i < n_target_short; i++) {
	print "  if (ptr->x_" var_target_short[i] ")";
	print "    fprintf (file, \"%*s%s (%#x)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_short[i] "\",";
	print "             ptr->x_" var_target_short[i] ");";
	print "";
}

for (i = 0; i < n_target_char; i++) {
	print "  if (ptr->x_" var_target_char[i] ")";
	print "    fprintf (file, \"%*s%s (%#x)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_char[i] "\",";
	print "             ptr->x_" var_target_char[i] ");";
	print "";
}

for (i = 0; i < n_target_string; i++) {
	print "  if (ptr->x_" var_target_string[i] ")";
	print "    fprintf (file, \"%*s%s (%s)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_string[i] "\",";
	print "             ptr->x_" var_target_string[i] ");";
	print "";
}

print "";
print "  if (targetm.target_option.print)";
print "    targetm.target_option.print (file, indent, ptr);";
print "}";

print "";
print "/* Print different target option variables from structures provided as arguments.  */";
print "void";
print "cl_target_option_print_diff (FILE *file,";
print "                             int indent ATTRIBUTE_UNUSED,";
print "                             struct cl_target_option *ptr1 ATTRIBUTE_UNUSED,";
print "                             struct cl_target_option *ptr2 ATTRIBUTE_UNUSED)";
print "{";

print "  fputs (\"\\n\", file);";
for (i = 0; i < n_target_other; i++) {
	print "  if (ptr1->x_" var_target_other[i] " != ptr2->x_" var_target_other[i] ")";
	hwi = host_wide_int[var_target_other[i]]
	if (hwi == "yes")
		print "    fprintf (file, \"%*s%s (%#\" HOST_WIDE_INT_PRINT \"x/%#\" HOST_WIDE_INT_PRINT \"x)\\n\",";
	else
		print "    fprintf (file, \"%*s%s (%#lx/%#lx)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_other[i] "\",";
	if (hwi == "yes") {
		print "             ptr1->x_" var_target_other[i] ",";
		print "             ptr2->x_" var_target_other[i] ");";
	}
	else {
		print "             (unsigned long)ptr1->x_" var_target_other[i] ",";
		print "             (unsigned long)ptr2->x_" var_target_other[i] ");";
	}
	print "";
}

for (i = 0; i < n_target_enum; i++) {
	print "  if (ptr1->x_" var_target_enum[i] " != ptr2->x_" var_target_enum[i] ")";
	print "    fprintf (file, \"%*s%s (%#x/%#x)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_enum[i] "\",";
	print "             ptr1->x_" var_target_enum[i] ",";
	print "             ptr2->x_" var_target_enum[i] ");";
	print "";
}

for (i = 0; i < n_target_int; i++) {
	print "  if (ptr1->x_" var_target_int[i] " != ptr2->x_" var_target_int[i] ")";
	print "    fprintf (file, \"%*s%s (%#x/%#x)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_int[i] "\",";
	print "             ptr1->x_" var_target_int[i] ",";
	print "             ptr2->x_" var_target_int[i] ");";
	print "";
}

for (i = 0; i < n_target_short; i++) {
	print "  if (ptr1->x_" var_target_short[i] " != ptr2->x_" var_target_short[i] ")";
	print "    fprintf (file, \"%*s%s (%#x/%#x)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_short[i] "\",";
	print "             ptr1->x_" var_target_short[i] ",";
	print "             ptr2->x_" var_target_short[i] ");";
	print "";
}

for (i = 0; i < n_target_char; i++) {
	print "  if (ptr1->x_" var_target_char[i] " != ptr2->x_" var_target_char[i] ")";
	print "    fprintf (file, \"%*s%s (%#x/%#x)\\n\",";
	print "             indent, \"\",";
	print "             \"" var_target_char[i] "\",";
	print "             ptr1->x_" var_target_char[i] ",";
	print "             ptr2->x_" var_target_char[i] ");";
	print "";
}

for (i = 0; i < n_target_string; i++) {
	name = var_target_string[i]
	print "  if (ptr1->x_" name " != ptr2->x_" name "";
	print "      && (!ptr1->x_" name" || !ptr2->x_" name
	print "          || strcmp (ptr1->x_" name", ptr2->x_" name ")))";
	print "    fprintf (file, \"%*s%s (%s/%s)\\n\",";
	print "             indent, \"\",";
	print "             \"" name "\",";
	print "             ptr1->x_" name " ? ptr1->x_" name " : \"(null)\",";
	print "             ptr2->x_" name " ? ptr2->x_" name " : \"(null)\");";
	print "";
}

print "}";

print "";
print "/* Compare two target options  */";
print "bool";
print "cl_target_option_eq (struct cl_target_option const *ptr1 ATTRIBUTE_UNUSED,";
print "                     struct cl_target_option const *ptr2 ATTRIBUTE_UNUSED)";
print "{";
n_target_val = 0;
n_target_str = 0;
n_target_array = 0;

for (i = 0; i < n_target_save; i++) {
	var = target_save_decl[i];
	sub (" *=.*", "", var);
	name = var;
	type = var;
	sub("^.*[ *]", "", name)
	sub(" *" name "$", "", type)
	if (target_save_decl[i] ~ "^const char \\*+[_" alnum "]+$") {
		var_target_str[n_target_str++] = name;
		string_options_names[name]++
	}
	else {
		if (target_save_decl[i] ~ " .*\\[.+\\]+$") {
			size = name;
			sub("[^\\[]+\\[", "", size);
			sub("\\]$", "", size);
			sub("\\[.+", "", name)
			sub(" [^ ]+$", "", type)
			var_target_array[n_target_array] = name
			var_target_array_type[n_target_array] = type
			var_target_array_size[n_target_array++] = size
		}
		else {
			var_target_val_type[n_target_val] = type;
			var_target_val[n_target_val++] = name;
		}
	}
}
if (have_save) {
	for (i = 0; i < n_sv; i++) {
		if (flag_set_p("Save", sv_flags[i])) {
			name = var_name(sv_flags[i])
			if(name == "")
				name = "target_flags";

			if(name in var_list_seen)
				continue;

			var_list_seen[name]++;
			otype = var_type_struct(sv_flags[i])
			if (otype ~ "^const char \\**$")
				var_target_str[n_target_str++] = "x_" name;
			else {
				var_target_val_type[n_target_val] = otype;
				var_target_val[n_target_val++] = "x_" name;
			}
		}
	}
} else {
	var_target_val_type[n_target_val] = "int";
	var_target_val[n_target_val++] = "x_target_flags";
}

for (i = 0; i < n_target_str; i++) {
	name = var_target_str[i]
	print "  if (ptr1->" name" != ptr2->" name;
	print "      && (!ptr1->" name" || !ptr2->" name
	print "          || strcmp (ptr1->" name", ptr2->" name ")))";
	print "    return false;";
}
for (i = 0; i < n_target_array; i++) {
	name = var_target_array[i]
	size = var_target_array_size[i]
	type = var_target_array_type[i]
	print "  if (memcmp (ptr1->" name ", ptr2->" name ", " size " * sizeof(" type ")))"
	print "    return false;";
}
for (i = 0; i < n_target_val; i++) {
	name = var_target_val[i]
	print "  if (ptr1->" name" != ptr2->" name ")";
	print "    return false;";
}

if (has_target_explicit_mask) {
	print "  for (size_t i = 0; i < ARRAY_SIZE (ptr1->explicit_mask); i++)";
	print "    if (ptr1->explicit_mask[i] != ptr2->explicit_mask[i])";
	print "      return false;"
}

for (i = 0; i < n_target_other; i++) {
	if (var_target_other[i] in var_target_explicit_mask) {
		print "  if (ptr1->explicit_mask_" var_target_other[i] " != ptr2->explicit_mask_" var_target_other[i] ")";
		print "    return false;";
	}
}

for (i = 0; i < n_target_int; i++) {
	if (var_target_int[i] in var_target_explicit_mask) {
		print "  if (ptr1->explicit_mask_" var_target_int[i] " != ptr2->explicit_mask_" var_target_int[i] ")";
		print "    return false;";
	}
}

print "  return true;";

print "}";

print "";
print "/* Hash target options  */";
print "hashval_t";
print "cl_target_option_hash (struct cl_target_option const *ptr ATTRIBUTE_UNUSED)";
print "{";
print "  inchash::hash hstate;";
for (i = 0; i < n_target_str; i++) {
	name = var_target_str[i]
	print "  if (ptr->" name")";
	print "    hstate.add (ptr->" name", strlen (ptr->" name"));";
	print "  else";
	print "    hstate.add_int (0);";
}
for (i = 0; i < n_target_array; i++) {
	name= var_target_array[i]
	size = var_target_array_size[i]
	type = var_target_array_type[i]
	print "  hstate.add_int (" size ");";
	print "  hstate.add (ptr->" name ", sizeof (" type ") * " size ");";
}
for (i = 0; i < n_target_val; i++) {
	name = var_target_val[i]
	print "  hstate.add_hwi (ptr->" name");";
}
if (has_target_explicit_mask) {
	print "  for (size_t i = 0; i < ARRAY_SIZE (ptr->explicit_mask); i++)";
	print "    hstate.add_hwi (ptr->explicit_mask[i]);";
}

for (i = 0; i < n_target_other; i++) {
	if (var_target_other[i] in var_target_explicit_mask)
		print "  hstate.add_hwi (ptr->explicit_mask_" var_target_other[i] ");";
}

for (i = 0; i < n_target_int; i++) {
	if (var_target_int[i] in var_target_explicit_mask)
		print "  hstate.add_hwi (ptr->explicit_mask_" var_target_int[i] ");";
}

print "  return hstate.end ();";
print "}";

print "";
print "/* Stream out target options  */";
print "void";
print "cl_target_option_stream_out (struct output_block *ob ATTRIBUTE_UNUSED,";
print "                             struct bitpack_d *bp ATTRIBUTE_UNUSED,";
print "                             struct cl_target_option *ptr ATTRIBUTE_UNUSED)";
print "{";
for (i = 0; i < n_target_str; i++) {
	name = var_target_str[i]
	print "  bp_pack_string (ob, bp, ptr->" name", true);";
}
for (i = 0; i < n_target_array; i++) {
	name = var_target_array[i]
	size = var_target_array_size[i]
	print "  for (unsigned i = 0; i < " size "; i++)"
	print "    bp_pack_value (bp, ptr->" name "[i], 64);";
}
for (i = 0; i < n_target_val; i++) {
	name = var_target_val[i]
	print "  bp_pack_value (bp, ptr->" name", 64);";
}

if (has_target_explicit_mask) {
	print "  for (size_t i = 0; i < ARRAY_SIZE (ptr->explicit_mask); i++)";
	print "    bp_pack_value (bp, ptr->explicit_mask[i], 64);";
}

for (i = 0; i < n_target_other; i++) {
	if (var_target_other[i] in var_target_explicit_mask) {
		print "  bp_pack_value (bp, ptr->explicit_mask_" var_target_other[i] ", 64);";
	}
}

for (i = 0; i < n_target_int; i++) {
	if (var_target_int[i] in var_target_explicit_mask) {
		print "  bp_pack_value (bp, ptr->explicit_mask_" var_target_int[i] ", 64);";
	}
}

print "}";

print "";
print "/* Stream in target options  */";
print "void";
print "cl_target_option_stream_in (struct data_in *data_in ATTRIBUTE_UNUSED,";
print "                            struct bitpack_d *bp ATTRIBUTE_UNUSED,";
print "                            struct cl_target_option *ptr ATTRIBUTE_UNUSED)";
print "{";
for (i = 0; i < n_target_str; i++) {
	name = var_target_str[i]
	print "  ptr->" name" = bp_unpack_string (data_in, bp);";
	print "  if (ptr->" name")";
	print "    ptr->" name" = xstrdup (ptr->" name");";
}
for (i = 0; i < n_target_array; i++) {
	name = var_target_array[i]
	size = var_target_array_size[i]
	print "  for (int i = " size " - 1; i >= 0; i--)"
	print "    ptr->" name "[i] = (" var_target_array_type[i] ") bp_unpack_value (bp, 64);";
}
for (i = 0; i < n_target_val; i++) {
	name = var_target_val[i]
	print "  ptr->" name" = (" var_target_val_type[i] ") bp_unpack_value (bp, 64);";
}

if (has_target_explicit_mask) {
	print "  for (size_t i = 0; i < ARRAY_SIZE (ptr->explicit_mask); i++)";
	print "    ptr->explicit_mask[i] = bp_unpack_value (bp, 64);";
}

for (i = 0; i < n_target_other; i++) {
	if (var_target_other[i] in var_target_explicit_mask) {
		print "  ptr->explicit_mask_" var_target_other[i] " = bp_unpack_value (bp, 64);";
	}
}

for (i = 0; i < n_target_int; i++) {
	if (var_target_int[i] in var_target_explicit_mask) {
		print "  ptr->explicit_mask_" var_target_int[i] " = bp_unpack_value (bp, 64);";
	}
}

print "}";

print "/* free heap memory used by target options  */";
print "void";
print "cl_target_option_free (struct cl_target_option *ptr ATTRIBUTE_UNUSED)";
print "{";
for (i = 0; i < n_target_str; i++) {
	name = var_target_str[i]
	print "  if (ptr->" name")";
	print "    free (const_cast <char *>(ptr->" name"));";
}
print "}";

n_opt_val = 4;
var_opt_val[0] = "x_optimize"
var_opt_val_type[0] = "char "
var_opt_hash[0] = 1;
var_opt_val[1] = "x_optimize_size"
var_opt_val_type[1] = "char "
var_opt_hash[1] = 1;
var_opt_val[2] = "x_optimize_debug"
var_opt_val_type[2] = "char "
var_opt_hash[2] = 1;
var_opt_val[3] = "x_optimize_fast"
var_opt_val_type[3] = "char "
var_opt_hash[3] = 1;
for (i = 0; i < n_sv; i++) {
	if (flag_set_p("(Optimization|PerFunction)", sv_flags[i])) {
		name = var_name(sv_flags[i])
		if(name == "")
			continue;

		if(name in var_opt_list_seen)
			continue;

		var_opt_list_seen[name]++;

		otype = var_type_struct(sv_flags[i])
		var_opt_val_type[n_opt_val] = otype;
		var_opt_val[n_opt_val] = "x_" name;
		var_opt_hash[n_opt_val] = flag_set_p("Optimization", sv_flags[i]);

		# If applicable, optimize streaming for the common case that
		# the current value is unchanged from the 'Init' value:
		# XOR-encode it so that we stream value zero.
		# Not handling non-parameters as those really generally don't
		# have large initializers.
		# Not handling enums as we don't know if '(enum ...) 10' is
		# even valid (see synthesized 'if' conditionals below).
		if (flag_set_p("Param", sv_flags[i]) \
		    && !(otype ~ "^enum ")) {
			# Those without 'Init' are zero-initialized and thus
			# already encoded ideally.
			init = opt_args("Init", sv_flags[i])
			var_opt_optimize_init[n_opt_val] = init;
		}

		# Mark options that are annotated with both Optimization and
		# Target so we can avoid streaming out target-specific opts when
		# offloading is enabled.
		if (flag_set_p("Target", sv_flags[i]))
			var_target_opt[n_opt_val] = 1;

		# These options should not be passed from host to target, but
		# are not actually target specific.
		if (flag_set_p("NoOffload", sv_flags[i]))
			var_target_opt[n_opt_val] = 2;

		n_opt_val++;
	}
}
print "";
print "/* Hash optimization options  */";
print "hashval_t";
print "cl_optimization_hash (struct cl_optimization const *ptr ATTRIBUTE_UNUSED)";
print "{";
print "  inchash::hash hstate;";
for (i = 0; i < n_opt_val; i++) {
	if (!var_opt_hash[i])
		continue;
	name = var_opt_val[i]
	otype = var_opt_val_type[i];
	if (otype ~ "^const char \\**$")
	{
		print "  if (ptr->" name")";
		print "    hstate.add (ptr->" name", strlen (ptr->" name"));";
		print "  else";
		print "    hstate.add_int (0);";
	}
	else
		print "  hstate.add_hwi (ptr->" name");";
}
print "  for (size_t i = 0; i < ARRAY_SIZE (ptr->explicit_mask); i++)";
print "    hstate.add_hwi (ptr->explicit_mask[i]);";
print "  return hstate.end ();";
print "}";

print "";
print "/* Compare two optimization options  */";
print "bool";
print "cl_optimization_option_eq (cl_optimization const *ptr1,";
print "                           cl_optimization const *ptr2)";
print "{";
for (i = 0; i < n_opt_val; i++) {
	if (!var_opt_hash[i])
		continue;
	name = var_opt_val[i]
	otype = var_opt_val_type[i];
	if (otype ~ "^const char \\**$")
	{
		print "  if (ptr1->" name" != ptr2->" name;
		print "      && (!ptr1->" name" || !ptr2->" name
		print "          || strcmp (ptr1->" name", ptr2->" name ")))";
		print "    return false;";
	}
	else
	{
		print "  if (ptr1->" name" != ptr2->" name ")";
		print "    return false;";
	}
}
print "  for (size_t i = 0; i < ARRAY_SIZE (ptr1->explicit_mask); i++)";
print "    if (ptr1->explicit_mask[i] != ptr2->explicit_mask[i])";
print "      return false;"
print "  return true;";
print "}";

print "";
print "/* Stream out optimization options  */";
print "void";
print "cl_optimization_stream_out (struct output_block *ob,";
print "                            struct bitpack_d *bp,";
print "                            struct cl_optimization *ptr)";
print "{";
for (i = 0; i < n_opt_val; i++) {
	name = var_opt_val[i]
	otype = var_opt_val_type[i];
	if (otype ~ "^const char \\**$")
		print "  bp_pack_string (ob, bp, ptr->" name", true);";
	else {
		if (otype ~ "^unsigned") {
			sgn = "unsigned";
		} else {
			sgn = "int";
		}
		# Do not stream out target-specific opts if offloading is
		# enabled.
		if (var_target_opt[i])
			print "  if (!lto_stream_offload_p) {"
		# If applicable, encode the streamed value.
		if (var_opt_optimize_init[i]) {
			print "  if (" var_opt_optimize_init[i] " > (" var_opt_val_type[i] ") 10)";
			print "    bp_pack_var_len_" sgn " (bp, ptr->" name" ^ " var_opt_optimize_init[i] ");";
			print "  else";
			print "    bp_pack_var_len_" sgn " (bp, ptr->" name");";
		} else {
			print "  bp_pack_var_len_" sgn " (bp, ptr->" name");";
		}
		if (var_target_opt[i])
			print "}"
	}
}
print "  for (size_t i = 0; i < ARRAY_SIZE (ptr->explicit_mask); i++)";
print "    bp_pack_value (bp, ptr->explicit_mask[i], 64);";
print "}";

print "";
print "/* Stream in optimization options  */";
print "void";
print "cl_optimization_stream_in (struct data_in *data_in ATTRIBUTE_UNUSED,";
print "                           struct bitpack_d *bp ATTRIBUTE_UNUSED,";
print "                           struct cl_optimization *ptr ATTRIBUTE_UNUSED)";
print "{";
for (i = 0; i < n_opt_val; i++) {
	name = var_opt_val[i]
        if (var_target_opt[i] == 1) {
		print "#ifdef ACCEL_COMPILER"
		print "#error accel compiler cannot define Optimization attribute for target-specific option " name;
		print "#else"
	} else if (var_target_opt[i] == 2) {
		print "#ifdef ACCEL_COMPILER"
		print "  ptr->" name " = global_options." name ";"
		print "#else"
	}
	otype = var_opt_val_type[i];
	if (otype ~ "^const char \\**$") {
		print "  ptr->" name" = bp_unpack_string (data_in, bp);";
		print "  if (ptr->" name")";
		print "    ptr->" name" = xstrdup (ptr->" name");";
	}
	else {
		if (otype ~ "^unsigned") {
			sgn = "unsigned";
		} else {
			sgn = "int";
		}
		print "  ptr->" name" = (" var_opt_val_type[i] ") bp_unpack_var_len_" sgn " (bp);";
		# If applicable, decode the streamed value.
		if (var_opt_optimize_init[i]) {
			print "  if (" var_opt_optimize_init[i] " > (" var_opt_val_type[i] ") 10)";
			print "    ptr->" name" ^= " var_opt_optimize_init[i] ";";
		}
	}
	if (var_target_opt[i])
		print "#endif"
}
print "  for (size_t i = 0; i < ARRAY_SIZE (ptr->explicit_mask); i++)";
print "    ptr->explicit_mask[i] = bp_unpack_value (bp, 64);";
print "}";
print "/* Free heap memory used by optimization options  */";
print "void";
print "cl_optimization_option_free (struct cl_optimization *ptr ATTRIBUTE_UNUSED)";
print "{";
for (i = 0; i < n_opt_val; i++) {
	name = var_opt_val[i]
	otype = var_opt_val_type[i];
	if (otype ~ "^const char \\**$")
	{
	      print "  if (ptr->" name")";
	      print "    free (const_cast <char *>(ptr->" name"));";
	}
}
print "}";

print "void";
print "cl_optimization_compare (gcc_options *ptr1, gcc_options *ptr2)"
print "{"

# all these options are mentioned in PR92860
checked_options["flag_merge_constants"]++
checked_options["param_max_fields_for_field_sensitive"]++
checked_options["flag_omit_frame_pointer"]++
# arc exceptions
checked_options["TARGET_ALIGN_CALL"]++
checked_options["TARGET_CASE_VECTOR_PC_RELATIVE"]++
checked_options["arc_size_opt_level"]++
# arm exceptions
checked_options["arm_fp16_format"]++


for (i = 0; i < n_opts; i++) {
	name = var_name(flags[i]);
	if (name == "")
		continue;

	# We do not want to compare warning-related options, since they
	# might have been modified by a #pragma GCC diagnostic.
	if (flag_set_p("Warning", flags[i]))
		continue;

	if (flag_set_p("NoOffload", flags[i]))
		continue;

	if (name in checked_options)
		continue;
	checked_options[name]++

	if (name in string_options_names || ("x_" name) in string_options_names) {
	  print "  if (ptr1->x_" name " != ptr2->x_" name "";
	  print "      && (!ptr1->x_" name" || !ptr2->x_" name
	  print "          || strcmp (ptr1->x_" name", ptr2->x_" name ")))";
	  print "    internal_error (\"%<global_options%> are modified in local context\");";
	}
	else {
	  print "  if (ptr1->x_" name " != ptr2->x_" name ")"
	  print "    internal_error (\"%<global_options%> are modified in local context\");";
	}
}

print "}";
}
