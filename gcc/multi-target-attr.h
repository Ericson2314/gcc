/* Redirect shared code's insn-attribute questions to the back end in force.
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

/* See target-attr.h for what this fixes, how it was measured, and why
   "this base has no such attribute" is a return value rather than a fork.

   `genattr' emits `#include "multi-target-attr.h"' as the LAST line of the
   build root's `insn-attr.h' -- the un-namespaced one it writes from the
   primary's `.md' -- and only on a multi-target build.  A back end's own
   `insn-attr-<base>.h' never names this file, so a back end's translation
   unit keeps the generated declarations and this header is invisible to it.

   THE ORDER IS THE POINT, exactly as in `multi-target-preds.h': every name
   below is DECLARED in the text above the include, so these macros rename
   USES and not DECLARATIONS.

   MULTI_TARGET_ATTR_NO_REDIRECT is defined by the generated `insn-attrtab.cc',
   `insn-dfatab.cc' and `insn-latencytab.cc' -- everything `genattrtab'
   writes through `write_header'.  Those files DEFINE `get_attr_enabled',
   `insn_default_length' and the rest, and renaming a definition would have
   them define `mt_get_attr_enabled' instead, colliding with the forwarder in
   `target-cumargs-select.cc'.  The guard is emitted by `genattrtab' under the
   same condition as the include, so the two cannot drift apart.

   WHY THE `HAVE_ATTR_*' RENAMES ARE SAFE HERE AND WOULD NOT HAVE BEEN
   ANYWHERE ELSE.  A macro that expands to a CALL is silently 0 on a `#if'
   line: the preprocessor turns `mt_have_attr_length ()' into `0 ()' ... into
   0, with no diagnostic.  Every `#if HAVE_ATTR_*' in shared code was found
   and rewritten to a runtime `if' BEFORE these renames were added -- the two
   pass gates in `recog.cc'.  A guard arm asserts there is no
   `#if HAVE_ATTR_' left outside `config/' and the generators, because a new
   one would fail silently and in the direction that looks like a working
   build.  */

#ifndef GCC_MULTI_TARGET_ATTR_H
#define GCC_MULTI_TARGET_ATTR_H

#if !defined GENERATOR_FILE && !defined MULTI_TARGET_ATTR_NO_REDIRECT

#include "target-attr.h"
#include "target-automata.h"

/* WHICH ATTRIBUTES THE SELECTED BASE HAS.  Not a union: see target-attr.h.
   aarch64 has no `preferred_for_size' and i386 does, and telling shared code
   that the selected back end has one when it does not is the `HAVE_V8HFmode'
   failure -- the union's answer leaking -- rather than a conservative one.  */
#undef HAVE_ATTR_length
#define HAVE_ATTR_length mt_have_attr_length ()

#undef HAVE_ATTR_enabled
#define HAVE_ATTR_enabled mt_have_attr_enabled ()

#undef HAVE_ATTR_preferred_for_size
#define HAVE_ATTR_preferred_for_size mt_have_attr_preferred_for_size ()

#undef HAVE_ATTR_preferred_for_speed
#define HAVE_ATTR_preferred_for_speed mt_have_attr_preferred_for_speed ()

/* OBJECT-LIKE, NOT FUNCTION-LIKE, and that is load-bearing rather than
   stylistic: `shorten_branches' (final.cc:1015, final.cc:1068) takes the
   ADDRESS of `insn_min_length' and `insn_default_length' and passes it as an
   `int (*) (rtx_insn *)'.  A function-like macro would not expand there at
   all, leaving those two call paths on the primary's copy while every other
   use moved -- a half-conversion that builds and links clean.  */
#undef get_attr_enabled
#define get_attr_enabled mt_get_attr_enabled

#undef get_attr_preferred_for_size
#define get_attr_preferred_for_size mt_get_attr_preferred_for_size

#undef get_attr_preferred_for_speed
#define get_attr_preferred_for_speed mt_get_attr_preferred_for_speed

#undef insn_default_length
#define insn_default_length mt_insn_default_length

#undef insn_min_length
#define insn_min_length mt_insn_min_length

#undef insn_current_length
#define insn_current_length mt_insn_current_length

/* THE DFA PIPELINE-HAZARD ENTRY POINTS; see target-automata.h.

   OBJECT-LIKE, NOT FUNCTION-LIKE, for the reason stated above, and because
   `insn_default_latency' is a function POINTER upstream of this rename --
   an object-like macro leaves every call site's spelling untouched whether
   the name was a function or a pointer.

   `max_insn_queue_index' is the one that is NOT a call in the original: it
   is `extern const int'.  It appears in three macro BODIES in haifa-sched.cc
   (`INVALID_TICK', `MIN_TICK', `NEXT_Q') as well as in 22 ordinary
   expressions; macro bodies are expanded at their use, so the rewrite
   reaches all 25 sites.  */
#undef state_size
#define state_size mt_state_size

#undef max_insn_queue_index
#define max_insn_queue_index mt_max_insn_queue_index ()

#undef state_reset
#define state_reset mt_state_reset

#undef state_transition
#define state_transition mt_state_transition

#undef state_dead_lock_p
#define state_dead_lock_p mt_state_dead_lock_p

#undef min_insn_conflict_delay
#define min_insn_conflict_delay mt_min_insn_conflict_delay

#undef print_reservation
#define print_reservation mt_print_reservation

#undef dfa_start
#define dfa_start mt_dfa_start

#undef dfa_finish
#define dfa_finish mt_dfa_finish

#undef dfa_clear_single_insn_cache
#define dfa_clear_single_insn_cache mt_dfa_clear_single_insn_cache

#undef bypass_p
#define bypass_p mt_bypass_p

#undef insn_latency
#define insn_latency mt_insn_latency

#undef maximal_insn_latency
#define maximal_insn_latency mt_maximal_insn_latency

#undef insn_default_latency
#define insn_default_latency mt_insn_default_latency

/* NOT REDIRECTED, AND EACH FOR A STATED REASON -- silence about a name in
   this family would read as "checked and clean".

   `get_attr_length' and `get_attr_min_length' are HAND-WRITTEN in final.cc
   (declared in output.h) as wrappers over `insn_default_length' and
   `insn_min_length'.  Redirecting the two leaves above moves them with it,
   and there is only ever one definition of the wrapper.

   `insn_variable_length_p' is stubbed by genattr but is named by no shared
   translation unit in this tree; measured, not assumed.

   THE SCHEDULING ENTRY POINTS ARE NO LONGER IN THIS PARAGRAPH -- they are
   redirected above, and what changed the verdict is worth recording.  An
   earlier version of this comment said they were "deliberately left alone"
   because they were a modelling leak with `haifa-sched.o' as the dominant
   consumer.  They are not only that: `state_size' is the LENGTH of the DFA
   state buffer, so leaving it bare is a heap overflow and not a wrong
   answer.  See target-automata.h for the ASAN report.

   `internal_dfa_insn_code' is STILL not redirected, and that is measured
   rather than inherited: outside comments, no shared translation unit names
   it.  It is a function POINTER that each base's `init_sched_attrs ()'
   assigns, and `mt_init_base_sched_attrs' (target-sched.h) is what makes the
   selected base's copy non-null -- which the redirected `state_transition'
   above then consumes.  The two fixes are used together and neither is
   sufficient alone.

   `min_issue_delay', `get_cpu_unit_code', `cpu_unit_reservation_p',
   `insn_has_dfa_reservation_p', `dfa_clean_insn_cache', `state_alts' and
   `insn_alts' are exported by `insn-automata.cc' and named by no shared
   translation unit; measured, not assumed.  */

#endif /* !GENERATOR_FILE && !MULTI_TARGET_ATTR_NO_REDIRECT */

#endif /* GCC_MULTI_TARGET_ATTR_H */
