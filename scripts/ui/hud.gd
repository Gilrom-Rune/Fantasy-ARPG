class_name Hud
extends CanvasLayer
## On-screen interface during play:
##  - bottom: character portrait with crescent life/mana bars, the skill bar, XP bar
##  - top-left: class, level, area level and kills
##  - messages, "[F] ..." prompts, the death screen
## Also owns the inventory window and the Enchanter's Table window.

signal respawn_requested

var player: Player
var float_texts: Array = []

var overlay: WorldOverlay
var inventory_ui: InventoryUI
var enchanter_ui: EnchanterUI
var orb: PortraitOrb
var prompt_label: Label
var closed_at_frame := -100  ## so the F that closes the table doesn't reopen it
var xp_bar: ProgressBar
var xp_label: Label
var info_label: Label
var messages: VBoxContainer
var death_panel: Control
var skill_slots: Array = []  ## SkillSlot controls, one per weapon slot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	UiTheme.apply()


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
	enchanter_ui = EnchanterUI.new()
	enchanter_ui.visible = false
	add_child(enchanter_ui)
	enchanter_ui.setup(player)


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


func _build_top() -> void:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.flat(Color(UiTheme.BG, 0.82), UiTheme.GOLD_DIM, 1, 3, 8))
	plate.position = Vector2(14, 12)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label = UiUtil.label("", 15)
	plate.add_child(info_label)
	add_child(plate)

	var help := UiUtil.label("WASD move   •   LMB RMB Q E 1-6 skills   •   F use   •   I inventory", 14, UiTheme.MUTED)
	help.add_theme_constant_override("outline_size", 4)
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_anchor(help, Vector2(1, 0), Rect2(-620, 16, 604, 20))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(help)


func _build_bottom() -> void:
	# A full-width strip along the bottom; its contents stay centred.
	var strip := HBoxContainer.new()
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top = -PortraitOrb.SIZE.y - 6
	strip.offset_bottom = -6
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)

	orb = PortraitOrb.new()
	orb.setup(player)
	strip.add_child(orb)

	# Skill bar + XP bar, sitting low next to the portrait.
	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_END
	right.add_theme_constant_override("separation", 4)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(right)

	prompt_label = UiUtil.label("", 19, UiTheme.SOUL)
	prompt_label.add_theme_font_override("font", UiTheme.title_font())
	prompt_label.add_theme_constant_override("outline_size", 6)
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	right.add_child(prompt_label)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.flat(Color(UiTheme.BG, 0.88), UiTheme.GOLD, 2, 4, 7))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	frame.add_child(row)
	for i in Weapon.MAX_SLOTS:
		var slot := SkillSlot.new()
		slot.setup(player, i)
		row.add_child(slot)
		skill_slots.append(slot)

	var xp_row := Control.new()
	xp_row.custom_minimum_size = Vector2(0, 14)
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(xp_row)
	xp_bar = UiUtil.bar(UiTheme.XP)
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(xp_bar)
	xp_label = UiUtil.label("", 12, UiTheme.TEXT)
	xp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_constant_override("outline_size", 4)
	xp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	xp_row.add_child(xp_label)

	# Spacer the same width as the portrait so the skill bar stays centred.
	var balance := Control.new()
	balance.custom_minimum_size = Vector2(PortraitOrb.SIZE.x, 0)
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(balance)


func _build_messages() -> void:
	messages = VBoxContainer.new()
	messages.position = Vector2(16, 70)
	messages.custom_minimum_size = Vector2(520, 0)
	messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(messages)


func _build_death() -> void:
	death_panel = ColorRect.new()
	(death_panel as ColorRect).color = Color(0.18, 0.0, 0.0, 0.55)
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_panel.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.window(28))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := UiUtil.title("You Have Died", 40)
	t.add_theme_color_override("font_color", Color(0.95, 0.35, 0.28))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UiUtil.hint("You will return to the camp.")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var b := UiUtil.button("Respawn  (R)", func(): respawn_requested.emit())
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(220, 40)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
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
	var l := UiUtil.label(text, 16, color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	messages.add_child(l)
	if messages.get_child_count() > 7:
		messages.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func menu_open() -> bool:
	return inventory_ui.visible or enchanter_ui.visible


func toggle_inventory() -> void:
	if enchanter_ui.visible:
		return
	inventory_ui.visible = not inventory_ui.visible
	get_tree().paused = inventory_ui.visible
	if inventory_ui.visible:
		inventory_ui.refresh()


func open_enchanter() -> void:
	inventory_ui.visible = false
	enchanter_ui.visible = true
	get_tree().paused = true
	enchanter_ui.refresh()


func close_menus() -> void:
	inventory_ui.visible = false
	enchanter_ui.visible = false
	enchanter_ui.drag_from = -1
	get_tree().paused = false
	closed_at_frame = Engine.get_physics_frames()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and menu_open():
		close_menus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and enchanter_ui.visible:
		close_menus()
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
	xp_bar.max_value = player.xp_to_next()
	xp_bar.value = player.xp
	xp_label.text = "Level %d   -   %d%% to next level" % [player.level, floori(100.0 * player.xp / player.xp_to_next())]
	info_label.text = "%s   •   Level %d   •   Area level %d   •   Kills %d" % [player.class_name_text(), player.level, Game.area_level, Game.kills]
	var near: Node3D = null if player.dead else player.nearest_interactable()
	prompt_label.text = ("[F]  " + String(near.get("label")).replace("  [F]", "")) if near and not menu_open() else ""
	var open := player.unlocked_slots()
	for i in Weapon.MAX_SLOTS:
		skill_slots[i].visible = i < open
