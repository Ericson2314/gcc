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

#if defined (CROSS_DIRECTORY_STRUCTURE) && !defined (TARGET_SYSTEM_ROOT)
# undef LOCAL_INCLUDE_DIR
# undef NATIVE_SYSTEM_HEADER_DIR
#else
# undef CROSS_INCLUDE_DIR
#endif

/* THE C++ HEADER DIRECTORIES ARE THE ONLY RUNTIME ENTRIES HERE, and this is
   where they enter the include search path.

   They used to be `--with-gxx-include-dir' and `--with-gxx-libcxx-include-dir'
   in gcc/configure.ac, i.e. one string chosen when gcc was built.  A path into
   a libstdc++ or libc++ installation is not a fact about the host gcc runs on;
   it is a fact about the toolchain gcc has been pointed at, and a compiler
   serving many targets has one such answer per target.  So the answer arrives
   in the per-target config file and cc1 has it in targ_caps by the time
   add_standard_paths asks for this table.

   An empty string means "this target has no such directory" and the entry is
   dropped below, rather than entering the search path as "".  The built-in
   defaults are still the installation-relative paths gcc/Makefile.in computes
   from $(libdir)/$(prefix)/$(version), so a compiler told nothing about its
   target searches exactly what it always did.  */

const struct default_include *
cpp_include_defaults_table (void)
{
  /* FUNCTION-LOCAL, and that is the whole point of this being a function.
     Four of the initialisers below read targ_caps, and a namespace-scope array
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
#ifdef LOCAL_INCLUDE_DIR
    /* /usr/local/include comes before the fixincluded header files.  */
    { LOCAL_INCLUDE_DIR, 0, 0, 1, 1, 2 },
    { LOCAL_INCLUDE_DIR, 0, 0, 1, 1, 0 },
#endif
#ifdef PREFIX_INCLUDE_DIR
    { PREFIX_INCLUDE_DIR, 0, 0, 1, 0, 0 },
#endif
#ifdef FIXED_INCLUDE_DIR
    /* This is the dir for fixincludes.  */
#ifndef SYSROOT_HEADERS_SUFFIX_SPEC
    { FIXED_INCLUDE_DIR, "GCC", 0, 0, 0, 2 },
#endif
    { FIXED_INCLUDE_DIR, "GCC", 0, 0, 0,
      /* A multilib suffix needs adding if different multilibs use
	 different headers.  */
#ifdef SYSROOT_HEADERS_SUFFIX_SPEC
      1
#else
      0
#endif
    },
#endif
#ifdef CROSS_INCLUDE_DIR
    /* One place the target system's headers might be.  */
    { CROSS_INCLUDE_DIR, "GCC", 0, 0, 0, 0 },
#endif
#ifdef TOOL_INCLUDE_DIR
    /* Another place the target system's headers might be.  */
    { TOOL_INCLUDE_DIR, "BINUTILS", 0, 1, 0, 0 },
#endif
#ifdef NATIVE_SYSTEM_HEADER_DIR
    /* /usr/include comes dead last.  */
    { NATIVE_SYSTEM_HEADER_DIR, NATIVE_SYSTEM_HEADER_COMPONENT, 0, 0, 1, 2 },
    { NATIVE_SYSTEM_HEADER_DIR, NATIVE_SYSTEM_HEADER_COMPONENT, 0, 0, 1, 0 },
#endif
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
