/* Declarations and data types for RTL call insn generation.
   Copyright (C) 2013-2026 Free Software Foundation, Inc.

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

#ifndef GCC_CALLS_H
#define GCC_CALLS_H

/* For cumulative_args_t and pack_cumulative_args.  See the note by
   pass_by_reference below for why the interface is in terms of the opaque
   wrapper and not CUMULATIVE_ARGS, which is a different type in every back
   end and therefore a different mangled name in every back end.  */
#include "target.h"

/* Describes a function argument.

   Each argument conceptually has a gimple-level type.  Usually this type
   is available directly as a tree via the TYPE field, but when calling
   libgcc support functions it might instead be inferred from a mode,
   in which case the type isn't available directly.

   This gimple-level type might go through promotion before being passed to
   the target function.  Depending on the context, the MODE field is either
   the mode of the gimple-level type (whether explicitly given or not)
   or the mode after promotion has been performed.  */
class function_arg_info
{
public:
  function_arg_info ()
    : type (NULL_TREE), mode (VOIDmode), named (false),
      pass_by_reference (false)
  {}

  /* Initialize an argument of mode MODE, either before or after promotion.  */
  function_arg_info (machine_mode mode, bool named)
    : type (NULL_TREE), mode (mode), named (named), pass_by_reference (false)
  {}

  /* Initialize an unpromoted argument of type TYPE.  */
  function_arg_info (tree type, bool named)
    : type (type), mode (TYPE_MODE (type)), named (named),
      pass_by_reference (false)
  {}

  /* Initialize an argument with explicit properties.  */
  function_arg_info (tree type, machine_mode mode, bool named)
    : type (type), mode (mode), named (named), pass_by_reference (false)
  {}

  /* Return true if the gimple-level type is an aggregate.  */
  bool aggregate_type_p () const { return type && AGGREGATE_TYPE_P (type); }

  /* Return the size of the gimple-level type, or -1 if the size is
     variable or otherwise not representable as a poly_int64.

     Use this function when MODE is the mode of the type before promotion,
     or in any context if the target never promotes function arguments.  */
  poly_int64 type_size_in_bytes () const
  {
    if (type)
      return int_size_in_bytes (type);
    return GET_MODE_SIZE (mode);
  }

  /* Return the size of the argument after promotion, or -1 if the size
     is variable or otherwise not representable as a poly_int64.

     Use this function when MODE is the mode of the type after promotion.  */
  poly_int64 promoted_size_in_bytes () const
  {
    if (mode == BLKmode)
      return int_size_in_bytes (type);
    return GET_MODE_SIZE (mode);
  }

  /* True if the argument represents the end of the argument list,
     as returned by end_marker ().  */
  bool end_marker_p () const { return mode == VOIDmode; }

  /* Return a function_arg_info that represents the end of the
     argument list.  */
  static function_arg_info end_marker ()
  {
    return function_arg_info (void_type_node, /*named=*/true);
  }

  /* The type of the argument, or null if not known (which is true for
     libgcc support functions).  */
  tree type;

  /* The mode of the argument.  Depending on context, this might be
     the mode of the argument type or the mode after promotion.  */
  machine_mode mode;

  /* True if the argument is treated as a named argument, false if it is
     treated as an unnamed variadic argument (i.e. one passed through
     "...").  See also TARGET_STRICT_ARGUMENT_NAMING.  */
  unsigned int named : 1;

  /* True if we have decided to pass the argument by reference, in which case
     the function_arg_info describes a pointer to the original argument.  */
  unsigned int pass_by_reference : 1;
};

extern int flags_from_decl_or_type (const_tree);
extern int call_expr_flags (const_tree);
extern bool setjmp_call_p (const_tree);
extern bool gimple_maybe_alloca_call_p (const gimple *);
extern bool gimple_alloca_call_p (const gimple *);
extern bool alloca_call_p (const_tree);
extern bool must_pass_in_stack_var_size (const function_arg_info &);
extern bool must_pass_in_stack_var_size_or_pad (const function_arg_info &);
extern bool must_pass_va_arg_in_stack (tree);
extern rtx prepare_call_address (tree, rtx, rtx, rtx *, int, int);
extern bool shift_return_value (machine_mode, bool, rtx);
extern rtx expand_call (tree, rtx, int);
extern void fixup_tail_calls (void);

/* These three take cumulative_args_t rather than CUMULATIVE_ARGS *, and the
   difference is not cosmetic.  CUMULATIVE_ARGS is a per-target type -- a
   `struct ix86_args' on i386, an anonymous struct given the name by typedef on
   aarch64 -- so `apply_pass_by_reference_rules (CUMULATIVE_ARGS *, ...)'
   MANGLES DIFFERENTLY in every back end.  calls.cc, compiled once against the
   primary's tm.h, defined the i386 spelling; aarch64.cc called the aarch64
   one; the link failed with

     undefined reference to
       apply_pass_by_reference_rules(CUMULATIVE_ARGS*, function_arg_info&)

   which reads as a missing object and is nothing of the kind.  cumulative_args_t
   is target.h's opaque wrapper and exists for exactly this: it is one type in
   every back end.

   The CUMULATIVE_ARGS * overloads below keep all thirty-odd existing call
   sites -- most of them in config/, which this project does not edit -- saying
   what they already say.  They are inline, so they add no symbol and no
   per-target name.  */
extern bool pass_by_reference (cumulative_args_t, function_arg_info);
extern bool pass_va_arg_by_reference (tree);
extern bool apply_pass_by_reference_rules (cumulative_args_t,
					   function_arg_info &);
extern bool reference_callee_copied (cumulative_args_t,
				     const function_arg_info &);

inline bool
pass_by_reference (CUMULATIVE_ARGS *ca, function_arg_info arg)
{
  return pass_by_reference (pack_cumulative_args (ca), arg);
}

inline bool
apply_pass_by_reference_rules (CUMULATIVE_ARGS *ca, function_arg_info &arg)
{
  return apply_pass_by_reference_rules (pack_cumulative_args (ca), arg);
}

inline bool
reference_callee_copied (CUMULATIVE_ARGS *ca, const function_arg_info &arg)
{
  return reference_callee_copied (pack_cumulative_args (ca), arg);
}

extern void maybe_complain_about_tail_call (tree, const char *);

extern rtx rtx_for_static_chain (const_tree, bool);
extern bool cxx17_empty_base_field_p (const_tree);

#endif // GCC_CALLS_H
