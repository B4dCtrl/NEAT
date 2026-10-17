#!/usr/bin/env python3
"""Regenerates the `bases` and `sets` sections of data/items.json.

The gear catalogue is a chain of 20 sets (tier 1..20). Every set has 18 pieces,
six for each class (knight / ranger / arcanist): weapon, helm, chest, gloves, boots
and ring. A piece can only be worn by its own class (the Stairborn founder wears
Knight and Ranger gear). Merging ("Evolve") turns a piece of tier N into the same slot of tier N+1.
Edit SETS below and run:  python3 -I tools/gen_item_data.py
Then re-render the art:   godot --path . -s res://tools/gen_item_art.gd
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
P = ROOT / "data" / "items.json"
data = json.loads(P.read_text())

STAT_TXT = {"lifesteal": "Lifesteal", "thorns": "Thorns (reflect)", "regen": "HP regen per second", "mana_regen_pct": "Mana regeneration",
            "attack_pct": "Attack", "magic_power_pct": "Magic", "hp_pct": "HP", "defense_pct": "Defense",
            "crit_chance": "Crit chance", "crit_damage": "Crit damage", "attack_speed_pct": "Attack speed",
            "dodge": "Dodge", "damage_pct": "Damage", "fire_damage_pct": "Fire damage", "gold_pct": "Gold",
            "drop_pct": "Drop chance", "move_speed_pct": "Climb speed"}
SPECIAL_TXT = {"fire_imbue": "attacks become Fire", "burning_soul": "attacks apply a burn over time",
               "regrowth": "Regrowth: slowly heals", "chain_lightning": "crits chain lightning"}

# id, name, min_floor, (main, accent, dark, glow), motif, [bonus2, bonus4, bonus6(, special)]
# bonus = ({stat: value}, special or None)
W = ("knight", "ranger", "arcanist")
SETS = [
    ("wayfarer", "Wayfarer", 1, ("#8a8f99", "#b08a4a", "#6b4a2d", "#d9d27a"), "none",
     [({"move_speed_pct": 0.05}, None), ({"hp_pct": 0.06}, None), ({"gold_pct": 0.10}, None)],
     ["Iron Sword", "Short Bow", "Oak Staff", "Leather Cap", "Padded Vest", "Leather Grips", "Leather Boots", "Copper Ring"]),
    ("gravebound", "Gravebound", 10, ("#d8d2bd", "#8f8a78", "#4a463c", "#7be07b"), "bone",
     [({"defense_pct": 0.08}, None), ({"hp_pct": 0.10}, None), ({"damage_pct": 0.12}, None)],
     ["Gravecleaver", "Boneshot Bow", "Ossuary Staff", "Skullcap of the Fallen", "Ribcage Plate", "Knucklebone Gauntlets", "Marrow Treads", "Tomb Signet"]),
    ("ashen_king", "Ashen King", 20, ("#4a3b36", "#e8641c", "#2a1f1c", "#ffb347"), "ember", None,
     ["Ashen Brand", "Cinderbow", "Emberlord Staff", "Crown of Cinders", "Ashen Mantle", "Smoldering Grasp", "Charred Sabatons", "Ember Seal"]),
    ("verdant_warden", "Verdant Warden", 40, ("#4f8c3e", "#9be36b", "#5a3d22", "#e8f56a"), "thorn", None,
     ["Thornheart", "Briarbow", "Heartwood Staff", "Warden's Hood", "Barkskin Vest", "Vinegrips", "Rootwalkers", "Seedstone Band"]),
    ("stormcaller", "Stormcaller", 60, ("#5a6e9a", "#f5e050", "#2c3550", "#bfe6ff"), "bolt", None,
     ["Tempest Edge", "Thunderstring", "Stormcaller's Rod", "Storm Visage", "Galeweave", "Sparkknuckles", "Striders of Lightning", "Band of the Tempest"]),
    ("frostbound", "Frostbound", 80, ("#9fd8ee", "#ffffff", "#3d6a8a", "#6fe0ff"), "frost",
     [({"defense_pct": 0.10}, None), ({"dodge": 0.06}, None), ({"attack_speed_pct": 0.12}, None)],
     ["Rimefang Blade", "Glacier Bow", "Wintertide Staff", "Hoarfrost Helm", "Iceplate Cuirass", "Frostbite Gauntlets", "Snowdrift Boots", "Rime Ring"]),
    ("prismatic", "Prismatic Vein", 105, ("#7fd6e8", "#e07fe8", "#3a5a7a", "#fff1a0"), "prism",
     [({"magic_power_pct": 0.10}, None), ({"crit_chance": 0.06}, None), ({"crit_damage": 0.30}, None)],
     ["Facetblade", "Prism Bow", "Shard Scepter", "Geode Crown", "Crystalmail", "Gemgrasp Gloves", "Glassstep Boots", "Prism Ring"]),
    ("sunken_tide", "Sunken Tide", 130, ("#2f8f9a", "#e8d6a8", "#1f4a5a", "#7cf0e0"), "wave",
     [({"hp_pct": 0.10}, None), ({"defense_pct": 0.10}, None), ({"gold_pct": 0.20}, None)],
     ["Tidebreaker", "Coralbow", "Brineweave Staff", "Diver's Helm", "Barnacle Plate", "Kelp Wraps", "Tidewalkers", "Pearl Band"]),
    ("dune_nomad", "Dune Nomad", 160, ("#d8b060", "#c0702c", "#6b4a2a", "#5ad0c0"), "sun",
     [({"gold_pct": 0.12}, None), ({"drop_pct": 0.10}, None), ({"move_speed_pct": 0.20}, None)],
     ["Sandscimitar", "Dunebow", "Mirage Staff", "Sunveil Turban", "Nomad's Robe", "Sandsilk Gloves", "Duststriders", "Scarab Ring"]),
    ("forgeborn", "Forgeborn", 190, ("#5b5b66", "#ff8a2a", "#2a2a30", "#ffd060"), "rivet",
     [({"defense_pct": 0.10}, None), ({"attack_pct": 0.12}, None), ({"fire_damage_pct": 0.25}, "fire_imbue")],
     ["Slagmaul", "Rivet Crossbow", "Anvil Scepter", "Foundry Helm", "Blastplate", "Tongs Gauntlets", "Cinder Greaves", "Molten Signet"]),
    ("bloodmoon", "Bloodmoon", 225, ("#8c1f2f", "#e8e0d0", "#3a0f18", "#ff4060"), "fang",
     [({"attack_pct": 0.10}, None), ({"crit_chance": 0.06}, None), ({"crit_damage": 0.35}, None)],
     ["Crimson Fang", "Moonbleed Bow", "Hemomancer's Staff", "Bloodmoon Crown", "Sanguine Mail", "Clawed Mitts", "Hunter's Boots", "Fangsigil"]),
    ("nightbloom", "Nightbloom", 265, ("#5a2f7a", "#c06ae0", "#2a163a", "#9bff6a"), "bloom",
     [({"magic_power_pct": 0.10}, None), ({"dodge": 0.06}, None), ({"damage_pct": 0.15}, None)],
     ["Venomthorn", "Nightshade Bow", "Wilting Staff", "Belladonna Hood", "Nightbloom Vest", "Toxin Grips", "Creeper Boots", "Blossom Ring"]),
    ("voidtouched", "Voidtouched", 310, ("#3a2a5a", "#8a5aff", "#16101f", "#e05aff"), "eye",
     [({"damage_pct": 0.08}, None), ({"crit_damage": 0.30}, None), ({"attack_pct": 0.20, "magic_power_pct": 0.20}, None)],
     ["Riftblade", "Voidstring", "Abyssal Staff", "Gazing Helm", "Voidwoven Robe", "Umbral Grasp", "Nullwalkers", "Eye Signet"]),
    ("wraithwoven", "Wraithwoven", 360, ("#a8d8c8", "#e8fff6", "#4a6a64", "#8affd8"), "wisp",
     [({"dodge": 0.06}, None), ({"move_speed_pct": 0.15}, None), ({"attack_speed_pct": 0.15}, None)],
     ["Spectral Edge", "Wisp Bow", "Banshee Staff", "Shroud Hood", "Ghostlace Tunic", "Phantom Fingers", "Hollow Steps", "Soul Ring"]),
    ("radiant_choir", "Radiant Choir", 415, ("#f2e6b0", "#ffffff", "#b08a2a", "#fff6a0"), "halo",
     [({"hp_pct": 0.12}, None), ({"defense_pct": 0.12}, None), ({"hp_pct": 0.20}, "regrowth")],
     ["Halo Brand", "Seraph Bow", "Choirstaff", "Aureole Helm", "Chorister's Plate", "Blessed Gauntlets", "Lightstep Sandals", "Sunlit Band"]),
    ("titanforge", "Titanforge", 475, ("#8a6a40", "#c8c8d0", "#3a2f22", "#ffb050"), "rivet",
     [({"hp_pct": 0.15}, None), ({"attack_pct": 0.15}, None), ({"defense_pct": 0.25}, None)],
     ["Colossus Blade", "Titan Ballista", "Atlas Staff", "Titan Helm", "Colossus Plate", "Titan Fists", "Titan Greaves", "Titan Seal"]),
    ("dragonscale", "Dragonscale", 540, ("#a83a2a", "#3a8a4a", "#3a1a14", "#ffcf4a"), "scale",
     [({"attack_pct": 0.12}, None), ({"fire_damage_pct": 0.25}, None), ({"damage_pct": 0.20}, "burning_soul")],
     ["Wyrmfang", "Drake Bow", "Dragonbone Staff", "Dragonhelm", "Scalemail", "Talon Gauntlets", "Wyrmstriders", "Dragon's Eye Ring"]),
    ("starfall", "Starfall", 610, ("#2a3a7a", "#ffe680", "#141a3a", "#ffffff"), "stars",
     [({"crit_chance": 0.06}, None), ({"magic_power_pct": 0.15}, None), ({"crit_damage": 0.40}, None)],
     ["Comet Blade", "Starstring", "Astral Staff", "Starcrown", "Nebula Robe", "Stardust Gloves", "Meteor Boots", "Constellation Ring"]),
    ("eclipse", "Eclipse", 690, ("#1c1a24", "#ff9a2a", "#0a090e", "#ffd060"), "corona",
     [({"damage_pct": 0.10}, None), ({"attack_speed_pct": 0.12}, None), ({"crit_chance": 0.10}, "chain_lightning")],
     ["Umbra Edge", "Corona Bow", "Eclipse Staff", "Eclipse Visage", "Penumbra Plate", "Dusk Gauntlets", "Shadowfall Boots", "Corona Ring"]),
    ("infinite", "Infinite Regalia", 800, ("#f5f0e6", "#f2c14e", "#8f7a4a", "#9bd8ff"), "regal",
     [({"hp_pct": 0.10}, None), ({"attack_pct": 0.12, "magic_power_pct": 0.12}, None), ({"damage_pct": 0.25, "gold_pct": 0.25, "drop_pct": 0.15}, None)],
     ["Infinity Brand", "Endless Bow", "Staff of Ages", "Crown of Stairs", "Regalia of the Tower", "Gloves of Ascent", "Boots of the Summit", "Ring of Eternity"]),
]

CLASSES = ("knight", "ranger", "arcanist")
CODE = {"knight": "k", "ranger": "r", "arcanist": "a"}
ARMOR = ("helm", "chest", "gloves", "boots", "ring")
# two stat flavours, alternating by tier: sturdy (odd) and sharp (even)
TEMPL = {
    0: {"weapon_k": {"attack": 8, "hp": 10}, "weapon_r": {"attack": 9}, "weapon_a": {"magic_power": 10},
        "helm": {"hp": 14, "defense": 3}, "chest": {"hp": 26, "defense": 5}, "gloves": {"defense": 2, "hp": 8, "power": 2},
        "boots": {"hp": 12, "defense": 3}, "ring": {"hp": 16, "power": 3}},
    1: {"weapon_k": {"attack": 10, "defense": 2}, "weapon_r": {"attack": 10}, "weapon_a": {"magic_power": 11},
        "helm": {"hp": 8, "power": 3}, "chest": {"hp": 18, "power": 4}, "gloves": {"power": 4, "hp": 4},
        "boots": {"hp": 8, "power": 2}, "ring": {"power": 6}},
}
FIXED = {"weapon_r": {"attack_speed_pct": 0.03}, "weapon_a": {"crit_chance": 0.02}, "boots": {"move_speed_pct": 0.02}}
# Class flavour on top of the shared template: the Knight's pieces are sturdy, the
# Ranger's sharp, the Arcanist's magical. "gain" turns a share of the defensive
# stats into offence (flat Attack for Rangers, Magic for Arcanists).
FLAVOUR = {
    "knight": {"hp": 1.15, "defense": 1.25, "power": ("attack", 0.8), "gain": ("attack", 0.0, 0.0), "fixed": {}},
    "ranger": {"hp": 0.80, "defense": 0.70, "power": ("attack", 1.2), "gain": ("attack", 0.04, 0.6), "fixed": {"helm": {"crit_chance": 0.01}}},
    "arcanist": {"hp": 0.70, "defense": 0.60, "power": ("magic_power", 1.2), "gain": ("magic_power", 0.05, 0.8), "fixed": {"helm": {"mana_regen_pct": 0.02}}},
}
# Piece names are "<set> <noun>"; the noun rotates with the set so a catalogue
# does not read the same twenty times. (EN, PT, ES)
NOUNS = {
    "knight": {
        "helm": [("Helm", "Elmo", "Yelmo"), ("Greathelm", "Elmo Pesado", "Yelmo Pesado"), ("Visor", "Viseira", "Visera")],
        "chest": [("Cuirass", "Couraça", "Coraza"), ("Breastplate", "Peitoral", "Peto"), ("Plate", "Armadura", "Armadura de Placas")],
        "gloves": [("Gauntlets", "Manoplas", "Guanteletes"), ("Vambraces", "Braçais", "Brazales"), ("Fists", "Punhos", "Puños")],
        "boots": [("Greaves", "Grevas", "Grebas"), ("Sabatons", "Escarpes", "Escarpes"), ("Treads", "Passos de Placa", "Pasos de Placa")],
        "ring": [("Signet", "Sinete", "Sello"), ("Seal", "Selo", "Sigilo"), ("Crest", "Brasão", "Blasón")]},
    "ranger": {
        "helm": [("Hood", "Capuz", "Capucha"), ("Cowl", "Touca", "Cogulla"), ("Cap", "Boné", "Gorra")],
        "chest": [("Jerkin", "Gibão", "Jubón"), ("Leathers", "Couros", "Cueros"), ("Vest", "Colete", "Chaleco")],
        "gloves": [("Bracers", "Braçadeiras", "Muñequeras"), ("Grips", "Luvas de Couro", "Guantes de Cuero"), ("Wraps", "Faixas", "Vendas")],
        "boots": [("Boots", "Botas", "Botas"), ("Striders", "Passadas", "Zancadas"), ("Moccasins", "Mocassins", "Mocasines")],
        "ring": [("Band", "Anel", "Anillo"), ("Loop", "Aro", "Aro"), ("Talon", "Garra", "Garra")]},
    "arcanist": {
        "helm": [("Circlet", "Diadema", "Diadema"), ("Pointed Hat", "Chapéu Pontudo", "Sombrero Puntiagudo"), ("Diadem", "Tiara", "Tiara")],
        "chest": [("Robe", "Túnica", "Túnica"), ("Vestments", "Vestes", "Vestiduras"), ("Mantle", "Manto", "Manto")],
        "gloves": [("Mitts", "Luvas", "Guantes"), ("Sleeves", "Mangas", "Mangas"), ("Cuffs", "Mitenes", "Mitones")],
        "boots": [("Sandals", "Sandálias", "Sandalias"), ("Slippers", "Chinelos", "Zapatillas"), ("Shoes", "Sapatos", "Zapatos")],
        "ring": [("Sigil", "Sigilo", "Sigilo"), ("Charm", "Amuleto", "Amuleto"), ("Focus", "Foco", "Foco")]},
}
LEGACY_ID = {"weapon_k": "iron_sword", "weapon_r": "short_bow", "weapon_a": "oak_staff"}   # wayfarer keeps old ids
SET_POWER_STEP = 0.08


def fmt(v):
    return f"{v*100:.1f}".rstrip("0").rstrip(".") + "%"


def bonus_text(stats, special):
    parts = [f"+{fmt(v)} {STAT_TXT[k]}" for k, v in stats.items()]
    t = ", ".join(parts)
    if special:
        t += (", " if parts else "") + SPECIAL_TXT[special]
    return t


# Set bonuses PROGRESS: value = base x threshold factor x tier factor. A tier-20 set
# is worth about 4.5x a tier-1 set, and each set has its own identity (stat mix).
BASE = {"attack_pct": 0.06, "magic_power_pct": 0.06, "hp_pct": 0.08, "defense_pct": 0.08, "crit_chance": 0.015,
        "crit_damage": 0.08, "attack_speed_pct": 0.04, "dodge": 0.015, "damage_pct": 0.04, "fire_damage_pct": 0.08,
        "gold_pct": 0.08, "drop_pct": 0.04, "move_speed_pct": 0.05, "lifesteal": 0.02, "thorns": 0.06,
        "regen": 0.003, "mana_regen_pct": 0.12}
THRESH = {"2": 1.0, "4": 1.6, "6": 2.4}
GROUP = {1: 1.0, 2: 0.75, 3: 0.6, 4: 0.5}
TIER_STEP = 0.18
A, M, H, D, C, CD, AS, DG, DM, FD, G, DR, MV, LS, TH, RG, MR = ("attack_pct", "magic_power_pct", "hp_pct", "defense_pct", "crit_chance",
    "crit_damage", "attack_speed_pct", "dodge", "damage_pct", "fire_damage_pct", "gold_pct", "drop_pct", "move_speed_pct", "lifesteal",
    "thorns", "regen", "mana_regen_pct")
BON = {   # set: [(stats at 2p, special), (stats at 4p, special), (stats at 6p, special)]
    "wayfarer": [([MV], None), ([H], None), ([G], None)],
    "gravebound": [([D], None), ([H, LS], None), ([DM, TH], None)],
    "ashen_king": [([A, M], None), ([FD], "fire_imbue"), ([DM, FD], "burning_soul")],
    "verdant_warden": [([H, RG], None), ([D, TH], None), ([RG, H], "regrowth")],
    "stormcaller": [([AS], None), ([C, AS], None), ([CD, C], "chain_lightning")],
    "frostbound": [([D], None), ([DG, D], None), ([AS, DG], None)],
    "prismatic": [([M], None), ([C, M], None), ([CD, M], None)],
    "sunken_tide": [([H], None), ([D, MR], None), ([G, H], None)],
    "dune_nomad": [([G], None), ([DR, MV], None), ([G, DR], None)],
    "forgeborn": [([D], None), ([A, TH], None), ([FD, DM], "fire_imbue")],
    "bloodmoon": [([A], None), ([LS, C], None), ([LS, CD], None)],
    "nightbloom": [([M], None), ([DG, LS], None), ([DM, M], None)],
    "voidtouched": [([DM], None), ([CD, A], None), ([A, M, DM], None)],
    "wraithwoven": [([DG], None), ([MV, DG], None), ([AS, DG, LS], None)],
    "radiant_choir": [([H], None), ([D, RG], None), ([H, MR], "regrowth")],
    "titanforge": [([H, D], None), ([A, H], None), ([D, TH, H], None)],
    "dragonscale": [([A], None), ([FD, C], None), ([DM, FD], "burning_soul")],
    "starfall": [([C], None), ([M, MR], None), ([CD, C], None)],
    "eclipse": [([DM], None), ([AS, CD], None), ([C, DM], "chain_lightning")],
    "infinite": [([H, A, M], None), ([DM, G], None), ([DM, G, DR, LS], None)],
}

old_sets = data["sets"]
bases, sets = [], {}
NAMES_I18N = {}     # "<English name>": [pt, es]
set_tr = {}         # set name -> (pt, es), from the existing language packs
for lang_i, lang in enumerate(("pt", "es")):
    pack = json.loads((ROOT / "data" / "lang" / f"{lang}.json").read_text())
    for sid_, name_, *_rest in SETS:
        set_tr.setdefault(name_, [name_, name_])[lang_i] = pack.get(name_, name_)


def add_base(bid, nm, slot, cls, sid, stats, fixed):
    b = {"id": bid, "name": nm, "slot": slot, "class": cls, "set": sid, "icon": bid, "stats": stats}
    if fixed:
        b["fixed"] = dict(fixed)
    bases.append(b)


for i, (sid, name, floor, pal, motif, bon, names) in enumerate(SETS):
    mult = 1 + SET_POWER_STEP * i
    pieces, weapons = {}, {}
    # weapons: one per class, named by hand
    for wkey, wname in zip(("weapon_k", "weapon_r", "weapon_a"), names[:3]):
        cls = {"weapon_k": "knight", "weapon_r": "ranger", "weapon_a": "arcanist"}[wkey]
        bid = LEGACY_ID[wkey] if sid == "wayfarer" else f"{sid}_{wkey}"
        stats = {k: round(v * mult, 1) for k, v in TEMPL[i % 2][wkey].items()}
        add_base(bid, wname, "weapon", cls, sid, stats, FIXED.get(wkey))
        weapons[cls] = wname
    # armour and ring: one piece per class, "<set> <noun>"
    for slot in ARMOR:
        tmpl = {k: v * mult for k, v in TEMPL[i % 2][slot].items()}
        for cls in CLASSES:
            fl = FLAVOUR[cls]
            en, pt, es = NOUNS[cls][slot][i % 3]
            nm = f"{name} {en}"
            NAMES_I18N[nm] = [f"{pt} {set_tr[name][0]}", f"{es} {set_tr[name][1]}"]
            stats = {}
            hp, de, po = tmpl.get("hp", 0.0), tmpl.get("defense", 0.0), tmpl.get("power", 0.0)
            if hp:
                stats["hp"] = round(hp * fl["hp"], 1)
            if de:
                stats["defense"] = round(de * fl["defense"], 1)
            key, k = fl["power"]
            off = po * k
            gkey, g_hp, g_de = fl["gain"]
            off += (hp * g_hp + de * g_de) if gkey == key else 0.0
            if off > 0.0:
                stats[key] = round(off, 1)
            fixed = dict(FIXED.get(slot, {}))
            fixed.update(fl["fixed"].get(slot, {}))
            add_base(f"{sid}_{slot}_{CODE[cls]}", nm, slot, cls, sid, stats, fixed)
            if cls == "knight":
                pieces[slot] = nm
    pieces = {"weapon": names[0], **pieces}
    bonuses = {}
    tier_mult = 1 + TIER_STEP * i
    for th, (stats_list, sp) in zip(("2", "4", "6"), BON[sid]):
        vals = {k: round(BASE[k] * THRESH[th] * tier_mult * GROUP[len(stats_list)], 4) for k in stats_list}
        e = {"stats": vals, "text": bonus_text(vals, sp)}
        if sp:
            e["specials"] = [sp]
        bonuses[th] = e
    sets[sid] = {"name": name, "tier": i + 1, "min_floor": floor, "power": round(mult, 2),
                 "art": {"main": pal[0], "accent": pal[1], "dark": pal[2], "glow": pal[3], "motif": motif},
                 "pieces": pieces, "weapons": weapons, "bonuses": bonuses}

data["bases"] = bases
data["sets"] = sets
data["set_order"] = [s[0] for s in SETS]
data.pop("set_chance", None)
data["forge"]["evolve"] = {
    "_comment": "Evolve: burn `count` bag items of one set, kind and rarity into ONE item of the NEXT set in set_order (same rarity). Class-bound pieces have `class_change` chance to come out as another class.",
    "count": 3, "class_change": 0.25, "tier_growth": 1.3,
    "costs": {"common": {"gold": 30, "crystals": 0}, "uncommon": {"gold": 80, "crystals": 0},
              "rare": {"gold": 240, "crystals": 0}, "epic": {"gold": 800, "crystals": 2},
              "legendary": {"gold": 3000, "crystals": 10}, "mythic": {"gold": 9000, "crystals": 30}},
}
P.write_text(json.dumps(data, indent="\t") + "\n")
# Translations of the generated piece names, merged into the language packs by tools/i18n/build.py.
(ROOT / "tools" / "i18n" / "gear_names.json").write_text(json.dumps(NAMES_I18N, indent="\t", ensure_ascii=False) + "\n")
print(len(bases), "bases in", len(sets), "sets;", len(NAMES_I18N), "piece names")
