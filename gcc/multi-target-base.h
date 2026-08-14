/* Naming a back end's own headers at the point of inclusion.
   Copyright (C) 2025 Free Software Foundation, Inc.

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


/* Naming a back end's own headers at the point of inclusion.

   Each configured back end gets a `<base>-inc/' directory holding its own
   tm.h, tm_p.h, tm-preds.h, tm-constrs.h and generated insn-*.h.  A source
   compiled once per back end reaches them by naming the base:

       #include BASE_HEADER (tm.h)         -> "i386-inc/tm.h"

   The base is `-DMT_BASE=<cpu>-inc', set per object by the rules in
   multi-target-md.mk.  One `-D' serves every header.

   State, and what this does not cover: scratchpad/T173-BASE-HEADER.md.  */

#ifndef GCC_MULTI_TARGET_BASE_H
#define GCC_MULTI_TARGET_BASE_H

#ifndef MT_BASE
#error "MT_BASE is not defined: this source is compiled once per back end and \
must be given -DMT_BASE=<cpu>-inc.  See gcc/multi-target-base.h."
#endif

/* MT_HDR_STR and MT_HDR_XSTR, and the double indirection they exist for.  */
#include "multi-target-header.h"

/* This back end's copy of the header F.  F is UNQUOTED: BASE_HEADER (tm.h).

   ARM 6 of scratchpad/t140-inject.sh reads the expansion and fails if it does
   not contain the base name.

   The `-D' is MT_BASE: `BASE' is a template parameter in
   config/aarch64/aarch64-sve-builtins-shapes.cc and a macro parameter in two
   more files, and `-DBASE=aarch64-inc' fails with `expected
   nested-name-specifier before aarch64', naming neither the flag nor a
   file.  */
#define BASE_HEADER(f) MT_HDR_XSTR (MT_BASE/f)

/* THE WITNESS.  Two `-D's on this object's command line say which back end it
   is compiled for, and this makes them check each other:

       -DMT_BASE=<cpu>-inc                which headers it reads
       -DMULTI_TARGET_TARGETM_BASE=<cpu>  whose hook table it binds to,
					  paired with the -Dtargetm= renames

   The tag header is generated into ONE base's directory, so building the path
   from MT_BASE and the file name from MULTI_TARGET_TARGETM_BASE fails by name
   whenever they disagree:

       MT_BASE wrong	  fatal: aarch64-inc/mt-inc-tag-i386.h: No such file
       MT_BASE undefined  fatal: MT_BASE/tm.h: No such file

   Both operands are expanded because MT_HDR_XSTR's parameter is not adjacent
   to the `#'.

   Objects carrying MT_BASE alone -- mt-<cpu>/reg-probe.o, the mtd-<cpu>
   driver objects and mt-<cpu>/options-{init,tables}.o, which cannot carry
   MULTI_TARGET_TARGETM_BASE because target.h requires it to be paired with
   -Dtargetm= -- have no second statement of their base to check against, and
   this arm is silent for them.  */
#ifdef MULTI_TARGET_TARGETM_BASE
#include MT_HDR_XSTR (MT_BASE/mt-inc-tag-MULTI_TARGET_TARGETM_BASE.h)
#endif

#endif /* GCC_MULTI_TARGET_BASE_H */
