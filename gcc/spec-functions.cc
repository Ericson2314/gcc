/* One back end's table of driver spec functions.
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

/* Compiled once per back end, exactly like target-asm-ops.cc: TM_H_FILE names
   that back end's tm-<base>.h and SPEC_FUNCTIONS_SYMBOL the name its table
   takes, so that all of them can be linked into one driver.  See
   spec-functions-select.cc for the registry and why this is keyed by target.

   WHAT WENT WRONG WITHOUT THIS.  `gcc.cc' used to end static_spec_functions[]
   with

       #ifdef EXTRA_SPEC_FUNCTIONS
	 EXTRA_SPEC_FUNCTIONS
       #endif

   and gcc.cc no longer includes tm.h, so that guard became permanently false
   and every back end's spec functions vanished from the driver -- while
   `gen-target-specs' went on emitting the spec TEXT that calls them, because
   it does expand the target headers.  One header, two halves, only one of them
   carried: i386.h:686 supplies `%:local_cpu_detect(arch ...)' and i386.h:648
   supplies the { name, function } entry that makes it resolvable.  The result
   was `fatal error: unknown spec function 'local_cpu_detect'' for every
   -march=native and -mtune=native compilation, found by the C++ census as
   g++.dg/pr90773-1d.C.

   The code was never missing: driver-i386.o arrives through extra_gcc_objs and
   `nm' finds host_detect_local_cpu in the driver.  Only the name that reaches
   it was gone -- so this is a registry, not a port.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"

#ifndef TM_H_FILE
#define TM_H_FILE "tm.h"
#endif
#include TM_H_FILE

#include "gcc.h"

/* `extern' is not redundant: a namespace-scope `const' object has internal
   linkage in C++, so without it the table would be built correctly and then be
   unnameable from the registry -- the same trap target-asm-ops.cc documents.

   `constexpr' is deliberate for the same reason it is there.  Every entry is a
   string literal and the address of a function, so a well-formed table is a
   constant expression; anything a back end writes here that is NOT one would
   otherwise be emitted as a static constructor running before the driver has
   decoded a single option, and would be silently wrong rather than rejected.

   NOT gated on `#ifdef EXTRA_SPEC_FUNCTIONS' being true: a back end that
   defines none gets a table holding only the terminator, which is a real
   answer ("this target publishes no spec functions") and is what makes the
   must-miss below meaningful.  An absent table and an empty one must not be
   the same thing, or "no entry for this target" and "no such function on this
   target" become indistinguishable -- and the whole defect above was one of
   those two masquerading as the other.  */
extern const struct spec_function SPEC_FUNCTIONS_SYMBOL[];
constexpr struct spec_function SPEC_FUNCTIONS_SYMBOL[] =
{
#ifdef EXTRA_SPEC_FUNCTIONS
  EXTRA_SPEC_FUNCTIONS
#endif
  { NULL, NULL }
};
