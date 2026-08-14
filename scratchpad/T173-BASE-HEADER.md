# Naming the base at the point of inclusion — the one place this is written down

Task #173. This is the rationale that used to be repeated as a four-line
comment in every converted file under `gcc/config/`. It lives here once;
`gcc/multi-target-base.h` points at it, and nothing else should restate it.

## The rule

A source that is compiled **once per back end** spells every per-back-end
header as

```c
#include "multi-target-base.h"
#include BASE_HEADER (tm.h)          /* -> "i386-inc/tm.h" */
```

Macro form, argument unquoted, never a hardcoded base name, and the expansion
yields the **quoted** include (user's preference). `BASE_HEADER` reads
`-DMT_BASE=<cpu>-inc`, which the makefile sets **per object**, so the header
always follows what is actually being built.

Hardcoding `"riscv-inc/tm.h"` is rejected even where it would work today: if
that file is ever compiled for a second base it opens riscv's headers and
compiles **cleanly**, because the file exists. `BASE_HEADER` cannot fail that
way.

## Why not `-I<base>-inc`

The user's ruling: *"we really need to get rid of the -I tricks."* The
argument, in the order it actually bites:

- **It is selection by path order, and it is silent.** With several back ends
  configured, every `<base>-inc/` holds the same sixteen names. A missing or
  mis-ordered `-I` does not fail — it compiles the wrong target's headers
  perfectly well. `d7a12b9d5c4`'s own subject is that mechanism failing to
  reach its consumers.
- **It is a second authority for one fact.** `-DMT_BASE=<cpu>-inc` and
  `-I<cpu>-inc` say the same thing twice, which is the root shape this branch
  exists to remove.
- **Upstream is not doing it.** Upstream finds `tm.h` through `-I` too, but
  upstream has exactly **one** candidate, so its `-I` is finding a file, not
  choosing between bases. Using `-I` to *select* is this branch's invention.

## What is done, and what the `-I` is still doing

`gcc/config/` is finished: **all 280 direct include sites over 11 stems** name
their base, and `git grep '#include "<stem>.h"' gcc/config` returns only the
15 files that have no base (below). Nothing under `gcc/config/` is selected by
include-path order any more.

**The `-I` cannot yet be deleted, and the reason is measured, not assumed.**
It is still the only mechanism supplying per-back-end headers **transitively**,
through *shared* headers — and a shared header cannot name a base. Read from
the baseline 47-back-end build's own `.deps` (`t173-deps.sh`), which lists
every header each compilation actually opened:

```
2000 objects open <base>-inc/insn-modes.h        (via coretypes.h:553)
2000                        insn-modes-inline.h
1952                        tm.h
1725                        insn-codes.h
 754                        insn-config.h
 649                        insn-opinit.h
 365                        tm_p.h
```

Only ~280 of those are direct includes in `gcc/config/`. The rest arrive
through `coretypes.h`, `rtl.h` and friends.

**And deleting the `-I` would fail SILENTLY, which is the part that decides
the sequencing.** `t173-rootstems.sh`: 15 of the 16 stems *also* exist under
their plain name in the build root, so an unconverted include does not become
a `No such file` — it quietly starts reading the build root's copy. And
`t173-rootvsbase.sh` says what that copy is, at 47 back ends, i386 vs riscv:

```
stem                   root           i386-inc       riscv-inc
insn-constants.h       801ba7df7801   801ba7df7801   ae4a94788b05   root is i386's
insn-attr-common.h     817d9a8bd888   817d9a8bd888   f5c5e78f7ce5   root is i386's
insn-codes.h           5aeec06641cc   5aeec06641cc   ec14eff8b336   root is i386's
insn-config.h          2b8a758a795e   2b8a758a795e   1663fdf01b0a   root is i386's
insn-modes.h           e3829ca9640b   e3829ca9640b   273a85fed2cc   root is i386's
insn-modes-inline.h    c2942130a4a4   c2942130a4a4   9f5627481df1   root is i386's
insn-target-def.h      8ed769972514   8ed769972514   b24f838d5a4a   root is i386's
```

**Every stem is genuinely per base — no stem is unioned** — and for seven of
them the build root's copy is byte-identical to the primary's. So removing
the `-I` today hands ~2000 per-back-end objects i386's mode numbering, insn
codes and target-def table, with no diagnostic. That is §2a's
*"reverting a per-base header to a shared one because the shared one builds"*,
arriving disguised as the cleanup that removes it.

The brief's method — *"delete it and let the build break, the breakage
enumerates them for you"* — assumed the failure would be loud. Measured, it is
not, and that is the finding rather than a reason to proceed carefully.

### The mechanism that would finish it

The shared side needs the base named too, and `coretypes.h` **already has the
hook** for one stem:

```c
#ifndef INSN_MODES_H
#define INSN_MODES_H "insn-modes.h"
#endif
#include INSN_MODES_H
```

so a per-base object only needs that macro to resolve to
`BASE_HEADER (insn-modes.h)` when `MT_BASE` is defined. The same shape —
`#ifdef MT_BASE` naming the base, plain name otherwise — covers the other six
stems wherever a shared header reaches them. That names the base at the point
of inclusion, keeps `-DMT_BASE` the sole authority, and needs no `-I`.

It is a change to *shared* headers, i.e. the same population as
"stop the 248 shared TUs including `tm.h`", and it should be sequenced with
that rather than bolted onto a `gcc/config/` sweep.

## The files that have no base

15 files under `gcc/config/` are compiled **once**, so `BASE_HEADER` is the
wrong answer and `-DMT_BASE` is not passed to them. Classified from the
generated makefile (`t173-classify.sh`) over three configurations, never from
the path:

| file(s) | channel |
|---|---|
| `i386/driver-i386.cc`, `aarch64/`, `arm/`, `alpha/driver-*.cc` | `config.host` `host_extra_gcc_objs` → `EXTRA_GCC_OBJS` |
| `darwin-driver.cc`, `vxworks-driver.cc` | `config.gcc` `extra_gcc_objs`; they live in `gcc/config/`, not `config/<cpu>/` |
| `sol2-c.cc`, `vms/vms-c.cc` | `c_target_objs`, held out of the per-base list by the awk's `^config/<cpu>/` test |
| `arm-d.cc`, `mips-d.cc`, `rs6000-d.cc`, `s390-d.cc`, `sparc-d.cc`, `freebsd-d.cc` | `@d_target_objs@`, a single `${target}` substitution |
| `avr/gen-avr-mmcu-specs.cc` | `avr/t-avr`, a build-machine tool |

Each of these gets the **shared** `tm.h`, which is i386's header chain under a
target-neutral name. Two consequences worth stating separately:

- `driver-i386.o` is the only host driver currently built and it is right **by
  luck** — the host is x86_64, so the primary's chain happens to be the right
  one. On an aarch64 host, `driver-aarch64.o` would be compiled once against
  i386's macros and say nothing. **Latently wrong, not currently wrong.**
  #143 chose `target-specs` as the route for `-march=native`, which is the
  same answer here: what `local_cpu_detect` wants is a fact about the deployed
  machine.
- `@d_target_objs@` is the `PASSES_EXTRA` shape verbatim — fed by the legacy
  single `${target}`, so only one back end's D glue is ever built, and the
  other five are absent rather than off.
