/* Per-back-end frame and argument-register facts that shared code asks for.
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

/* SIX MACROS THAT `function.cc' EVALUATES AGAINST THE PRIMARY'S tm.h.

   Each one is a question about the SELECTED back end's frame layout or
   argument registers, and each one is answered today by whichever base
   compiled the middle end -- i.e. by i386, for every target.  The six, with
   the i386 symbol each drags into `function.o' as evidence that it is i386
   answering:

     STACK_BOUNDARY                  -> ix86_cfun_abi (via TARGET_64BIT_MS_ABI)
     PREFERRED_STACK_BOUNDARY        -> ix86_preferred_stack_boundary
     STACK_SLOT_ALIGNMENT            -> ix86_local_alignment
     MINIMUM_ALIGNMENT               -> ix86_minimum_alignment
     OUTGOING_REG_PARM_STACK_SPACE   -> ix86_function_type_abi
     FUNCTION_ARG_REGNO_P            -> ix86_function_arg_regno_p

   NOTE THE THIRD LINE.  `function.cc' references `ix86_local_alignment', and
   the macro that drags it in is `STACK_SLOT_ALIGNMENT' -- NOT `LOCAL_ALIGNMENT'
   and not `LOCAL_DECL_ALIGNMENT', which are the two the symbol's name suggests
   and which `function.cc' never spells.  i386 happens to implement three
   different macros with one function.  Converting the macro a symbol's name
   implies converts one that nothing in the file uses.

   WHY THESE ARE CALLS AND NOT `target-cdata' FIELDS.  target-cdata.h holds the
   scalar per-target constants, and it would be the cheaper home.  It is the
   wrong one, and the measurement that says so is already in the tree:
   target-cdata.h's own header comment lists `STACK_BOUNDARY' as one of SIX
   macros out of thirty-five measured NOT invariant under
   `__attribute__((target))', because i386's reaches `ix86_cfun_abi ()', which
   reads `cfun'.  A field there is evaluated once, with `cfun' null, and then
   freezes -- silently.  The other five are worse still: four take arguments,
   so there is no value to cache at all.  So these pay for a real call, and the
   design note in target-cdata.h is the reason rather than a preference.

   WHY THIS TABLE HANGS OFF `target_cumargs_desc' RATHER THAN HAVING ITS OWN
   REGISTRY.  The registry -- the per-base symbol declarations and the
   `TARGETM_*_TABLES' list -- is emitted by `gen-multi-target-md.awk'.  A
   seventh registry would be a mechanical copy of the cumargs one there, and
   that file is under concurrent edit.  Hanging a `const struct
   target_frame_desc *' off the table that is ALREADY generated, and that is
   already supplied from the same per-base translation unit compiled with
   `-I<base>-inc', costs one pointer and no generator change.  The two structs
   stay separate so that the split is a fact about ownership and not about
   what the fields mean; if a registry is ever cheap, this lifts out whole.  */

#ifndef GCC_TARGET_FRAME_H
#define GCC_TARGET_FRAME_H

/* One back end's answers.  Every entry is a function, including the two that
   look like constants: i386's `STACK_BOUNDARY' and `PREFERRED_STACK_BOUNDARY'
   both vary with option state within a single compilation, so a value here
   would be the frozen-at-startup bug described above.  aarch64's really are
   constants and its thunks compile to `return 128;', which is what a constant
   costs when it is allowed to be one.  */
struct target_frame_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* STACK_BOUNDARY.  */
  int (*stack_boundary) (void);

  /* PREFERRED_STACK_BOUNDARY.  Not derivable from the above: defaults.h makes
     it STACK_BOUNDARY only for a base that defines no such macro, and that
     `#ifndef' is answered in the per-base translation unit, so each base
     contributes its own answer rather than the primary's.  */
  int (*preferred_stack_boundary) (void);

  /* STACK_SLOT_ALIGNMENT (TYPE, MODE, ALIGN).  */
  unsigned int (*stack_slot_alignment) (tree type, machine_mode mode,
					unsigned int align);

  /* MINIMUM_ALIGNMENT (EXP, MODE, ALIGN).  EXP is a TYPE or a DECL, and is
     null at emit-rtl.cc:1201; the back end's own function copes, as it always
     has -- this changes who is asked, not what is asked.  */
  unsigned int (*minimum_alignment) (tree exp, machine_mode mode,
				     unsigned int align);

  /* OUTGOING_REG_PARM_STACK_SPACE (FNTYPE).  */
  int (*outgoing_reg_parm_stack_space) (tree fntype);

  /* FUNCTION_ARG_REGNO_P (N).  Generic code walks 0 .. FIRST_PSEUDO_REGISTER,
     which is the UNION width (see target-regs.h), so this is asked about
     register numbers the selected back end does not have -- alias.cc:3294 and
     df-scan.cc:3499 both do exactly that.  Every back end's definition is a
     range test or a table lookup that answers false outside its own range, so
     the union width is safe here; it is recorded because it was checked, not
     because it is obvious.  */
  bool (*function_arg_regno_p) (int regno);
};

/* The answers in force, or NULL until a target is selected.  Shared code goes
   through the `mt_' functions below rather than touching this, so that the
   by-name diagnostic cannot be bypassed.  */
extern const struct target_frame_desc *targetm_frame;

/* The shared-code spellings.  defaults.h points the six macros at these for
   every translation unit that is NOT a back end's own; a back end's own
   translation unit keeps the real macros, which is how the answers get
   supplied in the first place.  */
extern int mt_stack_boundary (void);
extern int mt_preferred_stack_boundary (void);
extern unsigned int mt_stack_slot_alignment (tree, machine_mode, unsigned int);
extern unsigned int mt_minimum_alignment (tree, machine_mode, unsigned int);
extern int mt_outgoing_reg_parm_stack_space (tree);
extern bool mt_function_arg_regno_p (int);

#endif /* GCC_TARGET_FRAME_H */
