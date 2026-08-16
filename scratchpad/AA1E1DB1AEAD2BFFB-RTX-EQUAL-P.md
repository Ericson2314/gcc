# `rtx_equal_p` said two different `const_poly_int`s were equal — the `sve/acle` residual

Task #209. Fixed in `06179fbe3df`.

## THE BRIEF'S LEAD WAS A RED HERRING, AND IT IS WORTH SAYING WHY

The brief's lead was `lane %wd out of range`: ~4,132 hits in the aarch64
`gcc.log` against a 4,034 residual in `sve/acle`, **2,054 of them naming a
negative lane**, read as "a computed value gone wrong".

It is not `sve/acle`'s. Measured, in the source, in one command:

```
$ grep -rl "lane -\?[0-9]* out of range" gcc/testsuite/ | sed 's|/[^/]*$||' \
    | sort | uniq -c | sort -rn
    173 gcc/testsuite/gcc.target/aarch64/advsimd-intrinsics
     50 gcc/testsuite/gcc.target/aarch64/simd
      9 gcc/testsuite/gcc.target/arm/simd
```

**Zero in `sve/acle`.** Every one of those 232 files spells the message in a
`dg-error`, i.e. the diagnostic is the test's own EXPECTED output, emitted on
runs that PASS, and each file runs at several option variants. The balance the
brief noticed — 2,078 positive against 2,054 negative — is the signature of
`*_indices_1.c`, which passes one too-small and one too-large index per
intrinsic. The compiler is right; the counting instrument was `grep` on a log
that contains expected errors as well as unexpected ones.

Generalise: **a diagnostic string in `gcc.log` is not a failure.** A count over
the log cannot distinguish "the compiler said this and the test wanted it" from
"the compiler said this and the test did not". Only the `.sum` can, and the
`.sum` is per-directory. The ~4,132-against-4,034 match was an arithmetic
coincidence — which the writeup that raised it had itself labelled
"a hypothesis with an arithmetic coincidence behind it, not a diagnosis".

## WHAT `sve/acle` ACTUALLY IS, AND IT IS THE SAME BUG AS `sme/acle-asm`

The brief asked whether `sme/acle-asm`'s single ICE shares a cause with
`sve/acle`. It does — and the cheapest possible measurement said so before any
theory did. `aarch64-sve-acle.exp` (the `general/` + `general-c/` half) scores
**PASS 6062 / FAIL 10**, and all ten lines are ICEs or their companions:

```
FAIL: .../sve/acle/general/deref_2.c   (internal compiler error: in final_scan_insn_1, at final.cc:2846)
FAIL: .../sve/acle/general/struct_1.c  (internal compiler error: in final_scan_insn_1, at final.cc:2846)
FAIL: .../sve/acle/general/nosve_4.c   (internal compiler error: Segmentation fault)
FAIL: .../sve/acle/general/nosve_5.c   (internal compiler error: Segmentation fault)
```

`final.cc:2846` is `fatal_insn ("could not split insn", insn)` — the exact site
the brief attributes to `sme/acle-asm` alone.

**And `-O0 -g` was never the condition.** The brief records the `sme` ICE as
"`-O0 -g` only". Measured on the same file, same compiler:

```
-O0 -g   could-not-split: 1
-O0      could-not-split: 1     <- the -g arm is not the variable
-O1      could-not-split: 0
-Og -g   could-not-split: 0
```

`-g` appeared to matter only because `aarch64-sme-acle-asm.exp`'s torture list
has exactly one unoptimised entry and it is spelled `-std=c90 -O0 -g`.
`deref_2.c` then shows it is not even about `-O0`: that test carries
`dg-options "-O2"` and ICEs at `-O2`.

## THE CAUSE, MEASURED IN THE RUNNING `cc1`

`rtl.cc:31` carries this comment, added by an earlier task:

> Only the generator half needs `tm.h`. A generator is a single-target program
> compiled against its base's `tm-<base>.h`, and `hard-reg-set.h` takes its
> register widths from the raw `tm.h` names under `GENERATOR_FILE`; shared code
> takes `multi-target-reg-widths.h`.

True about `hard-reg-set.h`. `rtl.h` **also** keys three macros on a `tm.h`
name:

```c
#if TARGET_SUPPORTS_WIDE_INT
#define CASE_CONST_UNIQUE   case CONST_INT: case CONST_WIDE_INT: \
                            case CONST_POLY_INT: case CONST_DOUBLE: case CONST_FIXED
#else
#define CASE_CONST_UNIQUE   case CONST_INT: case CONST_DOUBLE: case CONST_FIXED
#endif
```

`TARGET_SUPPORTS_WIDE_INT` is defined by 12 of 47 back ends and given `0` by
`defaults.h:1389` for the rest; it reaches a TU only through `tm.h`. In
`rtl.cc` it is **undefined**, and `#if` on an undefined name is silently
FALSE — PRINCIPLES §4's named trap, with no diagnostic. So `CASE_CONST_UNIQUE`
there omits `CONST_POLY_INT`, `rtx_equal_p` falls through to the generic
operand loop, and `CONST_POLY_INT`'s rtl format is the **empty string**
(`rtl.def:352`), so no operands are compared:

```
(gdb) call debug_rtx (c1)      (const_poly_int:DI [8, 8])     c1 = 0x7ffff78e9e38
(gdb) call debug_rtx (c2)      (const_poly_int:DI [48, 8])    c2 = 0x7ffff792f2f8
(gdb) p (int) rtx_equal_p (c1, c2, 0)
$1 = 1
```

Different pointers, same code (118), same mode, **equal**.

`try_split`'s infinite-loop guard (`emit-rtl.cc:4009`) compares each insn of
the split sequence against the original pattern. aarch64's
`*add<mode>3_poly_1` splits `(plus src [48, 8])` into `(plus src [8, 8])` plus
`(plus dest 40)`; the first of those now "equals" the original, so the guard
returns `trial` and the whole split is discarded:

```
trial   (set (reg:DI x0) (plus:DI (reg/f:DI 31 sp) (const_poly_int:DI [48, 8])))
seq[0]  (set (reg:DI x0) (plus:DI (reg/f:DI 31 sp) (const_poly_int:DI [8, 8])))
seq[1]  (set (reg:DI x0) (plus:DI (reg:DI 0 x0)   (const_int 40)))

rtx_equal_p (PATTERN (seq[0]), pat) = 1     <- the guard
rtx_equal_p (PATTERN (seq[1]), pat) = 0     <- non-vacuity: it can say 0
```

The insn then reaches `final` with a `"#"` template and ICEs.

**Everything that looked like the obvious suspect was eliminated first, by
measurement, and each elimination is a result:**

| suspect | how it was refuted |
|---|---|
| the wrong base's `split_insns` | the backtrace names `insn_aarch64::gen_split_12` |
| `split5` never runs (its gate reads `targetm.stack_regs ()`) | `.395r.split5` dump exists, i.e. the pass ran |
| `epilogue_completed` is 0 | read in the running `cc1` at the failure: `1` |
| the split predicate is wrong | `aarch64_add_offset_temporaries` returns `1` on all three calls inside `split5` |
| `reg_overlap_mentioned_p` (a `hard_regno_nregs` leak) | the split BODY runs — `aarch64_split_add_offset` is called — so the whole condition was true |
| the split emits nothing | the sequence was printed and is CORRECT |

The last row is the turn: the split ran, produced right code, and the code was
thrown away by a *shared* consumer. **A leak can be downstream of the thing it
breaks.**

## THE POPULATION — eleven shared objects, and they are the wrong eleven

Measured from the 47-base build's own `.deps`, not from `git grep`:

```
objects that include rtl.h AND read tm.h   260     (value 1, from i386.h:3110)
objects that include rtl.h and do NOT      11 hand-written:
  rtl  print-rtl  rtlhash  read-rtl  real  rtl-error  lists
  rtx-vector-builder  print-tree  function-tests  gcc-rich-location
```

Comparing (`rtl.cc`), hashing (`rtlhash.cc`) and dumping (`print-rtl.cc`) of
`rtx` are all in the eleven. `rtx_equal_p` alone has ~1,591 mentions across
`gcc/`, so the blast radius is far wider than the directory this task was set
from; `sve/acle` is where it happened to be loud.

## THE FIX

`rtl.h` supplies the answer for non-generator TUs, before the `#if`:

```c
#if !defined (GENERATOR_FILE) && !defined (TARGET_SUPPORTS_WIDE_INT)
#define TARGET_SUPPORTS_WIDE_INT 1
#endif
```

**PRINCIPLES §2a's test, stated rather than assumed.** The banned shape is a
floor that hands *the primary's* answer to a base that never spoke. This is
not that: the `CASE_CONST_*` families describe the **shared** rtx vocabulary —
every back end in the binary allocates, compares and hashes the same `rtx`
objects — so the question has no per-base answer, and the value chosen is the
one 260 of those 271 shared objects already compute. It cannot reach a per-base
TU, where `tm.h` has already answered.

**RESIDUAL, stated so it is not later read as closed:** 35 back ends define
nothing and get `defaults.h`'s `0`, so a per-base TU of one of those 35 still
spells `CASE_CONST_ANY` one way while shared code spells it another. That is a
live divergence of the same class, untouched here. Converting
`TARGET_SUPPORTS_WIDE_INT` to a union setting is the real fix and is a separate
task.

`rtl.cc` gets a tripwire that refuses to build if the macro is ever 0 or
undefined there again. The comment that authorised the removal read as evidence
the removal was safe; a check that fails by name is the only thing that makes
this class loud.

## THE SCORE — two 47-base builds of the same tree, same harness, same assembler

Both sides `.rc`-stamped, GUARD 3c reporting `assembler is
aarch64-unknown-linux-gnu's own, and it produces: AArch64` on **all six** runs,
`mt-specsread` PASSES (4 arms) on all six. **KILLED 0 on every run, never
subtracted.** Load 13.9–21.9 at scoring, under the ~25 provisional threshold.
Scored from the preserved `.sum` files, never from the `=== gcc Summary`
marker.

```
                                       BASELINE        FIXED         STOCK
                                       06179fbe3df^    06179fbe3df   (SC-BOARD)
aarch64-sve-acle.exp                    6062 /   10    6064 /   6
aarch64-sve-acle-asm.exp               71900 / 4024   73912 /   0
  gcc.target/aarch64/sve/acle TOTAL    77962 / 4034   79976 /   6   79980 / 0
gcc.target/aarch64/sme/acle-asm         3982 /  176    4070 /   0    4070 / 0
```

**`sme/acle-asm` is at exact parity with stock, 4070 / 0.**
**`sve/acle` goes 4,034 -> 6.**

**The baseline reproduces the brief's board exactly** — `sve/acle` 77962/4034
and `sme/acle-asm` 3982/176 — which is what makes these two builds comparable
to the board the task was set from.

**The FAIL columns were homogeneous, and that is checkable rather than
assumed.** Of the baseline's 4,024 `sve/acle` asm failures, **2,012 are
`final.cc:2846` and 2,012 are their `(test for excess errors)` companions, and
there is nothing else** — the residue after removing those two shapes is 0. All
176 of `sme/acle-asm` are the same two shapes, 88 and 88.

## THE RESIDUAL 6, AND IT IS A DIFFERENT DEFECT

`sve/acle/general/nosve_4.c` and `nosve_5.c`, three lines each. Identical on
**both** builds, so not this change:

```
nosve_4.c:4:1: error: this operation requires the SVE ISA extension
nosve_4.c:4:1: internal compiler error: Segmentation fault
```

The test expects that error at **line 6**, not line 4 (hence the separate
`(test for errors, line 6)` line), and the compiler then segfaults. Undiagnosed
here and left for a separate task.

## BARS

```
make all-gcc, 47 bases, cold, from an immutable snapshot 06179fbe3df, anchor 52
  rc=0   error: lines 0   multiple definition 0   undefined reference 0
  Killed/signal 9 0    cc1 links (230,912,200 bytes)

cc1 -quiet -nostdinc -O2 -ftarget-config=<cfg> big.c -o x.s
  x86_64   12369 bytes  md5 378fc33c1e70   == the recorded bar, byte for byte
mt-bars.sh -g arm            rc=0, real .debug sections
  build dir /tmp/b-aa1e1db1aead2bffb-fix   md5 77aefc9e374a  (PATH-SENSITIVE)
specs-config  wc -l 232  grep -c . 224
  x86_64  cfbc7a65e54e     aarch64  575aff0c188b
  riscv64 9af7409ac460     s390x    37901805bf3c
```

The `-g` md5 moved (`77a61e9c1c11` -> `77aefc9e374a`) and it is the build-dir
path, not the compiler. `a5764a65f9eec0063-gcheck.sh` compiles ONE constant
absolute path with both compilers, and **the entire diff is `DW_AT_producer`**:

```
< .string "... -ftarget-config=/tmp/b-aa1e1db1aead2bffb/lib/.../specs-config"
> .string "... -ftarget-config=/tmp/b-aa1e1db1aead2bffb-fix/lib/.../specs-config"
```

plus the `.LASF` reordering the four extra characters cause.

## BOTH-SIDED — `-O2 scratchpad/big.c`, every configured target

```
x86_64-pc-linux-gnu          IDENTICAL   md5 378fc33c1e70
aarch64-unknown-linux-gnu    IDENTICAL   md5 3997823179af
riscv64-unknown-linux-gnu    IDENTICAL   md5 564e39d275c8
s390x-ibm-linux-gnu          rc=1 on BOTH sides (pre-existing)
```

**x86_64 byte-identical is required** and is the point of the arm: `i386.h`
already defined the macro, so any movement there would mean the new definition
had reached a TU that was already answered.

**All four IDENTICAL is the correct null here, not a weak result, and saying so
matters.** `big.c` contains no SVE and therefore no `const_poly_int`, so there
is nothing in it for a `CONST_POLY_INT` comparison to change. The arm that CAN
move is the reproducer, and it does:

```
                          baseline           fixed
deref_2.c   -O2           ICE                rc=0, 5 addpl/addvl
struct_1.c  (default)     ICE                rc=0
ld1_hor_vnum_za128.c -O0  ICE                rc=0
```

and the fixed aarch64 output assembles with the real cross assembler into an
`ELF64 / AArch64` object. s390x's `rc=1` is the pre-existing
`big.c:82 __builtin_va_start` segfault the `EPILOGUE_USES` writeup already
records, byte-identical before and after.

## NON-VACUITY OF THE INSTRUMENT

The probe that found it (`#if TARGET_SUPPORTS_WIDE_INT` / `#error` appended to
each file's real include prefix, compiled with that object's real command line)
reports **both** values on the same run:

```
rtl.cc           MTWI_IS_ZERO      <- the defect
emit-rtl.cc      MTWI_IS_ONE
recog.cc         MTWI_IS_ONE
cse.cc           MTWI_IS_ONE
simplify-rtx.cc  MTWI_IS_ONE
varasm.cc        MTWI_IS_ONE
```

A first version of the same probe reconstructed the include prefix with `awk`
and truncated it, and reported `MTWI_IS_ONE` for **all** files — a clean green
produced by a truncated input. It was caught because it disagreed with the
running compiler, not because it looked wrong.

On the fixed tree the same probe reports, with a **negative control** (a file
with no includes at all, which must read ZERO, so the probe is known able to
print both answers on that same run):

```
control          MTWI_IS_ZERO      <- the control
rtl              MTWI_IS_ONE
emit-rtl         MTWI_IS_ONE
print-rtl        MTWI_IS_ONE
rtlhash          MTWI_IS_ONE
real             MTWI_IS_ONE
```

The tripwire in `rtl.cc` carries its own control. Removing ONLY the three lines
`rtl.h` gained (verified: 3 lines removed) and compiling the real `rtl.cc`
against the shadowed header:

```
CONTROL (fix removed)  rc=1
  rtl.cc:48:2: error: #error "rtl.cc: TARGET_SUPPORTS_WIDE_INT is 0 or
  undefined here, so CASE_CONST_UNIQUE omits CONST_POLY_INT and rtx_equal_p
  compares two const_poly_ints by CONST_POLY_INT's EMPTY rtl format, i.e. equal."
UNMODIFIED             rc=0
```

The first attempt at that control ALSO reported `rc=0` — and it was wrong, not
reassuring: a quoted `#include "rtl.h"` searches the including file's own
directory first, so `-I/tmp/tw-aa1e` never shadowed anything. It only became a
control once `rtl.cc` itself was copied next to the modified header. Same shape
as everything else in this file: **a check that could not have fired reads
exactly like a check that passed.**
