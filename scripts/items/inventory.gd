class_name Inventory
extends RefCounted
## Everything the player owns: equipped gear, the bag, skill gems, support
## gems and uncut gems. Emits `changed` whenever anything moves.

signal changed

const BAG_SIZE := 40
const SKILL_SLOTS := 4

var equipment := {"weapon": null, "helmet": null, "body": null, "boots": null, "ring": null}
var bag: Array = []
var skill_slots: Array = [null, null, null, null]  ## SkillGem or null
var loose_gems: Array = []  ## SkillGems not in a slot
var supports: Array = []  ## support ids not socketed in anything
var uncut: Array = []  ## [{ "kind": "skill" | "support", "level": int }]


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


func add_uncut(kind: String, level: int) -> void:
	uncut.append({"kind": kind, "level": level})
	changed.emit()


## Turns an uncut gem into the chosen skill or support.
func cut(index: int, choice_id: String) -> void:
	if index < 0 or index >= uncut.size():
		return
	var u: Dictionary = uncut[index]
	uncut.remove_at(index)
	if u["kind"] == "skill":
		var gem := SkillGem.new(choice_id, u["level"])
		var empty := skill_slots.find(null)
		if empty >= 0:
			skill_slots[empty] = gem
		else:
			loose_gems.append(gem)
	else:
		supports.append(choice_id)
	changed.emit()


## Puts a loose skill gem into a slot. Whatever was there goes back to loose gems.
func place_gem(slot_index: int, loose_index: int) -> void:
	var gem: SkillGem = loose_gems[loose_index]
	loose_gems.remove_at(loose_index)
	if skill_slots[slot_index]:
		loose_gems.append(skill_slots[slot_index])
	skill_slots[slot_index] = gem
	changed.emit()


func remove_gem(slot_index: int) -> void:
	var gem: SkillGem = skill_slots[slot_index]
	if gem:
		loose_gems.append(gem)
		skill_slots[slot_index] = null
		changed.emit()


func socket(slot_index: int, support_id: String) -> String:
	var gem: SkillGem = skill_slots[slot_index]
	if gem == null:
		return "No skill in this slot"
	var reason := gem.can_socket(support_id)
	if reason != "":
		return reason
	gem.supports.append(support_id)
	supports.erase(support_id)
	changed.emit()
	return ""


func unsocket(slot_index: int, support_index: int) -> void:
	var gem: SkillGem = skill_slots[slot_index]
	if gem == null or support_index >= gem.supports.size():
		return
	supports.append(gem.supports[support_index])
	gem.supports.remove_at(support_index)
	changed.emit()
