# #175 — `gen_nop`: the fix was already in the tree, and here is the measurement

## 1. The brief was stale by eighteen minutes

The brief for this task states that `gen_blockage` is "ALREADY FIXED" and that
`gen_nop` remains, and asks for the same move to be repeated for it.

Measured on the tree, not on the brief: commit `a626931d29b`
*"multi-target: select `gen_blockage`, `gen_nop`, `gen_speculation_barrier`
per back end [task #136]"* (2026-08-14 11:03) landed **all three** names in one
change. The brief was written from `7b22c75bde9` (11:19), a concurrent
worktree's measurement commit whose own numbers were taken from a `cc1` built
at 10:10 — before the fix existed. Both commits are ancestors of `ed7feb54b99`,
the HEAD this task started from.

So there was nothing to implement. `gcc/multi-target-select.cc:967` already
carries the forwarder, `gcc/multi-target-md-entry.h:44` already carries the
`rtx (*gen_nop) (void)` slot, and `genemit.cc` already declines to write the
bare name in the un-namespaced run. The task became **verification and the
suite delta**, which is what is recorded below.

Two facts in the brief were checked and hold: `HAVE_nop` is 1 at both
configured bases, so the `HAVE_*` question is inert on this pair; and every
back end defines `nop`, so the null-pointer arm (an `internal_error` naming the
back end) is unreachable in practice and is there as a fail-by-name rather than
as a fallback.

## 2. The witness — the ICE, read from the running compiler

`scratchpad/t175-nop.sh`. Instrument choice matters here: three bodies named
`gen_nop` exist in `cc1` and **every arrangement of them links**, so a symbol
table cannot say which one shared code binds. The RTL dump can, because the two
back ends' `nop` patterns are structurally different.

`void foo (int x) { if (x) ; }` at `-O0`:

```
BEFORE  /tmp/b-a78a/gcc/cc1 (built 10:10, pre-fix)
  aarch64  (insn 9 3 0 2 (const_int 0 [0]) ...)          <- i386's nop pattern
           during RTL pass: vregs
           internal compiler error: in extract_insn, at recog.cc:2892
  x86_64   rc 0

AFTER   /tmp/b-a7de5/gcc/cc1 (this tree, ed7feb54b99, anchor 55)
  aarch64  (insn 9 3 0 2 (unspec [(const_int 0 [0])] UNSPEC_NOP) ... 91 {nop})
           rc 0, one `nop' mnemonic emitted
  x86_64   (insn 9 3 0 2 (const_int 0 [0]) ... 1531 {nop})
           rc 0, one `nop' mnemonic emitted
```

**Both-sided, and the discriminator is not the mnemonic.** Both targets emit
the identical assembler string `nop`, so an output-text check would pass on the
broken compiler too. What separates them is the *pattern* and the *insn code*:
91 for aarch64, 1531 for x86_64. Each base gets its own, which is the claim.

The BEFORE arm was taken by running the other agent's surviving pre-fix binary
directly. Its snapshot directory has since been removed, so `t175-nop.sh`
refuses that build dir by name rather than reporting a half-answer — the
refusal is the intended behaviour, and the BEFORE numbers above were captured
before it went.

## 3. Validation of the build before it was trusted to produce numbers

Snapshot `ed7feb54b99`, anchor **55** measured on the snapshot itself; `git
archive` extraction with no `.git`, chmod `a-w`. `make all-gcc` rc=0, `error:`
0, `multiple definition` 0, `undefined reference` 0.

The two `specs-config` files carry 230 lines with **distinct** md5s
`a6c4c68bdf33` (x86_64) / `f1a5ab201d95` (aarch64), reproducing the recorded
bars exactly. That is the arm separating a real probe against cross binutils
from one that fell back and wrote a file naming aarch64 while describing
x86_64.

## 4. The suite delta

Both targets, `MT_COMPILE_ONLY=1`, `make -j8`, same mode as the baseline, both
`rc=0`, all four `mtcheck.sh` guards green on both (specs md5, the compiler
naming its own target back, non-vacuity, and the `multi-target.exp` banner).
Counts grepped from the merged `.sum` agree **exactly** with DejaGnu's own
`=== gcc Summary ===` on both targets — two instruments, same numbers.

```
                                   PASS     FAIL    XPASS    XFAIL    UNSUP    UNRES    ERROR
x86_64   T173 baseline           162165    16290        3     1556     4451    13361       32
x86_64   this run                162165    16290        3     1556     4451    13361       32
         delta                        0        0        0        0        0        0        0

aarch64  T173 baseline            83158   106277        6      816    11298   133718       32
aarch64  this run                 88017    98009        3      832    11012   133396       32
         delta                    +4859    -8268       -3      +16     -286     -322        0
```

**x86_64 is unchanged in all seven columns.** That is the control, and it is
what makes the aarch64 movement attributable rather than atmospheric: one
binary, two targets, the primary's numbers frozen.

### The ICE column, which is what the fix was aimed at

Counted from the merged `gcc.log`, not the `.sum` — a `.sum` records an ICE as
an ordinary FAIL and says nothing about where the compiler died.

```
aarch64 ICEs by site        baseline   this run
  in extract_insn, at recog.cc:2892       5103          0
  in get_attr_type, at aarch64.md          26          0
  in gen_lowpart_general, rtlhooks.cc:57  509        509
  in aarch64_output_casesi                 68         68
```

`extract_insn` is **gone entirely**, and so is every `unrecognizable insn`
message (`grep -c` = 0 for both). That matches the brief's own decomposition:
`gen_nop` 9277 occurrences and `gen_blockage` 973 were stated to be 100% of
that column with no third cause, and `a626931d29b` fixed both in one commit,
so the whole column going to zero is the predicted result rather than a
surprise. `get_attr_type` fell out with it — an unrecognizable insn has no
attributes to query, so it was a downstream symptom of the same defect, not a
separate one.

The two ICE sites that did **not** move are the honest negative: 509
`gen_lowpart_general` and 68 `aarch64_output_casesi` are untouched, which is
what a targeted fix should look like. `aarch64_output_casesi`'s line number
shifts 14446 → 14447 from an unrelated commit in the range, not from a change
in the count.

### What is NOT claimed

- **The delta is HEAD vs baseline, not `gen_nop` in isolation.** The baseline
  snapshot is `80bf400ae06` and this run is `ed7feb54b99`; ~40 commits sit
  between them. The `extract_insn` collapse is attributed to `a626931d29b`
  because the five-line reproducer in §2 demonstrates that mechanism directly,
  not because it is the only change in the range. The PASS/FAIL movement is
  the range's, not one commit's.
- **The whole-suite totals fell by ~4000 results on aarch64** (335305 →
  331301). Tests that ICE emit extra result lines; removing the ICE removes
  them. Recorded rather than netted out.
- **KILLED is 2 on aarch64 and 0 on x86_64**, counted from the log and never
  subtracted. The 15-minute load average was 17 at scoring time (below the ~25
  provisional threshold), but two OOM-killed compilations are still in the
  aarch64 FAIL column as ordinary failures.
- Execution still has zero observations: no target libgcc, so every `dg-do
  run` was downgraded and a PASS means "it compiled". Much of *both* FAIL
  columns is the absent runtime, which is why the aarch64-minus-x86_64 delta
  is the signal and the common part is the build's shape.
- 45 of 47 back ends remain unmeasured; only C and LTO were configured.

## 5. Harness

Harness note: `t175-conf.sh`, `t175-topbuild.sh` and `t175-mtcheck.sh` inherit
a `( cd "$SRC" && git diff --quiet )` assert written for snapshots that were
git worktrees. On a `git archive` snapshot there is no repository, so git walks
up to whatever repo contains `/tmp` and the assert becomes an error rather than
a check. Replaced with the two properties this snapshot actually has: its
`SNAP-SHA` stamp, and read-only.
