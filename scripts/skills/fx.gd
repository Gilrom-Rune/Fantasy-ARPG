class_name Fx
extends RefCounted
## Simple procedural visual effects (no art assets needed yet).


static func glow_mat(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func fade_mat(color: Color, alpha: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color, alpha)
	m.no_depth_test = false
	return m


static func _add(node: Node3D, pos: Vector3) -> bool:
	if Game.world == null:
		node.free()
		return false
	Game.world.add_child(node)
	node.global_position = pos
	return true


## Expanding ring + flash disc, used for explosions and novas.
static func burst(pos: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	var root := Node3D.new()
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.04
	disc.mesh = cyl
	var disc_mat := fade_mat(color, 0.45)
	disc.material_override = disc_mat
	root.add_child(disc)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.0
	ring.mesh = torus
	var ring_mat := fade_mat(color.lightened(0.3), 0.9)
	ring.material_override = ring_mat
	root.add_child(ring)

	if not _add(root, pos + Vector3(0, 0.08, 0)):
		return
	disc.scale = Vector3.ONE * radius * 0.3
	ring.scale = Vector3(radius * 0.3, 1.0, radius * 0.3)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(disc, "scale", Vector3(radius, 1.0, radius), duration * 0.5)
	tw.tween_property(ring, "scale", Vector3(radius, 1.0, radius), duration * 0.6)
	tw.tween_property(disc_mat, "albedo_color:a", 0.0, duration)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(root.queue_free)


## Flat pie-slice shaped flash for melee swings and cones.
static func sector(pos: Vector3, dir: Vector3, radius: float, arc_deg: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = sector_mesh(radius, arc_deg)
	var mat := fade_mat(color, 0.55)
	mi.material_override = mat
	if not _add(mi, pos + Vector3(0, 0.15, 0)):
		return
	mi.look_at(mi.global_position + dir, Vector3.UP)
	mi.scale = Vector3(0.6, 1, 0.6)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.12)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(mi.queue_free)


## A warning circle on the ground that fills up until the blast lands.
static func telegraph(pos: Vector3, radius: float, color: Color, duration: float) -> Node3D:
	var root := Node3D.new()
	var outline := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.94
	torus.outer_radius = radius
	outline.mesh = torus
	outline.material_override = fade_mat(color, 0.8)
	root.add_child(outline)
	var fill := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	fill.mesh = cyl
	fill.material_override = fade_mat(color, 0.25)
	fill.scale = Vector3(0.05, 1, 0.05)
	root.add_child(fill)
	if _add(root, pos + Vector3(0, 0.06, 0)):
		root.create_tween().tween_property(fill, "scale", Vector3.ONE, duration)
	return root


static func sector_mesh(radius: float, arc_deg: float, segments: int = 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(arc_deg) * 0.5
	for i in segments:
		var a0 := -half + 2.0 * half * i / segments
		var a1 := -half + 2.0 * half * (i + 1) / segments
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0), 0, -cos(a0)) * radius)
		st.add_vertex(Vector3(sin(a1), 0, -cos(a1)) * radius)
	return st.commit()
