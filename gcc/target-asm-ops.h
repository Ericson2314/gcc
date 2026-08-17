/* Per-back-end assembler directive tables.
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

/* The POD half of targetm.asm_out -- GLOBAL_ASM_OP and the section-switching
   directives -- collected per back end.

   Those hooks are initialised by TARGET_INITIALIZER from macros in tm.h, and
   `struct gcc_target targetm' is defined in each back end's config/<cpu>/<cpu>.cc.
   Only the configured target's <cpu>.cc is compiled into the compiler, so
   targetm holds one target's directives and every other target reading them
   gets that target's answers.

   Compiling all 45 <cpu>.cc files is the eventual fix and needs the whole
   per-back-end insn-* pipeline behind it.  This is the cheap part of that:
   one small translation unit, compiled once per back end against that back
   end's tm-<base>.h -- the same step that already builds 45 <base>-common.o --
   holding just the values that are plain strings.  At startup the selected
   table is copied into targetm.asm_out, so every consumer keeps reading
   targetm and simply sees the right target's directives.  */

#ifndef GCC_TARGET_ASM_OPS_H
#define GCC_TARGET_ASM_OPS_H

/* Function pointers, not strings.  On some targets these directives depend on
   command-line options rather than on the target alone -- rx switches all of
   them plus GLOBAL_ASM_OP on -mas100-syntax, pdp11 on TARGET_DEC_ASM, arm's
   CTORS/DTORS on TARGET_AAPCS_BASED -- and mmix's DATA_SECTION_ASM_OP is a
   call into the back end.  None of those is a constant expression, so none can
   be stored in a table.  More importantly the value varies per COMPILATION,
   not per target, so a table keyed by target identity is the wrong shape for
   it however it is typed.  Evaluating a function at the point of use sees the
   options in force.  */
struct target_asm_ops
{
  const char *(*global_op) (void);
  const char *(*text_section_asm_op) (void);
  const char *(*data_section_asm_op) (void);
  const char *(*sdata_section_asm_op) (void);
  const char *(*readonly_data_section_asm_op) (void);
  const char *(*bss_section_asm_op) (void);
  const char *(*sbss_section_asm_op) (void);
  const char *(*ctors_section_asm_op) (void);
  const char *(*dtors_section_asm_op) (void);
  const char *(*init_section_asm_op) (void);

  /* ASM_OUTPUT_ALIGN (FILE, LOG) -- advance the location counter to a
     multiple of 2**LOG bytes.

     WHY IT IS HERE AND NOT LEFT ALONE.  It is a STATEMENT macro, not a
     string, and it is read from ~30 target-independent sites: `varasm.cc'
     (7), `dwarf2out.cc' (4), `dwarf2codeview.cc' (13), `final.cc' (3) and
     `vmsdbgout.cc'.  Shared code therefore emitted the PRIMARY's directive
     for every base, and the two spellings do not merely differ in whitespace
     -- they differ in what the operand MEANS:

       config/riscv/riscv.h:1122   "\t.align\t%d",  LOG
       config/i386/att.h:60        "\t.align %d",   1 << LOG

     riscv's assembler reads `.align N' as 2^N, so an alignment of 2^8 was
     emitted as `.align 256' and requested 2^256.  That is board item 7's
     `out of memory allocating 9223372036854841454 bytes'
     (scratchpad/agent-a018835bbcfad2e28-align.sh), and it is not riscv's bug:
     50 back ends define this macro and they disagree about `.align' vs
     `.balign' vs `.p2align' and about log vs bytes.

     A FUNCTION POINTER FOR THE REASON THE HEADER COMMENT ABOVE GIVES: several
     back ends switch the directive on options (`i386/gas.h:61' picks
     `.balign' or `.align'; pdp11 on TARGET_DEC_ASM), so the VALUE is
     per-compilation.  The table stores the function's ADDRESS, which is a
     constant expression, so `constexpr' still holds and still rejects an
     option-dependent initialiser.

     NO `#ifdef' WRAPPER, DELIBERATELY, unlike the section ops above.  For
     those, absence means "this target has no such section" and NULL says it.
     Here shared code aligns unconditionally, so absence is not an answer a
     base can give: a base whose chain never defines the macro must fail to
     compile THIS file, by name, rather than acquire a silent no-op that emits
     nothing and looks like correct output.  */
  void (*output_align) (FILE *, int);

  /* USE_SELECT_SECTION_FOR_FUNCTIONS -- this back end wants
     `function_section_1' (varasm.cc) to route a function with no explicit
     section through TARGET_ASM_SELECT_SECTION rather than through
     `hot_function_section'.

     A BOOL RATHER THAN A `#ifdef', BECAUSE THE `#ifdef' KILLED msp430 ON ITS
     FIRST INPUT.  Exactly one back end in the tree defines the macro
     (config/msp430/msp430.h:525) and the primary does not, so the `#ifdef' in
     shared `varasm.cc' was false for all 47 bases -- the "leaked absence"
     class in INSTRUMENTS.md, where guarded code runs for NOBODY.  The
     consequence is not a subtly wrong section: the `#else' arm calls
     `targetm.asm_out.function_section' unconditionally, and msp430's hook
     opens with

       gcc_assert (DECL_SECTION_NAME (decl) != NULL);   msp430.cc:2466

     which upstream can rely on precisely BECAUSE the macro sends the
     no-section case elsewhere.  So msp430 ICEd on `int f(int x){return x+1;}'
     and contributed no FAIL rows at all.

     Note the direction of the default: false is what a back end that never
     defined the macro has always got, so converting the guard cannot change
     any other base's output.  */
  bool use_select_section_for_functions;
};

/* Wrap each target macro in a function of the right shape.  Defined
   unconditionally, with the #ifdef inside the body, so that a back end
   lacking the macro yields a function returning NULL rather than needing a
   separate fallback -- "no such section" then has exactly one spelling.

   Included both by target-def.h, so each back end's targetm starts out
   correct, and by target-asm-ops.cc, which is compiled once per back end
   against that back end's tm-<base>.h to build its table.  These are
   `static inline', so each translation unit gets its own copy and the
   addresses stored in a table are still constant expressions.  */
#define GCC_TARGET_ASM_OP_WRAPPER(FN, MACRO)		\
  static inline const char *				\
  FN (void)						\
  {							\
    return MACRO;					\
  }

#ifdef GLOBAL_ASM_OP
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_global_op, GLOBAL_ASM_OP)
#else
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_global_op, NULL)
#endif
#ifdef TEXT_SECTION_ASM_OP
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_text, TEXT_SECTION_ASM_OP)
#else
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_text, NULL)
#endif
#ifdef DATA_SECTION_ASM_OP
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_data, DATA_SECTION_ASM_OP)
#else
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_data, NULL)
#endif
#ifdef SDATA_SECTION_ASM_OP
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_sdata, SDATA_SECTION_ASM_OP)
#else
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_sdata, NULL)
#endif
#ifdef READONLY_DATA_SECTION_ASM_OP
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_rodata, READONLY_DATA_SECTION_ASM_OP)
#else
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_rodata, NULL)
#endif
#ifdef BSS_SECTION_ASM_OP
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_bss, BSS_SECTION_ASM_OP)
#else
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_bss, NULL)
#endif
#ifdef SBSS_SECTION_ASM_OP
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_sbss, SBSS_SECTION_ASM_OP)
#else
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_sbss, NULL)
#endif
#ifdef CTORS_SECTION_ASM_OP
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_ctors, CTORS_SECTION_ASM_OP)
#else
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_ctors, NULL)
#endif
#ifdef DTORS_SECTION_ASM_OP
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_dtors, DTORS_SECTION_ASM_OP)
#else
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_dtors, NULL)
#endif
#ifdef INIT_SECTION_ASM_OP
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_init, INIT_SECTION_ASM_OP)
#else
GCC_TARGET_ASM_OP_WRAPPER (gcc_taop_init, NULL)
#endif

/* ASM_OUTPUT_ALIGN's wrapper.  `static inline' like the others, so the
   address stored in the table stays a constant expression.  The macro is a
   statement and several back ends spell it as a `do { } while (0)' or a bare
   `if', so it is invoked as a statement here and nothing is returned.

   DEFINED ONLY IN THE TRANSLATION UNITS THAT STILL HAVE THE REAL MACRO, which
   the other wrappers in this file do not need to say because their macros are
   not redirected.  This one is: in a shared TU `multi-target-macros.h' has
   already turned ASM_OUTPUT_ALIGN into a call to `mt_asm_output_align', so
   compiling the body there would define a wrapper that calls the selector
   which calls the wrapper.  It is dead code in that TU and would compile, and
   a self-referential definition that happens to be unreferenced is exactly the
   kind of thing that stops being unreferenced later without anyone noticing.
   The test is the same five-way one `multi-target-macros.h:188' uses.  */
#if defined (MULTI_TARGET_TARGETM_BASE) || defined (GENERATOR_FILE)	\
    || defined (MULTI_TARGET_SUPPLY_TU) || defined (MULTI_TARGET_REG_PROBE) \
    || !defined (__cplusplus)
static inline void
gcc_taop_output_align (FILE *stream, int log)
{
  ASM_OUTPUT_ALIGN (stream, log);
}
#endif

/* #ifndef so a back end that supplies its own hook still wins.  */
#ifndef TARGET_ASM_GLOBAL_OP
#define TARGET_ASM_GLOBAL_OP gcc_taop_global_op
#endif
#ifndef TARGET_ASM_TEXT_SECTION_ASM_OP
#define TARGET_ASM_TEXT_SECTION_ASM_OP gcc_taop_text
#endif
#ifndef TARGET_ASM_DATA_SECTION_ASM_OP
#define TARGET_ASM_DATA_SECTION_ASM_OP gcc_taop_data
#endif
#ifndef TARGET_ASM_SDATA_SECTION_ASM_OP
#define TARGET_ASM_SDATA_SECTION_ASM_OP gcc_taop_sdata
#endif
#ifndef TARGET_ASM_READONLY_DATA_SECTION_ASM_OP
#define TARGET_ASM_READONLY_DATA_SECTION_ASM_OP gcc_taop_rodata
#endif
#ifndef TARGET_ASM_BSS_SECTION_ASM_OP
#define TARGET_ASM_BSS_SECTION_ASM_OP gcc_taop_bss
#endif
#ifndef TARGET_ASM_SBSS_SECTION_ASM_OP
#define TARGET_ASM_SBSS_SECTION_ASM_OP gcc_taop_sbss
#endif
#ifndef TARGET_ASM_CTORS_SECTION_ASM_OP
#define TARGET_ASM_CTORS_SECTION_ASM_OP gcc_taop_ctors
#endif
#ifndef TARGET_ASM_DTORS_SECTION_ASM_OP
#define TARGET_ASM_DTORS_SECTION_ASM_OP gcc_taop_dtors
#endif
#ifndef TARGET_ASM_INIT_SECTION_ASM_OP
#define TARGET_ASM_INIT_SECTION_ASM_OP gcc_taop_init
#endif
/* Only meaningful where the wrapper above exists; the shared TUs that do not
   define it also never name TARGET_ASM_OUTPUT_ALIGN.  */
#if defined (MULTI_TARGET_TARGETM_BASE) || defined (GENERATOR_FILE)	\
    || defined (MULTI_TARGET_SUPPLY_TU) || defined (MULTI_TARGET_REG_PROBE) \
    || !defined (__cplusplus)
#ifndef TARGET_ASM_OUTPUT_ALIGN
#define TARGET_ASM_OUTPUT_ALIGN gcc_taop_output_align
#endif
#endif

/* No `#ifndef' guard on this one, unlike the hook names above: it is not a
   target.def hook a back end could already have supplied, it is the tm.h
   macro itself, read here in the per-base TU.  */
#ifdef USE_SELECT_SECTION_FOR_FUNCTIONS
#define TARGET_ASM_USE_SELECT_SECTION_FOR_FUNCTIONS true
#else
#define TARGET_ASM_USE_SELECT_SECTION_FOR_FUNCTIONS false
#endif

/* One entry per configured back end, so a table can be found by name.  */
struct target_asm_ops_entry
{
  const char *name;
  const struct target_asm_ops *ops;
};

extern const struct target_asm_ops_entry targetm_asm_ops_registry[];

/* The table in force.  */
extern const struct target_asm_ops *targetm_asm_ops;

/* Look BASE up in the registry, or NULL.  BASE is a cpu_type, the same name
   the tm-<base>.h files are keyed by.  */
extern const struct target_asm_ops *target_asm_ops_for (const char *base);

/* Copy the selected table into targetm.asm_out.  Must run before
   init_varasm_once; see the comment there.  */
extern void init_targetm_asm_ops (void);

/* ASM_OUTPUT_ALIGN for the base in force; `multi-target-macros.h' redirects
   the macro here.  Not copied into `targetm.asm_out' the way the section ops
   are, because there is no such hook to copy it into: the macro has no
   `targetm' counterpart upstream and inventing one would mean touching
   target.def and 50 back ends to change where a directive is printed.  */
extern void mt_asm_output_align (FILE *stream, int log);

/* USE_SELECT_SECTION_FOR_FUNCTIONS for the base in force.  Like
   `mt_asm_output_align', not copied into `targetm.asm_out': the macro has no
   `targetm' counterpart upstream.  */
extern bool mt_use_select_section_for_functions (void);

#endif /* GCC_TARGET_ASM_OPS_H */
