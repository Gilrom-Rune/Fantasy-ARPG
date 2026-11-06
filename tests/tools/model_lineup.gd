extends SceneTree
## Renders modular Quaternius characters side by side to a PNG, for checking
## outfits. Only the HEAD of the base body is kept; the outfit pieces form the
## rest of the body (see head_only). Was:
## how outfits look. Run with a display (xvfb-run) and:
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
	var base: Node3D = (load(Q + parts[0] + ".gltf") as PackedScene).instantiate()
	var skel: Skeleton3D = base.find_child("*", true, false) as Skeleton3D
	skel = base.find_children("*", "Skeleton3D", true, false)[0]
	if parts.size() > 1:
		# Keep only the head of the base body; the outfit pieces are the body.
		for mi in skel.get_children():
			if mi is MeshInstance3D and String(mi.name).to_lower().begins_with("superhero"):
				mi.mesh = head_only(mi.mesh, mi.skin)
	for i in range(1, parts.size()):
		var piece: Node = (load(Q + parts[i] + ".gltf") as PackedScene).instantiate()
		for mi in piece.find_children("*", "MeshInstance3D", true, false):
			mi.owner = null
			mi.get_parent().remove_child(mi)
			skel.add_child(mi)
			mi.skeleton = NodePath("..")
		piece.free()
	return base


## Returns a copy of a skinned mesh with only the triangles that move with the
## head or neck bones (everything below the neck is removed).
static func head_only(mesh: Mesh, skin: Skin) -> ArrayMesh:
	var keep_bones := {}
	for i in skin.get_bind_count():
		if String(skin.get_bind_name(i)) in ["Head", "neck_01"]:
			keep_bones[i] = true
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var per := bones.size() / verts.size()  # 4 or 8 bone influences per vertex
		var head_vert := PackedByteArray()
		head_vert.resize(verts.size())
		for v in verts.size():
			var best := 0
			for k in range(1, per):
				if weights[v * per + k] > weights[v * per + best]:
					best = k
			head_vert[v] = 1 if keep_bones.has(bones[v * per + best]) else 0
		var idx := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			idx = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():  # some meshes list triangles directly, without an index
			for v in verts.size():
				idx.append(v)
		var new_idx := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if head_vert[idx[t]] and head_vert[idx[t + 1]] and head_vert[idx[t + 2]]:
				new_idx.append(idx[t])
				new_idx.append(idx[t + 1])
				new_idx.append(idx[t + 2])
		if new_idx.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = new_idx
		for ch in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[ch] = null  # extra data channels the game doesn't use
		var flags: int = mesh.surface_get_format(s)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(s))
	return out
