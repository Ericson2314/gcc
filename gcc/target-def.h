/* Default initializers for a generic GCC target.
   Copyright (C) 2001-2026 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by the
   Free Software Foundation; either version 3, or (at your option) any
   later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; see the file COPYING3.  If not see
   <http://www.gnu.org/licenses/>.

   In other words, you are welcome to use, share and improve this program.
   You are forbidden to forbid anyone else to use, share and improve
   what you give them.   Help stamp out software-hoarding!  */

/* See target.def for a description of what this file contains and how to
   use it.

   We want to have non-NULL default definitions of all hook functions,
   even if they do nothing.  */

/* Note that if one of these macros must be defined in an OS .h file
   rather than the .c file, then we need to wrap the default
   definition in a #ifndef, since files include tm.h before this one.  */

#define TARGET_ASM_ALIGNED_HI_OP "\t.short\t"
#define TARGET_ASM_ALIGNED_SI_OP "\t.long\t"
#define TARGET_ASM_ALIGNED_DI_OP NULL
#define TARGET_ASM_ALIGNED_TI_OP NULL

/* GAS and SYSV4 assemblers accept these.  */
#if defined (OBJECT_FORMAT_ELF)
#define TARGET_ASM_UNALIGNED_HI_OP "\t.2byte\t"
#define TARGET_ASM_UNALIGNED_SI_OP "\t.4byte\t"
#define TARGET_ASM_UNALIGNED_DI_OP "\t.8byte\t"
#define TARGET_ASM_UNALIGNED_TI_OP NULL
#else
#define TARGET_ASM_UNALIGNED_HI_OP NULL
#define TARGET_ASM_UNALIGNED_SI_OP NULL
#define TARGET_ASM_UNALIGNED_DI_OP NULL
#define TARGET_ASM_UNALIGNED_TI_OP NULL
#endif /* OBJECT_FORMAT_ELF */

/* There is no standard way to handle P{S,D,T}Imode, targets must implement them
   if required.  */
#define TARGET_ASM_ALIGNED_PSI_OP NULL
#define TARGET_ASM_UNALIGNED_PSI_OP NULL
#define TARGET_ASM_ALIGNED_PDI_OP NULL
#define TARGET_ASM_UNALIGNED_PDI_OP NULL
#define TARGET_ASM_ALIGNED_PTI_OP NULL
#define TARGET_ASM_UNALIGNED_PTI_OP NULL

#if !defined(TARGET_ASM_CONSTRUCTOR) && !defined(USE_COLLECT2)
# ifdef CTORS_SECTION_ASM_OP
#  define TARGET_ASM_CONSTRUCTOR default_ctor_section_asm_out_constructor
# else
#  ifdef TARGET_ASM_NAMED_SECTION
#   define TARGET_ASM_CONSTRUCTOR default_named_section_asm_out_constructor
#  else
#   define TARGET_ASM_CONSTRUCTOR default_asm_out_constructor
#  endif
# endif
#endif

#if !defined(TARGET_ASM_DESTRUCTOR) && !defined(USE_COLLECT2)
# ifdef DTORS_SECTION_ASM_OP
#  define TARGET_ASM_DESTRUCTOR default_dtor_section_asm_out_destructor
# else
#  ifdef TARGET_ASM_NAMED_SECTION
#   define TARGET_ASM_DESTRUCTOR default_named_section_asm_out_destructor
#  else
#   define TARGET_ASM_DESTRUCTOR default_asm_out_destructor
#  endif
# endif
#endif

#if !defined(TARGET_HAVE_CTORS_DTORS)
# if defined(TARGET_ASM_CONSTRUCTOR) && defined(TARGET_ASM_DESTRUCTOR)
# define TARGET_HAVE_CTORS_DTORS true
# endif
#endif

#ifndef TARGET_TERMINATE_DW2_EH_FRAME_INFO
#ifdef EH_FRAME_SECTION_NAME
#define TARGET_TERMINATE_DW2_EH_FRAME_INFO false
#endif
#endif

#if !defined(TARGET_ASM_OUTPUT_ANCHOR) && !defined(ASM_OUTPUT_DEF)
#define TARGET_ASM_OUTPUT_ANCHOR NULL
#endif

#define TARGET_ASM_ALIGNED_INT_OP				\
		       {TARGET_ASM_ALIGNED_HI_OP,		\
			TARGET_ASM_ALIGNED_PSI_OP,		\
			TARGET_ASM_ALIGNED_SI_OP,		\
			TARGET_ASM_ALIGNED_PDI_OP,		\
			TARGET_ASM_ALIGNED_DI_OP,		\
			TARGET_ASM_ALIGNED_PTI_OP,		\
			TARGET_ASM_ALIGNED_TI_OP}

#define TARGET_ASM_UNALIGNED_INT_OP				\
		       {TARGET_ASM_UNALIGNED_HI_OP,		\
			TARGET_ASM_UNALIGNED_PSI_OP,		\
			TARGET_ASM_UNALIGNED_SI_OP,		\
			TARGET_ASM_UNALIGNED_PDI_OP,		\
			TARGET_ASM_UNALIGNED_DI_OP,		\
			TARGET_ASM_UNALIGNED_PTI_OP,		\
			TARGET_ASM_UNALIGNED_TI_OP}

#if !defined (TARGET_FUNCTION_INCOMING_ARG)
#define TARGET_FUNCTION_INCOMING_ARG TARGET_FUNCTION_ARG
#endif

/* Carry the target's ASM_OUTPUT_EXTERNAL into
   targetm.asm_out.output_external.  varasm.cc is compiled once for the whole
   compiler, so it cannot read ASM_OUTPUT_EXTERNAL directly without baking one
   target's answer into every target; targetm, by contrast, is instantiated per
   back end.  This file is included only by the config/<cpu>/<cpu>.cc that
   instantiates targetm, and after tm.h, so the macro already has its final
   value (several OS headers, e.g. config/rx/linux.h, #undef and redefine it).  */
#if defined (ASM_OUTPUT_EXTERNAL) && !defined (TARGET_ASM_OUTPUT_EXTERNAL)
static void
target_def_output_external (FILE *stream ATTRIBUTE_UNUSED,
			    tree decl ATTRIBUTE_UNUSED,
			    const char *name ATTRIBUTE_UNUSED)
{
  ASM_OUTPUT_EXTERNAL (stream, decl, name);
}
#define TARGET_ASM_OUTPUT_EXTERNAL target_def_output_external
#endif

/* Same bridge, for the alias/weak family.  These six travel together on
   purpose: ASM_OUTPUT_DEF and ASM_WEAKEN_DECL select mutually exclusive
   branches of do_assemble_alias, so converting one without the other would
   leave the middle end dispatching at run time into a branch that had been
   compiled out.  Leaving a hook NULL is the signal that the target has no such
   directive, which is how TARGET_ASM_OUTPUT_ANCHOR already works below.  */

#if defined (ASM_OUTPUT_DEF) && !defined (TARGET_ASM_OUTPUT_DEF)
static void
target_def_output_def (FILE *stream ATTRIBUTE_UNUSED,
		       const char *name ATTRIBUTE_UNUSED,
		       const char *value ATTRIBUTE_UNUSED)
{
  ASM_OUTPUT_DEF (stream, name, value);
}
#define TARGET_ASM_OUTPUT_DEF target_def_output_def
#endif

#if defined (ASM_OUTPUT_DEF_FROM_DECLS) && !defined (TARGET_ASM_OUTPUT_DEF_FROM_DECLS)
static void
target_def_output_def_from_decls (FILE *stream ATTRIBUTE_UNUSED,
				  tree decl ATTRIBUTE_UNUSED,
				  tree target ATTRIBUTE_UNUSED)
{
  ASM_OUTPUT_DEF_FROM_DECLS (stream, decl, target);
}
#define TARGET_ASM_OUTPUT_DEF_FROM_DECLS target_def_output_def_from_decls
#endif

#if defined (ASM_WEAKEN_DECL) && !defined (TARGET_ASM_WEAKEN_DECL)
static void
target_def_weaken_decl (FILE *stream ATTRIBUTE_UNUSED,
			tree decl ATTRIBUTE_UNUSED,
			const char *name ATTRIBUTE_UNUSED,
			const char *value ATTRIBUTE_UNUSED)
{
  ASM_WEAKEN_DECL (stream, decl, name, value);
}
#define TARGET_ASM_WEAKEN_DECL target_def_weaken_decl
#endif

#if defined (ASM_WEAKEN_LABEL) && !defined (TARGET_ASM_WEAKEN_LABEL)
static void
target_def_weaken_label (FILE *stream ATTRIBUTE_UNUSED,
			 const char *name ATTRIBUTE_UNUSED)
{
  ASM_WEAKEN_LABEL (stream, name);
}
#define TARGET_ASM_WEAKEN_LABEL target_def_weaken_label
#endif

#if defined (ASM_OUTPUT_WEAK_ALIAS) && !defined (TARGET_ASM_OUTPUT_WEAK_ALIAS)
static void
target_def_output_weak_alias (FILE *stream ATTRIBUTE_UNUSED,
			      const char *name ATTRIBUTE_UNUSED,
			      const char *value ATTRIBUTE_UNUSED)
{
  ASM_OUTPUT_WEAK_ALIAS (stream, name, value);
}
#define TARGET_ASM_OUTPUT_WEAK_ALIAS target_def_output_weak_alias
#endif

/* Only nvptx defines TARGET_SUPPORTS_ALIASES (a run-time test on -malias);
   every other target leaves it to the default, which asks output_def.  */
#if defined (TARGET_SUPPORTS_ALIASES) && !defined (TARGET_ASM_SUPPORTS_ALIASES)
static bool
target_def_supports_aliases (void)
{
  return TARGET_SUPPORTS_ALIASES;
}
#define TARGET_ASM_SUPPORTS_ALIASES target_def_supports_aliases
#endif

/* nvptx and i386 Cygwin/MinGW define TARGET_USE_LOCAL_THUNK_ALIAS_P.  */
#if defined (TARGET_USE_LOCAL_THUNK_ALIAS_P) \
    && !defined (TARGET_ASM_USE_LOCAL_THUNK_ALIAS_P)
static bool
target_def_use_local_thunk_alias_p (tree decl ATTRIBUTE_UNUSED)
{
  return TARGET_USE_LOCAL_THUNK_ALIAS_P (decl);
}
#define TARGET_ASM_USE_LOCAL_THUNK_ALIAS_P target_def_use_local_thunk_alias_p
#endif

/* Carry the target's stack-register file into targetm.stack_regs.  STACK_REGS,
   FIRST_STACK_REG, LAST_STACK_REG and STACK_REG_P are a single family -- only
   i386 defines any of them, and none of them is guarded independently -- so
   they have to become runtime data together or not at all.  STACK_REG_P is not
   bridged: it is derived from the range (see stack_reg_range::includes_p).

   Same reasoning as for TARGET_POINTERS_EXTEND_KIND below: this belongs in
   target-def.h rather than defaults.h, because defaults.h is included at the
   end of tm.h and would therefore win.  */
#if defined (STACK_REGS) && !defined (TARGET_STACK_REGS)
static struct stack_reg_range
target_def_stack_regs (void)
{
  return { FIRST_STACK_REG, LAST_STACK_REG };
}
#define TARGET_STACK_REGS target_def_stack_regs
#endif

/* Carry the target's POINTERS_EXTEND_UNSIGNED into
   targetm.pointers_extend_kind.  The middle-end files that used to read the
   macro (explow.cc, expr.cc, except.cc, emit-rtl.cc, ...) are compiled once for
   the whole compiler, so they cannot read it directly without baking one back
   end's answer into every target.

   Note that the macro's *absence* is a fourth state, distinct from any of its
   values, and is what PTR_EXTEND_NONE records.  Collapsing it onto
   PTR_EXTEND_SIGN (value 0) or PTR_EXTEND_ZERO (value 1) would silently change
   the extension sign on the ~32 targets that do not define the macro.

   This bridge belongs here rather than in defaults.h: defaults.h is included at
   the end of tm.h, i.e. *before* target-def.h, so a definition there would win
   and this wrapper would never run.  Never have both.  */
#if defined (POINTERS_EXTEND_UNSIGNED) && !defined (TARGET_POINTERS_EXTEND_KIND)
static enum ptr_extend_kind
target_def_pointers_extend_kind (void)
{
  return ((POINTERS_EXTEND_UNSIGNED) > 0 ? PTR_EXTEND_ZERO
	  : (POINTERS_EXTEND_UNSIGNED) < 0 ? PTR_EXTEND_INSN
	  : PTR_EXTEND_SIGN);
}
#define TARGET_POINTERS_EXTEND_KIND target_def_pointers_extend_kind
#endif

/* Declare a target attribute table called NAME that only has GNU attributes.
   There should be no null trailing element.  E.g.:

     TARGET_GNU_ATTRIBUTES (aarch64_attribute_table,
     {
       { "aarch64_vector_pcs", ... },
       ...
     });  */

#define TARGET_GNU_ATTRIBUTES(NAME, ...) \
  static const attribute_spec NAME##_2[] = __VA_ARGS__; \
  static const scoped_attribute_specs NAME##_1 = { "gnu", { NAME##_2 } }; \
  static const scoped_attribute_specs *const NAME[] = { &NAME##_1 }

/* Must precede target-hooks-def.h: it supplies TARGET_ASM_GLOBAL_OP and the
   TARGET_ASM_*_SECTION_ASM_OP family by wrapping each tm.h macro in a
   function, and target-hooks-def.h only fills in a default where the hook is
   not already defined.  */
#include "target-asm-ops.h"

#include "target-hooks-def.h"

#include "hooks.h"
#include "targhooks.h"
#include "insn-target-def.h"
