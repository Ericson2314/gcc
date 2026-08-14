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

/* This back end's copy of the header F.  F is UNQUOTED: BASE_HEADER (tm.h).

   The double indirection is load-bearing.  `#' suppresses expansion of its
   operand, so MT_HDR_STR alone stringifies the spelling and yields the
   literal "MT_BASE/tm.h".  MT_HDR_XSTR forces one round of expansion first,
   so MT_BASE becomes `i386-inc' before the `#' sees it.  ARM 6 of
   scratchpad/t140-inject.sh reads the expansion and fails if it does not
   contain the base name.

   The helpers are MT_HDR_STR/MT_HDR_XSTR because XSTR is rtl.h's accessor and
   MT_STR is defined differently in target-cumargs.cc and target-regs.cc.

   The `-D' is MT_BASE: `BASE' is a template parameter in
   config/aarch64/aarch64-sve-builtins-shapes.cc and a macro parameter in two
   more files, and `-DBASE=aarch64-inc' fails with `expected
   nested-name-specifier before aarch64', naming neither the flag nor a
   file.  */
#define MT_HDR_STR(f) #f
#define MT_HDR_XSTR(f) MT_HDR_STR (f)
#define BASE_HEADER(f) MT_HDR_XSTR (MT_BASE/f)

/* THE WITNESS.  A header a per-back-end object reaches only through the
   include path, naming its own base's tag through BASE_HEADER, so the two
   flags that say which back end this object is compiled for must agree:

       mt-inc-witness.h	     #include BASE_HEADER (mt-inc-tag-<that base>.h)
       mt-inc-tag-<base>.h   the tag it names, and the ONLY base whose
			     directory holds it

   giving, always by name:

       include path missing   fatal: mt-inc-witness.h: No such file
       include path wrong	    fatal: i386-inc/mt-inc-tag-aarch64.h: No such file
       MT_BASE wrong	    fatal: aarch64-inc/mt-inc-tag-i386.h: No such file
       MT_BASE undefined	    fatal: MT_BASE/tm.h: No such file

   Spelled by its plain name: BASE_HEADER (mt-inc-witness.h) would resolve
   through `-I.' and the first arm would test nothing.  */
#include "mt-inc-witness.h"

#endif /* GCC_MULTI_TARGET_BASE_H */
