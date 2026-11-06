class_name Chest
extends StaticBody3D
## A treasure chest. Press F next to it to open it. Chests are a good source
## of uncut gems.

var label := "Chest  [F]"
var label_color := Color(1.0, 0.8, 0.4)
var opened := false
var level := 1
var _lid: Node3D


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("chests")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.8, 0.8)
	shape.shape = box
	shape.position.y = 0.4
	add_child(shape)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.28, 0.12)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.9, 0.7, 0.25)
	gold.metallic = 0.8
	gold.roughness = 0.35
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.55, 0.8)
	body.mesh = bm
	body.position.y = 0.275
	body.material_override = wood
	add_child(body)
	var band := MeshInstance3D.new()
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(1.24, 0.1, 0.84)
	band.mesh = band_mesh
	band.position.y = 0.45
	band.material_override = gold
	add_child(band)
	# The lid pivots on its back edge.
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.55, -0.4)
	add_child(_lid)
	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.2, 0.25, 0.8)
	lid.mesh = lm
	lid.position = Vector3(0, 0.125, 0.4)
	lid.material_override = wood
	_lid.add_child(lid)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.3)
	glow.light_energy = 0.8
	glow.omni_range = 3.0
	glow.position.y = 1.0
	add_child(glow)


func can_interact() -> bool:
	return not opened


func interact(_player: Player) -> void:
	if opened:
		return
	opened = true
	remove_from_group("interactables")
	var tw := create_tween()
	tw.tween_property(_lid, "rotation_degrees:x", -110.0, 0.35)
	tw.tween_interval(20.0)
	tw.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.5)
	tw.tween_callback(queue_free)
	Game.message("Opened a chest!", label_color)
	var pos := global_position + Vector3(0, 0, 1.2)
	var gem_level := clampi(level / 2 + 1 + randi_range(0, 2), 1, 20)
	# Chests always give at least one uncut gem.
	LootDrop.spawn({"type": "uncut", "kind": "skill" if randf() < 0.45 else "support", "level": gem_level}, pos)
	if randf() < 0.6:
		LootDrop.spawn({"type": "uncut", "kind": "support", "level": gem_level}, pos)
	if randf() < 0.3:
		LootDrop.spawn({"type": "uncut", "kind": "skill", "level": gem_level}, pos)
	for i in randi_range(1, 2):
		LootDrop.spawn({"type": "item", "item": ItemGen.roll_item(level, ItemGen.roll_rarity(0.15))}, pos)
