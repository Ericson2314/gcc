/* Per-back-end insn-pattern existence facts that shared code asks for.
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

/* THE THREE `HAVE_<pattern>' BOOLEANS THAT SHARED CODE READS.

   `genconfig' writes one `insn-config-<base>.h' per back end, and the maxima
   in it are unioned (see the long note at the top of genconfig.cc: a maximum
   is safe to raise, so `MAX_DUP_OPERANDS' can hold one value correct for
   everybody).  THE BOOLEANS ARE NOT UNIONABLE and genconfig says so: a max
   over booleans is an OR, and telling the middle end that a pattern exists
   when the selected back end has no such pattern is a silent wrong answer,
   not a conservative one.

   So they stayed per back end -- correctly -- and shared code went on reading
   whichever base's `insn-config.h' the build root happened to resolve to.
   Measured in an x86_64 + aarch64 build directory:

       insn-config-i386.h      HAVE_lo_sum 0   HAVE_rotate 1  HAVE_rotatert 1
       insn-config-aarch64.h   HAVE_lo_sum 1   HAVE_rotate 1  HAVE_rotatert 1

   `HAVE_lo_sum' is the live divergence, and it is SILENT in exactly the way
   this branch keeps finding: `combine.cc:4918', `combine.cc:6101' and
   `lra-constraints.cc:4242' all read 0, so when aarch64 is the selected
   target two combine transformations and one LRA path that aarch64 CAN
   express are simply never attempted.  Nothing is mis-set and nothing is
   diagnosed; the compiler just quietly generates worse code.  There is no
   test that fails.

   `HAVE_rotate' and `HAVE_rotatert' are worse in shape though not for this
   pair.  genconfig only ever DEFINED them (never `#define X 0'), and
   `simplify-rtx.cc:4773' asked `#if defined(HAVE_rotate) && defined
   (HAVE_rotatert)' -- a preprocessor line in a file the whole compiler
   shares.  A `#if` cannot be answered per target, so genconfig grew a
   unanimity check that STOPPED THE BUILD when the configured back ends
   disagreed, and its message ended "This combination of targets needs that
   use site made runtime before it can be built."  That is what this file is:
   the use site made runtime.  The check is not relaxed, it is discharged.

   WHY A TABLE AND NOT A UNION.  Per genconfig's own note, unioning is the one
   thing that must not happen here.  Per PRINCIPLES 2 this is a HOOK, not a
   `target-specs' capability: whether a back end has a `rotate' pattern is
   settled by its `.md` file, ships with the compiler, and cannot differ
   between two installations serving the same target.

   WHY IT HANGS OFF `target_cumargs_desc'.  The same reason target-frame.h
   gives: the per-base symbol declarations and the `TARGETM_*_TABLES' list are
   emitted by `gen-multi-target-md.awk', and a further registry would be a
   mechanical copy of the cumargs one there.  The supplying translation unit
   is already compiled once per base and names this base's insn-config.h at
   the point of inclusion.  That include is the whole mechanism.  */

#ifndef GCC_TARGET_INSN_H
#define GCC_TARGET_INSN_H

/* One back end's answers.  Plain booleans and not function pointers, unlike
   target-frame.h: these are settled by the back end's machine description
   before any option is decoded, they cannot vary with `cfun' or with
   `__attribute__((target))', and there is nothing to evaluate.  The frame
   entries pay for a call because i386's `STACK_BOUNDARY' really does read
   `cfun'; nothing here does.  */
struct target_insn_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* HAVE_lo_sum -- combine.cc:4918, combine.cc:6101, lra-constraints.cc:4242.  */
  bool have_lo_sum;

  /* HAVE_rotate and HAVE_rotatert -- simplify-rtx.cc:4773, which wants BOTH
     before it will reverse a rotate by a constant.  Kept as two fields rather
     than one combined flag because they are two questions with two answers;
     a back end with `rotate' and no `rotatert' exists and the combined form
     would silently stop being able to say so.  */
  bool have_rotate;
  bool have_rotatert;

  /* AUTO_INC_DEC -- `rtl.h:2901', "does this machine have any sort of
     auto-increment addressing".  Twenty-seven use sites across reload1.cc,
     reload.cc, combine.cc, recog.cc, lra.cc, lower-subreg.cc, sched-deps.cc,
     loop-invariant.cc, regrename.cc, emit-rtl.cc and auto-inc-dec.cc.

     ONE FIELD FOR EIGHT MACROS, and that is not the shortcut it looks like.
     rtl.h's own definition is the disjunction

       #if (defined (HAVE_PRE_INCREMENT) || defined (HAVE_PRE_DECREMENT)
            || defined (HAVE_POST_INCREMENT) || defined (HAVE_POST_DECREMENT)
            || defined (HAVE_PRE_MODIFY_DISP) || defined (HAVE_POST_MODIFY_DISP)
            || defined (HAVE_PRE_MODIFY_REG) || defined (HAVE_POST_MODIFY_REG))

     so the question shared code asks is already the disjunction and never the
     individual eight.  Storing the disjunction is storing the question that is
     asked; storing the eight would be storing a vocabulary nothing reads.
     (Contrast `have_rotate'/`have_rotatert' two lines up, which are two fields
     precisely because two different questions ARE asked.)

     WHY IT IS WRONG TODAY, MEASURED OVER ALL 48 REAL HEADER CHAINS
     (scratchpad/t169-autoinc.sh): the eight come from `insn-flags-<base>.h',
     which genflags writes from that back end's `.md'.  i386 defines NONE of
     them.  rtl.h is shared, so it is preprocessed once against the primary's
     chain, and AUTO_INC_DEC is therefore 0 for every configured back end --
     while 25 of the 48 would compute 1 from their own headers, aarch64 among
     them (which defines five of the eight).  Auto-increment addressing is
     switched off compiler-wide for 25 back ends.

     THIS IS THE SILENT HALF.  Nothing is undefined, nothing fails to link, no
     value is out of range: the middle end simply stops looking for REG_INC
     notes and stops forming auto-inc addresses, and emits correct, slower
     code.  A symbol sweep cannot see it because there is no symbol; a build
     cannot see it because it builds.  */
  bool auto_inc_dec;

  /* LOAD_EXTEND_OP (MODE) -- `rtl.h:4762', inside `load_extend_op', which is
     an inline function in a header the whole compiler shares.

     THE ONLY ENTRY HERE THAT IS A CALL, and for the reason target-frame.h
     gives rather than by preference: it takes an argument, so there is no
     value to cache.  33 of the 48 back ends define it and i386 -- the base the
     middle end is compiled against -- is not one of them, so today every
     target reads i386's absence: `defaults.h:1386''s `LOAD_EXTEND_OP(M)
     UNKNOWN'.  For aarch64, whose own answer is `ZERO_EXTEND', that turns
     `load_extend_op' into "this machine does not widen on load" for every
     narrow load in the compilation.  It is the leaked-ABSENCE shape again: no
     value is mis-set, nothing is diagnosed, and the middle end simply stops
     making an inference it is entitled to make.

     `int' at the boundary, not `machine_mode' and not `enum rtx_code': this
     header is reached from `defaults.h', i.e. from the tail of every `tm.h',
     long before `coretypes.h', so neither type exists yet.  target-regs.h
     records the same constraint and takes the same decision.  */
  int (*load_extend_op) (int mode);
};

/* The answers in force, or NULL until a target is selected.  Shared code goes
   through the `mt_' functions below so the by-name diagnostic cannot be
   bypassed.  */
extern const struct target_insn_desc *targetm_insn;

extern bool mt_have_lo_sum (void);
extern bool mt_have_rotate (void);
extern bool mt_have_rotatert (void);
extern bool mt_auto_inc_dec (void);
extern int mt_load_extend_op (int mode);

#endif /* GCC_TARGET_INSN_H */
