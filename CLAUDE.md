# Notes for Claude

- Godot 4.7, GDScript. The owner is new to programming: Claude writes the code, so keep things readable and explain changes in plain language.
- Content is data-driven in `data/*.json`; prefer adding content there over special-case code.
- All bonuses are StatBlock modifiers (`scripts/core/stat_block.gd`): flat / increased / more, with tag conditions.
- Most nodes are built in code (not .tscn) so they can be edited as text.
- Avoid `:=` on Variant expressions (dictionary lookups etc.); GDScript treats that as a parse error. Use explicit types.
- Before pushing, run both:
  - `godot --headless --script res://tests/run_tests.gd`
  - `godot --headless --fixed-fps 60 --path . -- --autoplay --seconds=90` (must print no SCRIPT ERROR)
- Screenshots: `xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility --fixed-fps 30 --path . -- --autoplay --seconds=30 --screenshot=/path/shot.png` (add `--inventory-shot` for the inventory window).
