/* Per-back-end C-family target entry points.
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

/* WHAT THIS IS

   Two target macros are invoked as STATEMENTS from translation units that are
   compiled once for the whole compiler:

     c-family/c-cppbuiltin.cc   TARGET_CPU_CPP_BUILTINS ()
     c-family/c-pragma.cc       REGISTER_TARGET_PRAGMAS ()

   Both expand to a call into the back end -- `ix86_target_macros ()' and
   `ix86_register_pragmas ()' for i386, `aarch64_cpu_cpp_builtins ()' and
   `aarch64_register_pragmas ()' for aarch64 -- so a shared TU that expands
   them holds a hard reference to ONE back end's function, whichever back end
   the shared tm.h happens to be.  Measured in a x86_64 + aarch64 build:
   `c-family/c-cppbuiltin.o' has undefined references to `ix86_target_macros'
   and `ix86_arch_features', and `c-family/c-pragma.o' to
   `ix86_register_pragmas', in a compiler that also serves aarch64.  cc1
   selecting aarch64 therefore ran i386's TARGET_CPU_CPP_BUILTINS and died
   inside `ix86_target_macros_internal'.

   HOOK, NOT CAPABILITY.  These are static per-target behaviour that ships with
   the back end: the answer cannot differ between two installations of the same
   compiler serving the same target, so this is a target hook and not a
   `target-specs' probe.

   The shape is the one already used for `target_asm_ops' and the (c-DATA)
   refresh: one small translation unit compiled once per back end against that
   back end's tm-<base>.h, exporting a table under a per-base symbol, plus a
   registry generated from multi-target.manifest and a pointer chosen by
   multi_target_select.  Nothing is unioned; the vocabulary is shared and the
   datum is per base.

   The macros stay macros.  They are invoked as statements rather than read on
   a `#if' line, so there is a run-time route, and the per-base TU is where
   they are expanded -- the only place that sees the right tm.h.  */

#ifndef GCC_TARGET_C_OPS_H
#define GCC_TARGET_C_OPS_H

struct cpp_reader;

struct target_c_ops
{
  /* TARGET_CPU_CPP_BUILTINS ().  PFILE is passed rather than left to the
     macro's habit of reading a variable called `pfile' from its caller's
     scope, so that the wrapper does not depend on that spelling.  */
  void (*cpu_cpp_builtins) (struct cpp_reader *pfile);

  /* REGISTER_TARGET_PRAGMAS (), or a no-op for a back end that defines no
     such macro.  Which of the two it is, is a property of the back end and is
     decided where the back end's own tm.h is visible.  */
  void (*register_pragmas) (void);
};

struct target_c_ops_entry
{
  const char *name;
  const struct target_c_ops *ops;
};

/* NULL until multi_target_select installs one.  Deliberately not initialised
   to the primary's table: with no target selected there is no answer, and
   answering with whichever base linked first is the bug this branch exists to
   remove.  */
extern const struct target_c_ops *targetm_c_ops;

/* The table for BASE, or NULL if this compiler has none for it.  */
extern const struct target_c_ops *target_c_ops_for (const char *base);

/* The two call sites above go through these, which fail BY NAME rather than
   returning quietly when no target has been selected.  */
extern void target_c_cpu_cpp_builtins (struct cpp_reader *pfile);
extern void target_c_register_pragmas (void);

#endif /* GCC_TARGET_C_OPS_H */
