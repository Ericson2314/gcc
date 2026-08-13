
# TASK #132 -- THE `cfun->machine' SWEEP.  ELEVEN MACROS ENUMERATED, NINE
# CLEAN, ONE ALREADY DONE, ONE FIXED -- AND THE GUARDS OVER IT ARE A SECOND,
# LARGER LEAK THAT RUNS IN BOTH DIRECTIONS.

Worktree came up at bare-repo HEAD `7208eca60d0' AGAIN -- `grep -c
MULTI_TARGET gcc/Makefile.in' was **0**, `git reset --hard multi-target' took
it to **39**, no `scratchpad/' at all.  That is now ELEVEN in a row.  Build
dir `/tmp/b132', my own, cold.  **The brief named no task numbers I could
read**, which is the coordinator's error and not mine; everything below is
measured in `/tmp/b132'.

## 0. THE ENUMERATION -- DERIVED FROM THE HEADERS, NOT TYPED (`t132-sweep.sh')

The brief's framing was right: `machine_function' is a struct DECLARATION,
not a symbol, so `nm' says nothing, and a header probe cannot see it either
because both bases declare a struct of that name.  What CAN be enumerated is
the set of macros whose bodies reach `cfun->machine', and then which of those
NAMES shared code spells.  Eleven such macros in `i386.h'.  Spelled outside
`config/' (ChangeLogs excluded): **exactly two**.

    ACCUMULATE_OUTGOING_ARGS      i386.h:1647   SHARED, ~40 sites   <- FIXED
    INCOMING_FRAME_SP_OFFSET      i386.h:2177   SHARED              <- #131

    ix86_stack_locals                            CLEAN
    ix86_varargs_gpr_size                        CLEAN
    ix86_varargs_fpr_size                        CLEAN
    ix86_optimize_mode_switching                 CLEAN
    ix86_pc_thunk_call_expanded                  CLEAN
    ix86_tls_descriptor_calls_expanded_in_cfun   CLEAN
    ix86_static_chain_on_stack                   CLEAN
    ix86_red_zone_used                           CLEAN
    TARGET_INDIRECT_BRANCH_REGISTER              CLEAN

CLEAN means: spelled ONLY inside `config/i386/', where `cfun->machine' does
mean i386's struct.  **A checked-and-clean family is a result**, so they are
listed by name in `defaults.h' as well as here.

**The tm.h chain bounds this.**  i386's chain adds linux/unix/att/gnu-user/
x86-64, and `grep cfun->machine' over all of `config/*/*.h' shows the only
i386-side hits are the eleven in `i386.h' plus two in `i386-features.h',
which is not in tm.h.  So the enumeration is bounded and provable, not a
best-effort scan.

**DIRECT dereferences of `cfun->machine' in shared code: exactly ONE** (grep
for `cfun->machine->' outside `config/'), `dwarf2out.cc:21505-21509'.  See
section 3.  `function.cc:4870' assigns the pointer and never dereferences it;
that is fine.

**THE GENERAL FORM, ASKED AND ANSWERED (`t132-types.sh').**  Type names
declared in BOTH bases' headers: `reg_class' (known, handled),
`seh_frame_state' (both bases forward-declare it as an OPAQUE `GTY((skip))'
pointer -- aarch64 has SEH now, for `aarch64-w64-mingw32' -- and shared code
never dereferences it: FINE), and `GTY' (an artefact of the awk, not a type).
So `cfun->machine' is the only per-back-end pointee type shared code actually
reads through.

## 1. THE FIX -- `ACCUMULATE_OUTGOING_ARGS'

Same four-part shape #131 used: a `target_frame_desc' member, a per-base
thunk in `target-cumargs.cc', a selector in `target-cumargs-select.cc', an
`#undef'-then-redirect in `defaults.h'.

**WORSE THAN :2177, NOT MILDER.**  :2177 is `func_type == TYPE_EXCEPTION', so
one of eight bit patterns misfires.  This is `func_type != TYPE_NORMAL', so
**seven of eight do**.  #131 measured aarch64's bits reading 3.

**A CALL, NOT A CONSTANT.**  i386's body reads `cfun' three ways, and
`crtl->stack_realign_needed' is written DURING reload -- not constant across
a run, across two functions, or across two passes over one function.

**`emit-rtl.h' AND `predict.h' HAD TO BE ADDED to `target-cumargs.cc'.**
Without them: `i386.h:1651: crtl was not declared in this scope'.  That is
the mechanism working, identically to #131's `cfun' failure -- the read now
happens where the struct name means i386's struct, so i386's headers have to
be satisfiable there.

**`#undef' FIRST, and here there really IS a fallback in this file** --
`defaults.h:902' defines the name itself.  #131 paid 495 warnings learning
that "no fallback in this file" and "not yet defined" are different
questions; this time the `#undef' went in from the start.

## 2. THE EVIDENCE IT IS NOT INERT, AND IT IS BOTH-SIDED

**#131's three artefacts are ALL byte-identical across this change**, which
reads as "the fix did nothing".  It is not: none of `fn-add', `fn-call',
`fn-data' has outgoing arguments ON THE STACK, and `ACCUMULATE_OUTGOING_ARGS'
decides nothing when there are none.  `scratchpad/fn-outargs.c' -- ten
arguments, so two go on the stack on aarch64 -- is the input that moves.
Measured with the redirect INJECTED OFF and back ON in the same build dir
(`t132-inject.sh', sed not python3, state asserted in BOTH directions):

    aarch64  850 bytes d282037340da  ->  793 bytes 41cbd5927c02   CHANGED
    x86_64   604 bytes a3031ab34010  ->  604 bytes a3031ab34010   unchanged

x86_64 must NOT move -- it was already getting i386's answer -- and does not.
That is what distinguishes "fixed" from "everyone now gets the same new
answer".

**THE DIFF IS WRONG CODE, NOT A COSMETIC DIFFERENCE:**

    -       str     w2, [sp, -8]!        <- aarch64 does not PUSH arguments
    -       .cfi_def_cfa_offset 40
    +       str     w2, [sp, 8]
    -       str     w2, [sp, -8]!
    -       .cfi_def_cfa_offset 48
    +       str     w2, [sp]
    -       ldp     x29, x30, [sp, 32]
    -       add     sp, sp, 48
    +       ldp     x29, x30, [sp, 16]
    +       add     sp, sp, 32
    -       .cfi_def_cfa_offset -16      <- a NEGATIVE CFA offset
    +       .cfi_def_cfa_offset 0

i386's answer is normally 0 on x86_64-linux and aarch64's own is the constant
1, so aarch64 was being compiled in the **push-arguments-individually shape
it does not have**, and the epilogue CFI ended at `.cfi_def_cfa_offset -16'
-- an unwinder computing the CFA sixteen bytes BELOW the stack pointer.  Exit
0 throughout, as always.

**ASSEMBLED, DISASSEMBLED AND FRAME-DECODED with real aarch64 binutils**
(`pkgsCross.aarch64-multiplatform.buildPackages.binutils', named and asserted
first).  Correct AAPCS64 -- `w0'-`w7' plus `[sp]' and `[sp,#8]' -- and

    CIE  DW_CFA_def_cfa: r31 (sp) ofs 0     Return address column: 30
    FDE  advance 4; def_cfa_offset 32; offset r29 at cfa-16, r30 at cfa-8;
         advance 60; restore r29/r30; def_cfa_offset 0

**OBJECT LEVEL, BOTH DIRECTIONS** (`t132-obj.sh', `index ($0, f)' and an
empty-cut refusal):

    aarch64  mt_base_accumulate_outgoing_args   mov $0x1,%eax; ret
    i386     mt_base_accumulate_outgoing_args   mov 0x70(%rax),%rax <- cfun->machine
                                                mov 0xf0(%rax),%eax
                                                and $0x18000,%eax   <- func_type bits
                                                ... plus the option-state tests

i.e. i386 still reads that bitfield, at an offset that is now correct because
the TU declares i386's struct.  Eleven shared objects bind
`mt_accumulate_outgoing_args()'; `combine-stack-adj.o' binds **0**, and that
is not a miss -- see section 4.

## 3. THE NEIGHBOURS, WITH VERDICTS (recorded in `defaults.h' too)

**`ARG_POINTER_CFA_OFFSET' -- CORRECT TODAY FOR A REASON THAT DOES NOT
SCALE.**  Neither base defines it, so both reach `defaults.h:1219''s
`FIRST_PARM_OFFSET (FNDECL) + crtl->args.pretend_args_size', and
`FIRST_PARM_OFFSET' is the literal **0 in both** (i386.h:1661,
aarch64.h:1062).  The leak is real; its value happens to agree.  That is the
wrong-reason green PRINCIPLES names.  Nine back ends define it directly (rx
4, avr -1, pru non-constant, six others 0).  **Not converted, because with a
pair that agrees there is no measurement that could distinguish the fix from
the status quo.**  Recorded as UNMEASURABLE WITH THIS PAIR -- not clean.

**`FRAME_POINTER_CFA_OFFSET' -- CANNOT BECOME A CALL.  Position of use
decides shape.**  `#ifdef'-tested at six shared sites (function.cc:1466,
:1967; var-tracking.cc:9990, :10093, :10146, :10166, :10202;
dwarf2out.cc:21620).  Defining the name to a call makes every one of those
guards TRUE for every target -- the `#if HAVE_ATTR_length' failure in
reverse.  Only nvptx, vax and pa define it; neither base does, so all six are
FALSE and that is each base's own answer.  **What it needs is a build-time
union check** ("no configured base may define it unless they all agree"), not
a conversion.  Not written; it belongs with the other union-list checks.

**`dwarf2out.cc:21505-21509' -- THE ONLY DIRECT DEREFERENCE, AND NO REDIRECT
CAN FIX IT.**  Shared code reads `cfun->machine->fs.cfa_reg->u.reg.regno',
`.fs.fp_valid', `.fs.fp_offset', `.fs.sp_offset' -- i386's
`machine_frame_state', BY FIELD NAME.  There is no macro to redirect.  It is
inside `#ifdef CODEVIEW_DEBUGGING_INFO', defined only by
`config/i386/cygming.h', so it is **dead in this configuration** and in any
whose bases exclude cygming; it is not dead in general.  **The fix is a
target hook, i.e. a design decision, and I stopped rather than invent one.**

## 4. THE GUARDS -- A SECOND LEAK, LARGER, AND IT RUNS BOTH WAYS

PRINCIPLES says: when a symbol names your suspect, walk the GUARDS that
decided you reached that line.  `t132-sites.sh' classifies each use by its
own line, which answers "can this become a call?".  `t132-guardctx.sh' asks
the other question, and found two.

**`PUSH_ROUNDING' -- i386 DEFINES IT, aarch64 does NOT.**  13 of 51 back ends
define it; shared code asks `#ifdef PUSH_ROUNDING' at **19 sites** (expr.cc
x8, calls.cc, cse.cc, recog.cc, reload1.cc, lra-eliminations.cc, rtlanal.cc,
function.cc, targhooks.cc, combine-stack-adj.cc, defaults.h).  Two sit
directly over `ACCUMULATE_OUTGOING_ARGS' uses:

  * `targhooks.cc:913' -- `default_push_argument' is `return
    !ACCUMULATE_OUTGOING_ARGS;' inside `#ifdef PUSH_ROUNDING', a guard the
    PRIMARY makes true.  (My change does improve this site even under the
    wrong guard: aarch64 now gets `!1 = false' where it used to get
    `!0 = true', i.e. it no longer claims to push arguments.)
  * `combine-stack-adj.cc:842' -- inside `#ifndef PUSH_ROUNDING', so the test
    is **compiled OUT for every target**.  That is why `combine-stack-adj.o'
    binds the new selector 0 times; the 0 is real and is a finding, not a
    measurement failure.

`calls.o' also still carries `U ix86_push_rounding(poly_int<2u,long>)' and
`U ix86_reg_parm_stack_space(tree_node const*)', so `PUSH_ROUNDING' leaks as
a VALUE as well as an existence question.

**`STACK_DYNAMIC_OFFSET' -- AND THIS ONE RUNS THE OTHER WAY.**  **AARCH64
defines it** (aarch64.h:1688, the `-fstack-clash-protection' outgoing-args
reservation); **i386 does not**; `function.cc:1411' asks `#ifndef
STACK_DYNAMIC_OFFSET' and gets the PRIMARY's answer, so **aarch64's own
definition is discarded for every target** and function.cc's generic one is
used instead.  A leaked ABSENCE of the NON-primary base's answer -- the same
shape target-frame.h records for `INIT_EXPANDERS', and the same family as
`HAVE_V8HFmode' in that the primary/union answers where the selected base
should.  **Not fixed.  It is an existence predicate and wants the
`has_init_expanders' pair shape, which is a task.**

Also in that closure and unconverted: `REG_PARM_STACK_SPACE' (i386 defines,
aarch64 does not; guards `calls.cc:3571' and `:4598') and
`INCOMING_REG_PARM_STACK_SPACE' (neither defines).

## 5. THE BARS -- ALL IN `/tmp/b132', BEFORE AND AFTER IN THE SAME BUILD DIR

  * `make multi-target-objs cc1 lto1' in `$B/gcc' -- **rc=0**.
  * **x86_64 `-O2' big.c md5 `378fc33c1e70', 12369 bytes -- UNMOVED.**
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock', absolute `IN', 5
    distinct md5 per side, **negative control firing (1158 vs 804)**, and
    demonstrably in THIS build dir (`mt cfg :
    /tmp/b132/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config').
    O0 `1c00922491f8', O1 `4fabab94b41b', O2 `378fc33c1e70',
    O3 `d220421237bc', Os `d6787f7e281f'.
  * **aarch64 `int x = 1;' rc=0, 373 bytes, empty stderr, md5
    `b01d9157fdc1'** -- the recorded bar (`small.c'; `fn-data.c' is 375 /
    `0252fa95df03', differing only in the `.file' name), unmoved.
  * `fn-add' / `fn-call' / `fn-data' byte-identical on BOTH bases:
    aarch64 `28943da2efab' / `d4224a2c155d' / `0252fa95df03';
    x86_64 `f776a3b16e36' / `b9716cd03194' / `e2879feb51f6'.
  * `big.c' **unmoved**: `extract_insn, recog.cc:2890' during RTL pass `ira',
    on the same `(insn 34 33 0 3 (const_int 0 [0]))' #131 printed.  Stated as
    unmoved because the INSN was compared, not only the site.
  * **Incremental stderr 24 lines / 0 `warning:'**, all `'@' is redundant'
    from unmodified aarch64 `.md' -- within the documented 8-to-32 floor,
    composition stated, taken from a `make' no arm had touched a header
    before.  (A `defaults.h' edit rebuilds ~600 objects and gives 451 / 111;
    that is the cold-ish arm and is not comparable.)

## 6. WHAT I DID NOT DO

  * **The guard closure of section 4** -- `PUSH_ROUNDING' (19 existence sites
    plus a value), `STACK_DYNAMIC_OFFSET', `REG_PARM_STACK_SPACE'.  Named,
    measured, not touched.  `STACK_DYNAMIC_OFFSET' is the one I would take
    next: it is a single `#ifndef', it silently disables aarch64's
    stack-clash outgoing-args reservation, and the fix shape already exists.
  * **`ARG_POINTER_CFA_OFFSET'** -- deliberately, see section 3.  Converting
    a pair that agrees banks no evidence and cannot be shown to have worked.
  * **The `dwarf2out.cc' CODEVIEW hook** -- a design decision, stopped.
  * **`insn-emit' NOT TOUCHED**, per the brief: a forwarder scheme there
    decides `gen_movxf' by implication and needs the user's ruling.  Nothing
    here pre-empts it.
  * **The scoreboard was NOT run and I claim NO movement.**  Carrying the
    recorded line unchanged: header **i386 112 PASS / 0 FAIL, aarch64 8 PASS
    / 104 FAIL of which only 2 are TRUSTED**; TAB **i386 32/0, aarch64
    27/5**.  `ACCUMULATE_OUTGOING_ARGS' is not in `macro-status.txt', so the
    correct entry is **"no probe arm exists" -- unmeasurable, not clean**.
    It is an ordinary `tm.h' macro and DOES belong on the board; adding an
    arm for it, and for #131's three, is a task.
  * No compile-time or memory measurement.  `ACCUMULATE_OUTGOING_ARGS' is now
    an indirect call at ~40 sites, several of them in `expand_call''s inner
    loops.  Both bases' recorded artefacts are byte-identical, so this is
    throughput and not correctness, but it is unmeasured and I am not
    claiming it is free.  It joins `Pmode''s 648 sites (#125), #128's
    constraint indirection, #130's attribute indirection and #131's
    `FUNCTION_MODE'.
  * `make all-target-libgcc' not re-run; #119's `-m32' blocker unchanged (a
    plain top-level `make' still fails at `configure-target-libgcc').

## 7. INSTRUMENT NOTES

  * **The brief's warning about `awk '$0 ~ f'' was applied, not
    rediscovered** -- `t132-obj.sh' uses `index ($0, f)' and refuses on an
    empty cut.
  * **A `--exclude=ChangeLog*' is load-bearing in the OTHER direction here.**
    Every one of the nine CLEAN `ix86_*' macros has hits in `ChangeLog-*'
    files, which a naive "is it spelled outside config/?" scan reads as
    SHARED.  Without the exclusion the sweep reports 11 leaks instead of 2 --
    a false positive rather than a false negative, but it would have sent the
    next agent converting nine macros nothing uses.
  * **"Is this use in a preprocessor context?" and "is this use REACHED under
    a primary-decided guard?" are two arms, not one**, and the second found
    strictly more.  `t132-sites.sh' scored `combine-stack-adj.cc:842' as an
    ordinary code use, correctly; it is also dead code.  Running only the
    first arm would have converted the macro and left both `PUSH_ROUNDING'
    sites unexamined.
  * **An `nm' binding count of 0 can be a real finding rather than an
    instrument failure**, and the two are distinguished by having a reason:
    10 of 11 objects bound the symbol, so the 11th's 0 was investigated
    rather than dismissed, and it named a second bug.
  * **My own first build was contaminated**: an edit landed before the
    baseline was taken.  Caught, `target-frame.h' reverted, and the baseline
    re-measured on a rebuilt compiler before any AFTER reading.  The recorded
    bars all matched, which is what said the revert was complete.
  * **`t132-specs.sh' must run before any codegen arm.**  Without it every
    compile is `fatal error: no configuration file for target', which on
    first sight reads as a compiler bug and is not one.  It cost one arm.

## 8. FILES

    t132-clone.sh     derives my build-dir scripts from #131's; REFUSES on a
                      leftover `b132'
    t132-conf.sh      two-target configure, /tmp/b132
    t132-build.sh     make at the TOP level -- `all-gcc' goes here
    t132-gccbuild.sh  make in $B/gcc -- `multi-target-objs cc1 lto1' here
    t132-specs.sh     both target-specs probes, real aarch64 binutils
    t132-sweep.sh     ARM A: the eleven macros, DERIVED from i386.h, with a
                      FATAL if the derivation is empty, and a per-name
                      SHARED/CLEAN verdict
    t132-sites.sh     ARM B: every use site, tagged PREPROC vs code
    t132-neigh.sh     ARM C: the fallback bodies, FIRST_PARM_OFFSET, and
                      which base defines what
    t132-types.sh     ARM D: the GENERAL form -- every type name declared in
                      either base's header, intersected with shared code
    t132-obj.sh       ARM E: both-sided object-level values, index() not ~,
                      empty-cut refusal, nm non-vacuity floor
    t132-guardctx.sh  ARM F: the GUARDS over each use.  This is the arm that
                      found PUSH_ROUNDING and STACK_DYNAMIC_OFFSET
    t132-closure.sh   ARM G: per-base definedness of every guard macro
    t132-inject.sh    the injection: removes ONLY the defaults.h redirect,
                      sed not python3, state asserted in BOTH directions,
                      REFUSES to double-inject or to restore without a saved
                      original
    t132-outargs.sh   fn-outargs.c on both bases -- the input on which
                      ACCUMULATE_OUTGOING_ARGS is observable at all
    fn-outargs.c      ten arguments plus alloca; two args land on the stack
    t132-asm.sh       assemble + disassemble + decode .eh_frame with the REAL
                      aarch64 binutils, tools named and asserted first
    t132-state.sh     big.c site + `int x = 1;' + x86_64 -O2
    t132-fn.sh        the three #131 function-body inputs, both bases
    t132-sc.sh        stock-compare, ABSOLUTE big.c, tagged outdir
