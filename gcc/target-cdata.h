/* Per-configuration target data -- the (c-DATA) scalars.
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

/* WHAT THIS IS

   A group of target macros are not constants and not code either: they are
   values that are FIXED once the target configuration and the command line are
   known.  `SIZE_TYPE' on i386 is `(TARGET_LP64 ? "long unsigned int" : ...)';
   `UNITS_PER_WORD' is `(TARGET_64BIT ? 8 : 4)'.  They read option state, and
   option state is settled at the end of option processing.

   MACRO-LEAK.md classified these as class (c) -- "no value to union" -- and
   concluded a union could not reach them.  That is right about a union and
   wrong about the consequence: they need no hook and no call either.  They
   need ONE SLOT PER SELECTED CONFIGURATION, written once from the selected
   base's own expression, read under a target-neutral name as a single load.

   Nothing is unioned.  Class (b) unions one value ACROSS bases and hopes it is
   safe for all of them -- that is why `FIRST_PSEUDO_REGISTER' at 95 is a
   landmine.  Here the vocabulary is shared and the datum is per-config.

   THE INVARIANCE CLAIM, WHICH IS MEASURED AND IS NOT UNIVERSAL

   The whole cheap path rests on "settled after option processing, and it does
   not change again".  That was the load-bearing unmeasured claim of
   CLASS-C-DESIGN.md 8, and it has since been measured dynamically -- 35
   candidate macros read in a plugin at PLUGIN_ALL_PASSES_START, after
   `targetm.set_current_function', over 269 functions covering the i386
   target-attribute vocabulary plus `#pragma GCC target', 9415 rows, both
   controls asserted (`MOVE_MAX' must say VARIES, `BYTES_BIG_ENDIAN' must say
   invariant).

   29 of the 35 are invariant.  SIX ARE NOT, and they must never be added to
   this struct: `BIGGEST_ALIGNMENT', `STACK_BOUNDARY', `STORE_MAX_PIECES',
   `MOVE_MAX', `MOVE_MAX_PIECES', `COMPARE_MAX_PIECES'.  Five are the AVX width
   family; `STACK_BOUNDARY' varies through `TARGET_64BIT_MS_ABI' ->
   `ix86_cfun_abi ()', i.e. it reads `cfun', and belongs on the paying side
   with a real call.  A macro placed here that is NOT invariant is frozen at
   the value the command line gave it and stops responding to
   `__attribute__((target))', with no diagnostic at all -- so the measurement
   is a precondition for adding a field, not a nice-to-have.

   Do not size this from `options-save.cc' either.  The write set of
   `cl_target_option_restore' contains `ix86_move_max' and `ix86_cmodel', but
   `move-max=' and `cmodel=' are not valid target-attribute arguments, so a
   static read of that file answers VARIES for macros that do not.  It is wrong
   in the expensive direction.  */

#ifndef GCC_TARGET_CDATA_H
#define GCC_TARGET_CDATA_H

/* The poison an unrefreshed slot holds.

   The alternative -- initialising these with the PRIMARY's values so that
   something is always readable -- is precisely the bug this branch exists to
   remove: it would make a missed refresh behave correctly on the build machine
   and wrongly everywhere else.  A read before `init_targetm_cdata ()' must not
   be able to masquerade as an answer, so it yields a string no assembler and
   no front end will accept, naming itself.  */
#define TARGET_CDATA_POISON_STR "<target-cdata read before refresh>"

/* The same, for a numeric slot.  It cannot name itself, so it is picked to be
   a value no alignment, size, word width, column number or boolean could ever
   legitimately hold, and it is checked for by name after the refresh.
   0xdeadbeef read as a signed int.  */
#define TARGET_CDATA_POISON_NUM (-559038737)

/* THE ONE LIST.  The struct, every back end's refresh function, the poisoned
   initialiser and the post-refresh poison check are ALL generated from this,
   so a field added in one place and forgotten in another is not expressible.
   That is not tidiness: a field the refresh function forgot would silently
   keep the poison, and a hand-written poison check is exactly the thing most
   likely to forget the same field.

     STR (field, MACRO)        a string-valued macro
     NUM (type, field, MACRO)  a numeric one.

   THE TYPE IS NOT A FREE CHOICE, AND GETTING IT WRONG IS NOT COSMETIC.  The
   x86_64 byte-identity arm sees any change to an integer promotion or to the
   signedness of a comparison, and both mistakes were made here before this
   rule was written down.  Two properties of the macro's CURRENT expansion
   have to survive the move into a struct field:

     (1) the promoted type at the use site, and
     (2) whether the compiler can still see the value is non-negative.

   (2) is the one that is easy to miss.  `BITS_PER_WORD' is
   `(BITS_PER_UNIT * UNITS_PER_WORD)', an `int' -- but a CONSTANT-FOLDABLE
   one, so `unsigned_thing <= BITS_PER_WORD' is silent today.  Declaring the
   slot `int' makes it an opaque load, the non-negativity is lost, and
   varasm.cc alone gains four -Wsign-compare warnings that are not in the
   baseline set.  Declaring it `unsigned short' restores BOTH properties at
   once: it promotes to `int', exactly as today, and the promotion carries the
   proof that the value is non-negative.  So every non-negative, small,
   bounded quantity here is `unsigned short'.

   The exceptions are exceptions for stated reasons, not by oversight:

     `DWARF_CIE_DATA_ALIGNMENT' is NEGATIVE on most targets (i386:
     `(-((int) UNITS_PER_WORD))'), and dwarf2cfi.cc divides by it and tests
     `< 0'.  `int'.

     `STACK_CHECK_MAX_FRAME_SIZE' is `(1 << STACK_CHECK_PROBE_INTERVAL_EXP)
     - UNITS_PER_WORD'; the exponent reaches far past 16 on other targets, so
     `unsigned short' would silently truncate.  `int'.

     The booleans are `int'.  They are read with `!' and `?:' and never
     compared against an unsigned, so (2) does not arise for them.

   `MAX_FIXED_MODE_SIZE' is worth naming because BOTH obvious choices are
   wrong.  It expands to `GET_MODE_BITSIZE (...)', an `unsigned short'.  As
   `unsigned int' it turns `prec <= MAX_FIXED_MODE_SIZE' in ubsan.cc and four
   gimple-match sites from a signed comparison into an unsigned one -- a real
   change in meaning for a negative `prec'.  As `int' it loses (2) and
   gimple-ssa-store-merging.cc starts warning.  `unsigned short', the type it
   actually has, is right for the same reason it was right for the macro.

   ONLY MEASURED-INVARIANT MACROS MAY APPEAR HERE -- see the header comment.
   Note three exclusions that the invariance MEASUREMENT could not have caught,
   because none of them is about the value changing between functions:

     `SUPPORTS_STACK_ALIGNMENT' is `(MAX_STACK_ALIGNMENT > STACK_BOUNDARY)',
     and i386's `STACK_BOUNDARY' reaches `ix86_cfun_abi ()'.  The measurement
     says the BOOLEAN is invariant, and it is -- on i386 the left side is
     `MAX_OFILE_ALIGNMENT' and dwarfs any stack boundary, and on aarch64 the
     two sides are literally the same macro.  That is not enough.  A field
     here is evaluated ONCE, in `target-cdata.cc', at a point where `cfun' is
     null and where the back end's own functions are not even declared -- the
     build fails with `ix86_cfun_abi was not declared in this scope'.  So a
     macro can be perfectly invariant and still be unfit for this mechanism,
     because the question is not only "does the value change" but "can the
     expression be EVALUATED at the refresh point".  Neither the design nor
     the invariance plugin asked the second question.

     `PIC_OFFSET_TABLE_REGNUM' on i386 reads `pic_offset_table_rtx', which is
     per-function RTL state written during expand.  A plugin sampling at
     PLUGIN_ALL_PASSES_START sees it in the same state every time and reports
     the macro invariant.  It is not; freezing it would silently change PIC
     code generation.

     `Pmode', `CASE_VECTOR_MODE' and `STACK_SIZE_MODE' are `machine_mode's, and
     mode NUMBERING is per base.  A mode in this struct would be a number
     transported into a vocabulary where it means something else -- the
     shared-numbering problem, which is Stage 4's, not this mechanism's.  */
#define TARGET_CDATA_FIELDS(STR, NUM)					\
  STR (asm_comment_start,	ASM_COMMENT_START)			\
  STR (wchar_type,		WCHAR_TYPE)				\
  STR (size_type,		SIZE_TYPE)				\
  STR (ptrdiff_type,		PTRDIFF_TYPE)				\
  NUM (int,	     bytes_big_endian,		BYTES_BIG_ENDIAN)	\
  NUM (int,	     words_big_endian,		WORDS_BIG_ENDIAN)	\
  NUM (int,	     float_words_big_endian,	FLOAT_WORDS_BIG_ENDIAN)	\
  NUM (int,	     reg_words_big_endian,	REG_WORDS_BIG_ENDIAN)	\
  NUM (int,	     strict_alignment,		STRICT_ALIGNMENT)	\
  NUM (int,	     shift_count_truncated,	SHIFT_COUNT_TRUNCATED)	\
  NUM (int,	     jump_tables_in_text_section,			\
					JUMP_TABLES_IN_TEXT_SECTION)	\
  NUM (unsigned short, bits_per_word,		BITS_PER_WORD)		\
  NUM (unsigned short, long_type_size,		LONG_TYPE_SIZE)		\
  NUM (unsigned short, parm_boundary,		PARM_BOUNDARY)		\
  NUM (unsigned short, attribute_aligned_value,	ATTRIBUTE_ALIGNED_VALUE) \
  NUM (unsigned short, malloc_abi_alignment,	MALLOC_ABI_ALIGNMENT)	\
  NUM (unsigned short, trampoline_size,		TRAMPOLINE_SIZE)	\
  NUM (int,	     dwarf_cie_data_alignment,	DWARF_CIE_DATA_ALIGNMENT) \
  NUM (unsigned short, stack_check_fixed_frame_size,			\
					STACK_CHECK_FIXED_FRAME_SIZE)	\
  NUM (int,	     stack_check_max_frame_size,			\
					STACK_CHECK_MAX_FRAME_SIZE)	\
  NUM (unsigned short, max_fixed_mode_size,	MAX_FIXED_MODE_SIZE)	\
  NUM (unsigned short, dwarf_frame_return_column,				\
					DWARF_FRAME_RETURN_COLUMN)

struct target_cdata
{
#define TARGET_CDATA_STR(F, M) const char *F;
#define TARGET_CDATA_NUM(T, F, M) T F;
  TARGET_CDATA_FIELDS (TARGET_CDATA_STR, TARGET_CDATA_NUM)
#undef TARGET_CDATA_STR
#undef TARGET_CDATA_NUM
};

/* One entry per configured back end.  The entry holds a FUNCTION, not a table:
   the values depend on option state, so they cannot be a constant-initialised
   struct the way `target_asm_ops' is.  target-asm-ops.cc uses `constexpr'
   precisely to REJECT an option-dependent initialiser; here option dependence
   is the normal case, so the shape has to be a function evaluated after
   options are decoded.  */
struct target_cdata_entry
{
  const char *name;
  void (*refresh) (struct target_cdata *);
};

extern const struct target_cdata_entry targetm_cdata_registry[];

/* The values in force.  A plain object, not a pointer: the point of this
   mechanism is that a use site is ONE LOAD, and a pointer would make it two.  */
extern struct target_cdata targetm_cdata;

/* The refresh function in force.  Selected by `multi_target_select'.  */
extern void (*targetm_cdata_refresh) (struct target_cdata *);

/* Look BASE up in the registry, or NULL.  */
extern void (*target_cdata_refresh_for (const char *base)) (struct target_cdata *);

/* Fill `targetm_cdata' from the selected base.  Must run after option
   processing -- see the invariance note above -- and before anything reads a
   redirected macro.  toplev.cc calls it immediately after
   `targetm.target_option.override ()'.  */
extern void init_targetm_cdata (void);

#endif /* GCC_TARGET_CDATA_H */
