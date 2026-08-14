# attic — retired instruments, and where each arm went

Kept, not deleted: their **readings** are quoted in `gcc/Makefile.in`,
`PRINCIPLES.md` and the `T*.md` notes, and a reader who wants to know what a
past figure actually measured needs the file that measured it. Nothing here is
live. See `INSTRUMENTS.md` for what is.

| retired | superseded by | arms carried across |
|---|---|---|
| `sweep.sh` | `mt-rename-sweep.sh` | `nm`/`ar` PATH check; the `libbackend.a` membership filter (only linked objects, so `mt_probe_*` stops being 21 of 22 hits) with every exclusion printed; per-base "contributed 0 objects" FATAL; collisions named with **both** defining objects; **nonzero exit** |
| `t150-rename-gap.sh` | `mt-rename-sweep.sh` | nothing unique — ancestor of t155/t157 |
| `t155-rename-gap.sh` | `mt-rename-sweep.sh` | hand-written vs generated reported **separately**; per name, how many bases define it and **which**; the empty-base call-out |
| `t157-rename-gap.sh` | `mt-rename-sweep.sh` | nothing unique — t165 is its copy |
| `t165-rename-gap.sh` | `mt-rename-sweep.sh` | the `.rc` **stamp check**; **arm 2** (base-vs-shared) with its vacuity call-out |
| `t167-rename-gap.sh` | `mt-rename-sweep.sh` | as t165 (it is t165 plus a comment); the `mt_probe_*` discount line |
| `t175-mtcheck.sh` | `mtcheck.sh` | the **snapshot** freeze arm (`SNAP-SHA` + read-only). `mtcheck.sh` had only the `git diff --quiet` worktree arm; it now dispatches on which kind of srcdir it was given, because each arm is wrong for the other — `git diff` in a `git archive` extraction has no repository and walks *up*, turning the check into an error |
| `t175-mtscore.sh` | `mtscore.sh` | byte-identical apart from the scorer path |

**No arm was dropped.** The survivor is the *union* of the six, not the latest
of them: later was not automatically better here — `sweep.sh`, the oldest, was
the only one that exits nonzero and the only one that filters to objects that
are actually linked, and the five later ones all lack both.

## Not yet retired, and why

The `t<NNN>-conf.sh` (63), `-build.sh` (54), `-specs.sh` (38) and `-bars.sh`
(14) families are superseded by `mt-conf.sh` / `mt-build.sh` / `mt-specs.sh` /
`mt-bars.sh` and are **left in place this session on purpose**: several agents
are mid-task with them, and moving a script out from under a running harness
is exactly the silent deletion this consolidation exists to prevent.

Stating it rather than leaving it implicit — nothing leaves the board silently,
and that cuts both ways. The criterion for moving them: a family member may go
to the attic once no in-flight task cites it and its task number is behind the
oldest live one. Before moving any of them, check it for an arm `mt-lib.sh`
lacks; the six above proved that the *oldest* file can be the one holding the
guard.
