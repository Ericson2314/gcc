/* #169 -- a loop whose natural aarch64 form uses auto-increment addressing.
   aarch64 defines HAVE_PRE_INCREMENT, HAVE_PRE_DECREMENT, HAVE_POST_INCREMENT,
   HAVE_POST_DECREMENT and HAVE_PRE_MODIFY_DISP; i386 defines none of the
   eight, and rtl.h read i386's answer for both.  x86_64 is the control: it
   genuinely has no auto-increment addressing, so its output must not change.  */
void
copy (long *__restrict d, const long *__restrict s, int n)
{
  int i;
  for (i = 0; i < n; i++)
    d[i] = s[i] + 1;
}

long
sum (const long *p, int n)
{
  long t = 0;
  int i;
  for (i = 0; i < n; i++)
    t += p[i];
  return t;
}
