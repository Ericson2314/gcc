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

#endif /* GCC_TARGET_FRAME_H */
