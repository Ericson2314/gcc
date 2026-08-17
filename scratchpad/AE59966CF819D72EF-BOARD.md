# THE JUMP-TABLE CONTENTS, AND THE TWO POPULATIONS REPORTED TOGETHER

**This does not supersede `A4568DE8F522450D3-BOARD.md`.** It merges that
board's branch into `multi-target-0`, continues its hand-over, and answers its
item 6 (`-undoc.sh`'s control) — which had already expired again by the time
this task started.

## 0. PROVENANCE — quote this with any row

```
worktree    .claude/worktrees/agent-ae59966cf819d72ef
            STARTED STALE, the NINETEENTH occurrence.  `rev-parse HEAD' was
            `7208eca60d0', the bare repo's 2022 HEAD; `grep -c MULTI_TARGET
            gcc/Makefile.in' read 0; `scratchpad/AD6A5C1D2539F5E18-PTRMEM.md'
            was absent.  All three arms agreed and it cost one turn.
            `git checkout -b mt-ae59966cf819d72ef multi-target-0' fixed it.
anchor      grep -c MULTI_TARGET gcc/Makefile.in = 52   (measured; unchanged
            by this work, which touches no Makefile.in)
merge base  multi-target-0 = e1f0cad1c2c
merged in   agent-a4568de8f522450d3-mt -- TWENTY-ONE commits, not the 16 the
            brief said.  Three add/add conflicts, all in the mt_frame table.
srcdirs     /tmp/snap-agent-ae59966cf819d72ef-<sha>, git archive, read-only,
            SNAP-SHA stamped, one per commit measured, verified byte-identical
            to `git archive HEAD' (see 5, the tar near-miss)
builds      PRE  /tmp/b-ae59966cf819d72ef       9adf8ca6ae6  (the merge)
            POST /tmp/b-ae59966cf819d72ef-post  4cbbccd242d  (+ the conversion)
            47 bases from backends-47.txt, cold, MT_MAKEFLAGS=-j6
tools       /tmp/tools-agent-ae59966cf819d72ef -- MY OWN, built by taa-tools.sh.
            Real cross binutils for all four targets.  No host-`as' fallback
            for any scored row; where a host-`as' specs-config IS used it is
            named as such and its answers are trusted for nothing (3d).
mode        MT_COMPILE_ONLY=1, all-gcc only
KILLED      0.  Counted, never subtracted.
```

## 1. THE MERGE

21 commits, unmerged at `multi-target-0`. Three add/add conflicts, all in the
`mt_frame ()` descriptor table, which both branches grow from the same end:
`target-frame.h` (struct members), `target-cumargs.cc` (includes, thunks,
initializer) and `target-cumargs-select.cc` (dispatchers).

Four of the five hunks are pure appends. **The fifth is a real modify/modify**
— the initializer is a comma-separated list and each side appended after
`mt_base_declare_cold_function_name` — and a union script that silently drops
the diff3 base section resolves that by deleting one side's edit, producing
something that **compiles**. `-resolve.sh` therefore refuses with rc=9 on a
non-empty base section rather than dropping it; that guard fired on exactly
the one hunk that needed a human, which is why it is committed rather than run
and deleted.

The 67 struct members and the 61 `mt_base_` initializers were then asserted to
agree name for name before the build (`-drive.sh`), because a mis-ordered
function-pointer table with no designated initializers is silent.

## 2. WHAT WAS FIXED — `ASM_OUTPUT_ADDR_VEC_ELT` / `ASM_OUTPUT_ADDR_DIFF_ELT`

`ADDR_VEC_ALIGN`, converted on the merged branch, is the **alignment** of a
case vector. These two are its **entries**. They sit in the same `final.cc`
block and are the larger leak by a wide margin.

### 2a. Measured at the object level, which is why this is not an inference

```
nm -uC /tmp/b-a4568de8f522450d3-post6/gcc/final.o
  U ix86_output_addr_vec_elt(_IO_FILE*, int)
  U ix86_output_addr_diff_elt(_IO_FILE*, int, int)
```

`final.cc` is shared, so both macros are `i386.h:2231` and `:2237`, and
neither symbol is in `MULTI_TARGET_RENAME_NAMES` — **one bare definition in
`i386.cc` writing every target's case vectors.**

### 2b. The divergence is by VALUE and it is the largest yet measured here

Measured through each base's **real `tm.h` chain**
(`-eltbodies.sh`, `cpp -dM -imacros tm-<base>.h`), not a `config/` directory
grep — which matters, and the same run proves it: the directory grep scores
`ASM_OUTPUT_CASE_LABEL` at **7** definers where `elfos.h` makes it **40**.

```
ASM_OUTPUT_ADDR_VEC_ELT    38 definers,  34 DISTINCT bodies
ASM_OUTPUT_ADDR_DIFF_ELT   38 definers,  33 DISTINCT bodies
```

Nearly every definer has its own, and none of the differences is stylistic:

```
mips    ptr_mode == DImode ? ".dword" : ".word"   -- entry width per ABI
m68k    "\t.long .L%d - 1b\n"                     -- a different anchor
arm     switch (GET_MODE (BODY)) SI .long / HI .word / QI .byte
xtensa  (%LL%d - %LLrtx%d) / 4                    -- SCALED
mmix    mmix_asm_output_addr_diff_elt (...)
```

### 2c. And i386's answer is not even x86_64's

`ix86_output_addr_vec_elt` (`i386.cc:16133`) picks `ASM_QUAD` over `ASM_LONG`
on `TARGET_LP64`, which is `global_options.x_ix86_isa_flags` — promoted only
by `ix86_option_override`, which runs only when i386 is **selected**. A
non-i386 base reads the **unconfigured default**. Same shape as `Pmode`, and
the reason "i386's answer happens to suit LP64 targets" is not a safe reading.
`LPREFIX` is i386's label prefix on top of that.

### 2d. The closure, and it is why this is not just an emitter swap

`tree-switch-conversion.h:537` is a **second** consumer and asks the opposite
question:

```c
#ifndef ASM_OUTPUT_ADDR_DIFF_ELT
  if (flag_pic)
    return false;              /* do not build a jump table at all */
#endif
```

i386 defines the macro, so that guard was false for all 47 bases and the
**nine** which define nothing — avr bpf ft32 mcore moxie nvptx or1k pdp11
xstormy16 — had PIC jump tables enabled on i386's authority. Converting only
the emitter would have turned their silent wrong entries into a
`gcc_unreachable ()`: a loud failure instead of a quiet one, and still not the
fix. PRINCIPLES names this exactly — walk the guards that decided you reached
the line and convert the closure.

### 2e. No fallback, and it is not a stub

`final.cc`'s own `#else` for each was `gcc_unreachable ()`. A back end that
emits a case vector must say how; a generic body would hand those nine i386's
directive under a new name, which is the `#ifndef` floor in its most
disguised form. The thunks fail in the same place and for the same reason
upstream would, with the difference that it is now a fact about **this** base.

### 2f. The fourth missing include of the same series, found the cheap way

`mips.h:3040`'s `TARGET_RTP_PIC` arm takes
`XEXP (DECL_RTL (current_function_decl), 0)`, so `target-cumargs.cc` now needs
`varasm.h` for `make_decl_rtl`. Fourth after epiphany/`attribs.h`,
`attribs.h`/`stringpool.h` and msp430/`recog.h` — and the first three cost a
47-base build each. `-syncheck.sh` found this one in one run.

**And that harness was covering less than half the population.** Its `BASES=`
default is a hand-written list of **22**, so it prints `22/22 ok` — which
reads as a clean sweep of the back ends and is a clean sweep of under half of
them, with nothing in the output saying so. `-syncheck47.sh` reads the list
from the build dir's own `mt-<base>/` directories and refuses below 40.
**47 of 47 clean** after `varasm.h`.

## 3. BARS

### 3a. PRE — `/tmp/b-ae59966cf819d72ef`, `9adf8ca6ae6`, the merge

```
make all-gcc          rc=0, stamp 0
error: lines          0
multiple definition   0
undefined reference   0
Killed / signal 9     0
cc1 links             231,167,704 bytes
stderr lines          4761   (cold arm; not comparable with the 32 floor)

WANT_ANCHOR=52 mt-bars.sh
  x86_64 -O2 big.c    12369 bytes  md5 378fc33c1e70   == THE RECORDED BAR
  -O2 -g              rc=0, real debug sections, md5 PATH-SENSITIVE

taa-specs.sh  (B=PRE, TOOLS=/tmp/tools-agent-ae59966cf819d72ef)
  all four   wc -l 232   grep -c . 224
  x86_64  cfbc7a65e54e   aarch64 575aff0c188b
  riscv64 9af7409ac460   s390x   37901805bf3c
  -- ALL FOUR UNCHANGED from the previous board, from a DIFFERENT build dir
     and a DIFFERENT tools dir.  That is the control saying this harness
     measures what that one did.
```

The previous board's post6 read **4762** stderr lines and a 231,073,632-byte
`cc1`. Mine is a different tree (the merge carries both sides' conversions),
so neither figure is expected to reproduce; the one-line stderr difference is
**reported, not explained**.

### 3b. POST — `/tmp/b-ae59966cf819d72ef-post`, `4cbbccd242d`, THE GATE

```
make all-gcc          rc=0, stamp 0
error: lines          0
multiple definition   0
undefined reference   0
Killed / signal 9     0
cc1 links             231,188,072 bytes   (PRE 231,167,704; +20,368)
stderr lines          4761                == PRE EXACTLY

WANT_ANCHOR=52 mt-bars.sh
  x86_64 -O2 big.c    12369 bytes  md5 378fc33c1e70   == THE RECORDED BAR

taa-specs.sh  (B=POST, same tools dir)
  all four   wc -l 232   grep -c . 224, ALL FOUR md5s UNCHANGED
  cfbc7a65e54e  575aff0c188b  9af7409ac460  37901805bf3c
```

The `-O2 -g` arm reads 78544 / `98324fc37cf6` on PRE and 78554 / `88c0412167a1`
on POST. That is the recorded path sensitivity, not a change: the build dir is
on the command line as `-ftarget-config=` and lands in `DW_AT_producer`, and
`-post` is exactly **5** characters longer. Quoted with both build dirs; the
`-O2` bar carries no debug info and is immune.

### 3c. THE OBJECT-LEVEL ARM, BOTH SIDES

```
nm -uC final.o
  PRE    U ix86_output_addr_vec_elt(_IO_FILE*, int)
         U ix86_output_addr_diff_elt(_IO_FILE*, int, int)
  POST   U mt_output_addr_vec_elt(_IO_FILE*, int)
         U mt_output_addr_diff_elt(_IO_FILE*, rtx_def*, int, int)
```

### 3d. THE CODEGEN ARM — AND MY OWN PREDICTION IN §2 WAS WRONG

I wrote, in the commit message and in the descriptor comment, that all four
scored targets are LP64 and spell `.L`, so all four would be **byte-identical**
and the board would not move. **Two of the four CHANGED**, and the reason the
prediction failed is worth more than the prediction: I reasoned about
`ASM_OUTPUT_ADDR_VEC_ELT`'s *directive width* and forgot that a jump table can
be **relative**, at which point the entry width is not the pointer width at
all — it is whatever the back end's own `casesi` pattern loads.

```
PRE=/tmp/b-ae59966cf819d72ef  POST=/tmp/b-ae59966cf819d72ef-post  -jtboth.sh
  scored=4  changed=2  byte-identical=2  skipped=0
  control ok: all 4 PRE outputs are distinct from one another

aarch64  CHANGED   .quad .L15-.L4        ->  .word (.L15 - .Lrtx4) / 4
riscv64  CHANGED   .quad .L15            ->  .word .L15
s390x    IDENTICAL md5 12fa74717921      <- genuinely 8-byte entries
x86_64   IDENTICAL md5 e153a7bc5904      <- the control
```

**And it is wrong code, not a different spelling.** The emitted code on both
changed targets loads a **4-byte** entry:

```
aarch64   ldr  w1, [x1, w0, uxtw #2]     index scaled by 4, loads a WORD
          add  x1, x0, w1, sxtw #2       and the entry is itself SCALED by 4
riscv64   slli a0,a0,2 / lw a5,0(a0)     stride 4, loads a WORD
```

`aarch64-elf.h:72` and `riscv.h:1102` say exactly what POST emits. So before
this, on **every aarch64 and riscv64 switch that became a jump table**, entry
`i` was read from bytes `[4i, 4i+4)` of a table written with an 8-byte stride
— the low half of entry `i/2` — and on aarch64 the value was additionally
**unscaled** where the `add` scales by 4. Two independent errors in one table.
The branch target was garbage.

**Confirmed at the object level with a real cross assembler**
(`-jtstride.sh`, `TOOLS=/tmp/tools-agent-ae59966cf819d72ef`, each `<triple>-as`
asserted to *execute*):

```
                     as   machine                        .rodata   directives
aarch64  PRE        rc=0  AArch64                          96      .quad
aarch64  POST       rc=0  AArch64                          48      .word
s390x    PRE/POST   rc=0  IBM S/390                        96/96   .quad
x86_64   PRE/POST   rc=0  Advanced Micro Devices X86-64    96/96   .quad
```

Twelve entries at 4 bytes is **48**; at 8 bytes it is **96**. aarch64's table
was exactly twice the size its own code indexed.

**Note both aarch64 sides assemble rc=0 into a well-formed AArch64 object.**
That is PRINCIPLES' *"assembles, right ELF machine" is not enough* arriving
again: the wrong table is syntactically perfect and `readelf` is happy with
it. Only comparing the table's size against the stride the code uses sees it.

**riscv64 does not assemble on EITHER side** — `Error: the architecture string
of -march and elf architecture attributes cannot be empty`, the known empty
`.attribute arch, ""` defect PRINCIPLES already records for this branch. It is
equal on both sides and is not caused by this change. So riscv64's result
rests on the text diff plus the `slli`/`lw` pair, and **is not confirmed at
the object level here**; aarch64's is.


### 3e. THE SUITE — aarch64, and it is INERT ACROSS 388,986 RESULTS

Both runs stamped (`check-aarch64-unknown-linux-gnu.rc` = 0), compile-only,
against aarch64's **own** cross assembler (`readelf` reported `AArch64`), with
the `MULTI-TARGET RUN` attribution banner present in both logs. `gcc.sum` is
389,937 lines on each side. `mt-namediff.sh`, by name:

```
                     OLD        NEW      DELTA
PASS              341962     341962         +0
FAIL               20688      20688         +0
XPASS/XFAIL/UNSUPPORTED/UNRESOLVED/ERROR      all +0

unchanged                388962
PASS -> NOT PASS              0     <- real regressions
NOT PASS -> PASS              0     <- real progress
only in new / only in old  24 / 24  <- tcl, testcase, /tmp and two
                                       snapshot-path-bearing gcc.dg/lto
                                       rows; harness rows, both sides
cardinality              2 files +3 results
```

**Zero movement in either direction.** Stated plainly rather than dressed up:
this conversion fixes wrong code that the aarch64 testsuite cannot see, and
that is itself the finding. Two reasons, both structural:

- the run is `MT_COMPILE_ONLY=1`, so nothing **executes** a switch, and a jump
  table with the wrong stride is only wrong when it is jumped through;
- no `scan-assembler` test in the aarch64 suite asserts the case-vector
  directive, so the `.quad` / `.word` difference is not asserted anywhere.

So the aarch64 board is **not** the instrument that would have caught this,
and it never was — which is precisely the argument for the byte-level and
object-level arms in 3d. A defect worth 388,986 results of silence is exactly
the shape PRINCIPLES describes for `EPILOGUE_USES`: *the only thing that sees
it is comparing the emitted body against a control.*

Read the other way, the zero is the strongest **non**-regression evidence
available: a change that rewrites every jump table on this target moved
nothing else at all.

`KILLED` / `virtual memory exhausted` is **0 on both aarch64 sides** — counted,
never subtracted. (The previous board recorded 10 per side on riscv64 under
load; this machine was quieter.)

### 3f. THE CONTROL — x86_64, BYTE-FOR-BYTE INERT

Both stamped rc=0, 199,171-line `gcc.sum` on each side.

```
                     OLD        NEW      DELTA
PASS              162164     162164         +0
FAIL               16295      16295         +0
XPASS/XFAIL/UNSUPPORTED/UNRESOLVED/ERROR      all +0

joined rows              197825
unchanged                197825      <- EVERY ONE
PASS -> NOT PASS              0
NOT PASS -> PASS              0
cardinality        0 more / 0 fewer / 0 gone / 0 new
only in new / old       21 / 21      harness rows
```

**197,825 results with zero transitions in either direction and zero
cardinality movement**, reproducing the previous board's 197,827-result
control on a different pair of trees. x86_64's codegen for a switch is
byte-identical across this change (md5 `e153a7bc5904`), so this is the
prediction that could have falsified and did not.

## 4. THE TWO POPULATIONS, TOGETHER

Neither instrument is the answer and the brief is right that they must be
reported as a pair.

```
leak census (tm.texi @defmac population), TMH from the PRE build's own tm.h

  TOTAL leaking macros                              289
    LEAK-PRIMARY (x86's answer served to all)       114
    DEAD-DEFAULT (fallback served to all)           175

  plus DESCRIPTOR macros claimed converted and STILL SPELLED RAW
  in shared code                                  34 of 97
  -- so the honest documented-population figure is ~323, and 289 is NOT
     an upper bound.  Same correction the previous board made; the numbers
     moved (35 of 94 -> 34 of 97) as conversions landed.

#32 `t32-values.tsv' (value divergence across back ends)   413
  in BOTH        331     <- the double count
  #32 ONLY        82     <- census-invisible BY CONSTRUCTION
  census ONLY    214     <- no measured value divergence

-undoc.sh (undocumented candidates)               106, BOTH ARMS GREEN
```

The `106` is now **verified** rather than printed: on the first run the
scanner exited 9 and called its own total void (4a). After the arm was rebuilt
it reports

```
ok  ARM A (mechanism): HOST_BIT_BUCKET found
ok  ARM B (population): still present: ASM_OUTPUT_ADDR_VEC
      ASM_OUTPUT_ADDR_DIFF_VEC ASM_OUTPUT_EXTERNAL_LIBCALL FRAME_BEGIN_LABEL
    converted or gone since this list was written: ASM_OUTPUT_CASE_END
```

and ARM B naming `ASM_OUTPUT_CASE_END` as already gone, unprompted, is the
arm working: that macro **is** documented, so it was never in this population,
and the list said so without anyone checking by hand.

GROOM2 recorded **330 / 83 / 213** against a 543-name `tm.texi` side. The side
is **545** here because the census's uppercase-only extraction was fixed —
`@defmac Pmode` was being **matched as `P`** — so the one-name shift is that
fix arriving, not a disagreement.

**The pairing carries a NEGATIVE control and it is the useful part.**
`ASM_OUTPUT_FUNCTION_PREFIX` is in **neither** column: undocumented, so
invisible to the census; defined by one back end only, so invisible to a
value-divergence census too. **The two instruments together are still not the
whole population**, and that macro is the standing proof of it.

### 4a. `-undoc.sh`'s control expired a SECOND time, exactly where its comment said

The first anchor was `ASM_OUTPUT_FUNCTION_PREFIX`, expired when that macro was
converted in the same session. It was re-anchored on `ADDR_VEC_ALIGN`
*"because it is NOT being converted"* — and `ADDR_VEC_ALIGN` was converted in
the next commit of the same branch. Run here it exits 9 and calls its own
total void. That is the wanted behaviour; the total **is** unverified until
the arm is fixed, so the instrument was fixed rather than the writeup.

The mistake is not "picked the wrong name". A single-name anchor drawn from
the work queue expires on its first conversion, and this branch converts about
one of these per session. It is now two arms:

- **ARM A, the mechanism, cannot expire.** `HOST_BIT_BUCKET` is undocumented
  and is a **host** fact, not a target one, so it is on nobody's queue. A name
  reaches the hit list only by appearing in **both** the `config/` `#define`
  scan and the shared-spelling scan, so one anchor proves both halves ran.
- **ARM B, the population, may expire loudly.** Five multi-back-end
  undocumented macros of which at least one must survive, with the surviving
  and the converted names both printed. When the last goes it refuses by name
  and says to **top the list up**, not to lower it to one name.

## 5. METHOD NOTES PAID FOR HERE

- **The stale-worktree trap, nineteenth occurrence, and only the `rev-parse`
  equality decided it.** `--is-ancestor` was not even reached; the equality
  differed immediately, the anchor read the bare-repo `0`, and the recent-file
  probe failed. Three agreeing arms, one turn.
- **A read-only snapshot makes `rm -rf` fail and `tar` refuse EVERY file, and
  the run continues.** `-drive.sh` does `chmod -R a-w` on its snapshot. A
  second run's `rm -rf` then cannot unlink the children, `tar` reports
  `Cannot open: File exists` for every path, and the build proceeds **against
  whatever tree was already there** — exit statuses, existence tests and the
  SNAP-SHA check all pass. Here the leftover happened to be the same sha, so
  nothing was wrong **and nothing would have said so either way**; it was
  settled by `diff -r` against a fresh `git archive HEAD`, which is the
  instrument, not the absence of complaint. `chmod -R u+w` before the `rm` is
  now in the script.
- **A definer census keyed on directories cannot see the chain, and the error
  is large.** `ASM_OUTPUT_CASE_LABEL`: 7 by `config/<be>/` grep, **40** through
  the real `tm.h` chain, the difference being `elfos.h`. `tgh-hdrmatrix.sh`
  already existed for exactly this and was **extended** (a `MACROS`
  environment override) rather than copied, because the defect it avoids is
  not specific to `targhooks.cc`'s macros.
- **My own definer scan printed `0/47` for every macro and that read like the
  finding.** It compared `backends-47.txt`, which holds **triples**, against
  `config/` directory **stems**. Nothing matches, every row reads "no back end
  defines this", and for a leak census that is the exciting direction. It now
  reads the mapping from the build dir's `gcc/mt-*/` and refuses below 40.
- **A harness's hardcoded population is a coverage claim nothing states.**
  `-syncheck.sh` prints `22/22 ok` from a hand-written `BASES=` list. Nothing
  in that output says 22 of 47. See 2f.
- **I SAID IN ADVANCE WHICH TARGETS COULD NOT MOVE AND I WAS WRONG, WHICH IS
  THE MOST USEFUL THING IN THIS BOARD.** The prediction — all four scored
  targets are LP64 and spell `.L`, exactly what i386's emitter gets right, so
  all four are correct by luck and byte-identical — went into the commit
  message, the descriptor comment and the harness header. **Two of the four
  changed.** The reasoning was about the POINTER width and a jump table may be
  RELATIVE, at which point the entry width is not the pointer width at all but
  whatever the back end's `casesi` pattern loads.

  Saying it in advance is still right and is what made the failure legible:
  the arm was run to confirm a stated prediction, so a `CHANGED` row was
  immediately a finding rather than a puzzle. **A prediction that cannot fail
  is not worth stating; this one failed and paid for itself.** The corrected
  statement is in `target-frame.h` in place of the wrong one, because a
  comment left standing while the board disagrees with it is how the next
  agent inherits my error as a fact.
- **THE SUITE COULD NOT SEE IT, AND THAT IS A PROPERTY OF THE SUITE.**
  388,986 aarch64 results moved by **zero** across a change that rewrites
  every jump table on the target. Compile-only means nothing executes a
  switch, and no `scan-assembler` test asserts the case-vector directive. So
  for this defect class the board is **not** the instrument, and the
  object-level arm (`.rodata` 96 -> 48 against the stride the code uses) is.
  Same shape as `EPILOGUE_USES`: the only thing that sees it is comparing the
  emitted body against a control.

## 6. WHAT I WOULD HAND THE NEXT AGENT

1. **The rest of the jump-table family — the WHOLE-TABLE half.** This task
   converted the *entries*; the *table* is still i386's. Measured through the
   real `tm.h` chain:

   ```
   ASM_OUTPUT_ADDR_VEC        4 definers (avr pa sparc xstormy16)   i386: NO
   ASM_OUTPUT_ADDR_DIFF_VEC   2 definers (pa sparc)                 i386: NO
   ASM_OUTPUT_CASE_END        5 definers                            i386: NO
   ASM_OUTPUT_CASE_LABEL     40 definers (elfos.h)                  i386: YES,
                                          5 distinct bodies, 36 share i386's
   ```

   All four are LEAKED ABSENCE except the last. `final.cc:2476` and `:2559`
   are `#if defined(A) || defined(B)`, so the four back ends with a
   whole-table routine (`avr_output_addr_vec` and friends) **have never
   emitted a jump table through it** — and `final.cc:2478`'s comment says the
   label must then not be emitted either, so those four also get a label they
   should not have. This is a **shape change**, not an emitter swap: the `#if`
   becomes a runtime `if (mt_has_output_addr_vec () || …)`, which is why it
   was not folded into this commit.

   `ASM_OUTPUT_CASE_LABEL` is the low-value member (4 back ends differ from
   i386) and is the one whose directory-grep count is wrong by 33; do not
   re-derive it from `config/`.

2. **`ASM_OUTPUT_MAX_SKIP_ALIGN`** — the board before last's item #3, still
   live, still mis-scored as converted by the census (`varasm.cc:2173`,
   `final.cc:2432`). Unchanged by this task.

3. **The 34 DESCRIPTOR macros still spelled raw** (`-descaudit.sh`). Each is a
   leak the census removes from its own headline. Head of the list unchanged:
   `STACK_GROWS_DOWNWARD`, `DWARF2_FRAME_REG_OUT`, `CUMULATIVE_ARGS`,
   `FRAME_POINTER_CFA_OFFSET`, `MAX_OFILE_ALIGNMENT`.

4. **A 32-BIT TARGET ON THE BOARD IS NOW THE HIGHEST-VALUE HARNESS ITEM.**
   Every scored target is LP64. Whole classes of leak — the stdint family, the
   entry-width half of this one, `Pmode`-shaped defects — are invisible to all
   four by construction, and this task only caught its own because two of the
   four happen to use *relative* tables. `arm-eabi` or `m68k-elf` through
   `mt-specs-fallback.sh` would cost one specs-config and change what the
   board can see.

5. **`mtcheck.sh`'s empty `DEJAGNU` (see the suite-driver commit).** Worked
   around from outside because another agent's run was executing the file.
   Make the export conditional once no run is in flight — otherwise the next
   `check-gcc` gets a zero-byte `gcc.sum` beside `make` exit 0.

6. **`-undoc.sh`'s ARM B is a list, and lists run out.** It currently holds
   `ASM_OUTPUT_ADDR_VEC`, `ASM_OUTPUT_ADDR_DIFF_VEC`,
   `ASM_OUTPUT_EXTERNAL_LIBCALL`, `FRAME_BEGIN_LABEL`. Item 1 above converts
   the first two. **Top the list up in the same commit**, from the scan's own
   ranked output; do not lower it to one name, which is how it expired twice.
