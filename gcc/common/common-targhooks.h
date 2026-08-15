/* Default common target hook functions.
   Copyright (C) 2003-2026 Free Software Foundation, Inc.

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

#ifndef GCC_COMMON_TARGHOOKS_H
#define GCC_COMMON_TARGHOOKS_H

/* THE SELECTED BACK END'S `DWARF2_UNWIND_INFO', AND WHY IT IS A POINTER.

   `default_except_unwind_info' below needs to know whether the target has
   DWARF 2 frame unwind.  Upstream it reads the `DWARF2_UNWIND_INFO' macro,
   which is a fact about ONE back end and reached this file through `tm.h';
   here that would be the primary's answer for all 47.  The real per-base
   answer lives on `target_frame_desc' (`target-frame.h'), reached by
   `mt_dwarf2_unwind_info ()' -- but that is in `libbackend.a' and this file
   is in `libcommon-target.a', which `xgcc', `cpp' and `lto-wrapper' link
   WITHOUT libbackend.  Calling it directly is an undefined symbol in three
   programs.

   So the pointer is defined here, in the archive every one of those programs
   has, and `multi_target_select' stores into it when it installs
   `targetm_frame'.  Null in a driver, and null FAILS BY NAME rather than
   defaulting: measured, no driver source calls `except_unwind_info', and if
   one ever does it must get a diagnostic rather than UI_SJLJ for every
   target.  That silent UI_SJLJ is exactly what #208 was.  */
extern int (*mt_dwarf2_unwind_info_hook) (void);

extern enum unwind_info_type default_except_unwind_info (struct gcc_options *);
extern enum unwind_info_type dwarf2_except_unwind_info (struct gcc_options *);
extern enum unwind_info_type sjlj_except_unwind_info (struct gcc_options *);

extern bool default_target_handle_option (struct gcc_options *,
					  struct gcc_options *,
					  const struct cl_decoded_option *,
					  location_t);
extern vec<const char *> default_get_valid_option_values (int, const char *);

extern const struct default_options empty_optimization_table[];

const char *
default_compute_multilib(
  const struct switchstr *,
  int,
  const char *multilib,
  const char *,
  const char *,
  const char *,
  const char *,
  const char *);

#endif
