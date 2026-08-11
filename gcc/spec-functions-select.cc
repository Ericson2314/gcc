/* Which back end's driver spec functions are in force.
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

/* THE TABLE IS KEYED BY TARGET, AND THAT IS THE WHOLE POINT.

   The obvious implementation is one flat name->function table holding every
   back end's entries, and it is wrong here in the specific way this compiler
   exists to prevent.  `local_cpu_detect' is published by NINE back ends --
   i386, rs6000, aarch64, mips, alpha and sparc (three headers) all bind it to
   a function spelled `host_detect_local_cpu', and s390 binds it to
   `s390_host_detect_local_cpu'.  In a flat table the first match wins, so
   whichever back end happened to be listed first would answer `-march=native'
   for every target: one name, several targets, no diagnostic, and a wrong
   -march rather than a link error.

   So the registry maps TARGET -> that target's own table, and a lookup
   consults only the table of the target in force.  Cross-back-end collisions
   are then not merely detected, they are unrepresentable -- which is cheaper
   and stronger than any checker over a flat table would have been.

   A note on why the nine-way collision cannot actually fire today, because it
   changes what the must-miss is testing.  Every one of those definitions sits
   behind a gate on the HOST compiler's own predefined macros --
   `#if defined(__i386__) || defined(__x86_64__)' in i386.h,
   `#if defined(__aarch64__)' in aarch64.h -- because -march=native asks what
   machine the driver is RUNNING on, not what it is compiling for.  config.host
   links driver-<cpu>.o only when host and target agree.  So in any one build at
   most one back end publishes `local_cpu_detect' at all, and on this x86_64
   host that is i386.  The aarch64 table really is empty of it, and a lookup
   that returned i386's function for an aarch64 compilation would be reporting
   the host's CPU as the target's -- silently, and only on the targets nobody
   builds natively.  That is the must-miss.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "gcc.h"

/* The table for a target whose back end has no tm-<base>.h of its own -- the
   group that shares default-common.cc.  A real, empty table rather than a null
   entry: see the registry header's comment.  None of the sixteen headers that
   define EXTRA_SPEC_FUNCTIONS is in that group, so nothing is being dropped
   here; if one ever joins it, that back end needs a tm-<base>.h before it
   needs anything in this file.  */
static const struct spec_function spec_functions_empty[] = { { NULL, NULL } };

/* Declares every configured back end's table and defines
   SPEC_FUNCTIONS_TABLES listing them, one entry per configured TARGET (several
   targets of one back end share a table).  Written by configure from the target
   list, exactly as multi-target-common.h is.  */
#include "multi-target-spec-functions.h"

/* Naming every table here is not merely descriptive: these objects are linked
   from an archive, and an archive member nothing refers to is not pulled in at
   all.  Without this table only whichever one something else happened to
   mention would reach the driver.  The same note is on the two registries this
   copies, and it is load-bearing on all three.  */
#define SPEC_FUNCTIONS_ENTRY(NAME, SYM) { NAME, SYM },
static const struct spec_functions_entry spec_functions_registry[] = {
  SPEC_FUNCTIONS_TABLES
  { NULL, NULL }
};
#undef SPEC_FUNCTIONS_ENTRY

/* The table in force.  NULL, not any target's, until something selects one --
   the same rule common/common-target-select.cc arrived at the hard way.  A
   driver that has selected nothing must not answer as the build's own triple,
   because that is the bug that behaves correctly on the machine you test on
   and wrongly everywhere else.  NULL here means `unknown spec function', which
   is a diagnostic naming the function, and that is the right answer for a
   driver that does not know its target.  */
static const struct spec_function *selected_spec_functions = NULL;

/* Select by target triple.  Returns false and changes nothing if TARGET was
   not configured, so a caller can report it rather than silently resolving
   spec functions against another machine's table.  Deliberately no fallback:
   an unrecognised target leaves NULL in force.  */

bool
spec_functions_select (const char *target)
{
  for (const struct spec_functions_entry *e = spec_functions_registry;
       e->target != NULL; e++)
    if (strcmp (e->target, target) == 0)
      {
	selected_spec_functions = e->table;
	return true;
      }
  return false;
}

/* Look NAME up in the selected target's table.  Returns NULL when no target
   has been selected, when this target publishes no spec functions, or when it
   publishes none by this name -- three different situations that all mean the
   same thing to the caller, which is that gcc.cc should carry on and then
   report `unknown spec function'.  */

const struct spec_function *
lookup_target_spec_function (const char *name)
{
  if (selected_spec_functions == NULL)
    return NULL;

  for (const struct spec_function *sf = selected_spec_functions;
       sf->name != NULL; sf++)
    if (strcmp (sf->name, name) == 0)
      return sf;

  return NULL;
}
