class_name SkillExecutor
extends RefCounted
## Performs a compiled skill in the world. Each "behavior" is a different way
## of delivering hits: projectiles, novas, melee sweeps, delayed ground blasts.


static func execute(caster: Actor, c: Dictionary, target_point: Vector3) -> void:
	if Game.world == null:
		return
	var origin := caster.global_position
	var to := target_point - origin
	to.y = 0
	var dir := to.normalized() if to.length() > 0.05 else caster.facing
	match c["behavior"]:
		"projectile":
			var n: int = c["projectiles"]
			var spread := deg_to_rad(c["spread"])
			for i in n:
				var offset := (i - (n - 1) / 2.0) * spread
				var d := dir.rotated(Vector3.UP, offset)
				Projectile.spawn(caster, c, origin + Vector3(0, 1.0, 0) + d * (caster.radius + 0.3), d)
		"nova":
			Fx.burst(origin, c["radius"], c["color"], 0.4)
			hit_circle(caster.team, caster, c, origin, c["radius"])
		"melee_arc":
			Fx.sector(origin, dir, c["range"], c["arc"], c["color"])
			hit_cone(caster, c, origin, dir, c["range"], c["arc"])
		"ground_aoe":
			var point := origin + dir * minf(to.length(), c["range"])
			var marker := Fx.telegraph(point, c["radius"], c["color"], c["delay"])
			var team := caster.team
			var timer := Game.tree().create_timer(c["delay"], false)
			timer.timeout.connect(func():
				if is_instance_valid(marker):
					marker.queue_free()
				Fx.burst(point, c["radius"], c["color"], 0.45)
				hit_circle(team, caster if is_instance_valid(caster) else null, c, point, c["radius"]))
		_:
			push_warning("Unknown skill behavior: %s" % c["behavior"])


## Hits every enemy of `team` inside the circle. Returns how many were hit.
static func hit_circle(team: int, source: Actor, c: Dictionary, center: Vector3, radius: float, exclude: Dictionary = {}) -> int:
	var count := 0
	for t in Game.targets_for(team):
		if t.dead or exclude.has(t.get_instance_id()):
			continue
		if Game.flat_distance(t.global_position, center) <= radius + t.radius:
			t.take_hit(SkillCompiler.roll_hit(c), source)
			count += 1
	return count


static func hit_cone(caster: Actor, c: Dictionary, origin: Vector3, dir: Vector3, reach: float, arc_deg: float) -> int:
	var count := 0
	var half := deg_to_rad(arc_deg) * 0.5
	for t in Game.targets_for(caster.team):
		if t.dead:
			continue
		var to: Vector3 = t.global_position - origin
		to.y = 0
		var d := to.length()
		if d > reach + t.radius:
			continue
		if d > t.radius and dir.angle_to(to / d) > half:
			continue
		t.take_hit(SkillCompiler.roll_hit(c), caster)
		count += 1
	return count
