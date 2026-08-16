/* The multi-target conversion layer: target macros redirected to per-config
   data, register unions and run-time `mt_*' calls.
   Copyright (C) 1992-2026 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

GCC is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

Under Section 7 of GPL version 3, you are granted additional
permissions described in the GCC Runtime Library Exception, version
3.1, as published by the Free Software Foundation.

You should have received a copy of the GNU General Public License and
a copy of the GCC Runtime Library Exception along with this program;
see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see
<http://www.gnu.org/licenses/>.  */

/* WHY THIS IS A FILE OF ITS OWN, AND NOT THE TAIL OF `defaults.h'.

   `gcc/defaults.h' has ZERO source-level includers anywhere in the tree: its
   only route into a translation unit is the tail `gcc/mkconfig.sh' appends to
   `tm.h' and `tm-<base>.h'.  Everything below used to live at the end of it,
   which meant THIS BRANCH'S ENTIRE CONVERSION LAYER was reached only through
   the header the branch exists to delete.  Deleting a `tm.h' include from
   `backend.h' / `target.h' / `cp/cp-tree.h' / `m2/gm2-gcc/gcc-consolidation.h'
   would have removed `POINTER_SIZE', `BITS_PER_WORD', `BYTES_BIG_ENDIAN' and
   the rest of the CONVERTED set along with the unconverted ones -- and the
   converted names used on `#if' lines would then have silently evaluated
   FALSE.  The conversion would have been undone by the deletion it was
   performed to enable, with no diagnostic.  So it gets a name of its own and
   a route of its own.

   IT IS TARGET-NEUTRAL BY CONSTRUCTION.  Nothing here names a back end; it
   names `targetm_cdata', `targetm_regs', `targetm_frame', `targetm_insn', the
   `mt_*' functions and `MULTI_TARGET_UNION_*'.  Its four includes
   (`target-cdata.h', `target-regs.h', `target-frame.h', `target-insn.h') have
   no includes of their own and name no target either.  What it DOES require
   is `coretypes.h': `target-frame.h' declares functions taking `tree' and
   `machine_mode'.  That requirement is not new -- it held while this was
   `defaults.h''s tail, because `tm.h' is reached after `coretypes.h' in every
   shared translation unit -- it is only now stated where it can be checked.

   WHERE IT MUST BE INCLUDED, AND WHY NOT `coretypes.h'.

   These are `#undef' + `#define' pairs, so THE LAST INCLUSION WINS.  In a
   translation unit that still reaches `tm.h', the back end's own headers
   define 30-odd of the 65 names below, so an inclusion placed EARLIER than
   `tm.h' would be overwritten by the primary's values and would additionally
   emit a "macro redefined" warning per name per translation unit.  This is a
   design constraint, not a preference: `coretypes.h' says of itself that
   nearly every source includes it BEFORE `tm.h', and the four channel headers
   include `tm.h' after it.  So `coretypes.h' is the wrong place while any
   `tm.h' survives, and making it the right place would need a second list of
   65 `#undef's emitted ahead of the back-end headers -- a second authority for
   one fact, which is the bug this branch hunts.

   It is therefore included from exactly two places, and both are correct in
   both the transitional and the terminal state:

     - the tail of `defaults.h', i.e. immediately after every `tm.h' /
       `tm-<base>.h'.  Byte-for-byte today's ordering and today's semantics.
     - immediately AFTER a `tm.h' include in each of the four channel
       headers.  Today the include guard makes that a no-op; when the `tm.h'
       line is deleted it becomes the surviving route, with no other edit and
       no ordering change.

   A shared translation unit that includes neither `tm.h' nor any of the four
   should include this file directly.  */

#ifndef GCC_MULTI_TARGET_MACROS_H
#define GCC_MULTI_TARGET_MACROS_H

/* `target_unit', MOVED HERE FROM `defaults.h'.

   OUTSIDE the consumer/back-end guard below, because both sides need it:
   `rtl.h' declares `vec<target_unit> &' parameters and every back end's own
   translation unit includes `rtl.h' too.  It is target-neutral where it
   stands -- `BITS_PER_UNIT' is `insn-modes.h''s, reached through
   `coretypes.h:553' in every shared TU independently of `tm.h', and it is the
   genmodes union quantity rather than the primary's answer.  Its old home was
   the one thing `rtl.h' needed from `defaults.h' that was never a target
   macro at all.  Done this way to keep gengtype happy.  */
#ifndef USED_FOR_TARGET
#if BITS_PER_UNIT == 8
#define TARGET_UNIT uint8_t
#elif BITS_PER_UNIT == 16
#define TARGET_UNIT uint16_t
#elif BITS_PER_UNIT == 32
#define TARGET_UNIT uint32_t
#else
#error Unknown BITS_PER_UNIT
#endif
typedef TARGET_UNIT target_unit;
#endif

/* ------------------------------------------------------------------------
   (c-DATA): REDIRECT THE CONFIG-INVARIANT TARGET MACROS TO PER-CONFIG SLOTS.

   This block is included LAST on purpose -- from the tail of defaults.h,
   which is itself the tail of every tm header, and from the four channel
   headers immediately after their `tm.h'.  So by here every back end's
   definition and every `defaults.h' fallback has been made.  What is
   redirected is therefore the final answer for the primary base -- which is exactly the answer that must stop
   being used by target-independent code.

   WHY A `#undef' RATHER THAN A HOOK.  These macros denote a VALUE that is
   settled once options are processed, not code.  One slot per configuration,
   written once, read as a single load, is cheaper than what is here today --
   i386's `SIZE_TYPE' is a load, a test and a select -- and it needs no
   `target.def' entry, which is what keeps Stage 2 off the ~86-hook bill.

   THE GUARD IS THE WHOLE DESIGN.  `MULTI_TARGET_TARGETM_BASE' is defined by
   the build for exactly those objects compiled FOR a particular back end (see
   MULTI_TARGET_RENAME_NAMES in Makefile.in and gen-multi-target-md.awk).
   Those translation units must keep the real macros: they are how the values
   are supplied in the first place, and a back end reading a redirected macro
   would be reading its own answer back through a global.  Everything else --
   the middle end, the front ends, `libbackend' -- is compiled once, against
   the PRIMARY's tm.h, and is precisely the code that must not be.

   ONLY MEASURED-INVARIANT MACROS MAY BE ADDED HERE.  See target-cdata.h: six
   of the thirty-five candidates vary with `__attribute__((target))', and one
   of those placed here would freeze at its command-line value with no
   diagnostic.

   `GENERATOR_FILE' IS THE SECOND EXEMPTION, AND IT WAS NOT OBVIOUS.  The
   build-time generators (`genconfig', `genmodes', ... ) are compiled once per
   base against that base's `tm-<base>.h', and they do NOT get
   MULTI_TARGET_TARGETM_BASE.  They also do not link `target-cdata-select.o'
   and never will: they run on the build machine, before the compiler exists,
   and a generator IS a single-target program by construction.  Redirecting
   their macros would point them at a `targetm_cdata' that has no definition
   to link against.  The first four (c-DATA) macros did not reveal this
   because no generator spells `SIZE_TYPE' or `ASM_COMMENT_START';
   `BITS_PER_WORD' and the endianness macros are a different matter, and the
   MAX_BITS_PER_WORD guard below fired in `genconfig-aarch64.o' before any of
   them did.

   `MULTI_TARGET_SUPPLY_TU' IS THE THIRD, and it is a third category rather
   than an oversight.  `target-asm-ops-<base>.o' is compiled against one
   base's tm.h precisely to capture that base's macro values, so it is supply
   side -- but it is built for all 45 configured bases, not only the
   MULTI_TARGET_OBJS ones, and it is not `targetm'-renamed, so it cannot carry
   MULTI_TARGET_TARGETM_BASE: `target.h:392' rejects that name without a
   matching `-Dtargetm='.  gen-multi-target-md.awk defines this one instead.  */
/* `!defined (__cplusplus)' IS THE FOURTH, AND IT IS `libgcc'.

   `libgcc' compiles C, and it reaches this file through `tconfig.h' ->
   `tm.h' -> here.  `target-frame.h' declares `mt_minimum_alignment (tree,
   machine_mode, unsigned int)' and friends, and a C translation unit has no
   `tree' and no `machine_mode', so every `libgcc' object that includes
   `libgcov.h' or `generic-morestack.c' failed with

       error: unknown type name 'machine_mode'

   and NO `libgcc.a' has been built on this branch since.  The compile error
   was the visible half; the invisible half is that a C consumer cannot use
   this machinery at all -- the redirects expand to calls into the compiler's
   own per-base tables, which are not linked into a runtime library and never
   will be.

   THIS IS NOT A LEAK BEING REOPENED, and the distinction matters because
   "keep the real macros" normally means "the primary answers".  A runtime
   library is single-target by ruling: one host per runtime tree.  So the one
   tm.h it is compiled against is legitimately ITS OWN target's, and taking
   that target's `STACK_BOUNDARY' is the right answer rather than a primary's.
   That the tm.h it is handed today is `gcc/'s build-directory one is a real
   and separate bug -- libgcc/Makefile.in's `-I$(gcc_objdir)' -- and it is not
   this guard's to fix; converting these macros would not fix it either, since
   the wrong tm.h would still be the one supplying the base.

   MEASURED BEFORE RELYING ON IT: no C source under `libgcc/' spells any of
   the thirteen names redirected below.  The hits a grep for them returns are
   `X86_64_SAVE_NEW_STACK_BOUNDARY' in `config/i386/morestack.S' (assembly, a
   different identifier) and `__LIBGCC_DWARF_CIE_DATA_ALIGNMENT__' in
   `unwind-dw2.c'.  So this arm changes no value that anything reads; it stops
   a header the C front end cannot parse from being parsed.  If a libgcc file
   ever does spell one, it gets its own target's tm.h answer, which is the
   answer it wants.  */
#if defined (MULTI_TARGET_TARGETM_BASE) || defined (GENERATOR_FILE)	\
    || defined (MULTI_TARGET_SUPPLY_TU) || defined (MULTI_TARGET_REG_PROBE) \
    || !defined (__cplusplus)
/* A back end's own translation unit, a build-time generator, another
   supply-side TU, or a C consumer such as libgcc: keep the real macros.  */

/* AND `MT_FIRST_PSEUDO_REGISTER' MUST STILL HAVE A MEANING HERE, because
   `rtl.h' spells it unconditionally in `HARD_REGISTER_NUM_P'.

   `MT_FIRST_PSEUDO_REGISTER' normally reads `targetm_regs', which arrives
   with `target-regs.h' from the `#else' branch below -- so in every exempt
   context it would be an undeclared identifier.  Measured: three
   `gencondmd' objects failed with `'MT_FIRST_PSEUDO_REGISTER' was not
   declared in this scope' the moment `HARD_REGISTER_NUM_P' was converted,
   because generators reach `regs.h' -> `rtl.h' and never link
   `target-regs-select.o'.

   THE FALLBACK IS THIS TU'S OWN `FIRST_PSEUDO_REGISTER', AND THAT IS A REAL
   PER-BASE ANSWER RATHER THAN A FLOOR.  Every exempt context is
   single-target BY CONSTRUCTION: a back end's TU and a supply-side TU are
   compiled against that base's own `tm-<base>.h', a generator runs on the
   build machine against one base's headers before any compiler exists, and a
   runtime library is single-host by ruling.  So `FIRST_PSEUDO_REGISTER'
   there IS the answer for the only target that TU serves.  This is the
   supply-side floor PRINCIPLES section 2a permits, not the consumer-side one
   it bans -- no base ever reads another's value through it.

   It is defined HERE rather than as an `#ifdef' in `rtl.h' on purpose.  An
   `#ifdef MT_FIRST_PSEUDO_REGISTER' in `rtl.h' would be decided at the point
   `rtl.h' is PARSED, so it would silently pick the wrong branch for any TU
   that includes `rtl.h' before `tm.h' -- a second authority for one fact,
   resolved by include order, with no diagnostic.  Defining it in both
   branches of the one `#if' that already makes this decision keeps the
   decision in one place, and the macro body is expanded at USE time.  */
#define MT_FIRST_PSEUDO_REGISTER FIRST_PSEUDO_REGISTER

#else
#include "target-cdata.h"

/* ------------------------------------------------------------------------
   THE REGISTER VOCABULARY, PART 2 OF 2: THE PER-CONFIGURATION DATA.

   Only the two class NAMES that target-independent code actually spells, and
   only because it spells them in no constant-expression context at all -- no
   case label, no array bound, no static initialiser, no `#if' (swept).
   `NO_REGS' is deliberately absent: it is 0 in all 52 back ends, and
   reginfo.cc and ira.cc seed their subunion and superunion tables by
   memset-to-zero, which is only meaningful if 0 is the empty class.

   `REGNO_REG_CLASS' is here rather than left alone because it is called from
   INSIDE the function that ICEs (reginfo.cc:405), and because i386's
   definition is the bare subscript `regclass_map[REGNO]' -- with the union
   width above, generic code asks it about three register numbers i386 does
   not have.  The dispatched version answers NO_REGS out of range.  */
#include "target-regs.h"
#include "multi-target-reg-widths.h"

/* `enum reg_class' ITSELF, FOR A TRANSLATION UNIT THAT HAS NO `tm.h'.

   The TYPE, not any value.  `hard-reg-set.h:551' declares three
   `enum reg_class' arrays in `struct target_hard_regs', and `coretypes.h:432'
   says of the enum that it "is target specific, so it should not appear in
   target-independent code" -- which is why `reg_class_t' is an int.  The
   declaration nevertheless comes from the back end's own header, so a shared
   translation unit that stops including `tm.h' loses the TYPE and gets

       hard-reg-set.h:551: use of enum 'reg_class' without previous declaration

   which is the single largest cause on the measured list: 8 of the 22 Class A
   files that fail with `tm.h' emptied fail on exactly this, and it is what
   revoked `lists.cc', `rtlhash.cc' and `rtl-error.cc' after they had been
   scored deletable.

   THIS IS NOT AN `#ifndef' FLOOR, AND THE TEST PRINCIPLES 2a PRESCRIBES IS
   "WHOSE ANSWER IS THE FALLBACK".  The answer here is NOBODY'S: no register
   class VALUE is supplied.  `ALL_REGS', `GENERAL_REGS' and `REGNO_REG_CLASS'
   below still come from `targetm_regs', i.e. from the selected base, and a
   base that has not been selected still fails by name.  The one enumerator
   is `NO_REGS = 0', which is 0 in all 52 back ends -- the same measurement
   the block above already relies on when it says reginfo.cc and ira.cc seed
   their tables by memset-to-zero.

   THE GUARD IS `GCC_TM_H', WHICH IS A FACT AND NOT A DEFAULT.  It asks "has a
   back end's header chain been read in this translation unit", and the answer
   decides who declares the type -- never what it contains.  In the `tm.h'
   route this header is reached from `defaults.h', i.e. from INSIDE `tm.h'
   after its own guard is set, so this is skipped and the back end's real enum
   stands, unchanged, byte for byte.

   IF A TRANSLATION UNIT REACHES THIS FIRST AND `tm.h' LATER, the back end's
   declaration collides with this one and the compiler says so.  That is the
   wanted direction: a hard error naming both declarations, rather than two
   authorities for one type agreeing by luck.  Measured over the whole tree at
   anchor 48: no shared TU is in that order today (`tm.h' is conventionally
   the fourth line, ahead of everything that reaches here).

   THE WIDTH IS CROSS-CHECKED RATHER THAN ASSUMED.  A one-enumerator enum and
   a 34-enumerator one must agree on size or `struct target_hard_regs' has two
   layouts -- the `cl_optimization' shape exactly.  `target-regs.cc' measures
   `sizeof (enum reg_class)' in each base's OWN preprocessor context and
   `mt_check_reg_class_size' compares it with this one at selection time,
   naming the base and both sizes.  A silent agreement is not what is being
   relied on; a check that can fail is.  */
#ifndef GCC_TM_H
enum reg_class { NO_REGS = 0 };
#endif

/* THE COMPILE-TIME WIDTHS, FOR CONSUMER TRANSLATION UNITS.

   Target-independent code declares its own arrays with these bounds -- one
   `char global_regs[FIRST_PSEUDO_REGISTER]' in reginfo.cc is enough to make
   the point -- and it is compiled ONCE, against the primary's tm.h.  Sized at
   the primary's 92 they overflow the moment a base with 95 is selected.  So
   for these translation units the two names mean the compile-time MAXIMUM
   over the configured back ends.

   THIS IS NOT WHAT MAKES `struct target_hard_regs' ONE LAYOUT, and it cannot
   be.  A back end's own translation unit is exempt from this block by design,
   and must be: `config/i386/i386.h' declares `regclass_map' and three
   debugger register maps `[FIRST_PSEUDO_REGISTER]' at a point BEFORE
   defaults.h has been reached, while `config/i386/i386.cc' defines them
   after -- so an override here that reached back-end objects would make the
   declaration 92 and the definition 95.  That is a hard error, and it was
   the first thing this design hit.  The four SHARED structures name
   MULTI_TARGET_UNION_* explicitly instead; see hard-reg-set.h.  A site missed
   there is silent, so `init_reg_sets' checks all four struct sizes against
   the values a back end's own translation unit computed.

   `LIM_REG_CLASSES' KEEPS ITS ENUM TYPE.  It is assigned to `enum reg_class'
   lvalues in eight places (reginfo.cc:374, ira.cc:541, :1212, :1253, ...) and
   C++ has no implicit int-to-enum conversion, so a plain integer here would
   be eight errors rather than a union.  It is also an array bound twice
   (ira.cc:995, lra-constraints.cc:2170-2171), which is why it stays a
   constant expression and does not become a run-time count.  */
#undef FIRST_PSEUDO_REGISTER
#define FIRST_PSEUDO_REGISTER MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER
#undef N_REG_CLASSES
#define N_REG_CLASSES MULTI_TARGET_UNION_N_REG_CLASSES
#undef LIM_REG_CLASSES
#define LIM_REG_CLASSES ((enum reg_class) MULTI_TARGET_UNION_N_REG_CLASSES)

#undef ALL_REGS
#define ALL_REGS ((enum reg_class) targetm_regs->all_regs)
#undef GENERAL_REGS
#define GENERAL_REGS ((enum reg_class) targetm_regs->general_regs)
#undef REGNO_REG_CLASS
#define REGNO_REG_CLASS(REGNO) \
  ((enum reg_class) targetm_regs->regno_reg_class ((int) (REGNO)))

/* `PIC_OFFSET_TABLE_REGNUM', asked of the SELECTED base.  See the field
   comment in target-regs.h for what the primary answering cost: i386's
   expands to `INVALID_REGNUM' for x86_64, so `emit-rtl.cc:6361' left
   `pic_offset_table_rtx' NULL for every one of the forty-four back ends that
   DO have a PIC register, and mips's prologue then handed that null to
   `reg_overlap_mentioned_p'.

   NOT `#ifdef'-BREAKING AND NOT CONSTANT-EXPRESSION-BREAKING.  Swept over all
   of `gcc/' outside `config/' and the generators: the twelve shared spellings
   (df-scan.cc x3, emit-rtl.cc x4, cfgexpand.cc x2, shrink-wrap.cc x2,
   builtins.cc, df-problems.cc, reginfo.cc) are every one an ordinary run-time
   expression -- no `#if', no case label, no array bound, no static
   initialiser -- and the only preprocessor occurrence of the name anywhere is
   `defaults.h:871's own `#ifndef', which is upstream's and is on the supply
   side.  `REAL_PIC_OFFSET_TABLE_REGNUM' is a DIFFERENT name, is `#ifdef'd at
   ira-lives.cc:1684 and lra-lives.cc:1111, and is NOT converted here.  */
#undef PIC_OFFSET_TABLE_REGNUM
#define PIC_OFFSET_TABLE_REGNUM (targetm_regs->pic_offset_table_regnum ())

/* `MAX_BITS_PER_WORD' is an array bound in eleven places.  If this back end
   did not supply its own, the fallback above derived it from BITS_PER_WORD,
   and BITS_PER_WORD is about to stop being a constant expression.  Refuse,
   by name, rather than emit eleven confusing errors in expmed.h.  The name
   means "the compile-time MAXIMUM over configurations", so a literal is the
   right answer for it, not a per-config slot.  */
#ifdef MAX_BITS_PER_WORD_FROM_BITS_PER_WORD
#error the primary back end does not define MAX_BITS_PER_WORD, so defaults.h \
derived it from BITS_PER_WORD -- which the (c-DATA) redirection below turns \
into a run-time load, breaking the eleven array bounds in expmed.h, \
expmed.cc and lower-subreg.h.  Give the primary an explicit MAX_BITS_PER_WORD \
(a compile-time maximum over configurations, which is what the name means).
#endif

#undef ASM_COMMENT_START
#define ASM_COMMENT_START (targetm_cdata.asm_comment_start)
#undef WCHAR_TYPE
#define WCHAR_TYPE (targetm_cdata.wchar_type)
#undef SIZE_TYPE
#define SIZE_TYPE (targetm_cdata.size_type)
#undef PTRDIFF_TYPE
#define PTRDIFF_TYPE (targetm_cdata.ptrdiff_type)

#undef BYTES_BIG_ENDIAN
#define BYTES_BIG_ENDIAN (targetm_cdata.bytes_big_endian)
#undef WORDS_BIG_ENDIAN
#define WORDS_BIG_ENDIAN (targetm_cdata.words_big_endian)
#undef FLOAT_WORDS_BIG_ENDIAN
#define FLOAT_WORDS_BIG_ENDIAN (targetm_cdata.float_words_big_endian)
#undef REG_WORDS_BIG_ENDIAN
#define REG_WORDS_BIG_ENDIAN (targetm_cdata.reg_words_big_endian)
#undef STRICT_ALIGNMENT
#define STRICT_ALIGNMENT (targetm_cdata.strict_alignment)
#undef SHIFT_COUNT_TRUNCATED
#define SHIFT_COUNT_TRUNCATED (targetm_cdata.shift_count_truncated)
#undef JUMP_TABLES_IN_TEXT_SECTION
#define JUMP_TABLES_IN_TEXT_SECTION (targetm_cdata.jump_tables_in_text_section)
#undef BITS_PER_WORD
#define BITS_PER_WORD (targetm_cdata.bits_per_word)
#undef LONG_TYPE_SIZE
#define LONG_TYPE_SIZE (targetm_cdata.long_type_size)
#undef PARM_BOUNDARY
#define PARM_BOUNDARY (targetm_cdata.parm_boundary)
#undef FUNCTION_BOUNDARY
#define FUNCTION_BOUNDARY (targetm_cdata.function_boundary)
/* `TARGET_PTRMEMFUNC_VBIT_LOCATION'.  See the field comment in
   target-cdata.h: this is the layout of every pointer to member function, it
   was the primary's for all 47 back ends, and it is the one macro in this
   block whose leak is an ABI break rather than a code-quality one.

   NOT `#if'-BREAKING.  Swept over all of `gcc/' outside `config/': the eleven
   spellings (cp/typeck.cc x7, ipa-prop.cc, builtins.cc, function.h, and
   defaults.h's own supply-side `#ifndef') are ordinary run-time expressions,
   two `switch' conditions among them and both with `default: gcc_unreachable
   ()'.  No `#if', no case label, no array bound, no static initialiser.

   The slot is an `int' and this redirect does not cast it back to
   `enum ptrmemfunc_vbit_where_t'.  That enum is declared in `tree-core.h',
   which this header is nowhere near -- `multi-target-macros.h' arrives
   through `tm.h', long before any tree header -- and a cast naming it would
   bind the redirect to an include order it cannot see.  Every use site
   compares against the enumerators or switches with a default, so the
   integral form means exactly what the enumerator form did.  */
#undef TARGET_PTRMEMFUNC_VBIT_LOCATION
#define TARGET_PTRMEMFUNC_VBIT_LOCATION (targetm_cdata.ptrmemfunc_vbit_location)
/* ASM_OUTPUT_ALIGN.  A statement macro rather than a value, so it goes to
   `target-asm-ops.h''s per-base table rather than to `targetm_cdata'; see
   that header for why the operand's MEANING and not just its spelling varies
   between back ends.  Reached at a settled point -- every definition of it is
   in the back end's own header chain (`riscv.h', `i386/att.h', `elfos.h'),
   never in `insn-config.h' -- so a redirect here is the last word, which is
   `LOAD_EXTEND_OP''s argument above.  Swept: all ~30 uses outside `config/'
   are statements, none is in a `#if'.

   DECLARED HERE RATHER THAN BY INCLUDING `target-asm-ops.h'.  That header
   also carries `gcc_taop_output_align', whose body is `ASM_OUTPUT_ALIGN' --
   the macro this block is in the middle of replacing -- so pulling it in at
   this point would make the definition depend on whether it arrived before or
   after the redirect.  One extern declaration has no such ordering.  */
extern void mt_asm_output_align (FILE *, int);
#undef ASM_OUTPUT_ALIGN
#define ASM_OUTPUT_ALIGN(STREAM, LOG) (mt_asm_output_align ((STREAM), (LOG)))
#undef ATTRIBUTE_ALIGNED_VALUE
#define ATTRIBUTE_ALIGNED_VALUE (targetm_cdata.attribute_aligned_value)
#undef MALLOC_ABI_ALIGNMENT
#define MALLOC_ABI_ALIGNMENT (targetm_cdata.malloc_abi_alignment)
#undef TRAMPOLINE_SIZE
#define TRAMPOLINE_SIZE (targetm_cdata.trampoline_size)
#undef DWARF_CIE_DATA_ALIGNMENT
#define DWARF_CIE_DATA_ALIGNMENT (targetm_cdata.dwarf_cie_data_alignment)
#undef STACK_CHECK_FIXED_FRAME_SIZE
/* Kept on ONE line, past the usual column limit, on purpose: tab-probe.sh's
   completeness check matches `^#define <M> (targetm_cdata.' and a continuation
   makes it report the macro unredirected.  It did, and that is the check
   working -- but the honest fix is the line, not a more forgiving matcher.  */
#define STACK_CHECK_FIXED_FRAME_SIZE (targetm_cdata.stack_check_fixed_frame_size)
#undef STACK_CHECK_MAX_FRAME_SIZE
#define STACK_CHECK_MAX_FRAME_SIZE (targetm_cdata.stack_check_max_frame_size)
#undef MAX_FIXED_MODE_SIZE
#define MAX_FIXED_MODE_SIZE (targetm_cdata.max_fixed_mode_size)
/* `STORE_FLAG_VALUE' -- what a `set' of a comparison result stores for true.
   It is `1' for most back ends and `-1' for those whose compares produce an
   all-ones mask, and a shared TU compiled once answered `1' for every one of
   them: the wrong sign here is silently wrong comparison code, not an ICE.

   Fit for cdata rather than a call, on this file's own two tests: measured
   over all 48 configured back ends, every one expands it to an integer
   LITERAL (only `-1' and `1' occur), so it is invariant and it is evaluable
   at `target-cdata.cc''s refresh point, where `cfun' is null and no back
   end's functions are declared.  `scratchpad/t32-valueall.sh' is the arm.  */
#undef STORE_FLAG_VALUE
#define STORE_FLAG_VALUE (targetm_cdata.store_flag_value)
/* `WORD_REGISTER_OPERATIONS' -- whether an operation on a word-width register
   yields a result valid for the whole word.  A pure 0/1 predicate that decides
   how much shared code may assume about the high bits of a sub-word value, so
   a shared TU compiled once handed every back end the primary's assumption.

   Measured over all 48 back ends: every one expands it to the literal `0' or
   `1', so it is invariant and evaluable at the refresh point.  No `#if' site
   anywhere outside `defaults.h''s own supply-side fallback, so unlike
   `STORE_FLAG_VALUE' above this redirect stands alone.  */
#undef WORD_REGISTER_OPERATIONS
#define WORD_REGISTER_OPERATIONS (targetm_cdata.word_register_operations)
/* `DWARF_FRAME_RETURN_COLUMN' WAS REDIRECTED HERE AND IS NOW A CALL, with the
   rest of the DWARF register family below.  epiphany's reads
   `current_function_decl', which is null when `target-cdata.cc' runs.  */

/* ------------------------------------------------------------------------
   THE FRAME AND ARGUMENT-REGISTER MACROS.  See target-frame.h for what each
   one was answering with before, and why these are CALLS rather than
   `targetm_cdata' fields -- the short version being that target-cdata.h's own
   header comment already records `STACK_BOUNDARY' as measured NOT invariant,
   and four of the six take arguments so there is no value to cache.

   THESE ARE NOT `#undef'-THEN-DEFINE FOR TIDINESS.  Every one of the six
   already has a definition by this point -- four of them from `defaults.h'
   itself a thousand lines above, two from the primary's `config/<cpu>/<cpu>.h'
   -- and it is the primary's, which is the bug.

   A redirect here reaches every consumer at once, which is the point:
   `function.cc' is the file this was chased into, but `calls.cc' spells
   OUTGOING_REG_PARM_STACK_SPACE seven times, `cfgexpand.cc' spells
   MINIMUM_ALIGNMENT four, and `alias.cc', `builtins.cc', `df-scan.cc',
   `ifcvt.cc', `loop-invariant.cc' and `rtlanal.cc' each ask
   FUNCTION_ARG_REGNO_P about the primary's argument registers.  Editing the
   call sites in one file would have left all of those answering as i386.

   SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE LANDING, because that is what
   makes a redirect like this fail: a `#if', a case label, an array bound or a
   static initialiser cannot hold a call.  Outside `config/', the six appear
   only in ordinary run-time expressions.  Two `#ifdef STACK_BOUNDARY'
   (reload1.cc:1293, emit-rtl.cc:6024) are unaffected -- the name stays
   defined.  The one derived macro that follows them into run time is
   `SUPPORTS_STACK_ALIGNMENT' (`MAX_STACK_ALIGNMENT > STACK_BOUNDARY', above);
   all sixteen of its uses outside `config/' are `if' conditions, and it
   becoming per-target is a fix rather than a cost.  */
#include "target-frame.h"

/* The three `HAVE_<pattern>' booleans, for the same set of translation units
   and by the same route.  Unlike the six below there is no `#undef'/`#define'
   pair for these: their use sites in combine.cc, lra-constraints.cc and
   simplify-rtx.cc were rewritten to call `mt_have_*' directly.  A redirect
   would have been wrong here in a way it is not wrong there -- `HAVE_lo_sum'
   is defined by `insn-config.h', which shared code includes at unpredictable
   points relative to this header, so a `#define' here would win in some
   translation units and lose in others with nothing to say which.  Four call
   sites spelled out is cheaper than a macro whose value depends on include
   order.  */
#include "target-insn.h"

/* CONDITION-CODE MODE SELECTION; see target-ccmode.h for the measurement and
   for what each of the three was answering.

   These DO get `#undef'/`#define' pairs, unlike the `HAVE_<pattern>' block
   above and for the reason it gives: all three come from the back end's own
   `<cpu>.h' with a `defaults.h' fallback, exactly like `LOAD_EXTEND_OP' and
   the frame macros below, so they are reached at a settled point and a
   redirect here is the last word.

   THE `#ifdef SELECT_CC_MODE' GUARDS ARE NOT CLOSED BY THE REDIRECT, and that
   is the half a redirect alone would get wrong.  The name stays defined here,
   so `#ifdef SELECT_CC_MODE' remains true -- which is what it already was for
   every back end, because `i386.h:2074' defines it.  27 of the 47 back ends
   define no such macro and upstream compiles those three blocks OUT for them.
   `combine.cc' (two sites), `ccmp.cc' and `compare-elim.cc' therefore have
   their guards rewritten as `if (mt_has_select_cc_mode ())', PRINCIPLES'
   SHAPE 1 and SHAPE 2; the redirect below serves the bodies.

   `REVERSIBLE_CC_MODE' and `REVERSE_CONDITION' need no existence predicate:
   `defaults.h:1215' and `:1420' supply real answers for a back end that
   defines nothing, and evaluated in the per-base translation unit those are
   that back end's own answers rather than the primary's.

   SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE LANDING, as the frame block
   below records: outside `config/' the three appear only in ordinary run-time
   expressions (`combine.cc:3218', `:6943', `ccmp.cc:309',
   `compare-elim.cc:528', `:539', `:542', `jump.cc:373', `:374').  There is no
   `#if' on any of them, and `compare-elim.cc:517's local
   `#define SELECT_CC_MODE(A,B,C) (gcc_unreachable (), VOIDmode)' -- a dummy
   under the `#ifndef' that could never be reached -- is deleted with the
   guard it belonged to.  */
#include "target-ccmode.h"

#undef SELECT_CC_MODE
#define SELECT_CC_MODE(OP, X, Y) \
  ((machine_mode) mt_select_cc_mode ((int) (OP), (X), (Y)))
#undef REVERSIBLE_CC_MODE
#define REVERSIBLE_CC_MODE(MODE) (mt_reversible_cc_mode ((int) (MODE)))
#undef REVERSE_CONDITION
#define REVERSE_CONDITION(CODE, MODE) \
  ((enum rtx_code) mt_reverse_condition ((int) (CODE), (int) (MODE)))

/* THE MODE-SWITCHING ENTITY LIST AND THE SCHEDULER-ATTRIBUTE INITIALISER.
   Declarations only, and no `#undef'/`#define' pair for either, for the
   reason the `HAVE_<pattern>' paragraph above gives: the macros they replace
   (`OPTIMIZE_MODE_SWITCHING', `NUM_MODES_FOR_MODE_SWITCHING',
   `INSN_SCHEDULING') are read at points this header cannot order itself
   against, and both have a SINGLE shared consumer each -- `mode-switching.cc'
   and `cfgexpand.cc'/`run-rtl-passes.cc'.  Rewriting three call sites is
   cheaper and has no include-order dependence.  See target-modeswitch.h and
   target-sched.h for what each was answering wrongly and for whom.  */
#include "target-modeswitch.h"
#include "target-sched.h"

/* `LOAD_EXTEND_OP' IS THE ONE MEMBER OF target-insn.h THAT DOES GET A
   `#undef'/`#define' PAIR, and the paragraph above says why the other three
   do not: theirs come from `insn-config.h', which shared code includes at
   unpredictable points relative to this header.  This one comes from the back
   end's own `<cpu>.h' with a `defaults.h' fallback, exactly like the frame
   macros below, so it is reached at a settled point and a redirect here is the
   last word.  Its use site -- `rtl.h:4762', inside the inline `load_extend_op'
   -- is a header every translation unit shares, which is also why leaving it
   to a rewritten call site was not an option: there is one call site and it is
   in the header that has to stop needing `tm.h'.  */
#undef LOAD_EXTEND_OP
#define LOAD_EXTEND_OP(MODE) \
  ((enum rtx_code) mt_load_extend_op ((int) (MODE)))

/* THE EIGHT AUTO-INCREMENT FORMS.  These get `#undef'/`#define' pairs for
   `LOAD_EXTEND_OP''s reason and not the `HAVE_<pattern>' paragraph's: they do
   NOT come from `insn-config.h'.  They come from the back end's own `<cpu>.h'
   -- `riscv.h:1313', `aarch64.h', `arm.h', `rs6000.h' and 21 more -- with
   `rtl.h''s `#ifndef ... 0' as the fallback, so they are reached at a settled
   point and a redirect here is the last word.  `rtl.h''s fallbacks then never
   fire in a shared TU, because the names are already defined when it is read;
   in every exempt TU above they fire exactly as upstream intends.

   WHY A REDIRECT AND NOT REWRITTEN CALL SITES.  There are 34 of them, and
   `rtl.h:3062-3090' spells four of the eight again inside
   `USE_LOAD_POST_INCREMENT' and its five siblings -- macros in a header every
   translation unit shares.  That is the same argument `LOAD_EXTEND_OP' makes
   two paragraphs up: the use site is in the header that has to stop needing
   `tm.h'.

   SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE LANDING, as this file's other
   blocks record.  Outside `config/' the eight appear only in ordinary
   run-time expressions -- `if' conditions and `?:' in `auto-inc-dec.cc', a
   `gcc_assert' in `expr.cc', `if' conditions in `cse.cc'.  There is no `#if'
   on any of them and no array bound, no case label and no static initialiser;
   `rtl.h:2998's `#if defined (...)' disjunction is inside the exempt arm, so
   it is never reached with these definitions in scope.  */
#undef HAVE_PRE_INCREMENT
#define HAVE_PRE_INCREMENT	 (mt_have_autoinc (MT_AUTOINC_PRE_INC))
#undef HAVE_PRE_DECREMENT
#define HAVE_PRE_DECREMENT	 (mt_have_autoinc (MT_AUTOINC_PRE_DEC))
#undef HAVE_POST_INCREMENT
#define HAVE_POST_INCREMENT	 (mt_have_autoinc (MT_AUTOINC_POST_INC))
#undef HAVE_POST_DECREMENT
#define HAVE_POST_DECREMENT	 (mt_have_autoinc (MT_AUTOINC_POST_DEC))
#undef HAVE_PRE_MODIFY_DISP
#define HAVE_PRE_MODIFY_DISP	 (mt_have_autoinc (MT_AUTOINC_PRE_MODIFY_DISP))
#undef HAVE_POST_MODIFY_DISP
#define HAVE_POST_MODIFY_DISP	 (mt_have_autoinc (MT_AUTOINC_POST_MODIFY_DISP))
#undef HAVE_PRE_MODIFY_REG
#define HAVE_PRE_MODIFY_REG	 (mt_have_autoinc (MT_AUTOINC_PRE_MODIFY_REG))
#undef HAVE_POST_MODIFY_REG
#define HAVE_POST_MODIFY_REG	 (mt_have_autoinc (MT_AUTOINC_POST_MODIFY_REG))

/* AND THE EIGHT `USE_*' MACROS WITH THEM, WHICH IS NOT OPTIONAL.  They live in
   `rtl.h:3060-3090' as `#ifndef' fallbacks that expand to the eight above, so
   redirecting only the `HAVE_*' half leaves seven back ends' explicit answers
   overridden by the `HAVE_*' one.  aarch64 defines all eight to a literal `0'
   while having five of the addressing modes, so while `HAVE_POST_INCREMENT'
   was stuck at 0 the fallback accidentally agreed with it; correcting the
   `HAVE_*' half alone starts telling `tree-ssa-loop-ivopts.cc' that aarch64
   wants post-increment addressing, which aarch64 has said in its own header
   that it does not.  Measured before this went in: aarch64's `copy' loop
   acquired `ldr w3, [x1], 4' / `str w3, [x0, 4]!' where stock aarch64 emits
   indexed addressing.  The two halves go together or neither does.  */
#undef USE_LOAD_POST_INCREMENT
#define USE_LOAD_POST_INCREMENT(M) \
  (mt_use_autoinc (MT_USEINC_LOAD_POST_INC, (int) (M)))
#undef USE_LOAD_POST_DECREMENT
#define USE_LOAD_POST_DECREMENT(M) \
  (mt_use_autoinc (MT_USEINC_LOAD_POST_DEC, (int) (M)))
#undef USE_LOAD_PRE_INCREMENT
#define USE_LOAD_PRE_INCREMENT(M) \
  (mt_use_autoinc (MT_USEINC_LOAD_PRE_INC, (int) (M)))
#undef USE_LOAD_PRE_DECREMENT
#define USE_LOAD_PRE_DECREMENT(M) \
  (mt_use_autoinc (MT_USEINC_LOAD_PRE_DEC, (int) (M)))
#undef USE_STORE_POST_INCREMENT
#define USE_STORE_POST_INCREMENT(M) \
  (mt_use_autoinc (MT_USEINC_STORE_POST_INC, (int) (M)))
#undef USE_STORE_POST_DECREMENT
#define USE_STORE_POST_DECREMENT(M) \
  (mt_use_autoinc (MT_USEINC_STORE_POST_DEC, (int) (M)))
#undef USE_STORE_PRE_INCREMENT
#define USE_STORE_PRE_INCREMENT(M) \
  (mt_use_autoinc (MT_USEINC_STORE_PRE_INC, (int) (M)))
#undef USE_STORE_PRE_DECREMENT
#define USE_STORE_PRE_DECREMENT(M) \
  (mt_use_autoinc (MT_USEINC_STORE_PRE_DEC, (int) (M)))

#undef STACK_BOUNDARY
#define STACK_BOUNDARY (mt_stack_boundary ())
#undef PREFERRED_STACK_BOUNDARY
#define PREFERRED_STACK_BOUNDARY (mt_preferred_stack_boundary ())
#undef STACK_SLOT_ALIGNMENT
#define STACK_SLOT_ALIGNMENT(TYPE, MODE, ALIGN) \
  (mt_stack_slot_alignment ((TYPE), (MODE), (ALIGN)))
#undef MINIMUM_ALIGNMENT
#define MINIMUM_ALIGNMENT(EXP, MODE, ALIGN) \
  (mt_minimum_alignment ((EXP), (MODE), (ALIGN)))
#undef OUTGOING_REG_PARM_STACK_SPACE
#define OUTGOING_REG_PARM_STACK_SPACE(FNTYPE) \
  (mt_outgoing_reg_parm_stack_space ((FNTYPE)))
#undef FUNCTION_ARG_REGNO_P
#define FUNCTION_ARG_REGNO_P(N) (mt_function_arg_regno_p ((int) (N)))

/* `EPILOGUE_USES'.  `df-scan.cc:3647' is the only shared consumer and spells
   it unconditionally, so the redirect is safe; see target-frame.h for why the
   leaked i386 answer emits a bare `ret' for every aarch64 SME2 ZA-writing
   function instead of producing a wrong value.  */
#undef EPILOGUE_USES
#define EPILOGUE_USES(REGNO) (mt_epilogue_uses ((int) (REGNO)))

/* THE STACK-ALIGNMENT CLOSURE.  See target-frame.h for the full argument; the
   short version is that the leak `nm -uC cfgexpand.o' names
   (`ix86_incoming_stack_boundary', from i386.h:803 -- and i386 is the only one
   of the 48 back ends to define `INCOMING_STACK_BOUNDARY' at all) is NOT the
   one that makes `expand_stack_alignment' run for aarch64.  That is
   `SUPPORTS_STACK_ALIGNMENT' at :1256, whose `MAX_STACK_ALIGNMENT' comes from
   the `#ifdef' at :1249 being answered by the primary.  Redirecting only the
   named one leaves aarch64 inside a function it should return from, which is
   a quieter version of the same bug rather than a fix.

   ALL FOUR ARE `#undef'-THEN-DEFINE FROM A DEFINITION THIS FILE MADE ABOVE --
   :945, :1250/:1252, :1250/:1253 and :1256 -- and those definitions are what
   makes the leak transitive: `SUPPORTS_STACK_ALIGNMENT' names no back-end
   symbol and looks target-neutral where it is written.

   SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE LANDING.  Outside `config/'
   the four have 2 + 1 + 21 + 11 uses and every one is an ordinary run-time
   expression: `if' conditions in builtins.cc, calls.cc, cfgexpand.cc,
   explow.cc and function.cc, comparisons and assignments in cfgexpand.cc,
   function.cc and asan.cc, and one `known_le' in tree-vect-data-refs.cc.
   There is no `#if', no case label, no array bound and no static initialiser
   -- and none of the four is `#ifdef'-guarded at a use site, so unlike
   `DATA_ALIGNMENT' there is no guard here that a redirect could leave being
   answered by a different back end than the body.  */
#undef INCOMING_STACK_BOUNDARY
#define INCOMING_STACK_BOUNDARY (mt_incoming_stack_boundary ())
#undef MAX_STACK_ALIGNMENT
#define MAX_STACK_ALIGNMENT (mt_max_stack_alignment ())
#undef MAX_SUPPORTED_STACK_ALIGNMENT
#define MAX_SUPPORTED_STACK_ALIGNMENT (mt_max_supported_stack_alignment ())
#undef SUPPORTS_STACK_ALIGNMENT
#define SUPPORTS_STACK_ALIGNMENT (mt_supports_stack_alignment ())

/* ------------------------------------------------------------------------
   THE REGISTER-ELIMINATION TABLE.  See target-frame.h for the four register
   numbers that diverge and for why the LIST matters more than the offset
   function whose symbol `nm -uC ira.o' actually names.

   `INITIAL_ELIMINATION_OFFSET' IS REDIRECTED.  Outside `config/' it has 14
   uses -- rtlanal.cc has 11, reload1.cc 2, lra-eliminations.cc 1 -- and every
   one assigns through the third argument in an ordinary statement.  No `#if',
   no case label, no array bound, no static initialiser, and (swept) no
   `#ifdef INITIAL_ELIMINATION_OFFSET' anywhere in shared code, so there is no
   guard a redirect could leave answered by a different back end than the body.

   `ELIMINABLE_REGS' IS POISONED RATHER THAN REDIRECTED, because there is
   nothing to redirect it TO: it is a brace initialiser and a run-time table
   has no such spelling.  Its eight shared consumers now walk
   `mt_num_eliminable_regs ()' / `mt_eliminable_from' / `mt_eliminable_to'.
   Leaving the name alone would have been the quiet option and the wrong one:
   the macro would stay defined, expanding to the primary's four pairs, and
   the ninth consumer -- or a rebased upstream one -- would compile clean and
   be wrong in exactly the way this change is fixing.  Poisoned, it is an
   error naming the replacement.  A `#pragma GCC poison' is not usable here:
   this file is read by the compiler that is BEING BUILT as well as by the one
   building it, and the name is legitimately defined in every back end's own
   translation unit, which this block already excludes by other means.

   THE POISON IS A `#define' FOR ONE AND A BARE `#undef' FOR THE OTHER, and
   the asymmetry is deliberate.  A poison `#define' makes `#ifdef' TRUE, which
   is the wrong answer for a name whose whole content is an existence
   question.  `ELIMINABLE_REGS' is never `#ifdef'd -- swept over all of `gcc/'
   and `libgcc/'; the only hit is a 2007 ChangeLog entry -- so a `#define'
   there can only ever be reached as a use, which is what it must catch.
   `RELOAD_ELIMINABLE_REGS' WAS `#ifdef'd, at reload1.cc:288, and that site is
   half the reason this family is being converted: it asked the PRIMARY's
   headers whether the SELECTED base has a reload-specific table.  That
   question is now answered in target-cumargs.cc, in the base's own
   translation unit, and recorded as `n_reload_eliminables'.  So the name is
   simply undefined here -- a poison `#define' would resurrect exactly the
   `#ifdef'-answered-by-the-primary bug in any site that asked again.  */
#undef INITIAL_ELIMINATION_OFFSET
#define INITIAL_ELIMINATION_OFFSET(FROM, TO, OFFSET) \
  ((OFFSET) = mt_initial_elimination_offset ((int) (FROM), (int) (TO)))

#undef ELIMINABLE_REGS
#define ELIMINABLE_REGS \
  MULTI_TARGET_ELIMINABLE_REGS_IS_PER_BASE_call_mt_num_eliminable_regs_instead
#undef RELOAD_ELIMINABLE_REGS

/* ------------------------------------------------------------------------
   `Pmode' -- THE MODE OF AN ADDRESS.  See target-frame.h for the gdb reading
   that diagnosed this: at the failing `plus_constant' call, with frame #1 the
   ICE's own `aarch64_expand_prologue', the mode ARGUMENT is DImode (27,
   aarch64's own `Pmode') and the mode of the rtx is SImode (26), because
   `stack_pointer_rtx' was built in emit-rtl.cc -- shared code -- from i386's
   `(ix86_pmode == PMODE_DI ? DImode : SImode)' with `ix86_pmode' still at its
   `Init (PMODE_SI)' default.  x86_64 reads 27 and 27 and has no mismatching
   call at all.

   REDIRECTED RATHER THAN POISONED, unlike `ELIMINABLE_REGS' just above,
   because there is something to redirect it TO: it denotes a single value,
   and all 648 shared use sites want it as a run-time expression.  The sweep
   that establishes that is recorded at `mt_pmode''s declaration.

   THIS PARAGRAPH USED TO SAY `STACK_SAVEAREA_MODE' WAS HANDLED HERE, AND IT
   WAS NEVER TRUE.  It read: "`STACK_SAVEAREA_MODE' above expands to `Pmode'
   for a base that defines no such macro, and is defined EARLIER in this file,
   so it picks this up by ordinary macro expansion".  There was no `#undef' and
   no `#define' for that name anywhere in this file.  The sentence describes
   `defaults.h:1493's `#ifndef' fallback, which is DEAD in every shared
   translation unit because `config/i386/i386.h:2011' defines the name first --
   the `REGMODE_NATURAL_SIZE' / `EPILOGUE_USES' trap, third instance.

   It is kept here rather than quietly deleted because it is the reason the
   defect survived two boards: a comment reasoning correctly about a fallback
   reads as evidence that someone checked whether the fallback runs.  It cost
   71 FAIL rows over six back ends.  The real redirect is below.  */
#undef Pmode
#define Pmode (mt_pmode ())

/* `STACK_SAVEAREA_MODE (LEVEL)' -- the mode of the object `emit_stack_save'
   writes and `emit_stack_restore' reads.  See `target-frame.h' for the two
   insn dumps, for the ten-target measurement showing that shared code read
   only `TImode' and `DImode' and that NEITHER group got its own answer, and
   for why `TImode' on avr is the arm that proves the value is i386's rather
   than `defaults.h's.

   IT MUST FOLLOW THE `Pmode' REDIRECT ABOVE, for the reason the paragraph
   there gives about `FUNCTION_MODE': forty back ends take `defaults.h's
   `Pmode' fallback, and the per-base thunk expands it in the base's own
   translation unit where `Pmode' is still the real macro.

   `#undef' FIRST.  As with `FUNCTION_MODE', the absence of a live fallback in
   this file is not the same question as "not yet defined": i386's has already
   been read by this point in every shared TU, which is the entire bug.  */
#undef STACK_SAVEAREA_MODE
#define STACK_SAVEAREA_MODE(LEVEL) (mt_stack_savearea_mode ((int) (LEVEL)))

/* `FUNCTION_MODE' -- the mode of the MEM a call jumps through.  QImode for
   i386, `Pmode' for aarch64, and the diagnosed cause of the `extract_insn,
   recog.cc:2890' wall: `calls.cc:415' built every target's call as a `mem:QI'
   while all four of aarch64's call patterns match `(call (mem:DI ...))'.

   IT MUST FOLLOW THE `Pmode' REDIRECT ABOVE, and that is not a matter of
   tidiness.  Eight back ends define `FUNCTION_MODE' as `Pmode' outright; the
   per-base thunk expands it in the base's own translation unit where `Pmode'
   is still the real macro, but any shared spelling that reached this
   definition would want the redirected `Pmode', so the two are ordered the
   way `STACK_SAVEAREA_MODE' above is ordered against `Pmode'.

   `#undef' FIRST, AND THE FIRST DRAFT DID NOT.  Unlike the names above there
   is no defaults.h fallback for `FUNCTION_MODE' -- only `config/' defines it
   -- which reads as "there is nothing here to displace".  There is: the
   PRIMARY's `config/i386/i386.h:2028' has already been read by this point in
   every shared translation unit, which is the entire bug.  Without the
   `#undef' the compiler said so, `"FUNCTION_MODE" redefined', ~500 times, and
   the redirect still won -- so the evidence was a warning count and not a
   wrong answer.  Recorded because "no fallback in this file" is not the same
   question as "not yet defined".  */
#undef FUNCTION_MODE
#define FUNCTION_MODE (mt_function_mode ())

/* ------------------------------------------------------------------------
   THE DWARF REGISTER NUMBERING.  See target-frame.h for the gdb reading --
   `update_row_reg_save (... column=4294967294 ...)', which is
   `IGNORED_DWARF_REGNUM' read out of i386's map at one of its indices 16..19
   while the register being asked about was one of aarch64's x16..x19 -- and
   for the half of the brief's diagnosis (`TARGET_64BIT' silently selecting the
   32-bit map) that MEASURED FALSE: `ix86_isa_flags' is `Init'ed to
   `TARGET_64BIT_DEFAULT', which biarch64.h makes 64-bit already.

   ALL THREE MOVE TOGETHER.  `DWARF_FRAME_REGISTERS' is the BOUND that
   dwarf2cfi.cc:302 checks the other two against; redirecting the numbering
   without the bound would leave aarch64's correct 0..96 measured against
   i386's 17 and silently drop every register above 16 -- a quieter version of
   the bug, produced by the fix.  That is the closure failure PRINCIPLES
   section 4 names.

   `DWARF_FRAME_REGNUM' IS REDIRECTED IN ITS OWN RIGHT even though defaults.h
   above derives it from `DEBUGGER_REGNO'.  That derivation is a `#ifndef'
   answered by the PRIMARY's headers; cygming defines the two differently and
   aarch64 defines them the same, and only the base's own translation unit can
   say which.  Deriving it here would bake i386-on-linux's answer into all 48.

   NOT `#ifdef'-BREAKING: except.cc:2193 spells `#ifdef DWARF_FRAME_REGNUM' and
   both names remain defined, so that guard takes the same branch as today and
   both of its arms now call the SELECTED back end.  */
/* ------------------------------------------------------------------------
   THE TWO CFA-AT-ENTRY OFFSETS.  See target-frame.h for the gdb reading that
   named them -- aarch64 got 16 and 8 where its own headers say 0 and 0, and
   the 16 is `2 * UNITS_PER_WORD' because i386's macro reads
   `cfun->machine->func_type' out of AARCH64's `machine_function' object.

   BOTH, BECAUSE DISAGREEMENT IS WHAT EMITS THE DIRECTIVE.  dwarf2cfi.cc:2766
   emits the entry note only when the two differ, so redirecting one of them
   leaves the note being emitted with a different wrong number.

   `INCOMING_FRAME_SP_OFFSET' IS `#undef'-THEN-DEFINE FROM A DEFINITION THIS
   FILE MADE ABOVE (:1231), which is what made the leak transitive:
   `ARG_POINTER_CFA_OFFSET' at :1219 is defined here too, and neither name
   looks target-specific where it is written.

   `DEFAULT_INCOMING_FRAME_SP_OFFSET' IS DEFINED HERE RATHER THAN LEFT TO
   dwarf2cfi.cc:56's `#ifndef' fallback.  That fallback is an existence
   question -- "did this back end define its own?" -- and in shared code it
   was answered by whichever base compiled dwarf2cfi.cc.  Only two back ends
   in the tree define it (i386 and stormy16), so the fallback taken there is
   i386-on-linux's.  It IS `#undef'd first, and the first draft of this block
   reasoned that it need not be, on the grounds that dwarf2cfi.cc's `#ifndef'
   is the only other definition and sits BELOW this header.  That reasoning
   missed the one that matters: i386.h:2183 defines it, and the primary's
   tm.h has already been read here.  The compiler said so.

   SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE LANDING.  Outside `config/'
   and `testsuite/' the two have six use sites between them -- dwarf2cfi.cc
   :2767, :2771, :3266 and var-tracking.cc:832, :834, :10101 -- and every one
   is an ordinary run-time expression: no `#if', no case label, no array
   bound, no static initialiser.  The one `#ifndef' is dwarf2cfi.cc:56, which
   this block deliberately turns false.  */
#undef INCOMING_FRAME_SP_OFFSET
#define INCOMING_FRAME_SP_OFFSET (mt_incoming_frame_sp_offset ())
#undef DEFAULT_INCOMING_FRAME_SP_OFFSET
#define DEFAULT_INCOMING_FRAME_SP_OFFSET (mt_default_incoming_frame_sp_offset ())

/* ------------------------------------------------------------------------
   `ACCUMULATE_OUTGOING_ARGS' -- THE OTHER READ OF `cfun->machine' THAT SHARED
   CODE CAN REACH, and after this the last one.  #131 closed
   `INCOMING_FRAME_SP_OFFSET' (i386.h:2177) and recorded i386.h:1650 as an
   untouched sibling reading the same bitfield; this is that sibling.  The
   full enumeration behind "the last one" is `scratchpad/t132-sweep.sh': of
   the eleven macros i386.h defines whose bodies reach `cfun->machine', these
   two are the only names spelled anywhere outside `config/'.  The other nine
   (`ix86_stack_locals', `ix86_varargs_gpr_size', `ix86_varargs_fpr_size',
   `ix86_optimize_mode_switching', `ix86_pc_thunk_call_expanded',
   `ix86_tls_descriptor_calls_expanded_in_cfun', `ix86_static_chain_on_stack',
   `ix86_red_zone_used', `TARGET_INDIRECT_BRANCH_REGISTER') are spelled only
   inside `config/i386/', where `cfun->machine' does mean i386's struct.  A
   checked-and-clean family is a result, so they are named here rather than
   passed over in silence.

   THE MISREAD IS BROADER HERE THAN AT :2177.  That one is
   `func_type == TYPE_EXCEPTION', so exactly one of the eight bit patterns
   gives the wrong branch.  This one is `func_type != TYPE_NORMAL', so seven
   of the eight do.  #131 measured aarch64's bits reading 3.

   `#undef' FIRST, and here it is not merely hygiene: this file DEFINES the
   name itself at :902 (`#ifndef ACCUMULATE_OUTGOING_ARGS' -> 0), so without
   the `#undef' the redirect below is a redefinition of a macro this same
   header already wrote, on top of i386.h:1647 which tm.h read earlier still.
   #131 paid 495 warnings to learn that "no fallback in this file" and "not
   yet defined" are different questions; here there IS a fallback in this
   file.

   NOT `#ifdef'-BREAKING AND NOT CONSTANT-EXPRESSION-BREAKING.  Swept over all
   of `gcc/' outside `config/' and `testsuite/' (`scratchpad/t132-sites.sh'):
   ~40 use sites across calls.cc, expr.cc, function.cc, dce.cc, cselib.cc,
   builtins.cc, combine.cc, cfgcleanup.cc, combine-stack-adj.cc,
   var-tracking.cc and targhooks.cc, and every one is an ordinary run-time
   expression.  The only preprocessor occurrence in the tree is the `#ifndef'
   at :901, which is this file's own guard and is a definition, not a use.
   That distinction is what separates this macro from `FRAME_POINTER_CFA_
   OFFSET' below, which is `#ifdef'-tested at six shared sites and therefore
   cannot become a call at all.

   `function.cc:1423' and `:1430' USE IT INSIDE A MACRO BODY
   (`STACK_DYNAMIC_OFFSET'), which is still an ordinary run-time expression at
   every expansion of that macro -- checked, because a macro-in-a-macro is the
   shape that looks like a constant context and is not.  */
#undef ACCUMULATE_OUTGOING_ARGS
#define ACCUMULATE_OUTGOING_ARGS (mt_accumulate_outgoing_args ())

/* `PUSH_ARGS_REVERSED' -- the cheapest member of the `PUSH_ROUNDING' closure,
   and the one whose consequence is largest per line: its only shared use is
   `gimplify.cc:4791-4793', three run-time expressions in one `for' header
   that decide the order EVERY call's arguments are gimplified in.  i386
   defines it to `1', aarch64 does not, so that order was the primary's for
   every target.

   THE `#undef' IS LOAD-BEARING AND IS NOT TIDINESS.  This file has already
   defined the name a thousand lines above (`:915-928') -- either from the
   `PUSH_ROUNDING' ladder or from the `0' fallback -- using the PRIMARY's
   `PUSH_ROUNDING', `STACK_GROWS_DOWNWARD' and `ARGS_GROW_DOWNWARD'.  Omitting
   the `#undef' would leave that definition in force with `rc' still 0; the
   only signal would be a warning count, which is exactly how the
   `FUNCTION_MODE' near-miss went unnoticed.

   NO PREPROCESSOR USE ANYWHERE.  Swept over all of `gcc/' outside `config/'
   and `testsuite/': the only `#ifndef' occurrences are this file's own two
   guards, which are definitions rather than uses, and the two mentions in
   `cp/cp-tree.h' are in COMMENTS -- prose saying that certain lists are built
   in source order "regardless of PUSH_ARGS_REVERSED".  That is what makes it
   SHAPE 1 in the classification below where `PUSH_ROUNDING' itself is not.  */
#undef PUSH_ARGS_REVERSED
#define PUSH_ARGS_REVERSED (mt_push_args_reversed ())

/* `REG_PARM_STACK_SPACE' -- UNDEFINED FOR SHARED CODE, NOT REDIRECTED, and
   the difference is the point.  The name was `#ifdef'-tested at twelve shared
   sites (eleven in calls.cc, one `#if defined' in expr.cc); defining it to a
   call would have made every one of those guards TRUE for every target, which
   is the `#if HAVE_ATTR_length' failure recorded above running the other way.
   #135 replaced the guards with `mt_has_reg_parm_stack_space ()' and the two
   value uses with `mt_reg_parm_stack_space (...)', so nothing shared spells
   the macro any more -- and this `#undef' is what makes a future spelling
   fail to compile instead of quietly picking up i386's.

   AN `#undef' WITH NO `#define' IS A WEAKER GUARANTEE THAN A REDIRECT AND IS
   RECORDED AS SUCH: a re-introduced `REG_PARM_STACK_SPACE (x)' fails by name,
   but a re-introduced `#ifdef REG_PARM_STACK_SPACE' silently reads FALSE for
   every target.  That is strictly better than today (it reads the PRIMARY's
   answer for every target) and it is not the same as impossible.  The same
   caveat applies to every macro this project retires by undefining rather
   than by redirecting.  */
#undef REG_PARM_STACK_SPACE

/* `PUSH_ROUNDING' -- ALL 19 PREPROCESSOR SITES AND ALL 12 VALUE SITES IN
   TARGET-INDEPENDENT CODE ARE CONVERTED (#135), BUT THE NAME CANNOT BE
   `#undef'ED HERE, AND THE ATTEMPT IS THE FINDING.

   Undefining it builds `libbackend' clean and then fails in
   `insn-emit-1.cc' / `insn-emit-5.cc' with

       config/i386/mmx.md:430:27: error: PUSH_ROUNDING was not declared
       config/i386/i386.md:2221, :2313, :3884: likewise

   -- fifteen errors from FOUR i386 `.md' files.  Those are `define_split'
   preparation statements (`operands[2] = GEN_INT (-PUSH_ROUNDING (...))'),
   i.e. BACK-END code, but the `insn-emit-*.o' family is the un-namespaced one:
   it is compiled ONCE, shared, WITHOUT `MULTI_TARGET_TARGETM_BASE', with every
   configured back end's patterns in it.  So a back end's own macro use lands
   in a translation unit this file has classified as target-independent.

   That is a pre-existing wall (the `insn-emit' family, whose forwarder scheme
   decides `gen_movxf' by implication and needs the user's ruling), and it is
   NOT this task's to fix -- but it is worth stating precisely, because it is
   a shape no earlier conversion met: every macro retired so far was spelled
   only by files under `gcc/' itself.  `PUSH_ROUNDING' is the first whose CONSUMERS are done
   while its name must stay defined for a supply-side file that is compiled as
   if it were shared.

   `REG_PARM_STACK_SPACE' above CAN be `#undef'ed, and the difference is
   measured rather than assumed: no `.md' file spells it, so the same build
   that produced the errors above accepted that `#undef'.

   Consequence recorded honestly: shared code no longer READS this macro, but
   the name is still in scope in every shared translation unit with the
   primary's definition, so a re-introduced `#ifdef PUSH_ROUNDING' in
   shared code would silently be TRUE for every target -- the exact bug this
   family had.  The protection here is the conversion, not a diagnostic.  */

/* ------------------------------------------------------------------------
   THE NEIGHBOURS, CHECKED AND DELIBERATELY NOT REDIRECTED.  A family checked
   and judged fine is a result; silence about it is not.  All three verdicts
   are `scratchpad/t132-sites.sh' and `t132-closure.sh'.

   `ARG_POINTER_CFA_OFFSET' (:1219) -- CORRECT TODAY, AND CORRECT FOR A REASON
   THAT DOES NOT SCALE.  Neither i386 nor aarch64 defines it, so both reach
   this file's `FIRST_PARM_OFFSET (FNDECL) + crtl->args.pretend_args_size',
   and `FIRST_PARM_OFFSET' is the literal 0 in BOTH (i386.h:1661,
   aarch64.h:1062).  So the leak is real and its value happens to agree.  That
   is the wrong-reason green PRINCIPLES names: nine back ends define
   `ARG_POINTER_CFA_OFFSET' directly (rx 4, avr -1, pru non-constant, six
   others 0) and `FIRST_PARM_OFFSET' varies more widely still, so this becomes
   a live leak the moment a third base joins.  Not redirected because doing so
   for a pair that agrees banks no evidence and cannot be measured apart from
   the status quo -- it needs a base that disagrees, which this configuration
   does not have.  Recorded as UNMEASURABLE WITH THIS PAIR, not as clean.

   `FRAME_POINTER_CFA_OFFSET' -- CANNOT BECOME A CALL, and here position of
   use decides shape.  It is `#ifdef'-tested at six shared sites (function.cc
   :1466, :1967; var-tracking.cc:9990, :10093, :10146, :10166, :10202;
   dwarf2out.cc:21620), so a runtime value is impossible: defining the name to
   a call would make every one of those guards TRUE for every target, which is
   the `#if HAVE_ATTR_length' failure in reverse.  Only nvptx, vax and pa
   define it; neither configured base does, so all six guards are FALSE and
   that is each base's own answer.  What this needs is a build-time union
   check -- "no configured base may define FRAME_POINTER_CFA_OFFSET unless
   they all agree" -- not a conversion.  Not written here; it belongs with the
   other union-list checks.

   dwarf2out.cc:21505-21509 -- THE ONE PLACE SHARED CODE DEREFERENCES
   `cfun->machine' DIRECTLY, and it is not fixable by any redirect.  It reads
   `cfun->machine->fs.cfa_reg', `.fs.fp_valid', `.fs.fp_offset' and
   `.fs.sp_offset' -- i386's `machine_frame_state', by field name, from a
   shared translation unit.  It is inside `#ifdef CODEVIEW_DEBUGGING_INFO',
   which only config/i386/cygming.h defines, so it is DEAD in this
   configuration and in any configuration whose bases exclude cygming.  It is
   not dead in general: with cygming among the bases, that block compiles and
   then reads `fs' out of whichever base is selected.  There is no macro to
   redirect -- shared code names a back-end-private struct field -- so the fix
   is a target hook, i.e. a design decision, and it is recorded rather than
   taken.

   ------------------------------------------------------------------------
   `PUSH_ROUNDING' -- CLASSIFIED BY #133, CONVERTED IN FULL BY #135.  All 19
   preprocessor sites and all 12 value sites are now run-time; the shapes
   below are kept because each records WHY its site converted the way it did,
   and two of them are not substitutions.  What #135 added on top of the
   classification is at the end of this block.

   i386 defines it (i386.h:1621, `ix86_push_rounding'), aarch64 does not.
   SEVEN back ends define it, not the thirteen a grep for the name suggests:
   `#define PUSH_ROUNDING' at column 0 appears eight times and sh's is inside
   `#if 0', while arm's, alpha's, pa's, rs6000's, iq2000's and one of avr's
   are in comments.  Five of the seven are function calls taking and
   returning `poly_int64' (i386, m68k, h8300, pdp11, stormy16) and two are
   the identity `(BYTES)' (vax, avr) -- which is what makes the signature
   below fit every live definition -- so every `#ifdef PUSH_ROUNDING' below is answered by i386 for
   every target, and `calls.o' carries `U ix86_push_rounding(poly_int<2u,
   long>)' as well, i.e. it leaks as a VALUE and as an EXISTENCE question
   both.  The classification is written down BEFORE any conversion because a
   macro on a `#if' line cannot always become a runtime value, and two
   `#if HAVE_ATTR_length' gates once would have evaluated a call-valued macro
   to 0 and turned both passes off for every target.

   SHAPE 1 -- ordinary statements under the guard.  `#ifdef' becomes
   `if (mt_has_push_rounding ())', `PUSH_ROUNDING (x)' becomes
   `mt_push_rounding (x)'.  Mechanical.
       calls.cc:5181   function.cc:4151  lra-eliminations.cc:798
       reload1.cc:3030 recog.cc:1835     rtlanal.cc:4914
       expr.cc:4300    expr.cc:4354      expr.cc:1639     cse.cc:5628
       targhooks.cc:912
   Note targhooks.cc:912 is `return !ACCUMULATE_OUTGOING_ARGS;' under the
   guard, i.e. `default_push_argument' -- the DEFAULT OF AN EXISTING TARGET
   HOOK.  Several SHAPE-1 sites already test `targetm.calls.push_argument (0)'
   INSIDE the `#ifdef', so for them the existence question is already answered
   at run time and the `#ifdef' is only a compile-time short circuit on top of
   it.  Converting targhooks.cc:912 alone would close more of this family than
   its single line suggests.

   SHAPE 2 -- `#ifndef' over ordinary statements.  Becomes
   `if (!mt_has_push_rounding ())'.
       expr.cc:1679             (a `gcc_unreachable' precondition)
       combine-stack-adj.cc:841 (the pass gate)
   combine-stack-adj.cc:841 IS COMPILED OUT FOR EVERY TARGET TODAY, because
   i386 defines the macro.  That is a measured finding (#132), not a
   measurement failure, and it is why `combine-stack-adj.o' binds
   `mt_accumulate_outgoing_args' zero times.  Converting it TURNS A GATE ON
   for the 38 back ends that define no `PUSH_ROUNDING', so it is the one site
   in this family whose conversion changes pass behaviour rather than a value,
   and it wants its own before/after.  IT GOT ONE; see the end of this block.

   SHAPE 3 -- guard over a DECLARATION or DEFINITION.  Cannot become an `if',
   but needs no flag either: drop the guard and declare/define
   unconditionally, since the bodies convert under SHAPE 1.
       expr.cc:108   (forward declaration of `emit_single_push_insn')
       expr.cc:5149  (definitions of `emit_single_push_insn_1' and
                      `emit_single_push_insn')

   SHAPE 4 -- guard over a MACRO definition.  Fold the existence test into the
   macro body, which is already a run-time expression.
       expr.cc:1595   `PUSHG_P' ->  `(mt_has_push_rounding () && (to) == 0)'
       defaults.h:916 `PUSH_ARGS_REVERSED' -- see the separate note below.

   SHAPE 5 -- `#ifdef' whose `#endif' sits between an `if' and its `else'.
   Convertible, but it is a RESTRUCTURE of the if/else, not a substitution,
   and reviewing it as if it were one is how a dropped `else' arm gets missed.
       expr.cc:5384/:5424   expr.cc:5620/:5624

   AND ONE TYPE TRAP THAT MAKES THIS NON-MECHANICAL.  recog.cc:1836 spells
   `PUSH_ROUNDING (MACRO_INT (rounded_size))', where `MACRO_INT' is
   `.to_constant ()` when `NUM_POLY_INT_COEFFS == 1' and the IDENTITY
   otherwise -- this line said `> 1' and had the polarity backwards, which
   matters because the constant is 2 build-wide on this branch, so the
   wrapper is currently the identity everywhere and protects nobody
   (measured with `-E -dM' in all four contexts; scratchpad/t145-*).
   `poly-int-types.h:89' is the authority.  That wrapper exists
   because some back ends' macros are not poly-safe.  A single
   `poly_int64 mt_push_rounding (poly_int64)' makes the wrapper unnecessary at
   the SHARED sites, but the PER-BASE thunk must keep it for those back ends
   -- so the signature is a decision, not a transcription, and it should be
   made once for all 12 value sites rather than site by site.
   DECIDED THAT WAY IN #135, with the argument written out in target-frame.h.
   `function.cc:4151' is the one value site that stays non-poly on purpose:
   it feeds `size_int' from `TREE_INT_CST_LOW', so it was never poly and the
   `.to_constant ()' is at the call rather than in the thunk.

   ------------------------------------------------------------------------
   WHAT #135 ADDED TO THE CLASSIFICATION.

   THE PASS GATE, MEASURED BOTH WAYS IN ONE BUILD DIR
   (`scratchpad/t135-gate.sh' + `t135-gate-inject.sh'; the reading is
   `-fdump-rtl-csa', i.e. the COMPILER'S OWN report that the pass ran, not an
   inference from the assembly):

                       OFF (pre-#135)          ON (#135)
       aarch64         csa dump, 273 lines     NO csa dump        CHANGED
       x86_64          csa dump, 233 lines     csa dump, 233      unchanged

   and the emitted assembly is BYTE-IDENTICAL on both bases either way
   (aarch64 `be8a7f14b637', x86_64 `0b156589647b').  BOTH HALVES OF THAT ARE
   THE RESULT.  The gate really did change -- aarch64 stops running
   `combine_stack_adjustments', which is what an aarch64-only GCC does, since
   `#ifndef PUSH_ROUNDING' is TRUE there -- so the conversion RESTORES
   upstream behaviour for the 38 back ends that had been running a pass their
   own headers gate off.  And the codegen for this input does not move, so no
   claim is made that it produces different code; on an input where the pass
   found nothing to combine, "the pass ran" and "the pass did not run" have
   the same output, and reporting the dump difference as a codegen difference
   would be exactly the overclaim this project keeps finding.

   AND THE `#undef' THAT COULD NOT BE DONE; see the note beside the
   `REG_PARM_STACK_SPACE' `#undef' above.  i386's `.md' files spell
   `PUSH_ROUNDING' in `define_split' preparation statements, and those land in
   the SHARED `insn-emit-*.o'.

   THE OTHER TWO NAMES IN #134'S LADDER -- `STACK_GROWS_DOWNWARD' AND
   `ARGS_GROW_DOWNWARD' -- ARE STILL UNCONVERTED, AND THEY CANNOT BE
   CONVERTED THE WAY `PUSH_ROUNDING' WAS.  Reported rather than taken:

     * Both are `#if'-TESTED, not `#ifdef'-tested, at thirteen shared sites
       (explow.cc:1786; builtins.cc:5477, :5610, :5700, :5735; recog.cc:48;
       rtlanal.cc:372, :582, :586, :594, :606, :610, :618, :629) -- and
       `rtlanal.cc' tests them in NESTED pairs.  A call-valued macro in a
       `#if' evaluates to 0, which is the `#if HAVE_ATTR_length' failure
       this file already records; `FRAME_POINTER_CFA_OFFSET' above is the
       same verdict.  So these need either a union check or a real
       restructure of thirteen preprocessor sites, not a redirect.
     * They are genuinely per-base: 46 back-end headers define
       `STACK_GROWS_DOWNWARD 1' and the rest leave `defaults.h''s 0 (pa is
       explicit about it, with the definition commented out); exactly three
       define `ARGS_GROW_DOWNWARD 1' (pa, gcn, stormy16).
     * BUT NOT ON THIS PAIR.  i386 and aarch64 both have
       `STACK_GROWS_DOWNWARD 1' and neither has `ARGS_GROW_DOWNWARD', so
       every one of the thirteen sites has the same answer for both, and no
       arm built here could tell a converted version from the status quo.
       UNMEASURABLE WITH THIS PAIR, exactly like `ARG_POINTER_CFA_OFFSET' --
       recorded as that, and not as clean.
     * ONE MIXED SPELLING, CHECKED AND FOUND HARMLESS TODAY, WHICH IS WORTH
       STATING BECAUSE THE OBVIOUS READING IS THAT IT IS A BUG.
       `defaults.h:533' (`DWARF_CIE_DATA_ALIGNMENT') tests
       `#ifdef STACK_GROWS_DOWNWARD' while the thirteen sites above test
       `#if'.  An `#ifdef' would be TRUE for a back end that defined the name
       to 0 -- but no back end does: all 46 definitions are `1' and pa's is
       commented out entirely, measured rather than assumed.  It is also
       ABOVE this file's own `#ifndef ... 0' fallback at :1328, so the two
       spellings do not currently disagree anywhere.  Fragile, not wrong.

   `PUSH_ARGS_REVERSED' -- FOUND IN THIS CLOSURE, AND IT IS A LEAK IN ITS OWN
   RIGHT.  i386.h:1658 defines it to 1; aarch64 does not; bpf and nvptx do.
   Its shared use is gimplify.cc:4791-4793, three ordinary run-time
   expressions in one `for' header -- so **argument gimplification runs
   last-to-first for every target**, because the primary says so.  No
   preprocessor use anywhere, so it is SHAPE 1 with a one-file blast radius,
   and it is the cheapest item in this family.  CONVERTED BY #134 -- the
   redirect is above, next to `ACCUMULATE_OUTGOING_ARGS'.

   IT IS ALSO THE FIRST MEMBER OF THIS FAMILY WHOSE EVIDENCE IS BEHAVIOURAL.
   Everything else here was measured as a value or a bound symbol; argument
   evaluation order is neither.  On `int t (void) { return h (f (), g ()); }'
   at `-O0 -fno-inline', with the redirect injected off and back on in one
   build dir, aarch64 goes from `bl g; bl f' to `bl f; bl g' while x86_64's
   output is byte-identical -- and the aarch64 object assembles and
   disassembles under real aarch64 binutils with a correct CFA.
   `scratchpad/t134-order.sh'.

   `REG_PARM_STACK_SPACE' -- i386 defines it (i386.h:1672), aarch64 does not,
   13 back-end headers do.  Still leaking: `function.o' binds
   `U ix86_reg_parm_stack_space(tree_node const*)' even after #133, because
   function.cc:2327 spells `INCOMING_REG_PARM_STACK_SPACE' separately from the
   `STACK_DYNAMIC_OFFSET' ladder that #133 moved out.  That is PRINCIPLES'
   "one symbol can have several macro paths" measured again: closing the path
   you found does not close the symbol.  `INCOMING_REG_PARM_STACK_SPACE'
   itself is defined by exactly one back-end header (rs6000) and by neither
   base; it is derived from `REG_PARM_STACK_SPACE' at calls.cc and, until
   #134, at function.cc:1403 as well.

   #134 CLOSED THE function.cc PATH AND ONLY THAT ONE.  The derivation and the
   `#ifdef' both moved into `target-cumargs.cc'; `function.o' now binds
   `mt_incoming_reg_parm_stack_space' and binds `ix86_reg_parm_stack_space'
   ZERO times, where before it bound it once.  The per-base thunks diverge as
   they should -- i386's is a tail `jmp' to `ix86_reg_parm_stack_space'
   (R_X86_64_PLT32), aarch64's is `xor %eax,%eax; ret'.

   A VALUE ARM CANNOT DISTINGUISH THE TWO ON THIS PAIR, and saying so is the
   result.  `ix86_reg_parm_stack_space' returns 32 only for `TARGET_64BIT &&
   MS_ABI' and 0 otherwise, so the leaked answer for aarch64 was 0 -- the same
   number aarch64's own absence produces.  The bug was never the number; it
   was that the number came from `ix86_function_abi' being handed an aarch64
   `FUNCTION_DECL' and reading i386's option state about it.  Correct BY LUCK,
   which is the `Pmode' trap running the other way, and the reason the
   evidence here is the tail-jmp and the symbol count rather than a value.

   #135 CLOSED THE REMAINING TWO, and the enumeration is now complete:
     - `calls.cc' -- the ELEVEN `#ifdef' sites and TWO value sites.  CLOSED.
       Three of the eleven were guards over a DECLARATION or a DEFINITION
       (:174, :1096, :1194) and are simply dropped; two were guards over LOCAL
       VARIABLES (:2793, :4257), now declared unconditionally with
       `low_to_save'/`high_to_save' initialised, because with the guard gone
       the compiler can no longer see that they are written before read; four
       became `if (mt_has_reg_parm_stack_space () && ...)' or, where
       `save_area' already answers the question by being null, nothing at all;
       and the two value sites became `mt_reg_parm_stack_space (...)'.
     - `expr.cc:2192/:2198' -- CLOSED, and the `(void) fn;' that existed only
       to silence a set-but-not-used warning went with it, since `fn' is now
       used unconditionally further down the same function.
   `calls.o' and `expr.o' bind `ix86_reg_parm_stack_space' ZERO times where
   both bound it ONCE, measured in the same run in which `ix86_push_rounding'
   still scores 1 in seven objects -- so the zero is a finding and not a
   demangling failure (`scratchpad/t135-obj.sh', `index ($0, f)', nm
   non-vacuity floor of 117319 undefined lines).

   TWO SLOTS AND NOT ONE, which is the design decision in this conversion.
   `has_reg_parm_stack_space' answers what the `#ifdef's asked and
   `reg_parm_stack_space' answers what the two value uses asked, because
   "defined and yielding 0" and "not defined" are NOT the same state at every
   site: `save_fixed_argument_area' does `high = reg_parm_stack_space;
   if (ARGS_GROW_DOWNWARD) high += 1;', so on an args-grow-downward back end a
   zero value still inspects `stack_usage_map[0]' while the undefined case
   never calls the function.  Neither configured base grows args downward, so
   this pair could not have caught a collapse of the two; it was found by
   reading the callee.  See target-frame.h.

   THE THUNKS DIVERGE IN THE EXISTENCE ANSWER, WHICH IS THE PART THE VALUE
   CANNOT SHOW: i386's `mt_base_has_reg_parm_stack_space' is
   `mov $0x1,%eax; ret' and its value thunk is a `call' to
   `ix86_reg_parm_stack_space' (R_X86_64_PLT32); aarch64's are
   `mov $0x0,%eax; ret' and `mov $0x0,%eax; ret'.
     - `function.cc' -- CLOSED by #134; the name is now undefined there, so a
       future shared spelling fails by name.
     - `target-cumargs.cc:683-686, :745-748' -- the two per-base derivations.
       CORRECT BY CONSTRUCTION: that file is compiled once per back end with
       that back end's `tm.h'.  Judged fine, and stated rather than omitted.
     - `cse.cc:4263', `function.cc:2549/:4017/:4019', `function.h:574' --
       COMMENTS only.  Judged fine.
   So the symbol is closed in `function.o' and open in `calls.o' and
   `expr.o'.  Two paths were not all of them; there are four.  */

#undef DEBUGGER_REGNO
#define DEBUGGER_REGNO(REGNO) (mt_debugger_regno ((unsigned int) (REGNO)))
#undef DWARF_FRAME_REGNUM
#define DWARF_FRAME_REGNUM(REG) (mt_dwarf_frame_regnum ((unsigned int) (REG)))
#undef DWARF_FRAME_REGISTERS
#define DWARF_FRAME_REGISTERS (mt_dwarf_frame_registers ())
#undef DWARF_FRAME_RETURN_COLUMN
#define DWARF_FRAME_RETURN_COLUMN (mt_dwarf_frame_return_column ())

/* ------------------------------------------------------------------------
   THE FOUR POINTER REGNUMS AND THE TWO DERIVED PREDICATES -- MACRO-LEAK.md
   class (d), the fork #124 and #126 both stopped at.

   THE ICE THIS FIXES, in shared code, at alias.cc:3358:

       targetm.can_eliminate (FRAME_POINTER_REGNUM, STACK_POINTER_REGNUM)

   i386 supplies the two numbers (19 and 7) and the SELECTED back end supplies
   the hook, so `aarch64_can_eliminate' was asked about register 19 and its
   first statement asserts the FROM is one of aarch64's own 64 or 65.  That is
   `internal compiler error: in aarch64_can_eliminate, at aarch64.cc:14153' on
   `int g (int a) { return a + 1; }'.  ira.cc:2587 is the same call.

   ALL SIX MOVE TOGETHER.  `STACK_POINTER_REGNUM' was the one member of the set
   free of `#if' arithmetic and therefore the one a smaller change would have
   taken; that would have made `stack_pointer_rtx' correct while
   `hard_frame_pointer_rtx' kept i386's 6, and dwarf2cfi.cc:3250/3309 feed both
   of those rtxes to `DEBUGGER_REGNO' -- a half-right CFA, a QUIETER wrong
   answer than the one being fixed.

   WHAT HAD TO CHANGE FIRST, AND IT IS NOT IN THIS FILE.  A `#if' cannot call a
   function, and `enum global_rtl_index' in rtl.h used three of these names on
   `#if' lines to decide its own SHAPE.  Left alone, a call-valued regnum makes
   the preprocessor see undefined identifiers, evaluate `0 == 0' as TRUE, and
   alias `GR_ARG_POINTER' onto `GR_FRAME_POINTER' for every back end.  The enum
   now gives all three a distinct slot unconditionally and `init_emit_regs'
   performs the aliasing by storing one rtx OBJECT in two slots, which is what
   the invariant actually requires; rtl.h carries the argument and the
   guards measure it.  The other two `#if' users of these names -- emit-rtl.cc
   and dwarf2out.cc, both `#if !HARD_FRAME_POINTER_IS_ARG_POINTER' -- became
   run-time conjuncts of the expressions they guarded.

   `HARD_FRAME_POINTER_REGNUM' IS DEFINED HERE UNCONDITIONALLY, which also
   settles rtl.h's `#ifndef HARD_FRAME_POINTER_REGNUM' fallback: in shared code
   that `#ifndef' was answered by the PRIMARY's headers, so a back end that
   leaves it to rtl.h would have got i386's answer.  tm.h reaches every shared
   TU before rtl.h does, so this definition is the one in force there, and each
   base's own `#ifndef' outcome is recorded by its own thunk instead.

   NOT `#ifdef'-BREAKING: reginfo.cc:792 spells `#ifdef
   HARD_FRAME_POINTER_REGNUM' and the name stays defined, so that guard takes
   the branch it takes today and both of its arms now name the selected back
   end's register.  */
#undef STACK_POINTER_REGNUM
#define STACK_POINTER_REGNUM (mt_stack_pointer_regnum ())
#undef FRAME_POINTER_REGNUM
#define FRAME_POINTER_REGNUM (mt_frame_pointer_regnum ())
#undef HARD_FRAME_POINTER_REGNUM
#define HARD_FRAME_POINTER_REGNUM (mt_hard_frame_pointer_regnum ())
#undef ARG_POINTER_REGNUM
#define ARG_POINTER_REGNUM (mt_arg_pointer_regnum ())
#undef HARD_FRAME_POINTER_IS_FRAME_POINTER
#define HARD_FRAME_POINTER_IS_FRAME_POINTER \
  (mt_hard_frame_pointer_is_frame_pointer ())
#undef HARD_FRAME_POINTER_IS_ARG_POINTER
#define HARD_FRAME_POINTER_IS_ARG_POINTER \
  (mt_hard_frame_pointer_is_arg_pointer ())

/* ------------------------------------------------------------------------
   THE MOVE/CLEAR FAMILY.  See target-frame.h for the gdb-confirmed fault
   that starts this (`ix86_cost' null, `si_addr == 0xf4'), for why all seven
   move together rather than just the one that crashes, and for why
   `MAX_MOVE_MAX' is deliberately absent from the list.

   Note that four of these seven are being `#undef'd from a definition made
   by THIS FILE a thousand lines above -- `MOVE_MAX_PIECES' at :1098,
   `STORE_MAX_PIECES' at :1107, `COMPARE_MAX_PIECES' at :1112 and
   `SET_RATIO' at :1472 -- and those definitions are the ones that make the
   leak transitive.  `MOVE_MAX_PIECES' looks target-neutral where it is
   written; it is `MOVE_MAX', which is i386's AVX width.

   SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE LANDING
   (scratchpad/t113-sites.sh lists every shared spelling of all eight names).
   Outside `config/' the seven appear only in ordinary run-time expressions:
   loop bounds in `caller-save.cc', comparisons in `expr.cc',
   `gimple-fold.cc', `gimple-ssa-store-merging.cc', `tree-inline.cc' and
   `tree-sra.cc', and arguments in `targhooks.cc'.  The one `#ifdef
   MOVE_RATIO' (targhooks.cc:2261) is unaffected -- the name stays defined.
   `MAX_MOVE_MAX' is the single constant-expression user and is the single
   name not converted; that is not a coincidence, it is the reason.  */
#undef MOVE_MAX
#define MOVE_MAX (mt_move_max ())
#undef MOVE_MAX_PIECES
#define MOVE_MAX_PIECES (mt_move_max_pieces ())
#undef STORE_MAX_PIECES
#define STORE_MAX_PIECES (mt_store_max_pieces ())
#undef COMPARE_MAX_PIECES
#define COMPARE_MAX_PIECES (mt_compare_max_pieces ())
#undef MOVE_RATIO
#define MOVE_RATIO(SPEED) (mt_move_ratio ((bool) (SPEED)))
#undef CLEAR_RATIO
#define CLEAR_RATIO(SPEED) (mt_clear_ratio ((bool) (SPEED)))
#undef SET_RATIO
#define SET_RATIO(SPEED) (mt_set_ratio ((bool) (SPEED)))

/* ------------------------------------------------------------------------
   THE JUMP-TABLE SHAPE AND THE REGISTER-GRANULARITY ANSWER.  Two names, two
   ICE columns in the aarch64 testsuite, and the same disguise: one macro,
   several authorities, no diagnostic.  See target-frame.h for both field
   comments and for the position sweeps.

   `REGMODE_NATURAL_SIZE' IS NOT A NEW CONVERSION SO MUCH AS A CORRECTION TO
   ONE THIS FILE ALREADY CLAIMED.  The `MIN_UNITS_PER_WORD' closure note below
   lists `regs.h:31 REGMODE_NATURAL_SIZE (UNITS_PER_WORD)' among the eleven
   names that inherit the option-state redirect by ordinary macro expansion.
   That inheritance requires regs.h's `#ifndef' to be TAKEN, and in a shared
   translation unit it is not: the primary's `i386.h:1112' defines the name as
   `ix86_regmode_natural_size (MODE)' long before regs.h is read.  So the
   entry was true for a hypothetical base defining nothing and dead for the
   four back ends that define it -- i386, aarch64, riscv, sparc.  The
   `#undef' here is what makes it real, and it must come AFTER that block's
   `UNITS_PER_WORD' redirect has no further say in this name.  */
#undef CASE_VECTOR_PC_RELATIVE
#define CASE_VECTOR_PC_RELATIVE (mt_case_vector_pc_relative ())
#undef REGMODE_NATURAL_SIZE
#define REGMODE_NATURAL_SIZE(MODE) (mt_regmode_natural_size (MODE))

/* `CASE_VECTOR_MODE' completes the jump-table pair above, and
   `INCOMING_RETURN_ADDR_RTX' is the authority behind the last standing
   aarch64 ICE column.  See target-frame.h for both field comments.

   `CASE_VECTOR_MODE' WAS CORRECT BY LUCK AND ONLY WITHOUT PIC.  aarch64's is
   `Pmode'; i386's (`i386.h:1920') is
   `(!TARGET_LP64 || (flag_pic && ix86_cmodel != CM_LARGE_PIC)
     ? SImode : DImode)'.  Both are DImode when `!flag_pic', which is why the
   two-base build agreed; under `-fpic' i386's becomes SImode and aarch64 got
   4-byte jump-table elements from a back end that requires `Pmode'.
   `target-cdata.h:166' defers this name to the mode-numbering work, and that
   deferral is about a CACHED FIELD -- the mode vocabulary is unioned, so a
   mode returned by a CALL crosses no numbering boundary, exactly as `Pmode'
   and `FUNCTION_MODE' already do.

   `INCOMING_RETURN_ADDR_RTX' is a KIND divergence and not a value one: i386
   says the return address is in memory at the stack pointer, aarch64 says it
   is in x30.  `dwarf2cfi.cc:3283' built every target's CIE from i386's
   answer, and `maybe_record_trace_start' then found the rows inconsistent.  */
#undef CASE_VECTOR_MODE
#define CASE_VECTOR_MODE (mt_case_vector_mode ())
#undef INCOMING_RETURN_ADDR_RTX
#define INCOMING_RETURN_ADDR_RTX (mt_incoming_return_addr_rtx ())

/* ------------------------------------------------------------------------
   THE OPTION-STATE FAMILY -- `UNITS_PER_WORD', `POINTER_SIZE',
   `BIGGEST_ALIGNMENT'.  See target-frame.h for the bodies, for why all three
   are calls rather than cached values, and for the closure note.

   THIS BLOCK MUST BE LAST IN THE FILE, and that is a correctness constraint
   rather than tidiness -- the same one that orders `FUNCTION_MODE' after
   `Pmode' above, but with a much larger blast radius.  Eleven definitions
   EARLIER in this file, and one in `regs.h', spell these three names in their
   BODIES:

       :534/:536  DWARF_CIE_DATA_ALIGNMENT      (UNITS_PER_WORD)
       :582       DWARF2_ADDR_SIZE              (POINTER_SIZE)
       :603       BITS_PER_WORD                 (UNITS_PER_WORD)
       :616       SHORT_TYPE_SIZE               (UNITS_PER_WORD)
       :864       POINTER_SIZE                  (BITS_PER_WORD)
       :867       POINTER_SIZE_UNITS            (POINTER_SIZE)
       :957       TARGET_VTABLE_ENTRY_ALIGN     (POINTER_SIZE)
       :1120      MIN_UNITS_PER_WORD            (UNITS_PER_WORD)
       :1206      MAX_OFILE_ALIGNMENT           (BIGGEST_ALIGNMENT)
       :1278      ATTRIBUTE_ALIGNED_VALUE       (BIGGEST_ALIGNMENT)
       :1835      STACK_CHECK_FIXED_FRAME_SIZE  (UNITS_PER_WORD)
       regs.h:31  REGMODE_NATURAL_SIZE          (UNITS_PER_WORD)
                    -- LISTED HERE AND NEVER TRUE.  regs.h's `#ifndef' is
                    not taken in a shared TU; i386.h:1112 defined the name
                    first.  Redirected on its own above.

   A macro BODY is expanded at the use site, not where it is written, so each
   of those picks up the redirect automatically and correctly -- 354 further
   shared sites for `BITS_PER_WORD' alone, 181 for `DWARF2_ADDR_SIZE'.  Put
   this block ABOVE them and the `#ifndef's at :602, :863 and :1119 would test
   a name this block had already redefined, and :864's `POINTER_SIZE
   BITS_PER_WORD' would be a redefinition of the call rather than of the
   macro: the fallback ladder would answer a different question than the one
   it is written to answer.  Being last is what makes the inheritance work.

   `MIN_UNITS_PER_WORD' IS THE ONE MEMBER OF THAT LIST THAT MUST NOT BECOME A
   CALL -- `caller-save.cc:55' and `reload.h:179' use it as an ARRAY BOUND.
   It does not become one today, because the primary defines it as a literal
   4 rather than leaving it to :1120; `target-cumargs-select.cc' carries a
   `static_assert' so the day that stops being true is a diagnostic naming the
   macro rather than a non-constant-bound error naming neither.  The INDEX
   side of that same array -- `MOVE_MAX / UNITS_PER_WORD' -- does become the
   selected base's here, and `mt_move_max''s guard was moved onto the computed
   index in the same change.  Converting this family and leaving that guard on
   the numerator would have been the "one member of a closure" failure.

   SWEPT FOR CONSTANT-EXPRESSION CONTEXTS BEFORE REDIRECTING, over the three
   names AND all twelve derived ones (scratchpad/t141-pos.sh, t141-const.sh):
   no `#if'/`#elif' line in shared code names any of them, no `case' label, no
   `static_assert', no enumerator, no namespace-scope initialiser, and no
   `#ifdef' outside the `#ifndef' fallbacks listed above -- which this block
   follows and therefore cannot disturb.  Every bracketed spelling is a
   subscript of a run-time array.  */
#undef UNITS_PER_WORD
#define UNITS_PER_WORD (mt_units_per_word ())
#undef POINTER_SIZE
#define POINTER_SIZE (mt_pointer_size ())
#undef BIGGEST_ALIGNMENT
#define BIGGEST_ALIGNMENT (mt_biggest_alignment ())
#endif

#endif /* ! GCC_MULTI_TARGET_MACROS_H */
