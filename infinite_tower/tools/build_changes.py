#!/usr/bin/env python3
"""Changelog page: only what changed in the 20-set / gems / monster-fx update.
python3 -I tools/build_changes.py <old_img_dir> <new_img_dir> <out.html>"""
import base64, html, json, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
OLD, NEW, OUT = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
e = html.escape
items = json.loads((ROOT / "data/items.json").read_text())
en = json.loads((ROOT / "data/enemies.json").read_text())
sets, order = items["sets"], items["set_order"]
RP = {"common": "Comum", "uncommon": "Incomum", "rare": "Raro", "epic": "Épico", "legendary": "Lendário", "mythic": "Mítico"}

def b64(p):
    return "data:image/png;base64," + base64.b64encode(Path(p).read_bytes()).decode()

def im(p, cls="px"):
    return f'<img class="{cls}" src="{b64(p)}" alt="">' if Path(p).exists() else ""

CSS = (ROOT / "tools/whitepaper.css").read_text()
sp = ROOT / "assets/sprites"
rows = ""
for i, sid in enumerate(order):
    s = sets[sid]
    b = [x for x in items["bases"] if x["set"] == sid]
    cells = "".join(f'<div class="pc">{im(sp / (x["id"] + ".png"), "px sm2")}<small>{e(x["name"])}</small></div>' for x in b)
    bon = " · ".join(f'<b>{k}p</b> {e(v["text"])}' for k, v in s["bonuses"].items())
    nxt = sets[order[i + 1]]["name"] if i + 1 < len(order) else "—"
    rows += (f'<article class="setbox"><h4>{s["tier"]}. {e(s["name"])} <em>andar {s["min_floor"]}+ · poder ×{s["power"]} · evolui para: {e(nxt)}</em></h4>'
             f'<div class="setrow">{cells}</div><p class="muted">{bon}</p></article>')
aura = "".join(f'<div class="ic">{im(NEW / "rarity" / (r + ".png"), "px lg2")}<span>{RP[r]}</span></div>' for r in RP)
gems = "".join(f'<div class="card"><div class="art">{im(sp / ("gem_" + k + ".png"), "px lg2")}</div><div class="cname">{e(v["name"])}</div><div class="cbody">{e(v["description"])}</div></div>' for k, v in items["relics"].items())
mons = ""
for grp in ("enemies", "bosses"):
    for k, v in en[grp].items():
        if "fx" in v:
            mons += (f'<div class="card"><div class="ba">{im(OLD / grp / (k + ".png"), "px md")}<span>→</span>{im(NEW / grp / (k + ".png"), "px md")}</div>'
                     f'<div class="cname">{e(v["name"])}</div><div class="cbody">efeitos: {e(", ".join(v["fx"]))}</div></div>')
doc = f'''<title>Stairborn Novidades</title>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&family=Pixelify+Sans:wght@500;700&display=swap" rel="stylesheet">
<style>{CSS}
.px.sm2{{width:64px;height:64px}}.px.lg2{{width:96px;height:96px}}.px.md{{width:96px}}
.pc{{display:flex;flex-direction:column;align-items:center;gap:2px;width:84px;text-align:center;font-size:11px}}
.pc small{{line-height:1.2}}.ba{{display:flex;align-items:center;justify-content:center;gap:8px;background:var(--stage);border-radius:4px;padding:8px}}
</style>
<nav class="top"><b>NOVIDADES</b><a href="#sets">20 sets</a><a href="#evolve">Evolve</a><a href="#rar">Raridade</a><a href="#gems">Gems</a><a href="#mon">Monstros</a><a href="#pend">Pendente</a></nav>
<main><header class="hero"><p class="kicker">SOMENTE O QUE MUDOU</p><h1>Stairborn</h1>
<p class="lede">Itens com arte própria em 20 sets, merge que evolui de set, gems no lugar das relíquias e monstros com efeitos únicos.</p></header>
<section id="sets"><h2>1. 20 sets × 8 peças = 160 itens, cada um com arte própria</h2>
<p>Cada set tem arma de Cavaleiro, Arqueiro e Arcanista, capacete, peitoral, luvas, botas e anel. Silhueta, paleta, emblema e partículas mudam de set para set. Todo drop pertence a um set; os mais novos caem mais.</p>{rows}</section>
<section id="evolve"><h2>2. Merge novo: Evolve</h2>
<p class="callout"><b>3 itens do mesmo set, tipo e raridade → 1 item do próximo set</b>, na mesma raridade. Ex.: 3 Ashen Brand → 1 Thornheart. Em armas há <b>25%</b> de chance de sair de outra classe. O custo em ouro cresce ×1,3 por tier e épicos ou acima pedem cristais. O Refine (sobe raridade, 4 itens) continua, agora mantendo o melhor set.</p></section>
<section id="rar"><h2>3. Raridade visível no ícone</h2><p>Mesmo item em cada raridade: borda verde, brilho azul, roxo com cintilados, dourado e vermelho com estrelas.</p><div class="icons">{aura}</div></section>
<section id="gems"><h2>4. Relíquias viraram Gems equipáveis (12)</h2><p>Cada uma com corte e cor próprios. Três são novas: Dragon's Tear, Bulwark Jade e Peridot of Fortune.</p><div class="grid">{gems}</div></section>
<section id="mon"><h2>5. Monstros: antes → depois ({mons.count('class="card"')} variantes)</h2><p>Antes era só troca de cor. Agora cada variante tem seu efeito: gelo, brasas, lava, grama, espinhos, podridão, cristais, arco-íris, vazio, sombra, coroa, chifres e halo.</p><div class="grid">{mons}</div></section>
<section id="pend"><h2>6. Ainda não feito</h2><ul class="notes"><li><b>Mint progressivo</b> (120, 400, 520, 650...), ainda com a fórmula antiga.</li><li>Ajuste de dificuldade estilo Souls-like e da economia para a Steam.</li><li>Build Windows com tudo isso.</li></ul></section></main>'''
OUT.write_text(doc); print(OUT.stat().st_size / 1e6, "MB")
