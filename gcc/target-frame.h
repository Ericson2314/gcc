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

  /* INIT_EXPANDERS -- AND THE FIRST ENTRY HERE THAT IS AN *EXISTENCE*
     PREDICATE RATHER THAN A VALUE.

     The other six above are all questions whose answer every back end has.
     This one is a question about whether the back end has anything to say at
     all: `emit-rtl.cc' spells it `#ifdef INIT_EXPANDERS', 13 back ends define
     it (aarch64 arc arm avr cris csky epiphany ia64 m32r mmix nds32 sparc
     visium) and i386 -- the base the middle end is compiled against -- is not
     one of them.  So in shared code the `#ifdef' is FALSE, for every target,
     and the 13 back ends that install an `init_machine_status' never get it
     installed.

     THAT IS WHY THIS ONE MATTERS MORE THAN ITS SIZE SUGGESTS.  A leaked VALUE
     is wrong but present, and tends to fail near where it was read.  A leaked
     ABSENCE emits no code at all: nothing is mis-set, and the damage surfaces
     arbitrarily far away.  Concretely, for aarch64 it surfaced as

         emit-rtl.cc:6038   #ifdef INIT_EXPANDERS  -- false, so nothing runs
         => cfun->machine is never allocated
         => aarch64_set_current_function writes ARM_PCS_UNKNOWN to NULL+0x7b0

     a SIGSEGV in a back end whose own code is correct, four call levels and
     one compilation phase away from the guard that caused it.

     WHY A PAIR OF FIELDS AND NOT JUST A POINTER.  `has_init_expanders' is the
     base's own answer to `#ifdef INIT_EXPANDERS', recorded in the translation
     unit where that question is meaningful.  A bare NULL pointer would carry
     the same information and would be indistinguishable from a table built
     before this field existed -- i.e. from a stale object -- which is exactly
     the failure mode PRINCIPLES warns about: never let the absence of an
     answer BE an answer.  The two are cross-checked at selection time, so
     `(false, NULL)' means "this back end genuinely has none" and every other
     inconsistent combination fails by name.  */
  bool has_init_expanders;
  void (*init_expanders) (void);

  /* ------------------------------------------------------------------
     THE MOVE/CLEAR FAMILY -- ARM E, AND THE FIRST ENTRIES HERE THAT ARE
     NOT ABOUT ABSENCE OR ABOUT A DIVERGENT CONSTANT.

     `MOVE_RATIO' is `config/i386/i386.h:1968'

	 #define MOVE_RATIO(speed) ((speed) ? ix86_cost->move_ratio : 3)

     and `tree-inline.cc:4296' -- shared, compiled once against i386 -- says
     `size > MOVE_MAX_PIECES * MOVE_RATIO (speed_p)' with `speed_p' true.
     `ix86_cost' is `i386.cc:130', initialised NULL and written only by
     `ix86_option_override', which does not run when aarch64 is the selected
     target.  Confirmed under gdb rather than inferred
     (scratchpad/t113-ipa-diag.sh): the faulting instruction is
     `mov 0xf4(%rax),%eax' with `ix86_cost' holding 0 and `si_addr == 0xf4',
     which is `offsetof (processor_costs, move_ratio)'.

     So the macro does not expand to a VALUE at all.  It expands to a
     DEREFERENCE OF A BACK-END GLOBAL that only that back end's
     option-override initialises.  No `#ifdef' is involved, no symbol is
     undefined, and no divergent macro text is compared -- which is why none
     of the existing arms could see it.

     THE CRASH IS LUCK, AND THAT IS WHY THE WHOLE FAMILY MOVES TOGETHER.
     `ix86_cost' happens to start NULL, so `MOVE_RATIO' faults and we find
     out.  `MOVE_MAX' reads `ix86_move_max', a plain enum variable with a
     benign initialiser: it answers with i386's tuning while compiling for
     aarch64 and emits wrong code with no diagnostic whatsoever.  The two are
     in the SAME EXPRESSION on tree-inline.cc:4296.  Converting `MOVE_RATIO'
     alone would remove the SIGSEGV and leave that expression silently wrong
     -- trading a loud failure for a quiet one, which PRINCIPLES 2a names as
     a change that looks like a fix and is not.

     WHY SEVEN AND NOT THE FIVE THE HANDOVER NAMED.  The group is the
     TRANSITIVE CLOSURE through `defaults.h', measured rather than guessed
     (scratchpad/t113-armE2.sh chases each definition to a fixpoint):

	 MOVE_MAX_PIECES     <- MOVE_MAX          (defaults.h:1098)
	 STORE_MAX_PIECES    <- MOVE_MAX_PIECES   (defaults.h:1107)
	 COMPARE_MAX_PIECES  <- MOVE_MAX_PIECES   (defaults.h:1112)
	 SET_RATIO           <- MOVE_RATIO        (defaults.h:1472)

     `COMPARE_MAX_PIECES' and `SET_RATIO' were not on the handover's list of
     five, and leaving either behind reproduces the same half-fix one level
     down: aarch64 defines its own `SET_RATIO', i386 defines none, so shared
     code's `SET_RATIO' is i386's `MOVE_RATIO' -- and if `MOVE_RATIO' alone
     were redirected, `SET_RATIO' would quietly become aarch64's move ratio
     where aarch64 asks for its set ratio.  Correct-looking and wrong.

     `MAX_MOVE_MAX' IS DELIBERATELY NOT HERE, and the reason is a constraint
     rather than a preference: `reload.h:179' and `caller-save.cc:55' use it
     as an ARRAY BOUND, which cannot hold a call.  It is also not a per-target
     question -- the name says maximum, and the array is sized once for a
     binary that serves every back end.  It is a union quantity and belongs
     with the mode/register unions, not here.  See `max_move_max' below for
     the check that keeps the two consistent.

     ALL SEVEN ARE PLAIN VALUE THUNKS WITH NO `has_' FLAG, and that was
     measured, not assumed (scratchpad/t113-family.sh): all 48 cpu back ends
     define `MOVE_MAX' directly, and every other member has a `defaults.h'
     floor.  Crucially that floor is evaluated in THIS file's per-base
     translation unit, so a base with no `STORE_MAX_PIECES' gets the generic
     definition computed from ITS OWN `MOVE_MAX' -- not the primary's.  There
     is no absence to record, so a three-state flag here would be inventing a
     state that cannot occur; the pair below is where one is real.  */
  int (*move_max) (void);
  int (*move_max_pieces) (void);
  int (*store_max_pieces) (void);
  int (*compare_max_pieces) (void);
  int (*move_ratio) (bool speed);
  int (*clear_ratio) (bool speed);
  int (*set_ratio) (bool speed);

  /* This base's own `MAX_MOVE_MAX', recorded ONLY so that the bound and the
     index can be checked against each other.

     `caller-save.cc:55' sizes `regno_save_mem[][MAX_MOVE_MAX /
     MIN_UNITS_PER_WORD + 1]' from the PRIMARY's headers and then indexes it
     with `MOVE_MAX_WORDS', i.e. `MOVE_MAX / UNITS_PER_WORD', which the field
     above now makes the SELECTED base's.  That is exactly PRINCIPLES 3's
     "bound by one, indexed by another" -- the disguise that produced the
     `NUM_UNSPECV_VALUES' 114-vs-40 overrun.  Today i386's 64 is comfortably
     the larger and nothing overflows; recorded because it was checked, and
     checked at selection time so that the day it stops being true is a
     diagnostic naming the base rather than a corrupted array.  */
  int max_move_max;

  /* ------------------------------------------------------------------
     `DATA_ALIGNMENT' AND `DATA_ABI_ALIGNMENT' -- THE PAIR THAT IS BOTH AN
     EXISTENCE PREDICATE AND A STATE LEAK AT ONCE.

     i386.h:890 and :900 make both `ix86_data_alignment (TYPE, ALIGN, ...)'.
     `varasm.cc' spells each of them twice under `#ifdef', and `cp/rtti.cc'
     once.  i386 defines them, so in shared code those five `#ifdef's are TRUE
     for every target, and `align_variable' calls i386's function while
     compiling for aarch64 -- which defines neither macro and wants neither
     adjustment.

     THIS ONE FAILS ON `int x = 1;'.  Confirmed under gdb
     (scratchpad/t113-align-diag.sh), not inferred from the name, because a
     symbol's name does not tell you which macro pulled it in:

	 #0 ix86_data_alignment  <- align_variable <- varpool_node::analyze
	 => mov 0x190(%rax),%eax   with %rax == 0, si_addr == 0x190
	 ix86_tune_cost holds 0x0000000000000000

     `ix86_data_alignment' reads `ix86_tune_cost->prefetch_block'
     (i386.cc:18641) and 0x190 is that member's offset.  So it is the SAME
     mechanism as `MOVE_RATIO' -- an uninitialised back-end pointer -- but
     reached through a back-end FUNCTION CALL rather than by the macro body
     dereferencing anything itself.  A filter that looks only at macro bodies
     for `->' sees `MOVE_RATIO' and misses this entirely; both spellings
     count, and t113-armE2.sh reports them as KIND=STATE and KIND=FUNC.

     WHY THIS PAIR HAS THE THREE-STATE FLAG AND THE SEVEN ABOVE DO NOT.  Here
     absence is a real and common answer: only 31 back ends define
     `DATA_ALIGNMENT' and 5 define `DATA_ABI_ALIGNMENT', and `defaults.h'
     supplies no floor for either.  `false' is therefore legitimate and
     cannot double as "this table was built before the field existed", which
     is why it is recorded explicitly and cross-checked against the pointer
     rather than being spelled as a null.

     THE THUNKS RETURN `align' UNCHANGED FOR A BASE THAT HAS NEITHER, and
     that is NOT the `#ifndef' floor PRINCIPLES forbids.  It is the documented
     semantics -- i386.h's own comment says "If this macro is not defined,
     then ALIGN is used" -- and, decisively, it is computed in the base's own
     translation unit, so it is that base's answer and not the primary's.  It
     also makes four of the five call sites exactly equivalent to the code
     they replace: `align = align' is a no-op whichever branch runs, so the
     `#ifdef' can go and the call become unconditional.  The FIFTH,
     `cp/rtti.cc:1760', also sets `DECL_USER_ALIGN' inside the guard, so it
     is not identity-equivalent and keeps an explicit test of the flag.  That
     site is the reason the flag is load-bearing rather than decorative.  */
  bool has_data_alignment;
  unsigned int (*data_alignment) (tree type, unsigned int align);
  bool has_data_abi_alignment;
  unsigned int (*data_abi_alignment) (tree type, unsigned int align);
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

/* Replaces `#ifdef INIT_EXPANDERS / INIT_EXPANDERS;' at both of its sites in
   emit-rtl.cc.  Unconditional at the call site on purpose: the condition is
   per back end, so it belongs where the back end is known, not in shared code
   which cannot evaluate it correctly for anyone but the base it was compiled
   against.  */
extern void mt_init_expanders (void);

/* The move/clear family.  `defaults.h' points all seven macros at these for
   every translation unit that is not a back end's own.  */
extern int mt_move_max (void);
extern int mt_move_max_pieces (void);
extern int mt_store_max_pieces (void);
extern int mt_compare_max_pieces (void);
extern int mt_move_ratio (bool);
extern int mt_clear_ratio (bool);
extern int mt_set_ratio (bool);

/* `DATA_ALIGNMENT' / `DATA_ABI_ALIGNMENT'.  These are NOT redirected in
   `defaults.h': their five use sites are `#ifdef'-guarded, and a redirect
   would leave the guard being answered by the primary while the body was
   answered by the selected base -- the worst of both.  The sites call these
   directly and the `#ifdef's are gone, exactly as `mt_init_expanders'
   replaced `#ifdef INIT_EXPANDERS' rather than redirecting it.

   `mt_has_data_abi_alignment' is exported because `cp/rtti.cc' needs the
   predicate itself, not only the value; see target-frame.h's note above on
   why that site is not identity-equivalent.  */
extern unsigned int mt_data_alignment (tree, unsigned int);
extern unsigned int mt_data_abi_alignment (tree, unsigned int);
extern bool mt_has_data_abi_alignment (void);

#endif /* GCC_TARGET_FRAME_H */
