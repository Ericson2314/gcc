#!/bin/sh
# Assert every cross assembler in the inherited tools dir actually EXECUTES.
# A dangling symlink or a wrong-arch binary lists fine under ls; only running it decides.
D=${1:-/tmp/gasbin-agent-acda89931a903ec27}
ok=0; fail=0
for f in "$D"/*-as; do
  t=$(basename "$f")
  if v=$("$f" --version 2>&1); then
    case "$v" in
      *"GNU assembler"*) ok=$((ok+1)); echo "EXEC-OK   $t"; ;;
      *) fail=$((fail+1)); echo "EXEC-ODD  $t"; ;;
    esac
  else
    fail=$((fail+1)); echo "EXEC-FAIL $t"
  fi
done
echo "AS  ok=$ok fail=$fail"
r=0
for f in "$D"/*-readelf; do
  "$f" --version >/dev/null 2>&1 && r=$((r+1))
done
echo "READELF exec-ok=$r  named=$(ls "$D"/*-readelf 2>/dev/null | wc -l)"
