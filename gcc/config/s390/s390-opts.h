/* Definitions for option handling for IBM S/390.
   Copyright (C) 1999-2026 Free Software Foundation, Inc.

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

#ifndef S390_OPTS_H
#define S390_OPTS_H

/* Which processor to generate code or schedule for. The `cpu' attribute
   defines a list that mirrors this list, so changes to s390.md must be
   made at the same time.  The enumeration must also be kept in sync with
   `processor_table' and `processor_flags_table' in s390.cc (the enumeration
   values are used as indices into these tables).  */

enum s390_processor_type
{
  PROCESSOR_2064_Z900,
  PROCESSOR_2084_Z990,
  PROCESSOR_2094_Z9_109,
  PROCESSOR_2094_Z9_EC,
  PROCESSOR_2097_Z10,
  PROCESSOR_2817_Z196,
  PROCESSOR_2827_ZEC12,
  PROCESSOR_2964_Z13,
  PROCESSOR_3906_Z14,
  PROCESSOR_8561_Z15,
  PROCESSOR_3931_Z16,
  PROCESSOR_9175_Z17,
  S390_PROCESSOR_NATIVE,
  S390_PROCESSOR_max
};


/* Values for -mindirect-branch and -mfunction-return options.  */
enum s390_indirect_branch_setting {
  s390_indirect_branch_unset = 0,
  s390_indirect_branch_keep,
  s390_indirect_branch_thunk,
  s390_indirect_branch_thunk_inline,
  s390_indirect_branch_thunk_extern
};


/* Where to get the canary for the stack protector.  */
enum s390_stack_protector_guard_type
{
  SP_TLS,       /* per-thread canary in TLS block */
  SP_GLOBAL     /* global canary */
};
#endif
