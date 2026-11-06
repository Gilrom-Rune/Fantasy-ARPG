class_name Weapon
extends RefCounted
## The class weapon. Every class has exactly one weapon; its stats grow with
## the character's level. Skills live in the weapon's slots, set up at the
## Enchanter's Table.
##
## Each slot holds one active skill gem and one passive gem. The passive
## modifies the active skill in its slot. Slots can be joined with Soul
## Chains: every skill in a chained group gets the passives of the whole group.

const MAX_SLOTS := 10
const LEVELS_PER_SLOT := 10  ## 1 slot at the start, +1 at level 10, 20, ... 90

var class_id := ""
## [{ "active": SkillGem or null, "passive": "support id" or "" }]
var slots: Array = []
## Soul Chains: pairs of slot indexes, always stored [low, high].
var links: Array = []


func _init(cls: String = "") -> void:
	class_id = cls
	for i in MAX_SLOTS:
		slots.append({"active": null, "passive": ""})


func data() -> Dictionary:
	return DB.player_class(class_id)


func weapon_name() -> String:
	return data().get("weapon", "Weapon")


## How many slots are open at this character level.
static func unlocked_slots(level: int) -> int:
	return clampi(1 + level / LEVELS_PER_SLOT, 1, MAX_SLOTS)


## The character level that opens slot `index` (0-based).
static func unlock_level(index: int) -> int:
	return maxi(1, index * LEVELS_PER_SLOT)


## The weapon's modifiers at this level: base + per_level for each level gained.
func mods(level: int) -> Array:
	var out: Array = []
	for m in data().get("weapon_mods", []):
		var value := roundf(float(m["base"]) + float(m["per_level"]) * (level - 1))
		out.append({"stat": m["stat"], "kind": m["kind"], "value": value, "tags": m.get("tags", [])})
	return out


func describe(level: int) -> String:
	var lines: Array = ["%s  (grows with your level)" % weapon_name()]
	var by_stat := {}
	for m in mods(level):
		by_stat[m["stat"] + "|" + ",".join(m["tags"])] = m["value"]
	for m in data().get("weapon_mods", []):
		if not m.has("text"):
			continue
		var tags := ",".join(m.get("tags", []))
		var values: Array = [roundi(by_stat[m["stat"] + "|" + tags])]
		if m.has("pair"):
			values.append(roundi(by_stat.get(m["pair"] + "|" + tags, 0)))
		lines.append(String(m["text"]).format(values))
	return "\n".join(lines)


# --- Soul Chains --------------------------------------------------------------
func has_link(a: int, b: int) -> bool:
	return links.has([mini(a, b), maxi(a, b)])


## Adds the chain if missing, removes it if it already exists.
func toggle_link(a: int, b: int) -> void:
	if a == b:
		return
	var pair := [mini(a, b), maxi(a, b)]
	if links.has(pair):
		links.erase(pair)
	else:
		links.append(pair)


func clear_links(index: int) -> void:
	links = links.filter(func(p): return p[0] != index and p[1] != index)


## Every slot connected to `index` through chains (including itself).
## Chains to locked slots are ignored.
func chain_group(index: int, unlocked: int) -> Array:
	var group: Array = [index]
	var i := 0
	while i < group.size():
		var cur: int = group[i]
		for p in links:
			if p[0] >= unlocked or p[1] >= unlocked:
				continue
			var other := -1
			if p[0] == cur:
				other = p[1]
			elif p[1] == cur:
				other = p[0]
			if other >= 0 and not group.has(other):
				group.append(other)
		i += 1
	group.sort()
	return group


## The passives that apply to the skill in `index`: its own plus every
## passive in its Soul Chain group (no duplicates).
func passives_for(index: int, unlocked: int) -> Array:
	var out: Array = []
	for j in chain_group(index, unlocked):
		var p: String = slots[j]["passive"]
		if p != "" and not out.has(p):
			out.append(p)
	return out
