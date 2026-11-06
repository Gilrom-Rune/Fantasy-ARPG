extends SceneTree
## Renders modular Quaternius characters side by side to a PNG, for checking
## outfits. Only the HEAD of the base body is kept; the outfit pieces form the
## rest of the body (see ModularBody). Run with a display (xvfb-run) and:
##   godot --path . --script res://tests/tools/model_lineup.gd -- --out=/path/lineup.png

const Q := "res://assets/quaternius/"
const SETS := [
	["Superhero_Male_FullBody", "Male_Ranger_Body", "Male_Ranger_Arms", "Male_Ranger_Legs", "Male_Ranger_Feet_Boots", "Male_Ranger_Head_Hood", "Male_Ranger_Acc_Pauldron"],
	["Superhero_Female_FullBody", "Female_Ranger_Body", "Female_Ranger_Arms", "Female_Ranger_Legs", "Female_Ranger_Feet", "Female_Ranger_Head_Hood", "Female_Ranger_Acc_Pauldrons"],
	["Superhero_Male_FullBody", "Male_Peasant_Body", "Male_Peasant_Arms", "Male_Peasant_Legs", "Male_Peasant_Feet"],
	["Superhero_Female_FullBody", "Female_Peasant_Body", "Female_Peasant_Arms", "Female_Peasant_Legs", "Female_Peasant_Feet"],
]


func _initialize() -> void:
	var out := "/tmp/lineup.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.11, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.4
	root.add_child(sun)

	var x := -4.0
	for parts in SETS:
		var ch := _assemble(parts)
		root.add_child(ch)
		ch.position = Vector3(x, 0, 0)
		var aabb := AABB()
		for m in ch.find_children("*", "MeshInstance3D", true, false):
			aabb = aabb.merge(m.get_aabb())
		print(parts[1] if parts.size() > 1 else parts[0], " size: ", aabb.size)
		x += 2.0
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.position = Vector3(-1.0, 1.1, 6.5)
	cam.look_at(Vector3(0, 0.95, 0))
	for i in 20:
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


func _assemble(parts: Array) -> Node3D:
	var paths: Array = parts.map(func(n): return Q + n + ".gltf")
	return ModularBody.assemble(paths[0], paths.slice(1))
