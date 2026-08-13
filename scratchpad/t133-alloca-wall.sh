#!/bin/sh
# #133 -- IS THE aarch64 WALL `alloca' OR IS IT `-fstack-clash-protection'?
# Four arms, so the answer cannot be attributed to the wrong flag:
#   A  alloca, no  -fstack-clash-protection
#   B  alloca, yes -fstack-clash-protection
#   C  no alloca,  yes -fstack-clash-protection
#   D  x86_64 control for each of A-C
# A failing while C passes says the wall is alloca and has nothing to do with
# this task's macro.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b133}

cat > "$B/wall-alloca.c" <<'EOF'
extern int sink (char *);
extern void *alloca (__SIZE_TYPE__);
int f (int n) { char *p = (char *) alloca ((__SIZE_TYPE__) n); p[0] = (char) n; return sink (p); }
EOF
cat > "$B/wall-noalloca.c" <<'EOF'
extern int sink (char *);
int f (int n) { char buf[16]; buf[0] = (char) n; return sink (buf); }
EOF

run () { # $1 target  $2 src  $3 extra flags  $4 label
  out="$B/wall-$4.s"; rm -f "$out"
  sh "$S/eb-shell.sh" "cd $B/gcc && ./$1-gcc -S -O2 $3 -nostdinc -o $out $B/$2" \
    > "$B/wall-$4.out" 2> "$B/wall-$4.err"
  rc=$?
  if [ -s "$out" ]; then
    echo "$4: rc=$rc OK bytes=$(wc -c < "$out")"
  else
    echo "$4: rc=$rc WALL: $(sed -n 2p "$B/wall-$4.err")  insn: $(grep -m1 'UNSPECV\|unspec_volatile' "$B/wall-$4.err")"
  fi
}

A=aarch64-unknown-linux-gnu
X=x86_64-pc-linux-gnu
run $A wall-alloca.c   ""                          a64-alloca-noclash
run $A wall-alloca.c   "-fstack-clash-protection"  a64-alloca-clash
run $A wall-noalloca.c "-fstack-clash-protection"  a64-noalloca-clash
run $X wall-alloca.c   ""                          x86-alloca-noclash
run $X wall-alloca.c   "-fstack-clash-protection"  x86-alloca-clash
run $X wall-noalloca.c "-fstack-clash-protection"  x86-noalloca-clash
