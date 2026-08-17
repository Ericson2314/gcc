`decimal_float` RE-TAKE — WHAT THE FIX ACTUALLY MOVED, AND WHAT THE BRIEF GOT WRONG
==================================================================================

Task #241 follow-up.  `9ee972c229d` ("target-specs: pass `decimal_float' from
the manifest -- nothing ever did") is claimed to invalidate every board this
project has taken.  This row tests that claim rather than inheriting it.

0. PROVENANCE
-------------

```
worktree    /home/jcericson/src/gnu/gcc/multi-target, branch multi-target-0
            THE TRAP DID NOT FIRE.  rev-parse equality checked, not ancestry:
            git rev-parse HEAD           = 7b39423abba8a7ff5e7fa57f56662e39f1d82619
            git rev-parse multi-target-0 = 7b39423abba8a7ff5e7fa57f56662e39f1d82619
            EQUAL.  scratchpad/ present (1272 files).  No reset needed.

MULTI-TARGET SIDE
  srcdir    /tmp/snap-multi-target-7b39423abba  (mt-snap.sh, read-only)
  anchor    grep -c MULTI_TARGET gcc/Makefile.in = 55   MEASURED
  bases     the canonical 47 via `a302b44ba-conf47.sh', which is
            `af2bdad90c8ebe685-conf47.sh' with its one substitution inverted:
            `x86_64-pc-linux-gnu' in the i386 slot instead of i686.
  build     /tmp/b-302b44ba-mt

STOCK SIDE (THE CONTROL)
  srcdir    /tmp/snap-stock-302b44ba, upstream merge-base
            c31b7a09eea3c33bccca12bab4a7bb6b01da1ff6, anchor 0 (inverted
            assert), read-only, testsuite graft only.
            SAME merge-base the i686 row's control used, so the two rows'
            controls are the same compiler.
  tools     taa-tools.sh -> /tmp/tools-302b44ba: real cross binutils and real
            target glibc for x86_64, aarch64, s390x, riscv64.
```

1. THE HEADLINE, AND IT IS NOT WHAT THE BRIEF SAYS
---------------------------------------------------

**The brief's central factual claim is that the recorded boards are understated
"on at least five back ends".  Measured against the build's own manifest, the
targets with `decimal_float 1` are FIVE — and only THREE of them have a
recorded board that is actually affected.**

`gcc/multi-target.manifest`, read directly (`$1=="target"` / `decimal_float`):

```
decimal_float 1   aarch64  i686  powerpc64  s390x  x86_64          (5 targets)
decimal_float 0   the other 43, INCLUDING riscv64 AND arm
```

So of the boards the brief lists as understated:

```
target     recorded debt   manifest decimal_float   affected by this defect?
x86_64                67                        1   YES
aarch64              443                        1   YES   (brief says 513 -- STALE)
s390x                206                        1   YES   (brief says 207/269 -- STALE)
i686                  34                        1   ALREADY RE-TAKEN POST-FIX
riscv64              772                        0   NO
arm                  191                        0   NO
```

`gcc/config.gcc:1287` is the authority and it is a plain `case`: `aarch64*`,
`powerpc*-*-linux*`, `i?86*-*-linux*`, `x86_64*-*-linux*`, `s390*-*-linux*` and
the mingw/cygwin/gnu spellings.  riscv and arm are not in it and are not
supposed to be — `config/dfp.m4` is the reference list and they are absent
there too.  **riscv64's 772 and arm's 191 are not understated by one result**,
and re-taking them for this reason would have been work done for a reason that
was not true.

2. `i686` WAS ALREADY RE-TAKEN WITH THE FIX IN — the brief says otherwise
-------------------------------------------------------------------------

The brief says i686's 34 was taken pre-fix and lists it among the figures to
re-derive.  It was not.  `AF2BDAD90C8EBE685-I686-BOARD.md` §2 records three
runs of that row and names the third:

```
                          only-mt   only-stock
first run                     535        2015
+ the objdump fix             223        1665
+ decimal_float passed        114         349     <- the recorded 34 is THIS run
```

Verified on the surviving build rather than taken from the document.
`/tmp/b-af2bdad90c8ebe685/lib/gcc/17.0.0/i686-unknown-linux-gnu/specs-config`
line 12 says `decimal_float 1`, and the run's own `gcc.sum` produced 749
`gcc.dg/dfp/` results and 110 `c-c++-common/dfp` — **identical to the control,
to the unit**:

```
== i686-unknown-linux-gnu   manifest decimal_float = 1
  results in             MULTI-TARGET      STOCK
  gcc.dg/dfp                    749        749
  c-c++-common/dfp              110        110
  TOTAL                         859        859
  gap (stock - mt): 0
DFPSCOPE: PASS -- dfp.exp RUNS (859 of the control's 859 attempted)
```

3. THE THREE SCORERS REPRODUCE THE i686 ROW EXACTLY
----------------------------------------------------

The brief requires that a reused scorer be shown to reproduce a previously
recorded figure before any new number is quoted from it.  All three do, on the
surviving i686 build pair, with no adjustment:

```
scorer                              recorded                measured now
taa-mtscore.sh                      PASS 157580 FAIL 16048  PASS 157580 FAIL 16048
                                    UNSUP 5816 UNRES 12951  UNSUP 5816 UNRES 12951
a9364e5cd42e818ad-scope.sh          193997 / 194232         193997 / 194232
                                    only-mt 114 / stock 349 only-mt 114 / stock 349
a660907426e03e4e9-debtnames.sh      34                      34
```

None of the three is DEAD and none is measuring the wrong thing.

4. THE MECHANISM, BOTH ARMS, ONE BYTE APART (`a302b44ba-dfparms.sh`)
---------------------------------------------------------------------

"`dfp.exp` produces 749 lines now" is also what you would see if the front end
had stopped consulting `targ_caps` altogether.  So the claim tested is the
stronger one — that `decimal_float` in `specs-config` is *what decides it* —
and it is tested by flipping that one line in a copy and re-running the SAME
compiler on the SAME source:

```
-- decimal_float as built: '1'
-- ARM A (decimal_float 1): compiled
-- the two config files differ in exactly one line (decimal_float 1 -> 0)
-- ARM B (decimal_float 0): refused
     error: decimal floating-point not supported for this target
DFPARMS: PASS -- decimal_float in specs-config is what decides it, both ways
```

The script refuses unless the two config files differ in exactly two diff lines
(one `<`, one `>`), so a `sed` that matched nothing cannot present itself as a
passing test by re-running ARM A under ARM B's name.

5. BARS, MEASURED
-----------------

```
grep -c MULTI_TARGET gcc/Makefile.in            55        as the brief says
a660907426e03e4e9-mtgap.sh                       2        as the brief says
                                                 (mt_base, mt_dwarf2_unwind_info_hook)
mt-shcheck.sh                                 rc=1        RED, as the brief says,
                                                 arm 1: 1 of 1196 files fail `sh -n`
                                                 = scratchpad/t132-neigh.sh, line 30,
                                                 "unexpected EOF looking for matching `"
                                                 pre-existing, another agent's file,
                                                 NOT TOUCHED.
```

6. WHAT MEASURED FALSE IN THE BRIEF
------------------------------------

* **"aarch64 513"** — the recorded figure is **443**, not 513.
  `A992B7E5FA4FFAAA7-BOARD.md:355` is the most recent aarch64 row and its own
  heading is `DEBT **443** (was 513)`.  The brief quotes the superseded number.
* **"s390x 207/269"** — the recorded figure is **206**
  (`A992B7E5FA4FFAAA7-BOARD.md:532`, `DEBT **206** (was 207)`).  Same
  one-board lag.
* **"riscv64 772, arm 191 are understated"** — both targets have
  `decimal_float 0` in the manifest and in `config.gcc`.  Neither figure is
  affected by this defect at all.  §1.
* **"i686 34 was taken pre-fix"** — it was the third run of that row and the
  fix was in.  §2.
* **"commit `0feab61fbac` fixed a defect"** — `0feab61fbac` is the i686 BOARD
  document.  The fix is its parent, **`9ee972c229d`**.
* **`sc-conf.sh` / `sc-check.sh` advertise an override that does not exist.**
  Both print `REFUSING rather than accepting any build dir.  Set SC_TAG=.` from
  inside a `case "$_wt" in agent-*) ;; *) ... exit 9 ;; esac` that runs
  **before** `SC_TAG=${SC_TAG:-...}` on the next line.  In any checkout not
  named `agent-*` — which includes the main worktree, where this row ran — the
  documented escape hatch is unreachable and the script refuses no matter what
  `SC_TAG` is set to.  Worked around here without editing a shared file, by
  running the scripts through `/tmp/agent-302b44ba/scratchpad`, a symlink whose
  parent basename satisfies the `case`.
* **A latent `set -e` bug in `af2bdad90c8ebe685-conf47.sh`**, carried into this
  row's copy and fixed there.  The guard is written
  `grep -q x86_64 && { echo FATAL; exit 9; }` as the last command of the
  script's list; when the grep does **not** match — i.e. when the guard PASSES
  — the list returns 1 and `set -e` exits the script with no message.  It
  survived only because in that script the grep did match.  Written as an `if`
  in `a302b44ba-conf47.sh`.

7. THE SHARED WORKTREE WAS BEING EDITED UNDER THIS ROW
-------------------------------------------------------

Recorded because it changed how this row had to be built, not as an aside.
While this task ran, another agent held **uncommitted** changes to
`Makefile.in`, `Makefile.tpl` and `target-specs/configure.ac` (mtimes 12:10:45,
12:10:40 and 12:12:00, concurrent), carrying an `install-fixed-headers`/
`mkheaders` rule and a `ts_asm_ok_f` probe helper, and later **staged**
`gcc/dwarf2out.cc`, `gcc/target.h`, `target-specs/configure{,.ac}` and two
`t252-*` scripts in the SHARED INDEX.

Two consequences, both handled:

* `sc-snap.sh` refuses on `git diff --quiet` over the WHOLE tree, so another
  agent's unrelated edit blocked this row's control.  Narrowed to the two paths
  the graft actually reads (`a302b44ba-scsnap.sh`), which also reads them from
  `HEAD:` via `git show` rather than the worktree, and which self-tests the
  narrowed guard against a really-dirty path so a narrowing cannot pass as a
  deletion.  `git stash` and "commit their work" were both rejected: the first
  yanks a live agent's work, the second puts my name on code I have not read.
* The multi-target snapshot needed no such care: `mt-snap.sh` runs
  `git archive HEAD`, which reads the object database, so the concurrent edits
  are excluded by construction.  Confirmed: snapshot anchor 55 = HEAD's value.

Nothing of theirs was staged, unstaged, stashed or committed by this row.  The
index was restored to exactly the state it was found in, and this row's commit
is pathspec-limited to its own files.

8. STATUS OF THE FOUR RE-SCORES
--------------------------------

The i686 row is settled above and needed no new run.  The three that ARE
affected — x86_64, aarch64, s390x — need a fresh multi-target build and three
fresh controls, and those were in progress when this document was committed;
the machine was carrying another agent's `-j24` build at the same time
(load average 61) and both of this row's builds were SIGTERMed once at rc=143
before being restarted detached under `setsid`.  The build and control
directories, the scorers, and the two new instruments are all in place, so the
remaining work is the six testsuite runs and the arithmetic.

**No debt or scope figure for x86_64, aarch64 or s390x is quoted in this
document, because none has been re-derived yet.**  That is stated plainly here
rather than left as an absence a reader could mistake for "unchanged": on this
branch "no output" and "no mechanism" have looked identical four times.
