# `BASE_HEADER` — state, and the two things it does not cover

Task #173. `-DMT_BASE=<cpu>-inc` is the authority; a per-back-end header is
spelled `#include BASE_HEADER (<stem>.h)`.

## Done

All **280** direct per-back-end include sites under `gcc/config/` name their
base, over 11 stems (`tm` 32, `tm_p` 117, `insn-attr` 64, `tm-constrs` 41,
`insn-config` 22, `insn-codes` 18, `insn-opinit` 6, `options` 3, `insn-modes`
3, `insn-attr-common` 3, `tm-preds` 2, `insn-flags` 1).

**A back end's `.h` may not name a base.** Four were converted and reverted:
the shared `tm.h` includes `config/i386/i386.h` at line 50, so a header in
that chain is read by ~520 translation units that have no `MT_BASE`. Which
back end sits there is a property of the configuration. Sources compiled per
back end may name a base; headers may not.

## Not done 1 — the `-I` cannot be deleted yet, and it fails silently

`-I<base>-inc` still serves the **transitive** reaches, from shared headers,
which cannot name a base. From the 47-back-end build's own `.deps`
(`t173-deps.sh`), objects opening `<base>-inc/…`:

```
2000  insn-modes.h, insn-modes-inline.h   (coretypes.h:553)
1952  tm.h        1725 insn-codes.h       754 insn-config.h
 649  insn-opinit.h                       365 tm_p.h
```

Only ~280 of those are direct. And removal is **silent**, not loud: 15 of 16
stems also exist under their plain name in the build root
(`t173-rootstems.sh`), and `t173-rootvsbase.sh` at 47 bases, i386 vs riscv:

```
stem                   root           i386-inc       riscv-inc
insn-constants.h       801ba7df7801   801ba7df7801   ae4a94788b05
insn-attr-common.h     817d9a8bd888   817d9a8bd888   f5c5e78f7ce5
insn-codes.h           5aeec06641cc   5aeec06641cc   ec14eff8b336
insn-config.h          2b8a758a795e   2b8a758a795e   1663fdf01b0a
insn-modes.h           e3829ca9640b   e3829ca9640b   273a85fed2cc
insn-modes-inline.h    c2942130a4a4   c2942130a4a4   9f5627481df1
insn-target-def.h      8ed769972514   8ed769972514   b24f838d5a4a
```

No stem is unioned, and for seven the build root's copy **is i386's**. Deleting
the `-I` today hands ~2000 per-back-end objects the primary's mode numbering,
insn codes and target-def table with no diagnostic.

`coretypes.h` already has the hook for one stem —
`#ifndef INSN_MODES_H / #define INSN_MODES_H "insn-modes.h" / #include
INSN_MODES_H` — so resolving that macro to `BASE_HEADER (insn-modes.h)` under
`#ifdef MT_BASE` is the shape for the other six. That is a change to *shared*
headers, i.e. the same population as "stop the 248 shared TUs including
`tm.h`", and belongs with it.

**When the `-I` goes, the witness goes with it.** `mt-inc-witness.h` is
findable only through the `-I`, and it is what makes a wrong base fail by
name. `-DMT_BASE` alone needs its own check — the per-base header asserting
its own identity against `MT_BASE` — or a wrong `-DMT_BASE` compiles another
back end's headers cleanly.

## Not done 2 — the 15 files with no base

Compiled once, so `BASE_HEADER` does not apply and `-DMT_BASE` is not passed.
They get the shared `tm.h`, which is the primary's header chain. Classified
from the generated makefile (`t173-classify.sh`) over three configurations.

| file(s) | channel |
|---|---|
| `i386/driver-i386.cc`, `aarch64/`, `arm/`, `alpha/driver-*.cc` | `config.host` `host_extra_gcc_objs` → `EXTRA_GCC_OBJS` |
| `darwin-driver.cc`, `vxworks-driver.cc` | `config.gcc` `extra_gcc_objs`; they live in `gcc/config/`, not `config/<cpu>/` |
| `sol2-c.cc`, `vms/vms-c.cc` | `c_target_objs`, held out of the per-base list by the awk's `^config/<cpu>/` test |
| `arm-d.cc`, `mips-d.cc`, `rs6000-d.cc`, `s390-d.cc`, `sparc-d.cc`, `freebsd-d.cc` | `@d_target_objs@`, a single `${target}` substitution |
| `avr/gen-avr-mmcu-specs.cc` | `avr/t-avr`, a build-machine tool |

`driver-i386.o` is the only host driver built, and it is right by luck: the
host is x86_64, so the primary's chain is the right one. On an aarch64 host
`driver-aarch64.o` gets i386's macros silently. #143 chose `target-specs` for
`-march=native`, which is the same answer — `local_cpu_detect` wants a fact
about the deployed machine.

`@d_target_objs@` is the `PASSES_EXTRA` shape: fed by the legacy single
`${target}`, so five of the six D glue files are absent rather than off.
