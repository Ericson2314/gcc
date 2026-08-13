/* #132 -- an input on which ACCUMULATE_OUTGOING_ARGS is OBSERVABLE.
   The three artefacts #131 recorded (fn-add, fn-call, fn-data) are all
   byte-identical across this change, which reads as "the fix is inert".  It
   is not: none of them has outgoing arguments on the STACK, and
   ACCUMULATE_OUTGOING_ARGS only decides anything when there are.

   `h' takes ten arguments, so on aarch64 (8 core argument registers) two go
   on the stack; `alloca' puts the frame on the dynamic-offset path, which is
   function.cc's STACK_DYNAMIC_OFFSET and reads ACCUMULATE_OUTGOING_ARGS
   directly.  */
int h (int, int, int, int, int, int, int, int, int, int);

int
g (int n)
{
  char *p = __builtin_alloca (n);
  p[0] = 1;
  return h (n, n + 1, n + 2, n + 3, n + 4, n + 5, n + 6, n + 7, n + 8, p[0]);
}
