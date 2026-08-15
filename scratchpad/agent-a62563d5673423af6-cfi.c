/* A real function with a real frame: it must save the return address and a
   callee-saved register, so a correct CFI stream has .cfi_startproc, a
   .cfi_def_cfa* and at least two .cfi_offset entries.  A leaf function would
   need none of those, so a leaf is NOT a usable probe here -- an empty CFI
   stream and no CFI stream look identical on one.  */
extern long mt_callee (long);

long
mt_cfi_probe (long a, long b)
{
  long acc = 0;
  for (long i = 0; i < b; i++)
    acc += mt_callee (a + i);
  return acc;
}
