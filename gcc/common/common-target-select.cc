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
   this file holds the registry of all of them plus the one that is in force.

   BEFORE SELECTION THE TABLE IN FORCE IS EMPTY, NOT PRIVILEGED.  This file
   used to start `targetm_common' at the address of TARGETM_COMMON_SYMBOL --
   the table of whichever target the build itself was configured for -- so a
   compiler that had selected nothing quietly answered as that one target.
   Two things were wrong with that.  It is the thing this whole exercise
   removes: a missed target dependency behaves correctly on the build's own
   triple and wrongly everywhere else, which is precisely the bug class that
   cannot be found by testing.  And it made the SELECTOR depend on a symbol
   only the build triple's back end defines, so `--enable-backends=LIST' that
   did not name the build's own triple failed to link -- `undefined reference
   to targetm_common_i386_common' -- for a target nobody had asked for.

   So the initial table is `targetm_common_none' below: every function hook
   reports, by name, that it was used before a target was selected.  There is
   no fallback to a default target, deliberately; see targetm_common_select.

   The pointer is still initialised with the ADDRESS of a global, which is a
   constant expression: no dynamic initialisation, so no ordering question
   between translation units.  Holding a struct here instead and copying into
   it would be dynamically initialised, and anything that ran before the copy
   would read zeroed hooks -- a silent null call rather than a diagnostic.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "diagnostic-core.h"
#include "common/common-target.h"
#include "common/common-targhooks.h"

/* Declares every configured target's table and defines TARGETM_COMMON_TABLES
   listing them.  Written by configure from the target list.  */
#include "multi-target-common.h"

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

/* THE EMPTY BACK END.

   Generated from common-target.def rather than written out, so that a hook
   added to the .def cannot silently arrive here as a value-initialised null
   pointer -- which would be a segfault at the point of use rather than a
   diagnostic naming the hook, i.e. exactly the failure mode this table exists
   to replace.  A hand-written initializer goes stale without a compile error;
   this one cannot.

   Function hooks become stubs that report themselves by name.  Data hooks
   cannot report anything -- reading a POD is not a call -- so they take the
   .def's own INIT, which is the value target-independent code is written
   against.  That asymmetry is real and worth stating: an unselected compiler
   fails loudly the moment it CALLS a common hook, and answers "nothing
   special" if it merely READS one.  The data hooks here are few and are all
   consulted after option decoding, by which time selection has happened or a
   function hook has already fired.  */

/* Reported with fprintf rather than internal_error, and that is not laziness.
   The driver reaches its first common hook inside driver::decode_argv, which
   runs BEFORE driver::global_initializations calls diagnostic_initialize --
   so internal_error there segfaults inside diagnostic_impl and prints no
   message at all, only a backtrace.  A control that dies silently is not a
   loud failure; this one says the same thing in every binary at every stage,
   which is worth more than the backtrace it gives up.  */

static ATTRIBUTE_NORETURN void
no_common_target_selected (const char *hook)
{
  fprintf (stderr,
	   "%s: fatal error: common target hook `%s' was used before a target "
	   "was selected\n"
	   "no target has been installed: nothing called "
	   "targetm_common_select, so the table in force is the empty back "
	   "end.  A target is named by the `target' line of the file passed "
	   "as -ftarget-config=; a compiler given none has no target and "
	   "deliberately has no default.\n",
	   progname != NULL ? progname : "gcc", hook);
  exit (FATAL_EXIT_CODE);
}

#undef HOOKSTRUCT
#undef DEFHOOK
#undef DEFHOOK_UNDOC
#undef DEFHOOKPOD
#define HOOKSTRUCT(FRAGMENT)
#define DEFHOOKPOD(NAME, DOC, TYPE, INIT)
#define DEFHOOK(NAME, DOC, TYPE, PARAMS, INIT)		\
  static TYPE gcc_no_common_target_ ## NAME PARAMS	\
  {							\
    no_common_target_selected (#NAME);			\
  }
#define DEFHOOK_UNDOC DEFHOOK
#include "common/common-target.def"

#undef HOOKSTRUCT
#undef DEFHOOK
#undef DEFHOOK_UNDOC
#undef DEFHOOKPOD
#define HOOKSTRUCT(FRAGMENT)
#define DEFHOOKPOD(NAME, DOC, TYPE, INIT) INIT,
#define DEFHOOK(NAME, DOC, TYPE, PARAMS, INIT) gcc_no_common_target_ ## NAME,
#define DEFHOOK_UNDOC DEFHOOK
static struct gcc_targetm_common targetm_common_none =
{
#include "common/common-target.def"
};

#undef HOOKSTRUCT
#undef DEFHOOK
#undef DEFHOOK_UNDOC
#undef DEFHOOKPOD

/* The table in force.  Constant-initialised -- the address of a global is a
   constant expression -- so it is valid before anything runs, and it names the
   empty back end rather than any configured target's.  */
struct gcc_targetm_common *targetm_common = &targetm_common_none;

/* Select by target triple.  Returns false and changes nothing if TARGET was not
   configured, so a caller can report it rather than silently compiling for the
   wrong machine.  In particular it does NOT fall back on any table: an
   unrecognised target leaves the empty back end in force, so a caller that
   ignores the result gets a diagnostic at the first hook use instead of code
   for whatever machine happened to be first.  */
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
