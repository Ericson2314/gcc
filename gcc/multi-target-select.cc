/* Which back end's generated machine description is in force.
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

/* THE FORTY NAMES.

   Every configured back end's generated code now lives in `namespace
   insn_<base>' -- see print_ns_open in gensupport.cc -- and every one of its
   hand-written sources is compiled with -D<name>=<name>_<base> for the short
   list in MULTI_TARGET_RENAME_NAMES.  What is left is this file: the forty
   bare names the middle end reaches for directly, defined once, each
   forwarding to the back end in force.

   The set was not guessed.  It is `nm --defined-only' over i386's 42 object
   files intersected with aarch64's 52, filtered to strong symbols
   (scratchpad/sweep.sh), and it must be re-run rather than reasoned about:
   libbackend.a is an ARCHIVE, so a duplicate definition is diagnosed only
   when both members happen to be pulled in for other reasons.  `ld' once
   reported 7 of 40.  Never size this set with the linker.

   THREE TRAPS, ALL PAID FOR ALREADY IN common/common-target-select.cc AND
   target-asm-ops-select.cc, AND THEY APPLY HERE UNCHANGED:

     * NO PRIVILEGED DEFAULT.  Nothing here starts out pointing at the build
       triple's back end.  A compiler that has selected nothing has null
       tables and no recog, and says so by name at the first use.  Starting at
       the primary's tables is what makes a missed dependency behave correctly
       on the build machine and wrongly everywhere else -- the whole bug class
       this branch exists to remove.

     * NAME EVERY TABLE.  These objects come out of an archive and an archive
       member that nothing refers to is not pulled in at all.  mt_backends[]
       below refers to all of them; without it only whichever back end
       something else happened to mention would reach the compiler, however
       many were compiled.

     * INITIALISE WITH AN ADDRESS, NOT A STRUCT COPY.  mt_current is a pointer
       to a constant-initialised table, so there is no dynamic initialisation
       and no ordering question between translation units.  `targetm' used to
       be the one exception -- a copy -- and that was a bug, not a cost; see
       mt_install_* below.  Nothing here is a copy now.  */

/* The include order is recog.cc's, not a minimal set.  emit-rtl.h needs
   backend.h's forward declarations, tm-preds.h needs hard-reg-set.h before it
   will define `struct target_constraints' at all, and tm-constrs.h needs
   tm_p.h for the predicate prototypes its inline wrappers call.  Trimming
   this list produces a page of `incomplete type' and `not declared in this
   scope' inside those headers, which reads as a bug in them.  */
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "backend.h"
#include "target.h"
#include "rtl.h"
#include "tree.h"
#include "memmodel.h"
#include "tm_p.h"
#include "insn-config.h"
#include "emit-rtl.h"
#include "recog.h"
#include "output.h"
#include "real.h"
#include "diagnostic-core.h"
#include "options.h"
#include "tm-constrs.h"
#include "target-asm-ops.h"
#include "target-addr.h"
#include "target-cdata.h"
#include "target-regs.h"
#include "target-cumargs.h"
#include "multi-target-reg-widths.h"

/* Defines MT_BACKENDS -- one MT_BACKEND (<base>, insn_<base>) per configured
   back end -- and MT_TARGET_BASES, which maps each configured triple to the
   back end serving it.  Written by gen-multi-target-md.awk from
   multi-target.manifest.  */
#include "multi-target-backends.h"

/* THE SHARED CONSTRAINT STORAGE.

   genpreds used to emit these two into every back end's insn-preds-<base>.cc,
   so a compiler with two back ends had two of each under the bare names
   target-globals.h declares.  They are not per-back-end constants: `struct
   target_constraints' is runtime storage that the selected back end's
   init_reg_class_start_regs () fills in and the middle end reads through one
   pointer, so the right number of them is one.  Its LAYOUT is uniform because
   genpreds now sizes register_filters[] by NUM_REGISTER_FILTERS, which
   genconfig unions over every configured back end.  */
struct target_constraints default_target_constraints;
#if SWITCHABLE_TARGET
struct target_constraints *this_target_constraints = &default_target_constraints;
#endif

/* THE HOOK TABLE, AND IT IS A POINTER, NOT A COPY.

   target.h now spells `targetm' as `(*targetm_ptr)', so this file supplies
   the pointer and mt_install_<base> aims it at the selected back end's own
   `targetm_<base>'.  What that buys is the only thing that makes a
   multi-target compiler correct here: back ends WRITE through targetm long
   after startup -- twelve sites in the two configured back ends alone
   (i386.cc's seven `targetm.sched.* = NULL', i386-options.cc's
   `expand_builtin_va_start = NULL', i386-c.cc's and aarch64-c.cc's
   pragma_parse and friends) -- all of them from option-override or
   pragma-registration code that runs AFTER selection.  A copy taken here
   would be taken before those stores and the middle end would never see
   them: no link error, no diagnostic, it simply keeps calling the hook the
   back end just disabled.

   This file previously did copy, and said in a comment that no configured
   back end wrote through targetm, naming the grep that would check it.  The
   grep was run.  Both configured back ends do it.  A written invariant that
   nobody executed is how that survived, so the invariant is now enforced by
   construction rather than asserted: there is no second object to go stale.

   It starts NULL rather than at some default back end.  Reading a hook
   before selection is then a null dereference: loud, immediate, and at the
   point of use.  (common/common-target-select.cc can do better -- it
   generates a complete diagnosing table from common-target.def -- but
   target.def cannot be walked the same way, because TARGET_INITIALIZER's
   nesting is not expressible with a flat DEFHOOK sweep.  The ordering that
   makes this survivable is unchanged: nothing reaches `targetm' before
   option decoding, and option decoding needs targetm_common, which toplev.cc
   installs immediately before this and which DOES name itself when no target
   was selected.  The loud failure happens first, every time.)  */
struct gcc_target *targetm_ptr;

/* NOT USED, AND HERE ON PURPOSE.  Each back end's own ms_va_list_type_node is
   renamed to ms_va_list_type_node_<base> (MULTI_TARGET_RENAME_NAMES), and its
   gt-<file>.h GC root is compiled in the same translation unit, so it sees the
   rename and roots the right object.  gtype-desc.cc does not: gengtype scanned
   the declaration out of both config/i386/i386.h and config/aarch64/aarch64.h,
   which spell one name for two different objects, and emitted a root under the
   bare name.  That conflation is older than this file and belongs to the
   target headers; what this definition does is give the stale root something
   to point at, so the conflict is a permanently-null tree rather than a link
   failure.  It is a placeholder for a bug, not a fix for one.  */
tree ms_va_list_type_node;

/* Every back end's entry points, declared here rather than in a generated
   header because the shapes are fixed by the hand-written declarations in
   recog.h, rtl.h, output.h, emit-rtl.h and machmode.h -- if one of these ever
   disagrees with the header it declares against, the compiler says so at the
   forwarder below, which is the point.  */

/* verify_reg_names_in_constraints exists only under a condition; the
   alternative to these three macros is an #if inside three different macro
   bodies, where a `#' is not allowed at all.  */
#if CHECKING_P
# define MT_DECLARE_VERIFY extern void verify_reg_names_in_constraints (void);
# define MT_ENTRY_VERIFY(NS) NS::verify_reg_names_in_constraints,
# define MT_ENTRY_VERIFY_NULL NULL,
#else
# define MT_DECLARE_VERIFY
# define MT_ENTRY_VERIFY(NS)
# define MT_ENTRY_VERIFY_NULL
#endif

#define MT_DECLARE_FUNCS(NS)						\
  extern int recog (rtx, rtx_insn *, int *);				\
  extern rtx_insn *split_insns (rtx, rtx_insn *);			\
  extern rtx_insn *peephole2_insns (rtx, rtx_insn *, int *);		\
  extern void insn_extract (rtx_insn *);				\
  extern const char *get_insn_name (int);				\
  extern rtx_insn *peephole (rtx_insn *);				\
  extern void init_adjust_machine_modes (void);				\
  MT_DECLARE_VERIFY

/* The data tables.  One list, used three times: to declare them per back end,
   to name them in the installer, and -- because it is one list -- to make it
   impossible to add a table to two of those places and forget the third.

   `mode_name' is here like the rest.  Selecting WHICH mode_name is in force
   is not the same thing as renaming its entries: GET_MODE_NAME still returns
   "PSI" for PSImode, the strings are untouched, and no libgcc symbol moves.
   That distinction is the whole reason this is a table selection and not a
   symbol rename.  */
#define MT_MODE_TABLES(F, NS)						\
  F (mode_size, NS) F (mode_precision, NS) F (mode_inner, NS)		\
  F (mode_nunits, NS) F (mode_unit_size, NS) F (mode_unit_precision, NS) \
  F (mode_next, NS) F (mode_wider, NS) F (mode_2xwider, NS)		\
  F (mode_name, NS) F (mode_class, NS) F (mode_ibit, NS)		\
  F (mode_fbit, NS) F (mode_complex, NS) F (mode_base_align, NS)	\
  F (mode_mask_array, NS) F (class_narrowest_mode, NS)			\
  F (int_n_data, NS) F (real_format_for_mode, NS)

/* NS is threaded through because a macro parameter of MT_BACKEND is NOT
   substituted inside the body of another macro it expands to.  Without it
   MT_INSTALL_TABLE says `NS::mode_size' with NS undeclared, and the
   diagnostic names this line rather than the back end.  */
#define MT_OTHER_TABLES(F, NS)						\
  F (insn_data, NS) F (unspec_strings, NS) F (unspecv_strings, NS)

/* THE SCALARS, kept apart from the tables above for one reason: they are not
   pointers, so MT_INSTALL_TABLE's const_cast does not apply to them (a
   const_cast to a non-reference scalar type is ill-formed, so putting one of
   these in MT_OTHER_TABLES is caught at compile time rather than silently).
   They are still selected exactly like the tables and by the same list, which
   is what stops one being added without the other.

   `unspec_strings_len' is the LENGTH OF THE TABLE ON THE LINE ABOVE IT, and
   it exists because the compile-time NUM_UNSPEC*_VALUES cannot be: those come
   from the singular genconstants run over the primary's md.  Measured in this
   build dir, NUM_UNSPECV_VALUES is 114 while insn_aarch64::unspecv_strings_tab
   holds 40 entries, and insn_aarch64::unspec_strings_tab is the very next
   object in .rodata -- so print_exp's `unspec < NUM_UNSPECV_VALUES' let
   indices 40..113 read the neighbouring table and print a plain UNSPEC's name
   for an UNSPEC_VOLATILE.  An out-of-bounds read that never faults and never
   diagnoses: one name, two authorities, again.  */
#define MT_SCALAR_TABLES(F, NS)						\
  F (unspec_strings_len, NS) F (unspecv_strings_len, NS)

#define MT_ALL_TABLES(F, NS)						\
  MT_MODE_TABLES (F, NS) MT_OTHER_TABLES (F, NS) MT_SCALAR_TABLES (F, NS)

/* `decltype (::NAME)' rather than a spelled-out type: the qualifier on each of
   these (CONST_MODE_SIZE and friends) comes from tm.h and so differs between
   back ends -- aarch64's mode_size is writable because SVE adjusts it at
   startup, i386's is not.  Taking the type from the declaration the middle end
   actually uses means the two cannot drift apart silently.  */
#define MT_DECLARE_TABLE(NAME, NS) extern decltype (::NAME) NAME;

/* THE BARE TABLES THEMSELVES, and they start NULL.  Static storage, so this
   is zero-initialisation and not dynamic initialisation -- valid before
   anything runs, with no ordering question.  Reading one before a target is
   selected is a null dereference: loud, immediate, and at the point of use.
   That is the intended behaviour and it is why there is no `= i386's table'
   here.  */
#define MT_DEFINE_TABLE(NAME, NS) decltype (::NAME) NAME;
MT_ALL_TABLES (MT_DEFINE_TABLE, )

/* global_options_init_<base> is NOT in the back end's namespace: it is a
   hand-named function in options-init-<base>.cc, one per back end, and the
   name already carries the base.  What it does is apply that back end's own
   Init() values -- see optc-gen.awk -- which cannot be compiled into
   options.cc because an Init() argument is a macro from that back end's
   tm.h.  */
#define MT_BACKEND(BASE, NS)						\
  namespace NS {							\
    MT_DECLARE_FUNCS (NS)						\
    MT_ALL_TABLES (MT_DECLARE_TABLE, NS)				\
  }									\
  extern struct gcc_target targetm_ ## BASE;				\
  extern void global_options_init_ ## BASE (struct gcc_options *);
MT_BACKENDS
#undef MT_BACKEND

/* What a back end is, from this file's point of view.  */

struct mt_backend
{
  const char *name;
  int (*recog) (rtx, rtx_insn *, int *);
  rtx_insn *(*split_insns) (rtx, rtx_insn *);
  rtx_insn *(*peephole2_insns) (rtx, rtx_insn *, int *);
  void (*insn_extract) (rtx_insn *);
  const char *(*get_insn_name) (int);
  rtx_insn *(*peephole) (rtx_insn *);
  void (*init_adjust_machine_modes) (void);
#if CHECKING_P
  void (*verify_reg_names_in_constraints) (void);
#endif
  void (*install_tables) (void);
};

/* const_cast, not a plain assignment: see MT_DECLARE_TABLE.  The pointee's
   constness is the back end's business and the middle end's declaration is
   whatever the PRIMARY's tm.h says, so the two legitimately differ in either
   direction.  const_cast can only add or remove `const' -- it cannot paper
   over a genuinely different type, so a real mismatch is still an error.  */
#define MT_INSTALL_TABLE(NAME, NS) \
  ::NAME = const_cast<decltype (::NAME)> (NS::NAME);

/* Scalars: a plain copy, and deliberately NOT routed through the const_cast
   above, which would not compile for them.  */
#define MT_INSTALL_SCALAR(NAME, NS) ::NAME = NS::NAME;

#define MT_BACKEND(BASE, NS)						\
  static void mt_install_ ## BASE (void)				\
  {									\
    MT_MODE_TABLES (MT_INSTALL_TABLE, NS)				\
    MT_OTHER_TABLES (MT_INSTALL_TABLE, NS)				\
    MT_SCALAR_TABLES (MT_INSTALL_SCALAR, NS)				\
    /* POINT, do not copy.  The back end's own translation units are	\
       compiled with -Dtargetm=targetm_<base> (and the companion	\
       -DMULTI_TARGET_TARGETM_BASE, which target.h checks travels with	\
       it), so `targetm' THERE is this very object; the middle end	\
       reaches the same object through targetm_ptr.  One object, so a	\
       back end's TARGET_OPTION_OVERRIDE or pragma registration writing	\
       `targetm.foo = ...' after this line is a store the middle end	\
       reads.  A struct copy here would silently lose exactly those	\
       twelve stores.  */						\
    ::targetm_ptr = &targetm_ ## BASE;					\
    /* And the Init() values that only this back end can spell.  Written	\
       into global_options_init itself rather than handed to some later	\
       caller, because there are three callers of init_options_struct and	\
       one of them is the DRIVER, which never selects a target: a		\
       forwarder would have had to answer "no target selected" by doing	\
       nothing, which is the floor this file refuses everywhere else.	\
       One object, written once, before the one read that matters --	\
       toplev::main runs multi_target_select above				\
       init_options_struct.  */						\
    global_options_init_ ## BASE (&global_options_init);		\
  }
MT_BACKENDS
#undef MT_BACKEND

#define MT_BACKEND(BASE, NS)						\
  { #BASE, NS::recog, NS::split_insns, NS::peephole2_insns,		\
    NS::insn_extract,							\
    NS::get_insn_name, NS::peephole, NS::init_adjust_machine_modes,	\
    MT_ENTRY_VERIFY (NS)						\
    mt_install_ ## BASE },
static const struct mt_backend mt_backends[] = {
  MT_BACKENDS
  { NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    MT_ENTRY_VERIFY_NULL NULL }
};
#undef MT_BACKEND

/* Triple to back end.  Many-to-one: every aarch64-* triple this compiler was
   configured for is served by `aarch64'.  */

struct mt_target_base
{
  const char *target;
  const char *base;
};

#define MT_TARGET_BASE(TRIPLE, BASE) { TRIPLE, #BASE },
static const struct mt_target_base mt_target_bases[] = {
  MT_TARGET_BASES
  { NULL, NULL }
};
#undef MT_TARGET_BASE

/* THE BACK END IN FORCE, and it starts as none.  */
static const struct mt_backend *mt_current;

static ATTRIBUTE_NORETURN void
no_target_selected (const char *what)
{
  fprintf (stderr,
	   "%s: fatal error: `%s' was used before a target was selected\n"
	   "no back end has been installed: nothing called "
	   "multi_target_select, so there is no machine description in "
	   "force.  A target is named by the `target' line of the file passed "
	   "as -ftarget-config=; a compiler given none has no target and "
	   "deliberately has no default.\n",
	   progname != NULL ? progname : "cc1", what);
  exit (FATAL_EXIT_CODE);
}

static inline const struct mt_backend *
mt_in_force (const char *what)
{
  if (mt_current == NULL)
    no_target_selected (what);
  return mt_current;
}

/* Install the back end serving TARGET.  Returns false and changes nothing if
   TARGET was not configured -- in particular it does NOT fall back on any back
   end, so a caller that ignores the result gets a diagnostic at the first use
   rather than code for whatever machine happened to be first.  */

bool
multi_target_select (const char *target)
{
  const char *base = NULL;

  for (const struct mt_target_base *t = mt_target_bases; t->target; t++)
    if (strcmp (t->target, target) == 0)
      {
	base = t->base;
	break;
      }
  if (base == NULL)
    return false;

  for (const struct mt_backend *b = mt_backends; b->name; b++)
    if (strcmp (b->name, base) == 0)
      {
	b->install_tables ();

	/* THE TWO SIDE TABLES THAT ARE *NOT* PART OF `targetm', AND WHICH
	   NOTHING SELECTED UNTIL NOW.

	   `targetm_asm_ops' and `targetm_addr' are per-base tables held
	   outside `targetm' -- the first because `targetm.asm_out''s POD
	   directive slots are filled by TARGET_INITIALIZER from `tm.h' macros,
	   the second because `addresses.h''s funnels are not hooks at all.
	   Both are constant-initialised with the PRIMARY's table so that they
	   are valid before anything runs, and both must be re-pointed here,
	   at the one place that knows which base was chosen.

	   `targetm_asm_ops' was NOT re-pointed, and that was a live bug rather
	   than an omission with no consequence.  `init_targetm_asm_ops'
	   (toplev.cc) COPIES `*targetm_asm_ops' into `targetm.asm_out' during
	   backend_init.  With the pointer stuck on the primary, that copy
	   overwrote the selected back end's own correct directives -- which
	   TARGET_INITIALIZER had already put in `targetm_<base>' from that
	   base's headers -- with i386's.  So the mechanism did not merely fail
	   to help; it actively undid a value that was already right.

	   Measured before the fix, in the linked cc1 under `-ftarget-config=':
	   `targetm_asm_ops == &targetm_asm_ops_i386' and
	   `targetm.asm_out.global_op ()' returned "\t.globl\t", while
	   `targetm_asm_ops_aarch64.global_op ()' returned "\t.global\t".

	   The TAB probe passed GLOBAL_ASM_OP throughout, and correctly: it
	   reads the per-base TABLES, which were always right.  It had no arm on
	   the pointer that chooses between them.  Presence of a mechanism is
	   not evidence anything invokes it, and `.globl' vs `.global'
	   assembles identically, so nothing downstream would have said a word.
	   scratchpad/select-arm.sh is the arm that now covers it.  */
	targetm_addr = target_addr_for (base);
	if (targetm_addr == NULL)
	  internal_error ("back end %qs has no addressing-predicate table; "
			  "gen-multi-target-md.awk emits one for every back "
			  "end that has objects, so this is a build bug", base);

	targetm_asm_ops = target_asm_ops_for (base);
	if (targetm_asm_ops == NULL)
	  internal_error ("back end %qs has no assembler-directive table; "
			  "gen-multi-target-md.awk omits one for mmix and for "
			  "the back ends sharing default-common.cc, and such a "
			  "back end cannot be selected", base);

	/* The (c-DATA) refresh function.  Only the POINTER is chosen here:
	   the values it writes depend on option state, which has not been
	   decoded yet at this point, so `init_targetm_cdata ()' does the
	   actual fill much later, from toplev.cc's `process_options' and only
	   once `targetm.target_option.override ()' has run.  Splitting it that
	   way is not tidiness -- selecting and refreshing at the same moment
	   would capture the option defaults and freeze them.  */
	targetm_cdata_refresh = target_cdata_refresh_for (base);
	if (targetm_cdata_refresh == NULL)
	  internal_error ("back end %qs has no target-cdata refresh function; "
			  "one is emitted for every back end that has "
			  "objects, so this is a build bug", base);

	/* The register vocabulary: the six data arrays, the two counts, this
	   base's ALL_REGS and GENERAL_REGS, and its REGNO_REG_CLASS.  A TABLE
	   and not a refresh function, because none of it depends on option
	   state -- FIXED_REGISTERS and REG_CLASS_CONTENTS are settled by the
	   back end's headers alone -- so it can and does point here, before
	   options are decoded and long before `init_reg_sets' reads it.

	   Unlike `targetm_addr' and `targetm_asm_ops' above, `targetm_regs'
	   is NULL until this line rather than pre-pointed at the primary.
	   That is the difference between a mechanism that fails loudly and
	   one that fails correctly on the build machine: a pre-pointed
	   default here would compile aarch64 against i386's register classes
	   and i386's register names, in bounds and with no diagnostic.  */
	targetm_regs = target_regs_for (base);
	if (targetm_regs == NULL)
	  internal_error ("back end %qs has no register-vocabulary table; "
			  "gen-multi-target-md.awk emits one for every back "
			  "end that has objects, so this is a build bug", base);

	/* Who WRITES a CUMULATIVE_ARGS.  A table for the same reason as the
	   register vocabulary -- five macros settled by this back end's own
	   headers, none of them option-dependent -- and NULL until here for
	   the same reason: `init_cumulative_args' pre-pointed at the primary
	   is exactly the failure this file exists to remove, and it is one
	   the build machine cannot see.

	   The bound is re-checked here, at run time, against the values this
	   base measured in its OWN translation unit.  target-cumargs.cc
	   already static_asserts it, so this can only fire if the table and
	   `multi-target-reg-widths.h' came from different builds -- a stale
	   object in a build directory, which is a thing that happens and
	   which has no other symptom than a corrupted frame.  */
	targetm_cumargs = target_cumargs_for (base);
	if (targetm_cumargs == NULL)
	  internal_error ("back end %qs has no %<CUMULATIVE_ARGS%> table; "
			  "gen-multi-target-md.awk emits one for every back "
			  "end that has objects, so this is a build bug", base);
	if (targetm_cumargs->own_size
	      > (unsigned long) MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE
	    || targetm_cumargs->own_align
		 > (unsigned long) MULTI_TARGET_UNION_CUMULATIVE_ARGS_ALIGN)
	  internal_error ("back end %qs wants a %<CUMULATIVE_ARGS%> of %lu bytes "
			  "aligned to %lu, but this compiler was built to "
			  "hold %d aligned to %d; the objects of that back end and "
			  "multi-target-reg-widths.h are from different builds",
			  base, targetm_cumargs->own_size,
			  targetm_cumargs->own_align,
			  MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE,
			  MULTI_TARGET_UNION_CUMULATIVE_ARGS_ALIGN);

	/* The frame and argument-register answers ride on the same table; see
	   target-frame.h.  Checked rather than assumed: the pointer is filled
	   in by the same per-base translation unit that defines the table, so
	   a null one means an object built before that field existed is being
	   linked, which is the stale-object failure described above wearing a
	   different symptom.  */
	targetm_frame = targetm_cumargs->frame;
	if (targetm_frame == NULL)
	  internal_error ("back end %qs supplies a %<CUMULATIVE_ARGS%> table "
			  "with no frame table attached; its objects predate "
			  "target-frame.h and are from a different build", base);

	/* Which insn patterns this back end has; see target-insn.h.  Rides on
	   the same table, checked rather than assumed for the same reason as
	   the frame one directly above.  */
	targetm_insn = targetm_cumargs->insn;
	if (targetm_insn == NULL)
	  internal_error ("back end %qs supplies a %<CUMULATIVE_ARGS%> table "
			  "with no insn-pattern table attached; its objects "
			  "predate target-insn.h and are from a different "
			  "build", base);

	/* The C-family entry points -- TARGET_CPU_CPP_BUILTINS and
	   REGISTER_TARGET_PRAGMAS -- are NOT installed here, and the reason is
	   a link-time one rather than a design preference.  Their tables call
	   into c-family (`c_register_pragma', `builtin_define_with_value'),
	   so they belong to the objects that only cc1 links; this file is in
	   libbackend.a, which lto1 also links.  A `target_c_ops_for' call here
	   pulls target-c-ops-select.o -- and through it every back end's
	   <cpu>-c.o -- into lto1, where those c-family symbols do not exist.
	   Measured: lto1 and lto-dump failed with undefined references to
	   `builtin_define_with_value' and `c_register_pragma' from
	   mt-aarch64/aarch64-c.o while cc1 linked fine.  So the C-family side
	   resolves itself on first use, from multi_target_current_base below.
	   See target-c-ops.h.  */

	mt_current = b;
	return true;
      }

  /* The manifest said this triple's back end is BASE and BASE has no objects.
     That is a build-configuration bug, not a user error, so it is not a
     `return false' that the caller would report as an unknown target.  */
  internal_error ("target %qs names back end %qs, which was not built into "
		  "this compiler", target, base);
}

/* The base in force, for the per-base tables that cannot be installed from
   multi_target_select itself; see multi-target-select.h.  */

const char *
multi_target_current_base (void)
{
  return mt_current != NULL ? mt_current->name : NULL;
}

/* The bare names.  Each is the declaration in recog.h / rtl.h / output.h /
   emit-rtl.h / machmode.h, defined once, forwarding to the back end in
   force.  */

int
recog (rtx pattern, rtx_insn *insn, int *pnum_clobbers)
{
  return mt_in_force ("recog")->recog (pattern, insn, pnum_clobbers);
}

rtx_insn *
split_insns (rtx pattern, rtx_insn *insn)
{
  return mt_in_force ("split_insns")->split_insns (pattern, insn);
}

rtx_insn *
peephole2_insns (rtx pattern, rtx_insn *insn, int *pmatch_len)
{
  return mt_in_force ("peephole2_insns")->peephole2_insns (pattern, insn,
							   pmatch_len);
}

void
insn_extract (rtx_insn *insn)
{
  mt_in_force ("insn_extract")->insn_extract (insn);
}

const char *
get_insn_name (int code)
{
  return mt_in_force ("get_insn_name")->get_insn_name (code);
}

rtx_insn *
peephole (rtx_insn *ins1)
{
  return mt_in_force ("peephole")->peephole (ins1);
}

/* THIS ONE HAS NO FALLBACK ANYWHERE IN THE TREE and that is deliberate.
   A back end with no ADJUST_* in its modes file still gets an
   init_adjust_machine_modes from genmodes, so every configured back end has
   one; if that ever stops being true the forwarder below fails to compile,
   naming the back end.  It is not floored with an #ifndef, because the
   absence of an answer must not be allowed to read as an answer.  */

void
init_adjust_machine_modes (void)
{
  mt_in_force ("init_adjust_machine_modes")->init_adjust_machine_modes ();
}


/* THE CONDITIONAL ONE.  Its guard is the exact complement of the guard under
   which something ELSE in the tree defines the same name, so a mistake in it
   is a duplicate-definition link error rather than a wrong answer.  The guard
   is not a floor: it does not supply a default, it decides who owns the name.

   verify_reg_names_in_constraints: genoutput emits it only under
   `#if CHECKING_P'.

   THIS COMMENT SAID "THE TWO CONDITIONAL ONES" AND DESCRIBED A gen_blockage
   FORWARDER BELOW IT.  There is no such forwarder and there never was -- the
   description was the whole of it.  Do not read the paragraph that follows as
   a record of something that exists; it is the open problem, restated with
   what task #51 measured.

   SIX bare names are supplied to every configured target by the PRIMARY's
   un-namespaced insn-emit-*.o, measured on /tmp/b78 (x86_64 + aarch64) with
   `nm' over every object in the link:

     add_clobbers               <- combine.o recog.o rtl-ssa/changes.o
     added_clobbers_hard_reg_p  <- gcse.o recog.o
     gen_blockage               <- builtins.o explow.o function.o
                                   insn-output-{i386,aarch64}.o
                                   mt-i386/i386.o mt-aarch64/aarch64.o
     gen_nop                    <- cfgrtl.o except.o targhooks.o varasm.o
     gen_speculation_barrier    <- targhooks.o
     gen_movxf                  <- reg-stack.o

   gen_blockage is the one with a demonstrated wrong answer behind it:
   UNSPECV_BLOCKAGE is 1 for i386 and 5 for aarch64, so aarch64 emits an
   unspec_volatile numbered 1 that its own recog matches at 5.

   Writing the forwarders is NOT what is blocking this.  gcc/Makefile.in's OBJS
   names BOTH $(MULTI_TARGET_OBJS) and the primary's un-namespaced
   $(INSNEMIT_SEQ_O), so a forwarder here collides with insn-emit-*.o
   immediately.  (The comment further down that file claiming OBJS names the
   former "rather than" the latter is false; both are on the list.)  That hunk
   belongs to whoever owns Makefile.in.

   And five of the six can take a uniform forwarder while ONE cannot: every
   configured base defines add_clobbers, added_clobbers_hard_reg_p,
   gen_blockage, gen_nop and gen_speculation_barrier in its own namespace, but
   gen_movxf is defined by i386 and not by aarch64 -- so `fail to link, naming
   the base' is the right behaviour for the five and the wrong behaviour for
   gen_movxf, whose only caller (reg-stack.cc) is x87 code aarch64 cannot
   reach.  That is a design question and is left to a ruling, not resolved
   here by whichever choice makes the build succeed.

   Separately, and true of gen_blockage, gen_nop, gen_speculation_barrier and
   gen_movxf but not of the other two: WHETHER the middle end calls them at all
   is decided by HAVE_blockage / HAVE_speculation_barrier / STACK_REGS out of
   the SINGULAR insn-flags.h and tm.h, still the primary's.  Forwarding fixes
   which expansion runs; it does not fix who decides that one runs.  That is an
   insn-flags.h union job, the same one insn-config.h has already had done to
   it.  */

#if CHECKING_P
void
verify_reg_names_in_constraints (void)
{
  mt_in_force ("verify_reg_names_in_constraints")
    ->verify_reg_names_in_constraints ();
}
#endif
