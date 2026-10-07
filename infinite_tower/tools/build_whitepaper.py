#!/usr/bin/env python3
"""Builds the Stairborn asset & stats whitepaper (single HTML page).

  godot ... -s res://tools/export_asset_images.gd -- <img_dir>      # once
  python3 -I tools/build_whitepaper.py <img_dir> <out.html>

Every number is read from data/*.json, so the document cannot drift from the game.
"""
import base64, html, json, math, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMG = Path(sys.argv[1])
OUT = Path(sys.argv[2])


def J(name):
    return json.loads((ROOT / "data" / f"{name}.json").read_text())


classes, en, items = J("classes"), J("enemies"), J("items")
skills, asc, fl = J("skill_tree"), J("ascension_tree"), J("floor_rules")
bal = fl["balance"]
e = html.escape


def img(group, id_, cls="px", alt=None):
    p = IMG / group / f"{id_}.png"
    if not p.exists():
        return '<span class="noimg">–</span>'
    b = base64.b64encode(p.read_bytes()).decode()
    return f'<img class="{cls}" alt="{e(alt or id_)}" src="data:image/png;base64,{b}">'


def pct(x, d=0):
    return f"{x*100:.{d}f}%"


def num(x):
    """pt-BR: '.' thousands, ',' decimals; k/M/B above 100k."""
    x = float(x)
    for lim, suf in ((1e9, "B"), (1e6, "M"), (1e5, "k")):
        if x >= lim:
            return f"{x/(lim if suf != 'k' else 1e3):.1f}".replace(".", ",") + suf
    if abs(x - round(x)) < 0.05:
        return f"{round(x):,}".replace(",", ".")
    return f"{x:,.1f}".replace(",", "_").replace(".", ",").replace("_", ".")


def table(head, rows, cls=""):
    h = "".join(f"<th>{e(str(c))}</th>" for c in head)
    r = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in row) + "</tr>" for row in rows)
    return f'<div class="tw"><table class="{cls}"><thead><tr>{h}</tr></thead><tbody>{r}</tbody></table></div>'


STAT = {"hp": "HP", "attack": "Ataque", "defense": "Defesa", "magic_power": "Magia", "attack_speed": "Vel. ataque",
        "crit_chance": "Crítico", "crit_damage": "Dano crít.", "dodge": "Esquiva", "power": "Poder"}
AFFIX = {"attack_pct": "Ataque %", "magic_power_pct": "Magia %", "hp_pct": "HP %", "defense_pct": "Defesa %",
         "crit_chance": "Chance crít.", "crit_damage": "Dano crít.", "attack_speed_pct": "Vel. ataque %",
         "dodge": "Esquiva", "damage_pct": "Dano %", "fire_damage_pct": "Dano de fogo %", "gold_pct": "Ouro %",
         "drop_pct": "Drop %", "move_speed_pct": "Vel. subida %"}
RAR = items["rarities"]
RAR_PT = {"common": "Comum", "uncommon": "Incomum", "rare": "Raro", "epic": "Épico", "legendary": "Lendário",
          "mythic": "Mítico", "relic": "Relíquia"}
HRAR = bal["hero_rarities"]


def rchip(r):
    return f'<span class="chip" style="--c:{RAR[r]["color"]}">{RAR_PT[r]}</span>'


def card(group, id_, name, lines, big=False):
    body = "".join(f"<div>{l}</div>" for l in lines)
    return (f'<div class="card"><div class="art{" big" if big else ""}">{img(group, id_, alt=name)}</div>'
            f'<div class="cname">{e(name)}</div><div class="cbody">{body}</div></div>')


# ---------------------------------------------------------------- numbers used all over
n_classes = len(classes)
hireable = [k for k, v in classes.items() if not v.get("founder")]
enemies, bosses = en["enemies"], en["bosses"]
n_nodes = sum(len(v["nodes"]) for v in skills["classes"].values())
n_active = sum(1 for v in skills["classes"].values() for n in v["nodes"].values() if n["kind"] == "active")
bases = items["bases"]
kinds = sorted({f'{b["slot"]}/{b["class"]}' for b in bases})
sets = items["sets"]
relics = items["relics"]
cons = items["consumables"]
biomes = fl["biomes"]
names = bal["hero_names"]
counts = [
    ("Classes", n_classes, f"1 fundador + {len(hireable)} mintáveis"),
    ("Monstros", len(enemies), "comuns, com variações de cor"),
    ("Chefes", len(bosses), "3 patamares cada"),
    ("Afixos de monstro", len(en["affixes"]), "a partir do andar 5"),
    ("Bases de item", len(bases), f"{len(items['slots'])} espaços"),
    ("Afixos de item", len(items["affixes"]), "0–5 por item"),
    ("Raridades", 6, "+ Relíquia"),
    ("Conjuntos", len(sets), "2 / 4 / 6 peças"),
    ("Relíquias", len(relics), "únicas, 2 espaços"),
    ("Consumíveis", len(cons), "poções, buffs, bombas, tempo"),
    ("Nós de habilidade", n_nodes, f"{n_active} ativos"),
    ("Nós de Ascensão", len(asc["nodes"]), "meta-progressão"),
    ("Biomas", len(biomes), f"{fl['biome_span']} andares cada"),
    ("Santuários", len(fl["shrines"]), "eventos de andar"),
    ("Nomes de herói", len(names), "no sorteio do mint"),
]
total_assets = len(json.loads((IMG / "index.json").read_text()))

# ---------------------------------------------------------------- classes
def class_stat(c, lv):
    out = {}
    for k, v in c["base"].items():
        out[k] = v + c["growth"].get(k, 0) * (lv - 1)
    out["mana"] = c["mana"]["max"] + c["mana"]["per_level"] * (lv - 1)
    return out


cls_html = ""
for cid, c in classes.items():
    s1, s25, s50, s100 = (class_stat(c, l) for l in (1, 25, 50, 100))
    rows = []
    for k in ("hp", "attack", "defense", "mana"):
        lab = STAT.get(k, "Mana")
        rows.append([lab] + [num(s[k]) for s in (s1, s25, s50, s100)])
    rows.append(["Vel. ataque", *[f'{c["base"]["attack_speed"]:.2f}/s'] * 4])
    rows.append(["Crítico / dano", *[f'{pct(c["base"]["crit_chance"])} · ×{c["base"]["crit_damage"]:.1f}'] * 4])
    rows.append(["Esquiva", *[pct(c["base"]["dodge"])] * 4])
    rows.append(["Regen. mana", *[f'{c["mana"]["regen"]}/s'] * 4])
    tree = skills["classes"][cid]["nodes"]
    nodes = "".join(
        f'<li><span class="gl">{img("glyphs", n.get("icon", "star"), "px sm")}</span><b>{e(n["name"])}</b> '
        f'<em>{"ativa" if n["kind"] == "active" else "passiva"} · máx {n["max"]}</em><br><small>{e(n["text"])}</small></li>'
        for n in tree.values())
    base_sk = "".join(f'<li><b>{e(s["name"])}</b> <em>Nv {s["level"]} · {s["cooldown"]:.0f}s · {s.get("mana", 0)} mana</em><br><small>{e(s["description"])}</small></li>'
                      for s in c["skills"])
    uses = f' · usa itens de {", ".join(c["uses"])}' if c.get("uses") else ""
    cls_html += f'''
<article class="classbox">
  <div class="chead">{img("classes", cid, "px lg")}<div><h3>{e(c["name"])}</h3>
  <p class="muted">{e(c["role"])} · {"fundador (único, já nasce no jogo)" if c.get("founder") else "mintável"} · dano {c["damage_type"]} · ataque {c["attack_pattern"]}{uses}</p>
  <p class="muted">Arma inicial: <b>{e(c["starter_weapon"].replace("_"," "))}</b> · agro {c["aggro"]:g} · fila {c["default_row"]}</p></div></div>
  {table(["Atributo","Nv 1","Nv 25","Nv 50","Nv 100"], rows)}
  <div class="two"><div><h4>Habilidades de nascença</h4><ul class="sk">{base_sk}</ul></div>
  <div><h4>Árvore Ragnarok ({len(tree)} nós)</h4><ul class="sk">{nodes}</ul></div></div>
</article>'''

# ---------------------------------------------------------------- monsters
def scaled(floor_num):
    sc = en["scaling"]
    n = floor_num - 1
    return (sc["hp_growth"] ** n, sc["attack_growth"] ** n, sc["defense_growth"] ** n, sc["gold_growth"] ** n,
            sc["xp_scale"] * (1 + n * sc["xp_linear"]) ** sc["xp_power"])


mon_cards = ""
for mid, m in enemies.items():
    tr = ", ".join(f"{k} {v:g}" for k, v in m.get("traits", {}).items())
    mon_cards += card("enemies", mid, m["name"], [
        f'HP <b>{num(m["hp"])}</b> · ATQ <b>{m["attack"]}</b> · DEF <b>{m["defense"]}</b>',
        f'Vel {m["attack_speed"]}/s · crít {pct(m["crit_chance"])} · esq {pct(m["dodge"])}',
        f'{m["damage_type"]} · ouro {m["gold"]} · xp {m["xp"]}',
        *([f"traço: {tr}"] if tr else [])])

boss_cards = ""
for bid, b in bosses.items():
    sk = " · ".join(f'{s["name"]} ({s["type"]}, {s["cooldown"]:g}s)' for s in b.get("skills", []))
    boss_cards += card("bosses", bid, b["name"], [
        f'HP <b>{num(b["hp"])}</b> · ATQ <b>{b["attack"]}</b> · DEF <b>{b["defense"]}</b>',
        f'Vel {b["attack_speed"]}/s · {b["damage_type"]} · ouro {b["gold"]} · xp {b["xp"]}',
        f'<small>{e(sk)}</small>'], big=True)

fl_rows = []
for f in (1, 10, 25, 50, 100, 200, 400):
    h, a, d, g, x = scaled(f)
    fl_rows.append([f, f"×{h:.2f}", f"×{a:.2f}", f"×{d:.2f}", f"×{g:.2f}", f"×{x:.1f}"])
aff_rows = [[e(v["name"]), v["min_floor"], v["weight"],
             e(", ".join([f"{k} ×{x:g}" for k, x in v.get("mult", {}).items()] +
                         [f"{k} +{x:g}" for k, x in v.get("add", {}).items()] +
                         [f"{k} {x:g}" for k, x in v.get("traits", {}).items()]))] for v in en["affixes"].values()]
tier_rows = [[v["name"], f'×{v["hp_mult"]}', f'×{v["attack_mult"]}', f'×{v["gold_mult"]}', v["minions"]]
             for v in en["scaling"]["boss_tiers"].values()]
biome_rows = "".join(
    f'<tr><td>{i*fl["biome_span"]+1}–{(i+1)*fl["biome_span"]}</td><td>{e(b["name"])}</td>'
    f'<td>{", ".join(e(enemies[x]["name"]) for x in b["enemies"])}</td>'
    f'<td>{", ".join(e(bosses[x]["name"]) for x in b["bosses"])}</td></tr>' for i, b in enumerate(biomes))

# ---------------------------------------------------------------- items
item_cards = ""
for b in bases:
    st = " · ".join(f"{STAT.get(k, k)} {v:g}" for k, v in b["stats"].items())
    item_cards += card("items", b["id"], b["name"], [f'{b["slot"]}{" · " + b["class"] if b["class"] else ""}', st])
rar_rows = []
for r, d in RAR.items():
    if r == "relic":
        continue
    cap = f'1 a cada {d["cap_floors"]} andares' if "cap_floors" in d else "sem limite"
    rar_rows.append([rchip(r), f'×{d["mult"]}', d["affixes"], d["weight"], cap, d["salvage"]])
ilvls = (1, 25, 50, 100)
sword_rows = []
for r in ("common", "uncommon", "rare", "epic", "legendary", "mythic"):
    sword_rows.append([rchip(r)] + [num(7 * RAR[r]["mult"] * items["item_growth"] ** (l - 1)) for l in ilvls])
affix_rows = [[AFFIX.get(a["stat"], a["stat"]), f'{a["min"]:g}–{a["max"]:g}', e(a["suffix"]),
               ", ".join(a.get("slots", [])) or "todos"] for a in items["affixes"]]
set_html = ""
for sid, s in sets.items():
    pieces = "".join(f'<div class="setp">{img("slots", sl, "px sm")}<span>{e(nm)}<br><small>{sl}</small></span></div>'
                     for sl, nm in s["pieces"].items())
    bon = "".join(f'<li><b>{k} peças:</b> {e(v["text"])}</li>' for k, v in s["bonuses"].items())
    set_html += f'<div class="setbox"><h4>{e(s["name"])} <em>a partir do andar {s["min_floor"]}</em></h4><div class="setrow">{pieces}</div><ul>{bon}</ul></div>'
relic_cards = "".join(card("relics", "relic", v["name"], [e(v["description"])]) for v in relics.values())
cons_cards = "".join(card("consumables", k, v["name"], [e(v["text"]), f'preço {v["price"]} · peso {v["weight"]}']) for k, v in cons.items())

# ---------------------------------------------------------------- merge
F = items["forge"]["recipes"]
order = ["common", "uncommon", "rare", "epic", "legendary"]
def merges_for(target_idx):
    """number of merges of each step needed to build ONE item of order[target_idx+1]."""
    need, out = 1, {}
    for i in range(target_idx, -1, -1):
        out[order[i]] = need
        need *= F[order[i]]["count"]
    return out, need
merge_rows = []
for r in order:
    d = F[r]
    g50 = d["gold"] * items["item_growth"] ** 49
    merge_rows.append([rchip(r), f'{d["count"]} itens', rchip(d["to"]), num(d["gold"]), num(g50), d["crystals"]])
chain_rows = []
for i, r in enumerate(order):
    steps, commons = merges_for(i)
    gold1 = sum(F[k]["gold"] * n for k, n in steps.items())
    cry = sum(F[k]["crystals"] * n for k, n in steps.items())
    chain_rows.append([rchip(F[r]["to"]), num(commons), sum(steps.values()), num(gold1), num(gold1 * items["item_growth"] ** 49), cry])
kind_rows = []
for k in kinds:
    slot, cl = k.split("/")
    kind_rows.append([k.replace("/", " · ") if cl else k.replace("/", ""), ", ".join(b["name"] for b in bases if f'{b["slot"]}/{b["class"]}' == k)])

# ---------------------------------------------------------------- mint
hire = bal["hire"]
mint_rows = []
cum = 0
for n in range(0, 12):
    c = math.floor(hire["mint_gold_base"] * hire["mint_gold_growth"] ** n)
    cum += c
    mint_rows.append([n + 1, num(c), num(cum), num(math.floor(c * 0.4)) + " (−60%)"])
wsum = sum(v["weight"] for v in HRAR.values())
hr_rows = []
for r, v in HRAR.items():
    p = v["weight"] / wsum
    hr_rows.append([rchip(r), f'×{v["potential"]}', pct(p, 1), f"1 em {1/p:.0f}"])
luck_rows = []
for L in (0, 0.2, 0.5, 1.0, 2.0):
    w = {k: v["weight"] * (1 if k == "common" else 1 + L) for k, v in HRAR.items()}
    t = sum(w.values())
    luck_rows.append([f"+{int(L*100)}%"] + [pct(w[k] / t, 1) for k in HRAR])
combos = len(hireable) * len(names) * len(HRAR)
hire_rows = [[n + 1, num(math.floor(hire["gold_base"] * hire["gold_growth"] ** n))] for n in range(0, 6)]

# ---------------------------------------------------------------- progression
asc_rows = [[e(v["name"]), v["max"], f'{v["cost"]} (×{v["cost_growth"]})', e(v["text"])] for v in asc["nodes"].values()]
train_rows = [[e(v["name"]), ", ".join(f"{AFFIX.get(k, k)} +{pct(x)}" for k, x in v["stats"].items()), v["base_cost"], f'×{v["cost_growth"]}'] for v in bal["training"].values()]
shrine_rows = [[e(s["name"]), s["weight"], s["floors"] or "—", e(s["text"])] for s in fl["shrines"]]
ms_rows = [[m["floor"], e(m["name"]), m["crystals"]] for m in fl["milestones"]]
xp_rows = [[l, num(50 * (l * l - 3 * l + 4)), num(sum(50 * (k * k - 3 * k + 4) for k in range(1, l)))] for l in (2, 5, 10, 20, 30, 50, 75, 100, 150, 200)]
chest_rows = [[k.capitalize(), v["items"], RAR_PT[v["min_rarity"]], pct(v["relic_chance"]), v["crystals"]] for k, v in bal["chest"].items()]

cons_icons = "".join(f'<div class="ic">{img("icons", i, "px sm")}<span>{i}</span></div>' for i in ["coin", "skull", "relic", "soul", "crystal", "floor", "sword", "market"])
glyph_ids = sorted(p.stem for p in (IMG / "glyphs").glob("*.png"))
glyph_html = "".join(f'<div class="ic">{img("glyphs", g, "px sm")}<span>{g}</span></div>' for g in glyph_ids)
slot_html = "".join(f'<div class="ic">{img("slots", s, "px sm")}<span>{s}</span></div>' for s in items["slots"])
count_html = "".join(f'<div class="cnt"><b>{n}</b><span>{e(l)}</span><small>{e(s)}</small></div>' for l, n, s in counts)

CSS = open(ROOT / "tools" / "whitepaper.css").read()
doc = f'''<title>Stairborn Whitepaper</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&family=Pixelify+Sans:wght@500;700&display=swap" rel="stylesheet">
<style>{CSS}</style>
<nav class="top"><b>STAIRBORN</b><a href="#numeros">Números</a><a href="#classes">Classes</a><a href="#monstros">Monstros</a><a href="#chefes">Chefes</a><a href="#itens">Itens</a><a href="#merge">Merge</a><a href="#mint">Mint</a><a href="#progressao">Progressão</a><a href="#ui">Ícones</a><a href="#notas">Notas</a></nav>
<main>
<header class="hero">
  <div class="heroimgs">{img("classes","stairborn","px xl")}{img("classes","knight","px xl")}{img("classes","ranger","px xl")}{img("classes","arcanist","px xl")}</div>
  <p class="kicker">WHITEPAPER · v{e(open(ROOT/"project.godot").read().split('config/version="')[1].split('"')[0])}</p>
  <h1>Stairborn</h1>
  <p class="lede">Catálogo completo do jogo: cada arte, cada atributo, cada fórmula. Tudo abaixo é lido direto dos arquivos de dados do jogo, então reflete exatamente o que está no build. {total_assets} imagens renderizadas pelo próprio motor.</p>
</header>

<section id="numeros"><h2>1. Tudo em números</h2>
<p>Resumo de quantas coisas existem. As seções seguintes mostram cada uma delas.</p>
<div class="cnts">{count_html}</div>
<p class="callout"><b>Classes: {n_classes}.</b> O <b>Stairborn</b> é o fundador, único, e já nasce no jogo (não pode ser mintado). Cavaleiro, Arqueiro e Arcanista são as {len(hireable)} classes que o <b>Mint</b> sorteia. Cada classe tem 6 nós de árvore (3 ativos, o Arcanista 4) e 3 habilidades de nascença.</p>
</section>

<section id="classes"><h2>2. Classes ({n_classes})</h2>
<p>Atributos por nível = base + crescimento × (nível − 1). Valores abaixo são <b>sem equipamento, sem árvore e sem potencial de raridade</b>; o herói mintado multiplica os atributos de nascença pelo seu potencial (×1,00 a ×1,42). O XP segue a curva do Tibia: XP para o próximo nível = 50·(L² − 3L + 4).</p>
{cls_html}
<h3>Curva de XP (Tibia)</h3>
{table(["Nível","XP até o próximo","XP total acumulado"], xp_rows)}
<p class="muted">Cada nível dá 1 ponto de habilidade ({skills["points_per_level"]}). Nível máximo {bal["max_level"]}.</p>
</section>

<section id="monstros"><h2>3. Monstros ({len(enemies)})</h2>
<p>Valores no <b>andar 1</b>. Os monstros crescem exponencialmente por andar (tabela abaixo) e, a partir do andar 5, podem aparecer com um afixo ({int(en["affix_chance"]["base"]*100)}% de chance + {en["affix_chance"]["per_floor"]*100:.1f}% por andar, máximo {pct(en["affix_chance"]["max"])}). Variações de cor (“Shade Troll”, “Moss Slime”…) reaproveitam a arte com outro matiz.</p>
<div class="grid">{mon_cards}</div>
<h3>Escala por andar</h3>
{table(["Andar","HP","Ataque","Defesa","Ouro","XP"], fl_rows)}
<p class="muted">Crescimento por andar: HP ×{en["scaling"]["hp_growth"]}, ataque ×{en["scaling"]["attack_growth"]}, defesa ×{en["scaling"]["defense_growth"]}, ouro ×{en["scaling"]["gold_growth"]}. XP = {en["scaling"]["xp_scale"]:g} × (1 + {en["scaling"]["xp_linear"]}·(andar−1))^{en["scaling"]["xp_power"]:g}.</p>
<h3>Afixos de monstro ({len(en["affixes"])})</h3>
{table(["Afixo","Andar mín.","Peso","Efeito"], aff_rows)}
<h3>Biomas ({len(biomes)})</h3>
<div class="tw"><table><thead><tr><th>Andares (ciclo)</th><th>Bioma</th><th>Monstros</th><th>Chefes</th></tr></thead><tbody>{biome_rows}</tbody></table></div>
</section>

<section id="chefes"><h2>4. Chefes ({len(bosses)})</h2>
<p>Um chefe a cada 10 andares. O patamar sobe com a profundidade e multiplica os valores base (andar 1 mostrado abaixo).</p>
<div class="grid wide">{boss_cards}</div>
<h3>Patamares</h3>
{table(["Patamar","HP","Ataque","Ouro / XP","Lacaios"], tier_rows)}
<h3>Baús de chefe</h3>
{table(["Patamar","Itens","Raridade mín.","Chance de relíquia","Cristais"], chest_rows)}
</section>

<section id="itens"><h2>5. Itens</h2>
<h3>Bases de equipamento ({len(bases)})</h3>
<p>6 espaços: {", ".join(items["slots"])}. Armas são específicas de classe (Cavaleiro, Arqueiro, Arcanista); o resto é livre.</p>
<div class="slots">{slot_html}</div>
<div class="grid">{item_cards}</div>
<h3>Raridades</h3>
{table(["Raridade","Multiplicador","Afixos","Peso de drop","Limite (economia)","Sucata"], rar_rows)}
<p class="muted">Épico, Lendário e Mítico têm tempo de recarga em andares: se um deles já caiu recentemente, o próximo é rebaixado. Relíquias caem de chefes a partir do andar {bal["relic_min_floor"]}.</p>
<h3>Exemplo: Espada de Ferro (ataque base 7)</h3>
{table(["Raridade"]+[f"item lvl {l}" for l in ilvls], sword_rows)}
<p class="muted">Atributo base × multiplicador de raridade × {items["item_growth"]}^(nível−1), com variação aleatória de ±10%. O nível do item é o andar em que caiu.</p>
<h3>Afixos de item ({len(items["affixes"])})</h3>
{table(["Atributo","Faixa","Sufixo","Espaços"], affix_rows)}
<h3>Conjuntos ({len(sets)})</h3>
<p>Peças de conjunto só caem em Épico ou superior ({pct(items["set_chance"])} de chance por item elegível).</p>
{set_html}
<h3>Relíquias ({len(relics)})</h3>
<p>{bal["base_relic_slots"]} espaços de relíquia (até 4 com a Ascensão “Relic Vault”). Todas usam o mesmo ícone por enquanto.</p>
<div class="grid">{relic_cards}</div>
<h3>Consumíveis ({len(cons)})</h3>
<p>Chance de drop de consumível por vitória: {pct(items["consumable_drop_chance"])}. Poções e bombas são usadas automaticamente; buffs duram andares; tempo e teleporte são ativos.</p>
<div class="grid">{cons_cards}</div>
</section>

<section id="merge"><h2>6. Merge de itens</h2>
<p class="callout">O Merge <b>queima itens fracos para criar um item da raridade acima</b>. É o principal ralo de ouro e itens do jogo: quanto mais alto, exponencialmente mais caro. <b>Não existe merge de heróis</b>: heróis são obtidos pelo Mint ou pelo Mercado.</p>
<h3>Como funciona</h3>
<ol class="steps">
<li><b>Agrupamento.</b> Só itens da <b>mesma raridade</b> e do <b>mesmo tipo</b> se juntam. Tipo = espaço + classe: existem {len(kinds)} tipos ({", ".join(k.replace("/", " ").strip() for k in kinds)}).</li>
<li><b>Custo.</b> Escolha o grupo e o jogo mostra a cotação: quantidade de itens + ouro (+ cristais para Épico+). O ouro sobe ×{items["item_growth"]} por nível do item mais alto do grupo.</li>
<li><b>Queima.</b> Os N itens <b>mais fracos</b> do grupo são destruídos. Itens equipados e itens <i>vinculados</i> (bound) nunca entram.</li>
<li><b>Resultado.</b> Nasce <b>um item aleatório do mesmo tipo</b>, uma raridade acima, com nível = o maior nível entre os queimados, marcado como “forjado”.</li>
</ol>
<h3>Receitas</h3>
{table(["Entra","Quantidade","Sai","Ouro (nível 1)","Ouro (nível 50)","Cristais"], merge_rows)}
<h3>Quanto custa chegar lá (do zero, só de itens comuns)</h3>
{table(["Resultado","Itens comuns necessários","Merges","Ouro (nível 1)","Ouro (nível 50)","Cristais"], chain_rows)}
<p class="muted">Um Mítico exige {num(merges_for(4)[1])} comuns do mesmo tipo: na prática o Merge serve para fabricar até Raro/Épico com segurança; Lendário e Mítico dependem principalmente de drop e chefes.</p>
<h3>Tipos de item (os {len(kinds)} grupos de Merge)</h3>
{table(["Tipo","Bases incluídas"], kind_rows)}
<p class="muted"><b>Nota de design:</b> itens forjados <b>não</b> passam pelo limite de recarga de raridade dos drops. É intencional (o custo exponencial é o freio) e está listado nas notas finais.</p>
</section>

<section id="mint"><h2>7. Mint de heróis</h2>
<p class="callout">O <b>Mint</b> gera um herói <b>do zero</b> pagando ouro. O Stairborn (fundador) é o único que nasce sem custo; os próximos {bal["party_slots"]-1} espaços do grupo e o banco são preenchidos por Mint ou compra no Mercado.</p>
<h3>Como funciona</h3>
<ol class="steps">
<li><b>Pague.</b> Custo = {hire["mint_gold_base"]} × {hire["mint_gold_growth"]}^(mints já feitos), arredondado para baixo. Cada Mint encarece o próximo em ×{hire["mint_gold_growth"]}.</li>
<li><b>Sorteio (determinístico por conta).</b> Classe uniforme entre as {len(hireable)} mintáveis ({", ".join(classes[h]["name"] for h in hireable)}), nome entre {len(names)} opções, raridade pela tabela abaixo.</li>
<li><b>Potencial.</b> A raridade do herói multiplica seus atributos de nascença (×{HRAR["common"]["potential"]} a ×{HRAR["legendary"]["potential"]}). Equipamento e árvore somam por cima.</li>
<li><b>Destino.</b> Entra no grupo se houver espaço ({bal["party_slots"]} espaços); senão vai para o banco. Você escolhe quem equipar na tela de Heróis.</li>
<li><b>Bônus de Ascensão.</b> Guild Contracts (até −60% de custo), Veteran Recruits (nasce em nível mais alto) e Noble Blood (mais chance de raridade alta).</li>
</ol>
<h3>Chance de raridade</h3>
{table(["Raridade","Potencial","Chance","Frequência"], hr_rows)}
<h3>Com Noble Blood (sorte)</h3>
<p class="muted">Cada +X% de sorte multiplica o peso de todas as raridades acima de Comum por (1 + X).</p>
{table(["Sorte"]+[RAR_PT[k] for k in HRAR], luck_rows)}
<h3>Preço dos primeiros Mints</h3>
{table(["Mint nº","Custo","Total acumulado","Com desconto máx."], mint_rows)}
<p class="muted">Existem {combos} combinações de herói possíveis ({len(hireable)} classes × {len(names)} nomes × {len(HRAR)} raridades). Compra direta (Mercado/contratação): {hire["gold_base"]} × {hire["gold_growth"]:g}^(heróis − 1): {", ".join(str(r[1]) for r in hire_rows[:4])}…</p>
</section>

<section id="progressao"><h2>8. Progressão e economia</h2>
<h3>Ascensão ({len(asc["nodes"])} nós)</h3>
<p>Ao reiniciar a torre (andar {bal["ascension_min_floor"]}+) você ganha Almas = (andar / {bal["soul_divisor"]:g})^{bal["soul_exponent"]}, gastas aqui para sempre.</p>
{table(["Nó","Máx.","Custo","Efeito"], asc_rows)}
<h3>Treino (ouro)</h3>
{table(["Treino","Efeito por nível","Custo base","Crescimento"], train_rows)}
<h3>Santuários ({len(fl["shrines"])})</h3>
{table(["Santuário","Peso","Andares","Efeito"], shrine_rows)}
<h3>Marcos</h3>
{table(["Andar","Marco","Cristais"], ms_rows)}
<h3>Ritmo</h3>
<p>Tempo de caminhada entre andares: {bal["travel_time_start"]:g}s no começo, subindo suavemente até {bal["travel_time"]:g}s no andar {bal["travel_ramp_floors"]}. Queda: perde {pct(bal["fall_gold_loss"])} do ouro e volta {bal["fall_back_min"]}–{bal["fall_back_max"]} andares. Fogueira a cada 10 andares. Offline: até {bal["offline_max_hours"]:g}h.</p>
</section>

<section id="ui"><h2>9. Ícones e interface</h2>
<h3>Moedas e marcadores</h3><div class="icons">{cons_icons}</div>
<h3>Glifos de habilidade e menu ({len(glyph_ids)})</h3><div class="icons">{glyph_html}</div>
</section>

<section id="notas"><h2>10. Notas honestas de design</h2>
<ul class="notes">
<li><b>Mint nunca reseta na Ascensão.</b> O contador de mints segue subindo e o custo cresce ×{hire["mint_gold_growth"]} a cada um; um herói Lendário por Mint é muito improvável (1 em 100 por Mint) e fica cada vez mais caro.</li>
<li><b>Não há merge de heróis.</b> Só itens se fundem.</li>
<li><b>Merge ignora o limite de recarga de raridade.</b> O freio é o custo exponencial (quantidade, ouro, cristais).</li>
<li><b>Todas as relíquias compartilham um ícone genérico.</b> Arte própria é trabalho pendente.</li>
<li><b>Nomes de itens, monstros e habilidades ainda não estão traduzidos</b> nos pacotes de idioma (apenas a interface).</li>
<li><b>Testado por mim apenas em ambiente de teste.</b> Janelas flutuantes, bandeja e multi-monitor precisam ser validados no Windows.</li>
</ul>
</section>
<footer>Gerado automaticamente por <code>tools/build_whitepaper.py</code> a partir de <code>data/*.json</code>.</footer>
</main>'''
OUT.write_text(doc)
print("wrote", OUT, f"{OUT.stat().st_size/1e6:.2f} MB")
