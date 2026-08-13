/* One back end's addressing register-class predicates.
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

/* Compiled once per back end, with `-I<base>-inc' so that every `tm.h',
   `tm_p.h', `insn-*.h' and `options.h' it reaches is THAT back end's, and
   with -DTARGETM_ADDR_SYMBOL naming the table so all of them can be linked
   into one compiler.  See target-addr.h for why this exists and
   gen-multi-target-md.awk for the rules that build it.

   The bodies below are the `addresses.h' funnels, moved verbatim.  Keeping
   them character-for-character identical is deliberate: the whole claim of
   this change is that the SAME chain, evaluated in each base's own
   preprocessor context, gives each base its own answer.  Rewriting the chain
   at the same time would have made a behaviour change and a mechanism change
   indistinguishable if the arm went red.

   Unlike target-asm-ops.cc, this file needs more than `coretypes.h': the
   macros expand to back-end functions (`aarch64_regno_ok_for_base_p') and to
   generic globals (`reg_renumber'), so `tm_p.h' and `regs.h' come in too.
   That is also why the rules for it are emitted only for back ends whose
   HAND-WRITTEN objects are linked -- the `mt_bases' set -- and not for all 45
   the way target-asm-ops-<base>.o is.  A table for a back end whose <cpu>.cc
   is absent would compile and then fail to link, which is the trap
   target-asm-ops.cc records for mmix.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
/* This source is compiled once per configured back end, so it names the back
   end's headers rather than relying on -I<base>-inc.  See
   multi-target-base.h.  */
#include "multi-target-base.h"
#include BASE_HEADER (tm.h)
#include "rtl.h"
/* `memmodel.h' BEFORE `tm_p.h', as target-cumargs.cc and target-regs.cc
   already have it, and for a reason that only shows up once more than two
   back ends are configured: `tm_p.h' is this base's `<cpu>-protos.h', and
   alpha, ia64 and sparc declare functions taking `enum memmodel' there.  A
   C++ enum cannot be introduced by an elaborated-type-specifier in a
   parameter list, so those three fail with `use of enum memmodel without
   previous declaration'.  Two of the five per-base sources that include
   `BASE_HEADER (tm_p.h)' already had this include; the omission in the other
   three was invisible because neither i386 nor aarch64 names the type.  */
#include "memmodel.h"
#include BASE_HEADER (tm_p.h)
#include "regs.h"
#include "target-addr.h"

/* --- BASE_REG_CLASS and friends ------------------------------------- */

static int
gcc_taddr_base_reg_class (machine_mode mode ATTRIBUTE_UNUSED,
			  addr_space_t as ATTRIBUTE_UNUSED,
			  int outer_code ATTRIBUTE_UNUSED,
			  int index_code ATTRIBUTE_UNUSED,
			  rtx_insn *insn ATTRIBUTE_UNUSED)
{
#ifdef INSN_BASE_REG_CLASS
  return INSN_BASE_REG_CLASS (insn);
#else
#ifdef MODE_CODE_BASE_REG_CLASS
  return MODE_CODE_BASE_REG_CLASS (MACRO_MODE (mode), as,
				   (enum rtx_code) outer_code,
				   (enum rtx_code) index_code);
#else
#ifdef MODE_BASE_REG_REG_CLASS
  if (index_code == REG)
    return MODE_BASE_REG_REG_CLASS (MACRO_MODE (mode));
#endif
#ifdef MODE_BASE_REG_CLASS
  return MODE_BASE_REG_CLASS (MACRO_MODE (mode));
#else
  return BASE_REG_CLASS;
#endif
#endif
#endif
}

static int
gcc_taddr_index_reg_class (rtx_insn *insn ATTRIBUTE_UNUSED)
{
#ifdef INSN_INDEX_REG_CLASS
  return INSN_INDEX_REG_CLASS (insn);
#else
  return INDEX_REG_CLASS;
#endif
}

/* --- REGNO_OK_FOR_BASE_P and friends -------------------------------- */

static bool
gcc_taddr_ok_for_base_p_1 (unsigned regno ATTRIBUTE_UNUSED,
			   machine_mode mode ATTRIBUTE_UNUSED,
			   addr_space_t as ATTRIBUTE_UNUSED,
			   int outer_code ATTRIBUTE_UNUSED,
			   int index_code ATTRIBUTE_UNUSED,
			   rtx_insn *insn ATTRIBUTE_UNUSED)
{
#ifdef REGNO_OK_FOR_INSN_BASE_P
  return REGNO_OK_FOR_INSN_BASE_P (regno, insn);
#else
#ifdef REGNO_MODE_CODE_OK_FOR_BASE_P
  return REGNO_MODE_CODE_OK_FOR_BASE_P (regno, MACRO_MODE (mode), as,
					(enum rtx_code) outer_code,
					(enum rtx_code) index_code);
#else
#ifdef REGNO_MODE_OK_FOR_REG_BASE_P
  if (index_code == REG)
    return REGNO_MODE_OK_FOR_REG_BASE_P (regno, MACRO_MODE (mode));
#endif
#ifdef REGNO_MODE_OK_FOR_BASE_P
  return REGNO_MODE_OK_FOR_BASE_P (regno, MACRO_MODE (mode));
#else
  return REGNO_OK_FOR_BASE_P (regno);
#endif
#endif
#endif
}

static bool
gcc_taddr_ok_for_index_p_1 (unsigned regno ATTRIBUTE_UNUSED)
{
  return REGNO_OK_FOR_INDEX_P (regno);
}

/* `extern' is not redundant: a namespace-scope `const' object has internal
   linkage in C++, so without it the table is built correctly and then cannot
   be named from the selector.  See target-asm-ops.cc, where the same omission
   would have failed to link against all 44 tables at once.

   NOT `constexpr' here, deliberately, and the difference from
   target-asm-ops.cc is worth a line.  There the initialisers are `tm.h'
   STRINGS, and `constexpr' is what catches a back end whose directive
   secretly reads `target_flags' -- a per-compilation value in a table keyed by
   target identity.  Here every initialiser is the address of a `static'
   function defined just above, which is a constant expression by
   construction; there is no option-dependent value that could sneak in,
   because the option-dependence lives INSIDE the function where it is
   evaluated at the point of use.  */
extern const struct target_addr TARGETM_ADDR_SYMBOL;
const struct target_addr TARGETM_ADDR_SYMBOL =
{
  gcc_taddr_base_reg_class,
  gcc_taddr_index_reg_class,
  gcc_taddr_ok_for_base_p_1,
  gcc_taddr_ok_for_index_p_1
};
