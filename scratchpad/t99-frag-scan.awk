# Compare the CURRENT frag_source_for matcher against a thorough one.
# Input: targets.txt lines  triple|cpu|tmake_present|extra_objs|c_target_objs|out_file
# srcdir passed with -v.

# ---- shared: read a fragment as LOGICAL lines (join backslash continuations)
function load(path,   line, buf, n) {
  if (path in loaded) return loaded[path];
  n = 0; buf = "";
  while ((getline line < path) > 0) {
    sub(/\r$/, "", line);
    if (line ~ /\\$/) { sub(/\\$/, " ", line); buf = buf line; continue; }
    buf = buf line;
    llines[path, ++n] = buf; buf = "";
  }
  if (buf != "") llines[path, ++n] = buf;
  close(path);
  loaded[path] = n;
  return n;
}

# ---- CURRENT matcher, transcribed from gen-multi-target-md.awk:108
function cur(obj, frags, cpu,   i, n, parts, path, line, cont, j, m, toks) {
  n = split(frags, parts, " ");
  for (i = 1; i <= n; i++) {
    path = srcdir "/config/" parts[i];
    cont = 0;
    while ((getline line < path) > 0) {
      if (!cont) {
	if (line !~ ("^" obj "\\.o[ \t]*:")) continue;
	cont = 1;
      }
      m = split(line, toks, "[ \t]+");
      for (j = 1; j <= m; j++)
	if (toks[j] ~ /^\$\(srcdir\)\/config\/.*\.(cc|c)$/) { close(path); return toks[j]; }
      for (j = 1; j <= m; j++)
	if (toks[j] ~ /^[A-Za-z0-9_.+-]+\.(cc|c)$/ && ((cpu SUBSEP toks[j]) in seen_hdrgen)) {
	  close(path); return toks[j];
	}
      cont = (line ~ /\\$/);
      if (!cont) break;
    }
    close(path);
  }
  return "";
}

# ---- THOROUGH matcher
function thorough(obj, frags, cpu,   i, n, parts, path, k, nl, line, lhs, rhs,
			      ci, tn, tg, j, m, toks, found) {
  n = split(frags, parts, " ");
  for (i = 1; i <= n; i++) {
    path = srcdir "/config/" parts[i];
    nl = load(path);
    for (k = 1; k <= nl; k++) {
      line = llines[path, k];
      if (line ~ /^\t/) continue;
      sub(/^[ \t]+/, "", line);
      if (line ~ /^#/) continue;
      ci = index(line, ":");
      if (ci == 0) continue;
      # not an assignment
      if (substr(line, ci+1, 1) == "=") continue;
      if (substr(line, ci, 2) == "::") ci++;
      lhs = substr(line, 1, ci-1);
      rhs = substr(line, ci+1);
      if (index(rhs, "=") > 0 && rhs ~ /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*=/) continue;
      tn = split(lhs, tg, "[ \t]+");
      found = 0;
      for (j = 1; j <= tn; j++) if (tg[j] == obj ".o") found = 1;
      if (!found) continue;
      m = split(rhs, toks, "[ \t]+");
      for (j = 1; j <= m; j++)
	if (toks[j] ~ /^\$\(srcdir\)\/config\/.*\.(cc|c)$/) return toks[j];
      for (j = 1; j <= m; j++)
	if (toks[j] ~ /^[A-Za-z0-9_.+-]+\.(cc|c)$/ && ((cpu SUBSEP toks[j]) in seen_hdrgen))
	  return toks[j];
      for (j = 1; j <= m; j++)
	if (toks[j] ~ /^[A-Za-z0-9_.+-]+\.(cc|c)$/)
	  return "UNDECLARED:" toks[j] "@" parts[i];
      return "NOSRC@" parts[i];
    }
  }
  return "";
}

function scan_hdr_frag(path, cpu,   nl, k, line, i, n, parts) {
  nl = load(path);
  for (k = 1; k <= nl; k++) {
    line = llines[path, k];
    if (line !~ /^[ \t]*generated_files[ \t]*\+=/) continue;
    sub(/^[ \t]*generated_files[ \t]*\+=[ \t]*/, "", line);
    n = split(line, parts, "[ \t]+");
    for (i = 1; i <= n; i++)
      if (parts[i] != "" && parts[i] != "\\") seen_hdrgen[cpu SUBSEP parts[i]] = 1;
  }
}

BEGIN { FS = "|" }
{
  triple = $1; cpu = $2; frags = $3; xobjs = $4; cobjs = $5;
  # replicate the -headers fragment scan: gen-multi-target-md.awk scans
  # config/<cpu>/t-<cpu>-headers and any t-*-headers in tmake_file.
  hp = srcdir "/config/" cpu "/t-" cpu "-headers";
  scan_hdr_frag(hp, cpu);
  nf = split(frags, fa, " ");
  for (fi = 1; fi <= nf; fi++)
    if (fa[fi] ~ /-headers$/) scan_hdr_frag(srcdir "/config/" fa[fi], cpu);

  no = split(xobjs " " cobjs, oa, " ");
  for (oi = 1; oi <= no; oi++) {
    obj = oa[oi]; sub(/\.o$/, "", obj);
    if (obj == "") continue;
    key = cpu SUBSEP obj SUBSEP frags;
    if (key in done) continue;
    done[key] = 1;
    c = cur(obj, frags, cpu);
    t = thorough(obj, frags, cpu);
    if (c == "" && t != "")
      print "GAP\t" cpu "\t" obj ".o\t" t "\t" triple;
    else if (c == "" && t == "")
      print "NONE\t" cpu "\t" obj ".o\t-\t" triple;
  }
}
