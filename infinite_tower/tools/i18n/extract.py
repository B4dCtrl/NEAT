#!/usr/bin/env python3
"""Lists every English source string that needs a translation (UI literals in
Loc.t("...") + the player-facing texts of data/*.json).  python3 -I tools/i18n/extract.py"""
import glob, json, re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
TEXT_KEYS = {"name", "description", "text", "role", "suffix", "title"}
NAME_MAPS = {"pieces", "weapons"}
out = {}

def add(s, where):
    if isinstance(s, str) and s.strip() and re.search(r"[A-Za-z]{2,}", s):
        out.setdefault(s, where)

for f in glob.glob(str(ROOT / "**/*.gd"), recursive=True):
    if "/tools/" in f or "/tests/" in f:
        continue
    src = open(f).read()
    for m in re.finditer(r'Loc\.t\("((?:[^"\\]|\\.)*)"\)', src):
        s = m.group(1).replace("\\n", "\n").replace("\\t", "\t").replace("\\\"", "\"").replace("\\\\", "\\")
        if not re.fullmatch(r"[a-z_]+\.[a-z_0-9]+", s):      # keys like menu.status are in the packs
            add(s, Path(f).name)

def walk(node, where):
    if isinstance(node, dict):
        for k, v in node.items():
            if k in TEXT_KEYS and isinstance(v, str):
                add(v, where)
            elif k in NAME_MAPS and isinstance(v, dict):
                for x in v.values():
                    add(x, where)
            elif isinstance(v, (dict, list)):
                walk(v, where)
    elif isinstance(node, list):
        for v in node:
            walk(v, where)

for f in ["classes", "enemies", "items", "floor_rules", "ascension_tree", "skill_tree", "quests"]:
    d = json.load(open(ROOT / "data" / f"{f}.json"))
    if f == "items":
        for s in d["sets"].values():          # bonus texts are composed at runtime
            for b in s["bonuses"].values():
                b["text"] = ""
    walk(d, f + ".json")

loc = (ROOT / "core/loc.gd").read_text()
for m in re.finditer(r'"[a-z_]+": "([^"]+)"', loc[loc.index("STAT_LABEL"):]):
    add(m.group(1), "loc.gd")
json.dump(out, open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/to_translate.json", "w"), indent=1, ensure_ascii=False)
print(len(out), "strings")
