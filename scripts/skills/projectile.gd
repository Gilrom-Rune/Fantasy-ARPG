class_name Projectile
extends Node3D
## A flying projectile. Handles walls, piercing, chaining and explosions.

var caster: Actor
var team := 0
var c: Dictionary
var dir := Vector3.FORWARD
var speed := 15.0
var max_dist := 15.0
var travelled := 0.0
var pierce_left := 0
var chains_left := 0
var hit_ids := {}


static func spawn(from: Actor, compiled: Dictionary, origin: Vector3, direction: Vector3) -> Projectile:
	var p := Projectile.new()
	p.caster = from
	p.team = from.team
	p.c = compiled
	p.dir = direction.normalized()
	p.speed = compiled["projectile_speed"]
	p.max_dist = compiled["range"]
	p.pierce_left = compiled["pierce"]
	p.chains_left = compiled["chains"]

	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = Fx.glow_mat(compiled["color"], 4.0)
	p.add_child(mi)

	# A stretched, faded tail so it reads as moving fast.
	var tail := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.13
	tm.height = 0.26
	tail.mesh = tm
	tail.scale = Vector3(1, 1, 4)
	tail.position = Vector3(0, 0, 0.45)
	tail.material_override = Fx.fade_mat(compiled["color"], 0.45)
	p.add_child(tail)

	Game.world.add_child(p)
	p.global_position = origin
	p._orient()
	return p


func _orient() -> void:
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP)


func _src() -> Actor:
	return caster if is_instance_valid(caster) else null


func _physics_process(delta: float) -> void:
	var step := dir * speed * delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1)
	var wall := space.intersect_ray(query)
	if not wall.is_empty():
		_end(wall["position"])
		return
	global_position += step
	travelled += step.length()
	if travelled >= max_dist:
		_end(global_position)
		return
	for t in Game.targets_for(team):
		if t.dead or hit_ids.has(t.get_instance_id()):
			continue
		if Game.flat_distance(t.global_position, global_position) <= t.radius + 0.3:
			_hit(t)
			return


func _hit(target: Actor) -> void:
	hit_ids[target.get_instance_id()] = true
	target.take_hit(SkillCompiler.roll_hit(c), _src())
	if c["explode_radius"] > 0.0:
		SkillExecutor.hit_circle(team, _src(), c, global_position, c["explode_radius"], hit_ids)
		Fx.burst(Vector3(global_position.x, 0, global_position.z), c["explode_radius"], c["color"])
	if chains_left > 0:
		var next := _find_chain_target()
		if next:
			chains_left -= 1
			dir = next.global_position + Vector3(0, 1, 0) - global_position
			dir.y = 0
			dir = dir.normalized()
			travelled = 0.0
			_orient()
			return
	if pierce_left > 0:
		pierce_left -= 1
		return
	queue_free()


func _find_chain_target() -> Actor:
	var best: Actor = null
	var best_d := 12.0
	for t in Game.targets_for(team):
		if t.dead or hit_ids.has(t.get_instance_id()):
			continue
		var d := Game.flat_distance(t.global_position, global_position)
		if d < best_d:
			best_d = d
			best = t
	return best


func _end(pos: Vector3) -> void:
	if c["explode_radius"] > 0.0:
		SkillExecutor.hit_circle(team, _src(), c, pos, c["explode_radius"], hit_ids)
		Fx.burst(Vector3(pos.x, 0, pos.z), c["explode_radius"], c["color"])
	queue_free()
