# T163 — converting `HAVE_AS_TLS` to a runtime capability

Measured census: `scratchpad/t163-census.sh` (run it; do not quote from here).
At `846a695c863` it reads **118 non-ChangeLog sites over 19 back ends**.

## Two corrections to the brief, both measured

**1. It is NOT "still 1 from the BUILD HOST's assembler".** The probe is gone.
`gcc/configure.ac:2594` is an unconditional

    AC_DEFINE(HAVE_AS_TLS, 1, [...])

so it is a hardcoded 1 for every back end, independent of the build host's
assembler. Nothing probes it. The defect is therefore not a host leak, it is
that **the answer cannot be varied per target at all** — a compiler serving a
target whose assembler lacks TLS has no channel to say so, because
`targ_caps` has no field for it.

**2. Seven back ends carry a floor that is DEAD, and it reads as live.**
`rs6000.h:245`, `mips.h:3252`, `sparc.h:1622`, `alpha.h:159`, `frv.h:235`,
`xtensa.h:62`, `loongarch-opts.h:153` all say

    #ifndef HAVE_AS_TLS
    #define HAVE_AS_TLS 0

`auto-host.h` has already defined it, so **not one of these fires**. They read
as "this back end defaults TLS off" and do nothing. (The related `options.h`
ordering bug that made six back ends silently adopt loongarch's floor of 0 is
described at `opth-gen.awk:768` and was already fixed by the undef block
there. That is a *different* defect from this one; do not conflate them.)

The two `lynx.h` overrides (`i386/lynx.h:67`, `rs6000/lynx.h:88`) DO fire,
because they come after `auto-host.h`. They are per-CONFIGURATION, not per
back end — the `vms_debug` shape — which is what confirms this belongs in
`targ_caps` and not in `targetm`.

## The four shapes, and what each costs

| shape | sites | back ends | cost |
|---|---|---|---|
| `MD-COND` (insn condition) | 55 | 6 (rs6000 27, alpha 15, mips 5, frv 4, xtensa 3, loongarch 1) | see below |
| `PP-EXIST` (`#ifdef`/`#if defined`) | 33 | 17 | restructure per site |
| `C-VALUE` / `C-VALUE(define)` | 23 | many | **free** — value position |
| `PP-VALUE` (`#if HAVE_AS_TLS`) | 3 | rs6000, frv | restructure |
| `PP-OTHER` (`#undef`/`#endif`) | 4 | — | follows its block |

### `MD-COND` is NOT the blocker the configure.ac comment says it is

`gcc/configure.ac:2630` justifies the exclusion with "read from
`#if defined(...)` in generated .md TUs ... where `targ_caps` is not in
scope, so they stay build-time constants". Half right, and the wrong half is
load-bearing.

`genconditions.cc:179-183` emits, for every condition:

    __builtin_constant_p (<expr>) ? (int) (<expr>) : -1

A **non-constant** condition is legal and yields `-1`, meaning "evaluate at
run time". So a runtime value in an insn condition is expressible — and these
conditions are *already* non-constant (`"HAVE_AS_TLS && TARGET_ELF"`).
Folding is not the obstacle.

The real obstacle is narrower and is about **one generator, not the .md TUs**:
`build/gencondmd.o` is compiled with `-DGENERATOR_FILE` (`Makefile.in:1077`),
and `defaults.h:33` guards `#include "target-caps.h"` out for generators. So
`targ_caps.as_tls` would fail to compile *in gencondmd.cc*. The final
`insn-*.cc` TUs are fine — they are not generators and `targ_caps` is in
scope there through `tm.h` → `defaults.h`.

Fix shape: give `gencondmd.cc` a declaration (not the definition) so the
expression compiles and is non-constant. `__builtin_constant_p` then folds
the ternary to `-1` in a static initializer, so no reference is emitted and
gencondmd need not link `target-caps.o`. **Verify that by building, not by
reasoning** — if the fold does not happen, gencondmd fails to link with an
undefined `targ_caps`, which is a loud and acceptable failure mode.

### `PP-EXIST` is the real work, and 20 of its 33 sites are one pattern

The dominant sub-shape (20 sites, 14 back ends) is

    #ifdef HAVE_AS_TLS
    #define TARGET_HAVE_TLS true          /* or ... HAVE_AS_TLS */
    #endif

i.e. it gates a **target hook** in a static initializer table. A static
initializer cannot read `targ_caps` — the same wall `target-caps.h` already
documents for the mips `Init (...)` case.

**There is a landed precedent for exactly this, and it should be reused
rather than re-invented.** `defaults.h:307`:

    #define TARGET_SUPPORTS_WEAK (SUPPORTS_WEAK && targ_caps.gas_weak)

Two different questions, conjoined at the consumer: *does the target have a
spelling for this* (the back end's static answer) and *does this assembler
accept it* (the probed answer). `HAVE_AS_TLS` has the same two halves. So:

- define `TARGET_HAVE_TLS` **unconditionally** to the back end's own answer
  (`true` for the 14 that gate it on the macro today);
- add `bool as_tls` to `struct target_caps`, defaulting **true** (a modern
  GNU assembler has TLS; the optimistic-default group);
- conjoin at the consumers of `targetm.have_tls`.

That converts the 20 without touching a static initializer, and it separates
the two questions that upstream conflated because both read one constant.

The residue is small and genuinely per-site: 2 `DEFINES-MACRO`
(`defaults.h:127` `ASM_OUTPUT_TLS_COMMON`, `rs6000/xcoff.h:226`), 4
`GATES-CODE` in rs6000.cc (trivial — become runtime `if`s), and 2
`GATES-DECL` (`rs6000.cc:22331`, `aarch64.cc:1568`) where the guard hides a
whole `static` function definition. The `GATES-DECL` pair must define the
function unconditionally and branch at the registration site, or the hook
table names a function that does not exist — the "guard hiding a
*declaration*" row of PRINCIPLES section 3.

`defaults.h:127` additionally carries the **#49 hazard**: `mkconfig.sh`
appends `defaults.h` LAST, so any redirect placed there is invisible to every
back-end header read earlier in the chain — which is all seven dead floors
and both `lynx.h` overrides. "Was it converted?" and "is it converted by the
time it is read?" are different questions. Whatever lands must be checked by
preprocessing each base's real `tm-<base>.h`, not by grepping sources.

## `HAVE_AS_DTPREL_RELOC` travels with it

`configure.ac:2630` excludes the two together and `aarch64.cc:1568`/`:34263`
test them jointly. Anything done here should do both or explicitly say why
not.
