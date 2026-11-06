class_name EnchanterUI
extends Control
## The Enchanter's Table screen.
##  - Each unlocked weapon slot holds one active skill gem + one passive gem.
##  - Drag from one slot's chain node to another to forge a Soul Chain:
##    chained skills share each other's passives.
##  - Uncut gems are cut here too.
## The game is paused while it is open.

const SKILL_COLOR := Color(0.5, 1.0, 0.6)
const PASSIVE_COLOR := Color(0.55, 0.8, 1.0)
const LOCKED_COLOR := Color(0.4, 0.4, 0.42)
const HINT_COLOR := Color(0.6, 0.6, 0.6)

var player: Player
var nodes: Array = []  ## chain node buttons, one per slot (index = slot)
var drag_from := -1  ## slot whose chain is being dragged, or -1

var _title: Label
var _weapon_label: Label
var _slots_box: VBoxContainer
var _pouch: VBoxContainer
var _chooser: Chooser
var _chains: SoulChainLayer
var _refresh_queued := false


func setup(p: Player) -> void:
	player = p
	player.inv.changed.connect(_queue_refresh)
	player.stats_changed.connect(_queue_refresh)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 50
	panel.offset_top = 30
	panel.offset_right = -50
	panel.offset_bottom = -30
	panel.add_theme_stylebox_override("panel", UiUtil.box(Color(0.05, 0.06, 0.09, 0.97), Color(0.4, 0.6, 0.85), 6, 14))
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var top := HBoxContainer.new()
	_title = UiUtil.label("Enchanter's Table", 22, Color(0.65, 0.85, 1.0))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	top.add_child(UiUtil.button("Close (Esc)", func(): Game.hud.close_menus()))
	root.add_child(top)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root.add_child(body)

	# Left: weapon + slots
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.8
	body.add_child(left)
	_weapon_label = UiUtil.label("", 14, Color(0.85, 0.85, 0.85))
	left.add_child(_weapon_label)
	left.add_child(HSeparator.new())
	var hint := UiUtil.label("Each slot holds an ACTIVE skill gem and a PASSIVE gem that modifies it.\n" \
		+ "Soul Chains: drag from one ● node to another to link them - linked skills share their passives.\n" \
		+ "Drag between the same two nodes again to break a chain. Right-click a node to break all of its chains.", 13, HINT_COLOR)
	left.add_child(hint)
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 4)
	left.add_child(_slots_box)

	# Right: gem pouch
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_pouch = VBoxContainer.new()
	_pouch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pouch.add_theme_constant_override("separation", 4)
	scroll.add_child(_pouch)

	_chains = SoulChainLayer.new()
	_chains.ui = self
	add_child(_chains)
	_chooser = Chooser.new()
	add_child(_chooser)


func _queue_refresh() -> void:
	# Rebuilding is deferred so buttons are never freed while handling their own click.
	if not _refresh_queued:
		_refresh_queued = true
		refresh.call_deferred()


func refresh() -> void:
	_refresh_queued = false
	if not visible or player == null or _slots_box == null:
		return
	var inv := player.inv
	var weapon := inv.weapon
	var open := player.unlocked_slots()
	_title.text = "Enchanter's Table  -  %s %s  (Level %d)" % [player.class_name_text(), weapon.weapon_name(), player.level]
	_weapon_label.text = weapon.describe(player.level) + "\nSlots unlocked: %d / %d  (one more every %d levels)" % [open, Weapon.MAX_SLOTS, Weapon.LEVELS_PER_SLOT]
	UiUtil.clear(_slots_box)
	nodes.clear()
	for i in Weapon.MAX_SLOTS:
		_slots_box.add_child(_build_slot_row(i, i < open))
	_build_pouch()


func _build_slot_row(i: int, unlocked: bool) -> Control:
	var inv := player.inv
	var slot: Dictionary = inv.weapon.slots[i]
	var box := PanelContainer.new()
	var border := Color(0.3, 0.4, 0.55) if unlocked else Color(0.2, 0.2, 0.22)
	box.add_theme_stylebox_override("panel", UiUtil.box(Color(0.08, 0.09, 0.12), border, 4, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var key := UiUtil.label(Player.SLOT_KEYS[i], 14, Color(0.95, 0.8, 0.5) if unlocked else LOCKED_COLOR)
	key.custom_minimum_size = Vector2(38, 0)
	row.add_child(key)

	var node := Button.new()
	node.custom_minimum_size = Vector2(26, 26)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		var locked := UiUtil.label("Locked  -  opens at level %d" % Weapon.unlock_level(i), 14, LOCKED_COLOR)
		locked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(locked)
		node.disabled = true
		_style_node(node, Color(0.13, 0.13, 0.15))
	else:
		var gem: SkillGem = slot["active"]
		var active_tip := "Click to choose an active skill gem."
		if gem and player.compiled[i] != null:
			active_tip = SkillCompiler.describe(player.compiled[i]) + "\n\n" + String(gem.data().get("description", ""))
		var active := UiUtil.button(gem.display_name() if gem else "+ Active skill gem", func(): _choose_active(i),
			SKILL_COLOR if gem else HINT_COLOR, active_tip)
		active.custom_minimum_size = Vector2(210, 0)
		row.add_child(active)

		var pid: String = slot["passive"]
		var passive_text := "+ Passive gem"
		var passive_tip := "Click to choose a passive gem for this skill."
		if pid != "":
			var sup := DB.support(pid)
			passive_text = String(sup.get("name", pid))
			passive_tip = String(sup.get("description", "")) + "\nWorks with: " + SkillGem.requirement_text(pid)
		var passive := UiUtil.button(passive_text, func(): _choose_passive(i), PASSIVE_COLOR if pid != "" else HINT_COLOR, passive_tip)
		passive.custom_minimum_size = Vector2(170, 0)
		passive.disabled = gem == null
		row.add_child(passive)

		var shared := UiUtil.label(_shared_text(i), 12, Color(0.6, 0.85, 1.0))
		shared.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shared.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(shared)

		var linked := inv.weapon.chain_group(i, player.unlocked_slots()).size() > 1
		_style_node(node, Color(0.6, 0.88, 1.0) if linked else Color(0.22, 0.36, 0.46))
		node.tooltip_text = "Soul Chain node: drag to another slot's node to link them.\nRight-click to break this slot's chains."
		node.gui_input.connect(func(e: InputEvent): _on_node_input(e, i))
	row.add_child(node)
	nodes.append(node)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(120, 0)  # room for the chains to curve
	row.add_child(gap)
	return box


func _style_node(node: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := UiUtil.box(color if state != "hover" else color.lightened(0.3), Color(1, 1, 1, 0.5), 13, 0)
		node.add_theme_stylebox_override(state, s)
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Which passives this slot borrows from its Soul Chain group.
func _shared_text(i: int) -> String:
	var weapon := player.inv.weapon
	var open := player.unlocked_slots()
	var group := weapon.chain_group(i, open)
	if group.size() <= 1:
		return ""
	var others: Array = []
	var borrowed: Array = []
	for j in group:
		if j == i:
			continue
		others.append(Player.SLOT_KEYS[j])
		var p: String = weapon.slots[j]["passive"]
		if p != "" and p != weapon.slots[i]["passive"]:
			borrowed.append(String(DB.support(p).get("name", p)))
	var text := "Chained to " + ", ".join(others)
	if not borrowed.is_empty():
		text += "  ->  also gets: " + ", ".join(borrowed)
	var c = player.compiled[i]
	if c != null and not c["ignored"].is_empty():
		text += "  (doesn't fit: " + ", ".join(c["ignored"]) + ")"
	return text


func _on_node_input(e: InputEvent, i: int) -> void:
	if not (e is InputEventMouseButton):
		return
	var mb := e as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			drag_from = i
		elif drag_from >= 0:
			var target := _node_at(get_global_mouse_position())
			var from := drag_from
			drag_from = -1
			if target >= 0 and target != from:
				player.inv.toggle_chain(from, target)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		player.inv.clear_chains(i)


func _node_at(pos: Vector2) -> int:
	for j in mini(nodes.size(), player.unlocked_slots()):
		var n: Control = nodes[j]
		if n.get_global_rect().grow(6).has_point(pos):
			return j
	return -1


func _build_pouch() -> void:
	var inv := player.inv
	UiUtil.clear(_pouch)
	_pouch.add_child(UiUtil.header("Uncut Gems"))
	_pouch.add_child(UiUtil.label("Cut a gem to choose what it becomes.", 12, HINT_COLOR))
	for k in inv.uncut.size():
		var u: Dictionary = inv.uncut[k]
		var is_skill: bool = u["kind"] == "skill"
		var text := "Cut: Uncut %s Gem (Lv %d)" % ["Skill" if is_skill else "Passive", u["level"]]
		_pouch.add_child(UiUtil.button(text, func(): choose_cut(k), LootDrop.UNCUT_SKILL_COLOR if is_skill else LootDrop.UNCUT_SUPPORT_COLOR))
	if inv.uncut.is_empty():
		_pouch.add_child(UiUtil.label("None. Monsters and chests drop them.", 14, LOCKED_COLOR))

	_pouch.add_child(HSeparator.new())
	_pouch.add_child(UiUtil.header("Active Skill Gems"))
	for g in inv.skill_gems:
		var l := UiUtil.label("  " + g.display_name() + "   [" + ", ".join(g.tags()) + "]", 14, SKILL_COLOR)
		l.tooltip_text = String(g.data().get("description", ""))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		_pouch.add_child(l)
	if inv.skill_gems.is_empty():
		_pouch.add_child(UiUtil.label("None in your pouch.", 14, LOCKED_COLOR))

	_pouch.add_child(UiUtil.header("Passive Gems"))
	for pid in inv.passive_gems:
		var sup := DB.support(pid)
		var l := UiUtil.label("  " + String(sup.get("name", pid)) + "  -  " + String(sup.get("description", "")), 13, PASSIVE_COLOR)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pouch.add_child(l)
	if inv.passive_gems.is_empty():
		_pouch.add_child(UiUtil.label("None in your pouch.", 14, LOCKED_COLOR))


# --- Choosers -------------------------------------------------------------------
func _choose_active(slot_i: int) -> void:
	var inv := player.inv
	var options: Array = []
	var passives := inv.weapon.passives_for(slot_i, player.unlocked_slots())
	for k in inv.skill_gems.size():
		var g: SkillGem = inv.skill_gems[k]
		var preview := SkillCompiler.compile(g, player.stats, passives)
		options.append({"text": g.display_name(), "tip": SkillCompiler.describe(preview), "color": SKILL_COLOR,
			"action": func(): inv.set_active(slot_i, k)})
	if inv.weapon.slots[slot_i]["active"]:
		options.append({"text": "Remove (back to pouch)", "color": Color(1, 0.6, 0.5), "action": func(): inv.clear_active(slot_i)})
	_chooser.open("Active skill for slot %s" % Player.SLOT_KEYS[slot_i], options)


func _choose_passive(slot_i: int) -> void:
	var inv := player.inv
	var gem: SkillGem = inv.weapon.slots[slot_i]["active"]
	if gem == null:
		return
	var options: Array = []
	var seen := {}
	for pid in inv.passive_gems:
		if seen.has(pid):
			continue
		seen[pid] = true
		var sup := DB.support(pid)
		var fits := gem.fits(pid)
		var text := String(sup.get("name", pid))
		if not fits:
			text += "   (needs %s)" % SkillGem.requirement_text(pid)
		var id: String = pid
		options.append({"text": text, "tip": String(sup.get("description", "")), "color": PASSIVE_COLOR,
			"disabled": not fits, "action": func(): inv.set_passive(slot_i, id)})
	if inv.weapon.slots[slot_i]["passive"] != "":
		options.append({"text": "Remove (back to pouch)", "color": Color(1, 0.6, 0.5), "action": func(): inv.clear_passive(slot_i)})
	_chooser.open("Passive for %s" % gem.display_name(), options)


func choose_cut(index: int) -> void:
	var inv := player.inv
	var u: Dictionary = inv.uncut[index]
	var options: Array = []
	if u["kind"] == "skill":
		for id in DB.player_skill_ids():
			var preview := SkillCompiler.compile(SkillGem.new(id, u["level"]), player.stats)
			var tip: String = String(DB.skill(id).get("description", "")) + "\n\n" + SkillCompiler.describe(preview)
			var sid: String = id
			options.append({"text": "%s   [%s]" % [preview["name"], ", ".join(preview["tags"])], "tip": tip,
				"color": SKILL_COLOR, "action": func(): inv.cut(index, sid)})
		_chooser.open("Cut Uncut Skill Gem (Lv %d)" % u["level"], options)
	else:
		for id in DB.support_ids():
			var sup := DB.support(id)
			var tip: String = String(sup.get("description", "")) + "\n\nWorks with: " + SkillGem.requirement_text(id)
			var sid: String = id
			options.append({"text": String(sup.get("name", id)), "tip": tip, "color": PASSIVE_COLOR, "action": func(): inv.cut(index, sid)})
		_chooser.open("Cut Uncut Passive Gem", options)


## Used by the automated test bot to make sure every screen builds without errors.
func exercise() -> void:
	refresh()
	if not player.inv.uncut.is_empty():
		choose_cut(0)
	_choose_active(0)
	_choose_passive(0)
	_chooser.close()
