class_name LootDrop
extends Node3D
## An item or uncut gem lying on the ground. Walk over it to pick it up.

const UNCUT_SKILL_COLOR := Color(0.35, 1.0, 0.55)
const UNCUT_SUPPORT_COLOR := Color(0.4, 0.75, 1.0)

var payload: Dictionary  ## {"type": "item", "item": Item} or {"type": "uncut", "kind": ..., "level": ...}
var label := ""
var color := Color.WHITE
var _t := 0.0
var _visual: Node3D


static func spawn(data: Dictionary, pos: Vector3) -> LootDrop:
	var d := LootDrop.new()
	d.payload = data
	if data["type"] == "item":
		var item: Item = data["item"]
		d.label = item.name
		d.color = item.color()
	else:
		var is_skill: bool = data["kind"] == "skill"
		d.label = "Uncut %s Gem (Lv %d)" % ["Skill" if is_skill else "Support", data["level"]]
		d.color = UNCUT_SKILL_COLOR if is_skill else UNCUT_SUPPORT_COLOR
	Game.world.add_child(d)
	var offset := Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
	d.global_position = Vector3(pos.x, 0, pos.z) + offset
	return d


## Called when a monster dies. Better monsters drop more and better loot.
static func roll_drops(pos: Vector3, monster_level: int, rarity: int) -> void:
	var mult: float = [1.0, 2.5, 6.0][rarity]
	if randf() < 0.14 * mult:
		var item_rarity := ItemGen.roll_rarity(0.1 * rarity)
		spawn({"type": "item", "item": ItemGen.roll_item(monster_level, item_rarity)}, pos)
	if rarity == 2:
		spawn({"type": "item", "item": ItemGen.roll_item(monster_level, Item.Rarity.RARE)}, pos)
	var gem_level := clampi(monster_level / 2 + 1 + randi_range(0, 1), 1, 20)
	if randf() < 0.035 * mult:
		spawn({"type": "uncut", "kind": "skill", "level": gem_level}, pos)
	if randf() < 0.05 * mult:
		spawn({"type": "uncut", "kind": "support", "level": gem_level}, pos)


func _ready() -> void:
	add_to_group("loot")
	_visual = MeshInstance3D.new()
	if payload["type"] == "item":
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45, 0.2, 0.3)
		_visual.mesh = bm
	else:
		var gem := SphereMesh.new()  # low-poly sphere looks like a cut gem
		gem.radius = 0.22
		gem.height = 0.44
		gem.radial_segments = 6
		gem.rings = 2
		_visual.mesh = gem
	_visual.material_override = Fx.glow_mat(color, 1.2)
	_visual.position.y = 0.35
	add_child(_visual)

	var is_special: bool = payload["type"] == "uncut" or (payload["type"] == "item" and payload["item"].rarity == Item.Rarity.RARE)
	if is_special:
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.12
		cyl.height = 4.0
		beam.mesh = cyl
		beam.position.y = 2.0
		beam.material_override = Fx.fade_mat(color, 0.35)
		add_child(beam)


func _process(delta: float) -> void:
	_t += delta
	if _visual:
		_visual.rotation.y += delta * 1.5
		_visual.position.y = 0.35 + sin(_t * 3.0) * 0.06


func try_pickup(player: Player) -> void:
	if is_queued_for_deletion():
		return
	if payload["type"] == "item":
		if not player.inv.add_item(payload["item"]):
			return  # bag full; leave it on the ground
	else:
		player.inv.add_uncut(payload["kind"], payload["level"])
	Game.message("Picked up: " + label, color)
	queue_free()
