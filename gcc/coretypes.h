/* GCC core type declarations.
   Copyright (C) 2002-2026 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

GCC is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

Under Section 7 of GPL version 3, you are granted additional
permissions described in the GCC Runtime Library Exception, version
3.1, as published by the Free Software Foundation.

You should have received a copy of the GNU General Public License and
a copy of the GCC Runtime Library Exception along with this program;
see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see
<http://www.gnu.org/licenses/>.  */

/* Provide forward declarations of core types which are referred to by
   most of the compiler.  This allows header files to use these types
   (e.g. in function prototypes) without concern for whether the full
   definitions are visible.  Some other declarations that need to be
   universally visible are here, too.

   In the context of tconfig.h, most of these have special definitions
   which prevent them from being used except in further type
   declarations.  This is a kludge; the right thing is to avoid
   including the "tm.h" header set in the context of tconfig.h, but
   we're not there yet.  */

#ifndef GCC_CORETYPES_H
#define GCC_CORETYPES_H

#ifndef GTY
#define GTY(x)  /* nothing - marker for gengtype */
#endif

#ifndef USED_FOR_TARGET

typedef int64_t gcov_type;
typedef uint64_t gcov_type_unsigned;

struct bitmap_obstack;
class bitmap_head;
typedef class bitmap_head *bitmap;
typedef const class bitmap_head *const_bitmap;
struct simple_bitmap_def;
typedef struct simple_bitmap_def *sbitmap;
typedef const struct simple_bitmap_def *const_sbitmap;
struct rtx_def;
typedef struct rtx_def *rtx;
typedef const struct rtx_def *const_rtx;
class scalar_mode;
class scalar_int_mode;
class scalar_float_mode;
class complex_mode;
class fixed_size_mode;
template<typename> class opt_mode;
typedef opt_mode<scalar_mode> opt_scalar_mode;
typedef opt_mode<scalar_int_mode> opt_scalar_int_mode;
typedef opt_mode<scalar_float_mode> opt_scalar_float_mode;
template<typename> struct pod_mode;
typedef pod_mode<scalar_mode> scalar_mode_pod;
typedef pod_mode<scalar_int_mode> scalar_int_mode_pod;
typedef pod_mode<fixed_size_mode> fixed_size_mode_pod;

/* Subclasses of rtx_def, using indentation to show the class
   hierarchy, along with the relevant invariant.
   Where possible, keep this list in the same order as in rtl.def.  */
struct rtx_def;
  struct rtx_expr_list;           /* GET_CODE (X) == EXPR_LIST */
  struct rtx_insn_list;           /* GET_CODE (X) == INSN_LIST */
  struct rtx_sequence;            /* GET_CODE (X) == SEQUENCE */
  struct rtx_insn;
    struct rtx_debug_insn;      /* DEBUG_INSN_P (X) */
    struct rtx_nonjump_insn;    /* NONJUMP_INSN_P (X) */
    struct rtx_jump_insn;       /* JUMP_P (X) */
    struct rtx_call_insn;       /* CALL_P (X) */
    struct rtx_jump_table_data; /* JUMP_TABLE_DATA_P (X) */
    struct rtx_barrier;         /* BARRIER_P (X) */
    struct rtx_code_label;      /* LABEL_P (X) */
    struct rtx_note;            /* NOTE_P (X) */

struct rtvec_def;
typedef struct rtvec_def *rtvec;
typedef const struct rtvec_def *const_rtvec;
struct hwivec_def;
typedef struct hwivec_def *hwivec;
typedef const struct hwivec_def *const_hwivec;
union tree_node;
typedef union tree_node *tree;
typedef const union tree_node *const_tree;
struct gimple;
typedef gimple *gimple_seq;
struct gimple_stmt_iterator;
class code_helper;
enum tree_index : unsigned;

/* Forward declare rtx_code, so that we can use it in target hooks without
   needing to pull in rtl.h.  */
enum rtx_code : unsigned;
/* Forward declare tree_code, so that we can use it in target hooks without
   needing to pull in tree-core.h.  */
enum tree_code : unsigned;

/* Forward decls for leaf gimple subclasses (for individual gimple codes).
   Keep this in the same order as the corresponding codes in gimple.def.  */

struct gcond;
struct gdebug;
struct ggoto;
struct glabel;
struct gswitch;
struct gassign;
struct gasm;
struct gcall;
struct gtransaction;
struct greturn;
struct gbind;
struct gcatch;
struct geh_filter;
struct geh_mnt;
struct geh_else;
struct gresx;
struct geh_dispatch;
struct gphi;
struct gtry;
struct gomp_atomic_load;
struct gomp_atomic_store;
struct gomp_continue;
struct gomp_critical;
struct gomp_ordered;
struct gomp_for;
struct gomp_parallel;
struct gomp_task;
struct gomp_sections;
struct gomp_single;
struct gomp_target;
struct gomp_teams;

/* Forward declaration of CFI's and DWARF's types.  */
struct dw_cfi_node;
using dw_cfi_ref = struct dw_cfi_node *;
enum dw_cfi_oprnd_type: int;
enum dwarf_call_frame_info: int;

/* Subclasses of toplevel_node, using indentation to show the class
   hierarchy.  */

struct toplevel_node;
  struct asm_node;
  struct symtab_node;
    struct cgraph_node;
    struct varpool_node;
struct cgraph_edge;

union section;
typedef union section section;
struct gcc_options;
struct cl_target_option;
struct cl_optimization;
struct cl_option;
struct cl_decoded_option;
struct cl_option_handlers;
class rich_location;
namespace diagnostics {
  class context;
  class text_sink;
} // namespace diagnostics
class pretty_printer;
class diagnostic_event_id_t;
typedef const char * (*diagnostic_input_charset_callback)(const char *);
namespace pp_markup { class element; }
typedef pp_markup::element pp_element;

template<typename T> struct array_traits;

/* Provides a read-only bitmap view of a single integer bitmask or an
   array of integer bitmasks, or of a wrapper around such bitmasks.  */
template<typename T, typename Traits = array_traits<T>,
	 bool has_constant_size = Traits::has_constant_size>
class bitmap_view;

/* Address space number for named address space support.  */
typedef unsigned char addr_space_t;

/* The value of addr_space_t that represents the generic address space.  */
#define ADDR_SPACE_GENERIC 0
#define ADDR_SPACE_GENERIC_P(AS) ((AS) == ADDR_SPACE_GENERIC)

/* The major intermediate representations of GCC.  */
enum ir_type {
  IR_GIMPLE,
  IR_RTL_CFGRTL,
  IR_RTL_CFGLAYOUT
};

/* Provide forward struct declaration so that we don't have to include
   all of cpplib.h whenever a random prototype includes a pointer.
   Note that the cpp_reader and cpp_token typedefs remain part of
   cpplib.h.  */

struct cpp_reader;
struct cpp_token;

/* The thread-local storage model associated with a given VAR_DECL
   or SYMBOL_REF.  This isn't used much, but both trees and RTL refer
   to it, so it's here.  */
enum tls_model {
  TLS_MODEL_NONE,
  TLS_MODEL_EMULATED,
  TLS_MODEL_REAL,
  TLS_MODEL_GLOBAL_DYNAMIC = TLS_MODEL_REAL,
  TLS_MODEL_LOCAL_DYNAMIC,
  TLS_MODEL_INITIAL_EXEC,
  TLS_MODEL_LOCAL_EXEC
};

/* Types of trampoline implementation.  */
enum trampoline_impl {
  TRAMPOLINE_IMPL_STACK,
  TRAMPOLINE_IMPL_HEAP
};

/* Types of ABI for an offload compiler.  */
enum offload_abi {
  OFFLOAD_ABI_UNSET,
  OFFLOAD_ABI_LP64,
  OFFLOAD_ABI_ILP32
};

/* Types of profile update methods.  */
enum profile_update {
  PROFILE_UPDATE_SINGLE,
  PROFILE_UPDATE_ATOMIC,
  PROFILE_UPDATE_PREFER_ATOMIC
};

/* Type of profile reproducibility methods.  */
enum profile_reproducibility {
    PROFILE_REPRODUCIBILITY_SERIAL,
    PROFILE_REPRODUCIBILITY_PARALLEL_RUNS,
    PROFILE_REPRODUCIBILITY_MULTITHREADED
};

/* Type of -fstack-protector-*.  */
enum stack_protector {
  SPCT_FLAG_DEFAULT = 1,
  SPCT_FLAG_ALL = 2,
  SPCT_FLAG_STRONG = 3,
  SPCT_FLAG_EXPLICIT = 4
};

/* Types of unwind/exception handling info that can be generated.
   Note that a UI_TARGET (or larger) setting is considered to be
   incompatible with -freorder-blocks-and-partition.  */

enum unwind_info_type
{
  UI_NONE,
  UI_SJLJ,
  UI_DWARF2,
  UI_SEH,
  UI_TARGET
};

/* How the target extends a ptr_mode value to Pmode, i.e. the runtime form
   of the POINTERS_EXTEND_UNSIGNED target macro.  Presence and value are one
   field on purpose: "the target says nothing" (PTR_EXTEND_NONE) is a distinct
   state from "the target says sign-extend" (PTR_EXTEND_SIGN, the macro's 0),
   and the two are not interchangeable -- see convert_memory_address_addr_space_1
   and promote_mode, which behave differently for each.  */

enum ptr_extend_kind
{
  /* Macro not defined: ptr_mode and Pmode are expected to agree, and the
     conversions below are not performed at all.  */
  PTR_EXTEND_NONE,
  /* POINTERS_EXTEND_UNSIGNED == 0 (also spelled `false'): sign-extend.  */
  PTR_EXTEND_SIGN,
  /* POINTERS_EXTEND_UNSIGNED > 0: zero-extend.  */
  PTR_EXTEND_ZERO,
  /* POINTERS_EXTEND_UNSIGNED < 0: neither; the target has a ptr_extend
     instruction that must be used instead.  */
  PTR_EXTEND_INSN
};

/* The integer the POINTERS_EXTEND_UNSIGNED macro used to have, for the call
   sites that pass it on as an `unsignedp' argument (convert_modes,
   convert_to_mode, SUBREG_CHECK_PROMOTED_SIGN).  -1 is SRP_POINTER.
   Not meaningful for PTR_EXTEND_NONE; such sites must test for that first.  */

inline int
ptr_extend_unsignedp (enum ptr_extend_kind kind)
{
  return kind == PTR_EXTEND_ZERO ? 1 : kind == PTR_EXTEND_INSN ? -1 : 0;
}

/* The target's stack-register file: the inclusive hard register number range
   [first, last], i.e. the runtime form of the STACK_REGS / FIRST_STACK_REG /
   LAST_STACK_REG family.

   An EMPTY range is the "this target has no stack registers" state -- the
   runtime form of STACK_REGS being undefined, which is every back end but
   i386.  Presence and the two bounds are ONE value on purpose, exactly as for
   ptr_extend_kind above: a separate have_p predicate alongside first/last
   could drift out of step with them, and there is no register number that can
   stand in for "absent".

   STACK_REG_P is not a separate hook because it is derived: it is just
   includes_p on this range.  */

struct stack_reg_range
{
  /* First and last stack hard register, inclusive.  LAST < FIRST means the
     target has none.  */
  int first;
  int last;

  bool empty_p () const { return first > last; }

  /* True if REGNO is one of the target's stack registers.  Always false when
     the range is empty, so callers need not test that separately.  */
  bool includes_p (unsigned int regno) const
  {
    return (int) regno >= first && (int) regno <= last;
  }
};

/* Callgraph node profile representation.  */
enum node_frequency {
  /* This function most likely won't be executed at all.
     (set only when profile feedback is available or via function attribute). */
  NODE_FREQUENCY_UNLIKELY_EXECUTED,
  /* For functions that are known to be executed once (i.e. constructors, destructors
     and main function.  */
  NODE_FREQUENCY_EXECUTED_ONCE,
  /* The default value.  */
  NODE_FREQUENCY_NORMAL,
  /* Optimize this function hard
     (set only when profile feedback is available or via function attribute). */
  NODE_FREQUENCY_HOT
};

/* Ways of optimizing code.  */
enum optimization_type {
  /* Prioritize speed over size.  */
  OPTIMIZE_FOR_SPEED,

  /* Only do things that are good for both size and speed.  */
  OPTIMIZE_FOR_BOTH,

  /* Prioritize size over speed.  */
  OPTIMIZE_FOR_SIZE
};

/* Enumerates a padding direction.  */
enum pad_direction {
  /* No padding is required.  */
  PAD_NONE,

  /* Insert padding above the data, i.e. at higher memory addresses
     when dealing with memory, and at the most significant end when
     dealing with registers.  */
  PAD_UPWARD,

  /* Insert padding below the data, i.e. at lower memory addresses
     when dealing with memory, and at the least significant end when
     dealing with registers.  */
  PAD_DOWNWARD
};

/* Possible initialization status of a variable.   When requested
   by the user, this information is tracked and recorded in the DWARF
   debug information, along with the variable's location.  */
enum var_init_status
{
  VAR_INIT_STATUS_UNKNOWN,
  VAR_INIT_STATUS_UNINITIALIZED,
  VAR_INIT_STATUS_INITIALIZED
};

/* Kind of artificial, compiler-generated lookup table.  Type of the
   second argument of TARGET_ADDR_SPACE_FOR_ARTIFICIAL_RODATA resp.
   targetm.addr_space.for_artificial_rodata.  */
enum artificial_rodata
{
  /* Generated by tree-switch-conversion.cc: Lowered GIMPLE_SWITCH expressions
     to something more efficient than a jump table.  */
  ARTIFICIAL_RODATA_CSWITCH,

  /* Generated by gimple-crc-optimization.cc:  CRC optimization.  */
  ARTIFICIAL_RODATA_CRC
};

/* The type of an alias set.  Code currently assumes that variables of
   this type can take the values 0 (the alias set which aliases
   everything) and -1 (sometimes indicating that the alias set is
   unknown, sometimes indicating a memory barrier) and -2 (indicating
   that the alias set should be set to a unique value but has not been
   set yet).  */
typedef int alias_set_type;

class edge_def;
typedef class edge_def *edge;
typedef const class edge_def *const_edge;
struct basic_block_def;
typedef struct basic_block_def *basic_block;
typedef const struct basic_block_def *const_basic_block;

#if !defined (GENERATOR_FILE)
# define OBSTACK_CHUNK_SIZE     memory_block_pool::block_size
# define obstack_chunk_alloc    mempool_obstack_chunk_alloc
# define obstack_chunk_free     mempool_obstack_chunk_free
#else
# define OBSTACK_CHUNK_SIZE     0
# define obstack_chunk_alloc    xmalloc
# define obstack_chunk_free     free
#endif

#define gcc_obstack_init(OBSTACK)				\
  obstack_specify_allocation ((OBSTACK), OBSTACK_CHUNK_SIZE, 0,	\
			      obstack_chunk_alloc,		\
			      obstack_chunk_free)

/* enum reg_class is target specific, so it should not appear in
   target-independent code or interfaces, like the target hook declarations
   in target.h.  */
typedef int reg_class_t;

class rtl_opt_pass;

namespace gcc {
  class context;
}

typedef std::pair <tree, tree> tree_pair;
typedef std::pair <const char *, int> string_int_pair;

/* Define a name->value mapping.  */
template <typename ValueType>
struct kv_pair
{
  const char *const name;	/* the name of the value */
  const ValueType value;	/* the value of the name */
};

#else

struct _dont_use_rtx_here_;
struct _dont_use_rtvec_here_;
struct _dont_use_rtx_insn_here_;
union _dont_use_tree_here_;
#define rtx struct _dont_use_rtx_here_ *
#define const_rtx struct _dont_use_rtx_here_ *
#define rtvec struct _dont_use_rtvec_here *
#define const_rtvec struct _dont_use_rtvec_here *
#define rtx_insn struct _dont_use_rtx_insn_here_
#define tree union _dont_use_tree_here_ *
#define const_tree union _dont_use_tree_here_ *

typedef struct scalar_mode scalar_mode;
typedef struct scalar_int_mode scalar_int_mode;
typedef struct scalar_float_mode scalar_float_mode;
typedef struct complex_mode complex_mode;

#endif

/* Classes of functions that compiler needs to check
   whether they are present at the runtime or not.  */
enum function_class {
  function_c94,
  function_c99_misc,
  function_c99_math_complex,
  function_sincos,
  function_c11_misc,
  function_c23_misc,
  function_c2y_misc
};

/* Enumerate visibility settings.  This is deliberately ordered from most
   to least visibility.  */
enum symbol_visibility
{
  VISIBILITY_DEFAULT,
  VISIBILITY_PROTECTED,
  VISIBILITY_HIDDEN,
  VISIBILITY_INTERNAL
};

/* enums used by the targetm.excess_precision hook.  */

enum flt_eval_method
{
  FLT_EVAL_METHOD_UNPREDICTABLE = -1,
  FLT_EVAL_METHOD_PROMOTE_TO_FLOAT = 0,
  FLT_EVAL_METHOD_PROMOTE_TO_DOUBLE = 1,
  FLT_EVAL_METHOD_PROMOTE_TO_LONG_DOUBLE = 2,
  FLT_EVAL_METHOD_PROMOTE_TO_FLOAT16 = 16
};

enum excess_precision_type
{
  EXCESS_PRECISION_TYPE_IMPLICIT,
  EXCESS_PRECISION_TYPE_STANDARD,
  EXCESS_PRECISION_TYPE_FAST,
  EXCESS_PRECISION_TYPE_FLOAT16
};

/* Level of size optimization.  */

enum optimize_size_level
{
  /* Do not optimize for size.  */
  OPTIMIZE_SIZE_NO,
  /* Optimize for size but not at extreme performance costs.  */
  OPTIMIZE_SIZE_BALANCED,
  /* Optimize for size as much as possible.  */
  OPTIMIZE_SIZE_MAX
};

/* Support for user-provided GGC and PCH markers.  The first parameter
   is a pointer to a pointer, the second either NULL if the pointer to
   pointer points into a GC object or the actual pointer address if
   the first argument points to a temporary and the third a cookie.  */
typedef void (*gt_pointer_operator) (void *, void *, void *);

#if !defined (HAVE_UCHAR)
typedef unsigned char uchar;
#endif

/* Most source files will require the following headers.  */
#if !defined (USED_FOR_TARGET)

/* Multi-target: the machine modes are a property of the back end, not of the
   build, so the generator programs are built once per back end against that
   back end's modes.  Which pair of generated headers to use is chosen on the
   command line; the configured target's is the default, which is what the
   compiler proper and the single-target build use.  */
#ifndef INSN_MODES_H
#define INSN_MODES_H "insn-modes.h"
#endif
#ifndef INSN_MODES_INLINE_H
#define INSN_MODES_INLINE_H "insn-modes-inline.h"
#endif

#include INSN_MODES_H
#include "signop.h"
#include "wide-int.h"
#include "wide-int-print.h"

/* On targets that don't need polynomial offsets, target-specific code
   should be able to treat poly_int like a normal constant, with a
   conversion operator going from the former to the latter.  We also
   allow this for gencondmd.cc for all targets, so that we can treat
   machine_modes as enums without causing build failures.

   TARGET_POLY_AWARE is a back end's declaration that it no longer wants
   either shorthand -- that its sources say known_lt, maybe_ne and
   to_constant () explicitly, as aarch64 and riscv already must.

   It exists because making the machine modes one shared vocabulary forces
   NUM_POLY_INT_COEFFS to 2 for everyone: poly_int is the container itself,
   not a name, so it cannot be kept per back end.  At 2 this conversion
   operator is gone, and every back end that relied on it stops compiling --
   548 sites in i386 alone.  Converting all 43 at once, in the same commit
   that flips the constant, would be a change nobody could review or bisect.

   With this opt-in a back end gets the 2-coefficient discipline while the
   constant is still 1, so it can be converted, built and proved
   codegen-identical on its own, one commit at a time.  The flip then changes
   nothing for any back end already opted in.

   It has to arrive on the command line, the way IN_TARGET_CODE does -- a
   back end's tmake fragment adding it to T_CFLAGS.  tm.h is far too late:
   this header is reached through coretypes.h, which nearly every source
   includes before tm.h.

   DELETE THIS, and every definition of it, together with the flip.  A
   migration switch that outlives its migration is just a list to fall off.  */
#if (defined (IN_TARGET_CODE) \
     && (defined (USE_ENUM_MODES) \
	 || (NUM_POLY_INT_COEFFS == 1 && !defined (TARGET_POLY_AWARE))))
#define POLY_INT_CONVERSION 1
#else
#define POLY_INT_CONVERSION 0
#endif

#include "poly-int.h"
#include "poly-int-types.h"
#include INSN_MODES_INLINE_H
#include "machmode.h"
#include "double-int.h"
#include "align.h"
/* Most host source files will require the following headers.  */
#if !defined (GENERATOR_FILE)
#include "iterator-utils.h"
#include "real.h"
#include "fixed-value.h"
#include "hash-table.h"
#include "hash-set.h"
#include "input.h"
#include "is-a.h"
#include "memory-block.h"
#include "dumpfile.h"
#endif
#endif /* GENERATOR_FILE && !USED_FOR_TARGET */

#endif /* coretypes.h */
