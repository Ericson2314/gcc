/* Generate from machine description:
   - some #define configuration flags.
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


/* flags to determine output of machine description dependent #define's.  */
static int max_recog_operands;  /* Largest operand number seen.  */
static int max_dup_operands;    /* Largest number of match_dup in any insn.  */
static int max_clobbers_per_insn;
static int have_cmove_flag;
static int have_cond_exec_flag;
static int have_lo_sum_flag;
static int have_rotate_flag;
static int have_rotatert_flag;
static int have_peephole_flag;
static int have_peephole2_flag;

/* Maximum number of insns seen in a split.  */
static int max_insns_per_split = 1;

/* Maximum number of input insns for peephole2.  */
static int max_insns_per_peep2;

static int clobbers_seen_this_insn;
static int dup_operands_seen_this_insn;

static void walk_insn_part (rtx, int, int);

/* ---------------------------------------------------------------------
   THE SHARED insn-config ANSWER.

   Every macro genconfig writes is used from a #if line, or as an array
   bound, or as a bitfield width -- never as a value a target hook could
   answer at run time.  `NUM_REGISTER_FILTERS' is all three at once:
   ira-int.h:356 tests it with #ifndef/#elif, sizes a bitfield with it, and
   recog.h:69 sizes another.  A macro used that way CANNOT become a
   `targ_caps'-style field, because a runtime field cannot appear on a
   preprocessor line.  So the only way two back ends can coexist in one
   compiler is for these macros to hold ONE value that is correct for all of
   them, computed over every configured back end -- exactly the shape the
   shared mode numbering already has (`modes-union.list', genmodes.cc -l/-U/-A).

   Measured in a two-target (i386 primary + aarch64) build dir, before this:

     NUM_REGISTER_FILTERS   0 for i386, 4 for aarch64
     MAX_DUP_OPERANDS      14 for i386, 6 for aarch64
     MAX_INSNS_PER_SPLIT    5 for i386, 4 for aarch64
     MAX_INSNS_PER_PEEP2    6 for i386, 4 for aarch64
     HAVE_lo_sum            0 for i386, 1 for aarch64

   and `insn-config.h', which 90 non-config/ files include, was byte-identical
   to the primary's.  So the whole middle end was compiled believing register
   filters do not exist while insn-recog-aarch64-*.o was compiled using them,
   and insn-extract-aarch64.o writes up to 14 dup operands into a recog_data
   whose dup_loc[] the middle end sized at 6.  Neither is a link error.

   The six MAX_/NUM_ macros are maxima, and a maximum is safe to raise: they
   size arrays and bitfields, the values stored in them are per-back-end
   indices that only that back end's own code interprets, and a wider field
   holds a narrower index unchanged.  They are unioned here.

   The HAVE_ booleans are NOT unioned -- see the note by emit_union_list --
   and this is deliberate: a max over booleans is an OR, and telling the
   middle end that a pattern exists when the selected back end has no such
   pattern is a silent wrong answer, not a conservative one.  They stay per
   back end in each insn-config-<base>.h, and the two that reach a #if line
   in a shared file are checked for unanimity instead of being averaged.

   -l  <emit the list>   write this back end's values, for the union file.
   -U <file>             read the union file; raise the maxima to it.
   -A <name>             announce/require this back end's name in the file.

   Absence is never an answer here.  With -U, a union file that does not
   mention this back end, or that omits a macro, or that reports a maximum
   BELOW what this back end needs (which is what a stale list looks like) is
   a fatal error.  An #ifndef-style floor would turn each of those into a
   silently wrong header, and on this branch that has happened before.  */

/* The macros that are unioned, in the order emitted.  Keep in sync with
   the printf block in main.  */
enum config_max {
  CM_MAX_RECOG_OPERANDS,
  CM_MAX_DUP_OPERANDS,
  CM_MAX_INSNS_PER_SPLIT,
  CM_MAX_INSNS_PER_PEEP2,
  CM_NUM_REGISTER_FILTERS,
  CM_NUM_DEPENDENT_FILTERS,
  CM_LAST
};

static const char *const config_max_name[CM_LAST] = {
  "MAX_RECOG_OPERANDS",
  "MAX_DUP_OPERANDS",
  "MAX_INSNS_PER_SPLIT",
  "MAX_INSNS_PER_PEEP2",
  "NUM_REGISTER_FILTERS",
  "NUM_DEPENDENT_FILTERS"
};

/* The booleans that reach a #if/#if defined line in a file the whole
   compiler shares, so that no per-back-end answer can exist.  simplify-rtx.cc
   :4773 is `#if defined(HAVE_rotate) && defined(HAVE_rotatert)', and genconfig
   only ever DEFINES these when the pattern is present, so "which back end"
   cannot be asked at that point.  If the configured back ends disagree about
   one of them we say so and stop, rather than picking a side.  */
enum config_bool {
  CB_HAVE_rotate,
  CB_HAVE_rotatert,
  CB_LAST
};

static const char *const config_bool_name[CB_LAST] = {
  "HAVE_rotate",
  "HAVE_rotatert"
};

/* Set by -l, -U and -A respectively.  */
static bool list_mode;
static const char *union_file;
static const char *this_base;

static bool
parse_config_opt (const char *arg)
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
emit_union_list (const int *maxv, const int *boolv)
{
  printf ("# genconfig -l: %s\n", this_base);
  printf ("base %s\n", this_base);
  for (int i = 0; i < CM_LAST; i++)
    printf ("%s %d\n", config_max_name[i], maxv[i]);
  for (int i = 0; i < CB_LAST; i++)
    printf ("%s %d\n", config_bool_name[i], boolv[i]);
}

/* Read UNION_FILE, raise MAXV to the maximum over every back end listed
   there, and check the shared booleans against BOOLV.  */

static void
apply_union_list (int *maxv, const int *boolv)
{
  FILE *f = fopen (union_file, "r");
  if (!f)
    fatal ("cannot open union file `%s': %s", union_file, xstrerror (errno));

  int seen_max[CM_LAST];
  int union_max[CM_LAST];
  for (int i = 0; i < CM_LAST; i++)
    seen_max[i] = 0, union_max[i] = 0;

  /* For each shared boolean: how many back ends define it, and how many
     back ends there are.  */
  int bool_yes[CB_LAST];
  for (int i = 0; i < CB_LAST; i++)
    bool_yes[i] = 0;
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

      for (int i = 0; i < CM_LAST; i++)
	if (!strcmp (name, config_max_name[i]))
	  {
	    if (value > union_max[i] || !seen_max[i])
	      union_max[i] = value;
	    seen_max[i]++;
	  }
      for (int i = 0; i < CB_LAST; i++)
	if (!strcmp (name, config_bool_name[i]) && value)
	  bool_yes[i]++;
    }
  fclose (f);

  if (nbases == 0)
    fatal ("%s: no `base' line; the union run produced nothing", union_file);

  /* A union file that does not mention us is the stale-list failure mode.
     It is not detectable from the values alone -- our own maxima may all
     happen to be below somebody else's -- so check the name.  */
  if (!found_me)
    fatal ("%s: lists %d back end(s), none of them `%s';\n"
	   "  this back end's insn-config.h would be sized for other targets",
	   union_file, nbases, this_base);

  for (int i = 0; i < CM_LAST; i++)
    {
      if (seen_max[i] != nbases)
	fatal ("%s: %s given for %d of %d back ends;\n"
	       "  a missing entry must not be read as a zero",
	       union_file, config_max_name[i], seen_max[i], nbases);
      if (union_max[i] < maxv[i])
	fatal ("%s: %s is %d there but this back end (`%s') needs %d;\n"
	       "  the union file is stale",
	       union_file, config_max_name[i], union_max[i], this_base,
	       maxv[i]);
      maxv[i] = union_max[i];
    }

  for (int i = 0; i < CB_LAST; i++)
    if (bool_yes[i] != 0 && bool_yes[i] != nbases)
      fatal ("%s: %d of %d back ends define %s.\n"
	     "  It is used from a #if line in a file the whole compiler\n"
	     "  shares (simplify-rtx.cc), so there is no per-back-end answer\n"
	     "  and no safe default: defining it enables a canonicalisation\n"
	     "  the back ends without the pattern cannot express, and not\n"
	     "  defining it silently disables it for the ones that can.\n"
	     "  This combination of targets needs that use site made runtime\n"
	     "  before it can be built.",
	     union_file, bool_yes[i], nbases, config_bool_name[i]);

  /* Unused today; kept so the signature says what is checked.  */
  (void) boolv;
}

/* RECOG_P will be nonzero if this pattern was seen in a context where it will
   be used to recognize, rather than just generate an insn.

   NON_PC_SET_SRC will be nonzero if this pattern was seen in a SET_SRC
   of a SET whose destination is not (pc).  */

static void
walk_insn_part (rtx part, int recog_p, int non_pc_set_src)
{
  int i, j;
  RTX_CODE code;
  const char *format_ptr;

  if (part == 0)
    return;

  code = GET_CODE (part);
  switch (code)
    {
    case CLOBBER:
      clobbers_seen_this_insn++;
      break;

    case MATCH_OPERAND:
      if (XINT (part, 0) > max_recog_operands)
	max_recog_operands = XINT (part, 0);
      return;

    case MATCH_OP_DUP:
    case MATCH_PAR_DUP:
      ++dup_operands_seen_this_insn;
      /* FALLTHRU */
    case MATCH_SCRATCH:
    case MATCH_PARALLEL:
    case MATCH_OPERATOR:
      if (XINT (part, 0) > max_recog_operands)
	max_recog_operands = XINT (part, 0);
      /* Now scan the rtl's in the vector inside the MATCH_OPERATOR or
	 MATCH_PARALLEL.  */
      break;

    case LABEL_REF:
      if (GET_CODE (XEXP (part, 0)) == MATCH_OPERAND
	  || GET_CODE (XEXP (part, 0)) == MATCH_DUP)
	break;
      return;

    case MATCH_DUP:
      ++dup_operands_seen_this_insn;
      if (XINT (part, 0) > max_recog_operands)
	max_recog_operands = XINT (part, 0);
      return;

    case LO_SUM:
      if (recog_p)
	have_lo_sum_flag = 1;
      return;

    case ROTATE:
      if (recog_p)
	have_rotate_flag = 1;
      return;

    case ROTATERT:
      if (recog_p)
	have_rotatert_flag = 1;
      return;

    case SET:
      walk_insn_part (SET_DEST (part), 0, recog_p);
      walk_insn_part (SET_SRC (part), recog_p,
		      GET_CODE (SET_DEST (part)) != PC);
      return;

    case IF_THEN_ELSE:
      /* Only consider this machine as having a conditional move if the
	 two arms of the IF_THEN_ELSE are both MATCH_OPERAND.  Otherwise,
	 we have some specific IF_THEN_ELSE construct (like the doz
	 instruction on the RS/6000) that can't be used in the general
	 context we want it for.  */

      if (recog_p && non_pc_set_src
	  && GET_CODE (XEXP (part, 1)) == MATCH_OPERAND
	  && GET_CODE (XEXP (part, 2)) == MATCH_OPERAND)
	have_cmove_flag = 1;
      break;

    case COND_EXEC:
      if (recog_p)
	have_cond_exec_flag = 1;
      break;

    case REG: case CONST_INT: case SYMBOL_REF:
    case PC:
      return;

    default:
      break;
    }

  format_ptr = GET_RTX_FORMAT (GET_CODE (part));

  for (i = 0; i < GET_RTX_LENGTH (GET_CODE (part)); i++)
    switch (*format_ptr++)
      {
      case 'e':
      case 'u':
	walk_insn_part (XEXP (part, i), recog_p, non_pc_set_src);
	break;
      case 'E':
	if (XVEC (part, i) != NULL)
	  for (j = 0; j < XVECLEN (part, i); j++)
	    walk_insn_part (XVECEXP (part, i, j), recog_p, non_pc_set_src);
	break;
      }
}

static void
gen_insn (md_rtx_info *info)
{
  int i;

  /* Walk the insn pattern to gather the #define's status.  */
  rtx insn = info->def;
  clobbers_seen_this_insn = 0;
  dup_operands_seen_this_insn = 0;
  if (XVEC (insn, 1) != 0)
    for (i = 0; i < XVECLEN (insn, 1); i++)
      walk_insn_part (XVECEXP (insn, 1, i), 1, 0);

  if (clobbers_seen_this_insn > max_clobbers_per_insn)
    max_clobbers_per_insn = clobbers_seen_this_insn;
  if (dup_operands_seen_this_insn > max_dup_operands)
    max_dup_operands = dup_operands_seen_this_insn;
}

/* Similar but scan a define_expand.  */

static void
gen_expand (md_rtx_info *info)
{
  int i;

  /* Walk the insn pattern to gather the #define's status.  */

  /* Note that we don't bother recording the number of MATCH_DUPs
     that occur in a gen_expand, because only reload cares about that.  */
  rtx insn = info->def;
  if (XVEC (insn, 1) != 0)
    for (i = 0; i < XVECLEN (insn, 1); i++)
      {
	/* Compute the maximum SETs and CLOBBERS
	   in any one of the sub-insns;
	   don't sum across all of them.  */
	clobbers_seen_this_insn = 0;

	walk_insn_part (XVECEXP (insn, 1, i), 0, 0);

	if (clobbers_seen_this_insn > max_clobbers_per_insn)
	  max_clobbers_per_insn = clobbers_seen_this_insn;
      }
}

/* Similar but scan a define_split.  */

static void
gen_split (md_rtx_info *info)
{
  int i;

  /* Look through the patterns that are matched
     to compute the maximum operand number.  */
  rtx split = info->def;
  for (i = 0; i < XVECLEN (split, 0); i++)
    walk_insn_part (XVECEXP (split, 0, i), 1, 0);
  /* Look at the number of insns this insn could split into.  */
  if (XVECLEN (split, 2) > max_insns_per_split)
    max_insns_per_split = XVECLEN (split, 2);
}

static void
gen_peephole (md_rtx_info *info)
{
  int i;

  /* Look through the patterns that are matched
     to compute the maximum operand number.  */
  rtx peep = info->def;
  for (i = 0; i < XVECLEN (peep, 0); i++)
    walk_insn_part (XVECEXP (peep, 0, i), 1, 0);
}

static void
gen_peephole2 (md_rtx_info *info)
{
  int i, n;

  /* Look through the patterns that are matched
     to compute the maximum operand number.  */
  rtx peep = info->def;
  for (i = XVECLEN (peep, 0) - 1; i >= 0; --i)
    walk_insn_part (XVECEXP (peep, 0, i), 1, 0);

  /* Look at the number of insns this insn can be matched from.  */
  for (i = XVECLEN (peep, 0) - 1, n = 0; i >= 0; --i)
    if (GET_CODE (XVECEXP (peep, 0, i)) != MATCH_DUP
	&& GET_CODE (XVECEXP (peep, 0, i)) != MATCH_SCRATCH)
      n++;
  if (n > max_insns_per_peep2)
    max_insns_per_peep2 = n;
}

int
main (int argc, const char **argv)
{
  progname = "genconfig";

  if (!init_rtx_reader_args_cb (argc, argv, parse_config_opt))
    return (FATAL_EXIT_CODE);

  if ((list_mode || union_file) && !this_base)
    fatal ("-l and -U require -A<base>");
  if (list_mode && union_file)
    fatal ("-l and -U are mutually exclusive");

  /* Allow at least 30 operands for the sake of asm constructs.
     This magic number is also used in genpreds to determine
     validity of a referenced operand when parsing dynamic register
     filters.  */
  /* ??? We *really* ought to reorganize things such that there
     is no fixed upper bound.  */
  max_recog_operands = 29;  /* We will add 1 later.  */
  max_dup_operands = 1;

  /* Read the machine description.  */

  md_rtx_info info;
  while (read_md_rtx (&info))
    switch (GET_CODE (info.def))
      {
      case DEFINE_INSN:
	gen_insn (&info);
	break;

      case DEFINE_EXPAND:
	gen_expand (&info);
	break;

      case DEFINE_SPLIT:
	gen_split (&info);
	break;

      case DEFINE_PEEPHOLE2:
	have_peephole2_flag = 1;
	gen_peephole2 (&info);
	break;

      case DEFINE_PEEPHOLE:
	have_peephole_flag = 1;
	gen_peephole (&info);
	break;

      default:
	break;
      }

  /* Collect the six maxima in one place so that -l, -U and the header all
     print the same numbers.  */
  int maxv[CM_LAST];
  maxv[CM_MAX_RECOG_OPERANDS] = max_recog_operands + 1;
  maxv[CM_MAX_DUP_OPERANDS] = max_dup_operands;
  maxv[CM_MAX_INSNS_PER_SPLIT] = max_insns_per_split;
  maxv[CM_MAX_INSNS_PER_PEEP2] = have_peephole2_flag ? max_insns_per_peep2 : 0;
  maxv[CM_NUM_REGISTER_FILTERS] = register_filters.length ();
  maxv[CM_NUM_DEPENDENT_FILTERS] = num_dependent_filters;

  int boolv[CB_LAST];
  boolv[CB_HAVE_rotate] = have_rotate_flag ? 1 : 0;
  boolv[CB_HAVE_rotatert] = have_rotatert_flag ? 1 : 0;

  if (list_mode)
    {
      emit_union_list (maxv, boolv);
      if (ferror (stdout) || fflush (stdout) || fclose (stdout))
	return FATAL_EXIT_CODE;
      return SUCCESS_EXIT_CODE;
    }

  if (union_file)
    apply_union_list (maxv, boolv);

  puts ("/* Generated automatically by the program `genconfig'");
  puts ("   from the machine description file `md'.  */\n");
  puts ("#ifndef GCC_INSN_CONFIG_H");
  puts ("#define GCC_INSN_CONFIG_H\n");

  printf ("#define MAX_RECOG_OPERANDS %d\n", maxv[CM_MAX_RECOG_OPERANDS]);
  printf ("#define MAX_DUP_OPERANDS %d\n", maxv[CM_MAX_DUP_OPERANDS]);

  /* This is conditionally defined, in case the user writes code which emits
     more splits than we can readily see (and knows s/he does it).  */
  printf ("#ifndef MAX_INSNS_PER_SPLIT\n");
  printf ("#define MAX_INSNS_PER_SPLIT %d\n", maxv[CM_MAX_INSNS_PER_SPLIT]);
  printf ("#endif\n");

  if (have_cmove_flag)
    printf ("#define HAVE_conditional_move 1\n");
  else
    printf ("#define HAVE_conditional_move 0\n");

  if (have_cond_exec_flag)
    printf ("#define HAVE_conditional_execution 1\n");
  else
    printf ("#define HAVE_conditional_execution 0\n");

  if (have_lo_sum_flag)
    printf ("#define HAVE_lo_sum 1\n");
  else
    printf ("#define HAVE_lo_sum 0\n");

  if (have_rotate_flag)
    printf ("#define HAVE_rotate 1\n");

  if (have_rotatert_flag)
    printf ("#define HAVE_rotatert 1\n");

  if (have_peephole_flag)
    printf ("#define HAVE_peephole 1\n");
  else
    printf ("#define HAVE_peephole 0\n");

  /* HAVE_peephole2 stays per back end -- it is only ever read as a value
     (recog.cc:4480) -- but MAX_INSNS_PER_PEEP2 sizes recog.cc's
     peep2_insn_data[], which is one array shared by every back end, so it
     takes the union even where this back end has no peephole2 at all.  */
  if (have_peephole2_flag)
    printf ("#define HAVE_peephole2 1\n");
  else
    printf ("#define HAVE_peephole2 0\n");
  printf ("#define MAX_INSNS_PER_PEEP2 %d\n", maxv[CM_MAX_INSNS_PER_PEEP2]);

  printf ("#define NUM_REGISTER_FILTERS %d\n", maxv[CM_NUM_REGISTER_FILTERS]);
  printf ("#define NUM_DEPENDENT_FILTERS %d\n", maxv[CM_NUM_DEPENDENT_FILTERS]);

  puts ("\n#endif /* GCC_INSN_CONFIG_H */");

  if (ferror (stdout) || fflush (stdout) || fclose (stdout))
    return FATAL_EXIT_CODE;

  return SUCCESS_EXIT_CODE;
}
