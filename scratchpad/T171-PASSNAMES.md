# #171 follow-up — the pass NAME vocabulary is still shared, and it now collides

Found by measuring the fix rather than by predicting it: `t171-dumpnames.sh`
on an eight-base build.  **Not a codegen defect. It is a design question about
user-visible option spellings, so it is reported rather than resolved** —
PRINCIPLES §2b.

## What was measured

`-fdump-passes` on the eight-base `after` compiler, compiling for aarch64,
lists 414 passes.  Three of them print as `(null)`:

```
   91:   (null)                          :  OFF      <- pre-existing, upstream
  389:      (null)                       :  OFF      <- aarch64's own, upstream
  404:         (null)                    :  OFF      <- NEW: arm's bti
```

Counts, so the attribution is not a guess:

| build | `(null)` lines |
|---|---|
| 2-base **before** (i386 + aarch64) | 1 |
| 2-base **after** | 2 |
| 8-base **after** (adds arm) | 3 |

## Two of the three are upstream, and only one is new to a multi-base binary

`register_one_dump_file` builds the pass's registered name from `pass->name`,
which lives in that pass's `pass_data` — **the C++ symbol renaming this task
did does not reach it.**  `pass_manager::register_pass_name` then does

```c
  if (m_name_to_pass_map->get (name))
    return;                 /* Ignore plugin passes.  */
```

so the second pass to claim a name is silently dropped from the map, its
`pass_tab[]` slot stays null, and `dump_one_pass` prints `(null)`.

- **Line 389 is aarch64's own and is upstream behaviour.**
  `aarch64-speculation.cc:501,507` — `make_pass_track_speculation` and
  `make_pass_late_track_speculation` both construct `pass_track_speculation`,
  which has one `name` field, `"speculation"`.  A stock aarch64 compiler
  prints this same `(null)`.  It appears here for the first time only because
  aarch64's passes are in the tree for the first time; **it is the fix
  exposing an upstream quirk, not the fix creating one.**
- **Line 404 is new.** aarch64's and arm's `pass_insert_bti` are two distinct
  passes built from the same `config/arm/aarch-bti-insert.cc`, whose
  `pass_data` name is `"bti"` (`aarch-bti-insert.cc:85`).  Both register
  `rtl-bti`; aarch64 wins by list order.

## What it costs

Nothing in codegen — the pass still runs; `hint 34 // bti c` is emitted.  What
is lost is the *handle*: `-fdump-rtl-bti`, `-fdisable-pass=rtl-bti`,
`-fenable-pass=`, and the plugin `PLUGIN_PASS_MANAGER_SETUP` reference all
reach aarch64's bti pass and **arm's is unnameable**.  One name, several
authorities, no diagnostic — this branch's own bug, arriving in the diagnostic
surface instead of in generated code.

## Why it was not fixed here, and the options

The obvious fix is to put the owner in the registered name — `rtl-aarch64-bti`
and `rtl-arm-bti` — since `opt_pass::mt_base` now carries it.  That **changes a
user-visible option spelling for every target pass in the compiler**
(`-fdump-rtl-stv1` → `-fdump-rtl-i386-stv1`), which is a decision about the
command-line interface and not something a build-system task should make
silently.

The tempting middle path is worse and was rejected: disambiguating *only on
collision* makes an option's spelling depend on which other back ends happen
to be configured.  So is fixing only `register_pass_name` and leaving
`dump_register` alone — `-fdump-passes` would then print `rtl-arm-bti` for a
switch that does not exist, which is a lie rather than a half-fix.

| option | cost |
|---|---|
| **(a)** owner in the name for every owned pass | every target pass's dump switch changes; diverges from upstream spellings; unambiguous, and says WHICH back end |
| **(b)** owner in the name only on collision | spelling depends on the configured back-end list — a name with two meanings, in the option surface |
| **(c)** leave it | arm's bti pass stays unnameable; silent |
| **(d)** refuse at startup when two owned passes claim one name | loud, but fails an eight-base build today for a diagnostic-only defect, during the "get the back ends building" phase |

**(a) is the recommendation** — it is the shape this branch has applied eight
times (union the vocabulary, qualify what collides, say which back end) — but
it needs the user's ruling on the option names, so it is written down rather
than done.
