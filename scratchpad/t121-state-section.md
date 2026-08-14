# #121 -- THE SELFTESTS, TURNED ON: WHAT THEY CATCH AND WHY

## 0. THE BRIEF'S PREMISE WAS RIGHT AND ITS DIAGNOSIS WAS WRONG

STATE.md section 4b handed this over as:

> `CImode` is **aarch64's** 768-bit tuple mode; i386 has none. `test_scalar_ops`
> walks `0 .. NUM_MACHINE_MODES` and tests everything `SCALAR_INT_MODE_P`, so
> the union hands it a mode from the other back end, and the constant-folding
> paths bail out above `MAX_BITSIZE_MODE_ANY_INT` (simplify-rtx.cc:2115, :2299).

The first sentence and the second clause are right.  **The cause is not the
`MAX_BITSIZE_MODE_ANY_INT` bail-out, and the width is not too large -- it is
ZERO.**  The two accounts make different predictions and the difference is
testable, which is why it was worth settling rather than inheriting.

## 1. THE CAUSE, READ OUT OF THE GENERATED TABLES

`genmodes.cc` unions the mode VOCABULARY and keeps the DATA per base.  A mode
some other configured back end defines and this one does not is a **hole**.
`read_union_list` (genmodes.cc:1607-1625) builds it:

    m->precision = 0;  m->bytesize = 0;  m->ncomponents = 0;
    m->alignment = 0;  m->format = "0";  m->is_hole = true;
    m->cl = (enum mode_class) c;          <-- the shared numbering's class

Everything about a hole says "not here" **except its class**, which still says
what the OTHER back end said.  And every predicate in `machmode.h` is written
on the class alone:

    SCALAR_INT_MODE_P (M)   GET_MODE_CLASS (M) == MODE_INT || == MODE_PARTIAL_INT
    VECTOR_MODE_P (M)       GET_MODE_CLASS (M) == MODE_VECTOR_*

So a hole is a usable scalar integer, or a usable vector, **of width zero**.
Read from the built artefacts (`scratchpad/t121-cimode.sh`), `CImode`'s row in
each base's own table:

    aarch64  class=MODE_INT  precision={48*BITS_PER_UNIT,0}  size=48  defined-by=aarch64-modes.def:99
    i386     class=MODE_INT  precision={0}                   size=0   defined-by=<unknown>:0
    riscv    class=MODE_INT  precision={0,0}                 size=0   defined-by=<unknown>:0

`<unknown>:0` is genmodes' own hole tag; a real mode names its `.def` file and
line.  `HAVE_CImode` is `#define`d for i386 too -- the `HAVE_V8HFmode` shape
from PRINCIPLES section 3, "exists somewhere" != "exists here".

`FOR_EACH_MODE*` never reaches a hole (`mode_next` and `class_narrowest_mode`
stay dense over the base's own modes).  Code that walks
`0 .. NUM_MACHINE_MODES` **by raw index** does, and `simplify-rtx.cc` has three
such loops in the selftests alone -- :9378, :9747, :9899.

## 2. THE SIZE OF THE EXPOSURE (`scratchpad/t121-holeclass.sh`)

Three bases, 517 modes in the shared numbering:

    base      holes  SCALAR_INT_MODE_P  VECTOR_MODE_P   of which the scalar-int ones are
    i386        393                  1            382   CI
    aarch64     325                  3            307   P2QI P2HI POI
    riscv       151                  5            119   CI XI P2QI P2HI POI

The scalar-int column is small; **the vector column is not**, and no selftest
reaches it because the run aborts on the scalar one first.

## 2a. THE SELFTESTS DO NOT REACH `test_scalar_ops` AT ALL, ON ANY BASE

Run with a target actually selected, each base aborts EARLIER and for a
DIFFERENT reason, and **none of the three is the `CImode` failure that was
handed over**:

    x86_64   rc=4  ICE in `multi_target_select' -- BEFORE any selftest runs:
                   "back end 'i386' installs no garbage-collection markers for
                   the types it defines; gengtype names them after the back
                   end's source directory under config/, which differs from
                   this back end's cpu_type"
    aarch64  rc=4  aarch64.cc:33935 aarch64_test_sve_folding: FAIL
                   ASSERT_EQ (lowpart_subreg (mode, and1, E_VNx16BImode), reg)
    riscv    rc=4  ICE in expand_insn, optabs.cc:8682, via
                   riscv_vector::emit_vlmax_insn <- gen_vec_duplicatervvm1di

The reason is the ORDER in `selftest-run-tests.cc`:
`targetm.run_target_selftests ()` (line 120) runs BEFORE
`simplify_rtx_cc_tests ()` (line 125).  So the back ends' own selftests fail
first and the middle-end mode walk is never reached.

`x86_64` is the sharpest of the three: it is not a selftest failure at all --
**i386 cannot select itself in this build.**  That is `gengtype`, which this
task was told not to touch, and it is reported rather than fixed.

## 2b. REACHING IT, AND THE DISCRIMINATOR FIRING

With `targetm.run_target_selftests` bypassed (a MEASUREMENT bypass, behind
`MT121_NO_TARGET_SELFTESTS`, not a shipped change -- it removes an unrelated
EARLIER failure so the test under study can be reached, and both are reported):

    aarch64  simplify-rtx.cc:9145 test_scalar_int_ops: FAIL
             ASSERT_RTX_EQ (op0, simplify_gen_binary (AND, mode, op0, op0))
               expected: (reg:P2QI 150)
               actual:   (const_int 0 [0])

    riscv    simplify-rtx.cc:9121 test_scalar_int_ops: FAIL
             ASSERT_RTX_EQ (op0, simplify_gen_binary (PLUS, mode, op0, const0_rtx))
               expected: (reg:CI 146)
               actual:   (plus:CI (reg:CI 146) ...)

**aarch64 fails on `P2QI`, not on `CI`.**  aarch64 HAS `CImode` and handles it
correctly; `P2QI` is i386's partial-int mode, a hole for aarch64.  riscv, which
lacks both, fails on `CI`.  The failing mode is whichever scalar-int mode the
SELECTED base LACKS -- which is what section 3 predicted before the run, and
what the inherited "CImode is too wide" account does not predict.

## 3. THE DISCRIMINATOR

The failing mode must be one the **selected** base LACKS.  So i386 fails on
`CI`, and **aarch64 must not** -- aarch64 has `CI`; it should fail on one of
i386's partial-int modes instead.  The inherited account predicts the failure
follows `CImode` for everyone.  `scratchpad/t121-run.sh` states this before
running.

## 4. THE FIX

`emit_mode_class` prints `MODE_RANDOM` for a hole.  `MODE_RANDOM` is what
`VOIDmode` and `BLKmode` are; it is the class for "no other word for it".

This is not a fallback supplying another base's answer -- the PRINCIPLES 2a
test asks *whose* answer it is, and this is **this base saying it has no such
mode**, which is its own answer and the true one.  The enum ORDER is untouched:
`m->cl` still decides which run of the enum the ordinal lands in, and that is
vocabulary, shared by construction.  Only the value this base's own table
reports changes, and that is data.

## 4a. THE FIX'S BLAST RADIUS, MEASURED -- AND WHY IT NEEDED A SECOND HALF

Reclassifying holes closes the exposure completely:

    base      holes  SCALAR_INT_MODE_P  VECTOR_MODE_P      (before -> after)
    i386        393        1 -> 0           382 -> 0
    aarch64     325        3 -> 0           307 -> 0
    riscv       151        5 -> 0           119 -> 0

Hole COUNTS are unchanged (393/325/151) -- the vocabulary is intact and only
the per-base data moved, which is the check in the other direction.  And
`CImode` in aarch64's own table is still `MODE_INT`, precision 384: the base
that HAS the mode is unaffected.

**But on its own it broke ordinary compilation, not just the selftests**, and
that had to be measured rather than assumed:

    cc1 -ftarget-config=<aarch64> /tmp/c.c
      internal compiler error: in expmed_mode_index, at expmed.h:259

`init_expmed` runs on EVERY compilation.  It walks
`for (mode = MIN_MODE_INT; mode <= MAX_MODE_INT; mode++)` -- an ORDINAL RANGE,
and `MIN_/MAX_MODE_<CLASS>` are the SHARED numbering's bounds, so the range
spans every configured back end's modes.  With holes reclassified,
`expmed_mode_index`'s switch on `GET_MODE_CLASS` falls to its
`gcc_unreachable ()`.

Note what that says about the state BEFORE the fix: `init_expmed` was
silently computing and caching RTL costs for zero-width modes belonging to
other back ends, on every compilation.  The ICE is the loud form of a wrong
answer that was already there.

`scratchpad/t121-modewalks.sh` counts the population that has to move with it,
over 1642 shared sources, in two shapes:

  * **Shape A**, `for (i = 0; i < NUM_MACHINE_MODES; i++)` plus a class
    predicate -- **28 sites**.  These are REPAIRED by the fix: the predicate
    stops rejecting nothing and starts rejecting holes.
  * **Shape B**, `for (mode = MIN_MODE_<C>; mode <= MAX_MODE_<C>; mode++)`,
    where the bounds ARE the predicate -- **5 sites, in 2 files**:
    `expmed.cc:226, :290, :295, :300` and `tree.cc:10364`.  These are BROKEN
    by the fix and are the second half of it.

Five sites is small enough to do, so it was done rather than handed over.
Each gets a class test, which is provably a no-op on a single-target build
(no holes, so it is never true) and restores "this base's own modes" on a
multi-target one.

## 4b. THE RESULT, BOTH-SIDED AND NON-VACUOUS

Ordinary compilation works and produces the RIGHT CODE for each base, which is
the check PRINCIPLES asks for rather than "where does it ICE":

    aarch64  rc=0   .arch armv8-a / mov w0, 0 / ret
    riscv    rc=0   .option nopic / .attribute arch / li a0,0 ...

The middle-end selftests, with a target selected and the back ends' own
selftests bypassed to reach them:

    aarch64  rc=0   -fself-test: 7677790 pass(es)
    riscv    rc=0   -fself-test: 8439208 pass(es)

**The pass counts DIFFER between the two bases**, which is the non-vacuity
evidence that matters: each base is walking its own mode set, not some shared
one.  A cc1 with no target selected also exits 0 from `-fself-test` having
tested nothing, so `scratchpad/t121-run.sh` now refuses to score rc=0 as a pass
unless a pass count was printed and is over a million.

Reproducing the bypass (it is a MEASUREMENT instrument and is deliberately NOT
committed -- `selftest-run-tests.cc` is shared middle-end code and should not
carry a debug env var):

    sed -i 's|^  if (targetm.run_target_selftests)$|  if (getenv ("MT121_NO_TARGET_SELFTESTS") == NULL \&\& targetm.run_target_selftests)|' \
      gcc/selftest-run-tests.cc

## 5. FOUND ON THE WAY -- AND IT BLOCKED EVERYTHING ELSE FIRST

Configuring a **third** back end made `cc1` fail to link:
`extract_base_offset_in_addr` is defined bare, same signature, by
`aarch64.cc`, `riscv.cc` and `arm.cc`.  `i386 + aarch64` cannot see it.
Fixed via `MULTI_TARGET_RENAME_NAMES`.

**The guard that was supposed to catch it did not exist.**  The comment above
that list names `scratchpad/sweep.sh` as the check.  There was no such file.
It now exists and reports the whole population per base pair, not whatever the
linker stopped on.  Its reading after the fix: all three pairs clean, and it
demonstrably fires -- it reported this collision before the fix.

## 6. TWO MORE FINDINGS, NEITHER FIXED, BOTH NAMED

### 6.1 i386 CANNOT SELECT ITSELF -- `gengtype` (DO-NOT-TOUCH, so reported)

    cc1 -ftarget-config=<x86_64> ...
      internal compiler error in multi_target_select():
      back end 'i386' installs no garbage-collection markers for the types it
      defines; gengtype names them after the back end's source directory under
      config/, which differs from this back end's cpu_type

This is not a selftest failure -- it happens BEFORE any selftest runs, and it
means **no x86_64 measurement of any kind is possible in this build**.  The
cause is named by the diagnostic itself: `gengtype` keys the markers on the
directory (`config/i386`) while the selection keys on `cpu_type`.  The brief
put `gengtype` out of scope, so it is reported and not touched.

### 6.2 THE riscv DRIVER SEGFAULTS -- ONE SHARED `multilib_select`

    ./riscv64-unknown-linux-gnu-gcc -### -c /tmp/c.c      ->  rc=139 (SIGSEGV)

Backtrace:

    __strlen_evex
    riscv_compute_multilib(switchstr const*, int, char const*, ...)
    driver::set_up_specs() const
    driver::main(int, char**)

`riscv_compute_multilib` (`common/config/riscv/riscv-common.cc:2076`, installed
as `TARGET_COMPUTE_MULTILIB`) walks `multilib_select`, which is **NULL**.
`multilib.h` is generated ONCE -- `gcc/Makefile.in:3175 s-mlib`, no per-base
rule -- so `multilib_select` is a single shared authority in a compiler serving
three targets.  riscv is the only in-tree back end with a
`TARGET_COMPUTE_MULTILIB` hook, so it is the only one that dereferences it, and
the pair build never had a back end that would.

This is the standing ruling's territory: multilib is mandatory everywhere and
nests inside per-target instantiation, so the multilib tables are per-target
data that is currently shared.  Not fixed here; it is a design item, not a
debugging one.

### 6.3 TWO REAL BACK-END SELFTEST FAILURES, ONCE THE SUITE RUNS

Neither is a mode hole; both are the back ends' own selftests failing:

    aarch64  aarch64.cc:33935 aarch64_test_sve_folding: FAIL
             ASSERT_EQ (lowpart_subreg (mode, and1, E_VNx16BImode), reg)
    riscv    ICE in expand_insn, optabs.cc:8682, via
             riscv_vector::emit_vlmax_insn <- insn_riscv::gen_vec_duplicatervvm1di
             <- riscv_vector::expand_const_vector <- legitimize_move

These are what the suite is FOR, and they are the reason it is worth having
switched on.  Neither is investigated here.
