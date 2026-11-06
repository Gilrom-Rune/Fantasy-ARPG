class_name WorldOverlay
extends Control
## Draws things that follow 3D positions on screen: enemy health bars,
## floating damage numbers and loot labels.

var hud: Hud


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var font := ThemeDB.fallback_font

	# Loot labels
	for drop in get_tree().get_nodes_in_group("loot"):
		var wp: Vector3 = drop.global_position + Vector3(0, 0.9, 0)
		if cam.is_position_behind(wp):
			continue
		var p := cam.unproject_position(wp)
		var size := font.get_string_size(drop.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var rect := Rect2(p.x - size.x * 0.5 - 5, p.y - size.y, size.x + 10, size.y + 4)
		draw_rect(rect, Color(0, 0, 0, 0.72))
		draw_rect(rect, Color(drop.color, 0.6), false, 1.0)
		draw_string(font, Vector2(rect.position.x + 5, p.y - 1), drop.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, drop.color)

	# Chests and the Enchanter's Table
	for obj in get_tree().get_nodes_in_group("interactables"):
		var wp: Vector3 = obj.global_position + Vector3(0, 2.2, 0)
		if cam.is_position_behind(wp):
			continue
		var p := cam.unproject_position(wp)
		var text: String = obj.label
		var col: Color = obj.label_color
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string_outline(font, Vector2(p.x - size.x * 0.5, p.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(p.x - size.x * 0.5, p.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)

	# Enemy health bars and names
	for e in get_tree().get_nodes_in_group("enemies"):
		var top: Vector3 = e.global_position + Vector3(0, e.bar_height, 0)
		if cam.is_position_behind(top):
			continue
		var p := cam.unproject_position(top)
		var w: float = 46.0 + 18.0 * e.rarity
		var frac: float = clampf(e.life / e.max_life, 0.0, 1.0)
		draw_rect(Rect2(p.x - w * 0.5, p.y, w, 6), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(p.x - w * 0.5 + 1, p.y + 1, (w - 2) * frac, 4), Color(0.85, 0.12, 0.1))
		if e.rarity > 0 or frac < 1.0:
			if e.rarity > 0:
				draw_string(font, Vector2(p.x - 100, p.y - 4), e.display_name, HORIZONTAL_ALIGNMENT_CENTER, 200, 13, e.name_color())

	# Floating combat text
	for f in hud.float_texts:
		if cam.is_position_behind(f["pos"]):
			continue
		var p := cam.unproject_position(f["pos"]) - Vector2(0, f["t"] * 45.0)
		var alpha := clampf(1.4 - f["t"] / 0.7, 0.0, 1.0)
		var col: Color = f["color"]
		col.a = alpha
		var fs: int = f["size"]
		draw_string_outline(font, Vector2(p.x - 60, p.y), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fs, 4, Color(0, 0, 0, alpha * 0.8))
		draw_string(font, Vector2(p.x - 60, p.y), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fs, col)
