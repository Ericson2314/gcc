# VERIFY-BACKLOG — deferred verification, run at last

Measured at `f0148c7520dde31517a865a2479d5ee113e88702` (branch `multi-target`).
HEAD did not move during the run (checked at start and end). Nothing committed,
nothing staged, nothing written into the tree — this file and the `vb-*.sh`
probes live in the session scratchpad under `/tmp`, deliberately NOT in the
repo `scratchpad/` (which is partly tracked; writing there would have left
untracked files behind).

Build measured: `/tmp/b-objs` — x86_64 primary (`i386`) + aarch64 non-primary.

## Instrument assertions made BEFORE scoring anything

The DEVSHELL warning was live, not hypothetical:

- `nm` is **not on PATH** in this environment (`which nm` -> not found). Every
  symbol count in this document was taken with an explicitly asserted
  `/nix/store/03kd334a6rknx3ai08g28bgcynjjkfap-binutils-2.46/bin/nm`, version
  printed, run as `cmd > out 2> err` with `err` asserted empty and `out`
  asserted non-empty. A `multi-target-select.o` with 81 undefined symbols and
  a `cc1` with 175,610 symbols are the non-empty inputs the scoring rests on.
- `make` is also not on PATH. Compile arms ran inside the DEVSHELL `-p` set
  kept **byte-identical** to the known-cached one, with
  `NIX_HARDENING_ENABLE` stripped of `format`.

**One of my own instruments failed mid-run and I am recording it**, because it
failed in the flattering direction. My first sweep for the object defining
`aarch64_expand_prologue` looped over `*.o` in `/tmp/b-objs/gcc` only, found
nothing, and I briefly read that as "the hand-written aarch64 back end is not
in this build". It is: it lives in `mt-aarch64/aarch64.o` and in
`libbackend.a`. A top-level glob is not a search. The corrected sweep used
`find` over `.o` **and** `.a`.

A second instrument was vacuous and got replaced: I checked for the
`GCC_TM_H`-gated block by grepping preprocessed output for
`CUMULATIVE_ARGS_MAGIC`. That is a `#define`, so it never appears in `-E`
output at all, and it scored 0 for the poisoned **and** the healthy arm —
a checker that answers "absent" unconditionally. Replaced with a grep for the
inline *definition* `get_cumulative_args (cumulative_args_t`, which is
directional (present healthy / absent poisoned).

---

## 1. Task #49 — gas-capability conversions re-verified with a NON-PRIMARY back end

### Verdict: CONFIRMED (the `GCC_TM_H` failure mode is repaired, and the repair is load-bearing)

The non-primary compile is real and its command line was captured from `make -n`,
not guessed:

    g++ ... -Iaarch64-inc -I. -Imt-aarch64 ... \
      -Dtargetm=targetm_aarch64 -DMULTI_TARGET_TARGETM_BASE=aarch64 \
      -o mt-aarch64/aarch64.o .../config/aarch64/aarch64.cc

Both halves of the rename are present, which `target.h:390-398` now asserts with
a paired `#error` — half a rename is a build error rather than a middle-end
object silently bound to one back end's table.

The forwarder that `5739d5e4fb3` broke is `aarch64-inc/tm.h`, and it is correct
now — it forwards **and** re-establishes the guard the middle end tests:

    #include "tm-aarch64.h"
    #ifndef GCC_TM_H
    #define GCC_TM_H
    #endif

This matters because `tm-aarch64.h` itself guards on `GCC_TM_AARCH64_H` and
never defines `GCC_TM_H`. Its mtime (Aug 11 16:43) is later than every sibling
forwarder in that directory (15:28), consistent with it having been repaired
separately.

### The injection — verification that could fail, and did

Three arms, each with the object deleted first, compiled to `/tmp` so no arm
could be stale, poisoned forwarder placed ahead of `aarch64-inc` on `-I` so
**nothing in the tree was edited**:

| arm | what | result |
|---|---|---|
| 0 baseline, real forwarder | must succeed | rc=0, object PRESENT, 0 errors |
| 1 positive control, `#error POISON_MARKER_ALPHA` | must fail **naming the marker** | rc=1, object ABSENT, marker named 2x |
| 2 the test, forwarder minus `GCC_TM_H` | must fail loudly | rc=1, object ABSENT, **15 errors, 55 `cumulative_args` mentions, 94 stderr lines** |

Marker survival asserted separately: the poisoned header contributes
`extern int POISON_49_NO_GCC_TM_H_MARKER;` which appears **2x** in the poisoned
preprocessed TU and **0x** in the healthy one; the `get_cumulative_args` inline
definition appears at line 127462 of the healthy TU and is **absent** from the
poisoned one while 10 call sites remain. Both directions demonstrated.

Arm 2's errors are all in `config/aarch64/aarch64.cc` plus its included
`calls.h`, with siblings unaffected — **exactly the "many errors in ONE file
while its siblings compile clean" ratio** the brief said reads as a broken
forwarder. The signature is reproducible on demand, so a future regression here
is detectable rather than silent.

### The mitigating property: CONFIRMED

`HAVE_GAS_HIDDEN` is now `#define HAVE_GAS_HIDDEN (targ_caps.gas_hidden)`
(`defaults.h:1576`) and is consumed as a value — `if (!HAVE_GAS_HIDDEN)` in
`varasm.cc:6886` and `targhooks.cc:1067`, `if (HAVE_GAS_HIDDEN && ...)` in
`ipa.cc:1081`. A member access on an undeclared object is a hard compile error,
so the conversion does hold the claimed property: where `#ifdef
HAVE_GAS_HIDDEN` deleted a block in silence, the runtime form cannot fail
quietly. This is the same mechanism arm 2 above exercised, which is why I count
it demonstrated rather than argued.

### What this does NOT establish

The brief asks for `rs6000`/`mips`/`avr` re-verified as non-primary. **They are
not in this build.** Only `mt-i386` and `mt-aarch64` object trees exist in
`/tmp/b-objs`. So the finding is: the *mechanism* by which a non-primary TU
loses `GCC_TM_H` is repaired and is now proven load-bearing, verified on the one
non-primary back end that exists. Whether `rs6000.o`/`mips.o`/`avr.o` build
clean as non-primary is **still unverified**, and needs a build that configures
them.

---

## 2. Task #51 — `gen_blockage`

### Verdict: REFUTED. Half done, and the missing half is a live wrong-answer bug.

This is the item the brief warned not to close on "the selector landed". It did
land, and it does not cover this.

**The distinguishing half is done.** `nm -C cc1` shows exactly one `::gen_blockage`
and the per-back-end copies properly namespaced — no archive quietly keeping one
of two:

    00000000010735b0 T gen_blockage()
    0000000002dc81d0 T insn_aarch64::gen_blockage()
    00000000027e00b0 T insn_i386::gen_blockage()

**The choosing half does not exist.** `multi-target-select.cc` contains **no
`gen_blockage` forwarder** — only a comment at line 526 describing one. The file
is 542 lines; the "two conditional ones" block at 520-533 announces
`gen_blockage` and `verify_reg_names_in_constraints`, and only the latter is
actually written. `gensupport.cc:4023-4024` states the same non-fact as
established: *"the bare `::gen_blockage` comes from multi-target-select.cc,
which forwards to the back end in force"*. `genflags.cc:266-273` contradicts it
and is the one that matches the code.

Settled in the artefact, not by grep:

- `::gen_blockage` is defined by **`insn-emit-1.o`** — the singular (primary,
  i386) insn-emit — at the same offsets `0x6b0`/`0x7252` as
  `insn-emit-i386-1.o`.
- Disassembly at `0x10735b0` sits amid `gen_ffssi2_no_cmove` and
  `gen_clzdi2_lzcnt_nf` and calls `expand_rtx` on an i386 encoding. It is a real
  i386 expansion, **not a forwarder** — a forwarder would not have the
  `gen_blockage()::expand_encoding` static local that `nm` also shows.
- `mt-aarch64/aarch64.o` (2752 symbols) carries `U gen_blockage()`, as do
  `explow.o`, `builtins.o`, `function.o`, `i386.o`.

**This is not benign.** The two `blockage` patterns are textually identical
RTL — `(unspec_volatile [(const_int 0)] UNSPECV_BLOCKAGE)` — but
`UNSPECV_BLOCKAGE` is a per-back-end enum constant:

    insn-constants-i386.h      UNSPECV_BLOCKAGE = 1
    insn-constants-aarch64.h   UNSPECV_BLOCKAGE = 5
    insn-constants.h           UNSPECV_BLOCKAGE = 1   <- singular = primary's

So with aarch64 selected, aarch64's five hand-written `gen_blockage ()` call
sites in `aarch64.cc` (plus `aarch64.md:1704`) and every middle-end caller emit
an `unspec_volatile` numbered **1**, which aarch64's recog matches at **5**.
This is the memory note's "shared numbering, many authorities" exactly: one
name, several authorities, no diagnostic. The escape-list reasoning that
`gen_blockage` needs *choosing* rather than *distinguishing* was right, and the
choosing was never implemented.

The source is honest about the blocker in `genflags.cc` and `gensupport.cc` —
it needs the singular `insn-flags.h` unioned, as `insn-config.h` already was —
but two comments assert a forwarder that does not exist, and those should be
corrected before someone reads them as this item being closed.

---

## 3. Task #15 — `LCOMM_WITH_ALIGNMENT`, `CV_UCOMP`

### Verdict: STILL UNVERIFIABLE. Both conversions are dead code in this configuration.

This is the `TARGET_XCOFF` shape again, and it narrows the claim.

**`HAVE_GAS_CV_UCOMP` -> `targ_caps.gas_cv_ucomp`** (`dwarf2codeview.cc:3389,
3580`). The conversion is written correctly. It is also never compiled here:
`dwarf2codeview.cc` is entirely inside `#ifdef CODEVIEW_DEBUGGING_INFO` (line
39), which neither x86_64-linux nor aarch64-linux defines.

    dwarf2codeview.o   936 bytes,   0 defined symbols
    varasm.o (control)          490 defined symbols

Zero symbols against a control that has 490 is the difference between "compiled
and clean" and "not compiled at all". Nothing about this conversion has been
exercised by any build on this branch that I can see.

**`HAVE_GAS_LCOMM_WITH_ALIGNMENT` -> `ASM_OUTPUT_ALIGNED_LOCAL_P`.** The runtime
read lives in `config/i386/bsd.h:76`
(`#define ASM_OUTPUT_ALIGNED_LOCAL_P (targ_caps.gas_lcomm_with_alignment)`) and
`varasm.cc:2367` / `:3008` consult it. But `i386/bsd.h` is referenced only from
`config.gcc` and is **not in either built `tm.h` chain**. In the preprocessed
non-primary TU, `gas_lcomm_with_alignment` occurs exactly **once**, and it is
the struct member declaration at `target-caps.h:254`, **not a use**. So in this
build `ASM_OUTPUT_ALIGNED_LOCAL_P` is `defaults.h:1592`'s constant `true`,
`if (ASM_OUTPUT_ALIGNED_LOCAL_P)` constant-folds, and the `ASM_OUTPUT_LOCAL`
fallback arm at `varasm.cc:2373` is unreachable.

Both need an i386-BSD-family target (for the `.lcomm` arm) and a
CodeView-enabled target such as a mingw/PE configuration (for `.cv_ucomp`)
before anything can be scored. Verifying them "in the artefact" is not possible
in the artefact that exists.

---

## 4. The `targetm_asm_ops` lesson applied generally — is the *selection* invoked?

`scratchpad/select-arm.sh` runs green at this commit, with both of its controls
behaving (positive `internal_error` found; negative `warning_at` absent):

    multi-target-select.o: 81 undefined symbols
    target_asm_ops_for:       PASS
    target_addr_for:          PASS
    target_cdata_refresh_for: PASS

### Is its coverage complete?

**For the family it was built for, yes.** A tree-wide grep finds exactly three
`*_for` selector lookups (`target-asm-ops-select.cc:51`,
`target-addr-select.cc:55`, `target-cdata-select.cc:56`), and
`multi-target-select.cc:428/434/448` are the only three assignment sites. The
arm names all three. Nothing in that family is unwatched.

**For the question the brief actually asks — "does the selection happen?" — no.**
Named gaps, in descending order of how much they bite:

1. **The emit family has no selector to check, and this is where the live bug
   is.** `::gen_blockage`, `::add_clobbers`, `::added_clobbers_hard_reg_p`,
   `insn_data` are bound to the singular primary objects with no `*_for` lookup
   in existence. `select-arm.sh` structurally cannot see them: it only asks
   whether a *named selector* is referenced, and for these there is no selector
   to name. Item 2 above was found by `nm` on `cc1`, not by this arm.
2. **It proves a relocation exists, not that the assignment is reached.** A
   reference in `multi-target-select.o` shows the call survived compilation.
   It says nothing about whether `mt_select_target` runs, whether the loop
   at `:392` matches, or whether the returned pointer is the *right* base's.
   The `NULL` checks at `:429/435/449` are the runtime guard, and no arm
   asserts they are exercised.
3. **It never checks the DATA half against the SELECTION half.** The brief's
   instruction to ask those two questions separately is not implemented: the
   arm reads only the pointer side. `insn-constants.h` is the counterexample
   that matters — the data is genuinely per-base
   (`insn-constants-{i386,aarch64}.h` both exist and differ), and the singular
   header is still the primary's, and no arm compares them. That single
   mismatch is what makes item 2 a wrong answer rather than a cosmetic one.
4. **`b->install_tables ()` (`:395`) is unwatched.** That is the *other*
   selection path — the one that swaps `targetm` itself — and it is a call
   through a struct member, so a mis-populated `mt_backends` entry would not
   change any relocation the arm inspects.
5. **No assertion that the build dir is multi-target.** It defaults to
   `/tmp/b-objs` and would pass identically against a single-target build
   that happened to contain a `multi-target-select.o`. Cheap to add: assert
   more than one `mt-*/` object dir exists.

A useful next arm is not another symbol-presence check. It is a differential
one: build the same source for both bases and compare a value that the two
back ends number differently — `UNSPECV_BLOCKAGE` (1 vs 5) is a ready-made
probe, and it is already known to be wrong, so the arm can be shown to fail
before it is trusted.

---

## What my instruments cannot see

- **Anything about `rs6000`, `mips`, `avr` as non-primary.** Not configured in
  `/tmp/b-objs`. Task #49's re-verification is complete only for `aarch64`.
- **Anything inside `#ifdef CODEVIEW_DEBUGGING_INFO` or `i386/bsd.h`.** Not
  compiled; see item 3. Same class as the `TARGET_XCOFF` narrowing.
- **COMDAT inlines with per-back-end bodies.** My `nm` sweeps filtered on
  defined symbols, which the brief correctly notes structurally hides these.
  A clean sweep above is not evidence of absence for that class.
- **Collision *sizes*.** I deliberately never sized a set from the link.
  `libbackend.a` is present in the build and would hide members exactly as the
  archive that hid 33 of 40 did. All per-object claims above come from `nm` on
  named `.o` files reached by `find`, not from link behaviour.
- **Runtime behaviour.** Everything here is static: symbols, relocations,
  disassembly, preprocessed text. I did not run `cc1` under
  `-ftarget-config=aarch64...` and observe a miscompile. The
  `UNSPECV_BLOCKAGE` 1-vs-5 conclusion is a strong static inference, not an
  observed ICE — worth closing with a runtime repro before it is written up
  as fact.
- **Concurrency.** Four agents edited the tree during the run. HEAD never
  moved (`f0148c7520d` at start and end), but the working tree gained
  modifications to `gcc/defaults.h`, `gcc/target-cdata*.{cc,h}`,
  `gcc/gen-multi-target-md.awk`, `gcc/check-target-caps.sh` and others.
  I re-checked every source line I quoted after the fact: `defaults.h:1576`,
  `defaults.h:1592` and `i386/bsd.h:76` are unchanged at the same line
  numbers. The **built objects** in `/tmp/b-objs` predate some of those edits,
  so items 1-3 describe the tree as of `f0148c7520d`'s committed state plus a
  build from Aug 11-12; a rebuild could move the `target-cdata` findings in
  particular.
