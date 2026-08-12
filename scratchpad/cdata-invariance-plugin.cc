/* Per-function probe of the 35 (c-DATA) candidate macros.
   Runs at PLUGIN_ALL_PASSES_START, i.e. after targetm.set_current_function
   has installed this function's target state.  Prints one line per
   (function, macro).  No verdict is computed here; the shell scores it. */
#include "gcc-plugin.h"
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#include "tree.h"
#include "function.h"
#include "basic-block.h"
#include "rtl.h"
#include "memmodel.h"
#include "emit-rtl.h"
#include "tree-pass.h"
#include "plugin-version.h"
#include "diagnostic.h"
#include "tm_p.h"

int plugin_is_GPL_compatible;

static FILE *out;

#define PI(M)  fprintf (out, "%s|%s|INT|%lld\n", fn, #M, (long long)(M))
#define PS(M)  fprintf (out, "%s|%s|STR|%s\n",   fn, #M, (const char *)(M))

static void
probe (void *, void *)
{
  const char *fn = current_function_decl
    ? IDENTIFIER_POINTER (DECL_NAME (current_function_decl)) : "<none>";

  PI (ATTRIBUTE_ALIGNED_VALUE);
  PI (BIGGEST_ALIGNMENT);
  PI (BYTES_BIG_ENDIAN);
  PI (DWARF_FRAME_RETURN_COLUMN);
  PI (JUMP_TABLES_IN_TEXT_SECTION);
  PI (LONG_TYPE_SIZE);
  PI (MALLOC_ABI_ALIGNMENT);
  fprintf (out, "%s|MAX_FIXED_MODE_SIZE|INT|%lld\n", fn,
	   (long long) (unsigned HOST_WIDE_INT) MAX_FIXED_MODE_SIZE);
  PI (MOVE_MAX);
  PI (PARM_BOUNDARY);
  PI (PIC_OFFSET_TABLE_REGNUM);
  PI (SHIFT_COUNT_TRUNCATED);
  PI (STACK_BOUNDARY);
  PI (STORE_MAX_PIECES);
  PI (STRICT_ALIGNMENT);
  PI (TRAMPOLINE_SIZE);
  PI (UNITS_PER_WORD);
  PI (WORDS_BIG_ENDIAN);
  PI (BITS_PER_WORD);
  PI (FLOAT_WORDS_BIG_ENDIAN);
  PI (REG_WORDS_BIG_ENDIAN);
  PI (MOVE_MAX_PIECES);
  PI (COMPARE_MAX_PIECES);
  PI (DWARF_CIE_DATA_ALIGNMENT);
  PI (STACK_CHECK_FIXED_FRAME_SIZE);
  PI (STACK_CHECK_MAX_FRAME_SIZE);
  PI (SUPPORTS_STACK_ALIGNMENT);
  fprintf (out, "%s|CASE_VECTOR_MODE|INT|%d\n", fn, (int) (machine_mode) CASE_VECTOR_MODE);
  fprintf (out, "%s|Pmode|INT|%d\n", fn, (int) (machine_mode) Pmode);
  fprintf (out, "%s|STACK_SIZE_MODE|INT|%d\n", fn, (int) (machine_mode) STACK_SIZE_MODE);
  PS (PTRDIFF_TYPE);
  PS (SIZE_TYPE);
  PS (WCHAR_TYPE);
  PS (ASM_COMMENT_START);
  PS (GLOBAL_ASM_OP);
  fflush (out);
}

int
plugin_init (struct plugin_name_args *info, struct plugin_gcc_version *ver)
{
  if (!plugin_default_version_check (ver, &gcc_version))
    return 1;
  const char *path = getenv ("CDATA_OUT");
  out = path ? fopen (path, "w") : stderr;
  if (!out)
    { fprintf (stderr, "cdata plugin: cannot open CDATA_OUT\n"); return 1; }
  register_callback (info->base_name, PLUGIN_ALL_PASSES_START, probe, NULL);
  return 0;
}
