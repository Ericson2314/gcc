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

/* THE TWO TABLES THE MIDDLE END NAMES BARE, and which therefore have to exist
   for EVERY configured back end whether its md defines the enum or not.

   print-rtl.cc, read-rtl-function.cc and multi-target-select.cc's
   MT_OTHER_TABLES / MT_SCALAR_TABLES all spell these two names; this array is
   not a new authority, it is the same list written where the definitions are
   made.  Every other enum in an md is the back end's own business and is
   emitted only when it exists.  */
static const char *const mt_required_enums[] = { "unspec", "unspecv" };

/* Which of the above this md actually defined.  */
static bool mt_required_seen[ARRAY_SIZE (mt_required_enums)];

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

  /* THE BACK ENDS WHOSE MACHINE HAS NO UNSPECS, AND WHY AN EMPTY TABLE IS
     THEIR OWN ANSWER RATHER THAN A FLOOR.

     mips defines `unspec' and no `unspecv'; arc, bpf, epiphany, ft32,
     microblaze, msp430, rx and v850 are in the same position, and m68k, m32r
     and others define neither.  multi-target-select.cc names
     insn_<base>::unspecv_strings and insn_<base>::unspecv_strings_len for
     EVERY configured back end -- it has to, because print-rtl.cc and
     read-rtl-function.cc name the bare `unspecv_strings' and something must
     be in force whichever back end is selected -- so a base that emitted
     neither is an undefined reference at the link of cc1.  Measured: adding
     mips to a base set gives `undefined reference to
     insn_mips::unspecv_strings' and `...::unspecv_strings_len'.

     PRINCIPLES 2a bans a floor that hands a base THE PRIMARY'S answer.  This
     is the other kind, the one that rule explicitly permits: length ZERO is
     what "this machine has no unspec_volatile constants" means, it is what
     upstream's single-target build behaves as (the `#if defined
     (NUM_UNSPECV_VALUES)' arms simply are not compiled), and no other back
     end's value can reach mips through it.  Every consumer is already written
     as `unspec < unspecv_strings_len', so a zero length is read as "never
     name one", which is exactly right.  The value is not invented: it is
     counted from this md, and it is 0 because this md has none.

     Emitted only in the namespaced run.  The un-namespaced one is upstream's
     shape, where an absent enum means absent code and there is nothing to
     select between.  */
  if (gen_target_ns ())
    for (unsigned i = 0; i < ARRAY_SIZE (mt_required_enums); i++)
      if (!mt_required_seen[i])
	{
	  const char *n = mt_required_enums[i];
	  printf ("\n/* This machine description defines no `%s' enum.  */\n",
		  n);
	  printf ("const char *const %s_strings_tab[] = { NULL };\n", n);
	  printf ("const char *const *%s_strings = %s_strings_tab;\n", n, n);
	  /* NOT ARRAY_SIZE of the array above: a zero-length array is not
	     valid, so the placeholder holds one NULL element, and the length
	     the middle end must see is the number of NAMED VALUES, which is
	     zero.  Writing ARRAY_SIZE here would publish a bound of 1 over a
	     table whose only entry is NULL -- print-rtl.cc would then pass
	     that NULL to %s for unspec 0.  */
	  printf ("int %s_strings_len = 0;\n", n);
	}

  print_ns_close (stdout);

  if (ferror (stdout) || fflush (stdout) || fclose (stdout))
    return FATAL_EXIT_CODE;

  return SUCCESS_EXIT_CODE;
}
