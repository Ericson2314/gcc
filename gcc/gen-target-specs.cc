/* Print one target's source-derived spec macros in read_specs() format.
   Copyright (C) 2026 Free Software Foundation, Inc.

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

/* WHY THIS EXISTS

   gcc.cc does not include tm.h, so every spec macro a target header defines
   is invisible to the driver: it only ever sees its own #ifndef fallback.
   That is deliberate -- the driver must carry no compile-time target
   knowledge -- but the replacement was only half-built.  target-specs/
   supplies the specs that come from PROBING the target's assembler and
   linker.  It cannot supply the specs that come from the target's tm.h
   chain, because those are properties of the SOURCE TREE, known at build
   time, and target-specs runs post-build against tools it has to interrogate.

   This program is the other half.  It is compiled once per configured target
   against that target's tm-<base>.h, and it prints the spec macros that
   header chain defines.  The output is a spec file fragment in exactly the
   `*name:\nvalue\n\n' form read_specs() parses, so the values reach the
   driver at run time by the mechanism that already exists -- every name
   emitted here is a registered static spec in gcc.cc's static_specs[], and a
   spec file entry overrides the built-in default.

   THE BOUNDARY.  Source-derived here; probed in target-specs/.  If a value
   depends on which assembler or linker is installed, it does not belong in
   this file.  If it is a string in the target's header chain, it does.

   GENERATOR_FILE is defined for this program exactly as it is for genmodes
   and friends, which is what lets tm-<base>.h skip its insn-flags-<base>.h
   and insn-modes-<base>.h includes -- those are not built for non-primary
   targets, and nothing here needs them.  */

#include "bconfig.h"
#include "system.h"
#include "coretypes.h"
#include "spec-names.h"

/* Macros the DRIVER supplies to the target headers, rather than the other way
   round.  A target header that references one of these is asking a question
   about the installed linker, which is target-specs/'s business, not this
   program's.  Each is therefore given a named-spec reference here: the
   structure the target header wrote is preserved, the driver resolves the
   name at run time, and target-specs can put a real value behind it without
   anything in this file changing.  Defining them to a fixed answer instead
   would bake a probe result into a source-derived file, which is exactly the
   boundary this program exists to keep.  */
#define LINK_LIBATOMIC_SPEC "%(link_libatomic)"

/* config/darwin.h builds its LINK_COMMAND_SPEC out of this one.  target-specs
   already writes *link_plugin, gated on whether an LTO plugin was found.  */
#define LINK_PLUGIN_SPEC "%(link_plugin)"

/* Likewise, and also from darwin.h's LINK_COMMAND_SPEC.  target-specs writes
   *link_compress_debug from what it found the linker able to do.  */
#define LINK_COMPRESS_DEBUG_SPEC "%(link_compress_debug)"

/* config/i386/cygming.h declares a `mingw_include_path' extra spec whose value
   is this.  It used to come from gcc/Makefile.in's PREPROCESSOR_DEFINES and was
   dropped when the compiler stopped being configured for one target, so nothing
   has defined it since -- another macro left referenced with no definer, found
   by compiling this file for i686-pc-cygwin.  The triple is what it always
   held, and here it is this target's triple rather than the build's one, which
   is more nearly right than what it replaced.  */
#define DEFAULT_TARGET_MACHINE TARGET_TRIPLE

#include TM_HEADER

/* gcc.cc does not build its `cpp', `cc1' and `link' specs from one macro
   each.  It builds them from two:

       cpp_spec  = CPP_SPEC  LIBC_CPP_SPEC       (gcc.cc:1167)
       cc1_spec  = CC1_SPEC  OS_CC1_SPEC         (gcc.cc:1168)
       link_spec = LINK_SPEC LIBC_LINK_SPEC      (gcc.cc:1174)

   The second of each is how a C library or an OS layer adds to what the CPU
   back end asked for, and five targets in the tree use them.  Emitting only
   the first would drop those silently -- the spec file would look complete and
   be missing an arm of the value on exactly the targets that needed it.  So
   the composition is mirrored here, with the same "" fallbacks gcc.cc uses,
   and these three are emitted unconditionally rather than under #ifdef.  */
#ifndef CPP_SPEC
#define CPP_SPEC ""
#endif
#ifndef LIBC_CPP_SPEC
#define LIBC_CPP_SPEC ""
#endif
#ifndef CC1_SPEC
#define CC1_SPEC ""
#endif
#ifndef OS_CC1_SPEC
#define OS_CC1_SPEC ""
#endif
#ifndef LINK_SPEC
#define LINK_SPEC ""
#endif
#ifndef LIBC_LINK_SPEC
#define LIBC_LINK_SPEC ""
#endif

/* Emit one spec.  A target may legitimately define a spec macro as the empty
   string; that is different from not defining it at all, and read_specs
   accepts an empty value, so it is passed through rather than skipped.  */

static void
emit (const char *name, const char *value)
{
  printf ("*%s:\n%s\n\n", name, value);
}

int
main (void)
{
  printf ("# Source-derived specs for %s.\n"
	  "# Generated by gen-target-specs from that target's tm.h chain.\n"
	  "# Do not edit; edit the target headers under gcc/config/ instead.\n"
	  "\n", TARGET_TRIPLE);

  /* Compilation.  */
#ifdef ASM_SPEC
  emit ("asm", ASM_SPEC);
#endif
#ifdef ASM_V_SPEC
  emit ("asm_v", ASM_V_SPEC);
#endif
#ifdef ASM_FINAL_SPEC
  emit ("asm_final", ASM_FINAL_SPEC);
#endif
  emit ("cpp", CPP_SPEC LIBC_CPP_SPEC);
  emit ("cc1", CC1_SPEC OS_CC1_SPEC);
#ifdef CC1PLUS_SPEC
  emit ("cc1plus", CC1PLUS_SPEC);
#endif

  /* Linking.  */
  emit ("link", LINK_SPEC LIBC_LINK_SPEC);
#ifdef LIB_SPEC
  emit ("lib", LIB_SPEC);
#endif
#ifdef LIBGCC_SPEC
  emit ("libgcc", LIBGCC_SPEC);
#endif
#ifdef STARTFILE_SPEC
  emit ("startfile", STARTFILE_SPEC);
#endif
#ifdef ENDFILE_SPEC
  emit ("endfile", ENDFILE_SPEC);
#endif
#ifdef LINK_GCC_C_SEQUENCE_SPEC
  emit ("link_gcc_c_sequence", LINK_GCC_C_SEQUENCE_SPEC);
#endif
#ifdef LINK_SSP_SPEC
  emit ("link_ssp", LINK_SSP_SPEC);
#endif
#ifdef LINK_COMMAND_SPEC
  emit ("link_command", LINK_COMMAND_SPEC);
#endif
#ifdef POST_LINK_SPEC
  emit ("post_link", POST_LINK_SPEC);
#endif
#ifdef LINKER_NAME
  emit ("linker", LINKER_NAME);
#endif

  /* Paths and prefixes.  */
#ifdef STARTFILE_PREFIX_SPEC
  emit ("startfile_prefix_spec", STARTFILE_PREFIX_SPEC);
#endif
#ifdef SYSROOT_SPEC
  emit ("sysroot_spec", SYSROOT_SPEC);
#endif
#ifdef SYSROOT_SUFFIX_SPEC
  emit ("sysroot_suffix_spec", SYSROOT_SUFFIX_SPEC);
#endif
#ifdef SYSROOT_HEADERS_SUFFIX_SPEC
  emit ("sysroot_hdrs_suffix_spec", SYSROOT_HEADERS_SUFFIX_SPEC);
#endif
#ifdef MD_EXEC_PREFIX
  emit ("md_exec_prefix", MD_EXEC_PREFIX);
#endif
#ifdef MD_STARTFILE_PREFIX
  emit ("md_startfile_prefix", MD_STARTFILE_PREFIX);
#endif
#ifdef MD_STARTFILE_PREFIX_1
  emit ("md_startfile_prefix_1", MD_STARTFILE_PREFIX_1);
#endif

  /* EXTRA_SPECS is how a target header declares additional named specs that
     its own spec strings then reference with %(name).  i386's CC1_SPEC refers
     to %(cc1_cpu), so omitting this would leave the emitted *cc1 dangling.  */
#ifdef EXTRA_SPECS
  {
    static const struct { const char *name; const char *spec; } extra[] =
      { EXTRA_SPECS };
    for (unsigned i = 0; i < sizeof (extra) / sizeof (extra[0]); i++)
      emit (extra[i].name, extra[i].spec);
  }
#endif

  /* DRIVER_SELF_SPECS is an array of strings, and the driver applies them in
     order, so they are concatenated into the single `self_spec' slot.  */
#ifdef DRIVER_SELF_SPECS
  {
    static const char *const self[] = { DRIVER_SELF_SPECS };
    printf ("*self_spec:\n");
    for (unsigned i = 0; i < sizeof (self) / sizeof (self[0]); i++)
      printf ("%s%s", i ? " " : "", self[i]);
    printf ("\n\n");
  }
#endif

  /* MULTILIB_DEFAULTS is a brace-enclosed list of option names, which the
     multilib_defaults spec spells as a space-separated list.  */
#ifdef MULTILIB_DEFAULTS
  {
    static const char *const mld[] = MULTILIB_DEFAULTS;
    printf ("*multilib_defaults:\n");
    for (unsigned i = 0; i < sizeof (mld) / sizeof (mld[0]); i++)
      printf ("%s%s", i ? " " : "", mld[i]);
    printf ("\n\n");
  }
#endif

  return 0;
}
