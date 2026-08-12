/* One back end's per-configuration target data.
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

/* Compiled once per back end, with `-I<base>-inc' so every header it reaches
   is that back end's, and with -DTARGETM_CDATA_SYMBOL naming its refresh
   function.  See target-cdata.h for what this is and for the invariance
   precondition on every field.

   THIS FILE IS ON THE SUPPLY SIDE OF THE REDIRECTION, so it must see the REAL
   macros rather than the redirected ones.  It does, and not by accident:
   defaults.h's redirection block is guarded on MULTI_TARGET_TARGETM_BASE,
   which the build defines for exactly the objects compiled for a particular
   back end -- this one included, because it is in MULTI_TARGET_OBJS_<base>.
   If that guard were ever lost, this file would assign each field from itself
   and every value would be the poison, which is loud rather than silent.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
/* Some of these macros are not self-contained arithmetic on option variables:
   aarch64's `DWARF_FRAME_RETURN_COLUMN' is `DWARF_FRAME_REGNUM (LR_REGNUM)',
   which calls `aarch64_debugger_regno ()'.  tm_p.h is this base's own
   <cpu>-protos.h, so the declarations come from the same back end the macros
   do.  (`rtl.h' is needed before it, exactly as target-addr.cc has it.)

   Note what this does NOT license.  A macro that needs a declaration is fine;
   a macro that needs per-function STATE is not, however easy the include
   makes it to compile -- see the `SUPPORTS_STACK_ALIGNMENT' and
   `PIC_OFFSET_TABLE_REGNUM' notes in target-cdata.h.  This file runs once,
   with `cfun' null.  */
#include "rtl.h"
#include "tm_p.h"
#include "target-cdata.h"

#ifndef MULTI_TARGET_TARGETM_BASE
/* No apostrophe in the message below: cpp lexes the text of a skipped
   conditional group, so one would warn "missing terminating ' character"
   on every compilation that defines MULTI_TARGET_TARGETM_BASE -- i.e. on
   every good build.  */
#error target-cdata.cc must be compiled for a particular back end (it needs \
the real tm.h macros of that base, not the redirected ones)
#endif

/* Every field, from the one list in target-cdata.h.  Written this way rather
   than as a run of assignments so that a field cannot be added to the struct
   and forgotten here -- which would leave it holding the poison in a build
   that otherwise looks complete.  */
void
TARGETM_CDATA_SYMBOL (struct target_cdata *d)
{
#define TARGET_CDATA_STR(F, M) d->F = (M);
#define TARGET_CDATA_NUM(T, F, M) d->F = (T) (M);
  TARGET_CDATA_FIELDS (TARGET_CDATA_STR, TARGET_CDATA_NUM)
#undef TARGET_CDATA_STR
#undef TARGET_CDATA_NUM
}
