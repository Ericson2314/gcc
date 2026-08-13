/* The per-back-end namespace and generated-header suffix, for the gen*
   programs.
   Copyright (C) 2000-2026 Free Software Foundation, Inc.

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

/* WHY THIS IS NOT IN gensupport.cc, where it was written.

   build/genconstants is the program that WRITES insn-constants.h.  It has to
   agree with every other gen* program about GEN_HDR_SUFFIX -- that is what
   gen_multi_target_p () decides for it -- and the only place such an
   agreement can live is one translation unit that all of them link.  That
   unit used to be gensupport.cc, which is compiled against rtl.h, hence
   tm.h, hence insn-constants.h.  So the program that writes insn-constants.h
   could not be COMPILED until insn-constants.h already existed:

       make[1]: Circular build/genconstants.o <- insn-constants.h dependency
                dropped.
       ./tm.h:41:11: fatal error: insn-constants.h: No such file or directory

   An existing build directory hid this completely, because the header was
   already there from an earlier state; it reproduced only from an empty one.

   The six functions below read no target macro and touch no rtx -- they are
   string handling over GEN_HDR_SUFFIX.  Splitting them out is therefore not a
   weakening of the single-authority rule that put them next to gensupport in
   the first place: there is still exactly ONE definition of gen_target_ns ()
   in the build, and now every generator, genconstants included, can link it
   without dragging in a target header.  The alternative -- a second copy of
   the suffix default inside genconstants.cc -- is precisely the one
   name/two authorities bug that GEN_HDR_SUFFIX exists to prevent.  */

#include "bconfig.h"
#include "system.h"
#include "coretypes.h"
#include "gen-target-ns.h"

/* Write `#include "NAME<suffix>.h"' to OUTF.  See gen-target-ns.h.  */

void
print_gen_include (FILE *outf, const char *name)
{
  fprintf (outf, "#include \"%s%s.h\"\n", name, GEN_HDR_SUFFIX);
}

/* The per-back-end namespace, or NULL in a single-target build.
   See gen-target-ns.h.  */

const char *
gen_target_ns (void)
{
  static char *ns;
  static bool computed;

  if (!computed)
    {
      const char *suffix = GEN_HDR_SUFFIX;

      computed = true;
      if (suffix[0] == '-' && suffix[1] != '\0')
	{
	  ns = concat ("insn_", suffix + 1, NULL);
	  /* cpu_type directory names are already identifier-safe, but do not
	     rely on it: one bad character here is a syntax error in every
	     generated file at once, which is a confusing way to learn it.  */
	  for (char *p = ns; *p; p++)
	    if (!ISALNUM (*p) && *p != '_')
	      *p = '_';
	}
    }
  return ns;
}

/* True if the md pattern NAME's gen_NAME is a name the MIDDLE END already
   declares, so that insn-flags-<base>.h must not declare it a second time.

   THE MEANING OF THIS LIST HAS CHANGED and the old meaning is worth keeping,
   because the reasoning behind it was half right.  It used to mean "keep
   gen_NAME at global scope", and genemit and genflags both stepped out of the
   namespace for it.  `blockage' is the only case either way: emit-rtl.h
   declares `gen_blockage' unconditionally and emit-rtl.cc DEFINES it under
   `#if !HAVE_blockage', so the middle end (builtins.cc, explow.cc,
   function.cc) calls one name supplied either by the middle end or by a back
   end's insn-emit.  Keeping the back end's copy global did make those calls
   unambiguous -- and it also meant that two configured back ends both defined
   `::gen_blockage', which an archive resolves by picking one and saying
   nothing.  The ambiguity was being bought at the price of the very thing
   this branch exists to fix.

   The per-back-end DEFINITIONS are namespaced now, like everything else.

   WHAT THIS COMMENT USED TO SAY, AND WHY IT WAS WRONG.  It said the bare
   `::gen_blockage' "comes from multi-target-select.cc, which forwards to the
   back end in force", and that multi-target-select.cc "defines `::gen_blockage'
   under `#if HAVE_blockage'".  Neither is true and neither has ever been true:
   multi-target-select.cc contains a COMMENT describing that forwarder and no
   forwarder.  Measured (task #51, /tmp/b78, x86_64 + aarch64): the only strong
   definition of the bare `::gen_blockage' in the whole link is in
   `insn-emit-5.o' -- the PRIMARY's un-namespaced insn-emit, i.e. i386's
   expander -- and `builtins.o', `explow.o', `function.o' and
   `mt-aarch64/aarch64.o' all bind to it.  `UNSPECV_BLOCKAGE' is 1 in
   insn-constants-i386.h and 5 in insn-constants-aarch64.h, so an aarch64
   compilation emits an `unspec_volatile' numbered 1 that its own recog matches
   at 5.  No link error, no diagnostic.

   It is not one name either.  The same measurement found SIX bare names that
   the primary's insn-emit answers for every configured target: `add_clobbers',
   `added_clobbers_hard_reg_p', `gen_blockage', `gen_nop',
   `gen_speculation_barrier' and `gen_movxf'.  Five of the six are defined by
   every configured base in its own namespace and can take a uniform forwarder;
   `gen_movxf' is defined by i386 and not by aarch64 and cannot.  See the
   handover for #51.

   What ALSO survives is a declaration problem: a namespaced declaration in
   insn-flags-<base>.h, pulled into scope by that header's using-directive,
   makes every hand-written `gen_blockage ()' in config/i386/i386.cc and
   config/aarch64/aarch64.cc an ambiguous overload against emit-rtl.h's.  So
   genflags SKIPS the names on this list; see the note at its call site.

   THE EDGE, STATED RATHER THAN FLOORED: whatever eventually defines
   `::gen_blockage' here must be guarded by the exact complement of
   emit-rtl.cc's `#if !HAVE_blockage', and HAVE_blockage comes from the
   SINGULAR insn-flags.h -- still the primary target's.  Configure a primary
   with no `blockage' pattern alongside a base that has one and the middle end
   calls emit-rtl.cc's generic expansion for both.  That is a wrong answer, not
   a link failure, and the fix is to union the singular insn-flags.h -- the same
   job insn-config.h has already had done to it.  Until then it is written
   down, here and in multi-target-select.cc, rather than papered over.

   The failure mode if this list is ever short is a compile error at the call
   site naming the function, not silent misbehaviour.  */

bool
gen_name_is_global_p (const char *name)
{
  static const char *const globals[] = { "blockage" };

  if (!gen_target_ns ())
    return false;
  for (unsigned i = 0; i < ARRAY_SIZE (globals); i++)
    if (strcmp (name, globals[i]) == 0)
      return true;
  return false;
}

/* Open the per-back-end namespace on OUTF.  No-op when singular.  */

void
print_ns_open (FILE *outf)
{
  const char *ns = gen_target_ns ();
  if (ns)
    fprintf (outf, "\nnamespace %s {\n", ns);
}

/* Close it again.  */

void
print_ns_close (FILE *outf)
{
  const char *ns = gen_target_ns ();
  if (ns)
    fprintf (outf, "\n} /* namespace %s */\n", ns);
}

/* Declare the namespace and pull it into the global scope, so that the
   thousands of hand-written call sites that say gen_addsi3 (...) keep
   working unqualified while the DEFINITIONS get distinct mangled names.
   A using-directive also covers members declared after it, which is what
   makes this usable at the top of a generated file.  */

void
print_ns_using (FILE *outf)
{
  const char *ns = gen_target_ns ();
  if (ns)
    fprintf (outf, "\nnamespace %s { }\nusing namespace %s;\n", ns, ns);
}
