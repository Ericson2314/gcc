# Getting more back ends EMITTING — measured before and after, eleven bases

Two builds, both from **immutable snapshots**, both `make -k -j8 all-gcc`
**rc=0 with the `.rc` stamp written after `make` returned**, 0 `error:`,
0 `multiple definition`, 0 `undefined reference`, stderr **1769 lines in both**:

| | commit | snapshot | build dir | anchor |
|---|---|---|---|---|
| BEFORE | `80bf400ae06` | `/tmp/snap-a9f631` | `/tmp/b-a9f631a78e8fb27d2` | 55 |
| AFTER | `00d509993c4` | `/tmp/snap-a9f631-b` | `/tmp/b-a9f631a78e8fb27d2-b` | 55 |

Anchor measured on the tree built, both times, per PRINCIPLES §4. Configured
back ends: the eleven of `t170-bases11.txt`. `cc1` is driven **directly** with
`-ftarget-config=`, never the driver.

**No OOM anywhere.** The machine was loaded (load average 26–43, no swap) and
the coordinator warned that an OOM kill wears the costume of an ICE. Checked
by name: zero hits for `Killed`, `signal 9`, `out of memory` or
`Cannot allocate` across both `make-top.err` files and every `.err` in
`ta9f-emit/`, `ta9f-cause/`, `ta9f-nobin/`. Every failure recorded below has
either a **gdb backtrace with named frames** or a **named diagnostic**; none is
a bare kill. The two mips results that are *not* crashes are non-termination
at 22 MB and 35 MB RSS with 100% CPU — the opposite shape from an OOM.

## 1. THE TABLE

Five arms, scored independently. The fifth is new; §4 says why.

### AFTER (`00d509993c4`)

| back end | emits `-O2` | x86 tokens | assembles | ELF machine | **word `long`** |
|---|---|---|---|---|---|
| x86_64 | **yes** | n/a | **yes** | **X86-64** | **ok 8** |
| aarch64 | **yes** (`big.c`) | no | **yes** | **AArch64** | **ok 8** |
| s390x | **yes** | no | `-O0`/`-O1` yes, **`-O2` no** | — | **ok 8** |
| riscv64 | **yes** (was `-O0` only) | no | no (`.attribute arch, ""`) | — | **WRONG 4, want 8** |
| visium | **yes** (was SIGSEGV) | no | UNKNOWN — no assembler exists | UNKNOWN | NOSYM (ICEs on the probe) |
| xtensa | **yes** (was SIGSEGV) | no | UNKNOWN — no assembler exists | UNKNOWN | **ok 4** |
| powerpc64 | no — FPE, `sched1` | — | — | — | ok 8 |
| mips64 | no — **does not terminate** | — | — | — | NOSYM (ICEs on the probe) |
| sparc64 | no — `only_leaf_regs_used` stub, by name | — | — | — | ok 8 |
| arm | no — `target_expmed` witness, by name | — | — | — | NO-EMIT |
| ia64 | no — `free(): invalid size`, GIMPLE `dce` | — | — | — | ok 8 |

### The movement

| back end | BEFORE `80bf400ae06` | AFTER `00d509993c4` |
|---|---|---|
| riscv64 | `-O2` **SIGSEGV in `sched1`**, frame `#0` at `0x0` | **emits at `-O2`**, 3197 bytes |
| visium | **SIGSEGV in `optimize_mode_switching`**, frame `#0` at `0x0`, every `-O` | **emits at `-O0` and `-O2`** |
| xtensa | **SIGSEGV in `optimize_mode_switching`**, frame `#0` at `0x0`, every `-O` | **emits at `-O0` and `-O2`** |
| ia64 | **SIGSEGV in `optimize_mode_switching`**, frame `#0` at `0x0` | wall gone; **a different wall behind it** (`free(): invalid size` in GIMPLE `dce`) |
| mips64 | **SIGSEGV in `expand`**, `insn_mips::state_transition`, frame `#0` at `0x0` | crash gone; **does not terminate** — see §3 |
| x86_64, aarch64, s390 | emitted | **byte-identical output**, see §5 |
| rs6000, sparc, arm | did not emit | unchanged, same cause |

**Emitting at `-O2`: 3 → 6.** Assembling to an object of the right ELF machine
is **2** (x86_64, aarch64) at `-O2` and unchanged; s390 assembles at `-O0`/`-O1`.
The four back ends with no cross binutils anywhere in this nixpkgs remain
**UNKNOWN** on the assemble/machine arms and no amount of output can promote
them.

The rows for sparc, ia64, visium and xtensa use the **explicitly-labelled
fallback config** (`ta9f-nobinutils.sh`: x86_64's probe answers under the
target's name). That config supplies a well-formed file so that "`cc1` refuses
to start" cannot be mistaken for "this back end cannot compile"; its *answers*
are not trusted for anything.

## 2. THE TWO CAUSES FIXED — one macro each, both read in a SHARED object

### `OPTIMIZE_MODE_SWITCHING` — three back ends, and a silent fourth class

`mode-switching.cc:43` wrapped the entire file **and the pass gate** in a raw
`#ifdef OPTIMIZE_MODE_SWITCHING`, and read the entity list as a file-scope
`static const int num_modes[] = NUM_MODES_FOR_MODE_SWITCHING`. The object is
shared, so both were i386's. **Five of forty-eight back ends define those
macros** — aarch64, epiphany, i386, riscv, sh.

- **Leaked presence.** The pass ran for all forty-eight. ia64, visium and
  xtensa register no mode-switching hooks, so the first unguarded
  `targetm.mode_switching.*` call went through a NULL slot. Backtrace, all
  three identical: `#0 0x0000000000000000 in ?? ()`,
  `#1 optimize_mode_switching()`, `#2 pass_mode_switching::execute`.
- **Leaked numbering, and this is the worse half.** aarch64 has **two**
  entities, i386 **four**; riscv two; sh one; epiphany five. The three that
  define the macro were running their own hooks against **i386's entity
  numbering**, with no crash and no diagnostic — the `UNSPECV_BLOCKAGE` shape
  arriving in a pass rather than in a pattern.

Now per-base data on the established `target-cumargs.cc` path
(`target-modeswitch.h`). `n_entities == 0` is that back end's own answer, not
a floor: it is what the absence of the macro from its `tm.h` already meant,
read in the one TU compiled against that back end's headers.

**The gate is observably per base** — `-fdump-passes`, same `cc1`, same input:

    x86_64   rtl-mode_sw : ON
    aarch64  rtl-mode_sw : ON      <- still on for a base that wants it
    visium   rtl-mode_sw : OFF     <- was ON, and crashed

### `init_sched_attrs` — two back ends

`genattr` emits `internal_dfa_insn_code` and `insn_default_latency` as
function POINTERS plus a real `init_sched_attrs ()` that assigns them, one set
per `namespace insn_<base>`. Measured in the eleven-base `cc1`:

    nm -C --defined-only cc1   T insn_riscv::init_sched_attrs()   (+ ten siblings)
                               B insn_riscv::internal_dfa_insn_code
                               T init_sched_attrs()               <- one BARE pair too
    nm -uC cfgexpand.o         U init_sched_attrs()               <- binds the BARE one

Its only two callers, `cfgexpand.cc:7109` and `run-rtl-passes.cc:56`, are
shared, so **exactly one of the twelve initialisers ever ran**. Every other
base's pointers stayed NULL in `.bss` — invisible until a back end asks its
own automaton, which two do on the ordinary path:

    riscv  insn_riscv::insn_has_dfa_reservation_p  <- riscv_sched_variable_issue  (sched1, -O2)
    mips   insn_mips::state_transition             <- mips_sim_wait_units         (expand, every -O)

both with frame `#0` at `0x0`.

**WHAT THIS DELIBERATELY DOES NOT FIX.** `haifa-sched.o` and the rest of
shared scheduling still bind the **bare** `internal_dfa_insn_code`,
`state_transition`, `insn_latency` and `dfa_start`, so the scheduler still
models every target with the primary's automaton. `multi-target-attr.h`
records that family as deliberately unselected and it still is. The added call
is **additive rather than a replacement** precisely so those consumers keep
the pointers they have; replacing it would take them away and turn a wrong
answer into a crash for every base.

**No stub was added. `T157-STUBS.md` stays at ONE.**

## 3. THE WALLS THAT MOVED RATHER THAN FELL — say so, do not bank them

PRINCIPLES: *"a wall that moves may have become silent wrong code … treat a
disappeared ICE as suspicious until the output is inspected."* Two of the five
did exactly that, and neither is scored as progress above.

- **mips64 DOES NOT TERMINATE.** It now gets past `expand`; it then runs at
  100% CPU with a flat 22–35 MB RSS and produced nothing in **21 minutes** on
  `big.c` and **10 minutes** on `t170-small.c`, both at `-O2`. Killed by hand;
  the table row is `FAIL` with an empty cause line for that reason and the
  honest cause is written here. **Not an OOM** — the RSS is flat and small,
  and the process was running, not being reaped. `gdb -p` could not attach
  (`ptrace: Operation not permitted`) so the spin site is **not yet located**.
  A crash traded for a hang is not obviously an improvement and is recorded as
  a change of wall, not a fix.
- **ia64** now reaches GIMPLE `dce` and dies with **`free(): invalid size`** —
  a heap corruption diagnostic, i.e. a different and probably older defect that
  the mode-switching crash was standing in front of.

## 4. THE FIFTH ARM: WORD SIZE, AND WHY IT EXISTS

PRINCIPLES records that "assembles, right ELF machine" **passed on riscv64
code that was 32-bit**. So `ta9f-emit.sh` adds a semantic arm: `ta9f-word.c`
declares `char mt_word_long[sizeof (long)]` and the scorer reads the size out
of the emitted `.s` as an ordinary assembler directive (`.comm`/`.size`),
comparing it against a table of expected widths **derived from the triple and
not from the artefact under test**.

Three properties that make it worth having:

- **it needs no assembler**, so it is the only semantic instrument available
  for the four back ends that have none in this nixpkgs;
- it runs at `-O0`, so a back end that only emits at `-O0` can still answer;
- it is independent of codegen quality — a back end wrong here is wrong about
  the target itself.

Non-vacuous in **both** directions: it scores `ok:8` on six 64-bit targets,
`ok:4` on xtensa (a 32-bit target, so the expectation table is not a constant),
and **`WRONG:4/8` on riscv64** — reproducing #172's finding from a completely
different instrument. The harness refuses to score if no target answers.

Incidental, from the same arm: **mips64's output says `.gcc_compiled_long32`
and `.module arch=mips3`** on a `mips64-*` triple. Not chased here; recorded
because it is the same word-size class as riscv's.

## 5. THE BOTH-SIDED CONTROL

The three back ends that already emitted produce **byte-identical** assembly
before and after, same inputs:

    x86_64  t170-small.c -O2   md5 5bf35622518f   (both)
    aarch64 big.c        -O2   md5 a35f82e4da9a   (both)
    s390x   t170-small.c -O2   md5 a52952316bec   (both)

All seven `specs-config` files are byte-identical too, and x86_64's is
`a6c4c68bdf33` — **the recorded two-base bar, at eleven bases**.

Note what aarch64's identical output does and does not say. aarch64 now gets
its **own** two-entity list instead of i386's four, so the leak was real (the
header values prove it); this input does not exercise SME and therefore does
not exhibit it. "Unchanged on this input" is the honest reading, not "the leak
was harmless".

## 6. THE FOUR REMAINING CAUSES, EACH LOCALISED FURTHER THAN INHERITED

### rs6000 — the FPE is `nregs_ymode == 0`, read out of the machine

Inherited as "FPE in `subreg_get_info` from `init_costs`". Read at the
faulting instruction, which needs no debug info and the build has none:

    Program received signal SIGFPE
    0x2477738 in subreg_get_info(...)
    => 0x2477738:  div    %rdi
       0x247773b:  test   %rdx,%rdx
    rax 0x8    rdi 0x0

`div` followed immediately by `test %rdx,%rdx` is the remainder test, i.e.
`rtlanal.cc:4195`, `gcc_assert ((nregs_xmode % nregs_ymode) == 0)`. So
**`nregs_xmode` is 8 and `nregs_ymode` is 0** — `hard_regno_nregs (xregno,
ymode)` returned zero registers for `ymode`, the signature of a **union hole**
(size 0, real class). The `gcc_assert` cannot fire because the `%` faults
first. Which supplier hands over the zero is **not** settled here; that needs
one object rebuilt with `-g`.

Also noted in passing and NOT the cause of this FPE: only **i386** defines
`HARD_REGNO_NREGS_HAS_PADDING`, and `rtlanal.cc` is shared, so every back end
is asked i386's padding question with i386's *unconfigured* option defaults.

### arm — `MIN_MODE_INT` is per base while the mode NUMBERING is unioned

The witness fires by name and it is right:

    back end 'arm' computes 'sizeof (struct target_expmed)' as 509504, but
    target-independent code allocates 514168

Measured in the build dir:

    insn-modes.h        MIN_MODE_INT = E_B2Imode      <- the union
    insn-modes-arm.h    MIN_MODE_INT = E_QImode       <- the ONLY base that differs
    (the other ten bases all say E_B2Imode)

`E_B2Imode` is **555 in every one of those headers**, so the mode numbering is
unioned correctly. What is not unioned is the mode-**class** bound. And the
ten that "agree" agree for a bad reason: `insn-modes-i386.h` marks `B2Imode`
`/* <unknown>:0 */` — it is a **hole**, and the hole has become their
*minimum integer mode*. arm is the one base that genuinely defines it
(`BOOL_MODE (B2I, 2, 1)`, `config/arm/arm-modes.def:88`).

**This is more than a size mismatch.** `expmed.h:236 expmed_mode_index` is an
`inline` in a header, compiled into shared *and* per-base TUs, and it uses
`MIN_MODE_INT` as the **index origin** and `NUM_MODE_INT` as an array bound.
Two TUs therefore index one `target_expmed` from origins fourteen modes apart.
The struct-size witness is what caught it; the indexing is the real damage.

Fixing it means unioning the mode-class bounds the way the numbering already
is, which changes what `FOR_EACH_MODE_IN_CLASS` walks for every back end.
That is a design decision (PRINCIPLES §2b), not a debugging step, and it is
left for whoever owns the mode union.

### sparc — unchanged, the recorded stub firing by name

`only_leaf_regs_used`, the single entry in `T157-STUBS.md`, at `-O1`/`-O2`.
At `-O0` it now fails in `ira` instead. Doing what the standing ruling asks.

### s390 `-O2` — unchanged

`la %r15,-160(%r15)` and two more; `la`'s displacement is 12-bit **unsigned**
and the negative form needs `lay`. `-O0` and `-O1` assemble to a real
**IBM S/390** object; only `-O2` does not. Reproduced exactly as #170 recorded
it.

## 7. A FALSE GREEN IN THE INHERITED HARNESS

`t170-cause.sh` prints `ASSEMBLES  Machine: <...>` for any `.s` its target's
`as` accepts. For rs6000 and mips it printed

    powerpc64 -O0: ASSEMBLES  Machine: PowerPC64
    mips64    -O0: ASSEMBLES  Machine: MIPS R3000

on `.s` files of **50, 57 and 175 bytes** — a `.file` line, an `.ident`, and
no function at all, because `cc1` had ICEd after opening the output. A real
assembler accepts that and `readelf` reports the right machine. The line reads
as "this back end works at `-O0`" and means "this back end emitted nothing".

Same shape as the `test -s` lesson in PRINCIPLES §4: **non-empty is not a
check.** `ta9f-emit.sh` avoids it by requiring `cc1` to exit 0 *before* the
assemble arm is reached; `ta9f-cause.sh` is inherited unmodified and this note
is the correction, so the two readings can still be compared.

## 8. WHAT WAS NOT MEASURED

- Nothing was executed. No target hardware or emulator is in play.
- The scheduler's own model is still the primary's for every base (§2).
- mips's spin site is unlocated; `gdb -p` cannot attach on this host.
- rs6000's supplier of `nregs_ymode == 0` is unidentified.
- `INSN_SCHEDULING` is still `#if`-gated in shared code. Note for whoever takes
  it: `t169-macros.tsv` lists it as `1 1 1 PRESENCE MINORITY 33`, i.e. one
  definer under `config/` — that row is **blind to the real supplier**, which
  is the generated `insn-attr-common-<base>.h`, one per back end. The count in
  that column is not the number of back ends that have a DFA.
