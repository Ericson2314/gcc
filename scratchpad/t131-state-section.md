
# TASK #131 -- THE WRONG CFI IS DIAGNOSED AND FIXED, AND THE `recog.cc:2890'
# WALL WAS A SECOND, DISTINCT PROBLEM: ONE MACRO, `FUNCTION_MODE'.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in' was **0**, `git reset --hard multi-target' took
it to **39**, and there was no `scratchpad/' at all.  That is now TEN in a
row.  Build dir `/tmp/b131', my own, cold.  **The brief named no task numbers
I could read**; everything below is measured in `/tmp/b131'.

## 0. THE TWO ARTEFACTS, BECAUSE THE SITE IS NOT THE MEASUREMENT

    add   aarch64  rc=0  532 bytes  md5 28943da2efab   (was 557 / 2a70c955a1b1)
    call  aarch64  rc=0  775 bytes  md5 d4224a2c155d   (was ICE recog.cc:2890)
    data  aarch64  rc=0  373 bytes  md5 b01d9157fdc1   -- the recorded bar, met
    add/call/data x86_64  f776a3b16e36 / b9716cd03194 / e2879feb51f6 -- ALL
    THREE BYTE-IDENTICAL before and after, in this build dir.

`int g (int a) { return a + 1; }' now emits, with NO entry note:

        .cfi_startproc
        sub     sp, sp, #16
        .cfi_def_cfa_offset 16
        str     w0, [sp, 12]
        ldr     w0, [sp, 12]
        add     w0, w0, 1
        add     sp, sp, 16
        .cfi_def_cfa_offset 0
        ret

and `int g (int a) { return f (a) + f (a + 1); }' -- which ICEd -- emits a
correct aarch64 frame: `stp x29, x30, [sp, -48]!', `str x19, [sp, 16]', two
`bl f', `ldp x29, x30, [sp], 48', with `.cfi_offset 29/30/19' and
`.cfi_def_cfa_offset 48 -> 0'.

**BOTH ASSEMBLED AND DISASSEMBLED WITH A REAL aarch64 ASSEMBLER**
(`pkgsCross.aarch64-multiplatform.buildPackages.binutils', named and asserted
in `t131-asm.sh' before anything is scored).  `readelf -h' says AArch64, the
disassembly is aarch64 machine code implementing each function, and
`readelf --debug-dump=frames' decodes the unwind table out of the assembled
object:

    CIE  DW_CFA_def_cfa: r31 (sp) ofs 0     Return address column: 30
    FDE  advance 4;  def_cfa_offset 16;  advance 16;  def_cfa_offset 0

i.e. the CFA now starts at sp+0, which is what aarch64 means.  Before, the
same reading was 16 / 32 / 16.

## 1. JOB 1 -- WHAT CARRIED THE WRONG CFI.  MEASURED, NOT INHERITED.

#130 named two candidates and declined to pick, because **16 is not
`UNITS_PER_WORD' (8) on its face**.  `t131-cfi-cause.sh': ONE breakpoint per
run, on `scan_trace', with gdb's own `^Breakpoint N, scan_trace' STOP line
matched (not `info breakpoints') and the backtrace printed, `--args' not
`gdb run', and `dwarf2cfi.cc' rebuilt at **`-g3'** because at `-g' the macro
reads were `No symbol "UNITS_PER_WORD" in current context' -- which is the
error #126 recorded being scored as a pass.  Both bases:

    aarch64:  cfun->machine->func_type = TYPE_EXCEPTION   UNITS_PER_WORD = 8
              INCOMING_FRAME_SP_OFFSET         = 16
              DEFAULT_INCOMING_FRAME_SP_OFFSET =  8
    x86_64:   cfun->machine->func_type = TYPE_NORMAL      UNITS_PER_WORD = 8
              INCOMING_FRAME_SP_OFFSET         =  8
              DEFAULT_INCOMING_FRAME_SP_OFFSET =  8

**16 IS `2 * UNITS_PER_WORD', AND THE ROUTE TO IT IS A NEW INSTANCE OF THE
`identity by address' DISGUISE.**  i386.h:2177 is `(cfun->machine->func_type
== TYPE_EXCEPTION ? 2 * UNITS_PER_WORD : UNITS_PER_WORD)', and `cfun->machine'
points at **aarch64's** `machine_function' object while `dwarf2cfi.cc' was
compiled against **i386's** declaration of that struct name.  So the 2-bit
`func_type' bitfield is read out of whatever aarch64 keeps at that offset, and
it read 3 = `TYPE_EXCEPTION'.  One struct NAME, two layouts, no diagnostic.
Nothing here fixes that type confusion in general -- `i386.h:1650' reads the
same field -- it removes the one read of it that reached emitted unwind data.

**BOTH MACROS HAD TO MOVE, AND THAT IS NOT A JUDGEMENT CALL.**  dwarf2cfi.cc
:2766 emits the entry note only when the two DISAGREE.  With the measured
values: converting `INCOMING_FRAME_SP_OFFSET' alone gives aarch64 0 against
i386's `DEFAULT_' 8, so the note is STILL emitted and now reads
`.cfi_def_cfa_offset 0' -- a different wrong file that still assembles.
Converting `DEFAULT_' alone leaves the real offset at 16.  (That is a
derivation from the two measured values, not a separate measurement: I did not
build the half-converted compiler.)

**THE SIBLINGS THE BRIEF ASKED ABOUT WERE ALREADY CONVERTED.**  Checked, and
stating it because a checked-and-clean family is a result: the four
stack-boundary macros (`INCOMING_STACK_BOUNDARY', `MAX_STACK_ALIGNMENT',
`MAX_SUPPORTED_STACK_ALIGNMENT', `SUPPORTS_STACK_ALIGNMENT'), the DWARF
numbering (`DWARF_FRAME_REGISTERS' / `DWARF_FRAME_REGNUM' / `DEBUGGER_REGNO')
and `DWARF_FRAME_RETURN_COLUMN' all already redirect (defaults.h:2186-2192,
:2289-2293, :2100).  The two sp offsets were the only hole in that closure.

## 2. JOB 2 -- `extract_insn, recog.cc:2890' IS A DISTINCT SECOND PROBLEM.
##    ESTABLISHED FROM THE INSN THE COMPILER PRINTED.

    (call_insn 7 6 8 2 (parallel [
        (set (reg:SI 0 x0)
            (call (mem:QI (symbol_ref:DI ("f") ...) [0 f S1 A8])
                  (const_int 0)))
        (unspec:DI [(const_int 2)] UNSPEC_CALLEE_ABI)
        (clobber (reg:DI 30 x30))]))
    during RTL pass: vregs

Note `mem:QI' and `S1'.  Every one of aarch64's call patterns
(aarch64.md:1563, :1591, :1630, :1646) matches `(call (mem:DI ...))', so
aarch64's own `recog' correctly refused an insn that SHARED code had built to
i386's shape.  The macro is **`FUNCTION_MODE'**: `QImode' at i386.h:2028,
`Pmode' at aarch64.h:1450, spelled by `calls.cc:415' as
`gen_rtx_MEM (FUNCTION_MODE, funexp)'.

**This is NOT the attribute-table family #130 landed, and NOT the unspec
numbering.**  `recog' was already dispatched per base (`multi-target-select.cc'
:644) and was already aarch64's; `insn-recog-{i386,aarch64}.o' both define only
namespaced `recog'.  #127's warning that this might be a second problem was
correct.  Converted, and the wall is gone.

## 3. WHAT LANDED

  * `target-frame.h' -- three new `target_frame_desc' members:
    `function_mode' (beside `pmode'), `incoming_frame_sp_offset',
    `default_incoming_frame_sp_offset'.
  * `target-cumargs.cc' -- three per-base thunks, plus `#include "function.h"'
    (i386's `INCOMING_FRAME_SP_OFFSET' reads `cfun', and without it the build
    failed by name at `i386.h:2178: cfun was not declared in this scope' --
    which is the mechanism working: the read now happens where `cfun->machine'
    means i386's struct).
  * `target-cumargs-select.cc' -- `mt_function_mode',
    `mt_incoming_frame_sp_offset', `mt_default_incoming_frame_sp_offset'.
  * `defaults.h' -- all three redirected, each `#undef'd first.
  * `dwarf2cfi.cc' -- its private `#ifndef DEFAULT_INCOMING_FRAME_SP_OFFSET'
    fallback KEPT, with a comment recording that it is now dead in shared code
    and why answering it there answered it with the primary's headers.

**`HOST_WIDE_INT' AND NOT `poly_int64'** for the two offsets, though
`dw_cfa_location::offset' is a `poly_int64' and that is the tempting type:
var-tracking.cc:549 declares `HOST_WIDE_INT stack_adjust' and :10101 does
`ofst -= ...' on an `int', and `poly_int64' converts implicitly to neither.

**A `#undef' MISTAKE WORTH RECORDING, because the reasoning was plausible and
the failure was a warning count rather than a wrong answer.**  The first draft
did not `#undef' `FUNCTION_MODE' or `DEFAULT_INCOMING_FRAME_SP_OFFSET',
reasoning that defaults.h has no fallback for either so there is nothing to
displace.  There is: the PRIMARY's `i386.h' has already been read at that
point.  The build still succeeded (`rc=0'), the redirect still won, and the
only evidence was **1082 warnings against the 587 of the previous arm** --
`"FUNCTION_MODE" redefined', ~500 times.  "No fallback in this file" and "not
yet defined" are different questions.

## 4. BOTH-SIDED EVIDENCE, AT THE OBJECT LEVEL (`t131-guards.sh' ARM 2)

Cut out of `objdump -dC target-cumargs-<base>.o' under each demangled label,
with a refusal when the cut is empty:

    i386    function_mode                    mov $0x18,%eax; ret   (QImode, 24)
    aarch64 function_mode                    mov $0x1b,%eax; ret   (DImode, 27)
    i386    incoming_frame_sp_offset         reads 0x70(%rdx) i.e. cfun->machine,
                                             tests the func_type bits, 8 or 16
    i386    default_incoming_frame_sp_offset tests the ISA bit, 8
    aarch64 incoming_frame_sp_offset         xor %eax,%eax; ret    (0)
    aarch64 default_incoming_frame_sp_offset xor %eax,%eax; ret    (0)

Both directions diverge, so this is not "everyone now gets the same new
answer".  **0x18/0x1b are the UNIONED mode numbers**, not upstream's; the
first draft of that arm asserted `0x2' for QImode from memory of a
single-target build and failed.

## 5. THE BARS

  * `make multi-target-objs cc1 lto1' in `$B/gcc' -- **rc=0**.
  * **x86_64 `-O2' big.c md5 `378fc33c1e70', 12369 bytes -- UNMOVED.**
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock', absolute `IN', 5
    distinct md5 per side, **negative control firing (1158 vs 804)**,
    demonstrably in THIS build dir (`mt cfg : /tmp/b131/lib/...').
    O0 `1c00922491f8', O1 `4fabab94b41b', O2 `378fc33c1e70',
    O3 `d220421237bc', Os `d6787f7e281f'.  Run twice, before and after the
    `FUNCTION_MODE' half.
  * **aarch64 `int x = 1;' rc=0, 373 bytes, empty stderr, md5 `b01d9157fdc1'**
    -- the recorded bar, unmoved.
  * `t131-guards.sh': **34 PASS / 0 FAIL**, ARM 0 content-by-name first, ARM 1
    the positional-initialiser order with a non-vacuity floor, ARM 2 the
    object-level values with an empty-cut refusal, ARM 3 the emitted CFI, ARM
    5 injection with a state assertion in both directions and a restore.
  * Incremental stderr: **24 lines, 0 `warning:', all 24 `'@' is redundant'
    from unmodified aarch64 `.md'** -- within the documented 8-to-32 floor,
    composition stated.

## 6. AN INSTRUMENT TRAP THIS RUN PRODUCED

**`cp' TO RESTORE AN INJECTED FILE REBUILDS THE WORLD.**  ARM 5 restores
`defaults.h' by content, which is correct -- and moves its mtime, so the next
`make' recompiled ~600 objects and reported **451 stderr lines** where the
incremental floor is 24.  Read as a stderr regression that is a false alarm;
read as a no-op arm it is a false green about what was rebuilt.  Take the
incremental reading from a `make' that no arm has touched a header before.

**`awk '$0 ~ f'' WITH A DEMANGLED C++ NAME MATCHES NOTHING.**  `<mt_base_
function_mode()>:' is a REGEX to awk, and `()' is an empty group, so the
pattern silently becomes `<mt_base_function_mode>:'.  All six ARM 2 arms
scored EMPTY -- which reads as "there is no per-base copy", the opposite of
the truth.  `index ($0, f)'.  Same family as #129's `nm -C' anchor and
PRINCIPLES' `nm -u' substring: a zero from a name-matching instrument is a
claim about the pattern.

**AND THE ONE THAT NEARLY COST AN ARM ITS MEANING:** `fn-data.c' gives
`375 bytes / 0252fa95df03' while `small.c' with identical CONTENT gives
`373 / b01d9157fdc1'.  The two-byte difference is the FILENAME in the `.file'
directive.  I spent time treating it as a DATESTAMP-dependent bar before
finding it; it is #125's lesson (`g-small.c' vs `small.c') arriving again.
**The recorded `b01d9157fdc1' bar is `small.c' and is met.**

## 7. WHAT I DID NOT DO

  * **`big.c' still fails, at the SAME SITE but on a DIFFERENT insn**, and I
    am not calling that unmoved or moved:

        f_builtin:  (insn 34 33 0 3 (const_int 0 [0]))
        during RTL pass: ira, via ira_remove_insn_scratches

    A bare `const_int 0' as a whole pattern.  That is a THIRD distinct
    problem.  The un-namespaced `insn-emit' family (`gen_blockage', `gen_nop'
    -- section 6 of #130) is the obvious suspect and I did **not** establish
    it; the printed pattern is not literally either back end's `blockage'
    (`(unspec_volatile [(const_int 0)] UNSPECV_BLOCKAGE)').  Recorded as
    UNDIAGNOSED with a named suspect, not as understood.
  * **`insn-emit' untouched**, per the brief: any forwarder scheme there
    decides `gen_movxf' by implication and that needs the user's ruling.
  * **The `cfun->machine' type confusion in general.**  `i386.h:1650' reads
    `func_type' too, and `struct machine_function' is one name with 48
    layouts.  Only the one read reaching unwind data is closed.
  * **`ARG_POINTER_CFA_OFFSET' (defaults.h:1219) is in the same neighbourhood
    and is NOT converted**: it expands to `FIRST_PARM_OFFSET (FNDECL) +
    crtl->args.pretend_args_size', i.e. another primary-answered macro, and
    `FRAME_POINTER_CFA_OFFSET' is `#ifdef'd at six shared sites (function.cc,
    var-tracking.cc x4, dwarf2out.cc) with neither i386 nor aarch64 defining
    it.  Found while sweeping, left alone, recorded.
  * **The scoreboard was NOT run and I claim no movement.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS /
    104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64 27/5**.
    `INCOMING_FRAME_SP_OFFSET', `DEFAULT_INCOMING_FRAME_SP_OFFSET' and
    `FUNCTION_MODE' are not in `macro-status.txt', so the correct entry is
    "no probe arm exists" -- **unmeasurable, not clean**.  They are ordinary
    `tm.h' macros and DO belong on the board; adding three arms is a task.
  * No compile-time or memory measurement.  `FUNCTION_MODE' is now an indirect
    call at eleven sites including `SET_DECL_MODE' on every FUNCTION_DECL.
    x86_64 output is byte-identical, so this is throughput and not
    correctness, but it is unmeasured and I am not claiming it is free.
  * `make all-target-libgcc' not re-run; #119's `-m32' blocker unchanged.

## 8. FILES

    t131-clone.sh     derives my build-dir scripts from #130's; REFUSES on a
                      leftover `b131'
    t131-conf.sh      two-target configure, /tmp/b131
    t131-build.sh     make at the TOP level      -- `all-gcc' goes here
    t131-gccbuild.sh  make in $B/gcc             -- `multi-target-objs' here;
                      running the latter through the former is `No rule to
                      make target', which cost one arm
    t131-specs.sh     both target-specs probes, real aarch64 binutils
    t131-dbg.sh       rebuilds dwarf2cfi.o at `-g3' (NOT `-g': the macro reads
                      need macro debug info) and relinks
    t131-cfi-cause.sh THE JOB 1 DIAGNOSIS: one breakpoint per run, gdb's own
                      STOP line matched, both bases
    t131-asm.sh       assembles + disassembles + decodes .eh_frame with the
                      REAL aarch64 binutils, tools named and asserted first
    t131-fn.sh        the three function-body inputs, both bases
    t131-state.sh     big.c site + `int x = 1;' + x86_64 -O2
    t131-sc.sh        stock-compare, ABSOLUTE big.c, tagged outdir
    t131-guards.sh    34 arms; ARM 0 first, ARM 2 the object-level values,
                      ARM 5 injection with control and restore
