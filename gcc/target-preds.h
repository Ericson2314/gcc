/* One back end's CONSTRAINT vocabulary, for shared code.
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

/* WHAT WAS WRONG.

   `genpreds' already writes one `tm-preds-<base>.h' per back end and one
   `insn-preds-<base>.cc' per back end, each in `namespace insn_<base>'.  The
   per-base mechanism is complete and has been for some time.  Nothing in
   shared code invoked it.

   `constrain_operands' lives in `recog.cc', which is SHARED, and the
   constraint vocabulary it uses -- `lookup_constraint',
   `constraint_satisfied_p', `reg_class_for_constraint',
   `get_constraint_type', `CONSTRAINT_LEN' and the rest -- reaches it from the
   build root's `tm_p.h', which includes the build root's `tm-preds.h', which
   `build/genpreds' writes FROM `config/i386/i386.md'.  So every back end's
   insns were being constraint-checked against the PRIMARY's letters.

   Measured in the running `cc1' (scratchpad/t128-cause.sh), compiling
   `int g (int a) { return a + 1; }' for aarch64, stopped at
   `_fatal_insn_not_found':

       recog_data.constraints[0] = "=rk,rk,w,rk,r,r,rk,rk"   (aarch64's)
       GLOBAL       lookup_constraint ("k") = 18
       insn_i386    lookup_constraint ("k") = 18
       insn_aarch64 lookup_constraint ("k") =  2
       GLOBAL       reg_class_for_constraint (k) = 0   = NO_REGS
       insn_i386    reg_class_for_constraint (k) = 0   = NO_REGS
       insn_aarch64 reg_class_for_constraint (k) = 6   = STACK_REG

   aarch64's `*adddi3_aarch64' spells `k' for its STACK_REG.  i386's `k' is
   `TARGET_AVX512F ? ALL_MASK_REGS : NO_REGS', and `TARGET_AVX512F' is i386
   option state that no `ix86_option_override' has promoted -- the `Pmode'
   silent-default shape again -- so it answers NO_REGS.  aarch64's real stack
   pointer was therefore rejected by aarch64's own add pattern, and the
   compiler died in `final_scan_insn_1' with "insn does not satisfy its
   constraints" on

       (set (reg/f:DI 31 sp) (plus:DI (reg/f:DI 31 sp) (const_int -16)))

   Note both directions diverge (18 vs 2, 0 vs 6), so this cannot be "everyone
   now gets the same new answer".

   WHY A TABLE AND NOT A UNION.  A constraint letter means a different thing on
   every back end -- that is what a constraint letter IS -- so there is no
   vocabulary to union, only data to select.  Per PRINCIPLES section 2 this is
   a HOOK and not a `target-specs' capability: the letters come from the `.md'
   file, ship with the compiler, and cannot differ between two installations
   serving the same target.

   WHY IT IS NOT A GENERATOR PROBLEM.  It was reasonable to expect one: these
   answers reach the compiler from the `.md' files through `genpreds', and the
   generators cannot read runtime target data.  They do not have to.  Each
   generator run still emits ONE back end's constants, exactly as it does
   today; all that changes is that shared code stops reading the primary's
   copy and asks which one is in force.  `genpreds.cc' gains six lines and no
   new inputs.

   HOW THE REDIRECTION IS DONE, and why it is a macro rename rather than a
   `defaults.h' `#undef'/`#define' pair like the rest of this branch.  These
   are `static inline' FUNCTIONS in a generated header, not macros, and
   `defaults.h' is reached from `tm.h' -- BEFORE `tm_p.h'.  A macro defined
   there would rewrite `tm-preds.h''s own DEFINITIONS, not just its uses.  So
   `genpreds' instead emits `#include "multi-target-preds.h"' as the last line
   of the shared `tm-preds.h', after the inline definitions have been parsed,
   and that header renames the USES.  The primary's inline bodies survive
   unreferenced; being `static inline', they emit no code.

   THE INT BOUNDARY IS DELIBERATE.  `enum constraint_num' is a different type
   in every `namespace insn_<base>', and its VALUES are per base -- 18 and 2
   above are the same letter.  The table therefore traffics in `int', so that
   no `enum constraint_num' ever crosses between two bases' vocabularies.
   Shared code may hold a value and pass it back (it does), but it may not
   compare one against a spelled enumerator; swept before landing, the only
   two it spells are `CONSTRAINT__UNKNOWN', which is 0 in every back end, and
   `CONSTRAINT_X' (lra-constraints.cc:4055), which becomes a call.  */

#ifndef GCC_TARGET_PREDS_H
#define GCC_TARGET_PREDS_H

/* NAMED, not guarded.  `tm-preds.h' wraps its own `get_register_filter' in
   `#if defined GCC_HARD_REG_SET_H' because it is included by translation
   units that have no such type; doing that HERE would make `struct
   target_preds_desc' a different SIZE in a translation unit that happens not
   to have reached hard-reg-set.h first -- which is the layout-disagreement
   bug this branch has already paid for once, in `struct target_constraints'
   (see the NUM_REGISTER_FILTERS note in genpreds.cc).  One layout, so the
   type is required rather than conditional.  */
#include "hard-reg-set.h"

/* One back end's constraint entry points.  Every member is a thunk defined in
   `target-cumargs.cc' compiled for that base, where `tm_p.h' resolves to that
   base's `tm_p-<base>.h' and hence to its `tm-preds-<base>.h'.  Compiling one
   file against one back end's headers is the whole mechanism; no back end is
   edited and no `target.def' entry is added.  */

struct target_preds_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* THIS BASE'S `CONSTRAINT__LIMIT' and its `CONSTRAINT_X'.  The first is
     carried only so a diagnostic can say how many letters the base has; the
     second is what `lra-constraints.cc' needs, and is a number that differs
     per base (i386 86, aarch64 elsewhere) rather than the compile-time
     constant it looks like.  */
  int limit;
  int constraint_X;

  int (*lookup) (const char *);
  bool (*satisfied_p) (rtx, int);
  int (*reg_class_for) (int);
  int (*constraint_type) (int);

  bool (*extra_register) (int);
  bool (*extra_memory) (int);
  bool (*extra_special_memory) (int);
  bool (*extra_relaxed_memory) (int);
  bool (*extra_address) (int);
  void (*allows_reg_mem) (int, bool *, bool *);

  size_t (*constraint_len) (char, const char *);
  bool (*const_int_ok) (HOST_WIDE_INT, int);

  /* THE WRITER OF `this_target_constraints->register_filters[]', AND ITS
     ABSENCE FROM THIS TABLE COST ~102,000 aarch64 TEST RESULTS.

     The paragraph below reasons correctly about the READER and was silent
     about the WRITER, which is the producer/consumer split arriving from the
     other side.  `register_filters[]' is shared runtime storage, and
     `multi-target-select.cc' says in as many words that "the selected back
     end's init_reg_class_start_regs () fills [it] in" -- but `reginfo.cc'
     called the BARE name, which is the SINGULAR `insn-preds.cc' generated
     from the primary's machine description.  i386 defines no register
     filters, so `register_filters.is_empty ()' held in that run and genpreds
     emitted

         void init_reg_class_start_regs () { }

     an empty body.  Every bit of `register_filters[]' therefore stayed 0, so
     `TEST_HARD_REG_BIT' answered NO for every register and every filtered
     constraint became unsatisfiable.  Measured on aarch64: `Uw2' is
     `FP_REGS' plus `regno % 2 == 0', and V24 (regno 56, even) failed it, so
     LRA reloaded an operand that was already correct, could not satisfy the
     reload, and died in `lra_split_hard_reg_for'.  The whole SVE/SME ACLE
     family -- where stock GCC fails ZERO -- went with it.

     Note the shape: the table selected every function that READS a filter and
     none that WRITES one, and the reading half was demonstrably wired (`nm
     -uC lra-constraints.o' shows `mt_get_register_filter'), which is exactly
     what made the gap invisible.  */
  void (*init_filters) (void);

  /* The register-filter side.  `test_register_filters' is NOT here: genpreds
     already emits an identical body in every back end's header, over the
     unioned `NUM_REGISTER_FILTERS' and the shared
     `this_target_constraints->register_filters[]', so there is nothing left
     to select between.  These four are per base because they map a
     CONSTRAINT NUMBER to a filter, and constraint numbers are per base.  */
  const HARD_REG_SET *(*register_filter) (int);
  int (*register_filter_id) (int);
  int (*dependent_filter_id) (int);
  int (*dependent_filter_ref) (int);
  bool (*eval_dependent) (int, unsigned int, machine_mode, unsigned int,
			  machine_mode);
};

/* THE TABLE IN FORCE, and it starts as none.

   NULL until a target is selected, for the reason `target-regs.h' gives at
   length and which this file is itself an instance of: pre-pointing it at the
   primary is precisely the bug being removed, and it is a bug that produces a
   plausible answer on the build machine.  */
extern const struct target_preds_desc *targetm_preds;

/* The shared-code spellings.  `multi-target-preds.h' renames `tm-preds.h''s
   inline wrappers onto these; a back end's own translation unit keeps the
   generated ones and never sees this file's names.  */

extern int mt_lookup_constraint (const char *);
extern bool mt_constraint_satisfied_p (rtx, int);
extern int mt_reg_class_for_constraint (int);
extern int mt_get_constraint_type (int);
extern bool mt_insn_extra_register_constraint (int);
extern bool mt_insn_extra_memory_constraint (int);
extern bool mt_insn_extra_special_memory_constraint (int);
extern bool mt_insn_extra_relaxed_memory_constraint (int);
extern bool mt_insn_extra_address_constraint (int);
extern void mt_insn_extra_constraint_allows_reg_mem (int, bool *, bool *);
extern size_t mt_insn_constraint_len (char, const char *);
extern bool mt_insn_const_int_ok_for_constraint (HOST_WIDE_INT, int);
extern const HARD_REG_SET *mt_get_register_filter (int);
extern int mt_get_register_filter_id (int);
extern int mt_get_dependent_filter_id (int);
extern int mt_get_dependent_filter_ref (int);
extern bool mt_eval_dependent_filter (int, unsigned int, machine_mode,
				      unsigned int, machine_mode);
extern int mt_constraint_X (void);

#endif /* GCC_TARGET_PREDS_H */
