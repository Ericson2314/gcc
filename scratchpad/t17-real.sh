#!/bin/sh
# Task #17: the real_{ld,nm,strip}_file_name capability, three arms.
#
#   absent    -- ordinary search (covered by t17-tools.sh)
#   good      -- the named file is used, and it is THIS target's, not the
#                other target's
#   bad       -- the named file does not exist: HARD ERROR naming the target and
#                the path.  This is the arm that matters.  The failure mode
#                being fixed is a SILENT fall-through to whatever ld/nm the host
#                has, which on a native build is indistinguishable from working.
#
# Run against both builds: on the BEFORE build the key does not exist, so
# writing it into the config file must do NOTHING -- which is what makes the
# AFTER result a change rather than a coincidence.
set -u
B=$1; L=$2
TMP=$(mktemp -d)
: > "$TMP/empty.o"
mkdir -p "$TMP/bin"
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  short=$(echo "$t" | cut -d- -f1)
  cat > "$TMP/bin/$short-nm" <<EOF
#!/bin/sh
echo "T17-MARKER $short-nm"
EOF
  chmod +x "$TMP/bin/$short-nm"
done

for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  short=$(echo "$t" | cut -d- -f1)
  base="$B/gcc/specs-$t-config"
  [ -f "$base" ] || { echo "FATAL: no $base"; exit 9; }

  # good
  cfg="$TMP/good-$t"; cp "$base" "$cfg"
  echo "real_nm_file_name $TMP/bin/$short-nm" >> "$cfg"
  # collect2's OWN dump of what it resolved.  Not execution: with no ld on this
  # host collect2 gives up before it would ever run nm, so an execution test
  # would score both arms the same for a reason that has nothing to do with the
  # key.
  out=$("$B/gcc/collect2" -debug -ftarget-config="$cfg" "$TMP/empty.o" 2>&1)
  echo "$L  $t  good: $(printf '%s' "$out" | grep -E '^(nm_file_name|c_file_name)' | tr -s ' ' | tr '\n' ';')"
  # cross-check: it must not have run the OTHER target's marker
  o=$(echo "$t" | sed 's/x86_64/@/;s/aarch64/x86_64/;s/@/aarch64/' | cut -d- -f1)
  if printf '%s' "$out" | grep -q "T17-MARKER $o-nm"; then
    echo "$L  $t  CONTROL FAILED: ran $o-nm"
  else
    echo "$L  $t  control: did not run $o-nm"
  fi

  # bad
  cfg="$TMP/bad-$t"; cp "$base" "$cfg"
  echo "real_nm_file_name /nonexistent/$t/nm" >> "$cfg"
  out=$("$B/gcc/collect2" -debug -ftarget-config="$cfg" "$TMP/empty.o" 2>&1)
  line=$(printf '%s' "$out" | grep -i 'real_nm_file_name' | head -1)
  if [ -n "$line" ]; then
    echo "$L  $t  bad:  $line"
  else
    echo "$L  $t  bad:  NO diagnostic naming the key -- fell through silently"
  fi
done
rm -rf "$TMP"
