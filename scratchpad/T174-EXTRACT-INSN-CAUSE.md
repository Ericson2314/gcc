# aarch64's 5,103 `extract_insn` ICEs: TWO causes, both already-known open items

Task: find the cause of the 5,103 `internal compiler error: in extract_insn,
at recog.cc:2892` on aarch64 in the first per-target testsuite baseline
(`T173-BASELINE.md`).

**Answer: two causes, and together they are 100% of the population.** Neither
is new — both are named in `multi-target-select.cc`'s comment block at line
~890 as *open*. What was missing was the number, and the number says this one
open item is the whole of the aarch64 ICE column.

## 1. Provenance

```
srcdir      /tmp/snap-ab0e  (immutable worktree, git diff --quiet asserted)
commit      7f6febe5628
anchor      grep -c MULTI_TARGET gcc/Makefile.in = 55   (measured on that tree)
build       /tmp/b-ab0e, --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu
            make all-gcc rc=0, `error:' lines 0, `multiple definition' 0
specs       reused from /tmp/b-a78a/lib/gcc/17.0.0/<triple>/specs-config
            x86_64  230 lines md5 a6c4c68bdf33   aarch64 230 lines md5 f1a5ab201d95
            -- byte-identical to PRINCIPLES' recorded pair
counts      from /tmp/b-a78a/gcc/testsuite.aarch64-unknown-linux-gnu/gcc/gcc.log
            (the baseline run; NOT re-run here -- see section 5)
```

## 2. THE REPRODUCER IS FIVE LINES AND IT IS AN `-O0` DEFECT

```c
void foo (int x) { if (x) ; }
```

```
$ cc1 -quiet -nostdinc -ftarget-config=<aarch64 specs-config> min.c -o min.s
min.c:5:1: error: unrecognizable insn:
(insn 9 3 0 2 (const_int 0 [0]) "min.c":5:1 -1
     (nil))
during RTL pass: vregs
min.c:5:1: internal compiler error: in extract_insn, at recog.cc:2892
```

**Both-sided, same binary, same source:** with the x86_64 `specs-config` the
identical command exits 0 and the `.s` contains the `nop`.

The optimisation sweep matters and was not in the brief. Of the three
reproducers handed over, `20000111-1.c` does not ICE at all, and the other two
ICE **only at default and `-O0`**:

```
gcc.dg/20000111-1.c   ok at "" -O0 -O1 -O2 -O3 -Os
gcc.dg/20000906-1.c   ICE at ""  ICE at -O0   ok at -O1 -O2 -O3 -Os
gcc.dg/20001116-1.c   ICE at ""  ICE at -O0   ok at -O1 -O2 -O3 -Os
```

That is consistent with the caller found in section 3: the shared nop emitters
in `cfgrtl.cc` are locus-preservation code that runs when blocks merge without
optimisation rewriting them away.

## 3. CAUSE 1 -- `gen_nop` (90.5% of occurrences)

`(const_int 0)` is not a nop on aarch64. It is **i386's** nop:

```
config/i386/i386.md:21733   (define_insn "nop"  [(const_int 0)] ...)
config/aarch64/aarch64.md:1330
                            (define_insn "nop"  [(unspec [(const_int 0)] UNSPEC_NOP)] ...)
```

Three bodies are linked into one `cc1`, and shared code binds the bare one:

```
$ nm -C cc1 | grep -wE 'gen_nop|gen_blockage'
00000000010b64a0 T gen_nop()                 <-- what shared code calls
000000000275dc20 T insn_aarch64::gen_nop()
0000000002bb9140 T insn_i386::gen_nop()
000000000107dc50 T gen_blockage()
000000000289fbe0 T insn_aarch64::gen_blockage()
0000000002b80910 T insn_i386::gen_blockage()
```

and the generator names its own provenance for the bare one:

```
/tmp/b-a78a/gcc/insn-emit-2.cc:282
    /* /tmp/snap-a78a/gcc/config/i386/i386.md:21733 */
    rtx
    gen_nop (void)
```

The bare name comes from the un-namespaced `insn-emit-*.o`, which is the
PRIMARY's. Shared callers, all four already listed in
`multi-target-select.cc:898`:

```
cfgrtl.cc:861    emit_nop_for_unique_locus_between
cfgrtl.cc:4207   fixup_reorder_chain's goto_locus split
except.cc:2568
targhooks.cc:2340
varasm.cc:1868   (a fifth, not on that list)
```

## 4. CAUSE 2 -- `gen_blockage` (9.5%), and the dump names the wrong constant

Every one of the non-`const_int` unrecognizable insns prints as

```
(insn 23 22 24 5 (unspec_volatile [ (const_int 0 [0]) ] UNSPECV_GET_FPCR) ...)
```

`UNSPECV_GET_FPCR` is aarch64's **1**. Measured in the build dir:

```
insn-constants-i386.h      UNSPECV_BLOCKAGE = 1
insn-constants-aarch64.h   UNSPECV_BLOCKAGE = 5   UNSPECV_GET_FPCR = 1
insn-constants.h (shared)  UNSPECV_BLOCKAGE = 1        <-- i386's
```

So i386's `gen_blockage` emits unspec_volatile **1**; aarch64's recogniser
matches blockage at **5** and does not match 1; and the dumper, reading
aarch64's own table, renders the 1 as `UNSPECV_GET_FPCR`. This is the
`UNSPECV_BLOCKAGE = 1 vs 5` entry in PRINCIPLES 3, now caught in the act.

**Note the trap for the next reader**: the dump names a *plausible aarch64
insn*. Nothing in the message says "i386". Anyone grepping for a blockage
problem finds nothing.

## 5. THE DECOMPOSITION -- these two causes are the whole column

Over `gcc.log` from the baseline run, every `error: unrecognizable insn:`
block classified by the pattern on the line that follows it:

```
occurrences (a file compiled at several torture options counts several times)
   9277   (const_int 0 [0])            gen_nop          90.5%
    973   unspec_volatile ... 1        gen_blockage      9.5%
      0   anything else
  -----
  10250

distinct source files
   4261   gen_nop
    186   gen_blockage
   4412   distinct files overall  (35 files hit by both)
```

`UNSPECV_GET_FPCR` is the ONLY unspec name that appears in any of these dumps
(`grep -oE 'UNSPECV?_[A-Z0-9_]+'` over all the blocks: 973 hits, one name).
There is no third cause. **5,103 is a count, and here the population is 2.**

## 6. WHY NO DELTA IS REPORTED -- the brief forbids the fix it asks for

The brief says *"DO NOT TOUCH: `gen_blockage` and the bare `gen_*` names (live
agent)"* and also *"re-run the suite and report the delta"*. The cause **is**
the forbidden area: both causes are bare `gen_*` names, one of them
`gen_blockage` by name. Nothing was changed, per PRINCIPLES ("if a brief
contradicts this document, say so and stop"). The delta is whatever the live
agent's forwarder work produces; the ceiling for it is measured above.

## 7. TWO MEASURED FACTS FOR WHOEVER LANDS THE FORWARDERS

The `multi-target-select.cc` comment gives one reason the `add_clobbers`
treatment was not simply repeated for these: *"WHETHER the middle end calls
them at all is decided by `HAVE_blockage` / `HAVE_speculation_barrier` out of
the SINGULAR insn-flags.h"*. Two things about that, measured:

- **At two bases it is inert for all three names.** `HAVE_nop`,
  `HAVE_blockage` and `HAVE_speculation_barrier` are all `1` in
  `insn-flags-i386.h` AND in `insn-flags-aarch64.h`. The singular header is
  telling the truth for this base set, so a forwarder alone is sufficient here
  and the insn-flags union is not a prerequisite **for the two-base fix**.
- **At 47 bases the two names diverge sharply, and in opposite directions.**
  Sweeping `config/*/` for `define_insn|define_expand "nop"` / `"blockage"`
  (`/tmp/ab0e-nopsweep.txt`): `nop` is defined by every back-end directory
  (the only three misses are `mingw`, `vms`, `vxworks`, which are OS dirs, not
  back ends); `blockage` is defined by only 29 of 51 directories. So a
  fail-to-link-by-name forwarder is unconditionally right for `gen_nop`, and
  for `gen_blockage` twenty back ends genuinely have no body to forward to --
  which is the case the singular `HAVE_blockage` currently answers wrongly and
  silently.

## 8. NOT MEASURED

- The other aarch64 ICE families (`gen_lowpart_general` 509,
  `aarch64_output_casesi` 68, `get_attr_type` 26) were not investigated. They
  are separate causes; nothing here bears on them.
- No suite run was taken on `/tmp/b-ab0e`. The counts in section 5 are from
  the `/tmp/b-a78a` baseline log, and PRINCIPLES 5's caveat about that run
  (two OOM kills) applies -- irrelevant at this magnitude, relevant to anyone
  diffing test-by-test.
- 45 of 47 back ends. Two-base build.
