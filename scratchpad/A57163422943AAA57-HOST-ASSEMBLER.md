# `gcc.c-torture/compile` is NOT a compiler defect — every multi-target board fed cross assembly to the HOST x86 assembler

SC-BOARD.md ranked this **#2 in the work queue**: 20,256 results across aarch64
and s390x, *"stock fails ZERO ... pure compile-and-assemble — no libgcc, no
linker, nothing to excuse it."* There is something to excuse it. It is the
harness.

## The defect

```
$ xgcc -ftarget-config=<s390x cfg>   -print-prog-name=as
/tmp/b-.../gcc/as
$ xgcc -ftarget-config=<aarch64 cfg> -print-prog-name=as
/tmp/b-.../gcc/as          <- THE SAME FILE, for every target

$ head <builddir>/gcc/as
ORIGINAL_AS_FOR_TARGET=".../gcc-wrapper-15.2.0/bin/as"    <- the HOST x86 as
```

One libtool-style shim around the build machine's own assembler, serving all
four targets. So every `-c` and every `dg-do assemble` handed s390x and
aarch64 assembly to an x86 assembler:

```
error: invalid -march= option: `z900'     9,184 occurrences on s390x
```

**SC-BOARD §0 already records this exact defect — and fixed it on the STOCK
side only.** Its guard S4 (`-print-prog-name=as`, then assemble a real
function and require `<target>-readelf -h` to name the machine) was written
for the control and never applied to the thing under test. The multi-target
side has carried it in every board this project has taken, TAA-BOARD included.

## The compiler is fine — measured, not assumed

```
xgcc -ftarget-config=<s390x cfg> -O1 -w -S -o z.s z.c        rc=0
s390x-ibm-linux-gnu-as -march=z900 -o z3.o z.s               OK
s390x-ibm-linux-gnu-readelf -h z3.o    Class: ELF64   Machine: IBM S/390
```

Same compiler, same input: the `.s` is correct and the target's own assembler
accepts it into a well-formed object.

## What it costs the debt figures

```
s390x   debt 14,256, of which ~10,114 is this   -> ~71% of that target's debt
aarch64 debt 93,526, of which ~10,142 is this
```

**s390x's real debt is on the order of 4,100, not 14,256.** Both figures in
`A57163422943AAA57-REBASELINE.md` are upper bounds for this reason as well as
for the `cselib` one already noted there.

## The fix, and why the obvious one does not work

`-B<toolsdir>/` alone does **nothing**: the cross tools are named
`<triple>-as`, the driver searches for `as`, and it falls through to the build
dir's shim. What the driver honours is a directory containing a plain `as`:

```sh
ln -sf $TOOLS/$T-as $B/asdir-$T/as
xgcc -B$B/asdir-$T/ -B$B/gcc/ ...
```

Landed in `mtcheck.sh` as **GUARD 3c**, with `MT_TOOLS_<triple>` naming each
target's binutils bin directory, and:

- **absence is a REFUSAL**, not a silent fallback to the host tool
  (`MT_ALLOW_HOST_AS=1` to state otherwise deliberately);
- the guard asks the RUNNING driver (`-print-prog-name=as`), then **assembles
  a real function** and requires the target's own `readelf` to name the
  machine — because a host `as` accepts an empty file, so "no complaint" is
  another way to see nothing;
- `ASDIR` is prepended to `GCC_UNDER_TEST`, so the guard protects the run
  rather than merely reporting on it.

Verified both ways: without `MT_TOOLS_*` it refuses by name; with it,
`-- guard: assembler is s390x-ibm-linux-gnu's own, and it produces: IBM S/390`.

## What this does NOT excuse

The SVE/SME ACLE cluster (~102,000 aarch64 FAILs) is unaffected — those are
`-S`-shaped `scan-assembler` tests that never reach an assembler, and their
cause is established separately as the constraint vocabulary
(`A57163422943AAA57-CONSTRAINT-VOCABULARY.md`).
