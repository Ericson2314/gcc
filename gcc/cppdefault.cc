/* CPP Library.
   Copyright (C) 1986-2026 Free Software Foundation, Inc.
   Contributed by Per Bothner, 1994-95.
   Based on CCCP program by Paul Rubin, June 1986
   Adapted to ANSI C, Richard Stallman, Jan 1987

   This program is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by the
   Free Software Foundation; either version 3, or (at your option) any
   later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; see the file COPYING3.  If not see
   <http://www.gnu.org/licenses/>.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#include "cppdefault.h"
#include "target-caps.h"

#ifndef NATIVE_SYSTEM_HEADER_COMPONENT
#define NATIVE_SYSTEM_HEADER_COMPONENT 0
#endif

/* This block now governs the compile-time DEFAULTS only.  Whether a target has
   a /usr/local/include and a /usr/include is a per-target answer, and it now
   arrives as a per-target answer: an empty local_include_dir or
   native_system_header_dir capability drops the entry, which is what these
   `#undef's did when the question could only be asked once.

   Note CROSS_DIRECTORY_STRUCTURE is not currently defined by anything --
   gcc/configure.ac sets CROSS= unconditionally -- so this takes the `#else'
   arm on every build here.  Whether that should change is a separate,
   deliberately deferred question; nothing below decides it.  */
#if defined (CROSS_DIRECTORY_STRUCTURE) && !defined (TARGET_SYSTEM_ROOT)
# undef LOCAL_INCLUDE_DIR
# undef NATIVE_SYSTEM_HEADER_DIR
#else
# undef CROSS_INCLUDE_DIR
#endif

#ifndef INCLUDE_DEFAULTS
/* Guarded, because a target header that supplies its own INCLUDE_DEFAULTS
   replaces the whole table below and these two helpers would then be unused
   statics -- a -Werror=unused-function build failure on openbsd, netbsd,
   rs6000/sysv4 and linux-under-musl, i.e. on exactly the configurations
   nobody here can build.  */

/* The compile-time fallbacks, AFTER the `#undef's above have had their say.
   "" rather than a missing entry, because the entries below are now
   unconditional and the compaction at the end of the table is what expresses
   "no such directory" -- one mechanism for the macro being undefined here and
   for the target config file saying so, instead of two.  */
#ifdef LOCAL_INCLUDE_DIR
# define LOCAL_INCLUDE_DIR_FALLBACK LOCAL_INCLUDE_DIR
#else
# define LOCAL_INCLUDE_DIR_FALLBACK ""
#endif
#ifdef NATIVE_SYSTEM_HEADER_DIR
# define NATIVE_SYSTEM_HEADER_DIR_FALLBACK NATIVE_SYSTEM_HEADER_DIR
#else
# define NATIVE_SYSTEM_HEADER_DIR_FALLBACK ""
#endif

/* NULL means the target config file said nothing about this directory, so the
   value compiled in stands.  "" is NOT nothing: it is this target saying it has
   no such directory, and it survives to be compacted out below.  Collapsing the
   two would make `omit the key' and `emit an empty key' mean the same thing,
   which is the silent half of this interface.  */
static const char *
cap_dir (const char *cap, const char *fallback)
{
  return cap != NULL ? cap : fallback;
}

/* The `component' of the /usr/include entries (see update_path in prefix.cc).
   It travels with the directory: a component naming one target's installation
   applied to another target's directory would relocate paths under the wrong
   prefix.  Same three states, except that here the empty answer is spelt NULL
   on the way out, because that is what a component-less entry has always been
   and what update_path tests for.  */
static const char *
native_system_header_component (void)
{
  const char *c = targ_caps.native_system_header_component;
  if (c == NULL)
    c = NATIVE_SYSTEM_HEADER_COMPONENT;
  return (c != NULL && c[0] != '\0') ? c : NULL;
}
#endif /* no INCLUDE_DEFAULTS */

/* THE RUNTIME ENTRIES: the C++ header directories, /usr/local/include and
   /usr/include.  This is where they enter the include search path.

   They used to be `--with-gxx-include-dir', `--with-gxx-libcxx-include-dir',
   `--with-local-prefix' and `--with-native-system-header-dir' in
   gcc/configure.ac, i.e. strings chosen when gcc was built.  A path into a
   libstdc++, libc++ or C library installation is not a fact about the host gcc
   runs on; it is a fact about the toolchain gcc has been pointed at, and a
   compiler serving many targets has one such answer per target.  So the answer
   arrives in the per-target config file and cc1 has it in targ_caps by the time
   add_standard_paths asks for this table.

   An empty string means "this target has no such directory" and the entry is
   dropped below, rather than entering the search path as "".  The built-in
   defaults are still what gcc/Makefile.in computes -- the installation-relative
   C++ paths, $(local_prefix)/include, and config.gcc's
   $(NATIVE_SYSTEM_HEADER_DIR) -- so a compiler told nothing about its target
   searches exactly what it always did.  */

const struct default_include *
cpp_include_defaults_table (void)
{
  /* FUNCTION-LOCAL, and that is the whole point of this being a function.
     Seven of the initialisers below read targ_caps, and a namespace-scope array
     would be dynamically initialised at load time -- before cc1 has opened the
     target config file -- so it would capture the built-in fallbacks and no
     -ftarget-config= would ever have any effect on the include path.  A
     function-local static is initialised on first call, which is after
     read_target_caps.  */
  static struct default_include table[]
#ifdef INCLUDE_DEFAULTS
/* A handful of target headers (config/linux.h under musl, openbsd.h,
   netbsd.h, rs6000/sysv4.h) supply their own ordering, built from the
   GPLUSPLUS_* macros.  Those are left alone deliberately: they are per-target
   headers stating a per-target answer, and reaching into them is the separate
   job of getting INCLUDE_DEFAULTS itself out of the privileged target's tm.h.
   Converting them here would change netbsd's hard-coded /usr/include/g++ on a
   build no one here can test.  */
= INCLUDE_DEFAULTS;
#else
= {
    /* Pick up GNU C++ generic include files.  */
    { targ_caps.gxx_include_dir, "G++", 1, 1, 0, 0 },
    /* Pick up GNU C++ target-dependent include files.  */
    { targ_caps.gxx_tool_include_dir, "G++", 1, 1, 0, 1 },
    /* Pick up GNU C++ backward and deprecated include files.  */
    { targ_caps.gxx_backward_include_dir, "G++", 1, 1, 0, 0 },
    /* Pick up libc++ include files, if we have -stdlib=libc++.  */
    { targ_caps.gxx_libcxx_include_dir, "G++", 2, 1, 0, 0 },
#ifdef GCC_INCLUDE_DIR
    /* This is the dir for gcc's private headers.  */
    { GCC_INCLUDE_DIR, "GCC", 0, 0, 0, 0 },
#endif
    /* /usr/local/include comes before the fixincluded header files.  No
       `#ifdef' any more: the entry is always built and the compaction below
       removes it when the answer, from either source, is "no such
       directory".  */
    { cap_dir (targ_caps.local_include_dir, LOCAL_INCLUDE_DIR_FALLBACK),
      0, 0, 1, 1, 2 },
    { cap_dir (targ_caps.local_include_dir, LOCAL_INCLUDE_DIR_FALLBACK),
      0, 0, 1, 1, 0 },
#ifdef PREFIX_INCLUDE_DIR
    { PREFIX_INCLUDE_DIR, 0, 0, 1, 0, 0 },
#endif
    /* This is the dir for fixincludes.  FORMERLY the compile-time
       -DFIXED_INCLUDE_DIR="$(libsubdir)/include-fixed", written by gcc's own
       build.  It is neither any more, and both halves of that changed for the
       same reason.

       fixincludes patches the ACTUAL SYSTEM HEADERS OF ONE MACHINE.  A
       compiler serving N targets has N sets of fixed headers and no single
       answer to compile in -- and $(libsubdir) is $(libdir)/gcc/$(version),
       with no target component, so the one directory that macro named was one
       directory for all of them.  The headers now live per target, under
       $(libsubdir)/<target>/include-fixed, written by fixincludes/mkheaders on
       the deployed machine, and the path arrives here in the per-target config
       file like every other post-install fact.

       THE DEFAULT IS "" AND THAT IS THE POINT.  gcc's build no longer creates
       include-fixed, so a compile-time path here would be a system include
       directory that NOTHING CREATES -- the entry would sit in every search
       path and be silently skipped.  "" is compacted
       out below, so a compiler nobody has told about fixed headers does not
       claim to have any.  Say `fixed_include_dir <path>' in the target config
       to get the entry back, and it names a directory mkheaders made.

       ONE ENTRY, multilib = 1, not the old two.  Upstream emitted a second
       multiarch (2) copy when SYSROOT_HEADERS_SUFFIX_SPEC was undefined and
       otherwise a multilib (1) copy; that macro is a tm.h macro, i.e. the
       privileged target answering for everyone.  mkheaders creates
       include-fixed<multi_dir> for every entry of fixinc_list -- multilib,
       unconditionally, for all targets -- so multilib = 1 is what actually
       exists on disk.  */
    { targ_caps.fixed_include_dir, "GCC", 0, 0, 0, 1 },
#ifdef CROSS_INCLUDE_DIR
    /* One place the target system's headers might be.  */
    { CROSS_INCLUDE_DIR, "GCC", 0, 0, 0, 0 },
#endif
    /* Another place the target system's headers might be: the include
       directory of the binutils installation for this target.  FORMERLY the
       compile-time -DTOOL_INCLUDE_DIR="$(gcc_tooldir)/include", and that macro
       was the last entry in this table under the control of NO capability at
       all -- it survived with gxx_tool_include_dir, fixed_include_dir and
       native_system_header_dir every one of them set to "".

       It was also WRONG, silently.  $(gcc_tooldir) ends in
       $(target_noncanonical), which is unsubstituted on this branch and so
       EMPTY, collapsing $(prefix)/<triple>/include to $(prefix)/include --
       `/usr/include' under the default prefix.  So the entry named the HOST's
       system headers, for every target, and a host that has a /usr/include
       compiled every target against it and succeeded.  gcc/Makefile.in:864
       diagnoses exactly this shape one line below where it was introduced, for
       build_tooldir; gcc_tooldir was left alone.

       Per target now, three-state like fixed_include_dir, default "" and
       compacted out below.  Separate from gxx_tool_include_dir on purpose: a
       target may use the host's C++ headers while needing its own binutils
       tree.  */
    { targ_caps.tool_include_dir, "BINUTILS", 0, 1, 0, 0 },
    /* /usr/include comes dead last.  Unconditional for the same reason as
       LOCAL_INCLUDE_DIR above.  */
    { cap_dir (targ_caps.native_system_header_dir,
	       NATIVE_SYSTEM_HEADER_DIR_FALLBACK),
      native_system_header_component (), 0, 0, 1, 2 },
    { cap_dir (targ_caps.native_system_header_dir,
	       NATIVE_SYSTEM_HEADER_DIR_FALLBACK),
      native_system_header_component (), 0, 0, 1, 0 },
    { 0, 0, 0, 0, 0, 0 }
  };
#endif /* no INCLUDE_DEFAULTS */

  /* Drop the directories the target config file left empty.  "" is a valid
     capability value meaning "this target has no such directory"; letting it
     through would add the current working directory to every system include
     search, which is a silent wrong answer rather than a missing one.  Done
     once, guarded, because the caller loops over this on every compilation.  */
  static bool compacted = false;
  if (!compacted)
    {
      compacted = true;
      unsigned j = 0;
      for (unsigned i = 0; table[i].fname != NULL; i++)
	if (table[i].fname[0] != '\0')
	  table[j++] = table[i];
      memset (&table[j], 0, sizeof table[j]);
    }

  return table;
}

#ifdef GCC_INCLUDE_DIR
const char cpp_GCC_INCLUDE_DIR[] = GCC_INCLUDE_DIR;
const size_t cpp_GCC_INCLUDE_DIR_len = sizeof GCC_INCLUDE_DIR - 8;
#else
const char cpp_GCC_INCLUDE_DIR[] = "";
const size_t cpp_GCC_INCLUDE_DIR_len = 0;
#endif

/* The configured prefix.  */
const char cpp_PREFIX[] = PREFIX;
const size_t cpp_PREFIX_len = sizeof PREFIX - 1;
const char cpp_EXEC_PREFIX[] = STANDARD_EXEC_PREFIX;

/* This value is set by cpp_relocated at runtime */
const char *gcc_exec_prefix;

/* Return true if the toolchain is relocated.  */
bool
cpp_relocated (void)
{
  static int relocated = -1;

  /* A relocated toolchain ignores standard include directories.  */
  if (relocated == -1)
    {
      /* Check if the toolchain was relocated?  */
      gcc_exec_prefix = getenv ("GCC_EXEC_PREFIX");
      if (gcc_exec_prefix)
       relocated = 1;
      else
       relocated = 0;
    }

  return relocated;
}
