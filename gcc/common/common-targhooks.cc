/* Default common target hook functions.
   Copyright (C) 2003-2026 Free Software Foundation, Inc.

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

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "target-caps.h"
#include "common/common-target.h"
#include "common/common-targhooks.h"
#include "opts.h"
#include "diagnostic-core.h"	/* fatal_error, for the unselected-target case */

/* The selected back end's `DWARF2_UNWIND_INFO'; see common-targhooks.h for
   why it is a pointer rather than a call and why null must be fatal.  */
int (*mt_dwarf2_unwind_info_hook) (void);

/* Determine the exception handling mechanism for the target.  */

enum unwind_info_type
default_except_unwind_info (struct gcc_options *opts ATTRIBUTE_UNUSED)
{
  /* Obey the former --enable-sjlj-exceptions configure switch, now a
     per-target capability.  Only a positive answer forces; -1 (not
     configured) and 0 (configured `=no') fall through, exactly as an
     undefined CONFIG_SJLJ_EXCEPTIONS did.  */
  if (targ_caps.sjlj_exceptions > 0)
    return UI_SJLJ;

  /* Upstream this is

	 #ifdef DWARF2_UNWIND_INFO
	   if (DWARF2_UNWIND_INFO)
	     return UI_DWARF2;
	 #endif

     and it is THE CAUSE OF #208.  This file has no `tm.h' (`953cf9eda76'
     removed it), so the `#ifdef' was silently FALSE and every back end
     without a `TARGET_EXCEPT_UNWIND_INFO' of its own -- aarch64 among them --
     fell through to UI_SJLJ.  Two symptoms, one predicate: `dwarf2cfi.cc:3723'
     stopped emitting ANY CFI, and `opts.cc:1564' silently turned off
     `-freorder-blocks-and-partition'.  Restoring the include is not the fix:
     the macro would then be i386's for all 47 back ends, which is the leak
     this project exists to remove and which merely happened to give aarch64
     the right answer.

     The answer now comes from the SELECTED base's own translation unit.  A
     null hook is fatal rather than defaulting, because "nobody installed an
     answer" and "this target has no DWARF unwind" are different facts and
     letting them share the UI_SJLJ return is what made this invisible for a
     day.  */
  if (mt_dwarf2_unwind_info_hook == NULL)
    fatal_error (UNKNOWN_LOCATION,
		 "the exception-unwinding method was asked for before any "
		 "back end was selected, so it is not known whether this "
		 "target has DWARF 2 frame unwind; a target must be chosen "
		 "with %<-ftarget-config=%> first");

  if (mt_dwarf2_unwind_info_hook ())
    return UI_DWARF2;

  return UI_SJLJ;
}

/* To be used by targets that force dwarf2 unwind enabled.  */

enum unwind_info_type
dwarf2_except_unwind_info (struct gcc_options *opts ATTRIBUTE_UNUSED)
{
  /* Obey the former --enable-sjlj-exceptions configure switch, now a
     per-target capability.  Only a positive answer forces; -1 (not
     configured) and 0 (configured `=no') fall through, exactly as an
     undefined CONFIG_SJLJ_EXCEPTIONS did.  */
  if (targ_caps.sjlj_exceptions > 0)
    return UI_SJLJ;

  return UI_DWARF2;
}

/* To be used by targets that force sjlj unwind enabled.  */

enum unwind_info_type
sjlj_except_unwind_info (struct gcc_options *opts ATTRIBUTE_UNUSED)
{
  return UI_SJLJ;
}

/* Default version of TARGET_HANDLE_OPTION.  */

bool
default_target_handle_option (struct gcc_options *opts ATTRIBUTE_UNUSED,
			      struct gcc_options *opts_set ATTRIBUTE_UNUSED,
			      const struct cl_decoded_option *decoded ATTRIBUTE_UNUSED,
			      location_t loc ATTRIBUTE_UNUSED)
{
  return true;
}

/* Default version of TARGET_GET_VALID_OPTION_VALUES.  */

vec<const char *>
default_get_valid_option_values (int, const char *)
{
  return vec<const char *> ();
}

const struct default_options empty_optimization_table[] =
  {
    { OPT_LEVELS_NONE, 0, NULL, 0 }
  };

/* Default version of TARGET_COMPUTE_MULTILIB.  */
const char *
default_compute_multilib(
  const struct switchstr *,
  int,
  const char *multilib,
  const char *,
  const char *,
  const char *,
  const char *,
  const char *)
{
  return multilib;
}
