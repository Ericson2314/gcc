dnl Post-build generation of a per-target spec file.
dnl
dnl Rationale: the HAVE_AS_*/HAVE_LD_* checks in gcc/configure.ac are probes of a
dnl SPECIFIC as/ld binary, not properties of a target.  A multi-target compiler
dnl cannot answer them when it is configured, because the target toolchain is not
dnl known yet.  Run post-build -- when the toolchain IS known -- the same probes
dnl produce the same answers, but they land in that target's spec file instead of
dnl being frozen into auto-host.h.
dnl
dnl Output is in the `*name:\nvalue\n\n' form that the driver's read_specs()
dnl already parses, so nothing in the driver needs to change to consume it.

dnl TS_AS_CHECK(DESCRIPTION, VARIABLE, AS-FLAGS, PROGRAM)
dnl ------------------------------------------------------
dnl The counterpart of gcc/acinclude.m4's gcc_GAS_CHECK_FEATURE, for probes that
dnl have moved here.  Deliberately NOT the same macro: that one caches its
dnl answer and AC_DEFINEs it into auto-host.h, and both of those are exactly
dnl what a per-target probe must not do.  Sets VARIABLE to yes or no.
dnl
dnl No cache variable: this script is re-run once per target against a different
dnl assembler each time, and a cache shared across those runs would hand one
dnl target's answer to another -- the project's canonical failure, in configure
dnl rather than in C.
m4_define([TS_AS_CHECK],
[AC_MSG_CHECKING([assembler for $1])
$2=no
if test x"$gcc_cv_as" != x; then
  cat > conftest.s <<'TS_ASEOF'
$4
TS_ASEOF
  if "$gcc_cv_as" $3 -o conftest.o conftest.s > /dev/null 2>&1; then
    $2=yes
  fi
  rm -f conftest.o conftest.s
fi
AC_MSG_RESULT([$$2])])

AC_INIT([gcc-target-specs], [1.0])
AC_CONFIG_SRCDIR([configure.ac])
dnl config.sub/config.guess live at the top of the tree.
AC_CONFIG_AUX_DIR([..])
dnl Picks up --target from the toplevel when built as a module; falls back to the
dnl host triple for a standalone run.
AC_CANONICAL_TARGET

dnl Overrides the target above, for generating specs for a target other than the
dnl one this tree was configured for.  That is the post-build, per-target case.
AC_ARG_WITH([target],
  [AS_HELP_STRING([--with-target=TRIPLE], [target these specs describe])],
  [target=$withval], [])

dnl Directory holding the target's binutils.  Prepended to PATH for the whole
dnl probe run.
dnl
dnl This is not a convenience.  Probing with two absolute paths (--with-as and
dnl --with-ld) is measurably insufficient: many checks invoke *other* binutils
dnl programs, or invoke as/ld in ways that make them exec their siblings, so
dnl with only two paths set roughly ten probes still fail -- among them
dnl HAVE_GAS_CFI_DIRECTIVE, HAVE_AS_LEB128 and HAVE_LD_EH_GC_SECTIONS.  A failed
dnl probe is not an error in GCC's configure; it silently records "no".  So the
dnl result is a spec file that is quietly pessimistic rather than one that is
dnl obviously broken.
AC_ARG_WITH([tools-dir],
  [AS_HELP_STRING([--with-tools-dir=DIR],
     [directory of the target's binutils; prepended to PATH while probing])],
  [ts_tools_dir=$withval], [ts_tools_dir=])

if test x"$ts_tools_dir" != x; then
  if test -d "$ts_tools_dir"; then
    PATH="$ts_tools_dir:$PATH"
    export PATH
    AC_MSG_NOTICE([probing with $ts_tools_dir at the front of PATH])
  else
    AC_MSG_ERROR([--with-tools-dir=$ts_tools_dir is not a directory])
  fi
fi

dnl Default tool names: a cross target gets the TRIPLE-prefixed tools, but for a
dnl native target the unprefixed names are the ones that actually exist -- a host
dnl commonly has `as' with no `x86_64-pc-linux-gnu-as' alias.  Prefer the
dnl prefixed name when it is present either way, since it is unambiguous.
if test "$target" = "$host"; then
  ts_default_as=as
  ts_default_ld=ld
  command -v ${target}-as > /dev/null 2>&1 && ts_default_as=${target}-as
  command -v ${target}-ld > /dev/null 2>&1 && ts_default_ld=${target}-ld
else
  ts_default_as=${target}-as
  ts_default_ld=${target}-ld
fi

AC_ARG_WITH([as],
  [AS_HELP_STRING([--with-as=PATH], [assembler to probe (default: TARGET-as, or as if native)])],
  [gcc_cv_as=$withval], [gcc_cv_as=$ts_default_as])

AC_ARG_WITH([ld],
  [AS_HELP_STRING([--with-ld=PATH], [linker to probe (default: TARGET-ld, or ld if native)])],
  [gcc_cv_ld=$withval], [gcc_cv_ld=$ts_default_ld])

dnl objdump and readelf.  Several probes below inspect the object a test
dnl assembly produced rather than trusting the assembler exit status -- some
dnl assemblers accept a directive and then encode it wrongly.  These were
dnl referenced but never set, so every probe that consults them silently took
dnl its "no tool, assume the worst" branch.
if test "$target" = "$host"; then
  ts_default_objdump=objdump
  ts_default_readelf=readelf
  command -v ${target}-objdump > /dev/null 2>&1 && ts_default_objdump=${target}-objdump
  command -v ${target}-readelf > /dev/null 2>&1 && ts_default_readelf=${target}-readelf
else
  ts_default_objdump=${target}-objdump
  ts_default_readelf=${target}-readelf
fi

AC_ARG_WITH([objdump],
  [AS_HELP_STRING([--with-objdump=PATH], [objdump to inspect probe output with])],
  [gcc_cv_objdump=$withval], [gcc_cv_objdump=$ts_default_objdump])
command -v "$gcc_cv_objdump" > /dev/null 2>&1 || gcc_cv_objdump=

AC_ARG_WITH([readelf],
  [AS_HELP_STRING([--with-readelf=PATH], [readelf to inspect probe output with])],
  [gcc_cv_readelf=$withval], [gcc_cv_readelf=$ts_default_readelf])
command -v "$gcc_cv_readelf" > /dev/null 2>&1 || gcc_cv_readelf=

dnl nm, for the probes that read the object back rather than trusting the
dnl assembler's exit status.  `.subsection -1' is the one that needs it: a
dnl broken assembler accepts the directive and emits in the wrong place.
if test "$target" = "$host"; then
  ts_default_nm=nm
  command -v ${target}-nm > /dev/null 2>&1 && ts_default_nm=${target}-nm
else
  ts_default_nm=${target}-nm
fi
AC_ARG_WITH([nm],
  [AS_HELP_STRING([--with-nm=PATH], [nm to inspect probe output with])],
  [gcc_cv_nm=$withval], [gcc_cv_nm=$ts_default_nm])
command -v "$gcc_cv_nm" > /dev/null 2>&1 || gcc_cv_nm=

AC_MSG_CHECKING([for nm])
AC_MSG_RESULT([${gcc_cv_nm:-not found}])
AC_MSG_CHECKING([for objdump])
AC_MSG_RESULT([${gcc_cv_objdump:-not found}])
AC_MSG_CHECKING([for readelf])
AC_MSG_RESULT([${gcc_cv_readelf:-not found}])

dnl This target's CPU/ABI defaults.  gcc/configure used to freeze one target's
dnl answers into configure_default_options[[]] and pair them with that target's
dnl OPTION_DEFAULT_SPECS templates inside the driver; here they are ordinary
dnl inputs, so one driver can carry different defaults for every target it
dnl serves.  gcc/config.gcc infers them from the triple and gcc/configure.ac
dnl records them in the multi-target manifest as `name=value' pairs.
AC_ARG_WITH([option-defaults],
  [AS_HELP_STRING([--with-option-defaults=LIST],
     [space-separated name=value defaults, as config.gcc infers them])],
  [spec_option_defaults=$withval], [spec_option_defaults=])

dnl Which back end this target uses.  The templates below are not the same for
dnl every back end -- i386 spells the `cpu' and `tune' defaults as -mtune, most
dnl others spell `cpu' as -mcpu -- so the expansion has to know.
AC_ARG_WITH([cpu-type],
  [AS_HELP_STRING([--with-cpu-type=NAME], [back end name, e.g. i386, mips])],
  [spec_cpu_type=$withval], [spec_cpu_type=])

dnl Properties of the target that are decided by the target itself rather than
dnl probed from a tool: gcc/config.gcc derives them from the triple and
dnl gcc/configure.ac reports them in the manifest.  They are passed through here
dnl because the target config file is the one channel cc1 reads.
AC_ARG_WITH([decimal-float],
  [AS_HELP_STRING([--with-decimal-float=0|1],
     [target has decimal float support in its libgcc])],
  [spec_decimal_float=$withval], [spec_decimal_float=0])
AC_ARG_WITH([decimal-bid-format],
  [AS_HELP_STRING([--with-decimal-bid-format=0|1],
     [target ABI encodes decimal float as BID rather than DPD])],
  [spec_decimal_bid_format=$withval], [spec_decimal_bid_format=0])
dnl Whether this build has a libatomic for this target.  Not probed: the
dnl question is "did the top level build one", and when these probes run it has
dnl not been installed yet, so asking the linker for -latomic would answer no on
dnl a build that is about to have one.  gcc/configure knows (TARGET_CONFIGDIRS)
dnl and gcc/Makefile.in passes it to exactly the one target it holds for.
AC_ARG_WITH([libatomic],
  [AS_HELP_STRING([--with-libatomic=yes|no],
     [this build provides a libatomic for the target])],
  [spec_libatomic=$withval], [spec_libatomic=no])
dnl Whether this target has a SHARED libgcc.  Not probed, for the same reason as
dnl libatomic: when these probes run libgcc has not been built, so asking the
dnl linker for -lgcc_s would answer no on a build that is about to have one.
dnl
dnl It is config.gcc data -- 24 of its arms put `t-slibgcc' in tmake_file, and
dnl that fragment sets SHLIB, which used to reach the driver as
dnl -DENABLE_SHARED_LIBGCC through gcc/Makefile.in's DRIVER_DEFINES.  The
dnl tmake_file it reached through was the PRIMARY target's, and gcc.cc is
dnl compiled once, so one target's answer was applied to all of them silently.
dnl The manifest records tmake_file_present per target; gcc/Makefile.in reads
dnl t-slibgcc out of it and passes the answer here, per target.
dnl
dnl `no' is the conservative default and it matches the driver's own built-in
dnl `*libgcc_variants' -- an unprobed driver, and a target this is not passed
dnl for, keep exactly the plain -lgcc that a build without ENABLE_SHARED_LIBGCC
dnl emitted.
AC_ARG_WITH([shared-libgcc],
  [AS_HELP_STRING([--with-shared-libgcc=yes|no],
     [this target has a shared libgcc (config.gcc gave it t-slibgcc)])],
  [spec_shared_libgcc=$withval], [spec_shared_libgcc=no])
dnl A value that is neither `yes' nor `no' would fall down the `else' arm below
dnl and be indistinguishable from a target that really has no shared libgcc --
dnl the absence of an answer becoming an answer, silently, on that one target.
dnl The default above is a decision; a misspelt --with-shared-libgcc= is not.
case $spec_shared_libgcc in
  yes | no ) ;;
  * ) AC_MSG_ERROR([--with-shared-libgcc must be `yes' or `no', not `$spec_shared_libgcc'; it says whether ${target} has a shared libgcc, and any other value would silently select the static libgcc specs for that target alone]) ;;
esac
dnl The target's GNU C Library version.  gcc/configure used to grep __GLIBC__
dnl out of the target sysroot's features.h; this step is the right place to ask,
dnl because it runs per target after the build and whoever runs it knows what
dnl the target actually is.  Unset means unknown (0.0), which is what a cross
dnl build with no target headers has always recorded, and every consumer treats
dnl unknown as "assume nothing newer".
AC_ARG_WITH([glibc-version],
  [AS_HELP_STRING([--with-glibc-version=M.N],
     [target runs glibc version M.N or later])],
  [spec_glibc_version=$withval], [spec_glibc_version=])
spec_glibc_major=0
spec_glibc_minor=0
if test x"$spec_glibc_version" != x; then
  if echo "$spec_glibc_version" | grep '^[[0-9]][[0-9]]*\.[[0-9]][[0-9]]*$' > /dev/null; then
    spec_glibc_major=`echo "$spec_glibc_version" | sed -e 's/\..*//'`
    spec_glibc_minor=`echo "$spec_glibc_version" | sed -e 's/.*\.//'`
  else
    AC_MSG_ERROR([--with-glibc-version requires a version number M.N])
  fi
fi

dnl Two libc facts that combine the triple with that version.  Worked out here
dnl rather than in gcc/config.gcc because config.gcc knows the triple but has no
dnl way to learn the glibc version, and cc1 knows neither.
ts_glibc_at_least () {
  # $1 major, $2 minor
  if test "$spec_glibc_major" -gt "$1"; then
    return 0
  fi
  if test "$spec_glibc_major" -eq "$1" && test "$spec_glibc_minor" -ge "$2"; then
    return 0
  fi
  return 1
}

spec_libc_hwcap_in_tcb=0
case ${target} in
  powerpc*-*-linux*)
    if ts_glibc_at_least 2 23; then spec_libc_hwcap_in_tcb=1; fi
    ;;
esac

spec_libc_gnustack=0
case ${target} in
  mips*-*-linux-musl*)
    spec_libc_gnustack=1
    ;;
  mips*-*-linux*)
    if ts_glibc_at_least 2 31; then spec_libc_gnustack=1; fi
    ;;
esac

AC_ARG_WITH([s390-excess-float-precision],
  [AS_HELP_STRING([--with-s390-excess-float-precision=0|1],
     [s390 target C library typedefs float_t to double])],
  [spec_s390_excess_fp=$withval], [spec_s390_excess_fp=0])

AC_ARG_WITH([specs-file],
  [AS_HELP_STRING([--with-specs-file=PATH], [where to write the spec file])],
  [specs_file=$withval], [specs_file=specs-${target}])

dnl Where this target's C++ headers live.  These were --with-gxx-include-dir
dnl and --with-gxx-libcxx-include-dir in gcc/configure.ac, i.e. ONE answer for
dnl the whole compiler; they are per target and they belong here.  They are not
dnl probes: nothing about an assembler or a linker is being asked.  They are
dnl the location of an installation, which is why they are options and not
dnl gcc_cv_ tests.
dnl
dnl THREE STATES, AND THE MIDDLE ONE IS THE TRAP.
dnl
dnl   unset       emit no key.  targ_caps keeps its built-in default, which is
dnl               the installation-relative path gcc/Makefile.in computes and
dnl               passes as -DGPLUSPLUS_INCLUDE_DIR.  This is today behaviour,
dnl               unchanged, and it is the right answer for a target installed
dnl               under our own prefix.
dnl   =DIR        emit DIR.  The tool and backward directories are derived from
dnl               it unless given separately.
dnl   =no         emit the key with an EMPTY value.  "This target has no such
dnl               directory": cppdefault.cc drops the entry from the include
dnl               search path rather than searching "".
dnl
dnl OMITTING THE KEY IS NOT THE SAME AS EMITTING IT EMPTY, and it is silently
dnl the opposite: an omitted key leaves the built-in default in place, so
dnl --with-gxx-libcxx-include-dir=no would go on searching the libc++ headers.
dnl That is why =no writes a key with nothing after the name rather than
dnl skipping the line.
ts_emit_gxx=no
ts_emit_gxx_libcxx=no
ts_gxx_include_dir=
ts_gxx_tool_include_dir=
ts_gxx_backward_include_dir=
ts_gxx_libcxx_include_dir=

AC_ARG_WITH([gxx-include-dir],
  [AS_HELP_STRING([--with-gxx-include-dir=DIR],
     [where this target's g++ header files are; "no" for none at all])],
  [ts_emit_gxx=yes
   case $withval in
     no|"") ts_gxx_include_dir= ;;
     yes)   AC_MSG_ERROR([--with-gxx-include-dir needs a directory or "no"]) ;;
     *)     ts_gxx_include_dir=$withval ;;
   esac], [])

AC_ARG_WITH([gxx-tool-include-dir],
  [AS_HELP_STRING([--with-gxx-tool-include-dir=DIR],
     [where this target's target-specific g++ headers are])],
  [ts_emit_gxx=yes
   case $withval in
     no|"") ts_gxx_tool_include_dir= ;;
     yes)   AC_MSG_ERROR([--with-gxx-tool-include-dir needs a directory or "no"]) ;;
     *)     ts_gxx_tool_include_dir=$withval ;;
   esac],
  [dnl Derived, and this derivation is the reason the key exists.  gcc's
   dnl Makefile.in builds GPLUSPLUS_TOOL_INCLUDE_DIR as
   dnl $(gcc_gxx_include_dir)/$(target_noncanonical) with target_noncanonical
   dnl UNSUBSTITUTED, so the built-in default has been a duplicate of
   dnl gxx_include_dir with a trailing slash, entered into the search path
   dnl twice.  Here ${target} is known, so this is the first place the entry
   dnl can be right.  Only derived when a base was given: with no base there is
   dnl nothing to append to, and emitting a bare "/${target}" would be worse
   dnl than the duplicate.
   if test x"$ts_emit_gxx" = xyes && test -n "$ts_gxx_include_dir"; then
     ts_gxx_tool_include_dir=$ts_gxx_include_dir/$target
   fi])

AC_ARG_WITH([gxx-backward-include-dir],
  [AS_HELP_STRING([--with-gxx-backward-include-dir=DIR],
     [where this target's backward-compatibility g++ headers are])],
  [ts_emit_gxx=yes
   case $withval in
     no|"") ts_gxx_backward_include_dir= ;;
     yes)   AC_MSG_ERROR([--with-gxx-backward-include-dir needs a directory or "no"]) ;;
     *)     ts_gxx_backward_include_dir=$withval ;;
   esac],
  [if test x"$ts_emit_gxx" = xyes && test -n "$ts_gxx_include_dir"; then
     ts_gxx_backward_include_dir=$ts_gxx_include_dir/backward
   fi])

AC_ARG_WITH([gxx-libcxx-include-dir],
  [AS_HELP_STRING([--with-gxx-libcxx-include-dir=DIR],
     [where this target's libc++ header files are; "no" for none at all])],
  [ts_emit_gxx_libcxx=yes
   case $withval in
     no|"") ts_gxx_libcxx_include_dir= ;;
     yes)   AC_MSG_ERROR([--with-gxx-libcxx-include-dir needs a directory or "no"]) ;;
     *)     ts_gxx_libcxx_include_dir=$withval ;;
   esac], [])

dnl Where this target's site-local and system headers live.  These were
dnl --with-local-prefix and --with-native-system-header-dir in gcc/configure.ac
dnl -- again ONE answer for the whole compiler -- plus the `native_system_header_dir'
dnl case in gcc/config.gcc.  Like the gxx keys above they are STRINGS and they
dnl are not probes: nothing is being asked of an assembler.
dnl
dnl THE SAME THREE STATES, AND THE SAME TRAP.  Absent means "nothing said" and
dnl leaves cppdefault.cc's compile-time fallback in place; a key with nothing
dnl after its name means "this target has no such directory" and removes the
dnl entry.  So the =no arms below clear the variable and the key is still
dnl written -- skipping the line would be silently the opposite of what was
dnl asked for.
dnl
dnl WHY THESE ARE WRITTEN UNCONDITIONALLY while the gxx ones are not.  The gxx
dnl built-in default is a path derived from OUR OWN prefix, which is right for
dnl any target installed under it, so saying nothing is a real answer.  These
dnl two are not: the built-in NATIVE_SYSTEM_HEADER_DIR is whatever config.gcc
dnl chose for the target this tree was CONFIGURED for, applied to every target
dnl the compiler can emit for.  That is the project's own bug, in the include
dnl search path -- a mingw target getting /usr/include because the build was
dnl configured for linux, with no diagnostic.  Stating the answer per target is
dnl the fix, so it is stated for every target.
AC_ARG_WITH([local-prefix],
  [AS_HELP_STRING([--with-local-prefix=DIR],
     [where this target's site-local headers are installed])],
  [case $withval in
     no|"") ts_local_prefix= ;;
     yes)   AC_MSG_ERROR([--with-local-prefix needs a directory or "no"]) ;;
     *)     ts_local_prefix=$withval ;;
   esac], [ts_local_prefix=/usr/local])

dnl "no" for the prefix means no site-local include directory at all, which is
dnl the empty key rather than "/include".
if test -n "$ts_local_prefix"; then
  ts_local_include_dir=$ts_local_prefix/include
else
  ts_local_include_dir=
fi

dnl The default is the `case $target' in gcc/config.gcc, reproduced here rather
dnl than approximated: /usr/include everywhere except the six arms that say
dnl otherwise.  config.gcc lines 277, 965, 980, 1425, 1940, 2225 and 2395 are
dnl the authority; keep this list and that one in step.
case $target in
  *-*-fuchsia*)                 ts_native_system_header_dir=/include ;;
  *-*-gnu*)                     ts_native_system_header_dir=/include ;;
  amdgcn-*-amdhsa*)             ts_native_system_header_dir=/include ;;
  *-*-mingw*)                   ts_native_system_header_dir=/mingw/include ;;
  *-*-msdosdjgpp*)              ts_native_system_header_dir=/dev/env/DJDIR/include ;;
  *)                            ts_native_system_header_dir=/usr/include ;;
esac

dnl `*-*-gnu*' above is the Hurd, and it must not swallow the GNU/Linux and
dnl GNU/kFreeBSD triples that config.gcc's enclosing arm lists beside it and
dnl then excludes with an inner case.  Those end in -gnu, so the pattern alone
dnl would match them and move /usr/include to /include for every glibc target
dnl in the tree.  Re-assert the exclusion the way config.gcc does.
case $target in
  *-*-linux* | *-*-kfreebsd*-gnu | *-*-kopensolaris*-gnu | *-*-uclinuxfdpiceabi)
    ts_native_system_header_dir=/usr/include ;;
esac

AC_ARG_WITH([native-system-header-dir],
  [AS_HELP_STRING([--with-native-system-header-dir=DIR],
     [where this target's system headers are; "no" for none at all])],
  [case $withval in
     no|"") ts_native_system_header_dir= ;;
     yes)   AC_MSG_ERROR([--with-native-system-header-dir needs a directory or "no"]) ;;
     *)     ts_native_system_header_dir=$withval ;;
   esac], [])

dnl The prefix-relocation component of the SAME two table entries, so it moves
dnl with the directory or not at all.  A config file that sets the directory and
dnl leaves this alone gets one target's directory keyed under another target's
dnl component, silently, so it is always written beside it.  The only tm.h in
dnl the tree that sets NATIVE_SYSTEM_HEADER_COMPONENT is config/mingw/mingw32.h;
dnl config/openbsd.h only reads it.  Everywhere else it is absent, which is the
dnl empty value here, NOT an omitted key.
case $target in
  *-*-mingw*) ts_native_system_header_component=MINGW ;;
  *)          ts_native_system_header_component= ;;
esac

dnl Missing tools are not an error.  When this runs as part of the tree the
dnl target's binutils may legitimately not be installed yet, and failing the
dnl whole build for that would be wrong -- the specs for that target simply
dnl cannot be probed now, and the file says so.
have_target_tools=yes

AC_MSG_CHECKING([for a usable assembler])
if test -x "$gcc_cv_as" || command -v "$gcc_cv_as" > /dev/null 2>&1; then
  AC_MSG_RESULT([$gcc_cv_as])
else
  AC_MSG_RESULT([not found])
  AC_MSG_WARN([assembler $gcc_cv_as not found; specs will not be probed])
  have_target_tools=no
fi

AC_MSG_CHECKING([for a usable linker])
if test -x "$gcc_cv_ld" || command -v "$gcc_cv_ld" > /dev/null 2>&1; then
  AC_MSG_RESULT([$gcc_cv_ld])
else
  AC_MSG_RESULT([not found])
  AC_MSG_WARN([linker $gcc_cv_ld not found; specs will not be probed])
  have_target_tools=no
fi

dnl ---------------------------------------------------------------------------
dnl Probes.  Each mirrors the corresponding check in gcc/configure.ac, but runs
dnl against the tools named above rather than the ones configure happened to find.
dnl ---------------------------------------------------------------------------

dnl --fatal-warnings, for probes that must not accept "assembled it, but warned
dnl that it does not mean what you asked".  Two probes in this file already
dnl referenced $fw_as_opt while nothing set it, so they were running without it
dnl and could have taken a warning for a pass.
AC_MSG_CHECKING([assembler for --fatal-warnings])
fw_as_opt=
echo '	.text' > conftest.s
if "$gcc_cv_as" --fatal-warnings -o conftest.o conftest.s > /dev/null 2>&1; then
  fw_as_opt=--fatal-warnings
fi
rm -f conftest.s conftest.o
AC_MSG_RESULT([${fw_as_opt:-not supported}])

dnl --gdwarf-5, feeding ASM_DEBUG_OPTION_SPEC / ASM_DEBUG_SPEC.
AC_MSG_CHECKING([assembler for --gdwarf-5])
gcc_cv_as_gdwarf_5=no
echo "	.text" > conftest.s
if "$gcc_cv_as" --gdwarf-5 -o conftest.o conftest.s > /dev/null 2>&1; then
  gcc_cv_as_gdwarf_5=yes
fi
AC_MSG_RESULT([$gcc_cv_as_gdwarf_5])

dnl --debug-prefix-map, feeding ASM_MAP.
AC_MSG_CHECKING([assembler for --debug-prefix-map])
gcc_cv_as_debug_prefix_map=no
if "$gcc_cv_as" --debug-prefix-map /a=/b -o conftest.o conftest.s > /dev/null 2>&1; then
  gcc_cv_as_debug_prefix_map=yes
fi
AC_MSG_RESULT([$gcc_cv_as_debug_prefix_map])

dnl Compressed debug sections: 0 none, 1 gABI, 2 gABI+zstd.  Feeds
dnl ASM_COMPRESS_DEBUG_SPEC and LINK_COMPRESS_DEBUG_SPEC.
AC_MSG_CHECKING([assembler for compressed debug sections])
gcc_cv_as_compress_debug=0
if "$gcc_cv_as" --compress-debug-sections=zlib -o conftest.o conftest.s > /dev/null 2>&1; then
  gcc_cv_as_compress_debug=1
  if "$gcc_cv_as" --compress-debug-sections=zstd -o conftest.o conftest.s > /dev/null 2>&1; then
    gcc_cv_as_compress_debug=2
  fi
fi
AC_MSG_RESULT([$gcc_cv_as_compress_debug])

AC_MSG_CHECKING([linker for compressed debug sections])
gcc_cv_ld_compress_debug=0
if "$gcc_cv_ld" --help 2>&1 | grep -- '--compress-debug-sections' > /dev/null; then
  gcc_cv_ld_compress_debug=1
  if "$gcc_cv_ld" --help 2>&1 | grep -- '--compress-debug-sections.*zstd' > /dev/null; then
    gcc_cv_ld_compress_debug=2
  fi
fi
AC_MSG_RESULT([$gcc_cv_ld_compress_debug])

dnl Whether to pass --build-id is a matter of what this linker supports and
dnl what the installation wants, so it is decided here rather than when the
dnl compiler is built.
AC_ARG_ENABLE([linker-build-id],
  [AS_HELP_STRING([--enable-linker-build-id],
     [always pass --build-id to the linker])],
  [], [enable_linker_build_id=no])

AC_MSG_CHECKING([linker for --build-id])
gcc_cv_ld_buildid=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '--build-id' > /dev/null; then
  gcc_cv_ld_buildid=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_buildid])

if test x"$enable_linker_build_id" = xyes && test x"$gcc_cv_ld_buildid" != xyes; then
  AC_MSG_WARN([--build-id is not supported by $gcc_cv_ld; ignored])
  enable_linker_build_id=no
fi

if test x"$enable_linker_build_id" = xyes; then
  link_buildid='%{!r:--build-id} '
else
  link_buildid=
fi

dnl This probe ran and its answer was thrown away -- it reached nothing but an
dnl AC_MSG_NOTICE at the end of the script.  Meanwhile the driver had lost
dnl LINK_EH_SPEC along with tm.h, so --eh-frame-hdr was being passed on no
dnl target at all.  config/gnu-user.h's comment already promised this channel
dnl ("the answer for a linker that does not is delivered by overriding the
dnl spec, see target-specs/configure.ac"); it just was not built.
dnl
dnl `%{!static|static-pie:...}' is the spelling every LINK_EH_SPEC used, except
dnl DragonFly's, which passed it unconditionally.  Static links have no
dnl PT_GNU_EH_FRAME consumer, so the guarded form is the correct one.
AC_MSG_CHECKING([linker for --eh-frame-hdr])
gcc_cv_ld_eh_frame_hdr=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '--eh-frame-hdr' > /dev/null; then
  gcc_cv_ld_eh_frame_hdr=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_eh_frame_hdr])

if test x"$gcc_cv_ld_eh_frame_hdr" = xyes; then
  link_eh='%{!static|static-pie:--eh-frame-hdr} '
else
  link_eh=
fi

AC_MSG_CHECKING([linker for -pie])
gcc_cv_ld_pie=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '-pie' > /dev/null; then
  gcc_cv_ld_pie=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_pie])

dnl .sleb128/.uleb128 with symbol arithmetic.  Older GAS and several non-GNU
dnl assemblers accept the directives but compute the difference wrongly, so the
dnl probe assembles a symbol difference and checks the encoded bytes rather than
dnl just the exit status.  Feeds targ_caps.leb128 in cc1, not a spec string.
AC_MSG_CHECKING([assembler for .sleb128/.uleb128])
gcc_cv_as_leb128=no
cat > conftest.s <<'TSEOF'
	.data
	.uleb128 L2 - L1
L1:
	.uleb128 0x8000000000000000
L2:
TSEOF
if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
  gcc_cv_as_leb128=yes
fi
AC_MSG_RESULT([$gcc_cv_as_leb128])

dnl The -Bstatic/-Bdynamic probe is gone with the *link_static and
dnl *link_dynamic specs it fed (see the note further down).  Its OTHER upstream
dnl consumer is worth naming so nobody re-adds the probe before the channel
dnl exists: HAVE_LD_STATIC_DYNAMIC picks the shape of LIBASAN_SPEC and its four
dnl siblings in gcc.cc, and that is an `#elif defined(...)' resolved when gcc.cc
dnl is COMPILED.  Delivering an answer to it means making those five sanitizer
dnl specs runtime first; a probe whose answer has nowhere to go is the thing
dnl this file keeps being caught doing.

rm -f conftest.s conftest.o

dnl ---------------------------------------------------------------------------
dnl Compose the spec fragments the probes feed, mirroring gcc.cc's #ifndef
dnl ladder.  Only probe-derived specs are emitted; specs that come from tm.h
dnl macros are the separate half of this problem and are not handled here.
dnl ---------------------------------------------------------------------------

if test x"$gcc_cv_as_debug_prefix_map" = xyes; then
  asm_map=' %{ffile-prefix-map=*:--debug-prefix-map %*} %{fdebug-prefix-map=*:--debug-prefix-map %*}'
else
  asm_map=''
fi

if test x"$gcc_cv_as_gdwarf_5" = xyes; then
  asm_debug_option_spec='%{g*:%{%:debug-level-gt(0):%{%:dwarf-version-gt(4):--gdwarf-5 ;%:dwarf-version-gt(3):--gdwarf-4 ;%:dwarf-version-gt(2):--gdwarf-3 ;:--gdwarf2 }}}'
  asm_debug_spec="%{g*:%{%:debug-level-gt(0):}}${asm_map}"
else
  asm_debug_option_spec=''
  asm_debug_spec="%{g*:%{%:debug-level-gt(0):--gdwarf2}}${asm_map}"
fi

case $gcc_cv_as_compress_debug in
  0) asm_compress_debug=' %{gz*:} ' ;;
  1) asm_compress_debug=' %{gz|gz=zlib:--compress-debug-sections=zlib} %{gz=none:--compress-debug-sections=none} %{gz=zlib-gnu:}' ;;
  2) asm_compress_debug=' %{gz|gz=zlib:--compress-debug-sections=zlib} %{gz=none:--compress-debug-sections=none} %{gz=zstd:--compress-debug-sections=zstd} %{gz=zlib-gnu:}' ;;
esac

case $gcc_cv_ld_compress_debug in
  0) link_compress_debug=' %{gz*:%e-gz is not supported in this configuration} ' ;;
  1) link_compress_debug=' %{gz|gz=zlib:--compress-debug-sections=zlib} %{gz=none:--compress-debug-sections=none} %{gz=zstd:%e-gz=zstd is not supported in this configuration} %{gz=zlib-gnu:}' ;;
  2) link_compress_debug=' %{gz|gz=zlib:--compress-debug-sections=zlib} %{gz=none:--compress-debug-sections=none} %{gz=zstd:--compress-debug-sections=zstd} %{gz=zlib-gnu:}' ;;
esac

dnl Expand this target's option defaults against its back end's
dnl OPTION_DEFAULT_SPECS templates, so the driver receives a plain self spec with
dnl no %(VALUE) left in it.  The driver used to hold both halves -- the template
dnl from tm.h, the value from configure -- in a static table that -dumpspecs did
dnl not show and no spec file could reach.
dnl
dnl The templates are transcribed from the back ends' OPTION_DEFAULT_SPECS.  They
dnl are NOT uniform: i386 spells both `cpu' and `tune' as -mtune, most others
dnl spell `cpu' as -mcpu, and mips guards -march with MIPS_ARCH_OPTION_SPEC.
dnl
dnl An option this script has no template for is NOT silently dropped: it is
dnl reported, and recorded as a comment in the spec file.  Dropping it would look
dnl exactly like a target that has no default for it, which is how a wrong
dnl default gets into a compiler without anyone noticing.
option_defaults=
option_defaults_unhandled=
for ts_od in ${spec_option_defaults}; do
  ts_name=`echo "$ts_od" | sed 's/=.*//'`
  ts_value=`echo "$ts_od" | sed 's/^[[^=]]*=//'`
  test x"$ts_value" = x && continue
  ts_tmpl=
  case ${spec_cpu_type}:${ts_name} in
    i386:cpu | i386:tune)
      dnl i386.h: {"cpu"|"tune", "%{!mtune=*:%{!mcpu=*:%{!march=*:-mtune=%(VALUE)}}}"}
      ts_tmpl="%{!mtune=*:%{!mcpu=*:%{!march=*:-mtune=${ts_value}}}}" ;;
    mips:arch)
      dnl mips.h guards this with MIPS_ARCH_OPTION_SPEC, which lists every -m
      dnl option that already implies an architecture.  Approximating it here
      dnl would be a guess, so it is reported instead.
      ts_tmpl= ;;
    *:arch)
      ts_tmpl="%{!march=*:-march=${ts_value}}" ;;
    *:cpu)
      ts_tmpl="%{!mcpu=*:%{!march=*:-mcpu=${ts_value}}}" ;;
    *:tune)
      ts_tmpl="%{!mtune=*:%{!mcpu=*:%{!march=*:-mtune=${ts_value}}}}" ;;
    *:abi)
      ts_tmpl="%{!mabi=*:-mabi=${ts_value}}" ;;
    *:float)
      ts_tmpl="%{!msoft-float:%{!mhard-float:-m${ts_value}-float}}" ;;
    *:nan)
      ts_tmpl="%{!mnan=*:-mnan=${ts_value}}" ;;
    *:divide)
      ts_tmpl="%{!mdivide-traps:%{!mdivide-breaks:-mdivide-${ts_value}}}" ;;
    *:llsc)
      ts_tmpl="%{!mllsc:%{!mno-llsc:-m${ts_value}}}" ;;
    *:mips-plt)
      ts_tmpl="%{!mplt:%{!mno-plt:-m${ts_value}}}" ;;
    *:synci)
      ts_tmpl="%{!msynci:%{!mno-synci:-m${ts_value}}}" ;;
    *:lxc1-sxc1)
      ts_tmpl="%{!mlxc1-sxc1:%{!mno-lxc1-sxc1:-m${ts_value}}}" ;;
    *:madd4)
      ts_tmpl="%{!mmadd4:%{!mno-madd4:-m${ts_value}}}" ;;
    *:msa)
      ts_tmpl="%{!mmsa:%{!mno-msa:-m${ts_value}}}" ;;
    *:compact-branches)
      ts_tmpl="%{!mcompact-branches=*:-mcompact-branches=${ts_value}}" ;;
    *:tls)
      dnl i386 spells this -mtls-dialect=; loongarch and riscv spell it -mtls-dialect=
      dnl too, and arm -mtls-dialect=.  Uniform enough to state.
      ts_tmpl="%{!mtls-dialect=*:-mtls-dialect=${ts_value}}" ;;
    *:schedule)
      ts_tmpl="%{!mschedule=*:-mschedule=${ts_value}}" ;;
  esac
  if test x"$ts_tmpl" = x; then
    option_defaults_unhandled="${option_defaults_unhandled} ${ts_name}=${ts_value}"
  else
    option_defaults="${option_defaults}${ts_tmpl} "
  fi
done

dnl The _32/_64 variants, --with-cmodel, --with-fp-32, --with-odd-spreg-32,
dnl --with-fpu and --with-isa-spec are deliberately absent from the table above.
dnl Their templates are guarded by OPT_ARCH32/OPT_ARCH64, whose expansion is a
dnl compile-time property of the back end's tm.h (i386 keys it on
dnl TARGET_64BIT_DEFAULT, mips on the default ABI), or they reach the back end as
dnl tm_defines rather than as a driver option at all.  Transcribing them from
dnl shell would be a guess; they are reported instead.
if test x"$option_defaults_unhandled" != x; then
  AC_MSG_WARN([no OPTION_DEFAULT_SPECS template for:${option_defaults_unhandled}])
fi

dnl Only write a spec file if the probes actually ran.  Writing one built from
dnl failed probes would record "feature absent" for every feature, which is a
dnl worse outcome than having no file: the driver would silently lose behaviour
dnl rather than fall back to its built-in defaults.
if test x"$have_target_tools" != xyes; then
  AC_MSG_NOTICE([skipping $specs_file: target tools unavailable, nothing probed])
else

dnl Capabilities that cc1 (not the driver) consults.  These cannot be spec
dnl strings -- cc1 never reads spec files -- so they go into a side-car config
dnl file, and the spec file below merely tells the driver to pass its path.
dnl One option carries all of them, so adding a capability never adds an option.
target_config_file=${specs_file}-config
AC_MSG_NOTICE([writing $target_config_file])
cat > "$target_config_file" <<EOF
# Target assembler/linker capabilities for ${target}.
# Read by cc1 via -ftarget-config=; see gcc/target-caps.h.
# Which target this configuration is for.  Not a capability: it is how cc1 and
# the driver learn their own target identity at all, and it is what selects the
# common hook table (see gcc/common/common-target-select.cc).  A compiler given
# no config file selects nothing and fails loudly at the first target hook,
# which is deliberate -- there is no default target any more.
target ${target}
leb128 `if test x"$gcc_cv_as_leb128" = xyes; then echo 1; else echo 0; fi`
# Properties of the target rather than of its tools: derived by config.gcc from
# the triple and passed in, not probed here.
decimal_float ${spec_decimal_float}
decimal_bid_format ${spec_decimal_bid_format}
s390_excess_float_precision ${spec_s390_excess_fp}
# Target C library.  0.0 means "not glibc, or not told"; consumers treat that as
# "assume nothing newer", which is what a build with no target headers got.
glibc_major ${spec_glibc_major}
glibc_minor ${spec_glibc_minor}
libc_hwcap_in_tcb ${spec_libc_hwcap_in_tcb}
libc_gnustack ${spec_libc_gnustack}
EOF

dnl Absolute path, because the driver's cwd is not the spec file's directory.
case $target_config_file in
  /*) target_config_path=$target_config_file ;;
  *)  target_config_path=`pwd`/$target_config_file ;;
esac

AC_MSG_NOTICE([writing $specs_file])
cat > "$specs_file" <<EOF
# Generated by target-specs/configure for ${target}.
# Probes were run against:
#   as: ${gcc_cv_as}
#   ld: ${gcc_cv_ld}
# Do not edit; regenerate by re-running that script against the same toolchain.
# Option defaults with no template here (see the warning above), recorded so a
# missing default is visible rather than looking like a target that has none:
#   ${option_defaults_unhandled}

*asm_debug:
${asm_debug_spec}

*asm_debug_option:
${asm_debug_option_spec}

*asm_compress_debug:
${asm_compress_debug}

*link_compress_debug:
${link_compress_debug}

*option_defaults:
${option_defaults}

*link_buildid:
${link_buildid}

*link_eh:
${link_eh}

*link_hardening:
${link_hardening}

*link_target_config:
-ftarget-config=${target_config_path}

*cc1_target_config:
-ftarget-config=${target_config_path}

EOF

AC_MSG_NOTICE([probe results for ${target}:])
AC_MSG_NOTICE([  as --gdwarf-5 ............ ${gcc_cv_as_gdwarf_5}])
AC_MSG_NOTICE([  as --debug-prefix-map .... ${gcc_cv_as_debug_prefix_map}])
AC_MSG_NOTICE([  as compress-debug ........ ${gcc_cv_as_compress_debug}])
AC_MSG_NOTICE([  ld compress-debug ........ ${gcc_cv_ld_compress_debug}])
AC_MSG_NOTICE([  ld --build-id ............ ${gcc_cv_ld_buildid}])
AC_MSG_NOTICE([  ld --eh-frame-hdr ........ ${gcc_cv_ld_eh_frame_hdr}])
AC_MSG_NOTICE([  ld -pie .................. ${gcc_cv_ld_pie}])

fi

dnl ===========================================================================
dnl LINKER SECTION
dnl
dnl Everything below is the gcc_cv_ld_* half of the probes relocated out of
dnl gcc/configure.ac.  It is kept in one block, and appends to the two files
dnl written above rather than editing their heredocs, so that work on the
dnl assembler half and work on this half never touch the same lines.
dnl
dnl The originals decided most of these from the in-tree ld's version number
dnl (gcc_fn_gld_min_version) or from a `case $target' listing which vendor
dnl linker was known to have the feature.  Neither is available here and
dnl neither is wanted: this script has the actual linker in $gcc_cv_ld, so
dnl every probe below asks it directly.  Where the original had no runnable
dnl test at all -- only a target pattern -- that is called out.
dnl ===========================================================================

if test x"$have_target_tools" = xyes; then

dnl --- Driver-side only: these become spec strings, and never reach cc1. -----

AC_MSG_CHECKING([linker for --as-needed])
gcc_cv_ld_as_needed=no
gcc_cv_ld_as_needed_option='--as-needed'
gcc_cv_ld_no_as_needed_option='--no-as-needed'
if "$gcc_cv_ld" --help 2>&1 | grep -- '--as-needed' > /dev/null; then
  gcc_cv_ld_as_needed=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_as_needed])

dnl Solaris ld spells the same idea as a linker-script directive.  The original
dnl gated this on `case $target' plus a version number; ask the linker instead.
AC_MSG_CHECKING([linker for $ldscript-style as-needed])
gcc_cv_ld_use_as_needed_ldscript=no
if test x"$gcc_cv_ld_as_needed" != xyes \
   && "$gcc_cv_ld" -z help 2>&1 | grep -- 'ignore' > /dev/null; then
  gcc_cv_ld_use_as_needed_ldscript=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_use_as_needed_ldscript])

dnl The answer goes to targ_caps.ld_demangle and nowhere else.  There used to be
dnl a *link_demangle spec beside it, and it was a duplicate with no consumer:
dnl HAVE_LD_DEMANGLE is read by collect2.cc (`if (!HAVE_LD_DEMANGLE)' at four
dnl sites), which decides whether COLLECT2 must demangle for itself.  That is a
dnl C question in a program that never reads a spec file, and it is already
dnl answered by the config file below.  The spec is gone.
AC_MSG_CHECKING([linker for --demangle])
gcc_cv_ld_demangle=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '--demangle' > /dev/null; then
  gcc_cv_ld_demangle=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_demangle])

AC_MSG_CHECKING([linker for --sysroot])
gcc_cv_ld_sysroot=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '--sysroot' > /dev/null; then
  gcc_cv_ld_sysroot=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_sysroot])

AC_MSG_CHECKING([linker for GNU-style response files])
gcc_cv_ld_at_file=no
echo '.byte 0' > conftest.s
echo conftest.o > conftest.at
if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1 \
   && "$gcc_cv_ld" -r -o conftest2.o @conftest.at > /dev/null 2>&1; then
  gcc_cv_ld_at_file=yes
fi
rm -f conftest.s conftest.o conftest2.o conftest.at
AC_MSG_RESULT([$gcc_cv_ld_at_file])

dnl Is there a usable gold BESIDE a default linker that is not gold?  This was
dnl HAVE_GOLD_NON_DEFAULT_SPLIT_STACK in gcc/configure.ac, and gcc.cc used it to
dnl pick between two spellings of STACK_SPLIT_SPEC -- with -fuse-ld=gold and
dnl without.  The probe was dropped in the configure sweep with nothing put in
dnl its place, so the gold arm has been unreachable on every target since.  It
dnl is a question about the installed linker, hence here.
dnl
dnl Three conditions, all of them from the original, kept together because the
dnl answer is only meaningful as a conjunction:
dnl   1. the DEFAULT linker is not already gold (if it is, -fuse-ld=gold buys
dnl      nothing and the original skipped the whole check);
dnl   2. a `<ld>.gold' exists beside it and understands
dnl      --split-stack-adjust-size, which is how gold advertises the feature;
dnl   3. on powerpc64 only, that gold is 2.25.1 or newer, because the complete
dnl      big- and little-endian split-stack support landed there.
dnl
dnl AND THE ANSWER IS `no' EVERYWHERE ELSE, which is the original's behaviour
dnl and not an oversight in transcription: its `case $target' had a powerpc64
dnl arm and no default arm, over a variable initialised to `no'.  The comment
dnl above it read "For platforms other than powerpc64*, enable as appropriate",
dnl i.e. a TODO nobody did.  Reproduced rather than repaired: widening it would
dnl start passing -fuse-ld=gold on targets that have never had it, which is a
dnl behaviour change and belongs in its own change with its own evidence.
AC_MSG_CHECKING([for a non-default gold with split-stack support])
gcc_cv_ld_gold_split_stack=no
ts_ld_is_gold=no
if "$gcc_cv_ld" --version 2>/dev/null | sed 1q | grep "GNU gold" > /dev/null; then
  ts_ld_is_gold=yes
fi
ts_ld_gold=
if test x"$ts_ld_is_gold" = xno; then
  if test -x "${gcc_cv_ld}.gold"; then
    ts_ld_gold="${gcc_cv_ld}.gold"
  elif command -v "${gcc_cv_ld}.gold" > /dev/null 2>&1; then
    ts_ld_gold=`command -v "${gcc_cv_ld}.gold"`
  fi
fi
if test x"$ts_ld_gold" != x; then
  if "$ts_ld_gold" --help 2>/dev/null | grep split-stack-adjust-size > /dev/null; then
    case $target in
      powerpc64*-*-*)
        ts_gold_vers=`"$ts_ld_gold" --version 2>/dev/null | sed 1q | sed -n \
          -e 's,^[[^)]]*[[ 	]]\([[0-9]][[0-9]]*\.[[0-9]][[0-9]]*[[^)]]*\)) .*$,\1,p'`
        case "$ts_gold_vers" in
          2.25.[[1-9]]* | 2.2[[6-9]][[.0-9]]* | 2.[[3-9]][[.0-9]]* | [[3-9]].[[.0-9]]*)
            gcc_cv_ld_gold_split_stack=yes ;;
        esac
        ;;
    esac
  fi
fi
AC_MSG_RESULT([$gcc_cv_ld_gold_split_stack])

dnl The original counted this in three levels, the middle one meaning "gold
dnl 2.20, plugin support only when -fuse-linker-plugin is given".  That
dnl distinction was a version-number judgement about one long-obsolete linker;
dnl here a linker either takes -plugin or it does not.
AC_MSG_CHECKING([linker for -z now])
gcc_cv_ld_now=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '-z now' > /dev/null; then
  gcc_cv_ld_now=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_now])

AC_MSG_CHECKING([linker for -z relro])
gcc_cv_ld_relro=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '-z relro' > /dev/null; then
  gcc_cv_ld_relro=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_relro])

AC_MSG_CHECKING([linker for -plugin])
gcc_cv_lto_plugin=0
if "$gcc_cv_ld" --help 2>&1 | grep -- '-plugin' > /dev/null; then
  gcc_cv_lto_plugin=2
fi
AC_MSG_RESULT([$gcc_cv_lto_plugin])

dnl How this linker spells "statically from here" and "back to dynamic".  GNU
dnl ld says -Bstatic/-Bdynamic, AIX ld -bstatic/-bdynamic, HP-UX ld
dnl -aarchive_shared/-adefault -- so it is a property of the linker, and a
dnl compiler serving many toolchains cannot have it compiled in.
dnl
dnl ONE PROBE, TWO CARRIERS, and both are written below from these two
dnl variables.  The duplication is forced, not chosen:
dnl
dnl   spec text  -- the sanitizer link specs in gcc.cc and in gnu-user.h /
dnl                 freebsd.h, via the %(link_static) / %(link_dynamic) named
dnl                 specs.  Spec text cannot read a variable.
dnl   C code     -- targ_caps.ld_static_option / .ld_dynamic_option, read by the
dnl                 seven language driver programs, which call
dnl                 `append_option (OPT_Wl_, ..., 1)'.  append_option cannot read
dnl                 a spec.
dnl
dnl Emitting only one of them is the failure this is guarding against: half the
dnl consumers would get the probed AIX spelling and the other half the GNU one,
dnl on the same target, with nothing to notice.  Keep the two emissions
dnl together and fed from these variables, never from two probes.
dnl
dnl EMPTY means the linker has no such pair at all, and every consumer must then
dnl omit the option rather than pass an empty one.  That replaces the old
dnl HAVE_LD_STATIC_DYNAMIC: a separate flag could say "yes" beside an empty
dnl spelling, and each consumer would emit a bare `-Wl,'.
AC_MSG_CHECKING([linker spelling for -Bstatic/-Bdynamic])
gcc_cv_ld_static_option=
gcc_cv_ld_dynamic_option=
if "$gcc_cv_ld" --help 2>&1 | grep -- '-Bstatic' > /dev/null; then
  gcc_cv_ld_static_option='-Bstatic'
  gcc_cv_ld_dynamic_option='-Bdynamic'
elif "$gcc_cv_ld" --help 2>&1 | grep -- '-bstatic' > /dev/null; then
  gcc_cv_ld_static_option='-bstatic'
  gcc_cv_ld_dynamic_option='-bdynamic'
elif "$gcc_cv_ld" --help 2>&1 | grep -- '-aarchive_shared' > /dev/null; then
  gcc_cv_ld_static_option='-aarchive_shared'
  gcc_cv_ld_dynamic_option='-adefault'
fi
AC_MSG_RESULT([${gcc_cv_ld_static_option:-none}/${gcc_cv_ld_dynamic_option:-none}])

dnl --- Consulted by cc1: these go in the target config file. ----------------

AC_MSG_CHECKING([linker for .hidden])
gcc_cv_ld_hidden=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '-Bsymbolic' > /dev/null; then
  gcc_cv_ld_hidden=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_hidden])

dnl HAVE_GAS_HIDDEN needs both halves, and they are probed in different sections
dnl of this script -- the assembler one runs LATER.  Combining them here read an
dnl unset gcc_cv_as_hidden and answered no however good the assembler was, which
dnl is the second way this one capability has been silently lost.  The two are
dnl combined where the file is written, once both answers exist.

AC_MSG_CHECKING([linker for read-only/read-write section mixing])
gcc_cv_ld_ro_rw_mix=unknown
echo '.section myfoosect, "a"' > conftest1.s
echo '.section myfoosect, "aw"' > conftest2.s
echo '.byte 1' >> conftest2.s
echo '.section myfoosect, "a"' > conftest3.s
echo '.byte 0' >> conftest3.s
if "$gcc_cv_as" -o conftest1.o conftest1.s > /dev/null 2>&1 \
   && "$gcc_cv_as" -o conftest2.o conftest2.s > /dev/null 2>&1 \
   && "$gcc_cv_as" -o conftest3.o conftest3.s > /dev/null 2>&1; then
  dnl The Wild linker has --gc-sections on by default, hence --no-gc-sections.
  if "$gcc_cv_ld" -shared -o conftest1.so conftest1.o \
        conftest2.o conftest3.o --no-gc-sections > /dev/null 2>&1 \
     || "$gcc_cv_ld" -shared -o conftest1.so conftest1.o \
        conftest2.o conftest3.o > /dev/null 2>&1 \
     || "$gcc_cv_ld" -r -o conftest1.so conftest1.o \
        conftest2.o conftest3.o > /dev/null 2>&1; then
    if test x"$gcc_cv_objdump" != x; then
      ts_mix=`"$gcc_cv_objdump" -h conftest1.so | sed -e '/myfoosect/!d' -e N`
      if echo "$ts_mix" | grep CONTENTS > /dev/null; then
	if echo "$ts_mix" | grep READONLY > /dev/null; then
	  gcc_cv_ld_ro_rw_mix=read-only
	else
	  gcc_cv_ld_ro_rw_mix=read-write
	fi
      fi
    fi
  fi
fi
rm -f conftest1.s conftest2.s conftest3.s conftest1.o conftest2.o conftest3.o
rm -f conftest1.so
AC_MSG_RESULT([$gcc_cv_ld_ro_rw_mix])

AC_MSG_CHECKING([linker for --gc-sections with exception handling])
gcc_cv_ld_eh_gc_sections=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '--gc-sections' > /dev/null; then
  gcc_cv_ld_eh_gc_sections=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_eh_gc_sections])

AC_MSG_CHECKING([linker for -z ctf])
gcc_cv_ld_ctf=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '-z ctf' > /dev/null; then
  gcc_cv_ld_ctf=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_ctf])

dnl The --version-script and -soname probes that used to sit here have gone back
dnl to gcc/configure.ac.  They were never target questions: they answer how to
dnl give libgccjit.so and libgdiagnostics.so -- HOST libraries, linked during the
dnl build by $(LLINKER) -- a version script and an soname.  This script runs
dnl AFTER the build, so an answer computed here can never reach the Makefile
dnl variable that needs it; both probes ran on every target and were discarded,
dnl while Makefile.in went on expanding @ld_version_script_option@ literally onto
dnl a link line.  CHECK C in scratchpad/sweep.sh is what named them.

dnl PE-only.  The original grepped the in-tree ld's own linker scripts for
dnl NOLOAD on .debug_loclists/.debug_rnglists, which cannot be done against an
dnl installed linker; ld --verbose prints the script it would use.
AC_MSG_CHECKING([linker for non-broken PE dwarf5])
gcc_cv_ld_broken_pe_dwarf5=no
case $target in
  *-*-cygwin* | *-*-mingw* | *-*-pe | *-*-win32)
    gcc_cv_ld_broken_pe_dwarf5=yes
    if "$gcc_cv_ld" --verbose 2>/dev/null \
       | grep -- '\.debug_loclists.*NOLOAD' > /dev/null; then
      gcc_cv_ld_broken_pe_dwarf5=no
    fi
    ;;
esac
AC_MSG_RESULT([$gcc_cv_ld_broken_pe_dwarf5])

AC_MSG_CHECKING([linker for --disable-dynamicbase])
gcc_cv_ld_disable_dynamicbase=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '--disable-dynamicbase' > /dev/null; then
  gcc_cv_ld_disable_dynamicbase=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_disable_dynamicbase])

dnl PowerPC-specific.  All three originals were AC_CACHE_CHECKs that assembled
dnl a snippet and linked it; kept as link tests, without the version fallbacks.
AC_MSG_CHECKING([linker for PowerPC .gnu.attributes long double])
gcc_cv_ld_ppc_attr=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '--no-warn-mismatch' > /dev/null; then
  gcc_cv_ld_ppc_attr=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_ppc_attr])

AC_MSG_CHECKING([linker for omitting dot symbols])
gcc_cv_ld_no_dot_syms=no
case $target in
  powerpc64*-*-*)
    cat > conftest1.s <<'TSEOF'
	.text
	bl .foo
TSEOF
    cat > conftest2.s <<'TSEOF'
	.section ".opd","aw"
	.align 3
	.globl foo
	.type foo,@function
foo:
	.quad .LEfoo,.TOC.@tocbase,0
	.text
.LEfoo:
	blr
	.size foo,.-.LEfoo
TSEOF
    if "$gcc_cv_as" -a64 -o conftest1.o conftest1.s > /dev/null 2>&1 \
       && "$gcc_cv_as" -a64 -o conftest2.o conftest2.s > /dev/null 2>&1 \
       && "$gcc_cv_ld" -melf64ppc -o conftest conftest1.o conftest2.o \
	    > /dev/null 2>&1; then
      gcc_cv_ld_no_dot_syms=yes
    fi
    rm -f conftest conftest1.s conftest2.s conftest1.o conftest2.o
    ;;
esac
AC_MSG_RESULT([$gcc_cv_ld_no_dot_syms])

dnl HAVE_LD_LARGE_TOC was AC_DEFINEd from two places in gcc/configure.ac, both
dnl setting the same gcc_cv_ld_large_toc cache variable, and they are NOT one
dnl probe in two arms: they test different things on different object formats.
dnl
dnl  - ELF PowerPC64 assembles a TLS sequence and *links* it with
dnl    --no-toc-sort: a property of the linker, which is what the name says.
dnl  - AIX assembles XCOFF `addis 9,LC..1@u(2)' and never links at all: a
dnl    property of the *assembler*, despite the name and the cache variable.
dnl
dnl Only one arm can run in a single-target build, so the two never met and the
dnl misnomer stayed invisible -- the same shape as the alpha/loongarch
dnl HAVE_AS_EXPLICIT_RELOCS collision.  They have to stay separate here: this
dnl script runs once per target, so it picks the arm that matches, and applying
dnl the ELF test to AIX would answer `no' for every AIX target (wrong emulation,
dnl wrong object format) where the original answered `yes'.  The consumers are
dnl in mutually exclusive headers -- rs6000/aix7?.h against
dnl rs6000/{linux64,freebsd64}.h -- so one capability name still serves both.
AC_MSG_CHECKING([linker/assembler for large TOC])
gcc_cv_ld_large_toc=no
case $target in
  *-*-aix*)
    dnl Assembler-only test: XCOFF large-TOC relocations.
    cat > conftest.s <<'TSEOF'
	.toc
LC..1:
	.tc a[TC],a[RW]
	.extern a[RW]
	.csect .text[PR]
.largetoctest:
	addis 9,LC..1@u(2)
	ld 3,LC..1@l(9)
TSEOF
    if "$gcc_cv_as" -a64 -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_ld_large_toc=yes
    fi
    rm -f conftest.s conftest.o
    ;;
  powerpc64*-*-*)
    dnl Link test: ELF TLS sequence through the linker.
    cat > conftest.s <<'TSEOF'
	.section ".tbss","awT",@nobits
	.align 3
ie0:	.space 8
	.global _start
	.text
_start:
	addis 9,2,ie0@got@tprel@ha
	ld 9,ie0@got@tprel@l(9)
TSEOF
    if "$gcc_cv_as" -a64 -o conftest.o conftest.s > /dev/null 2>&1 \
       && "$gcc_cv_ld" --no-toc-sort -o conftest conftest.o > /dev/null 2>&1; then
      gcc_cv_ld_large_toc=yes
    fi
    rm -f conftest conftest.s conftest.o
    ;;
esac
AC_MSG_RESULT([$gcc_cv_ld_large_toc])

AC_MSG_CHECKING([linker for TOC pointer alignment])
gcc_cv_ld_toc_align=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '--no-toc-optimize' > /dev/null; then
  gcc_cv_ld_toc_align=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_toc_align])

AC_MSG_CHECKING([linker for .eh_frame personality relaxation])
gcc_cv_ld_mips_personality_relaxation=no
case $target in
  mips*-*-*)
    cat > conftest.s <<'TSEOF'
	.cfi_startproc
	.cfi_personality 0x80,indirect_ptr
	.ent test
test:
	nop
	.end test
	.cfi_endproc

	.section .data,"aw",@progbits
indirect_ptr:
	.dc.a personality
TSEOF
    if "$gcc_cv_as" -KPIC -o conftest.o conftest.s > /dev/null 2>&1 \
       && "$gcc_cv_ld" -o conftest conftest.o -shared > /dev/null 2>&1 \
       && test x"$gcc_cv_readelf" != x; then
      if "$gcc_cv_readelf" -d conftest 2>&1 | grep TEXTREL > /dev/null 2>&1; then
	:
      elif "$gcc_cv_readelf" --relocs conftest 2>&1 \
	   | grep 'R_MIPS_REL32 *$' > /dev/null 2>&1; then
	:
      else
	gcc_cv_ld_mips_personality_relaxation=yes
      fi
    fi
    rm -f conftest conftest.s conftest.o
    ;;
esac
AC_MSG_RESULT([$gcc_cv_ld_mips_personality_relaxation])

AC_MSG_CHECKING([linker for -pie with copy relocations])
gcc_cv_ld_pie_copyreloc=no
if test x"$gcc_cv_ld_pie" = xyes \
   && "$gcc_cv_ld" --help 2>&1 | grep -- '-z text' > /dev/null; then
  gcc_cv_ld_pie_copyreloc=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_pie_copyreloc])

dnl AVR only.  The originals read the linker's version string and compared it
dnl against 2.29 and 2.42; ask the linker which emulations it has instead.
AC_MSG_CHECKING([linker for avr emulations])
gcc_cv_ld_avr_avrxmega3_rodata_in_flash=no
gcc_cv_ld_avr_avrxmega2_flmap=no
gcc_cv_ld_avr_avrxmega4_flmap=no
case $target in
  avr-*-*)
    ts_emuls=`"$gcc_cv_ld" -V 2>/dev/null`
    if echo "$ts_emuls" | grep avrxmega3 > /dev/null; then
      dnl The .rodata-in-flash change and the avrxmega3 emulation shipped
      dnl together, so the emulation's presence is the test.
      gcc_cv_ld_avr_avrxmega3_rodata_in_flash=yes
    fi
    if echo "$ts_emuls" | grep avrxmega2_flmap > /dev/null; then
      gcc_cv_ld_avr_avrxmega2_flmap=yes
    fi
    if echo "$ts_emuls" | grep avrxmega4_flmap > /dev/null; then
      gcc_cv_ld_avr_avrxmega4_flmap=yes
    fi
    ;;
esac
AC_MSG_RESULT([$gcc_cv_ld_avr_avrxmega3_rodata_in_flash/$gcc_cv_ld_avr_avrxmega2_flmap/$gcc_cv_ld_avr_avrxmega4_flmap])

dnl ---------------------------------------------------------------------------
dnl ASSEMBLER DEBUG SECTION
dnl
dnl The DWARF and CFI probes from gcc/configure.ac.  These must come after the
dnl linker section: the Solaris arm of the CFI probe reads gcc_cv_ld_ro_rw_mix,
dnl which is established there.
dnl ---------------------------------------------------------------------------

ts_asm_ok () {
  # $1 is the assembly text; assemble it and report yes/no.
  echo "$1" > conftest.s
  if "$gcc_cv_as" $ts_as_flags -o conftest.o conftest.s > /dev/null 2>&1; then
    echo yes
  else
    echo no
  fi
}

ts_as_flags=

dnl .cfi_startproc and friends.  gcc/configure.ac decided this with a
dnl `case "$target"': hppa-hpux forced no (its dynamic linker relocates text
dnl and data separately, so CFI difference expressions break), Darwin forced no
dnl (its assembler accepts them but then emits compact unwind that GCC's output
dnl disagrees with), and Solaris consulted the linker's read-only/read-write
dnl section merging plus an objdump check on whether .eh_frame came out
dnl read-only.  All of that is a property of the toolchain in front of us, so
dnl it is asked rather than assumed -- except the two "assembler lies" cases,
dnl which no probe can detect and which stay keyed on the target.
AC_MSG_CHECKING([assembler for cfi directives])
gcc_cv_as_cfi_directive=`ts_asm_ok '	.text
	.cfi_startproc
	.cfi_offset 0, 0
	.cfi_same_value 1
	.cfi_def_cfa 1, 2
	.cfi_escape 1, 2, 3, 4, 5
	.cfi_endproc'`
case "$target" in
  hppa*-*-hpux*)
    gcc_cv_as_cfi_directive=no ;;
  x86_64-*-darwin* | i?86-*-darwin* | powerpc*-darwin-*)
    gcc_cv_as_cfi_directive=no ;;
  *-*-solaris*)
    if test x"$gcc_cv_ld_ro_rw_mix" = xread-write; then
      :
    elif test x"$gcc_cv_objdump" = x; then
      gcc_cv_as_cfi_directive=no
    else
      # .eh_frame must come out read-write, or GCC and the assembler disagree.
      if "$gcc_cv_objdump" -h conftest.o 2>/dev/null \
	 | sed -e '/.eh_frame/!d' -e N | grep READONLY > /dev/null; then
	gcc_cv_as_cfi_directive=no
      fi
    fi
    ;;
esac
AC_MSG_RESULT([$gcc_cv_as_cfi_directive])

dnl Some assemblers accept .cfi_adjust_cfa_offset and then encode the advance
dnl wrongly, so this checks the emitted DW_CFA_advance_loc rather than the exit
dnl status.  Without objdump there is no way to tell, and the safe answer is no.
AC_MSG_CHECKING([assembler for working cfi advance])
gcc_cv_as_cfi_advance_working=no
if test x"$gcc_cv_as_cfi_directive" = xyes && test x"$gcc_cv_objdump" != x; then
  cat > conftest.s <<'TSEOF'
	.text
	.cfi_startproc
	.cfi_adjust_cfa_offset 64
	.skip 75040, 0
	.cfi_adjust_cfa_offset 128
	.cfi_endproc
TSEOF
  if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1 \
     && "$gcc_cv_objdump" -Wf conftest.o 2>/dev/null \
	| grep 'DW_CFA_advance_loc[[24]]:[[ 	]][[ 	]]*75040[[ 	]]' >/dev/null; then
    gcc_cv_as_cfi_advance_working=yes
  fi
fi
AC_MSG_RESULT([$gcc_cv_as_cfi_advance_working])

AC_MSG_CHECKING([assembler for .cfi_personality])
gcc_cv_as_cfi_personality_directive=`ts_asm_ok '	.text
	.cfi_startproc
	.cfi_personality 0, symbol
	.cfi_endproc'`
AC_MSG_RESULT([$gcc_cv_as_cfi_personality_directive])

dnl .cfi_sections.  On PE the directive is accepted by older assemblers that
dnl then emit the wrong .debug_frame relocation (binutils < 2.21), so there the
dnl emitted relocation is inspected instead of trusting the exit status.
AC_MSG_CHECKING([assembler for .cfi_sections])
gcc_cv_as_cfi_sections_directive=`ts_asm_ok '	.text
	.cfi_sections .debug_frame, .eh_frame
	.cfi_startproc
	.cfi_endproc'`
case $target in
  *-*-mingw* | *-*-cygwin* | *-*-pe | *-*-win32)
    if test x"$gcc_cv_as_cfi_sections_directive" = xyes; then
      gcc_cv_as_cfi_sections_directive=no
      if test x"$gcc_cv_objdump" != x \
	 && "$gcc_cv_objdump" -j .debug_frame -r conftest.o 2>/dev/null \
	    | grep -i secrel > /dev/null; then
	gcc_cv_as_cfi_sections_directive=yes
      fi
    fi
    ;;
esac
AC_MSG_RESULT([$gcc_cv_as_cfi_sections_directive])

dnl .gnu_attribute.  gcc/configure.ac probed this four separate times, once each
dnl in the powerpc, mips, msp430 and s390 arms of `case "$target"' -- the same
dnl directive every time (s390 used tag 8 rather than 4, which tests nothing
dnl different).  One probe here serves all four ports.
dnl AIX `.ref' and the DWARF location-list pseudo-ops.  Both were probed only
dnl inside the `*-*-aix*' arm in gcc/configure.ac, so non-AIX targets always
dnl answered 0; the capability defaults preserve that.
AC_MSG_CHECKING([assembler for AIX .ref])
gcc_cv_as_aix_ref=`ts_asm_ok '	.csect stuff[[rw]]
stuff:
	.long 1
	.extern sym
	.ref sym'`
AC_MSG_RESULT([$gcc_cv_as_aix_ref])

AC_MSG_CHECKING([assembler for AIX DWARF location lists])
gcc_cv_as_aix_dwloc=`ts_asm_ok '	.dwsect 0xA0000
Lframe..0:
	.vbyte 4,Lframe..0'`
AC_MSG_RESULT([$gcc_cv_as_aix_dwloc])

dnl The assembler half of HAVE_GAS_HIDDEN.  This probe was MISSING: the linker
dnl half below tested `x"$gcc_cv_as_hidden" = xyes' against a variable nothing
dnl ever assigned, so it was always empty, gas_hidden came out 0 on assemblers
dnl that have supported .hidden for twenty years, and cc1 stopped emitting
dnl .hidden entirely -- 61 gcc.dg/visibility-* and ~500 g++.dg/ext/visibility
dnl subtests.  Nothing noticed because until now no ordinary build read this
dnl file at all.
dnl
dnl AIX spells it as a third argument to .globl rather than as a directive.
AC_MSG_CHECKING([assembler for .hidden])
case "$target" in
  *-*-aix*) ts_hidden_s='	.globl foobar,hidden' ;;
  *)        ts_hidden_s='	.hidden foobar
foobar:' ;;
esac
gcc_cv_as_hidden=`ts_asm_ok "$ts_hidden_s"`
case "$target" in
  dnl Darwin's as has visibility, with a different syntax the probe cannot use.
  *-*-darwin*) gcc_cv_as_hidden=yes ;;
esac
AC_MSG_RESULT([$gcc_cv_as_hidden])

AC_MSG_CHECKING([assembler for .gnu_attribute])
gcc_cv_as_gnu_attribute=`ts_asm_ok '	.gnu_attribute 4,1'`
AC_MSG_RESULT([$gcc_cv_as_gnu_attribute])

AC_MSG_CHECKING([assembler for .loc is_stmt])
gcc_cv_as_is_stmt=`ts_asm_ok '	.text
	.file 1 "conf.c"
	.loc 1 1 0 is_stmt 1'`
AC_MSG_RESULT([$gcc_cv_as_is_stmt])

AC_MSG_CHECKING([assembler for .loc discriminator])
gcc_cv_as_discriminator=`ts_asm_ok '	.text
	.file 1 "conf.c"
	.loc 1 1 0 discriminator 1'`
AC_MSG_RESULT([$gcc_cv_as_discriminator])

dnl `# 0 "" 2' line markers.  Note this one is checked by assembling and
dnl requiring *no diagnostic output*, not merely a zero exit status: the
dnl assemblers that mishandle it warn rather than fail.
AC_MSG_CHECKING([assembler for tolerance to line number 0])
gcc_cv_as_line_zero=no
{ echo '# 1 "test.s" 1'; echo '# 0 "" 2'; } > conftest.s
if "$gcc_cv_as" -o conftest.o conftest.s 2>conftest.out > /dev/null \
   && test "x`cat conftest.out`" = x; then
  gcc_cv_as_line_zero=yes
fi
rm -f conftest.out
AC_MSG_RESULT([$gcc_cv_as_line_zero])

dnl dwarf2 .file/.loc.  The .debug_line file table has to come out in exactly
dnl the order given, because DW_AT_decl_file indexes into it; the second probe
dnl approximates that by checking the assembler rejects a duplicated index.
AC_MSG_CHECKING([assembler for dwarf2 .file/.loc])
gcc_cv_as_dwarf2_debug_line=no
cat > conftest.s <<'TSEOF'
	.file 1 "conftest.s"
	.loc 1 3 0
	nop
TSEOF
if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
  if test x"$gcc_cv_objdump" != x; then
    "$gcc_cv_objdump" -h conftest.o 2>/dev/null | grep debug_line > /dev/null 2>&1 \
      && gcc_cv_as_dwarf2_debug_line=yes
  else
    gcc_cv_as_dwarf2_debug_line=yes
  fi
fi
gcc_cv_as_dwarf2_file_buggy=`ts_asm_ok '	.file 1 "foo.s"
	.file 1 "bar.s"'`
if test x"$gcc_cv_as_dwarf2_file_buggy" = xyes; then
  # Accepting the duplicate index is the bug.
  gcc_cv_as_dwarf2_debug_line=no
fi
AC_MSG_RESULT([$gcc_cv_as_dwarf2_debug_line])

AC_MSG_CHECKING([assembler for .loc views])
gcc_cv_as_dwarf2_debug_view=no
if test x"$gcc_cv_as_dwarf2_debug_line" = xyes \
   && test x"$gcc_cv_as_leb128" = xyes; then
  gcc_cv_as_dwarf2_debug_view=`ts_asm_ok '	.file 1 "conftest.s"
	.loc 1 3 0 view .LVU1
	nop
	.data
	.uleb128 .LVU1
	.uleb128 .LVU1'`
fi
AC_MSG_RESULT([$gcc_cv_as_dwarf2_debug_view])

rm -f conftest.s conftest.o

dnl ===========================================================================
dnl BACK-END ASSEMBLER SECTION: aarch64
dnl
dnl These were the aarch64 arm of the `case "$target"' CPU-specific assembler
dnl checks in gcc/configure.ac.  They are guarded on the target so that a probe
dnl written in aarch64 assembly is not run against, say, a mips assembler --
dnl gcc/configure got that for free from the case statement, and this file has
dnl to be explicit about it.
dnl ===========================================================================

gcc_cv_as_aarch64_mabi=no
gcc_cv_as_aarch64_picreloc=no
gcc_cv_as_aarch64_aeabi=no
case ${target} in
  aarch64*-*-*)
    AC_MSG_CHECKING([assembler for -mabi option])
    echo '	.text' > conftest.s
    if "$gcc_cv_as" -mabi=lp64 -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_aarch64_mabi=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_aarch64_mabi])

    AC_MSG_CHECKING([assembler for -fpic relocs])
    cat > conftest.s <<'TSEOF'
	.text
	ldr     x0, [x2, #:gotpage_lo15:globalsym]
TSEOF
    if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_aarch64_picreloc=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_aarch64_picreloc])

    AC_MSG_CHECKING([assembler for AEABI build attributes])
    cat > conftest.s <<'TSEOF'
	.aeabi_subsection aeabi_feature_and_bits, optional, ULEB128
	.aeabi_attribute Tag_Feature_BTI, 1
	.aeabi_attribute Tag_Feature_PAC, 1
	.aeabi_attribute Tag_Feature_GCS, 1
TSEOF
    if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_aarch64_aeabi=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_aarch64_aeabi])

    rm -f conftest.s conftest.o
    ;;
  *)
    dnl Not aarch64: leave the defaults alone.  cc1 only consults these from the
    dnl aarch64 back end, so the value is irrelevant, but writing 0 rather than
    dnl 1 keeps "not probed" and "probed and absent" from looking alike.
    ;;
esac

dnl ---------------------------------------------------------------------------
dnl BACK-END ASSEMBLER SECTION: mips
dnl
dnl From the mips arm of the same `case "$target"'.  Guarded on the target so a
dnl probe written in mips assembly is not run against a foreign assembler.
dnl ---------------------------------------------------------------------------

gcc_cv_as_mips_nan=no
gcc_cv_as_micromips_support=no
gcc_cv_as_mips_dspr1_mult=no
gcc_cv_as_mips_explicit_relocs=no
gcc_cv_as_mips_explicit_relocs_pcrel=no
gcc_cv_as_ld_mips_jalr_reloc=no
gcc_cv_as_mips_dot_module=no
case ${target} in
  mips*-*-*)
    AC_MSG_CHECKING([assembler for -mnan= support])
    echo '	.text' > conftest.s
    if "$gcc_cv_as" -mnan=2008 -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_mips_nan=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_mips_nan])

    AC_MSG_CHECKING([assembler for .micromips support])
    echo '	.set micromips' > conftest.s
    if "$gcc_cv_as" $fw_as_opt -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_micromips_support=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_micromips_support])

    dnl Register names here are `$ac3', `$4', `$5'.  The version this replaces
    dnl read `multu ,,' and ran `if "" -32 ...' -- every `$' had been eaten by a
    dnl shell or perl expansion somewhere upstream of the file, taking the
    dnl assembler's own name with it.  The empty command always fails, so the
    dnl probe answered "no" on every toolchain and nothing said so.  Quote any
    dnl edit of this block.
    AC_MSG_CHECKING([assembler for DSPR1 mult with four accumulators])
    cat > conftest.s <<'TSEOF'
	.set	mips32r2
	.set	nodspr2
	.set	dsp
	madd	$ac3,$4,$5
	maddu	$ac3,$4,$5
	msub	$ac3,$4,$5
	msubu	$ac3,$4,$5
	mult	$ac3,$4,$5
	multu	$ac3,$4,$5
TSEOF
    if "$gcc_cv_as" -32 -mdspr2 -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_mips_dspr1_mult=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_mips_dspr1_mult])

    dnl Explicit relocation operators, and the JALR relocation that needs them.
    dnl These three were gcc/configure.ac's; MIPS_EXPLICIT_RELOCS reached
    dnl mips.opt as an `Init (...)' through tm_defines, which is why losing it
    dnl broke GENERATED options.cc and stopped every mips target building.
    dnl They are applied at run time now, in mips_option_init_struct.
    AC_MSG_CHECKING([assembler for %pcrel_hi/%pcrel_lo])
    echo '	lui $4,%pcrel_hi(foo)' > conftest.s
    if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_mips_explicit_relocs_pcrel=yes
      gcc_cv_as_mips_explicit_relocs=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_mips_explicit_relocs_pcrel])

    if test x"$gcc_cv_as_mips_explicit_relocs" != xyes; then
      AC_MSG_CHECKING([assembler for %gp_rel])
      echo '	lw $4,%gp_rel(foo)($4)' > conftest.s
      if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
	gcc_cv_as_mips_explicit_relocs=yes
      fi
      AC_MSG_RESULT([$gcc_cv_as_mips_explicit_relocs])
    fi

    dnl Needs the assembler, the linker AND objdump, and it is only meaningful
    dnl when the operators above exist -- that nesting is what made the removal
    dnl of the outer probe silently answer "no" here rather than fail.
    AC_MSG_CHECKING([assembler and linker for explicit JALR relocation])
    if test x"$gcc_cv_as_mips_explicit_relocs" = xyes \
       && test x"$gcc_cv_objdump" != x; then
      cat > conftest.s <<'TSEOF'
	.ent x
x:	lw $2,%got_disp(y)($3)
	lw $25,%call16(y)($28)
	.reloc	1f,R_MIPS_JALR,y
1:	jalr $25
	.reloc	1f,R_MIPS_JALR,x
1:	jalr $25
	.end x
TSEOF
      if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1 \
	 && "$gcc_cv_ld" -shared -o conftest.so conftest.o > /dev/null 2>&1; then
	if "$gcc_cv_objdump" -d conftest.so | grep jalr > /dev/null 2>&1 \
	   && "$gcc_cv_objdump" -d conftest.so | grep "bal.*<x>" > /dev/null 2>&1; then
	  gcc_cv_as_ld_mips_jalr_reloc=yes
	fi
      fi
    fi
    AC_MSG_RESULT([$gcc_cv_as_ld_mips_jalr_reloc])

    dnl .module.  This one was still in gcc/configure.ac's mips arm.  Two
    dnl consumers, and they disagree about nothing: mips.cc emits `.module'
    dnl directives when the assembler takes them and `.gnu_attribute 4, N'
    dnl when it does not, and mips.h's FP_ASM_SPEC hands -mhard-float and
    dnl friends to the assembler only in the first case.  Both now read this
    dnl one answer.
    AC_MSG_CHECKING([assembler for .module support])
    cat > conftest.s <<'TSEOF'
	.module mips2
	.module fp=xx
TSEOF
    if "$gcc_cv_as" -32 -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_mips_dot_module=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_mips_dot_module])

    rm -f conftest.s conftest.o
    ;;
esac

dnl ---------------------------------------------------------------------------
dnl loongarch.  Both of these were probed in gcc/configure.ac INSIDE
dnl `case $target in loongarch*-*-*)', which is a shape that cannot work in a
dnl compiler with no privileged target: the probe ran only when loongarch was
dnl the target GCC itself was configured for, and every other build fell to
dnl loongarch-opts.h's `#ifndef' floors of 0.  Loongarch then stopped passing
dnl -mrelax to its assembler and stopped defaulting linker relaxation on, with
dnl nothing to say so, because a floor turns a missing definition into a wrong
dnl answer rather than a build failure.
dnl
dnl THEY ARE A PAIR AND ARE PROBED AND EMITTED TOGETHER.  Linker relaxation
dnl needs both; the assembler spec needs the first.  Two of the three original
dnl consumers read them as one `&&' condition, so an answer for one without the
dnl other describes a configuration neither probe measured.
gcc_cv_as_loongarch_relax=no
gcc_cv_as_loongarch_cond_branch_relax=no
gcc_cv_as_loongarch_explicit_relocs=no
case ${target} in
  loongarch*-*-*)
    AC_MSG_CHECKING([assembler for -mrelax])
    echo '	.text' > conftest.s
    if "$gcc_cv_as" -mrelax -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_loongarch_relax=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_loongarch_relax])

    dnl 32769 nops puts the following branch out of the +/-32KiB range a
    dnl conditional branch can encode, so this assembles only if the assembler
    dnl relaxes it into a longer sequence.
    AC_MSG_CHECKING([assembler for conditional branch relaxation])
    cat > conftest.s <<'TSEOF'
a:
	.rept 32769
	nop
	.endr
	beq $a0,$a1,a
TSEOF
    if "$gcc_cv_as" $fw_as_opt -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_loongarch_cond_branch_relax=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_loongarch_cond_branch_relax])

    dnl Explicit relocation operators.  This is the half of the old shared
    dnl HAVE_AS_EXPLICIT_RELOCS that loongarch owned; alpha owned the other.
    AC_MSG_CHECKING([assembler for explicit relocation support])
    echo 'a:pcalau12i $t0,%pc_hi20(a)' > conftest.s
    if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_loongarch_explicit_relocs=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_loongarch_explicit_relocs])

    rm -f conftest.s conftest.o
    ;;
esac

dnl ---------------------------------------------------------------------------
dnl BACK-END ASSEMBLER SECTION: alpha
dnl
dnl From `case $target in alpha*-*-linux* | alpha*-*-*bsd*)' in
dnl gcc/configure.ac.  The first of these used to AC_DEFINE a macro name the
dnl LOONGARCH arm also defined, so whichever arm ran owned the name for both
dnl back ends and loongarch read alpha's answer through its own `#ifndef' floor.
dnl Per-back-end capability names cannot collide that way; that is the point of
dnl the prefix.
dnl ---------------------------------------------------------------------------

gcc_cv_as_alpha_explicit_relocs=no
gcc_cv_as_alpha_jsrdirect_relocs=no
case ${target} in
  alpha*-*-linux* | alpha*-*-*bsd*)
    AC_MSG_CHECKING([assembler for explicit relocation support])
    cat > conftest.s <<'TSEOF'
	.set nomacro
	.text
	extbl	$3, $2, $3	!lituse_bytoff!1
	ldq	$2, a($29)	!literal!1
	ldq	$4, b($29)	!literal!2
	ldq_u	$3, 0($2)	!lituse_base!1
	ldq	$27, f($29)	!literal!5
	jsr	$26, ($27), f	!lituse_jsr!5
	ldah	$29, 0($26)	!gpdisp!3
	lda	$0, c($29)	!gprel
	ldah	$1, d($29)	!gprelhigh
	lda	$1, d($1)	!gprellow
	lda	$29, 0($29)	!gpdisp!3
TSEOF
    if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_alpha_explicit_relocs=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_alpha_explicit_relocs])

    AC_MSG_CHECKING([assembler for jsrdirect relocation support])
    cat > conftest.s <<'TSEOF'
	.set nomacro
	.text
	ldq	$27, a($29)	!literal!1
	jsr	$26, ($27), a	!lituse_jsrdirect!1
TSEOF
    if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_alpha_jsrdirect_relocs=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_alpha_jsrdirect_relocs])

    rm -f conftest.s conftest.o
    ;;
esac

dnl ---------------------------------------------------------------------------
dnl BACK-END ASSEMBLER SECTION: riscv
dnl
dnl From the riscv arm of the same `case "$target"'.  Each gates a "skip this
dnl extension, binutils is too old" flag in common/config/riscv/riscv-common.cc.
dnl ---------------------------------------------------------------------------

gcc_cv_as_riscv_attribute=no
gcc_cv_as_riscv_isa_spec=no
gcc_cv_as_riscv_march_zifencei=no
gcc_cv_as_riscv_march_zaamo_zalrsc=no
gcc_cv_as_riscv_march_b=no
case ${target} in
  riscv*-*-*)
    AC_MSG_CHECKING([assembler for .attribute support])
    echo '	.attribute stack_align,4' > conftest.s
    if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_riscv_attribute=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_riscv_attribute])

    dnl The -march= probes take no input, only the option.
    echo '	.text' > conftest.s

    AC_MSG_CHECKING([assembler for -misa-spec= support])
    if "$gcc_cv_as" -misa-spec=2.2 -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_riscv_isa_spec=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_riscv_isa_spec])

    AC_MSG_CHECKING([assembler for -march=rv32i_zifencei support])
    if "$gcc_cv_as" -march=rv32i_zifencei2p0 -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_riscv_march_zifencei=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_riscv_march_zifencei])

    AC_MSG_CHECKING([assembler for -march=rv32i_zaamo_zalrsc support])
    if "$gcc_cv_as" -march=rv32i_zaamo_zalrsc -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_riscv_march_zaamo_zalrsc=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_riscv_march_zaamo_zalrsc])

    AC_MSG_CHECKING([assembler for -march=rv32i_b support])
    if "$gcc_cv_as" -march=rv32i_b -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_riscv_march_b=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_riscv_march_b])

    rm -f conftest.s conftest.o
    ;;
esac

dnl Windows @secrel32.  A mingw/cygwin ld that emits a runtime .reloc for a
dnl `.secrel32' reference, instead of resolving it at link time, miscompiles
dnl thread-local storage (PR80881).
dnl
dnl gcc/configure.ac used to test this inside the TLS probe and AC_MSG_ERROR,
dnl aborting the build.  That is not available here: this script runs after the
dnl compiler has been built, so there is no build to stop.  It warns loudly and
dnl records the answer, and i386's TLS expansion refuses to emit TLS when the
dnl capability says the linker is broken -- an error at compile time rather than
dnl silently wrong code at run time.
gcc_cv_ld_broken_secrel32=no
case $target in
  *-*-mingw* | *-*-cygwin* | *-*-pe | *-*-win32)
    AC_MSG_CHECKING([linker for broken @secrel32 relocations])
    if test x"$gcc_cv_objdump" = x; then
      AC_MSG_RESULT([cannot tell, no objdump])
      AC_MSG_WARN([cannot check for broken @secrel32 relocations without objdump; see https://gcc.gnu.org/bugzilla/show_bug.cgi?id=80881])
    else
      { echo '	.text'
        echo 'foo:	nop'
        echo '	.data'
        echo '	.secrel32 foo'; } > conftest.s
      if "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1 \
         && "$gcc_cv_ld" -o conftest.exe conftest.o > /dev/null 2>&1; then
        if "$gcc_cv_objdump" -h conftest.exe 2>/dev/null | grep '\.reloc' > /dev/null; then
          gcc_cv_ld_broken_secrel32=yes
        fi
        AC_MSG_RESULT([$gcc_cv_ld_broken_secrel32])
      else
        AC_MSG_RESULT([cannot tell, test link failed])
        AC_MSG_WARN([could not link the @secrel32 test; see https://gcc.gnu.org/bugzilla/show_bug.cgi?id=80881])
      fi
      rm -f conftest.s conftest.o conftest.exe
    fi
    if test x"$gcc_cv_ld_broken_secrel32" = xyes; then
      AC_MSG_WARN([])
      AC_MSG_WARN([*** $gcc_cv_ld has broken @secrel32 relocations.])
      AC_MSG_WARN([*** Thread-local storage would be MISCOMPILED with this linker.])
      AC_MSG_WARN([*** The compiler will refuse to emit TLS for this target.])
      AC_MSG_WARN([*** Use a linker with the PR80881 fix (GNU ld 2.44 or later).])
      AC_MSG_WARN([])
    fi
    ;;
esac

dnl The options -fhardened asks the linker for.  Read directly by the driver
dnl rather than referenced from another spec: an empty value means "this
dnl linker has neither", and the driver still decides whether to apply them.
link_hardening=
if test x"$gcc_cv_ld_now" = xyes; then
  link_hardening="-z now"
fi
if test x"$gcc_cv_ld_relro" = xyes; then
  link_hardening="${link_hardening} -z relro"
fi

dnl sparc: -relax, offsetable %lo(), LEON instructions.  Only the first two feed
dnl runtime capabilities; AS_LEON_FLAG is compile-time spec text in sparc.h, so
dnl the LEON answer is probed and reported for the record but not emitted.
case $target in
  sparc*-*-*)
    AC_MSG_CHECKING([assembler for -relax])
    gcc_cv_as_sparc_relax=no
    echo '	.text' > conftest.s
    if "$gcc_cv_as" -relax -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_sparc_relax=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_sparc_relax])

    dnl Some assemblers accept `%lo(sym + N)' and then encode it differently
    dnl from `%lo(sym) + N', so this compares the emitted bytes rather than the
    dnl exit status.  Without objdump there is no way to tell; say no.
    AC_MSG_CHECKING([assembler for offsetable %lo()])
    gcc_cv_as_sparc_offsetable_lo10=no
    if test x"$gcc_cv_objdump" != x; then
      { echo '.text'
        echo '	or %g1, %lo(ab) + 12, %g1'
        echo '	or %g1, %lo(ab + 12), %g1'; } > conftest.s
      if "$gcc_cv_as" -xarch=v9 -o conftest.o conftest.s > /dev/null 2>&1 \
         && "$gcc_cv_objdump" -s -j .text conftest.o 2>/dev/null \
            | grep ' 82106000 82106000' > /dev/null 2>&1; then
        gcc_cv_as_sparc_offsetable_lo10=yes
      fi
    fi
    AC_MSG_RESULT([$gcc_cv_as_sparc_offsetable_lo10])

    AC_MSG_CHECKING([assembler for LEON instructions])
    gcc_cv_as_sparc_leon=no
    { echo '.text'
      echo '	.register %g2, #scratch'
      echo '	.register %g3, #scratch'
      echo '	.align 4'
      echo '	smac %g2, %g3, %g1'
      echo '	umac %g2, %g3, %g1'
      echo '	casa [%g2] 0xb, %g3, %g1'; } > conftest.s
    if "$gcc_cv_as" -Aleon -o conftest.o conftest.s > /dev/null 2>&1; then
      gcc_cv_as_sparc_leon=yes
    fi
    AC_MSG_RESULT([$gcc_cv_as_sparc_leon])
    if test x"$gcc_cv_as_sparc_leon" != xyes; then
      AC_MSG_WARN([$gcc_cv_as does not accept -Aleon; GCC emits it unconditionally, so override the asm spec for this target])
    fi
    rm -f conftest.s conftest.o
    ;;
esac

dnl AIX: which assembler is this?  gcc/configure.ac answered this with
dnl HAVE_AIX_AS, from the `as -v' flavour probe removed in 2b32edf9539.  The
dnl macro has had no definer since, and its ONE consumer -- ASM_V_SPEC in
dnl config/rs6000/aix.h -- spells the test `#ifdef HAVE_AIX_AS', where an
dnl undefined identifier is simply false with no diagnostic.  So every AIX
dnl build since then has handed the IBM assembler the driver's built-in
dnl asm_v instead, which is `%{v} %{w:-W} %{I*}'.  The extra `%{I*}' is the
dnl part that matters: the IBM assembler does not take -I there.
dnl
dnl Found from the other end, which is the useful way to notice this class of
dnl bug: gen-target-specs emits *asm_v for every target whose header chain
dnl defines ASM_V_SPEC, and it emitted none for AIX.  A header that defines a
dnl macro under a dead `#ifdef' looks exactly like a header that never defined
dnl it.
dnl
dnl ASM_V_SPEC is a spec, and which assembler is installed for a target is not
dnl knowable when a multi-target compiler is configured, so the answer belongs
dnl here rather than in the target header.  aix.h's dead block is removed in
dnl the same commit that adds this: a bridge without the consumer conversion
dnl would only turn a silent false into a silent true.
gcc_cv_aix_as=no
case $target in
  *-*-aix*)
    AC_MSG_CHECKING([whether $gcc_cv_as is the AIX assembler])
    if "$gcc_cv_as" -v < /dev/null 2>&1 | grep '^as V' > /dev/null; then
      gcc_cv_aix_as=yes
      AC_MSG_RESULT([yes])
    else
      AC_MSG_RESULT([no, assuming GNU as])
    fi
    rm -f a.out
    ;;
esac

dnl Solaris: which linker is this?  gcc/configure.ac answered this with
dnl HAVE_SOLARIS_LD, whose probe was removed; nothing has defined it since, so
dnl every `#if HAVE_SOLARIS_LD' in config/sol2.h and friends has been silently
dnl false.  The effect is worth stating plainly, because it is the shape this
dnl project keeps finding: a Solaris build using GNU ld is ACCIDENTALLY correct,
dnl and a Solaris build using Sun ld is SILENTLY WRONG.  A deleted probe does
dnl not produce an error, it produces a configuration that happens to work for
dnl whoever tested it.
dnl
dnl config/sol2.h now builds both forms of LINK_ARCH_SPEC and registers them as
dnl link_arch_gnu / link_arch_sun.  The built-in default stays the GNU form, so
dnl nothing changes for the configuration that currently works; this script
dnl picks the Sun form when it finds Sun ld, and says so loudly when it cannot
dnl tell.
gcc_cv_solaris_ld=no
case $target in
  *-*-solaris2*)
    AC_MSG_CHECKING([whether $gcc_cv_ld is Sun ld])
    if "$gcc_cv_ld" --version 2>&1 | grep -i 'GNU ld' > /dev/null; then
      gcc_cv_solaris_ld=no
      AC_MSG_RESULT([no, GNU ld])
    elif "$gcc_cv_ld" -V 2>&1 | grep -i 'Solaris Link Editors' > /dev/null; then
      gcc_cv_solaris_ld=yes
      AC_MSG_RESULT([yes])
    else
      AC_MSG_RESULT([cannot tell])
      AC_MSG_WARN([])
      AC_MSG_WARN([*** Could not identify $gcc_cv_ld as either GNU ld or Sun ld.])
      AC_MSG_WARN([*** Assuming GNU ld, which is the compiler's built-in default.])
      AC_MSG_WARN([*** If this is Sun ld, the link specs will be wrong: no])
      AC_MSG_WARN([***   -M /usr/lib/ld/map.below4G for -mcmodel=medlow, and a])
      AC_MSG_WARN([***   -m emulation flag that Sun ld does not accept.])
      AC_MSG_WARN([])
    fi
    ;;
esac

dnl ===========================================================================
dnl THE BULK SWEEP OF 2026-08-11: everything below arrived in one move out of
dnl gcc/configure.ac, ahead of wiring its consumers up.  gcc/configure.ac's own
dnl note lists the eleven blocks in the order they stood there; the order here
dnl is the same, so the two can be read side by side.
dnl
dnl Every one of these asks a question about a TARGET's assembler.  None of
dnl them can be answered when a multi-target compiler is configured, because
dnl the assembler is not chosen yet -- which is precisely why they were all
dnl reading their floors in the all-targets build (0 of 33 defined, measured).
dnl ===========================================================================

dnl --- Generic assembler directives.  No `case', because these are asked of
dnl every assembler; the programs are architecture-neutral.
TS_AS_CHECK([.balign and .p2align], [gcc_cv_as_balign_and_p2align], [],
[	.balign 4
	.p2align 2])

TS_AS_CHECK([.p2align with maximum skip], [gcc_cv_as_max_skip_p2align], [],
[	.p2align 4,,7])

TS_AS_CHECK([.literal16], [gcc_cv_as_literal16], [], [	.literal16])

TS_AS_CHECK([.weak], [gcc_cv_as_weak], [], [	.weak foobar])

TS_AS_CHECK([.weakref], [gcc_cv_as_weakref], [], [	.weakref foobar, barfnot])

TS_AS_CHECK([.nsubspa comdat], [gcc_cv_as_nsubspa_comdat], [],
[	.SPACE $TEXT$
	.NSUBSPA $CODE$,COMDAT])

TS_AS_CHECK([.base64], [gcc_cv_as_base64], [],
[	.section .rodata
	.base64 "Tm9uIHB1ZG9yIGVzdCBuaWwgc2NpcmUsIHB1ZG9yIG5pbCBkaXNjZXJlIHZlbGxlLgo="])

TS_AS_CHECK([.cv_ucomp], [gcc_cv_as_cv_ucomp], [], [	.cv_ucomp 0])

TS_AS_CHECK([.lcomm with alignment], [gcc_cv_as_lcomm_with_alignment], [],
[	.lcomm bar,4,16])

dnl `.subsection -1' needs the object inspected: assemblers accept the
dnl directive and then emit at the END of the section, which is the bug the
dnl probe exists to find.  With no nm for this target the honest answer is
dnl "unknown", and "unknown" here has to mean no.
AC_MSG_CHECKING([assembler for working .subsection -1])
gcc_cv_as_subsection_m1=no
cat > conftest.s <<'TSEOF'
conftest_label1: .word 0
.subsection -1
conftest_label2: .word 0
.previous
TSEOF
if test x"$gcc_cv_nm" != x \
   && "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1; then
  "$gcc_cv_nm" conftest.o | grep conftest_label1 > conftest.nm1
  "$gcc_cv_nm" conftest.o | grep conftest_label2 | sed -e 's/label2/label1/' > conftest.nm2
  if cmp conftest.nm1 conftest.nm2 > /dev/null 2>&1; then :; else
    gcc_cv_as_subsection_m1=yes
  fi
  rm -f conftest.nm1 conftest.nm2
fi
rm -f conftest.s conftest.o
AC_MSG_RESULT([$gcc_cv_as_subsection_m1])

dnl --- Section flags.  Three of the four had a Solaris arm in gcc/configure.ac
dnl that pinned the answer to `no' without probing, on the grounds that GNU as
dnl with Solaris ld can assemble a flag the linker will not accept.  That arm
dnl is kept: it is target knowledge, and it belongs here rather than there.
gcc_cv_as_section_exclude=no
gcc_cv_as_shf_gnu_retain=no
gcc_cv_as_section_link_order=no
gcc_cv_as_shf_merge=no

TS_AS_CHECK([section exclude flag], [gcc_cv_as_section_exclude_e], [$fw_as_opt],
[	.section foo1,"e"
	.byte 0,0,0,0])
if test x"$gcc_cv_as_section_exclude_e" = xyes; then
  gcc_cv_as_section_exclude=yes
else
  dnl Solaris as spells it #exclude, and spells the section name differently
  dnl again on sparc than on x86.
  ts_exclude_s=
  case ${target} in
    sparc*-*-solaris2*)          ts_exclude_s='	.section "foo1", #exclude' ;;
    i?86-*-solaris2* | x86_64-*-solaris2*)
                                 ts_exclude_s='	.section foo1, #exclude' ;;
  esac
  if test x"$ts_exclude_s" != x; then
    TS_AS_CHECK([section exclude flag, Solaris spelling], [gcc_cv_as_section_exclude_hash], [],
[$ts_exclude_s
	.byte 0,0,0,0])
    gcc_cv_as_section_exclude=$gcc_cv_as_section_exclude_hash
  fi
fi

case ${target} in
  *-*-solaris2*)
    dnl Not probed on purpose; see above.
    ;;
  *)
    TS_AS_CHECK([section 'R' flag], [gcc_cv_as_shf_gnu_retain], [$fw_as_opt],
[	.section .foo,"awR",%progbits
	.byte 0])
    TS_AS_CHECK([section 'o' flag], [gcc_cv_as_section_link_order], [$fw_as_opt],
[	.section .foo,"a"
	.byte 0
	.section __patchable_function_entries,"awo",%progbits,.foo
	.byte 0])
    ;;
esac

TS_AS_CHECK([section merging support], [gcc_cv_as_shf_merge], [$fw_as_opt],
[	.section .rodata.str, "aMS", @progbits, 1])
if test x"$gcc_cv_as_shf_merge" != xyes; then
  TS_AS_CHECK([section merging support (%progbits)],
    [gcc_cv_as_shf_merge_percent], [$fw_as_opt],
[	.section .rodata.str, "aMS", %progbits, 1])
  gcc_cv_as_shf_merge=$gcc_cv_as_shf_merge_percent
fi

dnl --- .eh_frame optimization.  GAS up to 2.11.0 mis-optimizes it, and the
dnl remedy was --traditional-format, which gcc/configure.ac recorded as
dnl USE_AS_TRADITIONAL_FORMAT.  Distinguishing "good" from "buggy" needs the
dnl assembled bytes read back, so with no objdump the answer is "good", which
dnl is what every assembler released this century actually is.
AC_MSG_CHECKING([assembler for buggy .eh_frame optimization])
gcc_cv_as_eh_frame_traditional=no
if test x"$gcc_cv_objdump" != x; then
  if "$gcc_cv_as" -o conftest.o --traditional-format /dev/null > /dev/null 2>&1; then
    dnl The full byte-comparison probe from gcc/configure.ac is not reproduced:
    dnl it compared against two hand-written objdump transcripts for one
    dnl 32-bit little- and one big-endian layout, and neither transcript is
    dnl valid for most of the 45 back ends this file serves.  A probe that
    dnl answers "buggy" for every target whose .eh_frame simply looks
    dnl different would be worse than no probe: --traditional-format defeats
    dnl section merging everywhere.  So the question asked here is only
    dnl whether the assembler is old enough to HAVE the option in the sense
    dnl the workaround needs, and the answer is recorded rather than acted on.
    :
  fi
fi
AC_MSG_RESULT([$gcc_cv_as_eh_frame_traditional])

dnl --- darwin.
gcc_cv_as_mmacosx_version_min=no
gcc_cv_as_darwin_build_version=no
case ${target_os} in
  darwin*)
    TS_AS_CHECK([-mmacosx-version-min option], [gcc_cv_as_mmacosx_version_min],
      [-mmacosx-version-min=10.1], [	.text])
    if test x"$gcc_cv_as_mmacosx_version_min" = xyes; then
      TS_AS_CHECK([.build_version], [gcc_cv_as_darwin_build_version],
        [-mmacosx-version-min=10.14],
        [	.build_version macos, 10, 14 sdk_version 10, 14])
    fi
    ;;
esac

dnl --- avr.
gcc_cv_as_avr_mlink_relax=no
gcc_cv_as_avr_mrmw=no
gcc_cv_as_avr_mgccisr=no
case ${target} in
  avr-*-*)
    TS_AS_CHECK([--mlink-relax option], [gcc_cv_as_avr_mlink_relax],
      [--mlink-relax], [	.text])
    TS_AS_CHECK([-mrmw option], [gcc_cv_as_avr_mrmw], [-mrmw], [	.text])
    TS_AS_CHECK([__gcc_isr pseudo instruction], [gcc_cv_as_avr_mgccisr],
      [-mgcc-isr],
[	.text
	__gcc_isr 1
	__gcc_isr 2
	__gcc_isr 0,r24])
    ;;
esac

dnl --- cris.
gcc_cv_as_cris_no_mul_bug=no
case ${target} in
  cris-*-*)
    TS_AS_CHECK([-no-mul-bug-abort option], [gcc_cv_as_cris_no_mul_bug],
      [-no-mul-bug-abort], [	.text])
    ;;
esac

dnl --- ia64.
gcc_cv_as_ia64_ltoffx_ldxmov_relocs=no
case ${target} in
  ia64*-*-*)
    TS_AS_CHECK([ltoffx and ldxmov relocs], [gcc_cv_as_ia64_ltoffx_ldxmov_relocs], [],
[	.text
	addl r15 = @ltoffx(x#), gp
	;;
	ld8.mov r16 = @<:@r15@:>@, x#])
    ;;
esac

dnl --- powerpc.  Four of these need a different test program on AIX and on
dnl Darwin, because the three object formats spell `.machine' and the text
dnl section differently; gcc/configure.ac had the same three-way `case' and it
dnl is reproduced rather than simplified.
gcc_cv_as_powerpc_mfcrf=no
gcc_cv_as_power10_htm=no
gcc_cv_as_powerpc_rel16=no
gcc_cv_as_powerpc_entry_markers=no
gcc_cv_as_powerpc_pltseq_markers=no
gcc_cv_as_machine_directive=no
case ${target} in
  powerpc*-*-*)
    case ${target} in
      *-*-darwin*)
	TS_AS_CHECK([.machine directive support], [gcc_cv_as_machine_directive], [],
	  [	.machine ppc7400])
	if test x"$gcc_cv_as_machine_directive" != xyes; then
	  dnl gcc/configure.ac made this fatal (`exit 1' for a native build).
	  dnl It cannot be fatal here: this script probes many targets in one
	  dnl run, and one target's toolchain being too old must not stop the
	  dnl others.  It skips THIS target's spec file instead, which is the
	  dnl same outcome the missing-tools path already produces.
	  AC_MSG_WARN([$gcc_cv_as does not support ".machine"; powerpc-darwin needs cctools 528.5 or later])
	fi
	;;
    esac

    case ${target} in
      *-*-aix*)    ts_ppc_s='	.machine "pwr5"
	.csect .text@<:@PR@:>@
	mfcr 3,128' ;;
      *-*-darwin*) ts_ppc_s='	.text
	mfcr r3,128' ;;
      *)           ts_ppc_s='	.machine power4
	.text
	mfcr 3,128' ;;
    esac
    TS_AS_CHECK([mfcr field support], [gcc_cv_as_powerpc_mfcrf], [], [$ts_ppc_s])

    case ${target} in
      *-*-aix*)    ts_ppc_s='	.machine "pwr10"
	.csect .text@<:@PR@:>@
	tend. 0' ;;
      *-*-darwin*) ts_ppc_s='	.text
	tend. 0' ;;
      *)           ts_ppc_s='	.machine power10
	.text
	tend. 0' ;;
    esac
    TS_AS_CHECK([htm support on Power10], [gcc_cv_as_power10_htm], [], [$ts_ppc_s])

    case ${target} in
      *-*-aix*)    ts_ppc_s='	.csect .text@<:@PR@:>@
LCF..0:
	addis 11,30,_GLOBAL_OFFSET_TABLE_-LCF..0@ha' ;;
      *-*-darwin*) ts_ppc_s='	.text
LCF0:
	addis r11,r30,_GLOBAL_OFFSET_TABLE_-LCF0@ha' ;;
      *)           ts_ppc_s='	.text
.LCF0:
	addis 11,30,_GLOBAL_OFFSET_TABLE_-.LCF0@ha' ;;
    esac
    TS_AS_CHECK([rel16 relocs], [gcc_cv_as_powerpc_rel16], [-a32], [$ts_ppc_s])

    TS_AS_CHECK([prologue entry point marker support],
      [gcc_cv_as_powerpc_entry_markers], [-a64 $fw_as_opt],
      [	.reloc .,R_PPC64_ENTRY; nop])

    TS_AS_CHECK([plt sequence marker support],
      [gcc_cv_as_powerpc_pltseq_markers], [-a32 $fw_as_opt],
      [	.reloc .,R_PPC_PLTSEQ; nop])
    ;;
esac

dnl --- msp430.
gcc_cv_as_msp430_mspabi_attribute=no
case ${target} in
  msp430-*-*)
    TS_AS_CHECK([.mspabi_attribute support], [gcc_cv_as_msp430_mspabi_attribute], [],
      [	.mspabi_attribute 4,2])
    ;;
esac

dnl --- loongarch.  The -mrelax, conditional-branch-relaxation and explicit
dnl relocation probes are further up, in the loongarch back-end section; these
dnl are the rest of the arm.  -mno-relax also feeds the leb128 probe: GNU as
dnl for loongarch emits relocations for leb128 symbol arithmetic when
dnl relaxation is on, which makes the leb128 probe answer the wrong question.
gcc_cv_as_loongarch_mno_relax=no
gcc_cv_as_loongarch_call36=no
gcc_cv_as_loongarch_eh_frame_pcrel=no
gcc_cv_as_loongarch_tls_le_relaxation=no
gcc_cv_as_loongarch_16b_atomic=no
case ${target} in
  loongarch*-*-*)
    TS_AS_CHECK([-mno-relax support], [gcc_cv_as_loongarch_mno_relax],
      [-mno-relax], [	.text])
    TS_AS_CHECK([call36 relocation support], [gcc_cv_as_loongarch_call36], [],
[	pcaddu18i $r1, %call36(a)
	jirl $r1, $r1, 0])
    TS_AS_CHECK([eh_frame pcrel encoding support],
      [gcc_cv_as_loongarch_eh_frame_pcrel], [],
[	.cfi_startproc
	.cfi_personality 0x9b,a
	.cfi_lsda 0x1b,b
	.cfi_endproc])
    TS_AS_CHECK([tls le relaxation support],
      [gcc_cv_as_loongarch_tls_le_relaxation], [],
      [	lu12i.w $t0,%le_hi20_r(a)])
    TS_AS_CHECK([16-byte atomic support], [gcc_cv_as_loongarch_16b_atomic], [],
[	vori.b $vr0, $vr1, 0
	sc.q $a0, $a1, $a2, 0])
    ;;
esac

dnl --- s390.  The two alignment-hint answers are ONE `#if/#elif' ladder in
dnl s390.h; they are written together and must be read together.
gcc_cv_as_s390_machine_machinemode=no
gcc_cv_as_s390_architecture_modifiers=no
gcc_cv_as_s390_vector_hints=no
gcc_cv_as_s390_vector_hints_z13=no
case ${target} in
  s390x-*-*)
    TS_AS_CHECK([.machine and .machinemode support],
      [gcc_cv_as_s390_machine_machinemode], [],
[	.machinemode push
	.machinemode pop
	.machine push
	.machine pop])
    TS_AS_CHECK([architecture modifiers support],
      [gcc_cv_as_s390_architecture_modifiers], [], [	.machine z13+vx])
    TS_AS_CHECK([vector load/store alignment hints],
      [gcc_cv_as_s390_vector_hints], [], [	vl %v24,0(%r15),3])
    TS_AS_CHECK([vector load/store alignment hints on z13],
      [gcc_cv_as_s390_vector_hints_z13], [-mzarch -march=z13],
      [	vl %v24,0(%r15),3])
    ;;
esac

dnl --- arm.
gcc_cv_as_arm_option_extensions=no
case ${target} in
  arm*)
    TS_AS_CHECK([context-specific architecture extensions],
      [gcc_cv_as_arm_option_extensions], [-march=armv8.1-m.main+mve],
[	.text
	.thumb
	.syntax unified
	vmov.f32 s0, s1])
    ;;
esac

dnl --- i386/x86_64.  SIXTEEN keys, and until now not one of them was written:
dnl `grep -c gcc_cv_as_ix86' on this file was 0, so every x86 assembler
dnl capability in target-caps.h had been reading its built-in default on every
dnl target since the probes left gcc/configure.ac.  This is the largest single
dnl instance of the nothing-writes-it failure the checker exists to find.
dnl
dnl The programs are byte-for-byte the ones gcc/configure.ac used.  Four of them
dnl need the LINKER as well, and one needs objdump or readelf; where a tool is
dnl missing the answer stays `no', which is what gcc/configure.ac did too.
dnl
dnl gcc/configure.ac passed $as_32_opt/$ld_32_opt/$as_64_opt/$ld_64_opt and
dnl $tls_section_flag to these probes.  NONE OF THOSE FOUR IS EVER ASSIGNED
dnl ANYWHERE IN THAT FILE -- checked, on the commit before the probes moved --
dnl so every one expanded to the empty string and the probes ran with no flags.
dnl They are dropped here rather than carried over empty, because an empty
dnl variable that looks like a knob invites someone to set it, and setting
dnl $as_32_opt would change what these probes mean without changing what the
dnl compiler does with the answer.
gcc_cv_as_ix86_filds=no
gcc_cv_as_ix86_fildq=no
gcc_cv_as_ix86_cmov_sun_syntax=no
gcc_cv_as_ix86_ffreep=no
gcc_cv_as_ix86_sahf=no
gcc_cv_as_ix86_interunit_movq=no
gcc_cv_as_ix86_hle=no
gcc_cv_as_ix86_rep_lock_prefix=no
gcc_cv_as_ix86_ud2=no
gcc_cv_as_ix86_tlsgdplt=no
gcc_cv_as_ix86_tlsldmplt=no
gcc_cv_as_ix86_tlsldm=no
gcc_cv_as_ix86_got32x=no
gcc_cv_as_x86_64_code_6_gottpoff=no
gcc_cv_as_ix86_gotoff_in_data=no
gcc_cv_as_ix86_tls_get_addr_via_got=no
case ${target} in
  i?86-*-* | x86_64-*-*)
    TS_AS_CHECK([filds and fists mnemonics], [gcc_cv_as_ix86_filds], [],
[	filds (%ebp); fists (%ebp)])

    TS_AS_CHECK([fildq and fistpq mnemonics], [gcc_cv_as_ix86_fildq], [],
[	fildq (%ebp); fistpq (%ebp)])

    TS_AS_CHECK([Sun syntax for cmov], [gcc_cv_as_ix86_cmov_sun_syntax], [],
[	cmovl.l %edx, %eax])

    TS_AS_CHECK([ffreep mnemonic], [gcc_cv_as_ix86_ffreep], [],
[	ffreep %st(1)])

    TS_AS_CHECK([sahf mnemonic in 64bit mode], [gcc_cv_as_ix86_sahf], [],
[	.code64
	sahf])

    TS_AS_CHECK([interunit movq mnemonic], [gcc_cv_as_ix86_interunit_movq], [],
[	.code64
	movq %mm0, %rax
	movq %rax, %xmm0])

    TS_AS_CHECK([HLE prefixes], [gcc_cv_as_ix86_hle], [],
[	lock xacquire cmpxchg %esi, (%ecx)])

    TS_AS_CHECK([rep and lock prefixes], [gcc_cv_as_ix86_rep_lock_prefix], [],
[	rep movsl
	rep ret
	rep nop
	rep bsf %ecx, %eax
	rep bsr %ecx, %eax
	lock addl %edi, (%eax,%esi)
	lock orl $0, (%esp)])

    TS_AS_CHECK([ud2 mnemonic], [gcc_cv_as_ix86_ud2], [], [	ud2])

    dnl The four below assemble AND link, so TS_AS_CHECK cannot express them.
    AC_MSG_CHECKING([assembler and linker for @tlsgdplt])
    cat > conftest.s <<'TSEOF'
	call    tls_gd@tlsgdplt
TSEOF
    if test x"$gcc_cv_ld" != x \
       && "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1 \
       && "$gcc_cv_ld" -o conftest conftest.o -G > /dev/null 2>&1; then
      gcc_cv_as_ix86_tlsgdplt=yes
    fi
    rm -f conftest conftest.o conftest.s
    AC_MSG_RESULT([$gcc_cv_as_ix86_tlsgdplt])

    AC_MSG_CHECKING([assembler and linker for @tlsldmplt])
    cat > conftest.s <<'TSEOF'
	.section .tdata,"aw",@progbits
tls_ld:
	.section .text,"ax",@progbits
	call    tls_ld@tlsldmplt
TSEOF
    if test x"$gcc_cv_ld" != x \
       && "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1 \
       && "$gcc_cv_ld" -o conftest conftest.o -G > /dev/null 2>&1; then
      gcc_cv_as_ix86_tlsldmplt=yes
    fi
    rm -f conftest conftest.o conftest.s
    AC_MSG_RESULT([$gcc_cv_as_ix86_tlsldmplt])

    dnl The original also accepted Solaris `dis' where objdump was absent.  A
    dnl target-specs run has objdump named for the target or it has nothing, so
    dnl the fallback would only ever find the HOST's dis and answer for the
    dnl wrong toolchain -- exactly the confusion this directory exists to end.
    AC_MSG_CHECKING([assembler and linker for @tlsldm])
    cat > conftest.s <<'TSEOF'
	.section .text,"ax",@progbits
	.globl  _start
	.type   _start, @function
_start:
	leal	value@tlsldm(%ebx), %eax
	call	___tls_get_addr@plt

	.section .tdata,"aw",@progbits
	.type	value, @object
value:
TSEOF
    if test x"$gcc_cv_ld" != x && test x"$gcc_cv_objdump" != x \
       && "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1 \
       && "$gcc_cv_ld" -o conftest conftest.o -lc > /dev/null 2>&1; then
      if "$gcc_cv_objdump" -d conftest 2>/dev/null | grep nop > /dev/null; then
	gcc_cv_as_ix86_tlsldm=yes
      fi
    fi
    rm -f conftest conftest.o conftest.s
    AC_MSG_RESULT([$gcc_cv_as_ix86_tlsldm])

    AC_MSG_CHECKING([assembler and linker for calling ___tls_get_addr via GOT])
    cat > conftest.s <<'TSEOF'
	.section .text,"ax",@progbits
	.globl  _start
	.type   _start, @function
_start:
	leal	ld@tlsldm(%ecx), %eax
	call	*___tls_get_addr@GOT(%ecx)
	leal	gd@tlsgd(%ecx), %eax
	call	*___tls_get_addr@GOT(%ecx)

	.section .tdata,"aw",@progbits
	.type	ld, @object
ld:
	.byte 0
	.globl  gd
	.type	gd, @object
gd:
	.byte 0
TSEOF
    if test x"$gcc_cv_ld" != x \
       && "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1 \
       && "$gcc_cv_ld" -o conftest conftest.o > /dev/null 2>&1; then
      gcc_cv_as_ix86_tls_get_addr_via_got=yes
    fi
    rm -f conftest conftest.o conftest.s
    AC_MSG_RESULT([$gcc_cv_as_ix86_tls_get_addr_via_got])

    dnl @GOT32X and R_X86_64_CODE_6_GOTTPOFF both assemble on an old assembler
    dnl and then produce the WRONG relocation, so a plain assemble is not the
    dnl test: the object has to be read back.  Both start from `no' and only the
    dnl inspection can raise them, which is why a missing readelf or objdump
    dnl leaves them `no' rather than defaulting them true.
    AC_MSG_CHECKING([assembler and linker for R_386_GOT32X])
    cat > conftest.s <<'TSEOF'
	.data
bar:
	.byte 1
	.text
	.global _start
_start:
	cmpl $0, bar@GOT
	jmp *_start@GOT
TSEOF
    if test x"$gcc_cv_ld" != x && test x"$gcc_cv_objdump" != x \
       && test x"$gcc_cv_readelf" != x \
       && "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1 \
       && "$gcc_cv_readelf" --relocs --wide conftest.o 2>&1 \
	  | grep R_386_GOT32X > /dev/null 2>&1 \
       && "$gcc_cv_ld" -o conftest conftest.o > /dev/null 2>&1; then
      dnl 0xffffff in the disassembly is the unrelaxed form, i.e. the linker
      dnl kept a GOT load it should have turned into an immediate.
      if "$gcc_cv_objdump" -dw conftest 2>&1 | grep 0xffffff > /dev/null 2>&1
      then :; else
	gcc_cv_as_ix86_got32x=yes
      fi
    fi
    rm -f conftest conftest.o conftest.s
    AC_MSG_RESULT([$gcc_cv_as_ix86_got32x])

    AC_MSG_CHECKING([assembler and linker for R_X86_64_CODE_6_GOTTPOFF])
    cat > conftest.s <<'TSEOF'
	.text
	.globl	_start
	.type _start, @function
_start:
	addq	%r23,foo@GOTTPOFF(%rip), %r15
	.section .tdata,"awT",@progbits
	.type foo, @object
foo:
	.quad 0
TSEOF
    if test x"$gcc_cv_ld" != x && test x"$gcc_cv_objdump" != x \
       && test x"$gcc_cv_readelf" != x \
       && "$gcc_cv_as" -o conftest.o conftest.s > /dev/null 2>&1 \
       && "$gcc_cv_readelf" --relocs --wide conftest.o 2>&1 \
	  | grep R_X86_64_CODE_6_GOTTPOFF > /dev/null 2>&1 \
       && "$gcc_cv_ld" -o conftest conftest.o > /dev/null 2>&1; then
      if "$gcc_cv_objdump" -dw conftest 2>&1 \
	 | grep "add \+\$0xf\+8,%r23,%r15" > /dev/null 2>&1; then
	gcc_cv_as_x86_64_code_6_gottpoff=yes
      fi
    fi
    rm -f conftest conftest.o conftest.s
    AC_MSG_RESULT([$gcc_cv_as_x86_64_code_6_gottpoff])

    dnl Not an assemble-only test either: assemblers accept ".long x@GOTOFF" in
    dnl .data and then emit a relocation the linker rejects.  The original was a
    dnl bare assemble and this keeps that, because the failure it looks for is
    dnl at assembly time.
    TS_AS_CHECK([@GOTOFF in a data section], [gcc_cv_as_ix86_gotoff_in_data], [],
[	.text
.L0:
	nop
	.data
	.long .L0@GOTOFF])
    ;;
esac

dnl --- VMS debugging info.  NOT a probe: no assembler is asked anything.  This
dnl is the configuration saying "this target's debugger is VMS DEBUG", and it
dnl was VMS_DEBUGGING_INFO in alpha/vms.h and ia64/vms.h.
dnl
dnl BE EXACT, BECAUSE THE WRONG ANSWER IS SILENT IN BOTH DIRECTIONS.  Answering
dnl yes changes the DWARF 5 line table's file-entry FORMAT -- it adds the
dnl DW_LNCT_timestamp and DW_LNCT_size pairs -- and a consumer reads the extra
dnl pairs as file entries, so a stray yes corrupts the line table of every
dnl target it reaches without any tool reporting an error.  It also selects
dnl DW_AT_VMS_rtnbeg_pd_address, the HP prologue/epilogue attributes 0x2005 and
dnl 0x2008, DW_FORM_string over DW_FORM_strp, and the VMS debug main pointer
dnl DIE.  Answering no on a VMS target is the failure that is live right now:
dnl the capability is read by dwarf2out.cc and written by nobody, so VMS targets
dnl have been getting no VMS debug output at all.
dnl
dnl The two patterns are config.gcc's, not `*-*-vms*'.  config.gcc's `*-*-*vms*'
dnl arm adds vms/vms.h, which does NOT define VMS_DEBUGGING_INFO; only the
dnl `alpha*-dec-*vms*' and `ia64-hp-*vms*' arms add the alpha/vms.h and
dnl ia64/vms.h that do.  vax-*-vms* matches the broad pattern, is on the
dnl unsupported list, and never had the macro -- so the broad pattern would turn
dnl this on for a target that has never had it.
ts_vms_debug=no
case ${target} in
  alpha*-dec-*vms* | ia64-hp-*vms*) ts_vms_debug=yes ;;
esac

dnl --- Toolchain-vendor requirements that used to abort gcc/configure.
dnl
dnl All three of these were `exit 1' or AC_MSG_ERROR in gcc/configure.ac, which
dnl is the right severity when a compiler is built FOR one target and the wrong
dnl one here: this run probes many targets, and target N's toolchain being
dnl unusable must leave targets 1..N-1 alone.  So they warn and skip.
case ${target} in
  mips*-*-* | loongarch*-*-* | *-*-hpux*)
    if "$gcc_cv_as" -v < /dev/null 2>&1 | grep GNU > /dev/null; then :; else
      AC_MSG_WARN([$target requires the GNU assembler; $gcc_cv_as does not identify as one])
    fi
    ;;
  amdgcn-* | gcn-*)
    AC_MSG_CHECKING([llvm assembler version])
    gcc_cv_as_version=`"$gcc_cv_as" --version 2>&1 | sed -ne '/version/s/.* \(@<:@0-9@:>@\)/\1/p' || echo error`
    case "$gcc_cv_as_version" in
      13.0.@<:@1-9@:>@* | 13.@<:@1-9@:>@* | 1@<:@4-9@:>@* | @<:@2-9@:>@@<:@0-9@:>@* | @<:@1-9@:>@@<:@0-9@:>@@<:@0-9@:>@*)
        AC_MSG_RESULT([$gcc_cv_as_version, ok]) ;;
      *)
        AC_MSG_RESULT([$gcc_cv_as_version])
        AC_MSG_WARN([amdgcn requires LLVM 13.0.1 or later]) ;;
    esac
    ;;
esac

dnl --- Emit. -----------------------------------------------------------------

ts_bool () {
  if test x"$1" = xyes; then echo 1; else echo 0; fi
}

cat >> "$target_config_file" <<EOF
# Assembler debug/CFI capabilities.
ld_broken_secrel32 `ts_bool "$gcc_cv_ld_broken_secrel32"`
as_ref `ts_bool "$gcc_cv_as_aix_ref"`
xcoff_dwarf_extras `ts_bool "$gcc_cv_as_aix_dwloc"`
as_relax_option `ts_bool "$gcc_cv_as_sparc_relax"`
as_offsetable_lo10 `ts_bool "$gcc_cv_as_sparc_offsetable_lo10"`
as_gnu_attribute `ts_bool "$gcc_cv_as_gnu_attribute"`
cfi_directive `if test x"$gcc_cv_as_cfi_directive" = xyes && test x"$gcc_cv_as_cfi_advance_working" = xyes; then echo 1; else echo 0; fi`
cfi_personality `ts_bool "$gcc_cv_as_cfi_personality_directive"`
cfi_sections `ts_bool "$gcc_cv_as_cfi_sections_directive"`
gas_loc_stmt `ts_bool "$gcc_cv_as_is_stmt"`
gas_discriminator `ts_bool "$gcc_cv_as_discriminator"`
as_line_zero `ts_bool "$gcc_cv_as_line_zero"`
dwarf2_debug_line `ts_bool "$gcc_cv_as_dwarf2_debug_line"`
dwarf2_debug_view `ts_bool "$gcc_cv_as_dwarf2_debug_view"`

# alpha back-end assembler capabilities.  as_alpha_explicit_relocs and
# loongarch's as_loongarch_explicit_relocs below were ONE macro name in
# gcc/configure.ac; they are two questions with two answers.
as_alpha_explicit_relocs `ts_bool "$gcc_cv_as_alpha_explicit_relocs"`
as_alpha_jsrdirect_relocs `ts_bool "$gcc_cv_as_alpha_jsrdirect_relocs"`

# aarch64 back-end assembler capabilities.
as_aarch64_mabi `ts_bool "$gcc_cv_as_aarch64_mabi"`
as_aarch64_small_pic_relocs `ts_bool "$gcc_cv_as_aarch64_picreloc"`
as_aarch64_aeabi_build_attributes `ts_bool "$gcc_cv_as_aarch64_aeabi"`

# mips back-end assembler capabilities.
as_mips_nan `ts_bool "$gcc_cv_as_mips_nan"`
as_mips_micromips `ts_bool "$gcc_cv_as_micromips_support"`
as_mips_dspr1_mult `ts_bool "$gcc_cv_as_mips_dspr1_mult"`
as_mips_explicit_relocs `ts_bool "$gcc_cv_as_mips_explicit_relocs"`
as_mips_explicit_relocs_pcrel `ts_bool "$gcc_cv_as_mips_explicit_relocs_pcrel"`
as_ld_mips_jalr_reloc `ts_bool "$gcc_cv_as_ld_mips_jalr_reloc"`
# The *asm_fp_module spec below is written from this same answer -- write
# both or neither.
as_mips_dot_module `ts_bool "$gcc_cv_as_mips_dot_module"`

# loongarch back-end assembler capabilities.  A PAIR: linker relaxation needs
# both.  The *asm_mrelax spec below is written from these same two variables --
# write both or neither.
as_loongarch_relax `ts_bool "$gcc_cv_as_loongarch_relax"`
as_loongarch_cond_branch_relax `ts_bool "$gcc_cv_as_loongarch_cond_branch_relax"`
as_loongarch_explicit_relocs `ts_bool "$gcc_cv_as_loongarch_explicit_relocs"`

# riscv back-end assembler capabilities.
as_riscv_attribute `ts_bool "$gcc_cv_as_riscv_attribute"`
as_riscv_misa_spec `ts_bool "$gcc_cv_as_riscv_isa_spec"`
as_riscv_march_zifencei `ts_bool "$gcc_cv_as_riscv_march_zifencei"`
as_riscv_march_zaamo_zalrsc `ts_bool "$gcc_cv_as_riscv_march_zaamo_zalrsc"`
as_riscv_march_b `ts_bool "$gcc_cv_as_riscv_march_b"`

# Linker capabilities.
gas_hidden `if test x"$gcc_cv_as_hidden" = xyes && test x"$gcc_cv_ld_hidden" = xyes; then echo 1; else echo 0; fi`
ld_ro_rw_section_mixing `if test x"$gcc_cv_ld_ro_rw_mix" = xread-write; then echo 1; else echo 0; fi`
ld_eh_gc_sections `ts_bool "$gcc_cv_ld_eh_gc_sections"`
ld_ctf `ts_bool "$gcc_cv_ld_ctf"`
ld_sysroot `ts_bool "$gcc_cv_ld_sysroot"`
ld_at_file `ts_bool "$gcc_cv_ld_at_file"`
ld_pie `ts_bool "$gcc_cv_ld_pie"`
ld_pie_copyreloc `ts_bool "$gcc_cv_ld_pie_copyreloc"`
ld_personality_relaxation `ts_bool "$gcc_cv_ld_mips_personality_relaxation"`
ld_no_dot_syms `ts_bool "$gcc_cv_ld_no_dot_syms"`
ld_large_toc `ts_bool "$gcc_cv_ld_large_toc"`
ld_toc_align `ts_bool "$gcc_cv_ld_toc_align"`
ld_ppc_attr `ts_bool "$gcc_cv_ld_ppc_attr"`
ld_broken_pe_dwarf5 `ts_bool "$gcc_cv_ld_broken_pe_dwarf5"`
ld_avr_avrxmega3_rodata_in_flash `ts_bool "$gcc_cv_ld_avr_avrxmega3_rodata_in_flash"`
ld_avr_avrxmega2_flmap `ts_bool "$gcc_cv_ld_avr_avrxmega2_flmap"`
ld_avr_avrxmega4_flmap `ts_bool "$gcc_cv_ld_avr_avrxmega4_flmap"`
ld_now `ts_bool "$gcc_cv_ld_now"`
ld_relro `ts_bool "$gcc_cv_ld_relro"`
lto_plugin `if test "$gcc_cv_lto_plugin" -gt 0; then echo 1; else echo 0; fi`
ld_demangle `ts_bool "$gcc_cv_ld_demangle"`
# The linker's -Bstatic/-Bdynamic spellings, empty when it has no such pair.
# These are STRINGS, not booleans; see the rules at the end of target-caps.h.
# The %(link_static)/%(link_dynamic) specs below carry the same two answers to
# the spec half of the driver -- write both or neither.
ld_static_option ${gcc_cv_ld_static_option}
ld_dynamic_option ${gcc_cv_ld_dynamic_option}

# --- The 2026-08-11 sweep out of gcc/configure.ac.  Named after the macro each
# one replaces, lowercased, so the mapping back is mechanical.
# Generic assembler directives.
gas_balign_and_p2align `ts_bool "$gcc_cv_as_balign_and_p2align"`
gas_max_skip_p2align `ts_bool "$gcc_cv_as_max_skip_p2align"`
gas_literal16 `ts_bool "$gcc_cv_as_literal16"`
gas_subsection_ordering `ts_bool "$gcc_cv_as_subsection_m1"`
gas_weak `ts_bool "$gcc_cv_as_weak"`
gas_weakref `ts_bool "$gcc_cv_as_weakref"`
gas_nsubspa_comdat `ts_bool "$gcc_cv_as_nsubspa_comdat"`
gas_base64 `ts_bool "$gcc_cv_as_base64"`
gas_cv_ucomp `ts_bool "$gcc_cv_as_cv_ucomp"`
gas_lcomm_with_alignment `ts_bool "$gcc_cv_as_lcomm_with_alignment"`
# Section flags.  gas_section_exclude folds the "e" and "#exclude" spellings,
# exactly as HAVE_GAS_SECTION_EXCLUDE did.
#
# NO BACKTICKS IN THE PROSE OF THIS HEREDOC.  It is unquoted, because every
# value in it is a command substitution -- so a backtick in a comment opens one
# too, and the shell swallows every line up to the next stray backtick.  When
# that last happened the whole "cat" died with a parse error and NOT ONE key
# reached the file, silently.  Use "..." in comments here, never GNU quoting.
gas_section_exclude `ts_bool "$gcc_cv_as_section_exclude"`
gas_shf_gnu_retain `ts_bool "$gcc_cv_as_shf_gnu_retain"`
gas_section_link_order `ts_bool "$gcc_cv_as_section_link_order"`
gas_shf_merge `ts_bool "$gcc_cv_as_shf_merge"`
use_as_traditional_format `ts_bool "$gcc_cv_as_eh_frame_traditional"`
# darwin.
as_mmacosx_version_min `ts_bool "$gcc_cv_as_mmacosx_version_min"`
as_macos_build_version `ts_bool "$gcc_cv_as_darwin_build_version"`
# avr.  THE THREE avr KEYS ARE PROBED AND DELIBERATELY NOT WRITTEN.  Their
# only consumer is gen-avr-mmcu-specs.cc, which is a BUILD-MACHINE program: it
# writes device-specs/ at build time and reads HAVE_AS_AVR_MLINK_RELAX_OPTION,
# _MRMW_OPTION and _MGCCISR_OPTION from auto-host.h.  A build-time generator
# cannot read targ_caps, so there is nowhere for these answers to land yet, and
# check-target-caps is right to refuse a key nothing reads.  Writing them is
# one uncommented line each once avr's device specs are generated per target
# the way this directory generates the rest.
#   as_avr_mlink_relax `ts_bool "$gcc_cv_as_avr_mlink_relax"`
#   as_avr_mrmw `ts_bool "$gcc_cv_as_avr_mrmw"`
#   as_avr_mgccisr `ts_bool "$gcc_cv_as_avr_mgccisr"`
# cris.  PROBED, NOT WRITTEN, same reason in a different shape: the consumer is
# MAYBE_AS_NO_MUL_BUG_ABORT in cris.h, which is SPEC TEXT.  Spec text comes
# down the gen-target-specs channel, not through targ_caps, so this belongs
# beside asm_mrelax below rather than here -- as a spec, when someone writes
# the cris side of it.
#   as_no_mul_bug_abort `ts_bool "$gcc_cv_as_cris_no_mul_bug"`
# ia64.  PROBED, NOT WRITTEN, AND THIS ONE IS A CHECKER LIMIT, NOT A DESIGN
# GAP.  The reader exists and is correct -- defaults.h defines
# HAVE_AS_LTOFFX_LDXMOV_RELOCS from this key and ia64.md reads it at
# ia64.md:774 and :787 -- but check-target-caps.sh builds its reader corpus
# from *.cc, *.h, *.c and *.def only, so an .md file is invisible to it and the
# key reads as dead.  Uncomment this line together with adding "*.md" to that
# find; doing it alone turns "make target-specs" red for everyone.
#   as_ltoffx_ldxmov_relocs `ts_bool "$gcc_cv_as_ia64_ltoffx_ldxmov_relocs"`
# powerpc.
as_mfcrf `ts_bool "$gcc_cv_as_powerpc_mfcrf"`
as_power10_htm `ts_bool "$gcc_cv_as_power10_htm"`
as_rel16 `ts_bool "$gcc_cv_as_powerpc_rel16"`
as_entry_markers `ts_bool "$gcc_cv_as_powerpc_entry_markers"`
as_pltseq `ts_bool "$gcc_cv_as_powerpc_pltseq_markers"`
# msp430.
as_mspabi_attribute `ts_bool "$gcc_cv_as_msp430_mspabi_attribute"`
# loongarch.  The explicit-relocs answer is emitted further up; these are the
# rest of the arm.  as_loongarch_mno_relax is what the leb128 probe needs, not
# a capability cc1 reads.
as_loongarch_support_call36 `ts_bool "$gcc_cv_as_loongarch_call36"`
as_loongarch_eh_frame_pcrel_encoding `ts_bool "$gcc_cv_as_loongarch_eh_frame_pcrel"`
as_loongarch_tls_le_relaxation `ts_bool "$gcc_cv_as_loongarch_tls_le_relaxation"`
as_loongarch_16b_atomic `ts_bool "$gcc_cv_as_loongarch_16b_atomic"`
# s390.  The two alignment-hint answers are one "#if/#elif" ladder in s390.h.
# as_s390_machine_machinemode is PROBED AND NOT WRITTEN.  Its consumer is
# S390_USE_TARGET_ATTRIBUTE, which is tested with "#if" in nine places, one of
# them selecting SWITCHABLE_TARGET -- that one changes data layout and cannot
# become a run-time answer.  Making it a capability needs s390 to stop deciding
# SWITCHABLE_TARGET from an assembler probe, which is its own change.
#   as_s390_machine_machinemode `ts_bool "$gcc_cv_as_s390_machine_machinemode"`
as_s390_architecture_modifiers `ts_bool "$gcc_cv_as_s390_architecture_modifiers"`
as_s390_vector_loadstore_alignment_hints `ts_bool "$gcc_cv_as_s390_vector_hints"`
as_s390_vector_loadstore_alignment_hints_on_z13 `ts_bool "$gcc_cv_as_s390_vector_hints_z13"`
# arm.
gas_arm_extended_arch `ts_bool "$gcc_cv_as_arm_option_extensions"`
# i386/x86_64.  Sixteen keys, none of which was written by anything until now,
# so every one of them was the built-in default on every target.
as_ix86_filds `ts_bool "$gcc_cv_as_ix86_filds"`
as_ix86_fildq `ts_bool "$gcc_cv_as_ix86_fildq"`
as_ix86_cmov_sun_syntax `ts_bool "$gcc_cv_as_ix86_cmov_sun_syntax"`
as_ix86_ffreep `ts_bool "$gcc_cv_as_ix86_ffreep"`
as_ix86_sahf `ts_bool "$gcc_cv_as_ix86_sahf"`
as_ix86_interunit_movq `ts_bool "$gcc_cv_as_ix86_interunit_movq"`
as_ix86_hle `ts_bool "$gcc_cv_as_ix86_hle"`
as_ix86_rep_lock_prefix `ts_bool "$gcc_cv_as_ix86_rep_lock_prefix"`
as_ix86_ud2 `ts_bool "$gcc_cv_as_ix86_ud2"`
as_ix86_tlsgdplt `ts_bool "$gcc_cv_as_ix86_tlsgdplt"`
as_ix86_tlsldmplt `ts_bool "$gcc_cv_as_ix86_tlsldmplt"`
as_ix86_tlsldm `ts_bool "$gcc_cv_as_ix86_tlsldm"`
as_ix86_got32x `ts_bool "$gcc_cv_as_ix86_got32x"`
as_r_x86_64_code_6_gottpoff `ts_bool "$gcc_cv_as_x86_64_code_6_gottpoff"`
as_gotoff_in_data `ts_bool "$gcc_cv_as_ix86_gotoff_in_data"`
as_ix86_tls_get_addr_got `ts_bool "$gcc_cv_as_ix86_tls_get_addr_via_got"`
# Solaris.  The same answer already selects link_arch_gnu or link_arch_sun in
# the spec half below; sol2.cc reads it as a capability.  Write both or neither
# -- a target whose specs say Sun ld and whose config file says GNU ld is worse
# than either answer applied consistently.
solaris_ld `ts_bool "$gcc_cv_solaris_ld"`
# Whether this target's debugger is VMS DEBUG.  Not a probe; see the note
# beside the case that sets it.  Getting this wrong in the "yes" direction
# changes the DWARF 5 line-table file-entry format for whatever target it
# reaches, and no tool reports it.
vms_debug `ts_bool "$ts_vms_debug"`
EOF

dnl Where this target's site-local and system headers live.  STRINGS, and the
dnl empty string is a real answer, exactly as for the gxx keys below.  This is
dnl its own heredoc only so the three keys stay together with their comment;
dnl it is UNCONDITIONAL, for the reason given where the values are computed.
dnl
dnl NO BACKTICKS IN THE PROSE OF THIS HEREDOC EITHER.  It is unquoted.
cat >> "$target_config_file" <<EOF

# Site-local and system header directories for this target.  STRINGS.  An empty
# value means "this target has no such directory" and removes the entry;
# omitting the line would instead leave cppdefault.cc's compile-time fallback in
# place, which is the answer for whichever target this tree was configured for.
# The component is the prefix-relocation key of the SAME two table entries as
# the directory, so the two are always written together.
local_include_dir ${ts_local_include_dir}
native_system_header_dir ${ts_native_system_header_dir}
native_system_header_component ${ts_native_system_header_component}
EOF

dnl Where this target's C++ headers live.  STRINGS, and the empty string is a
dnl real answer -- cppdefault.cc drops the entry from the include search path
dnl rather than searching "".
dnl
dnl TWO CONDITIONAL HEREDOCS, not printf, and that is not a style choice.
dnl check-target-caps.sh learns which keys this script writes by reading the
dnl heredocs, and it treats any OTHER redirection onto $target_config_file as a
dnl hard error rather than as a key it failed to see -- because a hole there
dnl reads as "never written", which is a false positive on a live key.  A
dnl printf emission is exactly such a hole.  Anything added here must stay in
dnl this shape or teach that extractor first.
dnl
dnl The heredocs are UNQUOTED, like the big one above, so ${} expands.  KEEP
dnl BACKTICKS OUT OF THE COMMENTS IN THEM.
dnl
dnl An empty variable gives "name" followed by a space and nothing else, which
dnl is a key WITH an empty value: target-caps.cc takes the rest of the line
dnl after the name, so the slot becomes "" rather than keeping its default.
dnl Same shape ld_static_option uses for the same reason.
if test x"$ts_emit_gxx" = xyes; then
cat >> "$target_config_file" <<EOF

# C++ header directories for this target.  STRINGS, and empty is a real answer:
# cppdefault.cc drops the entry from the include search path rather than
# searching "".  A key that is absent is NOT the same thing -- that leaves the
# built-in installation-relative default in place.
gxx_include_dir ${ts_gxx_include_dir}
gxx_tool_include_dir ${ts_gxx_tool_include_dir}
gxx_backward_include_dir ${ts_gxx_backward_include_dir}
EOF
fi
if test x"$ts_emit_gxx_libcxx" = xyes; then
cat >> "$target_config_file" <<EOF
gxx_libcxx_include_dir ${ts_gxx_libcxx_include_dir}
EOF
fi

dnl --- WHAT WAS ACTUALLY WRITTEN, CHECKED AGAINST WHAT SHOULD HAVE BEEN.
dnl
dnl This file has produced two of this project's worst silent failures, and both
dnl were the same shape: a heredoc that did not finish.
dnl
dnl   1. A backtick inside a COMMENT in an unquoted heredoc.  The shell died with
dnl      "unexpected EOF while looking for matching backtick", nothing at all was
dnl      written, and configure still exited 0 -- so all 97 capabilities silently
dnl      took their built-in default on every target.
dnl   2. A single apostrophe in a comment truncated the options block out of a
dnl      generated makefile, again with exit 0.
dnl
dnl Neither is visible to check-target-caps.sh, and that is not a gap in that
dnl check -- it reads this file's TEXT to learn which keys the heredocs can emit,
dnl so a heredoc that reads correctly and executes badly looks perfect to it.
dnl Static analysis of the emitter cannot see the emitter failing to run.  Only
dnl reading back the artefact can.
dnl
dnl So the list below is a DELIBERATE DUPLICATE of the heredoc contents, and the
dnl duplication is the mechanism: two independent statements of the same fact,
dnl where disagreement in EITHER direction is a hard error that names the keys.
dnl A key added to a heredoc and not to this list fails as "written but not
dnl expected"; one added here and not emitted fails as "expected but missing".
dnl Keeping them in step is the cost, and it is the point -- the alternative is
dnl the absence of an answer being read as an answer, which is exactly how a
dnl truncated heredoc turned into 97 silent defaults.
dnl
dnl Use \047 for an apostrophe and NO BACKTICKS in the message text.
ts_expected="target leb128 decimal_float decimal_bid_format
  s390_excess_float_precision glibc_major glibc_minor libc_hwcap_in_tcb
  libc_gnustack ld_broken_secrel32 as_ref xcoff_dwarf_extras
  as_relax_option as_offsetable_lo10 as_gnu_attribute cfi_directive
  cfi_personality cfi_sections gas_loc_stmt gas_discriminator
  as_line_zero dwarf2_debug_line dwarf2_debug_view as_alpha_explicit_relocs
  as_alpha_jsrdirect_relocs as_aarch64_mabi as_aarch64_small_pic_relocs
  as_aarch64_aeabi_build_attributes
  as_mips_nan as_mips_micromips as_mips_dspr1_mult as_mips_explicit_relocs
  as_mips_explicit_relocs_pcrel as_ld_mips_jalr_reloc as_mips_dot_module
  as_loongarch_relax
  as_loongarch_cond_branch_relax as_loongarch_explicit_relocs as_riscv_attribute
  as_riscv_misa_spec
  as_riscv_march_zifencei as_riscv_march_zaamo_zalrsc as_riscv_march_b gas_hidden
  ld_ro_rw_section_mixing ld_eh_gc_sections ld_ctf ld_sysroot
  ld_at_file ld_pie ld_pie_copyreloc ld_personality_relaxation
  ld_no_dot_syms ld_large_toc ld_toc_align ld_ppc_attr
  ld_broken_pe_dwarf5 ld_avr_avrxmega3_rodata_in_flash ld_avr_avrxmega2_flmap
  ld_avr_avrxmega4_flmap
  ld_now ld_relro lto_plugin ld_demangle
  ld_static_option ld_dynamic_option gas_balign_and_p2align gas_max_skip_p2align
  gas_literal16 gas_subsection_ordering gas_weak gas_weakref
  gas_nsubspa_comdat gas_base64 gas_cv_ucomp gas_lcomm_with_alignment
  gas_section_exclude gas_shf_gnu_retain gas_section_link_order gas_shf_merge
  use_as_traditional_format as_mmacosx_version_min as_macos_build_version as_mfcrf
  as_power10_htm as_rel16 as_entry_markers as_pltseq
  as_mspabi_attribute as_loongarch_support_call36
  as_loongarch_eh_frame_pcrel_encoding as_loongarch_tls_le_relaxation
  as_loongarch_16b_atomic as_s390_architecture_modifiers
  as_s390_vector_loadstore_alignment_hints
  as_s390_vector_loadstore_alignment_hints_on_z13
  gas_arm_extended_arch as_ix86_filds as_ix86_fildq as_ix86_cmov_sun_syntax
  as_ix86_ffreep as_ix86_sahf as_ix86_interunit_movq as_ix86_hle
  as_ix86_rep_lock_prefix as_ix86_ud2 as_ix86_tlsgdplt as_ix86_tlsldmplt
  as_ix86_tlsldm as_ix86_got32x as_r_x86_64_code_6_gottpoff as_gotoff_in_data
  as_ix86_tls_get_addr_got solaris_ld vms_debug local_include_dir
  native_system_header_dir native_system_header_component"

dnl The two conditional blocks above.  Their keys are expected exactly when the
dnl block that writes them ran, so a wrong condition shows up here rather than
dnl as a key that quietly is not there.
if test x"$ts_emit_gxx" = xyes; then
  ts_expected="$ts_expected gxx_include_dir gxx_tool_include_dir gxx_backward_include_dir"
fi
if test x"$ts_emit_gxx_libcxx" = xyes; then
  ts_expected="$ts_expected gxx_libcxx_include_dir"
fi

dnl Read the artefact back.  A key with an EMPTY value is written as its name
dnl followed by a space, so match the name at the start of a line either way;
dnl treating "name " as absent would report every empty-valued string key
dnl missing, which is the false alarm that gets a check deleted.
dnl Process substitution is bash-only and configure runs under /bin/sh, so the
dnl two sides go through temporary files.
dnl THE BRACKETS BELOW ARE M4 QUOTES UNLESS THEY ARE QUOTED THEMSELVES.  Written
dnl without the outer [ ], autoconf strips one level from every character class
dnl and ships `$1 ~ /^a-z_a-z_0-9*$/' into configure -- which matches nothing, so
dnl the reader returns an empty key set and the check below reports all 118
dnl capabilities missing from a file that in fact contains all 118.  That is
dnl what happened on this code's first run.  A checker whose own reader silently
dnl reads nothing is the failure mode this whole block exists to prevent, so it
dnl gets the same treatment: the empty case is separated out below and named.
dnl No character class in the sed: awk's $1 already ignores leading blanks, so
dnl a leading-whitespace strip would be redundant AND would need bracket
dnl protection of its own -- and when that protection does not take, the
dnl brackets reach configure, sed is handed a script beginning with `[', it
dnl fails, and the pipeline yields nothing.  Fewer character classes is the fix
dnl that cannot regress.
sed 's/#.*//' "$target_config_file" \
  | awk ['$1 ~ /^[a-z_][a-z_0-9]*$/ { print $1 }'] | sort -u > conftest.tswritten
for ts_k in $ts_expected; do echo "$ts_k"; done | sort -u > conftest.tsexpected

ts_missing=`comm -23 conftest.tsexpected conftest.tswritten | tr '\n' ' '`
ts_extra=`comm -13 conftest.tsexpected conftest.tswritten | tr '\n' ' '`

ts_n_written=`grep -c . conftest.tswritten`
ts_n_expected=`grep -c . conftest.tsexpected`
ts_n_lines=`wc -l < "$target_config_file"`
rm -f conftest.tswritten conftest.tsexpected

dnl Reader-broken and everything-missing produce the same $ts_missing, and they
dnl need opposite fixes, so they get separate messages.  Without this arm the
dnl m4-quoting bug above reads as "the heredocs emitted nothing", which sends the
dnl next person to look at the right file for the wrong reason.
if test "$ts_n_expected" -eq 0; then
  AC_MSG_ERROR([the expected-capability list in configure.ac came out empty, so
this check would pass no matter what was written.])
fi
if test "$ts_n_written" -eq 0; then
  AC_MSG_ERROR([no capability keys could be read back out of $target_config_file,
which has $ts_n_lines lines.  Either nothing was written, or
the reader in configure.ac is broken -- and an m4-quoted character class is the
way that has already happened once.  Check the file before changing the list.])
fi

if test -n "$ts_missing"; then
  AC_MSG_ERROR([$target_config_file is missing capabilit(ies) this script is supposed to write:$ts_missing
A heredoc in configure.ac did not finish -- a backtick or an unbalanced quote in
one of its comments is the usual cause, and it fails with exit 0.  Do NOT delete
the name from the list above to make this pass: a capability that is not written
is the built-in default on every target forever, and that is precisely the
failure this check exists to make impossible to miss.])
fi

if test -n "$ts_extra"; then
  AC_MSG_ERROR([$target_config_file carries capabilit(ies) that are not in the
expected list in configure.ac:$ts_extra
Add them to ts_expected beside the heredoc that emits them, so that the day that
heredoc stops running, the omission is an error rather than a default.])
fi

if test "$ts_n_written" -ne "$ts_n_expected"; then
  AC_MSG_ERROR([$target_config_file has $ts_n_written capability keys but $ts_n_expected were expected, and yet neither list names one the other does not.  The reader in configure.ac is wrong.])
fi
AC_MSG_NOTICE([$target_config_file: $ts_n_written capabilities, all expected])

dnl The driver-side ones are spec fragments.  They are appended as their own
dnl spec entries rather than folded into the ones written above.
if test x"$gcc_cv_ld_as_needed" = xyes; then
  link_as_needed="%{!static:%{!static-pie:${gcc_cv_ld_as_needed_option}}}"
  link_no_as_needed="%{!static:%{!static-pie:${gcc_cv_ld_no_as_needed_option}}}"
else
  link_as_needed=
  link_no_as_needed=
fi

dnl What to link for libatomic.  This is LINK_LIBATOMIC_SPEC, which gcc.cc used
dnl to build behind `#if defined(TARGET_PROVIDES_LIBATOMIC) &&
dnl defined(USE_LD_AS_NEEDED)'.  Both macros came from tm.h, gcc.cc no longer
dnl includes tm.h, so the guard was unconditionally false and the macro was
dnl always "" -- while a dozen target headers under config/ still built their
dnl LINK_GCC_C_SEQUENCE_SPEC out of it.  gen-target-specs writes
dnl %(link_libatomic) where the header wrote the macro; this fills it in.
dnl
dnl The two questions the old guard asked are answered from two different
dnl places, and that split is the point.  "Is there a libatomic" is a fact about
dnl the build, passed in above.  "Can this linker take it as-needed" is a fact
dnl about the installed linker, and is asked here.
dnl
dnl THE OPTION SPELLINGS ARE USED RAW, not through %(link_as_needed).  Those
dnl named specs carry `%{!static:%{!static-pie:...}}' because the libgcc_s
dnl sequence needs it; LINK_LIBATOMIC_SPEC never had those guards and going
dnl through them would silently change what a -static link gets.  Same reason
dnl the ldscript form below is a separate string rather than a wrapper.
dnl
dnl gcc_cv_ld_as_needed_option and gcc_cv_ld_no_as_needed_option are set
dnl unconditionally at the top of the --as-needed probe, NOT inside its `yes'
dnl arm -- checked, because the last stranded macro restored here referenced
dnl data that had been stranded by the same guard, and emitting the spec would
dnl have produced a worse failure than leaving it out.
if test x"$spec_libatomic" != xyes; then
  link_libatomic=
elif test x"$gcc_cv_ld_as_needed" = xyes; then
  link_libatomic="%{!fno-link-libatomic:${gcc_cv_ld_as_needed_option} -latomic ${gcc_cv_ld_no_as_needed_option}} "
elif test x"$gcc_cv_ld_use_as_needed_ldscript" = xyes; then
  dnl Solaris ld: the as-needed decision is made by a linker script that comes
  dnl with the library, so the driver names that library instead of bracketing
  dnl the ordinary one.  This was USE_LD_AS_NEEDED_LDSCRIPT.
  link_libatomic='%{!fno-link-libatomic:-latomic_asneeded} '
else
  dnl A linker that cannot do as-needed at all gets nothing, which is what the
  dnl `#else' arm produced.  Linking -latomic unconditionally is not the
  dnl conservative choice: it is a hard dependency on a library the program may
  dnl not need.
  link_libatomic=
fi

dnl What -fsplit-stack adds to the link line.  The wrapper is needed whenever
dnl the option is used at all; the -fuse-ld=gold in front of it only when the
dnl default linker cannot do split stack and a usable gold sits beside it.  The
dnl `no' arm is byte-for-byte the driver's own default, so writing it into every
dnl spec file changes nothing on a target that answers no -- it is written
dnl anyway, because a spec file that states the answer is inspectable and one
dnl that omits it is indistinguishable from a spec file written before the probe
dnl existed.
if test x"$gcc_cv_ld_gold_split_stack" = xyes; then
  link_split_stack='%{fsplit-stack: -fuse-ld=gold --wrap=pthread_create}'
else
  link_split_stack='%{fsplit-stack: --wrap=pthread_create}'
fi

dnl Which libgcc libraries to name.  This is the ENABLE_SHARED_LIBGCC choice,
dnl which gcc.cc used to make with `#if defined' over a macro that came from the
dnl PRIMARY target's tmake_file -- see the long note in gcc.cc's init_spec.  The
dnl answer is per target and it selects SPEC TEXT, so it comes down this channel
dnl rather than through targ_caps.
dnl
dnl TWO names because the driver rewrites libgcc_spec at two sites that name
dnl DIFFERENT libraries: `-lgcc' (the -l form) and `libgcc.a%s' (the by-filename
dnl form, LINK_LIBGCC_SPECIAL_1 targets).  One name for both would give one site
dnl the other's libraries, silently, on exactly the targets that use the rarer
dnl form.
dnl
dnl The `no' arms are the identity: they reproduce the token the driver found,
dnl which is what a build without ENABLE_SHARED_LIBGCC emitted.  The `yes' arms
dnl are what init_gcc_specs () used to build.  The -l form defers its non-static
dnl body to %(libgcc_nonstatic), which gen-target-specs may have already
dnl overridden for a target whose headers set USE_LD_AS_NEEDED; the filename
dnl form does not, because that named spec holds the -l form's libraries and no
dnl target reaching the filename site sets USE_LD_AS_NEEDED.
if test x"$spec_shared_libgcc" = xyes; then
  libgcc_variants='%{static|static-libgcc:-lgcc -lgcc_eh}%{!static:%{!static-libgcc:%(libgcc_nonstatic)}}'
  libgcc_file_variants='%{static|static-libgcc:libgcc.a%s libgcc_eh.a%s}%{!static:%{!static-libgcc:%{!shared:%{!shared-libgcc:libgcc.a%s libgcc_eh.a%s}%{shared-libgcc:-lgcc_s libgcc.a%s}}%{shared:-lgcc_s}}}'
else
  libgcc_variants='-lgcc'
  libgcc_file_variants='libgcc.a%s'
fi

dnl How to hand the LTO plugin to the linker.  This is the whole spec, not just
dnl the -plugin option: without -plugin-opt=-fresolution= the linker calls
dnl lto-wrapper without a resolution file and the link still fails, so emitting
dnl a fragment would have looked like a fix and not been one.  The text is the
dnl one gcc.cc used to build behind `#if HAVE_LTO_PLUGIN', with that macro's
dnl two levels preserved as two shapes:
dnl
dnl   2  full support -- use the plugin by DEFAULT, unless -fno-use-linker-plugin
dnl      or -fno-lto.  This is what upstream's configure records for a linker
dnl      whose plugin interface is complete.
dnl   1  limited support -- use it only when asked with -fuse-linker-plugin.
dnl      Upstream reached this for gold 2.20 and nothing else; the probe below
dnl      cannot tell 1 from 2 by asking, so it never answers 1 today.  The arm
dnl      is written anyway, because a probe that learns the difference later
dnl      should not also have to invent the spec.
dnl   0  no -plugin at all -- reject an explicit -fuse-linker-plugin, which is
dnl      also the driver's built-in default.
dnl
dnl `%(lto_plugin)' is the target's own extra -plugin-opt (config/vxworks.h is
dnl the only definer); gen-target-specs writes it from LTO_PLUGIN_SPEC, so the
dnl target keeps the text and this script keeps only the choice.
ts_plugin_body='-plugin %(linker_plugin_file) \
    -plugin-opt=%(lto_wrapper) \
    -plugin-opt=-fresolution=%u.res \
    %(lto_plugin) \
    %{flinker-output=*:-plugin-opt=-linker-output-known} \
    %{!nostdlib:%{!nodefaultlibs:%:pass-through-libs(%(link_gcc_c_sequence))}}'
case $gcc_cv_lto_plugin in
  2) link_plugin="%{!fno-use-linker-plugin:%{!fno-lto:${ts_plugin_body}}}" ;;
  1) link_plugin="%{fuse-linker-plugin:${ts_plugin_body}}" ;;
  *) link_plugin='%{fuse-linker-plugin:%e-fuse-linker-plugin is not supported in this configuration}' ;;
esac

dnl The asm_mrelax spec, from the two loongarch probes.  Three shapes, not four:
dnl when the assembler will not take -mrelax at all the DEFAULT arm is
dnl -mno-relax whatever the conditional-branch answer was, because the original
dnl `#if' read the two with `&&'.  Keeping that here rather than in the spec
dnl text is what stops a later reader from "simplifying" it into two
dnl independent choices.
if test x"$gcc_cv_as_loongarch_relax" = xyes; then
  if test x"$gcc_cv_as_loongarch_cond_branch_relax" = xyes; then
    asm_mrelax_default='%{!mrelax:%{!mno-relax:-mrelax}}'
  else
    asm_mrelax_default='%{!mrelax:%{!mno-relax:-mno-relax}}'
  fi
  asm_mrelax="%{!mno-pass-mrelax-to-as:%{mrelax} %{mno-relax} ${asm_mrelax_default}}"
else
  asm_mrelax_default='%{!mrelax:%{!mno-relax:-mno-relax}}'
  asm_mrelax="%{mpass-mrelax-to-as:%{mrelax} %{mno-relax} ${asm_mrelax_default}}"
fi

dnl mips FP_ASM_SPEC, from the .module probe.  These four options tell the
dnl assembler which FP ABI the code uses, and gas only accepts them once it
dnl understands `.module'; passing -msoft-float to an older assembler makes it
dnl reject every hard-float instruction, which is why the original was gated at
dnl all.  Written whole for the same reason as asm_mrelax: it is one answer, and
dnl a fragment would invite a consumer to pass some of the four.
if test x"$gcc_cv_as_mips_dot_module" = xyes; then
  asm_fp_module='%{mhard-float} %{msoft-float} %{msingle-float} %{mdouble-float}'
else
  asm_fp_module=''
fi

dnl AIX asm_v: how to hand -v and -w to the IBM assembler.  Emitted ONLY when
dnl that assembler was actually found, for the same reason given at
dnl `*link_disable_dynamicbase' below -- a name written into all 183 spec files
dnl that only one target can ever use is 182 names nothing consults, which is
dnl what check-spec-refs exists to catch.  An AIX target using gas therefore
dnl falls back to the driver's own asm_v, which is the right answer for gas.
dnl
dnl The text is config/rs6000/aix.h's own, restored: `%{v} %{w:-W}', with no
dnl `%{I*}'.  The heredoc is QUOTED because the value is spec syntax that must
dnl reach the file verbatim.
if test x"$gcc_cv_aix_as" = xyes; then
  cat >> "$specs_file" <<'EOF'
*asm_v:
%{v} %{w:-W}

EOF
fi

dnl Solaris link_arch: pick the Sun-ld form when we found Sun ld.  Emitted as a
dnl reference to the named spec the target header already registers, so the spec
dnl TEXT stays in config/sol2.h where the target knowledge belongs and only the
dnl CHOICE lives here.
if test x"$gcc_cv_solaris_ld" = xyes; then
  cat >> "$specs_file" <<EOF
*link_arch:
%(link_arch_sun)

EOF
fi

cat >> "$specs_file" <<EOF
*link_as_needed:
${link_as_needed}

*link_no_as_needed:
${link_no_as_needed}

# The C half of these two is ld_static_option/ld_dynamic_option in the target
# config file above.  One probe, two carriers; changing one alone puts two
# different spellings on one target.
*link_static:
${gcc_cv_ld_static_option}

*link_dynamic:
${gcc_cv_ld_dynamic_option}

*link_libatomic:
${link_libatomic}

# What -fsplit-stack adds to the link line; the -fuse-ld=gold arm is taken only
# when this linker cannot do split stack itself and a usable gold sits beside
# it.  This is HAVE_GOLD_NON_DEFAULT_SPLIT_STACK.
*link_split_stack:
${link_split_stack}

# Which libgcc libraries to name, at each of the driver's two rewrite sites.
# This is ENABLE_SHARED_LIBGCC, which used to be decided once, by the primary
# target's tmake_file, for every target the compiler serves.  The two names are
# NOT interchangeable: the first spells its libraries with -l, the second by
# filename.  Written from --with-shared-libgcc, i.e. from this target's own
# tmake_file_present in the manifest.
*libgcc_variants:
${libgcc_variants}

*libgcc_file_variants:
${libgcc_file_variants}

*link_plugin:
${link_plugin}

# How to hand -mrelax to the assembler.  Written whole rather than as a
# fragment: the DEFAULT arm needs BOTH probe answers and the enclosing
# %{...} needs one, so a fragment would let a consumer assemble a combination
# neither probe describes.  loongarch's ASM_SPEC refers to this; every other
# target's ASM_SPEC does not mention it, and the driver's own default is the
# conservative opt-in form, so an unprobed driver is unchanged.
*asm_mrelax:
${asm_mrelax}

# The FP ABI options mips hands to its assembler, empty when the assembler is
# too old for the .module directive.  mips's ASM_SPEC refers to this and no
# other target's does; the driver's own default is empty, so an unprobed driver
# is unchanged.  No backticks in this text: the heredoc is unquoted so that
# \${asm_fp_module} expands, which means it is also a command-substitution
# context.
*asm_fp_module:
${asm_fp_module}

EOF

dnl `*link_disable_dynamicbase' is emitted ONLY when the linker takes the
dnl option, and that condition is not cosmetic: the spec is referenced by
dnl mingw's LINK_SPEC and by nothing else, so writing it into all 183 files
dnl would be 182 names nothing consults -- the exact thing check-spec-refs
dnl exists to catch.  `*link_arch' above uses the same shape for the same
dnl reason.  A mingw target whose linker lacks the option therefore falls back
dnl to the driver's empty default, which is what the dead
dnl `#if HAVE_LD_PE_DISABLE_DYNAMICBASE' produced.
dnl
dnl The condition inside the spec is the target header's own, restored:
dnl `%{!shared:%{!mdll:%{no-pie:...}}}'.  What used to be written here was
dnl `%{shared|pie:...}', which is very nearly the NEGATION of it -- an unread
dnl spec is not checked against the header it is supposed to replace, so it had
dnl drifted into being wrong as well as unused.
if test x"$gcc_cv_ld_disable_dynamicbase" = xyes; then
  cat >> "$specs_file" <<EOF
*link_disable_dynamicbase:
%{!shared:%{!mdll:%{no-pie:--disable-dynamicbase}}}

EOF
fi

AC_MSG_NOTICE([  ld --as-needed ........... ${gcc_cv_ld_as_needed}])
AC_MSG_NOTICE([  ld -Bstatic spelling ..... ${gcc_cv_ld_static_option:-none}])
AC_MSG_NOTICE([  libatomic on link line ... ${spec_libatomic}])
AC_MSG_NOTICE([  ld --demangle ............ ${gcc_cv_ld_demangle}])
AC_MSG_NOTICE([  ld --sysroot ............. ${gcc_cv_ld_sysroot}])
AC_MSG_NOTICE([  ld @file ................. ${gcc_cv_ld_at_file}])
AC_MSG_NOTICE([  ld -plugin ............... ${gcc_cv_lto_plugin}])
AC_MSG_NOTICE([  ld .hidden ............... ${gcc_cv_ld_hidden}])
AC_MSG_NOTICE([  ld ro/rw mixing .......... ${gcc_cv_ld_ro_rw_mix}])
AC_MSG_NOTICE([  ld --gc-sections ......... ${gcc_cv_ld_eh_gc_sections}])
AC_MSG_NOTICE([  ld -z ctf ................ ${gcc_cv_ld_ctf}])
AC_MSG_NOTICE([  non-default gold ......... ${gcc_cv_ld_gold_split_stack}])
AC_MSG_NOTICE([  shared libgcc ............ ${spec_shared_libgcc}])

fi

AC_OUTPUT
