/* A deliberately varied, self-contained input for the stock-GCC comparison
   arm.  The 9-line input the earlier arms used could in principle match by
   being too easy; this one exercises struct layout, bitfields, unions,
   switches, varargs, long double, __int128, vectors, atomics, alignment,
   setjmp-free EH-free but still non-trivial control flow, and the string
   builtins -- i.e. the places where a target macro divergence would show.
   No #include, so -nostdinc is harmless.  */

typedef unsigned long size_t_;
typedef __builtin_va_list va_list_;
typedef int v4si __attribute__ ((vector_size (16)));
typedef double v2df __attribute__ ((vector_size (16)));

struct S { long a; int b : 3; unsigned c : 5; char d; double e; };
union U { long l; double d; char c[8]; };
struct Big { char pad[100]; long x; };

extern int g_arr[64];
extern struct S g_s;
extern void sink (const void *);

static inline int sq (int x) { return x * x; }

int f_index (int *p, int i) { return p[i] + sq (i); }

long f_loop (struct S *p, long n)
{
  long s = 0;
  for (long i = 0; i < n; i++)
    s += p[i].a * p[i].b + p[i].c;
  return s;
}

double f_fp (double x, double y) { return x * y + x / y - __builtin_sqrt (x); }
long double f_ld (long double x, long double y) { return x * y + 1.0L; }
float f_f (float x, float y) { return x / y; }

int f_wrap (unsigned n)
{
  int s = 0;
  for (unsigned i = 0; i < n; i++)
    s += g_arr[i & 63];
  return s;
}

int f_sel (int a, int b, int c) { return a > b ? (b > c ? a : c) : b; }

char *f_copy (char *d, const char *s, unsigned n)
{
  while (n--)
    *d++ = *s++;
  return d;
}

void f_builtin (char *d, const char *s, size_t_ n)
{
  __builtin_memcpy (d, s, n);
  __builtin_memset (d, 0, 37);
  sink (__builtin_strchr (s, 'x'));
}

int f_switch (int x)
{
  switch (x)
    {
    case 0: return 11;
    case 1: return 22;
    case 2: return 33;
    case 7: return 44;
    case 9: return 55;
    case 100: return 66;
    case 101: return 77;
    case 102: return 88;
    default: return -1;
    }
}

int f_va (int n, ...)
{
  va_list_ ap;
  int s = 0;
  __builtin_va_start (ap, n);
  for (int i = 0; i < n; i++)
    s += __builtin_va_arg (ap, int);
  s += (int) __builtin_va_arg (ap, double);
  __builtin_va_end (ap);
  return s;
}

struct S f_ret_struct (long a, int b) { struct S s = { a, b, 3, 'z', 1.5 }; return s; }
struct Big f_ret_big (long x) { struct Big b = { { 0 }, x }; return b; }

long f_union (union U u) { return u.l ^ (long) u.d ^ u.c[3]; }

__int128 f_i128 (__int128 a, __int128 b) { return a * b + (a >> 7); }
unsigned __int128 f_u128 (unsigned __int128 a) { return a / 1000000007u; }

v4si f_vec (v4si a, v4si b) { return a * b + (a ^ b); }
v2df f_vecd (v2df a, v2df b) { return a * b + a / b; }

int f_atomic (int *p, int v)
{
  int old = __atomic_load_n (p, __ATOMIC_ACQUIRE);
  __atomic_store_n (p, v, __ATOMIC_RELEASE);
  return __atomic_fetch_add (p, v, __ATOMIC_SEQ_CST) + old;
}

int f_cas (int *p, int e, int d)
{
  return __atomic_compare_exchange_n (p, &e, d, 0, __ATOMIC_SEQ_CST, __ATOMIC_RELAXED);
}

int f_bits (unsigned long x)
{
  return __builtin_clzl (x) + __builtin_ctzl (x) + __builtin_popcountl (x)
	 + __builtin_parityl (x);
}

_Alignas (64) char g_aligned[256];
char *f_aligned (void) { return g_aligned; }

int f_recurse (int n) { return n <= 1 ? 1 : n * f_recurse (n - 1); }

int f_alloca (unsigned n)
{
  char *p = __builtin_alloca (n);
  __builtin_memset (p, 7, n);
  sink (p);
  return p[0];
}

int f_nested_loops (int *a, int n)
{
  int s = 0;
  for (int i = 0; i < n; i++)
    for (int j = 0; j < n; j++)
      if ((i ^ j) & 1)
	s += a[i * n + j];
      else
	s -= a[j * n + i];
  return s;
}

double f_convert (long a, unsigned long b, float c) { return (double) a + b + c; }
long f_convert2 (double d, float f) { return (long) d + (long) f; }

int f_ptr_cmp (const char *a, const char *b) { return a < b ? -1 : a > b ? 1 : 0; }

extern int (*g_fp) (int);
int f_indirect (int x) { return g_fp (x) + g_fp (x + 1); }
