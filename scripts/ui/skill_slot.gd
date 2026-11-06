class_name SkillSlot
extends Control
## One square on the skill bar: the skill's name on a tile tinted by its
## element, the key that uses it, its mana cost, and a clock-style cooldown.

const SIZE := Vector2(66, 66)

var player: Player
var index := 0
var _flash := 0.0
var _last_cd := 0.0


func setup(p: Player, i: int) -> void:
	player = p
	index = i
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if player == null:
		return
	var cd: float = player.cooldowns.get("slot%d" % index, 0.0)
	if cd <= 0.0 and _last_cd > 0.0:
		_flash = 0.35  # glow briefly when a cooldown finishes
	_last_cd = cd
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, SIZE)
	var c = player.compiled[index] if player else null
	draw_rect(r, UiTheme.INSET)

	if c == null:
		_frame(r, UiTheme.GOLD_DIM)
		_key()
		return

	# Tile: element colour, darker at the bottom.
	var col: Color = c["color"]
	var inner := r.grow(-3)
	draw_rect(inner, col.darkened(0.72))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.55)), Color(col.darkened(0.55), 0.9))
	draw_line(inner.position + Vector2(0, 1), inner.position + Vector2(inner.size.x, 1), Color(col, 0.45), 1.0)

	# Skill name, up to two lines, centred (hidden while the cooldown number shows).
	var f := UiTheme.bold_font()
	var cd_left: float = player.cooldowns.get("slot%d" % index, 0.0)
	var words: PackedStringArray = String(c["name"]).split(" ")
	var lines: Array = [" ".join(words.slice(0, maxi(1, words.size() - 1))), words[words.size() - 1]] if words.size() > 1 else [words[0]]
	var y := SIZE.y * 0.5 - (lines.size() - 1) * 7.0 + 4.0
	for line in (lines if cd_left <= 0.0 else []):
		var w := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var p := Vector2((SIZE.x - w) * 0.5, y)
		draw_string_outline(f, p, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
		draw_string(f, p, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.TEXT)
		y += 14.0

	# Mana cost (bottom right).
	var cost := int(c["mana_cost"])
	if cost > 0:
		var s := str(cost)
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var p := Vector2(SIZE.x - w - 4, SIZE.y - 4)
		draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.9))
		draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.75, 1.0))

	# Not enough mana: blue veil.
	if player.mana < float(c["mana_cost"]):
		draw_rect(inner, Color(0.05, 0.1, 0.35, 0.55))

	# Cooldown: dark clock sweep + seconds left.
	var cd: float = player.cooldowns.get("slot%d" % index, 0.0)
	var total: float = c["cooldown"]
	if cd > 0.0 and total > 0.0:
		_clock(inner, cd / total)
		var s := ("%.1f" % cd) if cd < 10.0 else str(ceili(cd))
		var tf := UiTheme.title_font()
		var w := tf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var p := Vector2((SIZE.x - w) * 0.5, SIZE.y * 0.5 + 7)
		draw_string_outline(tf, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.9))
		draw_string(tf, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	var border := UiTheme.GOLD if player.busy_time > 0.0 else UiTheme.GOLD_DIM
	if _flash > 0.0:
		border = UiTheme.TITLE.lightened(0.4)
	_frame(r, border)
	_key()


## Darkens the part of the tile still on cooldown, sweeping clockwise from the top.
func _clock(rect: Rect2, frac: float) -> void:
	var center := rect.get_center()
	var pts := PackedVector2Array([center])
	var start := -PI * 0.5
	var end := start + TAU * frac
	var radius := rect.size.length()
	var steps := maxi(2, int(40 * frac))
	for i in steps + 1:
		var a := lerpf(start, end, float(i) / steps)
		var p := center + Vector2(cos(a), sin(a)) * radius
		p.x = clampf(p.x, rect.position.x, rect.end.x)
		p.y = clampf(p.y, rect.position.y, rect.end.y)
		pts.append(p)
	if pts.size() >= 3:
		draw_colored_polygon(pts, Color(0, 0, 0, 0.6))


func _frame(r: Rect2, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.9), false, 3.0)
	draw_rect(r.grow(-1), col, false, 1.5)
	# Corner studs.
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		draw_rect(Rect2(corner - Vector2(2.5, 2.5), Vector2(5, 5)), col)


## The key badge in the top-left corner.
func _key() -> void:
	var f := UiTheme.bold_font()
	var s: String = Player.SLOT_KEYS[index]
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var badge := Rect2(Vector2(3, 3), Vector2(w + 8, 16))
	draw_rect(badge, Color(0.05, 0.04, 0.035, 0.92))
	draw_rect(badge, UiTheme.GOLD_DIM, false, 1.0)
	draw_string(f, Vector2(7, 15), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.TITLE)
