/* The gen_* entry points the middle end reaches for by a bare name.
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

#ifndef GCC_MULTI_TARGET_MD_ENTRY_H
#define GCC_MULTI_TARGET_MD_ENTRY_H

/* One of these per back end, defined inside namespace insn_<base> by that
   back end's insn-emit-<base>.cc and named by multi-target-select.cc's
   forwarders.  The field list is the list in gen-target-ns.cc, in order.

   A NULL POINTER IS AN ANSWER, AND IT IS THE POINT OF THE STRUCT.  Whether a
   back end has a `blockage' pattern at all is a property of that back end's
   machine description; the compile-time HAVE_blockage that used to decide it
   comes from the SINGULAR insn-flags.h, i.e. from one back end, and so
   answered for all of them.  Here each back end says for itself, and the
   forwarder decides per call what an absent pattern means -- the generic
   ASM_INPUT expansion for `blockage', silence for `speculation_barrier', an
   error naming the back end for `nop'.

   HAVE_speculation_barrier is a RUNTIME condition in general (genflags emits
   the pattern's md condition, not just 1), and the middle end already reads
   it as one, so it travels as a predicate rather than as the pointer's
   non-nullness.  It is null exactly when gen_speculation_barrier is.  */

struct mt_md_entry_points
{
  rtx (*gen_blockage) (void);
  rtx (*gen_nop) (void);
  rtx (*gen_speculation_barrier) (void);
  bool (*have_speculation_barrier) (void);
};

/* Whether the back end in force has a `speculation_barrier' pattern at all,
   and whether that pattern's condition holds right now.  The two are the two
   halves of what `HAVE_speculation_barrier' meant, kept apart because
   TARGET_HAVE_SPECULATION_SAFE_VALUE reads them separately; see targhooks.cc.
   Both are defined in multi-target-select.cc.  */
extern bool multi_target_has_speculation_barrier_p (void);
extern bool multi_target_have_speculation_barrier (void);

/* The forwarders themselves, declared here so that a shared translation unit
   calling one of them does not depend on the singular insn-flags.h for the
   declaration -- that header is generated from ONE back end's machine
   description, so a primary without the pattern leaves the shared caller with
   no declaration at all.  `gen_blockage' is emit-rtl.h's, which declares it
   unconditionally already.

   Not in target code: insn-emit-<base>.cc includes this header and opens with
   `using namespace insn_<base>', where these names are also declared, so a
   bare declaration there would make an expander's own call to one of them an
   ambiguous overload.  */
#ifndef IN_TARGET_CODE
extern rtx gen_nop (void);
extern rtx gen_speculation_barrier (void);
#endif

#endif /* GCC_MULTI_TARGET_MD_ENTRY_H */
