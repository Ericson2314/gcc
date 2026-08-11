/* Runtime target assembler/linker capabilities.
   Copyright (C) 2026 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

GCC is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with GCC; see the file COPYING3.  If not see
<http://www.gnu.org/licenses/>.  */

/* These used to be HAVE_AS_x, HAVE_GAS_x and HAVE_LD_x macros, answered by probing
   a specific as/ld while GCC itself was configured and frozen into
   auto-host.h.  A multi-target compiler is built once and used against many
   toolchains, so a single frozen answer is wrong by construction: the macros
   are now runtime values.

   target-specs/configure probes the real toolchain after the build and writes
   a target-config file next to that target's spec file.  The driver passes it
   to cc1 with -ftarget-config=, out of the spec file, so specs remain the one
   configuration channel.

   Everything defaults to the answer a modern GNU toolchain gives, so a
   compiler with no target-config file behaves like a normally-configured one
   rather than silently losing features.  */

#ifndef GCC_TARGET_CAPS_H
#define GCC_TARGET_CAPS_H

struct target_caps
{
  /* Assembler understands .uleb128/.sleb128 with symbolic arguments.  */
  bool leb128;

  /* s390 only: the target C library typedefs float_t to double, so
     -fexcess-precision=standard has to report FLT_EVAL_METHOD 1 to stay
     consistent with it.  Was --enable-s390-excess-float-precision, whose
     default compiled a `#include <math.h>' against the target sysroot.  A
     property of somebody else's libc is not something a compiler can know at
     build time, so it is asked for here instead; false is GCC's stated
     direction (glibc deriving float_t from __FLT_EVAL_METHOD__) and is what a
     cross build without target headers already got.  */
  bool s390_excess_float_precision;

  /* Decimal floating point (_Decimal32 and friends) is usable for this target:
     the back end has the modes and its libgcc has the support functions.  Was
     --enable-decimal-float, whose default was a `case $target' listing the
     handful of CPU/OS pairs that qualify.  Default false: a compiler that has
     not been told anything about the target cannot know that its libgcc
     carries the __bid_ and __dpd_ entry points, and claiming the modes exist
     turns a clean "mode not supported" into a link failure.  */
  bool decimal_float;

  /* Decimal float uses the BID encoding rather than DPD.  This is fixed by the
     target's ABI -- x86 and aarch64 are BID, powerpc and s390 are DPD -- and
     picks which half of libgcc's __bid_ and __dpd_ entry points is called, so it
     is derived from the target rather than probed.  DPD is the format the
     standard describes and what everything other than x86/aarch64 uses, so it
     is the default.  Only meaningful when decimal_float is true.  */
  bool decimal_bid_format;

  /* Version of the GNU C Library on the target, or 0.0 for "not glibc, or not
     known".  Was --with-glibc-version, and failing that a grep for __GLIBC__ in
     $target_header_dir/features.h -- gcc/configure reaching into the target's
     sysroot and freezing what it found.  Nothing about a sysroot can be a
     property of a compiler that serves many targets, so the version is supplied
     per target instead.

     0.0 is deliberately the default and is what a cross build with no target
     headers installed has always got: every consumer tests `>= some version' to
     turn NEWER behaviour on, so an unknown version turns none of it on.  That is
     the safe direction -- guessing a version we have not been told would enable
     behaviour the target's libc may not support.  */
  int glibc_major;
  int glibc_minor;

  /* powerpc only: the target C library exports AT_PLATFORM and AT_HWCAP in the
     TCB, which __builtin_cpu_supports and target_clones need.  glibc has done
     so since 2.23.  Both this and libc_gnustack below combine a triple test
     with a glibc version test, so target-specs works them out -- it is the step
     that knows both.  */
  bool libc_hwcap_in_tcb;

  /* mips only: the target C library honours PT_GNU_STACK, so a non-executable
     stack can be requested rather than inferred from -msoft-float.  musl always
     has; glibc since 2.31.  */
  bool libc_gnustack;

  /* Assembler debug/CFI capabilities.  Was the DWARF half of the
     gcc_GAS_CHECK_FEATURE block in gcc/configure.ac; see the ASSEMBLER DEBUG
     SECTION of target-specs/configure.ac.  All default true: every binutils
     GCC still builds with has had these for well over a decade, so an
     unconfigured compiler behaves like a normally configured one.  The
     original probes answered "no" for a cross build with no assembler to ask,
     which silently cost debug quality rather than failing.  */

  /* The target linker mishandles `@secrel32' relocations, so thread-local
     storage would be miscompiled (PR80881).  gcc/configure.ac used to detect
     this inside the TLS probe and AC_MSG_ERROR out of the build; that probe is
     gone, so target-specs asks the real linker and records the answer here.
     Note the polarity: true means BROKEN, so the safe default is false --
     a compiler that has not been told anything must not refuse to compile.  */
  bool ld_broken_secrel32;

  /* Assembler accepts the AIX `.ref' pseudo-op, which creates a reference to
     a DWARF table label so a garbage-collecting link keeps the frame tables
     for function bodies it kept.  Was HAVE_AS_REF, probed only in the
     `*-*-aix*' arm, so every other target already answered 0 -- which is why
     the default here is false rather than "what a modern assembler does".  */
  bool as_ref;

  /* Assembler accepts the AIX DWARF location-list section pseudo-ops
     (`.dwsect', `.vbyte').  Was HAVE_XCOFF_DWARF_EXTRAS, likewise AIX-only,
     and dwarf2out.cc already supplied 0 for everyone else.  */
  bool xcoff_dwarf_extras;

  /* Assembler resolves  in a data section, so jump tables need not be
     forced into .text.  Was HAVE_AS_GOTOFF_IN_DATA.  Both channels are
     runtime expressions -- i386.cc and JUMP_TABLES_IN_TEXT_SECTION in
     i386.h -- so this is the cleanest conversion in the i386 set.  */
  bool as_gotoff_in_data;

  /* Assembler encodes movq between an integer and an MMX/SSE register
     the way GCC expects.  Was HAVE_AS_IX86_INTERUNIT_MOVQ.  */
  bool as_ix86_interunit_movq;

  /* Assembler emits R_386_GOT32X relocations.  Was HAVE_AS_IX86_GOT32X.  */
  bool as_ix86_got32x;

  /* Assembler can call __tls_get_addr through the GOT, so -fno-plt TLS
     works.  Was HAVE_AS_IX86_TLS_GET_ADDR_GOT.  */
  bool as_ix86_tls_get_addr_got;

  /* Assembler emits R_X86_64_CODE_6_GOTTPOFF.  Was
     HAVE_AS_R_X86_64_CODE_6_GOTTPOFF.  */
  bool as_r_x86_64_code_6_gottpoff;

  /* Assembler accepts the Sun TLS local-dynamic PLT syntax.  Was
     HAVE_AS_IX86_TLSLDMPLT.  Defaults false: this is Solaris-as syntax,
     and auto-host.h answered 0 for GNU as.  */
  bool as_ix86_tlsldmplt;

  /* Assembler accepts the Sun TLS local-dynamic syntax.  Was
     HAVE_AS_IX86_TLSLDM.  Defaults false for the same reason.  */
  bool as_ix86_tlsldm;

  /* Assembler mnemonics and prefixes the i386 back end emits, all formerly
     `#ifdef HAVE_AS_IX86_*' guards around a fallback that hand-encodes the
     instruction.  Each guarded both arms of a C body, so every one converts to
     an ordinary `if'; none is a spec string or an existence test.

     Defaults follow what auto-host.h answered for GNU as, not a blanket
     assumption: the two Sun-assembler syntaxes are false.  */
  bool as_ix86_sahf;
  bool as_ix86_ud2;
  bool as_ix86_filds;
  bool as_ix86_fildq;
  bool as_ix86_hle;
  bool as_ix86_rep_lock_prefix;
  bool as_ix86_ffreep;
  bool as_ix86_tlsgdplt;
  bool as_ix86_cmov_sun_syntax;

  /* Assembler takes `-relax', and the linker relaxes tail calls into branch-
     always.  Was HAVE_AS_RELAX_OPTION.  Only the codegen half is a runtime
     value: the spec half (ASM_RELAX_SPEC) is a string baked into the driver's
     built-in specs before any target config is read, so it uses the spelling
     every supported assembler accepts and is overridden from the spec file if
     that is ever wrong.  */
  bool as_relax_option;

  /* Assembler accepts an offsetable %lo(), i.e. `%lo(sym + N)' and
     `%lo(sym) + N' assemble the same.  Was HAVE_AS_OFFSETABLE_LO10, reached
     through sparc.h's USE_AS_OFFSETABLE_LO10; both its consumers are ordinary
     runtime conditions in sparc.cc and neither appears in any .md.  */
  bool as_offsetable_lo10;

  /* Assembler accepts .gnu_attribute.  Was HAVE_AS_GNU_ATTRIBUTE, probed
     separately in the powerpc, mips, msp430 and s390 arms of the big
     `case "$target"' -- four copies of the same test, because each port
     wanted it and the probe was written per arm.  One capability now.

     config/vxworks.h used to #undef it, because the diab linker cannot handle
     .gnu_attribute sections; a runtime value cannot be #undef'd, so a VxWorks
     target must emit `as_gnu_attribute 0' from target-specs instead.  */
  bool as_gnu_attribute;

  /* Assembler accepts .cfi_startproc and friends, and encodes cfi advances
     correctly.  Was HAVE_GAS_CFI_DIRECTIVE, which seeded flag_dwarf2_cfi_asm
     through Init() in common.opt.  Init() needs a compile-time constant, so
     the option initialises to 1 and toplev re-seeds it from this once the
     target config has been read, unless the user passed -fdwarf2-cfi-asm or
     -fno-dwarf2-cfi-asm.  That is the shape dwarf2out_do_cfi_asm() already
     expected.  */
  bool cfi_directive;

  /* Assembler accepts .cfi_personality.  Was
     HAVE_GAS_CFI_PERSONALITY_DIRECTIVE.  */
  bool cfi_personality;

  /* Assembler accepts .cfi_sections.  Was HAVE_GAS_CFI_SECTIONS_DIRECTIVE,
     whose probe carried a `case $target_os' checking that PE targets got the
     right .debug_frame relocation (fixed in binutils 2.21).  */
  bool cfi_sections;

  /* Assembler accepts the is_stmt sub-directive of .loc.  Was
     HAVE_GAS_LOC_STMT.  */
  bool gas_loc_stmt;

  /* Assembler accepts the discriminator sub-directive of .loc.  Was
     HAVE_GAS_DISCRIMINATOR, which defaults.h turned into
     SUPPORTS_DISCRIMINATOR.  */
  bool gas_discriminator;

  /* Assembler tolerates `# 0 "" 2' line markers.  Was HAVE_AS_LINE_ZERO.  */
  bool as_line_zero;

  /* Assembler supports dwarf2 .file/.loc and preserves file table indices
     exactly as given.  Was HAVE_AS_DWARF2_DEBUG_LINE, which combined a
     debug_line probe with a "buggy .file" probe.  dwarf2out.cc derives
     DWARF2_ASM_LINE_DEBUG_INFO from this.  */
  bool dwarf2_debug_line;

  /* Assembler supports views in .loc directives.  Was
     HAVE_AS_DWARF2_DEBUG_VIEW; its probe also required leb128, since the test
     emits .uleb128 of a view symbol.  Feeds DWARF2_ASM_VIEW_DEBUG_INFO.  */
  bool dwarf2_debug_view;

  /* Linker capabilities.  Was the gcc_cv_ld_* half of the configure probes;
     see the LINKER SECTION of target-specs/configure.ac, which now asks the
     real linker rather than deciding from its version number or from a
     `case $target' listing which vendor linker was known to qualify.

     The defaults below split into two groups.  Features every current GNU ld
     has default true, so an unconfigured compiler behaves like a normally
     configured one.  Features that were target-specific in the original --
     the PowerPC, MIPS and PE ones -- default false, because there the safe
     answer is not "modern toolchain" but "assume nothing": each of them turns
     on a codegen shortcut that is wrong if the linker cannot back it up,
     whereas false only costs optimisation.  */

  /* Assembler and linker both handle .hidden.  Was HAVE_GAS_HIDDEN, the one
     capability needing both halves; the linker half is probed here and the
     assembler half by the assembler section of the same script.  */
  bool gas_hidden;

  /* Linker merges read-only and read-write input sections of the same name
     into a read-write output section.  Was HAVE_LD_RO_RW_SECTION_MIXING.  */
  bool ld_ro_rw_section_mixing;

  /* --gc-sections is safe in the presence of exception handling.  Was
     HAVE_LD_EH_GC_SECTIONS.  */
  bool ld_eh_gc_sections;

  /* Linker understands -z ctf.  Was HAVE_LD_CTF, which only Solaris ld
     answered yes to; false here.  */
  bool ld_ctf;

  /* Linker understands --sysroot.  Was HAVE_LD_SYSROOT.  */
  bool ld_sysroot;

  /* Linker reads GNU-style @file response files.  Was HAVE_LD_AT_FILE.  */
  bool ld_at_file;

  /* Linker supports -pie together with copy relocations, so a PIE may bind
     to a definition in a shared library by copy.  Was HAVE_LD_PIE_COPYRELOC,
     consulted by i386.  */
  bool ld_pie_copyreloc;

  /* MIPS only: linker relaxes absolute .eh_frame personality pointers into
     PC-relative form.  Was HAVE_LD_PERSONALITY_RELAXATION.  */
  bool ld_personality_relaxation;

  /* PowerPC64 ELFv1 only: linker copes with code that omits dot symbols.  Was
     HAVE_LD_NO_DOT_SYMS.  */
  bool ld_no_dot_syms;

  /* PowerPC64 only: linker supports a TOC larger than 64k.  Was
     HAVE_LD_LARGE_TOC.  */
  bool ld_large_toc;

  /* PowerPC64 only: the linker forces .TOC. to 8-byte alignment.  Was
     POWERPC64_TOC_POINTER_ALIGNMENT, which was a byte count rather than a
     flag; the only two values it ever took were 8 (linker guarantees it) and
     4, so it is a flag here and the byte count is recovered in defaults.h.  */
  bool ld_toc_align;

  /* PowerPC only: linker understands .gnu.attributes for long double.  Was
     HAVE_LD_PPC_GNU_ATTR_LONG_DOUBLE.  */
  bool ld_ppc_attr;

  /* PE only: this linker's default script puts .debug_loclists and
     .debug_rnglists where DWARF 5 output is unusable, so DWARF 5 must not be
     the default.  Was HAVE_LD_BROKEN_PE_DWARF5.  Note the sense: true means
     broken.  */
  bool ld_broken_pe_dwarf5;

  /* AVR only.  The linker's default script for the avrxmega3 emulation leaves
     .rodata in flash, so avr-gcc can skip __do_copy_data for it; and the
     avrxmega2_flmap / avrxmega4_flmap emulations exist at all.  Were
     HAVE_LD_AVR_AVRXMEGA3_RODATA_IN_FLASH, HAVE_LD_AVR_AVRXMEGA2_FLMAP and
     HAVE_LD_AVR_AVRXMEGA4_FLMAP, decided from the linker's version string
     (2.29 and 2.42 respectively).  False by default for the same reason as
     the PowerPC entries: claiming an emulation the linker does not have
     turns a clean diagnostic into a link failure.  */
  bool ld_avr_avrxmega3_rodata_in_flash;
  bool ld_avr_avrxmega2_flmap;
  bool ld_avr_avrxmega4_flmap;

  /* Linker understands -z now and -z relro.  Were HAVE_LD_NOW_SUPPORT and
     HAVE_LD_RELRO_SUPPORT, both already consumed with a runtime `if' rather
     than an #ifdef, so only the value had to move.  */
  /* Linker accepts `-pie'.  Was HAVE_LD_PIE, which had NO definition anywhere
     -- not configure.ac, not config.in, not auto-host.h -- while three
     preprocessor sites still tested it, so it was a silent 0.  See gcc.cc and
     opts.cc.  The spec text LD_PIE_SPEC stays a compile-time constant; only
     the guards are runtime.  */
  bool ld_pie;

  bool ld_now;
  bool ld_relro;

  /* Linker takes -plugin, so LTO can use the linker plugin rather than
     needing fat objects.  Was HAVE_LTO_PLUGIN, which counted 0/1/2 to
     distinguish gold 2.20's "only with -fuse-linker-plugin"; that middle case
     was a judgement about one obsolete linker and is not reproduced.  */
  bool lto_plugin;

  /* Linker demangles C++ symbols in its own diagnostics.  Was
     HAVE_LD_DEMANGLE.  Note the sense of its uses in collect2.cc: they are
     `#ifndef', because when the linker cannot demangle, collect2 does it
     instead and suppresses the linker's attempt via COLLECT_NO_DEMANGLE.
     False by default -- collect2 demangling is always correct, whereas
     delegating to a linker that turns out not to demangle loses the symbol
     names from every diagnostic.  */
  bool ld_demangle;

  /* aarch64 back-end assembler capabilities.  These were the HAVE_AS_* macros
     the aarch64 arm of the `case $target' assembler checks in gcc/configure.ac
     produced.  All default true: every binutils GCC still builds against has
     had them for years, and the original probes answered "no" whenever there
     was no assembler to ask -- quietly costing code quality on a cross build
     rather than failing.

     as_aarch64_mabi has a spec half as well; see ASM_MABI_SPEC in
     config/aarch64/aarch64-elf.h.  */
  bool as_aarch64_mabi;
  bool as_aarch64_small_pic_relocs;
  bool as_aarch64_aeabi_build_attributes;

  /* mips back-end assembler capabilities, from the mips arm of the same
     `case $target'.  True by default for the same reason as the aarch64 group:
     the probes answered "no" when there was no assembler to ask.

     HAVE_AS_NO_SHARED was spec-only: a spec cannot be a runtime test, so it
     needed no field at all, just a sensible default in the spec text.  */
  bool as_mips_nan;
  bool as_mips_micromips;
  bool as_mips_dspr1_mult;

  /* riscv back-end assembler capabilities.  True by default, as above.
     Every one of these gates a "skip this extension because older binutils
     does not know it" flag in common/config/riscv/riscv-common.cc, so true
     means "assembler is current, emit the extension normally" -- which is what
     the probe produced against any assembler new enough to matter.

     as_riscv_misa_spec has a spec half as well; see ASM_MISA_SPEC in
     config/riscv/riscv.h.  */
  bool as_riscv_attribute;
  bool as_riscv_misa_spec;
  bool as_riscv_march_zifencei;
  bool as_riscv_march_zaamo_zalrsc;
  bool as_riscv_march_b;

  /* The linker for this target is Sun ld rather than GNU ld.  Was
     HAVE_SOLARIS_LD, which has been silently 0 everywhere since the probe was
     removed, so every Solaris configuration has been behaving as if it linked
     with GNU ld.

     Only the constructor/destructor half of the old macro is carried here.
     Sun ld does not coalesce .ctors.N/.dtors.N, so with it every constructor
     must go into a single .ctors and the priority ordering GNU ld would have
     given us is not available; config/sol2.cc dispatches on this.  The other
     thirteen HAVE_SOLARIS_LD consumers are spec string literals
     (LD_WHOLE_ARCHIVE_OPTION, RDYNAMIC_SPEC, ...) and belong to target-specs,
     not here.

     False -- GNU ld -- is deliberately the default: it is what every Solaris
     build has silently been getting, so this records today's behaviour rather
     than changing it, and a compiler told nothing about its linker keeps the
     priority sections that are correct for the linker most people use.  */
  bool solaris_ld;
};

extern struct target_caps targ_caps;

/* True if the target's GNU C Library is known to be at least MAJOR.MINOR.
   An unknown version (0.0) is never "at least" anything, so callers that use
   this to enable newer behaviour leave it off until they are told otherwise.  */
inline bool
targ_glibc_at_least (int major, int minor)
{
  return (targ_caps.glibc_major > major
	  || (targ_caps.glibc_major == major
	      && targ_caps.glibc_minor >= minor));
}

/* Read capabilities from FILE, a `name value' per line text file.  Unknown
   names are ignored, so an older compiler tolerates a newer spec file.  */
extern void read_target_caps (const char *file);

#endif /* GCC_TARGET_CAPS_H */
