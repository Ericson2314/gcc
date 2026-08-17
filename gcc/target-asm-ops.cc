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

/* THIS BASE'S OWN `tm_p.h', i.e. its `<cpu>-protos.h'.  Several back ends
   spell a directive as a CALL rather than a string -- mmix's
   `DATA_SECTION_ASM_OP' is `mmix_data_section_asm_op ()' and its
   `ASM_OUTPUT_ALIGN' is `mmix_asm_output_align (...)' -- and those functions
   are declared in `<cpu>-protos.h', which `tm.h' does not include.  Without
   this the base fails to compile BY NAME:

     config/mmix/mmix.h:588: error: 'mmix_data_section_asm_op' was not
                                    declared in this scope

   Same series as `target-cumargs.cc''s `BASE_HEADER (tm_p.h)' and its
   epiphany/`attribs.h', `attribs.h'/`stringpool.h' and msp430/`recog.h'
   includes: the macro is expanded in a translation unit where it is THAT
   base's own, so that base's headers must be satisfiable here.

   `#ifdef' rather than unconditional only because the single-target build
   compiles this file without the per-base -D; there `tm_p.h' comes in through
   the ordinary chain.

   And `memmodel.h' FIRST, which is not style either: `sparc-protos.h:46'
   takes an `enum memmodel` parameter, so including tm_p.h alone failed the
   next build by name (`use of enum 'memmodel' without previous
   declaration`) -- the same one-error-at-a-time shape, one header deeper,
   that `target-cumargs.cc` records for attribs.h/stringpool.h.  Found in
   seconds by `a76a331dcb554f700-asmopscheck.sh` rather than by a build.  */
/* WHAT THE TWO LABEL WRAPPERS NEED, AND THIS FILE WAS DELIBERATELY MINIMAL
   BEFORE THEM.  Everything the table holds is a string constant or a function
   address, so `config.h', `system.h', `coretypes.h' and the base's own `tm.h'
   sufficed.  `gcc_taop_output_labelref' and `gcc_taop_generate_internal_label'
   expand whole BODIES out of 37 back-end headers, and those bodies call into
   shared support code.  Measured over all 47 bases with
   `scratchpad/a94d141d788a6b54f-taoptry.sh', which compiles THIS FILE ALONE
   per base in seconds -- the same missing name found through `make all-gcc'
   costs forty minutes per attempt:

     alpha.h:867      user_label_prefix              output.h
     elfos.h:138      sprint_ul                      output.h
     arc.h:1142       targetm.strip_name_encoding    target.h
     (several)        default_strip_name_encoding    output.h
     (several)        asm_fprintf                    output.h
     mips.h, riscv.h  make_decl_rtl                  varasm.h

   Same one-error-at-a-time series the `TM_P_H_FILE' comment below records for
   mmix and sparc, and the same conclusion: a macro expanded in a translation
   unit where it is THAT base's own means that base's headers must be
   satisfiable HERE.  The table is still `constexpr'; none of these headers
   contributes to it.

   THE ORDER IS LOAD-BEARING AND `rtl.h' MUST PRECEDE `TM_P_H_FILE'.  A back
   end's `<cpu>-protos.h' wraps most of itself in `#ifdef RTX_CODE', so with
   the old order the file was included and CONTRIBUTED NOTHING -- silently.
   Measured: i386 alone of 47 failed with `ix86_asm_output_labelref was not
   declared', because `i386-protos.h:205' sits inside that guard while alpha's
   equivalent does not.  A header that is present, parsed, and empty is the
   same object as a header that is absent, and only one base out of 47 was
   positioned to say so.  This is the include order `target-cumargs.cc' already
   uses, for the same reason.  */
#include "rtl.h"
#include "tree.h"

#ifdef TM_P_H_FILE
#include "memmodel.h"
#include TM_P_H_FILE
#endif

#include "target.h"
#include "output.h"
#include "varasm.h"

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
  TARGET_ASM_OUTPUT_ALIGN,
  TARGET_ASM_OUTPUT_LABELREF,
  TARGET_ASM_GENERATE_INTERNAL_LABEL,
  TARGET_ASM_USE_SELECT_SECTION_FOR_FUNCTIONS,
  TARGET_ASM_REGISTER_PREFIX,
  TARGET_ASM_IMMEDIATE_PREFIX,
  TARGET_ASM_LOCAL_LABEL_PREFIX
};
