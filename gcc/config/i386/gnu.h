/* Configuration for an i386 running GNU with ELF as the target machine.  */

/*
Copyright (C) 1994-2026 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GCC is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GCC.  If not, see <http://www.gnu.org/licenses/>.
*/

#define GNU_USER_LINK_EMULATION "elf_i386"

#undef GNU_USER_DYNAMIC_LINKER
#define GNU_USER_DYNAMIC_LINKER "/lib/ld.so"

/* i386 glibc provides __stack_chk_guard in %gs:0x14.  */
#define TARGET_THREAD_SSP_OFFSET        0x14

/* We only support -fsplit-stack on glibc targets.  This used to also require
   HAVE_GAS_CFI_PERSONALITY_DIRECTIVE, a configure-time probe; .cfi_personality
   is now a runtime capability (targ_caps.cfi_personality) and cannot be tested
   in a #if.  Every assembler GCC still builds with has it, so the glibc test
   alone stands.  */
#if (DEFAULT_LIBC == LIBC_GLIBC)
#define TARGET_CAN_SPLIT_STACK
#endif
/* We steal the last transactional memory word.  */
#define TARGET_THREAD_SPLIT_STACK_OFFSET 0x30
