# Why things left `gcc/configure.ac`

BRANCH-LOCAL.  This file is scaffolding for the multi-target work and is not
meant to reach upstream in this form: at submission the findings belong in
commit messages and in the GCC internals manual, and the pointers in
configure.ac go with them.  It is tracked rather than left in a scratch
directory only so that the `Why:` references in configure.ac resolve.

Every `dnl` block that the agents working on the multi-target branch wrote into
`gcc/configure.ac`, moved here.

## What this file is for, and what it is not

`gcc/configure.ac` went from 7,982 lines to about 4,300 by moving target
questions out of it.  Each removal was explained in place, in a `dnl` comment,
and the explanations accumulated: by the end roughly 1,300 of the file's lines
were prose about probes **that were no longer in it**.  Comments had risen 58%
while code fell 59%.

A comment explaining code that is present is documentation.  A comment
explaining code that is absent is archaeology, and it belongs where the
archaeology is kept, not in the file a maintainer reads to understand what the
script does today.

So the rule applied was:

1. explains something **still in `configure.ac`** -> stayed there
2. explains something now in **`target-specs/configure.ac`** -> belongs beside
   that probe
3. purely *"this used to be here"* -> **here**

What is left in `configure.ac` is a short pointer per site: what the code does
now, and a reference into this file.

## Read this before deleting anything here

These are not changelog entries.  A large fraction of them record a **finding**
-- a failure that was observed, diagnosed, and is invisible from the diff:

- deleting the `.hidden` probe made `crtstuff.c` and five other libgcc sources
  silently stop emitting `.hidden` for `__dso_handle`, `__EH_FRAME_BEGIN__` and
  `__TMC_END__`, changing linkage and interposition -- and **`make all-gcc`
  cannot see it, because it never builds libgcc**
- removing one mips probe left `MIPS_EXPLICIT_RELOCS` undeclared in *generated*
  code, naming a macro no source file mentions, so no mips target could build
  at all -- while the JALR probe beside it silently answered "no" on every
  toolchain, because it read a shell variable that was now unset

"The probe moved to target-specs" is a pointer and is disposable.  The two
paragraphs above are the reason anyone keeps a file like this.

## The single sentence the whole campaign reduces to

> The question is not "is this per-target".  It is: **is this a fact about a
> tool or an installation gcc will use at compile time, rather than about the
> machine gcc itself runs on?**

The triple is how a toolchain is *located*; it is not what *determines* the
answer.  Per-target was always a proxy for per-toolchain, which is why these
answers go stale when `-fuse-ld=lld` or a binutils upgrade changes the
toolchain without changing the triple.

---

# The notes, in the order they stood in the file

Line numbers are the position each block occupied immediately before it was
moved out (`a01c1fcc808`), and the code shown under each heading is what the
block sat above -- that is how to find the site now.

### configure.ac:121

Sat immediately above:

```
# Specify the local prefix
local_prefix=
AC_ARG_WITH(local-prefix,
...
AC_ARG_WITH([native-system-header-dir],
```

`--with-local-prefix` and `--with-native-system-header-dir` are gone from
`gcc/configure.ac`, together with `configured_native_system_header_dir` and
`AC_SUBST(local_prefix)`.

Each named an include SEARCH PATH -- `/usr/local/include` and `/usr/include` --
into the installation this compiler compiles *against*.  Same class as
`configure.ac:171` above, same consumer, same channel: a fact about the
toolchain gcc has been pointed at, not about the machine gcc runs on.

**`config.gcc` states the case for this one out loud.**
`native_system_header_dir` is a `case $target` there: `/usr/include` for most
targets, `/include` for cygwin and vxworks, `/mingw/include` for mingw,
`/dev/env/DJDIR/include` for djgpp.  One triple, chosen when gcc was
configured, decided the question for all 188 -- the standing shape.

They are now the `local_include_dir`, `native_system_header_dir` and
`native_system_header_component` keys of the per-target config file, read into
`targ_caps` and applied by `cppdefault.cc`.

**Why the pair had to move together, and it is not the reason the C++ pair
had.**  `cppdefault.cc` `#undef`s BOTH macros under
`CROSS_DIRECTORY_STRUCTURE && !TARGET_SYSTEM_ROOT`.  That `#undef` *is* the
per-target decision "this target has no such directory", taken from the
privileged target's `tm.h`; converting one of the two would have left it
covering a macro that no longer exists and a capability that does, and no
compiler would have complained.  `NATIVE_SYSTEM_HEADER_COMPONENT` had to travel
with `NATIVE_SYSTEM_HEADER_DIR` for the same reason -- it is the `component`
field of the *same two entries*, so a compiler that took the directory from one
target and the component from another would relocate that directory under the
wrong prefix in `update_path`.

**The default is NULL here, not a string, and that is the one real difference
from `configure.ac:171`.**  The `gxx_*` capabilities take their built-in
default in `target-caps.cc` from `PREPROCESSOR_DEFINES`.  These three cannot:
`LOCAL_INCLUDE_DIR` and `NATIVE_SYSTEM_HEADER_DIR` are subject to the `#undef`
above, and `NATIVE_SYSTEM_HEADER_COMPONENT` comes from `tm.h`, which
`target-caps.cc` does not include and must not (it is in `libcommon.a`, which
`collect2` links).  So `targ_caps` holds NULL for "the config file said
nothing" and `cppdefault.cc` -- where `tm.h` and the `#undef` are both visible
-- supplies the compile-time answer.  `""` remains the third state and means
"no such directory": the entry is compacted out rather than searched as `""`.

Consequence for whoever writes the keys: **suppressing `/usr/include` requires
emitting an EMPTY key.**  Omitting the key leaves the built-in default in
place, which is the opposite of what was asked, and is silent.

**`CROSS_DIRECTORY_STRUCTURE` was NOT decided here.**  `gcc/configure.ac` sets
`CROSS=` unconditionally, so the macro is never defined and that `#if` takes its
`#else` arm on every build -- the `#undef CROSS_INCLUDE_DIR` arm -- which is why
this change is behaviour-neutral by construction on anything buildable here.
Whether `CROSS_DIRECTORY_STRUCTURE` should come back is a deferred user
decision that three separate queue items now sit behind, and nothing in this
change touches it.

**What did not move.**  `NATIVE_SYSTEM_HEADER_DIR` is still `AC_SUBST`ed: it is
the compile-time default above, and separately it is `SYSTEM_HEADER_DIR`, i.e.
which headers *fixincludes* fixes during this build.  That second use really is
about the machine being built on.  `local_prefix` is still a `gcc/Makefile.in`
variable, now the literal `/usr/local` rather than a substitution, because it
is handed to the target libraries and is the default of `local_include_dir`.
`fixincludes/configure.ac` keeps its own `--with-local-prefix`, which is a host
question and stays.

**Two other readers of these macros are deliberately left on the compile-time
value**, and both are unchanged rather than half-converted:
`gcc/gcc.cc:11677` builds the Fortran `finclude` prefix by *string-pasting*
`NATIVE_SYSTEM_HEADER_DIR "/finclude/"`, and the driver does not call
`read_target_caps` at all -- only `cc1` does -- so a key there would read as
its default and mean nothing.  `gcc/m2/gm2-lang.cc:611,619` uses both macros
under `#ifdef`; `cc1gm2` *does* read the config file, so that one is a genuine
second reader that will now disagree with `cppdefault.cc` when a target sets
the keys.  It is left because it cannot be built or tested here, and it is
recorded so it is not mistaken for done.

### configure.ac:171

Sat immediately above:

```
AC_ARG_WITH(gxx-include-dir,
...
AC_ARG_WITH(gxx-libcxx-include-dir,
```

`--with-gxx-include-dir` and `--with-gxx-libcxx-include-dir` are gone from
`gcc/configure.ac`, together with `gcc_gxx_include_dir_add_sysroot` and
`gcc_gxx_libcxx_include_dir_add_sysroot` and their four `AC_SUBST`s.

Each named an include SEARCH PATH -- a fact about the libstdc++ or libc++
INSTALLATION this compiler will be compiling against, not about the machine
gcc itself runs on.  The triple is how such an installation is *located*; it
is not what *determines* the answer, and one build-time string cannot serve
188 targets.  Both interpolated `--with-sysroot`, which is per target, which
is the symptom that made this visible.

They are now the `gxx_include_dir`, `gxx_tool_include_dir`,
`gxx_backward_include_dir` and `gxx_libcxx_include_dir` keys of the per-target
config file, read into `targ_caps` and applied by `cppdefault.cc`.

**The channel is targ_caps and NOT a named spec, and that is forced rather
than chosen.**  `cppdefault.cc` is linked into `cc1`, and `cc1` never sees a
spec file -- the include chain is built inside the compiler proper, after
`read_target_caps`.  This is the same boundary that put the 92 probe macros
into a runtime config file instead of the specs channel.

**`cpp_include_defaults` had to stop being an array.**  Four of its entries now
read `targ_caps`, and a namespace-scope array is dynamically initialised at
load time -- *before* `cc1` opens the target config file.  It would have
captured the built-in fallbacks and no `-ftarget-config=` would ever have
changed the include path, silently and on every target.  It is now
`cpp_include_defaults_table ()`, whose function-local static is initialised on
first call; the header keeps a macro of the old name so that the four existing
`for (p = cpp_include_defaults; p->fname; p++)` loops (`incpath.cc` twice,
`d/d-incpath.cc`, `m2/gm2-lang.cc`) are unchanged AND cannot reach the table
without going through the initialisation.

The `struct default_include` members lost their `const` qualifiers for the
same reason: the table is compacted in place, dropping entries whose directory
the target config left empty.  `""` is a legitimate capability value meaning
"this target has no such directory", and letting it through would have added
the *current working directory* to every system include search -- a silent
wrong answer where a missing one was wanted.

**The `_add_sysroot` pair was deliberately NOT transcribed.**  `gcc` has no
`--with-sysroot` at all any more, so both variables were unconditionally `0`
here with no remaining code path able to set them: a computation whose every
answer is a constant.  Transcribing that faithfully into the new home is the
dead-code mistake this campaign keeps finding, so the two `-D...ADD_SYSROOT`
flags in `gcc/Makefile.in` are now literal `0`, kept only because
`config/linux.h` (musl), `openbsd.h` and `rs6000/sysv4.h` build
`INCLUDE_DEFAULTS` out of them.  When `target-specs` can genuinely probe a
per-target sysroot, that is a NEW `targ_caps` field, not a revival of this one.

**What did not move, and why.**  The installation-relative defaults --
`$(libsubdir)/$(libsubdir_to_prefix)include/c++/$(version)` and its
`include/c++/v1` sibling -- stay in `gcc/Makefile.in`, where they were already
expressed.  That part is about `--prefix` and `--libdir`, which autoconf owns,
and it must go on matching
`libstdc++-v3/acinclude.m4:GLIBCXX_EXPORT_INSTALL_INFO`.  `target-caps.o` is
compiled with `PREPROCESSOR_DEFINES` so that the built-in default of each
capability *is* that string rather than a second copy of it that has to be
kept in step.

**Left alone on purpose:** the target headers that supply their own
`INCLUDE_DEFAULTS` (`config/linux.h` under musl only -- the enclosing
`#if DEFAULT_LIBC == LIBC_MUSL` is why a normal glibc build never reaches it,
`openbsd.h`, `netbsd.h`, `rs6000/sysv4.h`).  Those state a per-target answer in
a per-target header, and `netbsd.h` hard-codes `/usr/include/g++`; rerouting
them through `targ_caps` would change that on a build nobody here can test.
Getting `INCLUDE_DEFAULTS` itself out of the privileged target's `tm.h` is a
separate job, and `TOOL_INCLUDE_DIR`/`CROSS_INCLUDE_DIR`/
`NATIVE_SYSTEM_HEADER_DIR` -- which have exactly the same defect and no key
yet -- belong to it.

**Why the pair had to move together.**  `--with-gxx-libcxx-include-dir=no`
disabled the `-stdlib` option and unset enabled it, so half a conversion would
have given a compiler offering `-stdlib` while pointing at a path that was
never configured.  It turned out not to be a coupling at all once looked at:
`-stdlib=` is enabled unconditionally on this branch already (see
`configure.ac:227` above), because `Condition(ENABLE_STDLIB_OPTION)` decides
whether the option EXISTS at `options.cc` compile time rather than what it
defaults to.  So the directory moved and the option's existence stayed, and
the `AC_DEFINE_UNQUOTED` of a variable that could only be `1` became a plain
`AC_DEFINE ... 1`.

### configure.ac:227

Sat immediately above:

```
      gcc_enable_stdlib_opt=1
    fi
    AC_DEFINE_UNQUOTED(ENABLE_STDLIB_OPTION, $gcc_enable_stdlib_opt,
```

A `case $target' turned -stdlib= on by default for Darwin 11 and later,
on the grounds that those releases default to libc++.  That is a statement
about a target, made before any target is chosen, and in a compiler
serving 183 of them it decided the question for all of them from one
triple.

It is NOT replaced by a target-specs probe, because the consumer cannot
take a runtime answer: c-family/c.opt:2882 carries
`Condition(ENABLE_STDLIB_OPTION)' on -stdlib=, which the option machinery
resolves when options.cc is COMPILED -- it decides whether the option
EXISTS, not what it defaults to.  So the option is enabled
unconditionally: a target whose C++ runtime has no libc++ then has
nothing to select with it, which is a rejected argument rather than a
silently wrong default, and that is the direction to fail in.

### configure.ac:571

Sat immediately above:

```
    GCC_TARGET_TEMPLATE([HAVE_LD_RO_RW_SECTION_MIXING])
    AC_DEFINE(HAVE_LD_RO_RW_SECTION_MIXING, 1,
      [Define if your linker links a mix of read-only
```

Two assembler/linker capabilities that the target libraries read, and that
therefore cannot be runtime values.  libgcc compiles with USED_FOR_TARGET,
which is exactly the case defaults.h guards its targ_caps redefinitions out
of -- deliberately, since target-library code cannot reach targ_caps at all
-- so for those TUs auto-host.h is the only source.  When the probes were
deleted the macros became undefined there, and crtstuff.c (7 sites),
libgcc2.c, libgcov.h, offloadstuff.c and the visium and stormy16
lib2funcs.c silently stopped emitting `.hidden' for __dso_handle,
__EH_FRAME_BEGIN__ and __TMC_END__, making them globally visible.  That is a
linkage and interposition change, and `make all-gcc' cannot see it because
it never builds libgcc.

Defined unconditionally rather than probed.  Restoring the probe is not an
option -- removing it is the point -- and there is no runtime alternative on
this side, so the choice is between 1 and 0.  1 is what a stock build's
auto-host.h contains on every supported host, so it preserves behaviour
exactly; 0 would silently change it everywhere.  GCC_TARGET_TEMPLATE lifts
the `#ifndef USED_FOR_TARGET' guard that would otherwise keep them out of
the target-library build.  The compiler proper still gets the runtime value:
defaults.h #undefs both and redefines them in terms of targ_caps.
HAVE_GAS_HIDDEN is gone from here entirely.  The compiler proper reads
targ_caps.gas_hidden (defaults.h), so this AC_DEFINE existed for exactly one
reason: to push a value across GCC_TARGET_TEMPLATE into libgcc, which had no
probe of its own.  libgcc/configure.ac now has one -- and a better one, since
it runs the assembler that will actually assemble libgcc's objects.
Consumers were libgcc's crtstuff.c, libgcc2.c, libgcov.h, offloadstuff.c and
the visium and stormy16 lib2funcs; none in gcc/.

### configure.ac:737

Sat immediately above:

```
    
    dnl with_cpu/with_float were AC_SUBSTed only to build the multiarch name for
    dnl soft-float/hard-float ABIs.  Multiarch is gone (see above) and so are the
```

--enable-multiarch selected the Debian-style multiarch library layout.
MULTIARCH_DIRNAME is a target path convention, so ENABLE_MULTIARCH is now
a target-header macro; config/mips/mips.h already tests it with `#ifndef',
and no target header raises it, which reproduces the stock default (the
option defaulted to `auto', and only an explicit --enable-multiarch ever
produced the AC_DEFINE).

The make-side residue is gone too: Makefile.in no longer defines
enable_multiarch and if_multiarch now expands to nothing, so the
BUILD_SYSTEM_HEADER_DIR crti.o wildcard probe that used to guess the
target's path convention from the build machine is gone with it.

### configure.ac:749

Sat immediately above:

```
    
    # needed for restricting the fixedincludes multilibs that we install
    AC_SUBST(with_multi_buildlist)
```

with_cpu/with_float were AC_SUBSTed only to build the multiarch name for
soft-float/hard-float ABIs.  Multiarch is gone (see above) and so are the
options themselves, so nothing is left to substitute.

### configure.ac:758

Sat immediately above:

```
    AC_DEFINE(DEFAULT_STK_CLASH_GUARD_SIZE, 0,
    	[Define to larger than zero set the default stack clash protector size.])
    
```

--with-stack-clash-protection-guard-size is gone.  It set one guard size for
whichever target the compiler was built for, and the back ends that read it
(aarch64, i386, powerpc, s390) each have their own idea of what is valid.
Zero was its default and means "use the back end's own default", so nothing
changes for a build that did not pass it; a build that did should say
-fstack-clash-protection with --param stack-clash-protection-guard-size
instead, which is per compilation rather than per compiler.

### configure.ac:799

Sat immediately above:

```
    
    
    dnl --enable-threads is gone.  It picked one thread package for one target and
```

--enable-decimal-float is gone, and with it GCC_AC_ENABLE_DECIMAL_FLOAT.
That macro was a `case $target' naming the CPU/OS pairs whose libgcc carries
the decimal support functions, with a fall-through arm that warned and said
no -- so with no $target it would have quietly disabled decimal float for
every target at once, which is the fall-through hazard this project keeps
running into.

Both halves of the answer are per target: whether decimal float is usable at
all, and whether the ABI encodes it as BID or DPD.  gcc/config.gcc derives
them from the triple (the same list, kept diff-able against ../config/dfp.m4,
which libgcc and libdecnumber still use for their own per-target builds) and
they reach cc1 at run time as targ_caps.decimal_float and
targ_caps.decimal_bid_format.

### configure.ac:814

Sat immediately above:

```
    enable_threads=''
    
    dnl --enable-tls is gone.  It was not a feature switch: it OVERRODE the
```

--enable-threads is gone.  It picked one thread package for one target and
froze it in as thread_model[[]] and gthr-default.h -- one of a set of
mutually exclusive target choices.  Every arm of config.gcc reads an empty
value as "this target's own default" (posix on GNU/Linux, rtems on RTEMS,
and so on), which is what a build that did not pass the option had, so the
thread model each target gets is unchanged.

### configure.ac:822

Sat immediately above:

```
    
    dnl --enable-vtable-verify selected whether libvtv is available to link against.
    dnl That is a target runtime library question, so ENABLE_VTABLE_VERIFY is now a
```

--enable-tls is gone.  It was not a feature switch: it OVERRODE the
assembler TLS probe, forcing a yes or no answer about a specific as.  The
probe it overrode is gone too (HAVE_AS_TLS is a build-time constant now),
so the variable had no remaining consumer and is removed with it.

### configure.ac:827

Sat immediately above:

```
    
    AC_ARG_ENABLE(analyzer,
    [AS_HELP_STRING([--disable-analyzer],
```

--enable-vtable-verify selected whether libvtv is available to link against.
That is a target runtime library question, so ENABLE_VTABLE_VERIFY is now a
target-header macro with a 0 default in defaults.h -- the same answer the
option gave by default.  config/sol2.h already tests it with `#if'.

### configure.ac:844

Sat immediately above:

```
    dwarf2=no
    
    AC_ARG_ENABLE(shared,
```

--with-dwarf2 is gone.  It appended tm-dwarf2.h to ONE tm_file, forcing the
default debug format for whichever target the compiler was built for.  Its
default was no, so nothing changes for a build that did not pass it, and the
targets that genuinely want it -- i386/nto, and the two nvptx/gcn arms --
already name tm-dwarf2.h in config.gcc themselves.  A target that wants
DWARF by default should say so there, per target, not here.

### configure.ac:871

Sat immediately above:

```
    enable_gcov=yes
    AC_SUBST(enable_gcov)
    
```

Whether to build libgcov and the related host tools.  This used to be
selectable with --disable-gcov, whose default was keyed on $target
(bpf-*-* opted out).  A multi-target compiler cannot answer that at
configure time, so the host tools are always built.

### configure.ac:878

Sat immediately above:

```
    CONFIGURE_SPECS=
    AC_SUBST(CONFIGURE_SPECS)
    
```

--with-specs is gone.  It froze a spec string into the driver as
CONFIGURE_SPECS, one of driver_self_specs[[]] -- a spec that could not be
overridden or even seen, since -dumpspecs does not show driver self specs.
Specs belong in a spec file, which is the whole point of the exercise, and
an empty CONFIGURE_SPECS is what every build that did not pass it had.

### configure.ac:958

Sat immediately above:

```
    AC_SUBST(enable_as_accelerator)
    AC_SUBST(real_target_noncanonical)
    AC_SUBST(accel_dir_suffix)
```

--enable-as-accelerator-for is gone.  It was never declared with
AC_ARG_ENABLE, so it never appeared in "configure --help"; it named ONE
host target that this compiler was to be the offload compiler for, and
rewrote the program names and the library subdirectory around it.  Picking
one target out of the set a multi-target compiler serves is exactly the
thing being removed, and it was built out of target_noncanonical, which no
longer exists.  enable_as_accelerator, accel_dir_suffix and real_target_noncanonical
stay AC_SUBSTed, empty: that is the ordinary non-accelerator build, which is
what every native configuration already got.

### configure.ac:971

Sat immediately above:

```
    AC_SUBST(omp_device_properties)
    AC_SUBST(omp_device_property_deps)
    
```

--enable-offload-targets is gone with the same reasoning: another undeclared
option, naming a fixed list of other targets to offload to and freezing it
into OFFLOAD_TARGETS.  Which targets a compiler can offload to is a property
of the configured target set, not a separate build-time list, and
the value left here -- no offload targets -- is what a plain native build
always produced.

### configure.ac:988

Sat immediately above:

```
    with_multilib_list=default
    with_multilib_generator=default
    
```

--with-multilib-list and --with-multilib-generator are gone.  They named the
multilib set for ONE target, and a compiler serving several has several
multilib sets; which libraries exist for a target is that target's own
configuration, not a property of the compiler binary.  `default' is what
every arm of config.gcc treats as "use this target's own set", and it is what
a build that did not pass either option always had, so behaviour is
unchanged.  (config.gcc sets the same two values itself, so that sourcing it
directly agrees with sourcing it from here.)

### configure.ac:999

Sat immediately above:

```
    
    # -------------------------
    # Checks for other programs
```

--with-picolibc is gone.  It turned picolibc support on for a target whose
triple does not say picolibc -- i.e. it named the target C library out of
band, which is precisely what a compiler serving several targets cannot
carry.  config.gcc still recognises a *-picolibc-* triple, which is the
half that is the target's own business.

### configure.ac:1439

Sat immediately above:

```
    AC_MSG_CHECKING([for gmp.h, which system.h needs and every probe below depends on])
    AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <gmp.h>]], [[]])],
      [AC_MSG_RESULT([yes])],
```

Every probe from here to the end of this block compiles a program that
includes "system.h", which reaches gmp.h through $GMPINC.  Autoconf records
a compile that fails for ANY reason as "the feature is absent" -- a missing
gmp.h counts the same as a genuinely undeclared function.  So an environment
without those headers does not fail here; it quietly answers "no" about
fifty times.  Every HAVE_DECL_* below goes to 0, and the rlim_t probe writes

    #define rlim_t long

into auto-host.h over the real glibc typedef.  The build then dies in every
object with "declaration does not declare anything", pointing at everything
except the cause.  It has cost several people an hour each, and because there
is no cache variable it happens again on every configure.

None of that is preventable by care in the source: the wrong answer comes
from the environment.  What is preventable is its being silent.  Assert the
precondition once, here, where CFLAGS and GMPINC are already set to exactly
what the probes will use.
Assert gmp.h specifically rather than system.h as a whole.  A bare
`#include "ansidecl.h"' plus `#include "system.h"' does NOT compile on glibc
and is not meant to: libiberty.h declares char *basename(const char *) while
glibc's string.h declares the C++ overload const char *basename(const char *),
and g++ rejects the pair as ambiguating.  That is precisely why the first
probe below carries its own `#define HAVE_DECL_BASENAME 1' prologue.  So a
plain system.h compile is not a precondition of this block, and asserting it
would fail every glibc build -- which is what the first version of this check
did.  system.h:718 is the line that actually depends on the environment.

### configure.ac:1821

Sat immediately above:

```
    if test x"${gcc_extra_targets}" = x; then
      AC_MSG_ERROR([--enable-targets=LIST is required])
    fi
```

--enable-targets names every target, and there is no other source for the
list: there is no falling back on --target when the list is empty, because
a fallback would make --target mean "the target" again, which is the thing
being removed.

### configure.ac:1829

Sat immediately above:

```
    gcc_manifest_targets="${gcc_extra_targets} ${target}"
    
    gcc_all_common_objects=
```

`${target}' IS added to the manifest, and that is not the fallback refused
above.  It is not a default and confers no privilege: since the compiler
now starts with an EMPTY common hook table (common/common-target-select.cc)
and installs one only when something selects a target by name, an entry in
this list is just an entry -- being first, or being the build's own triple,
buys nothing at run time.

What it buys is a link that works.  `${target}' still picks out_file, tm.h
and md_file, so THAT back end's <cpu>.cc is compiled into cc1 whatever
--enable-targets says, and it refers to symbols in its own
common/config/<cpu>/<cpu>-common.cc -- processor_alias_table, pta_size,
processor_names, num_arch_names, ix86_handle_option for i386.  Only the
manifest emits a rule building that object.  So a list that did not name
the build's own triple produced a cc1 and an lto1 that would not link, for
a target nobody had asked for; --enable-targets=all merely hid it by
happening to name i386.  The compiled-in back end has to be in the list
because it is compiled in, not because it is anyone's default.

Duplicates are removed by the canonicalisation loop below, not here: the
user writes `x86_64-linux-gnu' and ${target} is `x86_64-pc-linux-gnu', so
the two spellings only become comparable after config.sub has seen them.

### configure.ac:2860

Sat immediately above:

```
    if test "x$with_build_sysroot" != x; then
      BUILD_SYSTEM_HEADER_DIR=$with_build_sysroot'$${sysroot_headers_suffix}$(NATIVE_SYSTEM_HEADER_DIR)'
    fi
```

target_header_dir is GONE.  It was how the target's sysroot reached this
script, and the compiler must not care about target sysroots.

Every one of its consumers has now been moved out, and not one of them was
the compiler's own question:
  glibc version                 -> targ_caps.glibc_major/minor
  TARGET_LIBC_PROVIDES_HWCAP_IN_TCB, TARGET_LIBC_GNUSTACK -> targ_caps
  HAVE_SYS_SDT_H                -> libgcc/configure.ac  (AC_CHECK_HEADERS)
  TARGET_DL_ITERATE_PHDR        -> libgcc/configure.ac  (keyed on $host)
  inhibit_libc                  -> decided from gcc's own options; the
                                   "are the headers really there" half is
                                   libgcc's, which can just compile a test

BUILD_SYSTEM_HEADER_DIR stays: fixincludes genuinely does have a directory
of headers to fix, and it is named, not guessed at.

### configure.ac:2879

Sat immediately above:

```
    AC_ARG_WITH(fixincludes-machine,
    [AS_HELP_STRING([--with-fixincludes-machine=MACHINE],
                    [machine name whose system headers fixincludes should fix;
```

The machine whose system headers fixincludes is fixing.

This is NOT the compiler's target -- gcc/ no longer has one -- it is a
property of BUILD_SYSTEM_HEADER_DIR, i.e. of the header tree being fixed.
With no --with-build-sysroot that tree is the NATIVE one, so the machine it
belongs to is the host.  With a build sysroot the headers are some other
machine's and nothing here can name it; say so rather than guess.

It must never be empty.  fixincl.c:403 turns an empty TARGET_MACHINE into
`pz_machine = NULL', which is its self-test mode: per-machine gating is
switched off entirely and EVERY machine's fixes are applied to whatever
headers it is handed.  A vacuous filter is permissive, not empty.  That is
how config/vxworks' unistd.h wrapper (`#include <ioLib.h>') was written into
a glibc include-fixed and made libgcc unbuildable.  Makefile.in refuses to
run fixincludes when this is empty.

### configure.ac:2911

Sat immediately above:

```
    : ${inhibit_libc=false}
    if test x$with_newlib = xyes && test "x$with_headers" = xno; then
           inhibit_libc=true
```


The second half of the old test -- "--with-headers was given but the
headers are not actually there", which stat'd stdio.h inside the target
sysroot -- is gone along with that sysroot path.  It is libgcc's question
anyway: libgcc has a working compiler and can simply try to include
<stdio.h>, where gcc could only guess at a directory.  What is left here is
the part gcc genuinely knows, which is what its own options said.

These are dnl comments on purpose, so that grepping the GENERATED configure
for the old variable name stays a valid check that it is really gone.

### configure.ac:3141

Sat immediately above:

```
    
    dnl How to give a HOST shared library a version script and an soname.  These
    dnl two belong here and not in target-specs/, and the distinction is the whole
```

The "is gold available as a non-default linker, and does its split-stack
support cover this target" check stood here.  It is REMOVED, and the
replacement is not yet written -- said plainly, because a comment that
claims a hazard is closed when it is only named is worse than no comment.

Both halves of it were about a target: the linker it interrogated is
`$gcc_cv_ld.gold', a target linker, and the version ladder it applied to
the answer was a `case' arm for powerpc64 big- and little-endian, which is
where gold acquired complete split-stack support later than everywhere
else.  So it cannot stay.

It is not a targ_caps capability either.  Its one consumer is
`#ifdef HAVE_GOLD_NON_DEFAULT_SPLIT_STACK' in gcc.cc, and what it selects
is SPEC TEXT, which the driver has before it reads any target config.  The
channel is therefore a named spec written by target-specs, exactly like
*link_eh and *asm_debug -- and until that spec and its slot in gcc.cc both
exist, a probe would be an answer with nowhere to go, which is the thing
this file keeps being caught doing.

What changes meanwhile: the macro is undefined, so gcc.cc takes the arm it
already took on every host without a non-default gold -- which is nearly
all of them.  QUEUED, not done.

### configure.ac:3164

Sat immediately above:

```
    AC_MSG_CHECKING(linker version script option)
    gcc_cv_ld_version_script=no
    ld_version_script_option=''
```

How to give a HOST shared library a version script and an soname.  These
two belong here and not in target-specs/, and the distinction is the whole
reason they are back:

  the library being linked is libgccjit.so / libgdiagnostics.so -- HOST
  objects, linked by $(LLINKER) during this build.  Nothing about a target
  enters into it.  target-specs/ runs AFTER the build and writes spec files,
  so a probe placed there is structurally incapable of reaching a Makefile
  variable the build already needed -- and Makefile.in:1306-1307 still said
  `LD_VERSION_SCRIPT_OPTION = @ld_version_script_option@'.  With nothing
  AC_SUBSTing it, that is not empty, it is LEFT UNSUBSTITUTED, so
  `$(if $(LD_VERSION_SCRIPT_OPTION),...)' tested true and the link line for
  libgdiagnostics.so read
      -Wl,@ld_version_script_option@,.../libgdiagnostics.map
  Measured on a configured Makefile, not inferred.  It has not bitten only
  because --enable-languages=c builds neither library.

Keyed on $host, not $target as upstream had it: it is the host's linker
linking a host library.  That upstream used $target here was already wrong;
it happened to work because the two agree in a native build.

### configure.ac:3197

Sat immediately above:

```
      *-*-solaris2*)
        gcc_cv_ld_version_script=yes
        ld_version_script_option='-M'
```

Solaris 2 ld always supports -M.  It supports a subset of
--version-script since Solaris 11.4, but only under
-z gnu-version-script-compat, so -M stays the one to use.

### configure.ac:3295

Sat immediately above:

```
    
    # Figure out the dsymutil we will use.
    AS_VAR_SET_IF(gcc_cv_dsymutil,, [
```

The objdump, readelf and otool searches are gone.  All three were found,
printed and never used again -- no AC_SUBST, no Makefile variable, no probe
left that consults them.  They are TARGET tools in any case, and
target-specs/configure.ac has its own search for objdump, readelf and nm,
prefixed for the target it is probing.

### configure.ac:3331

Sat immediately above:

```
    
    
    
```

The CFI probe cluster (.cfi_startproc/.cfi_offset/.cfi_escape, working
cfi advance, .cfi_personality, .cfi_sections) and the gcc_fn_eh_frame_ro
helper have moved to target-specs/configure.ac.  Every arm of them was
target knowledge: a case over $target for hppa-hpux, Solaris (which reads
gcc_cv_ld_ro_rw_mix) and Darwin, plus a case over $target_os for PE for
.cfi_sections.  cc1 now reads cfi_personality and cfi_sections from
targ_caps.

### configure.ac:3343

Sat immediately above:

```
    
    dnl Thread-local storage.  gcc/configure.ac used to answer HAVE_AS_TLS with a
    dnl ~400-line parameterized probe: a `case "$target"' supplying a different
```

--enable-newlib-nano-formatted-io mirrored a newlib configure flag so GCC
could gate features on it.  Which newlib variant will be linked is a target
libc property, so HAVE_NEWLIB_NANO_FORMATTED_IO is now a target-header
macro with a 0 default in defaults.h, matching the stock default (the
option was off unless explicitly given).

### configure.ac:3349

Sat immediately above:

```
    AC_DEFINE(HAVE_AS_TLS, 1,
    	  [Define if your assembler and linker support thread-local storage.])
    
```

Thread-local storage.  gcc/configure.ac used to answer HAVE_AS_TLS with a
~400-line parameterized probe: a `case "$target"' supplying a different
conftest_s and tls_as_opt for each of ~20 architectures, then one
gcc_GAS_CHECK_FEATURE over the result, plus a Windows-only linker check for
broken @secrel32 relocations.

HAVE_AS_TLS does NOT become a targ_caps capability, for two reasons:

  - It is read from ~55 insn conditions in config/*/*.md (rs6000, alpha,
    mips, frv, xtensa, loongarch).  Those compile into generated TUs that
    see tm.h but not target-caps.h, so `targ_caps' is not in scope there.
  - It is already a target-header macro.  Eight target headers supply an
    `#ifndef HAVE_AS_TLS / #define HAVE_AS_TLS 0' fallback and the Lynx
    headers #undef it, so simply dropping the define here would silently
    turn TLS off on rs6000, sparc, alpha, mips, frv, xtensa and loongarch.

So it stays a build-time constant, defined unconditionally: every assembler
any supported binutils ships has had TLS for close to two decades.  A target
whose assembler lacks it still says so in its own header, exactly as the
Lynx ports already do.

### configure.ac:3373

Sat immediately above:

```
    
    AC_DEFINE(HAVE_AS_DTPREL_RELOC, 1,
    	[Define if your assembler supports DTPREL relocation.])
```

---------------------------------------------------------------------------
THE TARGET-TOOLCHAIN PROBES THAT USED TO LIVE HERE ARE ALL IN
target-specs/configure.ac NOW.  One sweep, deliberately ahead of wiring the
consumers up, so that the compile failures -- not a static analysis -- are
the work list.  What was in this stretch, in the order it appeared, so that
undoing any one move is a lookup rather than archaeology:

  1. assembler alignment and symbol directives: .balign/.p2align,
     .p2align max-skip, .literal16, .subsection -1, .weak, .weakref,
     .nsubspa comdat, .hidden, .base64, .cv_ucomp.
  2. the `ld --version' parser and the Solaris `GNU ld 2.30 or later'
     requirement, plus gcc_fn_gld_min_version/gcc_fn_gld_elf_min_version,
     which had no callers left.
  3. the loongarch -mno-relax probe that fed check_leb128_asflags.
  4. the .eh_frame optimization probe and USE_AS_TRADITIONAL_FORMAT.
  5. section flags: exclude (`e'/#exclude), SHF_GNU_RETAIN (`R'),
     SHF_LINK_ORDER (`o'), SHF_MERGE.
  6. the gcc_cv_as_comdat_group=yes pin, whose last reader went with (5).
  7. the darwin -mmacosx-version-min and .build_version probes.
  8. the whole `case "$target"' CPU block: alpha explicit/jsrdirect relocs,
     avr --mlink-relax/-mrmw/-mgcc-isr, cris -no-mul-bug-abort, ia64
     ltoffx/ldxmov, the powerpc set (.machine, mfcrf, power10 htm, rel16,
     entry markers, pltseq), msp430 .mspabi_attribute, the loongarch set
     (explicit relocs, call36, eh_frame pcrel, tls le relaxation, 16B
     atomic) and the s390 set (.machine/.machinemode, architecture
     modifiers, both vector alignment hint probes).
  9. the "requires the GNU assembler" check for mips/loongarch/hpux, the
     amdgcn LLVM >= 13.0.1 version gate, and the arm context-specific
     architecture-extension probe.
 10. the DWARF 4 .debug_line cluster keyed on `case $cpu_type'.
 11. .lcomm with alignment.

HAVE_AS_TLS and HAVE_AS_DTPREL_RELOC are NOT in that list.  Both are read
from `#if defined(...)' in generated .md TUs and in aarch64.cc, where
targ_caps is not in scope, so they stay build-time constants -- see the
reasoning kept above HAVE_AS_TLS.
---------------------------------------------------------------------------

### configure.ac:3420

Sat immediately above:

```
    
    dnl --enable-gnu-unique-object and its probe lived here.  The probe assembled
    dnl `.type foo, @gnu_unique_object' using $target_type_format_char from
```

--with-glibc-version is gone, and so is the probe that stood in for it: a
grep for __GLIBC__ in $target_header_dir/features.h, i.e. gcc/configure
opening the target sysroot and freezing what it found into TARGET_GLIBC_MAJOR
and TARGET_GLIBC_MINOR.  The compiler must not care about target sysroots,
and the failure mode was the familiar one: no target headers meant no
answer, so it recorded 0.0 and silently changed behaviour (this is what made
--with-long-double-128 flip an ABI).

The version is now targ_caps.glibc_major/minor, supplied per target through
the target config file; target-specs takes --with-glibc-version.  0.0 still
means unknown, and every consumer tests `>= X.Y' so unknown enables nothing.

### configure.ac:3432

Sat immediately above:

```
    
    dnl The "tolerance to line number 0" probe moved to target-specs.
    
```

--enable-gnu-unique-object and its probe lived here.  The probe assembled
`.type foo, @gnu_unique_object' using $target_type_format_char from
config.gcc and then required glibc >= 2.11 for ld.so support.  Both halves
describe the target, so the decision now lives in the libc target headers
as USE_GNU_UNIQUE_OBJECT (config/linux.h, config/gnu.h), defaulting to 0 in
defaults.h.  config/elfos.h consumes it from inside ASM_DECLARE_OBJECT_NAME.

### configure.ac:3455

Sat immediately above:

```
    
    
    dnl --enable-libssp and the gcc_cv_libc_provides_ssp probe used to decide
```

The ld64 and dsymutil probe blocks that stood here are gone to
target-specs/configure.ac -- as a DELETION, not a transcription, and the
distinction matters for anyone auditing this.

Both were guarded by `if test x"$ld64_flag" = xyes' and
`if test x"$dsymutil_flag" = xyes', and this file sets both variables to
`no' at the top and never to anything else -- the `case $target in *darwin*'
that used to set them went with the target canonicalisation.  So neither
block had run on any target for some time, LD64_HAS_* were undefined
everywhere, and `#if LD64_HAS_DEMANGLE' on an undefined macro is a silent 0.
That is what e1c6eb651c9 fixed, on the consumer side: config/darwin.h now
derives the five LD64_HAS_* from DEF_LD64_MAJOR, and defines them
unconditionally, so an AC_DEFINE here would now be a redefinition of a macro
the target header already owns.

Removing unreachable code is behaviour-neutral by construction, which is why
this one needs no follow-up: every consumer was already taking the floor.
LD64_VERSION keeps its "85.2.1" floor in darwin.h and DSYMUTIL_VERSION its
DET_UNKNOWN floor in darwin.cc, which is exactly what they had yesterday.
The real answers are a question for the ld64 that will actually link, i.e.
for target-specs.

### configure.ac:3478

Sat immediately above:

```
    
    dnl --enable-default-ssp used to AC_DEFINE(ENABLE_DEFAULT_SSP), gated on a
    dnl `case "$target"' that excluded ia64.  ENABLE_DEFAULT_SSP is now purely a
```

--enable-libssp and the gcc_cv_libc_provides_ssp probe used to decide
TARGET_LIBC_PROVIDES_SSP by inspecting the target C library: a
`case "$target"' over musl/linux/gnu/darwin/*bsd plus greps of
$target_header_dir/features.h.  That is a property of the target, so
TARGET_LIBC_PROVIDES_SSP now comes from the target headers
(config/gnu-user.h, config/freebsd.h, config/netbsd.h, config/darwin.h)
with a 0 default in defaults.h.

### configure.ac:3486

Sat immediately above:

```
    
    dnl libatomic_target names the ONE triple this build will have a libatomic for,
    dnl and is empty when there is none.  LINK_LIBATOMIC_SPEC needs it: -latomic is
```

--enable-default-ssp used to AC_DEFINE(ENABLE_DEFAULT_SSP), gated on a
`case "$target"' that excluded ia64.  ENABLE_DEFAULT_SSP is now purely a
target-header knob; defaults.h supplies DEFAULT_FLAG_SSP 0 when no target
header defines it.

### configure.ac:3491

Sat immediately above:

```
    libatomic_target=
    if test -z "${TARGET_CONFIGDIRS+set}"; then
      AC_MSG_NOTICE([TARGET_CONFIGDIRS is not set: assuming no libatomic for ${target}.])
```

libatomic_target names the ONE triple this build will have a libatomic for,
and is empty when there is none.  LINK_LIBATOMIC_SPEC needs it: -latomic is
put on the link line only where the library exists, and `is libatomic in
TARGET_CONFIGDIRS' is the only place that is known.  It cannot be probed by
target-specs/ the way the linker questions are, because at the time those
probes run the library has not been built yet, let alone installed.

It is deliberately a TRIPLE and not a yes/no.  The top level builds target
libraries for ${target} alone, so in a compiler serving 183 targets the
answer is yes for at most one of them; a boolean would have been handed to
every target's spec file and put -latomic on 182 link lines that have no
such library.  ${target} is already canonicalised here (see the top of this
file), so it compares equal to the manifest entry Makefile.in matches it
against.
TARGET_CONFIGDIRS reaches this script only as an ENVIRONMENT VARIABLE
exported by the top-level Makefile (Makefile.tpl:252) when it configures
gcc.  A `config.status --recheck' run by hand does not have it, and the
answer then silently flips to "no libatomic" -- which is how a spec file
that had `--as-needed -latomic --no-as-needed' in it came back empty after
an unrelated re-configure.  Upstream's AC_DEFINE had exactly the same
dependency and exactly the same silence.  Distinguish the two cases and say
which, so a re-configure that loses it leaves a line in the log instead of
quietly changing every link line.

### configure.ac:3527

Sat immediately above:

```
    
    dnl --with-long-double-128 and the probe behind it are gone.  The question --
    dnl does this target.s C library use 128-bit long double -- was answered by
```

The <sys/sdt.h> probe is gone.  Nothing in gcc/ ever read HAVE_SYS_SDT_H:
its only consumers are libgcc/unwind-dw2.c and unwind-arm-common.inc, which
received it through tconfig.h -> auto-host.h.  It describes the target C
library, i.e. libgcc's own host, and gcc answered it by looking inside
$target_header_dir -- a target sysroot a compiler serving many targets has
no business reading.  libgcc/configure.ac now does AC_CHECK_HEADERS(sys/sdt.h),
which spells it the same way, and those two files include auto-target.h.

### configure.ac:3535

Sat immediately above:

```
    
    dnl --with-long-double-format is gone.  It picked one of two mutually exclusive
    dnl ABIs -- IBM double-double or IEEE binary128 -- for powerpc64 Linux and froze
```

--with-long-double-128 and the probe behind it are gone.  The question --
does this target.s C library use 128-bit long double -- was answered by
reading __GLIBC__ out of $target_header_dir/features.h, i.e. by looking
inside the target sysroot, which a compiler serving many targets has no
business doing.  Worse, a cross build with no headers installed silently got
"no": the probe cannot run, so it records the wrong answer rather than
failing.  gcc/config.gcc now decides it from the triple, which is where the
musl half of the old logic already lived.  glibc 2.4 is from 2006 and every
glibc GCC supports is far past it, so the probe had exactly one answer.

### configure.ac:3545

Sat immediately above:

```
    
    dnl TARGET_LIBC_PROVIDES_HWCAP_IN_TCB and TARGET_LIBC_GNUSTACK are gone from
    dnl here.  Both combined a `case $target' with a glibc version test, and both
```

--with-long-double-format is gone.  It picked one of two mutually exclusive
ABIs -- IBM double-double or IEEE binary128 -- for powerpc64 Linux and froze
it into the compiler as TARGET_IEEEQUAD_DEFAULT.  config/rs6000/rs6000.cc
carries its own #ifndef fallback keyed on POWERPC_LINUX/POWERPC_FREEBSD,
which is what a build that did not pass the option always got, so nothing
changes for anyone who did not use it.  -mabi=ieeelongdouble still selects it
per compilation.

### configure.ac:3553

Sat immediately above:

```
    
    dnl The dl_iterate_phdr probe is gone, for the same reason and to the same
    dnl place: libgcc/configure.ac.  Nothing in gcc/ reads TARGET_DL_ITERATE_PHDR;
```

TARGET_LIBC_PROVIDES_HWCAP_IN_TCB and TARGET_LIBC_GNUSTACK are gone from
here.  Both combined a `case $target' with a glibc version test, and both
described the target's C library rather than this compiler.  They are now
targ_caps.libc_hwcap_in_tcb and targ_caps.libc_gnustack, worked out by
target-specs -- the step that knows the triple AND the glibc version -- and
read at run time by config/rs6000/ and config/mips/.

### configure.ac:3560

Sat immediately above:

```
    
    # We no longer support different GC mechanisms.  Emit an error if
    # the user configures with --with-gc.
```

The dl_iterate_phdr probe is gone, for the same reason and to the same
place: libgcc/configure.ac.  Nothing in gcc/ reads TARGET_DL_ITERATE_PHDR;
its consumers are libgcc/unwind-dw2-fde-dip.c and libgcc/crtstuff.c.

It was doubly wrong here.  It keyed on `case "$target"', and $target is
empty in this tree, so it fell through to `unknown' and the macro was never
defined for ANY target -- USE_PT_GNU_EH_FRAME silently off on Solaris, the
BSDs and musl.  And the FreeBSD arm of it grepped
$target_header_dir/sys/link_elf.h.  libgcc keys on $host, which is the same
machine under the name that is correct there, and greps the headers it is
actually compiling against.

### configure.ac:4095

Sat immediately above:

```
    
    # Specify what should be the default of -fdiagnostics-color option.
    AC_ARG_WITH([diagnostics-color],
```

--with-linker-hash-style is gone.  It baked one linker's hash format into
the driver, prepended to link_spec inside init_spec().  A target that wants
--hash-style= can say so in its own link spec; a build that did not pass the
option prepended nothing, which is now the only behaviour.

### configure.ac:4260

Sat immediately above:

```
    
    # On x86-64, when profiling is enabled with shrink wrapping, the mcount
    # call may not be placed at the function entry after
```

--enable-s390-excess-float-precision is gone, and so is the probe behind it.
On s390 the target C library has historically typedef'ed float_t to double,
and the compiler has to agree with whatever its libc does.  The default
answered that by compiling `#include <math.h>' against the target sysroot --
a build-time look inside the target's C library, which is the thing a
multi-target compiler cannot do.  It is now targ_caps.s390_excess_float_precision,
read at run time from the target config file (see gcc/target-caps.h), and
config/s390/s390.cc tests it with an ordinary `if'.

---

# The one-and-two-line notes, deleted outright

Four agent-written notes were short enough to be pure pointers.  Three said
only "this probe moved to target-specs" and are reproduced here for
completeness; the fourth carried an actual decision.

### configure.ac:985 -- the one with content

    --enable-offload-defaulted went with them; OFFLOAD_DEFAULTED stays
    undefined, as in a build that did not pass it.

### configure.ac:3328

    The .sleb128/.uleb128 probe lives in target-specs/configure.ac; the pin
    that used to stand in for it here is gone with the DWARF2_DEBUG_VIEW probe.

### configure.ac:3341

    The .loc is_stmt and .loc discriminator probes moved to target-specs.

### configure.ac:3439

    The "tolerance to line number 0" probe moved to target-specs.

---

# What was NOT moved, and why

Four blocks stayed in `gcc/configure.ac`, because each documents code that is
still there -- rule 1, not archaeology:

- **`ENABLE_STDLIB_OPTION`** -- why `-stdlib=` is now enabled unconditionally
  rather than probed, and why a target-specs probe cannot serve it (the
  consumer is `Condition(...)` in `c.opt`, resolved when `options.cc` is
  compiled).
- **`HAVE_GAS_HIDDEN` / `HAVE_GAS_WEAK` for the target libraries** -- why the
  two `AC_DEFINE`s are unconditional, which is the `crtstuff.c` finding quoted
  at the top of this file.  This one is doing active load-bearing work: it is
  the reason nobody re-deletes those defines.
- **`libatomic_target`** -- why it is a triple rather than a boolean, and why
  it cannot move to target-specs (the library is not built yet when those
  probes run).
- **the eleven-block index** at the head of the swept region, condensed to one
  line per moved block, which is all a reader of `configure.ac` needs.

Two upstream `dnl` lines are absent from the current file and were *not* lost
in this move -- they went earlier with the gas/ld flavour probes:

    dnl Don't define HAVE_GNU_AS, only HAVE_<FLAVOR>_AS when actually used.
    dnl Don't define HAVE_GNU_LD, only HAVE_<FLAVOR>_LD when actually used.

The other twelve upstream `dnl` lines are untouched.  Checked mechanically, not
by eye: an early pass deleted eight of them along with the agent notes, because
"short `dnl` block" turned out to be a rule that could not tell an agent's
disposable pointer from upstream's documentation of live code.  The rule now
compares each line against the pre-branch file.

---

# The `#'-style notes

The pass above moved the `dnl' blocks.  The agents also wrote ordinary
`#' comments, which unlike `dnl' are COPIED INTO the generated `configure'
-- so these were costing lines in two files, not one.  Same three-way test,
same pointer form.  Upstream `#' lines inside a mixed block were kept in
place; only agent-added lines were moved.


### configure.ac:44

Sat immediately above:

```
    build_subdir="build-${build_noncanonical}"
    if ( test $srcdir = . && test -d ../gcc ) \
       || test -d $srcdir/../host-${host_noncanonical}; then
```

Determine the build- and host-specific subdirectories.  GCC_TOPLEV_SUBDIRS
would do this, but it also derives a target_subdir and requires a canonical
target for it.

### configure.ac:292

Sat immediately above:

```
    demangler_in_ld=yes
    
    dsymutil_vers=
```

--with-demangler-in-ld is gone.  It only ever turned the linker --demangle
probe off; its default -- run the probe -- is now the only behaviour, and
whether a particular ld supports --demangle is a question for that ld, asked
by target-specs after the build rather than by this script.

### configure.ac:718

Sat immediately above:

```
    AC_ARG_ENABLE(targets,
    [AS_HELP_STRING([--enable-targets=all|LIST],
    		[additional target machines to support])],
```

Additional target machines this compiler should be able to serve, beyond the
one named by --target.  Comma-separated list, or "all".  Compare binutils'
--enable-targets, which GCC has never had.

This does not yet build additional back ends; it collects each extra target's
configuration so that target-specific data can be emitted per target rather
than frozen into the binary at configure time.

### configure.ac:813

Sat immediately above:

```
    
    dnl Whether to build libgcov and the related host tools.
    dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:871".
```

--enable-shared/--disable-shared meaning "do (not) provide a shared libgcc"
is gone from here.  It was a SECOND AUTHORITY AND-ed on top of a target fact:
DRIVER_DEFINES used to read

    $(if $(SHLIB),$(if $(filter yes,@enable_shared@),-DENABLE_SHARED_LIBGCC))

where $(SHLIB) comes from config/t-slibgcc via the target's tmake_file, and
@enable_shared@ came from this option.  Two different questions -- "does this
target have a shared libgcc" and "did the builder ask for one" -- sharing one
name, in one file, with no way to tell which had produced a given answer.

The option half goes because libgcc/configure.ac:52 asks it already, in the
place that owns it, and because `--enable-shared' given to a package means
THAT PACKAGE's host: given to gcc it has to mean gcc's own host, which is what
the option below now means.  Only the $(SHLIB) half remains, so the default
(enable_shared=yes) is unchanged; a build that explicitly passed
--disable-shared to gcc no longer suppresses shared-libgcc specs, and should
pass it to libgcc instead.

THE TARGET HALF IS STILL BROKEN AND IS NOT FIXED HERE.  $(SHLIB) reaches the
driver from the PRIMARY target's config.gcc, so in an --enable-targets=all
build one target's answer is applied to all of them.  See scratchpad/STATE.md,
"ENABLE_SHARED_LIBGCC flows through the privileged-target channel".

### configure.ac:1675

Sat immediately above:

```
    if test x"${target}" != x; then
      target_canon=`${srcdir}/../config.sub ${target} 2>/dev/null`
      if test x"${target_canon}" = x; then
```

Canonicalise ${target} before config.gcc dispatches on it.  AC_CANONICAL_TARGET
is deliberately gone -- it is what gave one target a privileged position --
but autoconf's legacy `target=$target_alias' assignment remains, and that
leaves ${target} holding exactly what was typed on the command line.
config.gcc matches canonical triples only, and its arms are ordered globs, so
an uncanonical name does not fail: it silently matches a LATER arm.
--target=aarch64-linux-gnu splits as aarch64/linux/gnu, misses
`aarch64*-*-linux*' and hits `aarch64*-*-gnu*' -- the GNU/Hurd port -- while
--enable-targets, which does canonicalise, records the Linux one.  The build
then had tm.h describing Hurd and tm-aarch64.h describing Linux.
The --enable-targets loop below does the same thing for the same reason.

### configure.ac:1697

Sat immediately above:

```
    gcc_extra_targets=
    case ${enable_targets} in
      no | "")
```

Multi-target: collect the same information for each additional target named by
--enable-targets.  config.gcc dispatches on ${target} and assigns tm_file &c.
unconditionally, so every extra target is handled by sourcing it again inside a
subshell; that keeps the primary target's variables above untouched and lets an
unsupported target fail as a non-zero exit we can report.

The result is a manifest, one stanza per target, which later build steps read
to emit per-target data instead of freezing one target's values into the
binary.  No additional back end is compiled yet.

### configure.ac:1711

Sat immediately above:

```
        gcc_extra_targets=`sed -n '/^LIST = /,/^ *$/p' ${srcdir}/../contrib/config-list.mk \
          | sed -e 's/^LIST = //' \
          | tr -d '\134' \
```

config.gcc matches targets with shell globs, so it cannot be enumerated.
contrib/config-list.mk carries the list GCC itself uses to build every
configuration, which is the same question asked for the same reason, so
take it from there rather than inventing a second list that would drift.

Entries may carry configure options as a trailing OPT-with-cpu=... ; only
the triple is wanted here.  \134 is a backslash, spelled in octal so that
neither m4 nor the shell has to be argued with about quoting.

### configure.ac:1752

Sat immediately above:

```
    gcc_common_ext=multi-target-common.ext
    gcc_common_ent=multi-target-common.ent
    : > ${gcc_common_ext}
```

Registry of the tables, as data for common/common-target-select.cc.  Built in
two pieces because every declaration has to precede the table that uses them,
and they are produced in the same pass.

### configure.ac:1759

Sat immediately above:

```
    gcc_all_spec_fn_objects=
    gcc_sf_ext=multi-target-spec-functions.ext
    gcc_sf_ent=multi-target-spec-functions.ent
```

The same two pieces for the driver's spec-function tables.  Kept in step with
the common-hook registry above, from the same loop over the same manifest, so
that the two cannot come to disagree about which targets exist -- gcc.cc
checks that they have not.

### configure.ac:1772

Sat immediately above:

```
    gcc_mt_canon=
    for gcc_mt in ${gcc_manifest_targets}; do
      gcc_mt_c=`${srcdir}/../config.sub ${gcc_mt} 2>/dev/null`
```

Canonicalise the list, and deduplicate it once canonical.  Targets are named
the way one would type them on a command line -- aarch64-elf, alpha-netbsd --
and configure would normally expand those before anyone sees them.
config.gcc matches canonical triples only, and answers a short form with
"Configuration ... not supported".

The dedup is not cosmetic.  ${target} is in this list unconditionally (see
above), so a user who also names the build's own triple -- and
--enable-targets=all names several i386 ones -- would otherwise get the same
object built by two identical make rules and listed twice in OBJS, and two
registry entries for one triple.  Two spellings of one triple only become
comparable after config.sub, which is why this happens here and not where the
list is assembled.

### configure.ac:1804

Sat immediately above:

```
      gcc_mt_data=`
        target=${gcc_mt}
        tm_defines= cpu_type= target_cpu_default=
```

The with_* group no longer needs clearing here: config.gcc clears it itself,
because --with-cpu/--with-arch/--with-tune/... are gone.  What used to leak
from the primary target into every other one (aarch64 rejecting x86's
--with-arch=x86-64) cannot arise any more; each target's CPU/ABI defaults are
inferred from its own triple and reported below as option_defaults.

### configure.ac:1818

Sat immediately above:

```
        test x"${tm_file}" = x && tm_file=${cpu_type}/${cpu_type}.h
        test x"${md_file}" = x && md_file=${cpu_type}/${cpu_type}.md
        test x"${out_file}" = x && out_file=${cpu_type}/${cpu_type}.cc
```

config.gcc leaves these unset for most targets; the primary target gets
them defaulted just below, so apply the same rules here or the manifest
would claim the target has no machine description.

### configure.ac:1826

Sat immediately above:

```
        echo "option_defaults ${target_option_defaults}"
        # Target properties cc1 needs that are decided by the triple, not probed.
        echo "decimal_float ${target_decimal_float}"
```

This targets own CPU/ABI defaults, as name=value pairs whose names are
the OPTION_DEFAULT_SPECS keys of its back end.  These were the values of
the undeclared --with-cpu/--with-arch/--with-tune/... options; with those
gone they are inferred from the triple, per target rather than one array
compiled into the driver.  target-specs turns them into the
option_defaults spec of this targets spec file.  (No apostrophes or
backticks in here: this whole block is inside a command substitution.)

### configure.ac:1837

Sat immediately above:

```
        echo "common_out_file ${common_out_file}"
        # Use $( ) here, not backticks.  This runs inside the outer command
        # substitution that captures the stanza, and a nested backtick closes that
```

Which common-hook table this target uses, and the name it will be
compiled under.  Recorded per target so that several can be built and
linked together; config.gcc applies this defaulting itself, after the
per-target clauses have had their say.

### configure.ac:1842

Sat immediately above:

```
        echo "common_out_symbol targetm_common_$(basename ${common_out_file} .cc | sed 's/-/_/g')"
        echo "tm_file ${tm_file}"
        echo "tm_p_file ${tm_p_file}"
```

Use $( ) here, not backticks.  This runs inside the outer command
substitution that captures the stanza, and a nested backtick closes that
early -- which silently emptied the whole thing.  (Not even in a comment:
the closing backtick is found while parsing, before the comment applies.)

### configure.ac:1850

Sat immediately above:

```
        mt_tmake_present=
        for mt_tf in ${tmake_file}; do
          if test -f ${srcdir}/config/${mt_tf}; then
```

Which of those fragments actually exist.  tmake_file names some that do
not -- sh-unknown-elf asks for sh/t-elf, which is not in the tree -- and
an include of a missing file is a hard error in make, so everything that
feeds these to make has to filter them first.  (No backtick in this
comment: the whole block is one command substitution, and a stray one
closes it while the file is parsed, long before the comment applies.)
Filtered once here, where
the answer is already known, rather than by each consumer in turn: this
is the same test the primary target's own tmake_file loop applies further
down, and it was the last fact the manifest left its readers to re-derive.

### configure.ac:1871

Sat immediately above:

```
        mt_tm_file="${tm_file} initfini-array.h"
        if test x"${dwarf2}" = xyes; then
          mt_tm_file="${mt_tm_file} tm-dwarf2.h"
```

The header list this target's tm.h is built from, in the same form the
single-target path uses.  $( ) rather than backticks: this is inside the
substitution capturing the stanza.
The tail the single-target path appends to tm_file further down --
initfini-array.h, tm-dwarf2.h, and defaults.h last of all -- is added
after this loop has run, so mirror it here.  The two lists must agree:
anything the primary tm.h gets and a per-back-end tm-<base>.h does not is
a macro some back end will turn out to need, and defaults.h in particular
is where target_unit and friends come from.

### configure.ac:1899

Sat immediately above:

```
        echo "extra_modes ${extra_modes}"
        # Headers this target's tm.h includes that no source tree contains: the
        # tmake_file fragments generate them into the build directory.  They are
```

This back end's extra machine modes.  The generators are built once per
back end against these (see gen-multi-target-md.awk); reading a target's
.md without them fails on the modes only that target defines.  Recorded
rather than derived: most back ends do call the file
<cpu>/<cpu>-modes.def, but config.gcc is the authority and nothing
obliges a back end to follow the convention.

### configure.ac:1906

Sat immediately above:

```
        mt_tm_gen_headers=
        for mt_f in ${tm_file}; do
          case ${mt_f} in
```

Headers this target's tm.h includes that no source tree contains: the
tmake_file fragments generate them into the build directory.  They are
listed separately because their names have to be made unique per back end
(three different back ends generate a file called sysroot-suffix.h) and
because something has to create them.

### configure.ac:1918

Sat immediately above:

```
        echo "tm_multilib_config ${TM_MULTILIB_CONFIG}"
      ` || {
        # Read the message here, not in the AC_MSG_ERROR argument: that argument is
```

The multilib set is NOT a config.gcc variable: MULTILIB_OPTIONS,
MULTILIB_MATCHES, MULTILIB_REUSE and MULTILIB_OSDIRNAMES are make
variables, assigned by the 136 t-* fragments named in tmake_file, so they
cannot be captured by sourcing config.gcc here.  Reading them needs make
to evaluate that target's fragments; see the multilib rules in
gcc/Makefile.in.

What config.gcc does own is the input those fragments compute from, and
without it the answer is wrong rather than merely missing -- sh/t-sh
derives MULTILIB_OPTIONS from $(TM_MULTILIB_CONFIG) and yields an empty
list when it is unset.  So it is recorded here, for the make side to feed
back in.

### configure.ac:1932

Sat immediately above:

```
        gcc_mt_msg=`cat ${gcc_mt_err} 2>/dev/null | tr '\n' ' '`
        AC_MSG_ERROR([--enable-targets: config.gcc failed for ${gcc_mt}: ${gcc_mt_msg}])
      }
```

Read the message here, not in the AC_MSG_ERROR argument: that argument is
m4-quoted, so a substitution written inside it is emitted literally and the
user is shown the backtick expression instead of what config.gcc said.

### configure.ac:1941

Sat immediately above:

```
      gcc_mt_cof=`echo "${gcc_mt_data}" | sed -n 's/^common_out_file //p'`
      gcc_mt_sym=`echo "${gcc_mt_data}" | sed -n 's/^common_out_symbol //p'`
      gcc_mt_obj=`basename ${gcc_mt_cof} .cc`.o
```

Collect each target's common-hook table so the build can compile all of
them.  Duplicates are real: several targets share one common file (and every
target without its own uses default-common.cc), so the same object must not
be listed, or built, twice.

### configure.ac:1952

Sat immediately above:

```
      gcc_mt_md=`echo "${gcc_mt_data}" | sed -n 's/^md_file //p'`
      gcc_mt_incl=`echo "${gcc_mt_incl}" | sed -e "s|^options\.h|options-${gcc_mt_base}.h|" -e "s|insn-constants\.h|insn-constants-${gcc_mt_base}.h|"`
      # config.gcc sets this per target and some back ends' tm.h reads it (nds32
```

This target's tm.h must pull in this target's options.h, not the generic
one: the types and enums a back end needs -- aarch64_feature_flags, bfin's
WA_*, alpha's MASK_SOFT_FP -- reach a build through the .opt files'
HeaderInclude directives, and so exist only in a generated options header
that was built with those .opt files.

### configure.ac:1959

Sat immediately above:

```
      gcc_mt_tcd=`echo "${gcc_mt_data}" | sed -n 's/^target_cpu_default //p'`
      # The same treatment for the headers a target's tmake_file would generate
      # into the build directory.  These need it more than options.h does: three
```

config.gcc sets this per target and some back ends' tm.h reads it (nds32
builds its default ISA out of it); passing the primary target's value, or
nothing at all, is not an option.

### configure.ac:1963

Sat immediately above:

```
      gcc_mt_genh=`echo "${gcc_mt_data}" | sed -n 's/^tm_generated_headers //p'`
      gcc_mt_genh_files=
      for gcc_mt_h in ${gcc_mt_genh}; do
```

The same treatment for the headers a target's tmake_file would generate
into the build directory.  These need it more than options.h does: three
different back ends generate a file called sysroot-suffix.h, so under one
name at most one of them could be right.

### configure.ac:1980

Sat immediately above:

```
           if test x"${gcc_mt_base}" != xdefault; then
             # This back end's own options header is NOT emitted here.  It cannot
             # be: it has to be built from the .opt files of ALL this back end's
```

One rule per object.  A pattern rule cannot serve here: the objects
sit in the build root but their sources are under
common/config/<cpu>/, and vpath cannot glob those directories.  The
-D is what gives each table a name of its own.
Each back end gets a tm.h of its own, under a name of its own, rather
than every back end sharing the one tm.h and 46 of them getting some
other target's macros.  default-common.cc includes no tm.h and so
needs none.

### configure.ac:1989

Sat immediately above:

```
             printf 'insn-constants-%s.h: build/genconstants$(build_exeext) $(srcdir)/config/%s\n\t$(RUN_GEN) build/genconstants$(build_exeext) $(srcdir)/config/%s > $@\n\n' \
               "${gcc_mt_base}" "${gcc_mt_md}" "${gcc_mt_md}" >> ${gcc_common_mk}
             # The build-directory headers this target's tm.h includes, holding
```

This back end's own options header is NOT emitted here.  It cannot
be: it has to be built from the .opt files of ALL this back end's
triples, and inside this loop only the first one has been seen.  See
the union pass after the loop.
... and this back end's constants, from its own machine description
rather than whichever target happened to generate insn-constants.h.

### configure.ac:1997

Sat immediately above:

```
             for gcc_mt_h in ${gcc_mt_genh_files}; do
               case ${gcc_mt_h} in
                 *sysroot-suffix*)
```

The build-directory headers this target's tm.h includes, holding
multilib-derived spec macros -- SYSROOT_SUFFIX_SPEC and friends.

These were empty placeholders while the multilib data did not exist:
a multi-target build includes no single target's tmake_file, so
MULTILIB_OPTIONS and friends were unset and the generators had
nothing to work from.  That data is now extracted per target into
multi-target.multilib, so the real content can be produced.
gen-sysroot-suffix.sh does it, and documents which targets still
cannot be answered on this side of the build, and why.
Two kinds end up in this list and they need different treatment.

### configure.ac:2015

Sat immediately above:

```
                   gcc_mt_horig=`echo "${gcc_mt_h}" | sed "s/-${gcc_mt_base}\\.h\$/.h/"`
                   printf '%s: %s\n\tcp $< $@\n\n' \
                     "${gcc_mt_h}" "${gcc_mt_horig}" >> ${gcc_common_mk}
```

The rest are headers a config/<cpu>/t-<cpu>-headers fragment
already generates under its plain name, which we then renamed
per back end so that two back ends generating the same name do
not collide.  The renamed copy has to be the fragment's output;
generating it empty meant tm-gcn.h included a
gcn-device-macros-gcn.h with nothing in it while the real
158-line gcn-device-macros.h sat unused beside it.  That was
true before this rule existed and would have kept being true.

### configure.ac:2034

Sat immediately above:

```
             gcc_mt_tmflag="-DTM_H_FILE='\"tm-${gcc_mt_base}.h\"'"
             printf 'spec-functions-%s.o: $(srcdir)/spec-functions.cc tm-%s.h $(GCC_H)\n\t$(COMPILE) %s -DSPEC_FUNCTIONS_SYMBOL=extra_spec_functions_%s $(srcdir)/spec-functions.cc\n\t$(POSTCOMPILE)\n\n' \
               "${gcc_mt_base}" "${gcc_mt_base}" "${gcc_mt_tmflag}" "${gcc_mt_base}" >> ${gcc_common_mk}
```

This back end's driver spec functions, from the same tm-<base>.h.
Only bases that HAVE one: the handful that share default-common.cc
have no tm-<base>.h to compile against, and are mapped to the empty
table below.  Checked, not assumed -- none of the sixteen headers
that define EXTRA_SPEC_FUNCTIONS belongs to that group.
The -D has to reach the compiler as -DTM_H_FILE='"tm-<base>.h"':
a string literal for #include, single-quoted so make and the shell
keep the inner quotes.  Assembled here rather than nested inside the
printf format, where three layers of quoting (m4, shell, make) had
to be got right at once and a mistake produces a valid-looking rule
that includes the wrong header.

### configure.ac:2049

Sat immediately above:

```
             printf 'extern const struct spec_function extra_spec_functions_%s@<:@@:>@;\n' \
               "${gcc_mt_base}" >> ${gcc_sf_ext}
           else
```

@<:@ and @:>@ are the m4 quadrigraphs for [ and ].  Written literally
they are eaten as m4 quotes and the declaration comes out as a
scalar -- which still compiles, because the registry then takes its
address, and links to a table read one element long.

### configure.ac:2062

Sat immediately above:

```
      printf '  TARGETM_COMMON_ENTRY ("%s", %s) \\\n' "${gcc_mt}" "${gcc_mt_sym}" >> ${gcc_common_ent}
      # And one spec-function entry per target, for the same reason.  A base with
      # no tm-<base>.h of its own (the group sharing default-common.cc) gets the
```

One entry per target, not per object: several targets can share a table.
This is also what forces the tables into the compiler at all -- they are
linked from an archive, and a member nothing refers to is simply not pulled
in, so without the registry only the --target one ends up in the binary.

### configure.ac:2067

Sat immediately above:

```
      if test x"${gcc_mt_base}" != xdefault; then
        printf '  SPEC_FUNCTIONS_ENTRY ("%s", extra_spec_functions_%s) \\\n' \
          "${gcc_mt}" "${gcc_mt_base}" >> ${gcc_sf_ent}
```

And one spec-function entry per target, for the same reason.  A base with
no tm-<base>.h of its own (the group sharing default-common.cc) gets the
EMPTY table rather than no entry: "this target publishes no spec functions"
and "this target is not in the registry" must stay distinguishable, because
gcc.cc treats the second as the two registries having drifted apart.

### configure.ac:2082

Sat immediately above:

```
    ${AWK} '
      # Manifest stanzas are blank-line separated `key value...` lines.
      /^common_out_file / {
```

The options header of a back end, built from the UNION of its triples'
extra_options.

This has to be a second pass.  Every other per-back-end rule above can be
emitted the first time a triple of that back end is seen, because what it
needs -- the .md file, the cpu_type -- is a property of the back end and every
triple reports the same value.  extra_options is not like that: it is a
property of the TRIPLE, it is where the OS brings its own options in, and the
triples of one back end genuinely disagree.  Emitting the rule from the first
triple therefore silently picked one OS's answer for all of them, which is the
"first-triple-wins" defect.

What it cost, concretely.  rs6000's first manifest triple is a Darwin one,
whose extra_options has no rs6000/sysv4.opt.  TARGET_LITTLE_ENDIAN is
`Mask(LITTLE_ENDIAN)' in that .opt and so was absent from options-rs6000.h;
config/rs6000/sysv4.h:50 defines TARGET_BIG_ENDIAN in terms of it, a
constraint in rs6000's .md reaches it through BYTES_BIG_ENDIAN, and
gencondmd failed to compile for the twelve rs6000 triples whose tm.h chain
includes sysv4.h.  cc1 could not be linked at all.

The union is taken WITHIN a back end only.  Across back ends it would not be
safe -- the option names genuinely conflict there, and the Mask() bits do not
fit -- and that is separate work.  Within a back end it was measured clean:
for all 45 back ends the unioned .opt set produces an options-<base>.h with no
`#error', because opt-read.awk merges same-named records (which is how an
ordinary single-target build already copes with, say, gnu-user.opt and
linux.opt both declaring -pthread).  One back end needed help to stay inside
the 32-bit target_flags word: see the note in config/vxworks.opt.

### configure.ac:2138

Sat immediately above:

```
    	if (!(f in seenall)) {
    	  seenall[[f]] = 1
    	  allfiles = allfiles " $(srcdir)/config/" f
```

... and the same files unioned across ALL back ends.  This list is
NOT used to generate any table: it is used only to collect the set of
option NAMES, so that every generated options header in the build can
be padded up to it, so that enum opt_code means one thing.  See
gcc/opt-stub.awk for why the data must not be unioned with it.

### configure.ac:2162

Sat immediately above:

```
          printf "optionlist-%s: $(lang_opt_files)%s optionlist-vocab $(srcdir)/opt-gather.awk $(srcdir)/opt-functions.awk $(srcdir)/opt-stub.awk\n", b, files[[b]]
          printf "\tLC_ALL=C; export LC_ALL; \\\n"
          printf "\t$(AWK) -f $(srcdir)/opt-gather.awk $(lang_opt_files)%s > $@.own\n", files[[b]]
```

This back end own records, PLUS a placeholder for every name in the
vocabulary it does not declare.  Without the padding this header
numbers enum opt_code by this back end option set alone, while
opts.cc is numbered by the shared one, and the two disagree: an OPT_
value produced in common/config/<cpu>/<cpu>-common.cc and consumed in
opts.cc then names a different option.  That is what made
default_options_optimization walk this back end
option_optimization_table straight into parse_sanitizer_options.

### configure.ac:2181

Sat immediately above:

```
          printf "\t  -v guard_name=OPTIONS_%s_H \\\n", toupper(b)
          printf "\t  -f $(srcdir)/opth-gen.awk < $< > $@\n\n"
        }
```

A guard of its own.  Sharing one guard across the shared options.h and
the other 44 made a second include of the family a silent no-op instead
of an error, so which options a TU got depended on include ORDER.
See opth-gen.awk.

### configure.ac:2246

Sat immediately above:

```
    tm_file="${tm_file} initfini-array.h"
    
    if test x"$dwarf2" = xyes
```

initfini-array.h is self-guarding: its body is wrapped in
`#if HAVE_INITFINI_ARRAY_SUPPORT', which config/elfos.h raises for ELF
targets, so it can simply always be in the bundle.

### configure.ac:2613

Sat immediately above:

```
    common_out_symbol=targetm_common_`basename $common_out_file .cc | sed 's/-/_/g'`
    AC_SUBST(common_out_symbol)
    
```

Name this target's common hook table is defined under.  Every target used to
call it `targetm_common', which is why two of them could never be linked into
the same compiler.  Derived from the file name so it needs no new data, and
sanitised because it becomes a C identifier.
NB: no brackets in the sed expression.  `[' and `]' are m4 quote characters, so
a character class here is silently eaten and the substitution never happens --
which produced `targetm_common_i386-common' and a compile error on the `-'.
Hyphen is the only character these file names contain that a C identifier
cannot, so replacing it directly avoids the problem entirely.

### configure.ac:2924

Sat immediately above:

```
    
    # Identify the linker which will work hand-in-glove with the newly
    # built GCC, so that we can examine its features.  This is the linker
```

--enable-ld and --enable-gold are gone.  They chose which of two in-tree
linkers this compiler would drive -- one of a set of mutually exclusive target
tools, decided once at build time.  Which linker runs is a property of the
invocation, and the linker to use already has a home: the `linker' static spec
in the driver.  Neither was passed by almost any build, so the in-tree ld is
what the search below now finds, exactly as before.

### configure.ac:2963

Sat immediately above:

```
    AC_SUBST(ORIGINAL_PLUGIN_LD_FOR_TARGET)
    AC_DEFINE_UNQUOTED(PLUGIN_LD_SUFFIX, "$PLUGIN_LD_SUFFIX", [Specify plugin linker])
    
```

--with-plugin-ld is gone: it named the linker the LTO plugin should be handed
to, another single target tool chosen at build time.  Not passing it left the
suffix as the basename of the linker found above -- normally plain `ld' -- and
that is now the only answer this script gives.

### configure.ac:3745

Sat immediately above:

```
    AC_ARG_ENABLE(host-shared,
    [AS_HELP_STRING([--enable-host-shared],
    		[build host code as shared libraries])])
```

--enable-host-shared, --enable-host-pie.

The `host-' prefix is redundant and is on its way out.  `--enable-shared'
given to a package means THAT PACKAGE's host: given to gcc it means gcc's own
host, given to libgcc it means libgcc's host, which is what gcc calls the
target.  One rule, resolved against whichever package is being configured --
so the prefix was a local invention where a convention already existed.

THE BLOCKER IS NOW GONE.  This file used to carry a SECOND
AC_ARG_ENABLE(shared) meaning "do not provide a shared libgcc" -- a target
question -- so renaming these would have put two authorities behind one name
in a single file, the later one silently winning.  That option has been
removed (see the note above DRIVER_DEFINES and libgcc/configure.ac:52).

What is left before the rename is purely the top level: it passes
--enable-host-shared and --enable-host-pie down here (22 uses in
../configure.ac), so both files have to change together or the option becomes
unrecognised, enable_shared goes unset, and the host is built non-shared --
which shows up as a libgccjit link error, not as a configure diagnostic.
Acceptance therefore has to be "a build with no flags still produces a shared
host where it should", not "the old spelling is rejected".

### configure.ac:3865

Sat immediately above:

```
    build_target_triple=${target}
    AC_SUBST(build_target_triple)
    
```

The triple the target libraries in THIS BUILD TREE are being built for.

This is emphatically NOT "the compiler's target": this compiler has none, and
nothing that gets compiled into it may depend on this value.  Read the
FIXINCLUDES_MACHINE comment in Makefile.in before reaching for it -- putting
the privileged target back is exactly what this project removed.

It exists for one purpose: so the build directory can hold a driver named the
way an INSTALLED driver is named, `<triple>-gcc', for the in-tree target
libraries (libgcc, libstdc++, ...) to invoke.  A bare `xgcc' has no way to
know which target it is compiling for, and with the empty back end that is a
hard error rather than a silent default; naming the in-tree driver the way
the installed one is named means the two paths are ONE mechanism instead of
two, so whatever verifies one verifies the other.

${target} is appended to gcc_manifest_targets unconditionally above, so this
triple is always one this compiler was configured to serve.  The toplevel
Makefile spells the same name as $(target)-gcc out of its own @target@; both
come from AC_CANONICAL_TARGET over the same arguments, so they agree.

### configure.ac:3887

Sat immediately above:

```
    gcc_driver_version=`eval "${get_gcc_base_ver} $srcdir/BASE-VER"`
    echo "gcc_driver_version: ${gcc_driver_version}"
    cat > gcc-driver-name.h <<EOF
```

Generate gcc-driver-name.h containing GCC_DRIVER_NAME for the benefit
of jit/jit-playback.cc.

This used to be "${target_noncanonical}-gcc-${version}${exeext}".
ACX_NONCANONICAL_TARGET went with AC_CANONICAL_TARGET, so
${target_noncanonical} has been EMPTY here ever since, and the header was
being written as

    #define GCC_DRIVER_NAME "-gcc-15.0.0"

i.e. libgccjit spawning a program whose name begins with a dash -- which does
not exist, and which anything that execs it through a shell would read as an
option rather than a filename.  An empty variable in a string concatenation
produces a plausible-looking result and no diagnostic; this is the same
silent-emptiness failure the rest of the canonicalisation fallout has.

The unprefixed name is now the correct one, not merely a workaround: the
driver serves every target in the build, so there is no triple to name it
after.  The <triple>-gcc spellings are per-target INSTALL ALIASES and belong
with the manifest, not baked into a compiled-once header.
