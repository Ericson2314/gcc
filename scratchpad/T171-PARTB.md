# #165 / #171 Part B — is renaming the right answer for a source two back ends share?

**Verdict: yes, for all three files, and the question "how many back ends list
it" is the wrong question.**  The right one is *does compiling it once force
one back end's answer on another*, and that has three different answers here,
each reached by a different mechanism.  A rule that reads the `extra_objs`
lists gets all three wrong.

Measured in `/tmp/b-a0e5-8-before` (snapshot `d0a93825d3d`, eight back ends:
i386, aarch64, rs6000, s390, riscv, mips, sparc, arm), with
`scratchpad/t171-partb.sh` and `scratchpad/t171-libc.sh`.

| file | aarch64 vs arm code | why two copies are required |
|---|---|---|
| `config/arm/aarch-common.cc` | **DIFFERS**, 4 instructions | per-base **data** |
| `config/arm/aarch-bti-insert.cc` | identical | per-base **callees** |
| `config/linux.cc` | identical (also i386 vs s390 / mips / rs6000) | per-base **branch**, currently dead in this target list |

## 1. `aarch-common.cc` — different data, and the difference is visible

Compiled with the build's own command for each base, disassembled, `_<base>`
suffixes normalised away so that renaming cannot masquerade as a difference in
code.  Four instructions differ, and every one of them is an immediate:

```
   484:	cmpw   $0x51,(%rdi)          |     484:	cmpw   $0x50,(%rdi)
   714:	cmpw   $0x51,(%rdi)          |     714:	cmpw   $0x50,(%rdi)
   cbc:	mov    $0x42,%esi            |     cbc:	mov    $0x50,%esi
   ceb:	mov    $0x42,%esi            |     ceb:	mov    $0x50,%esi
```

`0x42` = 66 and `0x50` = 80 are `CC_REGNUM`: `aarch64.md:111` says 66,
`arm.md:40` says 80.  They reach the file through `insn-constants.h` in that
back end's `tm.h`, which `aarch-common.cc:33` names as `BASE_HEADER (tm.h)`.
The site is `arm_md_asm_adjust`, the `TARGET_MD_ASM_ADJUST` hook, in
`gen_rtx_REG (mode, CC_REGNUM)` — i.e. `asm` flag outputs.  The `cmpw`s are a
CC machine-mode number, likewise per back end.

**Compiled once, one of the two back ends would put its condition codes in the
other's register**, silently, in generated RTL.  There is no diagnostic for
that anywhere.

## 2. `aarch-bti-insert.cc` — identical code, different callees

Byte-identical instructions.  `nm -uC` is the arm that settles it:

```
aarch64.o                          arm.o
U aarch_gen_bti_c_aarch64()        U aarch_gen_bti_c_arm()
U aarch_gen_bti_j_aarch64()        U aarch_gen_bti_j_arm()
U aarch_pac_insn_p_aarch64(rtx*)   U aarch_pac_insn_p_arm(rtx*)
U aarch_bti_enabled_aarch64()      U aarch_bti_enabled_arm()
U aarch_bti_j_insn_p_aarch64(..)   U aarch_bti_j_insn_p_arm(..)
U aarch_bti_arch_check_aarch64()   U aarch_bti_arch_check_arm()
U aarch_fun_is_indirect_return_aarch64(..)  U ..._arm(..)
```

Seven references each, to seven **different functions**.  One object can hold
one set.  So this file needs two copies for a reason the code comparison
cannot see — and note the direction of the trap: a comparison that had
stopped at "the instructions are identical" would have concluded *duplication*
and merged them.

Those seven names are already in `MULTI_TARGET_RENAME_NAMES`, so the rename
list is not merely making the link work here; it is what makes the two
instantiations *possible*.

## 3. `linux.cc` — identical because of the target list, not the file

Identical for aarch64/arm, i386/s390, i386/mips and i386/rs6000, with **no
per-base undefined reference at all** — only `global_options` and `targ_caps`.
Read naively that says the file is target-neutral and its three `linux_*`
renames are pure duplication.

It says no such thing.  `config/linux.h:31`:

```c
#ifdef SINGLE_LIBC
#define OPTION_GLIBC_P(opts)  (DEFAULT_LIBC == LIBC_GLIBC)          /* constant */
#else
#define OPTION_GLIBC_P(opts)  ((opts)->x_linux_libc == LIBC_GLIBC)  /* runtime  */
#endif
```

and `config.gcc:1115` gives every `*-*-uclinux*` target
`DEFAULT_LIBC=LIBC_UCLIBC SINGLE_LIBC` through `tm_defines`.  All eight
configured targets are glibc, so all eight take the runtime branch and all
eight agree.  `t171-libc.sh` adds that one target's own `tm_defines` to the
build's own command and the code changes completely — `linux_libc_has_function`
collapses from a nineteen-instruction option read to

```
   0:	xor    %eax,%eax
   2:	ret
```

a compile-time constant `false`.

**This is the `two back ends cannot tell' shape with eight back ends instead of
two**, and it is the most important of the three, because here the measurement
that looks like permission to merge is the one produced by the configuration
rather than by the file.  Merging on that evidence would be correct on this
build and wrong the first time somebody configures a uclinux target — with no
diagnostic, because the merged object compiles and links either way.

Limit of that arm, said out loud: it is a `-D` on the command line, not a
configured uclinux triple, so it demonstrates the mechanism rather than
reproducing the configuration.  Reproducing it needs a separate finding first —
`arm-linux-gnueabihf` and `arm-uclinuxfdpiceabi` are two triples of ONE back
end, and this build keys `tm-<base>.h` by `cpu_type`, so their two `tm_defines`
sets collapse into one header.  That is another instance of the same bug and is
recorded here, not fixed.

## The rule this yields

> A source under `config/` is compiled once per back end iff its **text**
> reads anything the back end supplies — a macro from its `tm.h`, a function
> only it defines, a `tm_defines` symbol.  How many back ends `config.gcc`
> lists it in decides nothing.

"Shared source" and "shared object" are different claims.  `aarch-common.cc` is
shared *text parameterised by `tm.h`* — a template, not a library — and asking
why a genuinely shared file has two copies is like asking why a template has
two instantiations.  Compiling it once does not remove a duplicate; it picks
one instantiation and gives it to everybody, which is precisely the defect this
branch exists to eliminate.

Corollary for the rename list: the renames are not a workaround for the
duplication.  They are what makes per-base instantiation expressible at all,
given that C++ has one global namespace for these symbols and the generators'
`namespace insn_<base>` trick does not reach hand-written sources.  The honest
alternative is not "compile once" but "put hand-written back-end sources in
`namespace <base>` too", which is a much larger change with the same effect and
no measurement here favours it.

**Nothing was added to or removed from `MULTI_TARGET_RENAME_NAMES` by this
work.**  Part A's ordering trap (`make_pass_insert_bti`) was dissolved by
making shared code call a per-base forwarder rather than the bare name, so the
rename stays valid unchanged.
