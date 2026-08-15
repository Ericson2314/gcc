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

## THE SCORE — my own two builds, same harness, same assembler

Both runs `.rc`-stamped (`check-aarch64-unknown-linux-gnu.rc` = 0), scored
from `mtcheck.sh`'s own summary and never from the `=== gcc Summary` marker.
**KILLED 0 on every run, never subtracted.** Load 1.0–2.3 at scoring, well
under the ~25 provisional threshold, so these are not provisional.

```
gcc.target/aarch64/sme2/acle-asm            PASS     FAIL   BODIES  COMPILE
  baseline      d3477e3c898  (unfixed)     28544     9050     8926      124
  + EPILOGUE_USES              9a15499d33c 36850      744        0      744
  + ASM_DECLARE_FUNCTION_NAME  b2fc4c0b9f8 37594        0        0        0
  + ASM_DECLARE_COLD_...       e3cdfe218ab 37594        0        0        0
  stock (SC-BOARD)                         37594        0

gcc.target/aarch64/sme/acle-asm
  baseline      (prior board)               3004     1154      962   104 (+88 other)
  + EPILOGUE_USES                           3886      272        0   184 (+88 other)
  + ASM_DECLARE_FUNCTION_NAME               3982      176        0    88 (+88 other)
  + ASM_DECLARE_COLD_...       e3cdfe218ab  3982      176        0    88 (+88 other)
```

**The last row is a PREDICTION THAT WAS CHECKED.** `e3cdfe218ab`'s commit
message says the cold-partition conversion moves no number, because cold
partitioning needs `-freorder-blocks-and-partition` and profile data that the
ACLE suites do not use. Scored on its own 47-base build, both directories come
back byte-identical to the previous row. A conversion claimed to be neutral
and then measured neutral is worth more than an unmeasured one — and had it
moved, that would have meant the reasoning was wrong, not that the fix was
good.

**`sme2/acle-asm` is at 37,594 PASS / 0 FAIL — exact parity with stock, from
9,050 failures.** `.rc` stamp 0, 37,594 preserved result lines, KILLED 0, load
1.01 at scoring.

`sme/acle-asm` is 1,154 -> 176, KILLED 0, load 1.18. Its entire residual is
**one ICE**, and only at `-O0 -g`:

```
44  -std=c90 -O0 -g -DTEST_OVERLOADS (internal compiler error:
                                     in final_scan_insn_1, at final.cc:2844)
44  -std=c90 -O0 -g -DTEST_FULL      (same)
+88 "excess errors" companion lines for the same tests
```

`final.cc:2844` is `fatal_insn ("could not split insn", insn)` — an insn whose
template is `"#"` did not split. **`split_insns` IS correctly per-base
selected** (`multi-target-select.cc:805` dispatches through
`mt_in_force ("split_insns")`), so this is not the wrong-splitter-table shape
and I am not claiming a cause. That it appears only with `-g` puts it near the
CFI/unwind item below.

**The baseline reproduces the brief's figures exactly (28544/9050)**, which is
what makes my two builds comparable to the board the task was set from.

`sme2`: **9,050 -> 744**, and every one of the 8,926
`check-function-bodies` failures is gone. `sme`: **1,154 -> 272**, likewise
all 962 BODIES gone. The `OTHER` column in `sme` is unchanged at 88, i.e. this
fix neither helped nor hurt it.

The residual in both is COMPILE, and it is the `ASM_DECLARE_FUNCTION_NAME`
family below — a distinct defect that this fix made visible.

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

### I FIRST WROTE THAT THIS COSTS ZERO RESULTS. THAT WAS WRONG, AND THE WAY IT WAS WRONG IS THE USEFUL PART.

The reasoning was sound as far as it went: `scanasm.exp:964` sets `fluff` to
`^\s*(?:\.|//|@|$|#)`, so every `.`-prefixed line IS discarded before a body is
compared, and this family therefore costs zero **`check-function-bodies`**
results. I then wrote the stronger sentence — that it "costs zero results" —
which does not follow, and is false.

It costs **COMPILE** results, and it is the whole of the SME residual. Measured
after the `EPILOGUE_USES` fix, same test, same flags:

```
stock         .arch armv8-a+sme          (file level)
              .arch armv8-a+sme-i16i64   (per function, line 7)
multi-target  .arch armv8-a+sme          (file level only)
```

`aarch64_declare_function_name` emits the per-function `.arch` update that
`#pragma GCC target "+sme-i16i64"` needs.
`sme/aarch64-sme-acle-asm.exp:66` sets `dg-do-what-default` to **assemble**
when the assembler supports `sme-i16i64`, so those tests really are assembled,
and the assembler refuses instructions the compiler generated correctly:

```
Error: selected processor does not support `addha za0.d,p0/m,p1/m,z0.d'
```

**This defect was hidden BEHIND the `EPILOGUE_USES` one.** While the ZA
instructions were being deleted, the assembler never saw them, so this could
not surface — and fixing the first defect is what made the second one
scoreable. That is why the COMPILE column ROSE (sme: 104 -> 184; sme2: 124 ->
744) while the total FAIL column collapsed. A rising sub-count next to a
falling total is not necessarily a regression; here it is previously-hidden
work becoming visible, and the only way to tell the two apart was to read what
the errors actually said.

Fixed in `4620cbee33b`, by the `mt_init_expanders` move rather than a
redirect: `varasm.cc:2218`'s `#ifdef`/`#else` pair goes into the per-base
thunk, and the shared call site becomes one unconditional
`mt_declare_function_name`.

**A METHOD NOTE, BECAUSE I NEARLY BANKED A WRONG ANALYSIS.** My first attempt
to explain the rising COMPILE column grepped
`testsuite.<triple>/gcc/gcc.log` — while a *second* `mtcheck` run was
overwriting it. `mtcheck.sh` writes every run to the same
`gcc.sum`/`gcc.log` path, so launching the `sme` run destroyed the `sme2`
artefacts. The errors I read (`addha_za64.c`) were `sme/acle-asm`'s, not
`sme2`'s, and I attributed them to the wrong directory.

What saved it was that the numbers did not line up: `kinds.sh` had grepped the
literal string `sme2/acle-asm`, which a `sme/acle-asm` file cannot match, and
its totals equalled `mtcheck`'s own stamped `36850/744` exactly — so that
classification was provably of the right file while the log grep provably was
not. **The `.rc`-stamped total is what made one reading checkable and the
other not.** Copy the `.sum` and `.log` to a run-specific name immediately
after each `mtcheck` invocation; the stamp tells you a run finished, it does
not tell you the file still belongs to that run.

### The family, closed and not closed — measured on the linked objects

```
                                            before      after (e3cdfe218ab)
varasm.o  ix86_asm_output_function_label      yes            NO
final.o   ix86_asm_output_function_label      yes            NO
varasm.o  ix86_asm_output_labelref            yes            yes   (not addressed)
final.o   ix86_output_addr_vec_elt            yes            yes   (not addressed)
final.o   ix86_output_addr_diff_elt           yes            yes   (not addressed)
```

**The two I did not fix still being reported is the non-vacuity arm**: the
instrument can still say non-zero on the same run that says zero for the one I
did fix, so the zero is a result rather than a broken grep.

`final.o`'s copy was found by the symbol REFUSING to disappear after
`varasm.cc` was converted — `final.cc:2229`'s `ASM_DECLARE_COLD_FUNCTION_NAME`,
which `elfos.h:319` defines in terms of `ASM_OUTPUT_FUNCTION_LABEL`. That is
PRINCIPLES' "one symbol can have several macro paths": closing the path you
found does not close the symbol. Fixed in `e3cdfe218ab`, and it moves **no
number** — cold partitioning needs `-freorder-blocks-and-partition` and profile
data, which the ACLE suites do not use. Stated so its zero is not later read as
evidence the conversion was unneeded.

`ASM_OUTPUT_LABELREF` (`varasm.cc:2962`) and `ASM_OUTPUT_ADDR_{VEC,DIFF}_ELT`
(`final.cc:2566`/`:2575`, jump-table entries) have their own consumers and are
left for a separate task.

## A THIRD THING, FOUND WHILE TESTING THE COLD PATH, AND NOT DIAGNOSED

Trying to exercise the cold-partition conversion, both multi-target compilers
answered:

```
cc1: note: '-freorder-blocks-and-partition' does not support unwind info
     on this architecture
```

**The stock aarch64 cross does not emit that note**, on the same source with
the same flags. So multi-target silently turns the optimisation OFF for
aarch64 where upstream leaves it on.

It is the same thread as the missing `.cfi_startproc`/`.cfi_endproc`/`.LFB`
labels still visible in every ACLE diff above: multi-target aarch64 is
emitting no DWARF CFI at all. `opts.cc:456` is

```c
opts->x_flag_unwind_tables = targetm_common->unwind_tables_default;
```

and `opts.cc:1581` gates the partitioning on that same field plus
`except_unwind_info`. `targetm_common` IS properly per-base selected here —
`common/common-target-select.cc` builds a registry from `common-target.def` and
starts at a `targetm_common_none` that names itself — so this is **not** the
plain leak the rest of this document is about, and I am not claiming a
mechanism.

The candidate worth testing first is **ordering**: whether
`targetm_common_select` has run by the time `opts.cc:456` reads the field, or
whether that read gets `targetm_common_none`'s all-zero POD defaults.
`multi-target-select.cc:148-151` asserts the ordering is safe —

> "nothing reaches `targetm` before option decoding, and option decoding needs
> targetm_common, which toplev.cc installs immediately before this"

— which is a **written invariant with an observed counterexample**, i.e.
exactly the shape PRINCIPLES says to treat as an unrun test. Whoever picks this
up should read the field in the running `cc1` rather than reasoning from the
comment.

Cost: unknown and not sized here. But "no CFI on aarch64" means no working
unwinding, so it is unlikely to be cheap, and it is invisible to
`check-function-bodies` for the same `fluff`-regex reason as everything else in
this section.
