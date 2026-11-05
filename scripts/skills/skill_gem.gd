class_name SkillGem
extends RefCounted
## A cut skill gem: one active skill plus the support gems socketed into it.

var skill_id: String = ""
var level: int = 1
var supports: Array = []  ## support ids


func _init(id: String = "", lvl: int = 1) -> void:
	skill_id = id
	level = lvl


func data() -> Dictionary:
	return DB.skill(skill_id)


func display_name() -> String:
	return "%s (Lv %d)" % [data().get("name", skill_id), level]


func tags() -> Array:
	return data().get("tags", [])


## Higher level gems have more support sockets: Lv1-2: 2, Lv3-5: 3, Lv6-8: 4, Lv9+: 5
func max_supports() -> int:
	return clampi(2 + level / 3, 2, 5)


## Returns "" if the support can be socketed, otherwise the reason it cannot.
func can_socket(support_id: String) -> String:
	var sup := DB.support(support_id)
	if sup.is_empty():
		return "Unknown support"
	if supports.has(support_id):
		return "Already socketed"
	if supports.size() >= max_supports():
		return "No free sockets"
	if not support_fits(tags(), sup):
		return "Needs a %s skill" % " or ".join(sup.get("requires", []))
	return ""


static func support_fits(skill_tags: Array, sup: Dictionary) -> bool:
	var req: Array = sup.get("requires", [])
	if req.is_empty():
		return true
	for t in req:
		if skill_tags.has(t):
			return true
	return false
