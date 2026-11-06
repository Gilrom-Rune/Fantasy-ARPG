class_name ModularBody
extends RefCounted
## Builds a Quaternius modular character: the outfit pieces (body, arms,
## legs, feet, hood...) all share one skeleton, so their meshes are moved onto
## the skeleton of the base body. Only the HEAD of the base body is kept,
## because the outfit pieces already form the rest of the body.

static var _head_cache := {}  ## base file -> ArrayMesh (head only)


## base_path: the base body .gltf (gives the skeleton, head, eyes, eyebrows).
## part_paths: outfit piece .gltf files.
static func assemble(base_path: String, part_paths: Array) -> Node3D:
	var base: Node3D = CharacterModel.load_scene(base_path).instantiate()
	var skel: Skeleton3D = base.find_children("*", "Skeleton3D", true, false)[0]
	if not part_paths.is_empty():
		for mi in skel.get_children():
			if mi is MeshInstance3D and String(mi.name).to_lower().begins_with("superhero"):
				if not _head_cache.has(base_path):
					_head_cache[base_path] = head_only(mi.mesh, mi.skin)
				mi.mesh = _head_cache[base_path]
	for path in part_paths:
		var piece: Node = CharacterModel.load_scene(path).instantiate()
		for mi in piece.find_children("*", "MeshInstance3D", true, false):
			mi.owner = null
			mi.get_parent().remove_child(mi)
			skel.add_child(mi)
			mi.skeleton = NodePath("..")
		piece.free()
	return base


## A copy of a skinned mesh keeping only the triangles that move with the
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
		var per := bones.size() / verts.size()  # bone influences per vertex
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
