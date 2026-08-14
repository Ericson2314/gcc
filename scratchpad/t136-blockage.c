void g (void *);
void f (int n)
{
  char *p = __builtin_alloca (n);
  g (p);
}
