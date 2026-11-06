class_name Inventory
extends RefCounted
## Everything the player owns: the class weapon (with its gem slots), worn
## gear, the bag, and the gem pouch. Emits `changed` whenever anything moves.

signal changed

const BAG_SIZE := 40

var weapon: Weapon
var equipment := {"helmet": null, "body": null, "boots": null, "ring": null, "amulet": null}
var bag: Array = []
var skill_gems: Array = []  ## SkillGems in the pouch (not in the weapon)
var passive_gems: Array = []  ## passive gem ids in the pouch
var uncut: Array = []  ## [{ "kind": "skill" | "support", "level": int }]


func _init(class_id: String = "") -> void:
	weapon = Weapon.new(class_id)


# --- Gear ---------------------------------------------------------------------
func add_item(item: Item) -> bool:
	if bag.size() >= BAG_SIZE:
		return false
	bag.append(item)
	changed.emit()
	return true


func equip_from_bag(index: int) -> void:
	if index < 0 or index >= bag.size():
		return
	var item: Item = bag[index]
	var old: Item = equipment[item.slot]
	equipment[item.slot] = item
	bag.remove_at(index)
	if old:
		bag.insert(index, old)
	changed.emit()


func unequip(slot: String) -> bool:
	var item: Item = equipment.get(slot)
	if item == null or bag.size() >= BAG_SIZE:
		return false
	equipment[slot] = null
	bag.append(item)
	changed.emit()
	return true


func discard(index: int) -> void:
	if index >= 0 and index < bag.size():
		bag.remove_at(index)
		changed.emit()


# --- Gems -----------------------------------------------------------------------
func add_uncut(kind: String, level: int) -> void:
	uncut.append({"kind": kind, "level": level})
	changed.emit()


## Turns an uncut gem into the chosen skill or passive. It goes into the pouch.
func cut(index: int, choice_id: String) -> void:
	if index < 0 or index >= uncut.size():
		return
	var u: Dictionary = uncut[index]
	uncut.remove_at(index)
	if u["kind"] == "skill":
		skill_gems.append(SkillGem.new(choice_id, u["level"]))
	else:
		passive_gems.append(choice_id)
	changed.emit()


## Moves a skill gem from the pouch into a weapon slot. The slot's old skill
## goes back to the pouch, and so does its passive if it no longer fits.
func set_active(slot_index: int, pouch_index: int) -> void:
	var slot: Dictionary = weapon.slots[slot_index]
	var gem: SkillGem = skill_gems[pouch_index]
	skill_gems.remove_at(pouch_index)
	if slot["active"]:
		skill_gems.append(slot["active"])
	slot["active"] = gem
	if slot["passive"] != "" and not gem.fits(slot["passive"]):
		passive_gems.append(slot["passive"])
		slot["passive"] = ""
	changed.emit()


func clear_active(slot_index: int) -> void:
	var slot: Dictionary = weapon.slots[slot_index]
	if slot["active"]:
		skill_gems.append(slot["active"])
		slot["active"] = null
		changed.emit()


## Returns "" on success, otherwise why it can't go there.
func set_passive(slot_index: int, passive_id: String) -> String:
	var slot: Dictionary = weapon.slots[slot_index]
	var gem: SkillGem = slot["active"]
	if gem == null:
		return "Put an active skill in this slot first"
	if not gem.fits(passive_id):
		return "Needs " + SkillGem.requirement_text(passive_id)
	if not passive_gems.has(passive_id):
		return "You don't have that passive gem"
	passive_gems.erase(passive_id)
	if slot["passive"] != "":
		passive_gems.append(slot["passive"])
	slot["passive"] = passive_id
	changed.emit()
	return ""


func clear_passive(slot_index: int) -> void:
	var slot: Dictionary = weapon.slots[slot_index]
	if slot["passive"] != "":
		passive_gems.append(slot["passive"])
		slot["passive"] = ""
		changed.emit()


# --- Soul Chains ------------------------------------------------------------------
func toggle_chain(a: int, b: int) -> void:
	weapon.toggle_link(a, b)
	changed.emit()


func clear_chains(index: int) -> void:
	weapon.clear_links(index)
	changed.emit()
