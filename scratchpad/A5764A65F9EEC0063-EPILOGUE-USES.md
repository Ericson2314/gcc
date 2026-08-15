# `EPILOGUE_USES` was i386's — the SME2 ACLE residual, and it deleted code

Fixed in `9a15499d33c`.

## The measurement that found it, and why the FAIL column could not

The brief's first instruction was to check whether `sme2/acle-asm`'s 9,050
FAILs are compile failures or `scan-assembler` mismatches, "because those are
entirely different investigations and the FAIL column does not distinguish
them." That check is the whole task:

```
=== sme2/acle-asm : PASS 28544  FAIL 9050  UNRESOLVED 0
      BODIES     8926        <- check-function-bodies: compiled, emitted wrong code
      COMPILE     124
```

**Zero UNRESOLVED, 8,926 of 9,050 `check-function-bodies`.** The compiler was
not failing. It was compiling, exiting 0, writing an empty stderr, and emitting
a well-formed `.s` that a real `aarch64-unknown-linux-gnu-as` accepts — with
every function body missing:

```
                              stock                     multi-target
add_write_0_z0_z0:      mov  w8, 0                      (nothing)
                        add  za.s[w8, 0, vgx2], ...     (nothing)
                        ret                             ret
```

`scratchpad/a5764a65f9eec0063-kinds.sh` is the classifier; it refuses a `.sum`
with no `PASS` lines, so a zero cannot come from an unread file.

## The cause

`df-scan.cc:3647` is the ONLY shared consumer of `EPILOGUE_USES`:

```c
df_epilogue_uses_p (regno)
  = EPILOGUE_USES (regno) || TEST_HARD_REG_BIT (crtl->must_be_zero_on_return, regno)
```

and it feeds `df_get_exit_block_use_set` — the hard registers considered live
on return. `defaults.h:1335`'s `#ifndef EPILOGUE_USES` is **dead**, because
`i386.h:1767` defines the name first. This is the `REGMODE_NATURAL_SIZE` trap
PRINCIPLES already records, in a new place.

Confirmed on the linked object rather than inferred:

```
$ nm -uC df-scan.o | grep -i epilogue_uses
                 U ix86_epilogue_uses(int)
```

and that is the **only** i386 symbol in `df-scan.o`.

**25 of 47 back ends define `EPILOGUE_USES`** (aarch64 alpha arc arm avr
epiphany frv ft32 i386 ia64 loongarch m68k mips mmix moxie pru riscv s390 sh
sparc v850 visium xstormy16 xtensa, plus `alpha/vms.h`). All 25 were being
answered by i386's set.

## Why it deletes code rather than mis-compiling it

`aarch64_epilogue_uses` (`aarch64.cc:10639`) returns true for `LR_REGNUM` after
`epilogue_completed`, and for `LOWERING_REGNUM`, `SME_STATE_REGNUM`,
`TPIDR2_SETUP_REGNUM`, `ZA_SAVED_REGNUM`, `ZA_REGNUM`, `ZT0_REGNUM` under the
relevant ZA conditions. i386 names none of them, so they were simply absent
from the exit block's use set. Same test, same insn, both sides:

```
stock   ;; exit block uses  ... 87 [lowering] 89 [sme_state]
                                90 [tpidr2_setup] 92 [za_saved] 93 [za]
mt      ;; exit block uses  ... (none of the five)

mt cse1:  DCE: Deleting insn 8      <- add za.s[w8, 0, vgx2], {z0.s-z1.s}, ...
          DCE: Deleting insn 4/3/2  <- and then the operand set-up
```

The RTL-pass walk (`scratchpad/a5764a65f9eec0063-walk.sh`) locates it exactly:
identical through `expand`, `vregs`, `into_cfglayout`, `jump`, `subreg1`,
`dfinit`; diverges in `cse1`'s DCE and is gone by `fwprop1`.

**That walk carries a non-vacuity arm that matters.** Stock prints the unspec
symbolically (`UNSPEC_SME_ADD_WRITE`); multi-target prints it **numerically**
(`] 652)`), because the shared unspec-name table is the primary's. A sweep
matching only the symbolic spelling scores every multi-target dump as ABSENT
and "finds" a deletion in the first pass — a null result indistinguishable
from the answer. The script asserts both spellings are observed before
reporting anything.

This is the **leaked-ABSENCE** shape rather than a leaked value: nothing is
mis-set, the compiler emits LESS code, and there is no diagnostic anywhere.
No ICE count, error count, or assembler check could have found it.

## The fix

An `epilogue_uses` slot on `target_frame_desc`, alongside
`function_arg_regno_p`, with that family's four links:

| link | file |
|---|---|
| struct field | `gcc/target-frame.h` |
| per-base thunk + initialiser entry | `gcc/target-cumargs.cc` |
| `mt_epilogue_uses` accessor, via `mt_frame ()` | `gcc/target-cumargs-select.cc` |
| redirect for shared TUs | `gcc/multi-target-macros.h` |

No existence field is needed, unlike `has_incoming_return_addr_rtx`: the shared
consumer never `#ifdef`s the name, and `defaults.h`'s `false` is the
**supply-side** fallback PRINCIPLES permits — reached in that base's own
translation unit, and upstream's own answer for a back end standing alone, not
the primary's.

## THE OTHER TWO DIRECTORIES DO NOT SHARE THE CAUSE — MEASURED, NOT ASSUMED

The brief asked to establish this rather than assume it. Same classifier, same
`.sum`:

```
=== sme2/acle-asm : PASS 28544  FAIL 9050   BODIES 8926  COMPILE  124
=== sme/acle-asm  : PASS  3004  FAIL 1154   BODIES  962  COMPILE  104  OTHER  88
=== sve/acle      : PASS 77962  FAIL 4034   BODIES    0  COMPILE 2016  OTHER 2018
=== sve2/acle     : PASS 58463  FAIL 1032   BODIES    0  COMPILE  558  OTHER  474
```

**`sve/acle` and `sve2/acle` have ZERO `check-function-bodies` failures.** They
are compile failures and are a different investigation. `aarch64_epilogue_uses`
touches only LR and the ZA/SME state registers, so there was never a mechanism
by which it could reach plain SVE — the numbers and the mechanism agree.

`sme/acle-asm`'s 962 BODIES are the same ZA shape and are expected to move with
this fix.

**Lead for the SVE pair, not chased:** the top diagnostics in the aarch64
`gcc.log` are `lane %wd out of range` — 2,078 positive plus 2,054 **negative**
lane values, ~4,132 total against `sve/acle`'s 4,034 residual. A *negative*
lane index means the operand value is wrong, not the bound, which points at the
endian lane-correction path rather than at `aarch64_simd_lane_bounds`
(`aarch64.cc:25510`) itself. That is a hypothesis with an arithmetic
coincidence behind it, not a diagnosis; it needs the same both-sided dump
treatment before anyone acts on it.

## BOTH-SIDED, AND riscv64 IS THE STRONGEST EVIDENCE IN THE TASK

`scratchpad/a5764a65f9eec0063-bothsided.sh`, `-O2 scratchpad/big.c`, baseline
build vs fixed build, every configured target:

```
x86_64-pc-linux-gnu          IDENTICAL   md5 378fc33c1e70
aarch64-unknown-linux-gnu    IDENTICAL   md5 2f0385292971
riscv64-unknown-linux-gnu    CHANGED     fc79f4e1abad -> 564e39d275c8  (1 line)
s390x-ibm-linux-gnu          rc=1 on BOTH sides (pre-existing, see below)
```

**x86_64 byte-identical and equal to the recorded bar** — required, because
i386 was already reading its own macro, so any movement there would mean the
redirect had broken the supply side.

**aarch64 identical on `big.c` is the correct result, not a null one.**
`aarch64_epilogue_uses` fires only for LR after `epilogue_completed` and for
the ZA/SME state registers; `big.c` contains no SME code and no sibcall, so
there is nothing for it to change. The aarch64 evidence is the SME2 reproducer
and the directory score, not this file.

**riscv64's one line is a latent wrong-code bug this fix removes**, and it is
ordinary code with no SME anywhere near it:

```
  f_builtin:
        addi  sp,sp,-16
        sd    ra,8(sp)         <- saves the return address
        ...   call memcpy / memset / strchr
+       ld    ra,8(sp)         <- ADDED BY THE FIX
        ld    s0,0(sp)
        addi  sp,sp,16
        tail  sink             <- SIBLING CALL
```

`riscv_epilogue_uses` (`riscv.cc:10852`) returns true for `RETURN_ADDR_REGNUM`
unconditionally; `aarch64.h:677`'s comment states the purpose outright —
registers "considered live for sibcalls; `EPILOGUE_USES` helps achieve that".
With i386 answering, `ra` was not live at exit, so the restore was dead and
DCE removed it. The function then tail-called `sink` with `ra` still holding
the return address of `strchr`, so `sink`'s `ret` would have jumped back into
the middle of `f_builtin`. Silent, at `-O2`, on a target that is not the one I
was sent to fix.

This is the both-sided arm doing what PRINCIPLES asks of it: showing target A
gets A's answer proves nothing unless another target still gets its own — and
here a *third* target turned out to have been getting the primary's all along.

**s390x's `rc=1` is PRE-EXISTING and is NOT this change.** Both sides fail
identically: `internal compiler error: Segmentation fault` in `RTL pass:
expand` at `big.c:82`, `__builtin_va_start (ap, n)`. Byte-identical failure
before and after, so this fix neither causes nor cures it. Recorded because a
target that cannot compile the bar file at all is worth someone's attention,
and because an unexplained `rc=1` in a both-sided table otherwise reads as
damage from the change under test.

## A SECOND, DISTINCT DEFECT FOUND ON THE WAY — REAL, AND IT DOES NOT SCORE HERE

With the bodies restored, the remaining diff against stock is entirely
assembler directives, and they are i386's:

```
stock                            multi-target
  .align  2                        .p2align 3
  .variant_pcs add_write_0_z0_z0   (absent)
  .type   X, %function             .type X, @function
  .cfi_startproc / .cfi_endproc    (absent)
```

Measured on the linked objects:

```
final.o    U ix86_output_addr_vec_elt(_IO_FILE*, int)
           U ix86_output_addr_diff_elt(_IO_FILE*, int, int)
           U ix86_asm_output_function_label(_IO_FILE*, char const*, tree_node*)
varasm.o   U ix86_asm_output_labelref(_IO_FILE*, char const*, char const*)
           U ix86_asm_output_function_label(_IO_FILE*, char const*, tree_node*)
```

`defaults.h:182` (`ASM_OUTPUT_FUNCTION_LABEL`) and `:198`
(`ASM_OUTPUT_LABELREF`) are two more dead `#ifndef`s that `i386.h:2276` /
`:2308` override; `ASM_OUTPUT_ADDR_VEC_ELT` / `ASM_OUTPUT_ADDR_DIFF_ELT` are
`i386.h:2231` / `:2236`, and jump-table entries are emitted with i386's format
for every target. `.variant_pcs` is missing because `aarch64.h:855`'s
`ASM_DECLARE_FUNCTION_NAME` is not the one a shared TU sees.

**It costs zero `check-function-bodies` results, and that is a fact about the
harness, not about the defect's severity.** `scanasm.exp:964` sets
`fluff` to `^\s*(?:\.|//|@|$|#)`, so every `.`-prefixed line is discarded
before the body is compared. The bodies these tests check are instruction
lines only. So this family is invisible to the directory that led me to it and
must be sized against `scan-assembler` tests and against object correctness
(`%function` vs `@function` is an ELF symbol-type difference; a missing
`.variant_pcs` is an ABI marker a linker consumes). **Stated here rather than
folded into the score, because a defect that cannot move the number I was sent
to move is exactly the kind that gets lost.**
