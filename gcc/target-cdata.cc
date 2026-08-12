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
#include "target-cdata.h"

#ifndef MULTI_TARGET_TARGETM_BASE
#error target-cdata.cc must be compiled for a particular back end (it needs \
that base's real tm.h macros, not the redirected ones)
#endif

void
TARGETM_CDATA_SYMBOL (struct target_cdata *d)
{
  d->asm_comment_start = ASM_COMMENT_START;
  d->wchar_type        = WCHAR_TYPE;
  d->size_type         = SIZE_TYPE;
  d->ptrdiff_type      = PTRDIFF_TYPE;
}
