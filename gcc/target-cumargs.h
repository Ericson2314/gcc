/* Per-back-end argument-accumulator entry points: who WRITES a CUMULATIVE_ARGS.
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

/* THE OTHER HALF OF mt-cumulative-args.h, AND IT IS A DIFFERENT BUG.

   mt-cumulative-args.h makes the STORAGE big enough for every configured
   back end.  This file decides WHO WRITES IT.  Both are needed and neither is
   useful alone:

     * bound without routing -- aarch64 code is compiled by calling i386's
       `init_cumulative_args', in bounds, with no diagnostic.  That is worse
       than the crash it replaces, because it looks like the arm passing.

     * routing without bound -- aarch64's `aarch64_init_cumulative_args'
       writes its 184-byte struct into the primary's 96-byte storage.  Same
       overflow, tidier route.

   FIVE MACROS, ALL OF THEM WRITES OR PREDICATES ABOUT THE ACCUMULATOR.
   `INIT_CUMULATIVE_ARGS' and its two variants initialise one;
   `CALL_POPS_ARGS' reads one; `OVERRIDE_ABI_FORMAT' is here because it is the
   OTHER thing `allocate_struct_function' does to the ABI state of a function
   being created, it is expanded three lines from the accumulator work, and it
   is where the aarch64 arm actually crashes today (`ix86_call_abi_override'
   called for an aarch64 function).  Leaving it out would have made this
   change unobservable on the only target that can show it working.

   THREE OF THE FIVE ARE EXISTENCE PREDICATES AND THEY STAY THAT WAY -- but
   in the per-back-end translation unit, which is the only place that can
   answer them.  `INIT_CUMULATIVE_INCOMING_ARGS' (5 back ends define it),
   `INIT_CUMULATIVE_LIBCALL_ARGS' (2), `CALL_POPS_ARGS' (1) and
   `OVERRIDE_ABI_FORMAT' (1) are `#ifdef'd in shared code today, i.e. answered
   by the PRIMARY for everybody.  target-cumargs.cc keeps each `#ifdef'
   exactly where it was but compiles it once per base, so "this back end
   defines no INIT_CUMULATIVE_INCOMING_ARGS" becomes that back end's own
   answer instead of the primary's.  The upstream `#else' arm moves with it
   unchanged; nothing acquires a default it did not already have.

   This is deliberately NOT a `target.def' hook.  A hook would be ~5 new
   entries in every one of 48 back ends' `TARGET_INITIALIZER's, and the values
   here are settled by the back end's own headers, which is what
   target-regs.cc, target-addr.cc and target-c-ops.cc are all already for.  */

#ifndef GCC_TARGET_CUMARGS_H
#define GCC_TARGET_CUMARGS_H

#include "mt-cumulative-args.h"
#include "target-frame.h"
#include "target-insn.h"
#include "target-preds.h"
#include "target-attr.h"
#include "target-modeswitch.h"
#include "target-sched.h"
#include "target-asmfprintf.h"
#include "target-automata.h"

/* Hand union-bounded storage to a back end.  `cumulative_args_t' is `void *'
   plus a token (target.h), so nothing about the LAYOUT crosses here -- which
   is exactly what lets one bound serve every base, and is the answer to "does
   anything read the storage back through a differently-shaped view".  Only
   the back end that wrote it ever sees a shape.

   This lives here rather than in mt-cumulative-args.h because that header is
   reached from emit-rtl.h, long before target.h.

   A DISTINCT NAME rather than an overload of `pack_cumulative_args', because
   an overload makes `pack_cumulative_args (NULL)' -- which calls.cc:976 spells
   for `pass_va_arg_by_reference' -- ambiguous, and the obvious repair is a
   cast to `CUMULATIVE_ARGS *' in shared code, i.e. putting back the one thing
   this change removes.  */
inline cumulative_args_t
mt_pack_cumulative_args (struct mt_cumulative_args *arg)
{
  cumulative_args_t ret;

#if CHECKING_P
  ret.magic = CUMULATIVE_ARGS_MAGIC;
#endif
  ret.p = (void *) arg->mt_raw;
  return ret;
}

/* One back end's accumulator entry points.

   Every function pointer takes `cumulative_args_t', never `CUMULATIVE_ARGS *'.
   That is not style: `CUMULATIVE_ARGS' is a different type -- and therefore a
   different mangled name -- in every back end, so a `CUMULATIVE_ARGS *'
   parameter here would make this table's type mean something different in
   each translation unit that names it.  calls.h:133 records the link failure
   that lesson came from.  */
struct target_cumargs_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* THIS BASE'S OWN `sizeof' and `alignof' of CUMULATIVE_ARGS, measured in
     its own translation unit.  Both are <= the MULTI_TARGET_UNION_* bounds in
     multi-target-reg-widths.h and target-cumargs.cc static_asserts exactly
     that; they are carried at run time so that a diagnostic can name the
     base and the two numbers rather than say "something is too big".  */
  unsigned long own_size;
  unsigned long own_align;

  /* INIT_CUMULATIVE_ARGS.  */
  void (*init_args) (cumulative_args_t, tree fntype, rtx libname,
		     tree fndecl, int n_named_args);

  /* INIT_CUMULATIVE_INCOMING_ARGS, or this base's INIT_CUMULATIVE_ARGS with
     N_NAMED_ARGS = -1 where it defines no such macro -- which is what
     function.cc's `#else' arm has always done, moved to where the `#ifdef'
     can be answered per base.  */
  void (*init_incoming_args) (cumulative_args_t, tree fntype, rtx libname);

  /* INIT_CUMULATIVE_LIBCALL_ARGS, or this base's INIT_CUMULATIVE_ARGS with
     (NULL_TREE, fun, 0, nargs); calls.cc's `#else' arm, likewise.  NARGS is
     passed for that arm's sake and is unused by the macro itself.  */
  void (*init_libcall_args) (cumulative_args_t, machine_mode outmode,
			     rtx fun, int nargs);

  /* CALL_POPS_ARGS, or 0 for a base that defines none.  Exactly one back end
     (i386) defines it, and the 0 is the value calls.cc's `#ifdef' already
     contributed for everyone else -- it is this base's own answer, not a
     fallback to the primary's.  */
  int (*call_pops_args) (cumulative_args_t);

  /* OVERRIDE_ABI_FORMAT, or nothing.  Same shape as CALL_POPS_ARGS: one back
     end defines it, and doing nothing is what `allocate_struct_function' has
     always done for the others.  */
  void (*override_abi_format) (tree fndecl);

  /* THIS BASE'S FRAME AND ARGUMENT-REGISTER ANSWERS; see target-frame.h, which
     also explains why they ride here instead of in a registry of their own.
     Never null: the per-base translation unit that defines this table defines
     that one immediately above it.  */
  const struct target_frame_desc *frame;

  /* THIS BASE'S INSN-PATTERN EXISTENCE ANSWERS; see target-insn.h.  Rides
     here for the same reason `frame' does, and is never null for the same
     reason: the per-base translation unit that defines this table defines
     that one too.  */
  const struct target_insn_desc *insn;

  /* THIS BASE'S CONSTRAINT VOCABULARY; see target-preds.h.  Rides here for
     the same reason `frame' and `insn' do, and is never null for the same
     reason: the per-base translation unit that defines this table defines
     that one too.  */
  const struct target_preds_desc *preds;

  /* THIS BASE'S INSN-ATTRIBUTE ENTRY POINTS; see target-attr.h.  Rides here
     for the same reason `frame', `insn' and `preds' do, and is never null for
     the same reason: the per-base translation unit that defines this table
     defines that one too.  */
  const struct target_attr_desc *attr;

  /* THIS BASE'S MODE-SWITCHING ENTITY LIST; see target-modeswitch.h.  Rides
     here for the same reason `frame', `insn', `preds' and `attr' do, and is
     never null for the same reason: the per-base translation unit that
     defines this table defines that one too.  A back end that does no mode
     switching supplies a table saying so, which is not the same thing as
     supplying no table.  */
  const struct target_modeswitch_desc *modeswitch;

  /* THIS BASE'S SCHEDULER-ATTRIBUTE INITIALISER; see target-sched.h.  Rides
     here for the same reason the four above do, and is never null for the
     same reason.  */
  const struct target_sched_desc *sched;

  /* THIS BASE'S `asm_fprintf' FORMAT EXTENSIONS; see target-asmfprintf.h.
     Rides here for the same reason the five above do, and is never null for
     the same reason: the per-base translation unit that defines this table
     defines that one too.  A back end with no extensions supplies a table
     saying so, which is not the same thing as supplying no table.  */
  const struct target_asmfprintf_desc *asmfprintf;

  /* THIS BASE'S DFA PIPELINE-HAZARD ENTRY POINTS; see target-automata.h.
     Rides here for the same reason the six above do, and is never null for
     the same reason.  A back end with no automaton supplies a table saying
     `has_dfa == false', which is not the same thing as supplying no table.  */
  const struct target_automata_desc *automata;
};

/* One entry per configured back end, so a table can be found by name.  */
struct target_cumargs_entry
{
  const char *name;
  const struct target_cumargs_desc *cumargs;
};

extern const struct target_cumargs_entry targetm_cumargs_registry[];

/* The entry points in force.

   NULL until a target is selected, for the reason target-regs.h gives at
   length: pre-pointing this at the primary would compile every target's
   arguments with i386's argument-passing state, correctly on the build
   machine and wrongly everywhere else, with no diagnostic.  */
extern const struct target_cumargs_desc *targetm_cumargs;

/* Look BASE up in the registry, or NULL.  BASE is a cpu_type.  */
extern const struct target_cumargs_desc *target_cumargs_for (const char *base);

/* The shared-code spellings.  These replace INIT_CUMULATIVE_ARGS and friends
   in target-independent code; a back end's own translation unit keeps the
   real macros, exactly as it keeps the real FIRST_PSEUDO_REGISTER.  */
extern void mt_init_cumulative_args (cumulative_args_t, tree, rtx, tree, int);
extern void mt_init_cumulative_incoming_args (cumulative_args_t, tree, rtx);
extern void mt_init_cumulative_libcall_args (cumulative_args_t, machine_mode,
					     rtx, int);
extern int mt_call_pops_args (cumulative_args_t);
extern void mt_override_abi_format (tree);

#endif /* GCC_TARGET_CUMARGS_H */
