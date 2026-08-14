/* One back end's MODE-SWITCHING entity list, for shared code.
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

   `mode-switching.cc' wrapped its entire body -- and its pass gate -- in a
   raw `#ifdef OPTIMIZE_MODE_SWITCHING', and read the entity list with

       static const int num_modes[] = NUM_MODES_FOR_MODE_SWITCHING;
       #define N_ENTITIES ARRAY_SIZE (num_modes)

   Both macros come from the back end's `tm.h'.  `mode-switching.o' is SHARED
   -- compiled once, against the primary's headers -- so both were i386's, for
   every configured back end.  FIVE of forty-eight back ends define
   `OPTIMIZE_MODE_SWITCHING' at all (aarch64, epiphany, i386, riscv, sh), so
   the pass gate said "yes, this target does mode switching" to forty-three
   back ends that had never said so, and handed each of them I386'S ENTITY
   NUMBERING.

   Two distinct wrong answers came out of that one macro, and it is worth
   separating them because only the first is visible:

   - LEAKED PRESENCE.  ia64, visium and xtensa define neither macro.  The pass
     ran anyway, `optimize_mode_switching' walked i386's entities, and the
     first unguarded `targetm.mode_switching.*' call went through a NULL slot:
     frame `#0' at address `0x0'.  Three back ends stopped there.  The null
     pointer is WHERE they stop; this macro is WHY.

   - LEAKED NUMBERING.  aarch64, riscv and sh define both macros and got
     i386's list regardless: `{ AVX_U128, I387_ROUNDEVEN, ... }' rather than
     `{ aarch64_tristate_mode::MAYBE, aarch64_local_sme_state::ANY }'.  That
     one produces no crash at all -- a different count of entities, each
     numbered as something else, silently.  It is the `UNSPECV_BLOCKAGE' shape
     (PRINCIPLES section 3: shared numbering, several authorities) arriving in
     a pass rather than in a pattern.

   WHY THE ENTITY LIST IS DATA AND NOT A UNION.  An entity number indexes THIS
   back end's own enum; there is no shared vocabulary to union, only a list to
   select, exactly as `target-attr.h' argues for attribute tables.  Per
   PRINCIPLES section 2 this is a HOOK and not a `target-specs' capability:
   the answer comes from the back end's headers, ships with the compiler, and
   cannot differ between two installations serving the same target.

   HOW "THIS BACK END DOES NO MODE SWITCHING" IS EXPRESSED, AND WHY THAT IS
   NOT AN INVENTED DEFAULT.  `n_entities == 0'.  That is not a floor and not a
   fallback: it is what the ABSENCE of `OPTIMIZE_MODE_SWITCHING' in that back
   end's own `tm.h' already means, read in the one translation unit that is
   compiled against that back end's headers.  Upstream, a target that does not
   define the macro compiles a `mode-switching.o' whose gate returns false;
   here the same back end supplies a table saying zero entities and the gate
   returns false for it and only for it.  No base ever reads another's answer,
   which is the test PRINCIPLES section 2a states.

   The remaining hazard is the OPPOSITE one and it is checked rather than
   assumed: a base that DOES define the macro but whose table says zero would
   silently stop doing mode switching.  `target-cumargs.cc' derives both
   fields from the same `#ifdef', so the two cannot disagree, and
   `multi-target-select.cc' refuses a null table by name.  */

#ifndef GCC_TARGET_MODESWITCH_H
#define GCC_TARGET_MODESWITCH_H

/* One back end's mode-switching entity list.  Filled in `target-cumargs.cc'
   compiled for that base, where `OPTIMIZE_MODE_SWITCHING' and
   `NUM_MODES_FOR_MODE_SWITCHING' are that base's own macros.  */

struct target_modeswitch_desc
{
  /* The cpu_type this describes, for diagnostics.  */
  const char *name;

  /* ARRAY_SIZE (NUM_MODES_FOR_MODE_SWITCHING), or 0 for a back end that
     defines no OPTIMIZE_MODE_SWITCHING.  See the note above on why 0 is this
     base's own answer and not a default.  */
  int n_entities;

  /* NUM_MODES_FOR_MODE_SWITCHING itself: entry E is the number of modes
     entity E can be in.  NULL exactly when N_ENTITIES is 0.  */
  const int *num_modes;

  /* OPTIMIZE_MODE_SWITCHING (E).  A FUNCTION and not a bool, because the
     macro is not a constant in any of the five back ends that define it: it
     reads option state (`TARGET_VECTOR', `TARGET_FPU_DOUBLE'), a global array
     (`ix86_optimize_mode_switching[]') or a back-end function.  Baking it
     into the table at static-initialisation time would freeze it before
     option processing -- the `ix86_pmode Init (PMODE_SI)' shape.  NULL
     exactly when N_ENTITIES is 0.  */
  bool (*optimize_p) (int entity);
};

/* The table in force, or NULL until a target is selected.  NULL and not the
   primary's, for the reason target-regs.h argues at length.  Shared code goes
   through the `mt_' functions below so the by-name diagnostic cannot be
   bypassed.  */
extern const struct target_modeswitch_desc *targetm_modeswitch;

/* Shared code's spellings.  `mt_mode_switching_p' is the pass gate: true iff
   the selected back end lists at least one entity.  */
extern bool mt_mode_switching_p (void);
extern int mt_mode_switch_n_entities (void);
extern const int *mt_mode_switch_num_modes (void);
extern bool mt_optimize_mode_switching (int entity);

#endif /* GCC_TARGET_MODESWITCH_H */
