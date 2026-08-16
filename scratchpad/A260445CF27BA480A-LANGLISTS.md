# The sibling per-language lists, after `MT_CXX_OBJS_<base>` (491713a900a)

Measured at `f12a610e587`, anchor **52**.  Instruments committed beside this
file: `agent-a260445cf27ba480a-langobjs.sh` (191 triples, `config.gcc` sourced
once each) and `agent-a260445cf27ba480a-eobjs-order.sh` (permute two records of
one `cpu_type` in a real manifest, require the generated make text to be
identical).

`MT_CXX_OBJS_<base>` was empty for 32 of 48 back ends because an assignment sat
inside a loop most bases never entered.  One instance of a shape is never one
instance here, so both shapes were asked of every per-language list.

## SHAPE A -- a list that never reaches the build per back end

**`d_target_objs`, `rust_target_objs`, `jit_target_objs` and
`fortran_target_objs` have no manifest record at all.**  They are `AC_SUBST`ed
straight out of `gcc/configure.ac:1621`'s single legacy `${target}` pass through
`config.gcc` and land in `gcc/Makefile.in:2314-2323` as
`D_TARGET_OBJS=@d_target_objs@` and siblings -- the PRIMARY target's list alone.
This is the state `c_target_objs` and `cxx_target_objs` were in before their
fixes, verbatim, in four more variables.

Population, from the 191-triple census (`default-d.o` / `default-rust.o` /
`default-jit.o` are unconditional, so every back end has a non-empty list):

| list | back ends with an own `<cpu>-*.o` |
|---|---|
| `d_target_objs` | aarch64 arm i386 loongarch mips pa riscv s390 sparc (9) |
| `rust_target_objs` | i386 (`${cpu_type}-rust.o`, one block) |
| `fortran_target_objs` | alpha i386 ia64 rs6000 -- all four are OS files (`darwin-f.o`, `vms-f.o`) |
| `jit_target_objs` | i386 (`i386-jit.o`) |

**And it is worse than a missing object, because the hook table is a single
global.**  `d/d-target.h:29` declares one `struct gcc_targetdm targetdm`,
defined once by whichever OS file is linked (`config/linux-d.cc:79`,
`config/default-d.cc:28`, ...), and its `d_cpu_versions` slot comes from
`TARGET_D_CPU_VERSIONS` in **`tm_d.h`**.  `d/d-builtins.cc:524` calls
`targetdm.d_cpu_versions ()` unconditionally.  `gcc/Makefile.in:3250`'s
`cs-tm_d.h` rule builds `tm_d.h` from `$(tm_d_include_list)`, i.e.
`@tm_d_include_list@`, i.e. the primary's chain -- and **`tm_d.h`, `tm_rust.h`
and `tm_jit.h` have no per-base counterpart anywhere**:

```
grep -n 'tm_d\|tm_rust\|tm_jit' gen-multi-target-md.awk gen-target-manifest.sh
-> 0 hits (the `tm_defines' matches are a different name)
```

So a multi-target `cc1d` would announce x86's D CPU versions for every target,
by the `TARGET_LIBCALL_VALUE` unsupplied-hook route, with no diagnostic.  This
is the shared-`tm.h` disease in three headers nobody has looked at, and the
reason nobody has is that no board builds those languages -- the same reason
`cc1plus` was never linked.

**NOT MEASURED, AND SAY SO:** nothing here was built.  This build is
`--enable-languages=c,c++`; `cc1d`, `cc1rust`, `f951` and `libgccjit` were not
compiled, not linked and not run.  The above is read from the source and the
generated makefile, and the D claim in particular is a link-and-hook argument,
not an observed wrong answer.

`objc` and `obj-c++` need no separate finding: `objc/Make-lang.in` and
`objcp/Make-lang.in` reach `C_TARGET_OBJS` / `CXX_TARGET_OBJS` through
`C_AND_OBJC_OBJS` / `CXX_AND_OBJCXX_OBJS`, so 491713a900a covers both.  That is
why `cc1objplus` failed alongside `cc1plus` in the report that found it.

## SHAPE B -- first-record-wins, and it is LIVE in `extra_objs`

`gen-multi-target-md.awk`'s `flush()` returns at

```awk
if (seen[cpu]) { emit_triple(); reset(); return }
```

so everything after that line is read from the FIRST record for a `cpu_type`.
Of the keys read there, the census asked which actually differ between two
triples of one back end:

| key | differs within a `cpu_type`? | consumed | verdict |
|---|---|---|---|
| `extra_objs` | **YES, 20 back ends** | first record only | **DEFECT, live** |
| `out_file`, `md_file`, `extra_modes`, `common_out_file` | no, across all 191 triples | first record only | correct today, and now measured rather than assumed |
| `tm_defines`, `tm_p_file`, `tm_include_list` | yes | `emit_triple()`, EVERY record | by design |
| `extra_options`, `target_gtfiles` | yes | unioned by `gen-target-manifest.sh` | fine |

The 20: aarch64 alpha arc arm bfin csky frv pa i386 ia64 m68k microblaze mips
or1k rs6000 s390 sh sparc vax xtensa.  The divergence is almost always an OS
object -- `linux.o`, `vms.o`, `darwin.o`.

Demonstrated on a real two-triple manifest (`aarch64-elf,aarch64-linux-gnu`),
permuting only the record order:

```
MULTI_TARGET_OBJS_aarch64   elf first:   ... aarch64-neon-builtins-shapes.o target-addr-aarch64.o ...
                            linux first: ... aarch64-neon-builtins-shapes.o mt-aarch64/linux.o target-addr-aarch64.o ...

only in the linux-first output:   mt-aarch64/linux.o: $(srcdir)/config/linux.cc aarch64-inc/s-inc s-gtype
```

`config/linux.cc` supplies `linux_libc_has_function`, which aarch64's
`linux.h` chain installs as `TARGET_LIBC_HAS_FUNCTION`.  Whether it is compiled
for the aarch64 base is decided by which triple's record came first.  One name,
several authorities, no diagnostic -- and `configure.ac:236` sorting
`--enable-targets` cannot help, because sorting fixes the ORDER and this defect
is that the order matters at all.

**Invisible to every board this branch has run**, because `backends-47.txt` is
one triple per back end, so no `cpu_type` has a second record to lose.

**NOT FIXED, deliberately, and here is the decomposition.**  The fix is the one
491713a900a and the `c_target_objs` fix used: accumulate per back end over every
record and emit at `END`.  For `extra_objs` that means moving `flush()`'s whole
hand-written-source block (`n = split(outf " " xobjs, parts, " ")` through the
`objs = objs " mt-" cpu "/" obj ".o"` append) out to `END`, because `objs`
becomes `MULTI_TARGET_OBJS_<cpu>` in the same function.  It also needs
`frag_source_for`'s second argument to become the ACCUMULATED `mtc_frags[cpu]`
rather than the first record's `tmkp` -- otherwise the union names `linux.o`
while the first record's fragments do not claim it, and the generator's own
`$(error ... nothing in aarch64's tmake_file claims a rule for linux.o)` fires.
That is a generator restructure needing its own 47-base build to validate, and
it is a no-op for every configuration this branch currently builds.
