class_name DB
extends RefCounted
## Game database. Loads skills, supports, item bases and affixes from the
## JSON files in res://data so the game's content can be edited without code.

const ELEMENTS: Array[String] = ["physical", "fire", "cold", "lightning"]
const ELEMENT_COLORS := {
	"physical": Color(0.92, 0.86, 0.74),
	"fire": Color(1.0, 0.42, 0.1),
	"cold": Color(0.45, 0.82, 1.0),
	"lightning": Color(1.0, 0.94, 0.35),
}
const SLOTS: Array[String] = ["helmet", "body", "boots", "ring", "amulet"]

static var skills: Dictionary = {}
static var supports: Dictionary = {}
static var bases: Dictionary = {}
static var affixes: Array = []
static var classes: Dictionary = {}
static var models: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	skills = _load_json("res://data/skills.json", {})
	supports = _load_json("res://data/supports.json", {})
	bases = _load_json("res://data/item_bases.json", {})
	affixes = _load_json("res://data/affixes.json", [])
	classes = _load_json("res://data/classes.json", {})
	models = _load_json("res://data/models.json", {})
	_loaded = true


static func _load_json(path: String, fallback: Variant) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read data file: " + path)
		return fallback
	var data: Variant = JSON.parse_string(text)
	if data == null or typeof(data) != typeof(fallback):
		push_error("Invalid JSON in data file: " + path)
		return fallback
	return data


static func skill(id: String) -> Dictionary:
	ensure_loaded()
	return skills.get(id, {})


static func player_class(id: String) -> Dictionary:
	ensure_loaded()
	return classes.get(id, {})


static func model(id: String) -> Dictionary:
	ensure_loaded()
	return models.get(id, {})


static func support(id: String) -> Dictionary:
	ensure_loaded()
	return supports.get(id, {})


## Skills a player can get from an uncut skill gem (monster skills excluded).
static func player_skill_ids() -> Array:
	ensure_loaded()
	var out := []
	for id in skills:
		if not skills[id].get("monster_only", false):
			out.append(id)
	return out


static func support_ids() -> Array:
	ensure_loaded()
	return supports.keys()


static func element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, Color.WHITE)
