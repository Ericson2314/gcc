# BACKLOG GROOMING — 42 items adjudicated against the tree

Worktree `agent-a6385f35ace2b08f7`, HEAD `e3fac057ae4` (== `multi-target` tip),
anchor `grep -c MULTI_TARGET gcc/Makefile.in` = **52** (measured, not quoted).

**The worktree arrived at the bare-repo HEAD `7208eca60d0`, anchor 0** — the
trap PRINCIPLES §5 predicts and the tenth agent to hit it. Reset with
`git checkout -B worktree-agent-a6385f35ace2b08f7 e3fac057ae4` before any
measurement was taken. Note that `git rev-parse multi-target` is
`e3fac057ae4`, which is **ahead of** the `2b20283b6b1` shown in this session's
opening git status; `git merge-base --is-ancestor 2b20283b6b1 e3fac057ae4`
succeeds, so `e3fac057ae4` is the tip and the snapshot was stale.

Nothing in this document changes code. Every figure below has the command that
produced it beside it. Where a "gone" verdict is given, a **positive control**
— the same pattern finding something it should find — is shown, because
PRINCIPLES §4 records this project losing days to a zero from a broken pattern.

---

## 0. TWO STRUCTURAL FINDINGS THAT AFFECT HOW THE LIST IS READ

### (a) THE ITEM NUMBERS IN THE BRIEF AND THE `#NNN` SECTIONS IN `STATE.md` ARE DIFFERENT AUTHORITIES, AND THEY COLLIDE

This is the `shared-numbering-many-authorities` pattern the project already has
a name for, now firing on the backlog itself. Measured collisions:

| n | brief's subject | `STATE.md`'s `#n` section | same? |
|---|---|---|---|
| 174 | `configure.ac:1621` sources `config.gcc` with `${target}` | ~14423 MODE ORDINALS / `extract_insn` | **NO** |
| 175 | pass-name vocabulary | `T175-GEN-NOP.md`: `gen_nop` | **NO** |
| 100 | sjlj residual | ~2027 associates #100 with `limits.h`/`#24` | **NO** |
| 95 | three silent-acceptance defects | ~1863 `test_scalar_int_ops` CImode selftest | **NO** |
| 143 | 8 bare `host_detect_local_cpu` | ~13386 "compiled once and shared" | **YES** (same item, different framing) |

Command: `grep -nE '^#{1,3} .*#(174|175|100|95|143)' scratchpad/STATE.md`
and `grep -nE '#(75|96|100|95)\b' scratchpad/STATE.md`.

**Consequence: do not resolve a backlog number by grepping `STATE.md` for it.**
Three of the five above would have produced a confident, wrong verdict. Every
verdict below is adjudicated against the brief's one-line *subject*, and where
`STATE.md` corroborates, the subject was checked to match first.

### (b) TWO ITEM NUMBERS CANNOT BE ADJUDICATED AT ALL

`#90` ("two pending gate removals") and `#95` ("three silent-acceptance
defects") have **no body in the brief and no section in the tree**:

```
grep -rn 'two pending gate|pending gate|gate removal' scratchpad/   -> 0 hits
grep -rn 'silently accept|silent acceptance|accepted silently' \
     gcc/Makefile.in Makefile.tpl target-specs/configure.ac \
     scratchpad/PRINCIPLES.md                                        -> 0 hits
POSITIVE CONTROL: grep -n 'inert' scratchpad/STATE.md               -> 12+ hits
```

The positive control shows the corpus and the grep both work. PRINCIPLES §5
says a task number in a brief is a *label for findings that must be restated in
the brief*, and that an agent who writes a verdict anyway is manufacturing a
green. **No verdict is given for #90 or #95.** They need their bodies restated
before anyone can work them.

### (c) ONE MECHANISM EXPLAINS SIX SEPARATE ITEMS

`#21`, `#25`, `#26`, `#69`, `#100`/`#120`, `#192` are all the same defect in six
costumes: **a build-time answer computed from the ONE legacy `${target}` and
imposed on all 47 bases, reaching its consumer on a `#if` line where a runtime
capability cannot go.** The chain is:

```
gcc/configure.ac:1621   . ${srcdir}/config.gcc        <- one ${target}
gcc/Makefile.in:673     tmake_file=@tmake_file@        <- that target's fragments alone
gcc/Makefile.in:3143    -include $(tmake_file)
gcc/config/t-slibgcc:2  SHLIB = true
gcc/Makefile.in:3940    $(if $(SHLIB),-DENABLE_SHARED_LIBGCC)
gcc/config/vxworks.h:277,285   #if defined(ENABLE_SHARED_LIBGCC)
```

`gcc/Makefile.in:2069-2072` states this in the tree already: *"in an EIGHT-base
build dir, tmake_file is substituted as i386's list alone"*. **These six should
be re-prioritised as one investigation with one channel design**, not six.

---

## GROUP A — early-era items

### #15 — verify unverified `targ_caps` conversions — **ALREADY DONE**

The verifier exists, is wired to the always-run path, and I ran it.

```
sh gcc/check-target-caps.sh $PWD/gcc \
   /tmp/b-a62563d5673423af6-47/specsread/bare-{aarch64-unknown-linux-gnu,x86_64-pc-linux-gnu}/specs-config
-> rc=0   "check-target-caps: 2 config file(s), every capability read by something"
```

POSITIVE CONTROL (a bogus key appended to a copy):

```
printf 'zzz_definitely_not_a_key 1\n' >> /tmp/ctc-neg.cfg
sh gcc/check-target-caps.sh $PWD/gcc /tmp/ctc-neg.cfg
-> rc=1  "capabilit(ies) written into a target config file that nothing reads:
          zzz_definitely_not_a_key"
```

**The exemption backlog has collapsed to one entry.** `gcc/check-target-caps.sh`
around :686-733: the table now holds only `target optout` (the configuration's
own name, read through `targ_caps_target_name`, deliberately fieldless). The
comment records that the *twenty-five* "answer discarded" entries and four
`gxx_*` ones are gone, and that the `declared and read, but nothing emits it`
half is **EMPTY** — it held twenty-one (16 ix86 assembler caps, `solaris_ld`,
`vms_debug`, and the three `cppdefault` keys). A stale exemption is fatal, so
the table cannot outlive what it excuses.

CAVEAT, stated because PRINCIPLES §5 requires it: the two `specs-config` files
are **another agent's build artefacts**, not fixtures I wrote. Their provenance
checks out (`grep -c . = 224`, matching `AB1900D5279BA137F-BOARD.md`'s recorded
224 for a tip-era config file), but a clean re-run belongs in whoever next
builds.

Residual, and it is narrow: `STATE.md` §5 (~4620) records **one** conversion
still unverified *at run time* — `as_ltoffx_ldxmov_relocs`, because ia64 does
not build in this tree. The missing arm is exactly "an ia64 build emitting
`@ltoffx` vs `@ltoff` under a config file setting the key 1 and 0".

### #18 — nest per-arch capability fields — **STILL LIVE, and recommend WON'T-DO**

`struct target_caps` is **flat: zero nested sub-structs**.

```
grep -cE '^  (bool|int|const char \*|unsigned) ' gcc/target-caps.h        -> 116
grep -nE 'struct [a-z_]+ *\{|\} [a-z_]+;' gcc/target-caps.h              -> 0
```

Per-arch prefix groups among the 116 (`grep -oE '^  (bool|int|const char \*) [a-z0-9_]+;' | ...`):
`ld` 21, `gas` 18, `ix86` 14, `loongarch` 7, `mips` 6, `riscv` 5, `s390` 4,
`aarch64` 3, `alpha` 2, `xcoff`/`vms`/`solaris`/`sjlj` 1 each.

This is a cosmetic reorganisation with a real cost: it would churn the 224-line
config-file key vocabulary, `read_target_caps`' strcmp ladder, and
`check-target-caps.sh`'s key parser, for no behavioural gain. It is also
squarely the `prototype-first-not-upstream-shape` trap. **Recommend close as
won't-do until upstreaming (#39) actually starts.**

### #21 — `HAVE_SOLARIS_AS`/`LD` are 0 for everyone — **PREMISE CONFIRMED; partly worked; the AS half untouched**

Premise holds and is now written into the tree at `gcc/defaults.h:495-543`:
both are hard `0`, and the comment states they are **PLACEHOLDERS, not
answers**, and — the sharp part — that *"these `#define`s do NOT reach those
sites: defaults.h is included at the END of tm.h, after the OS headers that
test them."*

```
git grep -nE '#[ \t]*define[ \t]+HAVE_SOLARIS_(AS|LD)' -- gcc/ target-specs/
-> gcc/defaults.h:525  #define HAVE_SOLARIS_AS 0
   gcc/defaults.h:528  #define HAVE_SOLARIS_LD 0
   gcc/defaults.h:543  #define HAVE_SOLARIS_LD 0     <- defined twice, two #ifndef blocks
```

Residual consumer sites, re-measured:

```
git grep -nE 'HAVE_SOLARIS_AS' -- gcc/config/ | grep -vE 'used to be|/\*| \* ' | wc -l -> 15
git grep -nE 'HAVE_SOLARIS_LD' -- gcc/config/ | grep -vE 'used to be|/\*| \* |producing' | wc -l -> 8
```

**Progress since the description**, all real: `targ_caps.solaris_ld` exists
(`gcc/target-caps.h:751`), is probed (`target-specs/configure.ac:2198-2206`) and
emitted (`:3073`); `gcc/config/sol2.cc:307` is converted; `LINK_ARCH_SPEC`
became a `*link_arch_gnu`/`*link_arch_sun` named-spec pair overridable by the
spec file (`gcc/config/sol2.h:282-330`).

**The asymmetry nobody has flagged: `solaris_as` has no probe and no field.**

```
grep -n 'solaris_as' target-specs/configure.ac gcc/target-caps.h  -> 0 hits
POSITIVE CONTROL: grep -n 'solaris_ld' target-specs/configure.ac  -> :2198, :2203, :2206
```

The AS half has had zero work, and it is the half with the *loud* consumers:
`gcc/config/sparc/sparc.md:560` and `:8049` use it as C in an insn condition,
where an absent macro is a hard error once `genattrtab`/`gencondmd` go per back
end.

**Next agent's first move:** add a `gcc_cv_solaris_as` probe to
`target-specs/configure.ac` mirroring `solaris_ld` at :2198, and a
`targ_caps.solaris_as` field — the `.md` C conditions will otherwise break the
build the day sparc is added to `--enable-backends`.

### #25 — `--with-darwin-extra-rpath` — **STILL LIVE, low severity, same class as #100/#120**

Still present and still a `gcc/configure` global:

```
gcc/configure.ac:2327  DARWIN_DO_EXTRA_RPATH=0
gcc/configure.ac:2328  AC_ARG_WITH(darwin-extra-rpath, ...)
gcc/configure.ac:2337  AC_DEFINE_UNQUOTED(DARWIN_DO_EXTRA_RPATH, $DARWIN_DO_EXTRA_RPATH)
gcc/config/darwin.h:398  #if DARWIN_DO_EXTRA_RPATH
```

Not carried to target-specs:
```
grep -c 'darwin.extra.rpath\|DARWIN_ADD_RPATH' target-specs/configure.ac -> 0
POSITIVE CONTROL: grep -ci darwin target-specs/configure.ac              -> 16
```

Severity correction: because darwin.h is the **only** reader, a global answer
does not currently leak *between* targets — it merely means an operator cannot
set it for darwin in a multi-target build without setting it for the build. It
is a `#if`-line consumer, so it is the same class as the sjlj pair and should be
worked with them, not separately.

For scale, the other `AC_ARG_WITH` names still in `gcc/configure.ac`:
`build-libsubdir changes-root-url cpp darwin-extra-rpath diagnostics-color
diagnostics-urls documentation-root-url gc insnemit-partitions
matchpd-partitions zstd zstd-include zstd-lib` — **`darwin-extra-rpath` is the
only per-target one left.** That is worth knowing: it is a population of one.

### #26 — `INCLUDE_DEFAULTS` include ORDER — **STILL LIVE, and it has a currently-firing defect**

Four target headers still build their own `INCLUDE_DEFAULTS`:

```
git grep -ln '^#define INCLUDE_DEFAULTS' -- gcc/config/
-> gcc/config/linux.h  gcc/config/netbsd.h  gcc/config/openbsd.h  gcc/config/rs6000/sysv4.h
```

**The live defect: `TOOL_INCLUDE_DIR` has no definition anywhere in the tree,
so two `#ifdef TOOL_INCLUDE_DIR` guards are silently always-false today.**

```
git grep -nE '(-D|#[ \t]*define[ \t]+)TOOL_INCLUDE_DIR' -- gcc/ | grep -v GPLUSPLUS
-> only comments (Makefile.in:915, configure.ac:3112, cppdefault.cc:259,
   target-caps.cc:307, target-caps.h:860).  NO definition.

POSITIVE CONTROL, identical pattern, different outcome:
git grep -nE '(-D|#[ \t]*define[ \t]+)CROSS_INCLUDE_DIR' -- gcc/
-> gcc/Makefile.in:5742  -DCROSS_INCLUDE_DIR=\"$(CROSS_SYSTEM_HEADER_DIR)\"
```

So at `gcc/config/linux.h:153` and `gcc/config/rs6000/sysv4.h:987` the
`{ TOOL_INCLUDE_DIR, "BINUTILS", 0, 1, 0, 0 }` entry **drops out of
`INCLUDE_DEFAULTS` with no diagnostic**, while the `CROSS_INCLUDE_DIR` entry
three lines above it survives. `gcc/Makefile.in:5724` documents the removal
(`TOOL_INCLUDE_DIR ... is now GONE from here entirely: it has its own key,
tool_include_dir`) but the two `#ifdef` consumers were not updated with it.
This is the `probe-removal-silent-default-traps` pattern, live.

Also still one-target-for-everyone: `gcc/Makefile.in:628`
`NATIVE_SYSTEM_HEADER_DIR = @NATIVE_SYSTEM_HEADER_DIR@`, `-D`'d at `:3942` and
`:5743`, and `#undef`/redefined by `gcc/config/i386/xm-djgpp.h:30` and
`gcc/config/mingw/mingw32.h:244`.

`gcc/CONFIGURE-HISTORY.md:232` already scopes the item:
*"Getting `INCLUDE_DEFAULTS` itself out of the privileged target's `tm.h` is a
separate job, and `TOOL_INCLUDE_DIR`/`CROSS_INCLUDE_DIR`/
`NATIVE_SYSTEM_HEADER_DIR` — which have exactly the same defect and no key yet
— belong to it."*

**Next agent's first move:** decide whether the two dead `#ifdef
TOOL_INCLUDE_DIR` arms should read `targ_caps.tool_include_dir` or be deleted —
either is a decision, and leaving them is the silent-default trap.

### #34 — cc1gm2 include chain — **ALREADY DONE**

`gcc/m2/gm2-gcc/gcc-consolidation.h` is fully converted:

```
:30  #include "multi-target-header.h"
:31  #include MT_HEADER (tm.h)
:36  #include "multi-target-macros.h"
:44  #include MT_HEADER (options.h)
```

with `MT_HEADER` defined at `gcc/multi-target-header.h:54,56`. The only bare
`"tm.h"` left under `gcc/m2/` is `gm2spec.cc:27` — the **driver** spec file,
which is the same host-side class as every other `*spec.cc` and is not this
item. Command: `git grep -n 'tm\.h\|MT_HEADER' -- gcc/m2/`.

### #37 — target libraries beyond libgcc — **STILL LIVE, and the correct figure is "1 of 26"**

`Makefile.def` declares **26** `target_modules`
(`grep -c '^target_modules' Makefile.def`). The per-target instantiation
machinery — the `$(foreach mt_t,$(MT_TARGET_SUBDIRS),$(eval ...))` design
described at `Makefile.tpl:2295-2320` as *"one PARAMETERISED block per module"*
— is used by **exactly one module, `target-specs`**:

```
grep -n 'MT_TARGET_SUBDIRS' Makefile.in | grep -vi specs
-> only the declaration (:310), the empty-guard (:320,:321) and prose.
   Every rule-generating use names target-specs.
```

So libgcc, libstdc++-v3, libatomic, libgomp and the other 22 remain
single-target. This is the same gap as #70's residue and the blocker behind
#172.

### #44 — 45 deleted `AC_ARG_*` warn — **STILL LIVE; the count is 54 deleted / 46 orphaned, and severity is lower than stated**

Measured against genuine upstream at the merge-base `c31b7a09eea`:

```
git show c31b7a09eea:gcc/configure.ac | grep -oE 'AC_ARG_(WITH|ENABLE)\(\[?[a-zA-Z0-9_-]+' | ... | sort -u   -> 85
same over gcc/configure.ac                                                                                   -> 35
same over target-specs/configure.ac                                                                          -> 30
comm -23 old new                                                                                             -> 54 deleted
comm -23 (deleted) (target-specs)                                                                            -> 46 with no target-specs counterpart
```

The 46: `build-sysroot cld comdat default-pie default-ssp demangler-in-ld
dsymutil dwarf2 fix-cortex-a53-835769 fix-cortex-a53-843419 fixed-point
frame-pointer gcov gnu-indirect-function gnu-unique-object gold
host-bind-now host-pie host-shared large-address-aware
leading-mingw64-underscores libssp linker-hash-style long-double-128
long-double-format mingw-wildcard multiarch multilib multilib-generator
multilib-list newlib-nano-formatted-io objc-gc picolibc plugin-ld secureplt
specs stack-clash-protection-guard-size standard-branch-protection sysroot
threads tls version-specific-runtime-libs vtable-verify windres
x86-64-mfentry`

**Severity correction the description does not carry:** autoconf's generic
mechanism *does* fire — `gcc/configure:1432` and `:27635` print
`WARNING: unrecognized options: $ac_unrecognized_opts`. So a user typing
`--enable-gold` is not silently ignored; they get a generic warning buried in
configure output with no pointer to `target-specs/configure`. The item is
therefore "redirect by name", not "warn at all", and it is a UX item rather than
a correctness one. **Recommend de-prioritise.**

### #46 — `HAVE_LD_PIE` — **STILL LIVE, and the population GREW: 14 macros / 28 sites (was 13 / 22)**

The item's own instrument still runs and I re-ran it:

```
sh scratchpad/t116-vacuous.sh > /tmp/v.txt 2> /tmp/v.err
wc -l /tmp/v.err       -> 0        (stderr asserted empty, per PRINCIPLES §5)
grep -c '^=== ' /tmp/v.txt   -> 14  macros   (recorded: 13)
grep -c '^  gcc' /tmp/v.txt  -> 28  sites    (recorded: 22)
head -1 /tmp/v.txt     -> "macros defined over targ_caps in defaults.h: 73"
```

New since the recorded run: `HAVE_AS_TLS` (`gcc/target-caps.h:341`) and
`HAVE_AS_MMACOSX_VERSION_MIN_OPTION` (`gcc/config/darwin.h:707`).

`STATE.md` §4 (~4579) is still the correct scoping and must be read first: **the
22 (now 28) are NOT uniformly vacuous.** `gcc/mkconfig.sh:76` says target-header
guards run *"long before defaults.h"*, so an `#ifdef` in `rs6000/linux64.h` is
the OLD floor mechanism still working. The exception is `HAVE_LD_PIE`, which
`gcc/mkconfig.sh:135-136` pre-defines to 1 *ahead of* the target headers, making
`#ifdef HAVE_LD_PIE` in `alpha/linux.h:92`, `gnu.h:45`, `i386/gnu64.h:32` and
`ia64/linux.h:39` genuinely always-true.

**Next agent's first move:** adjudicate the five `HAVE_LD_PIE` sites only —
they are the subset `mkconfig.sh` proves is vacuous. The other 23 need
per-site include-order reasoning and must not be swept.

Note this is the **same mechanism as #21 and #26**: the answer depends on
include ORDER, not on the macro.

### #69 — `--enable-shared` breaks vxworks — **STILL LIVE, mechanism fully pinned**

See §0(c) for the six-line chain. The load-bearing measurement is that
`tmake_file` is **not** a union across bases:

```
gcc/Makefile.in:673   tmake_file=@tmake_file@
gcc/Makefile.in:2069-2072  "In an EIGHT-base build dir, tmake_file is substituted
                            as i386's list alone: tmake_file= .../t-slibgcc ..."
gcc/config/t-slibgcc:2     SHLIB = true
grep -c 't-slibgcc' gcc/config.gcc  -> 24 target arms pull it
```

So whether `-DENABLE_SHARED_LIBGCC` is defined for all 47 bases is decided by
whichever single `${target}` `gcc/configure` was given, and
`gcc/config/vxworks.h:277` and `:285` read it on `#if` lines. `DRIVER_DEFINES`
(`gcc/Makefile.in:3931-3942`) is one set for one `gcc.o`; it also carries
`-DNATIVE_SYSTEM_HEADER_DIR` (#26).

**Next agent's first move:** `DRIVER_DEFINES` is the unit — every macro in it is
one target's answer compiled into a driver serving 47. Enumerate them before
touching `SHLIB`.

### #75 — 3 host tools depend on a target library — **STILL LIVE; correction: 3 EDGES over 2 host modules**

```
grep -oE 'module=[a-z]+-[a-zA-Z0-9_+-]+; *on=[a-z]+-target-[a-zA-Z0-9_+-]+' Makefile.def \
  | grep -v 'module=[a-z]*-target-'
-> module=all-gnattools; on=all-target-libada
   module=all-gnattools; on=all-target-libstdc++-v3
   module=all-gotools;   on=all-target-libgo
```

Distinct host modules: **`gnattools` and `gotools` — two, not three.** The "3"
is the edge count. `STATE.md:5174` confirms the subject
(*"#75 (gnattools/gotools) is untouched, as scoped"*). Blocked behind #37: there
is no per-target instantiation for any target module, so there is nowhere for a
per-target `gnattools` to attach.

### #80 — guard exists, verification owed — **ALREADY DONE; the verification is discharged in this document**

Three things were owed and all three now hold:

1. **The guard exists**: `gcc/check-target-caps.sh` (+ `check-spec-refs.sh`).
2. **It is invoked, not merely present** — the `mechanism-present-but-never-invoked`
   trap does not apply: `gcc/Makefile.in:3377-3379` puts
   `check-multi-target-specs` on `start.encap`, i.e. the always-run path, and
   `:4078` orders it *after* its producer so `-j` cannot check the previous
   build's files.
3. **It fails when it should** — shown under #15 above (rc=1, key named).

It also handles `absent-artefact-vs-absent-mechanism` by name:
`gcc/Makefile.in:4088` prints *"NOTHING CHECKED ... This is a SKIP, not a
pass."* rather than exiting 0 over an empty corpus. **Recommend close.**

### #89 — the 32-line stderr floor — **OBSOLETE as a work item; it is upstream noise and is already documented with its composition**

The floor is 8 `is unchanged` + 24 `'@' is redundant`. Both emitters are
upstream code, not this project's:

```
gcc/genoutput.cc:843   message_at (d->loc, "'@' is redundant for output template with...")
move-if-change:2       "Like mv $1 $2, but if the files are the same, just delete $1."
grep -c 'move-if-change' gcc/Makefile.in  -> 64 rules write through it
```

PRINCIPLES §6 (lines 1909-1925) already records the floor, its composition, that
it **varies with what was last rebuilt** (a no-op `make` gave 8, with the 24
absent), and that the cold arm is a different ~870-line population that must
never be quoted against it.

There is nothing here to fix that would not be the `test-harness floor` §2a
refuses. The one thing genuinely owed is procedural and is already written down:
*quote the composition you measured, never a remembered number.*
**Recommend close.** (If it is instead read as "get the floor to 0", that is
CANNOT TELL WITHOUT A BUILD: it needs a no-op incremental `make` and a line
count, and the fix would be adding stamps to 64 `move-if-change` rules — a
large change for cosmetics.)

### #90 — two pending gate removals — **CANNOT ADJUDICATE** (see §0(b))

### #94 — cppdefault re-check unblocked — **ALREADY DONE**

The blocker was the three cppdefault keys being declared-and-read but never
emitted. `gcc/check-target-caps.sh:726-731` records the resolution: the
twenty-one-entry "nothing emits it" list — *"the three cppdefault keys
`local_include_dir`, `native_system_header_dir` and
`native_system_header_component`"* among them — is **empty**, and *"All
twenty-one are emitted by `target-specs/configure.ac` now."*

The consumer side is converted end to end:

```
git grep -n 'targ_caps' gcc/cppdefault.cc
-> :94  native_system_header_component      :185 gxx_include_dir
   :187 gxx_tool_include_dir                :189 gxx_backward_include_dir
   :191 gxx_libcxx_include_dir              :216,:218 local_include_dir
   :252 fixed_include_dir                   :277 tool_include_dir
   :280,:283 native_system_header_dir
```

and `cppdefault.cc:166` notes seven initialisers read `targ_caps` from a
namespace-scope array initialised dynamically. The re-check itself is what I ran
under #15: green over two real config files, red on injection.
**Recommend close.**

### #95 — three silent-acceptance defects — **CANNOT ADJUDICATE** (see §0(b))

### #96 — per-target data in libdir — **PARTLY DONE: the driver half LANDED; only the `accel_dir_suffix` design question remains**

`STATE.md:5475-5495` describes the state at the time as *"there was no
per-target spec-file lookup at all"* — `find_target_config` found
`specs-config` under `<exec-prefix>/<version>/<target>/` but `set_up_specs`
looked for the spec file at `exec_prefix + just_machine_suffix + "specs"` with
`just_machine_suffix = ""`, i.e. `$(libdir)/gcc/specs`, one file for every
target.

**That half has since landed.** `gcc/gcc.cc:9350-9380` now carries the
per-target lookup, keyed off the same discovery:

```
gcc/gcc.cc:9379   if (found_target_config != NULL)
gcc/gcc.cc:9377   "Derived from found_target_config rather than composed again,
                   so the two files cannot come from different directories."
```

`fixincludes/mkheaders.in:160-163` puts the fixed headers in the same layout
(`$(libdir)/gcc/$(version)/<target>/`).

**What is actually left** is `STATE.md:3325`, and it is a design question, not
cleanup: `accel_dir_suffix` (`gcc/Makefile.in:821,823,3181`, consumed at
`gcc.cc:1763,5667,8686,9240,9470`) creates a **second** per-target axis — the
offload accel target — and nobody has said how the two compose. Offloading is
GCC's pre-existing narrow multi-target.

**Next agent's first move:** answer "are accel targets just more configured
targets?" before deleting or extending the suffix — `STATE.md:3332` warns the
axis may be load-bearing.

### #100 / #120 — sjlj residual — **THESE ARE ONE ITEM. STILL LIVE, exactly two sites, and already fully diagnosed in-tree**

`#120`'s "two sjlj consumers on `#if` lines" **is** `#100`'s residual. The two:

```
gcc/config/vxworks.h:297      || (DWARF2_UNWIND_INFO && !defined(CONFIG_SJLJ_EXCEPTIONS)))
gcc/config/i386/cygming.h:366 #if (defined (CONFIG_SJLJ_EXCEPTIONS) && !CONFIG_SJLJ_EXCEPTIONS)
```

Everything else moved: `targ_caps.sjlj_exceptions` (`gcc/target-caps.h:124`) is
read by `common/common-targhooks.cc:42,89` (the default for every target) and by
the arm, c6x, i386 and ia64 common files — five consumers, seven originally.

`gcc/configure.ac:1554-1580` already states the whole thing, including why
deleting the switch is the wrong move:

> *"Deleting this switch would not make those two targets read the capability —
> it would silently hand them the not-defined arm, flipping cygwin/mingw 32-bit
> to sjlj with no diagnostic. That is the probe-removal trap, so the switch
> stays until those two are given a channel of their own."*

and it emits an `AC_MSG_WARN` saying the switch now affects only those two.
`cygming.h` additionally uses it to **define `DWARF2_UNWIND_INFO`**, so it is
not merely a `#if` — it feeds a macro the middle end tests.

**Next agent's first move:** this is a *channel design* task shared with #25 and
the `HAVE_SOLARIS_LD` spec-literal group — "what carries a per-base answer to a
`#if` line?" — and should be scoped as one design, not three fixes.
**Recommend merging #120 into #100 and closing one of the two numbers.**

### #101 — fixincludes per target — **ALREADY DONE**

`gcc/` no longer runs fixincludes at all, and `mkheaders` takes the target as an
argument:

```
gcc/Makefile.in:6009-6012  "`stmp-fixinc' -- the rule that ran fixincludes during
                            gcc/'s build -- and the ... no-op ... are gone"
grep -n 'stmp-fixinc' gcc/Makefile.in  -> only 4 hits, all in comments
fixincludes/mkheaders.in:34  "THE TARGET IS AN ARGUMENT, not an @target@ substitution"
fixincludes/mkheaders.in:41  "@target@ is deliberately NOT read here.  Do not put it back."
fixincludes/mkheaders.in:112 if [ -z "$target" ] ; then ... "no --target=TRIPLE." ; exit
fixincludes/mkheaders.in:160-163  installs to $(libdir)/gcc/$(version)/<target>/
```

Note it fails by name when `--target` is absent rather than defaulting to the
build machine — the `never let the absence of an answer be an answer` rule,
correctly applied. `STATE.md:1837` corroborates (`#101 -- fixincludes is out of
gcc/'s build`). **Recommend close.**

---

## GROUP B — census items

### #32 — compiled-once files gated on target macros — **STILL LIVE, but the census OVER-COUNTS by ~285 sites (10%)**

Current recorded census, re-verified from the retained instrument output:

```
wc -l scratchpad/t32-sites.tsv                       -> 2845 sites
cut -f4 scratchpad/t32-sites.tsv | sort -u | wc -l   ->  224 files
wc -l scratchpad/t32-values.tsv                      ->  413 macros
```

The brief's "146 files / 925 sites" is superseded by **224 / 2845 / 413**.

**New finding: some of the census population is no longer compiled once.**

```
cut -f4 scratchpad/t32-sites.tsv | grep '^target-' | sort | uniq -c
-> target-regstack.cc 159, target-cumargs.cc 49, target-regs.cc 25,
   target-cumargs-select.cc 22, target-addr.cc 18, target-c-ops.cc 7, +5 more
   = 285 sites
```

Those TUs are compiled **per base** now — `gcc/Makefile.in:2021` says
*"compiled once per base as `target-cumargs-<cpu>.o`"*. A macro gated in a
per-base TU is not this item's defect. **The honest figure is ~2560 sites over
the compiled-once population**, and it is still a lower bound for headers by the
section's own caveats.

CANNOT TELL WITHOUT A BUILD for a full re-run: `t32-dump.sh` needs a 48-base
build's generated `tm-<base>.h` chain (`cpp -x c++`).

**Next agent's first move:** re-run `t32-census.sh` with the per-base object
list read from the generated `multi-target-md.mk`, so the 285 are excluded by
construction rather than by hand.

### #35 — 1137 divergent macros — **REFUTED: the figure has no source**

```
grep -rn '1137' scratchpad/
-> 2 hits, both irrelevant: t32-sites.tsv:2338 (a LINE NUMBER 1137 for
   CASE_VECTOR_SHORTEN_MODE in final.cc) and SC-diff-aarch64.txt:24 ("11374")
POSITIVE CONTROL: grep -c '413\|430' scratchpad/STATE.md  -> 34
```

No script in `scratchpad/*.sh` produces 1137. The real divergent-macro figures
at head are **413** (`wc -l scratchpad/t32-values.tsv`, divergence by value over
48 bases) and **430 after exclusions / 613 raw** (`wc -l
scratchpad/t169-macros.tsv`). **Recommend close and fold into #32/#169**, which
have instruments and reproducible numbers.

### #141 — four headers, 625 TUs — **STILL LIVE, restate as FIVE headers; the TU count needs a build**

```
git grep -ln 'MT_HEADER (tm\.h)' -- gcc   -> 5 files
   gcc/backend.h  gcc/cp/cp-tree.h  gcc/genmodes.cc
   gcc/m2/gm2-gcc/gcc-consolidation.h  gcc/target.h
```

"Four" is refuted in-tree by `scratchpad/T160-TMH-VOCABULARIES.md` §1:
`insn-constants.h` is a fifth channel sitting beside `options.h`.

625 comes from `T141-TMH-REMOVAL-PLAN.md:95` and is a shared-TU count from a
47/48-base build. The successor measurement (#187) is **812 of 833 shared
objects opening a per-base build-root header, 451 opening `tm.h`, 579 reading
`options.h`** — so 625 is superseded by 451 for the `tm.h` question specifically.
Re-counting needs a `.Po` sweep over a real build.

Confirmed rename: `-I<base>-inc` is gone from the compile lines; the `-inc`
directories survive only in `gcc/Makefile.in`'s `clean` rules (:6289, :6292).

### #147 — 421 enumerators — **STILL LIVE; the header population reproduces exactly, the enumerator count needs a build**

```
awk '/^HeaderInclude$/{getline h; print h}' gcc/config/*/*.opt | sort -u | wc -l  -> 35
  ... with one level of local #include closure                                     -> 49
```

Both match the recorded "49 headers (35 `I` files plus one level of their own
includes)" exactly. The **421** cannot be re-derived textually: brace-tracking
over the same 49 gives 913 (over-counts macro bodies and comments) and over the
35 alone gives 157. `scratchpad/mtq-enumleak.sh` reads the *build directory* for
the `insn-attr-common-<cpu>.h` collision arm.

**Settling measurement:** run `scratchpad/mtq-enumleak.sh` against a 48-base
build; it also re-reports the collision count (recorded: 2).

### #153 — pair-control bars — **the "cannot reproduce" claim is REFUTED; current green/red status CANNOT TELL WITHOUT A BUILD**

A pair-control bar is the two-base (i386+aarch64) reference codegen bar
(`grep -in 'pair.control' scratchpad/STATE.md` -> 11752, 11991, 12409, 13184).
`STATE.md:13184` says the bars *"cannot currently be reproduced"*. **That is
corrected in-tree** at `STATE.md` ~13700 (`5d96686ea51`): the bar reproduces
exactly, and the confusion was one quantity read two ways —
`12369` / `378fc33c1e70` is the **assembly** (`-o x.s`), `6376` /
`b55aaccf5ca7` is the **object** (`-c`).

Whether the bars are green at `e3fac057ae4` needs a two-base `make all-gcc` plus
`cc1 big.c`. `AB1900D5279BA137F-BOARD.md` records `12369 / 378fc33c1e70` as
`(== recorded)` at `cad1a29fbdc`, which is evidence but not a reading at this
commit.

### #160 — five channels, vocabularies — **CONFIRMED, still five; the "four" was the stale part**

From `gcc/mkconfig.sh`, verified present at head:

1. mkconfig top half (`LIBC_*`, `HAVE_LD_*`) — target-neutral
2. `options.h` (`:207-208`, rewritten to `<base>` names) — 579 shared readers
3. `insn-constants.h` (`:208`) — **the fifth the old description omits**
4. the back end's header chain + `insn-flags.h` (`:177`, `:193`)
5. `insn-modes.h` (`:194`) — arrives via `coretypes.h:553` *ahead of* `tm.h`;
   the widest channel at 812/833

`defaults.h` postponement (`:153-156`, `:236-246`) is still the mechanism.
**Only three of the five are per-target.** Recommend updating the description to
five and closing the census half; the remaining work is the two non-per-target
channels.

### #167 — `final_prescan_insn` — **STILL LIVE, unconverted, and NOT the same as the BOARD's aarch64 top cause**

```
grep -n 'FINAL_PRESCAN_INSN' gcc/final.cc
-> 2666: #ifdef FINAL_PRESCAN_INSN     2667: FINAL_PRESCAN_INSN (insn, ops, insn_noperands);
   2801: #ifdef FINAL_PRESCAN_INSN     2802: FINAL_PRESCAN_INSN (insn, recog_data.operand, ...)
grep -rl 'define FINAL_PRESCAN_INSN' gcc/config/ | wc -l   -> 14 back ends
```

Two `#ifdef`-guarded sites in a shared TU, 14 definers: **the primary decides
for all 14**, and it is `hook-exists-but-unsupplied` / the SILENT-FLOW class of
#169.

**Explicitly NOT the BOARD's cause.** `AB1900D5279BA137F-BOARD.md` §3's aarch64
item is `final_scan_insn_1` at `final.cc:2846`, which is
`fatal_insn ("could not split insn", insn)` — ~600 lines from the
`FINAL_PRESCAN_INSN` guard at 2801, with no shared code path between them. The
name similarity is a trap; **do not merge these two.**

### #168 — triple map — **ALREADY DONE (complete), with one anchor discrepancy worth settling**

The map is `scratchpad/T160-TRIPLE-MAP.md`, from `t160-map.sh` (predictor) +
`t160-validate.sh` (real builds) over a 48-back-end build. Every one of the 46
non-primary back ends has a row: **36 of 46 predicted LINK** as a third base,
**10 blocked by 6 named causes** (A `MULTI` shared-source collisions:
arm/sparc/s390/c6x/ia64/sh; B: m68k, sparc; C: epiphany; D: mcore). Three
demonstrated rather than predicted: `{i386,aarch64,riscv}`, `+mips`, `+ft32`.

**The one thing to settle:** `grep -vc '^#' scratchpad/backends-47.txt` -> **47**
triples, but that file's own header says *"48 lines, one for each `cpu_type` in
`gcc/config/`"*. **The file is one short of its own stated anchor**, and T160
measured 48. Since PRINCIPLES now anchors the project at 47, this needs one
command to resolve: re-derive the list from `cpu_type` over `config.gcc` and see
which count is right. Cheap, and an anchor being off by one is exactly the kind
of thing that later reads as a regression.

### #169 — the guard census — **ALREADY DONE**

```
wc -l scratchpad/t169-macros.tsv  -> 430  (macros after exclusions; 613 raw)
wc -l scratchpad/t169-sites.tsv   -> 690
```

Class split: LOUD-DEF 14/29, LOUD-DECL 6/7, SILENT-VALUE 171/203,
SILENT-FLOW 161/388, SILENT-OTHER 31/33 -> **20 LOUD vs 363 SILENT (18.1x)**;
335 macros scored by breadth, **164 with the primary in the minority**. The
tables are internally consistent (430 rows = the stated 430). A re-run needs the
48-base chain dump. This is a completed census; its *consequences* are #32, #167
and the class-(c) queue. **Recommend close the census and keep the tables.**

### #182 — 43 sites, 5 causes — **STILL LIVE; sites are now 45, causes still 5, and 2 sites are unclassified**

Re-measured independently:

```
git grep -n 'MIN_MODE_' -- 'gcc/*.cc' 'gcc/*.h' 'gcc/config/**/*.cc' 'gcc/config/**/*.h' \
  | grep -v genmodes.cc | wc -l     -> 45   (was 43)
POSITIVE CONTROL, same shape:  ... 'MAX_MODE_' ...  -> 40
```

By file: `expmed.cc 8`, `expmed.h 7`, `aarch64-protos.h 5`, `rs6000.cc 4`,
`tree.cc 3`, `stor-layout.cc 3`, `emit-rtl.cc 3`, `tree-core.h 2`,
`tree-complex.cc 2`, `real.h 2`, `i386.cc 2`, then `tree-vect-generic.cc`,
`optabs-query.cc`, `machmode.h`, `c-common.cc` at 1 each.

Cause status (`STATE.md` ~14436): A FIXED, **B OPEN (= #185)**, C clean, D
FIXED, E non-firing. The +2 drift is new sites not in the original cause table.

**Next agent's first move:** classify the 2 new sites before working cause B —
an unclassified site in a 5-cause table is how a cause silently gets a sixth
member.

### #185 — `AARCH64_APPROX_MODE` UB — **STILL LIVE, unchanged, and it is cause B of #182**

Definition at `gcc/config/aarch64/aarch64-protos.h:494`, 3 call sites
(`aarch64.cc:17140, 17205, 17316`). Verbatim at head:

```c
#define AARCH64_APPROX_MODE(MODE) \
  ((MIN_MODE_FLOAT <= (MODE) && (MODE) <= MAX_MODE_FLOAT) \
   ? ((uint64_t) 1 << ((MODE) - MIN_MODE_FLOAT)) \
   : (MIN_MODE_VECTOR_FLOAT <= (MODE) && (MODE) <= MAX_MODE_VECTOR_FLOAT) \
     ? ((uint64_t) 1 << ((MODE) - MIN_MODE_VECTOR_FLOAT \
			 + MAX_MODE_FLOAT - MIN_MODE_FLOAT + 1)) \
     : (0))
```

Recorded measurement at **11 bases** (`STATE.md` ~14537): union scalar-float run
10, vector-float run 210, so the maximum shift count is **219** on a `uint64_t`.
**A shift by >= 64 is UB, so it overflows by 155 already at 11 bases**, and the
overflow grows monotonically with every base added — at 47 it is strictly worse.
This is the `mode union` doing exactly what it is for (stopping `SImode` meaning
two things) and exposing a back end that assumed a small ordinal space; per §2a
the fix is downstream of the union, **not** a retreat from it.

Currently masked **by luck**: every in-tree `cpu_approx_modes` value is
`AARCH64_APPROX_NONE` (0) or `AARCH64_APPROX_ALL` (~0), so no intermediate mask
is ever computed. `gcc/config/aarch64/aarch64-json-schema.h:250` accepts
arbitrary integers and removes that protection.

Today's exact maximum ordinal needs the generated `insn-modes.h`
(`NUM_MACHINE_MODES` / `MAX_MODE_VECTOR_FLOAT`, union built by
`read_union_list`, `gcc/genmodes.cc:1534`). **This is the cheapest
build-dependent measurement on the whole list — it needs only `insn-modes.h`,
not a `cc1`.**

**Next agent's first move:** replace the `uint64_t` bitmask with a
`sbitmap`/`auto_bitmap` or a mode-indexed array; the shift cannot be made safe
while the ordinal space is a union.

---

## GROUP C — decisions and open design items

### #39 — upstreaming — **STILL LIVE, but it is a placeholder: no artefact exists**

`git log --oneline -30` shows no upstream-prep commit. The only "upstream"
commit is `cad1a29fbdc` *"scratchpad: collect the upstream bugs found
incidentally, none reported"*. `grep -ril upstream scratchpad/` -> 20 files, of
which the only upstreaming-shaped one is `scratchpad/UPSTREAM-BUGS.md`, and that
is about **bugs in unmodified upstream GCC found incidentally** (its header
notes filing needs a human at a browser — bugzilla is behind Anubis). No patch
series, no split plan.

**#39 is two different tasks wearing one number** — (i) file the
`UPSTREAM-BUGS.md` entries, blocked on a human; (ii) carve this branch into a
submittable series, for which no starting document exists. **Recommend splitting
it before it is scheduled.** Note also that #18 and several style items are only
justifiable once (ii) starts, so #39's shape gates them.

### #68 — `git grep '"tm.h"'` -> 0 — **REFUTED. It is 87, and the headline was never achievable as written**

```
git grep -n '"tm\.h"' -- gcc/ | wc -l                       -> 87
  ... excluding ChangeLogs                                   -> 81
git grep -n '#include "tm\.h"' -- gcc/ | wc -l               -> 60
git grep -l '#include "tm\.h"' -- gcc/ | grep -v testsuite | wc -l -> 40 files
POSITIVE CONTROL: git grep -n '"tree\.h"' -- gcc/ | wc -l    -> 727
```

The 40 non-testsuite files are **four distinct classes**, and only one is the
item:

- **18 in `gcc/` proper** — the real target: `collect2.cc`, `cppdefault.cc`,
  `gcov.cc`, `opts.cc`, `rtl.cc`, `rtlhooks.cc`, `print-rtl.cc`,
  `print-rtl-function.cc`, `rtl-tests.cc`, `read-rtl.cc`, `gensupport.cc`,
  `gencheck.cc`, `genmddump.cc`, `fold-const-call.cc`, `ipa-comdats.cc`,
  `vmsdbgout.cc`, `target-cumargs-select.cc`, `target-frame.h`
- **20 testsuite plugin tests** — not compiler objects at all
- **6 back-end driver / native-detect files** (`config/{aarch64,alpha,arm,avr,i386}`)
  — the same population as **#143**
- **15 front-end / LTO / jit** (`ada` 4, `rust` 2, `lto` 2, `fortran` 2, `d` 2,
  `m2`, `jit`, `go`, `cobol`, `c-family`)

`TM_H_FILE "tm.h"` also survives in the `gen*` build-time programs
(`genattrtab.cc:110`, `genemit.cc:26`, `genflags.cc:32`,
`genconditions.cc:34,46`) — a fifth class.

Guard machinery is alive, not deleted: `gcc/target.h:527,565` bracket with
`#ifdef GCC_TM_H`, `gcc/multi-target-macros.h:291` has `#ifndef GCC_TM_H`, and
`gcc/gen-multi-target-md.awk:966-970` documents the forwarder-never-defines-
`GCC_TM_H` bug.

**Recommend re-writing #68 as four numbered sub-items with the 18 middle-end
files as the only one that is actually the project's goal.** A "-> 0" acceptance
bar over 87 hits including testsuite plugins is a bar nobody can pass, which is
how an item sits open for a long time.

### #70 — libgcc re-scoped — **ALREADY DONE (the inversion is gone); one residue and one out-of-scope gap**

The `libgcc-config-inversion` memory ("libgcc reads gcc's build config as its
own") is resolved, and `git log --oneline -8 -- libgcc/` names the whole
campaign: `3cb734407ac` (probe `sys/sdt.h`/`dl_iterate_phdr`, drop
`target_header_dir`), `2d129bb3dfb` (probe `.hidden`/`.weak`), `d91e716c4d7`
(probe `PT_GNU_EH_FRAME` instead of reading gcc's `tm.h`),
`f20d6148812`+`e1c756af664` (linker RO/RW probe), `90d451f3e88` (probe
`__cxa_atexit`), `7e57f454bb1` (stop including gcc's `auto-host.h` in
`crtstuff.c`), `abd0a87eb25`.

```
grep -c auto-host libgcc/Makefile.in libgcc/config.host libgcc/crtstuff.c
-> Makefile.in 0, config.host 0, crtstuff.c 1 (a residual comment)
libgcc/configure.ac:238,249,290,405  "these USED TO come from gcc's auto-host.h
                                      through tconfig.h"
```

Residual coupling (not the inversion): `libgcc/Makefile.in:229` reads
`../gcc/BASE-VER`; `:285` still has `-I$(srcdir)/../gcc`.

**Out of scope for #70 but blocking #172:** libgcc is still one target module for
the primary target only (`Makefile.def:196`). That is **#37**, not #70.
**Recommend close #70 and move the per-target-libgcc work explicitly under #37.**

### #140 — per-base call for class (c) — **the HEADER half is DONE; the CONVERSION is STILL LIVE at ~1 of 91**

Two subjects share the number. The `STATE.md` `#140` (~10658, *"THE BASE IS
NAMED AT THE POINT OF INCLUSION, NOT LEFT TO AN `-I`"*) **landed**:
`gcc/multi-target-base.h` / `gcc/multi-target-header.h` define
`MT_HEADER`/`BASE_HEADER`; `-DMT_BASE=<cpu>-inc` is `MULTI_TARGET_BASE_DEF`
(`gcc/Makefile.in:2172`); `git grep -c MT_HEADER -- gcc/` -> 30 files;
`-I<base>-inc` is gone from the compile lines.

**Class (c)** is defined at `scratchpad/MACRO-LEAK.md:159` — *"NOT A CONSTANT
EXPRESSION — 91, every member named"* — split (c1) function-like expanding to
back-end functions/globals = **49**, (c2) `(TARGET_64BIT ? ...)`-shaped, (c3)
rtx-valued = **3**. **91 members today.**

Converted: `Pmode` (the model; 648 source sites, 715 `mt_pmode` call sites in
`cc1`, overhead <= 0.3%, `scratchpad/CLASS-C-COSTING.md`). Queued by
CLASS-C-COSTING.md §5 recommendation R1: `UNITS_PER_WORD`, `POINTER_SIZE`,
`BIGGEST_ALIGNMENT`.

**So: ~1 landed of 91, 3 queued with the costing already done.** Note
`STACK_REGS` is explicitly class (d), not (c), and CLASS-C-COSTING.md §4 names
live victims (aarch64 running the x87 `reg-stack.cc` pass; ICE in
`subst_stack_regs_pat`, `reg-stack.cc:2138`).

**Next agent's first move:** take R1's three macros in the `Pmode` shape — no
new measurement is owed, the costing is done.

### #143 — 8 bare `host_detect_local_cpu` — **STILL LIVE; count confirmed; and `STATE.md`'s #143 is the SAME item**

`git grep -n host_detect_local_cpu` (excluding ChangeLogs): **7 back ends define
the bare name** (aarch64, alpha, arm, i386, mips, rs6000, sparc); s390 is the
odd one out with `s390_host_detect_local_cpu`
(`gcc/config/s390/driver-native.cc:40`). The "8" counts the set of back ends
binding `local_cpu_detect`.

The collision is documented at the consumer: `gcc/spec-functions.cc:43` and
`gcc/spec-functions-select.cc:26-27` both say *"in a flat table the first match
wins"*. `scratchpad/t143-native.sh:70` is the instrument proving the name is
**not** in the rename list
(`awk '/^MULTI_TARGET_RENAME_NAMES/,/^$/' Makefile.in | grep -c host_detect_local_cpu`).

This is the `shared-numbering-many-authorities` pattern in code form, and it is
scored **latent, driver-side, deliberately left** at `STATE.md:13789` and
`:13932`. `STATE.md` ~13386's "compiled once and shared" framing is the *reason*
it is latent (`gcc/Makefile.in:1816`), not a different item — same authority.

Today `-march=native` silently resolves to i386's
(`scratchpad/t170-emit.sh:24`).

**Next agent's first move:** decide whether `-march=native` is in scope at all;
if yes, the first change is the rename list, not the sources.

### #159 — both switches inert — **CANNOT ADJUDICATE as stated; the likeliest reading is REFUTED**

```
grep -rn 'both switches|two switches|switches are inert|inert switch' scratchpad/ -> 0
POSITIVE CONTROL: grep -n 'inert' scratchpad/STATE.md                             -> 12+
```

No section names the pair. The obvious candidate — the two
`--enable-sjlj-exceptions` — is **not** inert: `gcc/configure.ac:1562-1580`
consumes it (deliberately, for the #100/#120 pair) and
`target-specs/configure.ac:282-286` consumes it into `spec_sjlj_exceptions`,
emitted at `:939`, listed at `:3199`. `--enable-linker-build-id` is likewise
live (`target-specs/configure.ac:691,700,702,705`).

Weakest local candidate from a consumer sweep
(`grep -o 'enable_[a-z0-9_]*' gcc/configure.ac | sort | uniq -c | sort -n`):
`enable_analyzer` (`gcc/configure.ac:712`) and `enable_win32_utf8_manifest`
(`:1587`) are each declared here with a single mention, but both need a
cross-file check before being called inert.

**Recommend: get the pair named, or close the item.** Guessing which two
switches are meant is how a false green gets manufactured.

### #172 — riscv end-to-end — **STILL LIVE; the BOARD scores riscv64 but does not make it end-to-end**

`AB1900D5279BA137F-BOARD.md` gives riscv64 a real, controlled score:
GUARD 3c reports the target's **own** assembler (`RISC-V`, readelf-verified);
PASS 267437 / FAIL 18542; debt **2,218** against stock `270248 / 15904` — the
first time riscv64 was measured against stock at all.

But the board's own §4: *"`make check` was compile-only on both sides and no
target libgcc exists in any build dir here, so nothing below is an execution
result"*, and its provenance line reads `MT_COMPILE_ONLY=1 ... all-gcc only, no
target libgcc`. **Zero execution results.**

End-to-end therefore means: build a riscv64 target libgcc, drop
`MT_COMPILE_ONLY`, and get an *executed* testsuite. That is blocked behind
**#37/#70** (`Makefile.def:196` — one libgcc, primary target only).

Known riscv64 blockers already sized on the board: `lra_assert (mode !=
VOIDmode)` at `lra.cc:192` (432 ICEs, bounding 686 of the debt, and **all 239 of
`gcc.dg/params`**); the `align-2.c`/`align-3.c` assembler operand
`9223372036854841454` = 2^63-6162 (20 results, a wrong-VALUE bug on an alignment
computation); and the `gcc.target/riscv` scan-assembler residual (1,111 results
that compile and emit *different* code than stock — the largest wrong-code
population on the board and the one no current instrument can see).

**Next agent's first move:** build a riscv64 target libgcc. Everything about
execution is behind it, and it is the same gap as #37.

### #174 — `configure.ac:1621` sources `config.gcc` with `${target}` — **the line is STILL THERE, but the concern is largely ADDRESSED; and `STATE.md`'s #174 is a different subject**

Verbatim at head:

```
gcc/configure.ac:~1615  # Canonicalise ${target} before config.gcc dispatches on it.
                        target_canon=`${srcdir}/../config.sub ${target} ...`
gcc/configure.ac:1621   . ${srcdir}/config.gcc || exit 1
```

**But it is no longer the only pass.** Immediately below (1624-1665),
`--enable-backends` builds `gcc_extra_targets` and
`gcc_manifest_targets="${gcc_extra_targets} ${target}"`, then
`. ${srcdir}/gen-target-manifest.sh` runs a per-target loop
(`gcc/gen-target-manifest.sh:118 target=${gcc_mt}` / `:128 . ${srcdir}/config.gcc`).
That script's own comment at `:39` names line 1621 as *"the single-target
`. ${srcdir}/config.gcc` above it"*.

**The live residue is three named call-outs** — `gen-target-manifest.sh:162`,
`:184`, `:210` — where a value still comes from the ONE legacy `${target}` pass.
Those three, not line 1621, are the item. They are the upstream end of the
chain in §0(c) and of #192.

Numbering conflict confirmed: `STATE.md` ~14423 and
`scratchpad/T174-EXTRACT-INSN-CAUSE.md` are about **mode ordinals /
`extract_insn` / `HAVE_nop`** — a different subject entirely. **Do not merge.**

### #175 — pass-name vocabulary — **numbering conflict; local `#175` is DONE and different. The real question is partly handled, with ONE named live collision**

`scratchpad/T175-GEN-NOP.md` is `#175` locally and is **`gen_nop`**, not pass
names — *"the fix was already in the tree"*: `a626931d29b` landed `gen_blockage`,
`gen_nop`, `gen_speculation_barrier` together
(`gcc/multi-target-select.cc:967` forwarder,
`gcc/multi-target-md-entry.h:44` slot). `scratchpad/T175-board.txt` is a
two-target scoreboard, not a pass-name union.

On the actual pass-name question: a per-base pass **file** channel exists —
`gcc/Makefile.in:1527` `$(MT_PASSES_DEFS)` is *"EVERY configured back end's
`<cpu>-passes.def`"*, `:1532` calls it *"the channel that replaces
`$(PASSES_EXTRA)`"*, and `:4412-4440` explains the `pass-instances.def`
redirection. A union of pass **names** with collision handling does not exist,
and `gcc/Makefile.in:1830` and `:1881` record the concrete instance:
**`make_pass_insert_bti` is named by BOTH `arm-passes.def` and
`aarch64-passes.def`**, and the double-registration/rename interaction is called
out there as a defect.

This is `shared-numbering-many-authorities` again — one name, two back ends,
links cleanly, means different things.

**Next agent's first move:** `gcc/Makefile.in:1830` and `:1881` —
resolve `make_pass_insert_bti`. It is the one concrete, named instance.

### #192 — `use_gcc_stdint` grain — **STILL LIVE. Produced per target, consumed one-for-all**

Producer is per-target: `gcc/config.gcc:126` documents it, `:247`
`use_gcc_stdint=none` is the default, and **30+ per-target arms** set it
(`wrap` at `:410, 885, 906, 957, 1011, 1059, 1107, 1111, 1118, 1128, 1265, 1351,
1459, 1670, 1820, 1846, 1852, 1860, 1896, 2251, 2331, 2352`; `provide` at
`:1156, 1227, 1268, 2065`).

Consumer is single and global — **exactly 4 hits**:

```
git grep -n 'use_gcc_stdint\|USE_GCC_STDINT' -- gcc/Makefile.in gcc/configure.ac target-specs/
-> gcc/configure.ac:3181  AC_SUBST(use_gcc_stdint)
   gcc/Makefile.in:1064   USE_GCC_STDINT = @use_gcc_stdint@
   gcc/Makefile.in:5926   if [ $(USE_GCC_STDINT) = wrap ] ...
   gcc/Makefile.in:5932   ... elif = provide

target-specs/ hits: 0
POSITIVE CONTROL: grep -c 'sjlj_exceptions' target-specs/configure.ac  -> non-zero
```

The positive control matters: a 0 over `target-specs/` could have meant the
search does not resolve targ_caps-style names, and it does.

It is **not** a targ_caps key and **not** a per-base header. The answer is a
plain `@...@` substitution carrying whatever the one legacy `${target}` pass
produced, so **in a 47-base build 46 bases get the primary's `stdint.h`
policy.** Same root as #174 and §0(c).

**Next agent's first move:** capture `use_gcc_stdint` in
`gen-target-manifest.sh`'s per-target loop; `gcc/Makefile.in:5926` is the single
rule that must become per-base.

---

## RECOMMENDED CLOSE LIST — ranked

| # | item | why |
|---|---|---|
| 1 | **#101** fixincludes per target | Done. `gcc/` runs no fixincludes; `mkheaders.in:34,41,112` takes `--target` and fails by name without it. |
| 2 | **#94** cppdefault re-check | Done. All 11 cppdefault keys read `targ_caps`; the 21-entry "nothing emits it" list is empty (`check-target-caps.sh:726-731`). |
| 3 | **#80** guard exists, verification owed | Done and discharged here: on `start.encap` (`Makefile.in:3378`), green on 2 real config files, red on injection, and it says SKIP rather than passing over an empty corpus. |
| 4 | **#15** unverified `targ_caps` conversions | Done. Exemption table down to one `optout`. Residual is exactly one run-time arm (ia64 `as_ltoffx_ldxmov_relocs`) — re-file as a one-line item, do not keep #15 open for it. |
| 5 | **#34** cc1gm2 include chain | Done. `gcc-consolidation.h` uses `MT_HEADER (tm.h)` / `(options.h)` / `multi-target-macros.h`. |
| 6 | **#70** libgcc re-scoped | Done; the inversion is gone across 7 named commits. The per-target-libgcc gap is #37, not this. |
| 7 | **#35** 1137 divergent macros | Refuted — the figure has no source. Fold into #32/#169, which have instruments. |
| 8 | **#169** guard census | Census complete (430/690, 20 LOUD vs 363 SILENT). Keep the tables; the consequences are #32/#167/class (c). |
| 9 | **#168** triple map | Complete (36/46 link, 10 blocked, 6 causes). Leave ONE follow-up: `backends-47.txt` is one line short of its own stated 48. |
| 10 | **#89** 32-line stderr floor | Upstream noise (`genoutput.cc:843` + `move-if-change`), already documented with composition in PRINCIPLES §6. Nothing to fix that §2a permits. |
| 11 | **#120** two sjlj `#if` consumers | **Duplicate of #100.** Close one number, keep #100. |
| 12 | **#18** nest per-arch capability fields | Won't-do until #39 (upstreaming) actually starts; churns the key vocabulary and both checkers for no behavioural gain. |
| 13 | **#159** both switches inert | Close unless the pair is named — the likeliest reading (the sjlj pair) is refuted, both are live consumers. |
| 14 | **#44** 45 deleted `AC_ARG_*` warn | De-prioritise to closed-ish: autoconf already warns generically (`configure:1432`); this is UX, not correctness. Correct figures: 54 deleted / 46 orphaned. |

Also **restate rather than close**: `#141` (four -> **five** headers), `#160`
(confirmed five; census half done), `#182` (43 -> **45** sites).

## RECOMMENDED RE-PRIORITISE LIST — ranked

1. **#185 `AARCH64_APPROX_MODE` UB** — a live shift-by-219 on a `uint64_t`,
   masked only by luck (every in-tree value is 0 or ~0), getting worse with every
   base added, and it is cause B of #182. **The cheapest build-dependent
   measurement on the entire list**: it needs the generated `insn-modes.h`, not a
   `cc1`.
2. **The six-item single mechanism (§0(c)): #69, #26, #21, #192, #100, #25** —
   one design ("what carries a per-base answer to a `#if` line, and what replaces
   the single-`${target}` `tmake_file`?"), six items closed by it. #26 has a
   currently-firing silent defect (`TOOL_INCLUDE_DIR` undefined, two `#ifdef`
   arms dead) that should be fixed first regardless of the design.
3. **#140 class (c) — R1's three macros** — `UNITS_PER_WORD`, `POINTER_SIZE`,
   `BIGGEST_ALIGNMENT` in the `Pmode` shape. The costing is already done, so no
   new measurement is owed; ~1 of 91 landed.
4. **#68 re-scoped to its 18 middle-end files** — the "-> 0 over 87 hits
   including testsuite plugins" bar is unpassable as written and is why the item
   has not moved. Split into four classes and schedule only the middle-end one.
5. **#37 / #172 per-target target-libraries** — `target-specs` is 1 of 26
   `target_modules` using the per-target machinery. Every execution result on the
   board is blocked behind a per-target libgcc, riscv64 included.

Behind those: **#167** (14 definers, primary decides for all, and it is NOT the
board's `final_scan_insn_1`), **#175**'s `make_pass_insert_bti` collision,
**#143**'s `-march=native` scope decision, **#96**'s accel-axis question, and
**#39** split into its two real tasks.

**#90 and #95 cannot be scheduled until their bodies are restated** (§0(b)).
