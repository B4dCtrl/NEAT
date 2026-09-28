# STAIRBORN — The Infinite Tower

> **"Your heroes climb while you work."**
> Idle RPG / auto-battler / loot-hunter em pixel art que vive na barra da sua tela.

Nome: **STAIRBORN**. O título da UI é lido de `application/config/name` em `project.godot`;
os nomes dos executáveis ficam em `export_presets.cfg`.

- **Engine:** Godot 4.3+ (GDScript; 4.3 é necessário para o ícone na bandeja), renderer *GL Compatibility* (leve, suporta janela transparente)
- **Plataformas:** Windows e Linux (presets em `export_presets.cfg`)
- **Arte:** 100% procedural a partir de grades de texto em `data/sprites.json` — nenhum asset binário

## Como rodar

```bash
godot --path infinite_tower            # joga
# ou exporte: godot --headless --path infinite_tower --export-release "Windows Desktop" export/windows/Stairborn.exe
godot --path infinite_tower -e         # abre no editor
```

| Tecla / ação | Efeito |
|---|---|
| Clique na barra | Abre o Expedition Mode |
| Arrastar a barra | Desliza a barra ao longo da borda (quando ela é mais estreita que a tela) |
| `Tab` / `F1` | Alterna Taskbar ↔ Expedition |
| `Esc` | Volta para a barra |
| `F9` (só em debug) | Acelera o tempo x1 → x5 → x25 → x100 |

## Testes

```bash
cd infinite_tower
godot --headless --path . -s res://tests/run_tests.gd                # 84 testes do core
godot --headless --path . -s res://tests/run_tests.gd -- --balance   # + simulação de 8h de balance
xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/screenshot.gd -- /tmp/shots
```

Os testes (106) cobrem: integridade dos JSONs, determinismo da torre e do combate, raridades e
auto-equip, Fall Back, save criptografado (incluindo arquivo adulterado → backup),
progresso offline determinístico e rápido, e Ascension.

## Arquitetura

Separação total **simulação ↔ visualização**. Nada em `core/` (exceto os dois autoloads)
conhece nós, cenas ou tempo real: tudo é função de `(state, rng, dt)`.

```text
infinite_tower/
├── core/
│   ├── combat_engine.gd      # Combate puro, tick fixo de 0.1s; step() ao vivo ou run_to_end() offline
│   ├── tower_generator.gd    # Andar = f(seed, número): tipo, bioma, inimigos, escalonamento
│   ├── loot_calculator.gd    # Raridades, afixos, peças de set, relics, baús de chefe
│   ├── save_system.gd        # Save AES (open_encrypted_with_pass) + .bak + Offline Progress
│   ├── expedition.gd         # Máquina de estados da subida: walk → fight/shrine/vault/boss → next
│   ├── stat_calculator.gd    # Herói + gear + sets + treino + Ascension + buffs + relics → stats finais
│   ├── inventory.gd          # Equipar, auto-equip por ganho real de poder, salvage, relics
│   ├── progression.gd        # XP/níveis, treino com gold, Ascension e árvore de Souls
│   ├── game_state.gd         # O estado inteiro é um Dictionary (JSON direto) + migração de versões
│   ├── data_db.gd            # Acesso somente-leitura às tabelas JSON
│   ├── platform_services.gd  # Costura para Steamworks (GodotSteam); no-op sem backend
│   ├── game.gd               # [autoload Game] dirige a Expedition, sinais p/ UI, autosave, ações
│   ├── audio.gd              # [autoload Audio] SFX e música chiptune sintetizados em código
│   ├── forge.gd              # Merge: itens do mesmo tipo sobem de raridade (sumidouro)
│   ├── danger.gd             # Simula a próxima luta: Easy / Fair / Hard / Deadly
│   └── window_manager.gd     # [autoload WindowManager] Taskbar ↔ Expedition, dock, foco
├── data/
│   ├── items.json            # Slots, raridades, bases, afixos, sets e relics
│   ├── enemies.json          # Monstros, chefes, curvas de escalonamento, tiers de chefe
│   ├── classes.json          # Knight / Ranger / Arcanist: stats, crescimento, skills
│   ├── floor_rules.json      # Biomas, arquétipos, shrines, marcos e TODO o balance
│   ├── ascension_tree.json   # Árvore de prestígio
│   └── sprites.json          # Pixel art em texto + paletas (inimigos reusam formas com outra paleta)
├── scenes/
│   ├── main.tscn             # Raiz: hospeda as duas views
│   ├── ui/
│   │   ├── taskbar_view.tscn    # Visão reduzida (Desktop Companion)
│   │   ├── expedition_view.tscn # Visão expandida (RPG completo)
│   │   ├── tower_stage.gd       # O palco da escada infinita (usado nas duas views)
│   │   ├── combat_fx.gd         # Cortes, flechas, bolas de fogo, crítico, esquiva, efeito por skill
│   │   ├── menu/                # Painéis ornamentados: moldura, ícones, Status/Talentos/Skills/Inventário
│   │   └── tabs/                # Party, Inventory, Ascension, Bestiary, History, Stats, Settings
│   └── entities/
│       ├── hero_sprite.tscn
│       ├── enemy_sprite.tscn
│       └── pixel_art.gd         # Constrói texturas a partir de sprites.json
└── tests/
```

### Fluxo de um frame

```
Game._process(dt) ──► Expedition.advance(dt) ──► CombatEngine.step() (a cada 0.1s)
        │                    │
        │                    └─► events[]  (floor, boss, loot, relic, fall_back...)
        └─► sinais: notified / floor_changed / inventory_changed ... ──► views
```

A **mesma** `Expedition.advance()` é chamada com `delta` do frame (ao vivo) e com blocos de
60s (offline). Não existe um "modo offline" com regras próprias.

## Decisões de design

### História de abertura (quadrinho)
Na primeira vez que o jogo abre, uma intro em quadrinho animado conta a origem: a torre
infinita além da última vila, os heróis que tentaram e nunca voltaram, a terra definhando
e o nascimento do primeiro **Stairborn** ao pé da torre. Os painéis surgem um a um, com
legendas digitadas. Clique/Espaço avança e "Skip" pula. Depois vem um tutorial "Como
jogar". Os dois podem ser revistos em Settings, e o botão **?** abre o tutorial. O texto
segue o idioma do sistema (português ou inglês). A subida só começa depois da intro.

### Bandeja do sistema e minimizar
Fechar (X) não encerra o jogo: ele vai para a **bandeja** (Windows/macOS) e a subida
continua a 5 FPS. Clique no ícone para mostrar a torre; o menu tem "Abrir Expedição" e
"Sair". Onde não há bandeja (Linux), fechar salva e sai. **Minimizar** a janela da
Expedição volta para o modo Taskbar (a torre no cantinho da barra de tarefas).

### Menu em painéis (sobre a torre)
Clique na torre (ou nos botões redondos ao lado dos heróis) para abrir painéis
com moldura ornamentada, como em Tiny Knights / taskbar RPGs: **Status**, **Talentos**
(árvore por herói com portões de nível 1/8/16/25), **Skills** (3 skills ativas por
classe, liberadas nos níveis 1/10/25, com cooldown ao vivo e liga/desliga), **Inventário**
(paper doll, bolsa, consumíveis e Forja) e **Configurações**. Até 3 painéis ficam lado a
lado; a janela cresce para cima e para a esquerda sem mover a torre. O botão ⤢ abre a
Expedição completa e o X manda o jogo para a bandeja.

### Bonfires, mana e perigo
Vida e **mana** não voltam entre os andares. As skills gastam mana (que regenera devagar
nas lutas); a **bonfire** (a cada 10 andares) recupera tudo. Com o **auto-descanso**
ligado, o grupo ferido (abaixo do limite escolhido) volta sozinho à bonfire; cair custa
25% do ouro. O número do andar muda de cor (Easy/Fair/Hard/Deadly) conforme uma
simulação da próxima luta (`core/danger.gd`).

### Heróis e Souls
O painel **HEROES** concentra a party (3 vagas), a reserva e o **mint** (com as chances
de raridade à vista). O painel **SOULS** traz a Ascensão e a árvore permanente.

### Progressão (Tibia) e árvore de skills (Ragnarok)
- **XP estilo Tibia:** o nível L custa `50·(L² − 3L + 4)` XP (100 no nível 1, 2 200 no 8,
  485 200 no 100); a XP dos monstros cresce de forma polinomial com o andar.
- **Ganho por nível por vocação:** Knight +30 HP/+0,5 mana, Ranger +20/+1,5,
  Arcanist +10/+3, Stairborn +24/+1 (as proporções 15/10/5 e 5/15/30 do Tibia).
- **Árvore da classe (`data/skill_tree.json`):** 1 ponto por nível. Passivas somam
  atributos por nível; skills ativas (Bash, Double Strafe, Fire Bolt, Meteor Storm...)
  têm níveis 1–10 com pré-requisitos e saem sozinhas na luta (**autocast**) gastando mana.

### Itens: equipar à mão, merge e limites da economia
- **Nada se equipa sozinho:** o jogador escolhe o que cada herói usa. Item equipado fica
  **vinculado** (não poderá ser negociado).
- **Merge (`core/forge.gd`):** 4–5 itens da mesma raridade e do mesmo tipo (slot, e a
  classe da arma) viram 1 item aleatório do mesmo tipo, uma raridade acima; custa ouro
  (e cristais nos tiers altos) que cresce com o nível do item.
- **Drops escassos:** chance base de 3,5% por monstro e raridades altas mais raras. Depois
  de um Epic/Legendary/Mythic, o próximo da mesma raridade só cai 5/30/150 andares depois
  (até lá ele vira a raridade de baixo).

### Monstros, afixos e chefes
28 monstros (variantes de cor com traços próprios: roubo de vida, espinhos, regeneração)
e 15 chefes, cada um com habilidades (Slam, Summon, Heal, Shield, Drain, Frenzy). O chefe
de cada Guardian gira pela lista do bioma; o Tower Lord é sempre o primeiro. A partir do
andar 5 monstros podem vir **Elite** com afixos (Armored, Swift, Giant, Vampiric, Thorny,
Regenerating, Shielded, Berserk) — mais fortes, maiores e com 60% mais gold/XP.

### Itens utilizáveis
Poções de vida, bombas de fogo, elixires (velocidade, fúria, ferro), pergaminho da fortuna
e pergaminho de subida. Caem dos monstros e são vendidos no Mercado. Com "auto-usar"
ligado a party bebe poção abaixo de 30% de vida e joga bomba em chefes.

### Efeitos, música e sons
Todos os efeitos são gerados em código: corte, garra, flecha, bola de fogo, faíscas,
estrela de **CRIT**, esquiva com **MISS**, domo do Shield Wall, chuva do Volley, meteoro,
cura, onda de choque, dreno, escudo hexagonal, raios e bombas, com tremor de tela nos
golpes fortes. O áudio é sintetizado na hora (sem arquivos): SFX para cada evento e duas
músicas chiptune em loop (subida e chefe). Volumes em Configurações.

### Torre helicoidal flutuando sobre a taskbar
Inspirado em *A Fool's Errand* (Playdate) e *TBH: Task Bar Hero*. A janela da barra é
**transparente**, compacta (~400px) e fica encostada no canto direito, logo acima da taskbar. Só aparecem uma torre
cilíndrica e um HUD com contorno de texto, legível sobre qualquer wallpaper. O resto da
janela deixa o clique passar para o desktop (`mouse_passthrough_polygon`).

A escada é **helicoidal**: cada andar é uma volta completa ao redor da torre (72% degraus,
28% patamar). O grupo fica na frente e a **torre gira** enquanto ele sobe. Os tijolos e
as seteiras se deslocam lateralmente, os degraus de trás passam por trás do cilindro e a
câmera olha levemente de cima. O combate acontece no patamar, e a câmera enquadra a luta.
No Fall Back a torre "desenrosca" para baixo.

Estilo padrão **1-bit** (tinta/papel com pontilhado ordenado Bayer, sprites quantizados
em 3 tons). Em *Settings → Art style* há a opção de cores por bioma.

### Focus Safety
No Taskbar Mode a janela é `unfocusable` (`WINDOW_FLAG_NO_FOCUS`): recebe cliques mas
**nunca** o foco do teclado. Notificações (lendário, relic, chefe, marco) são apenas um
brilho pulsante na borda da barra + texto no HUD. O relatório de progresso offline também
não abre janela: ele espera você abrir o Expedition Mode.

### Fogueiras e Fall Back (sem Game Over)
Os andares 1, 11, 21… têm uma **fogueira**. Nela o grupo descansa (cura total), equipa o
que houver de melhor na mochila, gasta pontos de habilidade e registra o **checkpoint**.
Se o grupo inteiro cair, ele rola escada abaixo pela espiral até a última fogueira (morreu
no 37 → volta ao 31) e continua farmando. O botão **"Camp at next bonfire"** faz o grupo
parar na próxima fogueira e esperar enquanto você mexe nos equipamentos.

### Heróis: o fundador e os recrutas
Todo jogo começa com **The Stairborn** sozinho. Há mais 2 vagas na party, preenchidas por
heróis **comprados no Mercado** ou **mintados**: gerados do zero, com classe, nome e raridade
(potencial ×1.0 a ×1.42 nos atributos base) aleatórios. Heróis a mais ficam no banco. Cada
herói tem sua **árvore de habilidades** (1 ponto por nível, ramos Might / Guard / Cunning).

### Mercado e Steam
O **Tower Market** troca o estoque a cada 15 min (determinístico por save): equipamentos
em ouro, heróis, um Lendário em destaque e relics em Crystals. A seção Steam abre o
Community Market no overlay. `tools/export_steam_itemdefs.gd` gera as item definitions do
Steam Inventory Service (relics e peças de set, negociáveis) a partir dos JSONs. Para
ativar: defina `steam_app_id` em `data/platform.json` e instale o GodotSteam.

### Arte do PixelLab
Heróis (com animação de caminhada), monstros, chefes e ícones foram gerados no PixelLab e
estão em `assets/sprites/`. Esses PNGs substituem automaticamente a pixel art em texto de
`data/sprites.json` (que continua valendo para o que não tiver PNG). Os personagens ficam
coloridos mesmo no modo 1-bit, destacados sobre a torre em tinta e papel.
Para importar novos downloads: `godot --headless --path . -s res://tools/import_pixellab.gd -- <pasta>`
(corta as bordas, alinha os pés, monta a tira de animação e vira os inimigos).

### Progresso offline determinístico
O save guarda a posição do RNG (como string — 64 bits não cabem em float JSON). Ao abrir o
jogo, o tempo ausente (limitado a 12h; relógio voltando para trás não conta) é simulado de
verdade por até 2h; o restante é pago na taxa de gold/XP observada. Mesmo save + mesmo
tempo = mesmo resultado. 3h offline custam ~1s de CPU.

### Save
JSON criptografado com AES-256 via `FileAccess.open_encrypted_with_pass`, que também valida
MD5: arquivo adulterado não abre e o loader cai para o `.bak`. A escrita é atômica
(tmp → rename). A chave está no binário: isso é resistência a edição casual, não DRM.

### Balance (data-driven)
Todos os números estão nos JSONs. Curva atual (sem Ascension, `--balance`):
com um jogador que só minta heróis quando tem ouro: ~30 andares em 30 min,
~50 em 1h (primeira Ascension) e uma parede por volta do 75 — é a hora de ascender.
A árvore de Ascension tem 4 colunas (Fundador, Guilda, Subida, Fortuna) pensadas para o
começo solo: fundador mais forte e com níveis iniciais, recrutas mais baratos/raros e
com níveis, ouro e andar inicial. Inimigos crescem ~5.6%/andar (HP) e itens ~4.2%/ilvl; a
diferença é coberta por níveis, treino, raridade, sets, relics e Souls.

## Conteúdo do MVP

- **Classes:** Knight (tank, aggro, *Shield Wall*), Ranger (crit/atk speed, *Volley*),
  Arcanist (AOE de fogo, *Meteor* com queimadura). Posição Front/Back altera o aggro.
- **Andares:** Standard, Shrine (4 buffs + altar que troca gold por item Raro+), Treasure
  Vault, Guardian (a cada 10), Elite Guardian (25), Tower Lord (100). 5 biomas em ciclo.
- **Loot:** Common → Uncommon → Rare → Epic → Legendary → Mythic → **RELIC**.
  Afixos por raridade; peças de set a partir de Epic.
- **Sets:** Ashen King (2: +10% ATK · 4: +20% Fire e ataques viram Fogo · 6: *Burning Soul*),
  Verdant Warden, Stormcaller.
- **Relics:** Blood Crown, Merchant's Eye, Phoenix Feather + 6 relics de stats.
- **Economia:** Gold (treino/salvage), Souls (Ascension Tree com 10 nós e pré-requisitos),
  Crystals (chefes, marcos, relics duplicadas).
- **Expedition Mode:** Party, Inventário com comparação de poder, Ascension, Bestiário,
  Histórico, medidor de DPS ao vivo, Configurações (always-on-top, dock topo/base, largura e
  altura da barra, opacidade, FPS da barra, volume, notificações, auto-equip/treino/salvage).

## Próximos passos sugeridos

- Hotkey **global** (fora da janela) exige GDExtension por plataforma — o Godot só captura
  teclas com a janela focada.
- Integração GodotSteam: preencher `core/platform_services.gd` (achievements já disparam em
  `REACH_50`, `REACH_100`...).
- Música composta/gravada no lugar da sintetizada, mais classes, skills ativas por item, cosméticos com
  Crystals.
