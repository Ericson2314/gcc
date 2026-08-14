# #170 — "links" vs "emits real code a real assembler accepts", eleven back ends

Build: `/tmp/b-a697b5bfd5294f5e8`, configured from the immutable snapshot
`/tmp/snap-a697b5` at `8e87bbadcc8`, anchor **50**, clean.
`make -k -j8 all-gcc` rc=0, **`cc1` links: 0 `multiple definition`, 0
`undefined reference`, 0 `Error`.** That half reproduces.

Everything below is `cc1` driven **directly** with `-ftarget-config=`, never the
driver: the riscv driver segfaults (#154) and `-march=native` is i386's
(`host_detect_local_cpu`), and neither is this task's subject.

## 1. THE TABLE

| back end | links | specs-config | emits `.s` | x86 tokens | assembles | ELF machine |
|---|---|---|---|---|---|---|
| i386 (`x86_64-pc-linux-gnu`) | yes | 230 / `a6c4c68bdf33` | **yes** `-O0/1/2` | n/a | **yes** | **X86-64** |
| aarch64 | yes | 230 / `1b8afb792629` | **yes** `-O0/1/2`, incl. `big.c` | no | **yes** | **AArch64** |
| s390 (`s390x-ibm-linux-gnu`) | yes | 230 / `ce59ae5c4073` | **yes** `-O0/1/2` | no | **`-O0`,`-O1` yes; `-O2` NO** | **IBM S/390** |
| riscv | yes | 230 / `b68f671472d5` | `-O0` yes; `-O1` unrecognizable insn; `-O2` ICE | no | **no** (one directive; see §3) | RISC-V *when that directive is patched* |
| rs6000 (`powerpc64-…`) | yes | 230 / `c0d87926fb87` | **no** — FPE at every `-O` | — | — | — |
| mips (`mips64-unknown-elf`) | yes | 230 / `04063751bd12` | **no** — SIGSEGV at every `-O` | — | — | — |
| arm (`arm-unknown-eabi`) | yes | 230 / `0ecc405381e2` | **no** — refuses by name before codegen | — | — | — |
| sparc | yes | **UNKNOWN** — no binutils | **no** — stub by name / SIGSEGV | — | UNKNOWN | UNKNOWN |
| ia64 | yes | **UNKNOWN** — no binutils | **no** — SIGSEGV | — | UNKNOWN | UNKNOWN |
| visium | yes | **UNKNOWN** — no binutils | **no** — SIGSEGV | — | UNKNOWN | UNKNOWN |
| xtensa | yes | **UNKNOWN** — no binutils | **no** — SIGSEGV | — | UNKNOWN | UNKNOWN |

**Score: 11 link, 4 emit, 3 assemble to an object of the right ELF machine**
(i386, aarch64, s390 — s390 at `-O0`/`-O1` only). riscv is one directive from
a fourth.

The seven specs-configs are all 230 lines / 222 non-blank with **seven distinct
md5s**, so they are seven files and not one served seven times. x86_64's is
`a6c4c68bdf33` — **byte-identical to the recorded two-base bar**, at eleven
bases.

The x86-token arm is not vacuous: it scores **40** on x86_64's own output and
**0** on s390's and aarch64's. So "no" is a real negative.

## 2. THE NAMED GAP: FOUR BACK ENDS HAVE NO ASSEMBLER ANYWHERE

Of **27,157** top-level nixpkgs attributes, the number matching `sparc`,
`ia64`, `visium` or `xtensa` is **0, 0, 0, 0** — against `aarch64`=1 and
`riscv`=2 measured the same way, which is the non-vacuity control that makes
those zeros the package set's and not the query's. `pkgsCross` has no such
attribute either. So for these four, "does a real assembler accept it" **cannot
be answered on this machine**, and UNKNOWN is the honest cell.

**But the toolchain is not what is stopping them.** Run with an explicitly
labelled fallback config (`t170-nobinutils.sh`, x86_64's answers under the
target's name, used only to get a well-formed config into `cc1`), **all four
ICE before emitting a byte.** Getting binutils for them would not move the
table today.

The other six have real cross binutils, each proved to be what it claims:
every linked `as` assembles an empty file and the object's ELF machine is read
back — X86-64 / AArch64 / PowerPC64 / IBM S/390 / RISC-V / MIPS / ARM, 0
failures. A link pointing at the host `as` fails that arm by name.

## 3. FAILURES BY CAUSE — six causes, not eleven failures

**C1 — a null function pointer in a per-base table. FIVE back ends.**
The single largest cause. Frame `#0` is address `0x0` in every case:

    riscv    insn_riscv::insn_has_dfa_reservation_p  <- riscv_sched_variable_issue
    mips     insn_mips::state_transition             <- mips_sim_wait_units
    ia64     optimize_mode_switching()                (the mode-switching hooks)
    visium   optimize_mode_switching()
    xtensa   optimize_mode_switching()

Two families: the **DFA/scheduler** entry points (riscv, mips) and the
**mode-switching** hooks (ia64, visium, xtensa). This is PRINCIPLES section 3's
`internal_dfa_insn_code` entry — *function vs function pointer* — met three
more times, and section 4's *"is a per-base variant built / does a selector
exist / does anything CALL the selector"* answered "the caller exists and the
slot is empty". Not `PASSES_EXTRA` (#171): these are generic passes calling
target hooks, not target passes failing to run.

**C2 — FPE in `subreg_get_info`. rs6000.**
`init_costs` → `init_subregs_of_mode` → `record_subregs_of_mode` →
`simplify_subreg_regno` → `subreg_get_info`, divide by zero, at every `-O`
including `-O0`. A size/word quantity reaching that function as **0** — the
shape of PRINCIPLES' *"a hole with a real class is a usable object"*, where
everything says "absent" except the one field still answering.

**C3 — the struct-size witness fires, by name. arm.**

    back end 'arm' computes 'sizeof (struct target_expmed)' as 509504, but
    target-independent code allocates 514168; a bound in its header is not
    spelled MULTI_TARGET_UNION_*

This is the check working exactly as PRINCIPLES describes it: it names the back
end, the struct, both sizes and the next action. arm never reaches codegen, and
that is the correct behaviour.

**C4 — a recorded stub firing by name. sparc.**

    'only_leaf_regs_used' was called, but this compiler was built without
    'LEAF_REGISTERS' reaching shared code ... there is deliberately no default
    -- see scratchpad/T157-STUBS.md

The fail-by-name shape the standing ruling asks for, doing its job. (sparc also
SIGSEGVs at `-O0`, a second and separate wall.)

**C5 — `.attribute arch, ""`. riscv. THE MOST INFORMATIVE FAILURE HERE.**
riscv emits genuine RISC-V at `-O0` — `addi sp,sp,-32`, `sw ra,28(sp)`,
`a0`/`a1`/`s0`/`ra`, DWARF regnos 1 and 8 — and its assembler refuses the file
at **line 3**:

    Error: the architecture string of -march and elf architecture attributes
    cannot be empty

Patch that one line and the same file assembles to an **ELF64 RISC-V object**.
So the ISA string is empty: riscv's own option override never supplied it.

**C6 — `la` with a negative displacement. s390, `-O2` only.**
s390 emits real s390 at all three `-O` levels (`ar %r2,%r3`, `lgfr`, `stmg`,
`aghi`, `br %r14`) and assembles cleanly at `-O0` and `-O1`. At `-O2` it emits

    la  %r15,-160(%r15)

and `as` refuses: `operand 2: operand out of range (-160 is not between 0 and
4095)`, 40+ times. `la`'s displacement is 12-bit **unsigned**; the negative form
needs `lay`. At `-O0` the same prologue is `aghi %r15,-176` and is correct — so
this is an `-O2` instruction-selection/arch-level defect, not a frame-layout one.

**C7 — `big.c` at eleven bases. x86_64.**
`big.c -O2` ICEs in `type_natural_mode`, `config/i386/i386.cc:2155`, on
`v4si f_vec`. PRINCIPLES already records this for three and four bases; it is
unchanged at eleven. **The recorded two-base bar `12369` / `378fc33c1e70`
therefore cannot be reproduced at eleven bases and this is not a regression
from this task** — the bars are base-count dependent and that is the recorded
reason. aarch64 compiles `big.c` at eleven bases and assembles it (13079 bytes,
`21c3146f09e7`, input `/tmp/snap-a697b5/scratchpad/big.c`). `scratchpad/t170-small.c`
is the portable input the other back ends are measured on.

## 4. THE FINDING THIS TASK EXISTS TO CATCH — AND IT IS NOT THE ONE EXPECTED

**No back end emitted x86 instructions under another name.** aarch64, s390 and
riscv each emit their own architecture's mnemonics and register names; the
token arm scores 0 on each while scoring 40 on x86_64. That is the good news
and it is the arm's own negative control that makes it worth stating.

**riscv64 emits 32-bit code.** In an ELF64 object, for a target whose `long` is
64 bits:

    long mt_shift (long a, int n) { return (a << n) | (a >> 1); }

      sw   ra,28(sp)          <- the return address stored as 32 bits
      .cfi_offset 1, -4       <- and DWARF agrees it is 4 bytes
      lw   a5,-24(s0)
      sll  a4,a4,a5           <- a 64-bit `long' shifted with 32-bit ops
      srai a5,a5,1

Not one `sd`/`ld` anywhere in the function. The word size is **4**. This is
PRINCIPLES' *silent-default variant* — the primary's **unconfigured** default,
correct for neither base, the `ix86_pmode` `Init (PMODE_SI)` shape — and it is
the same root as C5: riscv's option override never ran, so neither its ISA
string nor its word size was ever set.

Measured both-sided, which is the point: **aarch64 and s390 are correct 64-bit**
on the identical function (`str x0, [sp, 8]` / `lsl x1, x1, x0`;
`stmg`/`aghi`/`sllg`). So this is riscv's defect and not a shared one.

**And it says something about the bar itself.** Patch the one directive `as`
complains about and riscv produces a well-formed ELF64 RISC-V object that
`readelf -h` reports correctly. **"Assembles, right ELF machine" would have
passed on code that truncates every return address.** The bar aarch64 met is a
floor, not a proof; a target's own assembler catches an empty ISA string and
has nothing to say about a wrong word size.

## 5. A HARNESS TRAP WORTH INHERITING

`--enable-targets` accepts the alias; **everything downstream is named after
the canonicalised triple.** `MT_TARGET_SUBDIRS`, every
`configure-target-specs-<t>` rule, every spec directory and every
`specs-config` path use `arm-unknown-eabi`, `s390x-ibm-linux-gnu`,
`mips64-unknown-elf`, `powerpc64-unknown-linux-gnu`, `sparc64-unknown-linux-gnu`,
`visium-unknown-elf`, `xtensa-unknown-elf`, `ia64-unknown-elf` — not the
`all-backends.txt` spellings they were configured with.

Keyed on the typed name, the first run of `t170-specs.sh` reported

    make: *** No rule to make target 'configure-target-specs-arm-eabi'.  Stop.

for **eight of eleven**, and the three that "worked" were exactly the three
already spelled canonically. That reads as *eight back ends failed*; it is
*one harness read the wrong name*. `t170-bases11.txt` now carries both columns
for that reason.

Second, smaller: nixpkgs' binutils prefixes match the configured triple for
**only two** of six (aarch64, riscv64). `target-specs/configure` looks
`${target}-as` up by name, so the other four would silently find no tool and
take every probe's "assume the worst" branch — pessimistic, not obviously
broken. `t170-tools.sh` gives each real cross tool the name the probe looks up,
and proves by ELF machine that it is the right tool before anything is measured
with it.

## 6. WHAT THIS DID NOT MEASURE

- **No correctness beyond "a real assembler took it".** Nothing was executed;
  there is no target hardware or emulator in play. §4 shows why that gap
  matters: assembling is compatible with badly wrong code.
- **sparc, ia64, visium, xtensa: assembles/ELF-machine are UNKNOWN and cannot
  be made known here.** No assembler for them exists in this nixpkgs. LLVM
  covers sparc and xtensa upstream and was not tried; that is an available next
  step, and would still leave ia64 and visium with no instrument.
- **`-O0`/`-O1` results are a weaker bar than `-O2`** and are labelled as such
  in the table rather than merged into it.
- The x86-token arm is deliberately over-broad (it can only accuse). Its zeros
  are evidence that no x86 mnemonic *from that list* appears; they are not a
  proof of correct instruction selection.
