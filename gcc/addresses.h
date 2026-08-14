/* Inline functions to test validity of reg classes for addressing modes.
   Copyright (C) 2006-2026 Free Software Foundation, Inc.

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

/* Wrapper function to unify target macros MODE_CODE_BASE_REG_CLASS,
   MODE_BASE_REG_REG_CLASS, MODE_BASE_REG_CLASS and BASE_REG_CLASS.
   Arguments as for the MODE_CODE_BASE_REG_CLASS macro.  */

#ifndef GCC_ADDRESSES_H
#define GCC_ADDRESSES_H

#include "target-addr.h"

/* THE `#ifdef' CHAINS THAT USED TO BE HERE HAVE MOVED TO target-addr.cc.

   They have not been rewritten -- target-addr.cc holds them character for
   character -- they have been moved somewhere they are preprocessed ONCE PER
   BACK END rather than once, against the primary's `tm.h', for the whole
   compiler.  That is the entire content of the change: this header is
   included by target-independent code, so every `#ifdef BASE_REG_CLASS' here
   asked the primary target's headers a question that was being posed on
   behalf of some other target.

   The four funnels below are still `inline' and still take the same
   arguments; they now forward to the selected base's table.  See
   target-addr.h for the cost, the reg-class numbering caveat, and why this
   needs no new `target.def' hook and edits no back end.  */

inline enum reg_class
base_reg_class (machine_mode mode ATTRIBUTE_UNUSED,
		addr_space_t as ATTRIBUTE_UNUSED,
		enum rtx_code outer_code ATTRIBUTE_UNUSED,
		enum rtx_code index_code ATTRIBUTE_UNUSED,
		rtx_insn *insn ATTRIBUTE_UNUSED = NULL)
{
  return (enum reg_class) targetm_addr->base_reg_class (mode, as, outer_code,
						        index_code, insn);
}

inline enum reg_class
index_reg_class (rtx_insn *insn ATTRIBUTE_UNUSED = NULL)
{
  return (enum reg_class) targetm_addr->index_reg_class (insn);
}

/* Wrapper function to unify target macros REGNO_MODE_CODE_OK_FOR_BASE_P,
   REGNO_MODE_OK_FOR_REG_BASE_P, REGNO_MODE_OK_FOR_BASE_P and
   REGNO_OK_FOR_BASE_P.
   Arguments as for the REGNO_MODE_CODE_OK_FOR_BASE_P macro.  */

inline bool
ok_for_base_p_1 (unsigned regno ATTRIBUTE_UNUSED,
		 machine_mode mode ATTRIBUTE_UNUSED,
		 addr_space_t as ATTRIBUTE_UNUSED,
		 enum rtx_code outer_code ATTRIBUTE_UNUSED,
		 enum rtx_code index_code ATTRIBUTE_UNUSED,
		 rtx_insn* insn ATTRIBUTE_UNUSED = NULL)
{
  return targetm_addr->ok_for_base_p_1 (regno, mode, as, outer_code,
					index_code, insn);
}

/* The strict `REGNO_OK_FOR_INDEX_P' funnel.

   This one is NEW, and its absence is why `REGNO_OK_FOR_INDEX_P' was the one
   member of this family that target-independent code still spelled directly,
   at fourteen sites in six files.  `addresses.h' funnelled the three other
   corners of the base/index x class/predicate square and left this corner
   open; the macro therefore reached `ira-costs.cc', `reload.cc',
   `rtlanal.cc', `regcprop.cc' and `regrename.cc' from the PRIMARY's `tm.h'.

   Recording that plainly because CLASS-C-DESIGN.md 6 sized Stage 1 as "the
   addresses.h funnel, 9 macros -> 3 inline bodies, ~4 conversion sites".  The
   funnel is real for `BASE_REG_CLASS' and `REGNO_OK_FOR_BASE_P'; it was NOT
   real for `INDEX_REG_CLASS' (9 direct sites) or `REGNO_OK_FOR_INDEX_P' (14).
   Those 23 sites are converted with this change, and the count is the
   correction: Stage 1 is ~27 sites, not ~4.  */

inline bool
ok_for_index_p_1 (unsigned regno)
{
  return targetm_addr->ok_for_index_p_1 (regno);
}

/* Wrapper around ok_for_base_p_1, for use after register allocation is
   complete.  Arguments as for the called function.  */

inline bool
regno_ok_for_base_p (unsigned regno, machine_mode mode, addr_space_t as,
		     enum rtx_code outer_code, enum rtx_code index_code,
		     rtx_insn *insn = NULL)
{
  if (regno >= FIRST_PSEUDO_REGISTER && reg_renumber[regno] >= 0)
    regno = reg_renumber[regno];

  return ok_for_base_p_1 (regno, mode, as, outer_code, index_code, insn);
}

/* THE FIFTH FUNNEL, and it is spelled differently from the four above on
   purpose.

   `LEGITIMATE_PIC_OPERAND_P' is a `tm.h' macro of exactly the shape this
   header exists to funnel, but unlike BASE_REG_CLASS and friends it has no
   wrapper: six shared translation units spell the macro directly, so each of
   them was asking the PRIMARY's headers a question posed on behalf of another
   target.  The macro NAME is left alone -- back-end sources use it, and it is
   correct there, where `tm.h' is that back end's own -- and the six shared
   sites are changed to call this instead.  Keeping both spellings live is
   what makes the distinction visible: `LEGITIMATE_PIC_OPERAND_P' in shared
   code is now a bug you can grep for.  */

inline bool
mt_legitimate_pic_operand_p (rtx x)
{
  return targetm_addr->legitimate_pic_operand_p (x);
}

/* THE SIXTH, and the same rule applies: `CONSTANT_ADDRESS_P' in SHARED code
   is a bug, `CONSTANT_ADDRESS_P' in a back end's own source is correct.  */

inline bool
mt_constant_address_p (rtx x)
{
  return targetm_addr->constant_address_p (x);
}

#endif /* GCC_ADDRESSES_H */
