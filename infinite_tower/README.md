# STAIRBORN — The Infinite Tower

> **"Your heroes climb while you work."**
> Idle RPG / auto-battler / loot-hunter em pixel art que vive na barra da sua tela.

Nome: **STAIRBORN**. O título da UI é lido de `application/config/name` em `project.godot`;
os nomes dos executáveis ficam em `export_presets.cfg`.

- **Engine:** Godot 4.2+ (GDScript), renderer *GL Compatibility* (leve, suporta janela transparente)
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

Os testes cobrem: integridade dos JSONs, determinismo da torre e do combate, raridades e
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

### Torre helicoidal flutuando sobre a taskbar
Inspirado em *A Fool's Errand* (Playdate) e *TBH: Task Bar Hero*. A janela da barra é
**transparente** e fica logo acima da taskbar, no canto direito. Só aparecem uma torre
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

### Fall Back (sem Game Over)
Derrota → o grupo despenca 5–10 andares, cura total, e continua farmando. O andar que
barrou o grupo vira a **Wall** (exibida na UI com o número de tentativas). Treino
automático, XP e loot eventualmente quebram a parede; quando não quebram mais, é hora da
**Ascension**.

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
andar ~100 em 30 min, ~140 em 1h, ~200 em 3h e depois avanço lento com Fall Backs
frequentes (~290 em 8h) — o ponto natural para ascender. Inimigos crescem ~5.6%/andar (HP) e itens ~4.2%/ilvl; a
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
- Áudio (o volume master já existe), mais classes, skills ativas por item, cosméticos com
  Crystals.
