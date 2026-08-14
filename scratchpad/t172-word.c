/* #172 -- is the compiler emitting code for the width it claims?
 *
 * DELIBERATELY LEAF AND CALL-FREE.  The first version of this file called an
 * external function so the frame would carry a return-address save, which is
 * what PRINCIPLES quotes for riscv (`sw', `.cfi_offset 1, -4').  Measured, that
 * source runs into TWO defects that are not this task's: riscv ICEs with a
 * segfault in `sched1', and s390's output is rejected by its own assembler
 * ("operand 2: operand out of range (-160 is not between 0 and 4095)").  Both
 * are real and both are reported; neither can be allowed to stand between this
 * task and a word-size reading, so the probe avoids the frame entirely.
 *
 * `mt_word' is the decisive arm and it needs no code generation at all: the
 * DIRECTIVE the assembler back end picks for a `long' (.quad/.dword/.8byte vs
 * .word/.4byte) and the VALUES sizeof(long)/sizeof(void*) are read straight
 * out of the target's storage layout, i.e. out of UNITS_PER_WORD and
 * POINTER_SIZE.  A back end compiled at the wrong width cannot get these right
 * and still look plausible, which is exactly the failure mode an assembler
 * cannot see.  */

unsigned long mt_word[2] = { sizeof (long), sizeof (void *) };

/* And an arithmetic arm, so the reading is not purely about data layout:
   on a 64-bit RISC-V this is a full-width `sll'/`sra' pair, on a 32-bit one
   the same source is 32-bit arithmetic.  */
long
mt_shift (long a, int b)
{
  return (a << b) >> b;
}
