/* One back end's argument-accumulator entry points, in its own headers.
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

/* Compiled once per back end, with `-I<base>-inc' so every header it reaches
   is that back end's.  The SUPPLY side of target-cumargs.h; see that file for
   why five macros and why not a `target.def' hook.

   Two things happen here that can happen nowhere else:

     * the five macros are expanded in the translation unit whose `tm.h' is
       this back end's, so `INIT_CUMULATIVE_ARGS' means `aarch64_init_
       cumulative_args' for aarch64 and `init_cumulative_args' for i386;

     * `sizeof' and `alignof' of THIS back end's `CUMULATIVE_ARGS' are
       measured and checked against the union bound.  That check is the
       acceptance bar of the whole change: a base that outgrows the bound is
       a compile error naming this file and this base, rather than 88 bytes
       written past the end of a stack frame.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#include "rtl.h"
#include "tree.h"
#include "memmodel.h"
/* For the back end's own declaration of whatever INIT_CUMULATIVE_ARGS
   expands to -- `aarch64_init_cumulative_args' is declared in
   aarch64-protos.h, which is this base's tm_p.h.  */
#include "tm_p.h"
#include "target.h"
/* For `cfun'.  i386's `INCOMING_FRAME_SP_OFFSET' (i386.h:2177) reads
   `cfun->machine->func_type', and reading it HERE -- in a translation unit
   compiled with i386's own `machine_function' declaration AND i386's own
   `tm.h' -- is the entire point of the thunk: shared code read that same
   bitfield out of aarch64's object and got TYPE_EXCEPTION.  */
#include "function.h"
#include "multi-target-reg-widths.h"
/* THIS BASE'S insn-config.h, and that is the entire mechanism for the three
   booleans at the bottom of this file: `-I<base>-inc' comes ahead of `-I.' on
   this file's command line, so the quoted include resolves to
   `<base>-inc/insn-config.h', which is one line including
   `insn-config-<base>.h'.  In the build root the same spelling resolves to
   whichever base wrote the plain file, which is the bug.  */
#include "insn-config.h"
/* THIS BASE'S insn-attr.h, by the same `-I<base>-inc' mechanism and for the
   same reason.  It is what makes `get_attr_preferred_for_size' below mean
   `insn_aarch64::get_attr_preferred_for_size' where the attribute exists and
   `hook_int_rtx_1' where it does not -- the generated header carries both
   answers already, and this file simply gets compiled once per base so that
   it picks up each.  See target-attr.h.  */
#include "insn-attr.h"
#include "target-cumargs.h"

/* NO APOSTROPHE IN EITHER MESSAGE.  An unpaired quote in a #error draws a
   "missing terminating character" warning on top of the error -- target-regs.cc
   has one and it shows up in every build -- and this branch measures stderr.  */
#ifndef MULTI_TARGET_TARGETM_BASE
#error target-cumargs.cc must be compiled for one particular back end (it needs \
the real INIT_CUMULATIVE_ARGS of that base, not the one belonging to whichever \
base compiled the middle end)
#endif

#ifndef TARGETM_CUMARGS_SYMBOL
#error target-cumargs.cc must be compiled with -DTARGETM_CUMARGS_SYMBOL naming \
the table for this back end
#endif

/* THE BOUND, CHECKED.  These two are why the file is worth having even for a
   back end that defines none of the optional macros.

   `<=' and not `==': the bound is the maximum over the configured bases, so
   every base but the largest is strictly under it.  The largest sits exactly
   AT it, with no slack, deliberately -- the same shape as the `9 <= 9' pair
   `52fa9e763c5' left in optc-save-gen.awk.  A bound with slack would hide the
   next base that grows.  */
static_assert ((int) sizeof (CUMULATIVE_ARGS)
	       <= MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE,
	       "this back end's CUMULATIVE_ARGS is bigger than the union bound "
	       "in multi-target-reg-widths.h, so shared code would allocate "
	       "too little for it; gen-reg-widths.sh did not see this base");
static_assert ((int) alignof (CUMULATIVE_ARGS)
	       <= MULTI_TARGET_UNION_CUMULATIVE_ARGS_ALIGN,
	       "this back end's CUMULATIVE_ARGS needs stricter alignment than "
	       "the union bound in multi-target-reg-widths.h; "
	       "gen-reg-widths.sh did not see this base");

static void
mt_base_init_args (cumulative_args_t ca, tree fntype, rtx libname,
		   tree fndecl, int n_named_args)
{
  INIT_CUMULATIVE_ARGS (*get_cumulative_args (ca), fntype, libname, fndecl,
			n_named_args);
}

/* function.cc's `#ifdef INIT_CUMULATIVE_INCOMING_ARGS' / `#else', answered by
   this base rather than by the primary.  Both arms are upstream's, unchanged.  */
static void
mt_base_init_incoming_args (cumulative_args_t ca, tree fntype, rtx libname)
{
#ifdef INIT_CUMULATIVE_INCOMING_ARGS
  INIT_CUMULATIVE_INCOMING_ARGS (*get_cumulative_args (ca), fntype, libname);
#else
  INIT_CUMULATIVE_ARGS (*get_cumulative_args (ca), fntype, libname,
			current_function_decl, -1);
#endif
}

/* calls.cc's `#ifdef INIT_CUMULATIVE_LIBCALL_ARGS' / `#else', likewise.  */
static void
mt_base_init_libcall_args (cumulative_args_t ca, machine_mode outmode, rtx fun,
			   int nargs ATTRIBUTE_UNUSED)
{
#ifdef INIT_CUMULATIVE_LIBCALL_ARGS
  INIT_CUMULATIVE_LIBCALL_ARGS (*get_cumulative_args (ca), outmode, fun);
#else
  (void) outmode;
  INIT_CUMULATIVE_ARGS (*get_cumulative_args (ca), NULL_TREE, fun, 0, nargs);
#endif
}

/* calls.cc's `#ifdef CALL_POPS_ARGS'.  The 0 is what the absent `#ifdef' arm
   already contributed for every back end but i386; it is this base's answer,
   not a fallback to another base's.  */
static int
mt_base_call_pops_args (cumulative_args_t ca ATTRIBUTE_UNUSED)
{
#ifdef CALL_POPS_ARGS
  return CALL_POPS_ARGS (*get_cumulative_args (ca));
#else
  return 0;
#endif
}

/* `allocate_struct_function's `#ifdef OVERRIDE_ABI_FORMAT'.  This is the one
   the aarch64 arm dies on today: function.cc is compiled against i386's tm.h,
   so `ix86_call_abi_override' runs for every function of every target.  */
static void
mt_base_override_abi_format (tree fndecl ATTRIBUTE_UNUSED)
{
#ifdef OVERRIDE_ABI_FORMAT
  OVERRIDE_ABI_FORMAT (fndecl);
#endif
}

/* ------------------------------------------------------------------------
   THE FRAME AND ARGUMENT-REGISTER ANSWERS; see target-frame.h.

   Each thunk is one macro expansion, in the translation unit whose `tm.h' is
   this back end's.  That is the entire mechanism, and it is worth being blunt
   about what it buys: in shared code `STACK_BOUNDARY' means
   `(TARGET_64BIT_MS_ABI ? 128 : BITS_PER_WORD)' evaluated against i386's
   headers, for aarch64 too.  Here it means aarch64's 128 when this file is
   compiled with `-Iaarch64-inc' and i386's expression when it is compiled with
   `-Ii386-inc'.

   Nothing below has an `#else' arm or a default, because none of these six is
   an existence predicate: `defaults.h' gives all but STACK_BOUNDARY and
   FUNCTION_ARG_REGNO_P a generic definition, and a base that does not define
   its own gets that generic one HERE, in its own translation unit, rather than
   getting the primary's answer.  That is the difference the whole file exists
   to make, and it is why these thunks look trivial.  */

static int
mt_base_stack_boundary (void)
{
  return STACK_BOUNDARY;
}

static int
mt_base_preferred_stack_boundary (void)
{
  return PREFERRED_STACK_BOUNDARY;
}

/* ATTRIBUTE_UNUSED on the parameters below is not defensive: `defaults.h's
   generic MINIMUM_ALIGNMENT is `(ALIGN)' and its generic STACK_SLOT_ALIGNMENT
   ignores MODE, so for a base that defines neither -- aarch64 is one -- these
   really do go unused, and this branch measures stderr.  It is a no-op for a
   base that uses them.  */

static unsigned int
mt_base_stack_slot_alignment (tree type ATTRIBUTE_UNUSED,
			      machine_mode mode ATTRIBUTE_UNUSED,
			      unsigned int align ATTRIBUTE_UNUSED)
{
  return STACK_SLOT_ALIGNMENT (type, mode, align);
}

static unsigned int
mt_base_minimum_alignment (tree exp ATTRIBUTE_UNUSED,
			   machine_mode mode ATTRIBUTE_UNUSED,
			   unsigned int align ATTRIBUTE_UNUSED)
{
  return MINIMUM_ALIGNMENT (exp, mode, align);
}

static int
mt_base_outgoing_reg_parm_stack_space (tree fntype ATTRIBUTE_UNUSED)
{
  return OUTGOING_REG_PARM_STACK_SPACE (fntype);
}

static bool
mt_base_function_arg_regno_p (int regno ATTRIBUTE_UNUSED)
{
  return FUNCTION_ARG_REGNO_P (regno);
}

/* INIT_EXPANDERS, asked of THIS base.  See target-frame.h for why an existence
   predicate is a different animal from the six value thunks above.

   The `#ifdef' is the SAME `#ifdef' emit-rtl.cc used to spell; the only thing
   that changed is which translation unit evaluates it, and therefore which
   back end it is a fact about.  In emit-rtl.cc it was a fact about i386 (which
   defines no INIT_EXPANDERS) applied to all 48 back ends.  Here it is a fact
   about MULTI_TARGET_TARGETM_BASE, because this file is compiled once per base
   with `-I<base>-inc'.

   Note there is deliberately no `#else' arm supplying a generic
   INIT_EXPANDERS.  Unlike STACK_SLOT_ALIGNMENT above, defaults.h has no
   generic definition to fall back on, and inventing one would be the
   `#ifndef' floor PRINCIPLES forbids.  A base with no INIT_EXPANDERS has
   nothing to run, and says so through `has_init_expanders' below rather than
   through a null pointer that could equally mean a stale object.  */
#ifdef INIT_EXPANDERS
static void
mt_base_init_expanders (void)
{
  INIT_EXPANDERS;
}
# define MT_BASE_HAS_INIT_EXPANDERS true
# define MT_BASE_INIT_EXPANDERS mt_base_init_expanders
#else
# define MT_BASE_HAS_INIT_EXPANDERS false
# define MT_BASE_INIT_EXPANDERS NULL
#endif

/* THE MOVE/CLEAR FAMILY, asked of THIS base; see target-frame.h for why all
   seven move together and why `MAX_MOVE_MAX' does not move with them.

   Every one of these is one macro expansion in a translation unit whose
   `tm.h' is this back end's, which is the entire mechanism.  Four of the
   seven have no definition in most back ends and pick up `defaults.h's
   generic one HERE -- and that is the point rather than an accident: the
   generic `STORE_MAX_PIECES' is `MIN (MOVE_MAX_PIECES, 2 * sizeof
   (HOST_WIDE_INT))', so evaluating it here computes it from THIS base's
   `MOVE_MAX' instead of from the primary's.

   The casts to `int' are not cosmetic.  `MIN' against `sizeof' makes the
   generic `STORE_MAX_PIECES' `size_t', and returning that through an `int'
   field without saying so would be a silent narrowing on exactly the
   member whose whole job is to be a byte count.  Every base's value is a
   small positive constant, so the cast loses nothing; it is written down so
   that a base whose value ever stops being small fails a review rather than
   wrapping.  */

static int
mt_base_move_max (void)
{
  return (int) MOVE_MAX;
}

static int
mt_base_move_max_pieces (void)
{
  return (int) MOVE_MAX_PIECES;
}

static int
mt_base_store_max_pieces (void)
{
  return (int) STORE_MAX_PIECES;
}

static int
mt_base_compare_max_pieces (void)
{
  return (int) COMPARE_MAX_PIECES;
}

static int
mt_base_move_ratio (bool speed)
{
  return (int) MOVE_RATIO (speed);
}

static int
mt_base_clear_ratio (bool speed)
{
  return (int) CLEAR_RATIO (speed);
}

static int
mt_base_set_ratio (bool speed)
{
  return (int) SET_RATIO (speed);
}

/* `DATA_ALIGNMENT' and `DATA_ABI_ALIGNMENT', with the `(has_X, payload)'
   shape.  See target-frame.h for why this pair carries a flag and the seven
   above do not, and for the gdb confirmation that i386's implementation of
   both faults on `int x = 1;' when aarch64 is selected.

   The `#ifdef' is the SAME `#ifdef' varasm.cc used to spell.  What changed
   is which translation unit evaluates it, and therefore which back end it is
   a fact about: in varasm.cc it was a fact about i386 applied to all 48 back
   ends.

   No `#else' arm supplies a generic macro, because there is no generic macro
   to supply -- `defaults.h' has none for either name, and inventing one
   would be the floor PRINCIPLES forbids.  The identity behaviour a base with
   neither macro needs lives in the SELECTION side, where "this base has
   none" is a checked state rather than a silently missing definition.  */
#ifdef DATA_ALIGNMENT
static unsigned int
mt_base_data_alignment (tree type, unsigned int align)
{
  return DATA_ALIGNMENT (type, align);
}
# define MT_BASE_HAS_DATA_ALIGNMENT true
# define MT_BASE_DATA_ALIGNMENT mt_base_data_alignment
#else
# define MT_BASE_HAS_DATA_ALIGNMENT false
# define MT_BASE_DATA_ALIGNMENT NULL
#endif

#ifdef DATA_ABI_ALIGNMENT
static unsigned int
mt_base_data_abi_alignment (tree type, unsigned int align)
{
  return DATA_ABI_ALIGNMENT (type, align);
}
# define MT_BASE_HAS_DATA_ABI_ALIGNMENT true
# define MT_BASE_DATA_ABI_ALIGNMENT mt_base_data_abi_alignment
#else
# define MT_BASE_HAS_DATA_ABI_ALIGNMENT false
# define MT_BASE_DATA_ABI_ALIGNMENT NULL
#endif

/* THE STACK-ALIGNMENT CLOSURE, asked of THIS base; see target-frame.h for why
   all four move together and for why the one the `nm' output names is not the
   one that stops `big.c'.

   Four macro expansions in a translation unit whose `tm.h' is this back end's.
   Two of the four are defined by this back end (i386's
   `INCOMING_STACK_BOUNDARY' and `MAX_STACK_ALIGNMENT') and two are always
   `defaults.h's; for aarch64 all four are `defaults.h's, computed HERE from
   aarch64's own `STACK_BOUNDARY' and `PREFERRED_STACK_BOUNDARY' rather than
   from the primary's.

   No `#ifdef' and no `#else' arm anywhere below, and that is the point rather
   than an oversight: `defaults.h:1249's `#ifdef MAX_STACK_ALIGNMENT' has
   ALREADY RUN by the time control reaches here, against this base's headers,
   and has already chosen which of the two definitions of
   `MAX_SUPPORTED_STACK_ALIGNMENT' is in force.  Repeating the test here would
   ask the same question twice and offer a second place for the two answers to
   disagree.  */

static unsigned int
mt_base_incoming_stack_boundary (void)
{
  return (unsigned int) INCOMING_STACK_BOUNDARY;
}

static unsigned int
mt_base_max_stack_alignment (void)
{
  return (unsigned int) MAX_STACK_ALIGNMENT;
}

static unsigned int
mt_base_max_supported_stack_alignment (void)
{
  return (unsigned int) MAX_SUPPORTED_STACK_ALIGNMENT;
}

static bool
mt_base_supports_stack_alignment (void)
{
  return SUPPORTS_STACK_ALIGNMENT;
}

/* THE ELIMINATION TABLE, EVALUATED WHERE IT MEANS THIS BASE.  See
   target-frame.h for why the list and not only the offset function, and for
   the four register numbers that diverge.

   `[][2]' rather than a struct: the middle end's eight copies each declare
   their own `{const int from, to;}' struct, and the initialiser is nested
   braces either way.  Flattening to `&[0][0]' lets target-frame.h carry a
   plain `const int *' with no layout of its own.

   UNSIZED, so the initialiser decides the length and the static_assert below
   compares that length against the union bound.  Writing the bound in would
   silently zero-fill a base whose table is shorter, and a `{0, 0}' pair is an
   elimination FROM register 0 TO register 0 -- a plausible-looking entry that
   nothing downstream would reject.  */
static const int mt_base_eliminables[][2] = ELIMINABLE_REGS;
#define MT_BASE_N_ELIMINABLES ((int) ARRAY_SIZE (mt_base_eliminables))

#ifdef RELOAD_ELIMINABLE_REGS
static const int mt_base_reload_eliminables[][2] = RELOAD_ELIMINABLE_REGS;
#define MT_BASE_N_RELOAD_ELIMINABLES \
  ((int) ARRAY_SIZE (mt_base_reload_eliminables))
#define MT_BASE_RELOAD_ELIMINABLES (&mt_base_reload_eliminables[0][0])
#else
#define MT_BASE_N_RELOAD_ELIMINABLES MT_BASE_N_ELIMINABLES
#define MT_BASE_RELOAD_ELIMINABLES (&mt_base_eliminables[0][0])
#endif

/* WHAT THE UNION COSTS, CHECKED RATHER THAN ASSUMED, in both directions that
   matter.  `reload1.cc' declares `poly_int64 (*offsets_at)[MULTI_TARGET_UNION_
   NUM_ELIMINABLE_REGS]' and indexes it with this base's count; a base above
   the bound would write past the end of every row.  `<=' and not `==': the
   bound is the maximum over the configured bases, so all but the largest are
   strictly under it.  */
static_assert (MT_BASE_N_ELIMINABLES
	       <= MULTI_TARGET_UNION_NUM_ELIMINABLE_REGS,
	       "this back end has more ELIMINABLE_REGS pairs than the union "
	       "bound; multi-target-reg-probe.cc did not see it");
static_assert (MT_BASE_N_RELOAD_ELIMINABLES
	       <= MULTI_TARGET_UNION_NUM_ELIMINABLE_REGS,
	       "this back end has more RELOAD_ELIMINABLE_REGS pairs than the "
	       "union bound; multi-target-reg-probe.cc did not see it");
static_assert (MT_BASE_N_ELIMINABLES > 0,
	       "this back end has an empty ELIMINABLE_REGS");

/* INITIAL_ELIMINATION_OFFSET is a STATEMENT that assigns through its third
   argument -- i386's is `((OFFSET) = ix86_initial_elimination_offset (...))'
   and aarch64's is the same without the outer parentheses -- so it is wrapped
   rather than named, exactly as `ADJUST_REG_ALLOC_ORDER' is in
   target-regs.cc.  Expanding it here is the whole fix: this translation unit
   has THIS base's tm.h, so the function called is this base's.  */
static poly_int64
mt_base_initial_elimination_offset (int from, int to)
{
  poly_int64 offset = 0;
  INITIAL_ELIMINATION_OFFSET (from, to, offset);
  return offset;
}

/* `Pmode', evaluated in THIS base's translation unit.  See target-frame.h for
   the gdb reading that starts this and for why i386's answer in shared code is
   its unconfigured SImode default rather than x86_64's DImode.

   The cast through `machine_mode' and back is not ceremony.  Most back ends'
   `Pmode' is built from a `scalar_int_mode' object and would convert
   implicitly, but some spell a raw `E_*mode' enumerator, which would not; and
   `as_a' asserts that the mode really is a scalar integer, so a back end whose
   `Pmode' is not one fails HERE, by name, in its own translation unit, rather
   than at one of the 648 shared use sites.  */
static scalar_int_mode
mt_base_pmode (void)
{
  return as_a <scalar_int_mode> ((machine_mode) Pmode);
}

/* `FUNCTION_MODE', read in THIS base's translation unit: QImode for i386,
   `Pmode' -- and so DImode -- for aarch64.  Compiled once against i386's tm.h,
   shared code built every target's call MEM as QImode, and aarch64's own
   `recog' refused it.  See target-frame.h for the insn.

   No `as_a' and no assertion, unlike `mt_base_pmode' just above: there is
   nothing to assert.  stormy16, avr, rl78, msp430 and pdp11 all make this
   HImode and nds32, xtensa, riscv and eight others SImode; every value a back
   end writes here is legal, and the only thing that could be wrong is WHOSE
   answer it is.  */
static machine_mode
mt_base_function_mode (void)
{
  return (machine_mode) FUNCTION_MODE;
}

/* THE DWARF REGISTER-NUMBERING FAMILY, evaluated in THIS base's translation
   unit.  See target-frame.h for the gdb reading that diagnosed this, for the
   half of the brief's diagnosis that measured FALSE, and for why all three
   move together.

   THE BOUND CHECK IS THE POINT OF THESE TWO FUNCTIONS, not decoration.  i386's
   macro is a bare subscript into an array declared `[FIRST_PSEUDO_REGISTER]',
   and that name is 92 HERE -- in i386's own translation unit, which this block
   is exempt from defaults.h's union override precisely so that a back end's
   declarations and definitions agree.  Shared code spells the same name at the
   union width, 95, and `expand_builtin_init_dwarf_reg_sizes' really does walk
   `0 .. FIRST_PSEUDO_REGISTER' (dwarf2cfi.cc:334), so with i386 selected it
   asks about 92, 93 and 94.  Without this test that is an out-of-bounds read
   of a const array -- no fault, no diagnostic, a plausible number.

   `INVALID_REGNUM' AND NOT 0 for the out-of-range answer; the reasoning is in
   target-frame.h and the short version is that DWARF register 0 is %rax on one
   base and x0 on the other, so zero is a real register on both.

   Written as a wrapper rather than a named function pointer because both
   macros are function-LIKE and a back end may spell either as a table
   subscript, a call, or a conditional over both -- the same reason
   `INITIAL_ELIMINATION_OFFSET' above is wrapped.  */
static unsigned int
mt_base_debugger_regno (unsigned int regno)
{
  if (regno >= (unsigned int) FIRST_PSEUDO_REGISTER)
    return INVALID_REGNUM;
  return (unsigned int) DEBUGGER_REGNO (regno);
}

static unsigned int
mt_base_dwarf_frame_regnum (unsigned int regno)
{
  if (regno >= (unsigned int) FIRST_PSEUDO_REGISTER)
    return INVALID_REGNUM;
  return (unsigned int) DWARF_FRAME_REGNUM (regno);
}

static unsigned int
mt_base_dwarf_frame_registers (void)
{
  return (unsigned int) DWARF_FRAME_REGISTERS;
}

/* THE FOUR POINTER REGNUMS, read in THIS base's translation unit.  The values
   this pair produces are 7/19/6/16 for i386 and 31/64/29/65 for aarch64, and
   the divergence is the whole content of the `aarch64_can_eliminate' ICE --
   see target-frame.h for the assert and the call site.

   No bound check and no sentinel: these take no argument, so unlike
   `mt_base_debugger_regno' there is no out-of-range case to answer.

   `HARD_FRAME_POINTER_REGNUM' is reached through rtl.h's `#ifndef' fallback
   for a back end that does not define it, and that fallback is evaluated HERE,
   with this base's `FRAME_POINTER_REGNUM' -- which is the point.  rtl.h is
   included by this file, so all four names are in scope with this base's
   answers in force.  */
static unsigned int
mt_base_stack_pointer_regnum (void)
{
  return (unsigned int) STACK_POINTER_REGNUM;
}

static unsigned int
mt_base_frame_pointer_regnum (void)
{
  return (unsigned int) FRAME_POINTER_REGNUM;
}

static unsigned int
mt_base_hard_frame_pointer_regnum (void)
{
  return (unsigned int) HARD_FRAME_POINTER_REGNUM;
}

static unsigned int
mt_base_arg_pointer_regnum (void)
{
  return (unsigned int) ARG_POINTER_REGNUM;
}

/* THE TWO DERIVED PREDICATES, and they are asked HERE rather than derived from
   the four above precisely because six back ends -- arm, mips, xtensa,
   loongarch and gcn -- define them outright as 0 instead of letting rtl.h
   compare the regnums.  Reconstructing them from the regnums in shared code
   would silently discard those six answers.  Neither i386 nor aarch64 defines
   them, so on this pair both come from rtl.h's comparison and both are false;
   that is a measured fact about this pair, not an assumption about the rest.  */
static bool
mt_base_hard_frame_pointer_is_frame_pointer (void)
{
  return HARD_FRAME_POINTER_IS_FRAME_POINTER ? true : false;
}

static bool
mt_base_hard_frame_pointer_is_arg_pointer (void)
{
  return HARD_FRAME_POINTER_IS_ARG_POINTER ? true : false;
}

/* THE TWO CFA-AT-ENTRY OFFSETS, read in THIS base's translation unit.  The
   values this pair produces are 8 and 8 for i386 (both from i386.h:2177 and
   :2183, with a TYPE_NORMAL function) and 0 and 0 for aarch64, which defines
   neither macro and so gets defaults.h:1231 twice over.  Compiled once
   against i386's tm.h, shared code read 16 and 8 for aarch64 -- see
   target-frame.h for the gdb reading and for why 16 rather than 8.

   `DEFAULT_INCOMING_FRAME_SP_OFFSET' IS ASKED HERE AND NOT DERIVED, and this
   file is the only place the question can be asked correctly: dwarf2cfi.cc's
   `#ifndef' fallback for it is evaluated with whichever base compiled
   dwarf2cfi.cc, while here it is evaluated with THIS base's headers in force.
   dwarf2cfi.cc is the only file in the tree that spells the name, so the
   fallback has to be reproduced rather than reached -- it is written out
   below rather than by including dwarf2cfi.cc's private `#ifndef', which is
   not a header.  */
static HOST_WIDE_INT
mt_base_incoming_frame_sp_offset (void)
{
  return (HOST_WIDE_INT) INCOMING_FRAME_SP_OFFSET;
}

static HOST_WIDE_INT
mt_base_default_incoming_frame_sp_offset (void)
{
#ifdef DEFAULT_INCOMING_FRAME_SP_OFFSET
  return (HOST_WIDE_INT) DEFAULT_INCOMING_FRAME_SP_OFFSET;
#else
  return (HOST_WIDE_INT) INCOMING_FRAME_SP_OFFSET;
#endif
}

#define MT_STR1(X) #X
#define MT_STR(X) MT_STR1 (X)

/* THE INSN-PATTERN EXISTENCE ANSWERS; see target-insn.h.

   Three `#if'-free reads of THIS base's insn-config.h.  There is deliberately
   no `#ifdef' here even though genconfig used to emit these only when the
   pattern was present: genconfig now emits an explicit 0, so a back end with
   no rotate pattern SAYS so rather than being silent about it, and this file
   does not have to distinguish "absent" from "false" -- which it could not do
   correctly anyway, since the two mean the same thing here and only one of
   them survives being put in a struct field.

   A static_assert would be wrong on all three: every value 0 and 1 is legal,
   so there is nothing to assert.  What makes this non-vacuous is that the two
   bases produce DIFFERENT tables, which is checked at the object level rather
   than here (scratchpad/t111-insn-guards.sh).  */
static const struct target_insn_desc mt_base_insn = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  HAVE_lo_sum != 0,
  HAVE_rotate != 0,
  HAVE_rotatert != 0
};

/* THIS BASE'S CONSTRAINT VOCABULARY; see target-preds.h for the measurement
   that produced these and for why they cannot be unioned.

   Every one of these thunks is one line calling the wrapper `genpreds' has
   already written into THIS base's `tm-preds-<base>.h' -- reached because
   this file includes `tm_p.h' and is compiled with `-I<base>-inc' ahead of
   `-I.', so that spelling resolves to `tm_p-<base>.h'.  In the build root the
   same spelling reaches the primary's, which is the bug.

   `int' rather than `enum constraint_num' at the boundary, deliberately: the
   enum is a distinct type per `namespace insn_<base>' and its VALUES are per
   base -- `k' is 18 for i386 and 2 for aarch64 -- so letting one cross into
   shared code as an enum would make the two vocabularies look interchangeable
   to the type system.  target-preds.h says the same from the other side.  */

static int
mt_base_lookup_constraint (const char *p)
{
  return (int) lookup_constraint (p);
}

static bool
mt_base_constraint_satisfied_p (rtx x, int c)
{
  return constraint_satisfied_p (x, (enum constraint_num) c);
}

static int
mt_base_reg_class_for_constraint (int c)
{
  return (int) reg_class_for_constraint ((enum constraint_num) c);
}

static int
mt_base_get_constraint_type (int c)
{
  return (int) get_constraint_type ((enum constraint_num) c);
}

static bool
mt_base_insn_extra_register_constraint (int c)
{
  return insn_extra_register_constraint ((enum constraint_num) c);
}

static bool
mt_base_insn_extra_memory_constraint (int c)
{
  return insn_extra_memory_constraint ((enum constraint_num) c);
}

static bool
mt_base_insn_extra_special_memory_constraint (int c)
{
  return insn_extra_special_memory_constraint ((enum constraint_num) c);
}

static bool
mt_base_insn_extra_relaxed_memory_constraint (int c)
{
  return insn_extra_relaxed_memory_constraint ((enum constraint_num) c);
}

static bool
mt_base_insn_extra_address_constraint (int c)
{
  return insn_extra_address_constraint ((enum constraint_num) c);
}

static void
mt_base_insn_extra_constraint_allows_reg_mem (int c, bool *allows_reg,
					      bool *allows_mem)
{
  insn_extra_constraint_allows_reg_mem ((enum constraint_num) c,
					allows_reg, allows_mem);
}

static size_t
mt_base_insn_constraint_len (char fc, const char *str)
{
  return insn_constraint_len (fc, str);
}

static bool
mt_base_insn_const_int_ok_for_constraint (HOST_WIDE_INT v, int c)
{
  return insn_const_int_ok_for_constraint (v, (enum constraint_num) c);
}

static const HARD_REG_SET *
mt_base_get_register_filter (int c)
{
  return get_register_filter ((enum constraint_num) c);
}

static int
mt_base_get_register_filter_id (int c)
{
  return get_register_filter_id ((enum constraint_num) c);
}

static int
mt_base_get_dependent_filter_id (int c)
{
  return get_dependent_filter_id ((enum constraint_num) c);
}

static int
mt_base_get_dependent_filter_ref (int id)
{
  return get_dependent_filter_ref (id);
}

static bool
mt_base_eval_dependent_filter (int id, unsigned int regno, machine_mode mode,
			       unsigned int ref_regno, machine_mode ref_mode)
{
  return eval_dependent_filter (id, regno, mode, ref_regno, ref_mode);
}

/* THIS BASE'S INSN-ATTRIBUTE ENTRY POINTS; see target-attr.h for the
   measurement and for why "this base has no such attribute" is a return
   value rather than a design fork.

   Each of these six spellings resolves, in THIS translation unit, to either
   the back end's own namespaced function or to the stub `genattr' put behind
   the same name -- `hook_int_rtx_1' (constant 1) for a missing bool
   attribute, `hook_int_rtx_insn_unreachable' for a missing `length'.  The
   thunks add nothing to that decision and must not: reproducing exactly what
   the generator already means by "absent" is the whole reason this could be
   converted at all.

   `int' rather than the per-base `enum attr_enabled' at the boundary, for the
   same reason target-preds.h keeps `int': the enum is a distinct type in each
   `namespace insn_<base>'.  */

static int
mt_base_get_attr_enabled (rtx_insn *insn)
{
  return (int) get_attr_enabled (insn);
}

static int
mt_base_get_attr_preferred_for_size (rtx_insn *insn)
{
  return (int) get_attr_preferred_for_size (insn);
}

static int
mt_base_get_attr_preferred_for_speed (rtx_insn *insn)
{
  return (int) get_attr_preferred_for_speed (insn);
}

static int
mt_base_insn_default_length (rtx_insn *insn)
{
  return insn_default_length (insn);
}

static int
mt_base_insn_min_length (rtx_insn *insn)
{
  return insn_min_length (insn);
}

static int
mt_base_insn_current_length (rtx_insn *insn)
{
  return insn_current_length (insn);
}

/* `static' and reached through the `attr' pointer below, for the same reason
   `mt_base_frame' is.

   The four booleans are read HERE, where `HAVE_ATTR_*' is still this base's
   own `#if'-able constant out of `insn-attr-<base>.h'.  That is the only
   place they can be read correctly, and it is why they are carried as data
   rather than left to shared code.  */
static const struct target_attr_desc mt_base_attr = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  HAVE_ATTR_length != 0,
  HAVE_ATTR_enabled != 0,
  HAVE_ATTR_preferred_for_size != 0,
  HAVE_ATTR_preferred_for_speed != 0,
  mt_base_get_attr_enabled,
  mt_base_get_attr_preferred_for_size,
  mt_base_get_attr_preferred_for_speed,
  mt_base_insn_default_length,
  mt_base_insn_min_length,
  mt_base_insn_current_length
};

/* `static' and reached through the `preds' pointer below, for the same reason
   `mt_base_frame' is.  */
static const struct target_preds_desc mt_base_preds = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  (int) CONSTRAINT__LIMIT,
  (int) CONSTRAINT_X,
  mt_base_lookup_constraint,
  mt_base_constraint_satisfied_p,
  mt_base_reg_class_for_constraint,
  mt_base_get_constraint_type,
  mt_base_insn_extra_register_constraint,
  mt_base_insn_extra_memory_constraint,
  mt_base_insn_extra_special_memory_constraint,
  mt_base_insn_extra_relaxed_memory_constraint,
  mt_base_insn_extra_address_constraint,
  mt_base_insn_extra_constraint_allows_reg_mem,
  mt_base_insn_constraint_len,
  mt_base_insn_const_int_ok_for_constraint,
  mt_base_get_register_filter,
  mt_base_get_register_filter_id,
  mt_base_get_dependent_filter_id,
  mt_base_get_dependent_filter_ref,
  mt_base_eval_dependent_filter
};

/* `static', unlike the cumargs table: this one is reached only through the
   `frame' pointer in the table below, so it needs no name in the registry and
   gen-multi-target-md.awk needs no change to declare one.  */
static const struct target_frame_desc mt_base_frame = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  mt_base_stack_boundary,
  mt_base_preferred_stack_boundary,
  mt_base_stack_slot_alignment,
  mt_base_minimum_alignment,
  mt_base_outgoing_reg_parm_stack_space,
  mt_base_function_arg_regno_p,
  MT_BASE_HAS_INIT_EXPANDERS,
  MT_BASE_INIT_EXPANDERS,
  mt_base_move_max,
  mt_base_move_max_pieces,
  mt_base_store_max_pieces,
  mt_base_compare_max_pieces,
  mt_base_move_ratio,
  mt_base_clear_ratio,
  mt_base_set_ratio,
  (int) MAX_MOVE_MAX,
  MT_BASE_HAS_DATA_ALIGNMENT,
  MT_BASE_DATA_ALIGNMENT,
  MT_BASE_HAS_DATA_ABI_ALIGNMENT,
  MT_BASE_DATA_ABI_ALIGNMENT,
  mt_base_incoming_stack_boundary,
  mt_base_max_stack_alignment,
  mt_base_max_supported_stack_alignment,
  mt_base_supports_stack_alignment,
  MT_BASE_N_ELIMINABLES,
  &mt_base_eliminables[0][0],
  MT_BASE_N_RELOAD_ELIMINABLES,
  MT_BASE_RELOAD_ELIMINABLES,
  mt_base_initial_elimination_offset,
  mt_base_pmode,
  mt_base_function_mode,
  mt_base_debugger_regno,
  mt_base_dwarf_frame_regnum,
  mt_base_dwarf_frame_registers,
  mt_base_stack_pointer_regnum,
  mt_base_frame_pointer_regnum,
  mt_base_hard_frame_pointer_regnum,
  mt_base_arg_pointer_regnum,
  mt_base_hard_frame_pointer_is_frame_pointer,
  mt_base_hard_frame_pointer_is_arg_pointer,
  mt_base_incoming_frame_sp_offset,
  mt_base_default_incoming_frame_sp_offset
};

/* `extern' is not redundant: a namespace-scope `const' object has INTERNAL
   linkage in C++, so without it the table is built correctly and then cannot
   be named from the registry.  target-regs.cc records the same lesson.

   Not `constexpr', unlike target-regs.cc's: this table's members are function
   addresses, which are constant, but writing `constexpr' here would buy
   nothing -- there is no macro expansion in the initialiser that could
   quietly become option-dependent.  */
extern const struct target_cumargs_desc TARGETM_CUMARGS_SYMBOL;
const struct target_cumargs_desc TARGETM_CUMARGS_SYMBOL = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  (unsigned long) sizeof (CUMULATIVE_ARGS),
  (unsigned long) alignof (CUMULATIVE_ARGS),
  mt_base_init_args,
  mt_base_init_incoming_args,
  mt_base_init_libcall_args,
  mt_base_call_pops_args,
  mt_base_override_abi_format,
  &mt_base_frame,
  &mt_base_insn,
  &mt_base_preds,
  &mt_base_attr
};
