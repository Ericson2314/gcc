/* Selecting which back end's machine description is in force.
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

#ifndef GCC_MULTI_TARGET_SELECT_H
#define GCC_MULTI_TARGET_SELECT_H

/* Install the back end serving TARGET, a configured target triple.  Returns
   false and changes nothing if TARGET is not one this compiler was built for.

   This is the machine-description half of selection; targetm_common_select
   (common/common-target.h) is the option-handling half, and both have to run.
   They are deliberately separate calls: the common table is needed before
   option decoding, the machine description is not, and collapsing them would
   hide that ordering.  Nothing here falls back on a default back end -- see
   multi-target-select.cc for why there is not one.  */
extern bool multi_target_select (const char *);

#endif /* GCC_MULTI_TARGET_SELECT_H */
