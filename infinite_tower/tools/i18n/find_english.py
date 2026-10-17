#!/usr/bin/env python3
"""Flags English left in a translated UI dump (tests/ui_text_dump.gd output).
A word is suspicious when it shows up in the English strings of the game but
never in any translation of that language.
    python3 -I tools/i18n/find_english.py dump.json pt"""
import json, re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
dump = json.load(open(sys.argv[1]))
lang = sys.argv[2]
en = json.load(open(ROOT / "data/lang/en.json"))
tr = json.load(open(ROOT / f"data/lang/{lang}.json"))
keys = json.load(open(ROOT / "tools/i18n/keys.json"))
extra = json.load(open(ROOT / "tools/i18n/extra.json"))
word = re.compile(r"[A-Za-zÀ-ÿ']{3,}")
english = set()
for s in list(en.values()) + keys + list(extra.keys()):
    english.update(w.lower() for w in word.findall(s))
native = set()
for s in tr.values():
    native.update(w.lower() for w in word.findall(str(s)))
suspects = english - native
hits = {}
for screen, texts in dump.items():
    for t in texts:
        bad = sorted({w for w in word.findall(t) if w.lower() in suspects})
        if bad:
            hits.setdefault(t.replace("\n", " | ")[:160], (screen, bad))
for t, (screen, bad) in sorted(hits.items(), key=lambda x: x[1][0]):
    print(f"[{screen}] {bad}  ::  {t}")
print(len(hits), "suspect strings")
