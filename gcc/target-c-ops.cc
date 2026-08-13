/* One back end's C-family target entry points.
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

/* Compiled once per back end.  gen-multi-target-md.awk gives this translation
   unit `-I<base>-inc', so the plain `tm.h' and `tm_p.h' below are THAT back
   end's, and `-DTARGET_C_OPS_SYMBOL=targetm_c_ops_<base>' so that all of them
   can be linked into one compiler.  See target-c-ops.h for why.

   On the include path: this file lives in $(srcdir), which contains neither
   `tm.h' nor `tm_p.h', so the quoted includes cannot be answered by the
   directory of the including file and `-I<base>-inc' -- which INCLUDES puts
   ahead of `-I.' -- decides them.  That is the same trap the generated
   per-base sources are copied into mt-<base>/ to avoid, and it does not bite
   here only because of where this file sits.  Do not move it into the build
   root.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
/* This source is compiled once per configured back end, so it names the back
   end's headers rather than relying on -I<base>-inc.  See
   multi-target-base.h.  */
#include "multi-target-base.h"
#include BASE_HEADER (tm.h)

/* WHAT `REGISTER_TARGET_PRAGMAS' IS ALLOWED TO NAME, and why these three
   includes are not decoration AND WHY THEY SIT BEFORE `tm_p.h'.

   This function used to be expanded in `c-family/c-pragma.cc', which includes
   `tree.h', `target.h' and `c-pragma.h'.  Moving the expansion here without
   them worked for i386 and aarch64 only because BOTH of those back ends
   expand to a single call to a function their own `tm_p.h' declares
   (`ix86_register_pragmas ()', `aarch64_register_pragmas ()').  rs6000's
   expansion is a four-statement body, and every one of its four names came
   from somewhere else:

     c_register_pragma			c-family/c-pragma.h
     targetm				target.h  (spelled targetm_<base> here)
     rs6000_pragma_target_parse		rs6000-protos.h, but only #ifdef TREE_CODE
     altivec_resolve_overloaded_builtin	likewise

   The last two are the interesting pair, and they are why ORDER is
   load-bearing rather than a matter of taste: `tm_p.h' WAS included, and
   still declared neither, because the declarations sit behind
   `#ifdef TREE_CODE' and nothing had included `tree.h' YET.  Adding
   `#include "tree.h"' *after* `tm_p.h' changed nothing at all -- the guard
   had already been evaluated and taken the false arm, silently, because
   `#ifdef' on an undefined name does not error.  A guarded declaration
   quietly absent is the `rs6000_gnu_attr' shape.

   Nine other in-tree back ends have multi-statement expansions of this macro,
   so this is not an rs6000 peculiarity -- it is the general case, which a
   two-back-end build could not show.  */
#include "tree.h"
#include "target.h"
#include "c-family/c-pragma.h"

#include BASE_HEADER (tm_p.h)

#include "target-c-ops.h"

#ifndef TARGET_C_OPS_SYMBOL
#error target-c-ops.cc must be compiled with -DTARGET_C_OPS_SYMBOL=targetm_c_ops_<base>
#endif

/* TARGET_CPU_CPP_BUILTINS is invoked as a STATEMENT, not read on a `#if'
   line, so it has a run-time route -- and this is the only translation unit
   that sees the right tm.h to expand it in.

   The macro traditionally reads a variable spelled `pfile' out of its caller's
   scope (aarch64's expansion is literally `aarch64_cpu_cpp_builtins (pfile)'),
   which is why the parameter here is named `pfile' and not something tidier.
   Renaming it would break every back end whose expansion mentions it, silently
   for the ones whose expansion does not.  */

static void
mt_cpu_cpp_builtins (struct cpp_reader *pfile ATTRIBUTE_UNUSED)
{
  TARGET_CPU_CPP_BUILTINS ();
}

/* Most back ends define REGISTER_TARGET_PRAGMAS; some do not.  Which it is, is
   a fact about the back end, and this is where that back end's tm.h is
   visible, so the `#ifdef' belongs HERE rather than at the shared call site in
   c-family/c-pragma.cc -- where it would have been answered by whichever tm.h
   the shared build happened to use.  A back end without the macro gets a table
   entry that does nothing, which is its real answer and not a fallback.  */

static void
mt_register_pragmas (void)
{
#ifdef REGISTER_TARGET_PRAGMAS
  REGISTER_TARGET_PRAGMAS ();
#endif
}

/* `extern' is load-bearing.  A namespace-scope `const' object has INTERNAL
   linkage in C++, so without it this table is invisible to the selector and
   the only symptom is an undefined reference from target-c-ops-select.o -- in
   an object file that was built, and looks built.  */
extern const struct target_c_ops TARGET_C_OPS_SYMBOL;
extern const struct target_c_ops TARGET_C_OPS_SYMBOL = {
  mt_cpu_cpp_builtins,
  mt_register_pragmas
};
