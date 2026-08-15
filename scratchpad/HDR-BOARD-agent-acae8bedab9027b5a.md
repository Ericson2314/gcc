# `gcc.target/aarch64` — the header fix, and the leak it uncovered

Two defects, both `mechanism-present-but-never-invoked`, both measured by
running the suite three times over the same test selection with three
compilers that differ only by one commit each.

## 1. THE BOARD — `gcc.target/aarch64` only, same selection every run

```
build                    what it has                        PASS     FAIL    UNRES
/tmp/b-acae8bedab9027b5a   976a5c55392, neither fix        11453    74298   118309
   ...-2                   + include-<base> on the path   140372    27494    39377
   ...-3                   + per-base register aliases    155521    37171    23729

stock upstream (SC-BOARD.md §3a, c31b7a09eea)               211477     2260        -
recorded multi-target figure that debt was priced on          6441    75306        -
```

`+144,068 PASS` against the run this branch's own tree produced before either
fix, and `+149,080` against the 6,441 the 194,711-result debt was priced on.
`UNRESOLVED` fell by 94,580, which is the column that matters: it is "the
compilation failed so the test could not be run".

FAIL rises between `-2` and `-3` **and that is the fix landing**: a test that
died on `invalid register name` was one UNRESOLVED; the same test compiling
produces twenty `scan-assembler` results, some of which fail. PASS `+15,149`
against UNRES `−15,648` in that step.

Provenance, quoted with the commands in `scratchpad/mt-*.sh`:

```
srcdirs   /tmp/snap-agent-acae8bedab9027b5a{,-2,-3}  (git archive, read-only,
          SNAP-SHA 976a5c55392 / 6a4fbef57a5 / 1e07c7fa039), anchor 49 all three
configure --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu
          NOT `i386,aarch64': the bare back-end names map to
          `aarch64-unknown-none', which config.gcc does not support, and the
          build dies in configure-gcc.  Pass triples.
build     make all-gcc rc=0, `error:' 0, `multiple definition' 0, KILLED 0
specs     mt-specs.sh, real cross binutils
mode      MT_COMPILE_ONLY=1, mtcheck.sh, all four guards + the site.exp
          post-condition + the multi-target.exp banner, on every run
selection the 24 `.exp' files of gcc/testsuite/gcc.target/aarch64
KILLED     0 on all three runs.  Load at scoring 4.7 / 8.2 / 5.9.  Run -2
           spanned load 26 -> 1; runs -1 and -3 ran at 8-13.
bars       x86_64 -O2 big.c = 12369 / 378fc33c1e70 on -2 and -3, unmoved
           specs-config 232 / cfbc7a65e54e (x86_64), 575aff0c188b (aarch64)
```

The 6,441 in `SC-BOARD.md` is **not stale bookkeeping and not wrong**: it was
taken at `555482db346`, which is *before* `96b3c183b51` landed the per-back-end
`include-<cpu>/` directories. My own pre-fix run of the same selection reads
11,453, i.e. the same order of magnitude from a later tree.

## 2. `include-<base>` WAS BUILT, INSTALLED, NAMED — AND NEVER SEARCHED

Everything about `extra_headers` was already right. `accumulate_extra_headers`
in `gen-multi-target-md.awk:2440` unions over **every** manifest record for a
back end (so it does *not* have #191's first-record bug), `include-aarch64/`
holds exactly the nine headers `config.gcc:362-370` names plus the stamp — ten
is the correct count, against i386's 120 — and `install-headers` copies it to
`$(libsubdir)/include-<base>`, which is exactly what `cppdefault.cc:207` names.

What no arm had asked is whether a compilation opens it. It does not, in a
build tree:

```
ignoring nonexistent directory
  "/tmp/b-.../gcc/../lib/gcc/17.0.0/include-aarch64"
```

while the headers sit in `<builddir>/gcc/include-aarch64`. The plain `include/`
directory is in **exactly** the same position — it is also reported nonexistent
under `$(libsubdir)` — and has always been rescued by the driver spec `%I`,
which walks the exec prefixes appending `include`. The per-back-end directory
now takes the same route (`multi_target_options_base ()`, gcc.cc `%I`).

Both-sided, on the same compiler:

```
-ftarget-config=<aarch64>   include-aarch64  then include  then aarch64 glibc
-ftarget-config=<x86_64>    include-i386     then include  then x86_64 glibc
```

## 3. `ADDITIONAL_REGISTER_NAMES` — the other half of the register vocabulary

`REGISTER_NAMES` is per base in `struct target_regs_desc`.
`ADDITIONAL_REGISTER_NAMES` and `OVERLAPPING_REGISTER_NAMES` were still two
`#ifdef` blocks in `varasm.cc`, a middle-end TU, so every base had i386's
`eax`/`ax`/`al` as its complete set of aliases. Measured on the linked `cc1`:

```
aarch64 selected                     after the fix
  register int v0 __asm__("v0");  ok    ok      <- REGISTER_NAMES, already per base
  register int x1 __asm__("x1");  ok    ok
  register int z0 __asm__("z0");  ERR   ok      <- the macro, i386's
  register int w2 __asm__("w2");  ERR   ok
x86_64 selected
  register int eax __asm__("eax");      ok      <- unchanged
  register int al  __asm__("al");       ok
  register int z0  __asm__("z0");       ERR     <- negative control: aarch64's
                                                   alias must NOT leak to x86
```

In one `gcc.target/aarch64` run that macro was worth **1,041,532** occurrences
of `invalid register name for 'zN'`, 462,112 for `'pnN'` and 283,212 for
`'wN'`: the SVE/SME ACLE asm tests declare their operands as named-register
variables, so `sve/acle/asm`, `sve2/acle/asm`, `sme/acle-asm` and
`sme2/acle-asm` failed wholesale on it. After the fix that diagnostic is **0**.

## 4. WHAT IS NEXT, MEASURED RATHER THAN GUESSED

The residual after both fixes, from `-3`'s `gcc.log`:

```
23154  internal compiler error: in lra_split_hard_reg_for, at lra-assigns.cc
 9315  internal compiler error: in final_scan_insn_1, at final.cc
 7718  error: unable to find a register to spill
 3105  error: could not split insn
 1884  maximum number of LRA assignment passes is achieved
 1850  error: lane N out of range
```

The register-allocation family is now the top cause and it is the shape of
another per-base register-set leak (the ACLE asm tests pin specific hard
registers, so anything wrong in `fixed_regs`, `call_used_regs`, the class
contents or the SVE predicate classes surfaces here first). It was invisible
before, because these tests never got past the preprocessor.

Remaining distance to stock in this directory: `211477 − 155521 = 55,956`
results, an upper bound on the residual debt — the debt proper is a per-test
name diff against the stock `.sum`, which this task did not re-run.
