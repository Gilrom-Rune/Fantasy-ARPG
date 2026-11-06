# Notes for Claude

- Godot 4.7, GDScript. The owner is new to programming: Claude writes the code, so keep things readable and explain changes in plain language.
- Content is data-driven in `data/*.json`; prefer adding content there over special-case code.
- All bonuses are StatBlock modifiers (`scripts/core/stat_block.gd`): flat / increased / more, with tag conditions.
- Skills live in the class weapon (`scripts/items/weapon.gd`): up to 10 slots (1 + 1 per 10 levels), each = 1 active gem + 1 passive gem. Soul Chains link slots so chained skills share passives (connected groups). "Passive gems" are the entries in `data/supports.json`.
- Characters use KayKit CC0 models (`assets/characters`), configured in `data/models.json` and driven by `scripts/entities/character_model.gd` (weapon visibility, animations, tint overlay). All share one rig/animation set. Actors fall back to a capsule if a model id is missing.
- UI look lives in `scripts/ui/ui_theme.gd` (palette, Cinzel/Alegreya Sans fonts, restyles Godot's default theme). Use `UiUtil.window/title/header/hint/button` and `UiTheme` colours instead of hard-coded colours so every screen matches. HUD = `PortraitOrb` (face render via `PortraitCamera` + crescent life/mana) + `SkillSlot`s.
- Most nodes are built in code (not .tscn) so they can be edited as text.
- Avoid `:=` on Variant expressions (dictionary lookups etc.); GDScript treats that as a parse error. Use explicit types.
- Before pushing, run both:
  - `godot --headless --script res://tests/run_tests.gd`
  - `godot --headless --fixed-fps 60 --path . -- --autoplay --seconds=90` (must print no SCRIPT ERROR)
- Screenshots: `xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility --fixed-fps 30 --path . -- --autoplay --seconds=30 --screenshot=/path/shot.png` (add `--ui-shot=inventory|enchanter|classes` for a window, `--class=ID --level=N` to skip ahead).
