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

Harness note: `t175-conf.sh`, `t175-topbuild.sh` and `t175-mtcheck.sh` inherit
a `( cd "$SRC" && git diff --quiet )` assert written for snapshots that were
git worktrees. On a `git archive` snapshot there is no repository, so git walks
up to whatever repo contains `/tmp` and the assert becomes an error rather than
a check. Replaced with the two properties this snapshot actually has: its
`SNAP-SHA` stamp, and read-only.
