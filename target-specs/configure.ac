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

dnl Values that gcc/configure would have frozen into configure_default_options[]
dnl and paired with the target's OPTION_DEFAULT_SPECS templates.  Here they are
dnl just inputs, so a single driver can carry different defaults per target.
AC_ARG_WITH([arch],
  [AS_HELP_STRING([--with-arch=ARCH], [default -march for this target])],
  [spec_with_arch=$withval], [spec_with_arch=])
AC_ARG_WITH([cpu],
  [AS_HELP_STRING([--with-cpu=CPU], [default -mcpu for this target])],
  [spec_with_cpu=$withval], [spec_with_cpu=])
AC_ARG_WITH([tune],
  [AS_HELP_STRING([--with-tune=TUNE], [default -mtune for this target])],
  [spec_with_tune=$withval], [spec_with_tune=])

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

AC_MSG_CHECKING([linker for --build-id])
gcc_cv_ld_buildid=no
if "$gcc_cv_ld" --help 2>&1 | grep -- '--build-id' > /dev/null; then
  gcc_cv_ld_buildid=yes
fi
AC_MSG_RESULT([$gcc_cv_ld_buildid])

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

dnl Expand the option-default templates now, so the driver receives a plain self
dnl spec with no %(VALUE) left in it.
dnl
dnl CAVEAT: the templates below are the common shape (as used by i386, aarch64,
dnl riscv and most others).  A target whose OPTION_DEFAULT_SPECS differs will
dnl need its own template, which is exactly the config.gcc-derived data that
dnl should move into this generator rather than living in gcc/.
option_defaults=
if test x"$spec_with_arch" != x; then
  option_defaults="${option_defaults}%{!march=*:-march=${spec_with_arch}} "
fi
if test x"$spec_with_cpu" != x; then
  option_defaults="${option_defaults}%{!mcpu=*:%{!march=*:-mcpu=${spec_with_cpu}}} "
fi
if test x"$spec_with_tune" != x; then
  option_defaults="${option_defaults}%{!mtune=*:%{!mcpu=*:%{!march=*:-mtune=${spec_with_tune}}}} "
fi

dnl Only write a spec file if the probes actually ran.  Writing one built from
dnl failed probes would record "feature absent" for every feature, which is a
dnl worse outcome than having no file: the driver would silently lose behaviour
dnl rather than fall back to its built-in defaults.
if test x"$have_target_tools" != xyes; then
  AC_MSG_NOTICE([skipping $specs_file: target tools unavailable, nothing probed])
else

AC_MSG_NOTICE([writing $specs_file])
cat > "$specs_file" <<EOF
# Generated by target-specs/configure for ${target}.
# Probes were run against:
#   as: ${gcc_cv_as}
#   ld: ${gcc_cv_ld}
# Do not edit; regenerate by re-running that script against the same toolchain.

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

AC_OUTPUT
