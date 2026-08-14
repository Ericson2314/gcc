/* Per-back-end addressing register-class predicates.
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

/* THE PROBLEM

   `addresses.h' already collects fourteen target macros -- BASE_REG_CLASS,
   INDEX_REG_CLASS, REGNO_OK_FOR_BASE_P, REGNO_OK_FOR_INDEX_P and their
   MODE_/INSN_ variants -- into four inline funnels.  That is a real funnel and
   it is why this family is cheap to convert.  But the funnels are `#ifdef'
   chains over macros out of `tm.h', and `addresses.h' is included by
   target-independent code, which is compiled ONCE, against the PRIMARY base's
   `tm.h'.  So in a compiler holding two back ends, `base_reg_class ()' answers
   i386's GENERAL_REGS while generating aarch64 code, silently.

   That is the two-stage poison this branch keeps finding, and this family is
   its purest instance: `regclass_map' and friends link, answer, and are never
   diagnosed.

   THE SHAPE OF THE FIX, AND WHY IT IS NOT A NEW `target.def' HOOK

   The obvious move is ~4 new hooks in `target.def' plus a conversion in every
   one of the 60-odd back ends that define these macros.  That is the cost
   CLASS-C-DESIGN.md 1 priced at ~86 hooks and flagged as the reason to
   consider declining the whole route.

   None of it is necessary here, because the branch already has the mechanism:
   `target-asm-ops.cc' is a single small translation unit compiled ONCE PER
   BACK END against that back end's `tm-<base>.h'.  Do the same thing with the
   `addresses.h' bodies and the `#ifdef' chain is evaluated separately in each
   base's own preprocessor context -- which is exactly and only what was
   missing.  ZERO back ends are edited, zero macros are deleted, and no
   `target.def' entry is added.

   The Stage 0 correction ("convert a macro to a hook and DELETE the macro, so
   the unfilled case is `gcc_unreachable ()' rather than a silent default")
   was aimed at a real failure -- `default_libcall_value' answering i386 for
   every base.  It does not apply to this shape and it is worth saying why:
   there IS no unfilled case here.  Every base compiles its own copy of the
   chain from its own headers, so a base that defines none of the fourteen
   macros gets `defaults.h''s default IN ITS OWN CONTEXT, which is the correct
   answer for it rather than the primary's.  The silent-default trap is absent
   structurally, not by vigilance.

   WHAT IS STILL WRONG AFTER THIS, AND IS NOT MADE WORSE BY IT

   `enum reg_class' is numbered per back end (N_REG_CLASSES is 34 for i386 and
   20 for aarch64), so a class number crossing this boundary means different
   things on the two sides.  That is the shared-numbering problem the branch
   has open as Stage 4, and it is why the table below is typed `int' rather
   than `enum reg_class': an `int' cannot be silently indexed into
   `reg_class_contents[]' without a cast that someone had to write.

   Before this change, target-independent code got i386's class for every
   base -- wrong value, wrong numbering.  After it, it gets the selected base's
   own class in the selected base's own numbering -- right value, still the
   wrong numbering.  Strictly better and still not right; the arm that closes
   it is Stage 4, not this one.  */

#ifndef GCC_TARGET_ADDR_H
#define GCC_TARGET_ADDR_H

/* The four `addresses.h' funnels, one function pointer each.

   `int' rather than `enum rtx_code' for the codes, and `int' rather than
   `enum reg_class' for the results, so that this header needs nothing beyond
   `coretypes.h'.  `addresses.h' is included very early by some of its
   consumers and a dependency on `rtl.h' here would be a new include cycle for
   no gain -- `enum rtx_code' comes from `rtl.def' and is target-independent,
   so the round trip through `int' loses nothing.  */
struct target_addr
{
  int (*base_reg_class) (machine_mode mode, addr_space_t as,
			 int outer_code, int index_code, rtx_insn *insn);
  int (*index_reg_class) (rtx_insn *insn);
  bool (*ok_for_base_p_1) (unsigned regno, machine_mode mode, addr_space_t as,
			   int outer_code, int index_code, rtx_insn *insn);
  bool (*ok_for_index_p_1) (unsigned regno);
  /* LEGITIMATE_PIC_OPERAND_P, AND IT IS HERE FOR THE SAME REASON AS THE FOUR
     ABOVE RATHER THAN BY ANALOGY.

     Six shared translation units spell the macro -- reload1.cc:4088,
     lra-constraints.cc:2131, recog.cc:1535 and :1715, reload.cc:3433,
     ira-costs.cc:805 and ira.cc:4346 -- and it is a `tm.h' macro with a
     `defaults.h:1192' fallback of 1.  So in a compiler holding several back
     ends every one of those sites asked the PRIMARY's headers a question
     posed on behalf of another target, exactly as `BASE_REG_CLASS' did.

     HOW IT WAS FOUND IS THE INSTRUCTIVE PART, and it is PRINCIPLES 4's
     "a zero from a name-matching instrument is a claim about the instrument".
     A grep for the SYMBOL `legitimate_pic_operand_p' over every shared .cc
     and .h returned three hits, all spurious (a comment in targhooks.cc, a
     struct member `targetm.asm_out.print_operand' in final.cc, a build-time
     generator's own function in genmatch.cc), and the conclusion drawn was
     that no shared code names it and a bare rename would do.  It is reached
     through the MACRO, whose name the grep did not contain; the rename then
     produced `undefined reference to legitimate_pic_operand_p' from
     lra-constraints.o at the link of cc1, which is the instrument's blind
     spot reporting itself.

     `bool' not `int': i386 and sparc declare it `bool' and s390 and arm
     `int', and every consumer is a condition.  The narrowing happens in each
     base's own translation unit, where its own declaration is visible.  */
  bool (*legitimate_pic_operand_p) (rtx x);
};

/* One entry per configured back end, so a table can be found by name.  */
struct target_addr_entry
{
  const char *name;
  const struct target_addr *addr;
};

extern const struct target_addr_entry targetm_addr_registry[];

/* The table in force.  Selected by target identity alone, so -- as for
   `targetm_asm_ops' -- it is constant-initialised with the primary's table and
   is valid before anything runs.  */
extern const struct target_addr *targetm_addr;

/* Look BASE up in the registry, or NULL.  BASE is a cpu_type, the same key
   the tm-<base>.h files use.  */
extern const struct target_addr *target_addr_for (const char *base);

#endif /* GCC_TARGET_ADDR_H */
