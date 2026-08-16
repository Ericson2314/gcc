# THE 47-BACK-END BOARD: what can be run, what was run, and the causes MANY back ends share

Answers the user's question -- *"can we run every backend against tests? at
least against register diff tests?"* -- with numbers rather than a plan.

**Short answer: no, and the blocker is not GCC.** 17 of 47 can be attempted;
30 are blocked on a missing cross assembler that nixpkgs cannot package. Of
the 17, **10 produced a score** and **7 were refused by a guard**, each by
name. That is up from **4 back ends ever scored** and 6 that ever had a test
result of any kind.

## PROVENANCE -- quote this with any row

```
srcdir      /tmp/snap-agent-a7ee6ca7c923e4a58
            git archive of e3fac057ae4, read-only, SNAP-SHA stamped
anchor      grep -c MULTI_TARGET gcc/Makefile.in = 52   (MEASURED, not copied)
build       /tmp/b-a7ee6ca7c923e4a58, 47 triples from backends-47.txt
            make all-gcc rc=0;  `error:' 0;  multiple definition 0;
            undefined reference 0;  Killed 0;  cc1 links (230,932,208 bytes);
            47 mt-<cpu>/ directories for 47 distinct cpu_types
bars        x86_64 -O2 big.c    12369 bytes / md5 378fc33c1e70   (== recorded)
            specs-config x86_64 cfbc7a65e54e   aarch64 575aff0c188b
                         riscv64 9af7409ac460  s390x   37901805bf3c  (all ==)
            all 17 specs-configs: 232 lines / 224 non-blank, md5s ALL DISTINCT
            -g md5 0e254114328e != recorded 2145c3034ed2 -- PATH-SENSITIVE,
              different build dir name; not a regression, and not quotable bare
mode        MT_COMPILE_ONLY=1, -j6, all-gcc only, no target libgcc anywhere
subset      gcc.c-torture/compile ONLY -- see "WHAT IS NOT HERE"
tools       real cross binutils 2.46 per target, via nixpkgs crossSystem.config
guards      per target: specs-config exists, cc1 NAMES THE TARGET BACK,
            non-vacuity of -ftarget-config=, mt-specsread 4 arms, GUARD 3c the
            target's OWN assembler with a readelf machine check, site.exp
            attribution, multi-target.exp banner, and a per-target `.rc'
load        first 5 targets scored at 28-34 (another agent's -j16 run);
            last 5 at 5-20.  **The first five rows are PROVISIONAL on load.**
KILLED      0, counted and never subtracted
```

## 1. WHAT CAN BE ATTEMPTED AT ALL -- 47 back ends

Full table: `A7EE6CA7C923E4A58-STAGE1-TABLE.txt`.

```
READY        17    assembler + specs-config both present
NO-CROSS-AS  30    nixpkgs lib.systems: `Unknown CPU type'
```

**The 30 are blocked on PACKAGING, not on GCC**, and the distinction is the
whole point of the table: *"no cross `as` packaged"* and *"the compiler ICEs on
every input"* are different findings. `ia64`, `hppa64`, `bfin` and `cris` have
been in binutils for decades; nixpkgs' CPU table has 50 entries and does not
name them. Nothing here says whether those back ends emit correct code.

**Why the assembler is a hard gate -- the brief and I both had this wrong.**
`TAA-BOARD.md` 3 records the ruling that a `scan-assembler` test needs no
assembler. True of the TESTS, false of this HARNESS: `target-specs` refuses by
name without a real cross `as`, and `specs-config` is a precondition of
`mtcheck.sh` GUARD 1. **That refusal is correct and was not relaxed** -- it is
what prevents the host-`as` defect worth ~10,000 results per target. The honest
ceiling is nixpkgs', and 17 with the guard intact beats a bigger number without
it.

**`TAA-BOARD.md` 4b's "nixpkgs has no binutils for visium or xtensa (0 of
27,157 attributes)" is about the curated `pkgsCross` set, not about binutils.**
Requesting a triple through `crossSystem.config` produced real assemblers for
13 back ends with no `pkgsCross` attribute. **But the correction is narrower
than it first looked: `visium` and `xtensa` -- the two targets that claim was
about -- are both in the `Unknown CPU type` set, so their UNTRUSTED verdicts
SURVIVE.**

## 2. THE BOARD -- `gcc.c-torture/compile`, 10 scored

```
BACK END     TARGET                          PASS     FAIL   UNSUP   ICE rows
i386         x86_64-pc-linux-gnu            14853        0     134          0
aarch64      aarch64-unknown-linux-gnu      14792        0     188          0
s390         s390x-ibm-linux-gnu            14782        9     189          0
riscv        riscv64-unknown-linux-gnu      14752       64     196         32
or1k         or1k-unknown-elf               14589      246     262        117
alpha        alpha-unknown-linux-gnu        12335     4039     284       1685
mips         mips64-unknown-elf             11998     5129     395       2535
arm          arm-unknown-eabi               11593     2985     436         27
arc          arc-unknown-elf32               8589     2010     397        121
avr          avr-unknown-elf                 8258    12495     377       6185
```

**These are RAW PASS/FAIL, and for the six new back ends they are explicitly
NOT a debt figure**, because no stock control exists for them. Only the four
with existing controls could be stated as debt, and this subset is too narrow
to restate `AB1900D5279BA137F-BOARD.md`'s debts against.

The four previously-scored targets fail **0, 0, 9 and 64** here. That is a
genuine control: the subset and harness are not intrinsically hostile, so the
six new rows are the signal. **or1k, never scored before, comes in at 246 --
better than four of the back ends that have had attention for weeks.**

## 3. THE SEVEN BLOCKED, EACH BY THE ARTEFACT IT IS MISSING

Blocked is not failed and is not "never attempted"; all three are distinct and
stamped.

```
microblaze  segfault in avr-fuse-add        -- SHARED, see 5
rx          segfault in avr-fuse-add        -- SHARED
sh          segfault in avr-fuse-add        -- SHARED
mmix        no assembler-directive table    -- family of 4, see 5
msp430      ICE msp430_function_section, at config/msp430/msp430.cc:2466
sparc64     ICE sparc_asm_function_prologue, at config/sparc/sparc.cc:6224
m68k        driver rejects `-mcpu=m68020'   -- see A7EE...-M68K-OPTION-DEFAULT.md
```

Every one was caught by a guard refusing to score, not by a bad number.

## 4. CAUSES RANKED BY HOW MANY BACK ENDS CARRY THEM

The deliverable. Both orderings are printed because they disagree, and a
single ranking hides whichever it is not sorted by.

```
BE   ROWS   SITE
6    71     in extract_insn, at recog.cc:2892
4    68     in simplify_subreg, at simplify-rtx.cc:8549
3    669    in emit_move_insn, at expr.cc:4670
2    2527   Segmentation fault                    (mips64 2512, or1k 15)
2    1092   in expand_call, at calls.cc:3978      (alpha 1048, arc 44)
2    107    in lra_create_new_reg_with_unique_value, at lra.cc:192
1    6084   back end 'avr' has no pipeline automaton ...
```

**`extract_insn, at recog.cc:2892` is on SIX of the ten** -- alpha, arc, arm,
avr, mips64, or1k. `TAA-BOARD.md` 4 records this site as T173's headline at
**5,103 occurrences** and then notes it *"does not appear at all in this run
-- someone fixed it"*. **It was never fixed. It was invisible**, because the
only back ends carrying it had never been scored.

**`simplify_subreg` is exactly 17 rows on each of arc, arm, avr and or1k** --
an identical count on four unrelated back ends is the signature of one shared
defect on one shared test set, not four coincidences.

## 5. THE TWO BIGGEST FINDINGS, BOTH HANDED BACK

### `avr-fuse-add` runs for EVERY back end -- `A7EE6CA7C923E4A58-AVR-PASS.md`

An AVR RTL pass with **no `gate` override** (so `rtl_opt_pass`'s always-true
default applies) writes `func->machine->n_avr_fuse_add_executed += 1`
**before** its own `if (optimize && ...)` guard. Every back end declares its
own `machine_function`; the pass reads it as AVR's. **microblaze, rx and sh
segfault on `int f(int x){return x+1;}` at `-O0`.**

Registered through `PASSES_EXTRA`, collected once for the legacy single
`${target}` -- the **same shape as `extra_headers`**, worth 62,464 results on
aarch64 alone.

**The 8 back ends that compiled it cleanly are NOT proven fine.** A segfault
needs the write to land outside the allocation; a back end whose
`machine_function` is merely large enough takes it silently. **3 LOUD / 8
UNVERIFIED**, and the 8 are an upper bound on "unaffected". `avr` is itself in
the quiet column and is the one back end for which the write is correct by
construction -- which is why this survived.

### `avr` has no pipeline automaton -- 6,084 rows, and it settles a PRINCIPLES item

```
back end 'avr' has no pipeline automaton, but shared scheduling code compiled
for a primary that has one is asking it for pipeline hazards
```

**PRINCIPLES 1 lists "The DFA-absent case -- both configured bases have
reservations" among the things two back ends CANNOT TELL.** avr tells it. This
is the single largest cause by volume on the board and it is a textbook "one
name, several authorities": shared scheduling code compiled against the
primary's DFA, asked about a back end that has none. The diagnostic is
self-describing, which means someone anticipated it; nothing had ever reached
it.

Its sibling, `mmix`'s `back end 'mmix' has no assembler-directive table;
gen-multi-target-md.awk omits one for mmix and for the back ends sharing
default-common.cc`, is the same shape. Measured from the manifest, that family
is **mmix + ft32, moxie, rl78 = 4 back ends**; the other three are
NO-CROSS-AS, so it currently costs one scorable target.

## 6. WHAT IS *NOT* HERE -- UNKNOWN, never zero

- **The subset is `gcc.c-torture/compile` and nothing else.** ~15,000 results
  per target; every test compiles to an object with no libc, linker or
  execution, so it means the same thing on all 47. **Excluded and logged:** all
  of `gcc.dg` (part needs `<stdlib.h>`, which the bare-metal ELF targets have
  no headers for), `gcc.dg/{vect,torture,params,tree-ssa}`, `c-c++-common`,
  `gcc.misc-tests`, `gcc.c-torture/execute`, and **`gcc.target/<cpu>`**.
  `gcc.target` is excluded deliberately and it costs something real -- it is
  where `scan-assembler` divergence lives and the only axis riscv64's
  1,111-result wrong-code residual appeared on -- but its `.exp` name differs
  per back end and several targets have almost nothing there, so including it
  would make the across-target comparison inconsistent. **These numbers are a
  FLOOR on each back end's trouble, never a whole-suite figure.**
- **No execution.** No target libgcc exists; a PASS means "it compiled".
- **No stock control for the six new back ends**, so no debt figure for them.
- **30 back ends have no result of any kind**, and that is a statement about
  nixpkgs, not about them.
- **The first five rows were scored at load 28-34** and are provisional.
- **Whether the 8 quiet back ends are corrupted by `avr-fuse-add` is not
  established** and needs a both-sided assembly diff.

## 7. WHAT I WOULD HAND THE NEXT AGENT, IN ORDER

1. **`avr-fuse-add`'s missing gate.** 3 back ends dead on any input, 8
   unverified, one-line reproducer. Gating this one pass is NOT the fix --
   `avr_pass_casesi` and `avr_pass_ifelse` in the same file gate on
   `optimize > 0` and nothing about the target. It is a `PASSES_EXTRA`
   collection defect, like `extra_headers` before it.
2. **`extract_insn, at recog.cc:2892` on six back ends.** Believed fixed for
   two boards; it was hidden.
3. **The DFA-absent case, 6,084 rows on avr**, settling a question PRINCIPLES
   records as unanswerable with two back ends.
4. **mips64's 2,512 segfaults** -- half its FAIL column, one back end.
5. **alpha's 1,048 `expand_call`.**
6. **Package the 30 missing assemblers**, or route around nixpkgs. This is
   worth more than any single cause above: it is the difference between 17 of
   47 and 47 of 47, and it is not a GCC problem.
7. **m68k's `-mcpu=m68020`** -- one back end, exactly located, and the fix must
   not special-case m68k.
