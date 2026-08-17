# aarch64 trampolines: THREE leaks on one four-line function, and one of them
# puts executable code in `.rodata`

Measured with the board's compiler against the **stock aarch64 compiler the
board's debt is scored against**
(`scratchpad/agent-a992b7e5fa4ffaaa7-tramp.sh`). Both-sided by construction:
"multi-target emits X" is not a finding unless stock emits something else.

```c
int outer (int x)
{
  int inner (int y) { return y + x; }
  int (*p) (int) = inner;
  return p (1);
}
```

```
-- the section the trampoline lands in:
   STOCK          .text
   MULTI-TARGET   .section  .rodata
-- the alignment immediately before .LTRAMP0:
   STOCK          .align 3
   MULTI-TARGET   .align 2
```

## 1. `TRAMPOLINE_SECTION` — the trampoline is emitted into `.rodata`

```c
/* varasm.cc:3065 */
#ifdef TRAMPOLINE_SECTION
  switch_to_section (TRAMPOLINE_SECTION);
#endif

/* aarch64.h:1486 */
#define TRAMPOLINE_SECTION text_section
```

**i386 defines no `TRAMPOLINE_SECTION`**, so the shared `#ifdef` is false for
all 47 back ends and the `switch_to_section` never runs. aarch64's trampoline
is then written wherever the previous section left off — `.rodata`.

A trampoline is **executed**. `.rodata` is not mapped executable, so a call
through a nested function's address faults at run time. This is a
`__builtin_trampoline`-shaped W^X failure, not a cosmetic section choice.

**This is NOT in the `defaults.h` floor class** (`FLOORSWEEP.md`) and the sweep
could not have found it: there is no `#ifndef` floor, only a bare `#ifdef` in a
shared TU on a name the primary does not define. That is the **leaked absence**
family — `FINAL_PRESCAN_INSN`, `DELAY_SLOTS`, `GO_IF_LEGITIMATE_ADDRESS`
(`d1ae5fb5969`) — and it is a **third** enumerable class beside the two in
`FLOORSWEEP.md`:

| class | shape | found by |
|---|---|---|
| floor-dead | `#ifndef` floor, primary defines the name | `floorsweep.sh` |
| floor-fires | `#ifndef` floor, primary silent, a back end dissents | `floorsweep.sh` |
| **leaked absence** | **bare `#ifdef` in shared code, primary silent** | **nothing yet** |

The third has no sweep. `d1ae5fb5969` found its three by hand. That is the gap
worth closing next, and it is mechanically enumerable in exactly the same way:
`#ifdef <NAME>` in a shared TU where `<NAME>` is `#define`d under `config/`
and **not** by i386.

## 2. `TRAMPOLINE_ALIGNMENT` — 4-byte where aarch64 asks for 8

`.align 2` against stock's `.align 3`. aarch64 says 64 (`aarch64.h:1482`);
shared code takes `defaults.h`'s floor, which is
`FUNCTION_ALIGNMENT (FUNCTION_BOUNDARY)` — i386's. This is the `floor-fires`
row `FLOORSWEEP.md` predicted from headers alone, now confirmed in emitted
assembly.

An under-aligned trampoline is a correctness risk on a target whose
instruction fetch and cache-maintenance (`__builtin___clear_cache`) assume the
declared alignment.

## 3. `ASM_OUTPUT_MAX_SKIP_ALIGN` — the spurious `.p2align 3`, still live

Multi-target emits `.p2align 5,,15` **and** `.p2align 3`; stock emits only the
first. This is `A018835BBCFAD2E28-BOARD` handover item 3 confirmed unchanged at
tip, and its population is **7 not 6** — i386 defines it too
(`i386.h:2262`), which is why the shared `#ifdef` is true for everyone.

## What this is worth on the board

**Probably very little, and that is the point.** Nested functions are rare in
the testsuite and this is a compile-only board, so all three of these produce
assembly that assembles cleanly into a well-formed `ELF64 / AArch64` object.
Like the s390x `STACK_POINTER_OFFSET` bug, **the board cannot see any of
them.**

Three of the most serious defects found in this session — an ABI break on
s390x, executable code in `.rodata` on aarch64, and `__builtin_eh_return`
failing on two targets — were found by *compiling four small programs and
diffing against stock*, not by the suite. That is a statement about the
instrument, not about the targets: **the debt column is a lower bound, and a
compile-only debt column is a weak one.**
