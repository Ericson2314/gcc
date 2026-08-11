/* Overrides for elfos.h for AVR 8-bit microcontrollers.
   Copyright (C) 2011-2026 Free Software Foundation, Inc.
   Contributed by Georg-Johann Lay (avr@gjlay.de)

   This file is part of GCC.

   GCC is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   GCC is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GCC; see the file COPYING3.  If not see
   <http://www.gnu.org/licenses/>.  */

/* defaults.h requires HAVE_INITFINI_ARRAY_SUPPORT to be present
   in order for attribute "retain" to be recognized.  This is due
   to some quirks in crtstuff.h -- which isn't even used by avr.
   All we need is that Binutils supports the "R"etain section flag.
   If that's the case, define SUPPORTS_SHF_GNU_RETAIN so that
   defaults.h doesn't define it to 0.  */
/* avr wants SHF_GNU_RETAIN whenever the assembler has it, without defaults.h's
   additional .init_array requirement -- that is the whole point of overriding
   it here.  Was an `#if HAVE_GAS_SHF_GNU_RETAIN' around `#define ... 1', which
   also meant this target header had to `#include "auto-host.h"' to see a host
   build's answer about a target's assembler.  Both are gone: the capability is
   a runtime read.  */
#if defined(IN_GCC) && !defined(USED_FOR_TARGET) && !defined(GENERATOR_FILE)
#undef SUPPORTS_SHF_GNU_RETAIN
#define SUPPORTS_SHF_GNU_RETAIN (targ_caps.gas_shf_gnu_retain)
#endif

/* Overriding some definitions from elfos.h for AVR.  */

#undef PCC_BITFIELD_TYPE_MATTERS

#undef MAX_OFILE_ALIGNMENT
#define MAX_OFILE_ALIGNMENT (32768 * 8)

#undef STRING_LIMIT
#define STRING_LIMIT ((unsigned) 64)

/* Be conservative in crtstuff.c.  */
#undef INIT_SECTION_ASM_OP
#undef FINI_SECTION_ASM_OP

#undef ASM_DECLARE_FUNCTION_NAME
#define ASM_DECLARE_FUNCTION_NAME(STREAM, NAME, DECL) \
	avr_declare_function_name (STREAM, NAME, DECL)
