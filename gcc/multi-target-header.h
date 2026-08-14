/* Naming a back end's own headers from a SHARED header.
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


/* MT_HEADER (f) names the copy of F belonging to whatever this object is
   being compiled for:

       #include MT_HEADER (insn-codes.h)

   In a translation unit compiled per back end (-DMT_BASE=<cpu>-inc) that is
   "<cpu>-inc/insn-codes.h".  In a translation unit compiled once it is
   "insn-codes.h", the build root's copy, which is that translation unit's
   own answer.

   This is the form for a header that serves BOTH, which every shared header
   under gcc/ does: it is read once as part of a shared object and again,
   textually, inside each back end's own objects.  A source compiled only per
   back end uses BASE_HEADER from multi-target-base.h instead, which requires
   MT_BASE and #errors by name without it.

   Both spellings name the base at the point of inclusion, so neither depends
   on the include path to pick a back end.  */

#ifndef GCC_MULTI_TARGET_HEADER_H
#define GCC_MULTI_TARGET_HEADER_H

/* `#' suppresses expansion of its operand, so MT_HDR_STR alone stringifies
   the spelling and yields the literal "MT_BASE/tm.h".  MT_HDR_XSTR forces one
   round of expansion first, so MT_BASE becomes `i386-inc' before the `#' sees
   it.

   The helpers are MT_HDR_STR/MT_HDR_XSTR because XSTR is rtl.h's accessor and
   MT_STR is defined differently in target-cumargs.cc and target-regs.cc.  */
#define MT_HDR_STR(f) #f
#define MT_HDR_XSTR(f) MT_HDR_STR (f)

#ifdef MT_BASE
#define MT_HEADER(f) MT_HDR_XSTR (MT_BASE/f)
#else
#define MT_HEADER(f) MT_HDR_STR (f)
#endif

#endif /* GCC_MULTI_TARGET_HEADER_H */
