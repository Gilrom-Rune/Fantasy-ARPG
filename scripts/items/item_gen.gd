class_name ItemGen
extends RefCounted
## Random item generation: picks a base type, a rarity and rolls affixes.

const RARE_FIRST := ["Grim", "Storm", "Ash", "Dusk", "Wraith", "Bone", "Ember", "Frost", "Gloom", "Rune", "Hollow", "Thorn"]
const RARE_LAST := {
	"weapon": ["Bite", "Edge", "Song", "Fang", "Thirst"],
	"helmet": ["Crown", "Visage", "Brow", "Halo"],
	"body": ["Shell", "Hide", "Ward", "Coat"],
	"boots": ["Stride", "Trail", "March", "Tread"],
	"ring": ["Loop", "Coil", "Band", "Spiral"],
}
const MAX_PREFIX := 3
const MAX_SUFFIX := 3


static func roll_rarity(bonus: float = 0.0) -> int:
	var r := randf()
	if r < 0.12 + bonus * 0.5:
		return Item.Rarity.RARE
	if r < 0.5 + bonus:
		return Item.Rarity.MAGIC
	return Item.Rarity.NORMAL


static func roll_item(ilvl: int, rarity: int = -1, base_id: String = "") -> Item:
	DB.ensure_loaded()
	if base_id == "":
		var choices: Array = []
		for id in DB.bases:
			if int(DB.bases[id].get("min_ilvl", 1)) <= ilvl:
				choices.append(id)
		base_id = choices.pick_random()
	var b: Dictionary = DB.bases[base_id]
	var item := Item.new()
	item.base_id = base_id
	item.base_name = b["name"]
	item.name = b["name"]
	item.slot = b["slot"]
	item.ilvl = ilvl
	item.implicit = b.get("implicit", [])
	item.implicit_text = b.get("implicit_text", "")
	item.rarity = roll_rarity() if rarity < 0 else rarity

	var count := 0
	match item.rarity:
		Item.Rarity.MAGIC:
			count = randi_range(1, 2)
		Item.Rarity.RARE:
			count = randi_range(3, 5)
	for i in count:
		var affix := roll_affix(item)  # pool already respects prefix/suffix caps
		if affix.is_empty():
			break
		item.affixes.append(affix)
	_name_item(item)
	return item


## Picks a random affix this item can still take and rolls its values.
static func roll_affix(item: Item) -> Dictionary:
	var owned := item.affixes.map(func(a): return a["id"])
	var pool: Array = []
	for a in DB.affixes:
		if owned.has(a["id"]) or not a["slots"].has(item.slot):
			continue
		var cap := 1 if item.rarity == Item.Rarity.MAGIC else MAX_PREFIX
		if a["type"] == "prefix" and item.prefix_count() >= cap:
			continue
		if a["type"] == "suffix" and item.suffix_count() >= cap:
			continue
		if int(a["tiers"][0]["ilvl"]) > item.ilvl:
			continue
		pool.append(a)
	if pool.is_empty():
		return {}
	var a: Dictionary = pool.pick_random()
	# Higher item level unlocks better tiers; pick one of the best two available.
	var tiers: Array = a["tiers"].filter(func(t): return int(t["ilvl"]) <= item.ilvl)
	var tier: Dictionary = tiers[randi_range(maxi(0, tiers.size() - 2), tiers.size() - 1)]
	var values: Array = []
	var mods: Array = []
	for i in a["mods"].size():
		var r: Array = tier["values"][i]
		var v := randi_range(int(r[0]), int(r[1]))
		values.append(v)
		var m: Dictionary = a["mods"][i].duplicate()
		m["value"] = float(v)
		if not m.has("tags"):
			m["tags"] = []
		mods.append(m)
	return {
		"id": a["id"],
		"type": a["type"],
		"name": a.get("name", ""),
		"text": String(a["text"]).format(values),
		"mods": mods,
	}


static func _name_item(item: Item) -> void:
	match item.rarity:
		Item.Rarity.NORMAL:
			item.name = item.base_name
		Item.Rarity.MAGIC:
			var n := item.base_name
			for a in item.affixes:
				if a["type"] == "prefix":
					n = a["name"] + " " + n
				else:
					n = n + " " + a["name"]
			item.name = n
		Item.Rarity.RARE:
			item.name = "%s %s" % [RARE_FIRST.pick_random(), RARE_LAST.get(item.slot, ["Relic"]).pick_random()]
