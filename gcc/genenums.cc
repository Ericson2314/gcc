/* Generate from machine description the strings for each enum.
   Copyright (C) 2010-2026 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option)
any later version.

GCC is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GCC; see the file COPYING3.  If not see
<http://www.gnu.org/licenses/>.  */

#include "bconfig.h"
#include "system.h"
#include "coretypes.h"
/* genenums reads no target macro and no insn pattern; its output depends on
   the md files alone.  It needs print_gen_include / gen_target_ns, so that
   the insn-constants.h named below carries GEN_HDR_SUFFIX and so that the
   tables here agree with the declarations genconstants writes.  Those come
   from gen-target-ns.h, which reaches no target header -- NOT from
   gensupport.h, which needs rtl.h, which wants FIRST_PSEUDO_REGISTER, which
   comes out of insn-constants.h.  genconstants.cc explains why that matters;
   genenums is kept on the same footing so the two cannot drift apart.  */
#include "errors.h"
#include "statistics.h"
#include "vec.h"
#include "read-md.h"
#include "gen-target-ns.h"

/* The enum types the MIDDLE END names bare and unconditionally.  Every back
   end must export a table and a length for each of these, because
   multi-target-select.cc's MT_OTHER_TABLES / MT_SCALAR_TABLES declare and
   install them for ALL configured back ends -- not for the subset whose md
   happens to declare the enum.

   Only 20 of the 48 back ends write `define_c_enum "unspecv"'; the other 28
   emitted no unspecv_strings and no unspecv_strings_len at all, so the
   installer referenced symbols that were never defined and cc1 failed to
   link with `undefined reference to insn_<base>::unspecv_strings'.  */
static const char *const mt_required_enums[] = { "unspec", "unspecv" };

/* Set as each enum type is emitted, so main () can tell which of the above
   the md did NOT supply.  */
static bool mt_required_seen[ARRAY_SIZE (mt_required_enums)];

/* Emit the EMPTY form of one of those tables: a real per-back-end answer,
   not a borrowed one.  This back end genuinely has no names for this enum,
   and a length of 0 says exactly that -- every consumer bound is
   `i < <enum>_strings_len', so no index is ever accepted and no other back
   end's strings can be reached.  Note this is NOT an `#ifndef' floor
   supplying the primary's value; the primary's table is not consulted.

   A one-element dummy rather than a zero-length array: `T x[] = {}' is a GCC
   extension rather than valid C++, and the LENGTH is what any consumer
   reads, never ARRAY_SIZE of this object.  */
static void
print_empty_enum_type (const char *name)
{
  printf ("\n/* This back end's md declares no `%s' enum.  Empty table with"
	  "\n   length 0: the bound refuses every index.  */\n", name);
  printf ("static const char *const %s_strings_empty[1] = { \"\" };\n", name);
  printf ("const char *const *%s_strings = %s_strings_empty;\n", name, name);
  printf ("int %s_strings_len = 0;\n", name);
}

/* Called via traverse_enum_types.  Emit an enum definition for
   enum_type *SLOT.  */

static int
print_enum_type (void **slot, void *info ATTRIBUTE_UNUSED)
{
  struct enum_type *def;
  struct enum_value *value;

  def = (struct enum_type *) *slot;
  for (unsigned i = 0; i < ARRAY_SIZE (mt_required_enums); i++)
    if (strcmp (def->name, mt_required_enums[i]) == 0)
      mt_required_seen[i] = true;
  /* Array plus pointer on a multi-target build, matching the declaration
     genconstants writes into insn-constants-<base>.h.  */
  printf ("\nconst char *const %s_strings%s[] = {", def->name,
	  gen_target_ns () ? "_tab" : "");
  for (value = def->values; value; value = value->next)
    {
      printf ("\n  \"%s\"", value->def->name);
      if (value->next)
	putc (',', stdout);
    }
  printf ("\n};\n");
  if (gen_target_ns ())
    printf ("const char *const *%s_strings = %s_strings_tab;\n",
	    def->name, def->name);

  /* The table's own length, next to the table.  ARRAY_SIZE of the array just
     emitted rather than def->num_values: the middle end indexes the ARRAY,
     so the bound has to be the array's, and writing it any other way is the
     shared-numbering defect this file exists to avoid -- NUM_<enum>_VALUES
     was exactly that, one name computed from the primary's md and used as a
     bound on somebody else's table.  */
  const char *tab = gen_target_ns () ? "_tab" : "";
  printf ("int %s_strings_len = (int) ARRAY_SIZE (%s_strings%s);\n",
	  def->name, def->name, tab);

  /* And the cross-check against the header, which is written by a DIFFERENT
     generator run (genconstants) over the same md.  It catches a stale
     insn-constants-<base>.h against a fresh table, and it would catch an md
     whose enum values are not dense -- in which case num_values exceeds the
     table length and upstream's `< NUM_<enum>_VALUES' was already reading
     off the end in a single-target build too.  */
  char *value_name = ACONCAT (("num_", def->name, "_values", NULL));
  upcase_string (value_name);
  printf ("static_assert (ARRAY_SIZE (%s_strings%s) == %s,\n"
	  "\t       \"%s_strings does not have %s entries\");\n",
	  def->name, tab, value_name, def->name, value_name);
  return 1;
}

int
main (int argc, const char **argv)
{
  progname = "genenums";

  noop_reader reader;
  if (!reader.read_md_files (argc, argv, NULL))
    return (FATAL_EXIT_CODE);

  puts ("/* Generated automatically by the program `genenums'");
  puts ("   from the machine description file.  */\n");
  puts ("#include \"config.h\"\n");
  puts ("#include \"system.h\"\n");
  /* Suffixed with GEN_HDR_SUFFIX: genenums is now built once per back end
     (it is in the parts list in gen-multi-target-md.awk), so this must name
     THIS back end's insn-constants-<base>.h.  Its two exported tables,
     unspec_strings and unspecv_strings, are read by the middle end, so a
     stale insn-constants.h here mis-numbers them silently -- the reason the
     note this replaces asked for print_gen_include rather than a literal.  */
  print_gen_include (stdout, "insn-constants");
  putc ('\n', stdout);

  /* unspec_strings / unspecv_strings are named bare by the middle end
     (rtl.h, print-rtl.cc), so two back ends defining them bare collide
     silently.  Namespaced; multi-target-select.cc supplies the bare names.  */
  print_ns_open (stdout);
  reader.traverse_enum_types (print_enum_type, 0);
  /* AFTER the traversal, so mt_required_seen is complete.  Supplying the
     missing ones here rather than making the installer conditional keeps ONE
     authority for "which tables exist": the installer's list.  */
  if (gen_target_ns ())
    for (unsigned i = 0; i < ARRAY_SIZE (mt_required_enums); i++)
      if (!mt_required_seen[i])
	print_empty_enum_type (mt_required_enums[i]);
  print_ns_close (stdout);

  if (ferror (stdout) || fflush (stdout) || fclose (stdout))
    return FATAL_EXIT_CODE;

  return SUCCESS_EXIT_CODE;
}
