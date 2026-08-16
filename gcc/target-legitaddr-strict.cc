/* One back end's GO_IF_LEGITIMATE_ADDRESS, expanded with REG_OK_STRICT.
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

/* WHY THIS FILE EXISTS AT ALL, WHEN target-cumargs.cc IS ALREADY COMPILED
   ONCE PER BASE AND COULD HOLD ONE MORE THUNK.

   `GO_IF_LEGITIMATE_ADDRESS' is the only macro in the converted population so
   far whose EXPANSION depends on a second macro that is fixed when the header
   chain is READ rather than when the macro is USED.  `REG_OK_STRICT' is
   defined before the includes in `reload.cc' and `#undef'ed in
   `lra-constraints.cc'; a back end then supplies two bodies:

       fr30.h:601   #ifdef REG_OK_STRICT
                    #define REG_OK_FOR_BASE_P(X) \
                              (((unsigned) REGNO (X)) <= STACK_POINTER_REGNUM)
                    #else
                    #define REG_OK_FOR_BASE_P(X) 1
                    #endif

   and `fr30.h:549' / `:571' are two whole `GO_IF_LEGITIMATE_ADDRESS' bodies
   selected by the same `#ifdef', differing in that one and in whether
   ARG_POINTER_REGNUM is an acceptable base.  A single translation unit can
   read the header chain once and therefore holds exactly ONE of the two.  So
   the strict answer needs its own translation unit: `target-cumargs.cc' is
   compiled without `REG_OK_STRICT' and supplies the NON-strict thunk, and
   this file defines `REG_OK_STRICT' ahead of every include and supplies the
   strict one.  The definition is the FIRST thing in the file for that reason
   -- moving it below the includes would silently produce a second copy of the
   non-strict body under the strict name, which compiles, links, and is wrong
   in the direction that accepts a pseudo as a base register.

   WHAT WAS WRONG.  `fr30' is the tree's only definer of
   `GO_IF_LEGITIMATE_ADDRESS'.  Shared code asked the PRIMARY, and i386
   defines no such macro, so `recog.cc:1894', `reload.cc:2167' and
   `lra-constraints.cc:356' all took their `#else' arm -- correct for the 46
   bases that define nothing -- and `targhooks.cc:108's
   `default_legitimate_address_p' took its `#else' arm too, which is
   `gcc_unreachable ()'.  fr30 supplies no `TARGET_LEGITIMATE_ADDRESS_P' of
   its own, so that default IS its address predicate: every memory reference
   fr30 compiled reached an ICE.  Leaked ABSENCE, and the loud kind -- unlike
   FINAL_PRESCAN_INSN and DELAY_SLOTS it announces itself, which is why it is
   the least dangerous of the three and still the same defect.

   The symbol is named from `MULTI_TARGET_TARGETM_BASE', the same `-D' that
   names this base everywhere else, so the definition here and the
   declaration in `target-cumargs.cc' cannot drift: one authority, pasted the
   same way on both sides.  */

/* FIRST, before anything can read a back end's header chain.  */
#define REG_OK_STRICT

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "multi-target-base.h"
#include BASE_HEADER (tm.h)
#include "rtl.h"
#include "tree.h"
#include "memmodel.h"
/* For whatever this base's macro calls into; a definer may spell a function
   declared in its own `<cpu>-protos.h'.  */
#include BASE_HEADER (tm_p.h)
#include "target.h"
#include "target-legitaddr.h"

bool
MT_LEGITADDR_STRICT_FN (machine_mode mode ATTRIBUTE_UNUSED,
			rtx addr ATTRIBUTE_UNUSED,
			bool *win ATTRIBUTE_UNUSED)
{
#ifdef GO_IF_LEGITIMATE_ADDRESS
  GO_IF_LEGITIMATE_ADDRESS (mode, addr, mt_legit_ok);
  *win = false;
  return true;

 mt_legit_ok:
  *win = true;
  return true;
#else
  /* This base defines no such macro; say so rather than answering.  The
     caller then does what shared code did before -- go through
     `targetm.addr_space.legitimate_address_p' -- which is the right answer
     for 46 of the 47 bases and was the right answer for those 46 before this
     change too.  */
  return false;
#endif
}
