/* Per-back-end register vocabulary: the data, the counts, and the numbering.
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

/* WHAT THIS IS, AND WHY IT IS TWO THINGS AT ONCE

   `reginfo.cc' builds the compiler's whole register world out of six back-end
   macros -- FIXED_REGISTERS, CALL_USED_REGISTERS, REG_ALLOC_ORDER,
   REG_CLASS_CONTENTS, REGISTER_NAMES, REG_CLASS_NAMES -- evaluated at
   reginfo.cc:76-119, in a MIDDLE-END translation unit, i.e. against the
   PRIMARY base's tm.h.  In a compiler holding two back ends, generating
   aarch64 code, those are i386's register names and i386's register classes.

   It also walks them: `0 .. N_REG_CLASSES' and `0 .. FIRST_PSEUDO_REGISTER',
   which are 34 and 92 for i386 and 20 and 95 for aarch64.  The class walk is
   where the aarch64 arm has been stuck -- `init_reg_sets_1' asks
   `targetm.class_max_nregs' about class 20..33, and aarch64 asserts.

   BOTH HALVES ARE HERE ON PURPOSE, AND NEITHER IS USEFUL ALONE.  Bounding the
   loops by a run-time count without moving the data makes `cc1' stop ICEing
   and start compiling aarch64 against i386's register classes and i386's
   register names -- in bounds, no diagnostic, and it would look like the arm
   passing.  Moving the data without bounding the loops moves the ICE three
   lines and reads as a new blocker.  A `cc1' that ICEs loudly is strictly
   better than one that emits aarch64 with x86 register classes, so the two go
   together or neither goes.

   THREE NUMBERS, NOT ONE, AND THEY ARE DIFFERENT NUMBERS

     * The compile-time WIDTHS -- FIRST_PSEUDO_REGISTER and N_REG_CLASSES as
       defaults.h leaves them -- are the maxima over configured back ends and
       are identical in EVERY translation unit.  They are the LAYOUT of
       `target_hard_regs', `target_regs', `target_ira' and `target_ira_int',
       which generic code XCNEWs (target-globals.cc:71-89) and every back end
       reads.  One authority for the size and several for the contents is the
       `cl_optimization' shape; there is exactly one size here.

     * The selected base's own CLASS COUNT bounds the class loops.

     * The selected base's own REGISTER COUNT bounds the register loops.  It
       is a DIFFERENT number from the class count and from the union width;
       hppa64's 62 against hppa's 90 shows it is not even a property of the
       architecture, which is why this is keyed per CONFIGURATION, exactly the
       way MT_BACKENDS keys everything else.

   WHY `ALL_REGS' AND `GENERAL_REGS' BECOME RUN-TIME AND `NO_REGS' DOES NOT

   Target-independent code spells exactly four class names -- NO_REGS (345
   uses), ALL_REGS (64), GENERAL_REGS (56) and LIM_REG_CLASSES (31) -- and no
   interior class name at all.  NO_REGS is 0 in all 52 back ends and
   `reginfo.cc' and `ira.cc' seed their subunion/superunion tables by
   `memset'-to-zero, which is only meaningful if 0 is the empty class, so it
   stays the compile-time 0.  ALL_REGS and GENERAL_REGS appear in ZERO
   constant-expression contexts -- no case label, no array bound, no static
   initialiser, no `#if' -- so they can be variables, and each base keeps its
   own numbering.

   ANCHORING `ALL_REGS' AT `LIM_REG_CLASSES - 1' WAS CONSIDERED AND REJECTED.
   It is free only while the PRIMARY has the largest class count.  The moment
   a non-primary base has more, the union width grows, the primary's ALL_REGS
   moves off 33, the primary's numbering stops being a prefix of the union's,
   and the x86_64 byte-identity arm is put at risk for no gain.  Keeping the
   numbering per base keeps the primary's numbering an identity prefix, so
   that arm cannot move.

   WHAT IS STILL WRONG AFTER THIS

   A class number crossing between a back end and generic code still means
   what it means IN THE SELECTED BASE'S NUMBERING, which is right, but nothing
   type-checks that -- `reg_class_t' is an int.  And the register data
   installed here is the selected base's; the many OTHER back-end macros
   generic code expands to the primary's expressions (STACK_POINTER_REGNUM 7
   vs 31, FRAME_POINTER_REGNUM 19 vs 64, ...) are a separate conversion and
   are NOT fixed by this file.  See MACRO-LEAK.md.  */

#ifndef GCC_TARGET_REGS_H
#define GCC_TARGET_REGS_H

/* One back end's register vocabulary, as measured in ITS OWN preprocessor
   context by target-regs.cc.

   Deliberately built from `int', `char' and pointers only.  This header is
   reached from defaults.h, i.e. from the tail of every `tm.h', long before
   `coretypes.h' -- so `enum reg_class', `machine_mode' and `HARD_REG_SET' are
   all unavailable, and a use site casts.  The alternative (moving the
   dispatch to `hard-reg-set.h') was what the earlier design did and it needs
   a second, poisoned, declaration of every macro to stay honest; plain `int'
   needs none.  */
/* One `ADDITIONAL_REGISTER_NAMES' entry: an assembler-level alias for a
   register, e.g. aarch64's `z0' for V0_REGNUM or i386's `eax' for 0.  The
   field types are upstream's, from the anonymous struct varasm.cc used to
   declare at its use site; every back end's initialiser conforms to them
   because that use site is where they were all written.  */
struct mt_reg_alias
{
  const char *name;
  int number;
};

/* One `OVERLAPPING_REGISTER_NAMES' entry -- an alias naming NREGS registers
   at once (ia64's `ar.bsp', rs6000's `mq').  Same provenance.  */
struct mt_reg_overlap
{
  const char *name;
  int number;
  int nregs;
};

struct target_regs_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* THIS BASE'S OWN counts, not the union widths.  Both are <= the
     corresponding MULTI_TARGET_UNION_* in multi-target-reg-widths.h, and
     target-regs.cc static_asserts exactly that.  */
  int n_reg_classes;
  int first_pseudo_register;

  /* (first_pseudo_register + 31) / 32 -- the row stride of
     reg_class_contents below, in this base's own width.  reginfo.cc's
     N_REG_INTS is the UNION's stride and is a different number.  */
  int n_reg_ints;

  /* Class numbers in this base's own numbering.  NO_REGS is 0 in all 52 back
     ends and is not carried.  */
  int all_regs;
  int general_regs;

  /* FIXED_REGISTERS and CALL_USED_REGISTERS (or CALL_REALLY_USED_REGISTERS),
     first_pseudo_register entries each.  */
  const char *d_fixed_regs;
  const char *d_call_used_regs;

  /* REG_ALLOC_ORDER, first_pseudo_register entries, or NULL if this back end
     defines no REG_ALLOC_ORDER -- which is a real case and is why this is a
     pointer that may be null rather than a flag plus an array.  */
  const int *d_reg_alloc_order;

  /* ADJUST_REG_ALLOC_ORDER, wrapped in a function, or NULL if this back end
     defines none.

     THIS IS THE SLOT THAT WAS MISSING, AND IT COST AN ICE WITH NO NAME ON IT.
     `ira.cc:517' used to be a bare `#ifdef ADJUST_REG_ALLOC_ORDER' in a
     MIDDLE-END translation unit, i.e. it tested the PRIMARY's headers and
     then called the PRIMARY's function for every base.  Measured on the
     linked `cc1': `ira.o' carried an undefined reference to
     `x86_order_regs_for_local_alloc ()' and to nothing else, while
     `aarch64_adjust_reg_alloc_order ()' was DEFINED in the same binary and
     referenced by no object at all.

     That is not a cosmetic leak, because `ADJUST_REG_ALLOC_ORDER' is not an
     optional tweak for every back end.  aarch64's `REG_ALLOC_ORDER' is `{}' --
     an EMPTY initialiser (aarch64.h:1699) -- so the static table is 95 zeros
     and the adjust hook is the ONLY thing that ever makes it a permutation.
     With i386's function called in its place, `reg_alloc_order' held i386's
     92-entry order under an aarch64 selection: registers 92, 93 and 94 were
     absent from it entirely, `setup_class_hard_regs' never visited them, and
     its ordered count disagreed with its set-iterator count.  The symptom was
     `ira_assert (ira_class_hard_regs_num[cl] == n)' at ira.cc:507, which names
     neither the order, nor the base, nor the macro.

     A function pointer rather than a flag, for the reason `d_reg_alloc_order'
     is one: a flag and a body can disagree, a pointer cannot.  */
  void (*adjust_reg_alloc_order) (void);

  /* REG_CLASS_CONTENTS, flattened: row CL starts at [CL * n_reg_ints].  */
  const unsigned *d_reg_class_contents;

  /* REGISTER_NAMES (first_pseudo_register entries) and REG_CLASS_NAMES
     (n_reg_classes entries).  */
  const char *const *d_reg_names;
  const char *const *d_reg_class_names;

  /* ADDITIONAL_REGISTER_NAMES and OVERLAPPING_REGISTER_NAMES, which are the
     REGISTER NAMES A USER MAY WRITE that are not in REGISTER_NAMES: the
     `register ... __asm__ ("z0")' spelling, the names in an asm clobber list,
     and `-ffixed-<reg>'.

     THEY WERE `#ifdef's IN varasm.cc -- a MIDDLE-END translation unit -- so
     they were the PRIMARY's, exactly as REGISTER_NAMES itself was before this
     struct existed, and with the same absence of any diagnostic.  Measured on
     the linked cc1 with i386 + aarch64 configured and aarch64 selected:

	 register int v0 __asm__ ("v0");   accepted   (REGISTER_NAMES, per base)
	 register int x1 __asm__ ("x1");   accepted   (REGISTER_NAMES, per base)
	 register int z0 __asm__ ("z0");   error: invalid register name for 'z0'
	 register int w2 __asm__ ("w2");   error: invalid register name for 'w2'

     i.e. the half of aarch64's register vocabulary that lives in the macro was
     simply absent, and i386's `eax'/`ax'/`al' were in its place.  In one run of
     gcc.target/aarch64 that is 1,041,532 occurrences of `invalid register name
     for zN' plus 462,112 for `pnN' and 283,212 for `wN': the SVE and SME ACLE
     asm tests declare their operands as named-register variables, so the whole
     of sve/acle/asm, sve2/acle/asm and sme/acle-asm fails on it.

     Counts and not NULL-terminated arrays: a terminator would have to be an
     entry with a NULL name, and varasm.cc's own loops already skip entries
     whose name is empty, so a missed terminator would read past the end
     rather than stop.  NULL + 0 when the back end defines neither macro,
     which is most of them.  */
  const struct mt_reg_alias *d_additional_reg_names;
  int n_additional_reg_names;
  const struct mt_reg_overlap *d_overlapping_reg_names;
  int n_overlapping_reg_names;

  /* THE LAYOUT WITNESS.  `sizeof' of the structures that generic code
     allocates and every back end reads, as computed IN THIS BACK END'S OWN
     translation unit.  `init_reg_sets' compares them against the same
     `sizeof's taken in a middle-end translation unit and names the one that
     disagrees.

     This exists because the failure it catches has no other symptom.  The
     bounds in hard-reg-set.h, regs.h, ira.h and ira-int.h must be the union
     widths, spelled MULTI_TARGET_UNION_*; a field left spelled
     FIRST_PSEUDO_REGISTER or N_REG_CLASSES still COMPILES in both places, and
     simply gives the back end a struct that is smaller than the one generic
     code XCNEWs.  Every read past the short field is then in someone else's
     memory, with no diagnostic anywhere -- which is the shape this branch has
     been finding for a year.  These numbers turn "did I miss one" from
     vigilance into a measurement.

     FOUR WAS NOT ENOUGH, AND THE THREE ADDED HERE ARE WHY THE LIST IS NOW
     DERIVED FROM target-globals.cc RATHER THAN FROM THE HEADERS SOMEONE
     REMEMBERED TO CHECK.  `target_rtl' (rtl.h), `target_builtins'
     (builtins.h) and `target_reload' (reload.h) are allocated by exactly the
     same XCNEW in target-globals.cc and were each still spelling
     FIRST_PSEUDO_REGISTER.  `target_rtl' is not hypothetical: with i386 +
     aarch64 + rs6000 configured, `mt-i386/i386.o' addressed
     `x_mode_mem_attrs' 432 bytes below where `emit-rtl.o' put it, and cc1
     segfaulted in `sched2' compiling a two-line x86_64 input.  With only
     i386 + aarch64 the same skew is 48 bytes, which still lands inside the
     struct, so the pair read the wrong member and said nothing.  A new
     `target_*' struct with a register- or class-indexed field must be added
     to this list AND to `MT_CHECK_LAYOUT' in reginfo.cc.  */
  unsigned long sizeof_target_hard_regs;
  unsigned long sizeof_target_regs;
  unsigned long sizeof_target_ira;
  unsigned long sizeof_target_ira_int;
  unsigned long sizeof_target_rtl;
  unsigned long sizeof_target_builtins;
  unsigned long sizeof_target_reload;

  /* SEVEN WAS NOT ENOUGH EITHER, AND THE LIST IS NOW THE WHOLE OF
     `class target_globals' RATHER THAN THE STRUCTS SOMEONE HAD ALREADY FOUND
     A BUG IN.  Every member of that class is XCNEW'd by the same loop in
     target-globals.cc and every one of their headers is reachable from a back
     end's own translation unit, so the argument for checking `target_rtl'
     applies verbatim to all eighteen.  Two of the eleven added here are
     bounded by something that genuinely varies and were wrong in exactly the
     `target_rtl' way: `target_expmed' and `target_lower_subreg' size seven
     arrays by MAX_BITS_PER_WORD, which defaults.h must leave as a constant
     expression BECAUSE it is an array bound, so a shared translation unit
     gets the primary's 64 while `config/xtensa/xtensa.cc' -- one of twenty
     back-end sources that include expmed.h -- computes 32.  They now use
     MULTI_TARGET_UNION_MAX_BITS_PER_WORD.  The other nine were measured
     clean and are listed anyway, because an unchecked struct and a checked
     one look identical from here.  */
  unsigned long sizeof_target_flag_state;
  unsigned long sizeof_target_recog;
  unsigned long sizeof_target_function_abi_info;
  unsigned long sizeof_target_expmed;
  unsigned long sizeof_target_optabs;
  unsigned long sizeof_target_libfuncs;
  unsigned long sizeof_target_cfgloop;
  unsigned long sizeof_target_gcse;
  unsigned long sizeof_target_bb_reorder;
  unsigned long sizeof_target_lower_subreg;
  unsigned long sizeof_target_constraints;

  /* `sizeof (enum reg_class)' AS THIS BACK END SEES IT.

     Not a struct, and that is the point.  A shared translation unit with no
     `tm.h' takes the one-enumerator `enum reg_class' declared in
     multi-target-macros.h; a back end's own translation unit takes its real
     one, 34 enumerators for i386 and 20 for aarch64.  Three fields of
     `struct target_hard_regs' are arrays of that type, so if the two
     declarations disagreed on width the struct would have two layouts and
     `sizeof_target_hard_regs' above would catch it -- but it would report a
     struct size and name no cause.  This field makes the diagnostic name the
     actual disagreement.

     It is checked rather than assumed because the assumption is real: C++
     leaves the underlying type of an unfixed enum implementation-defined, and
     `-fshort-enums' would make the one-enumerator form narrower than any back
     end's.  A silent agreement between two authorities is what this branch
     exists to remove, so the agreement is measured on both sides.  */
  unsigned long sizeof_enum_reg_class;

  /* REGNO_REG_CLASS, FENCED.  Generic code walks 0..FIRST_PSEUDO_REGISTER,
     which is the UNION width, so it will ask about register numbers this back
     end does not have; i386's REGNO_REG_CLASS is `regclass_map[REGNO]' and
     would read three elements past the end of a real array.  The
     implementation answers NO_REGS outside its own range, which lets
     reginfo.cc:405 fence `operand_reg_set' and `fixed_reg_set' by itself.  */
  int (*regno_reg_class) (int regno);

  /* PIC_OFFSET_TABLE_REGNUM, evaluated in this back end's own translation
     unit.  Twelve SHARED translation units spell this macro -- df-scan.cc,
     emit-rtl.cc, cfgexpand.cc, builtins.cc, shrink-wrap.cc, reginfo.cc,
     df-problems.cc and more -- and every one of them was reading the
     PRIMARY's.

     WHAT THAT COST, MEASURED.  i386's expands to `INVALID_REGNUM' for
     x86_64, so `emit-rtl.cc:6361' left `pic_offset_table_rtx' NULL for EVERY
     configured back end.  mips's prologue asks
     `find_reg_fusage (insn, USE, pic_offset_table_rtx)', which hands the null
     to `reg_overlap_mentioned_p' and segfaults in
     `pass_late_thread_prologue_and_epilogue'.  Note the direction: the leak
     was of the primary's ABSENCE, so no back end got i386's $ebx either --
     they all got "there is no PIC register", which is a wrong answer for the
     forty-four back ends that define the macro.

     A FUNCTION and not a data field: the macro is not invariant in any of
     the three back ends checked (i386 reads `ix86_use_pseudo_pic_reg ()' and
     `pic_offset_table_rtx'; mips reads `reload_completed'; arm is the option
     variable `arm_pic_register'), which is also why target-cdata.h:160
     refuses it a cdata slot.  */
  unsigned int (*pic_offset_table_regnum) (void);
};

/* One entry per configured back end, so a table can be found by name.  */
struct target_regs_entry
{
  const char *name;
  const struct target_regs_desc *regs;
};

extern const struct target_regs_entry targetm_regs_registry[];

/* The vocabulary in force.

   NULL UNTIL A TARGET IS SELECTED, DELIBERATELY.  `targetm_addr' and
   `targetm_asm_ops' are constant-initialised with the PRIMARY's table because
   they are valid before anything runs; doing that here would be the exact bug
   this branch exists to remove -- a compiler that never selected would answer
   i386's register classes for every target, correctly on the build machine
   and wrongly everywhere else.  `init_reg_sets' checks by name instead.  */
extern const struct target_regs_desc *targetm_regs;

/* Look BASE up in the registry, or NULL.  BASE is a cpu_type, the same key
   the tm-<base>.h files use.  */
extern const struct target_regs_desc *target_regs_for (const char *base);

/* THE RUN-TIME BOUNDS.  Spelled differently from N_REG_CLASSES and
   FIRST_PSEUDO_REGISTER on purpose: those two are still needed, and still
   mean the compile-time union LAYOUT.  A site that wants "how many are there
   really" says so, and a site that wants "how big is the array" says that.
   Making one name mean both is what put i386's 34 classes over aarch64's data
   at reginfo.cc:293, :315 and :329 -- three loops that ran wrong for a year
   without an assert to say so.  */
#define MT_N_REG_CLASSES (targetm_regs->n_reg_classes)
#define MT_FIRST_PSEUDO_REGISTER (targetm_regs->first_pseudo_register)

/* `#ifdef REG_ALLOC_ORDER', asked of the SELECTED base instead of of the
   primary's headers.

   The nullness of `d_reg_alloc_order' is not a second, independent fact that
   could drift out of step with the `#ifdef': target-regs.cc sets that pointer
   under exactly that `#ifdef' and nothing else, so the two are one fact with
   one authority.  It is spelled as a macro here because five middle-end sites
   ask the question and a reader should be able to see they are asking the same
   one.

   This distinction is load-bearing rather than tidy.  The `#else' arms at
   ira-color.cc:5243 and reload1.cc:1910 are not "the same thing without the
   ordering" -- they are a DIFFERENT tie-break (prefer call-clobbered
   registers).  Making the sites unconditional would therefore not merely
   generalise them; it would silently give a back end that defines no
   REG_ALLOC_ORDER a tie-break it never asked for.  */
#define MT_HAVE_REG_ALLOC_ORDER (targetm_regs->d_reg_alloc_order != NULL)

#endif /* GCC_TARGET_REGS_H */
