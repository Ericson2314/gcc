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

AC_MSG_CHECKING([linker for --eh-frame-hdr])
gcc_cv_ld_eh_frame_hdr=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '--eh-frame-hdr' > /dev/null; then
  gcc_cv_ld_eh_frame_hdr=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_eh_frame_hdr])

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

AC_MSG_CHECKING([linker for -Bstatic/-Bdynamic])
gcc_cv_ld_static_dynamic=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '-Bstatic' > /dev/null; then
  gcc_cv_ld_static_dynamic=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_static_dynamic])

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
AC_MSG_NOTICE([  ld -Bstatic/-Bdynamic .... ${gcc_cv_ld_static_dynamic}])

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

dnl -Bstatic/-Bdynamic is probed above; the option *spelling* is not, and AIX
dnl and HP-UX spell it differently.  Ask for the spelling the linker admits to.
gcc_cv_ld_static_option='-Bstatic'
gcc_cv_ld_dynamic_option='-Bdynamic'
if test x"$gcc_cv_ld_static_dynamic" != xyes; then
  if "$gcc_cv_ld" --help 2>&1 | grep -- '-bstatic' > /dev/null; then
    gcc_cv_ld_static_dynamic=yes
    gcc_cv_ld_static_option='-bstatic'
    gcc_cv_ld_dynamic_option='-bdynamic'
  elif "$gcc_cv_ld" --help 2>&1 | grep -- '-aarchive_shared' > /dev/null; then
    gcc_cv_ld_static_dynamic=yes
    gcc_cv_ld_static_option='-aarchive_shared'
    gcc_cv_ld_dynamic_option='-adefault'
  fi
fi

dnl --- Consulted by cc1: these go in the target config file. ----------------

AC_MSG_CHECKING([linker for .hidden])
gcc_cv_ld_hidden=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '-Bsymbolic' > /dev/null; then
  gcc_cv_ld_hidden=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_hidden])

dnl HAVE_GAS_HIDDEN needs both halves; gcc_cv_as_hidden is probed by the
dnl assembler section of this script.
gcc_cv_gas_hidden=no
if test x"$gcc_cv_as_hidden" = xyes && test x"$gcc_cv_ld_hidden" = xyes; then
  gcc_cv_gas_hidden=yes
fi

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

AC_MSG_CHECKING([linker for --version-script])
gcc_cv_ld_version_script=no
ld_version_script_option=
if "$gcc_cv_ld" --help 2>&1 | grep -- '--version-script' > /dev/null; then
  gcc_cv_ld_version_script=yes
  ld_version_script_option='--version-script='
fi
AC_MSG_RESULT([$gcc_cv_ld_version_script])

AC_MSG_CHECKING([linker for -soname])
gcc_cv_ld_soname=no
ld_soname_option=
if "$gcc_cv_ld" --help 2>&1 | grep -- '-soname' > /dev/null; then
  gcc_cv_ld_soname=yes
  ld_soname_option='-soname'
fi
AC_MSG_RESULT([$gcc_cv_ld_soname])

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
dwarf2_debug_view `ts_bool ""`

# aarch64 back-end assembler capabilities.
as_aarch64_mabi `ts_bool "$gcc_cv_as_aarch64_mabi"`
as_aarch64_small_pic_relocs `ts_bool "$gcc_cv_as_aarch64_picreloc"`
as_aarch64_aeabi_build_attributes `ts_bool "$gcc_cv_as_aarch64_aeabi"`

# mips back-end assembler capabilities.
as_mips_nan `ts_bool "$gcc_cv_as_mips_nan"`
as_mips_micromips `ts_bool "$gcc_cv_as_micromips_support"`

# riscv back-end assembler capabilities.
as_riscv_attribute `ts_bool "$gcc_cv_as_riscv_attribute"`
as_riscv_misa_spec `ts_bool "$gcc_cv_as_riscv_isa_spec"`
as_riscv_march_zifencei `ts_bool "$gcc_cv_as_riscv_march_zifencei"`
as_riscv_march_zaamo_zalrsc `ts_bool "$gcc_cv_as_riscv_march_zaamo_zalrsc"`
as_riscv_march_b `ts_bool "$gcc_cv_as_riscv_march_b"`

# Linker capabilities.
gas_hidden `ts_bool "$gcc_cv_gas_hidden"`
ld_ro_rw_section_mixing `if test x"$gcc_cv_ld_ro_rw_mix" = xread-write; then echo 1; else echo 0; fi`
ld_eh_gc_sections `ts_bool "$gcc_cv_ld_eh_gc_sections"`
ld_ctf `ts_bool "$gcc_cv_ld_ctf"`
ld_sysroot `ts_bool "$gcc_cv_ld_sysroot"`
ld_at_file `ts_bool "$gcc_cv_ld_at_file"`
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
EOF

dnl The driver-side ones are spec fragments.  They are appended as their own
dnl spec entries rather than folded into the ones written above.
if test x"$gcc_cv_ld_as_needed" = xyes; then
  link_as_needed="%{!static:%{!static-pie:${gcc_cv_ld_as_needed_option}}}"
  link_no_as_needed="%{!static:%{!static-pie:${gcc_cv_ld_no_as_needed_option}}}"
else
  link_as_needed=
  link_no_as_needed=
fi

cat >> "$specs_file" <<EOF
*link_as_needed:
${link_as_needed}

*link_no_as_needed:
${link_no_as_needed}

*link_static:
${gcc_cv_ld_static_option}

*link_dynamic:
${gcc_cv_ld_dynamic_option}

*link_demangle:
%{!no-demangle:`if test x"$gcc_cv_ld_demangle" = xyes; then echo --demangle; fi`}

*link_plugin:
`if test "$gcc_cv_lto_plugin" -gt 0; then echo '%{!fno-use-linker-plugin:%{!fno-lto:-plugin %(linker_plugin_file)}}'; fi`

*link_disable_dynamicbase:
`if test x"$gcc_cv_ld_disable_dynamicbase" = xyes; then echo '%{shared|pie:--disable-dynamicbase}'; fi`

EOF

AC_MSG_NOTICE([  ld --as-needed ........... ${gcc_cv_ld_as_needed}])
AC_MSG_NOTICE([  ld --demangle ............ ${gcc_cv_ld_demangle}])
AC_MSG_NOTICE([  ld --sysroot ............. ${gcc_cv_ld_sysroot}])
AC_MSG_NOTICE([  ld @file ................. ${gcc_cv_ld_at_file}])
AC_MSG_NOTICE([  ld -plugin ............... ${gcc_cv_lto_plugin}])
AC_MSG_NOTICE([  ld .hidden ............... ${gcc_cv_ld_hidden}])
AC_MSG_NOTICE([  ld ro/rw mixing .......... ${gcc_cv_ld_ro_rw_mix}])
AC_MSG_NOTICE([  ld --gc-sections ......... ${gcc_cv_ld_eh_gc_sections}])
AC_MSG_NOTICE([  ld -z ctf ................ ${gcc_cv_ld_ctf}])
AC_MSG_NOTICE([  ld --version-script ...... ${gcc_cv_ld_version_script}])
AC_MSG_NOTICE([  ld -soname ............... ${gcc_cv_ld_soname}])

fi

AC_OUTPUT
