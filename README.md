# Fantasy-ARPG

An ARPG set in a fantasy world with 4 main classes and a subclass. It will have a versatile skill tree and a unique weapon system.

> **Current state: playable prototype.** One arena, endless monster waves, skill gems, support gems, uncut gems and random loot. Everything is placeholder shapes for now; art comes later.

## How to play it

1. Install **Godot 4.7** (standard version, not .NET) from https://godotengine.org/download
2. Download this project: on GitHub click the green **Code** button → **Download ZIP**, then unzip it.
3. Open Godot → **Import** → select the `project.godot` file in the unzipped folder → **Import & Edit**.
4. Press **F5** (or the ▶ Play button at the top right).

### Controls

| Key | Action |
|---|---|
| W A S D | Move |
| Left mouse | Skill 1 (aims at cursor) |
| Right mouse | Skill 2 |
| Q / E | Skills 3 and 4 |
| I or Tab | Inventory & gems (pauses the game) |
| R | Respawn after death |

Walk over items and gems to pick them up. Hover anything in the inventory for details.

## How the game works

- **Skill gems** go in your 4 skill slots. Higher-level gems hit harder and have more support sockets.
- **Support gems** go in a skill's sockets and change it: more projectiles, chaining, added fire, bigger area, and so on. A support only fits skills with matching tags (Multishot needs a *projectile* skill).
- **Uncut gems** drop from monsters. Cut one in the inventory to choose which skill or support it becomes.
- **Items** drop as Normal (white), Magic (blue) or Rare (yellow), with random affixes. Higher item level unlocks stronger affix tiers.
- **Monsters** get stronger every few dozen kills (area level). Blue (magic) and yellow (rare) monsters are tougher and drop more.
- **Damage types**: Fire can *ignite* (burn over time), Cold *chills* (slows), Lightning can *shock* (takes 20% more damage).

## Adding or changing content (no coding needed)

All content is in plain data files in `data/`:

| File | What it holds |
|---|---|
| `data/skills.json` | Active skills: damage, tags, speed, mana cost, projectiles, radius… |
| `data/supports.json` | Support gems: which tags they need and which modifiers they add |
| `data/item_bases.json` | Item base types (swords, helmets, rings…) |
| `data/affixes.json` | Random item modifiers and their value tiers |

### How modifiers work

Every bonus in the game (gear, supports, later the passive tree) is a **modifier**:

```json
{"stat": "damage", "kind": "increased", "value": 20, "tags": ["fire"]}
```

- `flat`: added to the base (+10 life)
- `increased`: all "increased" bonuses are **added together** (20% + 30% = 50%)
- `more`: each "more" bonus **multiplies** separately (×1.3 × 1.2)
- `tags`: the modifier only applies when all of its tags match. `["fire"]` means "increased fire damage" and `["spell"]` means "increased spell damage".

Final value = `(base + flat) × (1 + increased%) × each more`

## Project layout

```
data/             game content (JSON)
scenes/main.tscn  the main scene
scripts/
  core/           stat engine (stat_block.gd), data loader (db.gd), globals (game.gd)
  skills/         skill gems, the skill compiler, projectiles, visual effects
  entities/       actor (shared combat logic), player, enemy
  items/          items, random item generation, inventory
  world/          loot drops
  ui/             HUD, inventory window, health bars & damage numbers
  main.gd         builds the arena, spawns monsters
tests/            automated tests
```

## Automated tests

```bash
godot --headless --script res://tests/run_tests.gd
godot --headless --fixed-fps 60 --path . -- --autoplay --seconds=90
```

The first command runs unit tests for the stat math, supports, items and inventory. The second lets a bot play the game for 90 seconds and prints a summary, which catches crashes and script errors.
