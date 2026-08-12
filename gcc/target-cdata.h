/* Per-configuration target data -- the (c-DATA) scalars.
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

   A group of target macros are not constants and not code either: they are
   values that are FIXED once the target configuration and the command line are
   known.  `SIZE_TYPE' on i386 is `(TARGET_LP64 ? "long unsigned int" : ...)';
   `UNITS_PER_WORD' is `(TARGET_64BIT ? 8 : 4)'.  They read option state, and
   option state is settled at the end of option processing.

   MACRO-LEAK.md classified these as class (c) -- "no value to union" -- and
   concluded a union could not reach them.  That is right about a union and
   wrong about the consequence: they need no hook and no call either.  They
   need ONE SLOT PER SELECTED CONFIGURATION, written once from the selected
   base's own expression, read under a target-neutral name as a single load.

   Nothing is unioned.  Class (b) unions one value ACROSS bases and hopes it is
   safe for all of them -- that is why `FIRST_PSEUDO_REGISTER' at 95 is a
   landmine.  Here the vocabulary is shared and the datum is per-config.

   THE INVARIANCE CLAIM, WHICH IS MEASURED AND IS NOT UNIVERSAL

   The whole cheap path rests on "settled after option processing, and it does
   not change again".  That was the load-bearing unmeasured claim of
   CLASS-C-DESIGN.md 8, and it has since been measured dynamically -- 35
   candidate macros read in a plugin at PLUGIN_ALL_PASSES_START, after
   `targetm.set_current_function', over 269 functions covering the i386
   target-attribute vocabulary plus `#pragma GCC target', 9415 rows, both
   controls asserted (`MOVE_MAX' must say VARIES, `BYTES_BIG_ENDIAN' must say
   invariant).

   29 of the 35 are invariant.  SIX ARE NOT, and they must never be added to
   this struct: `BIGGEST_ALIGNMENT', `STACK_BOUNDARY', `STORE_MAX_PIECES',
   `MOVE_MAX', `MOVE_MAX_PIECES', `COMPARE_MAX_PIECES'.  Five are the AVX width
   family; `STACK_BOUNDARY' varies through `TARGET_64BIT_MS_ABI' ->
   `ix86_cfun_abi ()', i.e. it reads `cfun', and belongs on the paying side
   with a real call.  A macro placed here that is NOT invariant is frozen at
   the value the command line gave it and stops responding to
   `__attribute__((target))', with no diagnostic at all -- so the measurement
   is a precondition for adding a field, not a nice-to-have.

   Do not size this from `options-save.cc' either.  The write set of
   `cl_target_option_restore' contains `ix86_move_max' and `ix86_cmodel', but
   `move-max=' and `cmodel=' are not valid target-attribute arguments, so a
   static read of that file answers VARIES for macros that do not.  It is wrong
   in the expensive direction.  */

#ifndef GCC_TARGET_CDATA_H
#define GCC_TARGET_CDATA_H

/* The poison an unrefreshed slot holds.

   The alternative -- initialising these with the PRIMARY's values so that
   something is always readable -- is precisely the bug this branch exists to
   remove: it would make a missed refresh behave correctly on the build machine
   and wrongly everywhere else.  A read before `init_targetm_cdata ()' must not
   be able to masquerade as an answer, so it yields a string no assembler and
   no front end will accept, naming itself.  */
#define TARGET_CDATA_POISON_STR "<target-cdata read before refresh>"

struct target_cdata
{
  const char *asm_comment_start;
  const char *wchar_type;
  const char *size_type;
  const char *ptrdiff_type;
};

/* One entry per configured back end.  The entry holds a FUNCTION, not a table:
   the values depend on option state, so they cannot be a constant-initialised
   struct the way `target_asm_ops' is.  target-asm-ops.cc uses `constexpr'
   precisely to REJECT an option-dependent initialiser; here option dependence
   is the normal case, so the shape has to be a function evaluated after
   options are decoded.  */
struct target_cdata_entry
{
  const char *name;
  void (*refresh) (struct target_cdata *);
};

extern const struct target_cdata_entry targetm_cdata_registry[];

/* The values in force.  A plain object, not a pointer: the point of this
   mechanism is that a use site is ONE LOAD, and a pointer would make it two.  */
extern struct target_cdata targetm_cdata;

/* The refresh function in force.  Selected by `multi_target_select'.  */
extern void (*targetm_cdata_refresh) (struct target_cdata *);

/* Look BASE up in the registry, or NULL.  */
extern void (*target_cdata_refresh_for (const char *base)) (struct target_cdata *);

/* Fill `targetm_cdata' from the selected base.  Must run after option
   processing -- see the invariance note above -- and before anything reads a
   redirected macro.  toplev.cc calls it immediately after
   `targetm.target_option.override ()'.  */
extern void init_targetm_cdata (void);

#endif /* GCC_TARGET_CDATA_H */
