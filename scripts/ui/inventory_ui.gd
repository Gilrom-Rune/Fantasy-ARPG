class_name InventoryUI
extends Control
## The inventory window: worn gear, the bag, your character sheet and the gem
## pouch. Gems are put into the weapon at the Enchanter's Table in camp.
## The game is paused while it is open.

var player: Player
var _cols: Array = []  ## three VBoxContainers
var _refresh_queued := false


func setup(p: Player) -> void:
	player = p
	player.inv.changed.connect(_queue_refresh)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var w := UiUtil.window("Inventory", "Close  (I)", func(): Game.hud.close_menus())
	add_child(w["root"])
	var hover_hint := UiUtil.hint("Hover anything for details   ")
	hover_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	w["top"].add_child(hover_hint)
	w["top"].move_child(hover_hint, 1)
	var root: VBoxContainer = w["body"]

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)
	for i in 3:
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		scroll.add_child(col)
		body.add_child(scroll)
		_cols.append(col)


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		refresh.call_deferred()


func refresh() -> void:
	_refresh_queued = false
	if not visible or player == null or _cols.is_empty():
		return
	for col in _cols:
		UiUtil.clear(col)
	_build_equipment(_cols[0])
	_build_bag(_cols[1])
	_build_pouch(_cols[2])


# --- Column 1: weapon, gear, character sheet ---------------------------------------
func _build_equipment(col: VBoxContainer) -> void:
	var inv := player.inv
	col.add_child(UiUtil.header("Weapon"))
	var w := UiUtil.label(inv.weapon.describe(player.level), 14, Color(1.0, 0.78, 0.5))
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(w)
	col.add_child(UiUtil.header("Equipment"))
	col.add_child(UiUtil.label("Click an item to take it off.", 12, UiTheme.MUTED))
	for slot in DB.SLOTS:
		var row := HBoxContainer.new()
		var l := UiUtil.label(slot.capitalize(), 14, UiTheme.MUTED)
		l.custom_minimum_size = Vector2(70, 0)
		row.add_child(l)
		var item: Item = inv.equipment[slot]
		var b: Button
		if item:
			b = UiUtil.button(item.name, func(): inv.unequip(slot), item.color(), item.tooltip())
		else:
			b = UiUtil.button("(empty)", func(): pass, UiTheme.FAINT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		col.add_child(row)

	col.add_child(HSeparator.new())
	col.add_child(UiUtil.header("Character"))
	var p := player
	var lines := [
		"%s, level %d   (XP %d / %d)" % [p.class_name_text(), p.level, p.xp, p.xp_to_next()],
		"Life: %d    Regen: %.1f/s" % [p.max_life, p.life_regen],
		"Mana: %d    Regen: %.1f/s" % [p.max_mana, p.mana_regen],
		"Armour: %d" % p.armour,
		"Resistances:  Fire %d%%   Cold %d%%   Lightning %d%%" % [p.resists["fire"], p.resists["cold"], p.resists["lightning"]],
		"Movement speed: %.1f" % p.move_speed,
	]
	for line in lines:
		col.add_child(UiUtil.label(line, 14))


# --- Column 2: bag ------------------------------------------------------------------
func _build_bag(col: VBoxContainer) -> void:
	var inv := player.inv
	col.add_child(UiUtil.header("Bag  (%d / %d)" % [inv.bag.size(), Inventory.BAG_SIZE]))
	col.add_child(UiUtil.label("Click: equip    Right-click: destroy", 12, UiTheme.MUTED))
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
		col.add_child(UiUtil.label("Kill monsters and open chests to find items.", 14, UiTheme.FAINT))


# --- Column 3: gem pouch (read only) ---------------------------------------------------
func _build_pouch(col: VBoxContainer) -> void:
	var inv := player.inv
	col.add_child(UiUtil.header("Gem Pouch"))
	var note := UiUtil.label("Cut gems and set them into your weapon at the Enchanter's Table in camp (walk up to it and press F).", 13, UiTheme.SOUL)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)
	col.add_child(UiUtil.label("Uncut gems: %d" % inv.uncut.size(), 14))
	for g in inv.skill_gems:
		col.add_child(UiUtil.label("  " + g.display_name(), 14, EnchanterUI.SKILL_COLOR))
	for pid in inv.passive_gems:
		col.add_child(UiUtil.label("  " + String(DB.support(pid).get("name", pid)), 14, EnchanterUI.PASSIVE_COLOR))
	col.add_child(HSeparator.new())
	col.add_child(UiUtil.header("Weapon Slots"))
	var open := player.unlocked_slots()
	for i in open:
		var slot: Dictionary = inv.weapon.slots[i]
		var gem: SkillGem = slot["active"]
		var text := "%s:  %s" % [Player.SLOT_KEYS[i], gem.display_name() if gem else "(empty)"]
		if slot["passive"] != "":
			text += "  +  " + String(DB.support(slot["passive"]).get("name", ""))
		col.add_child(UiUtil.label(text, 14))
	if open < Weapon.MAX_SLOTS:
		col.add_child(UiUtil.label("Next slot opens at level %d." % Weapon.unlock_level(open), 13, UiTheme.FAINT))
