# #155 -- THE REMAINING `multiple definition` NAMES, CLASSIFIED

From `t155-rename-gap.sh` over all 48 configured bases: **64 colliding
hand-written names**, of which 7 are the benign `mt_probe_*`
(`MULTI_TARGET_REG_PROBES`: compiled, never linked).

48 names are now in `MULTI_TARGET_RENAME_NAMES`. What is left is below, with
the classification already done, so the next pass is an edit and a build rather
than an investigation.

**Do not inherit this list without re-running the sweep.** The collision set is
a function of which bases are configured, and — see the caveat at the bottom —
the *safety* of a rename is a function of which back end supplies the shared
`tm.h`.

## A. `config/arm/aarch-common.cc` — 20 names, one cause

`config.gcc:377` puts `aarch-common.o` in **aarch64's** `extra_objs` and
`config.gcc:424` puts it in **arm's**. One source compiled once per back end,
so every external it defines collides — **exactly the `config/linux.cc` shape**,
whose three `linux_*` names are already in the rename list for this reason.

Four are already renamed (`aarch_bti_enabled`, `aarch_bti_j_insn_p`,
`aarch_pac_insn_p`, `aarch_fun_is_indirect_return`). The other 20 should go in
together, since they are one cause and not twenty:

    aarch_gen_bti_c                     arm_early_load_addr_dep
    aarch_gen_bti_j                     arm_early_load_addr_dep_ptr
    aarch_bti_arch_check                arm_early_store_addr_dep
    aarch_rev16_p                       arm_early_store_addr_dep_ptr
    aarch_rev16_shleft_mask_imm_p       arm_no_early_alu_shift_dep
    aarch_rev16_shright_mask_imm_p      arm_no_early_alu_shift_value_dep
    aarch_mm_needs_acquire              arm_no_early_mul_dep
    aarch_mm_needs_release              arm_no_early_store_addr_dep
    aarch_accumulator_forwarding        arm_mac_accumulator_is_result
    aarch_validate_mbranch_protection   arm_mac_accumulator_is_mul_result
    make_pass_insert_bti                arm_md_asm_adjust
    arm_rtx_shift_left_p

All 20 are clean on **both** checkers: no shared TU spells the bare name
(`t155-classify.sh`), and no `config/` macro reaching a shared TU calls one
(`t155-macroref.sh`).

**ONE CAVEAT, AND IT IS THE ONE TO CHECK FIRST.** `make_pass_insert_bti` is a
pass constructor. `pass_insert_bti` is registered from
`config/arm/arm-passes.def:21` **and** `config/aarch64/aarch64-passes.def:26`,
i.e. from both back ends. Renaming the constructor per base is only correct if
each base's pass registration is also per base. **Verify that before landing
this one**; the other 19 do not have the question.

## B. Straightforward renames, classified clean

    debugger_register_map    c6x i386
    num_source_filenames     alpha mips
    minipool_barrier         arm csky
    minipool_fix_head        arm csky
    minipool_fix_tail        arm csky

## C. Another agent's name, reported as a crossing

    regno_reg_class          csky frv m68k mcore sh

Bare in five back ends. Its only shared hit is `target-regs.h:240`, which is
the **selector's own function-pointer member declaration** — `int
(*regno_reg_class) (int regno);` — not a call to a bare function. So by the
stated rule it is a rename, not a selector, and the selector it appears to need
already exists. Owned by the `print_operand`-family agent; not touched here.

## D. NOT renames — reported, not resolved

    constant_address_p         i386 sparc
    legitimate_pic_operand_p   arm i386 s390 sparc

Renaming these produced **51 `undefined reference` lines from shared objects**,
because shared code reaches them through `CONSTANT_ADDRESS_P` and
`LEGITIMATE_PIC_OPERAND_P` (`i386.h:1853`, `:1870`), used by `emit-rtl.cc`,
`explow.cc`, `final.cc`, `recog.cc`, `reload.cc`, `reload1.cc`, `ira-costs.cc`
and `lra-constraints.cc`.

They need the **macro converted** so each base answers for itself. A forwarder
is not the answer: `multi-target-select.cc` already refused the identical
question for `gen_movxf` — defined by i386 and not aarch64 — leaving it *"to a
ruling, not resolved here by whichever choice makes the build succeed."* 44 of
48 back ends define neither of these, and s390 defines `CONSTANT_ADDRESS_P` as
literal `0` with no function at all.

## E. Driver-side, left to `target-specs`

    host_detect_local_cpu    bare in 8 back ends

Already has a selector (`spec-functions-select.cc`); `target-specs` is being
chosen as the route for the `-march=native` capability that reads it.

---

## THE CAVEAT THAT APPLIES TO ALL OF THE ABOVE

**A rename's safety currently depends on which back end supplies the shared
`tm.h`.** `constant_address_p` is unsafe because *i386's* macro calls it;
`symbol_mentioned_p` is safe **only** because i386's `LEGITIMATE_PIC_OPERAND_P`
does not call it while *arm's does*. Configure arm as the `tm.h` supplier and
the safe and unsafe sets change.

This stops being true only when the macros are converted — which is the same
task as deleting the shared `tm.h`. Until then, **re-run
`t155-macroref.sh` after any change to which base supplies `tm.h`.**

---

## F. TWO OF THE 33 ARE UNVERIFIED BY ANY BUILD I RAN

`t155-macroref-all.sh` is over-broad by construction and flags ten names. Eight
of those are settled:

  * `constant_address_p`, `legitimate_pic_operand_p` -- now carry the
    `target_addr` funnel, which is what makes the rename safe;
  * `print_operand`, `print_operand_address`, `init_cumulative_args`,
    `output_ascii`, `symbol_mentioned_p`, `label_mentioned_p` -- **exercised**
    by the 4-base or 8-base build with a definer present, producing no
    undefined reference.

**Two were exercised by neither, and should be treated as unproven:**

    final_prescan_insn         h8300 iq2000 sh   -- none configured in either build
    nonpic_symbol_mentioned_p  lm32 sh           -- neither configured

By inspection both are safe *while i386 supplies the shared `tm.h`*: i386.h
defines no `FINAL_PRESCAN_INSN`, and its `LEGITIMATE_PIC_OPERAND_P` does not
call `nonpic_symbol_mentioned_p`. **That is an argument, not a measurement**,
and it is exactly the primary-dependent kind this file warns about at the
bottom. Configure sh (which defines both macros) and re-read before trusting
them.

The cheap arm: configure a base set containing `sh`, and check for undefined
references to those two names.
