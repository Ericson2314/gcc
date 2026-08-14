# The four remaining non-emitting causes — measured, and two of them were the same bug

Build: `/tmp/b-a76e996f6ef44dca5-f`, configured from the immutable snapshot
`/tmp/snap-a76e99-f` at `9fd2a3f9ed5`, **anchor 49**, clean tree,
`make -k -j8 all-gcc` **rc=0 with the `.rc` stamp written after `make`
returned**, 0 `error:`, 0 `multiple definition`, 0 `undefined reference`,
stderr 1754 lines. Eleven back ends (`t170-bases11.txt`). `cc1` is driven
directly with `-ftarget-config=`, never the driver.

**Six earlier build dirs (B–E) and their snapshots were deleted mid-task by a
coordinator `/tmp` sweep.** Every figure below is re-measured on build F, one
build, after the sweep. Nothing from B–E is quoted as a number.

## 1. THE TABLE

Five arms, scored independently, plus a **sixth added by this task**:
STABILITY. `ta76-flaky.sh`, and §4 says why it had to exist.

| back end | emits `-O2` | stable | x86 tokens | assembles | ELF machine | word `long` |
|---|---|---|---|---|---|---|
| x86_64 | **yes** (`big.c`) | 5/5 | n/a | **yes** | **X86-64** | **ok 8** |
| aarch64 | **yes** (`big.c`) | — | no | **yes** | **AArch64** | **ok 8** |
| **powerpc64** | **yes** — was FPE | **8/8** | no | **yes** | **PowerPC64** | **ok 8** |
| s390x | yes | — | no | no (`la` neg. disp.) | — | ok 8 |
| **arm** | **yes** — was `ira_init` SIGSEGV | **8/8** | no | no (**one** cause, §3) | — | **ok 4** |
| riscv64 | yes | — | no | no (`.attribute arch, ""`) | — | **WRONG 4, want 8** |
| visium | yes | — | no | UNKNOWN — no assembler exists | UNKNOWN | NOSYM |
| xtensa | yes | — | no | UNKNOWN — no assembler exists | UNKNOWN | ok 4 |
| **mips64** | **5 of 12 runs** | **UNSTABLE** | — | — | — | NOSYM |
| ia64 | `-O0` yes; `-O2` never | **UNSTABLE** (5 outcomes / 8 runs) | — | UNKNOWN | UNKNOWN | ok 8 |
| sparc64 | no — `only_leaf_regs_used` stub, by name | — | — | UNKNOWN | UNKNOWN | ok 8 |

**Emitting at `-O2`: 6 → 8 of 11** (powerpc64, arm). **Assembling to an object
of the right ELF machine: 2 → 3** (powerpc64). mips64 is *not* counted as
emitting; see §4.

Both-sided control, unchanged and byte-identical to the recorded bars:

```
x86_64  big.c -O2   12369 bytes  md5 378fc33c1e70   <- the recorded two-base bar
x86_64  specs-config  wc -l 230  grep -c . 222  md5 a6c4c68bdf33
```

Seven `specs-config` files, 230 lines each, **seven distinct md5s**, so they
are seven files and not one served seven times. All seven cross assemblers
were proved by ELF machine on an empty file before anything was measured with
them (`t170-tools.sh`, 0 failures).

## 2. THE CAUSES FIXED — SIX, and the first two are one sentence twice

### `simplifiable_subregs` — rs6000's SIGFPE. **The walk bound was the union's.**

`reginfo.cc:1384` walked `0 .. FIRST_PSEUDO_REGISTER`, which in a SHARED
translation unit is `MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER` = **334**
(ia64's). It asks two back-end-supplied things about each number:
`targetm.hard_regno_mode_ok`, and through `simplify_subreg_regno`,
`targetm.hard_regno_nregs`. rs6000 answers both out of
`rs6000_hard_regno_mode_ok_p` / `rs6000_hard_regno_nregs`, declared
`[NUM_MACHINE_MODES][FIRST_PSEUDO_REGISTER]` at `rs6000.cc:155` with
**rs6000's own 119**.

Measured under gdb (`ta76-rs6000-fpe.sh`, reading SysV argument registers at
function entry because the build has no debug info; it refuses to score an
empty trace):

```
ENTER xregno=146 ...  147 ...  148 ...  149 ...  238
```

`xregno = 238` against a 119-wide table — 215 entries past the end. The
`div` at `rtlanal.cc:4195` then faults because the out-of-bounds read answered
**0 registers**. Bounded by `MT_FIRST_PSEUDO_REGISTER`.

Note *why nothing was standing in front of it*: the sibling loop at
`reginfo.cc:605` has this exact bound already, and its comment says the
`fixed_nonglobal_reg_set` test in front of it *"would in fact short-circuit
today — which is precisely why the bound is here rather than relied upon"*.
This loop has no such test.

### `memcpy (reg_alloc_order, …, sizeof (reg_alloc_order))` — arm's `ira_init` SIGSEGV

Destination is the union-wide field (`hard-reg-set.h:542`); source is a back
end's own array on the stack. Upstream both are `FIRST_PSEUDO_REGISTER`, so
`sizeof` of either was right; here it reads `(334 − 88) × 4` bytes off the end
of arm's frame and puts the result where `ira.cc:setup_class_hard_regs` reads
it as a register number. **Three back ends: arm, arc, nds32.** Now the
SOURCE's size, with a `static_assert` naming the array. `rx.cc` has the same
shape on `fixed_regs`/`call_used_regs` in **both** directions; rx is not one
of the eleven configured bases, so it is fixed by inspection and **is not
covered by any measurement here**.

### `advance_state` — mips's non-termination

`mips_set_tuning_info` runs a DFA simulation at `expand`. Every question it
asks is `insn_mips::` — except the one it delegates: `mips_sim_reset` and
`mips_sim_next_cycle` call the SHARED `advance_state`, which binds the BARE
`state_transition`, i.e. **i386's automaton**.

```
nm -C mt-mips/mips.o    U insn_mips::state_transition(void*, rtx_def*)
                        U insn_mips::state_size()
                        U advance_state(void*)          <- the primary's
```

The two meet inside one loop: `mips_sim_wait_units` spins until *mips's*
automaton says the unit is free while every cycle is advanced by *i386's*.
Located by running `cc1` **under** gdb and interrupting with `timeout -s INT`
— `gdb -p` returns `ptrace: Operation not permitted` on this host, which is
why #a9f could not find it.

**This does not convert the shared scheduling family**; `multi-target-attr.h`
still records it as unselected and the leak ratchet still asserts it.

### `ASM_FPRINTF_EXTENSIONS` — arm's `gcc_unreachable` in `final`

Two of forty-eight back ends define it, i386 and arm, and **both define `%r`,
to different things**. `final.o` is shared, so the `#ifdef` and the macro body
were i386's for all forty-eight. arm's `%@` hit `gcc_unreachable ()`. Now a
per-base descriptor (`target-asmfprintf.h`) riding on the cumargs table.

**Read the direction**: this is LEAKED ABSENCE. arm's `%@` failed loudly only
because i386 has no `%@`; arm's `%r` would have printed an i386 register name
and said nothing.

### `ASSEMBLER_DIALECT` — **`bx |lr`, and this is the one to remember**

With the two above fixed, arm emitted at `-O2` for the first time on this
branch. What it emitted was

```
bx      |lr
```

`%|` in arm's template means "emit `REGISTER_PREFIX`", empty for the EABI.
`output_asm_insn` had `#ifdef ASSEMBLER_DIALECT || *p == '|'` — and **two of
forty-eight define `ASSEMBLER_DIALECT`**, i386 and i386/darwin — so `%|`
printed a literal `|`.

`cc1` exits 0 and writes a plausible `.s`. PRINCIPLES' *"a wall that moves may
have become silent wrong code"*, **arriving in the first output a back end
ever produced — which is exactly when nobody has a baseline to diff against.**
Seven `#ifdef`s in `final.cc` are now one run-time `bool` per function.

### `PIC_OFFSET_TABLE_REGNUM` — the primary's ABSENCE was everyone's answer

Twelve shared translation units spell it. i386's expands to `INVALID_REGNUM`
for x86_64, so `emit-rtl.cc:6361` left `pic_offset_table_rtx` **NULL for every
configured back end**, including the forty-four whose headers do define the
macro. Nobody got i386's `$ebx`; everybody got "this target has no PIC
register". mips's prologue handed that null to `reg_overlap_mentioned_p`.

Converted on `targetm_regs`, as a FUNCTION — `target-cdata.h:160` already
records why this macro cannot be cdata (it is not invariant). Swept rather
than assumed: all twelve shared spellings are ordinary run-time expressions;
the only preprocessor occurrence in the tree is `defaults.h:871`'s own
`#ifndef`, on the supply side.

## 3. arm's REMAINING BLOCKER IS **ONE** CAUSE, AND IT IS NAMED

arm's assembler output is refused for exactly one reason, 8 times, and nothing
else:

```
Error: unrecognized symbol type ""      <-   .type   mt_add, @function
```

`arm/elf.h:74` is `#define TYPE_OPERAND_FMT "%%%s"`; `elfos.h:284` is `"@%s"`.
`ASM_OUTPUT_TYPE_DIRECTIVE` is assembled in `defaults.h:246` from
`TYPE_ASM_OP` + `TYPE_OPERAND_FMT` and used in shared `final.cc:2074` and
`varasm.cc:6581` — the primary's. On arm's assembler `@` starts a comment, so
the type string is empty.

**Not fixed here, deliberately.** The value is a plain string and belongs in
the cdata family, but the `#if defined TYPE_ASM_OP && defined
TYPE_OPERAND_FMT` gate is a second, separate question (non-ELF back ends
define neither), and getting only the value half right would emit `.type`
directives for a back end that must not have them — silently. That is a
design decision (PRINCIPLES §2b), and there was one validation build left.

## 4. THE STABILITY ARM, AND WHY A SINGLE RUN WOULD HAVE LIED IN BOTH DIRECTIONS

mips64 at `-O2`, same compiler, same input, same config:

```
12 runs:   5  rc=0  md5 ec1e83b08653     <- emits 4262 bytes
           7  rc=4  md5 725f91e9fac0     <- SIGSEGV in GIMPLE `fixup_cfg'
UNSTABLE -- 2 distinct outcomes
```

and **under gdb it never faults at all** (gdb disables ASLR). ia64 at `-O2`:
**5 distinct outcomes in 8 runs** — SIGSEGV, SIGABRT
(`malloc(): unaligned tcache chunk`) and three different partial `.s` files.

So the two remaining walls on mips64 and ia64 are **the same class: memory
corruption**, not a missing per-base answer. The brief carried them as
different things (a hang, and `free(): invalid size`); they are not.
`ta76-flaky.sh` exists because the first run I took of mips scored `rc=0,
4262 bytes` and I would have written "mips emits" into this table.

x86_64 (5/5), powerpc64 (8/8) and arm (8/8) are STABLE, which is what makes
the mips and ia64 readings a property of those back ends rather than of the
machine.

## 5. WHAT THIS DID NOT MEASURE

- **Nothing was executed.** No target hardware or emulator is in play.
- **sparc, ia64, visium, xtensa remain UNKNOWN** on assembles/ELF-machine: no
  assembler for them exists in this nixpkgs, and no amount of output promotes
  them.
- **rx's `fixed_regs` over-run is fixed by inspection only** — rx is not a
  configured base here.
- **The corruption in mips and ia64 is not localised.** It is now *classified*
  (nondeterministic, ASLR-sensitive) but no allocation site is named. The next
  instrument wants ASAN or a `-fsanitize=address` `cc1`, which is a build, not
  a run.
- `REAL_PIC_OFFSET_TABLE_REGNUM` (`ira-lives.cc:1684`, `lra-lives.cc:1111`),
  `ASM_OUTPUT_OPCODE` (`final.cc:3486`) and `LEAF_REGISTERS` (`final.cc:211`)
  are three more raw `#ifdef`s reading the primary's headers, found while
  working these and **recorded rather than fixed**.
- s390's `-O2` `la` with a negative displacement and riscv's empty
  `.attribute arch` are unchanged and were not this task's subject.
- **`T157-STUBS.md` stays at ONE entry.** No stub was added.
