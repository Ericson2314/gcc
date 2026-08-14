# INSTRUMENTS — the current harness. Read this before writing a `t<NNN>-*.sh`.

`scratchpad/` holds ~780 files. Almost all of them are **one script copied per
task**. If you are about to write `t<NNN>-conf.sh`, the answer is already here.

## The set

| job | script |
|---|---|
| shared guards, sourced by all | `mt-lib.sh` |
| configure a build dir with a base set | `mt-conf.sh` |
| build in it, stamped | `mt-build.sh` |
| run `target-specs` per target | `mt-specs.sh` |
| the x86_64 `-O2` codegen bar | `mt-bars.sh` |
| `MULTI_TARGET_RENAME_NAMES` completeness | `mt-rename-sweep.sh` |
| the testsuite, once per target | `mtcheck.sh` |
| score its runs | `mtscore.sh` |
| every cited `scratchpad/` path exists | `mt-cite-check.sh` |

Typical run:

```sh
A=$(grep -c MULTI_TARGET gcc/Makefile.in)          # 49 today; run it, do not copy it
export WANT_ANCHOR=$A
SRC=$PWD sh scratchpad/mt-conf.sh  /tmp/b-<hash> i386,aarch64
         sh scratchpad/mt-build.sh /tmp/b-<hash> make-cc1 all-gcc
         sh scratchpad/mt-specs.sh /tmp/b-<hash>
         sh scratchpad/mt-bars.sh  /tmp/b-<hash>
         sh scratchpad/mt-rename-sweep.sh /tmp/b-<hash>
```

## Why the names carry no task number

Two failures, both this project's own root bug in its own tooling.

**One name, several authorities.** `gcc/Makefile.in` said its rename check was
`scratchpad/sweep.sh`, which did not exist; then `t150-`, `t155-`, `t157-`,
`t165-`, `t167-rename-gap.sh` — six instruments for one job, each written
because the previous "was inadequate", which was true when said and stopped
being true. Nothing said which was live.

**`t<NNN>` collides by construction.** Task numbers are handed out in
neighbouring blocks, so two unrelated agents pick the same filename: four
add/add merge conflicts in one day (`t160-*`, `t173-*`, `t174-*` twice), all on
unrelated work. Taking either side would have silently deleted a working
harness.

**And the thing that FORCED every copy was one guard.** Each script asserted
its build dir by this worktree's hash, hardcoded:

```sh
case "$D" in */b-a7de5*) ;; *) echo "FATAL: not named for this worktree"; exit 9 ;; esac
```

Right guard — a harness must assert which tree it measures — and unrunnable
from the next worktree, so the next agent copied it under a new number.
`mt-lib.sh` **derives** the tag from the script's own path instead. Same guard,
no edit per worktree, no number to collide on. If you find yourself editing one
line of an `mt-*.sh` to make it run, that line is a bug in `mt-lib.sh`; fix it
there rather than making the seventh copy.

## Adding to the set

Extend an `mt-*.sh`, or add one with a **descriptive** name. Do not fork.
If you must fork (an in-flight run must not see your edits), copy to a name
that says why, and delete it when the run lands.

`mt-cite-check.sh` asserts that every `scratchpad/` path named in
`gcc/Makefile.in` and `PRINCIPLES.md` exists. Run it after touching either.
It cannot say a citation is *right*, only that it is *there* — deliberately, so
it can only ever revoke a citation, never bless one.
