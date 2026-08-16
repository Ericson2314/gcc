# `gcc.target/<cpu>` ACROSS 47 BACK ENDS — 28 scored, and the DFA-absent defect is on ELEVEN

Answers the task: score every back end the cross assemblers unblock, on
`gcc.target/<cpu>` — where `scan-assembler` divergence lives and which the
previous sweep deliberately excluded.

**Headline: 28 back ends produced a stamped `.sum` on `gcc.target`, up from a
board where 10 had ever been scored on any subset.** 45 of 47 now have a
verified cross assembler and a probed `specs-config`; the remaining 2 are
`NOT-APPLICABLE`, not "missing".

## PROVENANCE — quote this with any row

```
worktree    agent-a7d26223eefcfa725
            RESET at the start of this task: it was created at the bare-repo
            HEAD 7208eca60d0, 39k commits behind, on a DIVERGENT line (not even
            an ancestor).  All three arms failed: rev-parse unequal, no
            scratchpad/, `grep -c MULTI_TARGET gcc/Makefile.in' = 0.
            Fourteenth agent to hit this.
srcdir      /tmp/snap-agent-a7d26223eefcfa725-4387bf9ce42
            git archive of 4387bf9ce42, read-only, SNAP-SHA stamped
anchor      grep -c MULTI_TARGET gcc/Makefile.in = 52   MEASURED, not copied
build       /tmp/b-a7d26223eefcfa725, 47 triples from the committed back-end map
            make all-gcc rc=0;  `error:' 0;  multiple definition 0;
            undefined reference 0;  Killed 0;  cc1 links (231,051,864 bytes);
            47 mt-<cpu>/ directories
bars        x86_64 -O2 big.c  12369 bytes / md5 378fc33c1e70   == recorded bar
            specs-config x86_64  232 lines / 224 non-blank / md5 cfbc7a65e54e
            all 45 specs-configs: 232 lines / 224 non-blank, md5s ALL DISTINCT
mode        MT_COMPILE_ONLY=1, MT_SUITE_JOBS=6, all-gcc only, no target libgcc
subset      gcc.target/<cpu> ONLY -- one `.exp' per back end
tools       /tmp/tools-a7d26223eefcfa725: 45 cross `as', canonical names,
            every one EXECUTED, gathered by copy from six inherited dirs
LOAD        HIGH AND NOT THE PROMISED QUIET WINDOW.  1-minute load ran 15-53
            throughout, from other agents' concurrent `cc1plus' builds.
            34 of 47 rows are marked PROVISIONAL on the 1-minute load.
KILLED      24 real (mips 10, riscv 14), COUNTED AND NEVER SUBTRACTED.
            The scorer's own KILLED column reads a constant 1 -- see below.
```

## 1. THE BOARD — `gcc.target/<cpu>`, 28 scored

Raw PASS/FAIL. **These are NOT debt figures** — no stock control was run for
any of them on this subset, so nothing here is a regression count.

```
BACKEND      TRIPLE                          PASS    FAIL   KILLED
i386         x86_64-pc-linux-gnu            26323      74        0
riscv        riscv64-unknown-linux-gnu      41714     560       14
mips         mips64-unknown-elf             16478    1746       10
aarch64      aarch64-unknown-linux-gnu       4297     537        0
alpha        alpha-unknown-linux-gnu         2153      30        0
s390         s390x-ibm-linux-gnu             1875     164        0
arm          arm-unknown-eabi                1215      92        0
vax          vax-dec-linux-gnu                974    2225        0
bpf          bpf-unknown-none                 579       5        0
sh           sh-unknown-elf                   386      58        0
microblaze   microblaze-xilinx-elf            321     101        0
arc          arc-unknown-elf32                211     153        0
rx           rx-unknown-elf                   192      21        0
frv          frv-unknown-elf                  154       0        0
ia64         ia64-unknown-elf                 124       9        0
bfin         bfin-unknown-elf                  80       1        0
or1k         or1k-unknown-elf                  46       0        0
xtensa       xtensa-unknown-elf                50       4        0
csky         csky-unknown-elf                  41       3        0
visium       visium-unknown-elf                28       2        0
epiphany     epiphany-unknown-elf              19       5        0
avr          avr-unknown-elf                   17     125        0
nds32        nds32be-unknown-elf               15       0        0
rl78         rl78-unknown-elf                   8      30        0
h8300        h8300-unknown-elf                  6      24        0
xstormy16    xstormy16-unknown-elf              6     440        0
cris         cris-axis-elf                      3     174        0
v850         v850e1-unknown-elf                 1       0        0
```

`A7D26223EEFCFA725-ROWS.txt` is the stamped row file.

## 2. THE NINETEEN NOT SCORED — each by the artefact it is missing

Five distinct verdicts. Collapsing them is what made the previous table need
redoing, and one of them below was collapsed wrongly by the harness itself.

```
NO-EXP (9)          upstream has no gcc.target/<be> directory at all
  fr30 ft32 iq2000 lm32 m32r mcore mmix mn10300 moxie
  -- a statement about the TESTSUITE, not about the back end.

NOT-APPLICABLE (2)  gcn, nvptx
  LLVM's assembler and `ptxas'.  There is no GNU cross `as' to package and
  their absence says nothing about the back end.  THIRD VERDICT, distinct
  from "not probed" and from "conservative default".

DIED-FIRST-INPUT (4)  cc1 dies on `int f(int x){return x+1;}' -- no FAIL rows
                      at all, invisible to any .sum-based ranking
  c6x      SIGSEGV in c6x_print_operand, during RTL pass: final
  msp430   ICE in msp430_function_section, at config/msp430/msp430.cc:2466
  pru      ICE in pru_hard_regno_mode_ok, at config/pru/pru.cc:547
  m68k     driver refuses `-mcpu=m68020' (#218)

GUARD 3c REFUSED (3)  the target's own assembler rejected cc1's output
  rs6000   Error: .size expression for mt_as_probe does not evaluate to a constant
  pa       Error: expected symbol name / unrecognized symbol type "mt_as_probe"
  -- both are MALFORMED ASM-DECLARATION DIRECTIVES, i.e. the
     ASM_DECLARE_FUNCTION_* family, the same shape as the
     ASM_DECLARE_FUNCTION_NAME leak PRINCIPLES records for aarch64.

NOT-ELF (1)
  pdp11    `pdp11-dec-aout-readelf named no machine' -- it is an a.out target
           and GUARD 3c's machine arm is ELF-shaped.  An honest refusal, and a
           statement about the GUARD, not about pdp11.
```

**And one of those five was mis-attributed by the guard.** `sparc` is recorded
above under GUARD 3c's message *"the target's own assembler rejected the
compiler's output"*. It is not an assembler problem at all:

```
sparc64  -O0 -S   rc=0
sparc64  -O1 -S   ICE: 'only_leaf_regs_used' was called, but this compiler was
                  built without 'LEAF_REGISTERS' reaching shared code
                  [a T157-STUBS.md fail-by-name stub, working exactly as designed]
```

GUARD 3c runs `xgcc -O1 -c` and treats **any** nonzero rc as an assembler
rejection, so a compiler ICE is reported under the assembler's name. Three
different findings — malformed directives, a fail-by-name stub, and an a.out
target — arrive in one column with one message.

## 3. CAUSES RANKED — both orderings, because they disagree

`a7d26223eefcfa725-causes2.sh`. ICE-only; the environment bloc is reported
separately below rather than dropped.

```
=== ORDERING 1: by NUMBER OF BACK ENDS sharing the ICE (breadth) ===
  6  back end 'BE' has no pipeline automaton, but shared scheduling code
     compiled for a primary that has one is asking it for pipeline hazards
     backends: avr cris h8300 rl78 vax xstormy16
  2  Segmentation fault                       backends: mips visium
  1  verify_flow_info failed                  backends: aarch64
  1  maximum number of LRA assignment passes is achieved   backends: s390
  1  in mips_pop_asm_switch_N                 backends: mips
  1  in mips_load_store_insns                 backends: mips
  1  in lra_create_new_reg_with_unique_value, at lra.cc:N  backends: riscv
  1  in in_hard_reg_set_p, at regs.h:N        backends: i386
  1  in iaN_zero_call_used_regs               backends: ia64
  1  in extract_insn, at recog.cc:N           backends: vax
  1  in emit_move_insn, at expr.cc:N          backends: mips

=== ORDERING 2: by TOTAL RESULTS (volume) ===
   1449  no pipeline automaton
    420  Segmentation fault
     20  in extract_insn, at recog.cc:N
     15  in mips_pop_asm_switch_N
      7  in emit_move_insn, at expr.cc:N
      6  in mips_load_store_insns
      2  in lra_create_new_reg_with_unique_value
      2  in in_hard_reg_set_p, at regs.h:N
      1  verify_flow_info failed
      1  maximum number of LRA assignment passes is achieved
      1  in iaN_zero_call_used_regs
```

**The two orderings agree at the top for once, and that agreement is the
finding**: the DFA-absent case is both the widest and the largest cause.

The excluded environment bloc, stated rather than dropped — no target libc, no
libstdc++ and no linker exist in a `MT_COMPILE_ONLY` run, by construction:

```
 28 back ends    168 results  GCC is not configured to support
 28 back ends    139 results  C++ compiler not installed
 12 back ends    173 results  ld returned
  7 back ends   1058 results  no include path in which to search
```

## 4. THE BIGGEST FINDING — the DFA-absent defect is on ELEVEN back ends

`A7EE6CA7C923E4A58-BOARD.md` §5 records this as **avr's**, 6,084 rows, one back
end, and notes that it settles a PRINCIPLES item ("the DFA-absent case — both
configured bases have reservations" is listed among the things two back ends
cannot tell).

It is not avr's. On `int mt_one (int x) { return x + 1; }` at `-O2`, with
nothing else in the file, **eleven of the 45 targets with a specs-config ICE
with this diagnostic**:

```
avr  cris  ft32  h8300  mmix  moxie  msp430  pdp11  rl78  vax  xstormy16
```

The `.sum`-based ranking sees only six of them, and not because the other five
are fine: `ft32`, `mmix`, `mn10300`, `moxie` are `NO-EXP` (no `gcc.target`
directory to run) and `msp430` had already died at `-O0` for a different
reason. **A cause on eleven back ends was recorded as one back end's, twice.**

## 5. THE PRECONDITION HAS THE BLIND SPOT IT EXISTS TO REMOVE

This is the task's own null-result requirement, turned on the instrument that
was supposed to satisfy it.

`a7ee6ca7c923e4a58-onelinecensus.sh` and the scorer's `DIED-FIRST-INPUT` arm
exist because *"a back end that dies on its first input contributes no FAIL
rows and is invisible to a `.sum`-based ranking, exactly like one never
attempted and one that passed everything."* Both compile the one-line function
with `-S` and **no `-O`**. Measured over all 45
(`A7D26223EEFCFA725-OLEVEL-CENSUS.txt`):

```
-O0 ok = 38      -O1 ok = 37      -O2 ok = 28
```

**Ten back ends compile a one-line function at `-O0` and ICE at `-O2`**, and
`gcc.target` is compiled mostly at `-O2`. So `-O0` is the least representative
single level available, and a precondition that probes only there reproduces
the exact blindness it was written to remove, one optimisation level down.
sparc is the worked example: it passed the precondition, was sent to the suite,
and was refused there under the wrong cause.

## 6. FOUR INSTRUMENT DEFECTS FOUND BY READING ROWS AGAINST THEIR ARTEFACTS

1. **`agent-acda89931a903ec27-specs.sh` `&&`-chains all 47 targets into one
   command.** m68k (#218) fails in the middle, so 23 targets were **never
   attempted** and every one was reported as `has an as; target-specs produced
   nothing`. It read `OK=21 SPECS-FAIL=24`; the truth is **45 OK, 0 FAIL**.
   "Never attempted" and "failed" as the same silence — PRINCIPLES' `-k` rule
   in a new place, failing in the direction that makes the branch look worse.
2. **The scorer's `KILLED` column is a constant 1.** `grep -ci 'killed'`
   matches `mtcheck.sh`'s own section LABEL. A target that killed three
   compilers would also read 1. Real total: **24** (mips 10, riscv 14).
3. **The `PROVISIONAL` gate reads the 15-minute load average.** For a run
   taking minutes that still reports the quiet period BEFORE the run started:
   aarch64 scored at a 1-minute load of 43.22 against a 15-minute 18.53 and was
   not marked.
4. **`agent-acda89931a903ec27-causes.sh` cannot see a self-describing
   diagnostic.** This branch's best messages name the back end (`back end 'vax'
   has no pipeline automaton...`), so one shared defect keys as N distinct
   causes and never reaches the top of a breadth ranking. Compounded by
   `s/[0-9]*/N/g` mangling `xstormy16` -> `xstormyN`, and by a back-end list
   built with `!~` (a REGEX substring match), which is why its output shows
   `28` beside 27 listed back ends. All four corrected in
   `a7d26223eefcfa725-causes2.sh`.

Also: **the 45 `<triple>-readelf` in the inherited tools dir have ONE md5
between them** — one multi-arch binary under 45 names, which
`agent-acda89931a903ec27-fulltools.sh` refuses in its own header and a later
sweep did anyway. GUARD 3c's machine arm is still meaningful (it tests what the
ASSEMBLER produced), but "45 readelf" is not 45 pieces of evidence.

## 7. WHAT IS *NOT* HERE — UNKNOWN, never zero

- **No stock control on this subset**, so **no debt figure for any row**.
- **No execution.** No target libgcc; a PASS means "it compiled and matched".
- **34 of 47 rows are PROVISIONAL on load** (1-minute load 15-53 from other
  agents' builds). The brief's promised quiet window did not hold.
- **9 back ends have no `gcc.target` directory upstream** and cannot be scored
  on this axis at all, by any amount of packaging.
- **Whether the 28 scored rows are stable was not tested.** PRINCIPLES records
  mips64 giving 5 rc=0 and 7 SIGSEGV in twelve identical runs, and ia64 five
  distinct outcomes in eight. mips and ia64 are both on this board and both
  were run **once**. `STABLE` is an arm and it was not run.
- **The `-O0`/`-O1`/`-O2` census is a one-line function**, not a claim about
  each back end's whole test set.

## 8. WHAT I WOULD HAND THE NEXT AGENT, IN ORDER

1. **The DFA-absent case on eleven back ends.** Widest AND largest cause;
   recorded as one back end's twice. Shared scheduling code compiled against
   the primary's automaton, asked about back ends that have none.
2. **Run the `-O2` arm of the precondition before any future board**, and fix
   GUARD 3c to distinguish a compiler ICE from an assembler rejection — three
   findings currently share one message.
3. **`ASM_DECLARE_FUNCTION_*` for rs6000 and pa.** Both emit directives their
   own assembler refuses on a one-line function; same family as the
   `ASM_DECLARE_FUNCTION_NAME` leak already recorded for aarch64. Fixing it
   unblocks powerpc's ~1379 `scan-assembler` tests, the largest such population
   of any back end.
4. **Stability arm on mips, ia64 and visium** before their rows are quoted.
5. **c6x's SIGSEGV in `c6x_print_operand`** and **pru's
   `pru_hard_regno_mode_ok`** — dead on any input, one-line reproducers.
6. **vax's 2,225 FAILs** — the worst FAIL:PASS ratio of any scored back end,
   and 1,073 of them are the DFA cause, so item 1 covers most of it.
7. **xstormy16's 440 FAILs against 6 PASSes.**
