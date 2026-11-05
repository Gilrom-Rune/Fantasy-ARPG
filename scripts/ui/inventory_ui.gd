class_name InventoryUI
extends Control
## The inventory window: equipment, bag, skill slots with support sockets,
## and cutting uncut gems. The game is paused while it is open.

const SUPPORT_COLOR := Color(0.55, 0.8, 1.0)
const SKILL_COLOR := Color(0.5, 1.0, 0.6)

var player: Player
var _cols: Array = []  ## three VBoxContainers
var _chooser: Control
var _chooser_title: Label
var _chooser_list: VBoxContainer


func setup(p: Player) -> void:
	player = p
	player.inv.changed.connect(refresh)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 50
	panel.offset_top = 40
	panel.offset_right = -50
	panel.offset_bottom = -40
	panel.add_theme_stylebox_override("panel", UiUtil.box(Color(0.07, 0.07, 0.09, 0.97), Color(0.5, 0.42, 0.28), 6, 14))
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var top := HBoxContainer.new()
	var title := UiUtil.label("Inventory & Gems", 22, Color(0.95, 0.8, 0.5))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UiUtil.label("Hover anything for details   ", 13, Color(0.6, 0.6, 0.6)))
	var close := UiUtil.button("Close (I)", func(): Game.hud.toggle_inventory())
	top.add_child(close)
	root.add_child(top)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)
	for i in 3:
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_stretch_ratio = [1.0, 1.0, 1.4][i]
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		scroll.add_child(col)
		body.add_child(scroll)
		_cols.append(col)

	_build_chooser()


func _build_chooser() -> void:
	_chooser = ColorRect.new()
	(_chooser as ColorRect).color = Color(0, 0, 0, 0.55)
	_chooser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chooser.visible = false
	add_child(_chooser)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chooser.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.add_theme_stylebox_override("panel", UiUtil.box(Color(0.09, 0.09, 0.12), Color(0.6, 0.5, 0.3), 6, 14))
	center.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	_chooser_title = UiUtil.header("")
	v.add_child(_chooser_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_chooser_list = VBoxContainer.new()
	_chooser_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_chooser_list)
	v.add_child(UiUtil.button("Cancel", func(): _chooser.visible = false))


## options: [{ "text", "tip", "color", "disabled", "action": Callable }]
func open_chooser(title: String, options: Array) -> void:
	_chooser_title.text = title
	UiUtil.clear(_chooser_list)
	for o in options:
		var action: Callable = o["action"]
		var on_press := func():
			_chooser.visible = false
			action.call()
		var b := UiUtil.button(o["text"], on_press, o.get("color", Color.WHITE), o.get("tip", ""))
		b.disabled = o.get("disabled", false)
		_chooser_list.add_child(b)
	if options.is_empty():
		_chooser_list.add_child(UiUtil.label("Nothing available.", 15, Color(0.6, 0.6, 0.6)))
	_chooser.visible = true


func refresh() -> void:
	if not visible or player == null or _cols.is_empty():
		return
	for col in _cols:
		UiUtil.clear(col)
	_build_equipment(_cols[0])
	_build_bag(_cols[1])
	_build_gems(_cols[2])


# --- Column 1: equipment + character sheet -----------------------------------
func _build_equipment(col: VBoxContainer) -> void:
	var inv := player.inv
	col.add_child(UiUtil.header("Equipment"))
	col.add_child(UiUtil.label("Click an item to take it off.", 12, Color(0.6, 0.6, 0.6)))
	for slot in DB.SLOTS:
		var row := HBoxContainer.new()
		var l := UiUtil.label(slot.capitalize(), 14, Color(0.7, 0.7, 0.7))
		l.custom_minimum_size = Vector2(64, 0)
		row.add_child(l)
		var item: Item = inv.equipment[slot]
		var b: Button
		if item:
			b = UiUtil.button(item.name, func(): inv.unequip(slot), item.color(), item.tooltip())
		else:
			b = UiUtil.button("(empty)", func(): pass, Color(0.45, 0.45, 0.45))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		col.add_child(row)

	col.add_child(HSeparator.new())
	col.add_child(UiUtil.header("Character"))
	var p := player
	var lines := [
		"Level %d   (XP %d / %d)" % [p.level, p.xp, p.xp_to_next()],
		"Life: %d    Regen: %.1f/s" % [p.max_life, p.life_regen],
		"Mana: %d    Regen: %.1f/s" % [p.max_mana, p.mana_regen],
		"Armour: %d" % p.armour,
		"Resistances:  Fire %d%%   Cold %d%%   Lightning %d%%" % [p.resists["fire"], p.resists["cold"], p.resists["lightning"]],
		"Movement speed: %.1f" % p.move_speed,
	]
	for line in lines:
		col.add_child(UiUtil.label(line, 14))


# --- Column 2: bag -----------------------------------------------------------
func _build_bag(col: VBoxContainer) -> void:
	var inv := player.inv
	col.add_child(UiUtil.header("Bag  (%d / %d)" % [inv.bag.size(), Inventory.BAG_SIZE]))
	col.add_child(UiUtil.label("Click: equip    Right-click: destroy", 12, Color(0.6, 0.6, 0.6)))
	for i in inv.bag.size():
		var item: Item = inv.bag[i]
		var tip := item.tooltip()
		var current: Item = inv.equipment[item.slot]
		if current:
			tip += "\n\n=== Currently equipped ===\n" + current.tooltip()
		var b := UiUtil.button("[%s] %s" % [item.slot.capitalize(), item.name], func(): inv.equip_from_bag(i), item.color(), tip)
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
				inv.discard(i))
		col.add_child(b)
	if inv.bag.is_empty():
		col.add_child(UiUtil.label("Kill monsters to find items.", 14, Color(0.55, 0.55, 0.55)))


# --- Column 3: skills, supports, uncut gems ------------------------------------
func _build_gems(col: VBoxContainer) -> void:
	var inv := player.inv
	col.add_child(UiUtil.header("Skills"))
	col.add_child(UiUtil.label("Click a skill to swap it. Click a socket to add or remove a support.", 12, Color(0.6, 0.6, 0.6)))
	for i in Inventory.SKILL_SLOTS:
		var gem: SkillGem = inv.skill_slots[i]
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UiUtil.box(Color(0.11, 0.11, 0.14), Color(0.3, 0.3, 0.35), 4, 6))
		var v := VBoxContainer.new()
		box.add_child(v)
		var row := HBoxContainer.new()
		var key := UiUtil.label(Player.SLOT_KEYS[i], 14, Color(0.95, 0.8, 0.5))
		key.custom_minimum_size = Vector2(40, 0)
		row.add_child(key)
		var slot_i := i
		if gem:
			var tip: String = SkillCompiler.describe(player.compiled[i]) + "\n\n" + gem.data().get("description", "")
			var b := UiUtil.button(gem.display_name(), func(): _choose_skill_for_slot(slot_i), SKILL_COLOR, tip)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
		else:
			var b := UiUtil.button("(empty - click to add a skill)", func(): _choose_skill_for_slot(slot_i), Color(0.5, 0.5, 0.5))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
		v.add_child(row)
		if gem:
			var sockets := HFlowContainer.new()
			for j in gem.max_supports():
				if j < gem.supports.size():
					var sid: String = gem.supports[j]
					var sup := DB.support(sid)
					var sj := j
					sockets.add_child(UiUtil.button("● " + sup.get("name", sid), func(): inv.unsocket(slot_i, sj), SUPPORT_COLOR, sup.get("description", "") + "\n\nClick to remove."))
				else:
					sockets.add_child(UiUtil.button("○ empty socket", func(): _choose_support_for_slot(slot_i), Color(0.5, 0.5, 0.55)))
			v.add_child(sockets)
		col.add_child(box)

	col.add_child(HSeparator.new())
	col.add_child(UiUtil.header("Uncut Gems"))
	col.add_child(UiUtil.label("Cut an uncut gem to choose which skill or support it becomes.", 12, Color(0.6, 0.6, 0.6)))
	for i in inv.uncut.size():
		var u: Dictionary = inv.uncut[i]
		var is_skill: bool = u["kind"] == "skill"
		var text := "Cut: Uncut %s Gem (Lv %d)" % ["Skill" if is_skill else "Support", u["level"]]
		var idx := i
		col.add_child(UiUtil.button(text, func(): _choose_cut(idx), LootDrop.UNCUT_SKILL_COLOR if is_skill else LootDrop.UNCUT_SUPPORT_COLOR))
	if inv.uncut.is_empty():
		col.add_child(UiUtil.label("None. Monsters drop them.", 14, Color(0.55, 0.55, 0.55)))

	col.add_child(HSeparator.new())
	col.add_child(UiUtil.header("Spare Skill Gems"))
	for g in inv.loose_gems:
		col.add_child(UiUtil.label("  " + g.display_name(), 14, SKILL_COLOR))
	if inv.loose_gems.is_empty():
		col.add_child(UiUtil.label("None.", 14, Color(0.55, 0.55, 0.55)))

	col.add_child(UiUtil.header("Spare Support Gems"))
	for sid in inv.supports:
		var sup := DB.support(sid)
		var l := UiUtil.label("  " + sup.get("name", sid) + "  -  " + sup.get("description", ""), 13, SUPPORT_COLOR)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	if inv.supports.is_empty():
		col.add_child(UiUtil.label("None.", 14, Color(0.55, 0.55, 0.55)))


func _choose_skill_for_slot(slot_i: int) -> void:
	var inv := player.inv
	var options: Array = []
	for k in inv.loose_gems.size():
		var g: SkillGem = inv.loose_gems[k]
		var gi := k
		var tip := SkillCompiler.describe(SkillCompiler.compile(g, player.stats))
		options.append({"text": g.display_name(), "tip": tip, "color": SKILL_COLOR, "action": func(): inv.place_gem(slot_i, gi)})
	if inv.skill_slots[slot_i]:
		options.append({"text": "Remove from slot", "color": Color(1, 0.6, 0.5), "action": func(): inv.remove_gem(slot_i)})
	open_chooser("Skill for %s" % Player.SLOT_KEYS[slot_i], options)


func _choose_support_for_slot(slot_i: int) -> void:
	var inv := player.inv
	var gem: SkillGem = inv.skill_slots[slot_i]
	var options: Array = []
	var seen := {}
	for sid in inv.supports:
		if seen.has(sid):
			continue
		seen[sid] = true
		var sup := DB.support(sid)
		var reason := gem.can_socket(sid)
		var text: String = sup.get("name", sid)
		if reason != "":
			text += "   (%s)" % reason
		var s: String = sid
		options.append({
			"text": text, "tip": sup.get("description", ""), "color": SUPPORT_COLOR,
			"disabled": reason != "", "action": func(): inv.socket(slot_i, s),
		})
	open_chooser("Support for %s" % gem.display_name(), options)


func _choose_cut(index: int) -> void:
	var inv := player.inv
	var u: Dictionary = inv.uncut[index]
	var options: Array = []
	if u["kind"] == "skill":
		for id in DB.player_skill_ids():
			var preview := SkillCompiler.compile(SkillGem.new(id, u["level"]), player.stats)
			var tip: String = DB.skill(id).get("description", "") + "\n\n" + SkillCompiler.describe(preview)
			var sid: String = id
			options.append({"text": "%s   [%s]" % [preview["name"], ", ".join(preview["tags"])], "tip": tip, "color": SKILL_COLOR, "action": func(): inv.cut(index, sid)})
		open_chooser("Cut Uncut Skill Gem (Lv %d)" % u["level"], options)
	else:
		for id in DB.support_ids():
			var sup := DB.support(id)
			var req: Array = sup.get("requires", [])
			var tip: String = sup.get("description", "") + "\n\nWorks with: " + ("any skill" if req.is_empty() else " or ".join(req) + " skills")
			var sid: String = id
			options.append({"text": sup.get("name", id), "tip": tip, "color": SUPPORT_COLOR, "action": func(): inv.cut(index, sid)})
		open_chooser("Cut Uncut Support Gem", options)
