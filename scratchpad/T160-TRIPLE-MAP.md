# #160 — THE TRIPLE MAP: what blocks `{i386, aarch64, X}` for each of the 48 back ends

**Read the verdict column as "does `cc1` LINK", and nothing more.**
`{i386, aarch64, riscv}` links and then ICEs in `multi_target_select`, and
riscv's own `cc1` segfaults before parsing (recorded for #150). No symbol
sweep can see either. **LINK IS NOT WORKS**, and a `predicted LINKS` row is
not a claim that the back end is correct.

| | |
|---|---|
| instrument | `scratchpad/t160-map.sh` (predictor), `scratchpad/t160-validate.sh` (real builds) |
| measured on | `/tmp/b-ac50572b8045cd6e0-48`, one 48-back-end build, `make -k all-gcc`, stamped `build-c2.rc` |
| srcdir | `/tmp/snap-ac50572b8045cd6e0`, an immutable snapshot, **anchor 48**, `git diff --quiet` |
| commit | `83c54dfa8c5` (i.e. **with** this task's `genenums` fix; the before-figures below are `88ff1929380`) |

---

## The headline

**36 of the 46 non-primary back ends are predicted to link as a third base.
Before this task's one-file `genenums` fix the figure was 14.** With the
`ft32.md` fix that followed it, **37** — but 36 is what the sweep in this
document measured, and ft32's row is upgraded on the authority of a real
build, not of a re-run.

**Three third bases are demonstrated, not predicted.** `{i386, aarch64, mips}`
and `{i386, aarch64, ft32}` both reach `make all-gcc` rc=0 with a linked
`cc1` (93,076,376 and 89,288,848 bytes). That is the user's stated goal —
more than two back ends in one binary — met for two back ends beyond the
recorded riscv one, with the remaining 34 predicted and the 10 blockers named.

The ten that do not are blocked by **six named causes**, and no cause covers
more than one back end except the arm/aarch64 shared-source one.

The dominant fact the map found: **one generator asymmetry was the sole
blocker for 22 back ends and one of two blockers for four more.** That is the
amplification PRINCIPLES §1 warns about, seen from the useful side — the
48-base link's "313 undefined references" was mostly one defect, and fixing it
took the count to 59.

## The table

`NOBJ` = an object in `MULTI_TARGET_OBJS_X` was never built (read from the
filesystem, because under `-k` "never attempted" and "passed" are the same
silence). `MULTI` = strong definitions colliding with the shared half or with
i386/aarch64. `UNDEF` = unresolved after attribution. Groups are lettered
against the cause list below.

| back end | verdict | cause |
|---|---|---|
| alpha arc avr bfin bpf cris csky fr30 frv gcn h8300 iq2000 lm32 loongarch m32r microblaze mips mmix mn10300 moxie msp430 nds32 nvptx or1k pa pdp11 pru riscv rl78 rs6000 rx v850 vax visium xstormy16 xtensa | **predicted LINKS** (36) | — |
| arm | MULTI ×29 | **A** — `aarch-common.cc`, `aarch-bti-insert.cc`: the *same source files* built into both arm and aarch64 |
| sparc | MULTI ×3, UNDEF ×1 | **A** `constant_address_p`, `legitimate_pic_operand_p`, `output_probe_stack_range`; **B** `only_leaf_regs_used` |
| s390 | MULTI ×3 | **A** `regclass_map`, `legitimize_pic_address`, `legitimate_pic_operand_p` |
| c6x | MULTI ×1 | **A** `debugger_register_map` |
| ia64 | MULTI ×1 | **A** `output_probe_stack_range` |
| sh | MULTI ×1 | **A** `tls_symbolic_operand` |
| m68k | UNDEF ×1 | **B** `immed_double_const` |
| mcore | UNDEF ×1 | **D** `merge_dllimport_decl_attributes` |
| epiphany | UNDEF ×1 | **C** `get_attr_sched_use_fpu` |
| ft32 | UNDEF ×2 | **C** `insn_ft32::ft32_expand_{pro,epi}logue` — **fixed in this task** |

---

## The cause groups

### A — a bare back-end-private helper name, defined by two back ends (6 back ends, 38 names)

**This is mechanical, and the coordinator's `print_operand` reading
generalises: for every one of these names, NO SHARED TU NAMES THE SYMBOL.**
Measured by grepping the whole of `gcc/` outside `config/` — the only hits are
*prose*: `target-regs.h`, `hard-reg-set.h`, `multi-target-macros.h` and
`target-addr.h` mention `regclass_map` inside explanatory comments and nowhere
else. Shared code reaches all of this through target hooks
(`TARGET_PRINT_OPERAND` at `target.def:1107`, called as
`targetm.asm_out.print_operand` at `final.cc:3679`) or through already-converted
macros (`REGNO_REG_CLASS` → `target-regs`).

So the fix is a `MULTI_TARGET_RENAME_NAMES` entry per name — each back end
simply keeps its own — exactly the `extract_base_offset_in_addr` precedent.
The `-D<name>=<name>_<base>` is emitted for every base by
`gen-multi-target-md.awk` already; adding a name is one line.

**Two things worth saying loudly to whoever owns the `multiple definition`
population:**

- **`print_operand` and `print_operand_address` do not block ANY triple
  containing i386 and aarch64.** They are defined bare by 7 and 8 back ends
  respectively, but *neither i386 nor aarch64 is among them* — both register
  their own differently-named functions as the hook. Those names collide only
  among the other back ends, i.e. they matter at 4+ bases, not at 3.
- arm's 29 are not 29 problems. They are two source files —
  `config/arm/aarch-common.cc` and `config/arm/aarch-bti-insert.cc` — compiled
  into both the arm and the aarch64 object sets. One rename rule covers them
  all, and it is the *correct* outcome: each base gets its own copy.

### B — leaked ABSENCE: a shared TU's definition compiled out by the primary's answer (2 back ends)

Distinct from every other cause here, and invisible to a collision sweep.
A shared translation unit guards a definition on a target macro, the macro
resolves to **i386's answer for everybody**, and the definition simply is not
there for the back end that needs it.

| back end | symbol | the guard | who answers it |
|---|---|---|---|
| sparc | `only_leaf_regs_used` | `final.cc:4150` `#ifdef LEAF_REGISTERS` | sparc is the **only** in-tree back end defining `LEAF_REGISTERS`; i386 does not, so the definition is absent |
| m68k | `immed_double_const` | `emit-rtl.cc:695` `#if TARGET_SUPPORTS_WIDE_INT == 0` | i386 says 1, so the function is not compiled; m68k says 0 and calls it |

This is the same class as `LOAD_EXTEND_OP` and `AUTO_INC_DEC` (33 and 22
definers, i386 in neither), with one difference that makes it *cheaper*: here
the leak deletes a **symbol**, so it fails loudly at the link instead of
silently changing behaviour. Every other instance of this class is silent.
**Two undefined references are the visible tip of it; do not read the 36
"predicted LINKS" rows as evidence the rest of the class is absent.**

### C — the `insn_<be>` namespace boundary (2 back ends)

The generated per-base files live in `namespace insn_<be>`, and two different
things cross that boundary wrongly.

- **ft32** (fixed, `667788e7a96`): `ft32.md`'s `prologue`/`epilogue`
  expanders each carried a redundant block-scope `extern void
  ft32_expand_prologue();`. Upstream that is a duplicate of `ft32-protos.h`;
  inside `namespace insn_ft32` it *declares a different function*, the call
  binds to it, and the real definition is at global scope. Deleting the two
  lines lets the call resolve through `ft32-protos.h` as every other back
  end's does.
- **epiphany** (open): `epiphany.md:1054`'s `peephole2` condition calls
  `get_attr_sched_use_fpu`. `insn-attrtab-epiphany.o` defines
  `insn_epiphany::get_attr_sched_use_fpu`, but the referencing file
  `insn-recog-epiphany-5.cc` **does not include `insn-attr-<be>.h`**, so
  unqualified lookup inside the namespace finds only the *global* declaration
  in `epiphany-protos.h` and binds there. A generator gap in `genrecog`, not
  an `.md` defect.

Both have the same tell and it is worth naming: **a declaration that was pure
redundancy at global scope becomes a second authority the moment a namespace
is wrapped around it, and nothing diagnoses that.**

### D — a back end calling a function no configured back end builds (1 back end)

`mcore.cc` calls `merge_dllimport_decl_attributes`, which is defined in
`config/mingw/winnt.cc`. `attribs.cc`/`attribs.h` name it too, under
`TARGET_DLLIMPORT_DECL_ATTRIBUTES`. Nothing in an mcore-elf configuration
builds `winnt.o`, so the reference is unresolved. This is a `config.gcc`
`extra_objs` question, not a link question.

### E — FIXED THIS TASK: `unspec_strings` / `unspecv_strings` for every base

**Sole blocker for 22 back ends; one of two blockers for four more.**

`multi-target-select.cc`'s `MT_OTHER_TABLES` / `MT_SCALAR_TABLES` name
`unspec_strings`, `unspecv_strings` and their two lengths for **all N bases
unconditionally**. `genenums` emitted a table only for an enum the back end's
md actually declares — and 26 of the 48 declare one or neither, because they
spell their `UNSPEC_*` constants with the older `define_constants` instead of
`define_c_enum`. `mips`, for instance, has `define_c_enum "unspec"` and no
`unspecv`.

The fix (`83c54dfa8c5`) emits an empty table of length 0 for an enum the base
does not have. **PRINCIPLES §2a's test, applied explicitly:** ask whose answer
the fallback is. A back end with no `unspecv` enum has no unspecv names, so
empty/0 is *its own* answer, identical to what upstream produces for it
standing alone. Upstream expresses it by not compiling the reader at all
(`#if defined (NUM_UNSPECV_VALUES)`, `print-rtl.cc:506`); a multi-target build
cannot, because that macro comes from the singular `genconstants` run and
therefore carries the primary's answer for everyone. Expressing it in data
(`len 0` makes every `XINT (x, 1) < unspecv_strings_len` false) reproduces
upstream's `#if` exactly, and no base reads another's table.

---

## What the instrument cannot see

Stated per PRINCIPLES §4 rule 5, because a clean result from an instrument
with unexamined blind spots is worth very little.

- **COMDAT / weak definitions are not scored as collisions.** The linker keeps
  one body by link order and says nothing; #52 is exactly that shape.
- **`libbackend.a` is an archive**, so `ld` reports only collisions whose
  members both get pulled in — it once reported 7 of 40. This sweep
  OVER-counts what `ld` prints and accurately counts what is duplicated.
- **Macros expanding to option state (`global_options.x_*`) are invisible to
  `nm` by construction.** `ix86_pmode`, `ix86_branch_cost` and their kind
  cannot appear here at all.
- **Leaked absence is only partly visible** — see group B.
- **One base set was built.** Anything that only appears when the base set
  changes the generated files is invisible. That is not hypothetical: it is
  precisely what the validation arm caught (below).

## Validation — three real 3-base builds, compared BY NAME

A predictor nobody checked is worth less than nothing, and this one was wrong
the first time.

| triple | predicted | the real build said |
|---|---|---|
| `{i386, aarch64, mips}` *(before the fix)* | LINKS | **WRONG** — `insn_mips::unspecv_strings`, `..._len` undefined |
| `{i386, aarch64, mips}` *(after the fix)* | LINKS | **`make all-gcc` rc=0, `cc1` linked, 93,076,376 bytes** |
| `{i386, aarch64, s390}` | MULTI: `regclass_map`, `legitimize_pic_address`, `legitimate_pic_operand_p` | **exactly those three, 3 of 3 by name** |
| `{i386, aarch64, ft32}` *(before the `.md` fix)* | UNDEF: `insn_ft32::ft32_expand_epilogue`, `...prologue` | **exactly those two, 2 of 2 by name** |
| `{i386, aarch64, ft32}` *(after `667788e7a96`)* | LINKS | **`make all-gcc` rc=0, `cc1` linked, 89,288,848 bytes, zero linker complaints** |

**The first row is the important one.** The predictor's baseline — what the
known-good `{i386, aarch64}` pair leaves unresolved — was computed over a
48-base build, in which the *shared* `multi-target-select.o` references
`insn_<be>::` symbols for all 48 back ends. Those references landed in the
baseline and were then subtracted from every back end: **92 `unspecv_strings`
references hidden at once**, including the one that mattered. Only a real
build could have shown that, which is what the arm is for.

The repair attributes every symbol to a base, by definition or by its
`insn_<be>` mangled namespace, and drops symbols belonging to bases outside
the triple. Parsing that namespace needs the mangling's **length prefix**, not
a character class: back-end names contain digits (`i386`, `h8300`, `c6x`), and
a greedy `insn_\([a-z0-9_]*\)[0-9]` attributed `_ZN9insn_mips15unspecv_stringsE`
to a base called `mips10gen_absdf`. Both defects are now asserted by name in
arm 0, so neither can return silently.

**The instrument can show its own fix landing** (PRINCIPLES §4): re-run on the
rebuilt tree it reports 14 → 36, with the 22 sole-blocker back ends moving to
`predicted LINKS`. A queue from a tool that could not do that cannot converge.

## What is left at 48 bases that no triple shows

The `{i386, aarch64, X}` question does not exercise everything. After the
`genenums` fix the full 48-base link is down to **59 undefined references and
181 multiple definitions**, and the undefined residue contains three causes
that only appear with more bases:

- `gt_ggc_mx_machine_function_{epiphany,mmix,nds32}` and their `gt_pch_nx_`
  partners — the gengtype-marker family (#155, owned elsewhere).
- `ghs_pragma_*` ×8 — v850's `c`-target glue, referenced but not in the link.
- `insn_m68k::gen_umulsi3_highpart` — another instance of group C.
