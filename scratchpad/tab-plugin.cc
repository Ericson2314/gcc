/* TAB step 2 -- DISPATCH CORRECTNESS, measured at run time inside the real
   linked multi-target cc1.

   The design (CLASS-C-DESIGN.md 5) proposed resolving each base's hook slot
   statically, from relocations.  That is archaeology over a link, and it
   cannot see a data slot at all.  This does the same job by *reading the
   slot*: the plugin binds to each base's target table by name (cc1 is linked
   -rdynamic, so targetm_<base> is in .dynsym) and prints the pointer stored
   in the slot.  Resolving that pointer to a symbol is done OUTSIDE, by nm
   over the same cc1, so nothing here depends on dladdr seeing static symbols.

   For a POD slot -- GLOBAL_ASM_OP is a string, not a function -- the same
   read is byte-exact: the accessor is called and its bytes are printed.
   `.globl' vs `.global' assembles identically, so nothing weaker than this
   distinguishes the two bases' answers.  */
#include "gcc-plugin.h"
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#include "tree.h"
#include "memmodel.h"
#include "tm_p.h"
#include "target.h"
#include "target-asm-ops.h"
#include "target-addr.h"
#include "target-cdata.h"
#include "plugin-version.h"

int plugin_is_GPL_compatible;

extern struct gcc_target targetm_i386;
extern struct gcc_target targetm_aarch64;
extern const struct target_asm_ops targetm_asm_ops_i386;
extern const struct target_asm_ops targetm_asm_ops_aarch64;
extern const struct target_addr targetm_addr_i386;
extern const struct target_addr targetm_addr_aarch64;
extern void targetm_cdata_refresh_i386 (struct target_cdata *);
extern void targetm_cdata_refresh_aarch64 (struct target_cdata *);

static void
dump_ptr (FILE *o, const char *base, const char *macro, const char *slot,
	  const void *p)
{
  fprintf (o, "PTR|%s|%s|%s|%p\n", base, macro, slot, p);
}

static void
dump_str (FILE *o, const char *base, const char *macro, const char *slot,
	  const char *s)
{
  fprintf (o, "STR|%s|%s|%s|", base, macro, slot);
  if (!s)
    fputs ("<null>", o);
  else
    for (const char *q = s; *q; q++)
      fprintf (o, "%02x", (unsigned char) *q);
  fputc ('\n', o);
}

static void
one_base (FILE *o, const char *base, const struct gcc_target *t,
	  const struct target_asm_ops *a, const struct target_addr *d,
	  void (*cdata_refresh) (struct target_cdata *))
{
  /* Stage 2 -- the (c-DATA) slots.  Each base's refresh function is CALLED
     here, into a local struct, and what it writes is printed.

     Calling it rather than reading `targetm_cdata' is the only way to get both
     bases out of one run: `targetm_cdata' holds the SELECTED base's values,
     and this plugin runs under one selection at a time.  It is also the
     stronger read -- it exercises the same function `init_targetm_cdata ()'
     calls, so a refresh that writes nothing shows up here.

     ONE CAVEAT, AND IT IS REAL.  These values may depend on option state, and
     the option state in force during this run is the SELECTED base's.  For the
     four macros dumped below that does not bite: aarch64's are plain constants
     in aarch64.h, and i386's depend on TARGET_LP64, which is correct here
     because i386 is the base this run selects.  A field added later whose
     value depends on the OTHER base's options would be measured wrong by this
     plugin, and would need a second run under that base's config.  */
  struct target_cdata cd;
  memset (&cd, 0, sizeof cd);
  cdata_refresh (&cd);
  dump_str (o, base, "ASM_COMMENT_START", "cdata.asm_comment_start",
	    cd.asm_comment_start);
  dump_str (o, base, "WCHAR_TYPE",        "cdata.wchar_type",   cd.wchar_type);
  dump_str (o, base, "SIZE_TYPE",         "cdata.size_type",    cd.size_type);
  dump_str (o, base, "PTRDIFF_TYPE",      "cdata.ptrdiff_type", cd.ptrdiff_type);

  /* Stage 1 -- the addresses.h family.  These four slots hold the addresses of
     `static' functions in target-addr-<base>.o, so BOTH bases' copies carry
     the SAME symbol name (gcc_taddr_base_reg_class and friends) at DIFFERENT
     addresses.  The ownership-by-name test therefore cannot apply, and must
     not be made to: tab-probe.sh's existing "per-base copy" branch is the
     right verdict here, and it is strictly the stronger one -- it requires the
     two bases to hold different addresses, which is precisely the property
     that failed for LIBCALL_VALUE (one body, every base).  */
  dump_ptr (o, base, "BASE_REG_CLASS",       "addr.base_reg_class",
	    (const void *) d->base_reg_class);
  dump_ptr (o, base, "INDEX_REG_CLASS",      "addr.index_reg_class",
	    (const void *) d->index_reg_class);
  dump_ptr (o, base, "REGNO_OK_FOR_BASE_P",  "addr.ok_for_base_p_1",
	    (const void *) d->ok_for_base_p_1);
  dump_ptr (o, base, "REGNO_OK_FOR_INDEX_P", "addr.ok_for_index_p_1",
	    (const void *) d->ok_for_index_p_1);

  /* Stage 0's three macros. */
  dump_ptr (o, base, "LIBCALL_VALUE",       "calls.libcall_value",
	    (const void *) t->calls.libcall_value);
  dump_ptr (o, base, "ASM_OUTPUT_EXTERNAL", "asm_out.output_external",
	    (const void *) t->asm_out.output_external);
  dump_str (o, base, "GLOBAL_ASM_OP",       "asm_ops.global_op",
	    a->global_op ? a->global_op () : NULL);

  /* Discrimination controls, emitted for every base so the script can assert
     the instrument reports BOTH agreement and disagreement.  Without the
     agreeing one, a TAB that returned a constant would look healthy. */
  dump_ptr (o, base, "CTL_SHARED",  "asm_out.output_source_filename",
	    (const void *) t->asm_out.output_source_filename);
  dump_str (o, base, "CTL_SHARED2", "asm_ops.text_section",
	    a->text_section_asm_op ? a->text_section_asm_op () : NULL);
  /* A slot both back ends override with their OWN named function.  If TAB
     cannot report these two as different, it cannot report anything as
     different, and every "same symbol" verdict would be unfalsifiable.  */
  dump_ptr (o, base, "CTL_DIFFER",  "legitimate_address_p",
	    (const void *) t->legitimate_address_p);
}

static void
run (void *, void *)
{
  const char *path = getenv ("TAB_OUT");
  FILE *o = path ? fopen (path, "w") : stderr;
  if (!o) { fprintf (stderr, "tab: cannot open TAB_OUT\n"); return; }
  one_base (o, "i386", &targetm_i386, &targetm_asm_ops_i386,
	    &targetm_addr_i386, targetm_cdata_refresh_i386);
  one_base (o, "aarch64", &targetm_aarch64, &targetm_asm_ops_aarch64,
	    &targetm_addr_aarch64, targetm_cdata_refresh_aarch64);
  fclose (o);
}

int
plugin_init (struct plugin_name_args *info, struct plugin_gcc_version *ver)
{
  if (!plugin_default_version_check (ver, &gcc_version))
    return 1;
  register_callback (info->base_name, PLUGIN_FINISH_UNIT, run, NULL);
  return 0;
}
