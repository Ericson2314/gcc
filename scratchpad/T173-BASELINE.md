# THE FIRST PER-TARGET TESTSUITE BASELINE ON THIS BRANCH

Everything here is one run, and it is **PROVISIONAL** for the reason in §5.
Quote §5 with any figure from §2 or the next reader will inherit a number
without its caveat, which is how this branch's stale bars happened.

## 1. Provenance -- quote this with the board

```
srcdir      /tmp/snap-a78a  (immutable worktree, git diff --quiet asserted)
commit      80bf400ae06
anchor      grep -c MULTI_TARGET gcc/Makefile.in = 55   (measured, not quoted)
build       /tmp/b-a78a, --enable-backends=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu
            make all-gcc rc=0, `error:' lines 0
specs       x86_64  230 lines / md5 a6c4c68bdf33
            aarch64 230 lines / md5 f1a5ab201d95      (DISTINCT -- really probed)
codegen bar cc1 -O2 big.c -o x.s = 12369 bytes / md5 378fc33c1e70
            -- reproduces PRINCIPLES' recorded two-base bar EXACTLY
mode        MT_COMPILE_ONLY=1, make -j8, dejagnu 1.6.3
```

The two spec files have **different md5s**, which is the arm that distinguishes
a real probe from one that silently fell back to the build machine's tools and
wrote a file NAMING aarch64 while DESCRIBING x86_64.

## 2. THE BOARD

```
TARGET                             PASS     FAIL    XPASS    XFAIL    UNSUP    UNRES    ERROR
x86_64-pc-linux-gnu              162165    16290        3     1556     4451    13361       32
aarch64-unknown-linux-gnu         83158   106277        6      816    11298   133718       32

KILLED (not a test result):       x86_64 0        aarch64 2
```

Cross-checked: these counts, taken by grepping the merged `.sum`, agree
**exactly** with DejaGnu's own `=== gcc Summary ===` block on both targets.
Two instruments, same numbers.

## 3. THE FINDING: THE PRIMARY WORKS, THE SECOND BASE DOES NOT

ICEs by site, from the merged `.sum`:

```
x86_64                                          aarch64
  2  Segmentation fault                          5103  in extract_insn, at recog.cc:2892
  2  "I'm sorry Dave" (a deliberate test)          509  in gen_lowpart_general, at rtlhooks.cc:57
                                                    68  in aarch64_output_casesi, aarch64.cc:14446
                                                    26  in get_attr_type, at aarch64.md:49049
                                                     7  in maybe_record_trace_start, dwarf2cfi.cc:2606
                                                     7  in get_insn_template, at final.cc:2047
                                                     5  Segmentation fault
                                                     4  in paradoxical_subreg_p, at rtl.h:3338
                                                     3  in ordered_min, at poly-int.h:1383
```

**x86_64 has essentially no ICEs and aarch64 has 5,700+.** That is the
both-sided shape: one configured back end is served correctly and the other is
not, by the same binary, on the same tests. `extract_insn` at `recog.cc:2892`
is "unrecognizable insn" -- the insn stream does not match the recognizer --
which is the signature of the shared-numbering / wrong-table class in
PRINCIPLES 3, not of a front-end or middle-end bug.

Smallest reproducers already isolated, all three ICEing in `extract_insn`:

```
gcc.dg/20000111-1.c   gcc.dg/20000906-1.c   gcc.dg/20001116-1.c
```

These are ordinary C, no target intrinsics, compile-only. **Handing these three
to whoever owns emit-correctness is the highest-value output of this task.**
`gen_lowpart_general` (509) is a second, independent cause.

## 4. WHAT THE NUMBERS DO NOT MEAN

- **Do not add compile-only and execution numbers together**, per
  `multi-target.exp`'s own warning. Every `dg-do run` was downgraded to
  `compile`, so a PASS here means "it compiled", not "it computes the right
  answer". This is the correct mode -- no target libgcc exists in this build
  (`all-gcc` only), so letting run tests link would manufacture a uniform
  failure floor.
- **A large part of both FAIL columns is the absent runtime, not multi-target.**
  `gcc.misc-tests/gcov-19.c` alone contributes 940 (x86_64) and 942 (aarch64)
  because gcov tests execute; `gcc.dg/lto/*` needs a linker. These are the same
  on both targets and are **not** evidence about back-end selection. The
  aarch64-minus-x86_64 delta is the multi-target signal; the common part is the
  build's shape.
- **13,361 / 133,718 UNRESOLVED is its own column and is never folded in.**
  10,956 of aarch64's are `compilation failed` on a test that then could not be
  run. ~800 execution tests were silently UNRESOLVED on this branch for months
  without moving a number, which is why this column exists.
- **No failure floor is subtracted anywhere.** A constant floor deleted the
  signal here once and hid 1447 real regressions.

## 5. PROVISIONAL -- READ BEFORE QUOTING

The machine was under load during this run (15-minute average 25--27, no swap).
Two aarch64 compilations were **OOM-killed** and recorded by DejaGnu as
ordinary FAILs, because DejaGnu cannot distinguish "the compiler said no" from
"the compiler was killed". `mtscore.sh` counts them from the log and prints
them as their own verdict.

Two of 106,277 is negligible for the conclusions in §3, which rest on
cause-level counts in the thousands. It is **not** negligible for anyone
diffing this board test-by-test against a later one. Re-run on a quiet machine
before treating any individual test's verdict as expected behaviour.

## 6. WHAT WAS NOT MEASURED

- **45 of 47 back ends.** This is a two-base build. Extending to N targets is
  a `for` loop in `mtcheck.sh` and a `target-specs` run per target needing that
  target's real cross binutils (`pkgsCross.<arch>.buildPackages.binutils`);
  the harness itself needs no change. Only 4 of 47 back ends emit assembly at
  all today, so most targets will refuse at guard 1 or 2 -- **by name**, which
  is the intended outcome, not a harness failure.
- **Execution.** Requires per-target libgcc and either native hardware or an
  emulator board. Zero observations on that axis, unchanged.
- **Languages other than C.** `--enable-languages=c,lto`; `check-g++` and the
  rest were never invoked.
