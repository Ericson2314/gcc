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

/* NOT REDIRECTED, AND EACH FOR A STATED REASON -- silence about a name in
   this family would read as "checked and clean".

   `get_attr_length' and `get_attr_min_length' are HAND-WRITTEN in final.cc
   (declared in output.h) as wrappers over `insn_default_length' and
   `insn_min_length'.  Redirecting the two leaves above moves them with it,
   and there is only ever one definition of the wrapper.

   `insn_variable_length_p' is stubbed by genattr but is named by no shared
   translation unit in this tree; measured, not assumed.

   `internal_dfa_insn_code', `insn_default_latency', `state_transition' and
   the rest of the SCHEDULING entry points are deliberately left alone: they
   belong to `insn-automata' / `insn-dfatab' / `insn-latencytab', which are
   three separate leaking families with `haifa-sched.o' as their dominant
   consumer.  `internal_dfa_insn_code' is a function POINTER assigned by
   `init_sched_attrs ()' -- genattrtab already makes it a pointer uniformly,
   so the kind mismatch is gone, but selecting it means selecting which base's
   `init_sched_attrs' RUNS, which is not a rename.  The leak ratchet in the
   guard script asserts they are still unselected, so wiring one up fails a
   check rather than landing unremarked.  */

#endif /* !GENERATOR_FILE && !MULTI_TARGET_ATTR_NO_REDIRECT */

#endif /* GCC_MULTI_TARGET_ATTR_H */
