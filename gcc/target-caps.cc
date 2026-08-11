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

/* This lives in libcommon.a because every host binary that consults a
   capability has to resolve targ_caps: cc1 and the language front ends, the
   driver and the language spec programs via libcommon-target.a, and collect2,
   which links neither opts.o nor toplev.o.  Only cc1 calls read_target_caps;
   everything else sees the built-in defaults.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "target-caps.h"

/* Target assembler/linker capabilities.  Initialised to what a modern GNU
   toolchain supports, so a compiler invoked without a target-config file
   behaves like a normally-configured one.

   Designated rather than positional, and deliberately so: several people add
   fields to this struct, and with a positional list an insertion silently
   mis-assigns every value below it rather than failing to compile -- C++ lets
   a short initializer list value-initialise the rest.  That has already
   happened here twice.  Keep these in declaration order; C++ requires it.  */
struct target_caps targ_caps =
{
  .leb128 = true,
  .s390_excess_float_precision = false,
  .decimal_float = false,
  .decimal_bid_format = false,
  .glibc_major = 0,
  .glibc_minor = 0,
  .libc_hwcap_in_tcb = false,
  .libc_gnustack = false,
  .as_ref = false,
  .xcoff_dwarf_extras = false,
  .as_gnu_attribute = true,
  .cfi_directive = true,
  .cfi_personality = true,
  .cfi_sections = true,
  .gas_loc_stmt = true,
  .gas_discriminator = true,
  .as_line_zero = true,
  .dwarf2_debug_line = true,
  .dwarf2_debug_view = true,
  .gas_hidden = true,
  .ld_ro_rw_section_mixing = true,
  .ld_eh_gc_sections = true,
  .ld_ctf = false,
  .ld_sysroot = true,
  .ld_at_file = true,
  .ld_pie_copyreloc = true,
  .ld_personality_relaxation = false,
  .ld_no_dot_syms = false,
  .ld_large_toc = false,
  .ld_toc_align = false,
  .ld_ppc_attr = false,
  .ld_broken_pe_dwarf5 = false,
  .ld_avr_avrxmega3_rodata_in_flash = false,
  .ld_avr_avrxmega2_flmap = false,
  .ld_avr_avrxmega4_flmap = false,
  .ld_now = true,
  .ld_relro = true,
  .lto_plugin = true,
  .as_aarch64_mabi = true,
  .as_aarch64_small_pic_relocs = true,
  .as_aarch64_aeabi_build_attributes = true,
  .as_mips_nan = true,
  .as_mips_micromips = true,
  .as_riscv_attribute = true,
  .as_riscv_misa_spec = true,
  .as_riscv_march_zifencei = true,
  .as_riscv_march_zaamo_zalrsc = true,
  .as_riscv_march_b = true
};

/* Read capability settings from FILE.  Format is one `name value' pair per
   line; `#' starts a comment.  Unknown names are ignored so that a newer spec
   file does not break an older compiler.  A missing or unreadable file is not
   an error -- the built-in defaults stand.  */

void
read_target_caps (const char *file)
{
  FILE *f = fopen (file, "r");
  if (f == NULL)
    return;

  char line[256];
  while (fgets (line, sizeof (line), f) != NULL)
    {
      char name[64];
      int value;

      if (line[0] == '#' || line[0] == '\n')
	continue;
      if (sscanf (line, "%63s %d", name, &value) != 2)
	continue;

      if (strcmp (name, "leb128") == 0)
	targ_caps.leb128 = value != 0;
      else if (strcmp (name, "s390_excess_float_precision") == 0)
	targ_caps.s390_excess_float_precision = value != 0;
      else if (strcmp (name, "decimal_float") == 0)
	targ_caps.decimal_float = value != 0;
      else if (strcmp (name, "decimal_bid_format") == 0)
	targ_caps.decimal_bid_format = value != 0;
      else if (strcmp (name, "glibc_major") == 0)
	targ_caps.glibc_major = value;
      else if (strcmp (name, "glibc_minor") == 0)
	targ_caps.glibc_minor = value;
      else if (strcmp (name, "libc_hwcap_in_tcb") == 0)
	targ_caps.libc_hwcap_in_tcb = value != 0;
      else if (strcmp (name, "libc_gnustack") == 0)
	targ_caps.libc_gnustack = value != 0;
      else if (strcmp (name, "as_ref") == 0)
	targ_caps.as_ref = value != 0;
      else if (strcmp (name, "xcoff_dwarf_extras") == 0)
	targ_caps.xcoff_dwarf_extras = value != 0;
      else if (strcmp (name, "as_gnu_attribute") == 0)
	targ_caps.as_gnu_attribute = value != 0;
      else if (strcmp (name, "cfi_directive") == 0)
	targ_caps.cfi_directive = value != 0;
      else if (strcmp (name, "cfi_personality") == 0)
	targ_caps.cfi_personality = value != 0;
      else if (strcmp (name, "cfi_sections") == 0)
	targ_caps.cfi_sections = value != 0;
      else if (strcmp (name, "gas_loc_stmt") == 0)
	targ_caps.gas_loc_stmt = value != 0;
      else if (strcmp (name, "gas_discriminator") == 0)
	targ_caps.gas_discriminator = value != 0;
      else if (strcmp (name, "as_line_zero") == 0)
	targ_caps.as_line_zero = value != 0;
      else if (strcmp (name, "dwarf2_debug_line") == 0)
	targ_caps.dwarf2_debug_line = value != 0;
      else if (strcmp (name, "dwarf2_debug_view") == 0)
	targ_caps.dwarf2_debug_view = value != 0;
      else if (strcmp (name, "gas_hidden") == 0)
	targ_caps.gas_hidden = value != 0;
      else if (strcmp (name, "ld_ro_rw_section_mixing") == 0)
	targ_caps.ld_ro_rw_section_mixing = value != 0;
      else if (strcmp (name, "ld_eh_gc_sections") == 0)
	targ_caps.ld_eh_gc_sections = value != 0;
      else if (strcmp (name, "ld_ctf") == 0)
	targ_caps.ld_ctf = value != 0;
      else if (strcmp (name, "ld_sysroot") == 0)
	targ_caps.ld_sysroot = value != 0;
      else if (strcmp (name, "ld_at_file") == 0)
	targ_caps.ld_at_file = value != 0;
      else if (strcmp (name, "ld_pie_copyreloc") == 0)
	targ_caps.ld_pie_copyreloc = value != 0;
      else if (strcmp (name, "ld_personality_relaxation") == 0)
	targ_caps.ld_personality_relaxation = value != 0;
      else if (strcmp (name, "ld_no_dot_syms") == 0)
	targ_caps.ld_no_dot_syms = value != 0;
      else if (strcmp (name, "ld_large_toc") == 0)
	targ_caps.ld_large_toc = value != 0;
      else if (strcmp (name, "ld_toc_align") == 0)
	targ_caps.ld_toc_align = value != 0;
      else if (strcmp (name, "ld_ppc_attr") == 0)
	targ_caps.ld_ppc_attr = value != 0;
      else if (strcmp (name, "ld_broken_pe_dwarf5") == 0)
	targ_caps.ld_broken_pe_dwarf5 = value != 0;
      else if (strcmp (name, "ld_avr_avrxmega3_rodata_in_flash") == 0)
	targ_caps.ld_avr_avrxmega3_rodata_in_flash = value != 0;
      else if (strcmp (name, "ld_avr_avrxmega2_flmap") == 0)
	targ_caps.ld_avr_avrxmega2_flmap = value != 0;
      else if (strcmp (name, "ld_avr_avrxmega4_flmap") == 0)
	targ_caps.ld_avr_avrxmega4_flmap = value != 0;
      else if (strcmp (name, "ld_now") == 0)
	targ_caps.ld_now = value != 0;
      else if (strcmp (name, "ld_relro") == 0)
	targ_caps.ld_relro = value != 0;
      else if (strcmp (name, "lto_plugin") == 0)
	targ_caps.lto_plugin = value != 0;
      else if (strcmp (name, "as_aarch64_mabi") == 0)
	targ_caps.as_aarch64_mabi = value != 0;
      else if (strcmp (name, "as_aarch64_small_pic_relocs") == 0)
	targ_caps.as_aarch64_small_pic_relocs = value != 0;
      else if (strcmp (name, "as_aarch64_aeabi_build_attributes") == 0)
	targ_caps.as_aarch64_aeabi_build_attributes = value != 0;
      else if (strcmp (name, "as_mips_nan") == 0)
	targ_caps.as_mips_nan = value != 0;
      else if (strcmp (name, "as_mips_micromips") == 0)
	targ_caps.as_mips_micromips = value != 0;
      else if (strcmp (name, "as_riscv_attribute") == 0)
	targ_caps.as_riscv_attribute = value != 0;
      else if (strcmp (name, "as_riscv_misa_spec") == 0)
	targ_caps.as_riscv_misa_spec = value != 0;
      else if (strcmp (name, "as_riscv_march_zifencei") == 0)
	targ_caps.as_riscv_march_zifencei = value != 0;
      else if (strcmp (name, "as_riscv_march_zaamo_zalrsc") == 0)
	targ_caps.as_riscv_march_zaamo_zalrsc = value != 0;
      else if (strcmp (name, "as_riscv_march_b") == 0)
	targ_caps.as_riscv_march_b = value != 0;
    }

  fclose (f);
}
