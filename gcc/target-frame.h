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
   already supplied from the same per-base translation unit, costs one pointer
   and no generator change.  The two structs
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

  /* This base's own `MAX_MOVE_MAX'.
     WARNING: NOTHING WRITES THIS FIELD AND NOTHING READS IT.

     `caller-save.cc:55' sizes `regno_save_mem[][MAX_MOVE_MAX /
     MIN_UNITS_PER_WORD + 1]' from the PRIMARY's headers and then indexes it
     with `MOVE_MAX_WORDS', i.e. `MOVE_MAX / UNITS_PER_WORD', which the field
     above now makes the SELECTED base's.  That is exactly PRINCIPLES 3's
     "bound by one, indexed by another" -- the disguise that produced the
     `NUM_UNSPECV_VALUES' 114-vs-40 overrun.

     THE PARAGRAPH THAT STOOD HERE CLAIMED A CHECK THAT DOES NOT EXIST.  It
     said this base's value was "checked at selection time so that the day it
     stops being true is a diagnostic naming the base rather than a corrupted
     array".  Measured 2026-08-13 by grepping the whole tree AND the generated
     build directory: `max_move_max' occurs exactly twice, both in this file --
     this declaration and the comment referring to it.  No initialiser, no
     reader, no assertion.  It is PRINCIPLES section 4's "presence of a
     mechanism is not evidence anything invokes it", and it reads as protection
     while providing none.

     WHAT THE NUMBERS ARE, so the next agent does not have to re-derive them.
     i386.h:1929 `MAX_MOVE_MAX 64' and i386.h:770 `MIN_UNITS_PER_WORD 4';
     aarch64 defines NEITHER, so its own answers come from the defaults.h
     floors -- `MAX_MOVE_MAX' = its `MOVE_MAX' = 16, `MIN_UNITS_PER_WORD' =
     its `UNITS_PER_WORD' = 8.  Shared code therefore sizes the array
     64 / 4 + 1 = 17 and aarch64 indexes it to 16 / 8 = 2.  Nothing overflows.

     IT IS CORRECT BY LUCK, AND THE LUCK IS NAMEABLE: the primary happens to
     supply BOTH the largest numerator and the smallest denominator.  The
     correct multi-target bound is max(MAX_MOVE_MAX) / min(MIN_UNITS_PER_WORD)
     + 1, and for this base pair that is also 64 / 4 + 1 = 17 -- the same
     number, which is why no measurement can currently tell the two apart.
     Convert either name alone and it stops being true: with aarch64's
     MIN_UNITS_PER_WORD of 8 as the denominator the bound becomes 16 / 8 + 1 =
     3 while i386 still indexes to 64 / 4 = 16.  So the two are a CLOSURE --
     `MAX_MOVE_MAX' unioned by MAXIMUM and `MIN_UNITS_PER_WORD' by MINIMUM,
     together or not at all -- and both are array bounds, so both must stay
     compile-time constants and neither may become an `mt_' call.  */
  int max_move_max;

  /* ------------------------------------------------------------------
     THE OPTION-STATE FAMILY: `UNITS_PER_WORD', `POINTER_SIZE',
     `BIGGEST_ALIGNMENT'.  MACRO-LEAK.md class (c2); the main body of the
     remaining "no shared TU includes tm.h" work by evaluation count.

     ALL THREE ARE OPTION STATE ON THE PRIMARY, which is what makes them the
     `Pmode' shape rather than the register shape:

	 i386.h:770   UNITS_PER_WORD     (TARGET_64BIT ? 8 : 4)
	 i386.h:766   POINTER_SIZE       (TARGET_64BIT ? 64 : 32)
	 i386.h:812   BIGGEST_ALIGNMENT  (TARGET_IAMCU ? 32 : ix86_biggest_alignment)
	 aarch64.h    UNITS_PER_WORD 8, POINTER_SIZE (TARGET_ILP32 ? 32 : 64),
		      BIGGEST_ALIGNMENT 128

     CALLS, NOT CACHED VALUES, AND THE REASON IS CORRECTNESS RATHER THAN
     TASTE.  `mavx' and `mavx512f' are `Save' in i386.opt, so
     `BIGGEST_ALIGNMENT' MOVES WITHIN ONE COMPILATION under
     `__attribute__((target("avx512f")))' -- and `stor-layout.cc' reads it
     while parsing, with no current function to hang a cache invalidation on.
     A value read once at selection time would be frozen at whatever the
     command line said, which is the exact failure `target-cdata.h' records
     for `STACK_BOUNDARY' and `target-cumargs-select.cc' records for `Pmode'.
     Caching here would be this branch's own bug, bought to save an overhead
     measured at the noise floor (see below).

     THE OVERHEAD WAS MEASURED, NOT ASSUMED.  `Pmode' has the identical shape
     and 648 shared sites; an isolation arm (one line changed, 715
     `call <mt_pmode>' sites -> 0, output identical on 19/19 TUs, 11
     interleaved runs) put its cost at <= 0.3%, at the noise floor.  This
     family is projected at <= 0.4%.  Static site count is the WRONG axis and
     has misled once: `UNITS_PER_WORD' has 41% as many static sites as `Pmode'
     and is evaluated 1.22x as often (4.31M vs 3.53M), with seven sites in
     `rtlanal.cc' carrying 84% of all evaluations.

     THE DERIVED CLOSURE IS LARGE AND IS PICKED UP BY ORDINARY MACRO
     EXPANSION, because `defaults.h' spells these names in the BODIES of
     eleven other definitions and a body is expanded at the use site, not at
     the point of definition.  Redirecting the three therefore also converts

	 BITS_PER_WORD  DWARF2_ADDR_SIZE  POINTER_SIZE_UNITS  SHORT_TYPE_SIZE
	 DWARF_CIE_DATA_ALIGNMENT  MAX_OFILE_ALIGNMENT  ATTRIBUTE_ALIGNED_VALUE
	 TARGET_VTABLE_ENTRY_ALIGN  STACK_CHECK_FIXED_FRAME_SIZE
	 REGMODE_NATURAL_SIZE (regs.h:31)  MIN_UNITS_PER_WORD

     -- 354 further shared sites for `BITS_PER_WORD' alone.  That is a
     benefit, not a hazard, EXCEPT for the last name; see the closure note.

     SWEPT FOR POSITION BEFORE REDIRECTING (scratchpad/t141-pos.sh and
     t141-const.sh, over all of `gcc/' outside `config/', `testsuite/' and
     `ada/gcc-interface/'), across the three names AND every derived name
     above.  Result: not one `#if'/`#elif'/`#ifdef' line in shared code names
     any of them except the `#ifndef' fallbacks in `defaults.h' and `regs.h'
     that define them in the first place, and which this redirect follows.  No
     `case' label, no `static_assert', no enumerator, no namespace-scope
     initialiser.  The bracket sweep returns nine hits and all nine are
     subscripts of RUN-TIME arrays or prose inside comments -- `dst_words[
     xbitpos / BITS_PER_WORD]' (expr.cc), `splitting[...]' (lower-subreg.cc),
     `integer_types[...]' (cp/rtti.cc) -- which a call-valued macro serves
     correctly.  There are exactly TWO real array bounds in the whole closure
     and they are the closure note below.

     THE CLOSURE, AND IT IS THE `MAX_MOVE_MAX' ONE ALREADY DOCUMENTED ABOVE.
     `defaults.h:1120' is `#define MIN_UNITS_PER_WORD UNITS_PER_WORD', and
     `caller-save.cc:55' / `reload.h:179' use `MIN_UNITS_PER_WORD' as an ARRAY
     BOUND, which cannot hold a call.  Today the redirect cannot reach those
     two sites -- i386.h:770 defines `MIN_UNITS_PER_WORD' as a literal 4, so
     `defaults.h''s `#ifndef' does not fire in shared code and the bound stays
     a constant.  THAT IS A FACT ABOUT WHICH BACK END IS THE PRIMARY, which is
     the thing this project exists to stop depending on, so it is asserted
     rather than relied on: `target-cumargs-select.cc' carries a
     `static_assert' beside the existing `MAX_MOVE_MAX' one, and the day the
     primary stops defining `MIN_UNITS_PER_WORD' the build fails BY NAME
     instead of `caller-save.cc' failing with "call to non-constexpr".

     AND THE INDEX SIDE MOVES WITH IT, WHICH IS WHY THIS IS A CLOSURE AND NOT
     A LONE ASSERT.  That array is indexed by `MOVE_MAX_WORDS', i.e.
     `MOVE_MAX / UNITS_PER_WORD' -- and this change makes the DENOMINATOR the
     selected base's.  The existing guard in `mt_move_max' checks only the
     numerator (`mm > MAX_MOVE_MAX'), which was sufficient while the
     denominator was the primary's constant and is NOT sufficient now: a base
     with a large `MOVE_MAX' and a small `UNITS_PER_WORD' produces an index
     the numerator test passes.  `mt_move_max' therefore now checks the
     computed INDEX against the computed BOUND.  Converting `UNITS_PER_WORD'
     and leaving that guard on the numerator is precisely the "convert one
     member of a closure" failure PRINCIPLES section 4 names -- it would have
     left the overrun possible while looking guarded.  */
  int (*units_per_word) (void);
  unsigned int (*pointer_size) (void);
  unsigned int (*biggest_alignment) (void);

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

  /* PROMOTE_MODE (MODE, UNSIGNEDP, TYPE) -- how a narrow integer is widened
     when it is held in a register.

     THE TWO DEFINITIONS DISAGREE ABOUT EXACTLY SImode, WHICH IS THE ONE THAT
     MATTERS ON A 64-BIT TARGET.  `riscv.h:298' promotes any integer narrower
     than a word to `word_mode' and, for SImode specifically, forces
     `UNSIGNEDP = 0' -- that is the "SImode values are kept sign-extended in
     registers" invariant the whole back end is written against.
     `i386.h:1991' promotes only HImode and QImode, only under
     `TARGET_PROMOTE_HI_REGS' / `TARGET_PROMOTE_QI_REGS', and says nothing
     about SImode at all.

     Read at `explow.cc:937' (inside `promote_mode') and `function.cc:980,
     990, 1030', all four under `#ifdef PROMOTE_MODE'.  The shared `tm.h' is
     i386's, so every base got i386's rule and riscv64's sign-extension
     invariant did not exist as far as the middle end was concerned.  Measured
     symptom (`gcc.target/riscv/zbb-sext.c'): stock emits `sext.b a0,a0' and
     `sext.h a0,a0'; multi-target emitted NEITHER, i.e. it returned a value it
     had not sign-extended.  That is wrong code, not slower code.

     A `has_' FLAG AND NOT A NULL CHECK, and not an identity thunk either.
     16 of the 47 bases define no `PROMOTE_MODE', and for those the four use
     sites must compile OUT exactly as upstream's `#ifdef' does -- promoting
     nothing is not the same as promoting to the same mode, because
     `function.cc:1030' also consults `unsignedp' afterwards.  So the flag is
     load-bearing and the guards become `if (mt_has_promote_mode ())'.

     `scalar_mode *' AND NOT `machine_mode *', WHICH THE BUILD DECIDED RATHER
     THAN TASTE.  `aarch64.h:58' spells `GET_MODE_SIZE (MODE) < 4', and
     `GET_MODE_SIZE' returns a plain `unsigned short' for a `scalar_mode' and
     a `poly_uint16' for a `machine_mode' -- so with the wider type it does
     not compile at all ("no match for `operator<' ... poly_uint16 and int").
     The macro is written against the one type upstream ever expands it with:
     `explow.cc' narrows to `smode' with `as_a <scalar_mode>' BEFORE the
     expansion. Widening the boundary type here silently changed what the
     macro means to every back end that measures a mode.

     Passed by pointer because the macro ASSIGNS to both of its first two
     arguments.  `tree' and `scalar_mode' are both available: this header is
     reached after `coretypes.h', unlike `target-insn.h', and the fields above
     already take `tree' and `machine_mode' (lines 88, 94, 395).  */
  bool has_promote_mode;
  void (*promote_mode) (scalar_mode *mode, int *unsignedp, const_tree type);

  /* ------------------------------------------------------------------
     THE STACK-ALIGNMENT CLOSURE -- FOUR NAMES, AND THE ONE THAT ACTUALLY
     STOPS `big.c' IS NOT THE ONE THE SYMBOL NAMES.

     `nm -uC cfgexpand.o' reports `U ix86_incoming_stack_boundary' and nothing
     else in this family, so `INCOMING_STACK_BOUNDARY' is the name the
     instrument hands you.  It is a real leak -- i386.h:803 makes it that
     global, i386 is the ONLY one of the 48 back ends that defines the macro,
     and `defaults.h:944's `#ifndef' is therefore false in shared code for
     every target, so all 47 others read i386's option state.

     BUT IT IS NOT WHY `expand_stack_alignment' IS ENTERED.  cfgexpand.cc:6895
     is `if (! SUPPORTS_STACK_ALIGNMENT) return;', and defaults.h:1256 makes
     that `(MAX_STACK_ALIGNMENT > STACK_BOUNDARY)'.  `MAX_STACK_ALIGNMENT' is
     defined by exactly three headers -- i386.h:850, i386/cygming.h:42 and
     nvptx.h:61 -- so defaults.h:1249's `#ifdef' is TRUE in shared code
     because the primary is i386, and every target gets i386's
     `MAX_OFILE_ALIGNMENT' (2^31 from elfos.h:63).  aarch64 defines no
     `MAX_STACK_ALIGNMENT', so its own answer is defaults.h:1252's
     `STACK_BOUNDARY', 128, and `SUPPORTS_STACK_ALIGNMENT' should be
     `128 > 128' -- FALSE.  The function should return at its second line and
     never reach line 6941's `gcc_assert (targetm.calls.get_drap_rtx != NULL)'
     at all.  DRAP is an i386 concept; aarch64 supplies no `get_drap_rtx'
     because it never asked to be here.

     SO CONVERTING `INCOMING_STACK_BOUNDARY' ALONE WOULD HAVE BEEN THE HALF-FIX
     PRINCIPLES 2a NAMES.  aarch64 would still enter the function, still be
     asked to realign a stack it does not realign, and the 6941 assert would
     still be reached -- or, worse, `INCOMING_STACK_BOUNDARY' would now answer
     128 and `crtl->stack_alignment_estimated' would happen to be <= 128, the
     assert would pass, and aarch64 would silently run i386's stack-realignment
     path with `stack_realign_needed' false.  A loud failure traded for a quiet
     one.  All four move together.

     WHY `MAX_SUPPORTED_STACK_ALIGNMENT' AND `SUPPORTS_STACK_ALIGNMENT' ARE
     THEIR OWN FIELDS RATHER THAN BEING DERIVED FROM THE OTHER TWO.  Both
     could be spelled in `defaults.h' as arithmetic over the redirected
     `MAX_STACK_ALIGNMENT' and `STACK_BOUNDARY', and it would even give the
     right answer.  It would also re-derive, in shared code, a choice that
     defaults.h:1249 makes with an `#ifdef' -- and the `#ifdef' is precisely
     the thing shared code cannot evaluate.  A base WITH `MAX_STACK_ALIGNMENT'
     has `MAX_SUPPORTED == MAX_STACK_ALIGNMENT'; a base WITHOUT has
     `MAX_SUPPORTED == PREFERRED_STACK_BOUNDARY', which is NOT equal to its
     `MAX_STACK_ALIGNMENT' (`STACK_BOUNDARY') whenever the two boundaries
     differ.  Deriving would silently pick one arm for everyone.  Each thunk
     below is one macro expansion in the base's own translation unit, so the
     `#ifdef' is consumed where it is meaningful and neither arm is preferred
     here.

     NO `has_' FLAG ON ANY OF THE FOUR, and that is a measured claim rather
     than an omission: `defaults.h' gives all four an unconditional definition
     by the time the per-base translation unit reaches the table, both arms of
     the :1249 `#ifdef' included.  There is no absence to record.  The
     existence question does not disappear -- it is answered inside the base's
     own preprocessing, which is the whole mechanism.

     BOUND-VS-INDEX, CHECKED RATHER THAN ASSUMED.  These are boundary
     constants, which is the shape that produced `NUM_OPTAB_PATTERNS' and
     `N_REG_CLASSES'.  Swept: outside `config/' nothing is dimensioned by any
     of the four.  `MAX_STACK_ALIGNMENT' has exactly one shared use
     (tree-vect-data-refs.cc:6808, a `known_le' comparison);
     `MAX_SUPPORTED_STACK_ALIGNMENT' has 21, all comparisons or assignments to
     an `unsigned int'; `SUPPORTS_STACK_ALIGNMENT' has 11, all `if'
     conditions; `INCOMING_STACK_BOUNDARY' has 2, both in cfgexpand.cc above.
     No `#if', no case label, no array bound, no static initialiser -- which
     is what makes a call-valued redirect legal at all.

     THE TYPES ARE `unsigned int' AND THAT IS NOT COSMETIC.  i386.h:2614
     declares `ix86_incoming_stack_boundary' `unsigned int', and i386's
     `MAX_STACK_ALIGNMENT' is elfos.h:63's `(((unsigned int) 1 << 28) * 8)' --
     2147483648, which does not fit in `int'.  Returning that through an `int'
     field would be implementation-defined narrowing on the single member
     whose entire job is to be an upper bound.  It also removes, rather than
     relocates, the pre-existing `-Wsign-compare' on `SUPPORTS_STACK_ALIGNMENT'
     (48 occurrences in a cold log), which came from comparing that unsigned
     constant with a signed `STACK_BOUNDARY'.

     ONE CONSEQUENCE WORTH WRITING DOWN.  asan.cc:1573 asserts
     `BITS_PER_UNIT * ASAN_SHADOW_GRANULARITY <= MAX_SUPPORTED_STACK_ALIGNMENT'
     -- 64 <= the value.  It has been comparing against i386's 2^31 for every
     target and could not fail.  It now compares against the selected base's
     answer (aarch64: 128, so still true).  A back end whose
     `PREFERRED_STACK_BOUNDARY' is below 64 would newly trip it.  That is the
     assert doing its job for the first time, not a regression introduced
     here.  */
  unsigned int (*incoming_stack_boundary) (void);
  unsigned int (*max_stack_alignment) (void);
  unsigned int (*max_supported_stack_alignment) (void);
  bool (*supports_stack_alignment) (void);

  /* ------------------------------------------------------------------
     THE ELIMINATION TABLE -- A LIST WHOSE LENGTH AND WHOSE CONTENTS ARE BOTH
     THE PRIMARY'S, AND WHOSE CONTENTS ARE REGISTER NUMBERS.

     `ELIMINABLE_REGS' is a brace initialiser, so no macro carries its length:
     `reload1.cc:280', `lra-eliminations.cc:107', `ira.cc:2535', `rtlanal.cc:352',
     `varasm.cc:1460', `stmt.cc:208', `df-scan.cc:3819' and `builtins.cc:956'
     each recover it by declaring a file-scope array from the macro and taking
     `ARRAY_SIZE'.  All eight are shared translation units, so all eight hold
     the PRIMARY's pairs.

     `nm -uC' names `ix86_initial_elimination_offset' in `ira.o', `reload1.o'
     and `rtlanal.o'.  As always that is the symbol INITIAL_ELIMINATION_OFFSET
     drags in, not the whole fault: the numbers handed to it come from this
     table, and

	 ARG_POINTER_REGNUM         i386 16   aarch64 65
	 FRAME_POINTER_REGNUM       i386 19   aarch64 64
	 STACK_POINTER_REGNUM       i386  7   aarch64 31
	 HARD_FRAME_POINTER_REGNUM  i386  6   aarch64 29

     so `ira_setup_eliminable_regset' asks `targetm.can_eliminate (16, 7)' of
     aarch64, whose `aarch64_can_eliminate' asserts the FROM is one of its own
     two -- `aarch64.cc:14153', the wall this converts.  BOTH BASES HAVE FOUR
     PAIRS, so a length check alone would have scored this leak as absent;
     `vax.h:314' has one pair and `rs6000.h:1614' six, so the length is a real
     variable and not a constant nobody happened to vary.

     THE LOOPS TAKE THE COUNT BELOW; THE LAYOUT TAKES THE UNION.
     `reload1.cc:318' is `static poly_int64 (*offsets_at)[NUM_ELIMINABLE_REGS]'
     -- a pointer-to-ARRAY type, which cannot hold a run-time count -- and
     `reload1.cc:4032' allocates with the same stride.  That is PRINCIPLES 3's
     "sized by one authority, indexed by another" again, so those two spell
     `MULTI_TARGET_UNION_NUM_ELIMINABLE_REGS' (measured per base by
     `multi-target-reg-probe.cc' and maximised by `gen-reg-widths.sh', exactly
     as the register and class widths are) while every loop bound spells
     `mt_num_eliminable_regs ()'.  The two are cross-checked: target-cumargs.cc
     static_asserts this base's own count against the union bound, so a base
     that outgrows it is a compile error naming that base rather than a write
     past the end of `offsets_at'.

     WHY TWO TABLES.  `reload1.cc' uses `RELOAD_ELIMINABLE_REGS' when a back
     end defines one and `ELIMINABLE_REGS' otherwise -- reload and LRA disagree
     about multi-register frame pointers (see the comment at reload1.cc:285) --
     while every other consumer uses `ELIMINABLE_REGS'.  That `#ifdef' is a
     question about the SELECTED base, so it is answered in the per-base
     translation unit and its result recorded here, rather than being asked
     of the primary's headers in `reload1.cc'.  No in-tree back end currently
     defines `RELOAD_ELIMINABLE_REGS' (checked by grep over all of `config/'),
     so `d_reload_eliminables' equals `d_eliminables' for both configured
     bases today; it is a separate field because the day one does define it is
     the day a single field silently gives reload LRA's table.

     FLATTENED, `{from, to}' PER PAIR: pair I is `d_eliminables[2 * I]' ->
     `d_eliminables[2 * I + 1]'.  `n_eliminables' counts PAIRS, not ints --
     stated because a count that could be read either way is the shape that
     produced `NUM_UNSPECV_VALUES'.  Shared code never indexes these directly;
     it goes through `mt_eliminable_from' / `mt_eliminable_to', which range
     check.  */
  int n_eliminables;
  const int *d_eliminables;
  int n_reload_eliminables;
  const int *d_reload_eliminables;

  /* INITIAL_ELIMINATION_OFFSET (FROM, TO, OFFSET), as a function returning the
     offset.  Every back end's is a statement that assigns through its third
     argument, so it is wrapped rather than named -- the same reason
     `ADJUST_REG_ALLOC_ORDER' is wrapped in target-regs.cc.

     `poly_int64' is nameable here because this header is reached from
     `defaults.h' only in C++ translation units that already have
     `coretypes.h' -- the same property that lets the fields above take `tree'
     and `machine_mode'.  It is ONE type across the whole compiler:
     `NUM_POLY_INT_COEFFS' is a UNION quantity (genmodes.cc:2206 emits
     `union_poly_int_coeffs'), measured 2 in this build, so a back end's own
     object and a shared object agree on the layout.  Were it still per base
     this field would be an ABI mismatch rather than a fix, which is why it is
     recorded.  */
  poly_int64 (*initial_elimination_offset) (int from, int to);

  /* `Pmode' -- the mode of an address.  MACRO-LEAK.md class (c4).

     THIS ONE IS THE SILENT-DEFAULT VARIANT OF THE LEAK, AND THAT IS WHY IT IS
     WORSE THAN THE USUAL SHAPE.  i386 spells it

         #define Pmode (ix86_pmode == PMODE_DI ? DImode : SImode)   i386.h:2001

     and `ix86_pmode' is an OPTION variable, `Init (PMODE_SI)' at
     i386.opt:314, set to PMODE_DI by `ix86_option_override' -- which runs
     only when i386 is the SELECTED target.  So in a shared translation unit
     compiling FOR AARCH64 the expression is not "the primary's answer" in the
     usual sense of x86_64's DImode; it is the primary's UNCONFIGURED DEFAULT,
     SImode, which is not the right answer for either configured base.  A leak
     that at least served the primary's real value would have produced DImode
     here by luck and hidden this for another release.

     MEASURED, NOT INFERRED (scratchpad/t125-cause.sh, gdb on the running cc1,
     one breakpoint per run, the frame gdb reports matched against the ICE's
     own backtrace).  At the failing call, frame #1 = `aarch64_expand_prologue':

         mode_arg = 27 = DImode   <- aarch64's own Pmode, from aarch64.h:1441
         mode_of_x = 26 = SImode  <- stack_pointer_rtx, built in emit-rtl.cc

     `stack_pointer_rtx' is `gen_raw_REG (Pmode, STACK_POINTER_REGNUM)' at
     emit-rtl.cc:6266 -- a SHARED translation unit, so it took i386's default
     -- and `explow.cc:102' asserts `GET_MODE (x) == mode'.  On the x86_64 side
     the same instrument reads 27 and 27 and finds no mismatching call
     anywhere, so this is a divergence and not "everyone got the same answer".

     A FUNCTION AND NOT A CONSTANT, for the reason the whole struct is
     functions: i386's answer varies with option state within one compilation.
     Freezing it at startup is the bug this header's opening comment
     describes.

     `scalar_int_mode' AND NOT `machine_mode' is deliberate.  `Pmode' today
     yields a `scalar_int_mode' in C++ (both bases' definitions are built from
     `DImode' / `SImode', which are `scalar_int_mode' objects), and generic
     code relies on that type at sites such as `GET_MODE_PRECISION (Pmode)'.
     Returning `machine_mode' would compile at the definition and fail, or
     silently pick a different overload, hundreds of sites away.  */
  scalar_int_mode (*pmode) (void);

  /* `FUNCTION_MODE' -- the mode of the MEM that a call jumps through.  QImode
     for i386 (i386.h:2028), `Pmode' (i.e. DImode) for aarch64
     (aarch64.h:1450).  MACRO-LEAK.md class (b), and the diagnosed cause of the
     `extract_insn, recog.cc:2890' wall that `int g (int a) { return f (a) +
     f (a + 1); }' hit for aarch64.

     WHAT THE ICE ACTUALLY WAS, from the insn the compiler printed rather than
     from the site it stopped at.  `calls.cc:415' -- shared code -- builds

	 funmem = gen_rtx_MEM (FUNCTION_MODE, funexp);

     so with i386's tm.h in force every target's call goes through a
     `mem:QI'.  The insn that reached `vregs' was

	 (call (mem:QI (symbol_ref:DI ("f") ...) [0 f S1 A8]) (const_int 0))

     -- note `S1', one byte -- while every one of aarch64's call patterns
     (aarch64.md:1563, :1591, :1630, :1646) matches `(call (mem:DI ...))'.  So
     aarch64's own `recog' correctly refused an insn that shared code had built
     to i386's shape.  THIS IS A SECOND, DISTINCT PROBLEM from the attribute
     tables #130 selected, which is what #127 warned it might be: nothing about
     it involves `HAVE_ATTR_*', unspec numbering, or the recog dispatcher --
     `recog' was already per-base and was already aarch64's.  It is one macro.

     A CALL AND NOT A `target-cdata' CONSTANT even though both configured bases
     spell it as a plain mode.  Eight back ends define it as `Pmode', which on
     this branch is already a run-time call (`mt_pmode'), and arm's `Pmode' is
     option state; a constant read once at startup would freeze it.  Measured
     on this pair only, a constant would have been green and wrong for arm --
     the failure mode recorded for the four pointer regnums.

     `machine_mode' AND NOT `scalar_int_mode', unlike `pmode' directly above.
     The two are not the same question: `Pmode' is required to be a scalar
     integer and generic code calls `GET_MODE_PRECISION' on it, whereas
     `FUNCTION_MODE' is only ever handed to `gen_rtx_MEM', `memory_address',
     `SET_DECL_MODE' and `small_register_classes_for_mode_p', all of which take
     a `machine_mode'.  Narrowing the type here would add an `as_a' assertion
     no use site needs and that nothing in the vocabulary guarantees.

     SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE LANDING.  Outside `config/'
     and `testsuite/' there are eleven use sites -- calls.cc:298, :299, :300,
     :413, :415, builtins.cc:1778, :1783, :1808, expr.cc:11656, varasm.cc:3329
     and tree.cc:1352 -- and every one is an ordinary run-time argument.  No
     `#if', no `#ifdef', no case label, no array bound, no static initialiser.
     Note the eleventh: `SET_DECL_MODE (t, FUNCTION_MODE)' is executed while
     building a FUNCTION_DECL, which is why this is a call the front end can
     reach; `-ftarget-config' is processed during option handling, before any
     parsing, so a target is in force by then, and if one somehow is not this
     fails by name rather than answering QImode.  */
  machine_mode (*function_mode) (void);

  /* `DEBUGGER_REGNO (N)' -- gcc register number to debugger/DWARF register
     number.  MACRO-LEAK.md class (c1).  THIS IS THE `BOUND BY ONE, INDEXED BY
     ANOTHER' DISGUISE, the sixth time it has appeared on this branch
     (`NUM_OPTAB_PATTERNS' 2975 vs 3328, `N_REG_CLASSES' 34 vs 20, the
     allocation-order table, the eliminables table, `NUM_UNSPECV_VALUES').

     The effective i386 definition for an ELF/linux host is gnu-user.h:30, not
     i386.h:2154 -- worth naming, because the two differ and only one of them
     is the one that runs:

         #define DEBUGGER_REGNO(n) \
           (TARGET_64BIT ? debugger64_register_map[n] : svr4_debugger_register_map[n])

     with both arrays declared `[FIRST_PSEUDO_REGISTER]' at i386.h:2157-2159 --
     i.e. dimensioned in i386's OWN translation unit, where that name is 92.
     Shared code spells the same name at the UNION width, 95
     (`multi-target-reg-widths.h'), and hands it the SELECTED back end's
     register numbers.  aarch64's own answer is a function,
     `aarch64_debugger_regno' (aarch64.h:835, aarch64.cc:1550).

     MEASURED (scratchpad/t126-cause.sh, gdb on the running cc1, one breakpoint
     per run, and the breakpoint gdb ITSELF reports matched against the
     function under test):

         Breakpoint 1, update_row_reg_save (... column=4294967294 ...)
                       at dwarf2cfi.cc:540

     4294967294 is `IGNORED_DWARF_REGNUM' (rtl.h:4172, `INVALID_REGNUM - 1'),
     which is what BOTH i386 maps hold at indices 16..19 -- i386's arg, flags,
     fpsr and frame pseudo-registers.  aarch64 x16..x19 are ordinary
     callee-clobbered/callee-saved registers that a prologue really does save,
     so `dwf_regno' returned -2 and `update_row_reg_save' tried to
     `vec_safe_grow_cleared' to four billion entries: `cc1 terminated by signal
     9' on a 150-line input.  The x86_64 arm of the same instrument finds no
     column over 1000 in a run that reaches exit, so this is a divergence and
     not "everyone got the same answer".

     THE BRIEF FOR THIS CHANGE ALSO CLAIMED A SECOND, OPTION-STATE LEAK HERE --
     that `TARGET_64BIT' is i386 option state and so, like `Pmode' before it,
     silently selects the 32-BIT map while compiling for aarch64.  MEASURED
     FALSE, and recorded rather than quietly dropped.  At the same breakpoint:

         global_options.x_ix86_isa_flags = 18
         TARGET_64BIT                    = 1

     18 is `OPTION_MASK_ISA_64BIT | OPTION_MASK_ABI_64', which is exactly
     `TARGET_64BIT_DEFAULT' from `config/i386/biarch64.h:28' -- the `Init' of
     `ix86_isa_flags' at i386.opt:26.  So unlike `ix86_pmode', whose `Init' is
     `PMODE_SI' and which only `ix86_option_override' promotes, this option's
     unconfigured default is ALREADY the 64-bit one, and the 64-bit map is the
     one being read.  The macro is still option-dependent -- which is why this
     field is a CALL and not a `target-cdata' constant, and why a `-m32' on the
     command line would move it -- but the silent-default shape that made
     `Pmode' worse than an ordinary leak is NOT present here.  One leak in this
     macro, not two.

     WHAT THE OUT-OF-RANGE ANSWER IS, AND WHY IT IS NOT ZERO.  Shared code
     legitimately asks about register numbers the selected back end does not
     have: `expand_builtin_init_dwarf_reg_sizes' (dwarf2cfi.cc:334) walks
     `0 .. FIRST_PSEUDO_REGISTER' at the UNION width, so with i386 selected it
     asks about 92, 93 and 94.  The per-base thunk answers `INVALID_REGNUM'
     there -- the vocabulary's own "this has no DWARF register" sentinel,
     which `init_one_dwarf_reg_size' already filters at dwarf2cfi.cc:302 with
     `if (rnum >= DWARF_FRAME_REGISTERS) return;'.

     ZERO WOULD HAVE BEEN THE ATTRACTIVE WRONG ANSWER, for the third time on
     this branch (it read as "free" in a cost table and "no registers" in a
     class table).  DWARF register 0 is a REAL register on both bases -- %rax
     and x0 -- so a zero fill would have silently attributed every nonexistent
     register's unwind information to the first one.  */
  unsigned int (*debugger_regno) (unsigned int regno);

  /* `DWARF_FRAME_REGNUM (N)'.  A SEPARATE FIELD RATHER THAN DERIVED FROM THE
     ONE ABOVE, and the reason is the failure mode this branch keeps meeting:
     a `#ifndef' answered by the primary.

     defaults.h:560 says `#ifndef DWARF_FRAME_REGNUM' -> `DEBUGGER_REGNO', and
     in shared code that `#ifndef' is answered by i386's headers, which do not
     define it.  But it is a question each back end answers for itself, and
     they do not all answer the same way: `config/i386/cygming.h:89' defines a
     DWARF_FRAME_REGNUM that is deliberately DIFFERENT from its DEBUGGER_REGNO
     (always the svr4 map, whatever the debug format), and aarch64.h:840
     defines one that is the same.  Deriving it here would bake i386-on-linux's
     "they are the same" into every back end and lose cygming's distinction
     with no diagnostic -- the `unsupplied hook' disguise.  Asked in the base's
     own translation unit, each back end's own `#ifndef' answer is the one that
     is recorded.  */
  unsigned int (*dwarf_frame_regnum) (unsigned int regno);

  /* `DWARF_FRAME_REGISTERS' -- one past the last valid DWARF frame register,
     i.e. the BOUND against which the two above are checked.  17 for i386
     (i386.h:997), 97 for aarch64 (aarch64.h:832).  MACRO-LEAK.md class (b).

     IN THE CLOSURE, AND THAT IS THE WHOLE REASON IT IS HERE.  Converting only
     `DEBUGGER_REGNO' would leave dwarf2cfi.cc:302

         if (rnum >= DWARF_FRAME_REGISTERS) return;

     comparing aarch64's correct DWARF numbers (0..96) against i386's 17, so
     every aarch64 register above 16 would be dropped from the register-size
     table -- a QUIETER wrong answer than the one being fixed, produced BY the
     fix.  PRINCIPLES section 4 names that shape ("a loud failure turned
     quiet") and records that it has nearly happened three times.

     Only two shared sites spell it -- dwarf2cfi.cc:302 and
     c-family/c-cppbuiltin.cc:1630, which defines
     `__LIBGCC_DWARF_FRAME_REGISTERS__' -- and neither is a constant-expression
     context, so a call is legal here.  Note the second one: it is the value
     libgcc's unwinder is compiled with, so leaving it as i386's 17 would have
     shipped a wrong bound into every target's `libgcc_eh'.  A function and not
     a constant because cygming.h:96 makes it `(TARGET_64BIT ? 33 : 17)'.  */
  unsigned int (*dwarf_frame_registers) (void);

  /* DWARF_FRAME_RETURN_COLUMN.  MOVED HERE OUT OF `target-cdata', AND IT IS
     THE ONLY CDATA FIELD THAT EVER HAD TO MOVE.

     It reads like a per-target constant -- i386 says `(TARGET_64BIT ? 16 : 8)',
     m68k says 24 -- and it was a `target_cdata' NUM field on that reading.  It
     is not one, because of exactly one back end:

	 epiphany.h:544  EPIPHANY_RETURN_REGNO
			   ((current_function_decl != NULL
			     && epiphany_is_interrupt_p (current_function_decl))
			    ? IRET_REGNUM : GPR_LR)
	 epiphany.h:559  DWARF_FRAME_RETURN_COLUMN
			   DWARF_FRAME_REGNUM (EPIPHANY_RETURN_REGNO)

     `target-cdata.cc' is evaluated ONCE, at selection time, with
     `current_function_decl' null; all eight shared readers are in
     `dwarf2cfi.cc's per-function CFI, where upstream has that decl SET.  A
     cached field therefore answers `GPR_LR' for every epiphany interrupt
     handler -- a wrong CFI return column, emitted silently.

     It belongs beside the two fields above rather than in a new registry: it
     is *defined* in terms of them (epiphany, arm, aarch64, sparc, cris, ...
     all spell `DWARF_FRAME_REGNUM (something)'), and defaults.h's fallback for
     a base that defines neither is `DWARF_FRAME_REGNUM (PC_REGNUM)' or
     `DWARF_FRAME_REGISTERS' -- both of which are answered in the per-base
     translation unit, so a base with no macro of its own contributes its own
     generic answer here rather than the primary's.

     `unsigned short' in the old field, `unsigned int' here, to match the two
     above and the `dwf_regno' / `DWARF2_FRAME_REG_OUT' arguments it is
     compared against; every definition in the tree is a small register number
     and none is negative.  */
  unsigned int (*dwarf_frame_return_column) (void);

  /* `DWARF2_UNWIND_INFO' -- does this back end have DWARF 2 frame unwind at
     all.  THE CAUSE OF #208: aarch64 emitted NO CFI WHATSOEVER, and silently
     disabled `-freorder-blocks-and-partition', from this one missing answer.

     It sits beside the three fields above because it is the same question
     asked one level up: those say how to NUMBER a frame register, this says
     whether there is a frame description to number at all.  And it is
     literally derived from a sibling of theirs -- `defaults.h:418' is

	 #if !defined (DWARF2_UNWIND_INFO) && defined (INCOMING_RETURN_ADDR_RTX)
	 #define DWARF2_UNWIND_INFO 1

     i.e. the answer is `does this base define INCOMING_RETURN_ADDR_RTX',
     which #194 already made a per-base fact on this very struct
     (`has_incoming_return_addr_rtx').  The family had form and this was the
     member still missing.

     WHY THE ANSWER HAD GONE MISSING, because the shape recurs.  The only
     shared consumer is `default_except_unwind_info'
     (`common/common-targhooks.cc:41'), and it reads the macro as

	 #ifdef DWARF2_UNWIND_INFO
	   if (DWARF2_UNWIND_INFO)
	     return UI_DWARF2;
	 #endif
	 return UI_SJLJ;

     `953cf9eda76' deleted that file's `#include "tm.h"'.  Nothing broke,
     nothing warned, and the `#ifdef' silently became FALSE -- so every back
     end without a `TARGET_EXCEPT_UNWIND_INFO' of its own started answering
     UI_SJLJ.  That is PRINCIPLES section 4's "`#if FOO' on an undefined FOO
     evaluates to false" trap, and note that the sweep which removed the line
     had a guard AGAINST exactly it: it required the TU to have genuinely lost
     `tm.h'.  That guard asks whether the amputation HAPPENED, not whether a
     conditional CHANGED SIDES, so it could not have fired here.  Before it,
     the file was reading i386's `DWARF2_UNWIND_INFO' for all 47 back ends --
     a leak that happened to give aarch64 the right answer, which is why the
     removal reads as the regression and the leak does not.

     A POD, NOT A CALL.  Every definition of the macro in the tree is a
     preprocessor constant (`aarch64.h:844' 1, `epiphany.h:553' 0,
     `i386/cygming.h:369/371' selected by `#ifdef'), so there is no option
     state to read and none of the `Pmode' caching trap applies.  Back ends
     whose answer really is computed -- arm, c6x, ia64, i386 -- supply
     `TARGET_EXCEPT_UNWIND_INFO' in their own `<be>-common.cc' and never reach
     this field at all.

     `0' FOR A BASE THAT DEFINES NEITHER MACRO IS THAT BASE'S OWN ANSWER, not
     a floor.  `nvptx' and `pdp11' define no `INCOMING_RETURN_ADDR_RTX' and no
     `DWARF2_UNWIND_INFO', so upstream's `#ifdef' is false for them standing
     alone and `default_except_unwind_info' returns UI_SJLJ.  This field
     reproduces that, in the base's own translation unit, and no base can read
     another's.  PRINCIPLES section 2a's supply-side test: a second configured
     back end cannot change it.  */
  int (*dwarf2_unwind_info) (void);

  /* ----------------------------------------------------------------------
     THE FOUR `*_POINTER_REGNUM' NAMES, PLUS THE TWO DERIVED PREDICATES.
     MACRO-LEAK.md class (d), and the fork that #124 and #126 both stopped at
     rather than guessing.

     THE VALUES, WHICH ARE THE BUG:

	 STACK_POINTER_REGNUM        i386  7   aarch64 31
	 HARD_FRAME_POINTER_REGNUM   i386  6   aarch64 29
	 FRAME_POINTER_REGNUM        i386 19   aarch64 64
	 ARG_POINTER_REGNUM          i386 16   aarch64 65

     ALL SIX MOVE TOGETHER BECAUSE THEY ARE A CLOSURE.  `emit-rtl.cc' builds
     `stack_pointer_rtx', `frame_pointer_rtx', `hard_frame_pointer_rtx' and
     `arg_pointer_rtx' from all four in SHARED code, and `dwarf2cfi.cc:3250'
     and `:3309' hand two of those rtxes straight to `dwf_cfa_reg', i.e. to
     `DEBUGGER_REGNO'.  Converting `STACK_POINTER_REGNUM' alone -- the only one
     of the four that was free of `#if' arithmetic, and therefore the tempting
     one -- would have made `stack_pointer_rtx' correct while
     `hard_frame_pointer_rtx' stayed at i386's 6: a HALF-RIGHT CFA, which is a
     quieter wrong answer than the one being fixed.  PRINCIPLES section 4
     records that "convert one member of a closure, leave its siblings" has
     nearly landed three times.

     WHAT THE ICE ACTUALLY WAS, and it is the plainest instance of the shared-
     numbering bug on this branch so far.  `alias.cc:3358', shared code, says

	 targetm.can_eliminate (FRAME_POINTER_REGNUM, STACK_POINTER_REGNUM)

     which with i386 supplying the macros is `can_eliminate (19, 7)' -- and the
     hook it reaches is the SELECTED back end's, `aarch64_can_eliminate'
     (aarch64.cc:14151), whose first statement is

	 gcc_assert (from == ARG_POINTER_REGNUM || from == FRAME_POINTER_REGNUM);

     evaluated in aarch64's OWN translation unit, where those names are 65 and
     64.  19 is neither, so `int g (int a) { return a + 1; }' died in
     `postreload' at aarch64.cc:14153.  One name, two authorities, no
     diagnostic.  `ira.cc:2587' is the same call with the same numbers.

     CALLS AND NOT `target-cdata' CONSTANTS.  i386 and aarch64 both spell all
     four as plain integer constants, so a constant field would have compiled
     and measured green on this pair -- and been wrong for arm, whose
     `HARD_FRAME_POINTER_REGNUM' is
     `(TARGET_ARM ? ARM_HARD_FRAME_POINTER_REGNUM : THUMB_HARD_FRAME_POINTER_REGNUM)',
     i.e. option state, the `Pmode' shape.  A field that is right for the two
     configured bases and silently wrong for a third is the thing this branch
     keeps producing; asking the base's own TU at run time cannot have that
     failure mode.

     THE TWO PREDICATES ARE SEPARATE FIELDS RATHER THAN DERIVED FROM THE
     REGNUMS, for the `#ifndef'-answered-by-the-primary reason that made
     `DWARF_FRAME_REGNUM' its own field in #126.  rtl.h derives them from the
     regnums only `#ifndef' the back end supplied them, and SIX back ends
     supply them outright -- arm, mips, xtensa, loongarch, gcn all define both
     as 0.  Deriving them here would bake i386's "nobody defined these, so
     compare the numbers" into all 48 and lose those six answers with no
     diagnostic: the `unsupplied hook' disguise.  Each base's own translation
     unit includes rtl.h with its own tm.h in force, so what is recorded is
     that base's own `#ifndef' outcome.

     NO OUT-OF-RANGE CASE AND THEREFORE NO SENTINEL.  Unlike `debugger_regno'
     above these take no argument; there is nothing to bound-check and nothing
     to fill.  */
  unsigned int (*stack_pointer_regnum) (void);
  unsigned int (*frame_pointer_regnum) (void);
  unsigned int (*hard_frame_pointer_regnum) (void);
  unsigned int (*arg_pointer_regnum) (void);
  bool (*hard_frame_pointer_is_frame_pointer) (void);
  bool (*hard_frame_pointer_is_arg_pointer) (void);

  /* ----------------------------------------------------------------------
     RETURN_ADDRESS_POINTER_REGNUM, AND IT IS THE LEAKED-ABSENCE SHAPE, NOT
     THE LEAKED-VALUE ONE.

     FIVE back ends define it -- `s390' (35), `sh', `h8300', `iq2000',
     `microblaze' -- and i386 does not.  Every shared reader is an `#ifdef',
     and a shared translation unit reads the PRIMARY's `tm.h', so all of them
     are FALSE for all 47 back ends.  Nothing is mis-set, nothing fails to
     link, and no value is out of range; a block of code simply is not there.

     WHAT IT COST, MEASURED.  `emit-rtl.cc:6355' is

	 #ifdef RETURN_ADDRESS_POINTER_REGNUM
	   return_address_pointer_rtx = gen_raw_REG (Pmode, RETURN_ADDRESS_POINTER_REGNUM);
	 #endif

     so `return_address_pointer_rtx' (`rtl.h:4148', a `target_rtl' member) is
     NEVER INITIALISED and stays NULL for every target.  `s390_va_start'
     (`s390.cc:13646') does

	 t = make_tree (TREE_TYPE (sav), return_address_pointer_rtx);

     and `make_tree' (`expmed.cc:5530') opens with `switch (GET_CODE (x))',
     which dereferences the null.  That is **683 bare
     `internal compiler error: Segmentation fault' FAILs** on s390x -- the
     target's second-largest cause after the CC-mode leak -- and a 15-line
     varargs function reproduces it.  Both-sided: x86_64, aarch64 and riscv64
     compile the identical function cleanly, because none of them has a return
     address pointer to lose.  `s390.h:618's `EH_RETURN_HANDLER_RTX' builds a
     `MEM' on the same null.

     THE OTHER THREE READERS ARE THE QUIET HALF, and they are why this is a
     field rather than a one-line repair at the crash site.  `emit-rtl.cc:859'
     stops `gen_rtx_REG' from returning the unique RAP rtx, so a second,
     non-identical one can be made for the same register; `varasm.cc:1577' and
     `stmt.cc:238' stop `register' asm variables naming the return address
     pointer from being rejected as "an internal GCC implementation detail",
     which is a wrong-code path rather than a diagnostic one.

     AN EXISTENCE FIELD AND NOT A SENTINEL REGNUM.  `INVALID_REGNUM' suggests
     itself and is wrong here for the reason the four regnums above give about
     `#ifndef'-derived predicates: "this back end has no return address
     pointer" and "this back end's return address pointer is register N" are
     two different facts, and a sentinel makes the first unrepresentable
     except by convention.  42 of 47 back ends answer `false', which is their
     OWN answer read in their OWN translation unit -- the supply-side floor
     PRINCIPLES 2a permits -- and not the primary's `#ifdef' answering for
     them.

     NOTE FOR UPSTREAM, found here and NOT fixed here because it is not this
     branch's bug: `read-rtl-function.cc:1431' guards its RAP branch with
     `#ifdef return_ADDRESS_POINTER_REGNUM' -- lowercase `return_'.  That
     identifier does not exist, so the branch is dead upstream too, on every
     target that has a return address pointer.  */
  bool (*has_return_address_pointer) (void);
  unsigned int (*return_address_pointer_regnum) (void);

  /* ----------------------------------------------------------------------
     THE TWO CFA-AT-ENTRY OFFSETS.  This pair is what made the aarch64
     prologue emit CORRECT instructions with WRONG unwind data, and it was
     invisible until #130 produced assembly to look at:

	 g:
	 .LFB0:
		 .cfi_startproc
		 .cfi_def_cfa_offset 16     <-- should not be here at all
		 sub     sp, sp, #16
		 .cfi_def_cfa_offset 32     <-- should be 16
		 ...
		 add     sp, sp, 16
		 .cfi_def_cfa_offset 16     <-- should be 0
		 ret

     The CFA is 16 too high throughout, so every unwind through such a frame
     reads the caller's state from 16 bytes past where it is.  The compiler
     exits 0; nothing but reading the output says so.

     WHAT CARRIES IT, read in the running cc1 rather than inferred
     (`t131-cfi-cause.sh', one breakpoint per run on `scan_trace', gdb's own
     `^Breakpoint N, scan_trace' stop line matched, both bases):

	 aarch64:  cfun->machine->func_type = TYPE_EXCEPTION, UNITS_PER_WORD = 8
		   INCOMING_FRAME_SP_OFFSET         = 16
		   DEFAULT_INCOMING_FRAME_SP_OFFSET =  8
	 x86_64:   cfun->machine->func_type = TYPE_NORMAL,    UNITS_PER_WORD = 8
		   INCOMING_FRAME_SP_OFFSET         =  8
		   DEFAULT_INCOMING_FRAME_SP_OFFSET =  8

     `16 is not UNITS_PER_WORD on its face' was the reason #130 declined to
     name a carrier, and the resolution is that it is 2 * UNITS_PER_WORD:
     i386.h:2177 is

	 (cfun->machine->func_type == TYPE_EXCEPTION ? 2 * UNITS_PER_WORD
						     : UNITS_PER_WORD)

     and `cfun->machine' points at AARCH64's `machine_function' object while
     dwarf2cfi.cc was compiled against I386's declaration of that struct name.
     So the `func_type' bitfield is read out of whatever aarch64 keeps at that
     offset, and it happened to read 3 -- TYPE_EXCEPTION.  This is the shared-
     numbering bug in its `identity by address' disguise: one struct NAME, two
     layouts, no diagnostic.  Nothing here fixes the type confusion in
     general (i386.h:1650 reads the same field); it removes the one read of it
     that reaches the emitted unwind data.

     BOTH MOVE TOGETHER, and the second one is the reason the wrong value
     becomes a wrong DIRECTIVE rather than staying internal.  dwarf2cfi.cc
     emits the entry note only when the two DISAGREE (:2766):

	 if (entry && DEFAULT_INCOMING_FRAME_SP_OFFSET != INCOMING_FRAME_SP_OFFSET)

     Converting `INCOMING_FRAME_SP_OFFSET' alone would give aarch64 its own 0
     while `DEFAULT_' stayed at i386's 8, so the two would STILL disagree, the
     note would STILL be emitted, and it would now read `.cfi_def_cfa_offset
     0' -- a different wrong file with the same shape.  Converting `DEFAULT_'
     alone leaves the real offset at 16.  This is the closure failure
     PRINCIPLES section 4 names, and here it is not hypothetical: either half
     alone produces output that still assembles.

     `DEFAULT_' IS A FIELD OF ITS OWN RATHER THAN DERIVED, for the
     `#ifndef'-answered-by-the-primary reason that made `DWARF_FRAME_REGNUM'
     its own field.  dwarf2cfi.cc:56 says `#ifndef DEFAULT_INCOMING_FRAME_SP_
     OFFSET' -> `INCOMING_FRAME_SP_OFFSET', and only two back ends in the tree
     define it at all (i386 and stormy16).  Deriving it here would bake
     i386-on-linux's "they are equal" into all 48 and lose stormy16's
     distinction with no diagnostic.  Asked in the base's own translation
     unit, each back end's own `#ifndef' outcome is what gets recorded.

     CALLS AND NOT `target-cdata' CONSTANTS.  i386's reads `cfun', which is
     precisely the failure target-cdata.h's header comment records for
     `STACK_BOUNDARY': a field is evaluated once with `cfun' null and then
     frozen.  aarch64 defines neither macro, so its thunks compile to
     `return 0;' -- which is what a constant costs when it is allowed to be
     one.

     `HOST_WIDE_INT' AND NOT `poly_int64', which is the tempting type because
     `dw_cfa_location::offset' is one.  It would not compile: var-tracking.cc
     :549 declares `HOST_WIDE_INT stack_adjust' and :10101 does `ofst -= ...'
     on an `int', and `poly_int64' converts implicitly to neither.  A
     `HOST_WIDE_INT' widens into the `poly_int64' at dwarf2cfi.cc:2771 and
     narrows in a compound assignment at var-tracking.cc:10101, which is what
     the plain macro did.  The six shared use sites are dwarf2cfi.cc:2767,
     :2771, :3266 and var-tracking.cc:832, :834, :10101; every one is an
     ordinary run-time expression -- no `#if', no case label, no array bound,
     no static initialiser (swept over all of `gcc/' outside `config/' and
     `testsuite/').  */
  HOST_WIDE_INT (*incoming_frame_sp_offset) (void);
  HOST_WIDE_INT (*default_incoming_frame_sp_offset) (void);

  /* `ACCUMULATE_OUTGOING_ARGS' -- THE SECOND READ OF `cfun->machine->func_type'
     THROUGH THE WRONG STRUCT DECLARATION, and the only one left that shared
     code can reach.  #131 closed `INCOMING_FRAME_SP_OFFSET' (i386.h:2177);
     i386.h:1647 is the sibling it named and did not close:

	 #define ACCUMULATE_OUTGOING_ARGS \
	   ((TARGET_ACCUMULATE_OUTGOING_ARGS \
	     && optimize_function_for_speed_p (cfun)) \
	    || (cfun->machine->func_type != TYPE_NORMAL \
		&& crtl->stack_realign_needed) \
	    || TARGET_STACK_PROBE \
	    || TARGET_64BIT_MS_ABI \
	    || (TARGET_MACHO && crtl->profile))

     Same `identity by address' disguise as :2177: `cfun->machine' points at
     the SELECTED base's `machine_function' object, while calls.cc, expr.cc,
     function.cc, dce.cc, cselib.cc, builtins.cc, combine.cc, cfgcleanup.cc,
     combine-stack-adj.cc, var-tracking.cc and targhooks.cc were all compiled
     against I386's declaration of that struct name.  The 3-bit `func_type'
     bitfield is read out of whatever aarch64 keeps at that offset.  It is a
     worse read than :2177's, not a milder one: :2177 compares for equality
     with `TYPE_EXCEPTION', so only one of the eight bit patterns is wrong,
     whereas this one is `!= TYPE_NORMAL', so SEVEN of the eight are.  #131
     measured that bitfield reading 3 on aarch64.

     Note what the leak decides.  aarch64's own answer is the constant 1
     (aarch64.h:1060); i386's is a run-time expression that is usually 0 on
     x86_64-linux.  So every one of the ~40 shared use sites -- argument-block
     layout in `expand_call', the `NO_DEFER_POP' pushes, dce's stack-store
     analysis, cfgcleanup's cross-jumping -- was taking i386's answer while
     generating aarch64 code, i.e. aarch64 was compiled in the
     PUSH-ARGUMENTS-INDIVIDUALLY shape it never uses.

     A CALL, EVALUATED AT EVERY USE, for the same measured reason as the two
     sp offsets above and one more: i386's body reads `cfun' three ways
     (`optimize_function_for_speed_p (cfun)', `cfun->machine->func_type',
     `crtl->stack_realign_needed'), and `crtl->stack_realign_needed' is set
     DURING reload.  It is not constant across a run, not constant across two
     functions, and not even constant across two passes over one function.  A
     `target-cdata' constant would be read once with `cfun' null.

     EVERY USE SITE IS AN ORDINARY RUN-TIME EXPRESSION -- no `#if', no case
     label, no array bound, no static initialiser.  Swept over all of `gcc/'
     outside `config/' and `testsuite/' (`scratchpad/t132-sites.sh'): the only
     preprocessor occurrence anywhere is defaults.h's own `#ifndef' guard,
     which is the definition and not a use.  That is what makes this one
     convertible where `FRAME_POINTER_CFA_OFFSET' is not; see defaults.h.  */
  bool (*accumulate_outgoing_args) (void);

  /* `STACK_DYNAMIC_OFFSET' -- AND THIS ONE LEAKS IN THE OPPOSITE DIRECTION
     FROM EVERY ENTRY ABOVE IT.  The others are "the primary's answer reaches
     everyone".  Here **aarch64 defines the macro** (aarch64.h:1688, the
     `-fstack-clash-protection' outgoing-args reservation) and **i386 does
     not**, so `function.cc:1411' asked `#ifndef STACK_DYNAMIC_OFFSET', got
     the PRIMARY's answer -- undefined -- and used function.cc's own generic
     ladder for every target.  aarch64's definition was DISCARDED, including
     for aarch64 itself.

     Same shape as `has_init_expanders' above, where i386 defined nothing and
     aarch64's `init_machine_status' was therefore never installed, and the
     same family as `HAVE_V8HFmode': one authority answering an existence
     question for many.  It is the reason this class keeps being found by
     accident rather than by instrument -- **an absence produces no code at
     all**, so no sweep looking for a wrong symbol or a wrong value can see
     it.  `nm' scores a discarded definition exactly as it scores a correct
     one: nothing.

     WHAT WAS DISCARDED.  aarch64's body reserves
     `STACK_CLASH_MIN_BYTES_OUTGOING_ARGS' of outgoing-argument space when
     `flag_stack_clash_protection && cfun->calls_alloca' and the real outgoing
     args are smaller, which is what lets `alloca' skip a probe.  Under the
     generic ladder that reservation never happened, so
     `-fstack-clash-protection' code with `alloca' was built without the space
     its probing strategy assumes.

     NO `has_' FLAG IS NEEDED HERE, unlike `INIT_EXPANDERS'.  The generic
     ladder is a real, correct answer for a base that defines nothing -- 42 of
     the 51 back ends are in that case -- so the `#ifndef' is reproduced
     INSIDE the per-base thunk, where it is a fact about that base rather than
     about whichever base compiled `function.cc'.  That is not the `#ifndef'
     floor PRINCIPLES forbids: the floor is forbidden because it makes a
     MISSING answer look like an answer, whereas here the base genuinely has
     an answer and the ladder is how the base's own headers spell it.

     `poly_int64' AND NOT `HOST_WIDE_INT', unlike the two sp offsets above:
     `crtl->outgoing_args_size' is a `poly_int64', aarch64's arm is a
     `ROUND_UP' of one, and `get_stack_dynamic_offset' returns one.

     A CALL AT EVERY USE, and there is only one use to make: upstream already
     funnels the macro through `get_stack_dynamic_offset ()' in function.cc
     (added 2023, precisely so the macro "sees a predictable set of included
     files").  That wrapper is now the only evaluation point in the tree, and
     the macro is no longer defined in shared code at all -- so a future
     shared spelling of the name fails BY NAME rather than silently picking up
     a generic ladder.  */
  poly_int64 (*stack_dynamic_offset) (tree fndecl);

  /* `PUSH_ARGS_REVERSED' -- the cheapest leak in the `PUSH_ROUNDING' closure
     and the one with the widest consequence per line of code.  i386.h:1658
     defines it to `1'; aarch64 does not; bpf and nvptx do.  Its ONLY shared
     use is `gimplify.cc:4791-4793', three run-time expressions in one `for'
     header, and they decide **the order in which every call's arguments are
     gimplified**.  So argument gimplification ran last-to-first for every
     target because the primary says so.

     THIS IS OBSERVABLE IN THE OUTPUT, which is what makes it different from
     most of the fields above.  Argument evaluation order is unspecified in C
     but not unobservable: two arguments that are side-effecting calls are
     emitted in whichever order this decides, and the emitted code differs.
     A value-only arm would therefore not have been enough here; the
     behavioural arm is `scratchpad/t134-order.sh'.

     THE DEFAULT IS A LADDER, NOT A CONSTANT, AND IT IS PER-BASE THROUGHOUT.
     `defaults.h:915-928' reads:

         #ifdef PUSH_ROUNDING
         # if defined (STACK_GROWS_DOWNWARD) != defined (ARGS_GROW_DOWNWARD)
         #  define PUSH_ARGS_REVERSED targetm.calls.push_argument (0)
         # endif
         #endif
         #ifndef PUSH_ARGS_REVERSED
         # define PUSH_ARGS_REVERSED 0
         #endif

     Every name in it -- `PUSH_ROUNDING', `STACK_GROWS_DOWNWARD',
     `ARGS_GROW_DOWNWARD' -- is the BASE's, so the ladder had three leaks in
     it rather than one.  It is not reproduced in the thunk: `defaults.h' is
     included by `target-cumargs.cc' with `MULTI_TARGET_TARGETM_BASE' defined,
     so the ladder is already evaluated there against that base's headers and
     the thunk simply reads the resulting macro.  That is the difference from
     `stack_dynamic_offset' above, whose ladder lived in a `.cc' file's
     private preprocessor block and had to be copied.

     `? true : false' AND NOT A CAST, for the reason
     `accumulate_outgoing_args' records: three back ends spell it `1' and the
     fallback spells it `0', but the third arm is a HOOK CALL returning
     `bool', and normalising here is what makes all three arrive as the same
     two values.

     NO `has_' FLAG.  A base that defines nothing genuinely means `0' -- 48 of
     the 51 back ends are in that case -- and `0' is the ladder's own answer
     for them, not a floor standing in for a missing one.  */
  bool (*push_args_reversed) (void);

  /* `INCOMING_REG_PARM_STACK_SPACE' -- `REG_PARM_STACK_SPACE''s SECOND path
     into shared code, and the reason `function.o' still bound
     `U ix86_reg_parm_stack_space(tree_node const*)' after #133 converted the
     first one.  PRINCIPLES' "one symbol can have several macro paths",
     measured a third time.

     `function.cc:1403' derives the name from `REG_PARM_STACK_SPACE' when a
     base does not define it itself, and `function.cc:2322' then asks
     `#ifdef INCOMING_REG_PARM_STACK_SPACE' to decide whether to set
     `all->reg_parm_stack_space' at all.  Both the derivation and the
     existence test were the primary's: i386 defines
     `REG_PARM_STACK_SPACE' (i386.h:1672), aarch64 does not, so aarch64
     functions were initialised with i386's answer -- computed by
     `ix86_reg_parm_stack_space' on an aarch64 `fndecl'.

     THE `#ifdef' ARM IS NOT LOST BY RETURNING 0.  `assign_parms_initialize_
     all' does `memset (all, 0, sizeof (*all))' four lines earlier, so "the
     macro is undefined" and "the macro yielded 0" already produce the same
     state at this site -- the only site.  A base with no definition returns
     0 here because 0 is what it means, not because 0 is a floor.

     `int' AND NOT `poly_int64': the field it initialises is
     `int reg_parm_stack_space' in `assign_parm_data_all', and every back
     end's macro is an integer constant or an `int'-returning function.  */
  int (*incoming_reg_parm_stack_space) (tree fndecl);

  /* `REG_PARM_STACK_SPACE' -- the THIRD and FOURTH paths, `calls.cc' (eleven
     `#ifdef's and two value uses) and `expr.cc:2192/:2198'.  Two slots and not
     one, and the split is the whole point:

     `has_reg_parm_stack_space' answers the EXISTENCE question that the
     `#ifdef's asked, `reg_parm_stack_space' answers the VALUE question.  A
     single value slot cannot serve both, because `REG_PARM_STACK_SPACE'
     yielding 0 and `REG_PARM_STACK_SPACE' being undefined are NOT the same
     state at every site: `save_fixed_argument_area' computes
     `high = reg_parm_stack_space; if (ARGS_GROW_DOWNWARD) high += 1;', so on
     an args-grow-downward base a zero value still inspects
     `stack_usage_map[0]' whereas the undefined case never calls the function
     at all.  Collapsing the two would have changed behaviour for exactly
     those back ends, silently, in the direction where nothing fails to
     build.  (Neither configured base is one -- i386 and aarch64 both grow
     args upward -- so this pair could not have caught it; it is the same
     "correct by luck on this pair" shape recorded for the value below, found
     by reading the callee rather than by measuring.)

     THE VALUE ARM CANNOT DISCRIMINATE ON THIS PAIR AND THAT IS THE RESULT,
     not a pass.  `ix86_reg_parm_stack_space' returns 32 only for
     `TARGET_64BIT && MS_ABI' and 0 otherwise, which is exactly what aarch64's
     absence yields.  The defect is `ix86_function_abi' being handed an
     aarch64 `FUNCTION_DECL' and reading i386's option state about it, so the
     evidence is which FUNCTION is called (a tail `jmp' to
     `ix86_reg_parm_stack_space' in the i386 thunk, `xor %eax,%eax' in
     aarch64's) and the existence answer, which DOES differ: true vs false.

     `tree' and not `const_tree': back ends spell the macro's argument both
     ways (i386's takes `const_tree', rs6000's takes `tree'), and the shared
     sites pass an `fndecl', an `fntype' or a literal `(tree) 0'.  */
  bool (*has_reg_parm_stack_space) (void);
  int (*reg_parm_stack_space) (tree fndecl_or_type);

  /* `PUSH_ROUNDING' -- 19 preprocessor sites and 12 value sites, classified
     into five shapes by #133 and converted by #135.  Two slots again, and for
     a sharper reason than `REG_PARM_STACK_SPACE': `PUSH_ROUNDING' is an
     EXISTENCE question at almost every site.  `#ifdef PUSH_ROUNDING' does not
     mean "the rounding is nonzero", it means "this target has push insns at
     all", and eleven of the nineteen sites use it that way -- including
     `default_push_argument', the default of the `TARGET_PUSH_ARGUMENT' hook
     that several of the same sites then consult INSIDE the guard.

     THE SIGNATURE IS THE DECISION, AND IT IS MADE ONCE HERE FOR ALL 12 VALUE
     SITES.  `poly_int64 (poly_int64)':

       - All FIVE function-implemented back-end macros already take and return
         `poly_int64' (`ix86_push_rounding', `m68k_', `h8300_', `pdp11_',
         `xstormy16_'), and the two macro-implemented ones (vax, avr) are the
         identity `(BYTES)'.  So `poly_int64' fits every LIVE definition.
         There are SEVEN live definitions, not the thirteen a `grep' for the
         name suggests: sh's is inside `#if 0' and arm's, alpha's, pa's,
         rs6000's, iq2000's and one of avr's are commented out.
       - `MACRO_INT' STAYS IN THE PER-BASE THUNK AND LEAVES THE SHARED SITES.
         It is `.to_constant ()' when `NUM_POLY_INT_COEFFS == 1' and the
         identity otherwise, and it exists because a back end's macro may not
         be poly-safe.  Keeping it in the thunk preserves recog.cc's exact
         behaviour for every back end; dropping it at the shared sites is what
         removes a compile-time constant-ness assumption from shared code.
       - The alternative -- `HOST_WIDE_INT (HOST_WIDE_INT)' -- was rejected:
         four of the twelve value sites pass a `poly_int64' whose constness is
         not known at the call (`GET_MODE_SIZE (mode)' among them), so that
         signature would have pushed a `.to_constant ()' into SHARED code,
         which is the constant-ness assumption this project is removing.  */
  bool (*has_push_rounding) (void);
  poly_int64 (*push_rounding) (poly_int64 bytes);

  /* `CASE_VECTOR_PC_RELATIVE' -- the jump-table shape.  THREE shared sites
     (`stmt.cc:1202', `expr.cc:14356', `final.cc:2147') and, before this, all
     three were answered by the primary: i386 does not define the macro at
     all, so `defaults.h:1162' supplied 0 for everyone, while aarch64's
     `aarch64.h:1496' says 1.

     WHAT THAT COST, MEASURED RATHER THAN ARGUED.  `stmt.cc' emitted an
     `ADDR_VEC' for aarch64 where the back end's own `casesi' expander
     requires an `ADDR_DIFF_VEC', and `aarch64_output_casesi' then died on its
     first line -- `gcc_assert (GET_CODE (diff_vec) == ADDR_DIFF_VEC)'.  68
     ICEs in the aarch64 testsuite column.

     A FUNCTION AND NOT A `target-cdata' FIELD, for the reason that struct's
     header states: the macro is option-dependent on seven of the sixteen back
     ends that define it -- `riscv_cmodel' (riscv.h:913),
     `rs6000_relative_jumptables' (rs6000.h:1735), `flag_pic || optimize_size'
     (nds32.h:1698), `TARGET_PID' (rx.h:466), `flag_pic' (c6x, nvptx),
     `TARGET_MIPS16_SHORT_JUMP_TABLES' (mips.h:2714).  A value cached at
     selection time would be frozen at whatever the command line said.

     SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE REDIRECTING.  The one
     `#if CASE_VECTOR_PC_RELATIVE' in the tree is `m68k.md:5804', which is a
     back end's own translation unit and therefore keeps the real macro; no
     `#if', `#ifdef', case label, array bound or static initialiser in shared
     code names it.  */
  bool (*case_vector_pc_relative) (void);

  /* `REGMODE_NATURAL_SIZE' -- how much of a register one mode occupies.
     EIGHT shared sites (`emit-rtl.cc' x2, `combine.cc' x2, `rtlanal.cc',
     `expmed.cc' x2, `expr.cc', `cfgexpand.cc', `ira-conflicts.cc',
     `reginfo.cc') and, before this, all of them were i386's.

     THIS IS THE `regs.h:31' FALLBACK NOT BEING REACHED, which is worth saying
     because `multi-target-macros.h' lists this name among the eleven that
     inherit the `UNITS_PER_WORD' redirect by ordinary macro expansion.  That
     inheritance only happens when regs.h's `#ifndef' is TAKEN -- and it is
     not, because the primary's `i386.h:1112' has already defined the name as
     `ix86_regmode_natural_size (MODE)'.  So the derived conversion recorded
     there was real for a base that defines nothing and dead for the one that
     matters.  Four back ends define the macro: i386, aarch64, riscv, sparc.

     WHAT IT COST.  aarch64's answer is `BYTES_PER_SVE_PRED' /
     `BYTES_PER_SVE_VECTOR' for variable-width SVE modes and `UNITS_PER_WORD'
     otherwise; i386's is `UNITS_PER_WORD' for everything that is not
     P2HImode/P2QImode.  `gen_lowpart_common (emit-rtl.cc:1649)' therefore
     computed `mregs > xregs' with the wrong divisor for every SVE mode and
     returned 0, and `gen_lowpart_general (rtlhooks.cc:57)' asserted.  509
     ICEs in the aarch64 testsuite column, of which 447 are
     `gcc.target/aarch64/sve'.

     `poly_uint64' AND NOT `unsigned int': aarch64's and riscv's already
     return `poly_uint64' (an SVE vector's size is not constant), and every
     shared site already stores the result in a `poly_uint64'.  Narrowing here
     would put a `.to_constant ()' where SVE is exactly the case that has
     none.  i386's and sparc's `unsigned int' widen silently and correctly.  */
  poly_uint64 (*regmode_natural_size) (machine_mode mode);

  /* `CASE_VECTOR_MODE' -- the mode of a jump table's elements.  The sibling
     of `case_vector_pc_relative' above, and left alone by the task that
     converted that one because `target-cdata.h:166' records it as deferred to
     the mode-numbering work.  MEASURED, THAT DEFERRAL DOES NOT APPLY TO THIS
     MECHANISM, and the distinction is worth stating because the note reads as
     though it blocks any conversion at all.

     What `target-cdata.h:166' says is that a `machine_mode' cannot be a
     `target-cdata' FIELD, because such a field is a number cached at
     selection time and mode NUMBERING would have to be per base for that
     number to mean anything.  That is a correct objection to a field.  It is
     not an objection to a CALL, for two independent reasons:

       - The mode vocabulary is UNIONED (`genmodes.cc' `read_union_list'), so
         `E_DImode' is one number for every configured base.  A mode crossing
         this boundary is not transported into a different vocabulary; there
         is only one.  `mt_base_pmode' and `mt_base_function_mode' already
         return modes through this very table and have since #124.
       - The reason this name cannot be a cached field anyway is the same one
         `case_vector_pc_relative' has: it is OPTION STATE.  i386's is
         `(!TARGET_LP64 || (flag_pic && ix86_cmodel != CM_LARGE_PIC)
           ? SImode : DImode)' (`i386.h:1920'), so a value frozen at selection
         time would be frozen at whatever `-fpic' said.

     WHAT IT COST, AND WHY IT WAS NOT AN ICE COLUMN.  Two shared sites read it
     (`stmt.cc:1204', `expr.cc:14346/14356/14357/14358'), and both got i386's
     expression evaluated against i386's option state.  aarch64's answer is a
     plain `Pmode' (`aarch64.h:1367'), i.e. DImode on this target.
     i386's yields DImode too -- but ONLY when `!flag_pic'.  Under `-fpic' the
     `flag_pic && ix86_cmodel != CM_LARGE_PIC' arm makes it SImode, so aarch64
     built PIC jump tables out of 4-byte elements while its own `casesi'
     expander and `aarch64_output_casesi' assume `Pmode'.  This agreed by
     luck in the non-PIC case and diverged the moment PIC was on, which is
     precisely the shape PRINCIPLES calls out for `INCOMING_REG_PARM_STACK_SPACE'
     and `ARG_POINTER_CFA_OFFSET': correct for a reason a third back end -- or
     here, a single extra flag -- destroys.

     SWEPT FOR CONSTANT-EXPRESSION CONTEXTS.  No `#if', `#ifdef', case label,
     array bound or static initialiser in shared code names `CASE_VECTOR_MODE'.
     The three tests against it -- `epiphany.h:737/746/801' and
     `i386.cc:16154' -- are back ends' own translation units and keep the real
     macro.  */
  machine_mode (*case_vector_mode) (void);

  /* `INCOMING_RETURN_ADDR_RTX' -- where the return address is on entry.
     THE AUTHORITY BEHIND THE LAST STANDING aarch64 ICE COLUMN, 7 ICEs in
     `maybe_record_trace_start', and the same disguise as everything else
     here: both configured bases define the name, so shared code took the
     primary's and there was no diagnostic.

       i386      `gen_rtx_MEM (Pmode, stack_pointer_rtx)'   i386.h:2162
       aarch64   `gen_rtx_REG (Pmode, LR_REGNUM)'           aarch64.h:1472

     These are not two values of one kind; they are different KINDS of answer.
     i386 says the return address is in MEMORY at the stack pointer, aarch64
     says it is in a REGISTER.

     AND THAT SPLIT IS NOT A PROPERTY OF THIS PAIR -- IT IS THE POPULATION.
     45 back ends define the macro, and by shape they are 7 `gen_rtx_MEM'
     against 37 `gen_rtx_REG' (the balance being back ends that call a
     function, e.g. avr).  i386 is one of the SEVEN.  So the primary hands a
     memory location to the 37 back ends whose return address is a register --
     this is a majority-wrong leak, not an aarch64 quirk, and it is invisible
     to any pair that happens to agree on the shape (i386 + rx, i386 + rl78
     and i386 + h8300 would all have looked fine).  `dwarf2cfi.cc:3283' passes whichever it got to
     `initial_return_save', which builds the CIE's initial row from it -- so
     for aarch64 the CIE claimed the return address was already spilled to the
     stack at function entry.  Every trace that then established the truth
     (LR live in x30 until the prologue stores it) disagreed with that row,
     and `maybe_record_trace_start' reached its `Inconsistent CFI state'
     `gcc_unreachable ()' at `dwarf2cfi.cc:2606'.

     Note where the failure surfaced: in the CFI row comparison, three files
     from the macro that decided it, with the back end entirely correct --
     the same geometry as `aarch64_output_casesi' in the sibling fix.

     A SECOND SHARED CONSUMER, AND IT IS AN EXISTENCE TEST.  `df-scan.cc:3559'
     is `if (REG_P (INCOMING_RETURN_ADDR_RTX))', which marks the return-address
     register live on entry to the function.  With i386's MEM that test is
     FALSE, so on aarch64 x30 was never added to the entry block's defs.  That
     is a dataflow consequence rather than an ICE, and it is why this
     conversion is not only about the assert.

     A FUNCTION, AND NOT MERELY BECAUSE OF OPTION STATE.  This one cannot be
     cached at all: it builds a fresh `rtx' and i386's body reads
     `stack_pointer_rtx', which is per-function RTL state created by
     `init_emit_regs'.  Caching an rtx at selection time would hand every
     function the first function's stack pointer object -- the
     `PIC_OFFSET_TABLE_REGNUM' trap `target-cdata.h:160' names.

     `dwarf2cfi.cc:52's `#ifndef' FALLBACK IS NOT THE SUPPLY-SIDE KIND AND IS
     LEFT ALONE.  It is `(gcc_unreachable (), NULL_RTX)', i.e. a fail-by-name
     for a back end that defines nothing, which is what PRINCIPLES asks for;
     it is simply never reached in a shared TU because the primary defines the
     name.  The thunk below is compiled per base, so for a base that genuinely
     defines nothing that fallback is reached HERE, in that base's own
     translation unit, and aborts naming the base rather than handing out
     i386's stack pointer.

     AND THAT REQUIRED AN EXISTENCE FIELD, WHICH THE FIRST VERSION DID NOT
     HAVE.  Restating the abort alone would have been wrong for the OTHER
     shared consumer: `df-scan.cc:3558's `#ifdef' means "if this back end has
     no such thing, do not mark the entry-block def" -- upstream SKIPS the
     block, it does not abort.  With the redirect keeping the name defined,
     that `#ifdef' is unconditionally true, so an abort-only thunk would have
     turned three back ends' correct upstream silence into an ICE in
     dataflow.  `has_incoming_return_addr_rtx' is therefore a real per-base
     answer of its own -- the `has_push_rounding' shape, and for the same
     reason: the macro is `#ifdef'-tested in shared code, so its EXISTENCE is
     a target property that has to be carried rather than derived from
     whichever base compiled the shared file.

     45 of 48 back ends define the macro; `bpf', `nvptx' and `pdp11' do not
     (none of the three has DWARF CFI to build a CIE for), and it was those
     three that turned a missing `#ifdef' here into a 47-base build failure.  */
  bool (*has_incoming_return_addr_rtx) (void);
  rtx (*incoming_return_addr_rtx) (void);

  /* EPILOGUE_USES (REGNO) -- AND THIS ONE LEAKS AN ANSWER THAT IS TOO SMALL,
     WHICH DELETES CODE RATHER THAN MIS-COMPILING IT.

     `df-scan.cc:3647' is the single shared consumer:

	 df_epilogue_uses_p (regno)
	   = EPILOGUE_USES (regno) || TEST_HARD_REG_BIT (..., regno)

     and it feeds `df_get_exit_block_use_set', i.e. the set of hard registers
     considered live on return.  Compiled against the primary it is
     `ix86_epilogue_uses', for all 47 back ends -- confirmed rather than
     inferred: `nm -uC df-scan.o' names `ix86_epilogue_uses(int)' and no other
     i386 symbol in that object.

     25 of 47 back ends define the macro (aarch64 alpha arc arm avr epiphany
     frv ft32 i386 ia64 loongarch m68k mips mmix moxie pru riscv s390 sh sparc
     v850 visium xstormy16 xtensa, plus alpha/vms.h).  Each was answering with
     i386's set.

     WHY IT COSTS MORE THAN A WRONG VALUE USUALLY DOES.  A register the
     selected back end needs live at exit, and that i386 does not name, is
     simply absent from the exit block's use set.  Nothing is mis-set and
     nothing complains; dataflow then concludes that whatever wrote that
     register is dead and DCE deletes it.  Measured on aarch64 SME2, where
     `EPILOGUE_USES' is what keeps the ZA state registers live:

	 stock   exit block uses  ... 87 [lowering] 89 [sme_state]
				     90 [tpidr2_setup] 92 [za_saved] 93 [za]
	 leaked  exit block uses  ... (none of the five)
	 => cse1 "DCE: Deleting insn 8", the `add za.s[w8, 0, vgx2], ...'
	 => every ZA-writing function emitted as a bare `ret', rc=0, no
	    diagnostic

     That is the leaked-ABSENCE shape `init_expanders' above describes, in the
     dataflow rather than in a `#ifdef': the compiler emits LESS code, exits
     0, and the damage is a silently empty function body.  It is worth
     `9,050' FAILs in `gcc.target/aarch64/sme2/acle-asm' alone, where stock
     fails zero, and every one of them is a `check-function-bodies' mismatch
     rather than a compile failure -- which is why no ICE or error count could
     ever have found it.

     NO EXISTENCE FIELD IS NEEDED, unlike `has_incoming_return_addr_rtx'.  The
     shared consumer spells the macro unconditionally, never `#ifdef's it, and
     `defaults.h:1335' gives a base that defines nothing the value `false'.
     That fallback is the SUPPLY-side kind PRINCIPLES permits: it is reached in
     that base's own translation unit and it is upstream's own answer for a
     back end standing alone, not the primary's.  */
  bool (*epilogue_uses) (int regno);

  /* ASM_DECLARE_FUNCTION_NAME, WITH ASM_OUTPUT_FUNCTION_LABEL AS ITS `#else'
     ARM -- AND THIS IS THE OTHER HALF OF THE SME RESIDUAL.

     `varasm.cc:2218' is the only shared consumer and it is an `#ifdef':

	 #ifdef ASM_DECLARE_FUNCTION_NAME
	   ASM_DECLARE_FUNCTION_NAME (asm_out_file, fnname, current_function_decl);
	 #else
	   ASM_OUTPUT_FUNCTION_LABEL (asm_out_file, fnname, current_function_decl);
	 #endif

     Both arms were the primary's: `nm -uC varasm.o' names
     `ix86_asm_output_function_label(_IO_FILE*, char const*, tree_node*)', and
     `final.o' names it too.  `elfos.h:303' supplies a generic
     ASM_DECLARE_FUNCTION_NAME to most ELF targets and `aarch64.h:855'
     overrides it, so the `#ifdef' is true for nearly everyone and the
     question was never existence -- it was WHOSE.

     WHAT IT COSTS, AND IT IS NOT COSMETIC.  aarch64's
     `aarch64_declare_function_name' emits the per-function `.arch' update for
     `#pragma GCC target', plus `.variant_pcs' and `%function'.  Without it:

	 stock         .arch armv8-a+sme          (file level)
		       .arch armv8-a+sme-i16i64   (per function, line 7)
	 multi-target  .arch armv8-a+sme          (file level only)

     `gcc.target/aarch64/sme/aarch64-sme-acle-asm.exp:66' sets
     `dg-do-what-default' to ASSEMBLE when the assembler supports
     `sme-i16i64', so the `*_za64.c' tests really are assembled -- and the
     assembler then refuses instructions the compiler generated CORRECTLY:

	 Error: selected processor does not support `addha za0.d,p0/m,p1/m,z0.d'

     That is 184 of `sme/acle-asm's residual and the bulk of `sme2's, and it
     only became visible once `EPILOGUE_USES' stopped deleting the
     instructions before the assembler could see them.  A defect hidden behind
     another defect, in the direction that made the first one look worse.

     WHY NO EXISTENCE FIELD, unlike `has_incoming_return_addr_rtx'.  The
     `#ifdef' has an `#else' that is itself a valid action, so both arms end
     in a call and there is no absence to represent.  The condition moves into
     the per-base translation unit -- where it is a fact about that back end
     rather than about whichever base compiled `varasm.cc' -- exactly as
     `mt_init_expanders' replaced `#ifdef INIT_EXPANDERS' rather than
     redirecting it.  The shared call site is therefore unconditional.  */
  void (*declare_function_name) (FILE *file, const char *name, tree decl);

  /* ASM_DECLARE_COLD_FUNCTION_NAME, with ASM_OUTPUT_LABEL as its `#else' arm.
     `final.cc:2229', the cold-partition sibling of the site above, and it was
     found by the symbol REFUSING to go away: after `varasm.o' was fixed,
     `nm -uC final.o' still named `ix86_asm_output_function_label', because
     `elfos.h:319's ASM_DECLARE_COLD_FUNCTION_NAME expands to
     `ASM_OUTPUT_FUNCTION_LABEL' too.

     That is PRINCIPLES' "one symbol can have several macro paths" and
     "sweep the family; do not meet it one wall at a time", arriving together:
     closing the path you found does not close the symbol, and the second path
     was one `#ifdef' away from the first.

     It costs nothing in the ACLE directories -- cold partitions need
     `-freorder-blocks-and-partition' and profile data, which these tests do
     not use -- so it is converted because it is the same defect, not because
     a number moved.  Stated plainly so nobody later reads its zero as
     evidence the conversion was unnecessary.  */
  void (*declare_cold_function_name) (FILE *file, const char *name, tree decl);

  /* ASM_DECLARE_FUNCTION_SIZE -- THE CLOSING HALF OF `declare_function_name'
     ABOVE, AND IT WAS LEFT BEHIND WHEN THAT ONE WAS CONVERTED.

     `varasm.cc:2254' (`assemble_end_function') is the only shared consumer and
     it is an `#ifdef' with no `#else'.  i386 defines no
     ASM_DECLARE_FUNCTION_SIZE of its own, so the value every base got was
     `elfos.h:397's generic `.size' directive -- which is the RIGHT answer for
     most of the 15 definers and the WRONG one for the two that matter here,
     because for them the macro is not about `.size' at all.

     WHAT IT COSTS: AN UNBALANCED `.option push'.  `riscv.h:1164' points the
     macro at `riscv_declare_function_size', whose job is to emit

	 .option pop

     closing the `.option push' / `.option arch, <isa>' that
     `riscv_declare_function_name' emits for any function carrying
     `#pragma GCC target', `__attribute__((target(...)))' or `norelax'.
     `ASM_DECLARE_FUNCTION_NAME' is CONVERTED (three lines above it in
     riscv.h), so on this branch the push is emitted and the pop never is: the
     per-function ISA override leaks forward into every subsequent function in
     the translation unit.  The two halves of one bracket answered by two
     different back ends.

     `s390.h:913' is the same shape -- `s390_asm_declare_function_size' emits
     `.machine pop' / `.machinemode pop' against the prefix hook's push -- and
     alpha, arm, ia64, microblaze, nvptx, c6x, epiphany and rs6000/linux64 all
     override the macro for their own reasons.

     THE SECTION SWITCH MOVES WITH IT, DELIBERATELY.  Upstream guards

	 if (crtl->has_bb_partition)
	   switch_to_section (function_section (decl));

     inside the SAME `#ifdef', so a base defining no ASM_DECLARE_FUNCTION_SIZE
     does not switch back either.  Splitting the two would give bases a
     combination upstream never produces, so the whole block is what the thunk
     evaluates.

     NO EXISTENCE FIELD, for `declare_function_name's reason: the absence is
     itself a complete action (do nothing), so there is nothing for shared code
     to branch on and the call site is unconditional.  */
  void (*declare_function_size) (FILE *file, const char *name, tree decl);

  /* ASM_OUTPUT_FUNCTION_PREFIX -- THE OPENING HALF OF THE BRACKET ABOVE, AND
     A MACRO THE LEAK CENSUS CANNOT SEE.

     `varasm.cc:2192' is the only shared consumer, an `#ifdef' with no `#else'.
     s390 is the ONLY back end that defines the macro and i386 does not, so the
     condition was false for all 47 bases and the body never ran anywhere: a
     leaked ABSENCE, the half of this defect class that produces no diagnostic
     of any kind.  s390 stopped emitting

	 .machinemode push / .machine push
	 .machinemode zarch / .machine "z900"

     around any function carrying `#pragma GCC target' or `target(...)'.  That
     is board item #4, recorded there as "the whole of that target's residual".

     WHY THE CENSUS MISSES IT, which is worth more than the macro.  The census
     population is `doc/tm.texi's own `@defmac' list, chosen so the census
     "cannot be accused of having chosen its own population" -- a real
     property, and the reason its 296 is quotable.  ASM_OUTPUT_FUNCTION_PREFIX
     is not documented in tm.texi at all.  So the authority that makes the
     census trustworthy is exactly what makes it blind here, and no amount of
     re-running it would ever have produced this row.  An undocumented target
     macro is a THIRD population beside LEAK-PRIMARY and DEAD-DEFAULT.

     Both s390 functions guard on `DECL_FUNCTION_SPECIFIC_TARGET', so push and
     pop are balanced by construction -- which is also why converting only
     `declare_function_size' would have been a half-fix rather than a partial
     improvement.  */
  void (*declare_function_prefix) (FILE *file, const char *name);

  /* ADJUST_INSN_LENGTH -- A DEAD `#ifdef' IN BRANCH SHORTENING, AND THE SECOND
     UNDOCUMENTED MACRO FOUND BY THE SAME SCAN.

     Four sites in `final.cc' (:404, :1111, :1131, :1368), every one an
     `#ifdef'.  i386 defines no ADJUST_INSN_LENGTH, so all four were FALSE for
     all 47 bases and the adjustment ran for NONE of the 13 back ends that
     define it: rx, mips, avr, sh, iq2000, msp430, v850, rs6000, arc, arm, pa,
     nds32 and aarch64.

     WHAT IT IS FOR, and why "merely worse code" is the wrong reading.  The
     macro's whole purpose is to correct an insn's length AFTER the generated
     `insn-attrtab' has computed it, and `shorten_branches' uses those lengths
     to decide whether a branch displacement is in range.  A length that is too
     SMALL is not a missed optimisation -- it lets the compiler emit a branch
     it believes reaches and which does not.  For arm, pa, sh, mips and avr
     this is core branch-shortening correctness.

     aarch64's is narrower and is stated exactly rather than overclaimed:
     `aarch64.h:1038' adds 4 bytes when `aarch64_madd_needs_nop (insn)', which
     is the Cortex-A53 erratum 835769 workaround and is gated on
     `-mfix-cortex-a53-835769'.  So on a default aarch64 compilation this macro
     is a no-op, and the movement expected on the scored board from THIS back
     end is small.  It is converted because it is a live wrong-code leak on 13
     back ends, not because a number is predicted to move.

     Not in `doc/tm.texi'.  Found by `-undoc.sh', the scan written after
     ASM_OUTPUT_FUNCTION_PREFIX showed that the census's tm.texi-derived
     population has a blind spot -- so the scan has now produced a second
     member of its own class, which is the argument for keeping it.  */
  void (*adjust_insn_length) (rtx_insn *insn, int *length);

  /* ADDR_VEC_ALIGN -- JUMP-TABLE ALIGNMENT, AND THE `.align' LEAK ONE MACRO
     OVER.

     Three consumers, all in `final.cc' (:894, :1153, :2480), and the leak
     hides behind a `#ifndef' rather than an `#ifdef', which is why it reads
     as harmless.  `final.cc:485' says

	 #ifndef ADDR_VEC_ALIGN
	 static int final_addr_vec_align (...) { ... }
	 #define ADDR_VEC_ALIGN(ADDR_VEC) final_addr_vec_align (ADDR_VEC)
	 #endif

     and i386 defines no ADDR_VEC_ALIGN, so that block was taken for ALL 47
     BASES.  Every back end got the generic `GET_MODE_SIZE' computation and
     the **12 that define the macro never got their own answer**:

	 aarch64  0        vax    0        csky  0
	 sh 2     pa 2     nds32 2         xstormy16 1
	 ia64     (SImode ? 2 : 3)         arm, arc  computed
	 nvptx / c6x        (JUMP_TABLES_IN_TEXT_SECTION ? 5 : 2)

     aarch64 and vax ask for **0** -- no alignment at all -- and were given
     `exact_log2 (GET_MODE_SIZE (mode))` instead, so every jump table on those
     targets is over-aligned. That is the same family as the `.align 256`
     defect the previous board fixed, where i386's `ASM_OUTPUT_ALIGN` reached
     riscv and aarch64 was found over-aligning arrays by 4096x. This is the
     jump-table half of it.

     NOTE THE `#ifdef` AT `final.cc:2479` WAS DEAD. It had an `#else` giving
     `exact_log2 (BIGGEST_ALIGNMENT / BITS_PER_UNIT)`, and that arm could
     never be taken, because the `#ifndef` above had already defined the name
     for exactly the bases that would have wanted it. Two fallbacks, one of
     them unreachable, disagreeing about the answer.

     THE FALLBACK IS SUPPLY-SIDE AND STAYS. `final_addr_vec_align` is now
     non-static (declared in `output.h`) and the thunk calls it for a base
     defining no macro. That is upstream's own answer for such a back end,
     reached in that base's own translation unit -- the kind PRINCIPLES
     permits -- and it is the SAME function rather than a restatement, so it
     cannot drift.

     Not in `doc/tm.texi`: the third member of the undocumented population,
     and the one `-undoc.sh`'s control is now anchored on. Re-anchor that
     control before relying on it again.  */
  int (*addr_vec_align) (rtx_jump_table_data *table);
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

/* `EPILOGUE_USES'.  One shared consumer, `df-scan.cc:3647', an ordinary
   run-time expression with no `#ifdef' around it, so a call-valued redirect in
   `multi-target-macros.h' is legal.  */
extern bool mt_epilogue_uses (int);

/* `PROMOTE_MODE'.  Spelled at the call site rather than redirected, for the
   `ASM_DECLARE_FUNCTION_NAME' reason below: all four sites are `#ifdef'
   pairs, and a redirect would leave the GUARD answered by the primary (i386
   defines the macro, so the guard is true for everybody) while the BODY was
   answered by the selected base -- so the 16 bases that define no
   `PROMOTE_MODE' would silently start promoting.  `mt_has_promote_mode ()'
   is the guard and `mt_promote_mode' the body.  */
extern bool mt_has_promote_mode (void);
extern void mt_promote_mode (scalar_mode *, int *, const_tree);

/* `ASM_DECLARE_FUNCTION_NAME' / `ASM_OUTPUT_FUNCTION_LABEL'.  Spelled at the
   call site rather than redirected, because the site is an `#ifdef' pair and
   a redirect would leave the GUARD answered by the primary while the BODY was
   answered by the selected base -- the shape target-frame.h's `DATA_ALIGNMENT'
   note already refuses.  `varasm.cc:2218's whole `#ifdef' block becomes one
   call.  */
extern void mt_declare_function_name (FILE *, const char *, tree);
extern void mt_declare_cold_function_name (FILE *, const char *, tree);

/* `ASM_DECLARE_FUNCTION_SIZE', the closing half of the pair above.  Spelled at
   the call site for the same reason: `varasm.cc:2254's block is an `#ifdef'
   and a redirect would leave the GUARD answered by whichever base compiled
   varasm.cc.  See the descriptor field for what the leaked answer costs on
   riscv and s390.  */
extern void mt_declare_function_size (FILE *, const char *, tree);

/* `ASM_OUTPUT_FUNCTION_PREFIX', the opening half.  s390's only, undocumented
   in tm.texi, and therefore invisible to the leak census.  See the descriptor
   field.  */
extern void mt_declare_function_prefix (FILE *, const char *);

/* `ADJUST_INSN_LENGTH'; `final.cc' :404, :1111, :1368.  `length' is in/out
   because every back end's macro assigns to its LENGTH parameter in place.
   Unconditional at all three call sites: a base defining no such macro gets a
   thunk with an empty body, which is the same nothing the dead `#ifdef' did --
   the difference being that the 13 bases which DO define it now get theirs.  */
extern void mt_adjust_insn_length (rtx_insn *, int *);

/* `ADDR_VEC_ALIGN'; `final.cc' :894, :1153, :2480.  Jump-table alignment.
   aarch64 and vax ask for 0 and were given the generic computation; see the
   descriptor field.  */
extern int mt_addr_vec_align (rtx_jump_table_data *);

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

/* The stack-alignment closure.  `defaults.h' points all four macros at these
   for every translation unit that is not a back end's own.  Unlike
   `DATA_ALIGNMENT' these ARE redirected rather than being spelled at the call
   sites: none of their 35 shared uses is `#ifdef'-guarded, so there is no
   guard that could end up answered by a different back end than the body.  */
extern unsigned int mt_incoming_stack_boundary (void);
extern unsigned int mt_max_stack_alignment (void);
extern unsigned int mt_max_supported_stack_alignment (void);
extern bool mt_supports_stack_alignment (void);

/* THE ELIMINATION TABLE, for shared code.  `INITIAL_ELIMINATION_OFFSET' IS
   redirected in `defaults.h' -- its 14 shared uses are all ordinary
   assignments through the third argument, with no `#if', no case label, no
   array bound and no `#ifdef' guard, so a call-valued redirect is legal.

   `ELIMINABLE_REGS' IS NOT REDIRECTED AND CANNOT BE: it is a brace
   initialiser, and there is no run-time spelling of a brace initialiser to
   point it at.  Its eight consumers are rewritten to walk these accessors
   instead, and `defaults.h' then POISONS the name for shared translation
   units, so a ninth consumer added later is a compile error naming the
   replacement rather than one more copy of the primary's four pairs.

   The two `from'/`to' readers range check and fail by name.  An out-of-range
   index here would read whatever int follows the table, and a register number
   is exactly the kind of value that stays plausible while being wrong.  */
extern int mt_num_eliminable_regs (void);
extern int mt_eliminable_from (int i);
extern int mt_eliminable_to (int i);

/* reload's own table.  Separate from the three above because a back end may
   define `RELOAD_ELIMINABLE_REGS'; see target-frame.h's field comment.  */
extern int mt_num_reload_eliminable_regs (void);
extern int mt_reload_eliminable_from (int i);
extern int mt_reload_eliminable_to (int i);

extern poly_int64 mt_initial_elimination_offset (int from, int to);

/* `Pmode'.  648 use sites outside `config/', `testsuite/' and
   `ada/gcc-interface/' -- and every one of them is an ordinary run-time
   expression.  Swept before redirecting, because a redirect to a call is only
   possible if no site needs a constant: no `#if'/`#elif' line in shared code
   names it, no `case' label, no array bound, no static initialiser, and no
   `#ifdef Pmode' anywhere outside two back ends' own headers
   (`mips.h:2751', `loongarch.h:855', both `#ifndef', both in translation
   units that keep the real macro).  */
extern scalar_int_mode mt_pmode (void);

/* THE OPTION-STATE FAMILY, for shared code.  See the field comments above for
   the values, for why all three are calls rather than cached constants
   (`BIGGEST_ALIGNMENT' moves within one compilation under
   `__attribute__((target("avx512f")))'), for the eleven `defaults.h' names
   that inherit the redirect by ordinary macro expansion, and for the
   `MIN_UNITS_PER_WORD' array bound that is the closure.

   THE RETURN TYPES ARE NOT ARBITRARY.  `UNITS_PER_WORD' is signed because
   shared code divides and subtracts with it freely and an unsigned answer
   would turn `x - UNITS_PER_WORD' into a huge positive number at every site
   that goes negative; the other two are unsigned because they are widths and
   alignments compared against unsigned quantities, and because a call is not
   a constant expression -- `-Wsign-compare' stays quiet on a signed CONSTANT
   known to be non-negative and does not stay quiet on a signed CALL, so the
   signedness that was invisible while these were macros becomes visible the
   moment they are functions.  */
extern int mt_units_per_word (void);
extern unsigned int mt_pointer_size (void);
extern unsigned int mt_biggest_alignment (void);

/* `FUNCTION_MODE', redirected in `defaults.h'.  See the field comment above
   for the insn dump that diagnosed the `recog.cc:2890' wall with it.  */
extern machine_mode mt_function_mode (void);

/* THE DWARF REGISTER-NUMBERING FAMILY.  See the three field comments for the
   measurement, for why `DWARF_FRAME_REGNUM' is not derived from
   `DEBUGGER_REGNO', and for why `DWARF_FRAME_REGISTERS' has to move with them.

   SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE REDIRECTING, over all of
   `gcc/' outside `config/', `testsuite/' and `ada/gcc-interface/'.  The three
   have 5, 4 and 2 shared use sites respectively (`DEBUGGER_REGNO' in
   dwarf2out.cc x4 and except.cc x1; `DWARF_FRAME_REGNUM' in dwarf2cfi.cc x3
   and dwarf2out.cc x2 plus defaults.h's own derivations;
   `DWARF_FRAME_REGISTERS' in dwarf2cfi.cc:302 and c-cppbuiltin.cc:1630), and
   every one is an ordinary run-time expression: no `#if', no case label, no
   array bound, no static initialiser.

   ONE `#ifdef' EXISTS AND IS DELIBERATELY LEFT WORKING.  except.cc:2193 is

       #ifdef DWARF_FRAME_REGNUM
         iwhich = DWARF_FRAME_REGNUM (iwhich);
       #else
         iwhich = DEBUGGER_REGNO (iwhich);
       #endif

   Both names stay DEFINED by the redirect, so that guard keeps taking the
   branch it takes today, and -- unlike `DATA_ALIGNMENT' -- there is no risk of
   the guard being answered by one back end and the body by another, because
   after the redirect both arms call the same selected back end.  Note that
   the `#ifdef' itself is still answered by whichever base compiled except.cc;
   that is a residual class-(d)-adjacent fact recorded in STATE.md, not
   something this change can fix, and it is harmless HERE only because the two
   arms now agree.  */
extern unsigned int mt_debugger_regno (unsigned int regno);
extern unsigned int mt_dwarf_frame_regnum (unsigned int regno);
extern unsigned int mt_dwarf_frame_registers (void);
/* Uncached, like the two above and for a stronger reason than they have: on
   epiphany this varies per FUNCTION, not merely per option state.  See the
   field comment.  */
extern unsigned int mt_dwarf_frame_return_column (void);
/* `DWARF2_UNWIND_INFO' for the selected base.  Shared code does NOT call this
   directly -- see the definition in target-cumargs-select.cc for the archive
   boundary that forbids it, and `mt_dwarf2_unwind_info_hook' in
   common/common-targhooks.h for the pointer it travels through.  */
extern int mt_dwarf2_unwind_info (void);

/* THE FOUR POINTER REGNUMS AND THE TWO DERIVED PREDICATES, for shared code.
   See the field comments above for why all six move as one set and why they
   are calls rather than constants.

   ALL SIX ARE REDIRECTED IN `defaults.h', which required removing the only
   thing that stopped them being run-time values: the per-target SHAPE of
   `enum global_rtl_index' at rtl.h.  That enum now has a distinct slot for
   each of the three pointers on every back end, and `init_emit_regs' does the
   aliasing by storing one rtx OBJECT in two slots.  The invariant the enum
   used to enforce is about rtx identity, not slot identity; rtl.h carries the
   evidence for that reading and t127-guards.sh ARM 5 and ARM 6 measure it in
   the running cc1.

   SWEPT BEFORE REDIRECTING, over all of `gcc/' outside `config/',
   `testsuite/' and `ada/gcc-interface/': every `#if'/`#elif' line naming any
   of the six is either inside rtl.h itself (deleted), or one of the two
   `#if !HARD_FRAME_POINTER_IS_ARG_POINTER' sites (emit-rtl.cc and
   dwarf2out.cc, both rewritten as run-time conjuncts of the expression they
   guarded), or `reginfo.cc:792', which is a `#ifdef' and stays true because
   the redirect keeps the name defined.  Of the remaining shared uses none is
   a case label, an array bound or a static initialiser -- the bracketed ones
   are all subscripts of run-time tables (`fixed_regs[ARG_POINTER_REGNUM]',
   `static_reg_base_value[STACK_POINTER_REGNUM]', `regno_reg_rtx[...]'), which
   a call-valued macro serves correctly.  */
extern unsigned int mt_stack_pointer_regnum (void);
extern unsigned int mt_frame_pointer_regnum (void);
extern unsigned int mt_hard_frame_pointer_regnum (void);
extern unsigned int mt_arg_pointer_regnum (void);
extern bool mt_hard_frame_pointer_is_frame_pointer (void);
extern bool mt_hard_frame_pointer_is_arg_pointer (void);

/* RETURN_ADDRESS_POINTER_REGNUM, for shared code; see the field comment.
   NOT redirected in `defaults.h', deliberately: every shared reader spells it
   inside an `#ifdef RETURN_ADDRESS_POINTER_REGNUM', so a redirect would leave
   the name defined, keep all four guards TRUE for all 47 back ends, and hand
   the 42 with no return address pointer a call that must not be made.  The
   existence question is the thing being converted, so the four call sites ask
   `mt_has_return_address_pointer ()' directly and the macro is not redefined
   at all.  */
extern bool mt_has_return_address_pointer (void);
extern unsigned int mt_return_address_pointer_regnum (void);

/* THE TWO CFA-AT-ENTRY OFFSETS, for shared code.  See the field comments
   above for the gdb reading that named them and for why they move as a pair.
   Both are redirected in `defaults.h'; `DEFAULT_INCOMING_FRAME_SP_OFFSET' is
   redirected THERE rather than left to dwarf2cfi.cc's own `#ifndef' fallback,
   because that fallback is an existence question and it was being answered by
   whichever base compiled dwarf2cfi.cc.  */
extern HOST_WIDE_INT mt_incoming_frame_sp_offset (void);
extern HOST_WIDE_INT mt_default_incoming_frame_sp_offset (void);
extern bool mt_accumulate_outgoing_args (void);

/* `STACK_DYNAMIC_OFFSET', for shared code.  NOT redirected in `defaults.h',
   and deliberately so: `function.cc''s `get_stack_dynamic_offset ()' is the
   only place in the tree that evaluated the macro, so the call goes there
   directly and the shared definition is gone entirely -- the same treatment
   `mt_init_expanders' gave `#ifdef INIT_EXPANDERS' rather than redirecting a
   name that would then still be spellable.  */
extern poly_int64 mt_stack_dynamic_offset (tree fndecl);

/* `PUSH_ARGS_REVERSED', for shared code.  Redirected in `defaults.h' rather
   than called directly, because unlike `STACK_DYNAMIC_OFFSET' the name is
   spelled at its use site (gimplify.cc) and defaults.h's own ladder is what
   has to be displaced there.  */
extern bool mt_push_args_reversed (void);

/* `INCOMING_REG_PARM_STACK_SPACE', for shared code.  NOT redirected in
   `defaults.h': like `STACK_DYNAMIC_OFFSET' it has exactly one shared use
   (function.cc:2322) and that use is an `#ifdef', which a redirect cannot
   help with.  The call replaces the guard and the body together, and the
   name stays undefined in shared code so a future spelling fails by name.  */
extern int mt_incoming_reg_parm_stack_space (tree fndecl);

/* `REG_PARM_STACK_SPACE', for shared code -- calls.cc and expr.cc.  NOT
   redirected in `defaults.h' for the reason `FRAME_POINTER_CFA_OFFSET' cannot
   be redirected at all: the name is `#ifdef'-tested at twelve shared sites,
   and defining it to a call would make every one of those guards TRUE for
   every target.  Position of use decides shape, so the guards are replaced by
   `if (mt_has_reg_parm_stack_space ())' and the value uses by
   `mt_reg_parm_stack_space (...)', and `defaults.h' then `#undef's the name so
   that a future shared spelling fails to compile rather than picking up the
   primary's.  */
extern bool mt_has_reg_parm_stack_space (void);
extern int mt_reg_parm_stack_space (tree fndecl_or_type);

/* `PUSH_ROUNDING', for shared code.  Not redirected either, and for the same
   reason: the name is `#ifdef'-tested at nineteen shared sites.  `defaults.h'
   `#undef's it after this header is included.

   ONE OF THE NINETEEN IS NOT A VALUE QUESTION AT ALL AND CHANGES BEHAVIOUR:
   `combine-stack-adj.cc''s pass gate is `#ifndef PUSH_ROUNDING', so today the
   whole `if (ACCUMULATE_OUTGOING_ARGS) return false;' is COMPILED OUT for
   every target because the primary defines the macro.  Converting it turns
   that early return on for the 38 back ends with no `PUSH_ROUNDING' --
   including aarch64, so it is observable on the configured pair.  */
extern bool mt_has_push_rounding (void);
extern poly_int64 mt_push_rounding (poly_int64 bytes);

/* `CASE_VECTOR_PC_RELATIVE' and `REGMODE_NATURAL_SIZE', for shared code.  Both
   ARE redirected in `multi-target-macros.h': neither name is `#ifdef'-tested
   anywhere in shared code, so unlike `PUSH_ROUNDING' there is no guard that
   could end up answered by a different back end than the body.  See the field
   comments above for the two ICE columns they were producing.  */
extern bool mt_case_vector_pc_relative (void);
extern poly_uint64 mt_regmode_natural_size (machine_mode mode);

/* `CASE_VECTOR_MODE' and `INCOMING_RETURN_ADDR_RTX', for shared code.  Both
   are redirected in `multi-target-macros.h'.  See the field comments above for
   why the `target-cdata.h:166' mode deferral does not reach the first, and for
   the CFI row the second was corrupting.

   THE SECOND IS `#ifdef'-TESTED IN SHARED CODE AND THE FIRST IS NOT, which is
   the one asymmetry between them.  `df-scan.cc:3558' guards its use with
   `#ifdef INCOMING_RETURN_ADDR_RTX'.  A redirect keeps the name defined, so
   that guard stays true -- which is CORRECT here and not a leak, because the
   thing behind it is now a call to the selected back end rather than to
   whichever base compiled `df-scan.cc'.  The existence question that guard is
   really asking is answered by `mt_has_incoming_return_addr_rtx ()', and
   `df-scan.cc' now asks it that way instead of by `#ifdef'.  A base that
   defines nothing answers `false' there and hits `dwarf2cfi.cc:52's
   `gcc_unreachable ()' by name if the VALUE is ever asked for anyway.  */
extern machine_mode mt_case_vector_mode (void);
extern bool mt_has_incoming_return_addr_rtx (void);
extern rtx mt_incoming_return_addr_rtx (void);

#endif /* GCC_TARGET_FRAME_H */
