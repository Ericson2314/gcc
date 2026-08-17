# `TARGET_VTABLE_ENTRY_ALIGN` — the residual 3, converted and measured

Worktree `agent-a8f6f467d15197cd3`. Two cold 47-back-end builds,
`--enable-languages=c,c++`, `-j8`, each from its own immutable `git archive`
snapshot named for the worktree id **and** the sha. Anchor **52** in both,
unmoved — nothing here touches `gcc/Makefile.in`.

| build | snapshot | contents |
|---|---|---|
| `/tmp/b-a8f6f467d15197cd3-PRE`  | `e1f0cad1c2c` | branch tip, no fix |
| `/tmp/b-a8f6f467d15197cd3-POST` | `1d776be416a` | + the `vtable_entry_align` frame call |

## 1. Both build, and `cc1plus` links and executed

```
             rc  error:  Killed  stderr  warning:  cc1plus bytes
PRE           0       0       0    4779      1018      236182552
POST          0       0       0    4779      1018      236183752
```

**PRE reproduces the previous task's POST2 figures exactly** — 4779 / 1018 and
`cc1plus` 236182552 bytes — which is the check that this build is the same
compiler that task measured, not a claim that I remembered to look. POST
matches PRE at 4779 / 1018, i.e. **the conversion adds no warnings**; the
1200-byte growth is 47 per-base functions plus the selector.

`cc1plus` was asserted present and **executed** on every target below before
any figure here was quoted.

## 2. Why this is a `target_frame_desc` CALL and not a `TARGET_CDATA_FIELDS` slot

`target-cdata.h:316` refuses the slot and its argument is correct, so it
stands unedited. `defaults.h:972` is `#define TARGET_VTABLE_ENTRY_ALIGN
POINTER_SIZE`; a macro body is expanded at the **use** site; `POINTER_SIZE` is
deliberately a per-base **call** (`mt_pointer_size`) because it moves within
one compilation. So the 44 back ends that define nothing **already had their
own dynamic answer**, and a cdata slot would have frozen it for 44 in order to
fix 3.

The fix is therefore in the family the header said it belonged to —
`target_frame_desc::vtable_entry_align`, beside `pointer_size` itself. The 44
keep the call, one indirection further out.

## 3. The prediction, written down before the run

This is the part that matters, because **"3 back ends define it, so 3 targets
change" is wrong**, and a sweep run without stating that first would have read
its own result as a partial failure.

PRE is *not* "i386's answer for everyone" — `POINTER_SIZE` is already
converted, so PRE is "every base's own `POINTER_SIZE`". A target moves only if
its literal **differs from its own `POINTER_SIZE`**:

```
ia64      defines 64   POINTER_SIZE 64  (TARGET_ILP32 is 0 for ia64-elf)  -> must NOT move
msp430    defines 16   POINTER_SIZE 16  (20 only under -mlarge)           -> must NOT move
avr       defines  8   POINTER_SIZE 16                                    -> MUST move
```

Read from each base's own `tm-<base>.h` through the real preprocessor before
the sweep ran, not from the source directory.

## 4. Both-sided over the targets with real cross assemblers

45 of 47 targets have a cross `as` that was asserted to **execute**
(`agent-a8f6f467d15197cd3-astest.sh`, 45 executed / 0 dead); amdgcn and nvptx
are excluded **by name**, never defaulted to the host `as`. `target-specs` ran
per target in both build dirs: **OK=45/45 in each, every `specs-config` 232
lines / 224 non-blank, all 45 md5s distinct, no duplicate-md5 fallback
signature.**

```
arm=default
targets scored: 41   changed=1   byte-identical=40   cc1plus-failed=4   VOID=0

   OK        avr     moved    (defines 8, its POINTER_SIZE is 16)
   OK        ia64    still    (defines 64 and its POINTER_SIZE is 64)
   UNSCORED  msp430  cc1plus emits no vtable here -- no verdict
```

**All three predictions hold.** The observable, verbatim — avr drops both
vtable alignment directives, one per vtable in the input:

```
avr   < 	.p2align	1
      < 	.p2align	1
```

`.p2align 1` is 2-byte alignment, i.e. avr's `POINTER_SIZE` of 16 bits. POST
emits neither, which is avr's own `TARGET_VTABLE_ENTRY_ALIGN 8` — a byte —
reaching shared code for the first time.

**The control held on every scored target.** `mt_va_control` is a plain
struct with no vtable, so its directives must be identical PRE and POST; the
script declares a target VOID rather than green if it moves, and **VOID=0**.

**`cc1plus`-failed = 4, all PRE-EXISTING and all confirmed identical at PRE:**
`mmix` (*"back end 'mmix' has no assembler-directive table"*), `pru` (ICE in
`pru_hard_regno_mode_ok`) — both recorded by the previous task — plus
**`msp430` (ICE in RTL pass `final`)** and **`sparc64` (ICE in RTL pass
`ira`)**, which are new to this input and not new to the tree.

**So msp430's answer is verified in the census and NOT at the compiler**, and
that is stated rather than folded into the 40. It is the same position `pru`
was in last task.

## 5. Two instrument defects found in my own sweep, both scoring FALSE GREENS

Recorded in the script rather than quietly fixed, because both are shapes the
next reader will reproduce.

**`test -s` is not a check, and it cost two wrong verdicts.** When `cc1plus`
ICEs it still writes the output file it was given: msp430 under `-mlarge`
produces a **44-byte** `.s` — a header comment and nothing else. `-s` passes
on both sides, `cmp` finds the two stubs identical, and the target is scored
**`identical`** — i.e. as positive evidence that the macro did not need to
move there. The first run of this sweep reported `targets scored: 43,
byte-identical=42`; with the reader checking that the artefact **contains the
vtable symbol it exists to emit**, the true figures are `41` and `40`, and
`msp430` and `sparc64` move from the evidence column to the failure column.
This is PRINCIPLES' 39-line-truncated-spec-file lesson arriving in a new
place: *"non-empty" and "long enough" and "exists" are not checks; they are
the shape that passes on the corrupted artefact.*

**"Did not move" and "was never scored" both printed `still`.** With the
reader fixed, the prediction check still reported `OK msp430 still` — because
a target that ICEs is simply absent from the CHANGED list, and absence was
being read as a satisfied prediction. It now prints `UNSCORED` and says there
is no verdict. Same null-result-as-a-pass shape, one level up, inside the arm
written to catch it.

**And the `-mlarge` arm cannot be run at all.** msp430 under `-mlarge` ICEs
in `c-family/c-cppbuiltin.cc:2039 type_suffix` — **at PRE and POST alike**, on
a two-line C file with no headers — so the one configuration in which
msp430's own comment predicts the symptom (*"defaults to `POINTER_SIZE`,
which is 20 for `TARGET_LARGE`"*, and 20 is not an alignment) is
unmeasurable here. The arm reports `UNMEASURABLE` rather than a verdict.

*Hypothesis, labelled as one and not measured:* that ICE may be downstream of
the `INT_TYPE_SIZE` leak in `scratchpad/A8F6F467D15197CD3-INTWIDTH.md` —
`type_suffix` is looking for an integer type matching a 20-bit pointer among
type nodes that were all built with the **primary's** widths.

## 6. Bars

```
cc1 -quiet -nostdinc -O2 -ftarget-config=<cfg> big.c -o x.s
  x86_64   12369 bytes  md5 378fc33c1e70     PRE and POST
specs-config  232 lines / 224 non-blank      all 45 targets, both builds
anchor  grep -c MULTI_TARGET gcc/Makefile.in  52   PRE and POST
```

The `specs-config` **md5 is not quoted as a bar** — it is a function of the
probing toolchain's paths.

## 7. What was NOT measured

* **No testsuite run.** No `g++` board was taken, so nothing here is a debt or
  regression figure against the corpus.
* **msp430 and sparc64 are unverified at the compiler** for this input, and
  `pru` and `mmix` compile no C++ at all here.
* **msp430 under `-mlarge`**, the case its own comment describes, is
  unmeasurable until the `c-cppbuiltin.cc:2039` ICE is fixed.
* **`d/decl.cc:2245` is the other consumer of this macro and was not
  compiled** — `d` has never been built multi-target. See
  `scratchpad/A8F6F467D15197CD3-FRONTENDS.md`.
* **amdgcn and nvptx** have no cross assembler and appear in no sweep.
