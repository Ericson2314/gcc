/* Per-back-end condition-code MODE SELECTION, which shared code asks for.
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

/* THE THREE CC MACROS SHARED CODE READS, AND WHAT THEY WERE ANSWERING.

   `SELECT_CC_MODE (OP, X, Y)' is how the middle end asks a back end which of
   its condition-code modes a given comparison wants.  20 of the 47 back ends
   define it, i386 among them:

       i386.h:2074    #define SELECT_CC_MODE(OP, X, Y) ix86_cc_mode ((OP), (X), (Y))
       s390.h:773     #define SELECT_CC_MODE(OP, X, Y) s390_select_ccmode ((OP), (X), (Y))
       aarch64.h:1453 #define SELECT_CC_MODE(OP, X, Y) aarch64_select_cc_mode (OP, X, Y)

   `combine.cc', `ccmp.cc' and `compare-elim.cc' are SHARED, so all three read
   the primary's, and every back end's comparisons were being assigned i386's
   CC modes.

   THE MODE VOCABULARY IS UNIONED AND THE DATA IS PER BASE, so i386's `CCGCmode'
   and s390's `CCZmode' are DIFFERENT NUMBERS.  That is what makes this leak
   loud on s390 rather than merely wrong: `combine.cc:6943' computes

       compare_mode = SELECT_CC_MODE (new_code, op0, op1);      <- ix86_cc_mode

   and then, twelve lines down, plants that mode straight onto the CC register:

       new_dest = gen_rtx_REG (compare_mode, regno);
       SUBST (SET_DEST (x), new_dest);

   The insn now sets the s390 CC register in an i386 CC mode.  `s390.md''s
   patterns gate on `s390_match_ccmode', which switches on the mode of
   `SET_DEST' over s390's own CC modes and ends

       s390.cc:1518     default:  gcc_unreachable ();

   -- `internal compiler error: in s390_match_ccmode_set', the top cause on
   s390x's row of the 47-base board.

   `REVERSIBLE_CC_MODE (MODE)' and `REVERSE_CONDITION (CODE, MODE)' are the
   same family and leak the same way, from `jump.cc:373-374' inside
   `reversed_comparison_code_parts':

       if (GET_MODE_CLASS (mode) == MODE_CC && REVERSIBLE_CC_MODE (mode))
         return REVERSE_CONDITION (code, mode);

   `defaults.h:1215' has `#ifndef REVERSIBLE_CC_MODE / #define ... 0' and
   `defaults.h:1420' has `#ifndef REVERSE_CONDITION / #define ...
   reverse_condition (code)'.  BOTH ARE DEAD in shared code, because
   `i386.h:2079' and `:2083' define the names first -- the
   `REGMODE_NATURAL_SIZE' trap PRINCIPLES 2a records, in a new place.  So what
   shared code actually reads is

       REVERSIBLE_CC_MODE(MODE)      1                       (i386's, always true)
       REVERSE_CONDITION(CODE, MODE) ix86_reverse_condition   (i386's)

   i.e. for all 47 back ends every CC mode is declared reversible and the
   reversal is computed by i386's rule.  15 back ends define
   `REVERSIBLE_CC_MODE' and 6 define `REVERSE_CONDITION'; s390's own answers
   are `s390.h:461' and `:466'.  Unlike the ICE above this one is SILENT: it
   produces a well-formed insn with the wrong condition on it.

   WHY A TABLE.  Per PRINCIPLES 2 this is a HOOK, not a `target-specs'
   capability: which CC mode a comparison wants is settled by the back end's
   machine description, ships with the compiler, and cannot differ between two
   installations serving the same target.  And it cannot be unioned -- a CC
   mode is exactly the kind of per-base datum the union deliberately keeps
   separate.

   WHY IT HANGS OFF `target_cumargs_desc'.  The same reason target-frame.h,
   target-insn.h, target-preds.h, target-attr.h, target-modeswitch.h,
   target-sched.h, target-asmfprintf.h and target-automata.h give: the
   per-base symbol declarations and the `TARGETM_*_TABLES' list are emitted by
   `gen-multi-target-md.awk', and a further registry would be a mechanical
   copy of the cumargs one.  The supplying translation unit is already
   compiled once per base and names this base's headers at the point of
   inclusion.  That include is the whole mechanism.

   `int' and `struct rtx_def *' at the boundary, not `machine_mode',
   `enum rtx_code' or `rtx': this header is reached from `defaults.h', i.e.
   from the tail of every `tm.h', long before `coretypes.h', so none of those
   three names exists yet.  target-insn.h and target-regs.h record the same
   constraint and take the same decision; `struct rtx_def *' is what
   `coretypes.h:57' makes `rtx' a typedef for, so the two are the same type
   once `coretypes.h' has been read.  */

#ifndef GCC_TARGET_CCMODE_H
#define GCC_TARGET_CCMODE_H

/* One back end's answers.  Function pointers rather than values, unlike
   target-insn.h's booleans: all three take arguments, so there is nothing to
   cache.  */
struct target_ccmode_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* SELECT_CC_MODE (OP, X, Y), or NULL for a back end that defines no such
     macro.

     NULL RATHER THAN A SECOND `has_select_cc_mode' BOOLEAN, deliberately:
     that would be one fact with two authorities, which is this branch's own
     root bug.  `mt_has_select_cc_mode ()' below is derived from this pointer,
     so the two cannot disagree.

     AND NULL RATHER THAN A FALLBACK, because there is no defensible fallback.
     `defaults.h' supplies none, and the 27 back ends that define nothing are
     back ends whose comparisons have exactly one CC mode; handing them
     another back end's selection function is the defect this field exists to
     remove.  Shared code asks `mt_has_select_cc_mode ()' first -- which is
     the run-time form of the `#ifdef SELECT_CC_MODE' those three call sites
     used to spell, and which was answered by the primary for everyone.  */
  int (*select_cc_mode) (int code, struct rtx_def *x, struct rtx_def *y);

  /* REVERSIBLE_CC_MODE (MODE) -- `jump.cc:373'.

     Never NULL, and that is not the same decision as the field above.  This
     one HAS a documented answer for a back end that defines nothing:
     `defaults.h:1215's `0'.  Evaluated in the per-base translation unit it is
     that back end's own answer -- upstream's value for a back end standing
     alone -- which is the supply-side floor PRINCIPLES 2a permits.  Read in
     shared code the same `#ifndef' is dead, because `i386.h:2079' defines the
     name first, and the value everyone gets is i386's unconditional `1'.  */
  bool (*reversible_cc_mode) (int mode);

  /* REVERSE_CONDITION (CODE, MODE) -- `jump.cc:374'.  Never NULL, for the
     same reason and with the same supply-side floor: `defaults.h:1420's
     `reverse_condition (code)'.  */
  int (*reverse_condition) (int code, int mode);
};

/* The answers in force, or NULL until a target is selected.  Shared code goes
   through the `mt_' functions below so the by-name diagnostic cannot be
   bypassed.  */
extern const struct target_ccmode_desc *targetm_ccmode;

/* Does the base in force define SELECT_CC_MODE at all?  The run-time form of
   the `#ifdef SELECT_CC_MODE' in combine.cc, ccmp.cc and compare-elim.cc.  */
extern bool mt_has_select_cc_mode (void);

/* SELECT_CC_MODE.  Calling this when `mt_has_select_cc_mode ()' is false is a
   bug and fails by name rather than returning a plausible mode.  */
extern int mt_select_cc_mode (int code, struct rtx_def *x, struct rtx_def *y);

extern bool mt_reversible_cc_mode (int mode);
extern int mt_reverse_condition (int code, int mode);

#endif /* GCC_TARGET_CCMODE_H */
