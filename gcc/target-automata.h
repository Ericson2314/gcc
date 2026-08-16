/* One back end's DFA PIPELINE-HAZARD entry points, for shared code.
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

/* WHAT WAS WRONG, AND THIS ONE SMASHES THE HEAP RATHER THAN MERELY
   MIS-MODELLING.

   `genautomata' writes one `insn-automata-<base>.cc' per back end, each in
   `namespace insn_<base>', and one UN-NAMESPACED `insn-automata.cc' from the
   PRIMARY's `.md'.  Both are built and both are linked.  Nothing selected
   between them, so `haifa-sched.o', `sched-rgn.o', `modulo-sched.o' and
   `sel-sched*.o' -- all shared -- bound the BARE `state_size',
   `state_transition', `state_reset', `insn_latency' and the rest, i.e.
   i386's.

   `target-attr.h' fixed the sibling family (`get_attr_enabled',
   `insn_default_length'); `target-sched.h' made each base initialise its OWN
   `internal_dfa_insn_code' pointer.  Both notes say in as many words that
   THIS family was deliberately left unselected.  What was not known then is
   that leaving it unselected is not a mis-model, it is a buffer overflow,
   because the DFA state is a variable-length object whose LENGTH is one of
   the leaking entry points.

   Measured with an ASAN+UBSan `cc1', six runs of six, identical every time:

       heap-buffer-overflow, WRITE of size 116
         ia64_variable_issue            config/ia64/ia64.cc:7689
       0 bytes after a 4-byte region allocated by
         ia64_init_dfa_pre_cycle_insn   config/ia64/ia64.cc:9661

   BOTH NUMBERS ARE EACH BACK END'S OWN.  `ia64.cc' is compiled for ia64, so
   its `state_size ()' is `insn_ia64::state_size ()' -- ia64's `DFA_chip' is
   4 bytes -- and `ia64_init_dfa_pre_cycle_insn' sizes `prev_cycle_state' and
   `temp_dfa_state' from it AND assigns the shared `dfa_state_size' from it.
   `sched_init' (haifa-sched.cc:7360) then overwrites that same shared
   variable with the BARE `state_size ()' -- i386's `DFA_chip', 116 bytes --
   and `ia64_variable_issue' memcpys 116 bytes into the 4-byte buffer.

   One name, two authorities, one storage location, with a memory-safety
   consequence: PRINCIPLES section 3, and section 4's "the bound is the
   union's, the numbering is per base" in its third and worst form.

   WHY THIS COULD NOT BE ADDITIVE, unlike `mt_init_base_sched_attrs'.  That
   fix works by having the selected base ALSO run its initialiser, leaving
   the bare one in place for the consumers that still want it.  Here the
   storage is SIZED by one authority and WRITTEN by another, so running both
   does not help -- whichever writes `dfa_state_size' last decides, and every
   `memcpy (..., dfa_state_size)' in shared code and in the back ends is then
   wrong for one of them.  There is exactly one right answer per compilation
   and it is the selected base's.  Hence a selector.

   WHY A SELECTOR AND NOT A RENAME.  The settled rule is that a rename
   suffices iff no shared translation unit names the bare symbol.  Measured,
   with the sites:

       state_transition          haifa-sched.cc x7, sel-sched.cc x3,
                                 modulo-sched.cc x4
       state_reset               haifa-sched.cc, sched-rgn.cc, sel-sched.cc,
                                 sel-sched-ir.cc x3, modulo-sched.cc
       state_size                haifa-sched.cc:7360
       state_dead_lock_p         haifa-sched.cc x2, modulo-sched.cc
       min_insn_conflict_delay   sched-rgn.cc:2235
       print_reservation         haifa-sched.cc x2, sched-rgn.cc
       dfa_start / dfa_finish    haifa-sched.cc
       dfa_clear_single_insn_cache  haifa-sched.cc:1159
       insn_latency              haifa-sched.cc, modulo-sched.cc x2
       maximal_insn_latency      sel-sched.cc:5353
       bypass_p                  haifa-sched.cc:1487
       insn_default_latency      haifa-sched.cc x4, sel-sched-ir.cc
       max_insn_queue_index      haifa-sched.cc, 25 sites

   Nine shared objects, so a bare rename would leave nine link errors.  A
   selector it is, in exactly the shape `target-attr.h' established.

   WHAT IS NOT IN THE TABLE, AND WHY -- silence about a name in this family
   would read as "checked and clean".  `min_issue_delay',
   `get_cpu_unit_code', `cpu_unit_reservation_p', `insn_has_dfa_reservation_p',
   `dfa_clean_insn_cache', `state_alts' and `insn_alts' are exported by
   `insn-automata.cc' and are named by NO shared translation unit in this
   tree (measured with `grep -rw' over everything outside `config/' and the
   generators).  The back ends that use them reach their own copy through
   their own `insn-attr-<base>.h', which is already right.  `dfa_start'
   calls `dfa_clean_insn_cache' internally, so selecting the former selects
   the latter's effect without the name having to move.

   `internal_dfa_insn_code' and `insn_default_latency' are function POINTERS
   that `init_sched_attrs ()' assigns.  The second IS in this table because
   shared code calls it by name; the first is not, because outside comments
   no shared translation unit does.  Both per-base pointers are made non-NULL
   by `mt_init_base_sched_attrs' (target-sched.h), which this change does not
   replace: the base's own `state_transition' calls its own
   `internal_dfa_insn_code' through that pointer, so the two fixes are
   consumed together and neither is sufficient alone.

   THE RESIDUAL, SAID OUT LOUD.  Shared scheduling code is still wrapped in
   `#ifdef INSN_SCHEDULING', which is the PRIMARY's macro out of the primary's
   `insn-attr-common.h'.  A base with no `define_insn_reservation' at all
   configured beside a primary that has one therefore still reaches this
   table, and finds it empty.  That case fails BY NAME here rather than
   calling through a null pointer -- see `mt_automata' in
   `target-cumargs-select.cc' -- which is the direction to fail in, but it is
   a refusal and not a fix.  Converting `INSN_SCHEDULING' itself is a
   separate task.

   THAT RESIDUAL WAS THE LARGEST SINGLE ICE CAUSE ON THIS BRANCH AND IS NOW
   CLOSED FOR THE GATES.  It was not a corner: `int f (int x) { return x + 1;
   }' at `-O2', no header and no libc, ICEd on ELEVEN of the 47 configured
   back ends -- avr, cris, ft32, h8300, mmix, moxie, msp430, pdp11, rl78, vax,
   xstormy16.  1,449 results by volume and the widest cause by breadth, on
   both orderings of the 28-back-end board at once.

   TWO THINGS ABOUT HOW IT STAYED HIDDEN, BOTH MORE TRANSFERABLE THAN THE FIX.

   It was recorded as avr's alone, TWICE, because the diagnostic NAMES THE
   BACK END.  A cause-ranking keyed on diagnostic text therefore scores one
   shared defect as N distinct causes of one back end each, and it can never
   rise in a breadth ranking however wide it is.  The property that makes a
   message useful to a human is the property that hides it from the
   instrument; `a7d26223eefcfa725-causes2.sh' folds the quoted name out before
   keying, and `a98009045f7229938-foldcheck.sh' asserts that fold still covers
   every self-naming diagnostic in the tree.

   And it was invisible at the level everything was probed at.  Over the 45
   targets with a specs-config, a one-line function gives `-O0' ok = 38,
   `-O1' ok = 37, `-O2' ok = 28: ten back ends compile it at `-O0' and ICE at
   `-O2'.  Scheduling is an `-O2' pass, so `-O0' is the LEAST representative
   single level available, and every precondition that probed only there
   reproduced the exact blindness it was written to remove.

   WHAT IS CONVERTED AND WHAT IS NOT.  The run-time GATES now ask
   `mt_has_insn_scheduling ()': the four pass gates in `sched-rgn.cc',
   `pass_sms::gate', the two split-pass gates in `recog.cc', and the
   paradoxical-SUBREG family (`recog.cc' `general_operand', `expr.cc'
   `force_operand', `combine.cc' x2) -- which are converted TOGETHER because
   they must agree: recog rejects what expr must not create and combine must
   not split towards.

   The FILE-SCOPE `#ifdef INSN_SCHEDULING' in `haifa-sched.cc',
   `sched-deps.cc', `sched-ebb.cc', `sched-rgn.cc', `modulo-sched.cc',
   `ddg.cc', `sel-sched*.cc' and `sched-int.h' are deliberately NOT converted
   and are not a leak: they decide whether the scheduler is COMPILED IN, and
   in a build containing any back end with a DFA it must be, for that back
   end.  They are the union's presence, which is correct; what was wrong was
   using the union's presence as the selected base's answer.

   `opts.cc' IS NOT CONVERTED, AND THE REASON IS A LINK BOUNDARY RATHER THAN
   AN OVERSIGHT.  Its two `#ifdef INSN_SCHEDULING' entries in
   `default_options_table' put `-fschedule-insns2' (and `-fschedule-insns' for
   speed) on at `-O2'.  `opts.o' is in `libcommon-target.a', which the DRIVER
   links; `targetm_automata' is in `libbackend.a', which it does not.  A call
   to `mt_has_insn_scheduling ()' there does not link -- the same boundary
   that put `$(MT_OPTIONS_TABLES_OBJS)' in `libcommon-target.a', recorded in
   `gcc/Makefile.in'.

   `toplev.cc:1428''s `#ifndef INSN_SCHEDULING' warning is NOT converted FOR
   THE SAME REASON, and this is the half-fix trap in the concrete: it warns
   `instruction scheduling not supported on this target machine' when the flag
   is set.  Converting it while `opts.cc' still sets the flag at `-O2' would
   emit that warning on EVERY `-O2' compile for the eleven back ends -- a new
   diagnostic on every test, from a change whose purpose was to remove one.
   The two are a matched pair and must move together, into `targetm_common'
   (which IS selected before `decode_options', at `toplev.cc:2407') rather
   than into this table.  Until then the observable is unchanged, because the
   pass gate and not the flag is now the authority.

   `DELAY_SLOTS' IS THE SAME DEFECT IN THE SAME GENERATED HEADER AND IS NOT
   FIXED HERE.  Stated rather than left to be rediscovered: it is the second
   macro `genattr-common' writes into `insn-attr-common-<base>.h', it is the
   primary's in shared code for exactly the reason `INSN_SCHEDULING' was, and
   the one-line census at `-O2' surfaced it for free while measuring this.

   Measured, cold 47-base build:

       insn-attr-common.h        DELAY_SLOTS 0     (== i386's)
       insn-attr-common-sparc.h  DELAY_SLOTS 1
       insn-attr-common-arc.h    DELAY_SLOTS 1
       12 of 47 back ends say 1 -- arc cris fr30 h8300 iq2000 microblaze mips
       or1k pa sh sparc visium -- and all twelve are answered by i386's 0.

   Observable on `int f (int x) { return x + 1; }' at `-O2', arc, in the same
   census run that found the eleven:

       cc1: warning: this target machine does not have delayed branches

   -- `toplev.cc:1433', `if (!DELAY_SLOTS && flag_delayed_branch)', reading
   i386's 0 for a back end that has them.  The warning is the visible half.
   The consequential half is `reorg.cc:3838' and `:3878': `-fdelayed-branch'
   is gated on the same 0, so **delay-slot filling has never run for any of
   the twelve on this branch**, and `function.cc:6766' asserts
   `gcc_assert (!DELAY_SLOTS)' -- an assertion that holds only because the
   answer is wrong.

   NOTE THE SHAPE, BECAUSE IT IS NOT THE `#ifdef' SHAPE.  `DELAY_SLOTS' is
   already a 0/1 VALUE and its consumers already spell `if (DELAY_SLOTS)'
   rather than `#ifdef' -- upstream did that conversion years ago.  So "the
   consumers are runtime `if's" is NOT evidence a macro is per-base here; the
   value reaching them is still one header's.  An audit looking for `#ifdef'
   would score this file clean.

   DELIBERATELY LEFT.  The fix is mechanical -- another member on
   `target_automata_desc', read in `target-cumargs.cc' where the macro is
   still that base's own, exactly as `has_dfa' is -- but turning it on starts
   running `reorg' on twelve back ends for the first time, which is a
   behaviour change of a different size from switching a gate OFF, and
   belongs in its own change with its own both-sided measurement.

   THE `void *' BOUNDARY IS DELIBERATE.  `state_t' is a typedef in the
   generated `insn-attr.h', and this header is read by translation units that
   do not include it.  It is `void *' in every back end's copy -- genattr
   emits the typedef verbatim -- so spelling it out here loses nothing and
   costs one fewer header dependency.  */

#ifndef GCC_TARGET_AUTOMATA_H
#define GCC_TARGET_AUTOMATA_H

/* One back end's DFA pipeline-hazard entry points.  Every member is a thunk
   defined in `target-cumargs.cc' compiled for that base, where
   `#include BASE_HEADER (insn-attr.h)' resolves to that base's
   `insn-attr-<base>.h' and its trailing `using namespace insn_<base>;' makes
   the unqualified spelling mean that base's automaton.  Compiling one file
   against one back end's headers is the whole mechanism; no back end is
   edited and no `target.def' entry is added.  */

struct target_automata_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* `DELAY_SLOTS' -- whether this back end's `.md' contains a `define_delay',
     read WHERE IT IS STILL THIS BASE'S OWN MACRO out of its own
     `insn-attr-common-<base>.h'.  See the long comment at the top of this
     file for the measurement; the short form is that the shared
     `insn-attr-common.h' says 0 because it is i386's, and twelve back ends --
     arc, cris, fr30, h8300, iq2000, microblaze, mips, or1k, pa, sh, sparc,
     visium -- were answered by that 0.

     NOTE THE SHAPE.  This is NOT the `#ifdef' shape: upstream converted
     `DELAY_SLOTS' to a 0/1 VALUE years ago and every consumer already spells
     `if (DELAY_SLOTS)'.  So every `#ifdef'-keyed sweep this project has run
     scored the file clean while the value reaching those `if's was one
     header's.  A macro's consumers being runtime `if's is not evidence the
     macro is per-base here.

     A `bool' field and not a thunk, unlike everything below it: `DELAY_SLOTS'
     is an integer literal in the generated header, so it is a constant
     expression here and the table stays statically initialised.  It is also
     OUTSIDE the `#ifdef INSN_SCHEDULING' arm of the initialiser, because the
     two are independent -- fr30, h8300, iq2000, microblaze, or1k and visium
     have delay slots and no automaton at all.  */
  bool delay_slots;

  /* Whether this back end has an automaton at all, i.e. whether its `.md'
     contains a `define_insn_reservation'.  This is `#ifdef INSN_SCHEDULING'
     read WHERE IT IS STILL THIS BASE'S OWN MACRO, which is the only place it
     can be read correctly.  False here means every pointer below is NULL and
     that is this generator's own answer, not a value invented here: genattr
     emits neither the declarations nor the definitions for such a back end.  */
  bool has_dfa;

  /* THE MEMBER NAMES ARE DELIBERATELY SHORT, AND THAT IS NOT A STYLE CHOICE.
     `target_attr_desc' records the measurement: a member spelled with the
     generated name is an ordinary identifier to the preprocessor, so the
     `#define's the generated headers emit -- and the renames
     `multi-target-attr.h' emits -- rewrite the STRUCT DECLARATION too.  There
     it failed loudly only because two members collided into one name; a
     single such member would have compiled and been initialised through a
     silently renamed field.  */

  /* `state_size ()'.  A function and not an `int': it is the size of a
     `struct DFA_chip' in this base's automaton and the whole reason this
     table exists, so it is read at the moment shared code asks rather than
     frozen at static-initialisation time.  */
  int (*size) (void);

  /* `max_insn_queue_index'.  Generated as `extern const int' in another
     translation unit, hence NOT a constant expression here; a thunk rather
     than a field so the table stays statically initialised and acquires no
     static-initialisation-order dependency.  */
  int (*max_queue_index) (void);

  /* The state-machine operations.  `state_t' is `void *'; see above.  */
  void (*reset) (void *);
  int (*transition) (void *, rtx);
  int (*dead_lock_p) (void *);
  int (*min_conflict_delay) (void *, rtx_insn *, rtx_insn *);

  /* Dump support: `print_reservation'.  */
  void (*print_res) (FILE *, rtx_insn *);

  /* `dfa_start' / `dfa_finish' / `dfa_clear_single_insn_cache'.  These own
     this base's `dfa_insn_codes' cache, which is a static inside its own
     namespace, so calling the primary's paired the cache of one automaton
     with the queries of another.  */
  void (*start) (void);
  void (*finish) (void);
  void (*clear_single_cache) (rtx_insn *);

  /* Latency.  `default_latency' is the `insn_default_latency' function
     POINTER, called through here so that shared code reaches the pointer
     `mt_init_base_sched_attrs' filled in for THIS base rather than the bare
     one the primary's `init_sched_attrs' filled in.  */
  int (*bypass) (rtx_insn *);
  int (*latency) (rtx_insn *, rtx_insn *);
  int (*max_latency) (rtx_insn *);
  int (*default_latency) (rtx_insn *);
};

/* The table in force, or NULL until a target is selected.  NULL and not the
   primary's, for the reason `target-regs.h' argues at length: a default here
   is exactly the bug being removed.  */
extern const struct target_automata_desc *targetm_automata;

/* The run-time form of `#ifdef INSN_SCHEDULING', for the SELECTED base.  A
   query, so it answers `false' for a base with no automaton rather than
   refusing it; it still refuses when no base is selected at all.  Every
   shared gate that used to read the primary's `#ifdef' calls this.  */
extern bool mt_has_insn_scheduling (void);

/* The run-time form of `DELAY_SLOTS', for the SELECTED base.  A query like
   `mt_has_insn_scheduling ()' -- it answers `false' for a base with no
   `define_delay' rather than refusing it, and still refuses when no base is
   selected at all.  Every shared consumer that used to read the primary's
   macro calls this: `cfgrtl.cc:493', `final.cc:1067', `function.cc:6766',
   `reorg.cc:3838' and `:3878'.

   `opts.cc:623' and `toplev.cc:1433' are NOT converted and that is a link
   boundary, not an oversight -- see the top of this file.  */
extern bool mt_delay_slots (void);

extern int mt_state_size (void);
extern int mt_max_insn_queue_index (void);
extern void mt_state_reset (void *);
extern int mt_state_transition (void *, rtx);
extern int mt_state_dead_lock_p (void *);
extern int mt_min_insn_conflict_delay (void *, rtx_insn *, rtx_insn *);
extern void mt_print_reservation (FILE *, rtx_insn *);
extern void mt_dfa_start (void);
extern void mt_dfa_finish (void);
extern void mt_dfa_clear_single_insn_cache (rtx_insn *);
extern int mt_bypass_p (rtx_insn *);
extern int mt_insn_latency (rtx_insn *, rtx_insn *);
extern int mt_maximal_insn_latency (rtx_insn *);
extern int mt_insn_default_latency (rtx_insn *);

#endif /* GCC_TARGET_AUTOMATA_H */
