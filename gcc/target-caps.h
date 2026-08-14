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

  /* This configuration emits VMS Debug information alongside DWARF: it changes
     the DWARF 5 line-table file-entry format (adding DW_LNCT_timestamp and
     DW_LNCT_size), adds DW_AT_VMS_rtnbeg_pd_address to subprogram DIEs, and
     emits the VMS debug main pointer DIE.  Was VMS_DEBUGGING_INFO in tm.h,
     defined only by config/alpha/vms.h and config/ia64/vms.h.

     PER CONFIGURATION, NOT PER BACK END, and that is why it lives here rather
     than in targetm.  config/alpha serves five triple families and only
     alpha*-dec-*vms* includes vms.h, so one alpha back end needs both answers;
     a per-back-end hook table cannot express that.  It is one of at least 905
     macros measured to vary between triples of a single back end.

     Default false: a compiler that has not been told it is targeting VMS must
     emit ordinary DWARF.  Guessing true would corrupt the line table for every
     other target, and the failure would be silent -- consumers would read the
     two extra format pairs as file entries.  */
  bool vms_debug;

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

  /* The former `--enable-sjlj-exceptions' configure switch, per target.
     THREE-STATE, and -1 is a real answer rather than a missing one:

       -1  not configured -- do not force anything; the back end decides the
	   unwind model from its own target state, which is what happens when
	   the switch is not given.
	0  configured as `=no'.
	1  configured as `=yes' -- force setjmp/longjmp.

     Only `1' changes behaviour.  Upstream defined CONFIG_SJLJ_EXCEPTIONS only
     when the switch was given and every consumer tests `if (CONFIG_...)', so
     `=no' and "not given" were already indistinguishable in the compiler.  The
     0/-1 split is kept because the switch genuinely accepts `=no' and folding
     that into "unset" would discard something the user said, but nothing reads
     the distinction today -- do not build on it without adding a consumer.

     It has to be per target because the override was GLOBAL: in a build with
     arm and i386, one `--enable-sjlj-exceptions' forced sjlj for BOTH, with no
     way to name a single target.  A target-side knob with no target.  */
  int sjlj_exceptions;

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

  /* Assembler's `.lcomm' takes a third operand giving the alignment.  Was
     HAVE_GAS_LCOMM_WITH_ALIGNMENT, which gated whether i386/bsd.h defined
     ASM_OUTPUT_ALIGNED_LOCAL at all.

     Note this one could NOT be converted by a defaults.h bridge: its consumer
     tested it with `#ifdef' to decide whether a target macro EXISTS, and a
     runtime value cannot appear on a `#if' line.  The macro is now defined
     unconditionally and varasm.cc branches on this field at the call site,
     where `rounded' is in scope for the unaligned fallback -- so the fallback
     is textually the same code the `#else' arm used to run.  */
  bool gas_lcomm_with_alignment;

  /* Assembler supports `.cv_ucomp' / `.cv_scomp', the CodeView compressed
     integer directives.  Was HAVE_GAS_CV_UCOMP.  Unlike the rest of this
     group its consumers are in dwarf2codeview.cc -- generic code, no target
     header -- so this one converts to a real runtime branch with no dependence
     on which target is primary.  */
  bool gas_cv_ucomp;

  /* Assembler supports the `.base64' directive, which lets long strings be
     emitted far more compactly.  Was HAVE_GAS_BASE64, whose only role was to
     decide whether elfos.h defined BASE64_ASM_OP; varasm.cc then tested that
     macro's existence.  BASE64_ASM_OP is unconditional now and this field is
     the real question.  */
  bool gas_base64;

  /* Assembler accepts the SHF_EXCLUDE section flag -- `e' in the ELF and PE
     flag strings, `,#exclude' in sparc's syntax.  Was HAVE_GAS_SECTION_EXCLUDE,
     whose probe folded both spellings.  Read by varasm.cc, sparc.cc, and
     mingw/winnt.cc, which emits `n' (never-load) instead when it is absent --
     the two winnt.cc sites were complementary `#if's and are now the two arms
     of one runtime test, so they cannot disagree.  */
  bool gas_section_exclude;

  /* Assembler supports the SHF_GNU_RETAIN section flag (`R' in the flag
     string), which keeps a section from being garbage-collected.  Was
     HAVE_GAS_SHF_GNU_RETAIN.  defaults.h folds this with the target's
     .init_array support into SUPPORTS_SHF_GNU_RETAIN; avr/elf.h overrides that
     to this field alone, and no longer has to include auto-host.h to do it.  */
  bool gas_shf_gnu_retain;

  /* Assembler has `.balign' and `.p2align' (and `.balignw').  Was
     HAVE_GAS_BALIGN_AND_P2ALIGN.  i386/gas.h picks the mnemonic with it;
     m68k.h emits a nop-filled `.balignw' or falls back to ASM_OUTPUT_ALIGN,
     which is what final.cc's macro-existence cascade used to reach.  */
  bool gas_balign_and_p2align;

  /* Assembler takes the max-skip form `.p2align LOG,,MAX', so -falign-*
     padding can be bounded.  Was HAVE_GAS_MAX_SKIP_P2ALIGN, which five target
     headers used to gate the DEFINITION of ASM_OUTPUT_MAX_SKIP_ALIGN; final.cc
     chose between that, ASM_OUTPUT_ALIGN_WITH_NOP and ASM_OUTPUT_ALIGN purely
     by which macros existed.  The macros are unconditional now and final.cc
     makes the choice, which keeps the fallback exact -- the max-skip arm emits
     two directives where the others emit one.  */
  bool gas_max_skip_p2align;

  /* Assembler accepts `.weak'.  Was HAVE_GAS_WEAK.  Note the split it forced
     into the open: SUPPORTS_WEAK "must be a preprocessor constant" and asks
     whether the TARGET has a spelling for a weak symbol, while
     TARGET_SUPPORTS_WEAK "can be any valid C expression" -- so this belongs in
     the second, and defaults.h ANDs it there.  Target headers that used to gate
     their ASM_WEAKEN_* definitions on the probe now define them
     unconditionally.  */
  bool gas_weak;

  /* Assembler accepts `.weakref'.  Was HAVE_GAS_WEAKREF.  Kept distinct from
     the new TARGET_USE_WEAKREF policy macro: pa/som.h does not want .weakref
     even though gas there accepts it, and it used to say so by pretending the
     capability was missing.  */
  bool gas_weakref;

  /* Assembler has working `.subsection -1' / `.previous', so a jump table can
     be parked at the start of the current section.  Was
     HAVE_GAS_SUBSECTION_ORDERING.  sparc uses it twice: to bracket address
     vectors, and -- the only case in this group where a capability reaches code
     GENERATION rather than an output spelling -- to pick CASE_VECTOR_MODE,
     since without it a pic jump table needs DImode to avoid a sign extend.  */
  bool gas_subsection_ordering;

  /* Assembler supports dwarf2 .file/.loc and preserves file table indices
     exactly as given.  Was HAVE_AS_DWARF2_DEBUG_LINE, which combined a
     debug_line probe with a "buggy .file" probe.  dwarf2out.cc derives
     DWARF2_ASM_LINE_DEBUG_INFO from this.  */
  bool dwarf2_debug_line;

  /* Assembler supports views in .loc directives.  Was
     HAVE_AS_DWARF2_DEBUG_VIEW; its probe also required leb128, since the test
     emits .uleb128 of a view symbol.  Feeds DWARF2_ASM_VIEW_DEBUG_INFO.  */
  bool dwarf2_debug_view;

  /* Assembler supports SHF_MERGE section flags (`.section .rodata.str1.1,
     "aMS",@progbits,1').  Was HAVE_GAS_SHF_MERGE, whose probe folded the
     `%progbits' spelling in.  Read by varasm.cc and dwarf2out.cc, both in
     value position, so this needs no consumer change.  */
  bool gas_shf_merge;

  /* Assembler supports the `o' section flag, linking one section's lifetime
     to another (`.section .foo,"ao",@progbits,.bar').  Was
     HAVE_GAS_SECTION_LINK_ORDER, read by targhooks.cc in value position.  */
  bool gas_section_link_order;

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

  /* alpha back-end assembler capabilities.

     as_alpha_explicit_relocs and as_loongarch_explicit_relocs below were ONE
     MACRO, `HAVE_AS_EXPLICIT_RELOCS', AC_DEFINEd from two different arms of
     gcc/configure.ac by two different probes.  Only one arm could run, and
     loongarch-opts.h floored the name with `#ifndef' -- so an alpha-primary
     build gave loongarch alpha's assembler answer, silently and with no link
     error, which is this project's failure mode in one macro.  Two names, two
     answers; the prefix is what makes the collision impossible rather than
     merely absent.

     as_alpha_explicit_relocs carries what TARGET_DEFAULT_EXPLICIT_RELOCS and
     TARGET_SUPPORT_ARCH used to: it sets MASK_EXPLICIT_RELOCS as a default in
     alpha_option_init_struct, and it decides whether alpha_file_start emits a
     `.arch' directive.  TARGET_DEFAULT_TARGET_FLAGS could not carry it -- that
     is a static initializer, the same wall the mips `Init (...)' case hit.  */
  bool as_alpha_explicit_relocs;
  bool as_alpha_jsrdirect_relocs;

  /* mips back-end assembler capabilities, from the mips arm of the same
     `case $target'.  True by default for the same reason as the aarch64 group:
     the probes answered "no" when there was no assembler to ask.

     HAVE_AS_NO_SHARED was spec-only: a spec cannot be a runtime test, so it
     needed no field at all, just a sensible default in the spec text.  */
  bool as_mips_nan;
  bool as_mips_micromips;
  bool as_mips_dspr1_mult;

  /* Assembler takes `.module'.  TWO consumers of one answer, and they are not
     alternatives: mips.cc emits `.module' directives when it is true and the
     older `.gnu_attribute 4, N' encoding when it is false, and mips.h's
     FP_ASM_SPEC hands -mhard-float and its three companions to the assembler
     only when it is true.  Passing -msoft-float to an assembler too old for
     `.module' makes it reject every hard-float instruction, which is why the
     spec was gated at all.  Both halves are written from this one field; the
     spec half is the *asm_fp_module spec.  */
  bool as_mips_dot_module;

  /* Assembler takes the `%gp_rel(sym)' explicit relocation operators, and the
     newer `%pcrel_hi'/`%pcrel_lo' pair.  These two decide the DEFAULT of
     -mexplicit-relocs=, which used to be MIPS_EXPLICIT_RELOCS, an AC_DEFINE
     reaching mips.opt through tm_defines and used as `Init (...)'.

     THAT IS A FOURTH WAY A PROBE ANSWER GETS CONSUMED, beside spec text, a C
     variable and a %(name) reference: the `Init (...)' of a .opt file, which
     becomes a STATIC INITIALIZER in generated options.cc.  It has two
     properties that make it the worst of the four to migrate.  A static
     initializer needs a constant expression, so it cannot read this struct at
     all -- the default has to be applied later, by the common
     option_init_struct hook, which runs before the command line is decoded and
     so still loses to an explicit -mexplicit-relocs=.  And when the macro goes
     missing the failure lands in GENERATED code: `options.cc:4024: error:
     MIPS_EXPLICIT_RELOCS was not declared', a file nobody edited, naming
     nothing that suggests a configure probe.  Any other probe whose answer
     reaches a .opt file has the same shape and is worth sweeping for.

     TWO BOOLS RATHER THAN ONE ENUM, and the enum is derived from them in
     common/config/mips/mips-common.cc.  They are two separate assembler
     questions with two separate answers, and this struct records what the
     assembler said; turning that into NONE/BASE/PCREL is a decision, and a
     decision belongs with the back end that has the enum.  Storing the derived
     value here would also make it possible for it to disagree with the pair.

     True by default, like the three above and for the same reason -- a modern
     GNU assembler has both, and the probes answered "no" only when there was
     nothing to ask.  Note the asymmetry, because it is the reason this is worth
     a sentence: a wrong "yes" here produces assembler errors, while a wrong
     "no" only costs optimisation.  It is tolerable because a compiler in this
     tree refuses to run at all without a target-config file, so these defaults
     are reachable only from a config file written by an OLDER target-specs
     that did not have these keys -- and that file's other mips answers would be
     equally stale.  */
  bool as_mips_explicit_relocs;
  bool as_mips_explicit_relocs_pcrel;

  /* Assembler and linker between them implement the explicit R_MIPS_JALR
     relocation, so the linker can relax an indirect call through $25 into a
     direct branch.  Was gcc_cv_as_ld_jalr_reloc in gcc/configure.ac, which
     OR'd MASK_RELAX_PIC_CALLS into target_cpu_default -- i.e. into
     TARGET_DEFAULT_TARGET_FLAGS, a DEFHOOKPOD, which must be a constant and
     therefore cannot read this struct either.  Applied in the same
     option_init_struct hook.

     This half was the SILENT one.  With the probe gone, `test
     $gcc_cv_as_mips_explicit_relocs = yes' tested an unset variable, so the
     JALR probe answered "no" whatever the toolchain could do, and the only
     symptom was slightly worse code.  The loud half -- the missing
     MIPS_EXPLICIT_RELOCS breaking generated options.cc -- is what got anyone's
     attention, and the two came from removing one probe.  */
  bool as_ld_mips_jalr_reloc;

  /* loongarch back-end assembler capabilities.  The assembler takes -mrelax at
     all, and it relaxes CONDITIONAL BRANCHES.  Read as a PAIR: linker
     relaxation needs both, and the driver spec that hands -mrelax to the
     assembler needs the first.

     These were HAVE_AS_MRELAX_OPTION and HAVE_AS_COND_BRANCH_RELAXATION, probed
     in gcc/configure.ac INSIDE `case $target in loongarch*-*-*)' -- so the
     probes ran only when loongarch was the target GCC itself was configured
     for.  A probe scoped by `case $target' is structurally incompatible with a
     compiler that has no privileged target: for every other build the macros
     were undefined, loongarch-opts.h's `#ifndef' floors made them 0, and
     loongarch silently stopped passing -mrelax to its assembler and stopped
     defaulting linker relaxation on.  Nothing failed, because the floors are
     what turn a missing definition into a wrong answer.

     True by default, as with the other back-end assembler groups: a current GNU
     assembler has both, and the probes answered "no" only when there was
     nothing to ask.  */
  bool as_loongarch_explicit_relocs;
  bool as_loongarch_relax;
  bool as_loongarch_cond_branch_relax;

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

  /* The 2026-08-11 sweep out of gcc/configure.ac.  Each was an AC_DEFINE that
     only existed when its own back end happened to be the configured target,
     so on every other build the macro was undefined and the back end compiled
     its "assembler cannot do this" arm -- silently, and for reasons that had
     nothing to do with the assembler in front of it.

     DEFAULTS ARE false HERE, unlike the optimistic assembler defaults above,
     and the difference is deliberate: those describe features every modern gas
     has, so `true' is the better guess for a compiler told nothing.  These
     have been OFF for essentially every build, because the floors in the
     target headers supplied 0.  Defaulting them true would turn features on
     for an unprobed toolchain that has never had them, which is a worse
     failure than leaving a capable assembler underused.  */
  bool as_entry_markers;		/* HAVE_AS_ENTRY_MARKERS  */
  bool as_mfcrf;			/* HAVE_AS_MFCRF  */
  bool as_power10_htm;			/* HAVE_AS_POWER10_HTM  */
  bool as_rel16;			/* HAVE_AS_REL16  */
  bool as_pltseq;			/* HAVE_AS_PLTSEQ  */
  bool as_mspabi_attribute;		/* HAVE_AS_MSPABI_ATTRIBUTE  */
  bool as_mmacosx_version_min;	  /* HAVE_AS_MMACOSX_VERSION_MIN_OPTION  */
  bool as_macos_build_version;		/* HAVE_AS_MACOS_BUILD_VERSION  */
  bool gas_literal16;			/* HAVE_GAS_LITERAL16  */
  bool gas_nsubspa_comdat;		/* HAVE_GAS_NSUBSPA_COMDAT  */
  bool gas_arm_extended_arch;		/* HAVE_GAS_ARM_EXTENDED_ARCH  */

  /* loongarch.  Upstream spelled these HAVE_AS_SUPPORT_CALL36,
     HAVE_AS_TLS_LE_RELAXATION, HAVE_AS_16B_ATOMIC and
     HAVE_AS_EH_FRAME_PCREL_ENCODING_SUPPORT -- names with no back end in them,
     which is how loongarch came to read alpha's answer for the neighbouring
     explicit-relocs probe.  The names here say whose question it is.  */
  bool as_loongarch_support_call36;
  bool as_loongarch_tls_le_relaxation;
  bool as_loongarch_16b_atomic;
  bool as_loongarch_eh_frame_pcrel_encoding;

  /* ia64.  Assembler understands the @ltoffx relocation and the ld8.mov
     spelling that goes with it.  Was HAVE_AS_LTOFFX_LDXMOV_RELOCS.

     ITS TWO READERS ARE IN ia64.md, AND THAT IS WHY THIS FIELD WAS MISSING FOR
     SO LONG.  defaults.h has defined HAVE_AS_LTOFFX_LDXMOV_RELOCS over this
     name since the sweep, and `*load_symptr_high' and `*load_symptr_low' expand
     it -- but they are OUTPUT TEMPLATES, compiled into insn-output.cc, so the
     macro is only expanded in a build that enables ia64.  No such build exists
     in this tree, so a struct with no such field compiled cleanly and the
     defect sat behind a back end nobody configures: `--enable-backends' with
     ia64 in it would have failed to compile, naming defaults.h rather than
     anything ia64.  check-target-caps.sh could not see it either -- its
     read-direction arm reads config files, and no config file carries a key
     nothing emits.

     Not an insn CONDITION, which matters: a condition would be folded by
     gencondmd at build time and the run-time answer could never reach it.  An
     output template is ordinary C++ in cc1, so this really is a capability.

     false, like the rest of this sweep, and here the default is exactly what
     the floor in ia64.h supplied for every build that was not configured for
     ia64.  */
  bool as_ltoffx_ldxmov_relocs;		/* HAVE_AS_LTOFFX_LDXMOV_RELOCS  */

  /* s390.  as_s390_machine_machinemode is deliberately absent: its consumer
     S390_USE_TARGET_ATTRIBUTE selects SWITCHABLE_TARGET with `#if', which
     cannot be a run-time answer.  See target-specs/configure.ac.  */
  bool as_s390_architecture_modifiers;
  bool as_s390_vector_loadstore_alignment_hints;
  bool as_s390_vector_loadstore_alignment_hints_on_z13;

  /* Assembler needs --traditional-format.  Was USE_AS_TRADITIONAL_FORMAT, read
     by gcc.cc's init_spec, which is to say by the DRIVER: a driver built for
     any other target could never prepend the flag, whatever it was asked to
     compile for.  */
  bool use_as_traditional_format;

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

  /* --- STRING-VALUED CAPABILITIES ------------------------------------------
     These are the first non-bool fields in this struct, so read this before
     adding another.  Three rules, each of which has a reason:

     1. NEVER NULL.  A string capability is always a valid C string; "not
	supported" is spelled "".  Every consumer either indexes [0] or hands
	the pointer to something that will dereference it, and a NULL that only
	appears on an unusual target is the kind of thing that is found by a
	segfault on someone else's machine.  read_target_caps enforces this:
	a line with no value sets "", never NULL.
     2. THE DEFAULT IS A STRING LITERAL, the replacement is xstrdup'd, and the
	old value is never freed.  There is exactly one config file per run and
	the strings live as long as the process, so a free would have to
	distinguish literal from heap for no benefit.  Same discipline as
	targ_caps_target_name below.
     3. DERIVE PREDICATES, DO NOT STORE THEM.  targ_ld_static_dynamic () below
	is computed from these two rather than being a third field, because a
	stored `has the pair' bit is a value that can disagree with the pair --
	which is this project's signature bug.  If you find yourself adding a
	bool that answers a question about a string, derive it instead.  */

  /* The linker's spellings of "link the libraries from here on statically"
     and "go back to preferring shared".  GNU ld spells them -Bstatic and
     -Bdynamic; AIX ld uses -bstatic/-bdynamic and HP-UX ld
     -aarchive_shared/-adefault, which is the whole reason these cannot be a
     compile-time constant in a driver that serves many targets.

     Both are used from BOTH kinds of consumer, and that is why they are here
     as well as in the spec file:

       spec TEXT  -- the sanitizer link specs in gcc.cc and in the target
		     headers, through the %(link_static)/%(link_dynamic) named
		     specs that target-specs writes from the same probe;
       C CODE     -- the seven language driver programs (g++spec.cc,
		     gfortranspec.cc, gospec.cc, d-spec.cc, gm2spec.cc,
		     a68spec.cc, gcobolspec.cc), which call
		     `append_option (OPT_Wl_, ..., 1)' and cannot read a spec.

     One probe, two carriers.  The carriers are unavoidable -- a spec cannot
     read a variable and append_option cannot read a spec -- but they must not
     be two answers, so target-specs writes both from one probe of one linker.

     Empty means the linker has no such pair at all, and every consumer must
     then omit the option rather than pass an empty one; see
     targ_ld_static_dynamic ().  */
  const char *ld_static_option;
  const char *ld_dynamic_option;

  /* WHERE THIS TARGET'S C++ HEADERS LIVE.  Formerly the configure options
     --with-gxx-include-dir and --with-gxx-libcxx-include-dir, i.e. one string
     baked into the compiler.  They are include SEARCH PATHS into a libstdc++
     or libc++ INSTALLATION -- a fact about the toolchain gcc has been pointed
     at, not about the machine gcc runs on -- so a compiler serving 188 targets
     has 188 answers and cannot hold them in a compile-time constant.

     Read by cppdefault.cc, which is linked into cc1.  That is why they are
     here and NOT named specs: the driver's spec file never reaches cc1, and
     the include chain is built inside cc1.

     "" means this target has no such directory and the entry is dropped from
     the search path entirely -- see rule 1 above; the empty case is the one
     that matters, and cppdefault.cc compacts rather than searching "".

     The defaults are the installation-relative paths gcc/Makefile.in computes
     ($(libsubdir)/$(libsubdir_to_prefix)include/c++/$(version) and friends),
     reaching this file as the GPLUSPLUS_* macros in PREPROCESSOR_DEFINES, so
     a compiler told nothing about its target searches what it always did.

     There is deliberately no add_sysroot companion: gcc has no --with-sysroot
     any more, so the two flags these replace were unconditionally 0 with
     nothing able to set them.  Add one when target-specs can actually probe a
     per-target sysroot -- do not resurrect a constant.  */
  const char *gxx_include_dir;
  const char *gxx_tool_include_dir;
  const char *gxx_backward_include_dir;
  const char *gxx_libcxx_include_dir;

  /* WHERE THIS TARGET'S FIXINCLUDES-FIXED SYSTEM HEADERS LIVE.  Formerly the
     compile-time -DFIXED_INCLUDE_DIR="$(libsubdir)/include-fixed", written by
     gcc's own build, which also ran fixincludes once and put the result there.

     Both were wrong for the same reason.  fixincludes patches the actual
     system headers of ONE machine -- `fixincl' fnmatches TARGET_MACHINE
     against each hack's `mach' glob at run time, and 137 of 252 hacks carry
     one -- so it has to be run once per target; and $(libsubdir) is
     $(libdir)/gcc/$(version), with NO target component, so one include-fixed
     under it is one directory N targets would overwrite in turn.  It is
     post-install, per-target environment adaptation, exactly like the probed
     spec files: the answer can change without rebuilding the compiler (fix the
     headers in place, point at a different sysroot) which is the test for that
     whole category.

     UNLIKE gxx_* ABOVE, THE BUILT-IN DEFAULT IS "" AND MUST STAY "".  There is
     no compile-time answer to fall back to, because there is no longer a
     compile-time directory: gcc's build does not create include-fixed.  A
     non-empty default would put a system include directory that nothing
     creates into every target's search path, silently skipped.  "" is a real
     answer meaning "this target
     has no fixed headers", and cppdefault.cc compacts the entry away.

     Written by fixincludes/mkheaders, which is the one thing that creates the
     directory, so the path in the config file and the path on disk are the
     same statement.  */
  const char *fixed_include_dir;

  /* WHERE THIS TARGET'S BINUTILS-INSTALLED SYSTEM HEADERS LIVE -- the
     "BINUTILS" entry of cppdefault.cc's table, historically the compile-time
     -DTOOL_INCLUDE_DIR=$(gcc_tooldir)/include.

     THE HOLE THIS CLOSES.  $(gcc_tooldir) was
     `$(libsubdir)/$(libsubdir_to_prefix)$(target_noncanonical)', and
     $(target_noncanonical) is unsubstituted on this branch, so the trailing
     component was EMPTY and the whole path collapsed to $(prefix) -- making
     TOOL_INCLUDE_DIR plain `/usr/include' under the default prefix.  That is
     the host's headers, entered into EVERY target's system include path, under
     no capability's control at all: it survived with gxx_tool_include_dir,
     fixed_include_dir and native_system_header_dir all set to "".  A build on a
     host with a populated /usr/include therefore compiled every target against
     the host's headers and SUCCEEDED, producing wrong code.  On a host without
     one (NixOS) the entry is merely inert, which is why it went unnoticed.

     Deliberately NOT the same key as gxx_tool_include_dir and NOT derived from
     any other: this is where a binutils installation put a target's headers,
     and a target may perfectly well use the host's C++ headers while needing
     its own binutils tree, or the reverse.

     DEFAULT "" FOR THE SAME REASON AS fixed_include_dir: there is no
     compile-time answer, because there is no compile-time target.  Any
     non-empty default would be one target's directory offered to all of them,
     which is the defect above restated.  cppdefault.cc compacts the entry
     away, so a compiler nobody has told about a tool include directory does not
     claim to have one.  Say `tool_include_dir <path>' in the target config
     (target-specs' --with-tool-include-dir) to get the entry back.  */
  const char *tool_include_dir;

  /* THIS TARGET'S NATIVE ld, nm AND strip, BY ABSOLUTE PATH -- formerly the
     tm.h macros REAL_LD_FILE_NAME, REAL_NM_FILE_NAME and REAL_STRIP_FILE_NAME
     (rs6000/aix.h says nm is /usr/ucb/nm), consulted by collect2 before its
     ordinary search.

     They were suppressed by `#ifdef CROSS_DIRECTORY_STRUCTURE #undef ...' in
     collect2.cc, i.e. by the question "am I a cross compiler?".  That question
     HAS NO COMPILE-TIME ANSWER HERE: CROSS_DIRECTORY_STRUCTURE is never defined
     any more, so the block is dead and the macros survive from whichever tm.h
     collect2 happens to include -- letting collect2 execute a path that names
     one target's native tools on a host that has no such tools, or worse, on
     behalf of a different target.

     Whether /usr/ucb/nm exists is a fact about the DEPLOYED MACHINE and can
     change without rebuilding the compiler, so it is a capability, not a hook.
     Default "" = "nothing said", and collect2 then runs its ordinary
     COMPILER_PATH/PATH search.  A non-empty value is used verbatim and must
     exist and be executable; collect2 diagnoses it by name if it does not,
     rather than falling through to another target's tools.  */
  const char *real_ld_file_name;
  const char *real_nm_file_name;
  const char *real_strip_file_name;

  /* WHERE THIS TARGET'S SITE-LOCAL AND SYSTEM HEADERS LIVE -- /usr/local/include
     and /usr/include on a typical GNU system.  Formerly the configure options
     --with-local-prefix and --with-native-system-header-dir, plus config.gcc's
     `native_system_header_dir', which is a `case $target': /usr/include for
     most, /include for cygwin and vxworks, /mingw/include for mingw,
     /dev/env/DJDIR/include for djgpp.  One triple decided it for all 188.

     NATIVE_SYSTEM_HEADER_COMPONENT is the `component' field of the same two
     entries (see update_path in prefix.cc) and is set by a target's tm.h --
     openbsd.h and i386/xm-djgpp.h.  It has to travel with the directory or the
     pair disagrees: a relocated toolchain would rewrite a prefix under a
     component that belongs to a different target's answer.

     THREE-STATE, AND UNLIKE gxx_* ABOVE THE DEFAULT IS NOT A STRING HERE.
     NULL means "the config file said nothing", and cppdefault.cc then uses the
     value compiled in.  It has to work that way round because the compile-time
     answer is not a plain Makefile string: LOCAL_INCLUDE_DIR and
     NATIVE_SYSTEM_HEADER_DIR are subject to the `#undef' that cppdefault.cc
     does under CROSS_DIRECTORY_STRUCTURE && !TARGET_SYSTEM_ROOT, and
     NATIVE_SYSTEM_HEADER_COMPONENT comes from tm.h, which this file does not
     include (target-caps.o is in libcommon.a, which collect2 links).

     "" is the third state and is a real answer: this target has no such
     directory.  The entry is dropped from the include search path entirely
     rather than searched as "" -- see rule 1 above.  For the component, ""
     means "no component", i.e. what a NULL component field has always meant.
     So a target-specs that wants to suppress /usr/include must EMIT AN EMPTY
     KEY; omitting the key leaves the built-in default in place, which is the
     opposite of what was asked and is silent.  */
  const char *local_include_dir;
  const char *native_system_header_dir;
  const char *native_system_header_component;
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

/* True if this linker has a -Bstatic/-Bdynamic pair at all, whatever it spells
   them.  This is the old HAVE_LD_STATIC_DYNAMIC, and it is a FUNCTION OF THE
   TWO STRINGS rather than a capability of its own on purpose: as a separate
   field it could say "yes" while the spellings were empty, and every consumer
   would then emit a bare `-Wl,' with no argument.  That is exactly how the
   restored `-plugin' spec nearly shipped without its file name -- connected,
   and failing worse than when it was missing.

   BOTH halves of a consumer's decision must be gated on this, not just the
   emission.  A language driver that swallows -static-libfoo (`args[i] |=
   SKIPOPT') because it intends to bracket the library, and then does not
   bracket it because the linker cannot, has silently ignored the user's
   option.  The two used to be one `#ifdef' and they must stay one test.  */

inline bool
targ_ld_static_dynamic (void)
{
  return (targ_caps.ld_static_option[0] != '\0'
	  && targ_caps.ld_dynamic_option[0] != '\0');
}

/* The target triple this configuration is for, as named by the `target' line
   of the target-config file, or NULL if no config file said.

   This is the compiler's ONLY runtime source for its own target identity, and
   that is the point: there is no built-in default triple any more, because a
   built-in default is a privileged target.  Consumers that need a back end --
   targetm_common_select, above all -- select on this and diagnose when it is
   absent rather than falling back on anything.

   It lives beside the capabilities rather than in a channel of its own because
   the target-config file is already the one thing cc1 reads that describes the
   target it was invoked for, and a second channel could disagree with it.  */
extern const char *targ_caps_target_name;

/* The same thing where a STRING is wanted unconditionally -- a diagnostic, a
   --version banner, a JSON field.  Never NULL, so a report cannot crash, and
   deliberately not a plausible-looking triple either: a compiler that has not
   selected a target says so in as many words, rather than printing something
   a reader would take for an answer.

   NOT for anything that COMPARES targets.  Two compilers that had selected
   nothing would compare EQUAL through this, and that is precisely the defect
   that made C++20 module CMIs accept one another -- see cp/module.cc.
   Comparisons must take targ_caps_target_name and treat NULL as "cannot
   answer".  */
extern const char *targ_caps_target_name_for_report (void);

/* Read capabilities from FILE, a `name value' per line text file.  Unknown
   names are ignored, so an older compiler tolerates a newer spec file.  */
extern void read_target_caps (const char *file);

#endif /* GCC_TARGET_CAPS_H */
