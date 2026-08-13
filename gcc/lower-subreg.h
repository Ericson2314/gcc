/* Target-dependent costs for lower-subreg.cc.
   Copyright (C) 2012-2026 Free Software Foundation, Inc.

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

#ifndef LOWER_SUBREG_H
#define LOWER_SUBREG_H 1

/* For MULTI_TARGET_UNION_MAX_BITS_PER_WORD; see the note in expmed.h.
   `struct target_lower_subreg' below is allocated by target-globals.cc and
   this header is reachable from back ends' own translation units, so its
   bounds must be the same number in both.  */
#ifdef GENERATOR_FILE
#ifndef MULTI_TARGET_UNION_MAX_BITS_PER_WORD
#define MULTI_TARGET_UNION_MAX_BITS_PER_WORD MAX_BITS_PER_WORD
#endif
#else
#include "multi-target-reg-widths.h"
#endif

/* Information about whether, and where, lower-subreg should be applied.  */
struct lower_subreg_choices {
  /* A boolean vector for move splitting that is indexed by mode and is
     true for each mode that is to have its copies split.  */
  bool move_modes_to_split[MAX_MACHINE_MODE];

  /* True if zero-extensions from word_mode to twice_word_mode should
     be split.  */
  bool splitting_zext;

  /* Index X is true if twice_word_mode shifts by X + BITS_PER_WORD
     should be split.  */
  bool splitting_ashift[MULTI_TARGET_UNION_MAX_BITS_PER_WORD];
  bool splitting_lshiftrt[MULTI_TARGET_UNION_MAX_BITS_PER_WORD];
  bool splitting_ashiftrt[MULTI_TARGET_UNION_MAX_BITS_PER_WORD];

  /* True if there is at least one mode that is worth splitting.  */
  bool something_to_do;
};

/* Target-specific information for the subreg lowering pass.  */
struct target_lower_subreg {
  /* An integer mode that is twice as wide as word_mode.  */
  scalar_int_mode_pod x_twice_word_mode;

  /* What we have decided to do when optimizing for size (index 0)
     and speed (index 1).  */
  struct lower_subreg_choices x_choices[2];
};

extern struct target_lower_subreg default_target_lower_subreg;
#if SWITCHABLE_TARGET
extern struct target_lower_subreg *this_target_lower_subreg;
#else
#define this_target_lower_subreg (&default_target_lower_subreg)
#endif

#endif
