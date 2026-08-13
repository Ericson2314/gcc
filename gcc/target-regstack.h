/* Per-back-end register-stack conversion: who has a register stack at all.
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

/* reg-stack.cc WAS NOT SHARED CODE.  It said so in its own first sentence --
   "a stack convention that the 387 uses" -- and 3,265 of its 3,557 lines sat
   inside `#ifdef STACK_REGS', a macro exactly TWO back ends of ~50 define
   (config/i386/i386.h and config/frv/frv.h).  Compiled once, against the
   primary's headers, that `#ifdef' was answered by i386 for everybody: the
   pass gate read

       #ifdef STACK_REGS
	 return true;
       #else
	 return false;
       #endif

   and therefore returned TRUE on every target the compiler served, including
   every target with no register stack.  This branch's root pattern -- one
   name, several authorities, no diagnostic -- with the primary supplying the
   answer.

   TWO back ends, not one, is why the body could not simply move to
   config/i386/.  It is per-base compilation that is wanted, not relocation:
   target-regstack.cc is compiled once per configured back end, against that
   back end's own headers, so `#ifdef STACK_REGS' becomes that back end's own
   answer.  The i386 copy gets the whole pass; an aarch64 copy gets the empty
   arm.  Same shape as target-cumargs.cc, and for the same reason.

   AND THE `gen_movxf' QUESTION DISSOLVES RATHER THAN BEING ANSWERED.
   reg-stack.cc:1170 spelled `gen_movxf', which only a back end defining an
   XFmode move pattern has.  As shared code that is a link-time reference the
   primary happened to satisfy; a forwarder or a `HAVE_movxf' guard would have
   been the obvious repair and would have been another shared answer to a
   per-base question.  Compiled per base, the name is spelled only inside
   `#ifdef STACK_REGS', i.e. only in a translation unit whose insn-flags-<cpu>.h
   has it.

   WHAT MUST STILL EXIST FOR A BASE WITH NO REGISTER STACK.  The file's own
   `#ifndef STACK_REGS' arm carried the warning: `stack_regs_mentioned' had to
   live OUTSIDE the guard because cfgcleanup.cc calls it on every target, and
   "a run-time test cannot elide a link-time reference, so the symbol has to
   exist wherever its caller does".  The complete export list of the old file,
   and where each lives now:

     regstack_completed	  int, rtl.h:4283.  Read by final.cc, regrename.cc
			  and df-problems.cc.  STAYS in reg-stack.cc, shared,
			  exactly as before -- it was already outside the
			  guard.
     stack_regs_mentioned  cfgcleanup.cc:1246.  Now defined ONCE in
			  target-regstack-select.cc, shared, as a call through
			  this table.  A base with no register stack supplies a
			  null hook and the shared wrapper returns false --
			  which is what the old `#ifndef' arm returned.
     make_pass_stack_regs
     make_pass_stack_regs_run
			  tree-pass.h:648-649, named by passes.def.  STAY in
			  reg-stack.cc, shared; only their GATE and their
			  EXECUTE now ask this table.
     reg_to_stack	  was already `static'; it is reached only through
			  this table's `reg_to_stack' member.

   That list is the check, not a formality: every one of the four is
   referenced from shared code compiled for bases that have no `STACK_REGS',
   so any of them going missing is a link failure on the aarch64 side of a
   two-base build -- loud, but only if you enumerate them first.  */

#ifndef GCC_TARGET_REGSTACK_H
#define GCC_TARGET_REGSTACK_H

/* One back end's register-stack answers.  */
struct target_regstack_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* Whether this back end defines STACK_REGS -- measured in ITS OWN
     translation unit, which is the whole point.  When false the two hooks
     below are null.  This is what the `*stack_regs' pass gates on; it used to
     gate on the primary's `#ifdef'.  */
  bool has_stack_regs;

  /* Does INSN mention a stack register?  Null for a base with no register
     stack; see the wrapper in target-regstack-select.cc for why the null is
     handled there rather than by pointing this at a shared "return false".  */
  bool (*stack_regs_mentioned) (const_rtx);

  /* Run the conversion; true if anything changed.  Null for a base with no
     register stack, in which case the pass never runs, because
     `has_stack_regs' is false.  */
  bool (*reg_to_stack) (void);
};

/* One entry per configured back end, so a table can be found by name.  */
struct target_regstack_entry
{
  const char *name;
  const struct target_regstack_desc *regstack;
};

extern const struct target_regstack_entry targetm_regstack_registry[];

/* The table in force.  NULL until a target is selected, for the reason
   target-regs.h gives at length: pre-pointing this at the primary is the bug
   being removed, not a convenience.  Note the difference in consequence from
   the other tables, though -- a NULL here makes the pass not run, which is
   the SAFE direction, so a missing selection would be quiet.  That is why
   multi-target-select.cc checks the lookup by name and calls internal_error
   rather than letting NULL stand.  */
extern const struct target_regstack_desc *targetm_regstack;

/* Look BASE up in the registry, or NULL.  BASE is a cpu_type.  */
extern const struct target_regstack_desc *target_regstack_for (const char *base);

#endif /* GCC_TARGET_REGSTACK_H */
