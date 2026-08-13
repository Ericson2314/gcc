/* Generate code to initialize optabs from machine description.
   Copyright (C) 1993-2026 Free Software Foundation, Inc.

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


#define DEF_RTL_EXPR(V, N, X, C) #V,

static const char * const rtx_upname[] = {
#include "rtl.def"
};

#undef DEF_RTL_EXPR

/* Vector in which to collect insns that match.  */
static vec<optab_pattern> patterns;

static void
gen_insn (md_rtx_info *info)
{
  optab_pattern p;
  if (find_optab (&p, XSTR (info->def, 0)))
    patterns.safe_push (p);
}

static int
pattern_cmp (const void *va, const void *vb)
{
  const optab_pattern *a = (const optab_pattern *)va;
  const optab_pattern *b = (const optab_pattern *)vb;
  return a->sort_num - b->sort_num;
}

static int
optab_kind_cmp (const void *va, const void *vb)
{
  const optab_def *a = (const optab_def *)va;
  const optab_def *b = (const optab_def *)vb;
  int diff = a->kind - b->kind;
  if (diff == 0)
    diff = a->op - b->op;
  return diff;
}

static int
optab_rcode_cmp (const void *va, const void *vb)
{
  const optab_def *a = (const optab_def *)va;
  const optab_def *b = (const optab_def *)vb;
  return a->rcode - b->rcode;
}

static const char *header_file_name = "init-opinit.h";
static const char *source_file_name = "init-opinit.c";

/* THE SHARED `NUM_OPTAB_PATTERNS' ANSWER.
   -----------------------------------------------------------------------
   `NUM_OPTAB_PATTERNS' is the length of `pat_enable[]' inside `struct
   target_optabs', and `struct target_optabs' is a SHARED type: it is defined
   in the `insn-opinit.h' that the whole middle end sees, `default_target_optabs'
   is a single object in `optabs-query.cc', and `this_target_optabs' points at
   one of those from everywhere.

   The number, however, is per back end -- it counts the optab patterns in
   THIS back end's machine description.  Measured in an x86_64 + aarch64
   build directory:

       insn-opinit-i386.h      NUM_OPTAB_PATTERNS  2975
       insn-opinit-aarch64.h   NUM_OPTAB_PATTERNS  3328
       insn-opinit.h (shared)  NUM_OPTAB_PATTERNS  2975   <- the primary's

   so `sizeof (struct target_optabs)' is 3465 bytes where the middle end
   allocates it and 3818 bytes where `insn_aarch64::init_all_optabs' fills it
   in.  That function writes `pat_enable[0 .. 3327]': 353 bools past the end of
   an object the linker sized for somebody else, over
   `supports_vec_gather_load' and `supports_vec_scatter_store' on the way out.
   Nothing links wrong and nothing is diagnosed.  It is PRINCIPLES 3's "sized
   by one, indexed by another", one struct at a time.

   Like the maxima in genconfig.cc this CANNOT become a runtime `targ_caps'
   field -- it is an array bound in a shared struct -- so it takes the union
   over every configured back end.  A maximum is safe to raise here for the
   same reason it is there: `pat_enable' is indexed by a pattern number that
   only the back end which generated it interprets, so a longer array holds a
   shorter back end's indices unchanged and the tail is never consulted.

   Absence is never an answer: with -U, a union file that does not name this
   back end, or that omits the macro, or that reports a value BELOW what this
   back end needs, is fatal.  An `#ifndef' floor would turn each of those into
   a silently undersized struct, which is the bug this is fixing.

   -l          write this back end's value, for the union file.
   -U <file>   read the union file; raise the value to it.
   -A <name>   announce/require this back end's name in the file.  */

/* The macros that are unioned, in the order emitted.  One today; kept as a
   table rather than a bare variable so that adding a second cannot forget one
   of the three places it has to appear.  */
enum opinit_max {
  OM_NUM_OPTAB_PATTERNS,
  OM_LAST
};

static const char *const opinit_max_name[OM_LAST] = {
  "NUM_OPTAB_PATTERNS"
};

/* Set by -l, -U and -A respectively.  */
static bool list_mode;
static const char *union_file;
static const char *this_base;

/* Write this back end's contribution to the union file.  */

static void
emit_union_list (const int *maxv)
{
  printf ("# genopinit -l: %s\n", this_base);
  printf ("base %s\n", this_base);
  for (int i = 0; i < OM_LAST; i++)
    printf ("%s %d\n", opinit_max_name[i], maxv[i]);
}

/* Read UNION_FILE and raise MAXV to the maximum over every back end listed
   there.  Deliberately a near-copy of genconfig.cc's apply_union_list: the two
   files are read by two generators built for different back ends, and sharing
   the code would mean a common object that both generator builds link, which
   is a bigger change than the duplication is worth.  If a third generator ever
   wants this, factor all three at once.  */

static void
apply_union_list (int *maxv)
{
  FILE *f = fopen (union_file, "r");
  if (!f)
    fatal ("cannot open union file `%s': %s", union_file, xstrerror (errno));

  int seen_max[OM_LAST];
  int union_max[OM_LAST];
  for (int i = 0; i < OM_LAST; i++)
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

      for (int i = 0; i < OM_LAST; i++)
	if (!strcmp (name, opinit_max_name[i]))
	  {
	    if (value > union_max[i] || !seen_max[i])
	      union_max[i] = value;
	    seen_max[i]++;
	  }
    }
  fclose (f);

  if (nbases == 0)
    fatal ("%s: no `base' line; the union run produced nothing", union_file);

  /* A union file that does not mention us is the stale-list failure mode, and
     it is NOT detectable from the values alone -- our own count may happen to
     be below somebody else's -- so check the name.  */
  if (!found_me)
    fatal ("%s: lists %d back end(s), none of them `%s';\n"
	   "  struct target_optabs would be sized for other targets",
	   union_file, nbases, this_base);

  for (int i = 0; i < OM_LAST; i++)
    {
      if (seen_max[i] != nbases)
	fatal ("%s: %s given for %d of %d back ends;\n"
	       "  a missing entry must not be read as a zero",
	       union_file, opinit_max_name[i], seen_max[i], nbases);
      if (union_max[i] < maxv[i])
	fatal ("%s: %s is %d there but this back end (`%s') needs %d;\n"
	       "  the union file is stale",
	       union_file, opinit_max_name[i], union_max[i], this_base,
	       maxv[i]);
      maxv[i] = union_max[i];
    }
}

static bool
handle_arg (const char *arg)
{
  switch (arg[1])
    {
    case 'h':
      header_file_name = &arg[2];
      return true;
    case 'c':
      source_file_name = &arg[2];
      return true;
    case 'l':
      if (arg[2] != '\0')
	return false;
      list_mode = true;
      return true;
    case 'U':
      if (arg[2] == '\0')
	return false;
      union_file = &arg[2];
      return true;
    case 'A':
      /* Rejected with no attached text rather than swallowing the next word:
	 a bare `-A' would otherwise take `-Uinsn-opinit-union.list' as the
	 back end's name and the diagnostic would point at the wrong thing.  */
      if (arg[2] == '\0')
	return false;
      this_base = &arg[2];
      return true;
    default:
      return false;
    }
}

static FILE *
open_outfile (const char *file_name)
{
  FILE *f = fopen (file_name, "w");
  if (!f)
    fatal ("cannot open file %s: %s", file_name, xstrerror (errno));
  fprintf (f,
	   "/* Generated automatically by the program `genopinit'\n"
	   "   from the machine description file `md'.  */\n\n");
  return f;
}

/* Declare the maybe_code_for_* function for ONAME, and provide
   an inline definition of the asserting code_for_* wrapper.  */

static void
handle_overloaded_code_for (FILE *file, overloaded_name *oname)
{
  fprintf (file, "\nextern insn_code maybe_code_for_%s (", oname->name);
  for (unsigned int i = 0; i < oname->arg_types.length (); ++i)
    fprintf (file, "%s%s", i == 0 ? "" : ", ", oname->arg_types[i]);
  fprintf (file, ");\n");

  fprintf (file, "inline insn_code\ncode_for_%s (", oname->name);
  for (unsigned int i = 0; i < oname->arg_types.length (); ++i)
    fprintf (file, "%s%s arg%d", i == 0 ? "" : ", ", oname->arg_types[i], i);
  fprintf (file, ")\n{\n  insn_code code = maybe_code_for_%s (", oname->name);
  for (unsigned int i = 0; i < oname->arg_types.length (); ++i)
    fprintf (file, "%sarg%d", i == 0 ? "" : ", ", i);
  fprintf (file,
	   ");\n"
	   "  gcc_assert (code != CODE_FOR_nothing);\n"
	   "  return code;\n"
	   "}\n");
}

/* Declare the maybe_gen_* function for ONAME, and provide
   an inline definition of the asserting gen_* wrapper.  */

static void
handle_overloaded_gen (FILE *file, overloaded_name *oname)
{
  unsigned HOST_WIDE_INT seen = 0;
  for (overloaded_instance *instance = oname->first_instance->next;
       instance; instance = instance->next)
    {
      pattern_stats stats;
      get_pattern_stats (&stats, XVEC (instance->insn, 1));
      unsigned HOST_WIDE_INT mask
	= HOST_WIDE_INT_1U << stats.num_generator_args;
      if (seen & mask)
	continue;

      seen |= mask;

      fprintf (file, "\nextern rtx maybe_gen_%s (", oname->name);
      for (unsigned int i = 0; i < oname->arg_types.length (); ++i)
	fprintf (file, "%s%s", i == 0 ? "" : ", ", oname->arg_types[i]);
      for (int i = 0; i < stats.num_generator_args; ++i)
	fprintf (file, ", rtx");
      fprintf (file, ");\n");

      fprintf (file, "inline rtx\ngen_%s (", oname->name);
      for (unsigned int i = 0; i < oname->arg_types.length (); ++i)
	fprintf (file, "%s%s arg%d", i == 0 ? "" : ", ",
		 oname->arg_types[i], i);
      for (int i = 0; i < stats.num_generator_args; ++i)
	fprintf (file, ", rtx x%d", i);
      fprintf (file, ")\n{\n  rtx res = maybe_gen_%s (", oname->name);
      for (unsigned int i = 0; i < oname->arg_types.length (); ++i)
	fprintf (file, "%sarg%d", i == 0 ? "" : ", ", i);
      for (int i = 0; i < stats.num_generator_args; ++i)
	fprintf (file, ", x%d", i);
      fprintf (file,
	       ");\n"
	       "  gcc_assert (res);\n"
	       "  return res;\n"
	       "}\n");
    }
}

int
main (int argc, const char **argv)
{
  FILE *h_file, *s_file;
  unsigned int i, j, n, last_kind[5];
  optab_pattern *p;

  progname = "genopinit";

  if (NUM_OPTABS > 0xfff || NUM_MACHINE_MODES > 0x3ff)
    fatal ("genopinit range assumptions invalid");

  if (!init_rtx_reader_args_cb (argc, argv, handle_arg))
    return (FATAL_EXIT_CODE);

  /* The output files are opened AFTER the machine description has been read,
     not before.  In -l mode there is no header and no source to write, and
     opening them first would truncate the real ones to the two-line banner --
     a build where `insn-opinit.h' exists, is non-empty, and contains no optab
     at all.  That is the "silently WRONG, not silently EMPTY" shape, so the
     opening is moved rather than made conditional in two places.  */

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

  /* Sort the collected patterns.  */
  patterns.qsort (pattern_cmp);

  /* THE UNION.  `own_patterns' is this back end's count and is what `pats[]'
     and the `ena[]' loops below are sized and driven by; `maxv' becomes the
     shared bound after -U.  Keeping them in two variables is the whole point:
     one name for both is the bug being fixed.  */
  const unsigned own_patterns = patterns.length ();
  int maxv[OM_LAST];
  maxv[OM_NUM_OPTAB_PATTERNS] = (int) own_patterns;

  if (list_mode)
    {
      if (!this_base)
	fatal ("-l needs -A<base>: an unnamed contribution cannot be checked "
	       "for by the run that reads the list");
      emit_union_list (maxv);
      if (ferror (stdout) || fflush (stdout) || fclose (stdout))
	return FATAL_EXIT_CODE;
      return SUCCESS_EXIT_CODE;
    }

  if (union_file)
    {
      if (!this_base)
	fatal ("-U needs -A<base>: without it the stale-list check cannot "
	       "tell whether this back end is in the file at all");
      apply_union_list (maxv);
    }

  h_file = open_outfile (header_file_name);
  s_file = open_outfile (source_file_name);

  /* Now that we've handled the "extra" patterns, eliminate them from
     the optabs array.  That way they don't get in the way below.  */
  n = num_optabs;
  for (i = 0; i < n; )
    if (optabs[i].base == NULL)
      optabs[i] = optabs[--n];
    else
      ++i;

  /* Sort the (real) optabs.  Better than forcing the optabs.def file to
     remain sorted by kind.  We also scrogged any real ordering with the
     purging of the X patterns above.  */
  qsort (optabs, n, sizeof (optab_def), optab_kind_cmp);

  fprintf (h_file, "#ifndef GCC_INSN_OPINIT_H\n");
  fprintf (h_file, "#define GCC_INSN_OPINIT_H 1\n");

  /* Emit the optab enumeration for the header file.  */
  fprintf (h_file, "enum optab_tag {\n");
  for (i = j = 0; i < n; ++i)
    {
      optabs[i].op = i;
      fprintf (h_file, "  %s,\n", optabs[i].name);
      if (optabs[i].kind != j)
	last_kind[j++] = i - 1;
    }
  fprintf (h_file, "  FIRST_CONV_OPTAB = %s,\n", optabs[last_kind[0]+1].name);
  fprintf (h_file, "  LAST_CONVLIB_OPTAB = %s,\n", optabs[last_kind[1]].name);
  fprintf (h_file, "  LAST_CONV_OPTAB = %s,\n", optabs[last_kind[2]].name);
  fprintf (h_file, "  FIRST_NORM_OPTAB = %s,\n", optabs[last_kind[2]+1].name);
  fprintf (h_file, "  LAST_NORMLIB_OPTAB = %s,\n", optabs[last_kind[3]].name);
  fprintf (h_file, "  LAST_NORM_OPTAB = %s\n", optabs[i-1].name);
  fprintf (h_file, "};\n\n");

  fprintf (h_file, "#define NUM_OPTABS          %u\n", n);
  fprintf (h_file, "#define NUM_CONVLIB_OPTABS  %u\n",
	   last_kind[1] - last_kind[0]);
  fprintf (h_file, "#define NUM_NORMLIB_OPTABS  %u\n",
	   last_kind[3] - last_kind[2]);
  /* The SHARED bound: the union max under -U, this back end's own count
     otherwise (a single-target build, where the two are the same thing).  */
  fprintf (h_file, "#define NUM_OPTAB_PATTERNS  %u\n",
	   (unsigned) maxv[OM_NUM_OPTAB_PATTERNS]);

  fprintf (h_file,
	   "typedef enum optab_tag optab;\n"
	   "typedef enum optab_tag convert_optab;\n"
	   "typedef enum optab_tag direct_optab;\n"
	   "\n"
	   "struct optab_libcall_d\n"
	   "{\n"
	   "  char libcall_suffix;\n"
	   "  const char *libcall_basename;\n"
	   "  void (*libcall_gen) (optab, const char *name,\n"
	   "		       char suffix, machine_mode);\n"
	   "};\n"
	   "\n"
	   "struct convert_optab_libcall_d\n"
	   "{\n"
	   "  const char *libcall_basename;\n"
	   "  void (*libcall_gen) (convert_optab, const char *name,\n"
	   "		       machine_mode, machine_mode);\n"
	   "};\n"
	   "\n"
	   "/* Given an enum insn_code, access the function to construct\n"
	   "   the body of that kind of insn.  */\n"
	   "#define GEN_FCN(CODE) (insn_data[CODE].genfun)\n"
	   "\n"
	   "#ifdef NUM_RTX_CODE\n");

  /* From here to the matching close, everything is per back end and is
     declared NOWHERE but in this generated header, so a namespace is all
     that is needed to keep two back ends' copies apart.  The inline
     accessors go inside with the arrays they read: they are COMDAT, and two
     back ends emitting `code_to_optab' with different bodies would dedupe
     to whichever the linker saw first -- the silent wrong-target failure,
     not a link error.  struct target_optabs and the this_*_optabs pointers
     stay OUTSIDE, because optabs.cc defines them.  */
  print_ns_open (h_file);

  fprintf (h_file,
	   "/* Contains the optab used for each rtx code, and vice-versa.  */\n"
	   "extern const optab code_to_optab_[NUM_RTX_CODE];\n"
	   "extern const enum rtx_code optab_to_code_[NUM_OPTABS];\n"
	   "\n"
	   "static inline optab\n"
	   "code_to_optab (enum rtx_code code)\n"
	   "{\n"
	   "  return code_to_optab_[code];\n"
	   "}\n"
	   "\n"
	   "static inline enum rtx_code\n"
	   "optab_to_code (optab op)\n"
	   "{\n"
	   "  return optab_to_code_[op];\n"
	   "}\n");

  for (overloaded_name *oname = rtx_reader_ptr->get_overloads ();
       oname; oname = oname->next)
    {
      handle_overloaded_code_for (h_file, oname);
      handle_overloaded_gen (h_file, oname);
    }

  print_ns_close (h_file);

  fprintf (h_file,
	   "#endif\n");

  print_ns_open (h_file);
  fprintf (h_file,
	   "\n"
	   "extern const struct convert_optab_libcall_d convlib_def[NUM_CONVLIB_OPTABS];\n"
	   "extern const struct optab_libcall_d normlib_def[NUM_NORMLIB_OPTABS];\n"
	   "\n"
	   "/* Returns the active icode for the given (encoded) optab.  */\n"
	   "extern enum insn_code raw_optab_handler (unsigned);\n"
	   "extern bool swap_optab_enable (optab, machine_mode, bool);\n");
  print_ns_close (h_file);

  fprintf (h_file,
	   "\n"
	   "/* Target-dependent globals.  */\n"
	   "struct target_optabs {\n"
	   "  /* Patterns that are used by optabs that are enabled for this target.  */\n"
	   "  bool pat_enable[NUM_OPTAB_PATTERNS];\n"
	   "\n"
	   "  /* Index VOIDmode caches if the target supports vec_gather_load for any\n"
	   "     vector mode.  Every other index X caches specifically for mode X.\n"
	   "     1 means yes, -1 means no.  */\n"
	   "  signed char supports_vec_gather_load[NUM_MACHINE_MODES];\n"
	   "  signed char supports_vec_scatter_store[NUM_MACHINE_MODES];\n"
	   "};\n");

  print_ns_open (h_file);
  fprintf (h_file,
	   "extern void init_all_optabs (struct target_optabs *);\n"
	   "extern bool partial_vectors_supported_p (void);\n");
  print_ns_close (h_file);

  fprintf (h_file,
	   "\n"
	   "extern struct target_optabs default_target_optabs;\n"
	   "extern struct target_optabs *this_fn_optabs;\n"
	   /* Declared unconditionally -- see the note in cfgloop.h.  This
	      header is generated, and generated headers reach tm.h/defaults.h
	      only through their includer, so the conditional form diverged
	      here too.  */
	   "extern struct target_optabs *this_target_optabs;\n");

  fprintf (s_file,
	   "#define IN_TARGET_CODE 1\n"
	   "#include \"config.h\"\n"
	   "#include \"system.h\"\n"
	   "#include \"coretypes.h\"\n"
	   "#include \"backend.h\"\n"
	   "#include \"predict.h\"\n"
	   "#include \"tree.h\"\n"
	   "#include \"rtl.h\"\n"
	   "#include \"alias.h\"\n"
	   "#include \"varasm.h\"\n"
	   "#include \"stor-layout.h\"\n"
	   "#include \"calls.h\"\n"
	   "#include \"memmodel.h\"\n");
  print_gen_include (s_file, "tm_p");
  fprintf (s_file,
	   "#include \"flags.h\"\n");
  print_gen_include (s_file, "insn-config");
  fprintf (s_file,
	   "#include \"expmed.h\"\n"
	   "#include \"dojump.h\"\n"
	   "#include \"explow.h\"\n"
	   "#include \"emit-rtl.h\"\n"
	   "#include \"stmt.h\"\n"
	   "#include \"expr.h\"\n");
  print_gen_include (s_file, "insn-codes");
  fprintf (s_file,
	   "#include \"optabs.h\"\n");

  /* The whole body of insn-opinit.cc is this back end's own; nothing in it
     is named by the middle end except through the header just written.  */
  print_ns_open (s_file);

  fprintf (s_file,
	   "\n"
	   "struct optab_pat {\n"
	   "  unsigned scode;\n"
	   "  enum insn_code icode;\n"
	   "};\n\n");

  /* THE BOUND HERE IS THIS BACK END'S OWN COUNT, NOT `NUM_OPTAB_PATTERNS'.
     The two were the same name until the union arrived and they are two
     different quantities:

       * `NUM_OPTAB_PATTERNS' sizes `pat_enable[]' in the SHARED struct
	 target_optabs, so it must be the maximum over every configured back
	 end -- see the note at the top of this file.
       * `pats[]' is THIS back end's sorted scode table, and `lookup_handler'
	 below binary-searches it with `h = ARRAY_SIZE (pats)'.

     Sizing `pats[]' by the union would append (union - own) zero-initialised
     `{ 0, CODE_FOR_nothing }' entries.  Zero sorts BELOW every real scode
     while sitting at the END of the array, so the table would no longer be
     sorted, and a binary search over an unsorted table does not fail -- it
     returns a wrong element, or -1, for arbitrary inputs.  On the back end
     with the smaller count that is every optab query silently answering
     CODE_FOR_nothing or worse, with nothing said.

     So the union raises the shared bound and leaves this one alone.  Printed
     as a literal rather than via a second macro so that no header can ever
     redefine it out from under the array it belongs to.  */
  fprintf (s_file,
	   "static const struct optab_pat pats[%u] = {\n",
	   (unsigned) patterns.length ());
  for (i = 0; patterns.iterate (i, &p); ++i)
    fprintf (s_file, "  { %#08x, CODE_FOR_%s },\n", p->sort_num, p->name);
  fprintf (s_file, "};\n\n");

  /* Some targets like riscv have a large number of patterns.  In order to
     prevent pathological situations in dataflow analysis split the init
     function into separate ones that initialize 1000 patterns each.  */

  const int patterns_per_function = 1000;

  if (patterns.length () > patterns_per_function)
    {
      unsigned num_init_functions
	= patterns.length () / patterns_per_function + 1;
      for (i = 0; i < num_init_functions; i++)
	{
	  fprintf (s_file, "static void\ninit_optabs_%02d "
		   "(struct target_optabs *optabs)\n{\n", i);
	  fprintf (s_file, "  bool *ena = optabs->pat_enable;\n");
	  unsigned start = i * patterns_per_function;
	  unsigned end = MIN (patterns.length (),
			      (i + 1) * patterns_per_function);
	  for (j = start; j < end; ++j)
	    fprintf (s_file, "  ena[%u] = HAVE_%s;\n", j, patterns[j].name);
	  fprintf (s_file, "}\n\n");
	}

      fprintf (s_file, "void\ninit_all_optabs "
	       "(struct target_optabs *optabs)\n{\n");
      for (i = 0; i < num_init_functions; ++i)
	fprintf (s_file, "  init_optabs_%02d (optabs);\n", i);
      fprintf (s_file, "}\n\n");
    }
  else
    {
      fprintf (s_file, "void\ninit_all_optabs "
	       "(struct target_optabs *optabs)\n{\n");
      fprintf (s_file, "  bool *ena = optabs->pat_enable;\n");
      for (i = 0; patterns.iterate (i, &p); ++i)
	fprintf (s_file, "  ena[%u] = HAVE_%s;\n", i, p->name);
      fprintf (s_file, "}\n\n");
    }

  fprintf (s_file,
	   "/* Returns TRUE if the target supports any of the partial vector\n"
	   "   optabs: while_ult_optab, len_load_optab, len_store_optab,\n"
	   "   mask_len_load_optab or mask_len_store_optab,\n"
	   "   for any mode.  */\n"
	   "bool\npartial_vectors_supported_p (void)\n{\n");
  bool any_match = false;
  fprintf (s_file, "\treturn");
  bool first = true;
  for (i = 0; patterns.iterate (i, &p); ++i)
    {
#define CMP_NAME(N) !strncmp (p->name, (N), strlen ((N)))
      if (CMP_NAME("while_ult") || CMP_NAME ("len_load")
	  || CMP_NAME ("len_store")|| CMP_NAME ("mask_len_load")
	  || CMP_NAME ("mask_len_store"))
	{
	  if (first)
	    fprintf (s_file, " HAVE_%s", p->name);
	  else
	    fprintf (s_file, " || HAVE_%s", p->name);
	  first = false;
	  any_match = true;
	}
    }
  if (!any_match)
    fprintf (s_file, " false");
  fprintf (s_file, ";\n}\n");


  /* Perform a binary search on a pre-encoded optab+mode*2.  */
  /* ??? Perhaps even better to generate a minimal perfect hash.
     Using gperf directly is awkward since it's so geared to working
     with strings.  Plus we have no visibility into the ordering of
     the hash entries, which complicates the pat_enable array.  */
  fprintf (s_file,
	   "static int\n"
	   "lookup_handler (unsigned scode)\n"
	   "{\n"
	   "  int l = 0, h = ARRAY_SIZE (pats), m;\n"
	   "  while (h > l)\n"
	   "    {\n"
	   "      m = (h + l) / 2;\n"
	   "      if (scode == pats[m].scode)\n"
	   "        return m;\n"
	   "      else if (scode < pats[m].scode)\n"
	   "        h = m;\n"
	   "      else\n"
	   "        l = m + 1;\n"
	   "    }\n"
	   "  return -1;\n"
	   "}\n\n");

  fprintf (s_file,
	   "enum insn_code\n"
	   "raw_optab_handler (unsigned scode)\n"
	   "{\n"
	   "  int i = lookup_handler (scode);\n"
	   "  return (i >= 0 && this_fn_optabs->pat_enable[i]\n"
	   "          ? pats[i].icode : CODE_FOR_nothing);\n"
	   "}\n\n");

  fprintf (s_file,
	   "bool\n"
	   "swap_optab_enable (optab op, machine_mode m, bool set)\n"
	   "{\n"
	   "  unsigned scode = (op << 20) | m;\n"
	   "  int i = lookup_handler (scode);\n"
	   "  if (i >= 0)\n"
	   "    {\n"
	   "      bool ret = this_fn_optabs->pat_enable[i];\n"
	   "      this_fn_optabs->pat_enable[i] = set;\n"
	   "      return ret;\n"
	   "    }\n"
	   "  else\n"
	   "    {\n"
	   "      gcc_assert (!set);\n"
	   "      return false;\n"
	   "    }\n"
	   "}\n\n");

  /* C++ (even G++) does not support (non-trivial) designated initializers.
     To work around that, generate these arrays programmatically rather than
     by our traditional multiple inclusion of def files.  */

  fprintf (s_file,
	   "const struct convert_optab_libcall_d "
	   "convlib_def[NUM_CONVLIB_OPTABS] = {\n");
  for (i = last_kind[0] + 1; i <= last_kind[1]; ++i)
    fprintf (s_file, "  { %s, %s },\n", optabs[i].base, optabs[i].libcall);
  fprintf (s_file, "};\n\n");

  fprintf (s_file,
	   "const struct optab_libcall_d "
	   "normlib_def[NUM_NORMLIB_OPTABS] = {\n");
  for (i = last_kind[2] + 1; i <= last_kind[3]; ++i)
    fprintf (s_file, "  { %s, %s, %s },\n",
	     optabs[i].suffix, optabs[i].base, optabs[i].libcall);
  fprintf (s_file, "};\n\n");

  fprintf (s_file, "enum rtx_code const optab_to_code_[NUM_OPTABS] = {\n");
  for (i = 0; i < n; ++i)
    fprintf (s_file, "  %s,\n", rtx_upname[optabs[i].fcode]);
  fprintf (s_file, "};\n\n");

  qsort (optabs, n, sizeof (optab_def), optab_rcode_cmp);

  fprintf (s_file, "const optab code_to_optab_[NUM_RTX_CODE] = {\n");
  for (j = 0; optabs[j].rcode == UNKNOWN; ++j)
    continue;
  for (i = 0; i < NON_GENERATOR_NUM_RTX_CODE; ++i)
    {
      if (j < n && optabs[j].rcode == i)
	fprintf (s_file, "  %s,\n", optabs[j++].name);
      else
	fprintf (s_file, "  unknown_optab,\n");
    }
  fprintf (s_file, "};\n\n");

  print_ns_close (s_file);

  /* This is the header that DECLARES the namespaced entities above, so it
     is the one that has to pull them into the global scope, exactly as
     insn-flags.h does for gen_*.  Every hand-written call site --
     optabs-query.h's inline optab_handler, optabs-libfuncs.cc's convlib_def
     -- then keeps working unqualified while the definitions carry distinct
     mangled names.  */
  print_ns_using (h_file);

  fprintf (h_file, "#endif\n");
  return (fclose (h_file) == 0 && fclose (s_file) == 0
	  ? SUCCESS_EXIT_CODE : FATAL_EXIT_CODE);
}
