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
/* THE ELIMINATION TABLE'S LENGTH, WHICH IS A THIRD KIND OF NUMBER AGAIN.

   `ELIMINABLE_REGS' is a brace initialiser, so its LENGTH is not a macro
   anybody can read: `reload1.cc' and `lra-eliminations.cc' both recover it by
   declaring a file-scope array from it and taking `ARRAY_SIZE'.  Compiled
   once against the primary's tm.h, that length -- and every register number
   in it -- is the primary's.  aarch64 and i386 happen to agree on FOUR pairs
   and disagree on all eight numbers (i386 arg/frame/stack/hard-frame are
   16/19/7/6, aarch64's are 65/64/31/29), so a length check alone would have
   scored the leak as absent; `vax.h:314' has ONE pair and `rs6000' has six,
   so the length genuinely varies.

   reload1.cc:318 declares `static poly_int64 (*offsets_at)[NUM_ELIMINABLE_REGS]'
   -- a pointer-to-ARRAY type, which cannot hold a run-time count.  That is the
   `sized by one authority, indexed by another' shape a fourth time, so the
   LAYOUT gets the union maximum measured here and the LOOPS get the selected
   base's own count from `target_frame_desc'.

   THE MAXIMUM OF BOTH TABLES.  `reload1.cc' uses `RELOAD_ELIMINABLE_REGS' when
   a back end defines one (no in-tree back end currently does, checked) and
   `ELIMINABLE_REGS' otherwise, while `lra-eliminations.cc' always uses
   `ELIMINABLE_REGS'.  Two tables, one array bound, so the bound is the larger
   -- taken here, in the translation unit where the `#ifdef' means this base.  */
static const struct { const int from, to; } mt_probe_elim[] = ELIMINABLE_REGS;
#ifdef RELOAD_ELIMINABLE_REGS
static const struct { const int from, to; } mt_probe_reload_elim[]
  = RELOAD_ELIMINABLE_REGS;
#define MT_PROBE_RELOAD_ELIM_N ((int) ARRAY_SIZE (mt_probe_reload_elim))
#else
#define MT_PROBE_RELOAD_ELIM_N ((int) ARRAY_SIZE (mt_probe_elim))
#endif
#define MT_PROBE_ELIM_N ((int) ARRAY_SIZE (mt_probe_elim))

extern "C" {
char mt_probe_first_pseudo_register[FIRST_PSEUDO_REGISTER + 1];
char mt_probe_n_reg_classes[N_REG_CLASSES + 1];
char mt_probe_num_eliminable_regs[(MT_PROBE_ELIM_N > MT_PROBE_RELOAD_ELIM_N
				   ? MT_PROBE_ELIM_N
				   : MT_PROBE_RELOAD_ELIM_N) + 1];

/* CUMULATIVE_ARGS IS MEASURED THE SAME WAY AND FOR THE SAME REASON.

   It is a TYPE -- `typedef struct ix86_args CUMULATIVE_ARGS' on i386, an
   anonymous struct given the name by typedef on aarch64 -- and shared
   translation units put one ON THE STACK (function.cc, calls.cc twice,
   expr.cc, dse.cc, var-tracking.cc) and one in a GC-allocated struct
   (`incoming_args::info', emit-rtl.h).  Compiled once against the primary's
   tm.h, every one of those is the PRIMARY'S SIZE, while the selected back
   end's `init_cumulative_args' writes ITS OWN.  Measured in a
   x86_64 + aarch64 build dir at the parent of this commit:

       sizeof (CUMULATIVE_ARGS)    i386  96   aarch64 184
       alignof (CUMULATIVE_ARGS)   i386   8   aarch64   8

   i.e. an 88-BYTE STACK OVERFLOW on every function aarch64 compiles -- the
   `cl_optimization' shape (`52fa9e763c5', 8 bytes past a GC object) an order
   of magnitude larger and on the frame.

   The preprocessor cannot read a `sizeof', so this is the same host compile
   plus `nm -S' as the two widths above, and for the same reason it executes
   nothing and stays correct when cross-building.  +1 on both bounds, so that
   "measured zero" and "nm printed nothing" remain different outcomes.  */
char mt_probe_cumulative_args_size[sizeof (CUMULATIVE_ARGS) + 1];
char mt_probe_cumulative_args_align[alignof (CUMULATIVE_ARGS) + 1];
}
