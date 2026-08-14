/* Common Backend requirements.

   Copyright (C) 2015-2026 Free Software Foundation, Inc.
   Contributed by Andrew MacLeod <amacleod@redhat.com>

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

#ifndef GCC_BACKEND_H
#define GCC_BACKEND_H

/* This is an aggregation header file. This means it should contain only
   other include files.  */

#include "multi-target-header.h"
#include MT_HEADER (tm.h)
/* The multi-target conversion layer.  It already arrives through the tm.h
   above (defaults.h ends with it), so the include guard makes this line a
   no-op today.  It is here so that deleting the tm.h line does not also
   delete the CONVERTED macros -- see multi-target-macros.h.  */
#include "multi-target-macros.h"
#include "function.h"
#include "bitmap.h"
#include "sbitmap.h"
#include "basic-block.h"
#include "cfg.h"

#endif /*GCC_BACKEND_H */
