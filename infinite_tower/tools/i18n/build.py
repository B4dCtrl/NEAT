#!/usr/bin/env python3
"""Merges tools/i18n/{pt,es}_N.json (indexed like extract.py's output) and extra.json
into data/lang/{pt,es}.json.  python3 -I tools/i18n/build.py"""
import json, subprocess, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
# keys.json freezes the order the numbered translation files were written against;
# strings added later go into extra.json (English -> [pt, es]).
keys = json.load(open(HERE / "keys.json"))
extra = json.load(open(HERE / "extra.json"))
for li, lang in enumerate(("pt", "es")):
    tr = {}
    for n in range(1, 5):
        tr.update(json.load(open(HERE / f"{lang}_{n}.json")))
    pack_path = ROOT / "data" / "lang" / f"{lang}.json"
    pack = json.load(open(pack_path))
    miss = 0
    for i, k in enumerate(keys):
        if str(i) in tr:
            pack[k] = tr[str(i)]
        else:
            miss += 1
    for k, v in extra.items():
        pack[k] = v[li]
    json.dump(pack, open(pack_path, "w"), indent="\t", ensure_ascii=False)
    open(pack_path, "a").write("\n")
    print(lang, len(pack), "keys,", miss, "missing")
