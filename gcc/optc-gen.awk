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
# Usage: awk -f opt-functions.awk -f opt-read.awk -f optc-gen.awk \
#            [-v header_name=header.h] < inputfile > options.cc

# Record one element of the `global_options_init' brace initializer, keyed the
# way opth-gen.awk keys `struct gcc_options' members so that the two can be
# matched up: the `SetByCombined' booleans live in their own namespace because
# a `bool frontend_set_flag_associative_math' and the `flag_associative_math'
# it shadows are two members with one name.
#
# Recording rather than printing is what lets the SAME four loops feed either
# the historical own-order output (single target -- byte-identical) or the
# union order (multi target).  Deriving both from one place is deliberate: an
# initializer emitted by a second copy of this logic is exactly how the two
# halves come to disagree in the first place.
function gi_add(kind, name, text,   key)
{
	key = kind SUBSEP name
	if (key in gi_text)
		return
	gi_text[key] = text
	gi_order[n_gi++] = key
}

# Dump that array of options into a C file.
END {
n_gi = 0


# Combine the flags of identical switches.  Switches
# appear many times if they are handled by many front
# ends, for example.
for (i = 0; i < n_opts; i++) {
    merged_flags[i] = flags[i]
}
for (i = 0; i < n_opts; i++) {
    while(i + 1 != n_opts && opts[i] == opts[i + 1] ) {
	merged_flags[i + 1] = merged_flags[i] " " merged_flags[i + 1];
	i++;
    }
}

# Record EnabledBy and LangEnabledBy uses.
n_enabledby = 0;
for (i = 0; i < n_langs; i++) {
    n_enabledby_lang[i] = 0;
}
for (i = 0; i < n_opts; i++) {
    enabledby_arg = opt_args("EnabledBy", flags[i]);
    if (enabledby_arg != "") {
        logical_and = index(enabledby_arg, " && ");
        if (logical_and != 0) {
            # EnabledBy(arg1 && arg2)
            split_sep = " && ";
        } else {
            # EnabledBy(arg) or EnabledBy(arg1 || arg2 || arg3)
            split_sep = " \\|\\| ";
        }
        n_enabledby_names = split(enabledby_arg, enabledby_names, split_sep);
        if (logical_and != 0 && n_enabledby_names > 2) {
            print "#error " opts[i] " EnabledBy(Wfoo && Wbar && Wbaz) currently not supported"
        }
        for (j = 1; j <= n_enabledby_names; j++) {
            enabledby_name = enabledby_names[j];
            enabledby_index = opt_numbers[enabledby_name];
            if (enabledby_index == "") {
                print "#error " opts[i] " Enabledby(" enabledby_name "), unknown option '" enabledby_name "'"
            } else if (!flag_set_p("Common", merged_flags[enabledby_index])) {
		print "#error " opts[i] " Enabledby(" enabledby_name "), '" \
		    enabledby_name "' must have flag 'Common'"		\
		    " to use Enabledby(), otherwise use LangEnabledBy()"
	    } else {
		condition = "";
                if (logical_and != 0) {
                    opt_var_name_1 = search_var_name(enabledby_names[1], opt_numbers, opts, flags, n_opts);
                    opt_var_name_2 = search_var_name(enabledby_names[2], opt_numbers, opts, flags, n_opts);
                    if (opt_var_name_1 == "") {
                        print "#error " enabledby_names[1] " does not have a Var() flag"
                    }
                    if (opt_var_name_2 == "") {
                        print "#error " enabledby_names[2] " does not have a Var() flag"
                    }
                    condition = "opts->x_" opt_var_name_1 " && opts->x_" opt_var_name_2;
                }
                if (enables[enabledby_name] == "") {
                    enabledby[n_enabledby] = enabledby_name;
                    n_enabledby++;
                }
                enables[enabledby_name] = enables[enabledby_name] opts[i] ";";
                enablesif[enabledby_name] = enablesif[enabledby_name] condition ";";
            }
        }
    }

    enabledby_arg = opt_args("LangEnabledBy", flags[i]);
    if (enabledby_arg != "") {
	enabledby_n_args = n_args(enabledby_arg)
	if (enabledby_n_args != 2 \
	    && enabledby_n_args != 4) {
	    print "#error " opts[i] " LangEnabledBy(" enabledby_arg ") must specify two or four arguments"
	}

	enabledby_langs = nth_arg(0, enabledby_arg);
	if (enabledby_langs == "")
	    print "#error " opts[i] " LangEnabledBy(" enabledby_arg ") must specify LANGUAGE"
	enabledby_opt = nth_arg(1, enabledby_arg);
	if (enabledby_opt == "")
	    print "#error " opts[i] " LangEnabledBy(" enabledby_arg ") must specify OPT"

	enabledby_posarg_negarg = ""
	if (enabledby_n_args == 4) {
	    enabledby_posarg = nth_arg(2, enabledby_arg);
	    enabledby_negarg = nth_arg(3, enabledby_arg);
	    if (enabledby_posarg == "" \
		|| enabledby_negarg == "")
		print "#error " opts[i] " LangEnabledBy(" enabledby_arg ") with four arguments must specify POSARG and NEGARG"
	    else
		enabledby_posarg_negarg = "," enabledby_posarg "," enabledby_negarg
	}

	n_enabledby_arg_langs = split(enabledby_langs, enabledby_arg_langs, " ");
	n_enabledby_array = split(enabledby_opt, enabledby_array, " \\|\\| ");
	for (k = 1; k <= n_enabledby_array; k++) {
	    enabledby_index = opt_numbers[enabledby_array[k]];
	    if (enabledby_index == "") {
		print "#error " opts[i] " LangEnabledBy(" enabledby_arg "), unknown option '" enabledby_opt "'"
		continue
	    }

	    for (j = 1; j <= n_enabledby_arg_langs; j++) {
		lang_name = enabledby_arg_langs[j]
		lang_index = lang_numbers[lang_name];
		if (lang_index == "") {
		    print "#error " opts[i] " LangEnabledBy(" enabledby_arg "), unknown language '" lang_name "'"
		    continue
		}

		lang_name = lang_sanitized_name(lang_name);

		if (enables[lang_name,enabledby_array[k]] == "") {
		    enabledby[lang_name,n_enabledby_lang[lang_index]] = enabledby_array[k];
		    n_enabledby_lang[lang_index]++;
		}
		enables[lang_name,enabledby_array[k]] \
		    = enables[lang_name,enabledby_array[k]] opts[i] enabledby_posarg_negarg ";";
	    }
	}
    }

    if (flag_set_p("Param", flags[i]) && !(opts[i] ~ "^-param="))
      print "#error Parameter option name '" opts[i] "' must start with '-param='"
}


# PER-BASE Init(), AND WHY IT IS A FUNCTION IN THE BACK END'S OWN FILE.
#
# `-v init_base=<base>' generates options-init-<base>.cc and nothing else.  The
# rest of this script is not run: this output is not an options.cc, it is the
# one piece of options.cc that cannot be written where options.cc is written.
#
# The problem it solves, restated so it is checkable.  `global_options_init'
# below is a static initialiser built from the PRIMARY back end's optionlist,
# over a `struct gcc_options' whose layout is the union of every configured
# back end's (opth-gen.awk).  So every member a non-primary back end has and
# the primary does not is value-initialised: aarch64 sees 0 where aarch64.opt
# said `Init(AARCH64_ABI_DEFAULT)'.
#
# Carrying those Init() arguments into that initialiser does not work, and the
# reason is not tidiness:
#
#   * an Init() argument is a back-end MACRO, not a value.  AARCH64_ABI_DEFAULT
#     is defined in config/aarch64/aarch64.h -- that base's tm.h.  options.cc is
#     compiled with the PRIMARY's tm.h, where the name does not exist.
#   * worse than not existing: DEFAULT_LARGE_SECTION_THRESHOLD is 65536 in
#     config/i386/i386.h and 16 in config/i386/rdos64.h.  A name that resolves
#     to some OTHER configuration's definition compiles clean and is wrong,
#     which is this branch's own recurring failure shape.
#
# So the values are emitted into a translation unit compiled with THAT base's
# tm.h and that base's options.h -- options-init-<base>.cc, which is one of
# that back end's own objects.  multi-target-select.cc calls
# global_options_init_<base> from mt_install_<base>, i.e. at target selection,
# which toplev.cc runs before init_options_struct.
#
# ASSIGNMENTS, not a brace initialiser.  A positional initialiser would have to
# be in union order while this record set is in this base's order, and a
# designated one may not be out of order in C++.  Per member, it also says
# exactly which members this base claims an answer for and leaves every other
# member at whatever the shared initialiser gave it -- which for the members
# both back ends share is the same value, since those come from the same .opt
# files.
if (init_base != "") {
	print "/* This file is auto-generated by optc-gen.awk.  */"
	print ""
	print "#define INCLUDE_MEMORY"
	n_headers = split(header_name, headers, " ")
	for (i = 1; i <= n_headers; i++)
		print "#include " quote headers[i] quote
	print "#include " quote "opts.h" quote
	print "#include " quote "intl.h" quote
	print "#include " quote "insn-attr-common.h" quote
	print ""
	# The same SourceInclude set options.cc gets.  An Init() argument is as
	# likely to be an enumerator from one of these (`DIAGNOSTICS_COLOR_NO',
	# `bidirectional_unpaired') as a target macro, and the whole point of
	# this file is that every name in it resolves where it is written.
	if (n_extra_c_includes > 0) {
		for (i = 0; i < n_extra_c_includes; i++)
			print "#include " quote extra_c_includes[i] quote
		print ""
	}
	print "/* Apply " init_base "'s own Init() values to OPTS.  Called from"
	print "   mt_install_" init_base " in multi-target-select.cc, at target"
	print "   selection.  */"
	print ""
	print "void global_options_init_" init_base " (struct gcc_options *);"
	print ""
	print "void"
	print "global_options_init_" init_base " (struct gcc_options *opts)"
	print "{"

	n_init = 0

	# `Variable' records that carry their own initialiser, e.g.
	# `Variable(int foo = 3)'.  Same treatment: the initialiser is a back-end
	# expression and belongs here.
	for (i = 0; i < n_extra_vars; i++) {
		var = extra_vars[i]
		if (var !~ "=")
			continue
		init = var
		sub(".*= *", "", init)
		sub(" *=.*", "", var)
		name = var
		sub("^.*[ *]", "", name)
		if (name ~ "\\[")
			continue
		sub("\\[.*\\]$", "", name)
		print "  opts->x_" name " = " init ";"
		n_init++
		seen_init[name] = 1
	}

	for (i = 0; i < n_opts; i++) {
		name = var_name(flags[i])
		if (name == "")
			continue
		init = opt_args("Init", flags[i])
		if (init == "")
			continue
		if (name in seen_init)
			continue
		# Private state: options.cc gives these a member and then
		# `#undef x_<name>', so `opts->x_<name>' does not name it here.
		if (static_var(opts[i], flags[i]) != "")
			continue
		seen_init[name] = 1
		print "  opts->x_" name " = " init ";"
		n_init++
	}

	# An empty body would compile, link, and quietly restore exactly the bug
	# this file exists to fix -- every one of this base's Init() values left
	# at zero, with the selector calling a function that does nothing.  A
	# back end with no Init() at all does not exist (the common .opt files
	# alone supply dozens), so zero here means the record set did not reach
	# this script.
	if (n_init == 0)
		print "#error options-init-" init_base ".cc: no Init() values at all; the optionlist for this back end did not reach optc-gen.awk"

	print "}"
	exit
}

# PER-BASE `cl_options[]' AND `cl_enums[]', AND WHY THEY CANNOT BE UNIONED.
#
# `-v tables_base=<base>' generates mt-<base>/options-tables.cc: the two option
# TABLES under names of that base's own, and nothing else.
#
# The vocabulary is already unioned (opt-stub.awk), so `enum opt_code' ordinals
# and hence the INDEX of every entry agree between bases.  What does not agree
# is what the entry SAYS.  Measured on i386 + aarch64, thirteen option names are
# declared by both back ends with different records, six of them with a
# different `Enum()':
#
#     mabi=      i386 Enum(calling_abi)  Var(ix86_abi)
#                a64  Enum(aarch64_abi)  Var(aarch64_abi)
#     mcmodel=   i386 Enum(cmodel)       a64 Enum(aarch64_cmodel)
#     mtls-dialect=, mstack-protector-guard=, mharden-sls=, mcpu=, ...
#
# There is ONE `cl_options[]' in the compiler and it was built from the PRIMARY
# back end's optionlist, so `-mabi=' was validated against i386's `calling_abi'
# whatever target had been selected:
#
#     xgcc: error: unrecognized argument in option '-mabi=lp64'
#     xgcc: note: valid arguments to '-mabi=' are: ms sysv
#
# on a driver whose selected target was aarch64.  A union is not available here
# and that is not a limitation of the mechanism: `-mabi=' has exactly one
# meaning per target and merging the two argument lists would make `lp64' a
# valid x86 ABI.  The table is DATA, kept per configuration, selected at run
# time -- multi-target-options-select.cc.
#
# Compiled with -I<base>-inc for the same reason options-init-<base>.cc is: an
# `EnumValue(... Value(AARCH64_ABI_LP64))' is a back-end MACRO, not a value, and
# in this file it must resolve in ITS OWN back end's tm.h.
if (tables_base != "" && init_base != "") {
	print "#error optc-gen.awk: -v tables_base= and -v init_base= are exclusive"
	exit 1
}
# The suffix every table name carries.  Empty when this is an ordinary
# options.cc, so a single-target build emits exactly the names it always did.
tab_sfx = (tables_base == "" ? "" : "_" tables_base)

# An ordinary options.cc in a MULTI-TARGET build emits neither table: they come
# from the per-base files above, and `cl_options'/`cl_enums' are pointers there
# (opts.h) rather than arrays.  Emitting them here as well would not merely be
# dead weight -- it would be a second definition of the primary's answer under
# the shared name, i.e. exactly the privileged default this removes.
emit_tables = (tables_base != "" || union_file == "")

# `macros[]' IS NOT A LOCAL OF THE lang_names[] LOOP, however much it looks
# like one.  opt-functions.awk's switch_flags() reads it to build the
# `CL_C | CL_CXX | ...' language mask of every cl_options[] entry, and it used
# to be filled as a side effect of printing lang_names[].  Guarding that print
# left the array empty and every mask came out as ` | | | | CL_WARNING' --
# caught here only because it happens not to be valid C++.  Filled on its own,
# before anything can read it.
for (i = 0; i < n_langs; i++)
	macros[i] = "CL_" lang_sanitized_name(langs[i])

print "/* This file is auto-generated by optc-gen.awk.  */"
print ""
print "#define INCLUDE_MEMORY"
n_headers = split(header_name, headers, " ")
for (i = 1; i <= n_headers; i++)
	print "#include " quote headers[i] quote
print "#include " quote "opts.h" quote
print "#include " quote "intl.h" quote
print "#include " quote "insn-attr-common.h" quote
print ""

if (n_extra_c_includes > 0) {
	for (i = 0; i < n_extra_c_includes; i++) {
		print "#include " quote extra_c_includes[i] quote
	}
	print ""
}

for (i = 0; emit_tables && i < n_enums; i++) {
	name = enum_names[i]
	type = enum_type[name]
	print "static const struct cl_enum_arg cl_enum_" name \
	    "_data[] = "
	print "{"
	print enum_data[name] "  { NULL, 0, 0 }"
	print "};"
	print ""
	print "static void"
	print "cl_enum_" name "_set (void *var, int value)"
	print "{"
	print "  *((" type " *) var) = (" type ") value;"
	print "}"
	print ""
	print "static int"
	print "cl_enum_" name "_get (const void *var)"
	print "{"
	print "  return (int) *((const " type " *) var);"
	print "}"
	print ""
}

if (emit_tables) {
if (tables_base != "")
	print "extern const struct cl_enum cl_enums" tab_sfx "[];"
print "const struct cl_enum cl_enums" tab_sfx "[] ="
print "{"
for (i = 0; i < n_enums; i++) {
	name = enum_names[i]
	ehelp = enum_help[name]
	if (ehelp == "")
		ehelp = "NULL"
	else
		ehelp = quote ehelp quote
	unknown_error = enum_unknown_error[name]
	if (unknown_error == "")
		unknown_error = "NULL"
	else
		unknown_error = quote unknown_error quote
	print "  {"
	print "    " ehelp ","
	print "    " unknown_error ","
	print "    cl_enum_" name "_data,"
	print "    sizeof (" enum_type[name] "),"
	print "    cl_enum_" name "_set,"
	print "    cl_enum_" name "_get"
	print "  },"
}
print "};"
if (tables_base != "")
	print "extern const unsigned int cl_enums" tab_sfx "_count;"
print "const unsigned int cl_enums" tab_sfx "_count = " n_enums ";"
print ""
}

# Everything below goes into a STATIC INITIALIZER, so every Init() argument has
# to be a constant expression -- and, in a compiler that serves many targets, a
# constant correct for all of them.  An answer probed from one assembler or
# chosen by a `case $target' is not one; it is a per-target value compiled in as
# everybody's, and nothing here can diagnose that.  Put the floor in Init() and
# set the real default from TARGET_OPTION_INIT_STRUCT.  See "Init(value)" in
# doc/options.texi, and mips_option_init_struct for the worked example.
#
# MULTI-TARGET, AND WHY Init() IS NOT UNIONED HERE.
#
# This is a POSITIONAL brace initializer.  `struct gcc_options' now has the
# union layout (opth-gen.awk), and this list is still built from the primary
# back end's optionlist, so it initialises the union's leading run and leaves
# the tail value-initialised.  That is well defined only because the union is
# first-appearance order with the primary FIRST -- the leading run IS the
# primary's member list, in order.  Anything that reorders the union breaks
# this silently, with a type-compatible value landing in the wrong member; the
# check is that `head -<n primary members>' of the union list still equals the
# primary's own list.
#
# The tail being zero is a real defect: a non-primary back end sees 0 where its
# .opt file said Init(...).  It is NOT fixed by carrying Init() into this list,
# and the reason is not tidiness:
#
#   * an Init() argument is a back-end MACRO, not a value.  aarch64.opt says
#     Init(AARCH64_ABI_DEFAULT), which config/aarch64/aarch64.h defines -- i.e.
#     that base's tm.h.  This file is compiled with the PRIMARY's tm.h, where
#     the name does not exist.
#   * worse than not existing: DEFAULT_LARGE_SECTION_THRESHOLD is defined by
#     config/i386/i386.h as 65536 and by config/i386/rdos64.h as 16.  A name
#     that resolves to some other configuration's definition compiles clean and
#     is wrong, which is the failure shape this whole branch is removing.
#
# So Init() is DATA and belongs where that base's tm.h is in scope: a per-base
# `global_options_init_<base>' emitted into the back end's own translation
# unit, with the selector choosing one at startup.  That is the selector's
# commit, not this one.  Layout is what is settled here.
# Matches the declaration opth-gen.awk emits: NOT const in a multi-target
# build, because multi-target-select.cc applies the selected back end's own
# Init() values to it at target selection.  See the note above.
if (tables_base == "") {
print (union_file != "" ? "struct gcc_options global_options_init =\n{" : "const struct gcc_options global_options_init =\n{")
for (i = 0; i < n_extra_vars; i++) {
	var = extra_vars[i]
	init = extra_vars[i]
	if (var ~ "=" ) {
		sub(".*= *", "", init)
	} else {
		init = "0"
	}
	sub(" *=.*", "", var)
	name = var
	sub("^.*[ *]", "", name)
	sub("\\[.*\\]$", "", name)
	var_seen[name] = 1
	gi_add("X", name, "  " init ", /* " name " */")
}
for (i = 0; i < n_opts; i++) {
	name = var_name(flags[i]);
	init = opt_args("Init", flags[i])

	if (name == "") {
		if (init != "")
		    print "#error " opts[i] " must specify Var to use Init"
		continue;
	}

	if (init != "") {
		if (name in var_init && var_init[name] != init)
			print "#error multiple initializers for " name
		var_init[name] = init
	}
}
for (i = 0; i < n_opts; i++) {
	name = var_name(flags[i]);
	if (name == "")
		continue;

	if (name in var_seen)
		continue;

	if (name in var_init)
		init = var_init[name]
	else
		init = "0"

	gi_add("X", name, "  " init ", /* " name " */")

	var_seen[name] = 1;
}
for (i = 0; i < n_opts; i++) {
	name = static_var(opts[i], flags[i]);
	if (name != "")
		gi_add("X", name, "  0, /* " name " (private state) */\n" \
				  "#undef x_" name)
}
for (i = 0; i < n_opts; i++) {
	if (flag_set_p("SetByCombined", flags[i]))
		gi_add("F", var_name(flags[i]),
		       "  false, /* frontend_set_" var_name(flags[i]) " */")
}

# THE INITIALIZER IS POSITIONAL, SO ITS ELEMENT SEQUENCE *IS* A CLAIM ABOUT
# `struct gcc_options'.  Nothing in the build compares the two files, so when
# the claim is wrong the compiler does not say so: a value lands on the member
# after the one it was written for, and it only becomes visible if the types
# happen to be incompatible.  Measured, x86_64 + x86_64-wrs-vxworks7, before
# this change: 1674 elements for a 1669-member struct, and the disagreement
# ran in BOTH directions at once -- five members the initializer invented (the
# `Target Undocumented' placeholders, see opt-stub.awk) and two it was missing
# (`vxworks_flags', the struct 13th member, and `VAR_mvthreads').  From
# element 13 onward every value was on the wrong member.  What the compiler
# said about that was `options.cc:1713:1: error: too many initializers for
# gcc_options' -- i.e. it noticed the count and nothing at all about the
# 1656 misplaced values, which is what it would have been left with had the
# two errors cancelled.
#
# Single target: `union_file' is empty, the four loops above are the four
# loops that were always here, and this prints them in the order they ran --
# byte-identical output.
#
# Multi target: `struct gcc_options' takes its layout from the union list, and
# a positional initializer built from anything else is guessing.  The two
# option sets are NOT the same and neither contains the other by construction:
#
#   * this file is generated from the SHARED optionlist, whose target records
#     are `extra_opt_files' -- the .opt files of the PRIMARY TRIPLE;
#   * the layout comes from gcc-options-<base>.part, generated from
#     `optionlist-<base>', whose target records are the .opt files of EVERY
#     TRIPLE mapping to that back end.
#
# `x86_64-wrs-vxworks7' and `x86_64-pc-linux-gnu' are two triples of the one
# i386 back end, so vxworks.opt is in the second set and not the first, and
# `vxworks_flags' and `VAR_mvthreads' are members of the struct that this file
# had no record for.  The stub padding cannot supply them either -- a stub
# carries no Var() and no Init(), by design -- so the sequence has to be taken
# from the union itself.
#
# Members this back end has no record for are `{}': value-initialisation,
# which is what the tail was already getting, spelled so that it is correct
# for an enum or a pointer as well as for an int.  (`0' is not: `enum E e = 0'
# is ill-formed C++, which is how the shifted initializer above announced
# itself.)  Init() values are NOT unioned here and that is settled -- see the
# long note above -- they are applied per base by the selector.
if (union_file == "") {
	for (i = 0; i < n_gi; i++)
		print gi_text[gi_order[i]]
} else {
	n_um = 0
	while ((getline uline < union_file) > 0) {
		if (uline ~ /^base /)
			continue
		nuf = split(uline, uf, "\t")
		if (nuf == 0 || uf[1] == "")
			continue
		# Only the four member kinds.  Everything else in the list
		# (I/R/D/X/E/H/C) describes something other than a
		# `struct gcc_options' member and must not take a slot.
		if (uf[1] != "V" && uf[1] != "O" && uf[1] != "S" && uf[1] != "F")
			continue
		ukey = (uf[1] == "F" ? "F" : "X") SUBSEP uf[2]
		if (ukey in um_seen)
			continue
		um_seen[ukey] = 1
		um_kind[n_um] = uf[1]
		um_name[n_um] = uf[2]
		um_key[n_um] = ukey
		n_um++
	}
	close(union_file)
	# A union list that yielded no members would silently turn this
	# initializer into `{}' for everything -- every Init() in the compiler
	# reading zero, with no diagnostic anywhere.  Fail by name instead.
	if (n_um == 0)
		print "#error optc-gen.awk: " union_file " yielded no `struct gcc_options' member records; `global_options_init' would initialise nothing"
	for (i = 0; i < n_um; i++) {
		if (um_key[i] in gi_text) {
			print gi_text[um_key[i]]
			gi_used[um_key[i]] = 1
			continue
		}
		if (um_kind[i] == "F")
			print "  {}, /* frontend_set_" um_name[i] " (another back end) */"
		else if (um_kind[i] == "S")
			print "  {}, /* " um_name[i] " (private state, another back end) */\n" \
			      "#undef x_" um_name[i]
		else
			print "  {}, /* " um_name[i] " (another back end) */"
	}
	# The other direction, and the one a prefix check cannot see: an
	# element this file has that the struct does not.  It cannot be
	# absorbed -- there is no slot for it -- so it is a hard error rather
	# than a dropped line, which would shift everything after it.
	for (i = 0; i < n_gi; i++)
		if (!(gi_order[i] in gi_used)) {
			gname = substr(gi_order[i], index(gi_order[i], SUBSEP) + 1)
			print "#error optc-gen.awk: `global_options_init' has an element for `" gname "' and " union_file " has no such member; the shared optionlist and the union list disagree"
		}
}
print "};"
print ""
print "struct gcc_options global_options;"
print "struct gcc_options global_options_set;"
print ""

print "const char * const lang_names[] =\n{"
for (i = 0; i < n_langs; i++)
	print "  " quote langs[i] quote ","

print "  0\n};\n"
print "const unsigned int cl_options_count = N_OPTS;\n"
print "#if (1U << " n_langs ") > CL_MIN_OPTION_CLASS"
print "  #error the number of languages exceeds the implementation limit"
print "#endif"
print "const unsigned int cl_lang_count = " n_langs ";\n"
}

if (!emit_tables) {
	# THE SKIPPED LOOP HAD A SIDE EFFECT, AND IT COMPILES EITHER WAY.
	#
	# The cl_options[] loop below merges the flags of duplicate option
	# records IN PLACE -- `flags[i + 1] = flags[i] " " flags[i + 1]' -- and
	# everything after it reads the merged result.
	# common_handle_option_auto asks var_name(flags[opt_numbers[...]]) and
	# emits `#error <opt> does not have a Var() flag' when the Var() sat on
	# a record that did not survive unmerged.  So skipping the loop does
	# not merely skip output; it changes what the REST of this file
	# computes.
	#
	# merged_flags[] at the top of this END block is the same merge done
	# into a copy, so assigning it back is the loop's effect without the
	# loop -- derived from that code rather than transcribed a second time.
	#
	# AND IT HAS TO BE HERE, not earlier.  Everything ABOVE this point --
	# global_options_init, in particular -- ran against the UNMERGED flags
	# and must keep doing so: hoisting this to the top of the file gave
	# `frontend_set_flag_signed_zeros' two entries in a positional brace
	# initialiser, which shifted every member after it and showed up as
	# `cannot convert bool to aarch64_arch' several hundred lines away.
	for (i = 0; i < n_opts; i++)
		flags[i] = merged_flags[i]

	# Say why the file simply stops here rather than leaving a reader to
	# discover that `cl_options' is absent.
	print "/* `cl_options[]' and `cl_enums[]' are NOT emitted here.  This is a"
	print "   multi-target build: they are per-configuration data, generated"
	print "   into mt-<base>/options-tables.cc and selected at run time by"
	print "   multi-target-options-select.cc.  Emitting the primary's answer"
	print "   under the shared name is the bug -- `-mabi=lp64' validated"
	print "   against i386's `calling_abi' on an aarch64 target.  */"
	print ""
}

if (tables_base != "") {
	# PRIVATE STATE.  opth-gen.awk gives each `Var(VAR_<opt>)' option a
	# member and then `#define x_VAR_<opt> do_not_use', so that only the
	# generated option machinery can reach it.  options.cc cancels the
	# poison where it needs the name -- in the global_options_init loop
	# below -- and this file needs it in exactly the same place, the
	# `offsetof' of each cl_options[] entry.  Without these, the build says
	#
	#     error: `struct gcc_options' has no member named `do_not_use'
	#
	# which names the poison rather than the option and points at the
	# header rather than here.
	for (i = 0; i < n_opts; i++) {
		name = static_var(opts[i], flags[i])
		if (name != "")
			print "#undef x_" name
	}
	print ""
}

if (emit_tables) {
if (tables_base != "")
	print "extern const struct cl_option cl_options" tab_sfx "[];"
print "const struct cl_option cl_options" tab_sfx "[] =\n{"

j = 0
for (i = 0; i < n_opts; i++) {
	back_chain[i] = "N_OPTS";
	indices[opts[i]] = j;
	# Combine the flags of identical switches.  Switches
	# appear many times if they are handled by many front
	# ends, for example.
	while( i + 1 != n_opts && opts[i] == opts[i + 1] ) {
		flags[i + 1] = flags[i] " " flags[i + 1];
		if (help[i + 1] == "")
			help[i + 1] = help[i]
		else if (help[i] != "" && help[i + 1] != help[i]) {
			print "#error Multiple different help strings for " \
				opts[i] ":"
			print "#error   " help[i]
			print "#error   " help[i + 1]
		}
				
		i++;
		back_chain[i] = "N_OPTS";
		indices[opts[i]] = j;
	}
	j++;
}

optindex = 0
for (i = 0; i < n_opts; i++) {
	# With identical flags, pick only the last one.  The
	# earlier loop ensured that it has all flags merged,
	# and a nonempty help text if one of the texts was nonempty.
	while( i + 1 != n_opts && opts[i] == opts[i + 1] ) {
		i++;
	}

	len = length (opts[i]);
	enum = opt_enum(opts[i])

	# Do not allow Joined and Separate properties if
	# an options ends with '='.
	if (flag_set_p("Joined", flags[i]) && flag_set_p("Separate", flags[i]) && opts[i] ~ "=$") {
		print "#error Option '" opts[i] "' ending with '=' cannot have " \
			"both Joined and Separate properties"
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

	s = substr("                                  ", length (opts[i]))
	if (i + 1 == n_opts)
		comma = ""

	if (help[i] == "")
		hlp = "NULL"
	else
		hlp = quote help[i] quote;

	missing_arg_error = opt_args("MissingArgError", flags[i])
	if (missing_arg_error == "")
		missing_arg_error = "NULL"
	else
		missing_arg_error = quote missing_arg_error quote


	warn_message = opt_args("Warn", flags[i])
	if (warn_message == "")
		warn_message = "NULL"
	else
		warn_message = quote warn_message quote

	alias_arg = opt_args("Alias", flags[i])
	if (alias_arg == "") {
		if (flag_set_p("Ignore", flags[i])) {
			  alias_data = "NULL, NULL, OPT_SPECIAL_ignore"
        if (warn_message != "NULL")
				  print "#error Ignored option with Warn"
        if (var_name(flags[i]) != "")
				  print "#error Ignored option with Var"
      }
    else if (flag_set_p("Deprecated", flags[i]))
        print "#error Deprecated was replaced with WarnRemoved"
    else if (flag_set_p("WarnRemoved", flags[i])) {
			  alias_data = "NULL, NULL, OPT_SPECIAL_warn_removed"
        if (warn_message != "NULL")
				  print "#error WarnRemoved option with Warn"
      }
		else
			alias_data = "NULL, NULL, N_OPTS"
		if (flag_set_p("Enum.*", flags[i])) {
			if (!flag_set_p("RejectNegative", flags[i]) \
			    && !flag_set_p("EnumSet", flags[i]) \
			    && !flag_set_p("EnumBitSet", flags[i]) \
			    && opts[i] ~ "^[Wfgm]")
				print "#error Enum allowing negative form"
		}
	} else {
		alias_opt = nth_arg(0, alias_arg)
		alias_posarg = nth_arg(1, alias_arg)
		alias_negarg = nth_arg(2, alias_arg)

		if (var_ref(opts[i], flags[i]) != "(unsigned short) -1")
			print "#error Alias setting variable"

		if (alias_posarg != "" && alias_negarg == "") {
			if (!flag_set_p("RejectNegative", flags[i]) \
			    && opts[i] ~ "^[Wfm]")
				print "#error Alias with single argument " \
					"allowing negative form"
		}
		if (alias_posarg != "" \
		    && flag_set_p("NegativeAlias", flags[i])) {
			print "#error Alias with multiple arguments " \
				"used with NegativeAlias"
		}

		alias_opt = opt_enum(alias_opt)
		if (alias_posarg == "")
			alias_posarg = "NULL"
		else
			alias_posarg = quote alias_posarg quote
		if (alias_negarg == "")
			alias_negarg = "NULL"
		else
			alias_negarg = quote alias_negarg quote
		alias_data = alias_posarg ", " alias_negarg ", " alias_opt
	}

	neg = opt_args("Negative", flags[i]);
	if (neg != "")
		idx = indices[neg]
	else {
		if (flag_set_p("RejectNegative", flags[i]))
			idx = -1;
		else {
			if (opts[i] ~ "^[Wfgm]")
				idx = indices[opts[i]];
			else
				idx = -1;
		}
	}
	# Split the printf after %u to work around an ia64-hp-hpux11.23
	# awk bug.
	printf(" /* [%i] = */ {\n", optindex)
	printf("    %c-%s%c,\n    %s,\n    %s,\n    %s,\n    %s, %s, %u,",
	       quote, opts[i], quote, hlp, missing_arg_error, warn_message,
	       alias_data, back_chain[i], len)
	printf(" /* .neg_idx = */ %d,\n", idx)
	condition = opt_args("Condition", flags[i])
	cl_flags = switch_flags(flags[i])
	cl_bit_fields = switch_bit_fields(flags[i])
	cl_zero_bit_fields = switch_bit_fields("")
	if (condition != "")
		printf("#if %s\n" \
		       "    %s,\n" \
		       "    0, %s,\n" \
		       "#else\n" \
		       "    0,\n" \
		       "    1 /* Disabled.  */, %s,\n" \
		       "#endif\n",
		       condition, cl_flags, cl_bit_fields, cl_zero_bit_fields)
	else
		printf("    %s,\n" \
		       "    0, %s,\n",
		       cl_flags, cl_bit_fields)
	printf("    %s, %s, %s }%s\n", var_ref(opts[i], flags[i]),
	       var_set(flags[i]), integer_range_info(opt_args("IntegerRange", flags[i]),
		    opt_args("Init", flags[i]), opts[i], flag_set_p("UInteger", flags[i])), comma)

	# Bump up the informational option index.
	++optindex
 }

print "};"
}

# mt-<base>/options-tables.cc is the two tables and NOTHING else.  Everything
# below -- common_handle_option_auto, the cpp glue -- is target-independent
# code that must exist exactly once in the compiler; a per-base copy of it
# would not link.
if (tables_base != "") {
	# A generator that computes the right answer and discards it, and a
	# generator that fails and exits 0, have both happened on this branch.
	# A tables file with no options in it would compile, link, and leave a
	# selected back end answering with an empty option table -- every
	# option "unrecognized", which reads as a driver bug.
	if (n_opts == 0)
		print "#error mt-" tables_base "/options-tables.cc: no option records at all; the optionlist for this back end did not reach optc-gen.awk"
	if (n_enums == 0)
		print "#error mt-" tables_base "/options-tables.cc: no Enum() records at all; -mabi= and friends would have no argument list"
	exit
}

print "\n\n"
print "bool                                                                  "
print "common_handle_option_auto (struct gcc_options *opts,                  "
print "                           struct gcc_options *opts_set,              "
print "                           const struct cl_decoded_option *decoded,   "
print "                           unsigned int lang_mask, int kind,          "
print "                           location_t loc,                            "
print "                           const struct cl_option_handlers *handlers, "
print "                           diagnostics::context *dc)                  "
print "{                                                                     "
print "  size_t scode = decoded->opt_index;                                  "
print "  HOST_WIDE_INT value = decoded->value;                               "
print "  enum opt_code code = (enum opt_code) scode;                         "
print "                                                                      "
print "  gcc_assert (decoded->canonical_option_num_elements <= 2);           "
print "                                                                      "
print "  switch (code)                                                       "
print "    {                                                                 "
# Handle EnabledBy
for (i = 0; i < n_enabledby; i++) {
    enabledby_name = enabledby[i];
    print "    case " opt_enum(enabledby_name) ":"
    n_enables = split(enables[enabledby_name], thisenable, ";");
    n_enablesif = split(enablesif[enabledby_name], thisenableif, ";");
    if (n_enables != n_enablesif) {
        print "#error n_enables != n_enablesif: Something went wrong!"
    }
    for (j = 1; j < n_enables; j++) {
        opt_var_name = var_name(flags[opt_numbers[thisenable[j]]]);
        if (opt_var_name != "") {
            condition = "!opts_set->x_" opt_var_name
            if (thisenableif[j] != "") {
                value = "(" thisenableif[j] ")"
            } else {
                value = "value"
            }
            print "      if (" condition ")"
            print "        handle_generated_option (opts, opts_set,"
            print "                                 " opt_enum(thisenable[j]) ", NULL, " value ","
            print "                                 lang_mask, kind, loc, handlers, true, dc);"
        } else {
            print "#error " thisenable[j] " does not have a Var() flag"
        }
    }
    print "      break;\n"
}
print "    default:    "
print "      break;    "
print "    }           "
print "  return true;  "
print "}               "

# Handle LangEnabledBy
for (i = 0; i < n_langs; i++) {
    lang_name = lang_sanitized_name(langs[i]);
    mark_unused = " ATTRIBUTE_UNUSED";

    print "\n\n"
    print "bool                                                                  "
    print lang_name "_handle_option_auto (struct gcc_options *opts" mark_unused ",              "
    print "                           struct gcc_options *opts_set" mark_unused ",              "
    print "                           size_t scode" mark_unused ", const char *arg" mark_unused ", HOST_WIDE_INT value" mark_unused ",  "
    print "                           unsigned int lang_mask" mark_unused ", int kind" mark_unused ",          "
    print "                           location_t loc" mark_unused ",                            "
    print "                           const struct cl_option_handlers *handlers" mark_unused ", "
    print "                           diagnostics::context *dc" mark_unused ")                  "
    print "{                                                                     "
    print "  enum opt_code code = (enum opt_code) scode;                         "
    print "                                                                      "
    print "  switch (code)                                                       "
    print "    {                                                                 "
    
    for (k = 0; k < n_enabledby_lang[i]; k++) {
        enabledby_name = enabledby[lang_name,k];
        print "    case " opt_enum(enabledby_name) ":"
        n_thisenable = split(enables[lang_name,enabledby_name], thisenable, ";");
        for (j = 1; j < n_thisenable; j++) {
            n_thisenable_args = split(thisenable[j], thisenable_args, ",");
            if (n_thisenable_args == 1) {
                thisenable_opt = thisenable[j];
                value = "value";
            } else {
                thisenable_opt = thisenable_args[1];
                with_posarg = thisenable_args[2];
                with_negarg = thisenable_args[3];
                value = "value ? " with_posarg " : " with_negarg;
            }
            opt_var_name = var_name(flags[opt_numbers[thisenable_opt]]);
            if (opt_var_name != "") {
                print "      if (!opts_set->x_" opt_var_name ")"
                print "        handle_generated_option (opts, opts_set,"
                print "                                 " opt_enum(thisenable_opt) ", NULL, " value ","
                print "                                 lang_mask, kind, loc, handlers, true, dc);"
            } else {
                print "#error " thisenable_opt " does not have a Var() flag"
            }
        }
        print "      break;\n"
    }
    print "    default:    "
    print "      break;    "
    print "    }           "
    print "  return true;  "
    print "}               "
}

#Handle CPP()
print "\n"
print "#include " quote "cpplib.h" quote;
print "void"
print "cpp_handle_option_auto (const struct gcc_options * opts,                   "
print "                        size_t scode, struct cpp_options * cpp_opts)"    
print "{                                                                     "
print "  enum opt_code code = (enum opt_code) scode;                         "
print "                                                                      "
print "  switch (code)                                                       "
print "    {                                                                 "
for (i = 0; i < n_opts; i++) {
    # With identical flags, pick only the last one.  The
    # earlier loop ensured that it has all flags merged,
    # and a nonempty help text if one of the texts was nonempty.
    while( i + 1 != n_opts && opts[i] == opts[i + 1] ) {
        i++;
    }

    cpp_option = nth_arg(0, opt_args("CPP", flags[i]));
    if (cpp_option != "") {
        opt_var_name = var_name(flags[i]);
        init = opt_args("Init", flags[i])
        if (opt_var_name != "" && init != "") {
            print "    case " opt_enum(opts[i]) ":"
            print "      cpp_opts->" cpp_option " = opts->x_" opt_var_name ";"
            print "      break;"
        } else if (opt_var_name == "" && init == "") {
            print "#error CPP() requires setting Init() and Var() for " opts[i]
        } else if (opt_var_name != "") {
            print "#error CPP() requires setting Init() for " opts[i]
        } else {
            print "#error CPP() requires setting Var() for " opts[i]
        }
    }
}
print "    default:    "
print "      break;    "
print "    }           "
print "}\n"
print "void"
print "init_global_opts_from_cpp(struct gcc_options * opts,                   "
print "                         const struct cpp_options * cpp_opts)"    
print "{                                                                     "
for (i = 0; i < n_opts; i++) {
    # With identical flags, pick only the last one.  The
    # earlier loop ensured that it has all flags merged,
    # and a nonempty help text if one of the texts was nonempty.
    while( i + 1 != n_opts && opts[i] == opts[i + 1] ) {
        i++;
    }
    cpp_option = nth_arg(0, opt_args("CPP", flags[i]));
    opt_var_name = var_name(flags[i]);
    if (cpp_option != "" && opt_var_name != "") {
        print "  opts->x_" opt_var_name " = cpp_opts->" cpp_option ";"
    }
}
print "}               "

split("", var_seen, ":")
print "\n#if !defined(GENERATOR_FILE) && defined(ENABLE_PLUGIN)"
print "DEBUG_VARIABLE const struct cl_var cl_vars[] =\n{"

for (i = 0; i < n_opts; i++) {
	name = var_name(flags[i]);
	if (name == "")
		continue;
	var_seen[name] = 1;
}

for (i = 0; i < n_extra_vars; i++) {
	var = extra_vars[i]
	sub(" *=.*", "", var)
	name = var
	sub("^.*[ *]", "", name)
	sub("\\[.*\\]$", "", name)
	if (name in var_seen)
		continue;
	print "  { " quote name quote ", offsetof (struct gcc_options, x_" name ") },"
	var_seen[name] = 1
}

print "  { NULL, (unsigned short) -1 }\n};\n#endif"

}
