#!/bin/sh
# #134 -- THE BEHAVIOURAL ARM for `PUSH_ARGS_REVERSED'.
#
# A value arm is not enough for this macro.  It decides the ORDER gimplify.cc
# walks a call's arguments, and that order is OBSERVABLE: two arguments that
# are side-effecting calls come out in whichever order this picks.  So the
# thing to measure is the emitted code, not a field.
#
# THE REQUIRED SHAPE, and it is the one that has separated "fixed" from
# "everyone now gets the same new answer" three times on this branch:
#
#     aarch64 output must CHANGE between injected-OFF and injected-ON;
#     x86_64  output must be BYTE-IDENTICAL between them.
#
# Either half alone proves nothing.  The x86_64 half is what says the primary
# still gets the primary's answer.
#
# `-O0 -fno-inline' on purpose: at -O2 the scheduler and the tree passes can
# reorder two calls anyway, so a difference there would not be attributable.
# At -O0 the call sequence is the gimple order.
#
# NON-VACUITY: the arm REFUSES unless the input actually emits both calls, so
# an empty or truncated .s cannot score as "no difference".
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b135}
TAG=${1:?usage: t134-order.sh <tag: off|on>}

cat > "$B/order.c" <<'EOF'
extern int f (void);
extern int g (void);
extern int h (int, int);

int
t (void)
{
  return h (f (), g ());
}
EOF

for cpu in aarch64-unknown-linux-gnu x86_64-pc-linux-gnu; do
  o="$B/order-$TAG-$cpu"
  rm -f "$o.s"
  sh "$S/eb-shell.sh" \
    "cd $B/gcc && ./$cpu-gcc -S -O0 -fno-inline -nostdinc -o $o.s $B/order.c" \
    > "$o.out" 2> "$o.err"
  rc=$?
  if [ "$rc" != 0 ] || [ ! -s "$o.s" ]; then
    echo "$TAG  $cpu  rc=$rc  NO OUTPUT: $(head -2 "$o.err" | tr '\n' ' ')"
    continue
  fi
  # The observable: which of f/g is called first.  Derived from the file, not
  # asserted against a remembered string.
  seq=$(grep -o 'bl[[:space:]]*[fg]$\|call[[:space:]]*[fg]$\|[[:space:]][fg]$' "$o.s" \
        | grep -o '[fg]$' | tr -d '\n')
  nf=$(grep -c '\<f\>' "$o.s")
  ng=$(grep -c '\<g\>' "$o.s")
  if [ "$nf" = 0 ] || [ "$ng" = 0 ]; then
    echo "$TAG  $cpu  FATAL-VACUOUS: f seen $nf times, g seen $ng -- refusing to score"
    exit 9
  fi
  echo "$TAG  $cpu  rc=$rc  bytes=$(wc -c < "$o.s")  md5=$(md5sum < "$o.s" | cut -c1-12)  callorder=[$seq]"
done
