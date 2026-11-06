class_name SkillGem
extends RefCounted
## A cut active skill gem. Higher levels hit harder.
## Its passives come from the weapon slot it sits in (see weapon.gd).

var skill_id: String = ""
var level: int = 1


func _init(id: String = "", lvl: int = 1) -> void:
	skill_id = id
	level = lvl


func data() -> Dictionary:
	return DB.skill(skill_id)


func display_name() -> String:
	return "%s (Lv %d)" % [data().get("name", skill_id), level]


func tags() -> Array:
	return data().get("tags", [])


## Can this passive gem modify this skill?
func fits(passive_id: String) -> bool:
	return support_fits(tags(), DB.support(passive_id))


static func support_fits(skill_tags: Array, sup: Dictionary) -> bool:
	if sup.is_empty():
		return false
	var req: Array = sup.get("requires", [])
	if req.is_empty():
		return true
	for t in req:
		if skill_tags.has(t):
			return true
	return false


static func requirement_text(passive_id: String) -> String:
	var req: Array = DB.support(passive_id).get("requires", [])
	return "any skill" if req.is_empty() else " or ".join(req) + " skills"
