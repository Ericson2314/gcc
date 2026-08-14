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
