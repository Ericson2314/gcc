/* Measure one back end's register-vocabulary widths, without running anything.
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

/* WHY THIS IS NOT A GENERATOR

   Every other union on this branch takes its inputs from a `gen*' program's
   records.  This one cannot.  `FIRST_PSEUDO_REGISTER' is `(LAST_FAKE_REGNUM +
   1)' for aarch64 and `FIRST_PSEUDO_REG' for i386; `N_REG_CLASSES' is
   `((int) LIM_REG_CLASSES)' for both -- ENUM-DERIVED, so the preprocessor
   cannot read them, and `tm.h' guards the `config/<cpu>/<cpu>.h' include on
   IN_GCC, which `INTERNAL_CFLAGS' supplies only for HOST compilation
   (Makefile.in:1258).  No `build/gen*' program sees these names at all.

   What does work is a host COMPILE plus `nm -S': declare an array whose bound
   is the value and read the object's size back out.  Nothing is executed, so
   the answer is still correct when the compiler is being cross-built --
   which is the property a `#error'-and-read-the-message trick or a run-time
   printf would both lose.

   +1 ON EVERY BOUND, DELIBERATELY.  A zero-sized object and an object `nm'
   failed to report are indistinguishable, and a missing answer must never be
   able to act as an answer.  gen-reg-widths.sh subtracts the 1 and rejects
   any symbol it did not find or whose size came back 0.

   -DMULTI_TARGET_REG_PROBE IS WHAT BREAKS THE CIRCULARITY.  defaults.h's
   union block is skipped for this translation unit, so it measures the back
   end's OWN width rather than the union -- without which the union would be
   the maximum of itself, a fixed point at whatever the first build wrote.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"

#ifndef MULTI_TARGET_REG_PROBE
#error multi-target-reg-probe.cc must be compiled with -DMULTI_TARGET_REG_PROBE \
(without it defaults.h overrides the very widths this file exists to measure, \
and the union becomes the maximum of itself)
#endif

/* `extern "C"' so the names `gen-reg-widths.sh' greps for are the names in
   the object file.  They are definitions, not declarations, so they have a
   size for `nm -S' to report.  */
extern "C" {
char mt_probe_first_pseudo_register[FIRST_PSEUDO_REGISTER + 1];
char mt_probe_n_reg_classes[N_REG_CLASSES + 1];
}
