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
/* genenums reads no target macro -- it includes tm.h only because rtl.h,
   which gensupport.h needs, wants FIRST_PSEUDO_REGISTER.  That reaches a
   structure size, not this program's output, which depends on the md files
   alone.  gensupport.h is here for print_gen_include, so that the
   insn-constants.h named below carries GEN_HDR_SUFFIX.  */
#ifndef TM_H_FILE
#define TM_H_FILE "tm.h"
#endif
#include TM_H_FILE
#include "rtl.h"
#include "errors.h"
#include "statistics.h"
#include "vec.h"
#include "read-md.h"
#include "gensupport.h"

/* Called via traverse_enum_types.  Emit an enum definition for
   enum_type *SLOT.  */

static int
print_enum_type (void **slot, void *info ATTRIBUTE_UNUSED)
{
  struct enum_type *def;
  struct enum_value *value;

  def = (struct enum_type *) *slot;
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
  print_ns_close (stdout);

  if (ferror (stdout) || fflush (stdout) || fclose (stdout))
    return FATAL_EXIT_CODE;

  return SUCCESS_EXIT_CODE;
}
