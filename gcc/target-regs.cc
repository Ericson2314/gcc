/* One back end's register vocabulary, measured in its own headers.
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
   is that back end's, and with -DTARGETM_REGS_SYMBOL naming its table.  This
   is the SUPPLY side of the redirection in defaults.h; see target-regs.h for
   what the three different numbers are and why.

   Same shape and the same reason as target-addr.cc: zero back ends are
   edited, zero macros are deleted, and no target.def entry is added.  The
   six data macros are plain macros in config/<cpu>/<cpu>.h, so evaluating
   them in a translation unit that has that back end's headers is the whole
   fix.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
/* This source is compiled once per configured back end, so it names the back
   end's headers rather than relying on -I<base>-inc.  See
   multi-target-base.h.  */
#include "multi-target-base.h"
#include BASE_HEADER (tm.h)
/* REGNO_REG_CLASS is not arithmetic on every back end: aarch64's is
   `aarch64_regno_regclass (REGNO)', declared in aarch64-protos.h, which is
   this base's own tm_p.h.  rtl.h first, exactly as target-addr.cc has it.  */
#include "backend.h"
#include "target.h"
#include "rtl.h"
#include "tree.h"
#include "df.h"
#include "memmodel.h"
#include BASE_HEADER (tm_p.h)
#include BASE_HEADER (insn-config.h)
/* For the four `sizeof's that witness the shared layout.  This include list is
   reginfo.cc's, deliberately: the CONSUMER side of the layout check computes
   its four `sizeof's after exactly these headers, and a witness taken after a
   different set is not a witness.  ira-int.h in particular reaches
   `bitmap_head' and `recog', neither of which target-addr.cc's shorter list
   provides.  */
#include "regs.h"
#include "ira.h"
#include "recog.h"
#include "ira-int.h"
/* `target_rtl' comes with rtl.h above.  These two are the other structures
   target-globals.cc allocates that have a register-indexed field; reginfo.cc,
   whose include list this one mirrors, already has reload.h.  A witness taken
   after a different set of headers is not a witness, so both sides must name
   the same ones.  */
#include "builtins.h"
#include "reload.h"
#include "target-regs.h"

#ifndef MULTI_TARGET_TARGETM_BASE
#error target-regs.cc must be compiled for a particular back end (it needs \
that base's real six register macros, not the primary's)
#endif

#ifndef TARGETM_REGS_SYMBOL
#error target-regs.cc must be compiled with -DTARGETM_REGS_SYMBOL naming \
this back end's table
#endif

/* THE OWN WIDTHS.  This is a back end's own translation unit, so defaults.h
   left FIRST_PSEUDO_REGISTER and N_REG_CLASSES meaning what THIS back end's
   headers say -- which is exactly the property the file exists for, and is
   why it must carry -DMULTI_TARGET_TARGETM_BASE.  The union widths are still
   needed, for the two bounds checks below, and are named explicitly.  */
#define OWN_FIRST_PSEUDO_REGISTER FIRST_PSEUDO_REGISTER
#define OWN_N_REG_CLASSES	  N_REG_CLASSES
#define OWN_N_REG_INTS		  ((OWN_FIRST_PSEUDO_REGISTER + 31) / 32)

/* Every array below is UNSIZED, so the initialiser decides its length and the
   static_asserts compare that length against the count this file reports.
   Writing `[OWN_FIRST_PSEUDO_REGISTER]' instead would make a back end whose
   FIXED_REGISTERS has the wrong number of entries compile silently with a
   zero tail -- which is precisely the failure mode (a register that is not
   fixed because nobody said it was) that has no diagnostic anywhere
   downstream.  */
static const char mt_fixed_regs[] = FIXED_REGISTERS;
static_assert (ARRAY_SIZE (mt_fixed_regs) == (size_t) OWN_FIRST_PSEUDO_REGISTER,
	       "FIXED_REGISTERS does not have FIRST_PSEUDO_REGISTER entries");

#ifdef CALL_REALLY_USED_REGISTERS
#ifdef CALL_USED_REGISTERS
#error CALL_USED_REGISTERS and CALL_REALLY_USED_REGISTERS are both defined
#endif
static const char mt_call_used_regs[] = CALL_REALLY_USED_REGISTERS;
#else
static const char mt_call_used_regs[] = CALL_USED_REGISTERS;
#endif
static_assert (ARRAY_SIZE (mt_call_used_regs)
	       == (size_t) OWN_FIRST_PSEUDO_REGISTER,
	       "CALL_USED_REGISTERS does not have FIRST_PSEUDO_REGISTER entries");

/* THE ONE ARRAY THAT IS SIZED RATHER THAN COUNTED, AND aarch64 IS WHY.

   `aarch64.h:1699' is `#define REG_ALLOC_ORDER {}' -- an EMPTY initialiser,
   with `ADJUST_REG_ALLOC_ORDER' (`aarch64_adjust_reg_alloc_order ()') filling
   the order in later.  Unsized, that is a zero-length array, and the
   ARRAY_SIZE assertion the other five arrays get would reject a perfectly
   legal back end.  reginfo.cc has always written this one with an explicit
   `[FIRST_PSEUDO_REGISTER]' bound and relied on the zero fill, so this
   matches it exactly.

   The consequence is that this array alone has no length check, which is
   worth stating rather than leaving as an omission: a REG_ALLOC_ORDER with
   too FEW entries is indistinguishable here from aarch64's deliberate none,
   and the tail is zeros either way.  reginfo.cc's tail fence turns the
   phantom-register part of that into the identity; the rest is the back end's
   own business, exactly as upstream.  */
#ifdef REG_ALLOC_ORDER
static const int mt_reg_alloc_order[OWN_FIRST_PSEUDO_REGISTER]
  = REG_ALLOC_ORDER;
#endif

/* ADJUST_REG_ALLOC_ORDER is a STATEMENT, not a function name -- i386 spells it
   `x86_order_regs_for_local_alloc ()' and nds32 spells it
   `nds32_adjust_reg_alloc_order ()' -- so it is wrapped rather than named.
   Evaluating it here is the whole point: this translation unit has THIS back
   end's headers, so the statement is this back end's.  */
#ifdef ADJUST_REG_ALLOC_ORDER
static void
mt_adjust_reg_alloc_order (void)
{
  ADJUST_REG_ALLOC_ORDER;
}
#endif

/* REG_CLASS_CONTENTS is written as `{ {..}, {..} }' with a row per class, and
   the row width is the back end's own N_REG_INTS -- 32 bits per element, hard
   coded at 32 rather than HOST_BITS_PER_INT, exactly as reginfo.cc has always
   had it.  Flattened to one dimension in the descriptor so that the header
   needs no width.  */
static const unsigned mt_reg_class_contents[][OWN_N_REG_INTS]
  = REG_CLASS_CONTENTS;
static_assert (ARRAY_SIZE (mt_reg_class_contents)
	       == (size_t) OWN_N_REG_CLASSES,
	       "REG_CLASS_CONTENTS does not have N_REG_CLASSES rows");

static const char *const mt_reg_names[] = REGISTER_NAMES;
static_assert (ARRAY_SIZE (mt_reg_names) == (size_t) OWN_FIRST_PSEUDO_REGISTER,
	       "REGISTER_NAMES does not have FIRST_PSEUDO_REGISTER entries");

/* `>=' AND NOT `==', AND THE ASYMMETRY WITH THE TWO ASSERTIONS ABOVE IS
   DELIBERATE RATHER THAN SLOPPY.

   The invariant that matters is that every class in `0 .. N_REG_CLASSES-1'
   has a name, because that is the whole range anything indexes this table
   with.  `==' additionally forbids a TRAILING entry, and three in-tree back
   ends have one: h8300, mn10300 and v850 all end `REG_CLASS_NAMES' with
   `"LIM_REGS"', a name for the `LIM_REG_CLASSES' sentinel, which is not a
   class and is never indexed.  Upstream never noticed because upstream only
   ever reads indices below `N_REG_CLASSES'.

   So this is not a check being weakened to make a build pass -- the check
   was asserting something upstream does not guarantee, and the direction
   that can actually hurt (FEWER names than classes, i.e. an out-of-bounds
   read of `reg_class_names') is still caught, by name, at the back end that
   has it.  `REG_CLASS_CONTENTS' and `REGISTER_NAMES' keep `==': no
   configured back end has a trailing row in either, so there is nothing
   there for the stricter form to be wrong about, and a `==' that has never
   fired is worth more than a `>=' that cannot.  */
static const char *const mt_reg_class_names[] = REG_CLASS_NAMES;
static_assert (ARRAY_SIZE (mt_reg_class_names) >= (size_t) OWN_N_REG_CLASSES,
	       "REG_CLASS_NAMES has FEWER than N_REG_CLASSES entries");

/* These are what the union COSTS, checked rather than assumed.  A back end
   configured into a build whose union widths are smaller than its own would
   overflow every one of the structures in target-globals.cc, silently.  The
   generated header cannot be wrong about this unless gen-reg-widths.sh missed
   a base -- which is exactly the failure this catches, by name, at the base
   it missed.  */
static_assert (OWN_FIRST_PSEUDO_REGISTER
	       <= MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER,
	       "this back end has more hard registers than the union width; "
	       "gen-reg-widths.sh did not see it");
static_assert (OWN_N_REG_CLASSES <= MULTI_TARGET_UNION_N_REG_CLASSES,
	       "this back end has more register classes than the union width; "
	       "gen-reg-widths.sh did not see it");
/* This translation unit is exempt from the defaults.h redirects, so these two
   are THIS back end's own; the caller-save tables are sized by the maximum
   over the configured bases.  See multi-target-reg-probe.cc.  */
static_assert (MAX_MOVE_MAX / MIN_UNITS_PER_WORD + 1
	       <= MULTI_TARGET_UNION_REGNO_SAVE_MODE_COLS,
	       "this back end needs more caller-save mode columns than the "
	       "union width; gen-reg-widths.sh did not see it");

/* NO_REGS is 0 in all 52 back ends -- checked textually over every
   config/<cpu>/<cpu>.h declaring `enum reg_class' -- and reginfo.cc and ira.cc seed
   their subunion and superunion tables by memset-to-zero, which is only
   meaningful if 0 is the empty class.  Assert it rather than rely on it.  */
static_assert ((int) NO_REGS == 0, "NO_REGS is not class 0 in this back end");

/* REGNO_REG_CLASS, fenced.  See the comment on the field in target-regs.h:
   generic code walks to the UNION width, so this is asked about register
   numbers that do not exist here, and i386's REGNO_REG_CLASS is a bare array
   subscript.  */
static int
mt_regno_reg_class (int regno)
{
  if (regno < 0 || regno >= OWN_FIRST_PSEUDO_REGISTER)
    return (int) NO_REGS;
  return (int) REGNO_REG_CLASS (regno);
}

#define MT_STR1(X) #X
#define MT_STR(X) MT_STR1 (X)

/* `extern' is not redundant and `constexpr' is not decoration; both are the
   lessons target-asm-ops.cc records.  A namespace-scope `const' object has
   INTERNAL linkage in C++, so without `extern' the table is built correctly
   and then cannot be named, and the registry fails to link against all of
   them at once.  And C++ accepts a non-constant namespace-scope initialiser
   by emitting a static constructor -- which would run before options are
   decoded -- so `constexpr' is what turns a back end whose ALL_REGS or
   GENERAL_REGS is somehow option-dependent into a compile error naming that
   back end, instead of a table quietly frozen at the default flags.  */
extern const struct target_regs_desc TARGETM_REGS_SYMBOL;
constexpr struct target_regs_desc TARGETM_REGS_SYMBOL = {
  MT_STR (MULTI_TARGET_TARGETM_BASE),
  OWN_N_REG_CLASSES,
  OWN_FIRST_PSEUDO_REGISTER,
  OWN_N_REG_INTS,
  (int) ALL_REGS,
  (int) GENERAL_REGS,
  mt_fixed_regs,
  mt_call_used_regs,
#ifdef REG_ALLOC_ORDER
  mt_reg_alloc_order,
#else
  NULL,
#endif
#ifdef ADJUST_REG_ALLOC_ORDER
  mt_adjust_reg_alloc_order,
#else
  NULL,
#endif
  &mt_reg_class_contents[0][0],
  mt_reg_names,
  mt_reg_class_names,
  sizeof (struct target_hard_regs),
  sizeof (struct target_regs),
  sizeof (struct target_ira),
  sizeof (struct target_ira_int),
  sizeof (struct target_rtl),
  sizeof (struct target_builtins),
  sizeof (struct target_reload),
  mt_regno_reg_class
};
