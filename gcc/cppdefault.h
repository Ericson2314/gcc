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

#ifndef GCC_CPPDEFAULT_H
#define GCC_CPPDEFAULT_H

/* This is the default list of directories to search for include files.
   It may be overridden by the various -I and -ixxx options.

   #include "file" looks in the same directory as the current file,
   then this list.
   #include <file> just looks in this list.

   All these directories are treated as `system' include directories
   (they are not subject to pedantic warnings in some cases).  */

/* NOT `const'-qualified member by member, although it used to be.  The G++,
   libc++, site-local and system header directories are per-target and now
   arrive at run time in
   targ_caps, so cppdefault.cc builds this table on first use and compacts out
   the entries the target config left empty.  The table it hands back is
   const-qualified as a whole, which is the guarantee callers actually want.  */
struct default_include
{
  const char *fname;		/* The name of the directory.  */
  const char *component;	/* The component containing the directory
				   (see update_path in prefix.cc) */
  char cplusplus;		/* When this is non-zero, we should only
				   consider this if we're compiling C++.
				   When the -stdlib option is configured, this
				   may take values greater than 1 to indicate
				   which C++ standard library should be
				   used.  */
  char cxx_aware;		/* Includes in this directory don't need to
				   be wrapped in extern "C" when compiling
				   C++.  */
  char add_sysroot;		/* FNAME should be prefixed by
				   cpp_SYSROOT.  */
  char multilib;		/* FNAME should have appended
				   - the multilib path specified with -imultilib
				     when set to 1,
				   - the multiarch path specified with
				     -imultiarch, when set to 2.  */
};

/* The standard include chain.  A FUNCTION rather than an array because several
   of its entries -- the libstdc++ and libc++ header directories,
   /usr/local/include and /usr/include -- are answers about the INSTALLATION
   this compiler is compiling against, and reach cc1
   in the per-target config file (targ_caps).  A namespace-scope array would be
   initialised before read_target_caps ever runs and would silently capture the
   built-in fallbacks instead; building on first use puts construction after
   the config file is read.  Every caller already writes
   `for (p = cpp_include_defaults; p->fname; p++)', so the macro keeps them
   working unchanged and, more to the point, makes it impossible to reach the
   table without going through the initialisation.  */
extern const struct default_include *cpp_include_defaults_table (void);
#define cpp_include_defaults (cpp_include_defaults_table ())
extern const char cpp_GCC_INCLUDE_DIR[];
extern const size_t cpp_GCC_INCLUDE_DIR_len;

/* The configure-time prefix, i.e., the value supplied as the argument
   to --prefix=.  */
extern const char cpp_PREFIX[];
/* The length of the configure-time prefix.  */
extern const size_t cpp_PREFIX_len;
/* The configure-time execution prefix.  This is typically the lib/gcc
   subdirectory of cpp_PREFIX.  */
extern const char cpp_EXEC_PREFIX[];
/* The run-time execution prefix.  This is typically the lib/gcc
   subdirectory of the actual installation.  */
extern const char *gcc_exec_prefix;

/* Return true if the toolchain is relocated.  */
bool cpp_relocated (void);

#endif /* ! GCC_CPPDEFAULT_H */
