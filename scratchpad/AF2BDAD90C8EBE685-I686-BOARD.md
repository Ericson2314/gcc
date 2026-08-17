`i686` — THE SECOND ILP32 ROW, AND THE FIRST ON THE LEAKED PRIMARY'S BACK END
============================================================================

Task #241: every scored target was LP64 except `arm`.  This row adds
`i686-unknown-linux-gnu` — ILP32, and the **i386 back end**, i.e. the back end
whose functions shared code calls by name (`x86_output_aligned_bss` from
`i386/gnu-user.h:87`).  A 32-bit row on THAT back end tests the leak on the
axis it is most likely to be wrong on.

0. PROVENANCE — quote this with the row
---------------------------------------

```
worktree    agent-af2bdad90c8ebe685
            THE TRAP FIRED AGAIN, 23rd time.  Created at bare-repo HEAD
            7208eca60d0 ("find_a_program: Only search for prefixed paths"),
            DIVERGENT: `merge-base --is-ancestor multi-target-0 HEAD' said NO,
            scratchpad/ absent.  Reset --hard onto 45557c05382.
            multi-target-0 = 45557c053822fd7c2f3605a1290d51be20439ba0
            HEAD after reset = 45557c053822fd7c2f3605a1290d51be20439ba0

MULTI-TARGET SIDE
  srcdir    /tmp/snap-agent-af2bdad90c8ebe685-45557c05382 (read-only archive)
  anchor    grep -c MULTI_TARGET gcc/Makefile.in = 55   MEASURED
  build     /tmp/b-af2bdad90c8ebe685, 47 bases, make all-gcc rc=0,
            `error:' 0, multiple definition 0, undefined reference 0, Killed 0
  bases     the committed 47 with TWO substitutions:
              arm-eabi            -> arm-linux-gnueabihf  (inherited)
              x86_64-pc-linux-gnu -> i686-unknown-linux-gnu   (see 4)
  tools     pkgsCross.gnu32 binutils 2.46 + i686 glibc 2.42.
            Probe assembles a TU: Class=ELF32 Machine=Intel 80386.
  config    specs-config 232 lines / 224 non-blank (the stable part)

STOCK SIDE (THE CONTROL)
  srcdir    /tmp/snap-stock-agent-af2bdad90c8ebe685, sc-snap.sh
            upstream merge-base c31b7a09eea3c33bccca12bab4a7bb6b01da1ff6
            anchor 0 (asserted, inverted), read-only, testsuite graft only
  build     /tmp/b-stock-agent-af2bdad90c8ebe685-i686, --target=i686-...,
            same cross binutils, same glibc headers through --with-sysroot,
            make all-gcc rc=0
  guards    S2 -dumpmachine, S3 headers reachable, S4 Machine: Intel 80386,
            S4b Class ELF32
```

1. THE BOARD
------------

Both sides `MT_COMPILE_ONLY=1`, C only, no target libgcc on either side.

```
VERDICT      MULTI-TARGET      STOCK      DELTA
PASS             157580     157950       -370
FAIL              16048      16012        +36
XPASS                 3          3         +0
XFAIL              1555       1555         +0
UNSUPPORTED        5816       5767        +49
UNRESOLVED        12951      12937        +14
ERROR                44          8        +36
```

**DEBT (stock PASS -> multi-target NOT PASS): 34.**  All 34 -> FAIL.

**SCOPE, quoted beside it as #241 requires:**

```
results produced   multi-target 193,997      stock 194,232
joined (name+occurrence)                     193,883
only multi-target  114
only stock         349
```

Debt by directory: `gcc.target/i386` 28, `outputs-2[2345]` 4,
`gcc.dg/strlenopt-80.c` 1, `gcc.dg/completion-5.c` 1.

The 28 in `gcc.target/i386` are the row's real work queue and are ILP32
codegen: `pr102230.c scan-assembler-times movl[\t ]*8\(%esp\), %eax 1`,
seven `avx512fp16-*` conversion counts, three `part-vect-*hf.c` "vectorized
using 4 byte vectors", `kortest_ccz-1.c scan-assembler-not kmov`.  Not
triaged further here.

Load at scoring 13.94 — under the ~25 provisional line.  KILLED 0.

2. WHY DEBT ALONE WOULD HAVE LIED, TWICE, IN THE FLATTERING DIRECTION
---------------------------------------------------------------------

The debt number was **34 in all three runs of this row**.  It did not move
while two real defects were found and fixed, because both lived entirely in
the SCOPE column.  Scope did move, a lot:

```
                          only-mt   only-stock
first run                     535        2015
+ the objdump fix             223        1665
+ decimal_float passed        114         349
```

**(a) The testsuite could not see the target's binutils.**
`sc-check.sh` (the control) runs `make check` with `PATH=$TOOLS:$PATH`;
`mtcheck.sh` only linked them into `asdir-<T>` UNPREFIXED, for `-B`.  The
suite spawns `<target>-objdump` BY NAME (`find_binutils_prog`), so
`gcc_target_object_format` returned `unknown`, `hidden-scan-for`
(`lib/scanasm.exp:156`) fell through to `return ""`, and an EMPTY regexp went
into the scan AND the test NAME:

```
mt     FAIL: gcc.dg/visibility-d.c scan-not-hidden
stock  PASS: gcc.dg/visibility-d.c scan-not-hidden hidden[ \t_]*foo00
```

30 FAILs that were the harness — and because the names differ they never
join, so they were NOT debt.  Fixed (`39656fbc58f`); after: 61 PASS / 0 FAIL
and the names match the control character for character.

**(b) Decimal float has been OFF for every target on every board.**
`target-specs/configure.ac:168` takes `--with-decimal-float` and defaults it
to **0**; nothing ever passed it.  `config.gcc:1285` computes it per target
and the manifest records `decimal_float 1` for i686, x86_64, aarch64,
powerpc64 and s390x — while every `specs-config` said 0, and
`targ_caps.decimal_float` is all cc1 reads.  Measured: `gcc.dg/dfp/dfp.exp`
produced ONE line (its banner) against 749 on the control, plus 110 in
`c-c++-common/dfp` — **858 results never attempted**, and zero debt.  The
compiler's own words were `error: unable to emulate 'DD'`.
Fixed (`9ee972c229d`): the recipe now extracts the two manifest lines beside
`option_defaults` and `cpu_type` and refuses when they are absent.
This is NOT an i686 property — x86_64's `specs-config` in the same build said
0 too.  i686 is where it was noticed, not where it is.

3. WHAT THE 32-BIT AXIS ITSELF SAID
------------------------------------

`a660907426e03e4e9-widthprobe.sh 4 4`: multi-target PASS, stock PASS,
negative control fired on both sides.  `sizeof(void*)`, `sizeof(long)`,
`__SIZEOF_POINTER__`, `__INTPTR_WIDTH__` all agree with the ILP32 ABI on both
sides.  No ILP32 leak found on that axis in this row.

4. THE THING THE ROW COULD NOT DO, AND WHY THAT IS THE FINDING
---------------------------------------------------------------

The obvious configuration — ADD i686 as a 48th base and keep x86_64 — is
accepted and is silently wrong.  `gen-target-manifest.sh` dedups on
`cpu_type`, so the FIRST triple of a back end decides `tm-<cpu>.h`, and
`i686-unknown-linux-gnu` sorts before `x86_64-pc-linux-gnu`.  Measured in
`/tmp/b-af2bdad90c8ebe685-probe`: two `cpu_type i386` stanzas with different
chains (i686 has no `biarch64.h`, no `x86-64.h`, no `linux64.h`), and
`tm-i386.h` built from the 32-bit one — the header `i386-common.o`,
`spec-functions-i386.o` and `target-asm-ops-i386.o` are compiled against.
Through `i386.h:566`/`:307` that makes `TARGET_64BIT` a compile-time 0 inside
the object computing x86_64's default option flags
(`i386-common.cc:2135`).  configure 0, build 0, no diagnostic.

Invisible from every board ever taken here for the same reason the LP64
assumption was: the committed 47 has exactly one triple per back end.  The
tree's other two answers to "several triples, one back end" are both correct
(options are UNIONED; `gen-multi-target-md.awk` gives each TRIPLE its own
`tm-<triple>.h` and INTERSECTS conditions).  Now REFUSED by name
(`907995867f3`), both arms run: RED on `aarch64,x86_64,i686`, GREEN on
`aarch64,x86_64`.

5. BARS, MEASURED
-----------------

```
grep -c MULTI_TARGET gcc/Makefile.in            55        unmoved
x86_64 -O2 big.c (mt-bars.sh, canonical 47)     12369 bytes md5 378fc33c1e70
                                                unmoved; -g arm rc=0, debug
                                                sections present
a660907426e03e4e9-mtgap.sh                      2 (mt_base, mt_dwarf2_unwind_info_hook)
mt-shcheck.sh                                   rc=1 -- SEE BELOW
```

`mt-shcheck.sh` is RED at `45557c05382` and was already red before this task:
`scratchpad/t132-neigh.sh` fails `sh -n` ("unexpected EOF while looking for
matching backquote"), 1 of 1176 committed `.sh` files.  The brief lists it as
a bar without saying it is currently failing.  Not touched here: it is
another agent's file and fixing it blind is how a false green gets made.

6. WHAT IN THE BRIEF MEASURED FALSE
------------------------------------

* **`sh scratchpad/mt-shcheck.sh` is not green** at the commit the brief names
  as the baseline (5, above).
* **"`i686-linux-gnu` and `arm` are the obvious candidates"** — `arm` is
  already scored, and `i686-linux-gnu` is the wrong spelling: `config.sub`
  canonicalises it to `i686-pc-linux-gnu`, while the available nixpkgs cross
  prefix is `i686-unknown-linux-gnu`.  Picking the brief's spelling would have
  produced the rename trap the s390x and arm rows both record.
* **"pick a target that ALREADY has a probed `specs-config`"** — no target
  had one.  `/tmp` held no build dir, no tools dir and no snapshot from any
  earlier agent; every artefact in this row was built from scratch.
* Guard S4 of `sc-check.sh` had **no `i?86` arm** and refused the control by
  name; the brief's "already has a probed specs-config and a real assembler"
  reading of "will not SKIP" does not cover harness arms that refuse.
* My own first two guards were wrong in the same direction and are recorded
  in the commits: `gnu/stubs.h` is the SAME file in the i686 and x86_64 glibc
  (both dispatch on `__x86_64__`), and `specs-config` contains no tool paths
  at all to grep for.
