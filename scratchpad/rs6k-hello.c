/* A small input for the rs6000 codegen arm.  Deliberately exercises the
   things this branch gets wrong silently: a frame that needs saving (so the
   prologue names real registers), an argument (so CUMULATIVE_ARGS is used),
   and a call (so the ABI is visible in the output).  */
int callee (int, int);

int
mt_leaf (int a)
{
  return a + 1;
}

int
mt_frame (int a, int b)
{
  int t = callee (a, b);
  return t + callee (b, a);
}

long
mt_mem (long *p, long i)
{
  return p[i] + p[i + 1];
}
