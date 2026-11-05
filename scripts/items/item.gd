class_name Item
extends RefCounted
## A piece of equipment: a base type plus randomly rolled affixes.

enum Rarity { NORMAL, MAGIC, RARE }

const RARITY_COLORS := [Color(0.92, 0.92, 0.92), Color(0.5, 0.6, 1.0), Color(1.0, 0.88, 0.35)]
const RARITY_NAMES := ["Normal", "Magic", "Rare"]

var base_id := ""
var base_name := ""
var name := ""
var slot := ""
var rarity := Rarity.NORMAL
var ilvl := 1
var implicit: Array = []
var implicit_text := ""
var affixes: Array = []  ## [{ "id", "type", "text", "mods": [...] }]


func all_mods() -> Array:
	var out: Array = implicit.duplicate()
	for a in affixes:
		out.append_array(a["mods"])
	return out


func color() -> Color:
	return RARITY_COLORS[rarity]


func prefix_count() -> int:
	return affixes.filter(func(a): return a["type"] == "prefix").size()


func suffix_count() -> int:
	return affixes.filter(func(a): return a["type"] == "suffix").size()


func tooltip() -> String:
	var lines: Array = [name]
	if name != base_name:
		lines.append(base_name)
	lines.append("%s %s   (item level %d)" % [RARITY_NAMES[rarity], slot.capitalize(), ilvl])
	lines.append("--------------------")
	if implicit_text != "":
		lines.append(implicit_text)
		lines.append("--------------------")
	for a in affixes:
		lines.append(a["text"])
	if affixes.is_empty():
		lines.append("(no affixes)")
	return "\n".join(lines)
