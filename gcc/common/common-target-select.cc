/* Selection of the common target hook table in force.
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

/* Every common/config/<cpu>/<cpu>-common.cc used to define its hook table as
   `targetm_common', so no two of them could be linked into one compiler.  Each
   now defines it under a name of its own, given by TARGETM_COMMON_SYMBOL, and
   this file names the one that is in force.

   The pointer is initialised with the address of that table, which is a
   constant expression: no dynamic initialisation, so no ordering question
   between translation units.  Holding a struct here instead and copying into
   it would be dynamically initialised, and anything that ran before the copy
   would read zeroed hooks -- a null call rather than a link failure.

   Note this file is compiled with the same -DTARGETM_COMMON_SYMBOL as the
   target's own common file.  If that ever went missing the default in
   common-target.h names a table nothing defines, so it fails at link time
   rather than silently selecting the wrong target.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "common/common-target.h"

/* Declares every configured target's table and defines TARGETM_COMMON_TABLES
   listing them.  Written by configure from the target list.  */
#include "multi-target-common.h"

extern struct gcc_targetm_common TARGETM_COMMON_SYMBOL;

/* Naming every table here is not merely descriptive: these objects are linked
   from an archive, and an archive member nothing refers to is not pulled in at
   all.  Without this table only the table named by TARGETM_COMMON_SYMBOL would
   reach the compiler, however many were compiled.  */
#define TARGETM_COMMON_ENTRY(NAME, SYM) { NAME, &SYM },
const struct targetm_common_entry targetm_common_registry[] = {
  TARGETM_COMMON_TABLES
  { NULL, NULL }
};
#undef TARGETM_COMMON_ENTRY

/* The table in force.  Constant-initialised -- see common-target.h -- so it is
   valid before anything runs.

   FIXME: this makes the target named by --target the one in effect until
   something selects another, which is the sort of privileged default that lets
   a missed target dependency go unnoticed.  It stands only until selection
   happens early enough that no user of targetm_common runs before it.  */
struct gcc_targetm_common *targetm_common = &TARGETM_COMMON_SYMBOL;

/* Select by target triple.  Returns false and changes nothing if TARGET was not
   configured, so a caller can report it rather than silently compiling for the
   wrong machine.  */
bool
targetm_common_select (const char *target)
{
  for (const struct targetm_common_entry *e = targetm_common_registry;
       e->target != NULL; e++)
    if (strcmp (e->target, target) == 0)
      {
	targetm_common = e->table;
	return true;
      }
  return false;
}
