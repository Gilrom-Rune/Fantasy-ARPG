class_name ClassSelectUI
extends CanvasLayer
## The first screen: pick a class. Each class has one weapon for the whole game.

signal chosen(class_id: String)


func _ready() -> void:
	layer = 20
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.02, 0.018, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	center.add_child(v)
	var title := UiUtil.title("Choose Your Class", 42)
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
	panel.custom_minimum_size = Vector2(300, 560)
	var card := UiTheme.window(16)
	card.border_color = color.lerp(UiTheme.GOLD, 0.45)
	panel.add_theme_stylebox_override("panel", card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var name_label := UiUtil.title(String(d.get("name", id)), 28)
	name_label.add_theme_color_override("font_color", color.lightened(0.35))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	v.add_child(_preview(String(d.get("model", ""))))
	v.add_child(HSeparator.new())
	v.add_child(UiUtil.label("Weapon: " + String(d.get("weapon", "")), 17, Color(1.0, 0.78, 0.5)))
	var desc := UiUtil.label(String(d.get("description", "")), 15)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(268, 0)
	v.add_child(desc)
	var start := DB.skill(String(d.get("start_skill", "")))
	v.add_child(UiUtil.label("Starting skill: " + String(start.get("name", "?")), 15, UiTheme.SKILL))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var b := UiUtil.button("Play as " + String(d.get("name", id)), func(): chosen.emit(id), UiTheme.TITLE)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(0, 40)
	v.add_child(b)
	return panel


## A small live 3D view of the class's character, idling.
func _preview(model_id: String) -> Control:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(268, 230)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.7)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 200, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)

	var model := CharacterModel.create(model_id)
	if model:
		vp.add_child(model)
	var cam := Camera3D.new()
	cam.fov = 35
	vp.add_child(cam)
	var eye := Vector3(-0.9, 1.5, -3.6)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.95, 0) - eye, Vector3.UP), eye)
	return box
