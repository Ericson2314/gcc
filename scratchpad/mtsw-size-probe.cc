/* SCRATCH INSTRUMENT (not part of the build).

   Measure `sizeof' of every `target_*' structure in target-globals.h, in
   whatever translation-unit context this file is compiled in.  Compiled once
   per configured back end (with -I<base>-inc -DMULTI_TARGET_TARGETM_BASE=<b>,
   i.e. EXEMPT from the defaults.h union override) and once as a shared
   translation unit, the two sets of sizes are the layout disagreement, per
   struct, by name.

   Nothing is executed: the size is carried in the size of an object, read
   back with `nm -S', exactly as multi-target-reg-probe.cc does.  +1 on every
   bound so that "measured zero" and "nm printed nothing" stay different
   outcomes.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#ifdef MULTI_TARGET_TARGETM_BASE
#include "multi-target-base.h"
#include BASE_HEADER (tm.h)
#else
#include "tm.h"
#endif
#include "backend.h"
#include "target.h"
#include "rtl.h"
#include "tree.h"
#include "df.h"
#include "memmodel.h"
#ifdef MULTI_TARGET_TARGETM_BASE
#include BASE_HEADER (tm_p.h)
#include BASE_HEADER (insn-config.h)
#else
#include "tm_p.h"
#include "insn-config.h"
#endif
#include "regs.h"
#include "ira.h"
#include "recog.h"
#include "ira-int.h"
#include "builtins.h"
#include "reload.h"
#include "flags.h"
#include "expmed.h"
#include "libfuncs.h"
#include "cfgloop.h"
#include "gcse.h"
#include "bb-reorder.h"
#include "lower-subreg.h"
#include "function-abi.h"
#include "insn-opinit.h"

extern "C" {
char mtsw_target_flag_state[sizeof (class target_flag_state) + 1];
char mtsw_target_regs[sizeof (struct target_regs) + 1];
char mtsw_target_rtl[sizeof (struct target_rtl) + 1];
char mtsw_target_recog[sizeof (struct target_recog) + 1];
char mtsw_target_hard_regs[sizeof (struct target_hard_regs) + 1];
char mtsw_target_function_abi_info[sizeof (struct target_function_abi_info) + 1];
char mtsw_target_reload[sizeof (struct target_reload) + 1];
char mtsw_target_expmed[sizeof (struct target_expmed) + 1];
char mtsw_target_optabs[sizeof (struct target_optabs) + 1];
char mtsw_target_libfuncs[sizeof (struct target_libfuncs) + 1];
char mtsw_target_cfgloop[sizeof (struct target_cfgloop) + 1];
char mtsw_target_ira[sizeof (struct target_ira) + 1];
char mtsw_target_ira_int[sizeof (class target_ira_int) + 1];
char mtsw_target_builtins[sizeof (struct target_builtins) + 1];
char mtsw_target_gcse[sizeof (struct target_gcse) + 1];
char mtsw_target_bb_reorder[sizeof (struct target_bb_reorder) + 1];
char mtsw_target_lower_subreg[sizeof (struct target_lower_subreg) + 1];
char mtsw_target_constraints[sizeof (struct target_constraints) + 1];

/* The individual quantities, so that a struct that disagrees can be
   attributed to the bound that caused it rather than guessed at.  */
char mtsw_q_MAX_MACHINE_MODE[(int) MAX_MACHINE_MODE + 1];
char mtsw_q_NUM_MACHINE_MODES[(int) NUM_MACHINE_MODES + 1];
char mtsw_q_NUM_MODE_INT[NUM_MODE_INT + 1];
char mtsw_q_NUM_MODE_IP_INT[NUM_MODE_IP_INT + 1];
char mtsw_q_NUM_MODE_IPV_INT[NUM_MODE_IPV_INT + 1];
char mtsw_q_MAX_BITS_PER_WORD[MAX_BITS_PER_WORD + 1];
char mtsw_q_MAX_RECOG_OPERANDS[MAX_RECOG_OPERANDS + 1];
char mtsw_q_NUM_REGISTER_FILTERS[NUM_REGISTER_FILTERS + 1];
char mtsw_q_NUM_INSN_CODES[NUM_INSN_CODES + 1];
char mtsw_q_NUM_OPTAB_PATTERNS[NUM_OPTAB_PATTERNS + 1];
char mtsw_q_NUM_ABI_IDS[NUM_ABI_IDS + 1];
char mtsw_q_HARD_REG_SET[sizeof (HARD_REG_SET) + 1];
char mtsw_q_MAX_MOVE_MAX[MAX_MOVE_MAX + 1];
char mtsw_q_MIN_UNITS_PER_WORD[MIN_UNITS_PER_WORD + 1];
/* BITS_PER_WORD is deliberately NOT probed: defaults.h has already turned it
   into a run-time load in a shared translation unit, so naming it here is a
   compile error rather than a measurement.  That is the reason
   MAX_BITS_PER_WORD exists as a separate name, and why it must stay a
   compile-time constant.  */
char mtsw_q_GR_MAX[(int) GR_MAX + 1];
char mtsw_q_LTI_MAX[(int) LTI_MAX + 1];
char mtsw_q_NUM_ALG_HASH_ENTRIES[NUM_ALG_HASH_ENTRIES + 1];
char mtsw_q_BA_LAST[(int) BA_LAST + 1];
}
