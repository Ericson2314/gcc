# Enumerate every .o rule in every config/**/t-* fragment, as LOGICAL lines,
# and classify how the current matcher (^obj\.o[ \t]*:) would score it.
FNR == 1 { buf = "" }
{
  sub(/\r$/, "");
  if ($0 ~ /\\$/) { l = $0; sub(/\\$/, " ", l); buf = buf l; next }
  buf = buf $0; line = buf; buf = "";
  if (line ~ /^\t/) next;
  raw = line;
  sub(/^[ \t]+/, "", line);
  if (line ~ /^#/ || line == "") next;
  ci = index(line, ":");
  if (ci == 0) next;
  if (substr(line, ci+1, 1) == "=") next;
  if (substr(line, ci, 2) == "::") ci++;
  lhs = substr(line, 1, ci-1);
  if (lhs !~ /\.o([ \t]|$)/) next;
  n = split(lhs, tg, "[ \t]+");
  for (j = 1; j <= n; j++) {
    if (tg[j] !~ /\.o$/) continue;
    tot++;
    why = "";
    if (j > 1) why = why ",not-first-target";
    if (raw ~ /^[ \t]+/) why = why ",indented";
    if (tg[j] ~ /[$%]/) why = why ",variable-or-pattern";
    if (why == "") why = ",OK-for-current";
    printf "%s\t%s\t%s\n", FILENAME, tg[j], substr(why, 2);
  }
}
END { printf "TOTAL_O_RULE_TARGETS %d\n", tot > "/dev/stderr" }
