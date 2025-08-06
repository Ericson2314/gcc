dnl Process this file with autoconf to produce a configure script.

sinclude(../config/enable.m4)
sinclude(../config/tls.m4)
sinclude(../config/toolexeclibdir.m4)
sinclude(../config/acx.m4)
sinclude(../config/no-executables.m4)
sinclude(../config/lib-ld.m4)
sinclude(../config/override.m4)
sinclude(../config/picflag.m4)
sinclude(../config/dfp.m4)
sinclude(../config/unwind_ipinfo.m4)
sinclude(../config/gthr.m4)
sinclude(../config/sjlj.m4)
sinclude(../config/cet.m4)

AC_INIT([GNU C Runtime Library], 1.0,,[libgcc])
AC_CONFIG_SRCDIR([static-object.mk])

# The libgcc should not depend on any header files
AC_DEFUN([_AC_INCLUDES_DEFAULT_REQUIREMENTS],
  [m4_divert_text([DEFAULTS],
    [ac_includes_default='/* none */'])])

AC_ARG_WITH(target-subdir,
[  --with-target-subdir=SUBDIR      Configuring in a subdirectory for target])
AC_ARG_WITH(cross-host,
[  --with-cross-host=HOST           Configuring with a cross compiler])
AC_ARG_WITH(ld,
[  --with-ld               arrange to use the specified ld (full pathname)])

if test "${srcdir}" = "."; then
  if test -n "${with_build_subdir}"; then
    libgcc_topdir="${srcdir}/../.."
    with_target_subdir=
  elif test -z "${with_target_subdir}"; then
    libgcc_topdir="${srcdir}/.."
  else
    if test "${with_target_subdir}" != "."; then
      libgcc_topdir="${srcdir}/../.."
    else
      libgcc_topdir="${srcdir}/.."
    fi
  fi
else
  libgcc_topdir="${srcdir}/.."
fi
AC_SUBST(libgcc_topdir)
AC_CONFIG_AUX_DIR($libgcc_topdir)
AC_CONFIG_HEADER(auto-target.h:config.in)

AC_ARG_ENABLE(shared,
[  --disable-shared        don't provide a shared libgcc],
[
  case $enable_shared in
  yes | no) ;;
  *)
    enable_shared=no
    IFS="${IFS= 	}"; ac_save_ifs="$IFS"; IFS="${IFS}:,"
    for pkg in $enableval; do
      if test "X$pkg" = "Xgcc" || test "X$pkg" = "Xlibgcc"; then
	enable_shared=yes
      fi
    done
    IFS="$ac_save_ifs"
    ;;
  esac
], [enable_shared=yes])
AC_SUBST(enable_shared)

AC_ARG_ENABLE(vtable-verify,
[  --enable-vtable-verify    Enable vtable verification feature ],
[case "$enableval" in
 yes) enable_vtable_verify=yes ;;
 no)  enable_vtable_verify=no ;;
 *)   enable_vtable_verify=no;;
 esac],
[enable_vtable_verify=no])
AC_SUBST(enable_vtable_verify)

AC_ARG_WITH(aix-soname,
[AS_HELP_STRING([--with-aix-soname=aix|svr4|both],
    [shared library versioning (aka "SONAME") variant to provide on AIX])],
[case "${host}:${enable_shared}" in
 power*-*-aix[[5-9]]*:yes)
   AC_MSG_CHECKING([which variant of shared library versioning to provide for shared libgcc])
   case ${withval} in
     aix|svr4|both) ;;
     *) AC_MSG_ERROR([Unknown argument to --with-aix-soname]);;
   esac
   AC_MSG_RESULT($withval)
   ;;
 *) with_aix_soname=aix ;;
 esac
], [with_aix_soname=aix])
AC_SUBST(with_aix_soname)

GCC_PICFLAG
AC_SUBST(PICFLAG)

AC_MSG_CHECKING([for --enable-version-specific-runtime-libs])
AC_ARG_ENABLE(version-specific-runtime-libs,
[  --enable-version-specific-runtime-libs    Specify that runtime libraries should be installed in a compiler-specific directory ],
[case "$enableval" in
 yes) version_specific_libs=yes ;;
 no)  version_specific_libs=no ;;
 *)   AC_MSG_ERROR([Unknown argument to enable/disable version-specific libs]);;
 esac],
[version_specific_libs=no])
AC_MSG_RESULT($version_specific_libs)

GCC_WITH_TOOLEXECLIBDIR

AC_ARG_WITH(slibdir,
[  --with-slibdir=DIR      shared libraries in DIR [LIBDIR]],
slibdir="$with_slibdir",
[if test "${version_specific_libs}" = yes; then
  slibdir='$(libsubdir)'
elif test -n "$with_cross_host" && test x"$with_cross_host" != x"no"; then
  case ${with_toolexeclibdir} in
    no)
      slibdir='$(exec_prefix)/$(host_noncanonical)/lib'
      ;;
    *)
      slibdir=${with_toolexeclibdir}
      ;;
  esac
else
  slibdir='$(libdir)'
fi])
AC_SUBST(slibdir)

# Command-line options.
# Very limited version of AC_MAINTAINER_MODE.
AC_ARG_ENABLE([maintainer-mode],
  [AS_HELP_STRING([--enable-maintainer-mode],
                 [enable make rules and dependencies not useful (and
                  sometimes confusing) to the casual installer])],
  [case ${enable_maintainer_mode} in
     yes) MAINT='' ;;
     no) MAINT='#' ;;
     *) AC_MSG_ERROR([--enable-maintainer-mode must be yes or no]) ;;
   esac
   maintainer_mode=${enableval}],
  [MAINT='#'])
AC_SUBST([MAINT])dnl

AC_PROG_INSTALL

AC_PROG_AWK
# We need awk; bail out if it's missing.
case ${AWK} in
  "") AC_MSG_ERROR([can't build without awk, bailing out]) ;;
esac

AC_CANONICAL_HOST
ACX_NONCANONICAL_HOST
ACX_NONCANONICAL_TARGET
GCC_TOPLEV_SUBDIRS

AC_ARG_ENABLE(gcov,
[  --disable-gcov          don't provide libgcov and related host tools],
[], [case $target in
       bpf-*-*)
         enable_gcov=no
       ;;
       *)
         enable_gcov=yes
       ;;
     esac])
AC_SUBST(enable_gcov)

# Calculate toolexeclibdir
# Also toolexecdir, though it's only used in toolexeclibdir
case ${version_specific_libs} in
  yes)
    # Need the gcc compiler version to know where to install libraries
    # and header files if --enable-version-specific-runtime-libs option
    # is selected.
    toolexecdir='$(libdir)/gcc/$(target_noncanonical)'
    toolexeclibdir='$(toolexecdir)/$(gcc_version)$(MULTISUBDIR)'
    ;;
  no)
    if test -n "$with_cross_host" &&
       test x"$with_cross_host" != x"no"; then
      # Install a library built with a cross compiler in tooldir, not libdir.
      toolexecdir='$(exec_prefix)/$(target_noncanonical)'
      case ${with_toolexeclibdir} in
	no)
	  toolexeclibdir='$(toolexecdir)/lib'
	  ;;
	*)
	  toolexeclibdir=${with_toolexeclibdir}
	  ;;
      esac
    else
      toolexecdir='$(libdir)/gcc-lib/$(target_noncanonical)'
      toolexeclibdir='$(libdir)'
    fi
    multi_os_directory=`$CC -print-multi-os-directory`
    case $multi_os_directory in
      .) ;; # Avoid trailing /.
      *) toolexeclibdir=$toolexeclibdir/$multi_os_directory ;;
    esac
    ;;
esac
AC_SUBST(toolexecdir)
AC_SUBST(toolexeclibdir)

dnl These must be called before AM_PROG_LIBTOOL, because it may want
dnl to call AC_CHECK_PROG.
AC_CHECK_TOOL(AR, ar)
AC_CHECK_TOOL(LIPO, lipo, :)
AC_CHECK_TOOL(NM, nm)
AC_CHECK_TOOL(RANLIB, ranlib, :)
AC_CHECK_TOOL(STRIP, strip, :)
AC_PROG_LN_S

GCC_NO_EXECUTABLES
AC_PROG_CC
AC_PROG_CPP_WERROR

AC_SYS_LARGEFILE

AC_CHECK_SIZEOF([double])
AC_CHECK_SIZEOF([long double])
AS_VAR_ARITH([double_type_size], [$ac_cv_sizeof_double \* 8])
AS_VAR_ARITH([long_double_type_size], [$ac_cv_sizeof_long_double \* 8])
AC_SUBST(double_type_size)
AC_SUBST(long_double_type_size)

AC_CHECK_HEADERS(inttypes.h stdint.h stdlib.h ftw.h \
	unistd.h sys/stat.h sys/types.h \
	string.h strings.h memory.h sys/auxv.h sys/mman.h)
AC_HEADER_STDC

dnl sys/sdt.h and dl_iterate_phdr used to be probed by gcc/configure and reached
dnl this library through tconfig.h -> auto-host.h.  Both describe the target C
dnl LIBRARY -- which is to say this library's own host -- and gcc answered them
dnl by poking around inside $target_header_dir, a target sysroot that a compiler
dnl serving many targets has no business reading.  Ask here instead, where the
dnl question is ours and the headers are the ones we will actually compile
dnl against.  AC_CHECK_HEADERS spells it HAVE_SYS_SDT_H, which is exactly the
dnl name unwind-dw2.c and unwind-arm-common.inc already test.
AC_CHECK_HEADERS(sys/sdt.h)

dnl Assembler capabilities this library needs for its own code generation.
dnl
dnl These used to come from gcc's auto-host.h through tconfig.h, and by the end
dnl HAVE_GAS_HIDDEN was not even probed there -- gcc/configure AC_DEFINE'd it to
dnl a flat 1, with a comment saying so, because the compiler proper had moved to
dnl the runtime targ_caps.gas_hidden and the only remaining reader was this
dnl library.  A constant 1 is a guess that happens to be right on every host GCC
dnl currently builds on; it is not an answer.
dnl
dnl Asking here is strictly better than asking in gcc/ ever was: $CC is the
dnl compiler that will actually build this library, so the probe drives the very
dnl assembler the objects will go through, rather than the one gcc's configure
dnl happened to find.
AC_CACHE_CHECK([whether the assembler supports .hidden], [libgcc_cv_as_hidden], [
  case "$host" in
    *-*-darwin*)
      dnl Darwin's assembler has visibility, spelled differently; the directive
      dnl probe would say no and take .hidden away from a target that has it.
      libgcc_cv_as_hidden=yes ;;
    *-*-aix*)
      AC_COMPILE_IFELSE([AC_LANG_SOURCE([[__asm__ (".globl foobar,hidden");]])],
			[libgcc_cv_as_hidden=yes], [libgcc_cv_as_hidden=no]) ;;
    *)
      AC_COMPILE_IFELSE([AC_LANG_SOURCE([[__asm__ (".hidden foobar\nfoobar:");]])],
			[libgcc_cv_as_hidden=yes], [libgcc_cv_as_hidden=no]) ;;
  esac])
if test x$libgcc_cv_as_hidden = xyes; then
  AC_DEFINE(HAVE_GAS_HIDDEN, 1, [Define if your assembler supports .hidden.])
fi

AC_CACHE_CHECK([whether the assembler supports .weak], [libgcc_cv_as_weak], [
  AC_COMPILE_IFELSE([AC_LANG_SOURCE([[__asm__ (".weak foobar");]])],
		    [libgcc_cv_as_weak=yes], [libgcc_cv_as_weak=no])])
if test x$libgcc_cv_as_weak = xyes; then
  AC_DEFINE(HAVE_GAS_WEAK, 1, [Define if your assembler supports .weak.])
fi

dnl Whether the linker merges read-only and read-write sections into one
dnl read-write section.  crtbegin/crtend on mingw and cygwin put the EH frame
dnl registration in .rdata when it does, and in .data when it does not, so
dnl getting this wrong is a link-time or run-time fault rather than a lost
dnl optimisation.
dnl
dnl This used to come from GCC's own auto-host.h, reaching a target library
dnl through GCC_TARGET_TEMPLATE -- a host build's recorded answer about somebody
dnl else's linker.  Asked here it drives $CC's linker, which is the one these
dnl objects will actually be linked with.  Same move HAVE_GAS_HIDDEN and
dnl HAVE_GAS_WEAK above already made.
dnl
dnl Only the two PE consumers care, so only PE hosts are probed; elsewhere the
dnl answer is unused and a link test would cost time for nothing.  The probe
dnl links rather than compiles, because the question is the LINKER's.
case "$host" in
  *-*-cygwin* | *-*-mingw*)
    AC_CACHE_CHECK([whether the linker mixes read-only and read-write sections],
		   [libgcc_cv_ld_ro_rw_mix], [
      cat > conftest_ro.s <<EOF
	.section .rdata,"dr"
	.long 1
EOF
      cat > conftest_rw.s <<EOF
	.section .rdata\$zzz,"dr"
	.long 2
EOF
      dnl A mixing linker places both inputs in one output section; one that
      dnl cannot will either error or leave them apart.  Failure to assemble is
      dnl reported as "no", which is the safe direction: crtbegin then uses
      dnl .data, which works either way.
      if AC_TRY_COMMAND([${CC-cc} $CFLAGS -c -o conftest_ro.o conftest_ro.s]) \
	 && AC_TRY_COMMAND([${CC-cc} $CFLAGS -c -o conftest_rw.o conftest_rw.s]) \
	 && AC_TRY_COMMAND([${CC-cc} $CFLAGS -nostdlib -r -o conftest_mix.o conftest_ro.o conftest_rw.o]); then
	libgcc_cv_ld_ro_rw_mix=yes
      else
	libgcc_cv_ld_ro_rw_mix=no
      fi
      rm -f conftest_ro.s conftest_rw.s conftest_ro.o conftest_rw.o conftest_mix.o])
    if test x$libgcc_cv_ld_ro_rw_mix = xyes; then
      AC_DEFINE(HAVE_LD_RO_RW_SECTION_MIXING, 1,
	[Define if your linker links a mix of read-only
	 and read-write sections into a read-write section.])
    fi
    ;;
esac

dnl The BSDs are the only ones that need looking at: elsewhere the answer
dnl follows from the C library, and on Solaris and musl it is unconditional.
dnl A separate cache variable rather than an AC_EGREP_HEADER nested inside an
dnl AC_MSG_CHECKING, so the "checking" lines do not interleave.
case "$host" in
  *-*-dragonfly* | *-*-freebsd*)
    AC_EGREP_HEADER([dl_iterate_phdr], [sys/link_elf.h],
		    [libgcc_cv_dl_iterate_phdr=yes],
		    [libgcc_cv_dl_iterate_phdr=no])
    ;;
  *-*-solaris2* | *-linux-musl*)
    libgcc_cv_dl_iterate_phdr=yes
    ;;
  *)
    libgcc_cv_dl_iterate_phdr=unknown
    ;;
esac
AC_MSG_CHECKING([for dl_iterate_phdr in the C library])
if test x$libgcc_cv_dl_iterate_phdr = xyes; then
  AC_DEFINE(TARGET_DL_ITERATE_PHDR, 1,
    [Define if your C library provides the `dl_iterate_phdr' function.])
fi
AC_MSG_RESULT($libgcc_cv_dl_iterate_phdr)

dnl Does the linker produce a PT_GNU_EH_FRAME segment?  This decides, for both
dnl crtstuff.c and unwind-dw2-fde-dip.c, whether exception frames are FOUND at
dnl unwind time through the program headers or REGISTERED by the startup files.
dnl The two must agree, so they read one answer.
dnl
dnl It was never libgcc's answer to give.  Tracing the real compile command with
dnl `-E -dD -H' shows exactly one definition of HAVE_LD_EH_FRAME_HDR reaching
dnl this library, and it comes from gcc's GENERATED tm.h, where gcc/mkconfig.sh
dnl writes an unconditional `#ifndef/#define 1'.  That default is right FOR GCC
dnl and its comment says why: target headers test the macro with #ifdef while
dnl composing spec strings, and the real answer arrives afterwards by
dnl target-specs/configure overriding the composed spec.  libgcc reads the same
dnl tm.h and has no spec to override -- the value is compiled into the object,
dnl permanently.  A default chosen for one consumer's benefit had become another
dnl consumer's answer, and on a target whose linker lacks --eh-frame-hdr it
dnl would surface as unwinding not working, three layers from the cause.
dnl
dnl NAMED DIFFERENTLY ON PURPOSE, and always given a value.  tm.h's guard is
dnl `#ifndef HAVE_LD_EH_FRAME_HDR', and auto-target.h is included BEFORE tm.h in
dnl both consumers.  A conventional AC_DEFINE emits nothing for a negative
dnl answer, so tm.h would then supply 1 and the "no" would be silently promoted
dnl to "yes" -- the negative is the only interesting result here, and it is
dnl exactly the one that could not survive that spelling.  0-or-1 under our own
dnl name cannot be overridden by anyone.
dnl
dnl GCC_NO_EXECUTABLES above means no test program can be linked, so ask the
dnl linker itself.  $CC is the compiler that will build this library, so
dnl -print-prog-name names the very linker these objects will go through.
AC_CACHE_CHECK([whether the linker produces PT_GNU_EH_FRAME],
	       [libgcc_cv_ld_eh_frame_hdr], [
  libgcc_cv_ld_eh_frame_hdr=no
  libgcc_ld=`$CC $CFLAGS $CPPFLAGS $LDFLAGS -print-prog-name=ld 2>/dev/null`
  if test -n "$libgcc_ld" \
     && $libgcc_ld --eh-frame-hdr --version >/dev/null 2>&1; then
    libgcc_cv_ld_eh_frame_hdr=yes
  fi])
if test x$libgcc_cv_ld_eh_frame_hdr = xyes; then
  libgcc_eh_frame_hdr=1
else
  libgcc_eh_frame_hdr=0
fi
AC_DEFINE_UNQUOTED(LIBGCC_HAVE_LD_EH_FRAME_HDR, [$libgcc_eh_frame_hdr],
  [Define to 1 if the linker produces a PT_GNU_EH_FRAME segment, 0 if not.
   Always given a value: a bare #undef would let gcc's tm.h supply 1.])

dnl Does the C library these objects will be linked against provide
dnl __cxa_atexit?  crtstuff.c uses the answer to decide whether it defines
dnl __dso_handle and calls __cxa_finalize from the startup files -- what runs
dnl at program startup and shutdown, compiled permanently into crtbegin.o.
dnl
dnl Until now it read gcc's DEFAULT_USE_CXA_ATEXIT out of auto-host.h, which is
dnl gcc's answer for the machine the COMPILER runs on, and which for every cross
dnl build is not a probe at all: gcc/configure.ac says in as many words that it
dnl cannot check when building a cross and assumes it is available.
dnl
dnl THREE OUTCOMES, NOT TWO, and the third is why this is not a plain probe.
dnl A from-scratch toolchain builds libgcc BEFORE it has a C library, so the
dnl question often cannot be asked at all.  An ordinary AC_DEFINE emits nothing
dnl in that case, gcc/defaults.h:1035 floors the macro to 0, and libgcc would
dnl record "this target has no __cxa_atexit" because nobody was there to answer.
dnl That is the same trap as LIBGCC_HAVE_LD_EH_FRAME_HDR above with the floor
dnl the other way up: there the floor promoted no to yes, here it converts
dnl unknown to no.  Same rule both times -- never let the absence of an answer
dnl BE an answer.  So the macro is ours, always valued, and carries its
dnl PROVENANCE, which is also printed by configure: two sources for one answer
dnl are only dangerous when they can disagree SILENTLY.
dnl
dnl The probe is a LINK, because the question is whether the symbol exists, not
dnl whether a header declares it -- __cxa_atexit is a C++ ABI entry point and is
dnl not reliably declared in <stdlib.h>, so a declaration test would report a
dnl present symbol as absent.  The test declares the function itself.
dnl GCC_NO_EXECUTABLES makes AC_LINK_IFELSE an m4 error, so the link is run by
dnl hand, and a control link runs FIRST: if that fails there is no usable C
dnl library and the probe reports unavailable rather than no.
dnl
dnl `-nostdlib -nostartfiles ... -lc' AND ITS OWN `_start' ARE THE WHOLE TRICK,
dnl and were arrived at by the probe failing first.  An ordinary link here is
dnl NOT a probe that sometimes cannot answer -- it can NEVER answer: libgcc's
dnl configure runs before libgcc is built, so the driver's own link spec asks
dnl for crtbegin.o and libgcc.a, which this very directory has not produced yet.
dnl Measured, on a perfectly ordinary native glibc build:
dnl   ld: cannot find crtbegin.o -> control fails -> "unavailable" -> 0
dnl A green build, a plausible provenance, and the answer taken from nobody.
dnl Dropping the start files and asking for -lc alone removes gcc's own
dnl not-yet-built artefacts from the question and leaves exactly the question
dnl asked: does the C LIBRARY resolve this symbol.  If -lc itself cannot be
dnl linked there is no C library, which is the real "unavailable".
AC_ARG_ENABLE([__cxa_atexit],
  [AS_HELP_STRING([--enable-__cxa_atexit],
    [declare whether __cxa_atexit is available, for when there is no C library
     to probe (a from-scratch bootstrap builds libgcc first)])],
  [], [enable___cxa_atexit=])

AC_CACHE_CHECK([whether the C library provides __cxa_atexit],
	       [libgcc_cv_cxa_atexit], [
  libgcc_cv_cxa_atexit=unavailable
  libgcc_cxa_link="$CC $CFLAGS $CPPFLAGS $LDFLAGS -nostdlib -nostartfiles"
  cat > conftest.c <<'_LIBGCC_EOF'
void _start (void) { }
_LIBGCC_EOF
  if $libgcc_cxa_link conftest.c -lc -o conftest$ac_exeext \
       >&AS_MESSAGE_LOG_FD 2>&1; then
    cat > conftest.c <<'_LIBGCC_EOF'
extern int __cxa_atexit (void (*) (void *), void *, void *);
void _start (void) { __cxa_atexit (0, 0, 0); }
_LIBGCC_EOF
    if $libgcc_cxa_link conftest.c -lc -o conftest$ac_exeext \
	 >&AS_MESSAGE_LOG_FD 2>&1; then
      libgcc_cv_cxa_atexit=yes
    else
      libgcc_cv_cxa_atexit=no
    fi
  fi
  rm -f conftest.c conftest$ac_exeext])

if test x$enable___cxa_atexit = xno; then
  dnl An explicit choice outranks a measurement: --disable- means do not use it
  dnl even where it exists, which is what gcc has always meant by the flag.
  libgcc_use_cxa_atexit=0
  libgcc_cxa_atexit_provenance=declared
else
  case $libgcc_cv_cxa_atexit in
    yes)
      libgcc_use_cxa_atexit=1
      libgcc_cxa_atexit_provenance=probed ;;
    no)
      libgcc_use_cxa_atexit=0
      libgcc_cxa_atexit_provenance=probed ;;
    *)
      if test x$enable___cxa_atexit = xyes; then
	libgcc_use_cxa_atexit=1
	libgcc_cxa_atexit_provenance=declared
      else
	libgcc_use_cxa_atexit=0
	libgcc_cxa_atexit_provenance=unavailable
      fi ;;
  esac
fi
AC_DEFINE_UNQUOTED(LIBGCC_USE_CXA_ATEXIT, [$libgcc_use_cxa_atexit],
  [Define to 1 if __cxa_atexit is to be used to register destructors, 0 if not.
   Always given a value: a bare #undef would let gcc's defaults.h supply 0, so
   "nobody could answer" would be recorded as "this target does not have it".])
AC_DEFINE_UNQUOTED(LIBGCC_CXA_ATEXIT_PROVENANCE, ["$libgcc_cxa_atexit_provenance"],
  [Where LIBGCC_USE_CXA_ATEXIT came from: "probed" (the C library was asked),
   "declared" (--enable/--disable-__cxa_atexit), or "unavailable" (no C library
   to ask and nothing declared, so the conservative 0 was used).])
AC_MSG_NOTICE([__cxa_atexit: LIBGCC_USE_CXA_ATEXIT=$libgcc_use_cxa_atexit (provenance: $libgcc_cxa_atexit_provenance)])

# Check for decimal float support.
AC_CACHE_CHECK([whether decimal floating point is supported], [libgcc_cv_dfp],
	       [AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <fenv.h>
]], [[
_Decimal32 x;
int fe_except =
  FE_INVALID|FE_DIVBYZERO|FE_OVERFLOW|FE_UNDERFLOW|FE_INEXACT;
]])],
				  [libgcc_cv_dfp=yes],
				  [libgcc_cv_dfp=no])])
decimal_float=$libgcc_cv_dfp
AC_SUBST(decimal_float)

GCC_AC_ENABLE_DECIMAL_FLOAT([$host])

# Check for fixed-point support.
AC_CACHE_CHECK([whether fixed-point is supported], [libgcc_cv_fixed_point],
	       [AC_COMPILE_IFELSE([AC_LANG_SOURCE([_Sat _Fract x;])],
	       			  [libgcc_cv_fixed_point=yes],
				  [libgcc_cv_fixed_point=no])])
fixed_point=$libgcc_cv_fixed_point
AC_SUBST(fixed_point)

# Check whether the compiler defines __PIE__ by default, so -fno-PIE is needed.
AC_CACHE_CHECK([whether the compiler defines __PIE__], [libgcc_cv_no_pie_cflags],
  [AC_COMPILE_IFELSE(
     [AC_LANG_PROGRAM([[
#ifdef __PIE__
#error __PIE__ defined
#endif
     ]], [[]])],
     [libgcc_cv_no_pie_cflags=''],
     [libgcc_cv_no_pie_cflags='-fno-PIE'])])

NO_PIE_CFLAGS=$libgcc_cv_no_pie_cflags
AC_SUBST([NO_PIE_CFLAGS])

# For platforms with the unwind ABI which includes an unwind library,
# libunwind, we can choose to use the system libunwind.
# config.gcc also contains tests of with_system_libunwind.
GCC_CHECK_UNWIND_GETIPINFO

# Check if the compiler is configured for setjmp/longjmp exceptions.
GCC_CHECK_SJLJ_EXCEPTIONS

GCC_CET_FLAGS(CET_FLAGS)
AC_SUBST(CET_FLAGS)

AC_ARG_ENABLE([explicit-exception-frame-registration],
  [AS_HELP_STRING([--enable-explicit-exception-frame-registration],
     [register exception tables explicitly at module start, for use
      e.g. for compatibility with installations without PT_GNU_EH_FRAME support])],
[
force_explicit_eh_registry=
if test "$enable_explicit_exception_frame_registration" = yes; then
  if test $ac_cv_sjlj_exceptions = yes; then
    AC_MSG_ERROR([Can't --enable-explicit-exception-frame-registration
                  with setjmp/longjmp exceptions])
  fi
  force_explicit_eh_registry=-DUSE_EH_FRAME_REGISTRY_ALWAYS
fi
])
AC_SUBST([force_explicit_eh_registry])

AC_ARG_ENABLE([tm-clone-registry],
[  --disable-tm-clone-registry    disable TM clone registry],
[
use_tm_clone_registry=
if test "$enable_tm_clone_registry" = no; then
  use_tm_clone_registry=-DUSE_TM_CLONE_REGISTRY=0
fi
],
[
use_tm_clone_registry=
case $target in
  msp430*elfbare)
   use_tm_clone_registry=-DUSE_TM_CLONE_REGISTRY=0
   ;;
esac
])
AC_SUBST([use_tm_clone_registry])

AC_LIB_PROG_LD_GNU

GCC_AC_THREAD_MODEL

# Check for assembler CFI support.
AC_CACHE_CHECK([whether assembler supports CFI directives], [libgcc_cv_cfi],
	       [AC_COMPILE_IFELSE(
[AC_LANG_SOURCE([asm("\n\
	.text\n\
	.cfi_startproc\n\
	.cfi_personality 0, symbol\n\
	.cfi_endproc");])],
  [libgcc_cv_cfi=yes],
  [libgcc_cv_cfi=no])])

# Check 32bit or 64bit.  In the case of MIPS, this really determines the
# word size rather than the address size.
cat > conftest.c <<EOF
#if defined(__x86_64__) || (!defined(__i386__) && defined(__LP64__)) \
    || defined(__mips64) || defined(__loongarch64)
host_address=64
#else
host_address=32
#endif
EOF
eval `${CC-cc} -E conftest.c | grep host_address=`
rm -f conftest.c

case ${host} in
mips*-*-*)
  AC_CACHE_CHECK([whether the target is hard-float],
		 [libgcc_cv_mips_hard_float],
		 [AC_COMPILE_IFELSE(
    [AC_LANG_SOURCE([#ifndef __mips_hard_float
     #error FOO
     #endif
    ])],
    [libgcc_cv_mips_hard_float=yes],
    [libgcc_cv_mips_hard_float=no])])
esac

# Determine the version of glibc, if any, used on the target.
AC_MSG_CHECKING([for target glibc version])
AC_ARG_WITH([glibc-version],
  [AS_HELP_STRING([--with-glibc-version=M.N],
    [assume GCC used with glibc version M.N or later])], [
if [echo "$with_glibc_version" | grep '^[0-9][0-9]*\.[0-9][0-9]*$']; then
  glibc_version_major=`echo "$with_glibc_version" | sed -e 's/\..*//'`
  glibc_version_minor=`echo "$with_glibc_version" | sed -e 's/.*\.//'`
else
  AC_MSG_ERROR([option --with-glibc-version requires a version number M.N])
fi], [
AC_COMPUTE_INT([glibc_version_major], [__GLIBC__],
				      [#include <features.h>],
				      [glibc_version_major=0])
AC_COMPUTE_INT([glibc_version_minor], [__GLIBC_MINOR__],
				      [#include <features.h>],
				      [glibc_version_minor=0])])
AC_MSG_RESULT([$glibc_version_major.$glibc_version_minor])

# Determine floating-point type for powerpc*-*-linux* or vxworks7*.
# Single-precision-only FPRs are not a supported configuration for
# this target, so are not allowed for in this test.
case ${host} in
powerpc*-*-linux* | powerpc*-*-vxworks7*)
  cat > conftest.c <<EOF
#ifdef __powerpc64__
ppc_fp_type=64
#elif defined _SOFT_FLOAT
ppc_fp_type=soft
#elif defined _SOFT_DOUBLE
ppc_fp_type=e500v1
#elif defined __NO_FPRS__
ppc_fp_type=e500v2
#else
ppc_fp_type=hard
#endif
EOF
eval `${CC-cc} -E conftest.c | grep ppc_fp_type=`
rm -f conftest.c
# glibc 2.19 and later provide all the soft-fp functions, with proper
# interactions with <fenv.h> exception and rounding mode handling, so
# make libgcc's versions into compat symbols if a recent enough glibc
# version is being used.
ppc_fp_compat=
case ${ppc_fp_type} in
soft|e500v1|e500v2)
  if test $glibc_version_major -gt 2 \
    || ( test $glibc_version_major -eq 2 \
        && test $glibc_version_minor -ge 19 ); then
    ppc_fp_compat="t-softfp-compat"
  fi
  ;;
esac
;;
esac

case ${host} in
# At present, we cannot turn -mfloat128 on via #pragma GCC target, so just
# check if we have VSX (ISA 2.06) support to build the software libraries, and
# whether the assembler can handle xsaddqp for hardware support.  Also check if
# a new glibc is being used so that __builtin_cpu_supports can be used.
powerpc*-*-linux*)
  saved_CFLAGS="$CFLAGS"
  CFLAGS="$CFLAGS -mabi=altivec -mvsx -mfloat128"
  AC_CACHE_CHECK([for PowerPC ISA 2.06 to build __float128 libraries],
		 [libgcc_cv_powerpc_float128],
		 [AC_COMPILE_IFELSE(
    [AC_LANG_SOURCE([vector double dadd (vector double a, vector double b) { return a + b; }])],
    [libgcc_cv_powerpc_float128=yes],
    [libgcc_cv_powerpc_float128=no])])

  CFLAGS="$CFLAGS -mcpu=power9 -mfloat128-hardware"
  AC_CACHE_CHECK([for PowerPC ISA 3.0 to build hardware __float128 libraries],
		 [libgcc_cv_powerpc_float128_hw],
		 [AC_COMPILE_IFELSE(
    [AC_LANG_SOURCE([#include <sys/auxv.h>
     #ifndef AT_PLATFORM
     #error "AT_PLATFORM is not defined"
     #endif
     #ifndef __BUILTIN_CPU_SUPPORTS__
     #error "__builtin_cpu_supports is not available"
     #endif
     vector unsigned char add (vector unsigned char a, vector unsigned char b)
     {
       vector unsigned char ret;
       __asm__ ("xsaddqp %0,%1,%2" : "=v" (ret) : "v" (a), "v" (b));
       return ret;
     }
     void *add_resolver (void) { return (void *) add; }
     __float128 add_ifunc (__float128, __float128)
	__attribute__ ((__ifunc__ ("add_resolver")));])],
    [libgcc_cv_powerpc_float128_hw=yes],
    [libgcc_cv_powerpc_float128_hw=no])])
  CFLAGS="$saved_CFLAGS"

  saved_CFLAGS="$CFLAGS"
  CFLAGS="$CFLAGS -mcpu=power10 -mfloat128-hardware"
  AC_CACHE_CHECK([for PowerPC ISA 3.1 to build hardware __float128 libraries],
		 [libgcc_cv_powerpc_3_1_float128_hw],
		 [AC_COMPILE_IFELSE(
    [AC_LANG_SOURCE([#include <sys/auxv.h>
     #ifndef AT_PLATFORM
     #error "AT_PLATFORM is not defined"
     #endif
     #ifndef __BUILTIN_CPU_SUPPORTS__
     #error "__builtin_cpu_supports is not available"
     #endif
     vector unsigned char conv (vector unsigned char qs)
     {
       vector unsigned char ret;
       __asm__ ("xscvsqqp %0,%1" : "=v" (ret) : "v" (qs));
       return ret;
     }
     void *conv_resolver (void) { return (void *) conv; }
     __float128 conv_ifunc (__float128)
	__attribute__ ((__ifunc__ ("conv_resolver")));])],
    [libgcc_cv_powerpc_3_1_float128_hw=yes],
    [libgcc_cv_powerpc_3_1_float128_hw=no])])
  CFLAGS="$saved_CFLAGS"
esac

case ${host} in
s390x-*-linux*)
  AC_CACHE_CHECK([Support float16 on s390],
		 [libgcc_cv_s390_float16],
		 [AC_COMPILE_IFELSE(
    [AC_LANG_SOURCE([#if ! __s390x__ || __ARCH__ < 8
     # error "HF not supported"
     #endif
     ])],
    [libgcc_cv_s390_float16=yes],
    [libgcc_cv_s390_float16=no])])
  ;;
esac

# Collect host-machine-specific information.
. ${srcdir}/config.host

# Used for constructing correct paths for offload compilers.
accel_dir_suffix=
real_host_noncanonical=${host_noncanonical}
if test x"$enable_as_accelerator_for" != x; then
  accel_dir_suffix=/accel/${target_noncanonical}
  real_host_noncanonical=${enable_as_accelerator_for}
fi
AC_SUBST(accel_dir_suffix)
AC_SUBST(real_host_noncanonical)

if test x"$enable_offload_targets" != x; then
  extra_parts="${extra_parts} crtoffloadbegin.o crtoffloadend.o"
  extra_parts="${extra_parts} crtoffloadtable.o crtoffloadtableS.o"
fi

# Check if Solaris/x86 linker supports ZERO terminator unwind entries.
# This is after config.host so we can augment tmake_file.
# Link with -nostartfiles -nodefaultlibs since neither are present while
# building libgcc.
case ${host} in
i?86-*-solaris2* | x86_64-*-solaris2*)
  cat > conftest.s <<EOF
	.section	.eh_frame,"a",@unwind
	.zero	4
	.section	.jcr,"aw",@progbits
	.zero	8
EOF
  if AC_TRY_COMMAND(${CC-cc} -shared -nostartfiles -nodefaultlibs -o conftest.so conftest.s 1>&AS_MESSAGE_LOG_FD); then
      tmake_file="${tmake_file} i386/t-crtstuff"
  fi
  ;;
esac

case ${host} in
loongarch32*-*-*)
  tmake_file="${tmake_file} loongarch/t-crtstuff-la32"
  ;;
esac

case ${host} in
loongarch64*-*-*)
  tmake_file="${tmake_file} loongarch/t-crtstuff-la64"
  ;;
esac

# Check if xtensa target is configured for windowed ABI and thus needs to use
# custom unwind code.
# This is after config.host so we can augment tmake_file.
case ${host} in
xtensa*-*)
  AC_COMPILE_IFELSE([AC_LANG_SOURCE(
		     [#ifdef __XTENSA_CALL0_ABI__
		      #error
		      #endif
		      ])],
		      [tmake_file="${tmake_file} xtensa/t-windowed"])
  ;;
esac

# Check for visibility support.  This is after config.host so that
# we can check for asm_hidden_op.
AC_CACHE_CHECK([for __attribute__((visibility("hidden")))],
    libgcc_cv_hidden_visibility_attribute, [
	echo 'int __attribute__ ((visibility ("hidden"))) foo (void) { return 1; }' > conftest.c
	libgcc_cv_hidden_visibility_attribute=no
	if AC_TRY_COMMAND(${CC-cc} -Werror -S conftest.c -o conftest.s 1>&AS_MESSAGE_LOG_FD); then
	    if grep "\\$asm_hidden_op.*foo" conftest.s >/dev/null; then
		libgcc_cv_hidden_visibility_attribute=yes
	    fi
	fi
	rm -f conftest.*
    ])

if test $libgcc_cv_hidden_visibility_attribute = yes; then
    vis_hide='-fvisibility=hidden -DHIDE_EXPORTS'
    AC_DEFINE_UNQUOTED(AS_HIDDEN_DIRECTIVE, $asm_hidden_op, [Define to the .hidden-like directive if it exists.])
else
    vis_hide=
fi
AC_SUBST(vis_hide)

# Check for .cfi_sections .debug_frame support.
AC_CACHE_CHECK([for .cfi_sections .debug_frame],
    libgcc_cv_cfi_sections_directive, [
	echo 'int foo (int, char *);' > conftest.c
	echo 'int bar (int x) { char *y = __builtin_alloca (x); return foo (x + 1, y) + 1; }' >> conftest.c
	libgcc_cv_cfi_sections_directive=no
	if AC_TRY_COMMAND(${CC-cc} -Werror -g -fno-asynchronous-unwind-tables -fno-unwind-tables -fno-exceptions -S conftest.c -o conftest.s 1>&AS_MESSAGE_LOG_FD); then
	    if grep "\\.cfi_sections.*\\.debug_frame" conftest.s >/dev/null; then
		libgcc_cv_cfi_sections_directive=yes
	    fi
	fi
	rm -f conftest.*
    ])
if test $libgcc_cv_cfi_sections_directive = yes; then
    AC_DEFINE(HAVE_AS_CFI_SECTIONS, 1, [Define to 1 if the assembler supports .cfi_sections .debug_frame directive.])
fi

# See if we have thread-local storage.  We can only test assembler
# since link-time and run-time tests require the newly built
# gcc, which can't be used to build executable due to that libgcc
# is yet to be built here.
GCC_CHECK_CC_TLS
set_have_cc_tls=
if test "$enable_tls $gcc_cv_have_cc_tls" = "yes yes"; then
  set_have_cc_tls="-DHAVE_CC_TLS"
fi
AC_SUBST(set_have_cc_tls)

# See if we have emulated thread-local storage.
GCC_CHECK_EMUTLS
set_use_emutls=
if test "$enable_tls $gcc_cv_use_emutls" = "yes yes"; then
  set_use_emutls="-DUSE_EMUTLS"
fi
AC_SUBST(set_use_emutls)

dnl Check if as supports AVX instructions.
AC_DEFUN([LIBGCC_CHECK_AS_AVX], [
case "${target}" in
i[[34567]]86-*-* | x86_64-*-*)
  AC_CACHE_CHECK([if the assembler supports AVX], libgcc_cv_as_avx, [
    AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[]], [[asm("vzeroupper");]])],
		   [libgcc_cv_as_avx=yes], [libgcc_cv_as_avx=no])
  ])
  if test x$libgcc_cv_as_avx = xyes; then
    AC_DEFINE(HAVE_AS_AVX, 1, [Define to 1 if the assembler supports AVX.])
  fi
  ;;
esac])
LIBGCC_CHECK_AS_AVX

dnl Check if as supports LSE instructions.
AC_DEFUN([LIBGCC_CHECK_AS_LSE], [
case "${target}" in
aarch64*-*-*)
  AC_CACHE_CHECK([if the assembler supports LSE], libgcc_cv_as_lse, [
    AC_COMPILE_IFELSE(
      [AC_LANG_PROGRAM([[]],
			[[asm(".arch armv8-a+lse\n\tcas w0, w1, [x2]");]])],
		   [libgcc_cv_as_lse=yes], [libgcc_cv_as_lse=no])
  ])
  if test x$libgcc_cv_as_lse = xyes; then
    AC_DEFINE(HAVE_AS_LSE, 1, [Define to 1 if the assembler supports LSE.])
  fi
  ;;
esac])
LIBGCC_CHECK_AS_LSE

dnl Check if as supports .variant_pcs.
AC_DEFUN([LIBGCC_CHECK_AS_VARIANT_PCS], [
case "${target}" in
aarch64*-*-*)
  AC_CACHE_CHECK([if as supports .variant_pcs], libgcc_cv_as_variant_pcs, [
    AC_COMPILE_IFELSE([AC_LANG_PROGRAM(,
      [[asm (".variant_pcs foobar");]])],
      [libgcc_cv_as_variant_pcs=yes], [libgcc_cv_as_variant_pcs=no])
  ])
  if test x$libgcc_cv_as_variant_pcs = xyes; then
    AC_DEFINE(HAVE_AS_VARIANT_PCS, 1,
	      [Define to 1 if the assembler supports .variant_pcs.])
  fi
  ;;
esac])
LIBGCC_CHECK_AS_VARIANT_PCS

# Check __getauxval ABI symbol for CPU feature detection.
case ${target} in
aarch64*-linux-*)
  # No link check because the libc may not be present.
  AC_CACHE_CHECK([for __getauxval],
		 [libgcc_cv_have___getauxval],
		 [case ${target} in
		  *-linux-gnu*)
		    libgcc_cv_have___getauxval=yes
		    ;;
		  *)
		    libgcc_cv_have___getauxval=no
		  esac])
  if test x$libgcc_cv_have___getauxval = xyes; then
    AC_DEFINE(HAVE___GETAUXVAL, 1,
	      [Define to 1 if __getauxval is available.])
  fi
esac

dnl Check if as supports RTM instructions.
AC_CACHE_CHECK(for init priority support, libgcc_cv_init_priority, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM(,
  [[void ip (void) __attribute__ ((constructor (1)));]])],
  [libgcc_cv_init_priority=yes],[libgcc_cv_init_priority=no])])
if test $libgcc_cv_init_priority = yes; then
  AC_DEFINE(HAVE_INIT_PRIORITY, 1,
  [Define if the compiler supports init priority.])
fi

# Conditionalize the sfp-machine.h header for this target machine.
if test -z "${sfp_machine_header}"; then
	sfp_machine_header=$cpu_type/sfp-machine.h
	if test -f ${srcdir}/config/${sfp_machine_header}; then
		:
	else
		sfp_machine_header=no-sfp-machine.h
	fi
fi
AC_SUBST(sfp_machine_header)

# Conditionalize the makefile for this target machine.
tmake_file_=
for f in ${tmake_file}
do
	if test -f ${srcdir}/config/$f
	then
		tmake_file_="${tmake_file_} \$(srcdir)/config/$f"
	fi
done
tmake_file="${tmake_file_}"
AC_SUBST(tmake_file)

# Likewise export definitions for libgcc_tm.h
tm_file_=
for f in ${tm_file}
do
	tm_file_="${tm_file_} \$(srcdir)/config/$f"
done
tm_file="${tm_file_}"
AC_SUBST(tm_file)
AC_SUBST(tm_defines)

# Map from thread model to thread header.
GCC_AC_THREAD_HEADER([$target_thread_file])

AC_CACHE_CHECK([for strub support],
  [libgcc_cv_strub_support],
  [AC_COMPILE_IFELSE(
    [AC_LANG_SOURCE([void __attribute__ ((__strub__)) fn (void) {}])],
    [libgcc_cv_strub_support=yes],
    [libgcc_cv_strub_support=no])])
if test "x$libgcc_cv_strub_support" != xno; then
  HAVE_STRUB_SUPPORT=
else
  HAVE_STRUB_SUPPORT='# '
fi
AC_SUBST(HAVE_STRUB_SUPPORT)

# Determine what GCC version number to use in filesystem paths.
GCC_BASE_VER

# Substitute configuration variables
AC_SUBST(cpu_type)
AC_SUBST(extra_parts)
AC_SUBST(asm_hidden_op)
AC_SUBST(enable_execute_stack)
AC_SUBST(unwind_header)
AC_SUBST(md_unwind_def_header)
AC_SUBST(md_unwind_header)
AC_SUBST(sfp_machine_header)
AC_SUBST(thread_header)

AC_ARG_ENABLE(werror,
[AS_HELP_STRING([--enable-werror],
		[build with -Werror for selected targets])],
[
case ${enable_werror} in
  no) WERROR="" ;;
  *) WERROR="-Werror" ;;
esac
],
[
WERROR="-Werror"
])
AC_SUBST(WERROR)

# We need multilib support.
AC_CONFIG_FILES([Makefile])
AC_CONFIG_COMMANDS([default],
  [[test -z "$CONFIG_HEADERS" || echo timestamp > stamp-h
if test -n "$CONFIG_FILES"; then
  # FIXME: We shouldn't need to set ac_file
  ac_file=Makefile
  . ${libgcc_topdir}/config-ml.in
fi]],
[[srcdir=${srcdir}
host=${host}
with_target_subdir=${with_target_subdir}
with_multisubdir=${with_multisubdir}
ac_configure_args="--enable-multilib ${ac_configure_args}"
CONFIG_SHELL=${CONFIG_SHELL-/bin/sh}
libgcc_topdir=${libgcc_topdir}
CC="${CC}"
]])
AC_OUTPUT
