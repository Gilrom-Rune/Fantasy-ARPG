class_name Hud
extends CanvasLayer
## On-screen interface: life/mana/xp bars, skill bar, messages, death screen.
## Owns the inventory window.

signal respawn_requested

var player: Player
var float_texts: Array = []

var overlay: WorldOverlay
var inventory_ui: InventoryUI
var life_bar: ProgressBar
var mana_bar: ProgressBar
var xp_bar: ProgressBar
var life_label: Label
var mana_label: Label
var info_label: Label
var messages: VBoxContainer
var death_panel: Control
var skill_boxes: Array = []  ## [{ "panel", "name", "cost", "shade" }]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10


func setup(p: Player) -> void:
	player = p
	overlay = WorldOverlay.new()
	overlay.hud = self
	add_child(overlay)
	_build_top()
	_build_bottom()
	_build_messages()
	_build_death()
	inventory_ui = InventoryUI.new()
	inventory_ui.visible = false
	add_child(inventory_ui)
	inventory_ui.setup(player)


func _build_top() -> void:
	info_label = UiUtil.label("", 15)
	info_label.position = Vector2(16, 12)
	add_child(info_label)
	var help := UiUtil.label("WASD move  •  LMB / RMB / Q / E skills  •  I or Tab: inventory & gems", 14, Color(0.7, 0.7, 0.7))
	_anchor(help, Vector2(1, 0), Rect2(-620, 12, 604, 20))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(help)


## Pins a control to an anchor point of the screen (0..1) with an offset rect.
func _anchor(c: Control, anchor: Vector2, rect: Rect2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = rect.position.x
	c.offset_top = rect.position.y
	c.offset_right = rect.position.x + rect.size.x
	c.offset_bottom = rect.position.y + rect.size.y


func _build_bottom() -> void:
	var root := VBoxContainer.new()
	_anchor(root, Vector2(0.5, 1), Rect2(-330, -100, 660, 90))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	var life_col := VBoxContainer.new()
	life_col.custom_minimum_size = Vector2(150, 0)
	life_label = UiUtil.label("", 14, Color(1, 0.75, 0.75))
	life_col.add_child(life_label)
	life_bar = UiUtil.bar(Color(0.75, 0.1, 0.1))
	life_bar.custom_minimum_size = Vector2(150, 18)
	life_col.add_child(life_bar)
	row.add_child(life_col)

	for i in Inventory.SKILL_SLOTS:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(80, 64)
		panel.add_theme_stylebox_override("panel", UiUtil.box(Color(0.08, 0.08, 0.1, 0.92), Color(0.45, 0.4, 0.3), 4, 4))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.add_child(UiUtil.label(Player.SLOT_KEYS[i], 12, Color(0.95, 0.8, 0.5)))
		var n := UiUtil.label("", 13)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size = Vector2(72, 0)
		v.add_child(n)
		var cost := UiUtil.label("", 11, Color(0.55, 0.7, 1.0))
		v.add_child(cost)
		panel.add_child(v)
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.6)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(shade)
		row.add_child(panel)
		skill_boxes.append({"panel": panel, "name": n, "cost": cost, "shade": shade})

	var mana_col := VBoxContainer.new()
	mana_col.custom_minimum_size = Vector2(150, 0)
	mana_label = UiUtil.label("", 14, Color(0.7, 0.8, 1.0))
	mana_col.add_child(mana_label)
	mana_bar = UiUtil.bar(Color(0.15, 0.3, 0.85))
	mana_bar.custom_minimum_size = Vector2(150, 18)
	mana_col.add_child(mana_bar)
	row.add_child(mana_col)

	xp_bar = UiUtil.bar(Color(0.75, 0.6, 0.2))
	xp_bar.custom_minimum_size = Vector2(660, 8)
	root.add_child(xp_bar)


func _build_messages() -> void:
	messages = VBoxContainer.new()
	messages.position = Vector2(16, 120)
	messages.custom_minimum_size = Vector2(500, 0)
	messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(messages)


func _build_death() -> void:
	death_panel = ColorRect.new()
	death_panel.color = Color(0.15, 0, 0, 0.55)
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_panel.add_child(center)
	var v := VBoxContainer.new()
	v.add_child(UiUtil.label("You have died", 42, Color(1, 0.35, 0.3)))
	var b := UiUtil.button("Respawn (R)", func(): respawn_requested.emit())
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	center.add_child(v)
	add_child(death_panel)


func show_death() -> void:
	death_panel.visible = true


func hide_death() -> void:
	death_panel.visible = false


func add_float_text(pos: Vector3, text: String, color: Color, size: int) -> void:
	float_texts.append({"pos": pos + Vector3(randf_range(-0.3, 0.3), 0, 0), "text": text, "color": color, "size": size, "t": 0.0})
	if float_texts.size() > 120:
		float_texts.pop_front()


func add_message(text: String, color: Color = Color.WHITE) -> void:
	var l := UiUtil.label(text, 15, color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	messages.add_child(l)
	if messages.get_child_count() > 7:
		messages.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func toggle_inventory() -> void:
	inventory_ui.visible = not inventory_ui.visible
	get_tree().paused = inventory_ui.visible
	if inventory_ui.visible:
		inventory_ui.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and inventory_ui.visible:
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("respawn") and death_panel.visible:
		respawn_requested.emit()


func _process(delta: float) -> void:
	if not get_tree().paused:
		for f in float_texts:
			f["t"] += delta
		float_texts = float_texts.filter(func(f): return f["t"] < 1.0)
	if player == null:
		return
	life_bar.max_value = player.max_life
	life_bar.value = player.life
	life_label.text = "Life %d / %d" % [ceili(player.life), roundi(player.max_life)]
	mana_bar.max_value = maxf(1.0, player.max_mana)
	mana_bar.value = player.mana
	mana_label.text = "Mana %d / %d" % [floori(player.mana), roundi(player.max_mana)]
	xp_bar.max_value = player.xp_to_next()
	xp_bar.value = player.xp
	info_label.text = "Level %d    Area level %d    Kills %d" % [player.level, Game.area_level, Game.kills]
	for i in Inventory.SKILL_SLOTS:
		var box: Dictionary = skill_boxes[i]
		var c = player.compiled[i]
		if c == null:
			box["name"].text = "-"
			box["cost"].text = ""
			box["shade"].visible = true
			continue
		box["name"].text = c["name"]
		var cd: float = player.cooldowns.get("slot%d" % i, 0.0)
		box["cost"].text = ("%.1fs" % cd) if cd > 0.05 else ("%d mana" % c["mana_cost"])
		box["shade"].visible = cd > 0.05 or player.mana < c["mana_cost"]
