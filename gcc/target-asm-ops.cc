/* One back end's assembler directive table.
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

/* Compiled once per back end.  TM_H_FILE names that back end's tm-<base>.h and
   TARGETM_ASM_OPS_SYMBOL the name its table takes, so that all of them can be
   linked into one compiler; see gen-multi-target-md.awk for the rules and
   target-asm-ops.h for why this exists.

   Everything here is a string constant out of tm.h, so the table is a
   constant expression: statically initialised, valid before anything runs,
   and no ordering question against any other translation unit.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"

#ifndef TM_H_FILE
#define TM_H_FILE "tm.h"
#endif
#include TM_H_FILE

#include "target-asm-ops.h"

/* defaults.h, at the end of every tm header, carries each target macro into
   the matching TARGET_ASM_* only when the back end defines it.  A back end
   that has no such section leaves it undefined, and target.def's default for
   these hooks is NULL -- so NULL here means exactly what it means there: this
   target has no such section, which consumers must treat as the old #ifdef
   did rather than as an empty directive.  */

/* `extern' is not redundant.  A namespace-scope `const' object has internal
   linkage in C++, so without it this compiles to a file-local symbol -- the
   table is built correctly and then cannot be named from anywhere, and the
   selector's registry fails to link against all 44 of them at once.

   `constexpr' is not decoration either, and it is what makes this file safe.
   C++ accepts a non-constant initialiser at namespace scope by emitting a
   static constructor, so a back end whose directive is option-dependent --
   rx's `(TARGET_AS100_SYNTAX ? "\t.GLB\t" : "\t.global\t")' reads target_flags
   -- compiles and links clean and is silently wrong twice over: the
   constructor runs before options are decoded, so it captures the default
   flags rather than the user's, and the value is then frozen against
   `#pragma GCC target'.  rx, arm and pdp11 were each emitting an .init_array
   entry here.  constexpr turns that into a compile error naming the back end,
   which is the whole point: a value that depends on a command-line flag is
   per-compilation, not per-target, and cannot live in a table keyed by target
   identity whatever its type.  Those belong in function hooks evaluated at use
   time.  */
extern const struct target_asm_ops TARGETM_ASM_OPS_SYMBOL;
constexpr struct target_asm_ops TARGETM_ASM_OPS_SYMBOL =
{
  TARGET_ASM_GLOBAL_OP,
  TARGET_ASM_TEXT_SECTION_ASM_OP,
  TARGET_ASM_DATA_SECTION_ASM_OP,
  TARGET_ASM_SDATA_SECTION_ASM_OP,
  TARGET_ASM_READONLY_DATA_SECTION_ASM_OP,
  TARGET_ASM_BSS_SECTION_ASM_OP,
  TARGET_ASM_SBSS_SECTION_ASM_OP,
  TARGET_ASM_CTORS_SECTION_ASM_OP,
  TARGET_ASM_DTORS_SECTION_ASM_OP,
  TARGET_ASM_INIT_SECTION_ASM_OP,
  TARGET_ASM_OUTPUT_ALIGN
};
