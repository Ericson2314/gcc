/* The selected back end's `asm_fprintf' format extensions.
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

/* WHAT THIS FIXES.  `final.cc:asm_fprintf' had

       #ifdef ASM_FPRINTF_EXTENSIONS
	 case 'A': ... case 'Z':	<- the reserved uppercase letters
	   break;
	 ASM_FPRINTF_EXTENSIONS (file, argptr, p)
       #endif
	 default:
	   gcc_unreachable ();

   and `final.o' is SHARED -- compiled once, against the primary's `tm.h'.
   So the `#ifdef' and the macro body were both i386's, for every configured
   back end.

   EXACTLY TWO BACK ENDS DEFINE THE MACRO, i386 and arm, and they define the
   SAME LETTER to mean different things -- which is PRINCIPLES section 3's
   "one name, several authorities" in a printf format:

       i386   %z  word-mode opcode suffix ('q' or 'l')
	      %r  reg_names[arg] with an `r'/`e' prefix for legacy int regs
       arm    %@  ASM_COMMENT_START
	      %r  REGISTER_PREFIX then reg_names[arg]

   Measured on the eleven-base build at `-O2', after the `reg_alloc_order'
   over-read was fixed and arm reached codegen for the first time:

       during RTL pass: final
       internal compiler error: in asm_fprintf, at final.cc:4086

   -- `gcc_unreachable ()', because `arm.cc' emits `%@' and the shared
   `final.o' only knew i386's letters.  Note the shape: this is LEAKED
   ABSENCE, the `LOAD_EXTEND_OP' / `AUTO_INC_DEC' family.  The primary not
   defining a letter is itself a value reaching everyone, and if arm's `%r'
   had been the one exercised first it would have printed i386's register
   name instead of failing -- silently wrong output rather than an ICE.

   HOW "THIS BACK END HAS NO EXTENSIONS" IS EXPRESSED.  A null `extension'
   pointer, which is what the ABSENCE of `ASM_FPRINTF_EXTENSIONS' from that
   back end's own `tm.h' already means, read in the one translation unit
   compiled against that back end's headers.  Not a floor and not a fallback:
   forty-six back ends genuinely have no extensions, and for them
   `gcc_unreachable ()' on an unknown letter is upstream's own behaviour.

   Per PRINCIPLES section 2 this is a HOOK, not a `target-specs' capability:
   the answer is in the back end's headers, ships with the compiler, and
   cannot differ between two installations serving the same target.  */

#ifndef GCC_TARGET_ASMFPRINTF_H
#define GCC_TARGET_ASMFPRINTF_H

struct target_asmfprintf_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* ASM_FPRINTF_EXTENSIONS spliced into a `switch (c)', or NULL for a back
     end that defines no such macro.  Returns true if C was one of this back
     end's letters and was consumed, false otherwise -- so that shared code
     can still reach `gcc_unreachable ()' for a genuinely unknown letter
     rather than printing nothing and carrying on.

     ARGS is `&argptr' from the caller and not a copy: a `%r' extension reads
     an argument off it, and the caller must see that argument consumed.  */
  bool (*extension) (FILE *file, va_list *args, int c);

  /* Whether this back end defines ASSEMBLER_DIALECT, i.e. whether `{', `}'
     and `|' are alternative-selection delimiters in ITS insn templates.

     TWO of forty-eight define it -- i386 and i386/darwin -- and `final.o' is
     shared, so `#ifdef ASSEMBLER_DIALECT' was true for all forty-eight.  This
     is LEAKED PRESENCE, and unlike the extension letters above it produces no
     diagnostic at all.  Measured, arm at `-O2' on scratchpad/t170-small.c:

         bx      |lr

     arm's `bx%?\t%|lr' spells `%|' meaning "emit REGISTER_PREFIX", which for
     the EABI is the empty string.  `output_asm_insn' at final.cc:3507 has

         if (*p == '%' #ifdef ASSEMBLER_DIALECT || *p == '{' || *p == '}'
                       || *p == '|' #endif )
           { putc (*p, asm_out_file); p++; }

     so with i386's `#ifdef' in force `%|' printed a literal `|' instead of
     reaching arm's `print_operand' punct handler.  A `|' in the operand
     position of every register-prefixed insn -- assembly the target's own
     assembler rejects, from a compiler that exited 0.  PRINCIPLES' "a wall
     that moves may have become silent wrong code", arriving as the FIRST
     output arm ever produced.  */
  bool has_assembler_dialect;

  /* ASSEMBLER_DIALECT itself, or NULL when HAS_ASSEMBLER_DIALECT is false.
     A function because i386's is `(ix86_asm_dialect)', an option variable:
     evaluating it at static-initialisation time would freeze it before
     option processing -- the `ix86_pmode Init (PMODE_SI)' shape.  */
  int (*assembler_dialect) (void);
};

/* The table in force, or NULL until a target is selected.  NULL and not the
   primary's, for the reason target-regs.h argues at length.  */
extern const struct target_asmfprintf_desc *targetm_asmfprintf;

/* Shared code's spelling.  False means "not one of this back end's letters".
   Fails BY NAME if no back end has been selected.  */
extern bool mt_asm_fprintf_extension (FILE *file, va_list *args, int c);

/* Whether the SELECTED back end has assembler dialects, and which one is in
   force.  Two names because the `#ifdef' and the value are two questions and
   shared code asks them separately; they come off one `#ifdef' in
   target-cumargs.cc, so they cannot disagree.  */
extern bool mt_have_assembler_dialect (void);
extern int mt_assembler_dialect (void);

#endif /* GCC_TARGET_ASMFPRINTF_H */
