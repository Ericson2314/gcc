
# TASK #133 -- `STACK_DYNAMIC_OFFSET': THE LEAK THAT RUNS THE OTHER WAY, FIXED
# AND MEASURED BOTH-SIDED IN A RUNNING cc1 -- PLUS ALL 19 `PUSH_ROUNDING'
# SITES CLASSIFIED AND NONE CONVERTED.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in' was **0**, `git reset --hard multi-target' took
it to **39**, no `scratchpad/'.  That is now TWELVE in a row.  Build dir
`/tmp/b133', my own, cold.  **The brief named no task numbers I could read**;
that is the coordinator's error and everything below is measured in
`/tmp/b133'.

## 1. JOB 1 -- THE FIX, AND WHY IT WAS A ONE-CALL CONVERSION

aarch64 DEFINES `STACK_DYNAMIC_OFFSET' (aarch64.h:1688); i386 does NOT; nine
back-end headers do.  `function.cc:1411' asked `#ifndef STACK_DYNAMIC_OFFSET'
in a translation unit compiled with i386's `tm.h', so the `#ifndef' was true,
**aarch64's definition was discarded for every target including aarch64**, and
function.cc's own generic ladder was used instead.

**THE DIRECTION IS THE POINT.**  Every previous entry in this family is "the
primary's answer reaches everyone".  This is "**the NON-primary's answer
reaches no one, itself included**" -- the `INIT_EXPANDERS' shape, where i386
defined nothing and aarch64's `init_machine_status' was never installed.  An
absence produces **no code at all**, so no instrument that looks for a wrong
symbol or a wrong value can see it; `nm' scores a discarded definition exactly
as it scores a correct one.  That is why this class keeps being found by
accident.

Four parts, the shape #131/#132 already established:

  * `target-frame.h'         -- `poly_int64 (*stack_dynamic_offset) (tree)'
  * `target-cumargs.cc'      -- `mt_base_stack_dynamic_offset', with BOTH ARMS
    OF function.cc's LADDER REPRODUCED INSIDE IT (and the
    `INCOMING_REG_PARM_STACK_SPACE'-from-`REG_PARM_STACK_SPACE' derivation
    that chooses between them), so the `#ifndef' is a fact about THIS base
  * `target-cumargs-select.cc' -- `mt_stack_dynamic_offset (tree)'
  * `function.cc'            -- the shared ladder DELETED; the existing
    wrapper `get_stack_dynamic_offset ()' now calls the selector

**NO `defaults.h' REDIRECT, deliberately.**  Upstream already funnels the
macro through `get_stack_dynamic_offset ()' (added 2023 "so that the macro
sees a predictable set of included files" -- the set of included files was the
bug).  It is the ONLY evaluation point in the tree, so the call goes there
directly and the name is left **undefined in shared code**: a future shared
spelling now fails BY NAME instead of quietly picking up a generic ladder.
Same treatment `mt_init_expanders' gave `#ifdef INIT_EXPANDERS'.

**REPRODUCING THE LADDER IS NOT THE `#ifndef' FLOOR PRINCIPLES FORBIDS.**  The
floor is forbidden because it makes a MISSING answer look like an answer.
Here 42 of 51 back ends genuinely have no definition and the generic ladder IS
their own headers' answer; what changed is which translation unit evaluates
it.  Same argument `mt_base_default_incoming_frame_sp_offset' records for
dwarf2cfi.cc's private `#ifndef'.

## 2. THE EVIDENCE, BOTH-SIDED, IN THE RUNNING cc1

**THE CODEGEN ARM CANNOT RUN ON aarch64, and that is a finding, not a gap.**
The aarch64 arm needs `flag_stack_clash_protection && cfun->calls_alloca'.
`t133-alloca-wall.sh' isolates it with four arms so it cannot be attributed to
the wrong flag:

    a64  alloca, no  -fstack-clash-protection   rc=0  765 bytes
    a64  alloca, YES -fstack-clash-protection   rc=1  WALL
    a64  no alloca,  YES -fstack-clash-protection   rc=0  666 bytes
    x86  all three                              rc=0  506 / 818 / 357

The wall is `error: unrecognizable insn: (insn 20 48 21 6 (unspec_volatile
[(const_int 0)] UNSPECV_GET_FPCR))' at pass `vregs'.  **That is the
un-namespaced `insn-emit' family printing i386's `gen_blockage' number through
aarch64's UNSPECV name table** -- #132's `big.c' suspect, now NAMED rather
than suspected, and out of scope per the brief.  **It is identical with this
task's change injected OFF**, so it is pre-existing and not caused here.

**SO THE READING WAS TAKEN IN gdb INSTEAD**, which the wall does not block:
the ICE is at `extract_insn', AFTER `instantiate_virtual_regs' has already
called `get_stack_dynamic_offset'.  `t133-sdo-cause.sh': ONE breakpoint per
run, matched against gdb's own `^Breakpoint N, get_stack_dynamic_offset' STOP
line AND the backtrace, `--args' not `gdb run', function.cc rebuilt at `-g3'.
Injection OFF and back ON in the SAME build dir (`t133-inject-sdo.sh', awk not
python3, state asserted in BOTH directions):

                        OFF (pre-#133)      ON (fixed)
    aarch64             coeffs = {0, 0}     coeffs = {16, 0}    CHANGED
    x86_64              coeffs = {0, 0}     coeffs = {0, 0}     unchanged

with the three gates read in the same stop: `flag_stack_clash_protection = 1',
`cfun->calls_alloca = 1', `crtl->outgoing_args_size = {0, 0}'.  **16 is
`ROUND_UP (STACK_CLASH_MIN_BYTES_OUTGOING_ARGS = 8, STACK_BOUNDARY/8 = 16)'**,
i.e. aarch64.h:1688 exactly.  The x86_64 column is what distinguishes "fixed"
from "everyone now gets the same new answer".

**WHAT WAS SILENTLY WRONG:** aarch64's reservation exists so `alloca' can SKIP
A PROBE.  Under the generic ladder it never happened, so
`-fstack-clash-protection' code with `alloca' was built without the space its
probing strategy assumes -- exit 0 throughout, as always.

**OBJECT LEVEL, BOTH DIRECTIONS** (`t133-obj.sh', `index ($0, f)', empty-cut
refusal, nm non-vacuity floor of 117318 undefined lines):

    aarch64  cmpl $0x0, flag_stack_clash_protection
             testb $0x2, 0xcc(cfun)          <- calls_alloca
             cmpq $0x0 / cmpq $0x7           <- known_lt (out_args_size, 8),
                                                a two-coefficient poly compare
             mov $0x10,%eax                  <- 16
    i386     mov 0x70(%rax),%rax             <- cfun->machine
             mov 0xf0(%rax),%eax
             and $0x18000,%eax               <- func_type bits, via
                                                ACCUMULATE_OUTGOING_ARGS
             call ...                        <- OUTGOING_REG_PARM_STACK_SPACE

**This is the first entry in the family where the fix makes code EXIST that
was not there before.**  The aarch64 body is 19 lines of instructions that no
object in the tree contained, because the macro that generates them had been
`#ifndef''d away.  `function.o' binds `U mt_stack_dynamic_offset(tree_node*)'
-- 1 object, and 1 is correct here rather than suspicious: there is exactly
one evaluation point.

## 3. JOB 2 -- ALL 19 `PUSH_ROUNDING' SITES CLASSIFIED, NONE CONVERTED

`t133-push-sites.sh' re-derives the list (41 shared mentions, 19 preprocessor
sites, 12 value sites).  Full verdicts are written into `defaults.h' beside
#132's neighbour verdicts, in five shapes:

  1. ordinary statements under the guard -- 11 sites, mechanical
     (calls.cc:5181, function.cc:4151, lra-eliminations.cc:798,
      reload1.cc:3030, recog.cc:1835, rtlanal.cc:4914, expr.cc:4300,
      expr.cc:4354, expr.cc:1639, cse.cc:5628, targhooks.cc:912)
  2. `#ifndef' over ordinary statements -- expr.cc:1679,
     combine-stack-adj.cc:841
  3. guard over a DECLARATION/DEFINITION -- expr.cc:108, expr.cc:5149;
     cannot become an `if', but needs no flag: define unconditionally
  4. guard over a MACRO DEFINITION -- expr.cc:1595 (`PUSHG_P'),
     defaults.h:916 (`PUSH_ARGS_REVERSED')
  5. `#endif' between an `if' and its `else' -- expr.cc:5384/:5424 and
     expr.cc:5620/:5624; a RESTRUCTURE, not a substitution

Three things the classification found that the count does not show:

  * **`targhooks.cc:912' is the default of an EXISTING target hook**
    (`default_push_argument'), and several SHAPE-1 sites already test
    `targetm.calls.push_argument (0)' INSIDE the `#ifdef'.  For those the
    existence question is ALREADY answered at run time and the `#ifdef' is a
    compile-time short circuit on top of it.  Converting that one line closes
    more of this family than its size suggests.
  * **`combine-stack-adj.cc:841' is compiled out for every target** (#132's
    finding, re-confirmed).  Converting it TURNS A PASS GATE ON for the 38
    back ends with no `PUSH_ROUNDING'.  It is the only site whose conversion
    changes pass behaviour rather than a value and it wants its own
    before/after.
  * **A TYPE DECISION, NOT A TRANSCRIPTION.**  recog.cc:1836 spells
    `PUSH_ROUNDING (MACRO_INT (rounded_size))'; `MACRO_INT' is
    `.to_constant ()' when `NUM_POLY_INT_COEFFS > 1', and it exists because
    some back ends' macros are not poly-safe.  A `poly_int64
    mt_push_rounding (poly_int64)' removes the wrapper at the shared sites but
    the per-base thunk must keep it.  Decide the signature once for all 12
    value sites.

**AND A LEAK FOUND IN THE CLOSURE, CHEAPER THAN ANY OF THEM.**
`PUSH_ARGS_REVERSED': i386.h:1658 defines it to 1, aarch64 does not, bpf and
nvptx do.  Its only shared use is gimplify.cc:4791-4793 -- three ordinary
run-time expressions in one `for' header -- so **argument gimplification runs
last-to-first for every target because the primary says so**.  No preprocessor
use anywhere; SHAPE 1, one file.  Recorded, not taken.

`REG_PARM_STACK_SPACE' still leaks: `function.o' binds
`U ix86_reg_parm_stack_space(tree_node const*)' even AFTER this task, because
function.cc:2327 spells `INCOMING_REG_PARM_STACK_SPACE' separately from the
ladder that moved out.  PRINCIPLES' "one symbol can have several macro paths",
measured again.

## 4. THE BARS -- ALL IN `/tmp/b133', AFTER THE FINAL REBUILD

  * `make multi-target-objs cc1 lto1' in `$B/gcc' -- **rc=0**.
  * **x86_64 `-O2' big.c md5 `378fc33c1e70', 12369 bytes -- UNMOVED**, before
    and after, same build dir.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock', ABSOLUTE `IN', 5
    distinct md5 per side, **negative control firing (1158 vs 804)**, and
    demonstrably in THIS build dir (`mt cfg :
    /tmp/b133/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config').
    O0 `1c00922491f8', O1 `4fabab94b41b', O2 `378fc33c1e70',
    O3 `d220421237bc', Os `d6787f7e281f'.
  * **aarch64 `int x = 1;' rc=0, 373 bytes, empty stderr, md5 `b01d9157fdc1'**
    -- the recorded bar (`small.c'; `fn-data.c' is 375 / `0252fa95df03',
    differing only in the `.file' name), unmoved.
  * `fn-add' / `fn-call' / `fn-data' byte-identical on BOTH bases:
    aarch64 `28943da2efab' / `d4224a2c155d' / `0252fa95df03';
    x86_64 `f776a3b16e36' / `b9716cd03194' / `e2879feb51f6'.
  * `big.c' **unmoved**: `extract_insn, recog.cc:2890'.
  * Stderr: **incremental `multi-target-objs cc1 lto1' = 0 lines / 0
    `warning:'** on a run whose sources no arm had touched.  The `defaults.h'
    comment edit rebuilds ~600 objects and gives **451 lines / 111
    `warning:'** -- that is the cold-ish arm and is NOT comparable with the
    8-to-32 incremental floor.  Cold `all-gcc' was **776 / 169**.

## 5. WHAT I DID NOT DO

  * **No `PUSH_ROUNDING' site converted**, per the brief: classify first.  The
    classification is the deliverable and it is in `defaults.h' by site.
  * **`PUSH_ARGS_REVERSED' not converted** -- found, named, one file.
  * **`REG_PARM_STACK_SPACE' / `INCOMING_REG_PARM_STACK_SPACE' not converted.**
  * **`insn-emit' NOT TOUCHED.**  This task NAMED its wall
    (`UNSPECV_GET_FPCR' on `alloca' + `-fstack-clash-protection', aarch64) and
    stopped: a forwarder scheme there decides `gen_movxf' by implication and
    needs the user's ruling.  Note this wall is now the thing standing between
    `STACK_DYNAMIC_OFFSET' and an assembly-level arm, so the two are coupled.
  * **`dwarf2out.cc:21505' CODEVIEW hook** -- design decision, untouched.
  * **`ARG_POINTER_CFA_OFFSET'** -- still UNMEASURABLE WITH THIS PAIR (#132).
  * **The scoreboard was NOT run and I claim NO movement.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS /
    104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64 27/5**.
    `STACK_DYNAMIC_OFFSET' is not in `macro-status.txt', so the correct entry
    is **"no probe arm exists" -- unmeasurable, not clean**.  It is an
    ordinary `tm.h' macro and DOES belong on the board.  The backlog of
    macros converted with no probe arm is now
    `INCOMING_FRAME_SP_OFFSET', `DEFAULT_INCOMING_FRAME_SP_OFFSET',
    `FUNCTION_MODE' (#131), `ACCUMULATE_OUTGOING_ARGS' (#132) and
    `STACK_DYNAMIC_OFFSET' (#133) -- **five**, and adding those five arms is
    now a task in its own right rather than a footnote.
  * No compile-time or memory measurement.  `STACK_DYNAMIC_OFFSET' is one
    indirect call per function at `instantiate_virtual_regs', which is the
    cheapest of any conversion so far; it is still unmeasured.
  * `make all-target-libgcc' not re-run; #119's `-m32' blocker unchanged.

## 6. INSTRUMENT NOTES

  * **MY OWN INJECTION GUARD WAS WRONG IN THE SAFE DIRECTION, AND THAT IS THE
    ONLY REASON I SAW IT.**  `t133-inject-sdo.sh' asserted "the redirect is
    gone" with `grep -c mt_stack_dynamic_offset', which also matches the
    **comment** naming the function.  The injection had in fact succeeded; the
    assertion failed anyway and refused to proceed.  Had I written the
    complementary check the same way it would have passed on a FAILED
    injection.  The fix is to match the CALL (`return mt_stack_dynamic_offset')
    and not the name.  Generalise: **an assertion on a symbol name matches the
    prose about the symbol too**, and prose is exactly what these files are
    full of.
  * **A WALL CAN BE THE MEASUREMENT'S PROBLEM RATHER THAN THE PATCH'S, AND THE
    WAY TO TELL IS A 2x2.**  `-fstack-clash-protection' + `alloca' walls on
    aarch64; running only that one arm would have read as "this task broke
    aarch64".  Four arms (alloca x clash x base) placed it exactly, and the
    injected-OFF run reproduced it byte for byte.
  * **THE ICE SITE WAS UPSTREAM OF THE READING I WANTED, WHICH IS WHY gdb
    WORKED.**  `get_stack_dynamic_offset' is called at
    `instantiate_virtual_regs'; the ICE is later, at `extract_insn'.  A
    "compile it and diff the assembly" arm scores that as unmeasurable; a
    breakpoint reads it fine.  **When codegen is blocked, ask whether the
    value you want is computed BEFORE the block.**
  * **`nm -C` scored the aarch64 thunk in x86-64 opcodes, correctly.**  Both
    per-base `target-cumargs-<base>.o' are HOST objects (x86-64), one
    per back end -- the aarch64 one contains x86-64 code implementing
    aarch64's ANSWERS.  Reading `mov $0x10,%eax' there is the reading, not a
    sign of a mixed-up object.
  * **The per-base objects are `target-cumargs-<base>.o' in `$B/gcc', NOT
    `mt-<base>/target-cumargs.o'.**  My first arm looked in `mt-<base>/', got
    "no such file", and would have reported "no per-base copy exists" -- the
    exact false negative PRINCIPLES warns about -- had it not had a FATAL
    instead of a silent skip.
