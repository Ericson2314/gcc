/* Register to Stack convert for GNU compiler.
   Copyright (C) 1992-2026 Free Software Foundation, Inc.

   This file is part of GCC.

   GCC is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   GCC is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
   or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
   License for more details.

   You should have received a copy of the GNU General Public License
   along with GCC; see the file COPYING3.  If not see
   <http://www.gnu.org/licenses/>.  */

/* WHAT IS LEFT OF reg-stack.cc, AND WHY THE REST IS NOT HERE.

   This file used to be 3,557 lines, of which 3,265 sat inside
   `#ifdef STACK_REGS' -- a macro exactly two back ends of ~50 define
   (config/i386/i386.h and config/frv/frv.h).  Compiled once, against the
   primary's headers, that guard was answered by i386 for every target the
   compiler served, and the pass gate below therefore returned TRUE
   everywhere, register stack or not.

   The body moved to target-regstack.cc, which is compiled once per configured
   back end; see target-regstack.h for the argument, and for the enumeration
   of what shared code still needs from a base that has no register stack.
   What stays here is the part that is genuinely target-independent:

     * `regstack_completed', which rtl.h declares unconditionally and which
       final.cc, regrename.cc and df-problems.cc read on every target.  It was
       already outside the guard.
     * the two passes named by passes.def.  Their gate and their execute now
       ask `targetm_regstack' -- the SELECTED back end's answer -- instead of
       asking the preprocessor, which could only ever give the primary's.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "backend.h"
#include "rtl.h"
#include "df.h"
#include "tree-pass.h"
#include "target-regstack.h"

/* Nonzero after end of regstack pass.  Declared unconditionally by rtl.h and
   cleared by final.cc on every target, so it is shared and stays here.  */
int regstack_completed = 0;

namespace {

const pass_data pass_data_stack_regs =
{
  RTL_PASS, /* type */
  "*stack_regs", /* name */
  OPTGROUP_NONE, /* optinfo_flags */
  TV_REG_STACK, /* tv_id */
  0, /* properties_required */
  0, /* properties_provided */
  0, /* properties_destroyed */
  0, /* todo_flags_start */
  0, /* todo_flags_finish */
};

class pass_stack_regs : public rtl_opt_pass
{
public:
  pass_stack_regs (gcc::context *ctxt)
    : rtl_opt_pass (pass_data_stack_regs, ctxt)
  {}

  /* opt_pass methods: */
  bool gate (function *) final override
    {
      /* THE SELECTED back end's `STACK_REGS', not the primary's.  This read
	 `#ifdef STACK_REGS -> return true' and so gated true for aarch64,
	 riscv, and every other target with no register stack.

	 A null table means no target has been selected, which cannot happen
	 by the time a pass gate runs; it gates false rather than dereferencing
	 so that the failure mode of a build bug is "the pass did not run",
	 which multi-target-select.cc's by-name check reports loudly at
	 selection time instead.  */
      return targetm_regstack != NULL && targetm_regstack->has_stack_regs;
    }

}; // class pass_stack_regs

} // anon namespace

rtl_opt_pass *
make_pass_stack_regs (gcc::context *ctxt)
{
  return new pass_stack_regs (ctxt);
}

/* Convert register usage from flat register file usage to a stack
   register file.  */
static unsigned int
rest_of_handle_stack_regs (void)
{
  /* Guarded by the same question the gate asks, for the same reason: this is
     reached only when the gate said yes, and `reg_to_stack' is null on a base
     with no register stack.  */
  if (targetm_regstack != NULL && targetm_regstack->has_stack_regs)
    {
      if (targetm_regstack->reg_to_stack ())
	df_insn_rescan_all ();
      regstack_completed = 1;
    }
  return 0;
}

namespace {

const pass_data pass_data_stack_regs_run =
{
  RTL_PASS, /* type */
  "stack", /* name */
  OPTGROUP_NONE, /* optinfo_flags */
  TV_REG_STACK, /* tv_id */
  0, /* properties_required */
  0, /* properties_provided */
  0, /* properties_destroyed */
  0, /* todo_flags_start */
  TODO_df_finish, /* todo_flags_finish */
};

class pass_stack_regs_run : public rtl_opt_pass
{
public:
  pass_stack_regs_run (gcc::context *ctxt)
    : rtl_opt_pass (pass_data_stack_regs_run, ctxt)
  {}

  /* opt_pass methods: */
  unsigned int execute (function *) final override
    {
      return rest_of_handle_stack_regs ();
    }

}; // class pass_stack_regs_run

} // anon namespace

rtl_opt_pass *
make_pass_stack_regs_run (gcc::context *ctxt)
{
  return new pass_stack_regs_run (ctxt);
}
