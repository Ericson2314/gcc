/* Selecting which back end's command-line option tables are in force.
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

   There is one `cl_options[]' and one `cl_enums[]' in the compiler, and they
   were generated from the PRIMARY back end's optionlist.  The option-name
   vocabulary is already unioned (opt-stub.awk), so every index means the same
   NAME in every back end -- but the CONTENT of an entry is the primary's.
   Measured in an x86_64 + aarch64 build, thirteen option names are declared by
   both back ends with different records, six of them with a different
   `Enum()':

       mabi=                    i386 Enum(calling_abi)  Var(ix86_abi)
                                a64  Enum(aarch64_abi)  Var(aarch64_abi)
       mcmodel=                 i386 Enum(cmodel)       a64 Enum(aarch64_cmodel)
       mtls-dialect=            i386 Enum(tls_dialect)  a64 Enum(aarch64_tls_type)
       mstack-protector-guard=  i386 Enum(ix86_...)     a64 Enum(aarch64_...)
       mharden-sls=             i386 Enum(harden_sls)   a64 a plain string
       mcpu=                    i386 an Alias(mtune=)   a64 Var(aarch64_cpu_string)
       march= mtune= mgeneral-regs-only momit-leaf-frame-pointer
       mstack-protector-guard-reg= mstack-protector-guard-offset=

   so an aarch64 target-config could not drive the driver at all:

       xgcc: error: unrecognized argument in option '-mabi=lp64'
       xgcc: note: valid arguments to '-mabi=' are: ms sysv

   THE FIX IS THE ESTABLISHED ONE AND THE UNION STOPS AT THE VOCABULARY.  The
   argument lists themselves must NOT be unioned: `-mabi=' has one meaning per
   target, and a table that accepted both back ends' arguments would make
   `lp64' a valid x86 ABI -- worse than the bug, because it would be silent.
   So the tables are per configuration (mt-<base>/options-tables.cc, generated
   by optc-gen.awk -v tables_base=<base> and compiled with that base's tm.h so
   an `EnumValue(... Value(AARCH64_ABI_LP64))' resolves where it was written),
   and this file chooses one at run time.

   NO PRIVILEGED DEFAULT.  The pointers start NULL, exactly as
   common/common-target-select.cc starts at the empty back end rather than at
   the build's own triple.  Initialising them to the primary's table would
   reinstate the bug in the one shape that cannot be tested for: correct on the
   build's own target and wrong on every other.  A missing selection is a NULL,
   and opts-common.cc turns that into a diagnostic naming the cause.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "opts.h"

/* Declares every configured base's tables and defines MT_OPTION_TABLES and
   MT_OPTION_TARGET_BASES.  Written by configure from the target list.  */
#include "multi-target-options.h"

/* Two lists, for the same reason multi-target-select.cc keeps two: the set of
   back ends whose tables are linked in, and the many-to-one map from the
   triple a target-config file names to the back end serving it.  Neither is
   derivable from the other.  */

struct mt_option_tables
{
  const char *base;
  const struct cl_option *options;
  const struct cl_enum *enums;
  unsigned int enums_count;
};

#define MT_OPTION_TABLE(BASE) \
  { #BASE, cl_options_ ## BASE, cl_enums_ ## BASE, cl_enums_ ## BASE ## _count },
static const struct mt_option_tables mt_option_tables[] = {
  MT_OPTION_TABLES
  { NULL, NULL, NULL, 0 }
};
#undef MT_OPTION_TABLE

struct mt_option_target_base
{
  const char *target;
  const char *base;
};

#define MT_OPTION_TARGET_BASE(TRIPLE, BASE) { TRIPLE, #BASE },
static const struct mt_option_target_base mt_option_target_bases[] = {
  MT_OPTION_TARGET_BASES
  { NULL, NULL }
};
#undef MT_OPTION_TARGET_BASE

/* An empty registry would compile and link, and every target would then be
   "not one of the targets this compiler was configured for" -- which reads as
   a manifest bug rather than as a header that was never generated.  Both
   arrays always carry their terminator, so 1 is the empty count.  */
#if !defined (MT_OPTION_TABLES) || !defined (MT_OPTION_TARGET_BASES)
# error "multi-target-options.h defined no registry: configure did not write it"
#endif

/* THE TABLES IN FORCE, and they start as none.  Not the primary's: see the
   header comment.  */
const struct cl_option *cl_options;
const struct cl_enum *cl_enums;
unsigned int cl_enums_count;

bool
multi_target_options_select (const char *target)
{
  const char *base = NULL;

  for (const struct mt_option_target_base *t = mt_option_target_bases;
       t->target != NULL; t++)
    if (strcmp (t->target, target) == 0)
      {
	base = t->base;
	break;
      }
  if (base == NULL)
    return false;

  for (const struct mt_option_tables *b = mt_option_tables; b->base != NULL;
       b++)
    if (strcmp (b->base, base) == 0)
      {
	/* All three together.  An index valid in one back end's enum table
	   runs off the end of another's -- i386 has 86 entries, aarch64 81 --
	   so a count left behind by a previous selection is an out-of-bounds
	   read with no diagnostic.  */
	cl_options = b->options;
	cl_enums = b->enums;
	cl_enums_count = b->enums_count;
	return true;
      }

  /* The two registries came out of one manifest, so this cannot happen; if it
     ever does, leaving the tables NULL means the next option decoded says so
     rather than being decoded against whatever was there before.  */
  return false;
}
