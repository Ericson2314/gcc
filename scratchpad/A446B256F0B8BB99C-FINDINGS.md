# `CASE_VECTOR_MODE` and `INCOMING_RETURN_ADDR_RTX`

Continuation of `T176-TWO-CAUSES.md`.  Two more names, the same disguise:
**one name, several authorities, no diagnostic.**

Snapshots, both immutable `git archive` extractions, `chmod -R a-w`, anchor
**49** on both:

```
BEFORE  /tmp/snap-agent-a446b256f0b8bb99c   a8eb6bb16e3   /tmp/b-a446b256f0b8bb99c
AFTER   /tmp/snap2-a446b256f0b8bb99c        b919189d1e5   /tmp/b-a446b256f0b8bb99c-after
```

Both builds: `make all-gcc` rc=0, `error:` 0, `multiple definition` 0,
`undefined reference` 0, stderr 1139 lines on both (identical).

---

## 0. First, two corrections to the brief

**The worktree was on the wrong tree.** It started at bare-repo HEAD
`7208eca60d0` — 192,751 commits, i.e. the `PRINCIPLES` §5 trap, which presents
as stale line numbers rather than as a wrong tree.  Reset to `multi-target`
before doing anything.  Note the branch had also moved on from the brief's
`2b20283b6b1` to **`a8eb6bb16e3`**, so this work is based on the later tree.

**The brief's bars are right and PRINCIPLES' are stale, as the brief said.**
Measured on the BEFORE build:

```
specs-config x86_64   wc -l 232  grep -c . 224  md5 cfbc7a65e54e
specs-config aarch64  wc -l 232  grep -c . 224  md5 575aff0c188b
x86_64 -O2 big.c -o x.s          12369 bytes    md5 378fc33c1e70
grep -c MULTI_TARGET gcc/Makefile.in           49
```

All four reproduce exactly on the AFTER build too.  **The anchor stayed 49**
because this change touches no `Makefile.in` — no new object, no new rule; both
conversions extend an existing per-base file and an existing dispatcher.

---

## 1. `CASE_VECTOR_MODE` — and the deferral that measures false

### The leak

```
aarch64.h:1367   #define CASE_VECTOR_MODE Pmode
i386.h:1920      #define CASE_VECTOR_MODE \
   (!TARGET_LP64 || (flag_pic && ix86_cmodel != CM_LARGE_PIC) ? SImode : DImode)
```

Both are DImode while `!flag_pic`.  That is the whole of the agreement, and it
ends at `-fPIC`.  Measured on the BEFORE compiler, reading the jump table's
mode out of `-fdump-rtl-final`:

```
                     BEFORE            AFTER
aarch64              TABLE MODE=DI     TABLE MODE=DI     (agreed by luck)
aarch64 -fPIC        TABLE MODE=SI     TABLE MODE=DI     <- the leak, fixed
x86_64               TABLE MODE=DI     TABLE MODE=DI     (control)
x86_64  -fPIC        TABLE MODE=SI     TABLE MODE=SI     (control, i386's own)
```

So aarch64 built PIC jump tables out of 4-byte elements while its own `casesi`
expander and `aarch64_output_casesi` assume `Pmode`.  In the emitted assembly
this shows as the jump table's alignment, `.align 4` → `.align 8`.

**aarch64 non-PIC is byte-identical before and after.**  That is not a weak
result, it is the direct confirmation of "correct by luck": the fix changes
nothing exactly where the two answers coincided.

### The deferral at `target-cdata.h:166` does not block this, and its premise is false

The note reads: *"`Pmode`, `CASE_VECTOR_MODE` and `STACK_SIZE_MODE` are
`machine_mode`s, and mode NUMBERING is per base.  A mode in this struct would
be a number transported into a vocabulary where it means something else."*

Measured (`a446b256f0b8bb99c-modenum.sh`, with a negative control):

```
enumerators: i386 244, aarch64 244
  E_SImode     i386=27   aarch64=27   same
  E_DImode     i386=28   aarch64=28   same
RESULT: mode numbering is SHARED -- enumerator lists identical
negative control: fired
control: the two insn-modes.h DO differ overall (per-base data), as designed
```

`genmodes.cc` unions the mode **vocabulary** and keeps only the per-base
**data**, so there is one numbering.  The premise was already false for as long
as `mt_base_pmode` has existed — `Pmode` and `FUNCTION_MODE` return modes
through this very table and have since #124.

The **conclusion** (keep modes out of `target-cdata`) is still right, for the
reason every other entry in that block has: these names are **option state**,
so a value cached at selection time would be frozen at whatever the command
line said.  So the note is now stated that way, and records that these names
want `target_frame_desc` rather than the mode-numbering work.

**This is the answer to the brief's "if the deferral is real, say so measured
and move on": it is not real for a call, and the measurement is above.**

Its non-vacuity guard earned its keep on the first run: it reported
`enumerators: i386 0, aarch64 0` and refused to score, because
`<base>-inc/insn-modes.h` is a one-line shim and the real content is in
`insn-modes-<base>.h`.  An instrument without that guard would have printed
"identical" — from two empty lists.

---

## 2. `INCOMING_RETURN_ADDR_RTX` — the last standing aarch64 ICE column

The brief asked for the authority behind the 7 `maybe_record_trace_start`
ICEs, and predicted "one name, several authorities, no diagnostic, three files
away in shared code".  That is exactly what it is.

### Finding it

`dwarf2cfi.cc` reads 21 target macros.  Scored by *whose* answer shared code
gets (`a446b256f0b8bb99c-dwarf-authority.sh`), one row per macro rather than a
count, exactly one is both **defined by both bases** and **unconverted**:

```
MACRO                              i386   aarch64  defaults.h converted
INCOMING_RETURN_ADDR_RTX           yes    yes      -          ** NOT **
```

(The sibling `DWARF_ALT_FRAME_RETURN_COLUMN` — aarch64 defines it, i386 does
not — was already converted, and `dwarf2cfi.cc:378` carries the note.)

### What it is

```
i386.h:2162      gen_rtx_MEM (Pmode, stack_pointer_rtx)
aarch64.h:1472   gen_rtx_REG (Pmode, LR_REGNUM)
```

Not two values of one kind — two **kinds**.  i386 says the return address is
in memory at the stack pointer; aarch64 says it is in a register.
`dwarf2cfi.cc:3283` passes whichever it got to `initial_return_save`, which
builds the CIE's initial row, so aarch64's CIE claimed the return address was
already spilled at function entry.  Every trace that then established the truth
(LR live in x30 until the prologue stores it) disagreed with that row, and
`maybe_record_trace_start` hit its `Inconsistent CFI state` `gcc_unreachable ()`
at **`dwarf2cfi.cc:2606`** — the exact line in the surviving logs.

**The back end is entirely correct and the authority is three files away**,
the same geometry as `aarch64_output_casesi` in the sibling fix.

### It is not an aarch64 quirk — it is the population

45 back ends define the macro; by shape **7 `gen_rtx_MEM` against 37
`gen_rtx_REG`**.  **i386 is one of the seven.**  So the primary hands a memory
location to the 37 back ends whose return address is a register.  It is a
majority-wrong leak, and invisible to any pair that happens to agree on the
shape — i386 + rx, i386 + rl78, i386 + h8300 would all have looked fine.
Another entry for the two-back-ends-cannot-tell list, and one where a *third*
back end would not have helped unless it was chosen off i386's side.

### A second consumer, and it is an existence test

`df-scan.cc:3559` is `if (REG_P (INCOMING_RETURN_ADDR_RTX))`, which marks the
return-address register live on entry.  With i386's MEM that test is **false**,
so on aarch64 x30 was never added to the entry block's defs.  A dataflow
consequence rather than an ICE, and the reason this conversion is not only
about the assert.

### Measured

Reproducer is `gcc.dg/shrink-wrap-sibcall.c` at `-O2 -g`, one of the two tests
carrying these ICEs in the surviving log (the other is `gcc.dg/pr59418.c`).

```
                BEFORE                                          AFTER
aarch64  rc=4  ICE in maybe_record_trace_start, dwarf2cfi.cc:2606   rc=0, no ICE
x86_64   rc=4  ICE in cselib_invalidate_regno, cselib.cc:2650       UNCHANGED
```

Before: a 6-line stub, no function emitted.  After: the complete 540-line
function with correct unwind info, including `.cfi_offset 30, -24` — x30/LR
recorded as saved at the right offset, which is precisely what the CIE was
lying about.

**The x86_64 ICE at `cselib.cc:2650` is a SEPARATE, PRE-EXISTING defect.** It
is identical before and after and is not touched by this work; it is reported
here rather than netted out, and it means x86_64 cannot serve as a *passing*
control on that one file — only as an *unchanged* one, which is what the
both-sided arm asserts.  It is a live x86_64 wall nobody has named, and is
worth a task.

---

## 3. Both-sided

`a446b256f0b8bb99c-bothsided.sh`.  Refuses to score unless the subject moved
**and** a control stayed identical — a comparison in which nothing moved is the
same shape as two empty lists agreeing.

```
CONTROL  cv-x86_64.s        identical  md5 3151d8d51361
CONTROL  cv-x86_64-pic.s    identical  md5 87fd78db272c
SUBJECT  cv-aarch64.s       identical  md5 16da5405b4b1   <- agreed by luck
SUBJECT  cv-aarch64-pic.s   DIFFERS    dabb363813e9 -> fb9b908362cc
CONTROL  cfi-x86_64.s       identical  md5 f862a775765f
SUBJECT  cfi-aarch64.s      DIFFERS    b61b11dd5077 -> d9cb0bd83f31
PASS: subject moved, control byte-identical
```

Plus the standing bars, all four byte-identical between the two builds.

---

## 4. Design notes

Both are **calls**, not `target-cdata` fields:

- `CASE_VECTOR_MODE` is `flag_pic`-dependent on i386 and seven others.
- `INCOMING_RETURN_ADDR_RTX` **builds an rtx**, and i386's reads
  `stack_pointer_rtx` — per-function state that does not exist until
  `init_emit_regs` has run.  Caching it would be the `PIC_OFFSET_TABLE_REGNUM`
  trap `target-cdata.h:160` names.

Neither thunk gets an `#ifdef`.  A base defining neither name fails to compile
**by name**, at build time, which is the fail-by-name PRINCIPLES asks for and
is strictly better than a run-time abort.  No supply-side floor was added for
either: `defaults.h` has none for either name, and copying
`dwarf2cfi.cc:52`'s `(gcc_unreachable (), NULL_RTX)` into the thunk would be a
second authority for the value.

Swept for constant-expression contexts before redirecting: no `#if`, `#ifdef`,
case label, array bound or static initialiser in shared code names either.  The
`== Pmode` / `== SImode` tests (epiphany, ia64, sparc, `i386.cc:16154`) are
back ends' own translation units and keep the real macros.  `df-scan.cc:3558`'s
`#ifdef` stays true, which is correct — the thing behind it is now a call to
the *selected* back end rather than to whichever base compiled `df-scan.cc`.

---

## 5. What is NOT claimed

- `STACK_SIZE_MODE` is the third name in that `target-cdata.h` note and is
  **still unconverted**.  The measurement above applies to it and it is a
  ready task.
- The x86_64 `cselib.cc:2650` ICE is untouched and unexplained.
- 45 of 47 back ends remain unmeasured; only C and LTO are configured.
- The `-fPIC` consequence is demonstrated on the RTL mode and on jump-table
  alignment.  Whether any *runtime* miscompilation followed is not established
  here — with no target libgcc nothing runs.
