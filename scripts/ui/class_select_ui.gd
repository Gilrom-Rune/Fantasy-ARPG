class_name ClassSelectUI
extends CanvasLayer
## The first screen: pick a class. Each class has one weapon for the whole game.

signal chosen(class_id: String)


func _ready() -> void:
	layer = 20
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	center.add_child(v)
	var title := UiUtil.label("Choose your class", 36, Color(0.95, 0.8, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for id in DB.classes:
		row.add_child(_card(id))


func _card(id: String) -> Control:
	var d := DB.player_class(id)
	var c: Array = d.get("color", [0.5, 0.5, 0.5])
	var color := Color(c[0], c[1], c[2])
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 330)
	panel.add_theme_stylebox_override("panel", UiUtil.box(Color(0.08, 0.08, 0.1), color, 8, 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiUtil.label(String(d.get("name", id)), 26, color.lightened(0.3)))
	v.add_child(UiUtil.label("Weapon: " + String(d.get("weapon", "")), 16, Color(1.0, 0.75, 0.45)))
	var desc := UiUtil.label(String(d.get("description", "")), 14)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(268, 0)
	v.add_child(desc)
	var start := DB.skill(String(d.get("start_skill", "")))
	v.add_child(UiUtil.label("Starting skill: " + String(start.get("name", "?")), 14, EnchanterUI.SKILL_COLOR))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var b := UiUtil.button("Play as " + String(d.get("name", id)), func(): chosen.emit(id), Color.WHITE)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(0, 40)
	v.add_child(b)
	return panel
