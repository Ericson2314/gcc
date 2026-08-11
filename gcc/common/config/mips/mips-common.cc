/* Common hooks for MIPS.
   Copyright (C) 1989-2026 Free Software Foundation, Inc.

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

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm-mips.h"
#include "common/common-target.h"
#include "common/common-target-def.h"
#include "opts.h"
#include "flags.h"
#include "target-caps.h"
#include "config/mips/mips-opts.h"

/* Implement TARGET_HANDLE_OPTION.  */

static bool
mips_handle_option (struct gcc_options *opts,
		    struct gcc_options *opts_set ATTRIBUTE_UNUSED,
		    const struct cl_decoded_option *decoded,
		    location_t loc ATTRIBUTE_UNUSED)
{
  size_t code = decoded->opt_index;

  switch (code)
    {
    case OPT_mno_flush_func:
      opts->x_mips_cache_flush_func = NULL;
      return true;

    case OPT_mfp32:
    case OPT_mfp64:
      opts->x_target_flags &= ~MASK_FLOATXX;
      return true;

    case OPT_mfpxx:
      opts->x_target_flags &= ~MASK_FLOAT64;
      return true;

    default:
      return true;
    }
}

/* Implement TARGET_OPTION_INIT_STRUCT.

   Two defaults that used to be answered when GCC itself was configured, by
   probing one assembler and one linker, and frozen into the build:

     MIPS_EXPLICIT_RELOCS  reached mips.opt as the `Init (...)' of
			   -mexplicit-relocs=, through tm_defines;
     MASK_RELAX_PIC_CALLS  was OR'd into target_cpu_default, i.e. into
			   TARGET_DEFAULT_TARGET_FLAGS below.

   Neither could stay where it was.  `Init (...)' becomes a static initializer
   in generated options.cc and TARGET_DEFAULT_TARGET_FLAGS is a DEFHOOKPOD;
   both need constant expressions, and neither can read targ_caps.  This hook
   can: it runs after the Init values are installed and BEFORE the command line
   is decoded, so it sets a default that an explicit -mexplicit-relocs= still
   overrides.

   The enum is DERIVED here rather than recorded in targ_caps.  What the
   assembler accepts is two independent yes/no answers; which of NONE/BASE/PCREL
   to default to is a decision about this back end, and it belongs where the
   enum is visible.  Storing the decision would also let it disagree with the
   two answers it came from.  */

static void
mips_option_init_struct (struct gcc_options *opts)
{
  if (targ_caps.as_mips_explicit_relocs_pcrel)
    opts->x_mips_opt_explicit_relocs = MIPS_EXPLICIT_RELOCS_PCREL;
  else if (targ_caps.as_mips_explicit_relocs)
    opts->x_mips_opt_explicit_relocs = MIPS_EXPLICIT_RELOCS_BASE;
  else
    opts->x_mips_opt_explicit_relocs = MIPS_EXPLICIT_RELOCS_NONE;

  /* Relaxing an indirect call through $25 into a direct branch needs the
     explicit R_MIPS_JALR relocation from BOTH the assembler and the linker,
     and target-specs asks both.  It also needs the explicit relocation
     operators the answer above is about, which is why the old probe was nested
     inside that one -- and why, when that one was removed, this one silently
     answered "no" on every target rather than failing.  */
  if (targ_caps.as_ld_mips_jalr_reloc
      && opts->x_mips_opt_explicit_relocs != MIPS_EXPLICIT_RELOCS_NONE)
    opts->x_target_flags |= MASK_RELAX_PIC_CALLS;
}

#undef TARGET_OPTION_INIT_STRUCT
#define TARGET_OPTION_INIT_STRUCT mips_option_init_struct

#undef TARGET_DEFAULT_TARGET_FLAGS
#define TARGET_DEFAULT_TARGET_FLAGS		\
  (TARGET_DEFAULT				\
   | TARGET_CPU_DEFAULT				\
   | TARGET_ENDIAN_DEFAULT			\
   | MASK_CHECK_ZERO_DIV)
#undef TARGET_HANDLE_OPTION
#define TARGET_HANDLE_OPTION mips_handle_option

struct gcc_targetm_common TARGETM_COMMON_SYMBOL = TARGETM_COMMON_INITIALIZER;
