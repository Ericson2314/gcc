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

struct target_asm_ops
{
  const char *global_op;
  const char *text_section_asm_op;
  const char *data_section_asm_op;
  const char *sdata_section_asm_op;
  const char *readonly_data_section_asm_op;
  const char *bss_section_asm_op;
  const char *sbss_section_asm_op;
  const char *ctors_section_asm_op;
  const char *dtors_section_asm_op;
  const char *init_section_asm_op;
};

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
