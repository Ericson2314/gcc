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

#endif /* GCC_TARGET_ASM_OPS_H */
