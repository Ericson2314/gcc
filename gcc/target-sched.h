/* One back end's SCHEDULER-ATTRIBUTE initialiser, for shared code.
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

/* WHAT WAS WRONG, MEASURED.

   `genattr' emits `internal_dfa_insn_code' and `insn_default_latency' as
   function POINTERS, and a real function `init_sched_attrs ()' that assigns
   them -- one set per back end, inside `namespace insn_<base>'.  Measured in
   an eleven-base `cc1':

       nm -C --defined-only cc1
         T insn_riscv::init_sched_attrs()      B insn_riscv::internal_dfa_insn_code
         T insn_mips::init_sched_attrs()       B insn_mips::internal_dfa_insn_code
         ... one pair per configured base, plus one BARE pair
       nm -uC cfgexpand.o
         U init_sched_attrs()                  <- the bare one, i.e. the primary's

   `cfgexpand.cc:7109' and `run-rtl-passes.cc:56' are the only two callers and
   both are SHARED, so exactly one of the twelve initialisers ever ran: the
   primary's.  Every other base's pointers stayed NULL in `.bss'.

   That is invisible until a back end's OWN code asks its OWN automaton, which
   two of them do on the ordinary path:

       riscv  insn_riscv::insn_has_dfa_reservation_p  <- riscv_sched_variable_issue
       mips   insn_mips::state_transition             <- mips_sim_wait_units

   both crashing with frame `#0' at address `0x0' -- a call through the NULL
   pointer, at `-O2' for riscv (pass `sched1') and at every `-O' for mips
   (pass `expand', through `mips_set_tuning_info').  PRINCIPLES section 3's
   `internal_dfa_insn_code' entry, met from the other side: not a kind
   mismatch this time but an initialiser that runs for one base and is needed
   by eleven.

   WHAT THIS FIXES AND WHAT IT DELIBERATELY DOES NOT.  It makes the base in
   force initialise ITS OWN pointers, in addition to -- not instead of -- the
   existing bare call.  That is the whole fix for a back end calling its own
   automaton, and it is NOT a fix for the larger leak sitting beside it:
   `haifa-sched.o' and the rest of shared scheduling still bind the BARE
   `internal_dfa_insn_code', `state_transition', `insn_latency' and
   `dfa_start', i.e. they still schedule every target's insns against the
   primary's automaton.  Replacing the bare call rather than adding to it
   would have taken those consumers' pointers away and turned a wrong answer
   into a crash for every base, which is why this is additive.

   Say the residual out loud rather than let the smaller fix read as the
   larger one: after this change riscv and mips reach codegen; nothing here
   makes the scheduler's own model per base.

   THAT RESIDUAL IS NOW CLOSED, AND THE REASON IT COULD NOT WAIT IS THE PART
   TO CARRY.  `target-automata.h' selects `state_size', `state_transition',
   `state_reset' and the rest per base.  This file's judgement that the
   residual was "a wrong answer" was too kind: `state_size' is the LENGTH of
   the DFA state buffer, so a back end sizing its own buffer from its own
   automaton while shared code overwrote `dfa_state_size' with the primary's
   was a heap overflow -- ia64 writing 116 bytes into 4, six ASAN runs of six.

   The two fixes are consumed together: the selected base's
   `state_transition' calls its own `internal_dfa_insn_code' through the
   pointer THIS file's initialiser fills in, so neither is sufficient alone
   and the additive shape here is still the right one.  */

#ifndef GCC_TARGET_SCHED_H
#define GCC_TARGET_SCHED_H

/* One back end's scheduler-attribute initialiser.  Filled in
   `target-cumargs.cc' compiled for that base, where `init_sched_attrs'
   resolves through that base's `insn-attr-<base>.h' using-directive.  */

struct target_sched_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* `insn_<base>::init_sched_attrs', or NULL for a back end whose `.md' has
     no `define_insn_reservation' at all -- `genattr' emits neither the
     pointers nor the initialiser for such a back end, and NULL here is that
     generator's own answer rather than a value invented here.

     "ONE IN-TREE BACK END IS IN THAT POSITION; THE OTHER FORTY-SEVEN HAVE A
     DFA" IS WHAT THIS COMMENT SAID, AND IT IS FALSE BY AN ORDER OF
     MAGNITUDE.  Measured from the generated headers themselves in a cold
     47-base build -- `#define INSN_SCHEDULING' in each
     `insn-attr-common-<base>.h', which IS `genattr-common''s answer, rather
     than a `grep' over `config/<be>/' which asks a different question
     (`a98009045f7229938-dfacensus.sh'):

	 47 headers
	 HAS an automaton   33
	 NO automaton       14   avr cris fr30 ft32 gcn h8300 mmix moxie
				 msp430 nvptx pdp11 rl78 vax xstormy16

     The figure matters because it is the population every `#ifdef
     INSN_SCHEDULING' in shared code was answering for with the primary's
     yes.  ELEVEN of those fourteen ICEd on `int f (int x) { return x + 1; }'
     at `-O2'; see target-automata.h.  Note also that the arithmetic in the
     old sentence never closed -- 1 + 47 = 48 in a 47-back-end tree.

     AND THE FIRST READING OF THIS CENSUS SAID 34/13 OVER 45 HEADERS, WHICH IS
     WORTH RECORDING BECAUSE IT IS THIS FILE'S OWN SUBJECT.  It was taken
     while the build was still generating headers, so two of them did not
     exist yet -- `i386' (the primary) and `gcn'.  A directory being read
     mid-write looks exactly like a directory that is complete, and the
     missing entries were silently absent rather than reported: PRINCIPLES'
     "a log being written looks exactly like a log that finished", in a glob.
     The 47 is now printed beside the split so the two cannot be quoted
     apart.  */
  void (*init_attrs) (void);
};

/* The table in force, or NULL until a target is selected.  */
extern const struct target_sched_desc *targetm_sched;

/* Run the selected base's `init_sched_attrs', if it has one.  Shared code
   calls this IN ADDITION to the bare `init_sched_attrs ()' it already calls;
   see the note above on why it is not a replacement.  */
extern void mt_init_base_sched_attrs (void);

#endif /* GCC_TARGET_SCHED_H */
