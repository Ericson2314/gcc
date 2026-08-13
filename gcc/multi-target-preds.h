/* Redirect shared code's constraint vocabulary to the back end in force.
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

/* See target-preds.h for what this fixes and how it was measured.

   `genpreds' emits `#include "multi-target-preds.h"' as the LAST line of the
   build root's `tm-preds.h' -- the un-namespaced one it writes from the
   primary's `.md' -- and only on a multi-target build.  A back end's own
   `tm-preds-<base>.h' never names this file, so a back end's translation unit
   keeps the generated inline wrappers and this header is invisible to it.

   THE ORDER IS THE POINT.  Every name below is `static inline' in the text
   ABOVE the include, so these macros rename USES and not DEFINITIONS.  That
   is why the redirection is not in `defaults.h' with the rest of the branch's
   `#undef'/`#define' pairs: `defaults.h' is reached from `tm.h', which is
   included before `tm_p.h', so a macro there would rewrite the definitions
   themselves.  Measured, not assumed: it does not merely look wrong, it is a
   syntax error at the definition.

   The primary's inline bodies stay in the file, now unreferenced.  They are
   `static inline', so no code is emitted for them and no symbol appears.

   MULTI_TARGET_PREDS_NO_REDIRECT is defined by the generated `insn-preds.cc'
   itself.  That file DEFINES `insn_const_int_ok_for_constraint' and
   `eval_dependent_filter' -- they are the only two names here that are extern
   rather than inline -- and renaming a definition would have it define
   `mt_insn_const_int_ok_for_constraint' instead, colliding with the forwarder
   in `target-cumargs-select.cc'.  The guard is emitted by genpreds next to
   the include, so the two cannot drift apart.  */

#ifndef GCC_MULTI_TARGET_PREDS_H
#define GCC_MULTI_TARGET_PREDS_H

#if !defined GENERATOR_FILE && !defined MULTI_TARGET_PREDS_NO_REDIRECT

#include "target-preds.h"

#undef lookup_constraint
#define lookup_constraint(P) \
  ((enum constraint_num) mt_lookup_constraint (P))

#undef constraint_satisfied_p
#define constraint_satisfied_p(X, C) \
  mt_constraint_satisfied_p (X, (int) (C))

#undef reg_class_for_constraint
#define reg_class_for_constraint(C) \
  ((enum reg_class) mt_reg_class_for_constraint ((int) (C)))

#undef get_constraint_type
#define get_constraint_type(C) \
  ((enum constraint_type) mt_get_constraint_type ((int) (C)))

#undef insn_extra_register_constraint
#define insn_extra_register_constraint(C) \
  mt_insn_extra_register_constraint ((int) (C))

#undef insn_extra_memory_constraint
#define insn_extra_memory_constraint(C) \
  mt_insn_extra_memory_constraint ((int) (C))

#undef insn_extra_special_memory_constraint
#define insn_extra_special_memory_constraint(C) \
  mt_insn_extra_special_memory_constraint ((int) (C))

#undef insn_extra_relaxed_memory_constraint
#define insn_extra_relaxed_memory_constraint(C) \
  mt_insn_extra_relaxed_memory_constraint ((int) (C))

#undef insn_extra_address_constraint
#define insn_extra_address_constraint(C) \
  mt_insn_extra_address_constraint ((int) (C))

#undef insn_extra_constraint_allows_reg_mem
#define insn_extra_constraint_allows_reg_mem(C, R, M) \
  mt_insn_extra_constraint_allows_reg_mem ((int) (C), R, M)

/* CONSTRAINT_LEN is a macro over this name, so renaming the function covers
   both spellings and there is no second authority to keep in step.  */
#undef insn_constraint_len
#define insn_constraint_len(FC, S) mt_insn_constraint_len (FC, S)

#undef insn_const_int_ok_for_constraint
#define insn_const_int_ok_for_constraint(V, C) \
  mt_insn_const_int_ok_for_constraint (V, (int) (C))

#undef get_register_filter
#define get_register_filter(C) mt_get_register_filter ((int) (C))

#undef get_register_filter_id
#define get_register_filter_id(C) mt_get_register_filter_id ((int) (C))

#undef get_dependent_filter_id
#define get_dependent_filter_id(C) mt_get_dependent_filter_id ((int) (C))

#undef get_dependent_filter_ref
#define get_dependent_filter_ref(ID) mt_get_dependent_filter_ref (ID)

#undef eval_dependent_filter
#define eval_dependent_filter(ID, RN, M, RRN, RM) \
  mt_eval_dependent_filter (ID, RN, M, RRN, RM)

/* THE ONE ENUMERATOR SHARED CODE SPELLS BY NAME.  `lra-constraints.cc:4055'
   assigns `CONSTRAINT_X', and X is a different number in every back end's
   vocabulary, so it cannot stay the primary's compile-time constant.
   `CONSTRAINT__UNKNOWN' is deliberately NOT redirected: genpreds emits it as
   0 in every back end, which makes it the one value that means the same thing
   in all of them.  */
#undef CONSTRAINT_X
#define CONSTRAINT_X ((enum constraint_num) mt_constraint_X ())

#endif /* !GENERATOR_FILE && !MULTI_TARGET_PREDS_NO_REDIRECT */

#endif /* GCC_MULTI_TARGET_PREDS_H */
