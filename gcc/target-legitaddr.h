/* The per-base name of this back end's strict GO_IF_LEGITIMATE_ADDRESS thunk.
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

/* Read by exactly two translation units, and its whole job is that they spell
   one name the same way: `target-legitaddr-strict.cc' DEFINES the function and
   `target-cumargs.cc' DECLARES it and puts its address in this base's
   `target_frame_desc'.  Both are compiled with the same
   `-DMULTI_TARGET_TARGETM_BASE=<cpu>', so the name is derived from one
   authority rather than agreed between two.

   Why a separate translation unit is needed at all -- `REG_OK_STRICT' selects
   between two whole macro bodies at header-read time, so one TU can hold only
   one of them -- is argued at length in `target-legitaddr-strict.cc'.

   The double indirection is the usual one: `MT_LA_CAT2's parameters are
   adjacent to `##' and so are NOT macro-expanded, and `MT_LA_CAT' exists
   solely to force one expansion of `MULTI_TARGET_TARGETM_BASE' first.  Without
   it the symbol would be the literal
   `mt_base_go_if_legitimate_address_strict_MULTI_TARGET_TARGETM_BASE' -- one
   name for all 47 bases, a multiply-defined symbol at link time if we are
   lucky and a silently shared body if we are not.  Same mechanism, same
   reason, as `BASE_HEADER' in multi-target-base.h.  */

#ifndef GCC_TARGET_LEGITADDR_H
#define GCC_TARGET_LEGITADDR_H

#define MT_LA_CAT2(a, b) a ## b
#define MT_LA_CAT(a, b) MT_LA_CAT2 (a, b)

#define MT_LEGITADDR_STRICT_FN \
  MT_LA_CAT (mt_base_go_if_legitimate_address_strict_, \
	     MULTI_TARGET_TARGETM_BASE)

#endif /* GCC_TARGET_LEGITADDR_H */
