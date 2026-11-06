# Fantasy-ARPG

An ARPG set in a fantasy world with 4 main classes and a subclass. It will have a versatile skill tree and a unique weapon system.

> **Current state: playable prototype.** Pick one of 4 classes, fight endless monster waves in an arena, and build your class weapon at the Enchanter's Table. Everything is placeholder shapes for now; art comes later.

## How to play it

1. Install **Godot 4.7** (standard version, not .NET) from https://godotengine.org/download
2. Download this project: on GitHub click the green **Code** button → **Download ZIP**, then unzip it.
3. Open Godot → **Import** → select the `project.godot` file in the unzipped folder → **Import & Edit**.
4. Press **F5** (or the ▶ Play button at the top right).

### Controls

| Key | Action |
|---|---|
| W A S D | Move |
| Left / Right mouse | Weapon slots 1 and 2 (aims at cursor) |
| Q, E, 1–6 | Weapon slots 3 to 10 |
| F | Use the Enchanter's Table / open a chest |
| I or Tab | Inventory (pauses the game) |
| Esc | Close a window |
| R | Respawn after death |

## How the game works

### Classes and weapons
Each class has **one weapon for the whole game**, and it **grows stronger every level**:

| Class | Weapon | Starting skill |
|---|---|---|
| Warrior | Greatsword | Cleave |
| Ranger | Bow | Power Shot |
| Mage | Staff | Fireball |
| Rogue | Twin Daggers | Dagger Strike |

(Placeholder names; change them in `data/classes.json`.)

### The Enchanter's Table
The table is in the **camp** in the middle of the arena. Monsters can't enter the camp, and you heal quickly there. Walk up to the table and press **F**.

- Your weapon has **skill slots**: 1 at the start, plus 1 more every 10 levels, up to **10 slots at level 90** (level cap 100).
- Each slot holds **one active skill gem** and **one passive gem**. The passive modifies that skill (Multishot = more projectiles, Searing = more burning, …). A passive only fits skills with matching tags.
- **Soul Chains:** every slot has a ● node. Drag from one node to another and a pale blue chain links them. **Linked skills share their passives.** Chains can connect through each other (1–2–3 all share). Drag between the same two nodes again to break a chain; right-click a node to break all of its chains. A shared passive that doesn't fit a skill is ignored for that skill.
- **Uncut gems** drop from monsters and **chests**. Cut them at the table to choose which skill or passive they become.

### Loot and monsters
- Armour, rings and amulets drop as Normal (white), Magic (blue) or Rare (yellow) with random affixes. Higher item level unlocks stronger affix tiers.
- Monsters get stronger every few dozen kills (area level). Blue (magic) and yellow (rare) monsters are tougher and drop more.
- Fire can *ignite* (burn over time), Cold *chills* (slows), Lightning can *shock* (20% more damage taken).

## Adding or changing content (no coding needed)

All content is in plain data files in `data/`:

| File | What it holds |
|---|---|
| `data/classes.json` | Classes, their weapon, base stats, and how the weapon grows per level |
| `data/skills.json` | Active skills: damage, tags, speed, mana cost, projectiles, radius… |
| `data/supports.json` | Passive gems: which tags they need and which modifiers they add |
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
  items/          class weapon (slots + Soul Chains), items, item generation, inventory
  world/          loot drops, chests, the Enchanter's Table
  ui/             HUD, inventory, Enchanter's Table window, class select, damage numbers
  main.gd         builds the arena, spawns monsters
tests/            automated tests
```

## Automated tests

```bash
godot --headless --script res://tests/run_tests.gd
godot --headless --fixed-fps 60 --path . -- --autoplay --seconds=90
godot --headless --fixed-fps 60 --path . -- --autoplay --class=mage --level=35 --seconds=90
```

The first command runs unit tests for the stat math, passives, weapon slots, Soul Chains, items and inventory. The others let a bot play the game for 90 seconds and prints a summary, which catches crashes and script errors.
