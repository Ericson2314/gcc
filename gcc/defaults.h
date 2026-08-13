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
#if defined (MULTI_TARGET_TARGETM_BASE) || defined (GENERATOR_FILE)	\
    || defined (MULTI_TARGET_SUPPLY_TU) || defined (MULTI_TARGET_REG_PROBE)
/* A back end's own translation unit, a build-time generator, or another
   supply-side TU: keep the real macros.  */
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
#endif

#endif  /* ! GCC_DEFAULTS_H */
