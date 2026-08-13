# WHAT THE CONVERSIONS COST, AND WHICH ROUTE CLASS (c) SHOULD TAKE

Measurement and a costed proposal.  **No compiler source was changed.**  The
diff is `scratchpad/` only; three throw-away *measurement* trees were built
under `/tmp/a3ab/` and are not part of the branch.

Because no compiler source changed, **the codegen bars cannot have moved**.
They were not re-run and nothing is claimed about them.  (`stock-compare`, the
x86_64 `big.c` md5, the aarch64 one-liner: unmoved by construction, not by
measurement.)

Inputs: `PRINCIPLES.md`, `MACRO-LEAK.md` class (c), `CLASS-C-DESIGN.md`,
`t137-ranking.txt`.  Scripts: `t139-conf.sh`, `t139-corpus.sh`, `t139-time.sh`,
`t139-sites.sh`, `t139-dupcost.sh`, `t139-count-inject.sh`, `t139-count-run.sh`.

---

## 0. THE ANSWER IN ONE PARAGRAPH

`Pmode` as a per-base call, at 648 source sites and **715 machine call sites in
the linked `cc1`**, costs **at most 0.2 % of compile time** and by the
least-noisy estimator costs **nothing measurable at all** (min-of-11 identical
to four significant figures).  That is measured against a compiler that differs
from HEAD in exactly that one macro, with **byte-identical output on 19 of 19
translation units**, so it is an overhead measurement and not two compilers
doing different work.  **The per-site-call route is affordable.  Say it
plainly: this unblocks class (c).**

And the population the brief worries about is **not uniformly hot** -- it is
about as far from uniform as a distribution gets.  Seven static sites, all in
`rtlanal.cc`, carry **84 %** of all 4.3 M `UNITS_PER_WORD` evaluations, and
5 files of 18 carry 98.4 %.  The recommendation is nevertheless the *plain*
call at every site: the whole cost is at the noise floor, so a special
mechanism for the hot subset would buy nothing observable and would cost a
second spelling of a name that must have exactly one.

---

## 1. WHAT WAS MEASURED, ON WHAT, HOW MANY TIMES

**Input.**  `scratchpad/big.c` is 150 lines and is the wrong input for this
question: a run of it is dominated by `cc1` start-up, which is paid once per
process and is exactly the part a per-site call cost does *not* scale with.
The published "+3.07 %" in `CLASS-C-DESIGN.md` §3b was measured on it, between
two differently-configured builds, and its own document says to read it as
"a few percent, not a factor".  This supersedes it with a like-for-like arm.

The corpus (`t139-corpus.sh`) is **19 real C translation units, 73,444 lines**,
preprocessed once with the host compiler so both compilers under test consume
byte-identical input: zlib, libbacktrace's DWARF reader, libdecnumber, the
libbid 128-bit decimal arithmetic (six TUs of dense integer code, which is
where `UNITS_PER_WORD` and `Pmode` are actually consulted), libffi's dlmalloc.
**Every TU is validated to compile before admission** -- the first corpus had
10 of 19 TUs that preprocessed but did not compile, so `cc1` was timed in its
diagnostic path and the only thing that noticed was the output comparison.

**Method** (`t139-time.sh`): arms interleaved A,B,A,B within every iteration
(not A*N then B*N, or every drift lands on whichever arm ran second); one
discarded warm-up; **11 scored iterations, all printed**; both min and median
reported, and the script says so out loud when they disagree on the sign.  Each
iteration compiles all 19 TUs, so each datum is ~10 s of work, not a
milliseconds-scale difference of two numbers.

**The equal-work check is the load-bearing one.**  The two arms' `.s` output is
compared file by file; a timing comparison between compilers doing different
work is not an overhead measurement.  Where it fails, the script refuses to
call the delta an overhead and says so.

All three compilers were configured identically through the top level
(`--enable-backends=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu`,
`CXXFLAGS=-O2 -g0`), each in its own build dir, each with `target-specs` run
for both targets against real aarch64 binutils.  Note `-O2`, not the `-O1` the
existing guard scripts use: at `-O1` the host compiler does not inline the
things whose non-inlining is the entire hypothesis.

### 1a. ARM A -- HEAD vs the pre-`Pmode` commit (x86_64 base)

Baseline `86627699062`, the parent of the `Pmode` conversion `395b23226a7`.
Anchor check: 37 `MULTI_TARGET` hits vs HEAD's 39, and no `#define Pmode` in
its `defaults.h` -- both asserted by `t139-conf.sh` before it would configure.

    pre-Pmode   min 9.683  median 9.692  mean 9.696  max 9.718  sd 0.010 s (0.11%)
    HEAD        min 9.771  median 9.792  mean 9.797  max 9.901  sd 0.036 s (0.37%)
    ratio       by min 1.0091 (+0.91%)   by median 1.0103 (+1.03%)
    output      identical 19/19, 1,897,966 bytes of asm compared

**+1.0 %, and it is an UPPER BOUND on `Pmode`, not a measurement of it.**  The
range contains **11 conversion commits**, not one: `Pmode`, the DWARF register
numbering, the four `*_POINTER_REGNUM` names, the CONSTRAINT vocabulary,
`NUM_INSN_CODES` as a union, the per-base `insn-attrtab` selection,
`FUNCTION_MODE`, `STACK_DYNAMIC_OFFSET`, `PUSH_ARGS_REVERSED`,
`REG_PARM_STACK_SPACE`, `PUSH_ROUNDING`.  Two of those change *table* selection
rather than adding calls, so part of the 1 % is data layout and i-cache, not
indirection.

**There is no aarch64 arm A, and the reason is the point.**  The pre-conversion
compiler does not compile the corpus for aarch64 at all -- `internal compiler
error: in aarch64_can_eliminate, at config/aarch64/aarch64.cc:14153` on the
first TU tried.  On that base the `Pmode` conversion is not a throughput
trade; it is the difference between a compiler and no compiler.

### 1b. ARM B -- HEAD vs HEAD-with-`Pmode`-as-a-constant.  THE ISOLATION.

Arm A cannot attribute its 1 %.  So a third compiler was built from HEAD with
exactly one line changed, `defaults.h`:

    -#define Pmode (mt_pmode ())
    +#define Pmode (DImode)

Both configured bases have `Pmode == DImode`, so this compiler must produce
identical output while paying none of the call cost.  **It is a measurement
instrument and was built in `/tmp`; nothing like it is proposed for the tree**
-- as a change it would be PRINCIPLES §2a's "converting a runtime read back to
a compile-time macro", and worse, it would restore the silent default for any
base whose `Pmode` is not `DImode`.

The injection was asserted to have taken effect, in the artefact rather than by
reading the diff: **715 `call ... <mt_pmode>` sites in HEAD's `cc1`, 0 in this
one.**

x86_64 base:

    Pmode-const min 9.826  median 9.883  mean 9.889  max 9.992  sd 0.044 s (0.44%)
    HEAD        min 9.826  median 9.903  mean 9.900  max 10.005  sd 0.049 s (0.50%)
    ratio       by min 1.0000 (-0.00%)   by median 1.0021 (+0.21%)
    output      identical 19/19

aarch64 base:

    Pmode-const min 3.495  median 3.502  mean 3.508  max 3.527  sd 0.011 s (0.30%)
    HEAD        min 3.503  median 3.514  mean 3.516  max 3.545  sd 0.013 s (0.38%)
    ratio       by min 1.0021 (+0.21%)   by median 1.0032 (+0.32%)
    output      identical 15/15 scored, 4 TUs unscorable in BOTH arms

**So: +0.0 % to +0.3 %, against a run-to-run standard deviation of 0.3 % to
0.5 %.  The effect is at or below the noise floor of the instrument, and the
honest statement is an upper bound: `Pmode`'s 715 call sites cost less than
0.3 % of compile time.**  Both estimators are quoted because the script is
built to notice when they disagree, and on x86_64 they do -- min says zero,
median says +0.21 %.

**The aarch64 arm is weaker evidence and should not be quoted as equal.**  Only
3.5 s of work completes there against x86_64's 9.9 s, and only 148 KB of asm
against 1.9 MB, because four TUs die early (§4).  It is corroboration, not a
second independent result.

**Do not compare the two sessions' absolute times** (9.68 s in §1a, 9.83 s in
§1b for the same corpus).  The machine drifts between sessions; that drift is
larger than the effect being measured, and interleaving within a session is the
only reason either arm means anything.

---

## 2. IS THE POPULATION HOT?  MEASURED, NOT ASSUMED

The brief's question -- are the 267 `UNITS_PER_WORD` sites uniformly hot -- is
not answerable from a static count: one line in `fold-const.cc` and one in
`lower-subreg.cc` differ by orders of magnitude at run time.  A fourth compiler
was built (`t139-count-inject.sh`) in which both macros count their own
evaluations, per source file, and dump at exit.

`UNITS_PER_WORD` is redefined there to i386's own `(TARGET_64BIT ? 8 : 4)`,
which is **exactly what a shared TU sees today** -- the macro is unconverted and
i386's `tm.h` supplies it -- so the counting build is value-identical to HEAD.
The counter lives inside the existing shared-consumer guard in `defaults.h`, so
back-end TUs, generators and libgcc keep the real macros.

**That claim was asserted, not asserted-about** (`t139-count-ident.sh`): the
counting compiler and HEAD produce **byte-identical `.s` for all 19 TUs**, and
every run was checked to have actually emitted a counter dump -- a run with no
dump would be a run whose counts came from somewhere else.

Over the whole corpus, x86_64 base:

    UNITS_PER_WORD   4,313,946 evaluations, from 18 distinct source files
    Pmode            3,531,256 evaluations, from 28 distinct source files

**THE FIRST SURPRISE: STATIC SITE COUNT IS A BAD PREDICTOR OF COST, AND IT
POINTS THE WRONG WAY HERE.**  `UNITS_PER_WORD` has 267 static sites to `Pmode`'s
648 -- 41 % as many -- and is evaluated **1.22 times as often**.  The brief's
worry is framed on the 267; the quantity that decides the cost is the 4.3 M,
and on that axis `UNITS_PER_WORD` is a slightly bigger job than the one already
measured at <=0.3 %.

**THE SECOND SURPRISE, AND IT IS THE ANSWER TO "ARE THEY UNIFORMLY HOT": NO,
NOT REMOTELY.**

    UNITS_PER_WORD, by file            share
      rtlanal.cc        3,629,852      84.1%
      lower-subreg.cc     237,188       5.5%
      combine.cc          162,324       3.8%
      cse.cc              119,967       2.8%
      df-problems.cc       94,965       2.2%
      simplify-rtx.cc      24,556       0.6%
      ... 12 more files, together       1.0%
      top 5 of 18 files                98.4%

    Pmode, by file
      rtlanal.cc        1,991,503      56.4%
      cselib.cc         1,066,881      30.2%
      emit-rtl.cc         105,519       3.0%
      ira-costs.cc         63,396       1.8%
      postreload.cc        59,785       1.7%
      top 5 of 28 files                93.1%

**Seven static sites carry 84 % of all `UNITS_PER_WORD` evaluations**, all in
`rtlanal.cc`: `subreg_get_info`'s alignment arithmetic (`3959`, `3961`, `3965`,
`4016`, `4018`) and the size-in-words factor at `4576`-`4578`.  For `Pmode`,
`rtlanal.cc` plus `cselib.cc` carry 86.6 %.

And **18 of the 45 shared consumers evaluate `UNITS_PER_WORD` at all** on this
corpus.  27 files' worth of sites are cold enough not to appear.  This is a
lower bound on the file set -- another corpus (C++ templates, vectorised
floating point, `-O0`) would light up different files -- but the *shape*, one
file carrying five sixths, is not going to invert.

**A side result worth banking: the counting build compiles.**  Turning
`UNITS_PER_WORD` into a comma expression with a side effect makes it a
non-constant expression at every one of its sites; every TU in a `c,lto` build
still compiled.  That is `CLASS-C-DESIGN.md` §2b's "no constant-expression
blocker" claim, re-measured for this macro specifically by a method that could
only fail loudly.  It does **not** cover the C++, Fortran, Ada, D, Rust and
modula-2 front ends, which this configuration does not build.

---

## 3. THE ROUTES, COSTED

### R1 -- a plain per-base call at every site, as `Pmode` has now

Mechanism already exists and is proven: `mt_X ()` loads `targetm_frame`, tests
it for null (so a compilation with no base selected fails **by name** rather
than dereferencing zero), and tail-jumps through the per-base thunk.  Four
instructions plus the thunk.

Cost: **measured at <=0.3 % for 715 call sites** (§1b).  `UNITS_PER_WORD` is
267 source sites, `POINTER_SIZE` 74, `BIGGEST_ALIGNMENT` 68 -- together
**smaller than the `Pmode` population that has already been paid for.**

Scale anchor from the linked `cc1`: **83 distinct `mt_*` selectors, 1,667
machine call sites**, of which `Pmode` alone is 715 (43 %).  The entire
existing conversion programme is smaller in call sites than twice `Pmode`.

### R2 -- caching, per compilation or per function

**Rejected, and on correctness rather than on speed.**  Two of the three
macros are per-function-variable state on i386, measured from `i386.opt`:

  * `BIGGEST_ALIGNMENT` is
    `(TARGET_IAMCU ? 32 : TARGET_AVX512F ? 512 : TARGET_AVX ? 256 : 128)`, and
    `mavx` / `mavx512f` are `Target Mask(...) Var(ix86_isa_flags) Save`.
    `Save` is precisely "participates in per-function target switching", so
    `__attribute__((target("avx512f")))` moves this value **within one
    compilation**.
  * `Pmode` reads `ix86_pmode`, a `TargetVariable`, i.e. also in the saved set.
    The branch already knows this: `mt_pmode`'s comment says it goes through
    `mt_frame ()` rather than caching "because a value read once at startup
    would be frozen at whatever the options said then".
  * `UNITS_PER_WORD` reads `TARGET_64BIT`, whose `m64` is likewise `Save`.

A refresh point does exist -- `invoke_set_current_function_hook`
(`function.cc:4697`) is the single funnel where per-function target state
becomes current -- but it is **not the only writer**: `c-pragma.cc:1275` calls
`cl_target_option_restore` directly for `#pragma GCC target`, and
`stor-layout.cc` consults `BIGGEST_ALIGNMENT` during parsing, where no function
is current at all.  So caching buys, at best, a saved indirect call the
measurement says is already free, in exchange for a **stale-cache class of bug
that is exactly the one this branch exists to delete**: a name that reads
plausibly and answers for the wrong configuration, with no diagnostic.

If the measurement had come out at 5 % this would be a real trade.  At <=0.3 %
it is paying the project's characteristic bug to buy nothing.

### R3 -- compile the consuming TUs per base

Mechanism also already exists (`target-cumargs.cc`), so it needs no design.
It was costed rather than argued (`t139-dupcost.sh`, against the real build
dir):

    UNITS_PER_WORD: 42 of its 45 shared .cc consumers are built in this
    configuration; their object text totals 11,157,584 bytes.

That is **~11 MB of object text per additional back end for one macro**, and
the consumers are the largest files in the compiler -- `tree-vect-loop.cc`
531 KB, `varasm.cc` 410 KB, `internal-fn.cc` 395 KB, `simplify-rtx.cc` 388 KB.
A 48-back-end build would add roughly **525 MB**.  And the cost is not only
size: each of those 42 files stops being compiled once for all targets, which
is a build-time multiplier on the slowest files in the tree.

**Reject for this population.**  It remains right for the *supply* side --
thunks, tables, a back end's own TU -- which is what `target-cumargs.cc` is.

### R4 -- something narrower for a hot subset

§2 says such a subset exists and is startlingly small: **7 sites in
`rtlanal.cc` carry 84 % of `UNITS_PER_WORD`**, and 5 files carry 98.4 %.  So if
a narrow mechanism is ever wanted, it is available and it is cheap to apply --
it is single-digit numbers of lines, not 267.

**But it should not be applied now, and the measurement is the reason.**  The
whole 3.5 M-evaluation `Pmode` population already costs <=0.3 %; a mechanism
that saves 84 % of a cost that is at the noise floor saves nothing observable,
and it would introduce a second way of spelling the same macro -- one hot
spelling and one cold spelling -- which is a second authority for one name, in
a project whose entire subject is what happens when a name has two.

The honest use of §2 is not as a plan.  It is as **the contingency**: if some
future corpus does show a real regression, this is the map that says where to
spend the effort, and it says the answer is a handful of lines in one file.
Two shapes are available there and neither needs new machinery:

  * hoist the repeated evaluation into a local within the function that
    already computes it (`subreg_get_info` reads it three times in one
    expression), which is an ordinary refactor with no target semantics at
    all; or
  * for the size-in-words factor at `rtlanal.cc:4576`, note it is dividing a
    mode size by the word size -- `REGMODE_NATURAL_SIZE`-shaped -- and may
    belong on the existing per-base frame descriptor as one call rather than
    two.

---

## 4. INCIDENTAL FINDING, WITH A REPRODUCER: THE x87 PASS RUNS FOR aarch64

Four of the 19 corpus TUs fail on the aarch64 base, in **both** arm-B
compilers, so they are not caused by anything measured here:

    libbacktrace_dwarf.i:3599   ICE in replace_reg,          reg-stack.cc:728
    libdecnumber_bid_bid2dpd..  ICE in subst_stack_regs_pat, reg-stack.cc:2138
    libdecnumber_decContext.i   ICE: Segmentation fault
    libdecnumber_decNumber.i    ICE in subst_stack_regs_pat, reg-stack.cc:2138

`reg-stack.cc` is the **x87 stack-register pass**.  Its gate is

    bool gate (function *) final override
      { #ifdef STACK_REGS  return true;  #else  return false;  #endif }

and `STACK_REGS` is defined by `config/i386/i386.h:969` and by no other
configured base.  So the gate is `true` for **every** target, and aarch64 runs
the x87 pass.  This is the absence channel -- `#ifdef` answered by the primary
-- with named, reproducible victims rather than a suspicion.  It is not in the
class-(c) population (`STACK_REGS` has no value to union; it is class (d)) and
it was not converted here.

Note what the shape of it says: `rest_of_handle_stack_regs` is also
`#ifdef`-bracketed, so the pass currently *runs* and does *work* for aarch64
rather than being a no-op.  Whoever takes it should convert the gate and the
body together, and the `stack_regs_mentioned` pair at `reg-stack.cc:3451` is
already the model for how the branch does this.

---

## 5. RECOMMENDATION

**Take R1: convert `UNITS_PER_WORD`, `POINTER_SIZE` and `BIGGEST_ALIGNMENT` as
plain per-base calls, in the shape `Pmode` already has.  No new mechanism, no
cache, no per-base duplication of consumers, and nothing special for the hot
subset.**

The evidence, in the order it should be read:

1. **The cost of the shape is measured and is at the noise floor.**  715 call
   sites, 3.53 M dynamic evaluations, <=0.3 % of compile time, byte-identical
   output on both bases (§1b).  Nobody had claimed this was free; now it has
   been measured rather than assumed, and it is.
2. **The new population is not bigger than the one already paid for.**
   `UNITS_PER_WORD` is 4.31 M evaluations against `Pmode`'s 3.53 M -- a factor
   of 1.22.  Projecting the §1b bound gives **<=0.4 %** for `UNITS_PER_WORD`,
   and it is a projection from two measurements, not an A/B; §7 says how to
   run the A/B, and it is cheap.
3. **Caching is rejected on correctness, not on speed** (§3 R2).
   `BIGGEST_ALIGNMENT` moves within a single compilation under
   `__attribute__((target("avx512f")))`, and it is consulted during parsing
   where no function is current.  A stale cache is a name answering for the
   wrong configuration with no diagnostic -- this branch's own bug, reinvented.
4. **Per-base compilation of the consumers costs ~11 MB of object text per
   back end for this one macro** (§3 R3), on the 42 largest files in the
   compiler.  Reject for consumers; keep it for suppliers, where it already is.
5. **A hot-subset mechanism is not needed and would cost more than it saves**
   (§3 R4) -- a second spelling of one name, to optimise a cost at the noise
   floor.

Sequencing, cheapest-evidence-first:

  * **First, and before converting anything: run the direct `UNITS_PER_WORD`
    A/B.**  It is one more build and one more `t139-time.sh` invocation and it
    replaces the projection in (2) with a measurement.  If it comes back at
    2 % rather than 0.4 %, this recommendation changes and it is much cheaper
    to find that out now.
  * `POINTER_SIZE` **must lose its `#ifndef` floor** (`defaults.h:863`) in the
    same change that converts it, or the conversion re-opens the absence
    channel under it.
  * `BIGGEST_ALIGNMENT` is the one to convert **first** of the three, despite
    being the least used: it is the only one of the three whose value moves
    per function on a configured base, so it is where a wrong mechanism shows
    up as a wrong answer rather than as luck.  It is also the one with a
    partial upstream hook (`TARGET_ABSOLUTE_BIGGEST_ALIGNMENT`) that looks
    like the answer and is not -- it is the maximum over all targets, i.e. the
    unioned quantity, where the selected target's own value is wanted.
  * `UNITS_PER_WORD` last of the three, being the largest sweep.

**One thing this cannot tell you and no arm here can.**  On this base pair
`UNITS_PER_WORD` is 8 for both (i386's `TARGET_64BIT ? 8 : 4` with `-m64`,
aarch64's constant 8), so the conversion will move **no value and no byte of
output**.  Like `MAX_MOVE_MAX`/`MIN_UNITS_PER_WORD`, it is correct today by
luck.  The arm for it must therefore be structural -- the name absent from both
bases' headers, the selector resolving to each base's own thunk -- and an arm
that only checks "output unchanged" will be green before and after and will
have measured nothing.

---

## 6. WHAT IS A RULING, NOT ENGINEERING

Stated separately because the brief asks, and because two of these are already
outstanding and must not be settled as a side effect of a costing document.

  * **Whether class (c) uses `targetm` hooks or the branch's `mt_*` thunks.**
    `CLASS-C-DESIGN.md` §1 measured the hook route at ~86 new `target.def`
    entries, each needing tm.texi documentation, a default, and a conversion in
    every back end in the tree.  The `mt_*` route needs none of that and is
    what the eleven landed conversions use.  This is an upstreaming-shape
    decision, not a performance one, and the measurement above does not decide
    it: **the cost figure is the same either way**, because both are an
    indirect call through a per-base pointer.
  * **Whether a cached scalar is admissible anywhere in this family.**  §3 R2
    recommends against, on correctness.  If the answer is "never cache a
    target answer", that is a rule worth writing into PRINCIPLES rather than
    re-deciding per macro.
  * **NOT DECIDED HERE, AND NOTHING ABOVE TOUCHES THEM:** `gen_movxf` and what
    any `insn-emit` forwarder implies, and what a triple-less installed `gcc`
    resolves to when no target is selected.  No measurement here bears on
    either; they are named only so it is on the record that they were left
    alone.

---

## 7. WHAT I DID NOT MEASURE, AND WHAT THE INSTRUMENT CANNOT SEE

  * **No conversion was performed and no compiler source changed.**  The
    codegen bars therefore cannot have moved and were not re-run.
  * **The <=0.3 % is an upper bound, not a value.**  The effect is at the noise
    floor; the correct reading is "not distinguishable from zero on this
    corpus", not "0.21 %".
  * **One host, one corpus, one optimisation level.**  All timings are
    `-O2` compiles of C on one x86_64 machine.  A cold i-cache workload, a
    different host microarchitecture, or `-O0` (where compile time is
    dominated by different passes) could weight the per-call cost differently.
  * **`UNITS_PER_WORD`'s cost was not measured directly** -- it is still a
    macro.  What is measured is `Pmode`'s, plus `UNITS_PER_WORD`'s dynamic
    evaluation count; the projection in §5 is arithmetic on those two, not an
    A/B.  The direct arm is available cheaply and was not run: build a
    `UNITS_PER_WORD`-as-call compiler and interleave it the same way.
  * **`POINTER_SIZE` and `BIGGEST_ALIGNMENT` were not counted.**  Only
    `UNITS_PER_WORD` and `Pmode` carry counters.  Their static counts (75, 68)
    and their consumers (`stor-layout.cc`, `varasm.cc`, `ipa-polymorphic-call.cc`)
    suggest they are far colder, and that suggestion is **not a measurement**.
    Adding them to `t139-count-inject.sh` is two lines.
  * **The counting build attributes to `__FILE__` at the point of use**, so a
    use written in a header is charged to that header, correctly, but a use in
    an inline function is charged to wherever it was written and not to its
    caller.  Hotness is therefore attributed to the *source line*, which is
    what a conversion changes, and not to a call tree.
  * **The site counts here are 268 / 75 / 68 against `t137-ranking.txt`'s
    267 / 74 / 68.**  Different file filters, one line apiece; neither figure
    should be quoted as the other's.
  * **`POINTER_SIZE` carries a live `#ifndef` floor** (`defaults.h:863`,
    `#define POINTER_SIZE BITS_PER_WORD`).  It does not fire today because both
    bases define the macro, but it is the absence channel sitting under the
    second-ranked macro in the family, and whoever converts it must delete the
    floor in the same change or the conversion re-opens it.
