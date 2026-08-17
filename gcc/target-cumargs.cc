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

/* Compiled once per back end, so every header it reaches
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
#include "multi-target-base.h"
#include BASE_HEADER (tm.h)
#include "rtl.h"
#include "tree.h"
#include "memmodel.h"
/* For the back end's own declaration of whatever INIT_CUMULATIVE_ARGS
   expands to -- `aarch64_init_cumulative_args' is declared in
   aarch64-protos.h, which is this base's tm_p.h.  */
#include BASE_HEADER (tm_p.h)
#include "target.h"
/* For `cfun'.  i386's `INCOMING_FRAME_SP_OFFSET' (i386.h:2177) reads
   `cfun->machine->func_type', and reading it HERE -- in a translation unit
   compiled with i386's own `machine_function' declaration AND i386's own
   `tm.h' -- is the entire point of the thunk: shared code read that same
   bitfield out of aarch64's object and got TYPE_EXCEPTION.  */
#include "function.h"
/* For `crtl' and for `optimize_function_for_speed_p'.  i386's
   `ACCUMULATE_OUTGOING_ARGS' (i386.h:1647) reads `crtl->stack_realign_needed',
   `crtl->profile' and `optimize_function_for_speed_p (cfun)'.  Without these
   the build failed BY NAME -- `i386.h:1651: crtl was not declared in this
   scope' -- which is the mechanism working exactly as it did for `cfun' in
   #131: the read now happens in the translation unit where `cfun->machine'
   means i386's `machine_function', so i386's headers have to be satisfiable
   here.  */
#include "emit-rtl.h"
#include "predict.h"
/* For `regs.h:31''s `#ifndef REGMODE_NATURAL_SIZE' fallback, evaluated HERE
   so that a base which does not define the macro gets `UNITS_PER_WORD' from
   its OWN headers.  Including the header rather than restating the fallback
   is deliberate: a restatement would be a second authority for the value and
   would silently stop tracking regs.h.  */
#include "regs.h"
#include "multi-target-reg-widths.h"
/* THIS BASE'S insn-config.h, and that is the entire mechanism for the three
   booleans at the bottom of this file.  */
#include BASE_HEADER (insn-config.h)
/* THIS BASE'S insn-attr.h, named the same way and for the same reason.  It is
   what makes `get_attr_preferred_for_size' below mean
   `insn_aarch64::get_attr_preferred_for_size' where the attribute exists and
   `hook_int_rtx_1' where it does not -- the generated header carries both
   answers already, and this file simply gets compiled once per base so that
   it picks up each.  See target-attr.h.  */
#include BASE_HEADER (insn-attr.h)
/* For `assemble_function_label_raw' and `assemble_name', which are what
   `ASM_OUTPUT_FUNCTION_LABEL' (defaults.h:182) and `ASM_OUTPUT_TYPE_DIRECTIVE'
   (defaults.h:266, reached through most bases' `ASM_DECLARE_FUNCTION_NAME')
   expand to.  Without it the build failed BY NAME --
   `defaults.h:183: assemble_function_label_raw was not declared in this
   scope' -- which is the same mechanism `crtl' and `cfun' above record: the
   expansion now happens in the translation unit where the macro is that
   base's own, so that base's headers have to be satisfiable here.  */
#include "output.h"
/* `explow.h' is here for `enum save_level' ALONE, and it is required rather
   than tidy: `mt_base_stack_savearea_mode' expands the base's OWN
   `STACK_SAVEAREA_MODE', and seven back ends spell `SAVE_NONLOCAL' /
   `SAVE_FUNCTION' in that body.  Without it the build fails, per back end, at
   `config/aarch64/aarch64.h:1470: error: SAVE_NONLOCAL was not declared in
   this scope'.  Note it did NOT fail for i386: that base's object was already
   up to date, so the first draft looked like it built.  */
#include "explow.h"
/* For `lookup_attribute', which `epiphany.h:776's ASM_DECLARE_FUNCTION_SIZE
   calls to find its `forwarder_section' attribute.  Without it the 47-base
   build failed BY NAME --

     config/epiphany/epiphany.h:776: error: lookup_attribute was not declared
     in this scope
     target-cumargs.cc:313: note: in expansion of macro ASM_DECLARE_FUNCTION_SIZE

   -- which is the same mechanism `crtl', `cfun' and `assemble_function_label_raw'
   above record, arriving for a fourth macro: the expansion now happens in the
   translation unit where the macro is that base's own, so that base's headers
   have to be satisfiable HERE.  One back end of 47 needed it, and the build
   named the back end, the file, the line and the identifier.

   `stringpool.h' FIRST, and not by style: `attribs.h:165's
   `canonicalize_attr_name' calls `get_identifier_with_length', which
   stringpool.h declares.  Including attribs.h alone failed the next 47-base
   build by name --

     attribs.h:165: error: get_identifier_with_length was not declared in this
     scope

   -- which is the same one-error-at-a-time shape as the epiphany diagnostic
   above, one header deeper.  This is the pairing the rest of GCC uses.  */
#include "stringpool.h"
#include "attribs.h"
/* For `recog_memoized', which `msp430.h:541's ADJUST_INSN_LENGTH calls to get
   an insn's code before adjusting its length.  Third in the same series and
   found the cheap way: `-syncheck.sh' compiles this file for 22 bases against
   an existing build dir with `-fsyntax-only', so all the missing declarations
   of a conversion turn up in ONE run instead of one 47-base build each.  The
   first two (epiphany/attribs.h, attribs.h/stringpool.h) cost a build apiece
   before that harness existed.  */
#include "recog.h"
#include "target-cumargs.h"
/* For MT_LEGITADDR_STRICT_FN -- the name of the strict GO_IF_LEGITIMATE_ADDRESS
   thunk this base's `target-legitaddr-strict.o' defines.  */
#include "target-legitaddr.h"

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
   compiled for aarch64 and i386's expression when it is compiled for i386.

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

/* EPILOGUE_USES, asked of THIS base.  ATTRIBUTE_UNUSED because `defaults.h's
   generic definition is the constant `false' and ignores the argument, which
   is what the 22 back ends defining no `EPILOGUE_USES' get -- in their own
   translation unit, which is the whole point.  See target-frame.h for what
   the leaked i386 answer costs.  */

static bool
mt_base_epilogue_uses (int regno ATTRIBUTE_UNUSED)
{
  return EPILOGUE_USES (regno);
}

/* ASM_DECLARE_FUNCTION_NAME, asked of THIS base.  The `#ifdef' is the SAME
   one `varasm.cc:2218' used to spell, `#else' arm included; the only thing
   that changed is which translation unit evaluates it, and therefore which
   back end it is a fact about.  In varasm.cc it was a fact about i386 applied
   to all 47 back ends -- and both arms then called i386's function, which is
   why aarch64 lost its per-function `.arch' directive, its `.variant_pcs' and
   its `%function'.  See target-frame.h.  */

static void
mt_base_declare_function_name (FILE *file, const char *name, tree decl)
{
#ifdef ASM_DECLARE_FUNCTION_NAME
  ASM_DECLARE_FUNCTION_NAME (file, name, decl);
#else
  ASM_OUTPUT_FUNCTION_LABEL (file, name, decl);
#endif
}

/* ASM_DECLARE_COLD_FUNCTION_NAME, asked of THIS base; `final.cc:2229's
   `#ifdef'/`#else' pair, relocated for the same reason.  `decl' is unused in
   the `#else' arm, which is what a base defining no such macro takes.  */

static void
mt_base_declare_cold_function_name (FILE *file, const char *name,
				    tree decl ATTRIBUTE_UNUSED)
{
#ifdef ASM_DECLARE_COLD_FUNCTION_NAME
  ASM_DECLARE_COLD_FUNCTION_NAME (file, name, decl);
#else
  ASM_OUTPUT_LABEL (file, name);
#endif
}

/* FINAL_PRESCAN_INSN, asked of THIS base.  Two `#ifdef' sites in `final.cc'
   (:2666 for `asm' bodies, :2801 for ordinary insns), both answered by
   whichever base compiled that file.  i386 defines no FINAL_PRESCAN_INSN, so
   both were FALSE for all 47 bases and the hook ran for NONE of the fourteen
   back ends that define it: aarch64, alpha, arc, arm, avr, c6x, epiphany,
   frv, h8300, iq2000, m68k, mips, rs6000, sh.  See target-frame.h for what
   each of them loses -- arm's is the entry point of its conditional-execution
   state machine, not an optimisation.

   Every definer's macro is a three-argument STATEMENT taking
   (INSN, OPVEC, NOPERANDS) and assigning to nothing, so the thunk needs no
   in/out parameter.  The parameters are ATTRIBUTE_UNUSED because a base
   defining no such macro leaves the body empty, and because some definers
   (aarch64's, alpha's) ignore OPVEC and NOPERANDS even when they do define
   it.  */

static void
mt_base_final_prescan_insn (rtx_insn *insn ATTRIBUTE_UNUSED,
			    rtx *opvec ATTRIBUTE_UNUSED,
			    int noperands ATTRIBUTE_UNUSED)
{
#ifdef FINAL_PRESCAN_INSN
  FINAL_PRESCAN_INSN (insn, opvec, noperands);
#endif
}

/* GO_IF_LEGITIMATE_ADDRESS, asked of THIS base, in its NON-strict form --
   this translation unit does not define `REG_OK_STRICT', so what the header
   chain handed us above is the non-strict body.  The strict body cannot be
   reached from here at all and lives in `target-legitaddr-strict.cc'; see
   that file for why, and target-frame.h for what was wrong.

   Returns whether this base defines the macro; `*win' is the answer when it
   does.  Two results rather than one because "no such macro" and "not a
   legitimate address" are different facts and the caller does different
   things with them: the first falls through to
   `targetm.addr_space.legitimate_address_p', the second is a `false'.  */

static bool
mt_base_go_if_legitimate_address_nonstrict (machine_mode mode ATTRIBUTE_UNUSED,
					    rtx addr ATTRIBUTE_UNUSED,
					    bool *win ATTRIBUTE_UNUSED)
{
#ifdef GO_IF_LEGITIMATE_ADDRESS
  GO_IF_LEGITIMATE_ADDRESS (mode, addr, mt_legit_ok);
  *win = false;
  return true;

 mt_legit_ok:
  *win = true;
  return true;
#else
  return false;
#endif
}

/* The strict half, defined in `target-legitaddr-strict.cc' compiled for THIS
   base.  Declared through the shared header so the name is derived from
   `MULTI_TARGET_TARGETM_BASE' on both sides rather than written out twice.  */
extern bool MT_LEGITADDR_STRICT_FN (machine_mode, rtx, bool *);

/* The one entry point the table holds, dispatching on `strict'.  The two
   arms are different TRANSLATION UNITS, not different branches of one
   expansion, which is the whole difficulty this macro presents.  */

static bool
mt_base_go_if_legitimate_address (machine_mode mode, rtx addr, bool strict,
				  bool *win)
{
  if (strict)
    return MT_LEGITADDR_STRICT_FN (mode, addr, win);
  return mt_base_go_if_legitimate_address_nonstrict (mode, addr, win);
}

/* ASM_DECLARE_FUNCTION_SIZE, asked of THIS base.  `varasm.cc:2254's whole
   `#ifdef' block, section switch included, relocated unchanged -- see
   target-frame.h for why the switch may not be split away from the macro
   call, and for what the leaked `elfos.h' answer costs riscv (an unbalanced
   `.option push', because the matching `ASM_DECLARE_FUNCTION_NAME' three
   lines above it in riscv.h IS converted) and s390 (`.machine pop').

   `decl' is read by the section switch as well as by the macro, so it is not
   ATTRIBUTE_UNUSED even for a base defining nothing -- but the whole body is
   then empty, so it is marked and the attribute is harmless where it is
   used.  */

static void
mt_base_declare_function_size (FILE *file ATTRIBUTE_UNUSED,
			       const char *name ATTRIBUTE_UNUSED,
			       tree decl ATTRIBUTE_UNUSED)
{
#ifdef ASM_DECLARE_FUNCTION_SIZE
  /* We could have switched section in the middle of the function.  */
  if (crtl->has_bb_partition)
    switch_to_section (function_section (decl));
  ASM_DECLARE_FUNCTION_SIZE (file, name, decl);
#endif
}

/* ASM_OUTPUT_FUNCTION_PREFIX, asked of THIS base -- `varasm.cc:2192'.  s390 is
   the only definer and i386 is not, so in shared code the `#ifdef' was false
   for all 47 bases and s390's `.machine push' / `.machinemode zarch' never
   appeared.  See target-frame.h, including why the leak census cannot see
   this macro at all.  */

static void
mt_base_declare_function_prefix (FILE *file ATTRIBUTE_UNUSED,
				 const char *name ATTRIBUTE_UNUSED)
{
#ifdef ASM_OUTPUT_FUNCTION_PREFIX
  ASM_OUTPUT_FUNCTION_PREFIX (file, name);
#endif
}

/* ADJUST_INSN_LENGTH, asked of THIS base.  Four `#ifdef' sites in `final.cc'
   (:404, :1111, :1131, :1368), all answered by whichever base compiled that
   file.  i386 does not define the macro, so the condition was FALSE for all 47
   bases and the adjustment ran for NONE of the 13 back ends that define it --
   rx, mips, avr, sh, iq2000, msp430, v850, rs6000, arc, arm, pa, nds32 and
   aarch64.

   `*length' rather than a return value so the macro sees an lvalue: every
   definition assigns to its LENGTH parameter in place (`length += 4',
   `LENGTH = ...'), which is the interface upstream documents by example
   rather than in tm.texi -- the macro is not documented there at all.  */

static void
mt_base_adjust_insn_length (rtx_insn *insn ATTRIBUTE_UNUSED,
			    int *length ATTRIBUTE_UNUSED)
{
#ifdef ADJUST_INSN_LENGTH
  ADJUST_INSN_LENGTH (insn, *length);
#endif
}

/* ADDR_VEC_ALIGN, asked of THIS base.  Three sites in `final.cc'; the leak was
   behind an `#ifndef' rather than an `#ifdef', so all 47 bases took the
   generic `final_addr_vec_align' and the 12 definers -- aarch64 and vax want
   0, i.e. NO alignment -- never got their own.  See target-frame.h.

   The `#else' calls the very function `final.cc' used to define privately,
   now non-static, rather than restating its body: one authority for the
   fallback, so it cannot drift from the generic answer it is meant to be.

   ATTRIBUTE_UNUSED ON `table' BECAUSE 10 OF THE 12 DEFINERS IGNORE IT, AND
   THE COUNT IS EVIDENCE WORTH RECORDING RATHER THAN JUST NOISE TO SILENCE.
   Before this attribute the 47-base build gained exactly **10** `unused
   parameter 'table'` warnings, one per base whose ADDR_VEC_ALIGN is a
   constant or ignores its argument -- aarch64 0, vax 0, csky 0, sh 2, pa 2,
   nds32 2, xstormy16 1, ia64 `(CASE_VECTOR_MODE == SImode ? 2 : 3)', and
   nvptx / c6x `(JUMP_TABLES_IN_TEXT_SECTION ? 5 : 2)'.  The two that DO read
   the table are arm and arc.  10 + 2 = the 12 definers, so the warning count
   enumerated exactly the population this conversion was aimed at, and nothing
   else -- a cheap confirmation that it reached the right back ends and only
   them.  Stated here because once the attribute silences it that evidence is
   no longer reproducible from a build log.  */

static int
mt_base_addr_vec_align (rtx_jump_table_data *table ATTRIBUTE_UNUSED)
{
#ifdef ADDR_VEC_ALIGN
  return ADDR_VEC_ALIGN (table);
#else
  return final_addr_vec_align (table);
#endif
}

/* INIT_EXPANDERS, asked of THIS base.  See target-frame.h for why an existence
   predicate is a different animal from the six value thunks above.

   The `#ifdef' is the SAME `#ifdef' emit-rtl.cc used to spell; the only thing
   that changed is which translation unit evaluates it, and therefore which
   back end it is a fact about.  In emit-rtl.cc it was a fact about i386 (which
   defines no INIT_EXPANDERS) applied to all 48 back ends.  Here it is a fact
   about MULTI_TARGET_TARGETM_BASE, because this file is compiled once per
   base.

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

/* PROMOTE_MODE, asked of THIS base; see target-frame.h for the measurement.

   The macro ASSIGNS to its first two arguments, so the thunk takes pointers
   and copies through local lvalues: `riscv.h:298' expands to a bare `if'
   whose body is `(UNSIGNEDP) = 0; (MODE) = word_mode;', and handing it `*mode'
   directly would work but reads as if the macro were a function.  The locals
   also keep the expansion's own `if' from binding to anything outside it --
   riscv's definition is an `if' with NO `else' and no `do { } while (0)'
   wrapper, which is exactly the shape that swallows a following `else'.  */
#ifdef PROMOTE_MODE
static void
mt_base_promote_mode (scalar_mode *mode, int *unsignedp, const_tree type)
{
  scalar_mode m = *mode;
  int u = *unsignedp;
  {
    PROMOTE_MODE (m, u, type);
  }
  *mode = m;
  *unsignedp = u;
}
# define MT_BASE_HAS_PROMOTE_MODE true
# define MT_BASE_PROMOTE_MODE mt_base_promote_mode
#else
# define MT_BASE_HAS_PROMOTE_MODE false
# define MT_BASE_PROMOTE_MODE NULL
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

/* THE OPTION-STATE FAMILY -- `UNITS_PER_WORD', `POINTER_SIZE',
   `BIGGEST_ALIGNMENT' -- evaluated in THIS base's translation unit.  See
   target-frame.h for the bodies, for the position sweep that establishes a
   call is legal at every shared site, and for the `MIN_UNITS_PER_WORD'
   closure.

   THE CASTS ARE LOAD-BEARING IN ONE DIRECTION ONLY.  Every back end spells
   these as arithmetic on `int'-typed option state, so the value converts
   cleanly; the casts exist so that a back end spelling `POINTER_SIZE' as a
   `long' or an enumerator is narrowed HERE, in its own translation unit,
   rather than at one of the 268 shared use sites.

   NO `has_' FLAG AND NO SENTINEL, and that was checked rather than assumed:
   `defaults.h' floors `POINTER_SIZE' from `BITS_PER_WORD' and `BITS_PER_WORD'
   from `UNITS_PER_WORD', and those floors are evaluated HERE, in the base's
   own translation unit, so a base that defines none of them still gets its
   OWN answer and not the primary's.  There is no absence to record.  */
static int
mt_base_units_per_word (void)
{
  return (int) UNITS_PER_WORD;
}

static unsigned int
mt_base_pointer_size (void)
{
  return (unsigned int) POINTER_SIZE;
}

static unsigned int
mt_base_biggest_alignment (void)
{
  return (unsigned int) BIGGEST_ALIGNMENT;
}

/* `TARGET_VTABLE_ENTRY_ALIGN', read in THIS base's translation unit.  Three
   back ends define it -- ia64 64, avr 8, msp430 16 -- and for the other 44
   this expands `defaults.h:972's `TARGET_VTABLE_ENTRY_ALIGN POINTER_SIZE'
   against THIS base's `POINTER_SIZE', which is the answer a single-target
   build of that back end gives.

   NOTE WHAT THIS FUNCTION IS NOT.  For the 44 it is not a frozen number: in
   a supply-side TU `POINTER_SIZE' is still the real macro, but the value is
   read on every CALL through `targetm_frame', not once at selection time, so
   i386's `(TARGET_64BIT ? 64 : 32)' and aarch64's `(TARGET_ILP32 ? 32 : 64)'
   keep moving with the option state exactly as they do for `mt_pointer_size'
   itself.  That is the whole reason this is a `target_frame_desc' call and
   not a `TARGET_CDATA_FIELDS' slot; see target-frame.h.  */
static unsigned int
mt_base_vtable_entry_align (void)
{
  return (unsigned int) TARGET_VTABLE_ENTRY_ALIGN;
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

/* `STACK_SAVEAREA_MODE (LEVEL)', read in THIS base's translation unit.  See
   target-frame.h for the six-back-end `extract_insn, at recog.cc:2892' wall
   this answers, for the two insn dumps, and for the measurement showing that
   the four back ends which do NOT ICE carry the same wrong answer silently.

   NO `#ifdef' AND NO EXISTENCE PREDICATE, and that is the same argument
   `mt_base_reversible_cc_mode' below makes.  Seven back ends define the macro
   (rs6000, s390, ia64, i386, nvptx, sparc, aarch64); the other forty get
   `defaults.h:1494's `Pmode' -- read HERE, in a translation unit whose `tm.h'
   is `BASE_HEADER (tm.h)', where `Pmode' is still the real macro and so is
   that back end's OWN word mode.  That is the supply-side floor PRINCIPLES
   2a permits: it is upstream's own documented answer for a back end that says
   nothing, and no base ever reads another's value through it.  The consumer-
   side floor -- `defaults.h's `#ifndef' evaluated in shared code, where
   i386.h:2011 has already won -- is the banned one, and is the bug.

   THE PARAMETER STAYS AN `int' AND IS NOT CAST BACK, which was checked rather
   than assumed.  `enum save_level' is declared in `explow.h:90', and
   `target-frame.h' -- which carries the slot -- is upstream of it, so the
   descriptor cannot name the enum.  This TU includes `explow.h' anyway,
   because the BASE's macro body spells the enumerators; the two facts are
   independent and only the first is about the signature.
   Every one of the seven definitions uses the argument ONLY in `==' tests
   against the enumerators -- i386, sparc and rs6000 on `SAVE_NONLOCAL',
   rs6000 and nvptx also on `SAVE_FUNCTION', ia64, s390 and aarch64 on
   `SAVE_NONLOCAL' -- and an `int'/enumerator comparison is exact.  No back end
   switches on it or indexes anything with it, so there is no range to check
   and an unknown level falls to that back end's own trailing `Pmode'.

   `(void) level' because the forty back ends that define nothing take
   `defaults.h:1494's `Pmode', which discards the argument; the same reason
   `mt_base_reversible_cc_mode' below discards its own.  */
static machine_mode
mt_base_stack_savearea_mode (int level)
{
  (void) level;
  return (machine_mode) STACK_SAVEAREA_MODE (level);
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

/* DWARF_FRAME_RETURN_COLUMN.  A CALL, not a `target_cdata' field, and this
   thunk is where the difference is paid: it is evaluated at each read, with
   whatever `current_function_decl' is in force, because epiphany's expands to

       DWARF_FRAME_REGNUM (current_function_decl != NULL
			   && epiphany_is_interrupt_p (current_function_decl)
			   ? IRET_REGNUM : GPR_LR)

   `tree.h' and `function.h' are ALREADY included by this file for `cfun' and
   for i386's `INCOMING_FRAME_SP_OFFSET', so this compiles here with no new
   include -- which is exactly why it must NOT live in `target-cdata.cc'.
   Adding the same include there would also have compiled, and would have
   evaluated `current_function_decl' once, at selection time, when it is null:
   every epiphany interrupt handler silently given `GPR_LR'.  Same include,
   opposite meaning, decided entirely by WHEN the translation unit is
   evaluated.  See target-cdata.h where the field used to be.

   No range check, unlike `mt_base_dwarf_frame_regnum' above: this takes no
   register number from shared code -- the back end names its own -- so there
   is no union-width argument to reject.  */
static unsigned int
mt_base_dwarf_frame_return_column (void)
{
  return (unsigned int) DWARF_FRAME_RETURN_COLUMN;
}

/* `DWARF2_UNWIND_INFO', read in THIS base's translation unit; see
   target-frame.h for why the field exists and what reading it in a SHARED one
   cost.  Both branches are this back end's own answer: `defaults.h:418' has
   already turned "defines INCOMING_RETURN_ADDR_RTX" into a 1 by the time this
   file is preprocessed, because BASE_HEADER (tm.h) ends with defaults.h and
   this base's header chain comes before it.

   The `#ifdef' is NOT the trap it is elsewhere in this project.  There it is
   a shared TU silently taking the primary's side of a conditional; here the
   conditional is evaluated once per base against that base's own headers, and
   the `#else' reproduces what upstream's own `#ifdef' in
   `default_except_unwind_info' does for a back end that defines neither macro
   -- nvptx and pdp11 -- rather than inventing a value for it.  */
static int
mt_base_dwarf2_unwind_info (void)
{
#ifdef DWARF2_UNWIND_INFO
  return (DWARF2_UNWIND_INFO) != 0;
#else
  return 0;
#endif
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

/* RETURN_ADDRESS_POINTER_REGNUM, in THIS base's preprocessor context; see
   target-frame.h for the 683 s390x segfaults this was worth and for the
   15-line reproducer.

   THE `#ifdef' IS CORRECT HERE AND WRONG EVERYWHERE ELSE, which is the whole
   point of the file it is in: this translation unit's `tm.h' is
   `BASE_HEADER (tm.h)', so the question "does this back end define
   RETURN_ADDRESS_POINTER_REGNUM" is asked of the back end it is about.  The
   four shared readers ask the same `#ifdef' of the PRIMARY and get `no' for
   all 47.

   `false' for the 42 back ends that define nothing is THEIR answer, not
   i386's: a back end with no return address pointer genuinely has none, and
   upstream compiles exactly these blocks out for it.  */
static bool
mt_base_has_return_address_pointer (void)
{
#ifdef RETURN_ADDRESS_POINTER_REGNUM
  return true;
#else
  return false;
#endif
}

static unsigned int
mt_base_return_address_pointer_regnum (void)
{
#ifdef RETURN_ADDRESS_POINTER_REGNUM
  return (unsigned int) RETURN_ADDRESS_POINTER_REGNUM;
#else
  /* Unreachable behind `has_return_address_pointer', and it FAILS BY NAME
     rather than returning a plausible register number.  A `0' here would be
     a real hard register on most back ends, so the wrong answer would be
     indistinguishable from a right one -- the shape PRINCIPLES bans.  */
  gcc_unreachable ();
#endif
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

/* `ACCUMULATE_OUTGOING_ARGS', read in THIS base's translation unit -- the
   second and last shared-code-reachable read of `cfun->machine' through the
   wrong `struct machine_function' declaration.  See target-frame.h.

   `? true : false' AND NOT A BARE CAST.  Every back end that defines the macro
   at all spells it `1' (39 of them), `TARGET_ACCUMULATE_OUTGOING_ARGS' (sh),
   `avr_accumulate_outgoing_args ()' (avr) or i386's `||' chain, and
   defaults.h:902 spells it `0'.  Those are `int', not `bool', and a base is
   free to write any nonzero int; the explicit test is what makes every such
   spelling arrive here as the same two values.  It is the same shape as
   `mt_base_hard_frame_pointer_is_arg_pointer' above.

   NOTE THAT THIS THUNK CANNOT BE HOISTED OUT OF THE PER-FUNCTION LOOP by a
   caller.  i386's body reads `optimize_function_for_speed_p (cfun)' and
   `crtl->stack_realign_needed', and the latter is written during reload, so
   the answer can differ between two passes over one function.  That is
   upstream behaviour and shared code already re-evaluates the macro at each
   of its ~40 sites; this preserves that rather than improving on it.  */
static bool
mt_base_accumulate_outgoing_args (void)
{
  return ACCUMULATE_OUTGOING_ARGS ? true : false;
}

/* `STACK_DYNAMIC_OFFSET', read in THIS base's translation unit -- and the
   first entry in this file where the LEAK RAN THE OTHER WAY.  Everything
   above closes "the primary's answer reached everyone".  This one closes
   "the NON-primary's answer reached no one, itself included": aarch64
   defines the macro (aarch64.h:1688), i386 does not, and `function.cc:1411'
   asked `#ifndef STACK_DYNAMIC_OFFSET' in a translation unit compiled with
   i386's `tm.h'.  The `#ifndef' was therefore true, aarch64's definition was
   thrown away, and function.cc's generic ladder was used for every target.

   THE LADDER IS REPRODUCED HERE RATHER THAN REACHED, for the same reason
   `mt_base_default_incoming_frame_sp_offset' above reproduces dwarf2cfi.cc's:
   it lives in a `.cc' file's private preprocessor block, not in a header, so
   there is nothing to include.  It is copied verbatim from function.cc
   :1413-1432 -- both arms, and the `INCOMING_REG_PARM_STACK_SPACE' derivation
   from `REG_PARM_STACK_SPACE' at :1403 that decides which arm applies.  Those
   two lines are function.cc's, and they were being decided by the primary as
   well; here every name in them is THIS base's.

   Note that `ACCUMULATE_OUTGOING_ARGS' inside the ladder is this base's real
   macro, not the `mt_accumulate_outgoing_args ()' redirect -- this file is
   compiled with `MULTI_TARGET_TARGETM_BASE' defined, so `defaults.h' leaves
   the name alone.  Evaluating the ladder here and the redirect there would
   have given the same answer for the SELECTED base and different answers for
   every other; getting the real macro is what makes this a fact about this
   base rather than about the current selection.  */
#ifndef STACK_DYNAMIC_OFFSET

# if defined (REG_PARM_STACK_SPACE) && !defined (INCOMING_REG_PARM_STACK_SPACE)
#  define MT_BASE_INCOMING_REG_PARM_STACK_SPACE REG_PARM_STACK_SPACE
# elif defined (INCOMING_REG_PARM_STACK_SPACE)
#  define MT_BASE_INCOMING_REG_PARM_STACK_SPACE INCOMING_REG_PARM_STACK_SPACE
# endif

# ifdef MT_BASE_INCOMING_REG_PARM_STACK_SPACE
#  define STACK_DYNAMIC_OFFSET(FNDECL)					\
  ((ACCUMULATE_OUTGOING_ARGS						\
    ? (crtl->outgoing_args_size						\
       + (OUTGOING_REG_PARM_STACK_SPACE ((!(FNDECL) ? NULL_TREE	  	\
					  : TREE_TYPE (FNDECL)))	\
	  ? 0								\
	  : MT_BASE_INCOMING_REG_PARM_STACK_SPACE (FNDECL)))		\
    : 0) + (STACK_POINTER_OFFSET))
# else
#  define STACK_DYNAMIC_OFFSET(FNDECL)					\
  ((ACCUMULATE_OUTGOING_ARGS ? crtl->outgoing_args_size			\
    : poly_int64 (0))							\
   + (STACK_POINTER_OFFSET))
# endif

#endif

static poly_int64
mt_base_stack_dynamic_offset (tree fndecl ATTRIBUTE_UNUSED)
{
  return STACK_DYNAMIC_OFFSET (fndecl);
}

/* `PUSH_ARGS_REVERSED', read in THIS base's translation unit.  See
   target-frame.h for what it decides (the order gimplify.cc evaluates every
   call's arguments in) and for why no ladder is reproduced here: this file is
   compiled with `MULTI_TARGET_TARGETM_BASE' defined, so `defaults.h' has
   already run its `PUSH_ROUNDING' / `STACK_GROWS_DOWNWARD' /
   `ARGS_GROW_DOWNWARD' ladder against THIS base's headers by the time this
   line is reached, and the macro below is that base's own answer.

   All three of those names are per-base, so the ladder was three leaks and
   not one; evaluating it here closes all three at once.

   The `? true : false' normalises i386's `1', the fallback's `0' and the
   ladder's `targetm.calls.push_argument (0)' -- an `int', an `int' and a
   `bool' -- to the field's two values.  */
static bool
mt_base_push_args_reversed (void)
{
  return PUSH_ARGS_REVERSED ? true : false;
}

/* `INCOMING_REG_PARM_STACK_SPACE', read in THIS base's translation unit --
   `REG_PARM_STACK_SPACE''s second path, the one #133's conversion did not
   cover.  See target-frame.h.

   THE DERIVATION IS REPRODUCED, not reached, for the same reason the
   `STACK_DYNAMIC_OFFSET' ladder above is: it lives in `function.cc''s private
   preprocessor block (`:1403'), not in a header.  It is the same two lines,
   and here every name in them is THIS base's rather than the primary's.

   A base defining neither macro returns 0, which is exactly the state
   `assign_parms_initialize_all''s `memset' has already established -- the
   `#ifdef' arm is preserved, not floored over.  */
#if defined (REG_PARM_STACK_SPACE) && !defined (INCOMING_REG_PARM_STACK_SPACE)
# define MT_BASE_INCOMING_RPSS REG_PARM_STACK_SPACE
#elif defined (INCOMING_REG_PARM_STACK_SPACE)
# define MT_BASE_INCOMING_RPSS INCOMING_REG_PARM_STACK_SPACE
#endif

static int
mt_base_incoming_reg_parm_stack_space (tree fndecl ATTRIBUTE_UNUSED)
{
#ifdef MT_BASE_INCOMING_RPSS
  return MT_BASE_INCOMING_RPSS (fndecl);
#else
  return 0;
#endif
}

/* `REG_PARM_STACK_SPACE' itself, read in THIS base's translation unit -- the
   calls.cc and expr.cc paths.  Two thunks, because the shared sites ask two
   different questions: twelve of them ask whether the base defines the macro
   AT ALL, and two ask for its value.  See target-frame.h for why collapsing
   them into "the value, with 0 meaning absent" is wrong for
   args-grow-downward back ends.

   The value thunk is `#ifdef'-ed rather than floored: a base that defines
   nothing cannot evaluate the macro, and shared code never asks it to,
   because every value site is now under the existence test.  The `0' in the
   `#else' arm is therefore unreachable-by-contract rather than a fallback --
   it exists so the field is always filled and so a base that acquires the
   macro later needs no edit here.  */
static bool
mt_base_has_reg_parm_stack_space (void)
{
#ifdef REG_PARM_STACK_SPACE
  return true;
#else
  return false;
#endif
}

static int
mt_base_reg_parm_stack_space (tree fndecl_or_type ATTRIBUTE_UNUSED)
{
#ifdef REG_PARM_STACK_SPACE
  return REG_PARM_STACK_SPACE (fndecl_or_type);
#else
  return 0;
#endif
}

/* `PUSH_ROUNDING', read in THIS base's translation unit.  See target-frame.h
   for the signature argument; `MACRO_INT' is deliberately kept HERE and
   removed from the shared sites, because it is exactly the wrapper that lets
   a back end whose macro is not poly-safe keep working.  */
static bool
mt_base_has_push_rounding (void)
{
#ifdef PUSH_ROUNDING
  return true;
#else
  return false;
#endif
}

static poly_int64
mt_base_push_rounding (poly_int64 bytes ATTRIBUTE_UNUSED)
{
#ifdef PUSH_ROUNDING
  return PUSH_ROUNDING (MACRO_INT (bytes));
#else
  return bytes;
#endif
}

/* `CASE_VECTOR_PC_RELATIVE' and `REGMODE_NATURAL_SIZE', read in THIS base's
   translation unit.  See target-frame.h for both field comments.

   NEITHER NEEDS AN `#ifdef' AND NEITHER GETS ONE, but the two reach their
   fallback by different routes and both routes are supply-side -- each base
   gets upstream's own documented default for a back end that defines nothing,
   never another base's answer:

     `CASE_VECTOR_PC_RELATIVE'  `defaults.h:1161' `#ifndef' -> 0, and
                                `defaults.h' is the tail of THIS base's
                                `tm.h', so the 0 is evaluated here.
     `REGMODE_NATURAL_SIZE'     `regs.h:31' `#ifndef' -> `UNITS_PER_WORD',
                                which is why this file includes `regs.h' at
                                all.  In a SHARED translation unit that
                                `#ifndef' is not taken -- the primary's
                                `i386.h:1112' got there first -- which is the
                                whole defect.  */
static bool
mt_base_case_vector_pc_relative (void)
{
  return CASE_VECTOR_PC_RELATIVE != 0;
}

static poly_uint64
mt_base_regmode_natural_size (machine_mode mode ATTRIBUTE_UNUSED)
{
  return REGMODE_NATURAL_SIZE (mode);
}

/* `CASE_VECTOR_MODE' and `INCOMING_RETURN_ADDR_RTX', read in THIS base's
   translation unit.  See target-frame.h for both field comments.

   `CASE_VECTOR_MODE' GETS NO `#ifdef': every back end that has a jump table
   defines it, and for one that does not, the name is simply undefined and
   this file fails to compile BY NAME for that base -- which is the
   fail-by-name PRINCIPLES asks for, at build time rather than at run time.

   `INCOMING_RETURN_ADDR_RTX' DOES GET ONE, AND AN EARLIER VERSION OF THIS
   FILE DID NOT, WHICH IS WHY THIS PARAGRAPH IS LONG.  The reasoning above
   was applied to it as well -- "likewise undefined, so the same by-name
   build failure applies" -- and that is exactly what happened: `bpf',
   `nvptx' and `pdp11' define no `INCOMING_RETURN_ADDR_RTX', so a 47-base
   `make all-gcc' stopped with three copies of

       target-cumargs.cc:946: `INCOMING_RETURN_ADDR_RTX' was not declared
                              in this scope

   and `cc1' never linked.  Fail-by-name is the right answer for a base that
   is SILENT about something upstream requires every back end to answer; it
   is the wrong answer here, because upstream does not require this one.
   Upstream's shared code asks the existence question explicitly, in two
   places, and has TWO different documented behaviours for a back end that
   defines nothing:

     `df-scan.cc:3558'   `#ifdef INCOMING_RETURN_ADDR_RTX' around the whole
                         `if (REG_P (...))' -- for a back end that defines
                         nothing the entry-block def is simply NOT MARKED.
                         Not an error, not a value: the block does not run.
     `dwarf2cfi.cc:52'   `#ifndef' -> `(gcc_unreachable (), NULL_RTX)' -- for
                         a back end that defines nothing, ASKING for the
                         value at all is a bug, and upstream aborts.

   So the pair below is the `PUSH_ROUNDING' shape a few functions up, for the
   same reason `PUSH_ROUNDING' has it: the macro is `#ifdef'-TESTED in shared
   code, so the existence question is a real per-base answer in its own right
   and must be carried as one.  A base that defines the macro answers `true'
   and its own expression; a base that does not answers `false', and the
   value thunk is then upstream's own `dwarf2cfi.cc:52' behaviour for that
   back end -- `gcc_unreachable ()', reached HERE, in that base's own
   translation unit, where it is that back end's answer and not a shared
   fallback anybody else can receive.

   This is the supply-side floor PRINCIPLES 2a permits, and the test it
   prescribes -- WHOSE answer is it? -- has the same answer for both arms: a
   second configured back end cannot change either one, because both are read
   in a TU compiled with `-DMULTI_TARGET_SUPPLY_TU' against exactly one base's
   `tm.h'.  Nothing here restates i386's `gen_rtx_MEM (Pmode,
   stack_pointer_rtx)' or anyone else's value, which is what a banned floor
   would have done.

   `MACRO_MODE' is not used on `CASE_VECTOR_MODE': it is already a plain
   `machine_mode' on every back end that defines it, including the eight
   that spell it `Pmode' (itself a run-time call on this branch).  */
static machine_mode
mt_base_case_vector_mode (void)
{
  return (machine_mode) CASE_VECTOR_MODE;
}

static bool
mt_base_has_incoming_return_addr_rtx (void)
{
#ifdef INCOMING_RETURN_ADDR_RTX
  return true;
#else
  return false;
#endif
}

static rtx
mt_base_incoming_return_addr_rtx (void)
{
#ifdef INCOMING_RETURN_ADDR_RTX
  return INCOMING_RETURN_ADDR_RTX;
#else
  /* `dwarf2cfi.cc:52's answer for this back end, evaluated in this back
     end's own translation unit.  NOT a plausible value: a wrong `rtx' here
     would build a wrong CIE initial row and fail hundreds of lines away in
     `maybe_record_trace_start', which is the defect this field exists to
     remove.  */
  gcc_unreachable ();
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
/* LOAD_EXTEND_OP, in THIS base's preprocessor context; see target-insn.h.

   No `#ifdef' and no fallback of its own: for a back end that defines the
   macro this is that back end's expression, and for the 15 that do not it is
   `defaults.h:1386''s `UNKNOWN' -- read HERE, where it is upstream's own
   documented answer for a back end that says nothing, rather than in shared
   code where it would be the primary's absence answering for everyone.  That
   is the supply-side floor PRINCIPLES 2a permits, and the distinction is the
   whole point of evaluating it in this translation unit.  */
static int
mt_base_load_extend_op (int mode)
{
  return (int) LOAD_EXTEND_OP ((machine_mode) mode);
}

/* The eight individual auto-increment forms, in THIS base's preprocessor
   context; see target-insn.h.

   A FUNCTION AND NOT EIGHT BOOLS IN THE INITIALISER BELOW, and the reason is
   not style: `riscv.h:1313' defines `HAVE_POST_MODIFY_DISP' as
   `TARGET_XTHEADMEMIDX', which reads option state.  As a field of a
   `static const struct' that is not a constant expression and does not
   compile; evaluated here, per call, it is that back end's own answer for the
   options actually in force.  Ten of the 25 back ends that define any of the
   eight define at least one of them in terms of a `TARGET_' macro.

   No `#ifdef' and no fallback of its own, exactly as `mt_base_load_extend_op'
   above: for a back end that defines the macro this is that back end's
   expression, and for one that does not it is `rtl.h''s own `0' -- read HERE,
   where "this back end says nothing" is the answer, rather than in shared code
   where the PRIMARY saying nothing would answer for everyone.  That difference
   is the entire defect this file exists to close.  */
static bool
mt_base_have_autoinc (int form)
{
  switch (form)
    {
    case MT_AUTOINC_PRE_INC:		return HAVE_PRE_INCREMENT != 0;
    case MT_AUTOINC_PRE_DEC:		return HAVE_PRE_DECREMENT != 0;
    case MT_AUTOINC_POST_INC:		return HAVE_POST_INCREMENT != 0;
    case MT_AUTOINC_POST_DEC:		return HAVE_POST_DECREMENT != 0;
    case MT_AUTOINC_PRE_MODIFY_DISP:	return HAVE_PRE_MODIFY_DISP != 0;
    case MT_AUTOINC_POST_MODIFY_DISP:	return HAVE_POST_MODIFY_DISP != 0;
    case MT_AUTOINC_PRE_MODIFY_REG:	return HAVE_PRE_MODIFY_REG != 0;
    case MT_AUTOINC_POST_MODIFY_REG:	return HAVE_POST_MODIFY_REG != 0;
    default:				return false;
    }
}

/* The eight `USE_*' preference macros, in THIS base's context; see
   target-insn.h for why they are a separate question from the eight above and
   for how the omission was found.  `int mode' at the boundary, cast back here,
   for `mt_base_load_extend_op''s reason.  */
static bool
mt_base_use_autoinc (int form, int mode)
{
  machine_mode m = (machine_mode) mode;

  switch (form)
    {
    case MT_USEINC_LOAD_POST_INC:   return USE_LOAD_POST_INCREMENT (m) != 0;
    case MT_USEINC_LOAD_POST_DEC:   return USE_LOAD_POST_DECREMENT (m) != 0;
    case MT_USEINC_LOAD_PRE_INC:    return USE_LOAD_PRE_INCREMENT (m) != 0;
    case MT_USEINC_LOAD_PRE_DEC:    return USE_LOAD_PRE_DECREMENT (m) != 0;
    case MT_USEINC_STORE_POST_INC:  return USE_STORE_POST_INCREMENT (m) != 0;
    case MT_USEINC_STORE_POST_DEC:  return USE_STORE_POST_DECREMENT (m) != 0;
    case MT_USEINC_STORE_PRE_INC:   return USE_STORE_PRE_INCREMENT (m) != 0;
    case MT_USEINC_STORE_PRE_DEC:   return USE_STORE_PRE_DECREMENT (m) != 0;
    default:			    return false;
    }
}

static const struct target_insn_desc mt_base_insn = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  HAVE_lo_sum != 0,
  HAVE_rotate != 0,
  HAVE_rotatert != 0,
  /* AUTO_INC_DEC, in THIS base's preprocessor context.  This file is compiled
     once per base with `-DMULTI_TARGET_SUPPLY_TU', which is one of the four
     names rtl.h's redirect (rtl.h:2901) tests for, so the spelling below is
     upstream's own eight-way `defined (HAVE_PRE_INCREMENT) || ...'
     disjunction, evaluated against `insn-flags-<base>.h' -- the file
     `BASE_HEADER (tm.h)' at the top of this TU brought in for THIS base.
     Read in shared code the same eight names are the primary's, and the
     primary defines none of them.  Same shape and same reason as
     `mt_base_load_extend_op' above: the answer is computed where the base's
     headers are the ones in scope.  */
  AUTO_INC_DEC != 0,
  mt_base_have_autoinc,
  mt_base_use_autoinc,
  mt_base_load_extend_op
};

/* THIS BASE'S CONSTRAINT VOCABULARY; see target-preds.h for the measurement
   that produced these and for why they cannot be unioned.

   Every one of these thunks is one line calling the wrapper `genpreds' has
   already written into THIS base's `tm-preds-<base>.h' -- reached because
   this file spells BASE_HEADER (tm_p.h), which names this base's
   `tm_p-<base>.h'.

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

/* THE FILTER WRITER.  This translation unit is compiled once per back end
   against that base's own `tm-preds-<base>.h', so the unqualified name here
   is that base's `init_reg_class_start_regs' -- the one genpreds generated
   from ITS machine description, with its `define_register_constraint'
   conditions in it.  The bare name in a SHARED translation unit is the
   primary's, whose body is empty whenever the primary declares no filters.
   See target-preds.h for what that cost.  */
static void
mt_base_init_reg_class_start_regs (void)
{
  init_reg_class_start_regs ();
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

/* THIS BASE'S MODE-SWITCHING ENTITY LIST; see target-modeswitch.h for the
   measurement and for why "this back end does no mode switching" is
   `n_entities == 0' rather than a default.

   The `#ifdef' is read HERE, where `OPTIMIZE_MODE_SWITCHING' is still this
   base's own macro out of its own `tm.h'.  That is the only place it can be
   read correctly: `mode-switching.o' is shared, so the same `#ifdef' there
   was the primary's answer served to forty-three back ends that had never
   defined it.

   Both fields come off the SAME `#ifdef', so a base cannot end up listing
   entities it will not optimise or the reverse.  */
#ifdef OPTIMIZE_MODE_SWITCHING
static const int mt_base_num_modes_for_mode_switching[]
  = NUM_MODES_FOR_MODE_SWITCHING;

/* A function and not a constant: `OPTIMIZE_MODE_SWITCHING' reads option state
   or a global array in every back end that defines it, so evaluating it at
   static-initialisation time would freeze it before option processing --
   the `ix86_pmode Init (PMODE_SI)' shape this branch exists to remove.  */
static bool
/* ATTRIBUTE_UNUSED because two of the five definers ignore the entity --
   riscv's macro is `(TARGET_VECTOR)' and sh's `(TARGET_FPU_DOUBLE)' -- and
   this branch measures stderr, so a warning here would be a permanent two
   lines in every build for a parameter the macro is entitled not to read.  */
mt_base_optimize_mode_switching (int entity ATTRIBUTE_UNUSED)
{
  return OPTIMIZE_MODE_SWITCHING (entity) != 0;
}

static const struct target_modeswitch_desc mt_base_modeswitch = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  (int) ARRAY_SIZE (mt_base_num_modes_for_mode_switching),
  mt_base_num_modes_for_mode_switching,
  mt_base_optimize_mode_switching
};
#else
static const struct target_modeswitch_desc mt_base_modeswitch = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  0,
  NULL,
  NULL
};
#endif

/* THIS BASE'S SCHEDULER-ATTRIBUTE INITIALISER; see target-sched.h for the
   measurement.  `init_sched_attrs' resolves here through this base's own
   `insn-attr-<base>.h' using-directive, so the address stored is
   `insn_<base>::init_sched_attrs' and not the primary's -- which is the
   entire mechanism, exactly as for the attribute thunks above.

   `INSN_SCHEDULING' comes from this base's `insn-attr-common-<base>.h'.  Note
   the failure mode if a base without a DFA is ever configured alongside a
   primary with one: `tm.h' would define the macro, this `#ifdef' would be
   true, and the compile would fail with `init_sched_attrs was not declared'.
   That is loud and names the file, which is the direction to fail in.  */
#ifdef INSN_SCHEDULING
static void
mt_base_init_sched_attrs (void)
{
  init_sched_attrs ();
}
#endif

static const struct target_sched_desc mt_base_sched = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
#ifdef INSN_SCHEDULING
  mt_base_init_sched_attrs
#else
  NULL
#endif
};

/* THIS BASE'S `asm_fprintf' FORMAT EXTENSIONS; see target-asmfprintf.h for
   the measurement and for why a null pointer is this base's own answer.

   The `#ifdef' is read HERE, where `ASM_FPRINTF_EXTENSIONS' is still this
   base's own macro out of its own `tm.h'.  That is the only place it can be
   read correctly: `final.o' is shared, so the same `#ifdef' there was the
   primary's answer served to forty-seven other back ends -- and the macro
   body with it, so arm's `%@' reached `gcc_unreachable ()' while arm's `%r'
   would have printed an i386 register name.

   The macro expands to bare `case' labels and is designed to be spliced into
   a switch; that is exactly what happens below.  ARGS is dereferenced rather
   than copied because a `%r' extension consumes an argument the CALLER must
   see consumed.  */
#ifdef ASM_FPRINTF_EXTENSIONS
static bool
mt_base_asm_fprintf_extension (FILE *file, va_list *args, int c)
{
  /* The macro's second parameter is used as `va_arg ((ARGS), int)', so it
     must be the va_list itself and not the pointer.  Its third is the
     format pointer, which neither definer reads; NULL would be a lie if one
     ever did, so it is passed as the address of the character instead.  */
  switch (c)
    {
      ASM_FPRINTF_EXTENSIONS (file, *args, &c)

    default:
      return false;
    }
  return true;
}
#endif

/* ASSEMBLER_DIALECT, evaluated in this base's own translation unit.  A
   function, not a constant: i386's is `(ix86_asm_dialect)', an option
   variable.  See target-asmfprintf.h for what the primary's `#ifdef' cost --
   `bx |lr' in arm's first-ever output.  */
#ifdef ASSEMBLER_DIALECT
static int
mt_base_assembler_dialect (void)
{
  return ASSEMBLER_DIALECT;
}
#endif

static const struct target_asmfprintf_desc mt_base_asmfprintf = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
#ifdef ASM_FPRINTF_EXTENSIONS
  mt_base_asm_fprintf_extension,
#else
  NULL,
#endif
#ifdef ASSEMBLER_DIALECT
  true,
  mt_base_assembler_dialect
#else
  false,
  NULL
#endif
};

/* THIS BASE'S DFA PIPELINE-HAZARD ENTRY POINTS; see target-automata.h for the
   measurement -- an ASAN-confirmed 116-byte write into a 4-byte buffer -- and
   for why this family could not be fixed additively the way
   `mt_init_base_sched_attrs' was.

   Every name below resolves to `insn_<base>::' through this base's own
   `insn-attr-<base>.h' using-directive, exactly as the attribute thunks
   above do.  The `#ifdef INSN_SCHEDULING' is read HERE, where it is still
   this base's own macro out of its own `insn-attr-common-<base>.h'; that is
   the only place it can be read correctly, and a back end with no
   `define_insn_reservation' has no such declarations to name.  */
#ifdef INSN_SCHEDULING
static int
mt_base_state_size (void)
{
  return state_size ();
}

/* `max_insn_queue_index' is `extern const int' defined in this base's
   `insn-automata-<base>.cc', so it is not a constant expression here and
   cannot be a plain field without making the table dynamically initialised.
   A thunk keeps the table static.  */
static int
mt_base_max_insn_queue_index (void)
{
  return max_insn_queue_index;
}

static void
mt_base_state_reset (void *s)
{
  state_reset ((state_t) s);
}

static int
mt_base_state_transition (void *s, rtx insn)
{
  return state_transition ((state_t) s, insn);
}

static int
mt_base_state_dead_lock_p (void *s)
{
  return state_dead_lock_p ((state_t) s);
}

static int
mt_base_min_insn_conflict_delay (void *s, rtx_insn *a, rtx_insn *b)
{
  return min_insn_conflict_delay ((state_t) s, a, b);
}

static void
mt_base_print_reservation (FILE *f, rtx_insn *insn)
{
  print_reservation (f, insn);
}

static void
mt_base_dfa_start (void)
{
  dfa_start ();
}

static void
mt_base_dfa_finish (void)
{
  dfa_finish ();
}

static void
mt_base_dfa_clear_single_insn_cache (rtx_insn *insn)
{
  dfa_clear_single_insn_cache (insn);
}

static int
mt_base_bypass_p (rtx_insn *insn)
{
  return bypass_p (insn);
}

static int
mt_base_insn_latency (rtx_insn *a, rtx_insn *b)
{
  return insn_latency (a, b);
}

static int
mt_base_maximal_insn_latency (rtx_insn *insn)
{
  return maximal_insn_latency (insn);
}

/* `insn_default_latency' is a function POINTER assigned by this base's
   `init_sched_attrs ()', which `mt_init_base_sched_attrs' runs (target-sched.h).
   Called through the pointer here rather than captured into the table,
   because the table is statically initialised and the pointer is null until
   that initialiser has run.  */
static int
mt_base_insn_default_latency (rtx_insn *insn)
{
  return insn_default_latency (insn);
}
#endif /* INSN_SCHEDULING */

static const struct target_automata_desc mt_base_automata = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  /* `DELAY_SLOTS' out of THIS base's `insn-attr-common-<base>.h'.  Outside the
     `#ifdef INSN_SCHEDULING' arms below because the two are independent: fr30,
     h8300, iq2000, microblaze, or1k and visium have delay slots and no
     automaton at all, and genattr-common emits this `#define' unconditionally
     while it emits `INSN_SCHEDULING' only for a back end with a
     `define_insn_reservation'.  */
  DELAY_SLOTS != 0,
#ifdef INSN_SCHEDULING
  true,
  mt_base_state_size,
  mt_base_max_insn_queue_index,
  mt_base_state_reset,
  mt_base_state_transition,
  mt_base_state_dead_lock_p,
  mt_base_min_insn_conflict_delay,
  mt_base_print_reservation,
  mt_base_dfa_start,
  mt_base_dfa_finish,
  mt_base_dfa_clear_single_insn_cache,
  mt_base_bypass_p,
  mt_base_insn_latency,
  mt_base_maximal_insn_latency,
  mt_base_insn_default_latency
#else
  false,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL
#endif
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
  mt_base_init_reg_class_start_regs,
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
  mt_base_units_per_word,
  mt_base_pointer_size,
  mt_base_biggest_alignment,
  mt_base_vtable_entry_align,
  MT_BASE_HAS_DATA_ALIGNMENT,
  MT_BASE_DATA_ALIGNMENT,
  MT_BASE_HAS_DATA_ABI_ALIGNMENT,
  MT_BASE_DATA_ABI_ALIGNMENT,
  MT_BASE_HAS_PROMOTE_MODE,
  MT_BASE_PROMOTE_MODE,
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
  mt_base_stack_savearea_mode,
  mt_base_debugger_regno,
  mt_base_dwarf_frame_regnum,
  mt_base_dwarf_frame_registers,
  mt_base_dwarf_frame_return_column,
  mt_base_dwarf2_unwind_info,
  mt_base_stack_pointer_regnum,
  mt_base_frame_pointer_regnum,
  mt_base_hard_frame_pointer_regnum,
  mt_base_arg_pointer_regnum,
  mt_base_hard_frame_pointer_is_frame_pointer,
  mt_base_hard_frame_pointer_is_arg_pointer,
  mt_base_has_return_address_pointer,
  mt_base_return_address_pointer_regnum,
  mt_base_incoming_frame_sp_offset,
  mt_base_default_incoming_frame_sp_offset,
  mt_base_accumulate_outgoing_args,
  mt_base_stack_dynamic_offset,
  mt_base_push_args_reversed,
  mt_base_incoming_reg_parm_stack_space,
  mt_base_has_reg_parm_stack_space,
  mt_base_reg_parm_stack_space,
  mt_base_has_push_rounding,
  mt_base_push_rounding,
  mt_base_case_vector_pc_relative,
  mt_base_regmode_natural_size,
  mt_base_case_vector_mode,
  mt_base_has_incoming_return_addr_rtx,
  mt_base_incoming_return_addr_rtx,
  mt_base_epilogue_uses,
  mt_base_declare_function_name,
  mt_base_declare_cold_function_name,
  mt_base_final_prescan_insn,
  mt_base_go_if_legitimate_address,
  mt_base_declare_function_size,
  mt_base_declare_function_prefix,
  mt_base_adjust_insn_length,
  mt_base_addr_vec_align
};

/* THIS BASE'S CONDITION-CODE MODE SELECTION; see target-ccmode.h for what
   these were answering before the table existed and for the measurement.

   All three are evaluated HERE, in a translation unit whose `tm.h' is
   `BASE_HEADER (tm.h)', i.e. this base's own header chain.  That is the whole
   mechanism: read in shared code the same three names are `i386.h:2074',
   `:2079' and `:2083' for all 47 back ends.  */

#ifdef SELECT_CC_MODE
/* This back end defines the macro, so this is ITS expression.  */
static int
mt_base_select_cc_mode (int code, rtx x, rtx y)
{
  return (int) SELECT_CC_MODE ((enum rtx_code) code, x, y);
}
#endif

/* REVERSIBLE_CC_MODE, in THIS base's preprocessor context.  No `#ifdef' and
   no fallback of its own: for a back end that defines the macro this is that
   back end's expression, and for the 32 that do not it is `defaults.h:1215's
   `0' -- read HERE, where it is upstream's own documented answer for a back
   end that says nothing, rather than in shared code where `i386.h:2079's
   unconditional `1' answers for everyone.  That is the supply-side floor
   PRINCIPLES 2a permits, and evaluating it in this translation unit is the
   entire distinction.

   `(void) mode' because several definitions -- i386's `1', mn10300's `0' and
   `defaults.h's `0' -- discard the argument, and an unused parameter here
   would be a warning that says nothing about the target.  */
static bool
mt_base_reversible_cc_mode (int mode)
{
  (void) mode;
  return REVERSIBLE_CC_MODE ((machine_mode) mode) != 0;
}

/* REVERSE_CONDITION, same shape and same reason.  The 41 back ends that
   define nothing get `defaults.h:1420's `reverse_condition (code)', which is
   upstream's answer for them; shared code was getting
   `ix86_reverse_condition'.  */
static int
mt_base_reverse_condition (int code, int mode)
{
  (void) mode;
  return (int) REVERSE_CONDITION ((enum rtx_code) code, (machine_mode) mode);
}

/* `static' and reached through the `ccmode' pointer below, for the same
   reason `mt_base_frame' is.  */
static const struct target_ccmode_desc mt_base_ccmode = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
#ifdef SELECT_CC_MODE
  mt_base_select_cc_mode,
#else
  /* NULL, not a fallback.  `mt_has_select_cc_mode ()' is derived from this
     pointer, so a back end with no `SELECT_CC_MODE' makes the run-time form
     of `#ifdef SELECT_CC_MODE' false for itself -- which is what the
     preprocessor did for it upstream and what the primary was overriding
     here.  */
  NULL,
#endif
  mt_base_reversible_cc_mode,
  mt_base_reverse_condition
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
  &mt_base_attr,
  &mt_base_modeswitch,
  &mt_base_sched,
  &mt_base_asmfprintf,
  &mt_base_automata,
  &mt_base_ccmode
};
