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

/* This header must stay free of rtl.h and of any target header.  The program
   that WRITES insn-constants.h includes it, so anything reached from here
   that reaches tm.h makes that program impossible to compile in a build
   directory that does not already contain the file it produces.  See the
   comment at the top of gen-target-ns.cc.  */

#ifndef GCC_GEN_TARGET_NS_H
#define GCC_GEN_TARGET_NS_H

/* Multi-target: in a multi-target build each of these programs runs once per
   back end and writes insn-<thing>-<base>.{h,cc}, so the headers its output
   INCLUDES must carry the same <base> suffix -- otherwise a back end's
   generated source is compiled against some other back end's insn-config.h /
   insn-codes.h / insn-attr.h / tm_p.h and mis-generates SILENTLY: it still
   compiles, because the names all exist, they just describe the wrong target.
   Which suffix to emit is settled when the generator itself is compiled, the
   same knob as TM_H_FILE (see gen-multi-target-md.awk).  Empty, i.e. the
   upstream names, in a single-target build.

   Applies ONLY to generated headers.  Hand-written ones the output also names
   (insn-addr.h, recog.h, ...) exist once and must not be suffixed.  */
#ifndef GEN_HDR_SUFFIX
#define GEN_HDR_SUFFIX ""
#endif

/* Write `#include "NAME<suffix>.h"' to OUTF.  NAME is given without the
   ".h".  Use this for every GENERATED header a generator's output names, so
   that adding a back end cannot leave one of them pointing at another back
   end's file.  */
extern void print_gen_include (FILE *outf, const char *name);

/* Multi-target, part two: the generated SOURCES define the same identifiers
   for every back end -- gen_addsi3, pattern42, recog_7 -- because they are
   the standard optab vocabulary plus per-file counters.  Measured on aarch64
   against the x86_64 libbackend.a: 6005 strong-symbol collisions, of which
   5058 are gen_*.  That overlap is structural, so there is nothing to dedupe;
   the names have to become distinct.

   They are made distinct by NAMESPACE rather than by renaming, because
   gen_addsi3 is called by that spelling from thousands of hand-written
   back-end sources and from the middle end.  A namespace plus a
   using-directive in the header that declares them changes the mangled
   symbol and changes no call site.  (The same reasoning as the machine-mode
   fix f7c4d1aed68: qualify what collides, leave the spelling alone.)

   Namespaced too, since the selector landed: recog, split_insns,
   peephole2_insns, add_clobbers, added_clobbers_hard_reg_p, insn_extract,
   get_insn_name, peephole and the mode and insn_data tables all have
   per-back-end definitions here and one bare forwarding definition in
   multi-target-select.cc.  */
extern const char *gen_target_ns (void);

/* True when the compiler being built holds more than one back end.

   gen_target_ns () answers a narrower question -- "am I generating FOR one
   particular back end" -- and for the per-back-end runs the two coincide.
   They come apart for the SINGULAR runs of a generator on a multi-target
   build: build/genconstants writes the insn-constants.h the middle end reads,
   has no back end of its own, and still has to declare unspec_strings as a
   pointer, because the definitions behind it are per back end.  Getting that
   wrong is not a link error -- the declaration and the definition disagree
   about array-versus-pointer in different translation units -- so it is worth
   a name of its own rather than an ad-hoc test at each site.

   GEN_MULTI_TARGET is passed by Makefile.in to exactly those singular
   generator objects, from $(multi_target_base), which is the same variable the
   modes and insn-config unions key on.  */

inline bool
gen_multi_target_p (void)
{
#ifdef GEN_MULTI_TARGET
  return true;
#else
  return gen_target_ns () != NULL;
#endif
}

extern bool gen_name_is_global_p (const char *name);
extern void print_ns_open (FILE *outf);
extern void print_ns_close (FILE *outf);
extern void print_ns_using (FILE *outf);

#endif /* GCC_GEN_TARGET_NS_H */
