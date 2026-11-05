class_name StatBlock
extends RefCounted
## A collection of stat modifiers. This is the heart of the build system.
##
## Every modifier is a Dictionary:
##   { "stat": "damage", "kind": "increased", "value": 20, "tags": ["fire"] }
##
## kind is one of:
##   "flat"      - added to the base value          (+10 to maximum Life)
##   "increased" - all increases are ADDED together  (20% increased Damage)
##   "more"      - each one MULTIPLIES separately    (30% more Damage)
##
## Final value = (base + flat) * (1 + sum(increased)/100) * product(1 + more/100)
##
## tags make a modifier conditional: a modifier only applies when ALL of its
## tags are present in the query. "20% increased damage" with tags ["fire"]
## only applies when calculating fire damage.

var mods: Array = []


func add(stat: String, kind: String, value: float, tags: Array = [], source: String = "") -> StatBlock:
	mods.append({"stat": stat, "kind": kind, "value": value, "tags": tags, "source": source})
	return self


func add_mod(mod: Dictionary, source: String = "") -> void:
	var m := mod.duplicate()
	if not m.has("tags"):
		m["tags"] = []
	if not m.has("value"):
		m["value"] = 0.0
	if source != "":
		m["source"] = source
	mods.append(m)


func add_all(list: Array, source: String = "") -> void:
	for m in list:
		add_mod(m, source)


func copy() -> StatBlock:
	var s := StatBlock.new()
	s.mods = mods.duplicate()
	return s


func _applies(m: Dictionary, stat: String, kind: String, tags: Array) -> bool:
	if m["stat"] != stat or m["kind"] != kind:
		return false
	for t in m["tags"]:
		if not tags.has(t):
			return false
	return true


func flat(stat: String, tags: Array = []) -> float:
	var total := 0.0
	for m in mods:
		if _applies(m, stat, "flat", tags):
			total += float(m["value"])
	return total


## Sum of all "increased" modifiers, in percent (20 = 20% increased).
func increased(stat: String, tags: Array = []) -> float:
	var total := 0.0
	for m in mods:
		if _applies(m, stat, "increased", tags):
			total += float(m["value"])
	return total


## Product of all "more" modifiers as a multiplier (1.3 = 30% more).
func more(stat: String, tags: Array = []) -> float:
	var total := 1.0
	for m in mods:
		if _applies(m, stat, "more", tags):
			total *= 1.0 + float(m["value"]) / 100.0
	return total


## Only the multiplier part: (1 + increased) * more.
func multiplier(stat: String, tags: Array = []) -> float:
	return maxf(0.0, 1.0 + increased(stat, tags) / 100.0) * more(stat, tags)


func calc(stat: String, base: float = 0.0, tags: Array = []) -> float:
	return (base + flat(stat, tags)) * multiplier(stat, tags)
