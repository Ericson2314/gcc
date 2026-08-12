/* One back end's argument-accumulator entry points, in its own headers.
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

/* Compiled once per back end, with `-I<base>-inc' so every header it reaches
   is that back end's.  The SUPPLY side of target-cumargs.h; see that file for
   why five macros and why not a `target.def' hook.

   Two things happen here that can happen nowhere else:

     * the five macros are expanded in the translation unit whose `tm.h' is
       this back end's, so `INIT_CUMULATIVE_ARGS' means `aarch64_init_
       cumulative_args' for aarch64 and `init_cumulative_args' for i386;

     * `sizeof' and `alignof' of THIS back end's `CUMULATIVE_ARGS' are
       measured and checked against the union bound.  That check is the
       acceptance bar of the whole change: a base that outgrows the bound is
       a compile error naming this file and this base, rather than 88 bytes
       written past the end of a stack frame.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#include "rtl.h"
#include "tree.h"
#include "memmodel.h"
/* For the back end's own declaration of whatever INIT_CUMULATIVE_ARGS
   expands to -- `aarch64_init_cumulative_args' is declared in
   aarch64-protos.h, which is this base's tm_p.h.  */
#include "tm_p.h"
#include "target.h"
#include "multi-target-reg-widths.h"
#include "target-cumargs.h"

/* NO APOSTROPHE IN EITHER MESSAGE.  An unpaired quote in a #error draws a
   "missing terminating character" warning on top of the error -- target-regs.cc
   has one and it shows up in every build -- and this branch measures stderr.  */
#ifndef MULTI_TARGET_TARGETM_BASE
#error target-cumargs.cc must be compiled for one particular back end (it needs \
the real INIT_CUMULATIVE_ARGS of that base, not the one belonging to whichever \
base compiled the middle end)
#endif

#ifndef TARGETM_CUMARGS_SYMBOL
#error target-cumargs.cc must be compiled with -DTARGETM_CUMARGS_SYMBOL naming \
the table for this back end
#endif

/* THE BOUND, CHECKED.  These two are why the file is worth having even for a
   back end that defines none of the optional macros.

   `<=' and not `==': the bound is the maximum over the configured bases, so
   every base but the largest is strictly under it.  The largest sits exactly
   AT it, with no slack, deliberately -- the same shape as the `9 <= 9' pair
   `52fa9e763c5' left in optc-save-gen.awk.  A bound with slack would hide the
   next base that grows.  */
static_assert ((int) sizeof (CUMULATIVE_ARGS)
	       <= MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE,
	       "this back end's CUMULATIVE_ARGS is bigger than the union bound "
	       "in multi-target-reg-widths.h, so shared code would allocate "
	       "too little for it; gen-reg-widths.sh did not see this base");
static_assert ((int) alignof (CUMULATIVE_ARGS)
	       <= MULTI_TARGET_UNION_CUMULATIVE_ARGS_ALIGN,
	       "this back end's CUMULATIVE_ARGS needs stricter alignment than "
	       "the union bound in multi-target-reg-widths.h; "
	       "gen-reg-widths.sh did not see this base");

static void
mt_base_init_args (cumulative_args_t ca, tree fntype, rtx libname,
		   tree fndecl, int n_named_args)
{
  INIT_CUMULATIVE_ARGS (*get_cumulative_args (ca), fntype, libname, fndecl,
			n_named_args);
}

/* function.cc's `#ifdef INIT_CUMULATIVE_INCOMING_ARGS' / `#else', answered by
   this base rather than by the primary.  Both arms are upstream's, unchanged.  */
static void
mt_base_init_incoming_args (cumulative_args_t ca, tree fntype, rtx libname)
{
#ifdef INIT_CUMULATIVE_INCOMING_ARGS
  INIT_CUMULATIVE_INCOMING_ARGS (*get_cumulative_args (ca), fntype, libname);
#else
  INIT_CUMULATIVE_ARGS (*get_cumulative_args (ca), fntype, libname,
			current_function_decl, -1);
#endif
}

/* calls.cc's `#ifdef INIT_CUMULATIVE_LIBCALL_ARGS' / `#else', likewise.  */
static void
mt_base_init_libcall_args (cumulative_args_t ca, machine_mode outmode, rtx fun,
			   int nargs ATTRIBUTE_UNUSED)
{
#ifdef INIT_CUMULATIVE_LIBCALL_ARGS
  INIT_CUMULATIVE_LIBCALL_ARGS (*get_cumulative_args (ca), outmode, fun);
#else
  (void) outmode;
  INIT_CUMULATIVE_ARGS (*get_cumulative_args (ca), NULL_TREE, fun, 0, nargs);
#endif
}

/* calls.cc's `#ifdef CALL_POPS_ARGS'.  The 0 is what the absent `#ifdef' arm
   already contributed for every back end but i386; it is this base's answer,
   not a fallback to another base's.  */
static int
mt_base_call_pops_args (cumulative_args_t ca ATTRIBUTE_UNUSED)
{
#ifdef CALL_POPS_ARGS
  return CALL_POPS_ARGS (*get_cumulative_args (ca));
#else
  return 0;
#endif
}

/* `allocate_struct_function's `#ifdef OVERRIDE_ABI_FORMAT'.  This is the one
   the aarch64 arm dies on today: function.cc is compiled against i386's tm.h,
   so `ix86_call_abi_override' runs for every function of every target.  */
static void
mt_base_override_abi_format (tree fndecl ATTRIBUTE_UNUSED)
{
#ifdef OVERRIDE_ABI_FORMAT
  OVERRIDE_ABI_FORMAT (fndecl);
#endif
}

#define MT_STR1(X) #X
#define MT_STR(X) MT_STR1 (X)

/* `extern' is not redundant: a namespace-scope `const' object has INTERNAL
   linkage in C++, so without it the table is built correctly and then cannot
   be named from the registry.  target-regs.cc records the same lesson.

   Not `constexpr', unlike target-regs.cc's: this table's members are function
   addresses, which are constant, but writing `constexpr' here would buy
   nothing -- there is no macro expansion in the initialiser that could
   quietly become option-dependent.  */
extern const struct target_cumargs_desc TARGETM_CUMARGS_SYMBOL;
const struct target_cumargs_desc TARGETM_CUMARGS_SYMBOL = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  (unsigned long) sizeof (CUMULATIVE_ARGS),
  (unsigned long) alignof (CUMULATIVE_ARGS),
  mt_base_init_args,
  mt_base_init_incoming_args,
  mt_base_init_libcall_args,
  mt_base_call_pops_args,
  mt_base_override_abi_format
};
