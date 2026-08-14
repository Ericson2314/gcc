/* The supply side of the OPTIONAL per-configuration scalars.
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

/* WHY THIS FILE EXISTS AT ALL, AND WHY THE `#ifdef's HERE ARE NOT THE BUG.

   `target-cdata.h' keeps ONE list of the optional fields, and the struct, the
   refresh function, the poisoned initialiser and the post-refresh check are
   all generated from it -- so a field cannot be added in one place and
   forgotten in another.  The refresh function has to ask "does this back end
   define this macro at all", and that question is `#ifdef', which cannot be
   written inside a list-driven macro expansion: the preprocessor will not
   evaluate a directive that an expansion produced.

   So the per-macro `#ifdef' has to be written out once, somewhere.  Here is
   the right somewhere, for the same reason `target-cumargs.cc' was the right
   place for `INIT_EXPANDERS': THIS HEADER IS ONLY EVER REACHED FROM
   `target-cdata.cc', which is compiled ONCE PER BACK END.
   Every `#ifdef' below is therefore answered by THE BACK END THE ANSWER IS
   FOR, which is correct by construction -- it is the exact opposite of the
   `#ifdef' in shared code that this conversion removes, where one base
   answered for all of them.

   The pattern is deliberately mechanical.  For each optional macro M:

     MT_HAS_M   1 or 0     -- does this back end define M
     MT_VAL_M   expression -- M when it has it, 0 when it does not

   `MT_VAL_M' must expand to something harmless in the absent case, because
   the refresh evaluates the ternary in both arms textually even though only
   one is live.

   A FIELD IN THE LIST WITH NO ENTRY HERE FAILS TO COMPILE, BY NAME.  The
   refresh pastes `MT_HAS_' onto the macro name, so a missing pair is
   `MT_HAS_WHATEVER was not declared in this scope' naming the macro -- not a
   silent zero, which would report every back end as having no answer and
   would look exactly like a correct build of a target with no such macro.  */

#ifndef GCC_TARGET_CDATA_OPT_H
#define GCC_TARGET_CDATA_OPT_H

#ifndef MULTI_TARGET_TARGETM_BASE
/* No apostrophe in the message: cpp lexes the text of a skipped conditional
   group, so one would warn about a missing terminating quote on every good
   build.  Same trap, same wording discipline, as target-cdata.cc.  */
#error target-cdata-opt.h is the SUPPLY side and must be compiled for a \
particular back end; reached from shared code it would ask the primary \
whether every other target has a macro
#endif

/* STATIC_CHAIN_REGNUM -- 45 of 48 back ends.  targhooks.cc's
   `default_static_chain' returned nothing at all without it, falling through
   to `sorry ("nested functions not supported on this target")' for every
   target because i386 has no such macro.  */
#ifdef STATIC_CHAIN_REGNUM
# define MT_HAS_STATIC_CHAIN_REGNUM 1
# define MT_VAL_STATIC_CHAIN_REGNUM (STATIC_CHAIN_REGNUM)
#else
# define MT_HAS_STATIC_CHAIN_REGNUM 0
# define MT_VAL_STATIC_CHAIN_REGNUM 0
#endif

/* STATIC_CHAIN_INCOMING_REGNUM -- the same function, the incoming half.  It
   is here rather than left behind because leaving it would put one arm of
   `default_static_chain' on the run-time answer and the other on the
   primary's `#ifdef'.  */
#ifdef STATIC_CHAIN_INCOMING_REGNUM
# define MT_HAS_STATIC_CHAIN_INCOMING_REGNUM 1
# define MT_VAL_STATIC_CHAIN_INCOMING_REGNUM (STATIC_CHAIN_INCOMING_REGNUM)
#else
# define MT_HAS_STATIC_CHAIN_INCOMING_REGNUM 0
# define MT_VAL_STATIC_CHAIN_INCOMING_REGNUM 0
#endif

/* EMPTY_FIELD_BOUNDARY -- 32 back ends.  aarch64 says 32; i386 has none, so
   stor-layout.cc never aligned a zero-width bitfield for anybody.  */
#ifdef EMPTY_FIELD_BOUNDARY
# define MT_HAS_EMPTY_FIELD_BOUNDARY 1
# define MT_VAL_EMPTY_FIELD_BOUNDARY (EMPTY_FIELD_BOUNDARY)
#else
# define MT_HAS_EMPTY_FIELD_BOUNDARY 0
# define MT_VAL_EMPTY_FIELD_BOUNDARY 0
#endif

/* STRUCTURE_SIZE_BOUNDARY -- 24 back ends.  aarch64 says 8.  */
#ifdef STRUCTURE_SIZE_BOUNDARY
# define MT_HAS_STRUCTURE_SIZE_BOUNDARY 1
# define MT_VAL_STRUCTURE_SIZE_BOUNDARY (STRUCTURE_SIZE_BOUNDARY)
#else
# define MT_HAS_STRUCTURE_SIZE_BOUNDARY 0
# define MT_VAL_STRUCTURE_SIZE_BOUNDARY 0
#endif

/* DWARF_ALT_FRAME_RETURN_COLUMN -- 11 back ends.  The sibling of
   DWARF_FRAME_RETURN_COLUMN, which was a mandatory field above and is now a
   CALL in `target_frame_desc' -- epiphany's reads `current_function_decl'.
   This one stays here: no definition in the tree reads per-function state
   (`scratchpad/cdata-perfn-sweep.sh' nominates only its sibling), and the 11
   are plain constants or option-state arithmetic.  */
#ifdef DWARF_ALT_FRAME_RETURN_COLUMN
# define MT_HAS_DWARF_ALT_FRAME_RETURN_COLUMN 1
# define MT_VAL_DWARF_ALT_FRAME_RETURN_COLUMN (DWARF_ALT_FRAME_RETURN_COLUMN)
#else
# define MT_HAS_DWARF_ALT_FRAME_RETURN_COLUMN 0
# define MT_VAL_DWARF_ALT_FRAME_RETURN_COLUMN 0
#endif

#endif /* GCC_TARGET_CDATA_OPT_H */
