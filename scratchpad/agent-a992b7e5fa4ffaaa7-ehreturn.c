void f (long off, void *handler)
{
  __builtin_eh_return (off, handler);
}
