# T157 — the stub register

The user relaxed the correctness bar for task #157: *"just get those backends
building — even if everything is busted it's OK, we'll figure it out."*
PRINCIPLES §2a's ban on stubs and floors is suspended **for link-level fixes on
this task only**, on two conditions, and this file is the second one:

1. prefer `gcc_unreachable ()` or a fail-by-name abort over a plausible wrong
   value — a stub returning the primary's answer is the one thing that will be
   genuinely hard to find later;
2. **record every stub in one committed list**, so the correctness pass gets a
   work queue instead of an archaeology problem.

## Stubs left by this task

**ONE.**

### 1. `only_leaf_regs_used` — `final.cc`, aborts by name

Reached by configuring **eight** back ends; `mt-sparc/sparc.o` calls it and an
eight-base link fails with `undefined reference to only_leaf_regs_used()`.

It is SHARED code — declared in `output.h`, defined in `final.cc` — whose
definition is gated on `LEAF_REGISTERS`, a per-back-end `tm.h` macro. Shared
objects are compiled once, against the primary's `tm.h`; i386 does not define
`LEAF_REGISTERS`, so **the definition is not compiled at all**.

The stub `internal_error`s naming the macro. It does **not** return a value,
deliberately: `true` would tell every back end its function uses only
renumberable registers, `false` would silently disable sparc's leaf-register
optimisation, and both are plausible values belonging to no back end —
findable only by reading the assembly of a sparc leaf function. The abort is
findable by running it once.

**The larger bug behind it, NOT fixed:** `function.cc:6491`'s
`rest_of_handle_check_leaf_regs` is gated on the *same* macro, so
`crtl->uses_only_leaf_regs` is never set for **any** back end. sparc's
leaf-register pass has been silently inert on this branch, not merely
unlinkable. The fix is to move `LEAF_REGISTERS` into the per-base family
(`target-regs.h` is its natural home) — a correctness change, deferred.

---

Everything else made for #157 supplies a genuine per-base answer, and it is
worth saying which kind each one is, because that is exactly the claim a later
reader will want to re-check:

| change | what it supplies | whose answer |
|---|---|---|
| `print_operand`, `print_operand_address`, `regclass_map` renamed per base | each back end keeps its own definition | its own — no shared TU names the bare symbol at all |
| `legitimize_pic_address` renamed per base | same | its own |
| `legitimate_pic_operand_p` → 5th `target_addr` funnel | `LEGITIMATE_PIC_OPERAND_P` evaluated in each base's own preprocessor context | its own, incl. `defaults.h`'s `1` read under *its* `tm.h` |
| genpreds singular `insn-preds.cc` redirect | routes one macro out of a shared object | the selected base's |
| gengtype installer reset + name check | dispatchers null for tags this base lacks; `gt_multi_target_no_marker` fails **by name** at the point of use | fail-by-name, no value invented |
| genenums empty `unspec`/`unspecv` tables | length **0** for an md that defines no such enum | its own — counted from that md, and what upstream behaves as |
| `HAVE_BFmode` guard (`tree.cc`) | no `bfloat16_type_node` for a base without BFmode | its own — exactly upstream's behaviour for it |
| `widest_int_mode_for_target ()` | widest int mode the **selected** base has | its own; `gcc_unreachable ()` rather than a floor if a base had none |
| 7 × `aarch_*`, `output_probe_stack_range` renamed per base | each back end keeps its own | its own — no shared TU, no macro |
| `constant_address_p` → 6th `target_addr` funnel | `CONSTANT_ADDRESS_P` in each base's own context | its own, incl. `defaults.h`'s generic form under *its* `tm.h` |

**No fallback anywhere in the above is another back end's value.** The
suspension was used exactly once, for `only_leaf_regs_used`, and there it
bought an abort rather than a value.

## The rename test, and why it is written down

Two of the eleven names added by this task looked like pure renames and were
not: `legitimate_pic_operand_p` and `constant_address_p`. In both cases a grep
for the **symbol** over every shared `.cc` and `.h` found nothing, and in both
cases shared code reaches the function through a **`tm.h` macro** whose name is
not the symbol's — `LEGITIMATE_PIC_OPERAND_P` (7 shared sites) and
`CONSTANT_ADDRESS_P` (7 shared sites), each with a `defaults.h` fallback and
each defined by **i386.h** as a call to the bare function.

So the rename turned `multiple definition` into `undefined reference`, twice.

**The test:** before concluding a bare rename suffices, ask what the PRIMARY's
`tm.h` expands the corresponding MACRO to — not only whether shared code spells
the symbol. A symbol grep answers a different question than the one being
asked, and answers it in the reassuring direction.

## TWENTY COLLIDING NAMES THAT THE LINKER DID NOT DIAGNOSE

`cc1` links with **eight** back ends at `f2c2de8aea9` — and
`scratchpad/t157-rename-gap.sh` over the same build dir reports **27** bare
names defined by more than one base. Seven are the deliberate
`MULTI_TARGET_REG_PROBES` (`mt_probe_*`, compiled and never linked). **Twenty
are real:**

```
aarch_accumulator_forwarding      arm_early_load_addr_dep
aarch_mm_needs_acquire            arm_early_load_addr_dep_ptr
aarch_mm_needs_release            arm_early_store_addr_dep
aarch_rev16_p                     arm_early_store_addr_dep_ptr
aarch_rev16_shleft_mask_imm_p     arm_mac_accumulator_is_mul_result
aarch_rev16_shright_mask_imm_p    arm_mac_accumulator_is_result
aarch_validate_mbranch_protection arm_md_asm_adjust
make_pass_insert_bti              arm_no_early_alu_shift_dep
                                  arm_no_early_alu_shift_value_dep
                                  arm_no_early_mul_dep
                                  arm_no_early_store_addr_dep
                                  arm_rtx_shift_left_p
```

All are `config/arm/aarch-common.cc` and `config/arm/aarch-bti-insert.cc`,
compiled once for **arm** and once for **aarch64** — the same shape as
`config/linux.cc`, already in the rename list for the same reason.

**A GREEN LINK IS NOT EVIDENCE THE RENAME LIST IS COMPLETE.** `gcc/Makefile.in`
says so above the list — "libbackend.a is an ARCHIVE, so a duplicate is
diagnosed only when both members happen to be pulled in for other reasons;
`ld` once reported 7 of 40" — and this is that sentence being demonstrated on a
live build rather than quoted. The seven `aarch_*` names in the previous commit
*were* diagnosed; these twenty are the same defect in the same two files and
were not. **The sweep is the authority; the linker is an under-count of it.**

Not renamed here, deliberately: each name needs the macro test above (does the
primary's `tm.h` expand some macro to it?) before a rename is safe, and two of
eleven failed that test in this task. Renaming twenty blind on the strength of
a sweep, with no link failure to check the result against, is how the
`legitimate_pic_operand_p` mistake gets made twenty times instead of once.

### RESOLVED by #165 — all twenty renamed, after the macro test

`scratchpad/t165-macrotest.sh` runs the test on each of the twenty, in two arms
that answer different questions: arm S (does a shared TU spell the bare
symbol?) and arm M (does *any* `#define` under `config/` carry the name in its
body?). Arm M is deliberately over-broad — it can only revoke a rename, never
authorise one — and it carries a positive control (`constant_address_p`, known
macro-reached) so that an all-clear cannot come from a broken instrument.

**Nineteen are clean on both arms. The twentieth is a false positive**:
`arm_md_asm_adjust` is found by arm.cc:838's
`#define TARGET_MD_ASM_ADJUST arm_md_asm_adjust`, which is the `target.def`
*hook* macro — expanded only by `target-def.h` inside arm.cc's own TU, so
definition and use are in the same base's objects and the `-D` reaches both.

Two blind spots of the source-level test were closed **against the generated
artefact**, which is where both answers actually live:

- the fourteen `arm_*` scheduling predicates are named by
  `mt-arm/insn-attrtab-arm.cc`, which is generated and therefore invisible to
  arm S. Safe, because `multi-target-md.mk` puts the `insn-*-<cpu>` objects
  inside `MULTI_TARGET_OBJS_<cpu>`, which carries `MULTI_TARGET_RENAMES` — the
  generated caller and the hand-written definition are renamed together.
- `make_pass_insert_bti` is named by `arm-passes.def` and
  `aarch64-passes.def`, which feed `pass-instances.def`, which **shared**
  `passes.cc` includes twice. That would have revoked the rename. It does not,
  for a reason that is itself a defect — see below.

## #165: THE COUNT IS **ELEVEN**, AND THE CEILING ABOVE IT IS NAMED

Measured both ways from an immutable snapshot, one build dir, per-base objects
deleted between arms so the changed `-D` set could not be missed (GCC objects do
not depend on `Makefile`, so an incremental build here is a false green):

| bases | commit | anchor | result |
|---|---|---|---|
| 8 (i386 aarch64 rs6000 s390 riscv mips sparc arm) | `70c9d9b3194` | 48 | links, rc=0, 167,756,696 B — but the sweep reports **20** real collisions |
| 8, same set | `4b25a706fd5` | 50 | links, rc=0, 167,770,896 B, sweep **0** real collisions |
| **11** (the 8 + ia64, visium, xtensa) | `70c9d9b3194` | 48 | **FAILS**, rc=2, `multiple definition` of `empty_delay_slot`, `output_ubranch`, no `cc1` |
| **11** (the 8 + ia64, visium, xtensa) | `4fc753a90b6` | 50 | **LINKS**, rc=0, 0 errors / 0 multiple definitions / 0 undefined references, 170,641,264 B |
| 16 (the 11 + alpha, csky, m68k, nds32, sh) | `4fc753a90b6` | 50 | fails; all 16 **compile**, 3 collision names + 2 undefined-reference causes remain |

**8 → 11.** The renames are load-bearing for exactly this set, not incidental:
`empty_delay_slot` and `output_ubranch` are defined by **sparc and visium**, both
in the 11.

That the 20 aarch64/arm names had to be fixed first is the point of the #157
finding — the 8-base build *linked* while carrying them, so the green said
nothing. Renaming them is what made adding a ninth back end a question about the
ninth back end rather than about arm.

### Why these five are not in the 11, each by name

- **nds32** — `undefined reference to gt_ggc_mx_machine_function_nds32` /
  `gt_pch_nx_machine_function_nds32`. The gengtype-marker shape.
- **m68k** — `undefined reference to immed_double_const`; see the wide-int
  ceiling below.
- **csky, m68k, sh** — `multiple definition of regno_reg_class`, which a rename
  does **not** fix (five back ends define `REGNO_REG_CLASS` as `regno_reg_class[…]`;
  the `constant_address_p` shape, caught by the macro test before the link).
- **sh** — `multiple definition of tls_symbolic_operand` against the **singular
  shared** `insn-preds.o`, which is a genpreds question, not a rename.
- **alpha** — `multiple definition of num_source_filenames`, against **mips**.
  Renameable for this base set; the over-broad arm M revoked it on
  `iq2000.h:758`'s `SET_FILE_NUMBER()`, a back end this build never configures.
  Recorded as a cost of the instrument's deliberate over-breadth, not a defect.

### THE WIDE-INT CEILING — the `only_leaf_regs_used` shape, now a CLASS

`insn-emit-m68k-8.o` fails with `undefined reference to immed_double_const`.
That function is **shared** code, `emit-rtl.cc:708`, gated on
`#if TARGET_SUPPORTS_WIDE_INT == 0` — a per-back-end `tm.h` macro. Shared objects
are compiled once against the **primary's** `tm.h`; `i386.h:3109` says `1`, so
the definition is not compiled **for anybody**.

Only **11 of 48** back ends define the macro (`defaults.h:1374` gives the other
37 a `0`), so every one of those 37 whose `.md` emits such a call cannot link.
This is a *structural ceiling on the back-end count*, not a per-back-end defect,
and it is the third instance of one shape:

| shared function | gated on | who decides |
|---|---|---|
| `only_leaf_regs_used` | `LEAF_REGISTERS` | i386 does not define it → absent for all |
| `rest_of_handle_check_leaf_regs` | `LEAF_REGISTERS` | same |
| `immed_double_const` | `TARGET_SUPPORTS_WIDE_INT` | i386 says 1 → absent for all |

The general form: **a shared TU's `#if` on a back-end macro makes the primary
decide which shared functions exist.** Worth a sweep of its own — nobody has
enumerated the population, and each instance costs one back end at link time
while being invisible to any build that does not configure that back end.

## `PASSES_EXTRA` IS i386's, SO EVERY OTHER BACK END'S TARGET PASSES ARE GONE

Found by asking whether `make_pass_insert_bti` was safe to rename; it is, and
the reason it is safe is that **nothing calls it, or any other back end's pass
constructor**.

`PASSES_EXTRA` is how a back end contributes its target passes to
`pass-instances.def`, and it is set by the per-target `config/<cpu>/t-<cpu>`
fragments reached through `-include $(tmake_file)`. In an **eight-base** build
dir, `tmake_file` is substituted as **i386's list alone**:

```
tmake_file= .../config/t-slibgcc .../config/t-linux .../config/t-glibc
            .../config/i386/t-linux64 .../config/i386/t-pmm_malloc
            .../config/i386/t-i386 .../config/i386/t-linux
            .../config/i386/t-gnu-property
```

because it comes from the single legacy `${target}` pass through `config.gcc`,
not from the back-end list. Measured in `pass-instances.def` in that build dir:
`pass_stv`, `pass_remove_partial_avx_dependency` and
`pass_insert_endbr_and_patchable_area` are present — i386's, from
`config/i386/t-i386`'s `PASSES_EXTRA` — and **not one pass from aarch64, arm,
rs6000, s390, riscv, mips or sparc**, though `t-aarch64:195` and `t-arm:163`
both still carry their `PASSES_EXTRA +=` lines.

Both halves of this project's defining bug in one channel:

- **leaked PRESENCE** — shared `passes.cc` walks `pass-instances.def`
  unconditionally, so i386's target passes are in the pipeline whichever base
  is selected;
- **leaked ABSENCE** — every other back end's target passes are silently
  missing. aarch64 and arm BTI insertion has never run on this branch. This is
  the `AUTO_INC_DEC` (#162) and `LEAF_REGISTERS` shape: no diagnostic, and the
  absence reads as "this back end has no target passes".

**Not fixed here, and it is not a stub — it is a design change.**
`pass-instances.def` is one shared authority and `passes.cc`'s `NEXT_PASS` walk
is compiled once, so a per-base pass list means either a per-base `passes.cc`
or a selector inside the walk. #165 is a link-level unblock and this is a
correctness change; it is recorded here so the correctness pass inherits it as
work rather than as archaeology.

Note the ordering trap for whoever takes it: fixing `PASSES_EXTRA` **revokes
the `make_pass_insert_bti` rename's justification**, since shared `passes.cc`
would then name the bare symbol from two bases. The rename must stay and the
pass list must select, not the other way round.

## Not fixed, and NOT stubbed — the real work queue

These are open walls, left failing loudly rather than papered over. None of
them is a stub; they are listed here because this is the file the correctness
pass will read.

- **#154 — riscv driver `SIGSEGV`.** Confirmed live at `98184824b07`:
  `riscv64-unknown-linux-gnu-gcc -c fn.c` exits **139**. `-dumpspecs` and `-v`
  are fine; only a real compilation reaches `set_multilib_dir`.
  `multilib.h` is generated once, so `multilib_select` is a single shared
  authority, and `riscv_compute_multilib` (`common/config/riscv/riscv-common.cc:2135`)
  does `p = multilib_select; while (*p != '\0')` with no null check.
  Fixing it properly means `multilib.h` per base. **`cc1` is unaffected — this
  is the driver only.**
- **s390 `default_function_value_regno_p`, `targhooks.cc:1153`,
  `gcc_unreachable ()`.** Reached during RTL combine for s390x on a four-base
  `cc1`. This is the targhook DEFAULTS matrix, which another agent owns and
  which #157's brief put out of bounds — deliberately not touched.
- **`MAX_MODE_INT` read as a MODE at five more sites**, same defect as the one
  converted, not swept because nothing measured them:
  `optabs.cc:8349`, `simplify-rtx.cc:2048`, `simplify-rtx.cc:2085`,
  `simplify-rtx.cc:7239`, `combine.cc:7475`. Read as a BOUND — a different
  question, possibly fine — at `dse.cc:1745` and `rtlanal.cc:79`.
- **`type_natural_mode`, `config/i386/i386.cc:2155`.** x86_64 `-O2` on
  `scratchpad/big.c` ICEs at `v4si f_vec (v4si a, v4si b)` in a **three**-base
  and a **four**-base build, at the same commit. The recorded bar
  (12369 bytes / `378fc33c1e70`) is a **two**-base figure. Tracks base count,
  not any #157 change — every one of those is a no-op when i386 is selected —
  but the two-base control at this commit is named in the report as **not
  measured**.
