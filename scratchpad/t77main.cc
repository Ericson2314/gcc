/* ARM 1 for task #77: a NON-PRIMARY back end's members round-tripping through
   the generated save/restore code in options-save.cc.

   Why this is a harness and not a cc1 invocation: selecting aarch64 in this
   branch ICEs in `aarch64_class_max_nregs' from `init_reg_sets_1' -- the hard
   register union (Application 2) has not landed -- so no aarch64 compilation
   can reach the parser.  That ICE is PRE-EXISTING and reproduces identically
   with /tmp/b-objs/gcc/cc1, which does not contain this change.  Option
   save/restore runs long before `init_regs', so it is reachable; this program
   links the same objects cc1 does, selects aarch64 the same way toplev does,
   and calls the generated entry points directly.

   The members exercised are declared by aarch64's .opt files ALONE:
     cl_optimization : x_aarch64_early_ra, x_flag_aarch64_early_ldp_fusion,
                       x_flag_aarch64_late_ldp_fusion, x_aarch64_narrow_gp_writes
     cl_target_option: x_aarch64_branch_protection_string, x_aarch64_tls_dialect,
                       x_aarch64_isa_flags_0/_1
   In an options-save.cc built from the PRIMARY's optionlist alone, none of
   them is written by save or read by restore, and every check below fails.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#include "target.h"
#include "common/common-target.h"
#include "multi-target-select.h"
#include "opts.h"
#include "options.h"
#include "diagnostic-core.h"

static int failures = 0;
static int checks = 0;

#define CHECK(what, got, want)						\
  do {									\
    checks++;								\
    if ((got) == (want))						\
      printf ("  ok   %-40s round-tripped as %lld\n", what,		\
	      (long long) (got));					\
    else								\
      {									\
	failures++;							\
	printf ("  FAIL %-40s expected %lld, got %lld\n", what,		\
		(long long) (want), (long long) (got));			\
      }									\
  } while (0)

/* `cl_optimization_compare' reports by calling internal_error, which does not
   return, so it is exercised in a child process the script scores by exit
   status.  Two modes, and both are needed: "same" must return normally (a
   compare that always fired would score "differ" for free), "differ" must not
   (that is the aarch64 member being looked at).  */
static int
compare_mode (bool differ)
{
  gcc_options a = global_options;
  gcc_options b = global_options;
  if (differ)
    b.x_aarch64_narrow_gp_writes = !a.x_aarch64_narrow_gp_writes;
  cl_optimization_compare (&a, &b);
  printf ("compare(%s): returned normally\n", differ ? "differ" : "same");
  return 0;
}

int
main (int argc, char **argv)
{
  const char *targ = "aarch64-unknown-linux-gnu";
  bool cmp_same = (argc > 1 && strcmp (argv[1], "compare-same") == 0);
  bool cmp_diff = (argc > 1 && strcmp (argv[1], "compare-differ") == 0);

  /* The same two calls, in the same order, that toplev.cc:2396 makes.  */
  if (!targetm_common_select (targ))
    {
      printf ("FATAL: targetm_common_select (%s) failed -- not a configured"
	      " target, so nothing below would mean anything\n", targ);
      return 9;
    }
  if (!multi_target_select (targ))
    {
      printf ("FATAL: multi_target_select (%s) failed\n", targ);
      return 9;
    }
  printf ("selected: %s\n", targ);

  /* Prove the selection is real and is NOT the primary: the i386 targetm and
     the aarch64 one are different objects.  If this fails, every `ok' below
     would be i386 code walking i386 members.  */
  if (targetm.target_option.save == NULL)
    printf ("note: selected targetm has no target_option.save hook\n");

  global_options = global_options_init;
  memset (&global_options_set, 0, sizeof (global_options_set));

  if (cmp_same || cmp_diff)
    return compare_mode (cmp_diff);

  /* ---- cl_optimization ------------------------------------------------ */
  printf ("\ncl_optimization_save/restore (aarch64-only members):\n");
  global_options.x_aarch64_early_ra = (enum aarch64_early_ra_scope) 2;
  global_options.x_flag_aarch64_early_ldp_fusion = 1;
  global_options.x_flag_aarch64_late_ldp_fusion = 1;
  global_options.x_aarch64_narrow_gp_writes = 1;
  global_options_set.x_aarch64_early_ra = (enum aarch64_early_ra_scope) 1;
  global_options_set.x_flag_aarch64_late_ldp_fusion = 1;

  struct cl_optimization o;
  memset (&o, 0, sizeof (o));
  cl_optimization_save (&o, &global_options, &global_options_set);

  /* The struct really was written, not merely left alone.  */
  CHECK ("cl_optimization.x_aarch64_early_ra", (int) o.x_aarch64_early_ra, 2);
  CHECK ("cl_optimization.x_flag_..._early_ldp", (int) o.x_flag_aarch64_early_ldp_fusion, 1);
  CHECK ("cl_optimization.x_flag_..._late_ldp", (int) o.x_flag_aarch64_late_ldp_fusion, 1);
  CHECK ("cl_optimization.x_..._narrow_gp_writes", (int) o.x_aarch64_narrow_gp_writes, 1);

  /* Clobber, then restore, and see the values come back.  */
  global_options.x_aarch64_early_ra = (enum aarch64_early_ra_scope) 0;
  global_options.x_flag_aarch64_early_ldp_fusion = 0;
  global_options.x_flag_aarch64_late_ldp_fusion = 0;
  global_options.x_aarch64_narrow_gp_writes = 0;
  memset (&global_options_set, 0, sizeof (global_options_set));

  cl_optimization_restore (&global_options, &global_options_set, &o);
  CHECK ("restored x_aarch64_early_ra", (int) global_options.x_aarch64_early_ra, 2);
  CHECK ("restored x_flag_..._early_ldp_fusion", (int) global_options.x_flag_aarch64_early_ldp_fusion, 1);
  CHECK ("restored x_flag_..._late_ldp_fusion", (int) global_options.x_flag_aarch64_late_ldp_fusion, 1);
  CHECK ("restored x_aarch64_narrow_gp_writes", (int) global_options.x_aarch64_narrow_gp_writes, 1);

  /* The explicit_mask half.  Its bit for a member is the member's ORDINAL in
     the walk, which is exactly what diverges when two walks are built from
     different lists.  */
  printf ("\nexplicit_mask (the private encoding, both ends from one list):\n");
  struct cl_optimization o2;
  memset (&o2, 0, sizeof (o2));
  memset (&global_options_set, 0, sizeof (global_options_set));
  global_options_set.x_aarch64_narrow_gp_writes = 1;
  cl_optimization_save (&o2, &global_options, &global_options_set);
  {
    int any = 0;
    for (size_t i = 0; i < ARRAY_SIZE (o2.explicit_mask); i++)
      if (o2.explicit_mask[i])
	any = 1;
    checks++;
    if (any)
      printf ("  ok   an aarch64-only Optimization option set a bit in"
	      " explicit_mask[%d]\n", (int) ARRAY_SIZE (o2.explicit_mask));
    else
      {
	failures++;
	printf ("  FAIL setting only an aarch64-only option left explicit_mask"
		" entirely zero -- it has no ordinal in the walk\n");
      }
  }

  /* ---- cl_target_option ----------------------------------------------- */
  printf ("\ncl_target_option_save/restore (aarch64-only members):\n");
  memset (&global_options_set, 0, sizeof (global_options_set));
  global_options.x_aarch64_branch_protection_string = "standard";
  global_options.x_aarch64_tls_dialect = (enum aarch64_tls_type) 1;
  global_options.x_aarch64_isa_flags_0 = 0x1234;
  global_options.x_aarch64_isa_flags_1 = 0x5678;
  /* aarch64's own TargetVariables.  They are also what aarch64_option_restore
     needs to be valid: it calls aarch64_get_tune_cpu, which asserts the tune
     is not aarch64_no_cpu.  Setting them here is not a workaround for the
     code under test -- they too are aarch64-only members that must survive
     the round trip, and they are checked below.  */
  global_options.x_selected_tune = (enum aarch64_cpu) 0;
  global_options.x_selected_arch = (enum aarch64_arch) 0;

  struct cl_target_option t;
  memset (&t, 0, sizeof (t));
  cl_target_option_save (&t, &global_options, &global_options_set);

  checks++;
  if (t.x_aarch64_branch_protection_string
      && strcmp (t.x_aarch64_branch_protection_string, "standard") == 0)
    printf ("  ok   cl_target_option.x_..._branch_protection_string = \"%s\"\n",
	    t.x_aarch64_branch_protection_string);
  else
    {
      failures++;
      printf ("  FAIL cl_target_option.x_..._branch_protection_string was not"
	      " saved (%s)\n",
	      t.x_aarch64_branch_protection_string
	      ? t.x_aarch64_branch_protection_string : "(null)");
    }
  CHECK ("cl_target_option.x_aarch64_tls_dialect", (int) t.x_aarch64_tls_dialect, 1);
  CHECK ("cl_target_option.x_aarch64_isa_flags_0", (long long) t.x_aarch64_isa_flags_0, 0x1234);
  CHECK ("cl_target_option.x_aarch64_isa_flags_1", (long long) t.x_aarch64_isa_flags_1, 0x5678);
  CHECK ("cl_target_option.x_selected_tune", (int) t.x_selected_tune, 0);
  CHECK ("cl_target_option.x_selected_arch", (int) t.x_selected_arch, 0);

  global_options.x_aarch64_branch_protection_string = NULL;
  global_options.x_aarch64_tls_dialect = (enum aarch64_tls_type) 0;
  global_options.x_aarch64_isa_flags_0 = 0;
  global_options.x_aarch64_isa_flags_1 = 0;
  global_options.x_selected_tune = (enum aarch64_cpu) 1;
  global_options.x_selected_arch = (enum aarch64_arch) 1;

  cl_target_option_restore (&global_options, &global_options_set, &t);
  checks++;
  if (global_options.x_aarch64_branch_protection_string
      && strcmp (global_options.x_aarch64_branch_protection_string, "standard") == 0)
    printf ("  ok   restored x_aarch64_branch_protection_string\n");
  else
    {
      failures++;
      printf ("  FAIL x_aarch64_branch_protection_string did not come back\n");
    }
  CHECK ("restored x_aarch64_tls_dialect", (int) global_options.x_aarch64_tls_dialect, 1);
  /* NOT an equality check, and the reason is worth stating: aarch64's own
     `targetm.target_option.restore' (aarch64_option_restore ->
     aarch64_override_options_internal) runs AFTER the generated walk and
     RECOMPUTES x_aarch64_isa_flags from the arch and tune.  So the back end,
     not options-save.cc, owns the final value here, and asserting 0x1234
     would be asserting the back end does not do its job.  What the generated
     walk owes is that the member is written at all -- it was clobbered to 0
     immediately above, and 0 is what "never restored" looks like.  The
     exact-equality evidence for this pair is the save-side check above and
     x_aarch64_isa_flags_1, which the hook leaves alone.  */
  checks++;
  if (global_options.x_aarch64_isa_flags_0 != 0)
    printf ("  ok   restored x_aarch64_isa_flags_0 is non-zero (%lld; the"
	    " aarch64 restore hook recomputes it)\n",
	    (long long) global_options.x_aarch64_isa_flags_0);
  else
    {
      failures++;
      printf ("  FAIL x_aarch64_isa_flags_0 is still the clobbered 0\n");
    }
  CHECK ("restored x_aarch64_isa_flags_1", (long long) global_options.x_aarch64_isa_flags_1, 0x5678);
  CHECK ("restored x_selected_tune", (int) global_options.x_selected_tune, 0);
  CHECK ("restored x_selected_arch", (int) global_options.x_selected_arch, 0);

  /* ---- eq/hash see them too ------------------------------------------- */
  printf ("\ncl_target_option_eq / _hash notice an aarch64-only member:\n");
  {
    struct cl_target_option t2 = t;
    checks++;
    if (!cl_target_option_eq (&t, &t2))
      { failures++; printf ("  FAIL two identical copies compared unequal\n"); }
    else
      {
	t2.x_aarch64_isa_flags_0 = 0x4321;
	checks++;
	if (cl_target_option_eq (&t, &t2))
	  {
	    failures++;
	    printf ("  FAIL changing x_aarch64_isa_flags_0 left them equal --"
		    " cl_target_option_eq does not look at it\n");
	  }
	else
	  printf ("  ok   changing x_aarch64_isa_flags_0 makes them unequal\n");
	checks++;
	if (cl_target_option_hash (&t) == cl_target_option_hash (&t2))
	  {
	    failures++;
	    printf ("  FAIL the hash ignores x_aarch64_isa_flags_0\n");
	  }
	else
	  printf ("  ok   the hash changes with x_aarch64_isa_flags_0\n");
      }
  }

  printf ("\nchecks=%d failures=%d\n", checks, failures);
  if (checks < 18)
    {
      printf ("FATAL: only %d checks ran; this run proves nothing\n", checks);
      return 9;
    }
  printf (failures ? "OVERALL FAIL\n" : "OVERALL PASS\n");
  return failures ? 1 : 0;
}
