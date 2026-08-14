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

/* THE ENUM TABLES multi-target-select.cc REQUIRES OF *EVERY* BACK END.
   MT_OTHER_TABLES and MT_SCALAR_TABLES in that file name `unspec_strings',
   `unspecv_strings' and their two lengths for all N bases unconditionally,
   because the middle end reads them through one bare name whichever back end
   is in force.  This generator, though, emits a table only for an enum the
   back end's md actually declares -- and 26 of the 48 declare neither
   `unspec' nor `unspecv', or only one of the two, because they spell their
   UNSPEC_* constants with the older `define_constants' rather than
   `define_c_enum'.  Measured at the cc1 link of a 48-base build: that single
   asymmetry is the sole blocker for 22 back ends and one of two blockers for
   four more.

   The two lists are one fact with two authorities, which is this branch's own
   root bug, so say where the other one is rather than leaving a reader to
   find it: gcc/multi-target-select.cc, MT_OTHER_TABLES / MT_SCALAR_TABLES.

   Named instances, because "26 of 48" is a count and a count is not a
   population: mips, arc, bpf, epiphany, ft32, microblaze, msp430, rx and v850
   define `unspec' and no `unspecv'; m68k and m32r define neither.  Measured
   directly before the fix: adding mips to a base set gives `undefined
   reference to insn_mips::unspecv_strings' and `...::unspecv_strings_len'.

   Two agents reached this fix independently from opposite ends -- one from a
   single mips link failure, one from a 48-base census -- and wrote the same
   generator change.  That agreement is the reason it is trusted here.  */
static const char *const mt_required_enums[] = { "unspec", "unspecv" };

/* Which of the above this md run has already emitted.  */
static bool mt_emitted[ARRAY_SIZE (mt_required_enums)];

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
      mt_emitted[i] = true;
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

  /* THE BACK END'S OWN ANSWER FOR AN ENUM IT DOES NOT HAVE, WHICH IS NOT THE
     SAME THING AS A FLOOR.  Read PRINCIPLES section 2a before changing this.

     What is banned there is a fallback that hands one back end ANOTHER back
     end's value -- in practice the primary's.  Nothing of the kind happens
     here: a back end whose md declares no `unspecv' has no unspecv names, so
     its table is empty and its length is 0, and that is exactly what upstream
     produces for that back end standing alone.  Upstream expresses it by not
     compiling the reader at all (`#if defined (NUM_UNSPECV_VALUES)' in
     print-rtl.cc); a multi-target build cannot, because that macro comes from
     the singular genconstants run and is therefore the PRIMARY's answer for
     everybody.  So the same behaviour has to be expressed in data instead:
     len 0 makes every `XINT (x, 1) < unspecv_strings_len' false, which is
     precisely what upstream's #if achieves.  No base ever reads another's
     table -- indeed this is what STOPS one doing so, since the alternative on
     the table is the link failing and someone reaching for the primary's.

     A one-element array rather than `[] = {}': a zero-length array is not
     valid C++, and the length that matters is the separate _len, which is 0.
     The element is null so that any indexing bug faults immediately rather
     than reading a plausible neighbouring string -- the failure mode
     MT_SCALAR_TABLES' own comment records for NUM_UNSPECV_VALUES.  */
  if (gen_target_ns ())
    for (unsigned i = 0; i < ARRAY_SIZE (mt_required_enums); i++)
      if (!mt_emitted[i])
	{
	  const char *n = mt_required_enums[i];
	  printf ("\n/* This back end's md declares no `%s' enum, so it has "
		  "no %s\n   names.  Empty table, length 0 -- see genenums.cc.  */\n",
		  n, n);
	  printf ("const char *const %s_strings_tab[1] = { nullptr };\n", n);
	  printf ("const char *const *%s_strings = %s_strings_tab;\n", n, n);
	  printf ("int %s_strings_len = 0;\n", n);
	}

  print_ns_close (stdout);

  if (ferror (stdout) || fflush (stdout) || fclose (stdout))
    return FATAL_EXIT_CODE;

  return SUCCESS_EXIT_CODE;
}
