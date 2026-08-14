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
