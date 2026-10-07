#!/usr/bin/env python3
"""One-off helper: wraps display string literals of a GDScript file in Loc.t("...").
Usage: i18n_wrap.py <file> [skip_line ...]   (prints the number of wrapped literals)
A literal qualifies when it has 3+ letters and starts with an uppercase letter or
contains a space; res:// paths, colours, dictionary-key style words and strings
already inside Loc.t() are left alone."""
import re, sys
f = sys.argv[1]
skip = {int(x) for x in sys.argv[2:] if x.isdigit()}
only = {int(x[1:]) for x in sys.argv[2:] if x.startswith('o')}
src = open(f).read().split("\n")
n = 0
lit = re.compile(r'"((?:[^"\\]|\\.)*)"')
for i, line in enumerate(src, 1):
    s = line.strip()
    if (only and i not in only) or i in skip or s.startswith("#") or s.startswith("const ") or "preload(" in s:
        continue
    def sub(m):
        global n
        txt = m.group(1)
        pre = line[:m.start()]
        if pre.endswith("Loc.t(") or pre.endswith("Loc.t((") :
            return m.group(0)
        if not re.search(r"[A-Za-z]{3,}", txt) or txt.startswith("res://") or txt.startswith("#") or txt.startswith("user://"):
            return m.group(0)
        if not (txt[:1].isupper() or " " in txt):
            return m.group(0)
        if re.fullmatch(r"[%A-Za-z_]+", txt) and not txt[:1].isupper():
            return m.group(0)
        # logic uses: comparisons, membership, dictionary lookups
        tail = line[m.end():m.end() + 3]
        if re.search(r'(==|!=)\s*$', pre) or tail.startswith("]") and pre.rstrip().endswith("["):
            return m.group(0)
        if pre.rstrip().endswith(("has(", "get(", "in [", "begins_with(", "ends_with(", "match ")):
            return m.group(0)
        n += 1
        return 'Loc.t("%s")' % txt
    new = lit.sub(sub, line)
    src[i - 1] = new
out = "\n".join(src)
if n and 'preload("res://core/loc.gd")' not in out and "const Loc " not in out:
    # after the last top-level preload const, else after the extends/doc header
    lines = out.split("\n")
    idx = max([k for k, l in enumerate(lines) if l.startswith("const ") and "preload(" in l], default=-1)
    if idx < 0:
        idx = max([k for k, l in enumerate(lines) if l.startswith("extends") or l.startswith("##")], default=0)
    lines.insert(idx + 1, 'const Loc = preload("res://core/loc.gd")')
    out = "\n".join(lines)
open(f, "w").write(out)
print(f, n)
