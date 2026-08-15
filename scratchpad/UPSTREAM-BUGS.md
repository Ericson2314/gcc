# UPSTREAM BUGS — found incidentally, none reported yet

Bugs in **unmodified upstream GCC**, found while doing the multi-target work but
not caused by it. Nothing here has been submitted. This file exists so that
when we do sit down to file them, the evidence is already assembled and nobody
has to re-derive it from a task description.

**Not in scope for this file:** anything the branch itself introduced, and
anything that is only a bug *given* the multi-target changes. The test is
whether it reproduces on a stock tree at `c31b7a09eea`, or — where the
configuration cannot be built here — whether it is visible in upstream source
by inspection. Each entry says which, because the two are not the same standard
of evidence and one of them below is explicitly the weaker one.

Filing needs a human at a browser: **gcc.gnu.org/bugzilla sits behind Anubis**
and refuses automated fetches, so none of this could be checked against existing
reports by machine. A search of the gcc-patches archives found no matching
report for any of them, which is suggestive and is not the same as confirming
they are unreported.

---

## 1. Two `match.pd` patterns are exact inverses; unbounded recursion on VLA vectors

**Status: MEASURED.** Reproduced 6/6, killed a 61 GB machine.

* `match.pd:11912` — `reduc (op @0 VECTOR_CST@1) -> op (reduc @0) (reduc @1)`
  — `2ef0e75d0bb`, 2022, unguarded, no `:s`
* `match.pd:11942` — `(op (reduc:s @0) (reduc:s @1)) -> (reduc (op @0 @1))`
  — `c74d6b12af6`, **"match.pd: combine a pair of vector reductions"**,
  Kyrylo Tkachov (NVIDIA), 2026-07-29, **on master**

Verified against the upstream mirror, not recalled: the second commit adds
exactly that pattern for MAX, MIN, AND, IOR and XOR.

The forward rule is normally self-limiting because `reduc (VECTOR_CST)`
constant-folds to a scalar. riscv's RVV types under `zve64f` are
**variable-length** (`VNx*`), so it does not fold, the cycle closes, and each
round trip allocates a fresh SSA name. The whole 30-frame backtrace is
`gimple_simplify_MIN_EXPR ↔ gimple_simplify_CFN_REDUC_MIN`.

**Reproducer:** `gcc.target/riscv/pr117506.c` at `-march=rv64im_zve64f`
`-mabi=lp64`. Observed **20.8 GB RSS and climbing** before it was killed.
Negative controls: riscv *without* the vector extension, x86_64, aarch64 and
s390x each compile the same input in under a second.

**Boundary, stated:** not confirmed against a stock riscv64 cross — none exists
in the worktree where this was found. The two commits are upstream and the
mechanism does not involve any branch machinery, but the reproduction was on
our compiler.

**Related and evidence the area is fragile:** PR tree-optimization/121772,
"match.pd: Add missing type check to reduc(ctor) pattern" — a different bug in
the same reduction patterns.

---

## 2. External libcall declarations silently dropped since GCC 14

**Status: REASONED FROM SOURCE, NOT MEASURED** — none of the affected
configurations builds in this environment. Weakest evidence in this file.

**Commit:** `f31a019d1161ec78846473da743aedf49cca8c27` (Jose E. Marchesi,
2023-11-24), PR target/109253, "Emit funcall external declarations only if
actually used."

Before it, `assemble_external_libcall` called
`targetm.asm_out.external_libcall (fun)` immediately and unconditionally. The
commit deferred emission into a new `pending_libcall_symbols` loop and placed
that loop inside the pre-existing `#ifdef ASM_OUTPUT_EXTERNAL` block in
`process_pending_assemble_externals`. **Queuing stayed unconditional; draining
became conditional.** On a target that does not define `ASM_OUTPUT_EXTERNAL`,
symbols are queued and never drained — no `.globl __divdi3`, no
`ASM_OUTPUT_EXTERNAL_LIBCALL`, nothing.

**Affected** (tm_file chain contains none of the 15 `ASM_OUTPUT_EXTERNAL`
definers): `alpha-dec-vms`, `alpha64-dec-vms`, `nvptx-unknown-none`,
`i686-pc-msdosdjgpp`, `microblaze-xilinx-{elf,linux-gnu}`, and **every Darwin**
(`i686/x86_64-apple-darwin*`, `powerpc{,64}-apple-darwin*`).

Upstream fix is one line: move the `pending_libcall_symbols` loop out of the
`#ifdef`. The branch gets it for free at `edb6a2e9559` by deleting the `#ifdef`
entirely.

**Before filing, build one affected target** — Darwin or nvptx — and confirm.
This is the entry most likely to be wrong.

---

## 3. `rs6000_redzone_clobber` passes an rtx where a `poly_int64` is expected

**Status: MEASURED**, and verified verbatim at `c31b7a09eea` with `git show`,
not recalled.

`rs6000.cc:13897` passes `GEN_INT (-red_zone_size)` — an **rtx** — as
`plus_constant`'s `poly_int64` third argument.

With `NUM_POLY_INT_COEFFS == 1` this compiles, because `poly_int<1, long>`'s
constructor casts its single argument: **the rtx pointer value becomes the
constant**. It is a hard error at `poly-int.h:464` only when N == 2.

So upstream is emitting an arbitrary pointer value as a stack offset on any
rs6000 configuration reaching that code, and the type system cannot see it at
N == 1. Fix is dropping the `GEN_INT`.

**Only N == 2 can see it**, which is why it has survived: the diagnostic-driven
sweeps that would have caught it only compile the copies some configured triple
builds, and rs6000 was not among them.

---

## 4. `netbsd-eabi.h` misspells its own spec — every little-endian ARM NetBSD link emits a bare `-m`

**Status: LIVE ON TRUNK**, one character.

```
gcc/config/arm/netbsd-eabi.h
:94   { "linker_little_emulation",  TARGET_LINKER_LITTLE_EMULATION },
:103  "%{mlittle-endian:-EL -m %(linker_liitle_emulation)} "
```

`liitle`. The spec is registered under the correct name and the reference
misspells it, so it expands to nothing and the link gets `-m` with no argument.

**It cannot be diagnosed by construction**, and that is the more interesting
half: `gcc.cc:7031`, `do_spec_1` case `'('`, walks the spec list and does
`if (sl) { … }` with **no else**. An unknown `%(name)` silently expands to
nothing. The silence is architectural, which is why a typo survives
indefinitely.

**The fix worth submitting is the diagnostic, not the typo.**

---

## 5. `#if SWITCHABLE_TARGET` without including `defaults.h`

**Status: LATENT** — real divergence, nothing reads the affected state yet.

Live on trunk for the 8 back ends on the `=1` path. `tree-vrp.cc`,
`tree-ssa-scopedtables.cc`, `plugin.cc`, `c-pretty-print.cc` and
`tree-diagnostic-cfg.cc` bind `&default_target_*` while the rest of the
compiler follows the switched pointer.

Harmless today because none of those five reads the state. It stops being
harmless the moment one of them does, and the failure would be silent and
target-dependent.

---

## Filing notes

Order by strength of evidence, which is not the same as severity: **3 and 4
are verified against stock source and are one-line fixes**; **1 is measured but
was reproduced on our compiler**; **2 is the one where the reasoning is sound
and the measurement is missing**; **5 is latent and may be better as a patch
than a bug**.

Two of these — 4's missing `else` and 2's conditional drain — are the same
shape this whole project keeps meeting: **a mechanism that is present, correct,
and never invoked, with no diagnostic when it isn't.** Worth saying so in the
reports; it is the argument for fixing the silence rather than the instance.
