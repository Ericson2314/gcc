/* THE SEMANTIC ARM.  PRINCIPLES records that "emits assembly, a real
   assembler accepts it, right ELF machine" PASSED on riscv64 code that was
   32-bit -- `sw' for the return address, `.cfi_offset 1, -4', `sll'/`srai' on
   a 64-bit `long', in an ELF64 object.  A target's own assembler validates
   SYNTAX FOR A MACHINE; it has nothing to say about the compiler having
   meant a different machine.

   So this file asks the compiler, in the only way that needs no per-target
   knowledge in the scorer and no assembler at all, what it believes this
   target's word size to be.  Each object's SIZE is the answer, and it appears
   in the emitted `.s' as an ordinary assembler directive -- `.comm sym,N,A'
   or `.size sym, N' -- which is target-neutral TEXT.  Two consequences worth
   stating:

   - it works for a back end that only emits at `-O0', and for one with no
     cross assembler anywhere (sparc, ia64, visium, xtensa), where every other
     semantic instrument this project has is unavailable;
   - it is independent of codegen QUALITY.  A back end can emit a wrong
     instruction and still be asked this question, and a back end that gets
     this wrong is wrong about the target itself, not about one pattern.

   `mt_shift' is kept for the eyeball arm: it is the exact function whose
   riscv output was 32-bit, so the assembly can be read beside the size.  */

char mt_word_long[sizeof (long)];
char mt_word_ptr[sizeof (void *)];
char mt_word_int[sizeof (int)];
char mt_word_short[sizeof (short)];

long mt_shift (long a, int n) { return (a << n) | (a >> 1); }
