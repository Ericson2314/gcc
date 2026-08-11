# configure.ac for GCC
# Process this file with autoconf to generate a configuration script.

# Copyright (C) 1997-2026 Free Software Foundation, Inc.

#This file is part of GCC.

#GCC is free software; you can redistribute it and/or modify it under
#the terms of the GNU General Public License as published by the Free
#Software Foundation; either version 3, or (at your option) any later
#version.

#GCC is distributed in the hope that it will be useful, but WITHOUT
#ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
#for more details.

#You should have received a copy of the GNU General Public License
#along with GCC; see the file COPYING3.  If not see
#<http://www.gnu.org/licenses/>.

# --------------------------------
# Initialization and sanity checks
# --------------------------------

AC_INIT
AC_CONFIG_SRCDIR(tree.cc)
AC_CONFIG_MACRO_DIRS([../config] [..])
AC_CONFIG_HEADER(auto-host.h:config.in)

gcc_version=`cat $srcdir/BASE-VER`

# Determine the host and build systems
AC_CANONICAL_BUILD
AC_CANONICAL_HOST

# Determine the noncanonical build name, and the noncanonical host name for Ada.
ACX_NONCANONICAL_BUILD
ACX_NONCANONICAL_HOST

# Used for constructing correct paths for offload compilers.
accel_dir_suffix=

# Determine the build- and host-specific subdirectories.  GCC_TOPLEV_SUBDIRS
# would do this, but it also derives a target_subdir and requires a canonical
# target for it.
build_subdir="build-${build_noncanonical}"
if ( test $srcdir = . && test -d ../gcc ) \
   || test -d $srcdir/../host-${host_noncanonical}; then
  host_subdir="host-${host_noncanonical}"
else
  host_subdir=.
fi
AC_SUBST(host_subdir)
AC_ARG_WITH(build-libsubdir,
[AS_HELP_STRING([--with-build-libsubdir=DIR],
		[directory where to find libraries for build system])],
build_libsubdir="$withval",
build_libsubdir="$build_subdir")
AC_SUBST(build_libsubdir)

# Set program_transform_name
AC_ARG_PROGRAM

# Check for bogus environment variables.
# Test if LIBRARY_PATH contains the notation for the current directory
# since this would lead to problems installing/building glibc.
# LIBRARY_PATH contains the current directory if one of the following
# is true:
# - one of the terminals (":" and ";") is the first or last sign
# - two terminals occur directly after each other
# - the path contains an element with a dot in it
AC_MSG_CHECKING(LIBRARY_PATH variable)
changequote(,)dnl
case ${LIBRARY_PATH} in
  [:\;]* | *[:\;] | *[:\;][:\;]* |  *[:\;]. | .[:\;]*| . | *[:\;].[:\;]* )
    library_path_setting="contains current directory"
    ;;
  *)
    library_path_setting="ok"
    ;;
esac
changequote([,])dnl
AC_MSG_RESULT($library_path_setting)
if test "$library_path_setting" != "ok"; then
AC_MSG_ERROR([
*** LIBRARY_PATH shouldn't contain the current directory when
*** building gcc. Please change the environment variable
*** and run configure again.])
fi

# Test if GCC_EXEC_PREFIX contains the notation for the current directory
# since this would lead to problems installing/building glibc.
# GCC_EXEC_PREFIX contains the current directory if one of the following
# is true:
# - one of the terminals (":" and ";") is the first or last sign
# - two terminals occur directly after each other
# - the path contains an element with a dot in it
AC_MSG_CHECKING(GCC_EXEC_PREFIX variable)
changequote(,)dnl
case ${GCC_EXEC_PREFIX} in
  [:\;]* | *[:\;] | *[:\;][:\;]* |  *[:\;]. | .[:\;]*| . | *[:\;].[:\;]* )
    gcc_exec_prefix_setting="contains current directory"
    ;;
  *)
    gcc_exec_prefix_setting="ok"
    ;;
esac
changequote([,])dnl
AC_MSG_RESULT($gcc_exec_prefix_setting)
if test "$gcc_exec_prefix_setting" != "ok"; then
AC_MSG_ERROR([
*** GCC_EXEC_PREFIX shouldn't contain the current directory when
*** building gcc. Please change the environment variable
*** and run configure again.])
fi

# -----------
# Directories
# -----------

# Specify the local prefix
local_prefix=
AC_ARG_WITH(local-prefix,
[AS_HELP_STRING([--with-local-prefix=DIR],
		[specifies directory to put local include])],
[case "${withval}" in
yes)	AC_MSG_ERROR(bad value ${withval} given for local include directory prefix) ;;
no)	;;
*)	local_prefix=$with_local_prefix ;;
esac])

# Default local prefix if it is empty
if test x$local_prefix = x; then
	local_prefix=/usr/local
fi

AC_ARG_WITH([native-system-header-dir],
  [  --with-native-system-header-dir=dir
                          use dir as the directory to look for standard
                          system header files in.  Defaults to /usr/include.],
[
 case ${with_native_system_header_dir} in
 yes|no) AC_MSG_ERROR([bad value ${withval} given for --with-native-system-header-dir]) ;;
 /* | [[A-Za-z]]:[[\\/]]*) ;;
 *) AC_MSG_ERROR([--with-native-system-header-dir argument ${withval} must be an absolute directory]) ;;
 esac
 configured_native_system_header_dir="${withval}"
], [configured_native_system_header_dir=])

AC_ARG_WITH(build-sysroot, 
  [AS_HELP_STRING([--with-build-sysroot=sysroot],
                  [use sysroot as the system root during the build])],
  [if test x"$withval" != x ; then
     SYSROOT_CFLAGS_FOR_TARGET="--sysroot=$withval"
   fi],
  [SYSROOT_CFLAGS_FOR_TARGET=])
AC_SUBST(SYSROOT_CFLAGS_FOR_TARGET)

if test "x$prefix" = xNONE; then
 test_prefix=/usr/local
else
 test_prefix=$prefix
fi
if test "x$exec_prefix" = xNONE; then
 test_exec_prefix=$test_prefix
else
 test_exec_prefix=$exec_prefix
fi


# Don't set gcc_gxx_include_dir to gxx_include_dir since that's only
# passed in by the toplevel make and thus we'd get different behavior
# depending on where we built the sources.
gcc_gxx_include_dir=
# Specify the g++ header file directory
AC_ARG_WITH(gxx-include-dir,
[AS_HELP_STRING([--with-gxx-include-dir=DIR],
                [specifies directory to put g++ header files])],
[case "${withval}" in
yes)	AC_MSG_ERROR(bad value ${withval} given for g++ include directory) ;;
no)	;;
*)	gcc_gxx_include_dir=$with_gxx_include_dir ;;
esac])

# If both --with-sysroot and --with-gxx-include-dir are passed, we interpolate
# the former in the latter and, upon success, compute gcc_gxx_include_dir as
# relative to the sysroot.
gcc_gxx_include_dir_add_sysroot=0

# This logic must match libstdc++-v3/acinclude.m4:GLIBCXX_EXPORT_INSTALL_INFO.
if test x${gcc_gxx_include_dir} = x; then
  gcc_gxx_include_dir="\$(libsubdir)/\$(libsubdir_to_prefix)include/c++/\$(version)"
fi

# Configuration for an alternate set of C++ headers.
gcc_gxx_libcxx_include_dir=
# Specify the alternate g++ header file directory
AC_ARG_WITH(gxx-libcxx-include-dir,
[AS_HELP_STRING([--with-gxx-libcxx-include-dir=DIR],
                [specifies directory to find libc++ header files])],
[case "${withval}" in
yes)	AC_MSG_ERROR(bad value ${withval} given for libc++ include directory) ;;
*)	gcc_gxx_libcxx_include_dir=$with_gxx_libcxx_include_dir ;;
esac])

# --with-gxx-libcxx-include-dir controls the enabling of the -stdlib option.
# if --with-gxx-libcxx-include-dir is 'no' we disable the stdlib option.
# if --with-gxx-libcxx-include-dir is unset we enable the stdlib option
# based on the platform (to be available on platform versions where it is the
# default for the system tools). We also use a default path within the compiler
# install tree.
# Otherwise, we use the path provided and enable the stdlib option.
# If both --with-sysroot and --with-gxx-libcxx-include-dir are passed, we
# check to see if the latter starts with the former and, upon success, compute
# gcc_gxx_libcxx_include_dir as relative to the sysroot.
gcc_gxx_libcxx_include_dir_add_sysroot=0
gcc_enable_stdlib_opt=0
if test x${gcc_gxx_libcxx_include_dir} != x; then
  if test x${gcc_gxx_libcxx_include_dir} = xno; then
    # set defaults for the dir, but the option is disabled anyway.
    gcc_gxx_libcxx_include_dir=
  else
    gcc_enable_stdlib_opt=1
  fi
else
  dnl A `case $target' turned -stdlib= on by default for Darwin 11 and later,
  dnl on the grounds that those releases default to libc++.  That is a statement
  dnl about a target, made before any target is chosen, and in a compiler
  dnl serving 183 of them it decided the question for all of them from one
  dnl triple.
  dnl
  dnl It is NOT replaced by a target-specs probe, because the consumer cannot
  dnl take a runtime answer: c-family/c.opt:2882 carries
  dnl `Condition(ENABLE_STDLIB_OPTION)' on -stdlib=, which the option machinery
  dnl resolves when options.cc is COMPILED -- it decides whether the option
  dnl EXISTS, not what it defaults to.  So the option is enabled
  dnl unconditionally: a target whose C++ runtime has no libc++ then has
  dnl nothing to select with it, which is a rejected argument rather than a
  dnl silently wrong default, and that is the direction to fail in.
  gcc_enable_stdlib_opt=1
fi
AC_DEFINE_UNQUOTED(ENABLE_STDLIB_OPTION, $gcc_enable_stdlib_opt,
          [Define if the -stdlib= option should be enabled.])

if test x${gcc_gxx_libcxx_include_dir} = x; then
  # default path, embedded in the compiler tree.
  libcxx_incdir='include/c++/v1'
  gcc_gxx_libcxx_include_dir="\$(libsubdir)/\$(libsubdir_to_prefix)$libcxx_incdir"
fi

AC_ARG_WITH(cpp_install_dir,
[AS_HELP_STRING([--with-cpp-install-dir=DIR],
                [install the user visible C preprocessor in DIR
                 (relative to PREFIX) as well as PREFIX/bin])],
[if test x$withval = xyes; then
  AC_MSG_ERROR([option --with-cpp-install-dir requires an argument])
elif test x$withval != xno; then
  cpp_install_dir=$withval
fi])

# We would like to our source tree to be readonly.  However when releases or
# pre-releases are generated, the flex/bison generated files as well as the 
# various formats of manuals need to be included along with the rest of the
# sources.  Therefore we have --enable-generated-files-in-srcdir to do 
# just that.

AC_MSG_CHECKING([whether to place generated files in the source directory])
  dnl generated-files-in-srcdir is disabled by default
  AC_ARG_ENABLE(generated-files-in-srcdir, 
    [AS_HELP_STRING([--enable-generated-files-in-srcdir],
		    [put copies of generated files in source dir
		     intended for creating source tarballs for users
		     without texinfo bison or flex])],
      generated_files_in_srcdir=$enableval,
      generated_files_in_srcdir=no)

AC_MSG_RESULT($generated_files_in_srcdir)

if test "$generated_files_in_srcdir" = "yes"; then
  GENINSRC=''
else
  GENINSRC='#'
fi
AC_SUBST(GENINSRC)

# -------------------
# Find default linker
# -------------------


# --with-demangler-in-ld is gone.  It only ever turned the linker --demangle
# probe off; its default -- run the probe -- is now the only behaviour, and
# whether a particular ld supports --demangle is a question for that ld, asked
# by target-specs after the build rather than by this script.
demangler_in_ld=yes

dsymutil_vers=


# ---------------
# Find C compiler
# ---------------

# If a non-executable a.out is present (e.g. created by GNU as above even if
# invoked with -v only), the IRIX 6 native ld just overwrites the existing
# file, even when creating an executable, so an execution test fails.
# Remove possible default executable files to avoid this.
#
# FIXME: This really belongs into AC_PROG_CC and can be removed once
# Autoconf includes it.
rm -f a.out a.exe b.out

# Find the native compiler
AC_PROG_CC
AC_PROG_CXX
ACX_PROG_GNAT([-I"$srcdir"/ada/libgnat])
ACX_PROG_GDC([-I"$srcdir"/d])

# Do configure tests with the C++ compiler, since that's what we build with.
AC_LANG(C++)

# Remove all -O flags: for historical reasons, unless bootstrapping we prefer
# optimizations to be activated explicitly by the toplevel.
case "$CC" in
  */prev-gcc/xgcc*) ;;
  *)
    new_CFLAGS=
    for flag in $CFLAGS; do
      case $flag in
	-O*) ;;
	*) new_CFLAGS="$new_CFLAGS $flag" ;;
      esac
    done
    CFLAGS=$new_CFLAGS
    new_CXXFLAGS=
    for flag in $CXXFLAGS; do
      case $flag in
	-O*) ;;
	*) new_CXXFLAGS="$new_CXXFLAGS $flag" ;;
      esac
    done
    CXXFLAGS=$new_CXXFLAGS
    ;;
esac
AC_SUBST(CFLAGS)
AC_SUBST(CXXFLAGS)
AC_SUBST(GDCFLAGS)


# -------------------------
# Check C compiler features
# -------------------------

AC_USE_SYSTEM_EXTENSIONS

AC_PROG_CPP
AC_C_INLINE

AC_SYS_LARGEFILE
AC_CHECK_SIZEOF(ino_t)
AC_CHECK_SIZEOF(dev_t)

# Select the right stat being able to handle 64bit inodes, if needed.
if test "$enable_largefile" != no; then
  case "$host, $build" in
    *-*-aix*,*|*,*-*-aix*)
      if test "$ac_cv_sizeof_ino_t" = "4" -a "$ac_cv_sizeof_dev_t" = 4; then
	AC_DEFINE(HOST_STAT_FOR_64BIT_INODES, stat64x,
	  [Define which stat syscall is able to handle 64bit indodes.])
      fi;;
  esac
fi


# sizeof(char) is 1 by definition.
AC_CHECK_SIZEOF(void *)
AC_CHECK_SIZEOF(short)
AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(long)
AC_CHECK_TYPES([long long], [AC_CHECK_SIZEOF(long long)])
GCC_STDINT_TYPES
if test x"$ac_cv_c_uint64_t" = x"no" -o x"$ac_cv_c_int64_t" = x"no"; then
  AC_MSG_ERROR([uint64_t or int64_t not found])
fi

# check what underlying integer type int64_t uses
AC_CACHE_CHECK(for int64_t underlying type, ac_cv_int64_t_type, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif
template <typename T> struct X { };
template <>
struct X<long> { typedef long t; };
]], [[X<int64_t>::t x;]])],[ac_cv_int64_t_type=long],[ac_cv_int64_t_type="long long"])])
if test "$ac_cv_int64_t_type" = "long"; then
  AC_DEFINE(INT64_T_IS_LONG, 1,
  [Define if int64_t uses long as underlying type.])
else
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif
template <typename T> struct X { };
template <>
struct X<long long> { typedef long long t; };
]], [[X<int64_t>::t x;]])],[],[AC_MSG_ERROR([error verifying int64_t uses long long])])
fi

AC_CACHE_CHECK(for std::swap in <utility>, ac_cv_std_swap_in_utility, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <utility>
]], [[int a, b; std::swap(a,b);]])],[ac_cv_std_swap_in_utility=yes],[ac_cv_std_swap_in_utility=no])])
if test $ac_cv_std_swap_in_utility = yes; then
  AC_DEFINE(HAVE_SWAP_IN_UTILITY, 1,
  [Define if <utility> defines std::swap.])
fi

# ---------------------
# Warnings and checking
# ---------------------

# Check $CC warning features (if it's GCC).
# We want to use -pedantic, but we don't want warnings about
# * 'long long'
# * variadic macros
# * overlong strings
# So, we only use -pedantic if we can disable those warnings.

# In stage 1, disable -Wformat warnings from old GCCs about new % codes
AC_ARG_ENABLE(build-format-warnings,
  AS_HELP_STRING([--disable-build-format-warnings],[don't use -Wformat while building GCC]),
  [],[enable_build_format_warnings=yes])
AS_IF([test $enable_build_format_warnings = no],
      [wf_opt=-Wno-format],[wf_opt=])
ACX_PROG_CXX_WARNING_OPTS(
	m4_quote(m4_do([-W -Wall -Wno-error=narrowing -Wwrite-strings ],
		       [-Wcast-qual $wf_opt])),
		       [loose_warn])
ACX_PROG_CC_WARNING_OPTS(
	m4_quote(m4_do([-Wstrict-prototypes -Wmissing-prototypes ],
		       [])), [c_loose_warn])
ACX_PROG_CXX_WARNING_OPTS(
	m4_quote(m4_do([-Wmissing-format-attribute ], [-Wconditionally-supported ],
		       [-Woverloaded-virtual])), [strict_warn])
ACX_PROG_CC_WARNING_OPTS(
	m4_quote(m4_do([-Wold-style-definition -Wc++-compat])), [c_strict_warn])
ACX_PROG_CXX_WARNING_ALMOST_PEDANTIC(
	m4_quote(m4_do([-Wno-long-long -Wno-variadic-macros ], 
		       [-Wno-overlength-strings])), [strict_warn])
ACX_PROG_CXX_WARNINGS_ARE_ERRORS([manual], [strict_warn])

# The above macros do nothing if the compiler is not GCC.  However, the
# Makefile has more goo to add other flags, so these variables are used
# to enable warnings only for GCC.
warn_cflags=
warn_cxxflags=
if test "x$GCC" = "xyes"; then
  warn_cflags='$(GCC_WARN_CFLAGS)'
  warn_cxxflags='$(GCC_WARN_CXXFLAGS)'
fi
AC_SUBST(warn_cflags)
AC_SUBST(warn_cxxflags)

# Disable exceptions and RTTI if building with g++
ACX_PROG_CC_WARNING_OPTS(
	m4_quote(m4_do([-fno-exceptions -fno-rtti -fasynchronous-unwind-tables])),
		       [noexception_flags])
	
# Enable expensive internal checks
is_release=
if test x"`cat $srcdir/DEV-PHASE`" != xexperimental; then
  is_release=yes
fi

AC_ARG_ENABLE(checking,
[AS_HELP_STRING([[--enable-checking[=LIST]]],
		[enable expensive run-time checks.  With LIST,
		 enable only specific categories of checks.
		 Categories are: yes,no,all,none,release.
		 Flags are: assert,df,extra,fold,gc,gcac,gimple,misc,
		 rtlflag,rtl,runtime,tree,valgrind,types])],
[ac_checking_flags="${enableval}"],[
# Determine the default checks.
if test x$is_release = x ; then
  ac_checking_flags=yes,extra
else
  ac_checking_flags=release
fi])
IFS="${IFS= 	}"; ac_save_IFS="$IFS"; IFS="$IFS,"
for check in release $ac_checking_flags
do
	case $check in
	# these set all the flags to specific states
	yes)		ac_assert_checking=1 ; ac_checking=1 ; ac_df_checking= ;
			ac_fold_checking= ; ac_gc_checking=1 ; ac_extra_checking= ;
			ac_gc_always_collect= ; ac_gimple_checking=1 ; ac_rtl_checking= ;
			ac_rtlflag_checking=1 ; ac_runtime_checking=1 ;
			ac_tree_checking=1 ; ac_valgrind_checking= ;
			ac_types_checking=1 ;;
	no|none)	ac_assert_checking= ; ac_checking= ; ac_df_checking= ;
			ac_fold_checking= ; ac_gc_checking= ; ac_extra_checking= ;
			ac_gc_always_collect= ; ac_gimple_checking= ; ac_rtl_checking= ;
			ac_rtlflag_checking= ; ac_runtime_checking= ;
			ac_tree_checking= ; ac_valgrind_checking= ;
			ac_types_checking= ;;
	all)		ac_assert_checking=1 ; ac_checking=1 ; ac_df_checking=1 ;
			ac_fold_checking=1 ; ac_gc_checking=1 ; ac_extra_checking=1 ;
			ac_gc_always_collect=1 ; ac_gimple_checking=1 ; ac_rtl_checking=1 ;
			ac_rtlflag_checking=1 ; ac_runtime_checking=1 ;
			ac_tree_checking=1 ; ac_valgrind_checking= ;
			ac_types_checking=1 ;;
	release)	ac_assert_checking=1 ; ac_checking= ; ac_df_checking= ;
			ac_fold_checking= ; ac_gc_checking= ; ac_extra_checking= ;
			ac_gc_always_collect= ; ac_gimple_checking= ; ac_rtl_checking= ;
			ac_rtlflag_checking= ; ac_runtime_checking=1 ;
			ac_tree_checking= ; ac_valgrind_checking= ;
			ac_types_checking= ;;
	# these enable particular checks
	assert) 	ac_assert_checking=1 ;;
	df)		ac_df_checking=1 ;;
	extra)		ac_extra_checking=1 ;;
	fold)		ac_fold_checking=1 ;;
	gc)		ac_gc_checking=1 ;;
	gcac)		ac_gc_always_collect=1 ;;
	gimple)		ac_gimple_checking=1 ;;
	misc)		ac_checking=1 ;;
	rtl)		ac_rtl_checking=1 ;;
	rtlflag)	ac_rtlflag_checking=1 ;;
	runtime)	ac_runtime_checking=1 ;;
	tree)		ac_tree_checking=1 ;;
	types)		ac_types_checking=1 ;;
	valgrind)	ac_valgrind_checking=1 ;;
	*)	AC_MSG_ERROR(unknown check category $check) ;;
	esac
done
IFS="$ac_save_IFS"

if test x$ac_checking != x ; then
  AC_DEFINE(CHECKING_P, 1,
[Define to 0/1 if you want more run-time sanity checks.  This one gets a grab
bag of miscellaneous but relatively cheap checks.])
else
  AC_DEFINE(CHECKING_P, 0)
fi
if test x$ac_extra_checking != x ; then
  AC_DEFINE(ENABLE_EXTRA_CHECKING, 1,
[Define to 0/1 if you want extra run-time checking that might affect code
generation.])
else
  AC_DEFINE(ENABLE_EXTRA_CHECKING, 0)
fi
if test x$ac_df_checking != x ; then
  AC_DEFINE(ENABLE_DF_CHECKING, 1,
[Define if you want more run-time sanity checks for dataflow.])
fi
if test x$ac_assert_checking != x ; then
  AC_DEFINE(ENABLE_ASSERT_CHECKING, 1,
[Define if you want assertions enabled.  This is a cheap check.])
fi
if test x$ac_gimple_checking != x ; then
  AC_DEFINE(ENABLE_GIMPLE_CHECKING, 1,
[Define if you want operations on GIMPLE (the basic data structure of
the high-level optimizers) to be checked for dynamic type safety at
runtime.  This is moderately expensive.])
fi
dnl Two assembler/linker capabilities that the target libraries read, and that
dnl therefore cannot be runtime values.  libgcc compiles with USED_FOR_TARGET,
dnl which is exactly the case defaults.h guards its targ_caps redefinitions out
dnl of -- deliberately, since target-library code cannot reach targ_caps at all
dnl -- so for those TUs auto-host.h is the only source.  When the probes were
dnl deleted the macros became undefined there, and crtstuff.c (7 sites),
dnl libgcc2.c, libgcov.h, offloadstuff.c and the visium and stormy16
dnl lib2funcs.c silently stopped emitting `.hidden' for __dso_handle,
dnl __EH_FRAME_BEGIN__ and __TMC_END__, making them globally visible.  That is a
dnl linkage and interposition change, and `make all-gcc' cannot see it because
dnl it never builds libgcc.
dnl
dnl Defined unconditionally rather than probed.  Restoring the probe is not an
dnl option -- removing it is the point -- and there is no runtime alternative on
dnl this side, so the choice is between 1 and 0.  1 is what a stock build's
dnl auto-host.h contains on every supported host, so it preserves behaviour
dnl exactly; 0 would silently change it everywhere.  GCC_TARGET_TEMPLATE lifts
dnl the `#ifndef USED_FOR_TARGET' guard that would otherwise keep them out of
dnl the target-library build.  The compiler proper still gets the runtime value:
dnl defaults.h #undefs both and redefines them in terms of targ_caps.
dnl HAVE_GAS_HIDDEN is gone from here entirely.  The compiler proper reads
dnl targ_caps.gas_hidden (defaults.h), so this AC_DEFINE existed for exactly one
dnl reason: to push a value across GCC_TARGET_TEMPLATE into libgcc, which had no
dnl probe of its own.  libgcc/configure.ac now has one -- and a better one, since
dnl it runs the assembler that will actually assemble libgcc's objects.
dnl Consumers were libgcc's crtstuff.c, libgcc2.c, libgcov.h, offloadstuff.c and
dnl the visium and stormy16 lib2funcs; none in gcc/.
GCC_TARGET_TEMPLATE([HAVE_LD_RO_RW_SECTION_MIXING])
AC_DEFINE(HAVE_LD_RO_RW_SECTION_MIXING, 1,
  [Define if your linker links a mix of read-only
   and read-write sections into a read-write section.])

GCC_TARGET_TEMPLATE(ENABLE_RUNTIME_CHECKING)
if test x$ac_runtime_checking != x ; then
  AC_DEFINE(ENABLE_RUNTIME_CHECKING, 1,
[Define if you want runtime assertions enabled.  This is a cheap check.])
fi
if test x$ac_tree_checking != x ; then
  AC_DEFINE(ENABLE_TREE_CHECKING, 1,
[Define if you want all operations on trees (the basic data
   structure of the front ends) to be checked for dynamic type safety
   at runtime.  This is moderately expensive.
   ])
  TREECHECKING=yes
fi
if test x$ac_types_checking != x ; then
  AC_DEFINE(ENABLE_TYPES_CHECKING, 1,
[Define if you want all gimple types to be verified after gimplifiation.
   This is cheap.
   ])
fi
AC_SUBST(TREECHECKING)
if test x$ac_rtl_checking != x ; then
  AC_DEFINE(ENABLE_RTL_CHECKING, 1,
[Define if you want all operations on RTL (the basic data structure
   of the optimizer and back end) to be checked for dynamic type safety
   at runtime.  This is quite expensive.])
fi
if test x$ac_rtlflag_checking != x ; then
  AC_DEFINE(ENABLE_RTL_FLAG_CHECKING, 1,
[Define if you want RTL flag accesses to be checked against the RTL
   codes that are supported for each access macro.  This is relatively
   cheap.])
fi
if test x$ac_gc_checking != x ; then
  AC_DEFINE(ENABLE_GC_CHECKING, 1,
[Define if you want the garbage collector to do object poisoning and
   other memory allocation checks.  This is quite expensive.])
fi
if test x$ac_gc_always_collect != x ; then
  AC_DEFINE(ENABLE_GC_ALWAYS_COLLECT, 1,
[Define if you want the garbage collector to operate in maximally
   paranoid mode, validating the entire heap and collecting garbage at
   every opportunity.  This is extremely expensive.])
fi
if test x$ac_fold_checking != x ; then
  AC_DEFINE(ENABLE_FOLD_CHECKING, 1,
[Define if you want fold checked that it never destructs its argument.
   This is quite expensive.])
fi
valgrind_path_defines=
valgrind_command=
if test x$ac_valgrind_checking != x ; then
  AM_PATH_PROG_WITH_TEST(valgrind_path, valgrind,
	[$ac_dir/$ac_word --version | grep valgrind- >/dev/null 2>&1])
  if test "x$valgrind_path" = "x"; then
    AC_MSG_ERROR([*** Cannot find valgrind])
  fi
  valgrind_path_defines=-DVALGRIND_PATH='\"'$valgrind_path'\"'
  valgrind_command="$valgrind_path -q"
  AC_DEFINE(ENABLE_VALGRIND_CHECKING, 1,
[Define if you want to run subprograms and generated programs
   through valgrind (a memory checker).  This is extremely expensive.])
fi
AC_SUBST(valgrind_path_defines)
AC_SUBST(valgrind_command)

# Enable code coverage collection
AC_ARG_ENABLE(coverage,
[AS_HELP_STRING([[--enable-coverage[=LEVEL]]],
		[enable compiler's code coverage collection.
		 Use to measure compiler performance and locate
		 unused parts of the compiler. With LEVEL, specify
		 optimization. Values are opt, noopt,
		 default is noopt])],
[case "${enableval}" in
  yes|noopt)
    coverage_flags="-fprofile-arcs -ftest-coverage -frandom-seed=\$@ -O0 -fkeep-static-functions"
    ;;
  opt)
    coverage_flags="-fprofile-arcs -ftest-coverage -frandom-seed=\$@ -O2 -fkeep-static-functions"
    ;;
  no)
    # a.k.a. --disable-coverage
    coverage_flags=""
    ;;
  *)
    AC_MSG_ERROR(unknown coverage setting $enableval)
    ;;
esac],
[coverage_flags=""])
AC_SUBST(coverage_flags)

AC_ARG_ENABLE(gather-detailed-mem-stats, 
[AS_HELP_STRING([--enable-gather-detailed-mem-stats],
		[enable detailed memory allocation stats gathering])], [],
[enable_gather_detailed_mem_stats=no])
gather_stats=`if test $enable_gather_detailed_mem_stats != no; then echo 1; else echo 0; fi`
AC_DEFINE_UNQUOTED(GATHER_STATISTICS, $gather_stats,
[Define to enable detailed memory allocation stats gathering.])

AC_ARG_ENABLE(valgrind-annotations,
[AS_HELP_STRING([--enable-valgrind-annotations],
		[enable valgrind runtime interaction])], [],
[enable_valgrind_annotations=no])
AC_CHECK_HEADER(valgrind/memcheck.h)
if test x$enable_valgrind_annotations != xno \
    || test x$ac_valgrind_checking != x; then
  if test $ac_cv_header_valgrind_memcheck_h = no; then
    AC_MSG_ERROR([*** Cannot find valgrind/memcheck.h])
  fi
  AC_DEFINE(ENABLE_VALGRIND_ANNOTATIONS, 1,
[Define to get calls to the valgrind runtime enabled.])
fi

# -------------------------------
# Miscenalleous configure options
# -------------------------------


# Additional target machines this compiler should be able to serve, beyond the
# one named by --target.  Comma-separated list, or "all".  Compare binutils'
# --enable-targets, which GCC has never had.
#
# This does not yet build additional back ends; it collects each extra target's
# configuration so that target-specific data can be emitted per target rather
# than frozen into the binary at configure time.
AC_ARG_ENABLE(targets,
[AS_HELP_STRING([--enable-targets=all|LIST],
		[additional target machines to support])],
[case "${enableval}" in
  yes) AC_MSG_ERROR([--enable-targets needs "all" or a list of targets]) ;;
  *)   ;;
esac],
[enable_targets=no])

dnl --enable-multiarch selected the Debian-style multiarch library layout.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:737".

dnl with_cpu/with_float were AC_SUBSTed only to build the multiarch name for
dnl soft-float/hard-float ABIs.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:749".

# needed for restricting the fixedincludes multilibs that we install
AC_SUBST(with_multi_buildlist)

# default stack clash protection guard size as power of twos in bytes.
# Please keep these in sync with params.def.
dnl --with-stack-clash-protection-guard-size is gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:758".
AC_DEFINE(DEFAULT_STK_CLASH_GUARD_SIZE, 0,
	[Define to larger than zero set the default stack clash protector size.])

# Specify the number of splits of match.pd to generate.
AC_ARG_WITH(matchpd-partitions,
[AS_HELP_STRING([--with-matchpd-partitions=num],
[Set the number of partitions to make for gimple and generic when splitting match.pd. [default=10]])],
[DEFAULT_MATCHPD_PARTITIONS="$with_matchpd_partitions"], [DEFAULT_MATCHPD_PARTITIONS=10])
if (test $DEFAULT_MATCHPD_PARTITIONS -lt 1); then
  AC_MSG_ERROR(m4_normalize([
		Invalid value $DEFAULT_MATCHPD_PARTITIONS for --with-matchpd-partitions. \
		Cannot be negative.]))
fi

AC_SUBST(DEFAULT_MATCHPD_PARTITIONS)

# Specify the number of splits of insn-emit.cc and insn-recog.cc to generate.
AC_ARG_WITH(insnemit-partitions,
[AS_HELP_STRING([--with-insnemit-partitions=num],
[Set the number of partitions of insn-emit.cc for genemit and genrecog to create. [default=10]])],
[DEFAULT_INSNEMIT_PARTITIONS="$with_insnemit_partitions"], [DEFAULT_INSNEMIT_PARTITIONS=10])
if (test $DEFAULT_INSNEMIT_PARTITIONS -lt 1); then
  AC_MSG_ERROR(m4_normalize([
		Invalid value $DEFAULT_INSNEMIT_PARTITIONS for --with-insnemit-partitions. \
		Cannot be negative.]))
fi

AC_SUBST(DEFAULT_INSNEMIT_PARTITIONS)

# Enable __cxa_atexit for C++.
AC_ARG_ENABLE(__cxa_atexit,
[AS_HELP_STRING([--enable-__cxa_atexit], [enable __cxa_atexit for C++])],
[], [])

dnl --enable-decimal-float is gone, and with it GCC_AC_ENABLE_DECIMAL_FLOAT.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:799".


dnl --enable-threads is gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:814".
enable_threads=''

dnl --enable-tls is gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:822".

dnl --enable-vtable-verify selected whether libvtv is available to link
dnl against.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:827".

AC_ARG_ENABLE(analyzer,
[AS_HELP_STRING([--disable-analyzer],
		[disable -fanalyzer static analyzer])],
if test x$enable_analyzer = xno; then
	analyzer=0
else
	analyzer=1
fi,
analyzer=1)
AC_DEFINE_UNQUOTED(ENABLE_ANALYZER, $analyzer,
[Define 0/1 if static analyzer feature is enabled.])

dnl --with-dwarf2 is gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:844".
dwarf2=no

AC_ARG_ENABLE(shared,
[AS_HELP_STRING([--disable-shared], [don't provide a shared libgcc])],
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

dnl Whether to build libgcov and the related host tools.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:871".
enable_gcov=yes
AC_SUBST(enable_gcov)

dnl --with-specs is gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:878".
CONFIGURE_SPECS=
AC_SUBST(CONFIGURE_SPECS)

ACX_PKGVERSION([GCC])
ACX_BUGURL([https://gcc.gnu.org/bugs/])

# Allow overriding the default URL for documentation
AC_ARG_WITH(documentation-root-url,
    AS_HELP_STRING([--with-documentation-root-url=URL],
                   [Root for documentation URLs]),
    [case "$withval" in
      yes) AC_MSG_ERROR([documentation root URL not specified]) ;;
      no)  AC_MSG_ERROR([documentation root URL not specified]) ;;
      */)  DOCUMENTATION_ROOT_URL="$withval" ;;
      *)   AC_MSG_ERROR([documentation root URL does not end with /]) ;;
     esac],[
     docroot_url_suffix=
changequote(,)dnl
     case "$gcc_version" in
       *.[123456].0) docroot_url_suffix="gcc-$gcc_version/";;
       *.[123456].1) docroot_url_suffix="gcc-`echo $gcc_version | sed 's/1$/0/'`/";;
     esac
changequote([,])dnl
     DOCUMENTATION_ROOT_URL="https://gcc.gnu.org/onlinedocs/$docroot_url_suffix"
])
AC_DEFINE_UNQUOTED(DOCUMENTATION_ROOT_URL,"$DOCUMENTATION_ROOT_URL",
	[Define to the root for documentation URLs.])

# Allow overriding the default URL for GCC changes
AC_ARG_WITH(changes-root-url,
    AS_HELP_STRING([--with-changes-root-url=URL],
                   [Root for GCC changes URLs]),
    [case "$withval" in
      yes) AC_MSG_ERROR([changes root URL not specified]) ;;
      no)  AC_MSG_ERROR([changes root URL not specified]) ;;
      */)  CHANGES_ROOT_URL="$withval" ;;
      *)   AC_MSG_ERROR([changes root URL does not end with /]) ;;
     esac],
     CHANGES_ROOT_URL="https://gcc.gnu.org/"
)
AC_DEFINE_UNQUOTED(CHANGES_ROOT_URL,"$CHANGES_ROOT_URL",
	[Define to the root for URLs about GCC changes.])

# Sanity check enable_languages in case someone does not run the toplevel
# configure # script.
AC_ARG_ENABLE(languages,
[AS_HELP_STRING([--enable-languages=LIST], [specify which front-ends to build])],
[case ,${enable_languages}, in
       ,,|,yes,)
		# go safe -- we cannot be much sure without the toplevel
		# configure's
		# analysis of which target libs are present and usable
		enable_languages=c
		;;
	 *,all,*)
		AC_MSG_ERROR([only the toplevel supports --enable-languages=all])
		;;
	*,c,*)
		;;
        *)
		enable_languages=c,${enable_languages}
		;;
esac],
[enable_languages=c])

# If top-level libada has been disabled, then wire in install-gnatlib
# invocation with `make install', so that one can build and install
# the library manually with `make -C gcc all gnatlib gnattools install'.
if test x"$enable_libada" = xno; then
  gnat_install_lib=gnat-install-lib
else
  gnat_install_lib=
fi
AC_SUBST(gnat_install_lib)

dnl --enable-as-accelerator-for is gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:958".
AC_SUBST(enable_as_accelerator)
AC_SUBST(real_target_noncanonical)
AC_SUBST(accel_dir_suffix)

dnl --enable-offload-targets is gone with the same reasoning:
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:971".
AC_SUBST(omp_device_properties)
AC_SUBST(omp_device_property_deps)

AC_DEFINE_UNQUOTED(OFFLOAD_TARGETS, "$offload_targets",
  [Define to offload targets, separated by commas.])
AC_DEFINE(ENABLE_OFFLOADING, 0,
  [Define this to enable support for offloading.])


dnl --with-multilib-list and --with-multilib-generator are gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:988".
with_multilib_list=default
with_multilib_generator=default

dnl --with-picolibc is gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:999".

# -------------------------
# Checks for other programs
# -------------------------

AC_PROG_MAKE_SET

# Find some useful tools
AC_PROG_AWK
# We need awk to create options.cc and options.h.
# Bail out if it's missing.
case ${AWK} in
  "") AC_MSG_ERROR([can't build without awk, bailing out]) ;;
esac

gcc_AC_PROG_LN_S
ACX_PROG_LN($LN_S)
AC_PROG_RANLIB
ranlib_flags=""
AC_SUBST(ranlib_flags)
     
gcc_AC_PROG_INSTALL

# See if cmp has --ignore-initial.
gcc_AC_PROG_CMP_IGNORE_INITIAL

# See if we have the mktemp command.
AC_CHECK_PROG(have_mktemp_command, mktemp, yes, no)

# See if makeinfo has been installed and is modern enough
# that we can use it.
ACX_CHECK_PROG_VER(MAKEINFO, makeinfo, --version,
  [GNU texinfo.* \([0-9][0-9.]*\)],
  [4.[7-9]*|4.[1-9][0-9]*|[5-9]*|[1-9][0-9]*])
if test $gcc_cv_prog_makeinfo_modern = no; then
  AC_MSG_WARN([
*** Makeinfo is missing or too old.
*** Info documentation will not be built.])
  BUILD_INFO=no-info
else
  BUILD_INFO=info
fi
AC_SUBST(BUILD_INFO)

# Determine whether makeinfo supports the CONTENTS_OUTPUT_LOCATION variable.
# If it does, we want to pass it to makeinfo in order to restore the old
# behavior of @{summary,}contents placement.
MAKEINFO_TOC_INLINE_FLAG=
AS_IF([test x"$MAKEINFO" != x], [
  AC_CACHE_CHECK([for CONTENTS_OUTPUT_LOCATION support in $MAKEINFO],
  		 [gcc_cv_texi_add_toc_inline_flags], [
    # Detect the unknown variable CONTENTS_OUTPUT_LOCATION warning
    if "$MAKEINFO" -c CONTENTS_OUTPUT_LOCATION=inline </dev/null 2>&1 \
       | grep CONTENTS_OUTPUT_LOCATION >/dev/null; then
      gcc_cv_texi_add_toc_inline_flags=no
    else
      gcc_cv_texi_add_toc_inline_flags=yes
    fi
  ])
  if test x"$gcc_cv_texi_add_toc_inline_flags" = xyes; then
    MAKEINFO_TOC_INLINE_FLAG='-c CONTENTS_OUTPUT_LOCATION=inline'
  fi
])
AC_SUBST([MAKEINFO_TOC_INLINE_FLAG])

# Is pod2man recent enough to regenerate manpages?
AC_MSG_CHECKING([for recent Pod::Man])
if (perl -e 'use 1.10 Pod::Man') >/dev/null 2>&1; then
  AC_MSG_RESULT(yes)
  GENERATED_MANPAGES=generated-manpages
else
  AC_MSG_RESULT(no)
  GENERATED_MANPAGES=
fi
AC_SUBST(GENERATED_MANPAGES)

MISSING="${CONFIG_SHELL-/bin/sh} $ac_aux_dir/missing"

# How about lex?
dnl Don't use AC_PROG_LEX; we insist on flex.
dnl LEXLIB is not useful in gcc.
AC_CHECK_PROGS([FLEX], flex, [$MISSING flex])

# Bison?
AC_CHECK_PROGS([BISON], bison, [$MISSING bison])

# Python3?
ACX_CHECK_PROG_VER(PYTHON, python3, --version,
  [Python.* \([0-9][0-9.]*\)],
  [3.[4-9]*|3.[1-9][0-9]*|[4-9].*|[1-9][0-9]*])
if test $gcc_cv_prog_python3_modern = no; then
  AC_MSG_WARN([
*** Python3 is missing.
*** Documentation for modula-2 will not include the target SYSTEM module.])
  HAVE_PYTHON=no
else
  HAVE_PYTHON=yes
fi
AC_SUBST(HAVE_PYTHON)

# Binutils are not build modules, unlike bison/flex/makeinfo.  So we
# check for build == host before using them.

# NM
if test x${build} = x${host} && test -f $srcdir/../binutils/nm.c \
  && test -d ../binutils ; then
  NM='../binutils/nm-new'
else
  AC_CHECK_PROG(NM, nm, nm, ${CONFIG_SHELL-/bin/sh} ${srcdir}/../missing nm)
fi

# AR
if test x${build} = x${host} && test -f $srcdir/../binutils/ar.c \
  && test -d ../binutils ; then
  AR='../binutils/ar'
else
  AC_CHECK_PROG(AR, ar, ar, ${CONFIG_SHELL-/bin/sh} ${srcdir}/../missing ar)
fi

# The jit documentation looks better if built with sphinx, but can be
# built with texinfo if sphinx is not available.
# Set "doc_build_sys" to "sphinx" or "texinfo" accordingly.
AC_CHECK_PROG(doc_build_sys, sphinx-build, sphinx, texinfo)

# --------------------
# Checks for C headers
# --------------------

# Need to reject headers which give warnings, so that the -Werror bootstrap
# works later. *sigh*  This needs to come before all header checks.
AC_PROG_CPP_WERROR

AC_HEADER_STDC
AC_HEADER_TIME
ACX_HEADER_STRING
AC_HEADER_SYS_WAIT
AC_HEADER_TIOCGWINSZ
AC_CHECK_HEADERS(limits.h stddef.h string.h strings.h stdlib.h time.h iconv.h \
		 fcntl.h ftw.h unistd.h sys/auxv.h sys/file.h sys/time.h sys/mman.h \
		 sys/resource.h sys/param.h sys/times.h sys/stat.h sys/locking.h \
		 direct.h malloc.h langinfo.h ldfcn.h locale.h wchar.h libgen.h)

# Check for thread headers.
AC_CHECK_HEADER(thread.h, [have_thread_h=yes], [have_thread_h=])
AC_CHECK_HEADER(pthread.h, [have_pthread_h=yes], [have_pthread_h=])

# These tests can't be done till we know if we have limits.h.
gcc_AC_C_CHAR_BIT
AC_C_BIGENDIAN

# ----------------------
# Checks for C++ headers
# ----------------------

dnl Autoconf will give an error in the configure script if there is no
dnl C++ preprocessor.  Hack to prevent that.
m4_pushdef([AC_MSG_ERROR], m4_defn([AC_MSG_WARN]))[]dnl
AC_PROG_CXXCPP
m4_popdef([AC_MSG_ERROR])[]dnl

AC_CHECK_HEADERS(unordered_map)
AC_CHECK_HEADERS(tr1/unordered_map)
AC_CHECK_HEADERS(ext/hash_map)

# --------
# Dependency checking.
# --------

ZW_CREATE_DEPDIR
AC_CONFIG_COMMANDS([gccdepdir],[
  ${CONFIG_SHELL-/bin/sh} $ac_aux_dir/mkinstalldirs build/$DEPDIR
  for lang in $subdirs c-family common analyzer custom-sarif-properties diagnostics text-art rtl-ssa sym-exec
  do
      ${CONFIG_SHELL-/bin/sh} $ac_aux_dir/mkinstalldirs $lang/$DEPDIR
  done], [subdirs="$subdirs" ac_aux_dir=$ac_aux_dir DEPDIR=$DEPDIR])

ZW_PROG_COMPILER_DEPENDENCIES([CXX])

# --------
# UNSORTED
# --------


# These libraries may be used by collect2.
# We may need a special search path to get them linked.
AC_CACHE_CHECK(for collect2 libraries, gcc_cv_collect2_libs,
[save_LIBS="$LIBS"
for libs in '' -lld -lmld \
		'-L/usr/lib/cmplrs/cc2.11 -lmld' \
		'-L/usr/lib/cmplrs/cc3.11 -lmld'
do
	LIBS="$libs"
	AC_TRY_LINK_FUNC(ldopen,
		[gcc_cv_collect2_libs="$libs"; break])
done
LIBS="$save_LIBS"
test -z "$gcc_cv_collect2_libs" && gcc_cv_collect2_libs='none required'])
case $gcc_cv_collect2_libs in
	"none required")	;;
	*)	COLLECT2_LIBS=$gcc_cv_collect2_libs ;;
esac
AC_SUBST(COLLECT2_LIBS)

# When building Ada code on Alpha, we need exc_resume which is usually in
# -lexc.  So test for it.
save_LIBS="$LIBS"
LIBS=
AC_SEARCH_LIBS(exc_resume, exc)
GNAT_LIBEXC="$LIBS"
LIBS="$save_LIBS"
AC_SUBST(GNAT_LIBEXC)

# To support -mcpu=native on Solaris/SPARC, we need libkstat.
save_LIBS="$LIBS"
LIBS=
AC_SEARCH_LIBS(kstat_open, kstat)
EXTRA_GCC_LIBS="$LIBS"
LIBS="$save_LIBS"
AC_SUBST(EXTRA_GCC_LIBS)

# Some systems put ldexp and frexp in libm instead of libc; assume
# they're both in the same place.  jcf-dump needs them.
save_LIBS="$LIBS"
LIBS=
AC_SEARCH_LIBS(ldexp, m)
LDEXP_LIB="$LIBS"
LIBS="$save_LIBS"
AC_SUBST(LDEXP_LIB)

# Some systems need dlopen
save_LIBS="$LIBS"
LIBS=
AC_SEARCH_LIBS(dlopen, dl)
DL_LIB="$LIBS"
LIBS="$save_LIBS"
AC_SUBST(DL_LIB)

# Use <inttypes.h> only if it exists,
# doesn't clash with <sys/types.h>, declares intmax_t and defines
# PRId64
AC_MSG_CHECKING(for inttypes.h)
AC_CACHE_VAL(gcc_cv_header_inttypes_h,
[AC_COMPILE_IFELSE([AC_LANG_PROGRAM(
[[#define __STDC_FORMAT_MACROS
#include <sys/types.h>
#include <inttypes.h>]],
  [[intmax_t i = -1;
#ifndef PRId64
choke me
#endif]])],
  [gcc_cv_header_inttypes_h=yes],
  [gcc_cv_header_inttypes_h=no])])
AC_MSG_RESULT($gcc_cv_header_inttypes_h)
if test $gcc_cv_header_inttypes_h = yes; then
  AC_DEFINE(HAVE_INTTYPES_H, 1,
	[Define if you have a working <inttypes.h> header file.])
fi

# Use <afunix.h> only if it exists,
AC_MSG_CHECKING(for afunix.h)
AC_CACHE_VAL(gcc_cv_header_afunix_h,
[AC_COMPILE_IFELSE([AC_LANG_PROGRAM(
[[#include <winsock2.h>
#include <afunix.h>]],
  [[SOCKADDR_UN addr;]])],
  [gcc_cv_header_afunix_h=yes],
  [gcc_cv_header_afunix_h=no])])
AC_MSG_RESULT($gcc_cv_header_afunix_h)
if test $gcc_cv_header_afunix_h = yes; then
  AC_DEFINE(HAVE_AFUNIX_H, 1,
	[Define if you have a working <afunix.h> header file.])
fi

# Look for the ZSTD package.
ZSTD_INCLUDE=
ZSTD_LIB=
AC_SUBST(ZSTD_INCLUDE)
AC_SUBST(ZSTD_LIB)
ZSTD_CPPFLAGS=
ZSTD_LDFLAGS=
AC_SUBST(ZSTD_CPPFLAGS)
AC_SUBST(ZSTD_LDFLAGS)
AC_ARG_WITH(zstd,
	[AS_HELP_STRING([--with-zstd=PATH],
		[specify prefix directory for installed zstd library.
		 Equivalent to --with-zstd-include=PATH/include
		 plus --with-zstd-lib=PATH/lib])])
AC_ARG_WITH(zstd-include,
	[AS_HELP_STRING([--with-zstd-include=PATH],
		[specify directory for installed zstd include files])])
AC_ARG_WITH(zstd-lib,
	[AS_HELP_STRING([--with-zstd-lib=PATH],
		[specify directory for the installed zstd library])])
case "x$with_zstd" in
  x) ;;
  xno)
    ZSTD_INCLUDE=
    ZSTD_LIB=
    ;;
  *) ZSTD_INCLUDE=$with_zstd/include
     ZSTD_LIB=$with_zstd/lib
     ;;
esac

if test "x$with_zstd" != xno; then
if test "x$with_zstd_include" != x; then
  ZSTD_INCLUDE=$with_zstd_include
fi
if test "x$with_zstd_lib" != x; then
  ZSTD_LIB=$with_zstd_lib
fi
if test "x$ZSTD_INCLUDE" != x \
   && test "x$ZSTD_INCLUDE" != xno; then
  ZSTD_CPPFLAGS=-I$ZSTD_INCLUDE
fi
if test "x$ZSTD_LIB" != x \
   && test "x$ZSTD_LIB" != xno; then
  ZSTD_LDFLAGS=-L$ZSTD_LIB
fi

saved_CXXFLAGS="$CXXFLAGS"
saved_LDFLAGS="$LDFLAGS"
CXXFLAGS="$CXXFLAGS $ZSTD_CPPFLAGS"
LDFLAGS="$LDFLAGS $ZSTD_LDFLAGS"

# LTO can use zstd compression algorithm
save_LIBS="$LIBS"
LIBS=
AC_SEARCH_LIBS(ZSTD_compress, zstd,, gcc_cv_header_zstd_h=no)
ZSTD_LIB="$LIBS"
LIBS="$save_LIBS"
AC_SUBST(ZSTD_LIB)

AC_MSG_CHECKING(for zstd.h)
AC_CACHE_VAL(gcc_cv_header_zstd_h,
# We require version 1.3.0 or later.  This is the first version that has
# ZSTD_getFrameContentSize.
[AC_COMPILE_IFELSE([AC_LANG_PROGRAM(
[[#include <zstd.h>
#if ZSTD_VERSION_NUMBER < 10300
#error "need zstd 1.3.0 or better"
#endif]])],
  [gcc_cv_header_zstd_h=yes],
  [gcc_cv_header_zstd_h=no])])
AC_MSG_RESULT($gcc_cv_header_zstd_h)
if test $gcc_cv_header_zstd_h = yes; then
  AC_DEFINE(HAVE_ZSTD_H, 1,
	[Define if you have a working <zstd.h> header file.])
elif test "x$with_zstd" != x; then
    as_fn_error $? "Unable to find zstd.h.  See config.log for details." "$LINENO" 5
fi

CXXFLAGS="$saved_CXXFLAGS"
LDFLAGS="$saved_LDFLAGS"
fi

dnl Disabled until we have a complete test for buggy enum bitfields.
dnl gcc_AC_C_ENUM_BF_UNSIGNED

define(gcc_UNLOCKED_FUNCS, clearerr_unlocked feof_unlocked dnl
  ferror_unlocked fflush_unlocked fgetc_unlocked fgets_unlocked dnl
  fileno_unlocked fprintf_unlocked fputc_unlocked fputs_unlocked dnl
  fread_unlocked fwrite_unlocked getchar_unlocked getc_unlocked dnl
  putchar_unlocked putc_unlocked)
AC_CHECK_FUNCS(times clock kill getrlimit setrlimit atoq \
	popen sysconf strsignal getrusage nl_langinfo \
	gettimeofday mbstowcs wcswidth mmap posix_fallocate setlocale \
	gcc_UNLOCKED_FUNCS madvise mallinfo mallinfo2 fstatat getauxval \
	clock_gettime munmap msync get_current_dir_name memrchr)

# At least for glibc, clock_gettime is in librt.  But don't pull that
# in if it still doesn't give us the function we want.
if test $ac_cv_func_clock_gettime = no; then
  AC_CHECK_LIB(rt, clock_gettime,
    [LIBS="-lrt $LIBS"
     AC_DEFINE(HAVE_CLOCK_GETTIME, 1,
	       [Define to 1 if you have the `clock_gettime' function.])])
fi

if test x$ac_cv_func_mbstowcs = xyes; then
  AC_CACHE_CHECK(whether mbstowcs works, gcc_cv_func_mbstowcs_works,
[    AC_RUN_IFELSE([AC_LANG_SOURCE([[#include <stdlib.h>
int main()
{
  mbstowcs(0, "", 0);
  return 0;
}]])],
    [gcc_cv_func_mbstowcs_works=yes],
    [gcc_cv_func_mbstowcs_works=no],
    [gcc_cv_func_mbstowcs_works=yes])])
  if test x$gcc_cv_func_mbstowcs_works = xyes; then
    AC_DEFINE(HAVE_WORKING_MBSTOWCS, 1,
  [Define this macro if mbstowcs does not crash when its
   first argument is NULL.])
  fi
fi

AC_CHECK_TYPE(ssize_t, int)
AC_CHECK_TYPE(caddr_t, char *)
AC_CHECK_TYPE(sighander_t,
  AC_DEFINE(HAVE_SIGHANDLER_T, 1,
    [Define if <sys/signal.h> defines sighandler_t]),
    ,signal.h)

GCC_AC_FUNC_MMAP_BLACKLIST

case "${host}" in
*-*-*vms*)
  # Under VMS, vfork works very differently than on Unix. The standard test 
  # won't work, and it isn't easily adaptable. It makes more sense to
  # just force it.
  ac_cv_func_vfork_works=yes
  ;;
esac
AC_FUNC_FORK

AM_ICONV

# Until we have in-tree GNU iconv:
LIBICONV_DEP=
if test -f "$LTLIBICONV"; then
  LIBICONV_DEP=$LTLIBICONV
fi
AC_SUBST(LIBICONV_DEP)

AM_LC_MESSAGES

AM_LANGINFO_CODESET

# We will need to find libiberty.h and ansidecl.h
saved_CFLAGS="$CFLAGS"
CFLAGS="$CFLAGS -I${srcdir} -I${srcdir}/../include $GMPINC"
saved_CXXFLAGS="$CXXFLAGS"
CXXFLAGS="$CXXFLAGS -I${srcdir} -I${srcdir}/../include $GMPINC"

dnl Every probe from here to the end of this block compiles a program that
dnl includes "system.h", which ...
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:1439".
AC_MSG_CHECKING([for gmp.h, which system.h needs and every probe below depends on])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <gmp.h>]], [[]])],
  [AC_MSG_RESULT([yes])],
  [AC_MSG_RESULT([no])
   AC_MSG_NOTICE([GMPINC is: $GMPINC])
   AC_MSG_ERROR([gmp.h cannot be included, but system.h includes it at line 718.

Every feature probe that follows compiles a program that includes system.h, and
a compile that fails for ANY reason is recorded as "feature absent".  Continuing
would write about fifty wrong answers into auto-host.h -- among them rlim_t,
whose bogus definition makes every object fail to build with an error that names
anything but this.

Put the GMP headers on the include path, or pass GMPINC; its current value is
shown above.  See config.log for the compiler output.])])

# gcc_AC_CHECK_DECLS doesn't support overloaded functions, so use the
# normal autoconf function for these.  But force definition of
# HAVE_DECL_BASENAME like gcc_AC_CHECK_DECLS does, to suppress the bizarre
# basename handling in libiberty.h.
# Match the configure test in libiberty so that we have a consistent result.
AC_CHECK_DECLS([basename(char*)], , ,[
#undef HAVE_DECL_BASENAME
#define HAVE_DECL_BASENAME 1
#if HAVE_LIBGEN_H
# include <libgen.h>
#endif
#include "ansidecl.h"
#include "system.h"])

AC_CHECK_DECLS([strstr(const char*,const char*)], , ,[
#include "ansidecl.h"
#include "system.h"])

gcc_AC_CHECK_DECLS(getenv atol atoll asprintf sbrk abort atof getcwd getwd \
	madvise mkstemps stpcpy strnlen strsignal strverscmp \
	strtol strtoul strtoll strtoull setenv unsetenv \
	errno snprintf vsnprintf vasprintf malloc realloc calloc \
	free getopt clock getpagesize ffs fmemopen gcc_UNLOCKED_FUNCS, , ,[
#include "ansidecl.h"
#include "system.h"])

gcc_AC_CHECK_DECLS(getrlimit setrlimit getrusage, , ,[
#include "ansidecl.h"
#include "system.h"
#ifdef HAVE_SYS_RESOURCE_H
#include <sys/resource.h>
#endif
])

gcc_AC_CHECK_DECLS(mallinfo mallinfo2, , ,[
#include "ansidecl.h"
#include "system.h"
#ifdef HAVE_MALLOC_H
#include <malloc.h>
#endif
])

AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include "ansidecl.h"
#include "system.h"
#ifdef HAVE_SYS_RESOURCE_H
#include <sys/resource.h>
#endif
]], [[rlim_t l = 0;]])],[],[AC_DEFINE([rlim_t],[long],
[Define to `long' if <sys/resource.h> doesn't define.])])

# On AIX 5.2, <ldfcn.h> conflicts with <fcntl.h>, as both define incompatible
# FREAD and FWRITE macros.  Fortunately, for GCC's single usage of ldgetname
# in collect2.cc, <fcntl.h> isn't visible, but the configure test below needs
# to undef these macros to get the correct value for HAVE_DECL_LDGETNAME.
gcc_AC_CHECK_DECLS(ldgetname, , ,[
#include "ansidecl.h"
#include "system.h"
#ifdef HAVE_LDFCN_H
#undef FREAD
#undef FWRITE
#include <ldfcn.h>
#endif
])

gcc_AC_CHECK_DECLS(times, , ,[
#include "ansidecl.h"
#include "system.h"
#ifdef HAVE_SYS_TIMES_H
#include <sys/times.h>
#endif
])

gcc_AC_CHECK_DECLS(sigaltstack, , ,[
#include "ansidecl.h"
#include "system.h"
#include <signal.h>
])

# More time-related stuff.
AC_CACHE_CHECK(for struct tms, ac_cv_struct_tms, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include "ansidecl.h"
#include "system.h"
#ifdef HAVE_SYS_TIMES_H
#include <sys/times.h>
#endif
]], [[struct tms tms;]])],[ac_cv_struct_tms=yes],[ac_cv_struct_tms=no])])
if test $ac_cv_struct_tms = yes; then
  AC_DEFINE(HAVE_STRUCT_TMS, 1,
  [Define if <sys/times.h> defines struct tms.])
fi

# use gcc_cv_* here because this doesn't match the behavior of AC_CHECK_TYPE.
# revisit after autoconf 2.50.
AC_CACHE_CHECK(for clock_t, gcc_cv_type_clock_t, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include "ansidecl.h"
#include "system.h"
]], [[clock_t x;]])],[gcc_cv_type_clock_t=yes],[gcc_cv_type_clock_t=no])])
if test $gcc_cv_type_clock_t = yes; then
  AC_DEFINE(HAVE_CLOCK_T, 1,
  [Define if <time.h> defines clock_t.])
fi

# Check if F_SETLKW is supported by fcntl.
AC_CACHE_CHECK(for F_SETLKW, ac_cv_f_setlkw, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <fcntl.h>]], [[
struct flock fl;
fl.l_whence = 0;
fl.l_start = 0;
fl.l_len = 0;
fl.l_pid = 0;
return fcntl (1, F_SETLKW, &fl);]])],
[ac_cv_f_setlkw=yes],[ac_cv_f_setlkw=no])])
if test $ac_cv_f_setlkw = yes; then
  AC_DEFINE(HOST_HAS_F_SETLKW, 1,
  [Define if F_SETLKW supported by fcntl.])
fi

# Check if O_CLOEXEC is defined by fcntl
AC_CACHE_CHECK(for O_CLOEXEC, ac_cv_o_cloexec, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <fcntl.h>]], [[
return open ("/dev/null", O_RDONLY | O_CLOEXEC);]])],
[ac_cv_o_cloexec=yes],[ac_cv_o_cloexec=no])])
if test $ac_cv_o_cloexec = yes; then
  AC_DEFINE(HOST_HAS_O_CLOEXEC, 1,
  [Define if O_CLOEXEC supported by fcntl.])
fi

# Check if O_NONBLOCK is defined by fcntl
AC_CHECK_HEADERS([fcntl.h])
AC_CHECK_DECL(O_NONBLOCK,,,[#include <fcntl.h>])
if test $ac_cv_have_decl_O_NONBLOCK = yes; then
  AC_DEFINE(HOST_HAS_O_NONBLOCK, 1,
  [Define if O_NONBLOCK supported by fcntl.])
fi

# Check if personality and ADDR_NO_RANDOMIZE are declared
# in sys/personality.h
AC_CACHE_CHECK(for personality ADDR_NO_RANDOMIZE,
	       ac_cv_personality_addr_no_randomize, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <sys/personality.h>]], [[
personality (personality (0xffffffffU) | ADDR_NO_RANDOMIZE);]])],
[ac_cv_personality_addr_no_randomize=yes],
[ac_cv_personality_addr_no_randomize=no])])
if test $ac_cv_personality_addr_no_randomize = yes; then
  AC_DEFINE(HOST_HAS_PERSONALITY_ADDR_NO_RANDOMIZE, 1,
  [Define if personality and ADDR_NO_RANDOMIZE are declared in
sys/personality.h.])
fi


# C++ Modules would like some networking features to provide the mapping
# server.  You can still use modules without them though.
# The following network-related checks could probably do with some
# Windows and other non-linux defenses and checking.

# Local socket connectivity wants AF_UNIX networking
# Check for AF_UNIX networking
AC_CACHE_CHECK(for AF_UNIX, ac_cv_af_unix, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>]],[[
sockaddr_un un;
un.sun_family = AF_UNSPEC;
int fd = socket (AF_UNIX, SOCK_STREAM, 0);
connect (fd, (sockaddr *)&un, sizeof (un));]])],
[ac_cv_af_unix=yes],
[ac_cv_af_unix=no])])
if test $ac_cv_af_unix = yes; then
  AC_DEFINE(HAVE_AF_UNIX, 1,
  [Define if AF_UNIX supported.])
fi

# Remote socket connectivity wants AF_INET6 networking
# Check for AF_INET6 networking
AC_CACHE_CHECK(for AF_INET6, ac_cv_af_inet6, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>]],[[
sockaddr_in6 in6;
in6.sin6_family = AF_UNSPEC;
struct addrinfo *addrs = 0;
struct addrinfo hints;
hints.ai_flags = 0;
hints.ai_family = AF_INET6;
hints.ai_socktype = SOCK_STREAM;
hints.ai_protocol = 0;
hints.ai_canonname = 0;
hints.ai_addr = 0;
hints.ai_next = 0;
int e = getaddrinfo ("localhost", 0, &hints, &addrs);
const char *str = gai_strerror (e);
freeaddrinfo (addrs);
int fd = socket (AF_INET6, SOCK_STREAM, 0);
connect (fd, (sockaddr *)&in6, sizeof (in6));]])],
[ac_cv_af_inet6=yes],
[ac_cv_af_inet6=no])])
if test $ac_cv_af_inet6 = yes; then
  AC_DEFINE(HAVE_AF_INET6, 1,
  [Define if AF_INET6 supported.])
fi

# Check if _LK_LOCK is supported by _locking
AC_CACHE_CHECK(for _LK_LOCK, ac_cv_lk_lock, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <io.h>
#include <sys/locking.h>]], [[
  int fd;
  return _locking (fd, _LK_LOCK, 0);]])],
[ac_cv_lk_lock=yes],[ac_cv_lk_lock=no])])
if test $ac_cv_lk_lock = yes; then
  AC_DEFINE(HOST_HAS_LK_LOCK, 1,
  [Define if _LK_LOC supported by _locking.])
fi

# Restore CFLAGS, CXXFLAGS from before the gcc_AC_NEED_DECLARATIONS tests.
CFLAGS="$saved_CFLAGS"
CXXFLAGS="$saved_CXXFLAGS"

# mkdir takes a single argument on some systems. 
gcc_AC_FUNC_MKDIR_TAKES_ONE_ARG

# File extensions
manext='.1'
objext='.o'
AC_SUBST(manext)
AC_SUBST(objext)

# With Setjmp/Longjmp based exception handling.
AC_ARG_ENABLE(sjlj-exceptions,
[AS_HELP_STRING([--enable-sjlj-exceptions],
                [arrange to use setjmp/longjmp exception handling])],
[force_sjlj_exceptions=yes],
[force_sjlj_exceptions=no])
if test $force_sjlj_exceptions = yes; then
  sjlj=`if test $enableval = yes; then echo 1; else echo 0; fi`
  AC_DEFINE_UNQUOTED(CONFIG_SJLJ_EXCEPTIONS, $sjlj,
    [Define 0/1 to force the choice for exception handling model.])
fi

# Windows32 UTF-8 manifest support for running the driver and compiler
# executables with the UTF-8 active code page on mingw hosts.
# Non-mingw hosts ignore this option.
# The shell variables this sets are picked up from the mingw branches
# of config.host so they have to be set before it gets sourced.
AC_ARG_ENABLE(win32-utf8-manifest,
[AS_HELP_STRING([--disable-win32-utf8-manifest],
                [disable embedding a utf8 manifest on mingw hosts])
AS_HELP_STRING([--enable-win32-utf8-manifest],
               [enable embedding a utf8 manifest on mingw hosts (default)])],,)

if test "x$enable_win32_utf8_manifest" != xno; then
  host_xmake_mingw=i386/x-mingw32-utf8
  host_extra_gcc_objs_mingw=utf8rc-mingw32.o
  host_extra_objs_mingw=utf8-mingw32.o
fi

# --------------------------------------------------------
# Build, host, and target specific configuration fragments
# --------------------------------------------------------

# Collect build-machine-specific information.
. ${srcdir}/config.build || exit 1

# Collect host-machine-specific information.
. ${srcdir}/config.host || exit 1

target_gtfiles=

# Canonicalise ${target} before config.gcc dispatches on it.  AC_CANONICAL_TARGET
# is deliberately gone -- it is what gave one target a privileged position --
# but autoconf's legacy `target=$target_alias' assignment remains, and that
# leaves ${target} holding exactly what was typed on the command line.
# config.gcc matches canonical triples only, and its arms are ordered globs, so
# an uncanonical name does not fail: it silently matches a LATER arm.
# --target=aarch64-linux-gnu splits as aarch64/linux/gnu, misses
# `aarch64*-*-linux*' and hits `aarch64*-*-gnu*' -- the GNU/Hurd port -- while
# --enable-targets, which does canonicalise, records the Linux one.  The build
# then had tm.h describing Hurd and tm-aarch64.h describing Linux.
# The --enable-targets loop below does the same thing for the same reason.
if test x"${target}" != x; then
  target_canon=`${srcdir}/../config.sub ${target} 2>/dev/null`
  if test x"${target_canon}" = x; then
    AC_MSG_ERROR([${target} is not a recognised target name])
  fi
  target=${target_canon}
fi

# Collect target-machine-specific information.
. ${srcdir}/config.gcc || exit 1

# Multi-target: collect the same information for each additional target named by
# --enable-targets.  config.gcc dispatches on ${target} and assigns tm_file &c.
# unconditionally, so every extra target is handled by sourcing it again inside a
# subshell; that keeps the primary target's variables above untouched and lets an
# unsupported target fail as a non-zero exit we can report.
#
# The result is a manifest, one stanza per target, which later build steps read
# to emit per-target data instead of freezing one target's values into the
# binary.  No additional back end is compiled yet.
gcc_extra_targets=
case ${enable_targets} in
  no | "")
    ;;
  all)
    # config.gcc matches targets with shell globs, so it cannot be enumerated.
    # contrib/config-list.mk carries the list GCC itself uses to build every
    # configuration, which is the same question asked for the same reason, so
    # take it from there rather than inventing a second list that would drift.
    #
    # Entries may carry configure options as a trailing OPT-with-cpu=... ; only
    # the triple is wanted here.  \134 is a backslash, spelled in octal so that
    # neither m4 nor the shell has to be argued with about quoting.
    gcc_extra_targets=`sed -n '/^LIST = /,/^ *$/p' ${srcdir}/../contrib/config-list.mk \
      | sed -e 's/^LIST = //' \
      | tr -d '\134' \
      | tr ' ' '\012' \
      | sed -e 's/OPT.*$//' \
      | grep . \
      | sort -u \
      | tr '\012' ' '`
    if test x"${gcc_extra_targets}" = x; then
      AC_MSG_ERROR([--enable-targets=all: could not read contrib/config-list.mk])
    fi
    ;;
  *)
    gcc_extra_targets=`echo "${enable_targets}" | sed 's/,/ /g'`
    ;;
esac

dnl --enable-targets names every target, and there is no other source for
dnl the list:
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:1821".
if test x"${gcc_extra_targets}" = x; then
  AC_MSG_ERROR([--enable-targets=LIST is required])
fi

dnl `${target}' IS added to the manifest, and that is not the fallback
dnl refused above.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:1829".
gcc_manifest_targets="${gcc_extra_targets} ${target}"

gcc_all_common_objects=
gcc_all_common_symbols=
gcc_common_mk=multi-target-common.mk
echo "# Generated by configure: one rule per target's common hook table." > ${gcc_common_mk}
# Registry of the tables, as data for common/common-target-select.cc.  Built in
# two pieces because every declaration has to precede the table that uses them,
# and they are produced in the same pass.
gcc_common_ext=multi-target-common.ext
gcc_common_ent=multi-target-common.ent
: > ${gcc_common_ext}
: > ${gcc_common_ent}
# The same two pieces for the driver's spec-function tables.  Kept in step with
# the common-hook registry above, from the same loop over the same manifest, so
# that the two cannot come to disagree about which targets exist -- gcc.cc
# checks that they have not.
gcc_all_spec_fn_objects=
gcc_sf_ext=multi-target-spec-functions.ext
gcc_sf_ent=multi-target-spec-functions.ent
: > ${gcc_sf_ext}
: > ${gcc_sf_ent}
gcc_target_manifest=multi-target.manifest
: > ${gcc_target_manifest}
gcc_mt_err=conftest.mterr

# Canonicalise the list, and deduplicate it once canonical.  Targets are named
# the way one would type them on a command line -- aarch64-elf, alpha-netbsd --
# and configure would normally expand those before anyone sees them.
# config.gcc matches canonical triples only, and answers a short form with
# "Configuration ... not supported".
#
# The dedup is not cosmetic.  ${target} is in this list unconditionally (see
# above), so a user who also names the build's own triple -- and
# --enable-targets=all names several i386 ones -- would otherwise get the same
# object built by two identical make rules and listed twice in OBJS, and two
# registry entries for one triple.  Two spellings of one triple only become
# comparable after config.sub, which is why this happens here and not where the
# list is assembled.
gcc_mt_canon=
for gcc_mt in ${gcc_manifest_targets}; do
  gcc_mt_c=`${srcdir}/../config.sub ${gcc_mt} 2>/dev/null`
  if test x"${gcc_mt_c}" = x; then
    AC_MSG_ERROR([--enable-targets: ${gcc_mt} is not a recognised target name])
  fi
  gcc_mt_seen=no
  for gcc_mt_have in ${gcc_mt_canon}; do
    if test x"${gcc_mt_have}" = x"${gcc_mt_c}"; then
      gcc_mt_seen=yes
    fi
  done
  if test x"${gcc_mt_seen}" = xno; then
    gcc_mt_canon="${gcc_mt_canon} ${gcc_mt_c}"
  fi
done
gcc_manifest_targets=${gcc_mt_canon}

for gcc_mt in ${gcc_manifest_targets}; do
  # The with_* group no longer needs clearing here: config.gcc clears it itself,
  # because --with-cpu/--with-arch/--with-tune/... are gone.  What used to leak
  # from the primary target into every other one (aarch64 rejecting x86's
  # --with-arch=x86-64) cannot arise any more; each target's CPU/ABI defaults are
  # inferred from its own triple and reported below as option_defaults.
  gcc_mt_data=`
    target=${gcc_mt}
    tm_defines= cpu_type= target_cpu_default=
    tm_file= tm_p_file= tmake_file=
    extra_objs= extra_options= extra_headers=
    out_file= md_file= target_gtfiles=
    common_out_file= target_has_targetm_common= dwarf2= extra_modes=
    TM_MULTILIB_CONFIG=
    . ${srcdir}/config.gcc 2> ${gcc_mt_err} > /dev/null || exit 1
    # config.gcc leaves these unset for most targets; the primary target gets
    # them defaulted just below, so apply the same rules here or the manifest
    # would claim the target has no machine description.
    test x"${tm_file}" = x && tm_file=${cpu_type}/${cpu_type}.h
    test x"${md_file}" = x && md_file=${cpu_type}/${cpu_type}.md
    test x"${out_file}" = x && out_file=${cpu_type}/${cpu_type}.cc
    echo "target ${gcc_mt}"
    echo "cpu_type ${cpu_type}"
    # This targets own CPU/ABI defaults, as name=value pairs whose names are
    # the OPTION_DEFAULT_SPECS keys of its back end.  These were the values of
    # the undeclared --with-cpu/--with-arch/--with-tune/... options; with those
    # gone they are inferred from the triple, per target rather than one array
    # compiled into the driver.  target-specs turns them into the
    # option_defaults spec of this targets spec file.  (No apostrophes or
    # backticks in here: this whole block is inside a command substitution.)
    echo "option_defaults ${target_option_defaults}"
    # Target properties cc1 needs that are decided by the triple, not probed.
    echo "decimal_float ${target_decimal_float}"
    echo "decimal_bid_format ${target_decimal_bid_format}"
    # Which common-hook table this target uses, and the name it will be
    # compiled under.  Recorded per target so that several can be built and
    # linked together; config.gcc applies this defaulting itself, after the
    # per-target clauses have had their say.
    echo "common_out_file ${common_out_file}"
    # Use $( ) here, not backticks.  This runs inside the outer command
    # substitution that captures the stanza, and a nested backtick closes that
    # early -- which silently emptied the whole thing.  (Not even in a comment:
    # the closing backtick is found while parsing, before the comment applies.)
    echo "common_out_symbol targetm_common_$(basename ${common_out_file} .cc | sed 's/-/_/g')"
    echo "tm_file ${tm_file}"
    echo "tm_p_file ${tm_p_file}"
    echo "tmake_file ${tmake_file}"
    # Which of those fragments actually exist.  tmake_file names some that do
    # not -- sh-unknown-elf asks for sh/t-elf, which is not in the tree -- and
    # an include of a missing file is a hard error in make, so everything that
    # feeds these to make has to filter them first.  (No backtick in this
    # comment: the whole block is one command substitution, and a stray one
    # closes it while the file is parsed, long before the comment applies.)
    # Filtered once here, where
    # the answer is already known, rather than by each consumer in turn: this
    # is the same test the primary target's own tmake_file loop applies further
    # down, and it was the last fact the manifest left its readers to re-derive.
    mt_tmake_present=
    for mt_tf in ${tmake_file}; do
      if test -f ${srcdir}/config/${mt_tf}; then
	mt_tmake_present="${mt_tmake_present} ${mt_tf}"
      fi
    done
    echo "tmake_file_present ${mt_tmake_present}"
    echo "extra_objs ${extra_objs}"
    echo "extra_options ${extra_options}"
    echo "out_file ${out_file}"
    echo "md_file ${md_file}"
    # The header list this target's tm.h is built from, in the same form the
    # single-target path uses.  $( ) rather than backticks: this is inside the
    # substitution capturing the stanza.
    # The tail the single-target path appends to tm_file further down --
    # initfini-array.h, tm-dwarf2.h, and defaults.h last of all -- is added
    # after this loop has run, so mirror it here.  The two lists must agree:
    # anything the primary tm.h gets and a per-back-end tm-<base>.h does not is
    # a macro some back end will turn out to need, and defaults.h in particular
    # is where target_unit and friends come from.
    mt_tm_file="${tm_file} initfini-array.h"
    if test x"${dwarf2}" = xyes; then
      mt_tm_file="${mt_tm_file} tm-dwarf2.h"
    fi
    mt_tm_file="${mt_tm_file} defaults.h"

    mt_tm_include_list="options.h insn-constants.h"
    for mt_f in ${mt_tm_file}; do
      case ${mt_f} in
	./* ) mt_tm_include_list="${mt_tm_include_list} $(echo ${mt_f} | sed 's/^..//')" ;;
	defaults.h ) mt_tm_include_list="${mt_tm_include_list} ${mt_f}" ;;
	* ) mt_tm_include_list="${mt_tm_include_list} config/${mt_f}" ;;
      esac
    done
    echo "tm_include_list ${mt_tm_include_list}"
    echo "tm_defines ${tm_defines}"
    # The value TARGET_CPU_DEFAULT must have in this target's tm.h.  Without it
    # a back end that reads the macro -- nds32 does -- does not compile.
    echo "target_cpu_default ${target_cpu_default}"
    # This back end's extra machine modes.  The generators are built once per
    # back end against these (see gen-multi-target-md.awk); reading a target's
    # .md without them fails on the modes only that target defines.  Recorded
    # rather than derived: most back ends do call the file
    # <cpu>/<cpu>-modes.def, but config.gcc is the authority and nothing
    # obliges a back end to follow the convention.
    echo "extra_modes ${extra_modes}"
    # Headers this target's tm.h includes that no source tree contains: the
    # tmake_file fragments generate them into the build directory.  They are
    # listed separately because their names have to be made unique per back end
    # (three different back ends generate a file called sysroot-suffix.h) and
    # because something has to create them.
    mt_tm_gen_headers=
    for mt_f in ${tm_file}; do
      case ${mt_f} in
	./* ) mt_tm_gen_headers="${mt_tm_gen_headers} $(echo ${mt_f} | sed 's/^..//')" ;;
      esac
    done
    echo "tm_generated_headers ${mt_tm_gen_headers}"
    # The multilib set is NOT a config.gcc variable: MULTILIB_OPTIONS,
    # MULTILIB_MATCHES, MULTILIB_REUSE and MULTILIB_OSDIRNAMES are make
    # variables, assigned by the 136 t-* fragments named in tmake_file, so they
    # cannot be captured by sourcing config.gcc here.  Reading them needs make
    # to evaluate that target's fragments; see the multilib rules in
    # gcc/Makefile.in.
    #
    # What config.gcc does own is the input those fragments compute from, and
    # without it the answer is wrong rather than merely missing -- sh/t-sh
    # derives MULTILIB_OPTIONS from $(TM_MULTILIB_CONFIG) and yields an empty
    # list when it is unset.  So it is recorded here, for the make side to feed
    # back in.
    echo "tm_multilib_config ${TM_MULTILIB_CONFIG}"
  ` || {
    # Read the message here, not in the AC_MSG_ERROR argument: that argument is
    # m4-quoted, so a substitution written inside it is emitted literally and the
    # user is shown the backtick expression instead of what config.gcc said.
    gcc_mt_msg=`cat ${gcc_mt_err} 2>/dev/null | tr '\n' ' '`
    AC_MSG_ERROR([--enable-targets: config.gcc failed for ${gcc_mt}: ${gcc_mt_msg}])
  }
  echo "${gcc_mt_data}" >> ${gcc_target_manifest}
  echo "" >> ${gcc_target_manifest}

  # Collect each target's common-hook table so the build can compile all of
  # them.  Duplicates are real: several targets share one common file (and every
  # target without its own uses default-common.cc), so the same object must not
  # be listed, or built, twice.
  gcc_mt_cof=`echo "${gcc_mt_data}" | sed -n 's/^common_out_file //p'`
  gcc_mt_sym=`echo "${gcc_mt_data}" | sed -n 's/^common_out_symbol //p'`
  gcc_mt_obj=`basename ${gcc_mt_cof} .cc`.o
  gcc_mt_base=`basename ${gcc_mt_cof} -common.cc`
  gcc_mt_incl=`echo "${gcc_mt_data}" | sed -n 's/^tm_include_list //p'`
  gcc_mt_tmdef=`echo "${gcc_mt_data}" | sed -n 's/^tm_defines //p'`
  gcc_mt_eopts=`echo "${gcc_mt_data}" | sed -n 's/^extra_options //p'`
  # This target's tm.h must pull in this target's options.h, not the generic
  # one: the types and enums a back end needs -- aarch64_feature_flags, bfin's
  # WA_*, alpha's MASK_SOFT_FP -- reach a build through the .opt files'
  # HeaderInclude directives, and so exist only in a generated options header
  # that was built with those .opt files.
  gcc_mt_md=`echo "${gcc_mt_data}" | sed -n 's/^md_file //p'`
  gcc_mt_incl=`echo "${gcc_mt_incl}" | sed -e "s|^options\.h|options-${gcc_mt_base}.h|" -e "s|insn-constants\.h|insn-constants-${gcc_mt_base}.h|"`
  # config.gcc sets this per target and some back ends' tm.h reads it (nds32
  # builds its default ISA out of it); passing the primary target's value, or
  # nothing at all, is not an option.
  gcc_mt_tcd=`echo "${gcc_mt_data}" | sed -n 's/^target_cpu_default //p'`
  # The same treatment for the headers a target's tmake_file would generate
  # into the build directory.  These need it more than options.h does: three
  # different back ends generate a file called sysroot-suffix.h, so under one
  # name at most one of them could be right.
  gcc_mt_genh=`echo "${gcc_mt_data}" | sed -n 's/^tm_generated_headers //p'`
  gcc_mt_genh_files=
  for gcc_mt_h in ${gcc_mt_genh}; do
    gcc_mt_hb=`basename ${gcc_mt_h} .h`
    gcc_mt_incl=`echo "${gcc_mt_incl}" | sed -e "s|\\([[ ]]\\)${gcc_mt_hb}\\.h|\\1${gcc_mt_hb}-${gcc_mt_base}.h|g"`
    gcc_mt_genh_files="${gcc_mt_genh_files} ${gcc_mt_hb}-${gcc_mt_base}.h"
  done
  # gcc_mt_eopts is deliberately NOT turned into a make rule here.  It is read
  # back out of the manifest by the union pass after this loop; see there.
  case " ${gcc_all_common_objects} " in
    *" ${gcc_mt_obj} "*) ;;
    *) gcc_all_common_objects="${gcc_all_common_objects} ${gcc_mt_obj}"
       gcc_all_common_symbols="${gcc_all_common_symbols} ${gcc_mt_sym}"
       # One rule per object.  A pattern rule cannot serve here: the objects
       # sit in the build root but their sources are under
       # common/config/<cpu>/, and vpath cannot glob those directories.  The
       # -D is what gives each table a name of its own.
       # Each back end gets a tm.h of its own, under a name of its own, rather
       # than every back end sharing the one tm.h and 46 of them getting some
       # other target's macros.  default-common.cc includes no tm.h and so
       # needs none.
       if test x"${gcc_mt_base}" != xdefault; then
         # This back end's own options header is NOT emitted here.  It cannot
         # be: it has to be built from the .opt files of ALL this back end's
         # triples, and inside this loop only the first one has been seen.  See
         # the union pass after the loop.
         # ... and this back end's constants, from its own machine description
         # rather than whichever target happened to generate insn-constants.h.
         printf 'insn-constants-%s.h: build/genconstants$(build_exeext) $(srcdir)/config/%s\n\t$(RUN_GEN) build/genconstants$(build_exeext) $(srcdir)/config/%s > $@\n\n' \
           "${gcc_mt_base}" "${gcc_mt_md}" "${gcc_mt_md}" >> ${gcc_common_mk}
         # The build-directory headers this target's tm.h includes, holding
         # multilib-derived spec macros -- SYSROOT_SUFFIX_SPEC and friends.
         #
         # These were empty placeholders while the multilib data did not exist:
         # a multi-target build includes no single target's tmake_file, so
         # MULTILIB_OPTIONS and friends were unset and the generators had
         # nothing to work from.  That data is now extracted per target into
         # multi-target.multilib, so the real content can be produced.
         # gen-sysroot-suffix.sh does it, and documents which targets still
         # cannot be answered on this side of the build, and why.
         # Two kinds end up in this list and they need different treatment.
         for gcc_mt_h in ${gcc_mt_genh_files}; do
           case ${gcc_mt_h} in
             *sysroot-suffix*)
               printf '%s: multi-target.manifest multi-target.multilib $(srcdir)/gen-sysroot-suffix.sh\n\t$(SHELL) $(srcdir)/gen-sysroot-suffix.sh %s multi-target.manifest multi-target.multilib $(srcdir) > $@\n\n' \
                 "${gcc_mt_h}" "${gcc_mt}" >> ${gcc_common_mk}
               ;;
             *)
               # The rest are headers a config/<cpu>/t-<cpu>-headers fragment
               # already generates under its plain name, which we then renamed
               # per back end so that two back ends generating the same name do
               # not collide.  The renamed copy has to be the fragment's output;
               # generating it empty meant tm-gcn.h included a
               # gcn-device-macros-gcn.h with nothing in it while the real
               # 158-line gcn-device-macros.h sat unused beside it.  That was
               # true before this rule existed and would have kept being true.
               gcc_mt_horig=`echo "${gcc_mt_h}" | sed "s/-${gcc_mt_base}\\.h\$/.h/"`
               printf '%s: %s\n\tcp $< $@\n\n' \
                 "${gcc_mt_h}" "${gcc_mt_horig}" >> ${gcc_common_mk}
               ;;
           esac
         done
         printf 'tm-%s.h: options-%s.h insn-constants-%s.h%s Makefile\n\tTARGET_CPU_DEFAULT="%s" HEADERS="%s" DEFINES="%s" \\\n\t  $(SHELL) $(srcdir)/mkconfig.sh tm-%s.h\n\n' \
           "${gcc_mt_base}" "${gcc_mt_base}" "${gcc_mt_base}" "${gcc_mt_genh_files}" "${gcc_mt_tcd}" "${gcc_mt_incl}" "${gcc_mt_tmdef}" "${gcc_mt_base}" >> ${gcc_common_mk}
         printf '%s: $(srcdir)/common/config/%s tm-%s.h\n\t$(COMPILE) -DTARGETM_COMMON_SYMBOL=%s $<\n\t$(POSTCOMPILE)\n\n' \
           "${gcc_mt_obj}" "${gcc_mt_cof}" "${gcc_mt_base}" "${gcc_mt_sym}" >> ${gcc_common_mk}
         gcc_all_common_tm_headers="${gcc_all_common_tm_headers} tm-${gcc_mt_base}.h"
         # This back end's driver spec functions, from the same tm-<base>.h.
         # Only bases that HAVE one: the handful that share default-common.cc
         # have no tm-<base>.h to compile against, and are mapped to the empty
         # table below.  Checked, not assumed -- none of the sixteen headers
         # that define EXTRA_SPEC_FUNCTIONS belongs to that group.
         # The -D has to reach the compiler as -DTM_H_FILE='"tm-<base>.h"':
         # a string literal for #include, single-quoted so make and the shell
         # keep the inner quotes.  Assembled here rather than nested inside the
         # printf format, where three layers of quoting (m4, shell, make) had
         # to be got right at once and a mistake produces a valid-looking rule
         # that includes the wrong header.
         gcc_mt_tmflag="-DTM_H_FILE='\"tm-${gcc_mt_base}.h\"'"
         printf 'spec-functions-%s.o: $(srcdir)/spec-functions.cc tm-%s.h $(GCC_H)\n\t$(COMPILE) %s -DSPEC_FUNCTIONS_SYMBOL=extra_spec_functions_%s $(srcdir)/spec-functions.cc\n\t$(POSTCOMPILE)\n\n' \
           "${gcc_mt_base}" "${gcc_mt_base}" "${gcc_mt_tmflag}" "${gcc_mt_base}" >> ${gcc_common_mk}
         gcc_all_spec_fn_objects="${gcc_all_spec_fn_objects} spec-functions-${gcc_mt_base}.o"
         # @<:@ and @:>@ are the m4 quadrigraphs for [ and ].  Written literally
         # they are eaten as m4 quotes and the declaration comes out as a
         # scalar -- which still compiles, because the registry then takes its
         # address, and links to a table read one element long.
         printf 'extern const struct spec_function extra_spec_functions_%s@<:@@:>@;\n' \
           "${gcc_mt_base}" >> ${gcc_sf_ext}
       else
         printf '%s: $(srcdir)/common/config/%s\n\t$(COMPILE) -DTARGETM_COMMON_SYMBOL=%s $<\n\t$(POSTCOMPILE)\n\n' \
           "${gcc_mt_obj}" "${gcc_mt_cof}" "${gcc_mt_sym}" >> ${gcc_common_mk}
       fi
       printf 'extern struct gcc_targetm_common %s;\n' "${gcc_mt_sym}" >> ${gcc_common_ext}
       ;;
  esac
  # One entry per target, not per object: several targets can share a table.
  # This is also what forces the tables into the compiler at all -- they are
  # linked from an archive, and a member nothing refers to is simply not pulled
  # in, so without the registry only the --target one ends up in the binary.
  printf '  TARGETM_COMMON_ENTRY ("%s", %s) \\\n' "${gcc_mt}" "${gcc_mt_sym}" >> ${gcc_common_ent}
  # And one spec-function entry per target, for the same reason.  A base with
  # no tm-<base>.h of its own (the group sharing default-common.cc) gets the
  # EMPTY table rather than no entry: "this target publishes no spec functions"
  # and "this target is not in the registry" must stay distinguishable, because
  # gcc.cc treats the second as the two registries having drifted apart.
  if test x"${gcc_mt_base}" != xdefault; then
    printf '  SPEC_FUNCTIONS_ENTRY ("%s", extra_spec_functions_%s) \\\n' \
      "${gcc_mt}" "${gcc_mt_base}" >> ${gcc_sf_ent}
  else
    printf '  SPEC_FUNCTIONS_ENTRY ("%s", spec_functions_empty) \\\n' \
      "${gcc_mt}" >> ${gcc_sf_ent}
  fi
done
rm -f ${gcc_mt_err}

# The options header of a back end, built from the UNION of its triples'
# extra_options.
#
# This has to be a second pass.  Every other per-back-end rule above can be
# emitted the first time a triple of that back end is seen, because what it
# needs -- the .md file, the cpu_type -- is a property of the back end and every
# triple reports the same value.  extra_options is not like that: it is a
# property of the TRIPLE, it is where the OS brings its own options in, and the
# triples of one back end genuinely disagree.  Emitting the rule from the first
# triple therefore silently picked one OS's answer for all of them, which is the
# "first-triple-wins" defect.
#
# What it cost, concretely.  rs6000's first manifest triple is a Darwin one,
# whose extra_options has no rs6000/sysv4.opt.  TARGET_LITTLE_ENDIAN is
# `Mask(LITTLE_ENDIAN)' in that .opt and so was absent from options-rs6000.h;
# config/rs6000/sysv4.h:50 defines TARGET_BIG_ENDIAN in terms of it, a
# constraint in rs6000's .md reaches it through BYTES_BIG_ENDIAN, and
# gencondmd failed to compile for the twelve rs6000 triples whose tm.h chain
# includes sysv4.h.  cc1 could not be linked at all.
#
# The union is taken WITHIN a back end only.  Across back ends it would not be
# safe -- the option names genuinely conflict there, and the Mask() bits do not
# fit -- and that is separate work.  Within a back end it was measured clean:
# for all 45 back ends the unioned .opt set produces an options-<base>.h with no
# `#error', because opt-read.awk merges same-named records (which is how an
# ordinary single-target build already copes with, say, gnu-user.opt and
# linux.opt both declaring -pthread).  One back end needed help to stay inside
# the 32-bit target_flags word: see the note in config/vxworks.opt.
${AWK} '
  # Manifest stanzas are blank-line separated `key value...` lines.
  /^common_out_file / {
    base = $[]2
    sub(/.*\//, "", base)
    sub(/-common\.cc$/, "", base)
    next
  }
  /^extra_options / {
    for (i = 2; i <= NF; i++)
      opt[[i]] = $[]i
    n = NF
    next
  }
  /^$/ { flush() }
  END { flush() }

  function flush(   i, f) {
    # default-common.cc back ends have no options-<base>.h at all.
    if (base != "" && base != "default") {
      for (i = 2; i <= n; i++) {
	f = opt[[i]]
	# Order is preserved and duplicates dropped: opt-gather.awk is fed
	# each file once, and a file listed twice would be gathered twice.
	if (!((base SUBSEP f) in seen)) {
	  seen[[base SUBSEP f]] = 1
	  files[[base]] = files[[base]] " $(srcdir)/config/" f
	}
	# ... and the same files unioned across ALL back ends.  This list is
	# NOT used to generate any table: it is used only to collect the set of
	# option NAMES, so that every generated options header in the build can
	# be padded up to it, so that enum opt_code means one thing.  See
	# gcc/opt-stub.awk for why the data must not be unioned with it.
	if (!(f in seenall)) {
	  seenall[[f]] = 1
	  allfiles = allfiles " $(srcdir)/config/" f
	}
      }
      if (!(base in emitted)) {
	emitted[[base]] = 1
	order[[++nbase]] = base
      }
    }
    base = ""; n = 0
  }

  END {
    # The .opt files of every configured back end.  gcc/Makefile.in feeds this to
    # opt-gather.awk to build optionlist-vocab, the union of option NAMES.
    printf "MT_OPT_UNION_FILES =%s\n\n", allfiles
    for (i = 1; i <= nbase; i++) {
      b = order[[i]]
      # This back end own records, PLUS a placeholder for every name in the
      # vocabulary it does not declare.  Without the padding this header
      # numbers enum opt_code by this back end option set alone, while
      # opts.cc is numbered by the shared one, and the two disagree: an OPT_
      # value produced in common/config/<cpu>/<cpu>-common.cc and consumed in
      # opts.cc then names a different option.  That is what made
      # default_options_optimization walk this back end
      # option_optimization_table straight into parse_sanitizer_options.
      printf "optionlist-%s: $(lang_opt_files)%s optionlist-vocab $(srcdir)/opt-gather.awk $(srcdir)/opt-functions.awk $(srcdir)/opt-stub.awk\n", b, files[[b]]
      printf "\tLC_ALL=C; export LC_ALL; \\\n"
      printf "\t$(AWK) -f $(srcdir)/opt-gather.awk $(lang_opt_files)%s > $@.own\n", files[[b]]
      printf "\t$(AWK) -f $(srcdir)/opt-functions.awk -f $(srcdir)/opt-stub.awk \\\n"
      printf "\t  -v vocab=optionlist-vocab optionlist-vocab $@.own > $@.stub\n"
      printf "\t@echo \"$@: `wc -l < $@.own` own + `wc -l < $@.stub` placeholder records\"\n"
      printf "\tLC_ALL=C; export LC_ALL; \\\n"
      printf "\tcat $@.own $@.stub | sort > $@\n"
      printf "\trm -f $@.own $@.stub\n\n"
      printf "options-%s.h: optionlist-%s $(srcdir)/opt-functions.awk $(srcdir)/opt-read.awk $(srcdir)/opth-gen.awk\n", b, b
      printf "\t$(AWK) -f $(srcdir)/opt-functions.awk -f $(srcdir)/opt-read.awk \\\n"
      # A guard of its own.  Sharing one guard across the shared options.h and
      # the other 44 made a second include of the family a silent no-op instead
      # of an error, so which options a TU got depended on include ORDER.
      # See opth-gen.awk.
      printf "\t  -v guard_name=OPTIONS_%s_H \\\n", toupper(b)
      printf "\t  -f $(srcdir)/opth-gen.awk < $< > $@\n\n"
    }
  }
' ${gcc_target_manifest} >> ${gcc_common_mk}

# Assemble the registry header from the two pieces.
{
  echo "/* Generated by configure.  Every configured target's common hook table."
  echo "   Do not edit.  */"
  echo ""
  cat ${gcc_common_ext}
  echo ""
  echo "#define TARGETM_COMMON_TABLES \\"
  cat ${gcc_common_ent}
  echo "  /* end of table */"
} > multi-target-common.h
rm -f ${gcc_common_ext} ${gcc_common_ent}

# The same, for the driver's spec-function tables.
{
  echo "/* Generated by configure.  Every configured target's driver"
  echo "   spec-function table.  Do not edit.  */"
  echo ""
  cat ${gcc_sf_ext}
  echo ""
  echo "#define SPEC_FUNCTIONS_TABLES \\"
  cat ${gcc_sf_ent}
  echo "  /* end of table */"
} > multi-target-spec-functions.h
rm -f ${gcc_sf_ext} ${gcc_sf_ent}

AC_SUBST(gcc_manifest_targets)
AC_SUBST(gcc_all_common_objects)
AC_SUBST(gcc_all_common_symbols)
AC_SUBST(gcc_all_spec_fn_objects)
if test x"${gcc_extra_targets}" != x; then
  AC_MSG_NOTICE([additional targets: ${gcc_extra_targets}])
fi
AC_SUBST(gcc_extra_targets)

extra_objs="${host_extra_objs} ${extra_objs}"
extra_gcc_objs="${host_extra_gcc_objs} ${extra_gcc_objs}"

# Default the target-machine variables that were not explicitly set.
if test x"$tm_file" = x
then tm_file=$cpu_type/$cpu_type.h; fi

if test x"$extra_headers" = x
then extra_headers=; fi

if test x$md_file = x
then md_file=$cpu_type/$cpu_type.md; fi

if test x$out_file = x
then out_file=$cpu_type/$cpu_type.cc; fi

if test x"$tmake_file" = x
then tmake_file=$cpu_type/t-$cpu_type
fi

# initfini-array.h is self-guarding: its body is wrapped in
# `#if HAVE_INITFINI_ARRAY_SUPPORT', which config/elfos.h raises for ELF
# targets, so it can simply always be in the bundle.
tm_file="${tm_file} initfini-array.h"

if test x"$dwarf2" = xyes
then tm_file="$tm_file tm-dwarf2.h"
fi

# Say what files are being used for the output code and MD file.
echo "Using \`$srcdir/config/$out_file' for machine-specific logic."
echo "Using \`$srcdir/config/$md_file' as machine description file."

# If any of the xm_file variables contain nonexistent files, warn
# about them and drop them.

bx=
for x in $build_xm_file; do
  if    test -f $srcdir/config/$x
  then      bx="$bx $x"
  else      AC_MSG_WARN($srcdir/config/$x does not exist.)
  fi
done
build_xm_file="$bx"

hx=
for x in $host_xm_file; do
  if    test -f $srcdir/config/$x
  then      hx="$hx $x"
  else      AC_MSG_WARN($srcdir/config/$x does not exist.)
  fi
done
host_xm_file="$hx"

tx=
for x in $xm_file; do
  if    test -f $srcdir/config/$x
  then      tx="$tx $x"
  else      AC_MSG_WARN($srcdir/config/$x does not exist.)
  fi
done
xm_file="$tx"

count=a
for f in $tm_file; do
	count=${count}x
done
if test $count = ax; then
	echo "Using \`$srcdir/config/$tm_file' as target machine macro file."
else
	echo "Using the following target machine macro files:"
	for f in $tm_file; do
		echo "	$srcdir/config/$f"
	done
fi

if test x$use_long_long_for_widest_fast_int = xyes; then
	AC_DEFINE(USE_LONG_LONG_FOR_WIDEST_FAST_INT, 1,
[Define to 1 if the 'long long' type is wider than 'long' but still
efficiently supported by the host hardware.])
fi

count=a
for f in $host_xm_file; do
	count=${count}x
done
if test $count = a; then
	:
elif test $count = ax; then
	echo "Using \`$srcdir/config/$host_xm_file' as host machine macro file."
else
	echo "Using the following host machine macro files:"
	for f in $host_xm_file; do
		echo "	$srcdir/config/$f"
	done
fi
echo "Using ${out_host_hook_obj} for host machine hooks."

if test "$host_xm_file" != "$build_xm_file"; then
	count=a
	for f in $build_xm_file; do
		count=${count}x
	done
	if test $count = a; then
		:
	elif test $count = ax; then
		echo "Using \`$srcdir/config/$build_xm_file' as build machine macro file."
	else
		echo "Using the following build machine macro files:"
		for f in $build_xm_file; do
			echo "	$srcdir/config/$f"
		done
	fi
fi

if test -n "$configured_native_system_header_dir"; then
  native_system_header_dir=$configured_native_system_header_dir
fi
NATIVE_SYSTEM_HEADER_DIR="$native_system_header_dir"
AC_SUBST(NATIVE_SYSTEM_HEADER_DIR)

case ${host} in
  powerpc*-*-darwin*)
    AC_CACHE_CHECK([whether mcontext_t fields have underscores],
      gcc_cv_mcontext_underscores,
      AC_COMPILE_IFELSE([AC_LANG_SOURCE([
#include <sys/cdefs.h>
#include <sys/signal.h>
#include <ucontext.h>
int main() { mcontext_t m; if (m->ss.srr0) return 0; return 0; }
])],
	gcc_cv_mcontext_underscores=no, gcc_cv_mcontext_underscores=yes))
      if test $gcc_cv_mcontext_underscores = yes; then
        AC_DEFINE(HAS_MCONTEXT_T_UNDERSCORES,,dnl
          [mcontext_t fields start with __])
      fi
    ;;
esac


# --------
# UNSORTED
# --------

use_cxa_atexit=no
if test x$enable___cxa_atexit = xyes || \
   test x$enable___cxa_atexit = x -a x$default_use_cxa_atexit = xyes; then
  if test x$host = x$target; then
    case $host in
      # mingw32 doesn't have __cxa_atexit but uses atexit registration
      # keyed to flag_use_cxa_atexit
      *-*-mingw32*)
	use_cxa_atexit=yes
	;;
      powerpc-ibm-aix*)
	use_cxa_atexit=yes
	;;
      *)
	AC_CHECK_FUNC(__cxa_atexit,[use_cxa_atexit=yes],
	  [echo "__cxa_atexit can't be enabled on this target"])
	;;
    esac
  else
    # We can't check for __cxa_atexit when building a cross, so assume
    # it is available 
    use_cxa_atexit=yes
  fi
  if test x$use_cxa_atexit = xyes; then
    AC_DEFINE(DEFAULT_USE_CXA_ATEXIT, 2,
      [Define if you want to use __cxa_atexit, rather than atexit, to
      register C++ destructors for local statics and global objects.
      This is essential for fully standards-compliant handling of
      destructors, but requires __cxa_atexit in libc.])
  fi
fi

# Look for a file containing extra machine modes.
if test -n "$extra_modes" && test -f $srcdir/config/$extra_modes; then
  extra_modes_file='$(srcdir)'/config/${extra_modes}
  AC_SUBST(extra_modes_file)
  AC_DEFINE_UNQUOTED(EXTRA_MODES_FILE, "config/$extra_modes",
  [Define to the name of a file containing a list of extra machine modes
   for this architecture.])
fi

# Convert extra_options into a form suitable for Makefile use.
extra_opt_files=
all_opt_files=
for f in $extra_options; do
  extra_opt_files="$extra_opt_files \$(srcdir)/config/$f"
  all_opt_files="$all_opt_files $srcdir/config/$f"
done
AC_SUBST(extra_opt_files)

# auto-host.h is the file containing items generated by autoconf and is
# the first file included by config.h.
# If host=build, it is correct to have bconfig include auto-host.h
# as well.  If host!=build, we are in error and need to do more 
# work to find out the build config parameters.
if test x$host = x$build
then
	build_auto=auto-host.h
	HAVE_AUTO_BUILD='# '
else
	# We create a subdir, then run autoconf in the subdir.
	# To prevent recursion we set host and build for the new
	# invocation of configure to the build for this invocation
	# of configure. 
	tempdir=build.$$
	rm -rf $tempdir
	mkdir $tempdir
	cd $tempdir
	case ${srcdir} in
	/* | [A-Za-z]:[\\/]* ) realsrcdir=${srcdir};;
	*) realsrcdir=../${srcdir};;
	esac
	# Clearing GMPINC is necessary to prevent host headers being
	# used by the build compiler.  Defining GENERATOR_FILE stops
	# system.h from including gmp.h.
	CC="${CC_FOR_BUILD}" CFLAGS="${CFLAGS_FOR_BUILD}" \
	CXX="${CXX_FOR_BUILD}" CXXFLAGS="${CXXFLAGS_FOR_BUILD}" \
	LD="${LD_FOR_BUILD}" LDFLAGS="${LDFLAGS_FOR_BUILD}" \
	GMPINC="" CPPFLAGS="${CPPFLAGS_FOR_BUILD} -DGENERATOR_FILE" \
	${realsrcdir}/configure \
		--enable-languages=${enable_languages-all} \
		${enable_option_checking+--enable-option-checking="$enable_option_checking"} \
		--target=$target_alias --host=$build_alias \
		--build=$build_alias || exit # retaining $tempdir

	# We just finished tests for the build machine, so rename
	# the file auto-build.h in the gcc directory.
	mv auto-host.h ../auto-build.h
	cd ..
	rm -rf $tempdir
	build_auto=auto-build.h
	HAVE_AUTO_BUILD=
fi
AC_SUBST(build_subdir)
AC_SUBST(HAVE_AUTO_BUILD)

tm_file="${tm_file} defaults.h"
tm_p_file="${tm_p_file} tm-preds.h"
host_xm_file="auto-host.h ansidecl.h ${host_xm_file}"
build_xm_file="${build_auto} ansidecl.h ${build_xm_file}"
# We don't want ansidecl.h in target files, write code there in ISO/GNU C.
# put this back in temporarily.
xm_file="auto-host.h ansidecl.h ${xm_file}"

# --------
# UNSORTED
# --------

changequote(,)dnl
# Compile in configure arguments.
if test -f configargs.h ; then
	# Being re-configured.
	gcc_config_arguments=`grep configuration_arguments configargs.h | sed -e 's/.*"\([^"]*\)".*/\1/'`
	gcc_reconf_arguments=`echo "$gcc_config_arguments" | sed -e 's/^.*\( : (reconfigured) .*$\)/\1/'`
	if [ "$gcc_reconf_arguments" != " : (reconfigured) $TOPLEVEL_CONFIGURE_ARGUMENTS" ]; then
		gcc_config_arguments="$gcc_config_arguments : (reconfigured) $TOPLEVEL_CONFIGURE_ARGUMENTS"
	fi
else
	gcc_config_arguments="$TOPLEVEL_CONFIGURE_ARGUMENTS"
fi

# Double all backslashes and backslash all quotes to turn
# gcc_config_arguments into a C string.
sed -e 's/\\/\\\\/g; s/"/\\"/g' <<EOF >conftest.out
$gcc_config_arguments
EOF
gcc_config_arguments_str=`cat conftest.out`
rm -f conftest.out

cat > configargs.h <<EOF
/* Generated automatically. */
static const char configuration_arguments[] = "$gcc_config_arguments_str";
static const char thread_model[] = "$thread_file";
EOF
changequote([,])dnl

changequote(,)dnl
gcc_BASEVER=`cat $srcdir/BASE-VER`
gcc_DEVPHASE=`cat $srcdir/DEV-PHASE`
gcc_DATESTAMP=`cat $srcdir/DATESTAMP`
if test -f $srcdir/REVISION ; then
	gcc_REVISION=`cat $srcdir/REVISION`
else
        gcc_REVISION=""
fi
cat > plugin-version.h <<EOF
#include "configargs.h"

#define GCCPLUGIN_VERSION_MAJOR   `echo $gcc_BASEVER | sed -e 's/^\([0-9]*\).*$/\1/'`
#define GCCPLUGIN_VERSION_MINOR   `echo $gcc_BASEVER | sed -e 's/^[0-9]*\.\([0-9]*\).*$/\1/'`
#define GCCPLUGIN_VERSION_PATCHLEVEL   `echo $gcc_BASEVER | sed -e 's/^[0-9]*\.[0-9]*\.\([0-9]*\)$/\1/'`
#define GCCPLUGIN_VERSION  (GCCPLUGIN_VERSION_MAJOR*1000 + GCCPLUGIN_VERSION_MINOR)

static char basever[] = "$gcc_BASEVER";
static char datestamp[] = "$gcc_DATESTAMP";
static char devphase[] = "$gcc_DEVPHASE";
static char revision[] = "$gcc_REVISION";

/* FIXME plugins: We should make the version information more precise.
   One way to do is to add a checksum. */

static struct plugin_gcc_version gcc_version = {basever, datestamp,
						devphase, revision,
						configuration_arguments};
EOF
changequote([,])dnl

# Determine what GCC version number to use in filesystem paths.
GCC_BASE_VER

# Internationalization
ZW_GNU_GETTEXT_SISTER_DIR

# If LIBINTL contains LIBICONV, then clear LIBICONV so we don't get
# -liconv on the link line twice.
case "$LIBINTL" in *$LIBICONV*)
	LIBICONV= ;;
esac


# Windows32 Registry support for specifying GCC installation paths.
AC_ARG_ENABLE(win32-registry,
[AS_HELP_STRING([--disable-win32-registry],
                [disable lookup of installation paths in the
                 Registry on Windows hosts])
AS_HELP_STRING([--enable-win32-registry], [enable registry lookup (default)])
AS_HELP_STRING([--enable-win32-registry=KEY],
               [use KEY instead of GCC version as the last portion
                of the registry key])],,)

case $host_os in
  win32 | pe | cygwin* | mingw32*)
    if test "x$enable_win32_registry" != xno; then
      AC_SEARCH_LIBS(RegOpenKeyExA, advapi32,, [enable_win32_registry=no])
    fi

    if test "x$enable_win32_registry" != xno; then
      AC_DEFINE(ENABLE_WIN32_REGISTRY, 1,
  [Define to 1 if installation paths should be looked up in the Windows
   Registry. Ignored on non-Windows hosts.])

      if test "x$enable_win32_registry" != xyes \
         && test "x$enable_win32_registry" != x; then
	AC_DEFINE_UNQUOTED(WIN32_REGISTRY_KEY, "$enable_win32_registry",
  [Define to be the last component of the Windows registry key under which
   to look for installation paths.  The full key used will be 
   HKEY_LOCAL_MACHINE/SOFTWARE/Free Software Foundation/{WIN32_REGISTRY_KEY}.
   The default is the GCC version number.])
      fi
    fi
  ;;
esac

# Get an absolute path to the GCC top-level source directory
holddir=`${PWDCMD-pwd}`
cd $srcdir
topdir=`${PWDCMD-pwd}`
cd $holddir

# Conditionalize the makefile for this host machine.
xmake_file=
for f in ${host_xmake_file}
do
	if test -f ${srcdir}/config/$f
	then
		xmake_file="${xmake_file} \$(srcdir)/config/$f"
	fi
done

# Conditionalize the makefile for this target machine.
tmake_file_=
for f in ${tmake_file}
do
	if test -f ${srcdir}/config/$f
	then
		tmake_file_="${tmake_file_} \$(srcdir)/config/$f"
	fi
done
tmake_file="${tmake_file_}${omp_device_property_tmake_file}"

out_object_file=`basename $out_file .cc`.o
common_out_object_file=`basename $common_out_file .cc`.o

# Name this target's common hook table is defined under.  Every target used to
# call it `targetm_common', which is why two of them could never be linked into
# the same compiler.  Derived from the file name so it needs no new data, and
# sanitised because it becomes a C identifier.
# NB: no brackets in the sed expression.  `[' and `]' are m4 quote characters, so
# a character class here is silently eaten and the substitution never happens --
# which produced `targetm_common_i386-common' and a compile error on the `-'.
# Hyphen is the only character these file names contain that a C identifier
# cannot, so replacing it directly avoids the problem entirely.
common_out_symbol=targetm_common_`basename $common_out_file .cc | sed 's/-/_/g'`
AC_SUBST(common_out_symbol)

tm_file_list="options.h"
tm_include_list="options.h insn-constants.h"
for f in $tm_file; do
  case $f in
    ./* )
       f=`echo $f | sed 's/^..//'`
       tm_file_list="${tm_file_list} $f"
       tm_include_list="${tm_include_list} $f"
       ;;
    defaults.h )
       tm_file_list="${tm_file_list} \$(srcdir)/$f"
       tm_include_list="${tm_include_list} $f"
       ;;
    * )
       tm_file_list="${tm_file_list} \$(srcdir)/config/$f"
       tm_include_list="${tm_include_list} config/$f"
       ;;
  esac
done

tm_p_file_list=
tm_p_include_list=
for f in $tm_p_file; do
  case $f in
    tm-preds.h )
       tm_p_file_list="${tm_p_file_list} $f"
       tm_p_include_list="${tm_p_include_list} $f"
       ;;
    * )
       tm_p_file_list="${tm_p_file_list} \$(srcdir)/config/$f"
       tm_p_include_list="${tm_p_include_list} config/$f"
  esac
done

tm_d_file_list=
tm_d_include_list=
for f in $tm_d_file; do
  case $f in
    * )
       tm_d_file_list="${tm_d_file_list} \$(srcdir)/config/$f"
       tm_d_include_list="${tm_d_include_list} config/$f"
       ;;
  esac
done

tm_rust_file_list=
tm_rust_include_list=
for f in $tm_rust_file; do
  case $f in
    * )
       tm_rust_file_list="${tm_rust_file_list} \$(srcdir)/config/$f"
       tm_rust_include_list="${tm_rust_include_list} config/$f"
       ;;
  esac
done

tm_jit_file_list=
tm_jit_include_list=
for f in $tm_jit_file; do
  case $f in
    * )
       tm_jit_file_list="${tm_jit_file_list} \$(srcdir)/config/$f"
       tm_jit_include_list="${tm_jit_include_list} config/$f"
       ;;
  esac
done

xm_file_list=
xm_include_list=
for f in $xm_file; do
  case $f in
    ansidecl.h )
       xm_file_list="${xm_file_list} \$(srcdir)/../include/$f"
       xm_include_list="${xm_include_list} $f"
       ;;
    auto-host.h )
       xm_file_list="${xm_file_list} $f"
       xm_include_list="${xm_include_list} $f"
       ;;
    * )
       xm_file_list="${xm_file_list} \$(srcdir)/config/$f"
       xm_include_list="${xm_include_list} config/$f"
       ;;
  esac
done

host_xm_file_list=
host_xm_include_list=
for f in $host_xm_file; do
  case $f in
    ansidecl.h )
       host_xm_file_list="${host_xm_file_list} \$(srcdir)/../include/$f"
       host_xm_include_list="${host_xm_include_list} $f"
       ;;
    auto-host.h )
       host_xm_file_list="${host_xm_file_list} $f"
       host_xm_include_list="${host_xm_include_list} $f"
       ;;
    * )
       host_xm_file_list="${host_xm_file_list} \$(srcdir)/config/$f"
       host_xm_include_list="${host_xm_include_list} config/$f"
       ;;
  esac
done

build_xm_file_list=
for f in $build_xm_file; do
  case $f in
    ansidecl.h )
       build_xm_file_list="${build_xm_file_list} \$(srcdir)/../include/$f"
       build_xm_include_list="${build_xm_include_list} $f"
       ;;
    auto-build.h | auto-host.h )
       build_xm_file_list="${build_xm_file_list} $f"
       build_xm_include_list="${build_xm_include_list} $f"
       ;;
    * )
       build_xm_file_list="${build_xm_file_list} \$(srcdir)/config/$f"
       build_xm_include_list="${build_xm_include_list} config/$f"
       ;;
  esac
done

# Define macro CROSS_DIRECTORY_STRUCTURE in compilation if this is a
# cross-compiler which does not use the native headers and libraries.
# Also use all.cross instead of all.internal and adjust SYSTEM_HEADER_DIR.
CROSS=						AC_SUBST(CROSS)
ALL=all.internal				AC_SUBST(ALL)
SYSTEM_HEADER_DIR='$(NATIVE_SYSTEM_HEADER_DIR)'	AC_SUBST(SYSTEM_HEADER_DIR)
BUILD_SYSTEM_HEADER_DIR=$SYSTEM_HEADER_DIR	AC_SUBST(BUILD_SYSTEM_HEADER_DIR)

dnl target_header_dir is GONE.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:2860".
if test "x$with_build_sysroot" != x; then
  BUILD_SYSTEM_HEADER_DIR=$with_build_sysroot'$${sysroot_headers_suffix}$(NATIVE_SYSTEM_HEADER_DIR)'
fi

dnl The machine whose system headers fixincludes is fixing.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:2879".
AC_ARG_WITH(fixincludes-machine,
[AS_HELP_STRING([--with-fixincludes-machine=MACHINE],
                [machine name whose system headers fixincludes should fix;
                 needed only with --with-build-sysroot, where the headers are
                 not the host's])],
[fixincludes_machine="$withval"],
[if test "x$with_build_sysroot" != x; then
   fixincludes_machine=
 else
   fixincludes_machine=$host
 fi])
AC_SUBST(fixincludes_machine)

# If this is using newlib, without having the headers available now,
# then define inhibit_libc in LIBGCC2_CFLAGS.
# This prevents libgcc2 from containing any code which requires libc
# support.
dnl The second half of the old test -- "--with-headers was given but the
dnl headers are not actually ...
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:2911".
: ${inhibit_libc=false}
if test x$with_newlib = xyes && test "x$with_headers" = xno; then
       inhibit_libc=true
fi
AC_SUBST(inhibit_libc)

# When building gcc with a cross-compiler, we need to adjust things so
# that the generator programs are still built with the native compiler.
# Also, we cannot run fixincludes.

# These are the normal (build=host) settings:
CC_FOR_BUILD='$(CC)'		AC_SUBST(CC_FOR_BUILD)
CXX_FOR_BUILD='$(CXX)'		AC_SUBST(CXX_FOR_BUILD)
BUILD_CFLAGS='$(ALL_CFLAGS)'	AC_SUBST(BUILD_CFLAGS)
BUILD_CXXFLAGS='$(ALL_CXXFLAGS)' AC_SUBST(BUILD_CXXFLAGS)
BUILD_LDFLAGS='$(LDFLAGS)'	AC_SUBST(BUILD_LDFLAGS)
STMP_FIXINC=stmp-fixinc		AC_SUBST(STMP_FIXINC)

# And these apply if build != host, or we are generating coverage data
if test x$build != x$host || test "x$coverage_flags" != x
then
    BUILD_CFLAGS='$(INTERNAL_CFLAGS) $(T_CFLAGS) $(CFLAGS-$@) $(CFLAGS_FOR_BUILD)'
    BUILD_CXXFLAGS='$(INTERNAL_CFLAGS) $(T_CFLAGS) $(CFLAGS-$@) $(CXXFLAGS_FOR_BUILD)'
    BUILD_LDFLAGS='$(LDFLAGS_FOR_BUILD)'
fi


if test x$enable_fixincludes = xno;
then
    STMP_FIXINC=''
fi

# Expand extra_headers to include complete path.
# This substitutes for lots of t-* files.
extra_headers_list=
# Prepend $(srcdir)/config/${cpu_type}/ to every entry in extra_headers.
for file in ${extra_headers} ; do
  extra_headers_list="${extra_headers_list} \$(srcdir)/config/${cpu_type}/${file}"
done

# If use_gcc_tgmath is set, append ginclude/tgmath.h.
if test x"$use_gcc_tgmath" = xyes
then extra_headers_list="${extra_headers_list} \$(srcdir)/ginclude/tgmath.h"
fi

# Define collect2 in Makefile.
case $host_can_use_collect2 in
  no) collect2= ;;
  *) collect2='collect2$(exeext)' ;;
esac
AC_SUBST([collect2])

# Add a definition of USE_COLLECT2 if system wants one.
case $use_collect2 in
  no) use_collect2= ;;
  "") ;;
  *) 
    host_xm_defines="${host_xm_defines} USE_COLLECT2"
    xm_defines="${xm_defines} USE_COLLECT2"
    case $host_can_use_collect2 in
      no)
        AC_MSG_ERROR([collect2 is required but cannot be built on this system])
        ;;
    esac
    ;;
esac

AC_DEFINE_UNQUOTED(LTOPLUGINSONAME,"${host_lto_plugin_soname}",
[Define to the name of the LTO plugin DSO that must be
  passed to the linker's -plugin=LIB option.])

# ---------------------------
# Assembler & linker features
# ---------------------------

# During stage 2, ld is actually gcc/collect-ld, which is a small script to
# discern between when to use prev-ld/ld-new and when to use ld/ld-new.
# However when ld-new is first executed from the build tree, libtool will
# relink it as .libs/lt-ld-new, so that it can give it an RPATH that refers
# to the build tree.  While doing this we need to use the previous-stage
# linker, or we have an infinite loop.  The presence of a shell script as
# ld/ld-new, and the fact that the script *uses ld itself*, is what confuses
# the gcc/collect-ld script.  So we need to know how libtool works, or
# exec-tool will fail.

m4_defun([_LT_CONFIG_COMMANDS], [])
LT_INIT
AC_SUBST(objdir)
AC_SUBST(enable_fast_install)

DARWIN_DO_EXTRA_RPATH=0
AC_ARG_WITH(darwin-extra-rpath,
[AS_HELP_STRING(
  [[--with-darwin-extra-rpath=[ARG]]],
   [Specify a runpath directory, additional to those provided by the compiler])],
[if test x"$withval" != x; then
   DARWIN_ADD_RPATH="$withval"
   DARWIN_DO_EXTRA_RPATH=1
 fi])
AC_DEFINE_UNQUOTED(DARWIN_DO_EXTRA_RPATH, $DARWIN_DO_EXTRA_RPATH,
  [Should add an extra runpath directory])
AC_DEFINE_UNQUOTED(DARWIN_ADD_RPATH, "$DARWIN_ADD_RPATH",
  [Specify a runpath directory, additional to those provided by the compiler])

# Identify the assembler which will work hand-in-glove with the newly
# built GCC, so that we can examine its features.  This is the assembler
# which will be driven by the driver program.
#
# If build != host, and we aren't building gas in-tree, we identify a
# build->target assembler and hope that it will have the same features
# as the host->target assembler we'll be using.
gcc_cv_as_gas_srcdir=`echo $srcdir | sed -e 's,/gcc$,,'`/gas

m4_pattern_allow([AS_FOR_TARGET])dnl
AS_VAR_SET_IF(gcc_cv_as,, [
if test -f $gcc_cv_as_gas_srcdir/configure.ac \
     && test -f ../gas/Makefile \
     && test x$build = x$host; then
	gcc_cv_as=../gas/as-new$build_exeext
elif test -x as$build_exeext; then
	# Build using assembler in the current directory.
	gcc_cv_as=./as$build_exeext
elif ( set dummy $AS_FOR_TARGET; test -x $[2] ); then
        gcc_cv_as="$AS_FOR_TARGET"
else
        AC_PATH_PROG(gcc_cv_as, $AS_FOR_TARGET)
fi])


ORIGINAL_AS_FOR_TARGET=$gcc_cv_as
AC_SUBST(ORIGINAL_AS_FOR_TARGET)
case "$ORIGINAL_AS_FOR_TARGET" in
  ./as | ./as$build_exeext) ;;
  *) AC_CONFIG_FILES(as:exec-tool.in, [chmod +x as]) ;;
esac 

if $gcc_cv_as --help 2>&1 | grep -- --fatal-warnings > /dev/null; then
  fw_as_opt=--fatal-warnings
fi

# --enable-ld and --enable-gold are gone.  They chose which of two in-tree
# linkers this compiler would drive -- one of a set of mutually exclusive target
# tools, decided once at build time.  Which linker runs is a property of the
# invocation, and the linker to use already has a home: the `linker' static spec
# in the driver.  Neither was passed by almost any build, so the in-tree ld is
# what the search below now finds, exactly as before.

# Identify the linker which will work hand-in-glove with the newly
# built GCC, so that we can examine its features.  This is the linker
# which will be driven by the driver program.
#
# If build != host, and we aren't building gas in-tree, we identify a
# build->target linker and hope that it will have the same features
# as the host->target linker we'll be using.
gcc_cv_ld_gld_srcdir=`echo $srcdir | sed -e 's,/gcc$,,'`/ld

AS_VAR_SET_IF(gcc_cv_ld,, [
if test -f $gcc_cv_ld_gld_srcdir/configure.ac \
     && test -f ../ld/Makefile \
     && test x$build = x$host; then
	gcc_cv_ld=../ld/ld-new$build_exeext
elif test -x collect-ld$build_exeext; then
	# Build using linker in the current directory.
	gcc_cv_ld=./collect-ld$build_exeext
elif ( set dummy $LD_FOR_TARGET; test -x $[2] ); then
        gcc_cv_ld="$LD_FOR_TARGET"
else
        AC_PATH_PROG(gcc_cv_ld, $LD_FOR_TARGET)
fi])


ORIGINAL_PLUGIN_LD_FOR_TARGET=$gcc_cv_ld
PLUGIN_LD_SUFFIX=`basename $gcc_cv_ld`
# if the PLUGIN_LD is set ld-new, just have it as ld
# as that is the installed named.
if test x$PLUGIN_LD_SUFFIX = xld-new \
   || test x$PLUGIN_LD_SUFFIX = xcollect-ld ; then
  PLUGIN_LD_SUFFIX=ld
fi
# --with-plugin-ld is gone: it named the linker the LTO plugin should be handed
# to, another single target tool chosen at build time.  Not passing it left the
# suffix as the basename of the linker found above -- normally plain `ld' -- and
# that is now the only answer this script gives.
AC_SUBST(ORIGINAL_PLUGIN_LD_FOR_TARGET)
AC_DEFINE_UNQUOTED(PLUGIN_LD_SUFFIX, "$PLUGIN_LD_SUFFIX", [Specify plugin linker])


# Check to see if we are using gold instead of ld
AC_MSG_CHECKING(whether we are using gold)
ld_is_gold=no
if test x$gcc_cv_ld != x; then
  if $gcc_cv_ld --version 2>/dev/null | sed 1q \
     | grep "GNU gold" > /dev/null; then
    ld_is_gold=yes
  fi
fi
AC_MSG_RESULT($ld_is_gold)

# Check to see if we are using mold instead of ld
AC_MSG_CHECKING(whether we are using mold)
ld_is_mold=no
if test x$gcc_cv_ld != x; then
  if $gcc_cv_ld --version 2>/dev/null | sed 1q \
     | grep "mold" > /dev/null; then
    ld_is_mold=yes
  fi
fi
AC_MSG_RESULT($ld_is_mold)

# Check to see if we are using Wild instead of ld
AC_MSG_CHECKING(whether we are using wild)
ld_is_wild=no
if test x$gcc_cv_ld != x; then
  if $gcc_cv_ld --version 2>/dev/null | sed 1q \
     | grep "Wild" > /dev/null; then
    ld_is_wild=yes
  fi
fi
AC_MSG_RESULT($ld_is_wild)

dnl The "is gold available as a non-default linker, and does its split-stack
dnl support cover this target" ...
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3141".

dnl How to give a HOST shared library a version script and an soname.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3164".
AC_MSG_CHECKING(linker version script option)
gcc_cv_ld_version_script=no
ld_version_script_option=''
if test $in_tree_ld = yes; then
  gcc_cv_ld_version_script=yes
  ld_version_script_option='--version-script'
elif test x$gcc_cv_ld != x; then
  if $gcc_cv_ld --help 2>&1 | grep -- --version-script > /dev/null; then
    gcc_cv_ld_version_script=yes
    ld_version_script_option='--version-script'
  fi
fi
case "$host" in
  dnl Solaris 2 ld always supports -M.
  dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3197".
  *-*-solaris2*)
    gcc_cv_ld_version_script=yes
    ld_version_script_option='-M'
    ;;
esac
AC_MSG_RESULT($gcc_cv_ld_version_script)
AC_SUBST(ld_version_script_option)

AC_MSG_CHECKING(linker soname option)
gcc_cv_ld_soname=no
ld_soname_option=''
if test $in_tree_ld = yes; then
  gcc_cv_ld_soname=yes
  ld_soname_option='-soname'
elif test x$gcc_cv_ld != x; then
  if $gcc_cv_ld --help 2>&1 | grep -- -soname > /dev/null; then
    gcc_cv_ld_soname=yes
    ld_soname_option='-soname'
  fi
fi
case "$host" in
  *-*-darwin*)
    gcc_cv_ld_soname=yes
    ld_soname_option='-install_name'
    ;;
  dnl Solaris 2 ld always supports -h, and --soname since a Solaris 10 update.
  *-*-solaris2*)
    gcc_cv_ld_soname=yes
    ld_soname_option='-h'
    ;;
esac
AC_MSG_RESULT($gcc_cv_ld_soname)
AC_SUBST(ld_soname_option)

ORIGINAL_LD_FOR_TARGET=$gcc_cv_ld
AC_SUBST(ORIGINAL_LD_FOR_TARGET)
case "$ORIGINAL_LD_FOR_TARGET" in
  ./collect-ld | ./collect-ld$build_exeext) ;;
  *) AC_CONFIG_FILES(collect-ld:exec-tool.in, [chmod +x collect-ld]) ;;
esac 

AC_MSG_CHECKING(what linker to use)
if test "$gcc_cv_ld" = ../ld/ld-new$build_exeext \
   || test "$gcc_cv_ld" = ../gold/ld-new$build_exeext; then
	# Single tree build which includes ld.  We want to prefer it
	# over whatever linker top-level may have detected, since
	# we'll use what we're building after installation anyway.
	AC_MSG_RESULT(newly built ld)
	in_tree_ld=yes
	ORIGINAL_LD_BFD_FOR_TARGET=../ld/ld-new$build_exeext
	ORIGINAL_LD_GOLD_FOR_TARGET=../gold/ld-new$build_exeext
else
	AC_MSG_RESULT($gcc_cv_ld)
	in_tree_ld=no
	gcc_cvs_ld_program=`dirname $gcc_cv_ld`/`basename $gcc_cv_ld $host_exeext`
	ORIGINAL_LD_BFD_FOR_TARGET=${gcc_cvs_ld_program}.bfd$host_exeext
	ORIGINAL_LD_GOLD_FOR_TARGET=${gcc_cvs_ld_program}.gold$host_exeext
fi

AC_SUBST(ORIGINAL_LD_BFD_FOR_TARGET)
AC_SUBST(ORIGINAL_LD_GOLD_FOR_TARGET)

# Figure out what nm we will be using.
gcc_cv_binutils_srcdir=`echo $srcdir | sed -e 's,/gcc$,,'`/binutils
AS_VAR_SET_IF(gcc_cv_nm,, [
if test -f $gcc_cv_binutils_srcdir/configure.ac \
     && test -f ../binutils/Makefile \
     && test x$build = x$host; then
	gcc_cv_nm=../binutils/nm-new$build_exeext
elif test -x nm$build_exeext; then
	gcc_cv_nm=./nm$build_exeext
elif ( set dummy $NM_FOR_TARGET; test -x $[2] ); then
        gcc_cv_nm="$NM_FOR_TARGET"
else
        AC_PATH_PROG(gcc_cv_nm, $NM_FOR_TARGET)
fi])

AC_MSG_CHECKING(what nm to use)
if test "$gcc_cv_nm" = ../binutils/nm-new$build_exeext; then
	# Single tree build which includes binutils.
	AC_MSG_RESULT(newly built nm)
	in_tree_nm=yes
else
	AC_MSG_RESULT($gcc_cv_nm)
	in_tree_nm=no
fi

ORIGINAL_NM_FOR_TARGET=$gcc_cv_nm
AC_SUBST(ORIGINAL_NM_FOR_TARGET)
case "$ORIGINAL_NM_FOR_TARGET" in
  ./nm | ./nm$build_exeext) ;;
  *) AC_CONFIG_FILES(nm:exec-tool.in, [chmod +x nm]) ;;
esac


dnl The objdump, readelf and otool searches are gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3295".

# Figure out the dsymutil we will use.
AS_VAR_SET_IF(gcc_cv_dsymutil,, [
if test -x dsymutil$build_exeext; then
    gcc_cv_dsymutil=./dsymutil$build_exeext
elif ( set dummy $DSYMUTIL_FOR_TARGET; test -x $[2] ); then
    gcc_cv_dsymutil=$DSYMUTIL_FOR_TARGET
elif ( set dummy $DSYMUTIL; test -x $[2] ); then
    gcc_cv_dsymutil=$DSYMUTIL
else
    AC_PATH_PROG(gcc_cv_dsymutil, $DSYMUTIL_FOR_TARGET)
fi])

ORIGINAL_DSYMUTIL_FOR_TARGET=$gcc_cv_dsymutil
AC_SUBST(ORIGINAL_DSYMUTIL_FOR_TARGET)
case "$ORIGINAL_DSYMUTIL_FOR_TARGET" in
  ./dsymutil | ./dsymutil$build_exeext) ;;
  *) AC_CONFIG_FILES(dsymutil:exec-tool.in, [chmod +x dsymutil]) ;;
esac 


gcc_AC_INITFINI_ARRAY

gcc_CHECK_ATTRIBUTE_ALIAS


dnl The CFI probe cluster (.cfi_startproc/.cfi_offset/.cfi_escape, working
dnl cfi advance, ...
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3331".


dnl --enable-newlib-nano-formatted-io mirrored a newlib configure flag so
dnl GCC could gate features on it.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3343".

dnl Thread-local storage.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3349".
AC_DEFINE(HAVE_AS_TLS, 1,
	  [Define if your assembler and linker support thread-local storage.])


dnl ---------------------------------------------------------------------------
dnl THE TARGET-TOOLCHAIN PROBES THAT USED TO LIVE HERE ARE ALL IN
dnl target-specs/configure.ac NOW.  One sweep, deliberately ahead of wiring the
dnl consumers up, so that the compile failures -- not a static analysis -- are
dnl the work list.  What was in this stretch, in the order it appeared, so that
dnl undoing any one move is a lookup rather than archaeology:
dnl
dnl   1. assembler alignment and symbol directives: .balign/.p2align,
dnl      .p2align max-skip, .literal16, .subsection -1, .weak, .weakref,
dnl      .nsubspa comdat, .hidden, .base64, .cv_ucomp.
dnl   2. the `ld --version' parser and the Solaris `GNU ld 2.30 or later'
dnl      requirement, plus gcc_fn_gld_min_version/gcc_fn_gld_elf_min_version,
dnl      which had no callers left.
dnl   3. the loongarch -mno-relax probe that fed check_leb128_asflags.
dnl   4. the .eh_frame optimization probe and USE_AS_TRADITIONAL_FORMAT.
dnl   5. section flags: exclude (`e'/#exclude), SHF_GNU_RETAIN (`R'),
dnl      SHF_LINK_ORDER (`o'), SHF_MERGE.
dnl   6. the gcc_cv_as_comdat_group=yes pin, whose last reader went with (5).
dnl   7. the darwin -mmacosx-version-min and .build_version probes.
dnl   8. the whole `case "$target"' CPU block: alpha explicit/jsrdirect relocs,
dnl      avr --mlink-relax/-mrmw/-mgcc-isr, cris -no-mul-bug-abort, ia64
dnl      ltoffx/ldxmov, the powerpc set (.machine, mfcrf, power10 htm, rel16,
dnl      entry markers, pltseq), msp430 .mspabi_attribute, the loongarch set
dnl      (explicit relocs, call36, eh_frame pcrel, tls le relaxation, 16B
dnl      atomic) and the s390 set (.machine/.machinemode, architecture
dnl      modifiers, both vector alignment hint probes).
dnl   9. the "requires the GNU assembler" check for mips/loongarch/hpux, the
dnl      amdgcn LLVM >= 13.0.1 version gate, and the arm context-specific
dnl      architecture-extension probe.
dnl  10. the DWARF 4 .debug_line cluster keyed on `case $cpu_type'.
dnl  11. .lcomm with alignment.
dnl
dnl HAVE_AS_TLS and HAVE_AS_DTPREL_RELOC are NOT in that list.  Both are read
dnl from `#if defined(...)' in generated .md TUs and in aarch64.cc, where
dnl targ_caps is not in scope, so they stay build-time constants -- see the
dnl reasoning kept above HAVE_AS_TLS.
dnl ---------------------------------------------------------------------------

AC_DEFINE(HAVE_AS_DTPREL_RELOC, 1,
	[Define if your assembler supports DTPREL relocation.])


dnl --with-glibc-version is gone, and so is the probe that stood in for it:
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3420".

dnl --enable-gnu-unique-object and its probe lived here.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3432".


AC_MSG_CHECKING(support for thin archives)
thin_archive_support=no
echo 'int main (void) { return 0; }' > conftest.c
if ($AR --version | sed 1q | grep "GNU ar" \
    && $CC $CFLAGS -c conftest.c \
    && $AR rcT conftest.a conftest.o \
    && $CC $CFLAGS $LDFLAGS -o conftest conftest.a) >/dev/null 2>&1; then
  thin_archive_support=yes
fi
rm -f conftest.c conftest.o conftest.a conftest
AC_MSG_RESULT($thin_archive_support)
AC_SUBST(thin_archive_support)


dnl The ld64 and dsymutil probe blocks that stood here are gone to
dnl target-specs/configure.ac -- as a ...
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3455".


dnl --enable-libssp and the gcc_cv_libc_provides_ssp probe used to decide
dnl TARGET_LIBC_PROVIDES_SSP by ...
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3478".

dnl --enable-default-ssp used to AC_DEFINE(ENABLE_DEFAULT_SSP), gated on a
dnl `case "$target"' that excluded ia64.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3486".

dnl libatomic_target names the ONE triple this build will have a libatomic for,
dnl and is empty when there is none.  LINK_LIBATOMIC_SPEC needs it: -latomic is
dnl put on the link line only where the library exists, and `is libatomic in
dnl TARGET_CONFIGDIRS' is the only place that is known.  It cannot be probed by
dnl target-specs/ the way the linker questions are, because at the time those
dnl probes run the library has not been built yet, let alone installed.
dnl
dnl It is deliberately a TRIPLE and not a yes/no.  The top level builds target
dnl libraries for ${target} alone, so in a compiler serving 183 targets the
dnl answer is yes for at most one of them; a boolean would have been handed to
dnl every target's spec file and put -latomic on 182 link lines that have no
dnl such library.  ${target} is already canonicalised here (see the top of this
dnl file), so it compares equal to the manifest entry Makefile.in matches it
dnl against.
dnl TARGET_CONFIGDIRS reaches this script only as an ENVIRONMENT VARIABLE
dnl exported by the top-level Makefile (Makefile.tpl:252) when it configures
dnl gcc.  A `config.status --recheck' run by hand does not have it, and the
dnl answer then silently flips to "no libatomic" -- which is how a spec file
dnl that had `--as-needed -latomic --no-as-needed' in it came back empty after
dnl an unrelated re-configure.  Upstream's AC_DEFINE had exactly the same
dnl dependency and exactly the same silence.  Distinguish the two cases and say
dnl which, so a re-configure that loses it leaves a line in the log instead of
dnl quietly changing every link line.
libatomic_target=
if test -z "${TARGET_CONFIGDIRS+set}"; then
  AC_MSG_NOTICE([TARGET_CONFIGDIRS is not set: assuming no libatomic for ${target}.])
  AC_MSG_NOTICE([  This is normal only if configure was not run by the top-level])
  AC_MSG_NOTICE([  Makefile.  A `config.status --recheck' by hand loses it, and])
  AC_MSG_NOTICE([  -latomic then disappears from the target's link line.])
elif echo " ${TARGET_CONFIGDIRS} " | grep " libatomic " > /dev/null 2>&1 ; then
  libatomic_target=${target}
  AC_DEFINE(TARGET_PROVIDES_LIBATOMIC, 1,
	    [Define if libatomic is built for the target.])
fi
AC_SUBST(libatomic_target)

dnl The <sys/sdt.h> probe is gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3527".

dnl --with-long-double-128 and the probe behind it are gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3535".

dnl --with-long-double-format is gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3545".

dnl TARGET_LIBC_PROVIDES_HWCAP_IN_TCB and TARGET_LIBC_GNUSTACK are gone from
dnl here.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3553".

dnl The dl_iterate_phdr probe is gone, for the same reason and to the same
dnl place:
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:3560".

# We no longer support different GC mechanisms.  Emit an error if
# the user configures with --with-gc.
AC_ARG_WITH(gc,
[AS_HELP_STRING([--with-gc={page,zone}],
		[this option is not supported anymore.  It used to choose
		 the garbage collection mechanism to use with the compiler])],
[AC_MSG_ERROR([Configure option --with-gc is only supported up to GCC 4.7.x])],
[])

# Libraries to use on the host.  This will normally be set by the top
# level Makefile.  Here we simply capture the value for our Makefile.
if test -z "${HOST_LIBS+set}"; then
  HOST_LIBS=
fi
AC_SUBST(HOST_LIBS)

# Use the system's zlib library.
AM_ZLIB

dnl Very limited version of automake's enable-maintainer-mode

AC_MSG_CHECKING([whether to enable maintainer-specific portions of Makefiles])
  dnl maintainer-mode is disabled by default
  AC_ARG_ENABLE(maintainer-mode,
[AS_HELP_STRING([--enable-maintainer-mode],
                [enable make rules and dependencies not useful
                 (and sometimes confusing) to the casual installer])],
      maintainer_mode=$enableval,
      maintainer_mode=no)

AC_MSG_RESULT($maintainer_mode)

if test "$maintainer_mode" = "yes"; then
  MAINT=''
else
  MAINT='#'
fi
AC_SUBST(MAINT)dnl

dnl Variables for tags utilities; copied from automake 1.16.4+'s init.m4
if test -z "$CTAGS"; then
  CTAGS=ctags
fi
AC_SUBST([CTAGS])
if test -z "$ETAGS"; then
  ETAGS=etags
fi
AC_SUBST([ETAGS])
if test -z "$CSCOPE"; then
  CSCOPE=cscope
fi
AC_SUBST([CSCOPE])

dnl Whether to prevent multiple front-ends from linking at the same time

AC_MSG_CHECKING([whether to avoid linking multiple front-ends at once])
  AC_ARG_ENABLE(link-mutex,
[AS_HELP_STRING([--enable-link-mutex],
		[avoid linking multiple front-ends at once to avoid thrashing
		 on the build machine])],
      do_link_mutex=$enableval,
      do_link_mutex=no)
AC_MSG_RESULT($do_link_mutex)

if test "$do_link_mutex" = "yes"; then
   DO_LINK_MUTEX=true
   AC_MSG_WARN([--enable-link-mutex is deprecated and will be removed in the next release, use --enable-link-serialization instead])
else
   DO_LINK_MUTEX=false
fi
AC_SUBST(DO_LINK_MUTEX)

dnl Whether to prevent multiple GCC front-ends from linking at the same time

AC_MSG_CHECKING([whether to serialize linking of multiple front-ends])
  AC_ARG_ENABLE(link-serialization,
[AS_HELP_STRING([--enable-link-serialization],
		[avoid linking multiple GCC front-ends at once using make
		 dependencies to avoid thrashing on the build machine])],
      do_link_serialization=$enableval,
      do_link_serialization=no)
AC_MSG_RESULT($do_link_serialization)

case "$do_link_serialization" in
  yes)
    DO_LINK_SERIALIZATION=1;;
  [[1-9]] | [[1-9]][[0-9]] | [[1-9]][[0-9]][[0-9]])
    DO_LINK_SERIALIZATION=$do_link_serialization;;
  no)
    DO_LINK_SERIALIZATION=;;
  *)
    AC_MSG_ERROR(bad value ${do_link_serialization} given for --enable-link-serialization) ;;
esac
AC_SUBST(DO_LINK_SERIALIZATION)

# --------------
# Language hooks
# --------------

# Make empty files to contain the specs and options for each language.
# Then add #include lines to for a compiler that has specs and/or options.

subdirs=
lang_opt_files=
lang_specs_files=
lang_tree_files=
# These (without "all_") are set in each config-lang.in.
# `language' must be a single word so is spelled singularly.
all_languages=
all_compilers=
all_outputs='Makefile'
# List of language configure and makefile fragments.
all_lang_configurefrags=
all_lang_makefrags=
# Additional files for gengtype
all_gtfiles="$target_gtfiles"

# These are the languages that are set in --enable-languages,
# and are available in the GCC tree.
all_selected_languages=

# Add the language fragments.
# Languages are added via two mechanisms.  Some information must be
# recorded in makefile variables, these are defined in config-lang.in.
# We accumulate them and plug them into the main Makefile.
# The other mechanism is a set of hooks for each of the main targets
# like `clean', `install', etc.

language_hooks="Make-hooks"

for lang in ${srcdir}/*/config-lang.in
do
changequote(,)dnl
	test "$lang" = "${srcdir}/*/config-lang.in" && continue

        lang_alias=`sed -n -e 's,^language=['"'"'"'"]\(.*\)["'"'"'"'].*$,\1,p' -e 's,^language=\([^   ]*\).*$,\1,p' $lang`
        if test "x$lang_alias" = x
        then
              echo "$lang doesn't set \$language." 1>&2
              exit 1
        fi
        subdir="`echo $lang | sed -e 's,^.*/\([^/]*\)/config-lang.in$,\1,'`"
        subdirs="$subdirs $subdir"

	# $gcc_subdir is where the gcc integration files are to be found
	# for a language, both for internal compiler purposes (compiler
	# sources implementing front-end to GCC tree converters), and for
	# build infrastructure purposes (Make-lang.in, etc.)
	#
	# This will be <subdir> (relative to $srcdir) if a line like 
	# gcc_subdir="<subdir>" or gcc_subdir=<subdir>
	# is found in <langdir>/config-lang.in, and will remain <langdir>
	# otherwise.
	#
	# Except for the language alias (fetched above), the regular
	# "config-lang.in" contents are always retrieved from $gcc_subdir,
	# so a <langdir>/config-lang.in setting gcc_subdir typically sets
	# only this and the language alias.

        gcc_subdir=`sed -n -e 's,^gcc_subdir=['"'"'"'"]\(.*\)["'"'"'"'].*$,\1,p' -e 's,^gcc_subdir=\([^   ]*\).*$,\1,p' $lang`
        if [ "$gcc_subdir" = "" ]; then
           gcc_subdir="$subdir"
        fi

        case ",$enable_languages," in
        *,$lang_alias,*)
            all_selected_languages="$all_selected_languages $lang_alias"
            if test -f $srcdir/$gcc_subdir/lang-specs.h; then
                lang_specs_files="$lang_specs_files $srcdir/$gcc_subdir/lang-specs.h"
	    fi
	    ;;
        esac
changequote([,])dnl

	language=
	boot_language=
	compilers=
	outputs=
	gtfiles=
	subdir_requires=
	. ${srcdir}/$gcc_subdir/config-lang.in
	if test "x$language" = x
	then
		echo "${srcdir}/$gcc_subdir/config-lang.in doesn't set \$language." 1>&2
		exit 1
	fi

	ok=:
        case ",$enable_languages," in
        	*,$lang_alias,*) ;;
		*)
			for i in $subdir_requires; do
				test -f "${srcdir}/$i/config-lang.in" && continue
				ok=false
				break
			done
		;;
	esac
	$ok || continue

	all_lang_configurefrags="$all_lang_configurefrags \$(srcdir)/$gcc_subdir/config-lang.in"
	if test "x$language" = xc && test -n "$all_lang_makefrags"; then
	    # Put c/Make-lang.in fragment first to match serialization languages order.
	    all_lang_makefrags="\$(srcdir)/$gcc_subdir/Make-lang.in $all_lang_makefrags"
	else
	    all_lang_makefrags="$all_lang_makefrags \$(srcdir)/$gcc_subdir/Make-lang.in"
	fi
	if test -f $srcdir/$gcc_subdir/lang.opt; then
	    lang_opt_files="$lang_opt_files $srcdir/$gcc_subdir/lang.opt"
	    all_opt_files="$all_opt_files $srcdir/$gcc_subdir/lang.opt"
	fi
	if test -f $srcdir/$gcc_subdir/$subdir-tree.def; then
	    lang_tree_files="$lang_tree_files $srcdir/$gcc_subdir/$subdir-tree.def"
	fi
	all_languages="$all_languages $language"
	all_compilers="$all_compilers $compilers"
	all_outputs="$all_outputs $outputs"
	all_gtfiles="$all_gtfiles [[$subdir]] $gtfiles"
        case ",$enable_languages," in
        	*,lto,*)
		    AC_DEFINE(ENABLE_LTO, 1, [Define to enable LTO support.])
		    enable_lto=yes
		    AC_SUBST(enable_lto)
		    ;;
		*) ;;
	esac
done

check_languages=
for language in $all_selected_languages
do
	check_languages="$check_languages check-$language"
done
if test x$enable_libgdiagnostics = xyes; then
	check_languages="$check_languages check-libgdiagnostics check-sarif-replay"
fi

selftest_languages=
for language in $all_selected_languages
do
	selftest_languages="$selftest_languages selftest-$language"
done

# We link each language in with a set of hooks, reached indirectly via
# lang.${target}.  Only do so for selected languages.

rm -f Make-hooks
touch Make-hooks
target_list="all.cross start.encap rest.encap tags \
	install-common install-man install-info install-dvi install-pdf \
	install-html dvi pdf html uninstall info man srcextra srcman srcinfo \
	mostlyclean clean distclean maintainer-clean install-plugin"

for t in $target_list
do
	x=
	for lang in $all_selected_languages
	do
		x="$x $lang.$t"
	done
	echo "lang.$t: $x" >> Make-hooks
done

echo "ifeq (\$(DO_LINK_SERIALIZATION),)" >> Make-hooks
echo "SERIAL_LIST =" >> Make-hooks
echo else >> Make-hooks
lang_cnt=0
lang_list=
prev=c
serialization_languages=c
for lang in $all_selected_languages
do
	test $lang = c && continue
	if test $lang = lto; then
		serialization_languages="$serialization_languages lto1 lto2"
	else
		serialization_languages="$serialization_languages $lang"
	fi
done
for lang in $serialization_languages
do
	test $lang = c && continue
	lang_cnt=`expr $lang_cnt + 1`
	lang_list=" $prev$lang_list"
	prev=${lang}
done
echo "SERIAL_LIST = \$(wordlist \$(DO_LINK_SERIALIZATION),$lang_cnt,$lang_list)" >> Make-hooks
echo endif >> Make-hooks
echo "SERIAL_COUNT = `expr $lang_cnt + 1`" >> Make-hooks
echo "INDEX.c = 0" >> Make-hooks
lang_idx=1
for lang in $serialization_languages
do
	test $lang = c && continue
	echo "$lang.prev = \$(if \$(word $lang_cnt,\$(SERIAL_LIST)),\$(\$(word $lang_cnt,\$(SERIAL_LIST)).serial))" >> Make-hooks
	echo "INDEX.$lang = $lang_idx" >> Make-hooks
	lang_cnt=`expr $lang_cnt - 1`
	lang_idx=`expr $lang_idx + 1`
done

# --------
# Option include files
# --------

${AWK} -f $srcdir/opt-include.awk $all_opt_files > option-includes.mk
option_includes="option-includes.mk"
AC_SUBST_FILE(option_includes)

# --------
# UNSORTED
# --------

# Create .gdbinit.

echo "dir ." > .gdbinit
echo "dir ${srcdir}" >> .gdbinit
if test x$gdb_needs_out_file_path = xyes
then
	echo "dir ${srcdir}/config/"`dirname ${out_file}` >> .gdbinit
fi
if test "x$subdirs" != x; then
	for s in $subdirs
	do
		echo "dir ${srcdir}/$s" >> .gdbinit
	done
fi
echo "source ${srcdir}/gdbinit.in" >> .gdbinit
echo "python import sys; sys.path.append('${srcdir}'); import gdbhooks" >> .gdbinit

# Put a breakpoint on __asan_report_error to help with debugging buffer
# overflow.
case "$CFLAGS" in
*-fsanitize=address*)
  echo "source ${srcdir}/gdbasan.in" >> .gdbinit
  ;;
esac

gcc_tooldir='$(libsubdir)/$(libsubdir_to_prefix)$(target_noncanonical)'
AC_SUBST(gcc_tooldir)
AC_SUBST(dollar)

# Find a directory in which to install a shared libgcc.

# Substitute configuration variables
AC_SUBST(subdirs)
AC_SUBST(srcdir)
AC_SUBST(all_compilers)
AC_SUBST(all_gtfiles)
AC_SUBST(all_lang_configurefrags)
AC_SUBST(all_lang_makefrags)
AC_SUBST(all_languages)
AC_SUBST(all_selected_languages)
AC_SUBST(build_exeext)
AC_SUBST(build_install_headers_dir)
AC_SUBST(build_xm_file_list)
AC_SUBST(build_xm_include_list)
AC_SUBST(build_xm_defines)
AC_SUBST(build_file_translate)
AC_SUBST(check_languages)
AC_SUBST(selftest_languages)
AC_SUBST(cpp_install_dir)
AC_SUBST(xmake_file)
AC_SUBST(tmake_file)
AC_SUBST(TM_ENDIAN_CONFIG)
AC_SUBST(TM_MULTILIB_CONFIG)
AC_SUBST(TM_MULTILIB_EXCEPTIONS_CONFIG)
AC_SUBST(extra_gcc_objs)
AC_SUBST(user_headers_inc_next_pre)
AC_SUBST(user_headers_inc_next_post)
AC_SUBST(extra_headers_list)
AC_SUBST(extra_objs)
AC_SUBST(extra_programs)
AC_SUBST(float_h_file)
AC_SUBST(gcc_config_arguments)
AC_SUBST(gcc_gxx_include_dir)
AC_SUBST(gcc_gxx_include_dir_add_sysroot)
AC_SUBST(gcc_gxx_libcxx_include_dir)
AC_SUBST(gcc_gxx_libcxx_include_dir_add_sysroot)
AC_SUBST(host_exeext)
AC_SUBST(host_xm_file_list)
AC_SUBST(host_xm_include_list)
AC_SUBST(host_xm_defines)
AC_SUBST(out_host_hook_obj)
AC_SUBST(install)
AC_SUBST(lang_opt_files)
AC_SUBST(lang_specs_files)
AC_SUBST(lang_tree_files)
AC_SUBST(local_prefix)
AC_SUBST(md_file)
AC_SUBST(out_file)
AC_SUBST(out_object_file)
AC_SUBST(common_out_file)
AC_SUBST(common_out_object_file)
AC_SUBST(tm_file_list)
AC_SUBST(tm_include_list)
AC_SUBST(tm_defines)
AC_SUBST(tm_p_file_list)
AC_SUBST(tm_p_include_list)
AC_SUBST(tm_d_file_list)
AC_SUBST(tm_d_include_list)
AC_SUBST(tm_rust_file_list)
AC_SUBST(tm_rust_include_list)
AC_SUBST(tm_jit_file_list)
AC_SUBST(tm_jit_include_list)
AC_SUBST(xm_file_list)
AC_SUBST(xm_include_list)
AC_SUBST(xm_defines)
AC_SUBST(use_gcc_stdint)
AC_SUBST(c_target_objs)
AC_SUBST(cxx_target_objs)
AC_SUBST(fortran_target_objs)
AC_SUBST(d_target_objs)
AC_SUBST(rust_target_objs)
AC_SUBST(jit_target_objs)
AC_SUBST(target_cpu_default)

AC_SUBST_FILE(language_hooks)

# Echo link setup.
if test x${build} = x${host} ; then
  if test x${host} = x${target} ; then
    echo "Links are now set up to build a native compiler for ${target}." 1>&2
  else
    echo "Links are now set up to build a cross-compiler" 1>&2
    echo " from ${host} to ${target}." 1>&2
  fi
else
  if test x${host} = x${target} ; then
    echo "Links are now set up to build (on ${build}) a native compiler" 1>&2
    echo " for ${target}." 1>&2
  else
    echo "Links are now set up to build (on ${build}) a cross-compiler" 1>&2
    echo " from ${host} to ${target}." 1>&2
  fi
fi

AC_ARG_VAR(GMPLIBS,[How to link GMP])
AC_ARG_VAR(GMPINC,[How to find GMP include files])

AC_ARG_VAR(ISLLIBS,[How to link isl])
AC_ARG_VAR(ISLINC,[How to find isl include files])
if test "x${ISLLIBS}" != "x" ; then 
   AC_DEFINE(HAVE_isl, 1, [Define if isl is in use.])
fi

GCC_ENABLE_PLUGINS
AC_SUBST(pluginlibs)
AC_SUBST(enable_plugin)
if test x"$enable_plugin" = x"yes"; then
  AC_DEFINE(ENABLE_PLUGIN, 1, [Define to enable plugin support.])
fi


# --enable-host-shared, --enable-host-pie.
#
# THE `host-' PREFIX IS WRONG AND IS STAYING FOR NOW.  It disambiguates against
# a target meaning that no longer exists in this file, and the convention it
# fights is universal: `--enable-shared' given to a package always means THAT
# PACKAGE's host.  Given to gcc it would mean gcc's host; given to libgcc it
# means libgcc's host, which is what gcc calls the target.  One rule, resolved
# against whichever package is being configured.  The prefix is a local
# invention where a convention already existed.
#
# It WAS renamed to `--enable-shared'/`--enable-pie', and the rename was BACKED
# OUT.  The reason is worth recording rather than rediscovering:
#
#   gcc/configure.ac ALREADY HAS AC_ARG_ENABLE(shared) -- near the top of this
#   file, "do not provide a shared libgcc".  It sets and AC_SUBSTs
#   `enable_shared', which Makefile.in turns into -DENABLE_SHARED_LIBGCC.  A
#   second AC_ARG_ENABLE(shared) here silently overwrites it, and being later
#   in the file it wins.  That is this project's canonical failure -- one name,
#   two authorities, no diagnostic -- committed inside a single file, and the
#   rename would have introduced it.
#
# So the rename has a PREREQUISITE, not merely a top-level dependency: the
# libgcc-shared option above has to leave gcc/configure.ac first.  It is a
# question about libgcc, libgcc/configure.ac:52 already asks it identically,
# and only then is the name free for the host meaning.
#
# Second dependency, unchanged: the top-level configure passes
# --enable-host-shared and --enable-host-pie down here (22 uses), and the top
# level ALSO forwards its own --disable-shared into host_configargs, so the two
# names would meet there too.  scratchpad/STATE.md carries the work item.
AC_ARG_ENABLE(host-shared,
[AS_HELP_STRING([--enable-host-shared],
		[build host code as shared libraries])])
AC_SUBST(enable_host_shared)

AC_ARG_ENABLE(host-pie,
[AS_HELP_STRING([--enable-host-pie],
		[build host code as PIE])])
AC_SUBST(enable_host_pie)

AC_ARG_ENABLE(libgdiagnostics,
[AS_HELP_STRING([--enable-libgdiagnostics],
		[build libgdiagnostics shared library])])
AC_SUBST(enable_libgdiagnostics)

if test "$enable_libgdiagnostics" = "yes"; then
  LIBGDIAGNOSTICS='libgdiagnostics sarif-replay'
else
  LIBGDIAGNOSTICS=''
fi
AC_SUBST(LIBGDIAGNOSTICS)


# See the note above --enable-host-shared for why the prefix is still here.
AC_ARG_ENABLE(host-bind-now,
[AS_HELP_STRING([--enable-host-bind-now],
		[link host code as BIND_NOW])])
AC_SUBST(enable_host_bind_now)

AC_ARG_ENABLE(libquadmath-support,
[AS_HELP_STRING([--disable-libquadmath-support],
  [disable libquadmath support for Fortran])],
ENABLE_LIBQUADMATH_SUPPORT=$enableval,
ENABLE_LIBQUADMATH_SUPPORT=yes)
if test "${ENABLE_LIBQUADMATH_SUPPORT}" != "no" ; then
  AC_DEFINE(ENABLE_LIBQUADMATH_SUPPORT, 1,
            [Define to 1 to enable libquadmath support])
fi


dnl --with-linker-hash-style is gone.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:4095".

# Specify what should be the default of -fdiagnostics-color option.
AC_ARG_WITH([diagnostics-color],
[AS_HELP_STRING([--with-diagnostics-color={never,auto,auto-if-env,always}],
                [specify the default of -fdiagnostics-color option
                 auto-if-env stands for -fdiagnostics-color=auto if
                 GCC_COLOR environment variable is present and
                 -fdiagnostics-color=never otherwise])],
[case x"$withval" in
   xnever)
     DIAGNOSTICS_COLOR_DEFAULT=DIAGNOSTICS_COLOR_NO
     ;;
   xauto)
     DIAGNOSTICS_COLOR_DEFAULT=DIAGNOSTICS_COLOR_AUTO
     ;;
   xauto-if-env)
     DIAGNOSTICS_COLOR_DEFAULT=-1
     ;;
   xalways)
     DIAGNOSTICS_COLOR_DEFAULT=DIAGNOSTICS_COLOR_YES
     ;;
   *)
     AC_MSG_ERROR([$withval is an invalid option to --with-diagnostics-color])
     ;;
 esac],
[DIAGNOSTICS_COLOR_DEFAULT=DIAGNOSTICS_COLOR_AUTO])
AC_DEFINE_UNQUOTED(DIAGNOSTICS_COLOR_DEFAULT, $DIAGNOSTICS_COLOR_DEFAULT,
		   [The default for -fdiagnostics-color option])

# Specify what should be the default of -fdiagnostics-urls option.
AC_ARG_WITH([diagnostics-urls],
[AS_HELP_STRING([--with-diagnostics-urls={never,auto,auto-if-env,always}],
                [specify the default of -fdiagnostics-urls option
                 auto-if-env stands for -fdiagnostics-urls=auto if
                 GCC_URLS or TERM_URLS environment variable is present and
                 -fdiagnostics-urls=never otherwise])],
[case x"$withval" in
   xnever)
     DIAGNOSTICS_URLS_DEFAULT=DIAGNOSTICS_URL_NO
     ;;
   xauto)
     DIAGNOSTICS_URLS_DEFAULT=DIAGNOSTICS_URL_AUTO
     ;;
   xauto-if-env)
     DIAGNOSTICS_URLS_DEFAULT=-1
     ;;
   xalways)
     DIAGNOSTICS_URLS_DEFAULT=DIAGNOSTICS_URL_YES
     ;;
   *)
     AC_MSG_ERROR([$withval is an invalid option to --with-diagnostics-urls])
     ;;
 esac],
[DIAGNOSTICS_URLS_DEFAULT=DIAGNOSTICS_URL_AUTO])
AC_DEFINE_UNQUOTED(DIAGNOSTICS_URLS_DEFAULT, $DIAGNOSTICS_URLS_DEFAULT,
		   [The default for -fdiagnostics-urls option])

# The triple the target libraries in THIS BUILD TREE are being built for.
#
# This is emphatically NOT "the compiler's target": this compiler has none, and
# nothing that gets compiled into it may depend on this value.  Read the
# FIXINCLUDES_MACHINE comment in Makefile.in before reaching for it -- putting
# the privileged target back is exactly what this project removed.
#
# It exists for one purpose: so the build directory can hold a driver named the
# way an INSTALLED driver is named, `<triple>-gcc', for the in-tree target
# libraries (libgcc, libstdc++, ...) to invoke.  A bare `xgcc' has no way to
# know which target it is compiling for, and with the empty back end that is a
# hard error rather than a silent default; naming the in-tree driver the way
# the installed one is named means the two paths are ONE mechanism instead of
# two, so whatever verifies one verifies the other.
#
# ${target} is appended to gcc_manifest_targets unconditionally above, so this
# triple is always one this compiler was configured to serve.  The toplevel
# Makefile spells the same name as $(target)-gcc out of its own @target@; both
# come from AC_CANONICAL_TARGET over the same arguments, so they agree.
build_target_triple=${target}
AC_SUBST(build_target_triple)

# Generate gcc-driver-name.h containing GCC_DRIVER_NAME for the benefit
# of jit/jit-playback.cc.
gcc_driver_version=`eval "${get_gcc_base_ver} $srcdir/BASE-VER"`
echo "gcc_driver_version: ${gcc_driver_version}"
cat > gcc-driver-name.h <<EOF
#define GCC_DRIVER_NAME "${target_noncanonical}-gcc-${gcc_driver_version}${exeext}"
EOF

# Check whether --enable-versioned-jit was given.
AC_ARG_ENABLE(versioned-jit,
[AS_HELP_STRING([--enable-versioned-jit],
  [enable versioned libgccjit build])],
enable_versioned_jit=$enableval,
enable_versioned_jit=no)
if test x$enable_versioned_jit = xyes ; then
  libgccjit_version=$gcc_driver_version
elif test x$enable_versioned_jit = xno ; then
  libgccjit_version=0
else
  AC_MSG_ERROR(bad value ${enableval} given for --enable-versioned-jit option)
fi
AC_SUBST([libgccjit_version])


# Check if -fno-PIE works.
AC_CACHE_CHECK([for -fno-PIE option],
  [gcc_cv_c_no_fpie],
  [saved_CXXFLAGS="$CXXFLAGS"
   CXXFLAGS="$CXXFLAGS -fno-PIE"
   AC_COMPILE_IFELSE([AC_LANG_SOURCE([int main(void) {return 0;}])],
     [gcc_cv_c_no_fpie=yes],
     [gcc_cv_c_no_fpie=no])
   CXXFLAGS="$saved_CXXFLAGS"])

# Check if -no-pie works.
AC_CACHE_CHECK([for -no-pie option],
  [gcc_cv_no_pie],
  [saved_LDFLAGS="$LDFLAGS"
   LDFLAGS="$LDFLAGS -no-pie"
   AC_LINK_IFELSE([AC_LANG_SOURCE([int main(void) {return 0;}])],
     [gcc_cv_no_pie=yes],
     [gcc_cv_no_pie=no])
   LDFLAGS="$saved_LDFLAGS"])

if test x$enable_host_shared = xyes; then
  PICFLAG=-fPIC
elif test x$enable_host_pie = xyes; then
  PICFLAG=-fPIE
elif test x$gcc_cv_c_no_fpie = xyes; then
  PICFLAG=-fno-PIE
else
  PICFLAG=
fi

AC_SUBST([PICFLAG])

if test x$enable_host_pie = xyes; then
  LD_PICFLAG=-pie
elif test x$gcc_cv_no_pie = xyes; then
  LD_PICFLAG=-no-pie
else
  LD_PICFLAG=
fi

if test x$enable_host_bind_now = xyes; then
  LD_PICFLAG="$LD_PICFLAG -Wl,-z,now"
fi

AC_SUBST([LD_PICFLAG])

# Enable Intel CET on Intel CET enabled host if jit is enabled.
GCC_CET_HOST_FLAGS(CET_HOST_FLAGS)
case x$enable_languages in
*jit*)
  ;;
*)
  CET_HOST_FLAGS=
  ;;
esac
AC_SUBST(CET_HOST_FLAGS)


dnl --enable-s390-excess-float-precision is gone, and so is the probe behind
dnl it.
dnl Why: gcc/CONFIGURE-HISTORY.md "configure.ac:4260".

# On x86-64, when profiling is enabled with shrink wrapping, the mcount
# call may not be placed at the function entry after
#	pushq %rbp
#	movq %rsp,%rbp
# As the result, the profile data may be skewed which makes PGO less
# effective:
# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=120881
# Enable -mfentry by default on x86-64 to put the profiling counter call
# before the prologue.
AC_PATH_PROG(PERF, perf, no)
AFDO_PROFILER=perf
if test x$PERF != xno; then
  case "$cpu_type" in
    aarch64)
      AC_MSG_CHECKING(AArch64 build supports SPE profiling for autoprofiledbootstrap)
      aarch64_spe_support=no
      if test -x $PERF; then
	# Do not use perf_spe if BRBE is supported
	if test ! -n "$($PERF record -j any,u -o /dev/null /bin/true 2>&1 | grep "PMU Hardware or event type doesn't support branch stack sampling.")"; then
	  AFDO_PROFILER=perf
	  aarch64_spe_support="using BRBE instead"
	elif test -n "$($PERF list pmu | grep arm_spe)"; then
	  AFDO_PROFILER=perf_spe
	  aarch64_spe_support=yes
	fi
      fi
      AC_MSG_RESULT($aarch64_spe_support)
      ;;
  esac
fi
AC_SUBST(PERF)
AC_SUBST(AFDO_PROFILER)


# Configure the subdirectories
# AC_CONFIG_SUBDIRS($subdirs)

# Create the Makefile
# and configure language subdirectories
AC_CONFIG_FILES($all_outputs)

AC_CONFIG_COMMANDS([default],
[
case ${CONFIG_HEADERS} in
  *auto-host.h:config.in*)
  echo > cstamp-h ;;
esac
# Make sure all the subdirs exist.
for d in $subdirs doc build common c-family
do
    test -d $d || mkdir $d
done
], 
[subdirs='$subdirs'])
AC_OUTPUT
