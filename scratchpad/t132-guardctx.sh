#!/bin/sh
# #132 ARM F -- THE GUARDS, not the use.
# t132-sites.sh classified each use by ITS OWN line, which is the question
# "can this become a call?".  This arm asks the OTHER question PRINCIPLES
# names: WHICH `#if' decided that we reach that line at all, and is that `#if'
# answered by the primary?  It found combine-stack-adj.cc:842 sitting under
# `#ifndef PUSH_ROUNDING' -- i386 defines PUSH_ROUNDING, aarch64 does not, so
# the whole test is compiled OUT for every target by the primary's answer.
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
cd "$G"

M=${1:-ACCUMULATE_OUTGOING_ARGS}
echo "== F1. enclosing preprocessor conditionals for every use of $M outside config/ =="
FILES=$(grep -rlw "$M" . --exclude-dir=config --exclude-dir=testsuite --exclude-dir=doc \
        --exclude-dir=po --exclude=ChangeLog\* --exclude=FSFChangeLog\* --include='*.cc' --include='*.h')
if [ -z "$FILES" ]; then echo "FATAL: zero files"; exit 9; fi
for f in $FILES; do
  awk -v m="$M" -v fn="$f" '
    /^[ \t]*#[ \t]*(if|ifdef|ifndef)/ { d++; stack[d]=NR ": " $0; next }
    /^[ \t]*#[ \t]*(else|elif)/       { if (d>0) stack[d]=stack[d] "  [ELSE at " NR "]"; next }
    /^[ \t]*#[ \t]*endif/             { if (d>0) d--; next }
    index($0, m) {
      if ($0 ~ /^[ \t]*#[ \t]*define/) next
      if (d==0) next
      printf "  %s:%d  under depth %d\n", fn, NR, d
      for (i=1;i<=d;i++) printf "       %s\n", stack[i]
    }' "$f"
done
echo
echo "== F2. is each guard macro answered by the PRIMARY? =="
for g in PUSH_ROUNDING; do
  printf '  %-22s i386: ' "$g"
  if grep -q "define $g" config/i386/i386.h; then echo -n "DEFINES"; else echo -n "no"; fi
  printf '   aarch64: '
  if grep -q "define $g" config/aarch64/aarch64.h; then echo "DEFINES"; else echo "no"; fi
done
echo
echo "== F3. scope of PUSH_ROUNDING as an EXISTENCE question in shared code =="
grep -rn '#[ \t]*if\(n\)\?def[ \t]*PUSH_ROUNDING\|defined *( *PUSH_ROUNDING' . \
  --exclude-dir=config --exclude-dir=testsuite --exclude-dir=doc --exclude=ChangeLog\* \
  --exclude=FSFChangeLog\* | sed 's/^/   /'
echo "   -- back ends that define it: $(grep -rl 'define PUSH_ROUNDING' config/ | wc -l) of $(ls -d config/*/ | wc -l) config dirs"
