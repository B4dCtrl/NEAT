#!/usr/bin/env python3
"""Regenerates the `bases` and `sets` sections of data/items.json.

The gear catalogue is a chain of 20 sets (tier 1..20). Every set has 8 pieces:
one weapon per class (knight / ranger / arcanist), helm, chest, gloves, boots and
ring. Merging ("Evolve") turns a piece of tier N into the same slot of tier N+1.
Edit SETS below and run:  python3 -I tools/gen_item_data.py
Then re-render the art:   godot --path . -s res://tools/gen_item_art.gd
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
P = ROOT / "data" / "items.json"
data = json.loads(P.read_text())

STAT_TXT = {"attack_pct": "Attack", "magic_power_pct": "Magic", "hp_pct": "HP", "defense_pct": "Defense",
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

SLOTS = ["weapon_k", "weapon_r", "weapon_a", "helm", "chest", "gloves", "boots", "ring"]
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
SLOT_OF = {"weapon_k": ("weapon", "knight"), "weapon_r": ("weapon", "ranger"), "weapon_a": ("weapon", "arcanist"),
           "helm": ("helm", ""), "chest": ("chest", ""), "gloves": ("gloves", ""), "boots": ("boots", ""), "ring": ("ring", "")}
LEGACY_ID = {"weapon_k": "iron_sword", "weapon_r": "short_bow", "weapon_a": "oak_staff"}   # wayfarer keeps old ids
SET_POWER_STEP = 0.08


def fmt(v):
    return f"{v*100:g}%"


def bonus_text(stats, special):
    parts = [f"+{fmt(v)} {STAT_TXT[k]}" for k, v in stats.items()]
    t = ", ".join(parts)
    if special:
        t += (", " if parts else "") + SPECIAL_TXT[special]
    return t


old_sets = data["sets"]
bases, sets = [], {}
for i, (sid, name, floor, pal, motif, bon, names) in enumerate(SETS):
    mult = 1 + SET_POWER_STEP * i
    pieces, weapons = {}, {}
    for slot_key, nm in zip(SLOTS, names):
        slot, cls = SLOT_OF[slot_key]
        bid = LEGACY_ID.get(slot_key) if sid == "wayfarer" and slot_key in LEGACY_ID else f"{sid}_{slot_key}"
        stats = {k: round(v * mult, 1) for k, v in TEMPL[i % 2][slot_key].items()}
        b = {"id": bid, "name": nm, "slot": slot, "class": cls, "set": sid, "icon": bid, "stats": stats}
        if slot_key in FIXED:
            b["fixed"] = dict(FIXED[slot_key])
        bases.append(b)
        if slot == "weapon":
            weapons[cls] = nm
        else:
            pieces[slot] = nm
    pieces = {"weapon": names[0], **pieces}
    if sid in old_sets:                       # keep the bonuses already tuned and tested
        bonuses = old_sets[sid]["bonuses"]
    else:
        bonuses = {}
        for th, (st, sp) in zip(("2", "4", "6"), bon):
            e = {"stats": st, "text": bonus_text(st, sp)}
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
    "_comment": "Evolve: burn `count` bag items of one set, kind and rarity into ONE item of the NEXT set in set_order (same rarity). Weapons have `class_change` chance to come out as another class.",
    "count": 3, "class_change": 0.25, "tier_growth": 1.3,
    "costs": {"common": {"gold": 30, "crystals": 0}, "uncommon": {"gold": 80, "crystals": 0},
              "rare": {"gold": 240, "crystals": 0}, "epic": {"gold": 800, "crystals": 2},
              "legendary": {"gold": 3000, "crystals": 10}, "mythic": {"gold": 9000, "crystals": 30}},
}
P.write_text(json.dumps(data, indent="\t") + "\n")
print(len(bases), "bases in", len(sets), "sets")
