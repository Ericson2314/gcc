# THE PER-TARGET TESTSUITE BOARD AT SIX TARGETS

Extends `T173-BASELINE.md` / `T175-board.txt` (x86_64 + aarch64) with
**riscv64** and **s390x** -- two back ends that had never had a test result of
any kind. **2 of 47 measured becomes 6 of 47** (four with real cross binutils, two through a fallback config -- see §4b). Read §6 before quoting §2.

## 1. Provenance -- quote this with the board

```
srcdir      /tmp/snap-agent-aa9936ad7ccd9023c
            (git archive of 555482db346, read-only, no .git at all)
anchor      grep -c MULTI_TARGET gcc/Makefile.in = 49   (measured, not quoted)
build       /tmp/b-agent-aa9936ad7ccd9023c
            --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu,
                             riscv64-unknown-linux-gnu,s390x-linux-gnu
            make all-gcc rc=0; `error:' 0; multiple definition 0;
            undefined reference 0
specs       x86_64  230 lines / md5 a6c4c68bdf33   (== PRINCIPLES' recorded bar)
            aarch64 230 lines / md5 f1a5ab201d95   (== PRINCIPLES' recorded bar)
            riscv64 230 lines / md5 9f68be7da0d2   (new)
            s390x   230 lines / md5 46aad87470b1   (new)
            four DISTINCT md5s -- guard 6 refuses the run if any two coincide
codegen bar cc1 -quiet -nostdinc -O2 -ftarget-config=<x86_64 cfg> \
              scratchpad/big.c -o x.s
            = 12369 bytes / md5 378fc33c1e70
            i.e. the recorded TWO-base bar, reproduced byte for byte at FOUR
            bases.  aarch64 on the same command: 12391 / dca9f5ff0b79 (the
            brief's 12196 / 9edf6aa6616c is a different commit and is not
            comparable; no regression is claimed either way).
mode        MT_COMPILE_ONLY=1, make -j6, dejagnu 1.6.3, all-gcc only.
            No target libgcc exists anywhere in this build, so a PASS means
            "it compiled", never "it computes the right answer".
tools       real cross binutils per target (nixpkgs
            pkgsCross.{aarch64-multiplatform,riscv64,s390x}) and each target's
            OWN glibc headers; scratchpad/taa-tools.sh
```

## 2. THE BOARD

```
TARGET                             PASS     FAIL    XPASS    XFAIL    UNSUP    UNRES    ERROR
x86_64-pc-linux-gnu              162118    16340        3     1556     4451    13366       26
aarch64-unknown-linux-gnu         88001    98027        3      832    11012   133394       26
riscv64-unknown-linux-gnu         75980    90931        4      626    23415    97787       27
s390x-ibm-linux-gnu               90464    46009        5      651     7811    13948       29

KILLED (NOT a test result):  x86_64 0   aarch64 2   riscv64 0   s390x 0
load at scoring time: 2.81 / 6.57 / 10.33   (the runs themselves saw 8-25)
```

**KILLED is its own column and is never subtracted.** aarch64's 2 are
`cc1 terminated by signal 9`, recorded by DejaGnu as ordinary FAILs.

**Delta against the recorded boards** (`T173-board.txt` / `T175-board.txt`,
commit `80bf400ae06`, two bases; this run is `555482db346`, four bases -- two
variables move at once, so read these as agreement, not as an experiment):

```
              T173 PASS/FAIL     T175 PASS/FAIL     HERE PASS/FAIL
x86_64        162165 / 16290     162165 / 16290     162118 / 16340
aarch64        83158 / 106277     88017 / 98009      88001 / 98027
```

x86_64 moves by 47 PASS / 50 FAIL and aarch64 reproduces T175 to within 16 --
so **adding two back ends did not disturb the two already on the board.**
That is the useful reading; it is not evidence about the new pair.

## 3. THE scan-assembler BOARD -- `gcc.target/<dir>`, per target

Per the user's ruling: a `scan-assembler` test needs no libgcc, no linker, no
execution and **no assembler**. It compiles to `.s` and greps the text.

```
target    dir        PASS    FAIL   XFAIL   UNSUP   UNRES        FAIL kinds (whole run)
x86_64    i386      26574      90      34     585       8   scan-asm 45   excess-err 12457  ICE 10
aarch64   aarch64    6441   75306      83    4697  122813   scan-asm 225  excess-err 86736  ICE 596
riscv64   riscv      5506   57475      20   16834   87670   scan-asm 116  excess-err 50562  ICE 33779
s390x     s390       2225     599       1     201     540   scan-asm 219  excess-err 28424  ICE 11189
```

**The control behaves**: x86_64 is 26574/90 in its own directory, i.e. the
primary is served correctly. **aarch64-minus-x86_64 on the same instrument is
the signal, and it is enormous.**

**AND THE HONEST FINDING ABOUT THE INSTRUMENT ITSELF: most tests never reach
the scan.** aarch64 has 225 `scan-assembler` failures against 86,736 "excess
errors" -- the compiler rejects or ICEs on the input long before anything is
emitted to grep. So `scan-assembler` is the right instrument for the defect
class and it is **not yet the binding constraint**; the diagnostics in §4 are.
Expect the scan-assembler numbers to grow as those are fixed.

Real scan-assembler failures do exist and each names its own reproducer, e.g.

```
aarch64  gcc.target/aarch64/simd_pcs_attribute-3.c
           scan-assembler-times \.variant_pcs\t_ZGVnM2v_foo 1
aarch64  scan-assembler-times and\tw0, w1, 1 10        (x4 tests)
aarch64  scan-assembler .section\t.note.gnu.property   (x4)
s390x    scan-assembler-times nopr\t%r0 1              (at -O1 -O2 -O3 -Os)
s390x    scan-assembler pre-label.*(1 halfwords)       (hotpatch alignment)
riscv64  scan-assembler \mth.swia[^\n\r]*-4,0\M        (XTheadMemIdx)
```

## 4. CAUSES -- what the compiler actually said

Counts are occurrences in the merged `gcc.log`; each diagnostic appears about
three times there (the compiler line, the excess-errors echo, the summary), so
**read the ranking, not the absolute number**.

**aarch64 -- the top cause is not codegen at all, it is a missing header, and
it is a new member of a family PRINCIPLES already lists.**

```
62464  error: arm_neon_sve_bridge.h: No such file or directory
 2900  error: arm_neon.h: No such file or directory
  571  error: arm_sve.h: No such file or directory
```

`ls <builddir>/gcc/include/` contains **only i386's intrinsic headers**
(`adxintrin.h` ... `avx512*`); there is no `arm_neon.h` anywhere in the build
dir. `extra_headers` is set per target in `config.gcc` (`config.gcc:368` adds
`arm_neon_sve_bridge.h`) and, like `tmake_file`, `extra_objs`, `c_target_objs`,
`target_gtfiles` and `out_file` before it, **it is collected once for the
legacy single `${target}` rather than per configured back end** -- the
`PASSES_EXTRA` shape exactly. Named failing test:
`gcc.target/aarch64/pch/pch_arm_neon.c`.

This one cause plausibly accounts for the bulk of aarch64's FAIL and UNRESOLVED
columns. It is a build-system fix, not a correctness fix, and per the standing
priority rule it should be taken before any of the ICEs below.

aarch64 ICE sites (ranked):

```
509  in gen_lowpart_general, at rtlhooks.cc:57
 68  in aarch64_output_casesi, at config/aarch64/aarch64.cc
  7  in maybe_record_trace_start, at dwarf2cfi.cc
  6  Segmentation fault
```

`extract_insn, at recog.cc:2892` -- **5,103 occurrences and the headline of
T173 -- does not appear at all in this run.** Someone fixed it between
`80bf400ae06` and `555482db346`. `gen_lowpart_general` (T173's second cause,
509) is unchanged, to the occurrence.

**riscv64 -- one cause, ~27k diagnostics, and it is the same one that breaks
the driver.**

```
26718  internal compiler error: in default_version, at
       common/config/riscv/riscv-common.cc:162
 2529  in as_a, at machmode.h:416
 1748  in operand_subword_force, at emit-rtl.cc
  977  in convert_mode_scalar, at expr.cc:737
 1587  error: gnu/stubs-ilp32.h: No such file or directory
```

The same site aborts `configure-target-specs-riscv64-unknown-linux-gnu` (from
`riscv_expand_arch` in a self-spec) and is the same defect as the empty
`.attribute arch, ""` PRINCIPLES records: **riscv's arch string is empty**, so
a real `riscv64-unknown-linux-gnu-as` refuses the output:

```
riscv64...s:3: Error: the architecture string of -march and elf architecture
attributes cannot be empty
```

Fix that one and roughly a third of riscv's board changes character.

**s390x**

```
5782  in as_a, at machmode.h:416      (also the failure of the big.c bar:
                                      trunc_int_for_mode <- gen_int_mode <-
                                      create_integer_operand, on
                                      __builtin_memcpy, RTL pass expand)
4257  Segmentation fault
1295  in s390_match_ccmode_set, at config/s390/s390.cc
```

s390x is the **best-behaved of the three non-primary targets** (2225/599 in its
own directory) and its 219 scan-assembler failures are the most likely place to
find real per-target codegen divergence today.

## 4b. VISIUM AND XTENSA -- two more back ends, through a FALLBACK config

`scan-assembler` needs no assembler, but the harness needs a `specs-config`,
and `target-specs` probes `<triple>-as` and SKIPs without one. nixpkgs has no
binutils for visium or xtensa (0 of 27,157 attributes, #170). So the #170
technique was used on purpose: point `target-specs` at the BUILD MACHINE'S own
`as`/`ld` (`taa-fallback-specs.sh`). **This is the #113b accident, requested
deliberately**, and everything it produces carries that caveat:

- **ASSEMBLES and ELF-MACHINE stay UNKNOWN** for both. No output can promote
  them; there is no assembler to be right about.
- **Any verdict that depends on an assembler CAPABILITY** (`.hidden`, TLS,
  CFI, section flags) is reading x86_64's answer under this target's name.
  Those are UNTRUSTED -- neither PASS nor FAIL.
- The two configs happen to have distinct md5s (`47f002363b48`,
  `ecd8ee496205`), so guard 6 passed; had they coincided the guard would have
  refused, correctly, and the answer would have been to run them separately,
  never to relax it.

Second build dir, same snapshot: `/tmp/b-agent-aa9936ad7ccd9023c-6`,
**six** bases (the four above plus `visium-elf`, `xtensa-elf`),
`make all-gcc rc=0`, `error:` 0.

```
TARGET                             PASS     FAIL    XPASS    XFAIL    UNSUP    UNRES    ERROR
visium-unknown-elf                73704    53439        8      607     8250    14016       29
xtensa-unknown-elf                83083    41571        8      624     6056    14173       29
KILLED: 0 and 0.  load at scoring: 17.94 / 17.40 / 15.35

gcc.target/<dir>       PASS  FAIL  XFAIL  UNSUP  UNRES     FAIL kinds (whole run)
visium/visium             8    19      2      0      7   scan-asm  11  ICE 16604
xtensa/xtensa            44    10      0      0      3   scan-asm   5  ICE  8182
```

Their own `gcc.target/` directories are tiny upstream (29 and 57 results), so
the interesting column is the whole-run one. **6 of 47 back ends now have a
test result; it was 2.**

## 4c. THE SAME THREE ICE SITES ON EVERY NON-PRIMARY TARGET

Read across §4 and §4b rather than down them:

```
site                                    s390x   riscv64  visium  xtensa
in as_a, at machmode.h:416               5782     2529     1816    4443
in operand_subword_force, at emit-rtl.cc    -     1748     1504    1256
in convert_mode_scalar, at expr.cc:737      -      977        -     757
Segmentation fault                       4257        -    13215     519
```

Four back ends, three shared middle-end sites, and `as_a, at machmode.h:416`
on all four. That is not four back-end bugs; it is the shape of one
mode-vocabulary defect reaching every base that is not the primary --
`as_a<scalar_int_mode>` failing means the mode reaching `trunc_int_for_mode`
is not a scalar int for THAT base. The same ICE stops the `big.c` bar on
s390x. **x86_64 has 10 ICEs in the entire run**; this is the both-sided shape.

Whoever takes it has a free reproducer: `scratchpad/big.c` at `-O2` with the
s390x config, failing on `__builtin_memcpy` at `big.c:57`.

## 5. WHAT THE NUMBERS DO NOT MEAN

- **No failure floor is subtracted anywhere.**
- **`dg-do run`/`link`/`assemble` were downgraded to `compile`**, so those
  tests are not evidence about execution. The downgrade is implemented by
  renaming `dg-do`, so it reaches only tests that declare their action that
  way. What it cannot reach is now **counted** rather than assumed
  (`taa-mtscore.sh`): per target, ~1,250-1,300 gcov results and 5-106
  execution-shaped results still linked and ran. `gcc.misc-tests/gcov-19.c`
  alone is 940 FAILs on **every** target -- identical on all four, therefore
  not a multi-target observation.
- **UNRESOLVED is its own column and is never folded in.** aarch64's 133,394
  and riscv's 97,787 are overwhelmingly "the compilation failed so the test
  could not be run", i.e. the same causes as §4 counted a second way.
- **The cross-target delta is the signal; the common part is the build's
  shape.**

## 6. PROVISIONAL, AND WHY

- The machine carried other agents throughout; load was 8-25 during the runs
  and 2.8 at scoring. Two aarch64 compilations were OOM-killed and are in the
  KILLED column. Fine for the cause-level conclusions in §3-§4, which rest on
  counts in the thousands; **not** fine for diffing this board test by test.
- An earlier attempt at this board was destroyed mid-run when `/tmp/b-aa99`
  and `/tmp/snap-aa99` were deleted by a coordinator `/tmp` sweep. Those
  results were discarded, not repaired. **This run was taken entirely after
  that event**, from a fresh snapshot and a fresh build dir named after the
  full worktree id. The harness caught the deletion by name (`no site.exp
  under .../testsuite.aarch64-... -- the run did not happen`); without that arm
  it would have shown one finished target and three refusals, which reads as
  "three back ends failed".

## 7. WHAT WAS NOT MEASURED -- UNKNOWN, not zero

- **41 of 47 back ends.** Six are on this board (§2 and §4b).
- **sparc64 and ia64** were not attempted. The fallback-config route of §4b
  would work for them too -- it needs no cross binutils -- so they are cheap
  next candidates, and the remaining 39 are limited by whether they emit at
  all, not by tools.
- **ASSEMBLES / ELF-MACHINE for visium and xtensa**: UNKNOWN by construction,
  see §4b.
- **Execution, and languages other than C.** `--enable-languages=c,lto`;
  `check-g++` and the rest were never invoked. Unchanged from T173.
