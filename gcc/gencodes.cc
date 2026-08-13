/* Generate from machine description:
   - some macros CODE_FOR_... giving the insn_code_number value
   for each of the defined standard insn names.
   Copyright (C) 1987-2026 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

GCC is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with GCC; see the file COPYING3.  If not see
<http://www.gnu.org/licenses/>.  */


#include "bconfig.h"
#include "system.h"
#include "coretypes.h"
/* Which back end this generator is built for.  Same knob as genpreds.cc.  */
#ifndef TM_H_FILE
#define TM_H_FILE "tm.h"
#endif
#include TM_H_FILE
#include "rtl.h"
#include "errors.h"
#include "gensupport.h"

/* WHY NUM_INSN_CODES IS UNIONED, AND WHY ONLY IT.
   ===============================================

   `insn-codes.h' publishes two different kinds of thing, and exactly one of
   them is shared.

     * The `CODE_FOR_<pattern>' enumerators are this back end's own insn
       numbering.  Nothing outside config/ names one -- measured over all of
       gcc/ excluding config/, testsuite/ and the gen* programs, the only
       enumerator shared code spells is `CODE_FOR_nothing', which is 0 for
       every back end.  So they can stay per back end and no union is
       possible for them anyway: two back ends spell the same name for two
       different patterns.

     * `NUM_INSN_CODES' is an ARRAY BOUND IN A STRUCT THE WHOLE COMPILER
       SHARES.  recog.h:578 sizes

	   alternative_mask x_bool_attr_masks[NUM_INSN_CODES][BA_LAST + 1];
	   operand_alternative *x_op_alt[NUM_INSN_CODES];

       inside `struct target_recog', and lra.cc:631 sizes
       `insn_code_data[NUM_INSN_CODES]'.  Both are indexed by
       `INSN_CODE (insn)' in SHARED code -- recog.cc:2707 and lra.cc:714 --
       so the bound is written by one back end and the index supplied by
       whichever back end is selected.

   Measured in a two-target (i386 + aarch64) build dir, which is what made
   this worth fixing rather than worth documenting:

       insn-codes.h          NUM_INSN_CODES = 15429   <- the PRIMARY's
       insn-codes-i386.h     NUM_INSN_CODES = 15429
       insn-codes-aarch64.h  NUM_INSN_CODES = 20512

   `default_target_recog' is 0x788a8 bytes of .bss sized from 15429, and
   recog.cc indexes it with aarch64 insn codes that run to 20511.  That is a
   163KB overrun of a shared object, with no link error and no diagnostic --
   the `bound by one, indexed by another' entry in this branch's bug table,
   the same shape as NUM_UNSPECV_VALUES 114 against a 40-entry table.

   So the bound takes the union over every configured back end and the
   enumerators do not.  The mechanism is genconfig.cc's, deliberately: `-l'
   writes this back end's contribution, `-U' reads the concatenation and
   raises the bound, `-A' names the back end so that a union file which does
   not mention us is a fatal error rather than a silently undersized header.
   Absence is never an answer: a missing entry, a missing base line, or a
   union maximum BELOW what this back end needs (what a stale list looks
   like) all stop the build by name.

   THE ENUM'S RANGE IS A SEPARATE QUESTION AND IS NOT ANSWERED HERE.  With
   15428 as its largest enumerator the shared `enum insn_code' has a valid
   range of [0, 16383], so converting an aarch64 code of 20000 to it is
   out of range.  Pinning the range would mean emitting a terminal
   enumerator into every back end's header, which changes `-Wswitch'
   behaviour for every `switch' over `enum insn_code' in config/.  That is a
   design decision with a cost, not a bound fix, and it is written up rather
   than guessed at.  */

/* The one unioned value.  Named in a list of one so that adding a second
   later is an edit to this table rather than a new mechanism.  */
enum codes_max {
  KM_NUM_INSN_CODES,
  KM_LAST
};

static const char *const codes_max_name[KM_LAST] = {
  "NUM_INSN_CODES"
};

/* Set by -l, -U and -A respectively.  */
static bool list_mode;
static const char *union_file;
static const char *this_base;

static bool
parse_codes_opt (const char *arg)
{
  if (arg[1] == 'l' && arg[2] == '\0')
    {
      list_mode = true;
      return true;
    }
  if (arg[1] == 'U' && arg[2] != '\0')
    {
      union_file = arg + 2;
      return true;
    }
  if (arg[1] == 'A' && arg[2] != '\0')
    {
      this_base = arg + 2;
      return true;
    }
  return false;
}

/* Write this back end's contribution to the union file.  */

static void
emit_union_list (const int *maxv)
{
  printf ("# gencodes -l: %s\n", this_base);
  printf ("base %s\n", this_base);
  for (int i = 0; i < KM_LAST; i++)
    printf ("%s %d\n", codes_max_name[i], maxv[i]);
}

/* Read UNION_FILE and raise MAXV to the maximum over every back end listed
   there.  Deliberately a near-copy of genconfig.cc's apply_union_list; see
   the note there.  The two are kept separate because the failure they guard
   against is a SHARED helper drifting away from one of its callers, which is
   this branch's own bug.  */

static void
apply_union_list (int *maxv)
{
  FILE *f = fopen (union_file, "r");
  if (!f)
    fatal ("cannot open union file `%s': %s", union_file, xstrerror (errno));

  int seen_max[KM_LAST];
  int union_max[KM_LAST];
  for (int i = 0; i < KM_LAST; i++)
    seen_max[i] = 0, union_max[i] = 0;

  int nbases = 0;
  bool found_me = false;

  char line[512];
  while (fgets (line, sizeof (line), f))
    {
      char name[256];
      int value;

      if (line[0] == '#' || line[0] == '\n')
	continue;
      if (sscanf (line, "base %255s", name) == 1)
	{
	  nbases++;
	  if (!strcmp (name, this_base))
	    found_me = true;
	  continue;
	}
      if (sscanf (line, "%255s %d", name, &value) != 2)
	fatal ("%s: cannot parse line `%s'", union_file, line);

      for (int i = 0; i < KM_LAST; i++)
	if (!strcmp (name, codes_max_name[i]))
	  {
	    if (value > union_max[i] || !seen_max[i])
	      union_max[i] = value;
	    seen_max[i]++;
	  }
    }
  fclose (f);

  if (nbases == 0)
    fatal ("%s: no `base' line; the union run produced nothing", union_file);

  /* A union file that does not mention us is the stale-list failure mode.
     It is not detectable from the values alone -- our own maximum may
     happen to be below somebody else's -- so check the name.  */
  if (!found_me)
    fatal ("%s: lists %d back end(s), none of them `%s';\n"
	   "  this back end's insn-codes.h would be sized for other targets",
	   union_file, nbases, this_base);

  for (int i = 0; i < KM_LAST; i++)
    {
      if (seen_max[i] != nbases)
	fatal ("%s: %s given for %d of %d back ends;\n"
	       "  a missing entry must not be read as a zero",
	       union_file, codes_max_name[i], seen_max[i], nbases);
      if (union_max[i] < maxv[i])
	fatal ("%s: %s is %d there but this back end (`%s') needs %d;\n"
	       "  the union file is stale",
	       union_file, codes_max_name[i], union_max[i], this_base,
	       maxv[i]);
      maxv[i] = union_max[i];
    }
}

static void
gen_insn (md_rtx_info *info)
{
  const char *name = XSTR (info->def, 0);
  int truth = maybe_eval_c_test (XSTR (info->def, 2));

  /* Don't mention instructions whose names are the null string
     or begin with '*'.  They are in the machine description just
     to be recognized.  */
  /* In -l mode the only output is the union contribution; the enumerators
     would corrupt it.  Note the md file is still READ in full, because
     get_num_insn_codes () is what -l reports.  */
  if (list_mode)
    return;

  if (name[0] != 0 && name[0] != '*')
    {
      if (truth == 0)
	printf (",\n   CODE_FOR_%s = CODE_FOR_nothing", name);
      else
	printf (",\n  CODE_FOR_%s = %d", name, info->index);
    }
}

int
main (int argc, const char **argv)
{
  progname = "gencodes";

  /* We need to see all the possibilities.  Elided insns may have
     direct references to CODE_FOR_xxx in C code.  */
  insn_elision = 0;

  if (!init_rtx_reader_args_cb (argc, argv, parse_codes_opt))
    return (FATAL_EXIT_CODE);

  /* -A carries the back end's name and is what makes a stale union file a
     diagnosable error rather than a silently undersized header.  Reject the
     combinations that would read as "no union asked for": an empty -A is
     already rejected by parse_codes_opt, but -l or -U with no -A at all
     would leave this_base NULL and every check below vacuous.  */
  if ((list_mode || union_file) && !this_base)
    fatal ("gencodes: -l and -U require -A<base>;\n"
	   "  without it there is nothing to check the union file against");
  if (list_mode && union_file)
    fatal ("gencodes: -l writes the union file and -U reads it;\n"
	   "  asking for both in one run is a rule that feeds itself");

  if (!list_mode)
    printf ("\
/* Generated automatically by the program `gencodes'\n\
   from the machine description file `md'.  */\n\
\n\
#ifndef GCC_INSN_CODES_H\n\
#define GCC_INSN_CODES_H\n\
\n\
enum insn_code {\n\
  CODE_FOR_nothing = 0");

  /* Read the machine description.  */

  md_rtx_info info;
  while (read_md_rtx (&info))
    switch (GET_CODE (info.def))
      {
      case DEFINE_INSN:
      case DEFINE_EXPAND:
	gen_insn (&info);
	break;

      default:
	break;
    }

  int maxv[KM_LAST];
  maxv[KM_NUM_INSN_CODES] = get_num_insn_codes ();

  if (list_mode)
    {
      emit_union_list (maxv);
      if (ferror (stdout) || fflush (stdout) || fclose (stdout))
	return FATAL_EXIT_CODE;
      return SUCCESS_EXIT_CODE;
    }

  if (union_file)
    apply_union_list (maxv);

  printf ("\n};\n\
\n\
/* THE UNION BOUND, not this back end's own count.  See the note at the top\n\
   of gencodes.cc: this sizes arrays in `struct target_recog' and in lra.cc\n\
   that SHARED code indexes with whichever back end's insn code is in\n\
   force.  */\n\
const unsigned int NUM_INSN_CODES = %d;\n\
#endif /* GCC_INSN_CODES_H */\n", maxv[KM_NUM_INSN_CODES]);

  if (ferror (stdout) || fflush (stdout) || fclose (stdout))
    return FATAL_EXIT_CODE;

  return SUCCESS_EXIT_CODE;
}
