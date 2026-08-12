/* Union-bounded storage for CUMULATIVE_ARGS in shared translation units.
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

/* THE STORAGE PROBLEM, WHICH IS NOT THE ROUTING PROBLEM

   `CUMULATIVE_ARGS' is a TYPE.  Six shared translation units put one on the
   STACK -- function.cc's `assign_parm_data_all', calls.cc twice, expr.cc,
   dse.cc, var-tracking.cc -- and emit-rtl.h puts one inside the GC-allocated
   `incoming_args'.  Every one of those is compiled ONCE, against the
   PRIMARY's tm.h, so the storage is the primary's size; the SELECTED back
   end's `init_cumulative_args' then writes its own.  Measured:

       sizeof (CUMULATIVE_ARGS)    i386  96   aarch64 184
       alignof (CUMULATIVE_ARGS)   i386   8   aarch64   8

   88 bytes past the end of a stack frame, on the path every function
   compilation takes.  It is the `cl_optimization' shape (`52fa9e763c5', 8
   bytes past a GC object) an order of magnitude larger and on the frame.

   ROUTING `INIT_CUMULATIVE_ARGS' THROUGH A TABLE DOES NOT FIX THIS ON ITS
   OWN, and that is the whole point of separating the two headers: a table
   would have aarch64 write ITS 184-byte struct into i386-shaped 96-byte
   storage, which is the same overflow reached by a tidier route.  The bound
   below fixes the storage; target-cumargs.h routes the writer.  Neither is
   useful without the other, and they are separate files so that a future
   reader cannot mistake one for the other.

   WHY A BOUND AND NOT A PER-BASE TYPE.  The storage is declared in code that
   is compiled once and must have ONE layout -- `incoming_args' is a member of
   `rtl_data', which generic code allocates and every back end reads, so its
   offsets have to agree in every translation unit in the program.  That is
   exactly the constraint `multi-target-reg-widths.h' already answers for the
   register vocabulary: one compile-time maximum over the configured bases,
   identical everywhere, with the per-base data selected at run time.

   WHY THIS IS NOT AN `#ifndef' FLOOR.  The bound is MEASURED, from the
   configured bases, by the same compile-plus-`nm -S' probe as the register
   widths (multi-target-reg-probe.cc), and target-cumargs.cc asserts each
   base against it.  There is no default: a build that learns nothing fails in
   gen-reg-widths.sh, and a base that outgrows the bound fails by name at
   compile time.  */

#ifndef GCC_MT_CUMULATIVE_ARGS_H
#define GCC_MT_CUMULATIVE_ARGS_H

/* A GENERATOR IS SINGLE-TARGET BY CONSTRUCTION AND MUST NOT REACH THE
   GENERATED BOUND -- because requiring it is a dependency CYCLE, not merely
   unnecessary work:

     multi-target-reg-widths.h -> mt-<base>/reg-probe.o -> <base>-inc/s-inc
       -> insn-*.h -> build/gencondmd-<triple> -> emit-rtl.h
       -> mt-cumulative-args.h -> multi-target-reg-widths.h

   The bound is measured from probe objects that are compiled against headers
   the generators produce.  NO ORDERING EDGE CAN FIX THAT; the cycle has to be
   cut, and this is the only arc in it that is wrong -- a generator has no
   business knowing what OTHER back ends need.

   This is #109.  Its symptom is that a FRESH build directory cannot build at
   all (`multi-target-reg-widths.h: No such file or directory' out of
   build/gencondmd-<triple>.cc), while every directory in which
   gen-reg-widths.sh had once been run by hand builds fine -- which is why it
   survived unnoticed since `ecad6abf6ae' and why it reads as a missing rule.
   The rule is not missing: gen-multi-target-md.awk emits it and
   multi-target-md.mk carries it.  It is unreachable.

   THE VALUES BELOW ARE NOT A FALLBACK AND NOT A DEFAULT, which matters
   because a fabricated bound here would be exactly the class of change that
   undoes this branch.  A generator is compiled against exactly one base's
   tm.h, so the union over "every back end this translation unit serves" is
   that base's own `CUMULATIVE_ARGS' -- the same arithmetic the generated
   header does, over a set of size one.  MT_INCOMING_ARGS_PAD accordingly
   comes out as 1 and both assertions below hold with equality, which is
   precisely what they do for the LARGEST base in a real multi-target build.

   A generator also never instantiates `rtl_data'; all that is required of it
   here is that `struct incoming_args' compile.  */
#ifdef GENERATOR_FILE
#define MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE ((int) sizeof (CUMULATIVE_ARGS))
#define MULTI_TARGET_UNION_CUMULATIVE_ARGS_ALIGN \
  ((int) alignof (CUMULATIVE_ARGS))
#else
#include "multi-target-reg-widths.h"
#endif

/* Storage for one `CUMULATIVE_ARGS', big enough and aligned enough for EVERY
   configured back end.

   Deliberately opaque bytes rather than a union with a `CUMULATIVE_ARGS'
   member.  A union would let a shared translation unit reach the primary's
   view of the bytes by accident -- write through one shape and read back
   through another, which is the `cl_target_option' half of `52fa9e763c5' --
   and there is nothing a shared translation unit may legitimately do with the
   fields.  It hands the address to the selected back end through
   `cumulative_args_t' and gets answers back through hooks.  */
struct mt_cumulative_args
{
  alignas (MULTI_TARGET_UNION_CUMULATIVE_ARGS_ALIGN)
  unsigned char mt_raw[MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE];
};

/* THE `crtl->args.info' BOUND, WHICH HAD TO BE DONE DIFFERENTLY.

   `incoming_args::info' cannot become an `mt_cumulative_args': nineteen back
   ends spell `crtl->args.info.<field>' (aarch64.cc four times, s390.cc
   fourteen, ...) and each one legitimately means ITS OWN struct.  So that
   member keeps its `CUMULATIVE_ARGS' type -- which is the right type in every
   translation unit that reads it -- and is followed by MT_INCOMING_ARGS_PAD
   bytes of tail, so that the FIELD is per-base and the FOOTPRINT is the
   union.  A back end writing 184 bytes at `&crtl->args.info' then stays
   inside the object in a build whose middle end sized it at 96.

   THE PAD IS WHAT MAKES THE LAYOUT UNIFORM, not merely large enough, and that
   is worth stating because it is the property the whole struct depends on:
   `info' plus the pad is `MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE + 1' bytes
   in EVERY translation unit -- 96 + 89 for i386, 184 + 1 for aarch64 -- so
   everything after `info' in `incoming_args' (and everything after
   `incoming_args' in `rtl_data') sits at the same offset whichever base
   compiled the file.  A pad that merely reserved the difference where it was
   positive would give the largest base a shorter struct than the others.

   The `+ 1' keeps the array from being zero-length when the primary happens
   to be the largest base, which is legal in GNU C++ but is not something to
   depend on; one byte is not worth a conditional.

   ALIGNMENT IS THE HALF A PAD CANNOT FIX, so it is asserted instead.  The
   offset of `info' is chosen by the primary's alignment, and a base needing
   MORE would be misaligned however much tail follows.  Today every configured
   base wants 8 and the assertion is exactly at the limit -- 8 <= 8, no slack,
   like the `9 <= 9' pair in `52fa9e763c5' -- which is the point: the first
   base that disagrees is a compile error naming this, not a misaligned store.
   The assertion lives in a header reached by BOTH shared and per-back-end
   translation units, so it is checked once per base as well as once for the
   primary.  */
#define MT_INCOMING_ARGS_PAD \
  (MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE - (int) sizeof (CUMULATIVE_ARGS) + 1)

static_assert (MULTI_TARGET_UNION_CUMULATIVE_ARGS_ALIGN
	       <= (int) alignof (CUMULATIVE_ARGS),
	       "some configured back end's CUMULATIVE_ARGS needs stricter "
	       "alignment than this one's, so the offset of "
	       "incoming_args::info -- chosen by THIS translation unit -- is "
	       "not good enough for it; MT_INCOMING_ARGS_PAD only fixes size");

static_assert ((int) sizeof (CUMULATIVE_ARGS)
	       <= MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE,
	       "this back end's CUMULATIVE_ARGS is larger than the union bound "
	       "in multi-target-reg-widths.h; gen-reg-widths.sh did not see it");

/* The `pack_cumulative_args' overload for this storage is in
   target-cumargs.h, NOT here, and the split is forced rather than tidy: this
   header is reached from emit-rtl.h, which 200-odd translation units include
   before they have seen target.h -- including every back end's own objects,
   where the first one to try it (mt-aarch64/aarch-common.o) reported
   `cumulative_args_t does not name a type'.  The storage bound needs nothing
   but tm.h; the packing needs the wrapper type.  */

#endif /* GCC_MT_CUMULATIVE_ARGS_H */
