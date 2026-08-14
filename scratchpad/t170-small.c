/* #170 -- the PORTABLE input, for back ends big.c does not fit.
   big.c uses __int128, vector types and long double; a 16- or 32-bit back end
   (visium, xtensa, arm-eabi) rejects those before codegen is reached, and a
   compile failure there says nothing about whether the back end emits code.
   So this file is deliberately confined to what every in-tree back end must
   support: int/long arithmetic, a loop, a call, a switch, a small struct, a
   pointer walk.  It is still not trivial -- it needs a frame, a call sequence,
   register allocation and a jump table or its equivalent, which is exactly
   where a leaked i386 register number or Pmode shows up.  */

extern int sink (int);
extern int g_arr[64];

struct P { int x; int y; };

int mt_add (int a, int b) { return a + b; }

long mt_shift (long a, int n) { return (a << n) | (a >> 1); }

int mt_loop (int n)
{
  int s = 0, i;
  for (i = 0; i < n; i++)
    s += g_arr[i & 63] * i;
  return s;
}

int mt_call (int a)
{
  return sink (a) + sink (a + 1) + mt_add (a, 2);
}

int mt_switch (int k)
{
  switch (k)
    {
    case 0: return 11;
    case 1: return 22;
    case 2: return 33;
    case 3: return 44;
    case 7: return 55;
    default: return -1;
    }
}

int mt_struct (struct P *p, int n)
{
  int s = 0;
  while (n-- > 0)
    { s += p->x - p->y; p++; }
  return s;
}

int mt_frame (int a, int b, int c, int d, int e, int f, int g)
{
  int loc[8];
  int i;
  for (i = 0; i < 8; i++)
    loc[i] = a + b * i;
  return loc[c & 7] + d + e + f + g;
}
