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

---

# The `undefined reference` half at 48 back ends — no new stubs

Measured independently of #157, at 48 configured back ends, from an immutable
snapshot with the log stamped before scoring: **108 distinct undefined symbols
/ 323 linker lines -> 0**. Seven causes. `scratchpad/ur-score.sh`.

**This work added NO stub.** `only_leaf_regs_used` above is the only one, and
it was found twice independently — from sparc at eight bases (#157) and from
sparc at 48 — which is worth recording as corroboration rather than
duplication. Everything else here supplies a real per-base answer or deletes a
guard that had no business being per-base:

| change | whose answer |
|---|---|
| `immed_double_const` — `#if TARGET_SUPPORTS_WIDE_INT == 0` deleted from the definition (`emit-rtl.cc`) and the declaration (`rtl.h`) | nobody's — the body reads **no target macro at all**, only host quantities and mode queries. m68k calls it from `m68k.md:3270`; the primary's `1` had compiled it out. |
| `merge_dllimport_decl_attributes` / `handle_dll_attribute` — `#if TARGET_DLLIMPORT_DECL_ATTRIBUTES` deleted (`attribs.cc`) | its own — whether a back end **uses** them is still decided by that back end's own `targetm`. mcore's `mcore.cc:169` puts it in `TARGET_MERGE_DECL_ATTRIBUTES` under its own headers, where the macro is 1. |
| `ft32.md` — a local `extern void ft32_expand_prologue ();` **inside an insn body** deleted | its own — `ft32-protos.h` already declares it correctly. genemit wraps bodies in `namespace insn_ft32`, so the local extern declared a *different* function nothing defines. |
| `epiphany-protos.h` — `get_attr_sched_use_fpu` moved **into** `namespace insn_epiphany` | its own — genattrtab defines it there; the bare declaration made twelve peephole2 calls bind to a global nothing defines. |
| `config.gcc` — `v850/t-v850` added to the `v850*-*-*` branch | its own — that fragment carries the only rule for `v850-c.o`, which the branch already listed in `c_target_objs`. |
| `nds32.cc`, `mmix.cc`, `epiphany.cc` — `#include "gt-<cpu>.h"` added | its own — gengtype already wrote each base's `machine_function` markers into that file, and nothing included it. |

## The generalisable cause, and the instrument for it

Three of the seven — `only_leaf_regs_used`, `immed_double_const`,
`merge_dllimport_decl_attributes` — are **one** defect:

> a **shared** TU compiles a function out under `#if <per-base target macro>`,
> the macro is read with the **primary's** `tm.h`, and a per-base object calls
> the function anyway.

PRINCIPLES §3's "guard hiding a declaration", in its *definition*-hiding form.
**A symbol sweep cannot find these before they fire** — the definition simply
is not there to be found, and `nm` on the shared object shows nothing at all.
The instrument that finds them ahead of the link is a grep for `#if TARGET_` /
`#ifdef` on a per-back-end macro **in shared sources**, cross-referenced
against what the guarded region defines. That sweep has not been run.

## The two namespace shapes, which are mirror images

Also worth naming together, because meeting either one alone teaches the wrong
lesson:

- **ft32** declared a function *inside* the generated namespace that is defined
  *outside* it;
- **epiphany** declared a function *outside* the generated namespace that is
  defined *inside* it.

Both produce `undefined reference`, and the fix runs in opposite directions.
The rule is not "namespace it" or "don't" — it is **the declaration must be in
the same namespace as the definition**, and generated per-base sources put
their definitions inside.

## A silently dropped `c_target_obj`, and a refusal that could not fire

`v850e1-elf` listed `v850-c.o` in `c_target_objs` while its `tmake_file` omitted
`v850/t-v850`, the only fragment carrying the rule.
`gen-multi-target-md.awk` asks each fragment where a `c_target_obj`'s source
lives, got no answer, and **dropped the object with no diagnostic**; the link
failed eight symbols later at `ghs_pragma_*`, a name that mentions neither
`v850-c.o` nor `config.gcc`.

The generator's existing `$(error)` for this could not catch it: an object no
fragment claims fails the `^config/<cpu>/` test and is dropped from `cobjs_own`
*before* reaching the loop that refuses — **the exclusion runs before the
check**. A `$(warning)` now sits at the drop site.

**Its first draft was unscoped and fired 48 times on a correct tree**, every
one a false positive on OS-side objects (`default-c.o`, `glibc-c.o`) which are
built by generic rules and legitimately have no fragment. Scoped to
`<cpu>-c.o` it reads **zero**, with `v850` as its negative control. That draft
also produced a false finding — that `ia64` had the same defect — which is
**withdrawn**: `ia64/t-ia64` does claim `ia64-c.o`, and it was never in the
warning's output. A check tuned badly enough is a source of findings, not just
noise.

## Leak left in place, named rather than papered over

Two `#if TARGET_WIN32_TLS` blocks inside `attribs.cc`'s `handle_dll_attribute`
are still read with the **primary's** headers — the same defect one level down.
Not on any currently-linking path, because only a back end that registers the
dllimport attributes reaches them.

---

## #167: THE COUNT IS **SIXTEEN**, AND NO NEW STUB WAS NEEDED

**The stub register above is still ONE.** Nothing in this task invented a
value; both changes are renames, and each gives a back end its own symbol.

Measured both ways from an immutable snapshot, ONE build dir, per-base objects
deleted between the arms (787 of them — GCC objects do not depend on
`Makefile`, so an incremental build after a `-D` change is a false green):

| bases | commit | anchor | result |
|---|---|---|---|
| 16 | `d0a93825d3d` | 50 | **FAILS** rc=2, no `cc1`, 2 collision causes, **0** undefined references |
| 16 | `7b6527b080f` | 52 | **LINKS** rc=0, 0 errors / 0 multiple definitions / 0 undefined references, `cc1` 176,858,896 B |

The sixteen are the eleven — i386, aarch64, rs6000, s390, riscv, mips, sparc,
arm, ia64, visium, xtensa — plus **alpha, csky, m68k, nds32, sh**.

**Scored as DEFINITIONS, not references**, in the linked binary:
`nm -C --defined-only cc1` lists `targetm_aarch64 targetm_alpha targetm_arm
targetm_csky targetm_i386 targetm_ia64 targetm_m68k targetm_mips targetm_nds32
targetm_riscv targetm_rs6000 targetm_s390 targetm_sh targetm_sparc
targetm_visium targetm_xtensa` — sixteen hook tables, one per configured base.

**Both sweep arms and `ld` agree at sixteen bases**, which is the first time
three instruments with different blind spots have been reconciled here:

```
arm 1 (base vs base)     7 colliding names, all mt_probe_* -> REAL 0
arm 2 (base vs SHARED)   0
ld                       0
```

### FOUR OF THE SIX RECORDED BLOCKERS WERE ALREADY DEAD — RE-MEASURE HANDED-DOWN QUEUES

The "why these five are not in the 11" list above was accurate when taken and
**four-sixths stale one merge later**, because the measurement behind it
(`4fc753a90b6`) is not a descendant of two commits on a parallel worktree
branch. `git merge-base --is-ancestor` settles it in a second; nobody ran it.

| recorded blocker | state at `d0a93825d3d` | killed by |
|---|---|---|
| `immed_double_const` | **gone** | the `#if TARGET_SUPPORTS_WIDE_INT == 0` around `emit-rtl.cc:706` removed |
| `gt_ggc_mx_machine_function_nds32` (+ pch sibling) | **gone** | `e1b47e6fb51`, `#include "gt-nds32.h"` in nds32.cc |
| `tls_symbolic_operand` | **gone** | `e55c19021e9` put the name in `MULTI_TARGET_RENAME_NAMES` |
| `regno_reg_class` | live | fixed here |
| `num_source_filenames` | live | fixed here |

This is worth more than the two fixes. A blocker list reads as current
indefinitely: every entry names a real symbol in a real file, and nothing about
it decays visibly. On a branch that merges parallel worktrees, **a named-cause
list is a measurement with a timestamp**, and the first action on inheriting one
is to re-run it, not to work it. Cost here: one build. Yield: four of six items
already done.

Note also that **the wide-int ceiling recorded above is NOT a ceiling.** It was
described as "a structural ceiling on the back-end count — only 11 of 48 back
ends define `TARGET_SUPPORTS_WIDE_INT`, so every one of the other 37 whose md
emits such a call cannot link". The resolution was not per-back-end at all:
compiling the one shared definition unconditionally serves every back end,
because — as the comment at `emit-rtl.cc:706` argues — **its body reads no
target macro**. The general shape ("a shared TU's `#if` on a back-end macro
makes the primary decide which shared functions exist") is still real and still
worth the sweep nobody has run; this instance was cheap.

### #167'S TWO NAMES, SETTLED BY A BUILD RATHER THAN BY INSPECTION

Both were renamed on a tree no build exercised, and were safe only *by
inspection* — the same primary-dependent reasoning that has been wrong twice.
A base set containing **sh** covers both, and sh is now in the set.

- **`nonpic_symbol_mentioned_p` — unconditionally safe, and both arms are empty
  for the right reason.** No `#define` anywhere under `config/` has it in its
  body, and no shared TU spells it. Two definers, `sh.cc` and `lm32.cc`, both
  back-end-local. `nm` shows `T nonpic_symbol_mentioned_p_sh` in `mt-sh/sh.o`
  in a link with zero undefined references.

- **`final_prescan_insn` — safe HERE, and safe only because of who the primary
  is.** This one is a live instance of the `constant_address_p` shape that
  happens not to fire, and recording it as simply "safe" would be wrong.

  `sh.h:1721`, `h8300.h:722` and `iq2000.h:448` define `FINAL_PRESCAN_INSN` as
  the **bare** `final_prescan_insn (...)`. Shared `final.cc` guards on
  `#ifdef FINAL_PRESCAN_INSN`. **i386 does not define the macro, and neither
  does `defaults.h`** — so with i386 as primary the guard is false, shared code
  expands nothing, and the rename cannot break it. `nm` confirms
  `T final_prescan_insn_sh`, and the link reports zero undefined references,
  which is the arm that could have failed.

  **Make sh, h8300 or iq2000 the primary and the same rename produces
  `undefined reference to final_prescan_insn` from `final.o`.** So this is not
  a settled name; it is a name whose hazard is masked by the primary's silence
  — and "the primary does not define this macro" is the weakest possible reason
  for something to work on a branch whose stated goal is that there is no
  primary. It belongs to the correctness pass. The honest form of the #167
  verdict is: **one of the two is settled, the other is measured-safe-for-this-
  primary.**

  Note the asymmetry that makes this hard to see: an **absent** macro and a
  **converted** macro produce the identical link result. Only reading the
  definers tells them apart.
