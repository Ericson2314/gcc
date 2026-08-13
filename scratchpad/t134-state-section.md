
# TASK #134 -- `PUSH_ARGS_REVERSED' CONVERTED WITH A BEHAVIOURAL BOTH-SIDED ARM
# (aarch64 CHANGES, x86_64 BYTE-IDENTICAL), AND `REG_PARM_STACK_SPACE'S SECOND
# PATH CLOSED WITH ALL FOUR PATHS ENUMERATED AND VERDICTED.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c MULTI_TARGET
gcc/Makefile.in' was **0**, `git reset --hard multi-target' took it to **39**,
no `scratchpad/'.  THIRTEEN in a row.  Build dir `/tmp/b134', my own, cold.
**The brief named no task numbers I could read**; that is the coordinator's
error and everything below is measured in `/tmp/b134'.

## 1. JOB 1 -- `PUSH_ARGS_REVERSED', AND THE LADDER WAS THREE LEAKS NOT ONE

i386.h:1658 defines it to `1'; aarch64 does not; bpf and nvptx do.  Only
shared use: gimplify.cc:4791-4793, three run-time expressions in one `for'
header -- **so every target's call arguments were gimplified last-to-first
because the primary says so.**

The part the brief did not have: `defaults.h:915-928' is not a constant
fallback, it is a LADDER --

    #ifdef PUSH_ROUNDING
    # if defined (STACK_GROWS_DOWNWARD) != defined (ARGS_GROW_DOWNWARD)
    #  define PUSH_ARGS_REVERSED targetm.calls.push_argument (0)
    # endif
    #endif
    #ifndef PUSH_ARGS_REVERSED
    # define PUSH_ARGS_REVERSED 0
    #endif

and `PUSH_ROUNDING', `STACK_GROWS_DOWNWARD' and `ARGS_GROW_DOWNWARD' are ALL
per-base.  **Three leaks in one ladder**, closed together.

Four parts, the #131/#132/#133 shape:

  * `target-frame.h'          -- `bool (*push_args_reversed) (void)'
  * `target-cumargs.cc'       -- `mt_base_push_args_reversed'.  **The ladder
    is NOT reproduced here**, unlike `STACK_DYNAMIC_OFFSET''s: that one lived
    in a `.cc' file's private preprocessor block with nothing to include,
    whereas this one is in `defaults.h', which this file already includes with
    `MULTI_TARGET_TARGETM_BASE' defined.  The ladder has therefore already run
    against THIS base's headers and the thunk just reads the macro.
  * `target-cumargs-select.cc' -- `mt_push_args_reversed ()'
  * `defaults.h'              -- `#undef' then redirect, beside
    `ACCUMULATE_OUTGOING_ARGS'

`? true : false' and not a cast: the three spellings are `1' (int), `0' (int)
and `targetm.calls.push_argument (0)' (bool).

## 2. THE BEHAVIOURAL ARM -- THE POINT OF THE TASK

Evaluation order is observable, so a value arm would not have been enough.
`scratchpad/t134-order.sh' on

    extern int f (void), g (void), h (int, int);
    int t (void) { return h (f (), g ()); }

at `-O0 -fno-inline' (NOT -O2: the scheduler can reorder two calls there and a
difference would not be attributable).  Redirect injected OFF and back ON in
the SAME build dir (`t134-par-inject.sh', sed not python3, state asserted in
both directions, matching the `#undef'/`#define' LINES and not the symbol name
-- #133 recorded that a name assertion also matches the prose):

                    OFF (pre-#134)          ON (fixed)
    aarch64         `bl g' then `bl f'      `bl f' then `bl g'    CHANGED
                    md5 0cbc679b3ec0        md5 364bcdc7b2fc
    x86_64          md5 7f363194d339        md5 7f363194d339      BYTE-IDENTICAL

**The x86_64 column is what separates "fixed" from "everyone now gets the same
new answer".**  The restore was rebuilt and reproduced `364bcdc7b2fc' exactly,
so the ON reading is not a one-off.

**ASSEMBLY ARM AVAILABLE HERE AND RUN** (`t134-asm.sh', real
`pkgsCross.aarch64-multiplatform.buildPackages.binutils', tools named and
asserted first).  The aarch64 output assembles and disassembles to real
aarch64 machine code -- `stp x29, x30, [sp, #-32]!' / `bl f' / `bl g' /
`bl h' -- and `readelf --debug-dump=frames' decodes a correct CFA:
`DW_CFA_def_cfa: r31 (sp) ofs 0', then x29/x30 at cfa-32/-24 and x19 at
cfa-16.  This input has no `alloca', so it does not meet #133's
`UNSPECV_GET_FPCR' wall.

Object level: `gimplify.o' binds `mt_push_args_reversed' once.  The two thunks
DIFFER and are readable: i386 `mov $0x1,%eax; ret', aarch64
`xor %eax,%eax; ret'.

## 3. JOB 2 -- `REG_PARM_STACK_SPACE': FOUR PATHS, ONE CLOSED, VERDICTS FOR ALL

**Two paths was NOT all of them.**  Enumerated from the source by
`t134-rpss.sh' (not from memory), verdict for each including the fine ones:

  1. `function.cc:1403' + `:2322' -- the `INCOMING_REG_PARM_STACK_SPACE'
     derivation and the `#ifdef' over `all->reg_parm_stack_space'.
     **CLOSED HERE.**  Both moved into `target-cumargs.cc'; the name is now
     UNDEFINED in shared code, so a future spelling fails by name.
  2. `calls.cc' -- **ELEVEN** `#ifdef REG_PARM_STACK_SPACE' sites (:174,
     :1096, :2793, :2885, :3568, :4014, :4257, :4272, :4597, :4945, closing
     :1194) plus two value sites (:2886, :4273).  **OPEN**; `calls.o' still
     binds `U ix86_reg_parm_stack_space'.  Several `#ifdef's span whole
     blocks, so this is `PUSH_ROUNDING' SHAPE 2/5 work, not a redirect.
  3. `expr.cc:2192/:2198' -- `#if defined' plus a value use.  **OPEN**;
     `expr.o' binds the symbol.
  4. `target-cumargs.cc:683-686' and `:745-748' -- the two per-base
     derivations.  **CORRECT BY CONSTRUCTION**, compiled once per back end
     with that back end's `tm.h'.  Stated rather than omitted.
  Plus five COMMENT-only mentions (cse.cc:4263, function.cc:2549/:4017/:4019,
  function.h:574) -- fine.

Evidence, both-sided:
  `function.o'  `U ix86_reg_parm_stack_space' **1 -> 0**, and it now binds
                `mt_incoming_reg_parm_stack_space' once.
  `calls.o'/`expr.o'  still 1 each -- the instrument can see the symbol, so
                the 0 is a finding and not a blind spot.
  thunks        i386 = tail `jmp' to `ix86_reg_parm_stack_space'
                (R_X86_64_PLT32, read off `objdump -dr');
                aarch64 = `xor %eax,%eax; ret'.

**A VALUE ARM CANNOT DISTINGUISH THE TWO ON THIS PAIR, AND SAYING SO IS THE
RESULT.**  `ix86_reg_parm_stack_space' returns 32 only for `TARGET_64BIT &&
MS_ABI' and 0 otherwise, so the value aarch64 was leaked is 0 -- exactly what
its own absence produces.  The bug was never the number: it was
`ix86_function_abi' being handed an aarch64 `FUNCTION_DECL' and reading i386's
option state about it.  **Correct by luck**, the `Pmode' trap running the
other way, which is why the evidence is the tail-jmp and the symbol count.

**The `#ifdef' arm is not floored over.**  `assign_parms_initialize_all' does
`memset (all, 0, sizeof (*all))' four lines above, so "macro undefined" and
"macro yielded 0" already produced the same state at the ONE site.

## 4. THE BARS -- ALL IN `/tmp/b134', ON THE FINAL BINARY

  * `make multi-target-objs cc1 lto1' in `$B/gcc' -- **rc=0**.
  * **x86_64 `-O2' big.c md5 `378fc33c1e70', 12369 bytes -- UNMOVED**, before
    and after, same build dir.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock', ABSOLUTE `IN', 5
    distinct md5 per side, **negative control firing (1158 vs 804)**, in THIS
    build dir (`mt cfg :
    /tmp/b134/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config').
    O0 `1c00922491f8', O1 `4fabab94b41b', O2 `378fc33c1e70',
    O3 `d220421237bc', Os `d6787f7e281f'.
  * **aarch64 `int x = 1;' rc=0, 373 bytes, empty stderr, md5 `b01d9157fdc1'**
    -- unmoved.
  * `fn-add'/`fn-call'/`fn-data' byte-identical on BOTH bases:
    aarch64 `28943da2efab'/`d4224a2c155d'/`0252fa95df03';
    x86_64 `f776a3b16e36'/`b9716cd03194'/`e2879feb51f6'.
    (`fn-call' has ONE argument, so it cannot see the order change -- which is
    why `order.c' exists.)
  * `big.c' **unmoved**: `extract_insn, recog.cc:2890'.
  * Both `specs-config' 230 lines, both targets probed with real aarch64
    binutils.
  * Stderr: **incremental `multi-target-objs cc1 lto1' = 0 lines / 0
    `warning:'** on a run no arm had touched a header before; the `defaults.h'
    comment edit rebuilds ~600 objects and gives **451 / 111**, the cold-ish
    arm, matching #133 exactly and NOT comparable with the 8-to-32 incremental
    floor.  Cold `all-gcc' **776 / 169**, also matching #133.

## 5. WHAT I DID NOT DO

  * **No `PUSH_ROUNDING' site converted.**  #133's five-shape classification
    stands untouched.  `PUSH_ARGS_REVERSED' was SHAPE 4 in it (a guard over a
    macro definition); it converted without touching `PUSH_ROUNDING' because
    the guard is `defaults.h''s own and the redirect displaces it whole.
  * **`calls.cc' and `expr.cc' `REG_PARM_STACK_SPACE' paths NOT converted** --
    enumerated and verdicted, above.  Thirteen sites in one file, several of
    them block-spanning.
  * **`insn-emit' NOT TOUCHED.**  #133's `UNSPECV_GET_FPCR' wall (`alloca' +
    `-fstack-clash-protection', aarch64) was not met by this task's inputs and
    nothing here pre-empts the `gen_movxf' ruling.
  * **`dwarf2out.cc:21505' CODEVIEW hook** -- design decision, untouched.
  * **THE SCOREBOARD WAS NOT RUN AND I CLAIM NO MOVEMENT.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS /
    104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64 27/5**.
    **`PUSH_ARGS_REVERSED' IS on the board and its aarch64 arm WILL flip
    FAIL -> PASS on the next run FOR THE WRONG REASON** -- the base-B redirect
    shape, both sides expanding to `(mt_push_args_reversed ())'.  Retire it;
    do not bank it.  It stays `UNCONVERTED' in `macro-status.txt' because it
    is a CALL and `tab-probe.sh' reads constants; the note is recorded there
    beside #108's and #124's.  `INCOMING_REG_PARM_STACK_SPACE' is not on the
    board at all -- **unmeasurable, not clean**.  The converted-without-an-arm
    backlog is now **SEVEN**.
  * No compile-time or memory measurement.  `PUSH_ARGS_REVERSED' is three
    indirect calls per call expression in gimplify.cc, which is the busiest
    site any conversion has taken so far; the recorded artefacts are
    byte-identical on both bases, so this is throughput, not correctness, and
    I am not claiming it is free.
  * `make all-target-libgcc' not re-run; #119's `-m32' blocker unchanged.

## 6. INSTRUMENT NOTES

  * **THE FALLBACK WAS A LADDER AND THE BRIEF DESCRIBED IT AS A CONSTANT.**
    Had the thunk been written to "just return the base's macro" without
    checking WHERE that macro comes from, it would still have been right --
    but only by accident, and only because `target-cumargs.cc' includes
    `defaults.h' with `MULTI_TARGET_TARGETM_BASE' defined.  The reason to
    check is that the OTHER convertible shape (copy the ladder, as #133 had
    to) would have been WRONG here: it would have re-evaluated
    `targetm.calls.push_argument' in a second place.  **Ask which side of the
    `MULTI_TARGET_TARGETM_BASE' guard the fallback lives on before deciding
    whether to copy it.**
  * **`-O0' IS PART OF THE MEASUREMENT, NOT A CONVENIENCE.**  At `-O2' the two
    calls can be reordered by passes that have nothing to do with this macro,
    so a difference there is unattributable and an ABSENCE of difference is
    equally so.  The arm states the flag and why.
  * **A NON-VACUITY REFUSAL ON THE INPUT, not just on the tool.**
    `t134-order.sh' refuses to score if either `f' or `g' is missing from the
    `.s'.  An empty or truncated assembly file otherwise scores as "no
    difference", which is the direction that reads as "nothing was broken".
  * **THE `0' IN `function.o' WAS CHECKED AGAINST TWO OBJECTS THAT STILL SAY
    `1'.**  `calls.o' and `expr.o' binding `ix86_reg_parm_stack_space' is what
    makes `function.o''s zero a finding rather than a demangling failure.
    `index ($0, f)' throughout, never `$0 ~ f'.
  * **A CORRECT-BY-LUCK VALUE IS THE HARDEST KIND TO REPORT.**  The honest
    verdict for `INCOMING_REG_PARM_STACK_SPACE' on this pair is "the value arm
    cannot discriminate, because both answers are 0" -- not a pass.  The
    discriminating evidence is which FUNCTION computes it.

## 7. FILES

    t134-*.sh          derived from #133's, /tmp/b134
    t134-par-inject.sh the PUSH_ARGS_REVERSED redirect, off/on, state asserted
                       in both directions against the LINES not the name
    t134-order.sh      THE BEHAVIOURAL ARM -- h (f (), g ()) at -O0, both
                       bases, call order derived from the .s, vacuity refusal
    t134-rpss.sh       JOB 2 -- object-level both-sided evidence AND the
                       enumeration of every REG_PARM_STACK_SPACE path with a
                       verdict for each, derived from the source
