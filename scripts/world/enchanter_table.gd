class_name EnchanterTable
extends StaticBody3D
## The Enchanter's Table in the camp. Walk up and press F to set the gems in
## your weapon's slots and link them with Soul Chains.

var label := "Enchanter's Table  [F]"
var label_color := Color(0.65, 0.85, 1.0)
var _crystal: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.0, 1.2)
	shape.shape = box
	shape.position.y = 0.5
	add_child(shape)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.22, 0.13)
	wood.roughness = 0.8
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(2.4, 0.15, 1.2)
	top.mesh = tm
	top.position.y = 0.95
	top.material_override = wood
	add_child(top)
	for x in [-1.0, 1.0]:
		for z in [-0.45, 0.45]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.15, 0.9, 0.15)
			leg.mesh = lm
			leg.position = Vector3(x, 0.45, z)
			leg.material_override = wood
			add_child(leg)
	# Glowing rune cloth on top
	var cloth := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.6, 0.02, 0.8)
	cloth.mesh = cm
	cloth.position.y = 1.04
	cloth.material_override = Fx.glow_mat(Color(0.25, 0.4, 0.9), 0.8)
	add_child(cloth)
	# Floating soul crystal
	_crystal = MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = 0.22
	gem.height = 0.6
	gem.radial_segments = 6
	gem.rings = 2
	_crystal.mesh = gem
	_crystal.material_override = Fx.glow_mat(Color(0.55, 0.85, 1.0), 3.0)
	add_child(_crystal)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.75, 1.0)
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position.y = 1.8
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	_crystal.position.y = 1.55 + sin(_t * 2.0) * 0.08
	_crystal.rotation.y += delta


func can_interact() -> bool:
	return true


func interact(_player: Player) -> void:
	if Game.hud:
		Game.hud.open_enchanter()
