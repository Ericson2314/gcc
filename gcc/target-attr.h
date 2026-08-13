/* One back end's INSN-ATTRIBUTE entry points, for shared code.
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

/* WHAT WAS WRONG.

   `genattrtab' already writes one `insn-attrtab-<base>.cc' per back end, each
   in `namespace insn_<base>', and `genattr' already writes one
   `insn-attr-<base>.h'.  Both are built and both are linked.  Nothing in
   shared code selected between them: `recog.o' and `final.o' bound the BARE
   names out of the un-namespaced `insn-attrtab.o' that `$(OBJS)' still
   carries, i.e. the primary's.

   Measured in an x86_64 + aarch64 `cc1' compiling
   `int g (int a) { return a + 1; }' for aarch64:

       get_attr_enabled   insn-attrtab.o          [bare, = i386's]
                          insn-attrtab-i386.o     [insn_i386::]
                          insn-attrtab-aarch64.o  [insn_aarch64::]
       ... and recog.o binds the BARE one.

   `get_bool_attr_mask_uncached' therefore asked i386's attribute tables which
   alternatives of aarch64's insn code 157 (`*adddi3_aarch64') were enabled.
   The answer disabled alternative 3 -- the `J' negative-immediate one that
   `(set (reg/f:DI 31 sp) (plus:DI (reg/f:DI 31 sp) (const_int -16)))' needs --
   and the compiler died in `final_scan_insn_1' with "insn does not satisfy
   its constraints", emitting no assembly at all.

   One name, several authorities, no diagnostic: PRINCIPLES section 3.

   WHY A TABLE AND NOT A UNION.  An attribute table maps THIS back end's insn
   codes to THIS back end's answers.  Insn codes are per base -- `NUM_INSN_CODES'
   is 15429 for i386 and 20512 for aarch64 -- so there is no vocabulary to
   union here, only data to select.  Per PRINCIPLES section 2 this is a HOOK
   and not a `target-specs' capability: the answers come from the `.md' file,
   ship with the compiler, and cannot differ between two installations serving
   the same target.

   THE `HAVE_ATTR_*' FORK, AND HOW IT WAS RESOLVED -- MEASURED, NOT ASSUMED.

   `recog.cc:2658' calls `get_attr_preferred_for_size' for every base, and
   aarch64 HAS NO SUCH ATTRIBUTE:

       HAVE_ATTR_length              shared=1  i386=1  aarch64=1
       HAVE_ATTR_enabled             shared=1  i386=1  aarch64=1
       HAVE_ATTR_preferred_for_size  shared=1  i386=1  aarch64=0
       HAVE_ATTR_preferred_for_speed shared=1  i386=1  aarch64=0

   There is no `insn_aarch64::get_attr_preferred_for_size' anywhere in the
   link, so a uniform table of function pointers cannot be filled until it is
   settled what a base with no such attribute puts in the slot.  The rule this
   branch forbids is inventing an answer; the rule it requires is to find out
   what "absent" ALREADY MEANS and reproduce exactly that.

   It means a constant 1.  `genattr.cc' emits, into EVERY base's header and
   OUTSIDE the namespace:

       extern int hook_int_rtx_1 (rtx);
       #if !HAVE_ATTR_preferred_for_size
       #define get_attr_preferred_for_size hook_int_rtx_1
       #endif

   and `hooks.cc:253' defines `hook_int_rtx_1' as `return 1;'.  So in a
   translation unit compiled with `-I<base>-inc', the spelling
   `get_attr_preferred_for_size (insn)' is ALREADY the right answer for that
   base -- the real function where the attribute exists, `hook_int_rtx_1'
   where it does not.  The thunks in `target-cumargs.cc' spell exactly that
   and nothing else.  Nothing here decides what absence means; the generator
   already decided, and this file is compiled once per base so that its
   decision is per base too.

   `insn-attr-<base>.h' ends with `using namespace insn_<base>;', which is
   what makes the unqualified spelling reach that base's namespaced
   definition.  That using-directive is why these thunks need no `insn_<base>::'
   qualification and why `target-cumargs.cc' needs no per-base source.

   Absence IS expressible as a return value here, so this is NOT the sjlj
   shape (a macro on a `#if' line that cannot become a runtime value).  The
   ONE place where it nearly was is the pair of `#if HAVE_ATTR_length' pass
   gates in `recog.cc'; those are rewritten to runtime `if', which compiles
   identically in both arms.  Had they not been rewritable, leaving them as a
   `#if' over a macro that now expands to a CALL would have silently
   evaluated to 0 -- both gates returning false with no diagnostic.  That is
   the trap this conversion had to step over, not around.

   THE INT BOUNDARY IS DELIBERATE, for the same reason `target-preds.h' gives:
   `enum attr_enabled' and friends are distinct types in each
   `namespace insn_<base>', so the table traffics in `int' and no base's enum
   ever crosses into shared code.  */

#ifndef GCC_TARGET_ATTR_H
#define GCC_TARGET_ATTR_H

/* One back end's insn-attribute entry points.  Every member is a thunk
   defined in `target-cumargs.cc' compiled for that base, where
   `#include "insn-attr.h"' resolves to that base's `insn-attr-<base>.h'.
   Compiling one file against one back end's headers is the whole mechanism;
   no back end is edited and no `target.def' entry is added.  */

struct target_attr_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* THIS BASE'S OWN `HAVE_ATTR_*'.  Not unioned: `HAVE_V8HFmode' is already
     on this branch's books as the case where the UNION's answer leaked, and
     "some configured back end has a preferred_for_size attribute" is not an
     answer to "does the selected one".  Carried as data so the `#if' in
     `insn-attr.h' stops being the authority for shared code.  */
  bool have_attr_length;
  bool have_attr_enabled;
  bool have_attr_preferred_for_size;
  bool have_attr_preferred_for_speed;

  /* THE MEMBER NAMES ARE DELIBERATELY SHORT, AND THAT IS NOT A STYLE CHOICE.

     `target-cumargs.cc' -- the file that fills this table -- includes the
     base's own `insn-attr.h', and that header ends with

         #define get_attr_preferred_for_size hook_int_rtx_1
         #define insn_default_length hook_int_rtx_insn_unreachable

     for a base lacking the attribute.  A member spelled `get_attr_enabled'
     is an ordinary identifier to the preprocessor, so those macros rewrite
     the STRUCT DECLARATION too: measured, the aarch64 compile produced two
     members both named `hook_int_rtx_1' and

         error: redeclaration of `int (* target_attr_desc::hook_int_rtx_1)
                (rtx_insn*)'
         error: too many initializers for `const target_attr_desc'

     It failed loudly here, but only because two of the four collided into
     one name.  A table with a single such member would have compiled, been
     initialised through a silently renamed field, and been correct on the
     primary.  `target_preds_desc' keeps short member names for the same
     reason; this is that lesson arriving a second time.  */

  /* recog.cc:2656-2660, through `get_bool_attr'.  Where the base has no such
     attribute the slot holds `hook_int_rtx_1', which is what the generated
     header already put there; see the long note above.  */
  int (*enabled) (rtx_insn *);
  int (*preferred_for_size) (rtx_insn *);
  int (*preferred_for_speed) (rtx_insn *);

  /* final.cc, through `get_attr_length' / `get_attr_min_length' (which are
     hand-written wrappers in final.cc, hence not in this table) and through
     `shorten_branches', which takes the ADDRESS of two of them.  Where the
     base has no `length' attribute the slot holds
     `hook_int_rtx_insn_unreachable', again the generated header's own
     answer.  */
  int (*default_length) (rtx_insn *);
  int (*min_length) (rtx_insn *);
  int (*current_length) (rtx_insn *);
};

/* The table in force, or NULL until a target is selected.  NULL and not the
   primary's, for the reason `target-regs.h' argues at length: a default here
   is exactly the bug being removed, and it is one the build machine cannot
   see.  Shared code goes through the `mt_' functions below so the by-name
   diagnostic cannot be bypassed.  */
extern const struct target_attr_desc *targetm_attr;

extern bool mt_have_attr_length (void);
extern bool mt_have_attr_enabled (void);
extern bool mt_have_attr_preferred_for_size (void);
extern bool mt_have_attr_preferred_for_speed (void);

extern int mt_get_attr_enabled (rtx_insn *);
extern int mt_get_attr_preferred_for_size (rtx_insn *);
extern int mt_get_attr_preferred_for_speed (rtx_insn *);
extern int mt_insn_default_length (rtx_insn *);
extern int mt_insn_min_length (rtx_insn *);
extern int mt_insn_current_length (rtx_insn *);

#endif /* GCC_TARGET_ATTR_H */
