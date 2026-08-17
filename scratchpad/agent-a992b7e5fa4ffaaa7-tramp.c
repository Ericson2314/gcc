int outer (int x)
{
  int inner (int y) { return y + x; }
  int (*p) (int) = inner;
  return p (1);
}
