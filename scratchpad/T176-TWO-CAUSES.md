# #176 — the two remaining named aarch64 ICE causes

Both are the same disguise as `add_clobbers`, `gen_nop` and `UNSPECV_BLOCKAGE`
before them: **one name, several authorities, no diagnostic.** Neither is a
*new* mechanism; both are a macro whose value shared code took from whichever
back end compiled the shared translation unit.

Snapshot `a3e48ce067d` (this worktree's HEAD), anchor **49**, two bases
(i386 + aarch64), `git archive` extraction, chmod `a-w`.
`make all-gcc` rc=0, `error:` 0, `multiple definition` 0,
`undefined reference` 0.

---

## 1. `REGMODE_NATURAL_SIZE` — 509 ICEs `in gen_lowpart_general, rtlhooks.cc:57`

### What was wrong

`regs.h:30` is

```c
#ifndef REGMODE_NATURAL_SIZE
#define REGMODE_NATURAL_SIZE(MODE)	UNITS_PER_WORD
#endif
```

and **that `#ifndef` is never taken in a shared translation unit**, because
the primary's `i386.h:1112` has already defined the name as
`ix86_regmode_natural_size (MODE)`. So all eight shared consumers —
`emit-rtl.cc` ×2, `combine.cc` ×2, `rtlanal.cc`, `expmed.cc` ×2, `expr.cc`,
`cfgexpand.cc`, `ira-conflicts.cc`, `reginfo.cc` — asked i386 how much of a
register a mode occupies, for every target.

Four back ends define the macro: **i386, aarch64, riscv, sparc**. aarch64's
answer is `BYTES_PER_SVE_PRED` / `BYTES_PER_SVE_VECTOR` for variable-width SVE
modes and `UNITS_PER_WORD` otherwise; i386's is `UNITS_PER_WORD` for
everything that is not `P2HImode`/`P2QImode`. `gen_lowpart_common`
(`emit-rtl.cc:1649`) divides both mode sizes by that granularity and returns 0
when `mregs > xregs`; `gen_lowpart_general` (`rtlhooks.cc:57`) then asserts.

### The instrument note that matters

**This name was already on the converted list, and the entry was never true.**
`multi-target-macros.h`'s `MIN_UNITS_PER_WORD` closure block lists

```
       regs.h:31  REGMODE_NATURAL_SIZE          (UNITS_PER_WORD)
```

among the eleven names that inherit the `UNITS_PER_WORD` redirect by ordinary
macro expansion. That inheritance is real *only if regs.h's `#ifndef` fires*,
which it does for a back end that defines nothing and does not for the one
that mattered. PRINCIPLES §4: *a written invariant is not a checked one.* The
list line now says so rather than being deleted, so the next reader sees why
the obvious reading is wrong.

### Reproducer — two lines

```c
typedef long v2di __attribute__((vector_size (16)));
v2di foo (v2di a, v2di b) { return a * b; }
```

at `-O -march=armv8.2-a+sve`. `mul<mode>3` (`aarch64-sve.md:4312`) calls
`aarch64_ptrue_reg (VNx2BImode)`, whose body is
`gen_lowpart (mode, force_reg (VNx16BImode, ...))`.

```
BEFORE  /tmp/b-a7de5/gcc/xgcc (ed7feb54b99, pre-fix)
  aarch64  rc=1  internal compiler error: in gen_lowpart_general, at rtlhooks.cc:57
AFTER   /tmp/b-a0c9/gcc/xgcc (a3e48ce067d)
  aarch64  rc=0  ptrue p7.b, all / mul z0.d, p7/m, z0.d, z1.d / ret
  x86_64   rc=0  md5 1a1d3e213119 -- BYTE-IDENTICAL to the pre-fix compiler
```

---

## 2. `CASE_VECTOR_PC_RELATIVE` — 68 ICEs `in aarch64_output_casesi`

### What was wrong

i386 does not define the macro at all, so `defaults.h:1162`'s `#ifndef`
supplied **0** — to everyone. `aarch64.h:1496` says **1**. Three shared sites
read it: `stmt.cc:1202`, `expr.cc:14356`, `final.cc:2147`.

`stmt.cc:1202` is the one that bites: it chooses between

```c
gen_rtx_ADDR_DIFF_VEC (...)   /* CASE_VECTOR_PC_RELATIVE || pic */
gen_rtx_ADDR_VEC (...)        /* otherwise */
```

so aarch64 got an `ADDR_VEC`, and `aarch64_output_casesi` died on its first
line — `gcc_assert (GET_CODE (diff_vec) == ADDR_DIFF_VEC)`.

Note the shape: **the back end's own output function is the thing that
failed, and the back end was not wrong.** A search that starts at
`config/aarch64/aarch64.cc:14447` finds correct code; the authority that
answered the question is three files away in shared code.

### Reproducer

A 24-case `switch` calling an extern function, at `-O1` (a `switch` whose arms
are constant returns is turned into a decision tree and never builds a table
at all — the first attempt did that and passed, which is a reminder that "the
reproducer did not fire" is a statement about the reproducer).

```
BEFORE  aarch64  rc=1  internal compiler error: in aarch64_output_casesi
AFTER   aarch64  rc=0  adrp x1, .L4 / ldr w1, [x1,w0,uxtw #2] / adr x0, .Lrtx4
        x86_64   rc=0  jmp *.L4(,%rdi,8) / .quad .L27 ...  -- BYTE-IDENTICAL
```

**The discriminator is the RTL, not the assembly**, read out of
`-fdump-rtl-final`:

```
aarch64    ADDR_DIFF_VEC=1  ADDR_VEC=0
x86_64     ADDR_DIFF_VEC=0  ADDR_VEC=1
```

(the grep is anchored on `(addr_vec` — `addr_vec` is a substring of
`addr_diff_vec`, and an unanchored count scores the fixed case as broken.)

---

## 3. The shape of the fix

Both join `target_frame_desc`, the existing per-base function table: a thunk
in `target-cumargs.cc` spells the real macro, compiled once per base with that
base's own `tm.h`; `target-cumargs-select.cc` dispatches; `multi-target-macros.h`
points the shared spelling at the dispatcher.

**Functions and not `target-cdata` fields.** `CASE_VECTOR_PC_RELATIVE` is
option state on seven of the sixteen back ends that define it (`riscv_cmodel`,
`rs6000_relative_jumptables`, `flag_pic`, `TARGET_PID`,
`TARGET_MIPS16_SHORT_JUMP_TABLES`, `flag_pic || optimize_size`), so a value
cached at selection time would be frozen at whatever the command line said;
`REGMODE_NATURAL_SIZE` takes an argument, so there is no value to cache at all.

**`poly_uint64` and not `unsigned int`** for the second: aarch64's and riscv's
already return `poly_uint64` — an SVE vector's size is not constant — and every
shared site already stores the result in one. Narrowing would have put a
`.to_constant ()` exactly where SVE has none.

**`target-cumargs.cc` gains `#include "regs.h"`** rather than restating the
`UNITS_PER_WORD` fallback. This is the supply-side floor §2a permits — a base
that defines nothing gets upstream's own documented default *from upstream's
own header*, never another base's answer — and including the header rather
than copying it keeps one authority for the value.

**Swept for constant-expression contexts first.** The only
`#if CASE_VECTOR_PC_RELATIVE` in the tree is `m68k.md:5804`, a back end's own
translation unit, which keeps the real macro; `aarch64-early-ra.cc:2071` is
the same for `REGMODE_NATURAL_SIZE`. No `#if`, `#ifdef`, case label, array
bound or static initialiser in shared code names either.

---

## 4. Bars, all four reproduced exactly

```
                                              recorded (b2b5b42b128)   this build (a3e48ce067d)
cc1 -quiet -nostdinc -O2 -ftarget-config=<c> <snap>/scratchpad/big.c -o x.s
  x86_64                                      12369 / 378fc33c1e70     12369 / 378fc33c1e70
  aarch64                                     12196 / 9edf6aa6616c     12196 / 9edf6aa6616c
specs-config x86_64   wc -l 230  grep -c . 222  md5 a6c4c68bdf33        a6c4c68bdf33
specs-config aarch64  wc -l 230  grep -c . 222  md5 f1a5ab201d95        f1a5ab201d95
```

`big.c` exercises neither SVE nor a jump table, so identical output is the
expected result and is the regression control, not evidence of the fix.
The evidence of the fix is §1 and §2.

---

## 5. The suite delta

Both targets, `MT_COMPILE_ONLY=1`, `make -j8`, both `rc=0`, all four
`mtcheck.sh` guards green on both. Baseline is `T173-board.txt`
(`80bf400ae06`).

```
                           PASS     FAIL   XPASS   XFAIL   UNSUP    UNRES   ERROR
x86_64  T173 baseline    162165    16290       3    1556    4451    13361      32
x86_64  this run         162165    16290       3    1556    4451    13354      16
        delta                 0        0       0       0       0       -7     -16

aarch64 T173 baseline     83158   106277       6     816   11298   133718      32
aarch64 this run          93055    96910       3     845   11012   128852      16
        delta             +9897    -9367      -3     +29    -286    -4866     -16
```

**x86_64 is unchanged in the five result columns — but NOT in all seven, and
saying so matters.** `ERROR` fell 32 → 16 on **both** targets by the same
amount, and `UNRES` moved −7 on x86_64. An identical move on both targets is
not attributable to a change that only alters what aarch64 computes; it is a
harness or environment difference between the baseline run and this one, and
it is recorded rather than netted out. The columns that carry the signal
(`PASS`/`FAIL`/`XPASS`) are frozen on x86_64 to the unit, which is the control
this delta rests on.

### The ICE column, counted from the merged `gcc.log`

A `.sum` records an ICE as an ordinary FAIL and says nothing about where the
compiler died, so these come from the log.

```
aarch64 ICEs by site                       before   this run
  in gen_lowpart_general, rtlhooks.cc:57      509          0
  in aarch64_output_casesi, aarch64.cc         68          0
  in paradoxical_subreg_p, rtl.h:3338           4          0
  in ordered_min, poly-int.h:1383               3          0
  in maybe_record_trace_start, dwarf2cfi.cc     7          7
`unrecognizable insn'                           0          0
```

**The two named causes are gone entirely, and two unnamed ones went with
them.** `paradoxical_subreg_p` and `ordered_min` were not in the brief and
were not aimed at: both assert on mode-size relations that
`REGMODE_NATURAL_SIZE` feeds, so they were downstream symptoms of the same
defect rather than separate causes — the same shape as `get_attr_type` falling
out with `extract_insn` in #175.

`maybe_record_trace_start` (7) did **not** move, and that is the honest
negative: it is a CFI/unwind defect and this change does not touch unwinding.
It is the whole of the remaining aarch64 ICE column.

**The `before` column for the last three rows is `ed7feb54b99`'s log
(`/tmp/b-a7de5`), not `T173-board.txt`'s** — the T173 log had been deleted
before this task started, and the board file records only per-target totals
and top FAIL files, not ICE sites. The 509 and 68 are the brief's own figures
and agree with that log exactly.

## 6. What is NOT claimed

- **`CASE_VECTOR_MODE` is the same family and is NOT fixed here.** aarch64's
  is `Pmode`, i386's is
  `(!TARGET_LP64 || (flag_pic && ix86_cmodel != CM_LARGE_PIC) ? SImode : DImode)`,
  and shared code at `stmt.cc:1204` and `expr.cc:14348` reads i386's. It is
  correct by luck on this pair in the non-PIC case (both yield `DImode`).
  `target-cdata.h:166` records it as deliberately deferred to the mode-numbering
  work, and it is left alone.
- **The suite delta is HEAD-vs-baseline, not these two commits in isolation.**
  The reproducers in §1 and §2 are what attribute the two ICE columns.
- 45 of 47 back ends remain unmeasured; only C and LTO are configured, and
  with no target libgcc every `dg-do run` is downgraded to compile. Much of
  *both* FAIL columns is the absent runtime; the aarch64-minus-x86_64 delta is
  the signal and the common part is the build's shape.
- **`KILLED` is 2 on aarch64, 0 on x86_64, counted and never subtracted** —
  the same two as the T173 baseline. Two OOM-killed compilations remain in the
  aarch64 FAIL column as ordinary failures.
- **The run is PROVISIONAL by the board's own rule.** The 15-minute load
  average at scoring time was **27.36** (1-min 19.85, 5-min 22.25), above the
  ~25 threshold. Four other agents were building on this machine. That
  inflates `KILLED` risk and timeout-shaped failures; it does not plausibly
  manufacture a 509 → 0 ICE collapse, which §1 and §2 attribute directly.
- **The whole-suite totals fell on aarch64** (335313 → 331677). Tests that ICE
  emit extra result lines; removing the ICE removes them. Recorded rather than
  netted out.
- **The build dir was destroyed mid-run once by an unrelated `/tmp` sweep and
  everything was re-measured from scratch**, including a fresh configure and
  `make all-gcc` from the same snapshot. The bars and both reproducers came
  out byte-identical across the two builds, which is a reproducibility check
  this task did not set out to run.
