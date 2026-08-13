/* Definitions of various defaults for tm.h macros.
   Copyright (C) 1992-2026 Free Software Foundation, Inc.
   Contributed by Ron Guilmette (rfg@monkeys.com)

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

#ifndef GCC_DEFAULTS_H
#define GCC_DEFAULTS_H

/* Runtime target capabilities.  Included this early because SUPPORTS_DISCRIMINATOR
   below needs targ_caps; the macro redefinitions themselves live with the rest
   of the capability block further down.  Generators and target-library builds
   must not pull in compiler internals, so it is guarded out for them.  */
#if !defined (GENERATOR_FILE) && !defined (USED_FOR_TARGET)
#include "target-caps.h"
#endif

/* How to start an assembler comment.  */
#ifndef ASM_COMMENT_START
#define ASM_COMMENT_START ";#"
#endif

/* Store in OUTPUT a string (made with alloca) containing an
   assembler-name for a local static variable or function named NAME.
   LABELNO is an integer which is different for each call.  */

#ifndef ASM_PN_FORMAT
# ifndef NO_DOT_IN_LABEL
#  define ASM_PN_FORMAT "%s.%lu"
# else
#  ifndef NO_DOLLAR_IN_LABEL
#   define ASM_PN_FORMAT "%s$%lu"
#  else
#   define ASM_PN_FORMAT "__%s_%lu"
#  endif
# endif
#endif /* ! ASM_PN_FORMAT */

#ifndef ASM_FORMAT_PRIVATE_NAME
# define ASM_FORMAT_PRIVATE_NAME(OUTPUT, NAME, LABELNO) \
  do { const char *const name_ = (NAME); \
       char *const output_ = (OUTPUT) = \
	 (char *) alloca (strlen (name_) + 32); \
       sprintf (output_, ASM_PN_FORMAT, name_, (unsigned long)(LABELNO)); \
  } while (0)
#endif

/* Choose a reasonable default for ASM_OUTPUT_ASCII.  */

#ifndef ASM_OUTPUT_ASCII
#define ASM_OUTPUT_ASCII(MYFILE, MYSTRING, MYLENGTH) \
  do {									      \
    FILE *_my_file = (MYFILE);				      \
    const unsigned char *_hide_p = (const unsigned char *) (MYSTRING);	      \
    int _hide_thissize = (MYLENGTH);					      \
    {									      \
      const unsigned char *p = _hide_p;					      \
      int thissize = _hide_thissize;					      \
      int i;								      \
      fprintf (_my_file, "\t.ascii \"");				      \
									      \
      for (i = 0; i < thissize; i++)					      \
	{								      \
	  int c = p[i];			   				      \
	  if (c == '\"' || c == '\\')					      \
	    putc ('\\', _my_file);					      \
	  if (ISPRINT (c))						      \
	    putc (c, _my_file);						      \
	  else								      \
	    {								      \
	      fprintf (_my_file, "\\%o", c);				      \
	      /* After an octal-escape, if a digit follows,		      \
		 terminate one string constant and start another.	      \
		 The VAX assembler fails to stop reading the escape	      \
		 after three digits, so this is the only way we		      \
		 can get it to parse the data properly.  */		      \
	      if (i < thissize - 1 && ISDIGIT (p[i + 1]))		      \
		fprintf (_my_file, "\"\n\t.ascii \"");			      \
	  }								      \
	}								      \
      fprintf (_my_file, "\"\n");					      \
    }									      \
  }									      \
  while (0)
#endif

/* This is how we tell the assembler to equate two values.  */
#ifdef SET_ASM_OP
#ifndef ASM_OUTPUT_DEF
#define ASM_OUTPUT_DEF(FILE,LABEL1,LABEL2)				\
 do {	fprintf ((FILE), "%s", SET_ASM_OP);				\
	assemble_name (FILE, LABEL1);					\
	fprintf (FILE, ",");						\
	assemble_name (FILE, LABEL2);					\
	fprintf (FILE, "\n");						\
  } while (0)
#endif
#endif

#ifndef IFUNC_ASM_TYPE
#define IFUNC_ASM_TYPE "gnu_indirect_function"
#endif

#ifndef TLS_COMMON_ASM_OP
#define TLS_COMMON_ASM_OP ".tls_common"
#endif

#if defined (HAVE_AS_TLS) && !defined (ASM_OUTPUT_TLS_COMMON)
#define ASM_OUTPUT_TLS_COMMON(FILE, DECL, NAME, SIZE)			\
  do									\
    {									\
      fprintf ((FILE), "\t%s\t", TLS_COMMON_ASM_OP);			\
      assemble_name ((FILE), (NAME));					\
      fprintf ((FILE), "," HOST_WIDE_INT_PRINT_UNSIGNED",%u\n",		\
	       (SIZE), DECL_ALIGN (DECL) / BITS_PER_UNIT);		\
    }									\
  while (0)
#endif

/* Decide whether to defer emitting the assembler output for an equate
   of two values.  The default is to not defer output.  */
#ifndef TARGET_DEFERRED_OUTPUT_DEFS
#define TARGET_DEFERRED_OUTPUT_DEFS(DECL,TARGET) false
#endif

/* The POD bridge that used to sit here -- TARGET_ASM_GLOBAL_OP and the nine
   section-op hooks defined straight to their tm.h macros -- is gone.  Those
   hooks are function pointers now (see target-asm-ops.h), and defaults.h is
   included at the END of tm.h, i.e. BEFORE target-def.h, so a definition here
   wins the `#ifndef` in target-asm-ops.h and hands a string literal to a
   `const char *(*)(void)` slot.  The bridge lives in target-asm-ops.h alone.  */

/* This is how to output the definition of a user-level label named
   NAME, such as the label on variable NAME.  */

#ifndef ASM_OUTPUT_LABEL
#define ASM_OUTPUT_LABEL(FILE,NAME) \
  do {						\
    assemble_name ((FILE), (NAME));		\
    fputs (":\n", (FILE));			\
  } while (0)
#endif

/* This is how to output the definition of a user-level label named
   NAME, such as the label on a function.  */

#ifndef ASM_OUTPUT_FUNCTION_LABEL
#define ASM_OUTPUT_FUNCTION_LABEL(FILE, NAME, DECL) \
  assemble_function_label_raw ((FILE), (NAME))
#endif

/* Output the definition of a compiler-generated label named NAME.  */
#ifndef ASM_OUTPUT_INTERNAL_LABEL
#define ASM_OUTPUT_INTERNAL_LABEL(FILE,NAME)	\
  do {						\
    assemble_name_raw ((FILE), (NAME));		\
    fputs (":\n", (FILE));			\
  } while (0)
#endif

/* This is how to output a reference to a user-level label named NAME.  */

#ifndef ASM_OUTPUT_LABELREF
#define ASM_OUTPUT_LABELREF(FILE,NAME)  \
  do {							\
    fputs (user_label_prefix, (FILE));			\
    fputs ((NAME), (FILE));				\
  } while (0)
#endif

/* Allow target to print debug info labels specially.  This is useful for
   VLIW targets, since debug info labels should go into the middle of
   instruction bundles instead of breaking them.  */

#ifndef ASM_OUTPUT_DEBUG_LABEL
#define ASM_OUTPUT_DEBUG_LABEL(FILE, PREFIX, NUM) \
  (*targetm.asm_out.internal_label) (FILE, PREFIX, NUM)
#endif

/* This is how we tell the assembler that a symbol is weak.  */
#ifndef ASM_OUTPUT_WEAK_ALIAS
#if defined (ASM_WEAKEN_LABEL) && defined (ASM_OUTPUT_DEF)
#define ASM_OUTPUT_WEAK_ALIAS(STREAM, NAME, VALUE)	\
  do							\
    {							\
      ASM_WEAKEN_LABEL (STREAM, NAME);			\
      if (VALUE)					\
        ASM_OUTPUT_DEF (STREAM, NAME, VALUE);		\
    }							\
  while (0)
#endif
#endif

/* This is how we tell the assembler that a symbol is a weak alias to
   another symbol that doesn't require the other symbol to be defined.
   Uses of the former will turn into weak uses of the latter, i.e.,
   uses that, in case the latter is undefined, will not cause errors,
   and will add it to the symbol table as weak undefined.  However, if
   the latter is referenced directly, a strong reference prevails.  */
/* Whether this target WANTS `.weakref' at all.  A policy decision, and a
   separate question from whether the assembler accepts the directive
   (targ_caps.gas_weakref): pa/som.h sets this to 0 precisely because gas DOES
   accept `.weakref' there but gives the wrong symbol type for function
   references.  It used to express that by `#undef HAVE_GAS_WEAKREF', i.e. by
   claiming a capability was absent when it was present.  */
#ifndef TARGET_USE_WEAKREF
#define TARGET_USE_WEAKREF 1
#endif

#ifndef ASM_OUTPUT_WEAKREF
#if TARGET_USE_WEAKREF
#define ASM_OUTPUT_WEAKREF(FILE, DECL, NAME, VALUE)			\
  do									\
    {									\
      fprintf ((FILE), "\t.weakref\t");					\
      assemble_name ((FILE), (NAME));					\
      fprintf ((FILE), ",");						\
      assemble_name ((FILE), (VALUE));					\
      fprintf ((FILE), "\n");						\
    }									\
  while (0)
#endif
#endif

/* How to emit a .type directive.  */
#ifndef ASM_OUTPUT_TYPE_DIRECTIVE
#if defined TYPE_ASM_OP && defined TYPE_OPERAND_FMT
#define ASM_OUTPUT_TYPE_DIRECTIVE(STREAM, NAME, TYPE)	\
  do							\
    {							\
      fputs (TYPE_ASM_OP, STREAM);			\
      assemble_name (STREAM, NAME);			\
      fputs (", ", STREAM);				\
      fprintf (STREAM, TYPE_OPERAND_FMT, TYPE);		\
      putc ('\n', STREAM);				\
    }							\
  while (0)
#endif
#endif

/* How to emit a .size directive.  */
#ifndef ASM_OUTPUT_SIZE_DIRECTIVE
#ifdef SIZE_ASM_OP
#define ASM_OUTPUT_SIZE_DIRECTIVE(STREAM, NAME, SIZE)	\
  do							\
    {							\
      HOST_WIDE_INT size_ = (SIZE);			\
      fputs (SIZE_ASM_OP, STREAM);			\
      assemble_name (STREAM, NAME);			\
      fprintf (STREAM, ", " HOST_WIDE_INT_PRINT_DEC "\n", size_); \
    }							\
  while (0)

#define ASM_OUTPUT_MEASURED_SIZE(STREAM, NAME)		\
  do							\
    {							\
      fputs (SIZE_ASM_OP, STREAM);			\
      assemble_name (STREAM, NAME);			\
      fputs (", .-", STREAM);				\
      assemble_name (STREAM, NAME);			\
      putc ('\n', STREAM);				\
    }							\
  while (0)

#endif
#endif

/* This determines whether or not we support weak symbols.  SUPPORTS_WEAK
   must be a preprocessor constant.  */
#ifndef SUPPORTS_WEAK
#if defined (ASM_WEAKEN_LABEL) || defined (ASM_WEAKEN_DECL)
#define SUPPORTS_WEAK 1
#else
#define SUPPORTS_WEAK 0
#endif
#endif

/* This determines whether or not we support weak symbols during target
   code generation.  TARGET_SUPPORTS_WEAK can be any valid C expression.

   The two macros divide exactly along the line this file already draws:
   SUPPORTS_WEAK "must be a preprocessor constant" and asks whether the TARGET
   has a way to spell a weak symbol at all, while this one "can be any valid C
   expression" and is where the ASSEMBLER's willingness to accept it belongs.
   That is why HAVE_GAS_WEAK becomes targ_caps.gas_weak here rather than being
   folded into SUPPORTS_WEAK.  */
#ifndef TARGET_SUPPORTS_WEAK
#define TARGET_SUPPORTS_WEAK (SUPPORTS_WEAK && targ_caps.gas_weak)
#endif

/* This determines whether or not we support the discriminator
   attribute in the .loc directive.  */
#ifndef SUPPORTS_DISCRIMINATOR
#if defined (GENERATOR_FILE) || defined (USED_FOR_TARGET)
#define SUPPORTS_DISCRIMINATOR 0
#else
#define SUPPORTS_DISCRIMINATOR (targ_caps.gas_discriminator)
#endif
#endif

/* Nonzero if .init_array/.fini_array sections are available and working.
   ELF targets define this to 1 in config/elfos.h; this used to be probed at
   configure time, which also meant every cross compiler answered 0.  */
#ifndef HAVE_INITFINI_ARRAY_SUPPORT
#define HAVE_INITFINI_ARRAY_SUPPORT 0
#endif

/* This determines whether or not we support marking sections with
   SHF_GNU_RETAIN flag.  Also require .init_array/.fini_array section
   for constructors and destructors.  */
/* Was `#if HAVE_GAS_SHF_GNU_RETAIN && HAVE_INITFINI_ARRAY_SUPPORT'.  The
   .init_array/.fini_array half is a target property and stays in the
   preprocessor; the assembler's support for the `R' flag is not, so it is a
   runtime read.  The only consumer (c-family/c-attribs.cc) tests this in value
   position, so a macro expanding to an expression works.  targ_caps is
   declared further down this file, which is fine: a macro body is not
   evaluated where it is written.  */
#ifndef SUPPORTS_SHF_GNU_RETAIN
#if HAVE_INITFINI_ARRAY_SUPPORT
#define SUPPORTS_SHF_GNU_RETAIN (targ_caps.gas_shf_gnu_retain)
#else
#define SUPPORTS_SHF_GNU_RETAIN 0
#endif
#endif

/* This determines whether or not we support link-once semantics.  */
#ifndef SUPPORTS_ONE_ONLY
#ifdef MAKE_DECL_ONE_ONLY
#define SUPPORTS_ONE_ONLY 1
#else
#define SUPPORTS_ONE_ONLY 0
#endif
#endif

/* This determines whether weak symbols must be left out of a static
   archive's table of contents.  Defining this macro to be nonzero has
   the consequence that certain symbols will not be made weak that
   otherwise would be.  The C++ ABI requires this macro to be zero;
   see the documentation.  */
#ifndef TARGET_WEAK_NOT_IN_ARCHIVE_TOC
#define TARGET_WEAK_NOT_IN_ARCHIVE_TOC 0
#endif

/* This determines whether or not we need linkonce unwind information.  */
#ifndef TARGET_USES_WEAK_UNWIND_INFO
#define TARGET_USES_WEAK_UNWIND_INFO 0
#endif

/* By default, there is no prefix on user-defined symbols.  */
#ifndef USER_LABEL_PREFIX
#define USER_LABEL_PREFIX ""
#endif

/* If the target supports weak symbols, define TARGET_ATTRIBUTE_WEAK to
   provide a weak attribute.  Else define it to nothing.

   This would normally belong in ansidecl.h, but SUPPORTS_WEAK is
   not available at that time.

   Note, this is only for use by target files which we know are to be
   compiled by GCC.  */
#ifndef TARGET_ATTRIBUTE_WEAK
# if SUPPORTS_WEAK
#  define TARGET_ATTRIBUTE_WEAK __attribute__ ((weak))
# else
#  define TARGET_ATTRIBUTE_WEAK
# endif
#endif

/* By default we can assume that all global symbols are in one namespace,
   across all shared libraries.  */
#ifndef MULTIPLE_SYMBOL_SPACES
# define MULTIPLE_SYMBOL_SPACES 0
#endif

/* If the target supports init_priority C++ attribute, give
   SUPPORTS_INIT_PRIORITY a nonzero value.  */
#ifndef SUPPORTS_INIT_PRIORITY
#define SUPPORTS_INIT_PRIORITY 1
#endif /* SUPPORTS_INIT_PRIORITY */

/* If we have a definition of INCOMING_RETURN_ADDR_RTX, assume that
   the rest of the DWARF 2 frame unwind support is also provided.  */
#if !defined (DWARF2_UNWIND_INFO) && defined (INCOMING_RETURN_ADDR_RTX)
#define DWARF2_UNWIND_INFO 1
#endif

/* If we have named sections, and we're using crtstuff to run ctors,
   use them for registering eh frame information.  */
#if defined (TARGET_ASM_NAMED_SECTION) && DWARF2_UNWIND_INFO \
    && !defined (EH_FRAME_THROUGH_COLLECT2)
#ifndef EH_FRAME_SECTION_NAME
#define EH_FRAME_SECTION_NAME ".eh_frame"
#endif
#endif

/* On many systems, different EH table encodings are used under
   difference circumstances.  Some will require runtime relocations;
   some will not.  For those that do not require runtime relocations,
   we would like to make the table read-only.  However, since the
   read-only tables may need to be combined with read-write tables
   that do require runtime relocation, it is not safe to make the
   tables read-only unless the linker will merge read-only and
   read-write sections into a single read-write section.  If your
   linker does not have this ability, but your system is such that no
   encoding used with non-PIC code will ever require a runtime
   relocation, then you can define EH_TABLES_CAN_BE_READ_ONLY to 1 in
   your target configuration file.

   Was `#ifdef HAVE_LD_RO_RW_SECTION_MIXING' choosing between 1 and 0.  That
   test sat ABOVE the targ_caps redefinition further down this file, so it saw
   auto-host.h's unconditional `#define ... 1' and was constant-true regardless
   of the runtime value -- and had the gcc-side define simply been deleted it
   would have become constant-FALSE, silently.  A runtime read is what it always
   meant; i386/sol2.h already defines this macro as `(TARGET_64BIT)', so an
   expression here is nothing new.  */
#ifndef EH_TABLES_CAN_BE_READ_ONLY
#define EH_TABLES_CAN_BE_READ_ONLY (targ_caps.ld_ro_rw_section_mixing)
#endif

/* Provide defaults for stuff that may not be defined when using
   sjlj exceptions.  */
#ifndef EH_RETURN_DATA_REGNO
#define EH_RETURN_DATA_REGNO(N) (void (N), INVALID_REGNUM)
#endif

/* Offset between the eh handler address and entry in eh tables.  */
#ifndef RETURN_ADDR_OFFSET
#define RETURN_ADDR_OFFSET 0
#endif

#ifndef MASK_RETURN_ADDR
#define MASK_RETURN_ADDR NULL_RTX
#endif

/* Number of hardware registers that go into the DWARF-2 unwind info.
   If not defined, equals FIRST_PSEUDO_REGISTER  */

#ifndef DWARF_FRAME_REGISTERS
#define DWARF_FRAME_REGISTERS FIRST_PSEUDO_REGISTER
#endif

/* Whether -mfentry is on by default on x86-64.  The x86 GNU targets say so;
   see config/i386/gnu-user-common.h.  */
#ifndef ENABLE_X86_64_MFENTRY
#define ENABLE_X86_64_MFENTRY 0
#endif

/* Whether the target supports gnu indirect functions.  Targets that do say so
   in config.gcc.  */
#ifndef TARGET_HAS_IFUNC
#define TARGET_HAS_IFUNC 0
#endif

/* Whether -fhardened can deliver what it promises here.  A target that can
   says so itself; see config/linux.h.  */
#ifndef TARGET_FHARDENED_SUPPORTED
#define TARGET_FHARDENED_SUPPORTED 0
#endif

/* Whether the assembler and linker in use are the Solaris ones rather than
   GNU as and GNU ld.  Upstream both come from configure probes of the target's
   tools (configure.ac's solaris_as and ld_flavor checks, AC_DEFINE_UNQUOTED to
   0 or 1), which were removed here: they are properties of particular
   assembler and linker binaries, so they belong in target-specs and
   ultimately have to reach the compiler at run time.

   PLACEHOLDERS, not answers.  Do not read these as a decision that no target
   uses the Solaris tools; they are 0 because nothing can supply the real
   value yet, and they should become a target capability queried at run time.

   Stated explicitly because the alternative is not "no definition" but a
   silent 0: nearly every user spells it `#if HAVE_SOLARIS_AS', where an
   undefined identifier is 0 with no diagnostic.  So the removal already had
   this effect throughout config/sol2.h, config/{i386,sparc}/sol2.h,
   config/i386/i386.cc, config/sparc/sparc.cc and go/gospec.cc, and merely hid
   it.  Note these #defines do NOT reach those sites: defaults.h is included at
   the END of tm.h, after the OS headers that test them.  Their behaviour is
   unchanged, and that is the point -- what changes is that the situation is
   now written down.

   config/sparc/sparc.md is the exception that made it visible, because it uses
   both as C rather than as preprocessor conditions, where an undefined
   identifier is a hard error: HAVE_SOLARIS_AS in an insn condition (found when
   gencondmd was first built per back end) and both in a define_attr symbol_ref
   at sparc.md:559, which genattrtab will compile when it too goes per back
   end.  `.md' C conditions are the only place an absent macro is loud; a sweep
   of every macro this branch has dropped from config.in against every .md file
   in the tree found exactly these two.  */
#ifndef HAVE_SOLARIS_AS
#define HAVE_SOLARIS_AS 0
#endif
#ifndef HAVE_SOLARIS_LD
#define HAVE_SOLARIS_LD 0
#endif

/* HAVE_SOLARIS_LD has exactly the same history and the same problem, and was
   still fully silent: nothing defined it anywhere, and all fifteen consumers
   spell it `#if HAVE_SOLARIS_LD', so it has been 0 with no diagnostic since
   the probe was removed.  Unlike HAVE_SOLARIS_AS it has no .md condition to
   make the gap loud, which is why it went unnoticed longer.

   Note what it selects: LD_WHOLE_ARCHIVE_OPTION, LINK_ARCH_SPEC_1,
   RDYNAMIC_SPEC, LINK_LIBGCC_MAPFILE_SPEC and friends are all spec string
   literals, so this one cannot become a runtime capability in its present
   shape -- it is the build-time/spec-override variant, not a targ_caps
   candidate.  Explicit 0 until target-specs supplies it.  */
#ifndef HAVE_SOLARIS_LD
#define HAVE_SOLARIS_LD 0
#endif

/* Offsets recorded in opcodes are a multiple of this alignment factor.  */
#ifndef DWARF_CIE_DATA_ALIGNMENT
#ifdef STACK_GROWS_DOWNWARD
#define DWARF_CIE_DATA_ALIGNMENT (-((int) UNITS_PER_WORD))
#else
#define DWARF_CIE_DATA_ALIGNMENT ((int) UNITS_PER_WORD)
#endif
#endif

/* The DWARF 2 CFA column which tracks the return address.  Normally this
   is the column for PC, or the first column after all of the hard
   registers.  */
#ifndef DWARF_FRAME_RETURN_COLUMN
#ifdef PC_REGNUM
#define DWARF_FRAME_RETURN_COLUMN	DWARF_FRAME_REGNUM (PC_REGNUM)
#else
#define DWARF_FRAME_RETURN_COLUMN	DWARF_FRAME_REGISTERS
#endif
#endif

/* How to renumber registers for gdb.  If not defined, assume
   no renumbering is necessary.  */

#ifndef DEBUGGER_REGNO
#define DEBUGGER_REGNO(REGNO) (REGNO)
#endif

/* The mapping from gcc register number to DWARF 2 CFA column number.
   By default, we just provide columns for all registers.  */
#ifndef DWARF_FRAME_REGNUM
#define DWARF_FRAME_REGNUM(REG) DEBUGGER_REGNO (REG)
#endif

/* The mapping from dwarf CFA reg number to internal dwarf reg numbers.  */
#ifndef DWARF_REG_TO_UNWIND_COLUMN
#define DWARF_REG_TO_UNWIND_COLUMN(REGNO) (REGNO)
#endif

/* Map register numbers held in the call frame info that gcc has
   collected using DWARF_FRAME_REGNUM to those that should be output in
   .debug_frame and .eh_frame.  */
#ifndef DWARF2_FRAME_REG_OUT
#define DWARF2_FRAME_REG_OUT(REGNO, FOR_EH) (REGNO)
#endif

/* The size of addresses as they appear in the Dwarf 2 data.
   Some architectures use word addresses to refer to code locations,
   but Dwarf 2 info always uses byte addresses.  On such machines,
   Dwarf 2 addresses need to be larger than the architecture's
   pointers.  */
#ifndef DWARF2_ADDR_SIZE
#define DWARF2_ADDR_SIZE ((POINTER_SIZE + BITS_PER_UNIT - 1) / BITS_PER_UNIT)
#endif

/* The size in bytes of a DWARF field indicating an offset or length
   relative to a debug info section, specified to be 4 bytes in the
   DWARF-2 specification.  The SGI/MIPS ABI defines it to be the same
   as PTR_SIZE.  */
#ifndef DWARF_OFFSET_SIZE
#define DWARF_OFFSET_SIZE 4
#endif

/* The size in bytes of a DWARF 4 type signature.  */
#ifndef DWARF_TYPE_SIGNATURE_SIZE
#define DWARF_TYPE_SIGNATURE_SIZE 8
#endif

/* Default sizes for base C types.  If the sizes are different for
   your target, you should override these values by defining the
   appropriate symbols in your tm.h file.  */

#ifndef BITS_PER_WORD
#define BITS_PER_WORD (BITS_PER_UNIT * UNITS_PER_WORD)
#endif

#ifndef CHAR_TYPE_SIZE
#define CHAR_TYPE_SIZE BITS_PER_UNIT
#endif

#ifndef BOOL_TYPE_SIZE
/* `bool' has size and alignment `1', on almost all platforms.  */
#define BOOL_TYPE_SIZE CHAR_TYPE_SIZE
#endif

#ifndef SHORT_TYPE_SIZE
#define SHORT_TYPE_SIZE (BITS_PER_UNIT * MIN ((UNITS_PER_WORD + 1) / 2, 2))
#endif

#ifndef INT_TYPE_SIZE
#define INT_TYPE_SIZE BITS_PER_WORD
#endif

#ifndef LONG_TYPE_SIZE
#define LONG_TYPE_SIZE BITS_PER_WORD
#endif

#ifndef LONG_LONG_TYPE_SIZE
#define LONG_LONG_TYPE_SIZE (BITS_PER_WORD * 2)
#endif

#ifndef WCHAR_TYPE_SIZE
#define WCHAR_TYPE_SIZE INT_TYPE_SIZE
#endif

#ifndef DECIMAL32_TYPE_SIZE
#define DECIMAL32_TYPE_SIZE 32
#endif

#ifndef DECIMAL64_TYPE_SIZE
#define DECIMAL64_TYPE_SIZE 64
#endif

#ifndef DECIMAL128_TYPE_SIZE
#define DECIMAL128_TYPE_SIZE 128
#endif

#ifndef SHORT_FRACT_TYPE_SIZE
#define SHORT_FRACT_TYPE_SIZE BITS_PER_UNIT
#endif

#ifndef FRACT_TYPE_SIZE
#define FRACT_TYPE_SIZE (BITS_PER_UNIT * 2)
#endif

#ifndef LONG_FRACT_TYPE_SIZE
#define LONG_FRACT_TYPE_SIZE (BITS_PER_UNIT * 4)
#endif

#ifndef LONG_LONG_FRACT_TYPE_SIZE
#define LONG_LONG_FRACT_TYPE_SIZE (BITS_PER_UNIT * 8)
#endif

#ifndef SHORT_ACCUM_TYPE_SIZE
#define SHORT_ACCUM_TYPE_SIZE (SHORT_FRACT_TYPE_SIZE * 2)
#endif

#ifndef ACCUM_TYPE_SIZE
#define ACCUM_TYPE_SIZE (FRACT_TYPE_SIZE * 2)
#endif

#ifndef LONG_ACCUM_TYPE_SIZE
#define LONG_ACCUM_TYPE_SIZE (LONG_FRACT_TYPE_SIZE * 2)
#endif

#ifndef LONG_LONG_ACCUM_TYPE_SIZE
#define LONG_LONG_ACCUM_TYPE_SIZE (LONG_LONG_FRACT_TYPE_SIZE * 2)
#endif

/* We let tm.h override the types used here, to handle trivial differences
   such as the choice of unsigned int or long unsigned int for size_t.
   When machines start needing nontrivial differences in the size type,
   it would be best to do something here to figure out automatically
   from other information what type to use.  */

#ifndef SIZE_TYPE
#define SIZE_TYPE "long unsigned int"
#endif

#ifndef SIZETYPE
#define SIZETYPE SIZE_TYPE
#endif

#ifndef PID_TYPE
#define PID_TYPE "int"
#endif

/* If GCC knows the exact uint_least16_t and uint_least32_t types from
   <stdint.h>, use them for char16_t and char32_t.  Otherwise, use
   these guesses; getting the wrong type of a given width will not
   affect C++ name mangling because in C++ these are distinct types
   not typedefs.  */

#ifndef CHAR8_TYPE
#define CHAR8_TYPE "unsigned char"
#endif

#ifdef UINT_LEAST16_TYPE
#define CHAR16_TYPE UINT_LEAST16_TYPE
#else
#define CHAR16_TYPE "short unsigned int"
#endif

#ifdef UINT_LEAST32_TYPE
#define CHAR32_TYPE UINT_LEAST32_TYPE
#else
#define CHAR32_TYPE "unsigned int"
#endif

#ifndef WCHAR_TYPE
#define WCHAR_TYPE "int"
#endif

/* WCHAR_TYPE gets overridden by -fshort-wchar.  */
#define MODIFIED_WCHAR_TYPE \
	(flag_short_wchar ? "short unsigned int" : WCHAR_TYPE)

#ifndef PTRDIFF_TYPE
#define PTRDIFF_TYPE "long int"
#endif

#ifndef WINT_TYPE
#define WINT_TYPE "unsigned int"
#endif

#ifndef INTMAX_TYPE
#define INTMAX_TYPE ((INT_TYPE_SIZE == LONG_LONG_TYPE_SIZE)	\
		     ? "int"					\
		     : ((LONG_TYPE_SIZE == LONG_LONG_TYPE_SIZE)	\
			? "long int"				\
			: "long long int"))
#endif

#ifndef UINTMAX_TYPE
#define UINTMAX_TYPE ((INT_TYPE_SIZE == LONG_LONG_TYPE_SIZE)	\
		     ? "unsigned int"				\
		     : ((LONG_TYPE_SIZE == LONG_LONG_TYPE_SIZE)	\
			? "long unsigned int"			\
			: "long long unsigned int"))
#endif


/* There are no default definitions of these <stdint.h> types.  */

#ifndef SIG_ATOMIC_TYPE
#define SIG_ATOMIC_TYPE ((const char *) NULL)
#endif

#ifndef INT8_TYPE
#define INT8_TYPE ((const char *) NULL)
#endif

#ifndef INT16_TYPE
#define INT16_TYPE ((const char *) NULL)
#endif

#ifndef INT32_TYPE
#define INT32_TYPE ((const char *) NULL)
#endif

#ifndef INT64_TYPE
#define INT64_TYPE ((const char *) NULL)
#endif

#ifndef UINT8_TYPE
#define UINT8_TYPE ((const char *) NULL)
#endif

#ifndef UINT16_TYPE
#define UINT16_TYPE ((const char *) NULL)
#endif

#ifndef UINT32_TYPE
#define UINT32_TYPE ((const char *) NULL)
#endif

#ifndef UINT64_TYPE
#define UINT64_TYPE ((const char *) NULL)
#endif

#ifndef INT_LEAST8_TYPE
#define INT_LEAST8_TYPE ((const char *) NULL)
#endif

#ifndef INT_LEAST16_TYPE
#define INT_LEAST16_TYPE ((const char *) NULL)
#endif

#ifndef INT_LEAST32_TYPE
#define INT_LEAST32_TYPE ((const char *) NULL)
#endif

#ifndef INT_LEAST64_TYPE
#define INT_LEAST64_TYPE ((const char *) NULL)
#endif

#ifndef UINT_LEAST8_TYPE
#define UINT_LEAST8_TYPE ((const char *) NULL)
#endif

#ifndef UINT_LEAST16_TYPE
#define UINT_LEAST16_TYPE ((const char *) NULL)
#endif

#ifndef UINT_LEAST32_TYPE
#define UINT_LEAST32_TYPE ((const char *) NULL)
#endif

#ifndef UINT_LEAST64_TYPE
#define UINT_LEAST64_TYPE ((const char *) NULL)
#endif

#ifndef INT_FAST8_TYPE
#define INT_FAST8_TYPE ((const char *) NULL)
#endif

#ifndef INT_FAST16_TYPE
#define INT_FAST16_TYPE ((const char *) NULL)
#endif

#ifndef INT_FAST32_TYPE
#define INT_FAST32_TYPE ((const char *) NULL)
#endif

#ifndef INT_FAST64_TYPE
#define INT_FAST64_TYPE ((const char *) NULL)
#endif

#ifndef UINT_FAST8_TYPE
#define UINT_FAST8_TYPE ((const char *) NULL)
#endif

#ifndef UINT_FAST16_TYPE
#define UINT_FAST16_TYPE ((const char *) NULL)
#endif

#ifndef UINT_FAST32_TYPE
#define UINT_FAST32_TYPE ((const char *) NULL)
#endif

#ifndef UINT_FAST64_TYPE
#define UINT_FAST64_TYPE ((const char *) NULL)
#endif

#ifndef INTPTR_TYPE
#define INTPTR_TYPE ((const char *) NULL)
#endif

#ifndef UINTPTR_TYPE
#define UINTPTR_TYPE ((const char *) NULL)
#endif

/* Width in bits of a pointer.  Mind the value of the macro `Pmode'.  */
#ifndef POINTER_SIZE
#define POINTER_SIZE BITS_PER_WORD
#endif
#ifndef POINTER_SIZE_UNITS
#define POINTER_SIZE_UNITS ((POINTER_SIZE + BITS_PER_UNIT - 1) / BITS_PER_UNIT)
#endif


#ifndef PIC_OFFSET_TABLE_REGNUM
#define PIC_OFFSET_TABLE_REGNUM INVALID_REGNUM
#endif

#ifndef PIC_OFFSET_TABLE_REG_CALL_CLOBBERED
#define PIC_OFFSET_TABLE_REG_CALL_CLOBBERED 0
#endif

#ifndef TARGET_DLLIMPORT_DECL_ATTRIBUTES
#define TARGET_DLLIMPORT_DECL_ATTRIBUTES 0
#endif

#ifndef TARGET_DECLSPEC
#if TARGET_DLLIMPORT_DECL_ATTRIBUTES
/* If the target supports the "dllimport" attribute, users are
   probably used to the "__declspec" syntax.  */
#define TARGET_DECLSPEC 1
#else
#define TARGET_DECLSPEC 0
#endif
#endif

/* By default, the preprocessor should be invoked the same way in C++
   as in C.  */
#ifndef CPLUSPLUS_CPP_SPEC
#ifdef CPP_SPEC
#define CPLUSPLUS_CPP_SPEC CPP_SPEC
#endif
#endif

#ifndef ACCUMULATE_OUTGOING_ARGS
#define ACCUMULATE_OUTGOING_ARGS 0
#endif

/* By default, use the GNU runtime for Objective C.  */
#ifndef NEXT_OBJC_RUNTIME
#define NEXT_OBJC_RUNTIME 0
#endif

/* Decide whether a function's arguments should be processed
   from first to last or from last to first.

   They should if the stack and args grow in opposite directions, but
   only if we have push insns.  */

#ifdef PUSH_ROUNDING

#ifndef PUSH_ARGS_REVERSED
#if defined (STACK_GROWS_DOWNWARD) != defined (ARGS_GROW_DOWNWARD)
#define PUSH_ARGS_REVERSED targetm.calls.push_argument (0)
#endif
#endif

#endif

#ifndef PUSH_ARGS_REVERSED
#define PUSH_ARGS_REVERSED 0
#endif

/* Default value for the alignment (in bits) a C conformant malloc has to
   provide. This default is intended to be safe and always correct.  */
#ifndef MALLOC_ABI_ALIGNMENT
#define MALLOC_ABI_ALIGNMENT BITS_PER_WORD
#endif

/* If PREFERRED_STACK_BOUNDARY is not defined, set it to STACK_BOUNDARY.
   STACK_BOUNDARY is required.  */
#ifndef PREFERRED_STACK_BOUNDARY
#define PREFERRED_STACK_BOUNDARY STACK_BOUNDARY
#endif

/* Set INCOMING_STACK_BOUNDARY to PREFERRED_STACK_BOUNDARY if it is not
   defined.  */
#ifndef INCOMING_STACK_BOUNDARY
#define INCOMING_STACK_BOUNDARY PREFERRED_STACK_BOUNDARY
#endif

#ifndef TARGET_DEFAULT_PACK_STRUCT
#define TARGET_DEFAULT_PACK_STRUCT 0
#endif

/* By default, the vtable entries are void pointers, the so the alignment
   is the same as pointer alignment.  The value of this macro specifies
   the alignment of the vtable entry in bits.  It should be defined only
   when special alignment is necessary.  */
#ifndef TARGET_VTABLE_ENTRY_ALIGN
#define TARGET_VTABLE_ENTRY_ALIGN POINTER_SIZE
#endif

/* There are a few non-descriptor entries in the vtable at offsets below
   zero.  If these entries must be padded (say, to preserve the alignment
   specified by TARGET_VTABLE_ENTRY_ALIGN), set this to the number of
   words in each data entry.  */
#ifndef TARGET_VTABLE_DATA_ENTRY_DISTANCE
#define TARGET_VTABLE_DATA_ENTRY_DISTANCE 1
#endif

/* Whether it is safe to use a local alias for a virtual function when
   constructing thunks, and whether the target supports aliases at all, are now
   the target hooks TARGET_ASM_USE_LOCAL_THUNK_ALIAS_P and
   TARGET_ASM_SUPPORTS_ALIASES.  They used to be defined here, derived from
   ASM_OUTPUT_DEF, which baked one target's answer into every target: the files
   that ask (symtab.cc, ipa-visibility.cc, the cp/ front end, d/decl.cc, ...)
   are compiled
   once for the whole compiler.  A back end that still defines the old macro
   gets it bridged into the hook by target-def.h; nvptx and i386 Cygwin/MinGW
   are the two that do.  There is deliberately no fallback definition here, so
   that a stale use of the old macro name fails to compile rather than silently
   reading whichever tm.h happened to win.  */

/* Indicate whether the target uses "target" attributes for function
   multiversioning.  This is used to choose between the "target" and
   "target_version" attributes when expanding a "target_clones" attribute, and
   determine whether the "target" and "target_clones" attributes are mutually
   exclusive.  */
#ifndef TARGET_HAS_FMV_TARGET_ATTRIBUTE
#define TARGET_HAS_FMV_TARGET_ATTRIBUTE 1
#endif

/* Select a attribute separator for function multiversioning.  */
#ifndef TARGET_CLONES_ATTR_SEPARATOR
#define TARGET_CLONES_ATTR_SEPARATOR ','
#endif

/* Select a format to encode pointers in exception handling data.  We
   prefer those that result in fewer dynamic relocations.  Assume no
   special support here and encode direct references.  */
#ifndef ASM_PREFERRED_EH_DATA_FORMAT
#define ASM_PREFERRED_EH_DATA_FORMAT(CODE,GLOBAL)  DW_EH_PE_absptr
#endif

/* By default, the C++ compiler will use the lowest bit of the pointer
   to function to indicate a pointer-to-member-function points to a
   virtual member function.  However, if FUNCTION_BOUNDARY indicates
   function addresses aren't always even, the lowest bit of the delta
   field will be used.  */
#ifndef TARGET_PTRMEMFUNC_VBIT_LOCATION
#define TARGET_PTRMEMFUNC_VBIT_LOCATION \
  (FUNCTION_BOUNDARY >= 2 * BITS_PER_UNIT \
   ? ptrmemfunc_vbit_in_pfn : ptrmemfunc_vbit_in_delta)
#endif

#ifndef DEFAULT_GDB_EXTENSIONS
#define DEFAULT_GDB_EXTENSIONS 1
#endif

/* Default to DWARF2_DEBUGGING_INFO.  Legacy targets can choose different
   by defining PREFERRED_DEBUGGING_TYPE.  */
#ifndef PREFERRED_DEBUGGING_TYPE
#if defined DWARF2_DEBUGGING_INFO || defined DWARF2_LINENO_DEBUGGING_INFO
#define PREFERRED_DEBUGGING_TYPE DWARF2_DEBUG
#else
#error You must define PREFERRED_DEBUGGING_TYPE if DWARF is not supported
#endif
#endif

#ifndef FLOAT_LIB_COMPARE_RETURNS_BOOL
#define FLOAT_LIB_COMPARE_RETURNS_BOOL(MODE, COMPARISON) false
#endif

/* True if the targets integer-comparison functions return { 0, 1, 2
   } to indicate { <, ==, > }.  False if { -1, 0, 1 } is used
   instead.  The libgcc routines are biased.  */
#ifndef TARGET_LIB_INT_CMP_BIASED
#define TARGET_LIB_INT_CMP_BIASED (true)
#endif

/* If FLOAT_WORDS_BIG_ENDIAN is not defined in the header files,
   then the word-endianness is the same as for integers.  */
#ifndef FLOAT_WORDS_BIG_ENDIAN
#define FLOAT_WORDS_BIG_ENDIAN WORDS_BIG_ENDIAN
#endif

#ifndef REG_WORDS_BIG_ENDIAN
#define REG_WORDS_BIG_ENDIAN WORDS_BIG_ENDIAN
#endif


#ifndef TARGET_DEC_EVAL_METHOD
#define TARGET_DEC_EVAL_METHOD 2
#endif

#ifndef HAS_LONG_COND_BRANCH
#define HAS_LONG_COND_BRANCH 0
#endif

#ifndef HAS_LONG_UNCOND_BRANCH
#define HAS_LONG_UNCOND_BRANCH 0
#endif

/* Determine whether __cxa_atexit, rather than atexit, is used to
   register C++ destructors for local statics and global objects.  */
#ifndef DEFAULT_USE_CXA_ATEXIT
#define DEFAULT_USE_CXA_ATEXIT 0
#endif

#if GCC_VERSION >= 3000 && defined IN_GCC
/* These old constraint macros shouldn't appear anywhere in a
   configuration using MD constraint definitions.  */
#endif

/* Determine whether the target runtime library is Bionic */
#ifndef TARGET_HAS_BIONIC
#define TARGET_HAS_BIONIC 0
#endif

/* Indicate that CLZ and CTZ are undefined at zero.  */
#ifndef CLZ_DEFINED_VALUE_AT_ZERO
#define CLZ_DEFINED_VALUE_AT_ZERO(MODE, VALUE)  0
#endif
#ifndef CTZ_DEFINED_VALUE_AT_ZERO
#define CTZ_DEFINED_VALUE_AT_ZERO(MODE, VALUE)  0
#endif

/* Provide a default value for STORE_FLAG_VALUE.  */
#ifndef STORE_FLAG_VALUE
#define STORE_FLAG_VALUE  1
#endif

/* This macro is used to determine what the largest unit size that
   move_by_pieces can use is.  */

/* MOVE_MAX_PIECES is the number of bytes at a time which we can
   move efficiently, as opposed to  MOVE_MAX which is the maximum
   number of bytes we can move with a single instruction.  */

#ifndef MOVE_MAX_PIECES
#define MOVE_MAX_PIECES   MOVE_MAX
#endif

/* STORE_MAX_PIECES is the number of bytes at a time that we can
   store efficiently.  Due to internal GCC limitations, this is
   MOVE_MAX_PIECES limited by the number of bytes GCC can represent
   for an immediate constant.  */

#ifndef STORE_MAX_PIECES
#define STORE_MAX_PIECES  MIN (MOVE_MAX_PIECES, 2 * sizeof (HOST_WIDE_INT))
#endif

/* Likewise for block comparisons.  */
#ifndef COMPARE_MAX_PIECES
#define COMPARE_MAX_PIECES  MOVE_MAX_PIECES
#endif

#ifndef MAX_MOVE_MAX
#define MAX_MOVE_MAX MOVE_MAX
#endif

#ifndef MIN_UNITS_PER_WORD
#define MIN_UNITS_PER_WORD UNITS_PER_WORD
#endif

#ifndef MAX_BITS_PER_WORD
#define MAX_BITS_PER_WORD BITS_PER_WORD
/* Remember that this fallback fired, so the redirection block at the end of
   this file can refuse to make `BITS_PER_WORD' a run-time load underneath it.
   MAX_BITS_PER_WORD is an ARRAY BOUND -- `expmed.h:105-171',
   `lower-subreg.h:35-37', `expmed.cc:128-129' and the gengtype output for
   `ada/utils.cc' -- eleven of them, all requiring a constant expression.

   This is the one real compile-time blocker in class (c), and it is invisible
   to a sweep of the class-(c) names themselves: nothing spells BITS_PER_WORD
   in a constant context, it is reached one level down through this line.  It
   is invisible a second way as well -- i386, the current primary, defines
   MAX_BITS_PER_WORD as a literal 64, so the fallback does not fire today and
   the redirection appears harmless.  Change the primary to a back end that
   omits it (aarch64 omits it) and eleven array bounds stop compiling.  */
#define MAX_BITS_PER_WORD_FROM_BITS_PER_WORD 1
#endif

#ifndef STACK_POINTER_OFFSET
#define STACK_POINTER_OFFSET    0
#endif

#ifndef LOCAL_REGNO
#define LOCAL_REGNO(REGNO)  0
#endif

#ifndef HONOR_REG_ALLOC_ORDER
#define HONOR_REG_ALLOC_ORDER 0
#endif

/* EXIT_IGNORE_STACK should be nonzero if, when returning from a function,
   the stack pointer does not matter.  The value is tested only in
   functions that have frame pointers.  */
#ifndef EXIT_IGNORE_STACK
#define EXIT_IGNORE_STACK 0
#endif

/* Assume that case vectors are not pc-relative.  */
#ifndef CASE_VECTOR_PC_RELATIVE
#define CASE_VECTOR_PC_RELATIVE 0
#endif

/* Force minimum alignment to be able to use the least significant bits
   for distinguishing descriptor addresses from code addresses.  */
#define FUNCTION_ALIGNMENT(ALIGN)					\
  (lang_hooks.custom_function_descriptors				\
   && targetm.calls.custom_function_descriptors > 0			\
   ? MAX ((ALIGN),						\
	  2 * targetm.calls.custom_function_descriptors * BITS_PER_UNIT)\
   : (ALIGN))

/* Assume that trampolines need function alignment.  */
#ifndef TRAMPOLINE_ALIGNMENT
#define TRAMPOLINE_ALIGNMENT FUNCTION_ALIGNMENT (FUNCTION_BOUNDARY)
#endif

/* Register mappings for target machines without register windows.  */
#ifndef INCOMING_REGNO
#define INCOMING_REGNO(N) (N)
#endif

#ifndef OUTGOING_REGNO
#define OUTGOING_REGNO(N) (N)
#endif

#ifndef SHIFT_COUNT_TRUNCATED
#define SHIFT_COUNT_TRUNCATED 0
#endif

#ifndef LEGITIMATE_PIC_OPERAND_P
#define LEGITIMATE_PIC_OPERAND_P(X) 1
#endif

#ifndef TARGET_MEM_CONSTRAINT
#define TARGET_MEM_CONSTRAINT 'm'
#endif

#ifndef REVERSIBLE_CC_MODE
#define REVERSIBLE_CC_MODE(MODE) 0
#endif

/* Biggest alignment supported by the object file format of this machine.  */
#ifndef MAX_OFILE_ALIGNMENT
#define MAX_OFILE_ALIGNMENT BIGGEST_ALIGNMENT
#endif

#ifndef FRAME_GROWS_DOWNWARD
#define FRAME_GROWS_DOWNWARD 0
#endif

#ifndef RETURN_ADDR_IN_PREVIOUS_FRAME
#define RETURN_ADDR_IN_PREVIOUS_FRAME 0
#endif

/* On most machines, the CFA coincides with the first incoming parm.  */
#ifndef ARG_POINTER_CFA_OFFSET
#define ARG_POINTER_CFA_OFFSET(FNDECL) \
  (FIRST_PARM_OFFSET (FNDECL) + crtl->args.pretend_args_size)
#endif

/* On most machines, we use the CFA as DW_AT_frame_base.  */
#ifndef CFA_FRAME_BASE_OFFSET
#define CFA_FRAME_BASE_OFFSET(FNDECL) 0
#endif

/* The offset from the incoming value of %sp to the top of the stack frame
   for the current function.  */
#ifndef INCOMING_FRAME_SP_OFFSET
#define INCOMING_FRAME_SP_OFFSET 0
#endif

#ifndef HARD_REGNO_NREGS_HAS_PADDING
#define HARD_REGNO_NREGS_HAS_PADDING(REGNO, MODE) 0
#define HARD_REGNO_NREGS_WITH_PADDING(REGNO, MODE) -1
#endif

#ifndef OUTGOING_REG_PARM_STACK_SPACE
#define OUTGOING_REG_PARM_STACK_SPACE(FNTYPE) 0
#endif

/* MAX_STACK_ALIGNMENT is the maximum stack alignment guaranteed by
   the backend.  MAX_SUPPORTED_STACK_ALIGNMENT is the maximum best
   effort stack alignment supported by the backend.  If the backend
   supports stack alignment, MAX_SUPPORTED_STACK_ALIGNMENT and
   MAX_STACK_ALIGNMENT are the same.  Otherwise, the incoming stack
   boundary will limit the maximum guaranteed stack alignment.  */
#ifdef MAX_STACK_ALIGNMENT
#define MAX_SUPPORTED_STACK_ALIGNMENT MAX_STACK_ALIGNMENT
#else
#define MAX_STACK_ALIGNMENT STACK_BOUNDARY
#define MAX_SUPPORTED_STACK_ALIGNMENT PREFERRED_STACK_BOUNDARY
#endif

#define SUPPORTS_STACK_ALIGNMENT (MAX_STACK_ALIGNMENT > STACK_BOUNDARY)

#ifndef LOCAL_ALIGNMENT
#define LOCAL_ALIGNMENT(TYPE, ALIGNMENT) ALIGNMENT
#endif

#ifndef STACK_SLOT_ALIGNMENT
#define STACK_SLOT_ALIGNMENT(TYPE,MODE,ALIGN) \
  ((TYPE) ? LOCAL_ALIGNMENT ((TYPE), (ALIGN)) : (ALIGN))
#endif

#ifndef LOCAL_DECL_ALIGNMENT
#define LOCAL_DECL_ALIGNMENT(DECL) \
  LOCAL_ALIGNMENT (TREE_TYPE (DECL), DECL_ALIGN (DECL))
#endif

#ifndef MINIMUM_ALIGNMENT
#define MINIMUM_ALIGNMENT(EXP,MODE,ALIGN) (ALIGN)
#endif

/* Alignment value for attribute ((aligned)).  */
#ifndef ATTRIBUTE_ALIGNED_VALUE
#define ATTRIBUTE_ALIGNED_VALUE BIGGEST_ALIGNMENT
#endif

/* For most ports anything that evaluates to a constant symbolic
   or integer value is acceptable as a constant address.  */
#ifndef CONSTANT_ADDRESS_P
#define CONSTANT_ADDRESS_P(X)   (CONSTANT_P (X) && GET_CODE (X) != CONST_DOUBLE)
#endif

#ifndef MAX_FIXED_MODE_SIZE
#define MAX_FIXED_MODE_SIZE MAX (BITS_PER_WORD * 2, 64)
#endif

/* Nonzero if structures and unions should be returned in memory.

   This should only be defined if compatibility with another compiler or
   with an ABI is needed, because it results in slower code.  */

#ifndef DEFAULT_PCC_STRUCT_RETURN
#define DEFAULT_PCC_STRUCT_RETURN 1
#endif

#ifndef PCC_BITFIELD_TYPE_MATTERS
#define PCC_BITFIELD_TYPE_MATTERS false
#endif

#ifndef INSN_SETS_ARE_DELAYED
#define INSN_SETS_ARE_DELAYED(INSN) false
#endif

#ifndef INSN_REFERENCES_ARE_DELAYED
#define INSN_REFERENCES_ARE_DELAYED(INSN) false
#endif

#ifndef NO_FUNCTION_CSE
#define NO_FUNCTION_CSE false
#endif

#ifndef HARD_REGNO_RENAME_OK
#define HARD_REGNO_RENAME_OK(FROM, TO) true
#endif

#ifndef EPILOGUE_USES
#define EPILOGUE_USES(REG) false
#endif

#ifndef ARGS_GROW_DOWNWARD
#define ARGS_GROW_DOWNWARD 0
#endif

#ifndef STACK_GROWS_DOWNWARD
#define STACK_GROWS_DOWNWARD 0
#endif

#ifndef STACK_PUSH_CODE
#if STACK_GROWS_DOWNWARD
#define STACK_PUSH_CODE PRE_DEC
#else
#define STACK_PUSH_CODE PRE_INC
#endif
#endif

/* Default value for flag_pie when flag_pie is initialized to -1:
   --enable-default-pie: Default flag_pie to -fPIE.
   --disable-default-pie: Default flag_pie to 0.
 */
#ifdef ENABLE_DEFAULT_PIE
# ifndef DEFAULT_FLAG_PIE
#  define DEFAULT_FLAG_PIE 2
# endif
#else
# define DEFAULT_FLAG_PIE 0
#endif

/* A multi-target compiler holds several back ends' state at once, so the
   this_target_* indirection must always be a real variable.  The !SWITCHABLE
   spelling is "#define this_target_X (&default_target_X)", which binds one
   back end's state at compile time -- precisely the class of baking this
   compiler exists to remove.  Force the switchable form for every target.

   Cost, accepted deliberately: the 37 back ends that did not set this lose
   the compile-time-constant address and gain a load through a pointer on
   every access to target-derived state.  That is a performance regression,
   not a correctness one.  The 8 back ends that already set it (i386, arm,
   aarch64, mips, rs6000, riscv, s390, loongarch) have shipped this path for
   years.

   Deliberately not "#ifndef": a back end must not be able to opt out.  */
#undef SWITCHABLE_TARGET
#define SWITCHABLE_TARGET 1

/* If the target supports integers that are wider than two
   HOST_WIDE_INTs on the host compiler, then the target should define
   TARGET_SUPPORTS_WIDE_INT and make the appropriate fixups.
   Otherwise the compiler really is not robust.  */
#ifndef TARGET_SUPPORTS_WIDE_INT
#define TARGET_SUPPORTS_WIDE_INT 0
#endif

#ifndef SHORT_IMMEDIATES_SIGN_EXTEND
#define SHORT_IMMEDIATES_SIGN_EXTEND 0
#endif

#ifndef WORD_REGISTER_OPERATIONS
#define WORD_REGISTER_OPERATIONS 0
#endif

#ifndef LOAD_EXTEND_OP
#define LOAD_EXTEND_OP(M) UNKNOWN
#endif

#ifndef INITIAL_FRAME_ADDRESS_RTX
#define INITIAL_FRAME_ADDRESS_RTX NULL
#endif

#ifndef SETUP_FRAME_ADDRESSES
#define SETUP_FRAME_ADDRESSES() do { } while (0)
#endif

#ifndef DYNAMIC_CHAIN_ADDRESS
#define DYNAMIC_CHAIN_ADDRESS(x) (x)
#endif

#ifndef FRAME_ADDR_RTX
#define FRAME_ADDR_RTX(x) (x)
#endif

#ifndef REVERSE_CONDITION
#define REVERSE_CONDITION(code, mode) reverse_condition (code)
#endif

#ifndef TARGET_PECOFF
#define TARGET_PECOFF 0
#endif

#ifndef TARGET_COFF
#define TARGET_COFF 0
#endif

#ifndef EH_RETURN_HANDLER_RTX
#define EH_RETURN_HANDLER_RTX NULL
#endif

#ifdef GCC_INSN_FLAGS_H
/* Dependent default target macro definitions

   This section of defaults.h defines target macros that depend on generated
   headers.  This is a bit awkward:  We want to put all default definitions
   for target macros in defaults.h, but some of the defaults depend on the
   HAVE_* flags defines of insn-flags.h.  But insn-flags.h is not always
   included by files that do include defaults.h.

   Fortunately, the default macro definitions that depend on the HAVE_*
   macros are also the ones that will only be used inside GCC itself, i.e.
   not in the gen* programs or in target objects like libgcc.

   Obviously, it would be best to keep this section of defaults.h as small
   as possible, by converting the macros defined below to target hooks or
   functions.
*/

/* The default branch cost is 1.  */
#ifndef BRANCH_COST
#define BRANCH_COST(speed_p, predictable_p) 1
#endif

/* If a memory-to-memory move would take MOVE_RATIO or more simple
   move-instruction sequences, we will do a cpymem or libcall instead.  */

#ifndef MOVE_RATIO
#if defined (HAVE_cpymemqi) || defined (HAVE_cpymemhi) || defined (HAVE_cpymemsi) || defined (HAVE_cpymemdi) || defined (HAVE_cpymemti)
#define MOVE_RATIO(speed) 2
#else
/* If we are optimizing for space (-Os), cut down the default move ratio.  */
#define MOVE_RATIO(speed) ((speed) ? 15 : 3)
#endif
#endif

/* If a clear memory operation would take CLEAR_RATIO or more simple
   move-instruction sequences, we will do a setmem or libcall instead.  */

#ifndef CLEAR_RATIO
#if defined (HAVE_setmemqi) || defined (HAVE_setmemhi) || defined (HAVE_setmemsi) || defined (HAVE_setmemdi) || defined (HAVE_setmemti)
#define CLEAR_RATIO(speed) 2
#else
/* If we are optimizing for space, cut down the default clear ratio.  */
#define CLEAR_RATIO(speed) ((speed) ? 15 :3)
#endif
#endif

/* If a memory set (to value other than zero) operation would take
   SET_RATIO or more simple move-instruction sequences, we will do a setmem
   or libcall instead.  */
#ifndef SET_RATIO
#define SET_RATIO(speed) MOVE_RATIO (speed)
#endif

/* Supply a default definition of STACK_SAVEAREA_MODE for emit_stack_save.
   Normally move_insn, so Pmode stack pointer.  */

#ifndef STACK_SAVEAREA_MODE
#define STACK_SAVEAREA_MODE(LEVEL) Pmode
#endif

/* Supply a default definition of STACK_SIZE_MODE for
   allocate_dynamic_stack_space.  Normally PLUS/MINUS, so word_mode.  */

#ifndef STACK_SIZE_MODE
#define STACK_SIZE_MODE word_mode
#endif

/* Whether to emit @gnu_unique_object symbols for symbols that must be unique
   across the whole process.  This needs a dynamic linker that honours
   STB_GNU_UNIQUE, so only the libc target headers that have it raise this
   (config/linux.h, config/gnu.h); everyone else gets 0.  */
#ifndef USE_GNU_UNIQUE_OBJECT
#define USE_GNU_UNIQUE_OBJECT 0
#endif

/* Nonzero if libvtv is available for the target, so -fvtable-verify can link
   against it.  Target headers for configurations that build libvtv raise this;
   the stock default was 0.  */
#ifndef ENABLE_VTABLE_VERIFY
#define ENABLE_VTABLE_VERIFY 0
#endif

/* Nonzero if the target's newlib was built with the "nano" formatted-IO
   variant, which msp430 needs for -mtiny-printf.  This used to mirror a newlib
   configure flag via --enable-newlib-nano-formatted-io.  */
#ifndef HAVE_NEWLIB_NANO_FORMATTED_IO
#define HAVE_NEWLIB_NANO_FORMATTED_IO 0
#endif

/* Assembler/linker capabilities that used to be frozen into auto-host.h by
   configure-time probes of one specific toolchain.  They are runtime values
   now; see target-caps.h.  Generators and target-library builds never consult
   them, and must not pull in compiler internals, so they are guarded out.  */
#if !defined (GENERATOR_FILE) && !defined (USED_FOR_TARGET)
#include "target-caps.h"
#undef HAVE_AS_LEB128
#define HAVE_AS_LEB128 (targ_caps.leb128)
#undef HAVE_AS_REF
#define HAVE_AS_REF (targ_caps.as_ref)
#undef HAVE_XCOFF_DWARF_EXTRAS
#define HAVE_XCOFF_DWARF_EXTRAS (targ_caps.xcoff_dwarf_extras)
#undef HAVE_AS_IX86_SAHF
#define HAVE_AS_IX86_SAHF (targ_caps.as_ix86_sahf)
#undef HAVE_AS_IX86_UD2
#define HAVE_AS_IX86_UD2 (targ_caps.as_ix86_ud2)
#undef HAVE_AS_IX86_FILDS
#define HAVE_AS_IX86_FILDS (targ_caps.as_ix86_filds)
#undef HAVE_AS_IX86_FILDQ
#define HAVE_AS_IX86_FILDQ (targ_caps.as_ix86_fildq)
#undef HAVE_AS_IX86_HLE
#define HAVE_AS_IX86_HLE (targ_caps.as_ix86_hle)
#undef HAVE_AS_IX86_REP_LOCK_PREFIX
#define HAVE_AS_IX86_REP_LOCK_PREFIX (targ_caps.as_ix86_rep_lock_prefix)
#undef HAVE_AS_IX86_FFREEP
#define HAVE_AS_IX86_FFREEP (targ_caps.as_ix86_ffreep)
#undef HAVE_AS_IX86_TLSGDPLT
#define HAVE_AS_IX86_TLSGDPLT (targ_caps.as_ix86_tlsgdplt)
#undef HAVE_AS_IX86_CMOV_SUN_SYNTAX
#define HAVE_AS_IX86_CMOV_SUN_SYNTAX (targ_caps.as_ix86_cmov_sun_syntax)
#undef HAVE_AS_GOTOFF_IN_DATA
#define HAVE_AS_GOTOFF_IN_DATA (targ_caps.as_gotoff_in_data)
#undef HAVE_AS_IX86_INTERUNIT_MOVQ
#define HAVE_AS_IX86_INTERUNIT_MOVQ (targ_caps.as_ix86_interunit_movq)
#undef HAVE_AS_IX86_GOT32X
#define HAVE_AS_IX86_GOT32X (targ_caps.as_ix86_got32x)
#undef HAVE_AS_IX86_TLS_GET_ADDR_GOT
#define HAVE_AS_IX86_TLS_GET_ADDR_GOT (targ_caps.as_ix86_tls_get_addr_got)
#undef HAVE_AS_R_X86_64_CODE_6_GOTTPOFF
#define HAVE_AS_R_X86_64_CODE_6_GOTTPOFF (targ_caps.as_r_x86_64_code_6_gottpoff)
#undef HAVE_AS_IX86_TLSLDMPLT
#define HAVE_AS_IX86_TLSLDMPLT (targ_caps.as_ix86_tlsldmplt)
#undef HAVE_AS_IX86_TLSLDM
#define HAVE_AS_IX86_TLSLDM (targ_caps.as_ix86_tlsldm)
#undef HAVE_AS_GNU_ATTRIBUTE
#define HAVE_AS_GNU_ATTRIBUTE (targ_caps.as_gnu_attribute)
#undef HAVE_AS_DSPR1_MULT
#define HAVE_AS_DSPR1_MULT (targ_caps.as_mips_dspr1_mult)
#undef HAVE_GAS_CFI_PERSONALITY_DIRECTIVE
#define HAVE_GAS_CFI_PERSONALITY_DIRECTIVE (targ_caps.cfi_personality)
#undef HAVE_GAS_CFI_SECTIONS_DIRECTIVE
#define HAVE_GAS_CFI_SECTIONS_DIRECTIVE (targ_caps.cfi_sections)
#undef HAVE_GAS_LOC_STMT
#define HAVE_GAS_LOC_STMT (targ_caps.gas_loc_stmt)
#undef HAVE_AS_LINE_ZERO
#define HAVE_AS_LINE_ZERO (targ_caps.as_line_zero)

/* The linker half, same treatment.  These were answered by probing one ld
   while GCC was configured; a compiler serving many toolchains has to ask at
   run time.  Each is #undef'd first because auto-host.h may still define it
   from a probe that has not been relocated yet, and the runtime answer must
   win.  Consumers that test them with #ifdef rather than #if have to become
   plain `if' -- the macro is always defined now, so an #ifdef is always
   true.  */
#undef HAVE_GAS_HIDDEN
#define HAVE_GAS_HIDDEN (targ_caps.gas_hidden)
#undef HAVE_LD_RO_RW_SECTION_MIXING
#define HAVE_LD_RO_RW_SECTION_MIXING (targ_caps.ld_ro_rw_section_mixing)
/* These two are tested in VALUE position by their consumers -- varasm.cc and
   dwarf2out.cc say `if (HAVE_GAS_SHF_MERGE && ...)', targhooks.cc says
   `if (HAVE_GAS_SECTION_LINK_ORDER)' -- because configure emitted them as 0/1
   rather than defined/undefined.  So the bridge converts them outright: there
   is no #ifdef anywhere to become vacuously true, and no source change needed.
   Checked, not assumed; these were the only uses in the tree.  */
#undef HAVE_GAS_SHF_MERGE
#define HAVE_GAS_SHF_MERGE (targ_caps.gas_shf_merge)
/* A target that defines ASM_OUTPUT_ALIGNED_LOCAL only when its assembler
   accepts an alignment operand on `.lcomm' redefines this to the matching
   targ_caps read; see i386/bsd.h.  Defaulted here rather than in the
   unconditional block below because a target header may set it first.  */
#ifndef ASM_OUTPUT_ALIGNED_LOCAL_P
#define ASM_OUTPUT_ALIGNED_LOCAL_P true
#endif
#undef HAVE_GAS_SECTION_LINK_ORDER
#define HAVE_GAS_SECTION_LINK_ORDER (targ_caps.gas_section_link_order)
#undef HAVE_LD_EH_GC_SECTIONS
#define HAVE_LD_EH_GC_SECTIONS (targ_caps.ld_eh_gc_sections)
#undef HAVE_LD_CTF
#define HAVE_LD_CTF (targ_caps.ld_ctf)
#undef HAVE_LD_SYSROOT
#define HAVE_LD_SYSROOT (targ_caps.ld_sysroot)
#undef HAVE_LD_AT_FILE
#define HAVE_LD_AT_FILE (targ_caps.ld_at_file)
#undef HAVE_LD_PIE_COPYRELOC
#define HAVE_LD_PIE_COPYRELOC (targ_caps.ld_pie_copyreloc)
#undef HAVE_LD_PERSONALITY_RELAXATION
#define HAVE_LD_PERSONALITY_RELAXATION (targ_caps.ld_personality_relaxation)
#undef HAVE_LD_NO_DOT_SYMS
#define HAVE_LD_NO_DOT_SYMS (targ_caps.ld_no_dot_syms)
#undef HAVE_LD_LARGE_TOC
#define HAVE_LD_LARGE_TOC (targ_caps.ld_large_toc)
#undef HAVE_LD_PPC_GNU_ATTR_LONG_DOUBLE
#define HAVE_LD_PPC_GNU_ATTR_LONG_DOUBLE (targ_caps.ld_ppc_attr)
#undef HAVE_LD_BROKEN_PE_DWARF5
#define HAVE_LD_BROKEN_PE_DWARF5 (targ_caps.ld_broken_pe_dwarf5)
#undef HAVE_LD_AVR_AVRXMEGA3_RODATA_IN_FLASH
#define HAVE_LD_AVR_AVRXMEGA3_RODATA_IN_FLASH \
  (targ_caps.ld_avr_avrxmega3_rodata_in_flash)
#undef HAVE_LD_AVR_AVRXMEGA2_FLMAP
#define HAVE_LD_AVR_AVRXMEGA2_FLMAP (targ_caps.ld_avr_avrxmega2_flmap)
#undef HAVE_LD_AVR_AVRXMEGA4_FLMAP
#define HAVE_LD_AVR_AVRXMEGA4_FLMAP (targ_caps.ld_avr_avrxmega4_flmap)
#undef HAVE_LD_PIE
#define HAVE_LD_PIE (targ_caps.ld_pie)
#undef HAVE_LD_NOW_SUPPORT
#define HAVE_LD_NOW_SUPPORT (targ_caps.ld_now)
#undef HAVE_LD_RELRO_SUPPORT
#define HAVE_LD_RELRO_SUPPORT (targ_caps.ld_relro)
/* Was 0/1/2; only "any plugin support at all" is distinguished now, and 2 is
   the value every caller compares against.  */
#undef HAVE_LTO_PLUGIN
#define HAVE_LTO_PLUGIN (targ_caps.lto_plugin ? 2 : 0)
#undef HAVE_LD_DEMANGLE
#define HAVE_LD_DEMANGLE (targ_caps.ld_demangle)

/* Not a flag but a byte count: the alignment the linker forces on .TOC..
   rs6000.cc supplies 8 when this is undefined, and the probe only ever chose
   between 8 and 4, so the flag selects between them.  */
#undef POWERPC64_TOC_POINTER_ALIGNMENT
#define POWERPC64_TOC_POINTER_ALIGNMENT (targ_caps.ld_toc_align ? 8 : 4)

/* Back-end assembler capabilities from the same sweep.  Each of these was an
   AC_DEFINE that only existed when its back end happened to be the configured
   target; every other build silently compiled the "assembler cannot do it"
   arm.  They are per-target answers now.

   NOTE FOR EVERY ONE OF THESE: the macro is now ALWAYS DEFINED, so a consumer
   written as `#ifdef' would take the true arm unconditionally, which is the
   exact opposite of the old silent-false.  Every consumer reached from here
   was converted to a run-time `if' or to a macro body; do not add an `#ifdef'
   consumer back.  */
#undef HAVE_AS_ENTRY_MARKERS
#define HAVE_AS_ENTRY_MARKERS (targ_caps.as_entry_markers)
#undef HAVE_AS_LTOFFX_LDXMOV_RELOCS
#define HAVE_AS_LTOFFX_LDXMOV_RELOCS (targ_caps.as_ltoffx_ldxmov_relocs)
#undef HAVE_AS_MFCRF
#define HAVE_AS_MFCRF (targ_caps.as_mfcrf)
#undef HAVE_AS_POWER10_HTM
#define HAVE_AS_POWER10_HTM (targ_caps.as_power10_htm)
#undef HAVE_AS_REL16
#define HAVE_AS_REL16 (targ_caps.as_rel16)
#undef HAVE_AS_PLTSEQ
#define HAVE_AS_PLTSEQ (targ_caps.as_pltseq)
#undef HAVE_AS_MSPABI_ATTRIBUTE
#define HAVE_AS_MSPABI_ATTRIBUTE (targ_caps.as_mspabi_attribute)
#undef HAVE_AS_MMACOSX_VERSION_MIN_OPTION
#define HAVE_AS_MMACOSX_VERSION_MIN_OPTION (targ_caps.as_mmacosx_version_min)
#undef HAVE_AS_MACOS_BUILD_VERSION
#define HAVE_AS_MACOS_BUILD_VERSION (targ_caps.as_macos_build_version)
#undef HAVE_GAS_LITERAL16
#define HAVE_GAS_LITERAL16 (targ_caps.gas_literal16)
#undef HAVE_GAS_NSUBSPA_COMDAT
#define HAVE_GAS_NSUBSPA_COMDAT (targ_caps.gas_nsubspa_comdat)
#undef HAVE_GAS_ARM_EXTENDED_ARCH
#define HAVE_GAS_ARM_EXTENDED_ARCH (targ_caps.gas_arm_extended_arch)
#undef HAVE_AS_SUPPORT_CALL36
#define HAVE_AS_SUPPORT_CALL36 (targ_caps.as_loongarch_support_call36)
#undef HAVE_AS_TLS_LE_RELAXATION
#define HAVE_AS_TLS_LE_RELAXATION (targ_caps.as_loongarch_tls_le_relaxation)
#undef HAVE_AS_16B_ATOMIC
#define HAVE_AS_16B_ATOMIC (targ_caps.as_loongarch_16b_atomic)
#undef HAVE_AS_EH_FRAME_PCREL_ENCODING_SUPPORT
#define HAVE_AS_EH_FRAME_PCREL_ENCODING_SUPPORT \
  (targ_caps.as_loongarch_eh_frame_pcrel_encoding)
#undef HAVE_AS_ARCHITECTURE_MODIFIERS
#define HAVE_AS_ARCHITECTURE_MODIFIERS (targ_caps.as_s390_architecture_modifiers)
#undef HAVE_AS_VECTOR_LOADSTORE_ALIGNMENT_HINTS
#define HAVE_AS_VECTOR_LOADSTORE_ALIGNMENT_HINTS \
  (targ_caps.as_s390_vector_loadstore_alignment_hints)
#undef HAVE_AS_VECTOR_LOADSTORE_ALIGNMENT_HINTS_ON_Z13
#define HAVE_AS_VECTOR_LOADSTORE_ALIGNMENT_HINTS_ON_Z13 \
  (targ_caps.as_s390_vector_loadstore_alignment_hints_on_z13)
#else
/* Target-library builds (USED_FOR_TARGET) have no targ_caps.

   THIS BRANCH DOES NOT SERVE GENERATORS, and it is worth saying so because it
   looks as though it should: the generated tm.h includes defaults.h only under
   `!GENERATOR_FILE', so a generator never reaches this file at all.  Whatever
   a generator needs has to be defined in the target header it does include --
   there are `#if defined (GENERATOR_FILE)' blocks to that effect in rs6000.h,
   ia64.h, s390.h, pa/som.h and loongarch/loongarch-opts.h, each naming this
   one.  Adding a name here and expecting build/gencondmd*.o to pick it up is
   the mistake this paragraph exists to stop; the build failure it produces
   names the .md line, not this file.

   THE VALUE IS 0, AND FOR THE GENERATOR COPIES THAT IS A KNOWN GAP, NOT A FIX.
   gencondmd pre-evaluates any insn condition it can fold to a constant, so an
   insn whose condition is `HAVE_AS_PLTSEQ && TARGET_ELF' is deleted at BUILD
   time and the run-time capability never reaches it.  That is exactly what the
   old floors did, so nothing regresses -- but as_pltseq, as_rel16 and
   as_loongarch_tls_le_relaxation are per-target only in the C++ that reads
   them, and still build-time constants in the insn conditions.  Closing that
   needs gencondmd to see a NON-constant, which the target-caps carrier does
   not offer a generator today.  */
#define HAVE_AS_ENTRY_MARKERS 0
#define HAVE_AS_LTOFFX_LDXMOV_RELOCS 0
#define HAVE_AS_MFCRF 0
#define HAVE_AS_POWER10_HTM 0
#define HAVE_AS_REL16 0
#define HAVE_AS_PLTSEQ 0
#define HAVE_AS_MSPABI_ATTRIBUTE 0
#define HAVE_AS_MMACOSX_VERSION_MIN_OPTION 0
#define HAVE_AS_MACOS_BUILD_VERSION 0
#define HAVE_GAS_LITERAL16 0
#define HAVE_GAS_NSUBSPA_COMDAT 0
#define HAVE_GAS_ARM_EXTENDED_ARCH 0
#define HAVE_AS_SUPPORT_CALL36 0
#define HAVE_AS_TLS_LE_RELAXATION 0
#define HAVE_AS_16B_ATOMIC 0
#define HAVE_AS_EH_FRAME_PCREL_ENCODING_SUPPORT 0
#define HAVE_AS_ARCHITECTURE_MODIFIERS 0
#define HAVE_AS_VECTOR_LOADSTORE_ALIGNMENT_HINTS 0
#define HAVE_AS_VECTOR_LOADSTORE_ALIGNMENT_HINTS_ON_Z13 0
#endif

/* How this linker spells "link the following statically" and "back to
   dynamic", and whether it can do so at all, used to be defaulted here as
   LD_STATIC_OPTION / LD_DYNAMIC_OPTION / HAVE_LD_STATIC_DYNAMIC.  All three are
   gone: they are `targ_caps.ld_static_option' and `.ld_dynamic_option' now, with
   targ_ld_static_dynamic () derived from the pair rather than stored beside it,
   so the spelling and the "has it at all" answer cannot disagree.

   A macro was the wrong shape for a second reason.  These reach the driver
   through TWO consumers -- spec text and the C code of the seven language
   driver programs -- and gcc.cc includes no tm.h, so this header had to keep a
   duplicate set for it.  Two defaults for one value is how they drift.  */

/* Nonzero if the target object format has COMDAT groups (ELF section groups,
   or the Sun as `.group' spelling of them).  ELF targets define this to 1 in
   config/elfos.h; PE/COFF and Mach-O leave it 0 and fall back to
   .gnu.linkonce / one-only semantics.  */
#ifndef HAVE_COMDAT_GROUP
#define HAVE_COMDAT_GROUP 0
#endif

/* Nonzero if the target C library provides stack protector support, i.e. it
   defines __stack_chk_fail (and __stack_chk_guard, or a TLS slot holding the
   canary), so the driver need not link -lssp.  Target headers for libcs that
   provide it define this to 1.  */
#ifndef TARGET_LIBC_PROVIDES_SSP
#define TARGET_LIBC_PROVIDES_SSP 0
#endif

/* Default value for flag_stack_protect when flag_stack_protect is initialized to -1:
   --enable-default-ssp: Default flag_stack_protect to -fstack-protector-strong.
   --disable-default-ssp: Default flag_stack_protect to 0.
 */
#ifdef ENABLE_DEFAULT_SSP
# ifndef DEFAULT_FLAG_SSP
#  define DEFAULT_FLAG_SSP 3
# endif
#else
# define DEFAULT_FLAG_SSP 0
#endif

/* Provide default values for the macros controlling stack checking.  */

/* The default is neither full builtin stack checking...  */
#ifndef STACK_CHECK_BUILTIN
#define STACK_CHECK_BUILTIN 0
#endif

/* ...nor static builtin stack checking.  */
#ifndef STACK_CHECK_STATIC_BUILTIN
#define STACK_CHECK_STATIC_BUILTIN 0
#endif

/* The default interval is one page (4096 bytes).  */
#ifndef STACK_CHECK_PROBE_INTERVAL_EXP
#define STACK_CHECK_PROBE_INTERVAL_EXP 12
#endif

/* The default is not to move the stack pointer.  */
#ifndef STACK_CHECK_MOVING_SP
#define STACK_CHECK_MOVING_SP 0
#endif

/* This is a kludge to try to capture the discrepancy between the old
   mechanism (generic stack checking) and the new mechanism (static
   builtin stack checking).  STACK_CHECK_PROTECT needs to be bumped
   for the latter because part of the protection area is effectively
   included in STACK_CHECK_MAX_FRAME_SIZE for the former.  */
#ifdef STACK_CHECK_PROTECT
#define STACK_OLD_CHECK_PROTECT STACK_CHECK_PROTECT
#else
#define STACK_OLD_CHECK_PROTECT						\
 (!global_options.x_flag_exceptions					\
  ? 75 * UNITS_PER_WORD							\
  : targetm_common->except_unwind_info (&global_options) == UI_SJLJ	\
    ? 4 * 1024								\
    : 8 * 1024)
#endif

/* Minimum amount of stack required to recover from an anticipated stack
   overflow detection.  The default value conveys an estimate of the amount
   of stack required to propagate an exception.  */
#ifndef STACK_CHECK_PROTECT
#define STACK_CHECK_PROTECT						\
 (!global_options.x_flag_exceptions					\
  ? 4 * 1024								\
  : targetm_common->except_unwind_info (&global_options) == UI_SJLJ	\
    ? 8 * 1024								\
    : 12 * 1024)
#endif

/* Make the maximum frame size be the largest we can and still only need
   one probe per function.  */
#ifndef STACK_CHECK_MAX_FRAME_SIZE
#define STACK_CHECK_MAX_FRAME_SIZE \
  ((1 << STACK_CHECK_PROBE_INTERVAL_EXP) - UNITS_PER_WORD)
#endif

/* This is arbitrary, but should be large enough everywhere.  */
#ifndef STACK_CHECK_FIXED_FRAME_SIZE
#define STACK_CHECK_FIXED_FRAME_SIZE (4 * UNITS_PER_WORD)
#endif

/* Provide a reasonable default for the maximum size of an object to
   allocate in the fixed frame.  We may need to be able to make this
   controllable by the user at some point.  */
#ifndef STACK_CHECK_MAX_VAR_SIZE
#define STACK_CHECK_MAX_VAR_SIZE (STACK_CHECK_MAX_FRAME_SIZE / 100)
#endif

/* By default, the C++ compiler will use function addresses in the
   vtable entries.  Setting this nonzero tells the compiler to use
   function descriptors instead.  The value of this macro says how
   many words wide the descriptor is (normally 2).  It is assumed
   that the address of a function descriptor may be treated as a
   pointer to a function.  */
#ifndef TARGET_VTABLE_USES_DESCRIPTORS
#define TARGET_VTABLE_USES_DESCRIPTORS 0
#endif

#endif /* GCC_INSN_FLAGS_H  */

#ifndef DWARF_GNAT_ENCODINGS_DEFAULT
#define DWARF_GNAT_ENCODINGS_DEFAULT DWARF_GNAT_ENCODINGS_GDB
#endif

/* When generating dwarf info, the default standard version we'll honor
   and advertise in absence of -gdwarf-<N> on the command line.  */
#ifndef DWARF_VERSION_DEFAULT
#define DWARF_VERSION_DEFAULT 5
#endif

#ifndef USED_FOR_TARGET
/* Done this way to keep gengtype happy.  */
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

/* Maximum length of COLLECT_GCC_OPTIONS before the driver spills it
   to a response file.  Hosts with tighter limits may override this.  */
#ifndef COLLECT2_OPTIONS_MAX_LENGTH
#define COLLECT2_OPTIONS_MAX_LENGTH 1024
#endif

/* ------------------------------------------------------------------------
   (c-DATA): REDIRECT THE CONFIG-INVARIANT TARGET MACROS TO PER-CONFIG SLOTS.

   This block is LAST in defaults.h on purpose, and defaults.h is included at
   the end of every tm header, so by here every back end's definition and every
   fallback above has been made.  What is redirected is therefore the final
   answer for the primary base -- which is exactly the answer that must stop
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
#undef DWARF_FRAME_RETURN_COLUMN
#define DWARF_FRAME_RETURN_COLUMN (targetm_cdata.dwarf_frame_return_column)

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

   `STACK_SAVEAREA_MODE' above expands to `Pmode' for a base that defines no
   such macro, and is defined EARLIER in this file, so it picks this up by
   ordinary macro expansion -- the redirect being last is what makes that
   work rather than a coincidence.  */
#undef Pmode
#define Pmode (mt_pmode ())

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
   `.to_constant ()` when `NUM_POLY_INT_COEFFS > 1'.  That wrapper exists
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

#endif  /* ! GCC_DEFAULTS_H */
