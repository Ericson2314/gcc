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
