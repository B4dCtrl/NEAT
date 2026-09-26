# Sprite overrides

Drop PNGs here to replace the built-in text pixel art (data/sprites.json).

| File | Replaces |
|---|---|
| `knight.png`, `ranger.png`, `arcanist.png` | heroes (by class id) |
| `<enemy_id>.png` (e.g. `slime.png`, `ashen_king.png`) | a specific enemy / boss |
| `<sprite_id>.png` (e.g. `golem.png`) | every enemy sharing that shape |
| `item_sword.png`, `item_helm.png`, ... | item icons |
| `icon_coin.png`, `icon_skull.png`, ... | HUD icons |

Format: transparent PNG, character facing **right**, feet at the bottom edge.
Animations go in a horizontal strip of square frames (e.g. 4 frames of 48x48 = 192x48).
Any size works: units are scaled to the same on-screen height. In 1-bit mode the
colours are quantised automatically.
