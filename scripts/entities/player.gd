class_name Player
extends Actor
## The player character: WASD to move, skills aim at the mouse cursor.

signal stats_changed

const SLOT_KEYS := ["LMB", "RMB", "Q", "E"]
const PICKUP_RANGE := 1.5

var inv := Inventory.new()
var xp := 0.0
var compiled: Array = [null, null, null, null]
var aim_point := Vector3.ZERO
var camera: Camera3D
var _mana_warn_cooldown := 0.0
var _bot_slot := 0


func _ready() -> void:
	super._ready()
	team = 0
	add_to_group("team_0")
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	build_body(Color(0.32, 0.48, 0.85), 1.8, 0.45)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.75
	ring.mesh = torus
	ring.scale = Vector3(1, 0.1, 1)
	ring.position.y = 0.03
	ring.material_override = Fx.glow_mat(Color(1.0, 0.8, 0.3), 1.5)
	add_child(ring)
	inv.changed.connect(rebuild)
	_give_starting_kit()
	rebuild()
	life = max_life
	mana = max_mana


func _give_starting_kit() -> void:
	inv.equipment["weapon"] = ItemGen.roll_item(1, Item.Rarity.NORMAL, "rusted_sword")
	inv.skill_slots[0] = SkillGem.new("fireball", 1)
	inv.skill_slots[1] = SkillGem.new("cleave", 1)
	inv.uncut.append({"kind": "skill", "level": 1})
	inv.uncut.append({"kind": "support", "level": 1})


func xp_to_next() -> float:
	return 40.0 * pow(1.35, level - 1)


## Rebuilds all stats from level + equipment, then recompiles every skill.
func rebuild() -> void:
	stats = StatBlock.new()
	base_stats = {
		"life": 50.0 + 10.0 * level,
		"mana": 40.0 + 5.0 * level,
		"mana_regen": 3.0 + 0.25 * level,
		"move_speed": 6.0,
	}
	for slot in inv.equipment:
		var item: Item = inv.equipment[slot]
		if item:
			stats.add_all(item.all_mods(), item.name)
	recalc()
	for i in Inventory.SKILL_SLOTS:
		var gem: SkillGem = inv.skill_slots[i]
		compiled[i] = SkillCompiler.compile(gem, stats) if gem else null
	stats_changed.emit()


func gain_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		rebuild()
		life = max_life
		mana = max_mana
		Game.message("Level up! You are now level %d." % level, Color(1.0, 0.9, 0.4))
		Game.float_text(global_position + Vector3(0, 2.6, 0), "LEVEL UP", Color(1.0, 0.9, 0.4), 30)


func _think(delta: float) -> void:
	_mana_warn_cooldown -= delta
	var move := Vector3.ZERO
	var wanted_slot := -1
	if Game.autoplay:
		var bot := _bot_inputs()
		move = bot[0]
		wanted_slot = bot[1]
	else:
		aim_point = _mouse_ground_point()
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move = _camera_relative(input)
		for i in Inventory.SKILL_SLOTS:
			if Input.is_action_pressed("skill_%d" % (i + 1)):
				wanted_slot = i
				break

	var speed := move_speed * action_speed() * (0.4 if busy_time > 0.0 else 1.0)
	velocity = move * speed
	move_and_slide()
	if move.length() > 0.1 and busy_time <= 0.0:
		face(move)
	if wanted_slot >= 0:
		try_use_slot(wanted_slot)
	_pickup_nearby()


func try_use_slot(i: int) -> bool:
	var c = compiled[i]
	if c == null:
		return false
	if mana < c["mana_cost"] and busy_time <= 0.0:
		if _mana_warn_cooldown <= 0.0:
			Game.float_text(global_position + Vector3(0, 2.4, 0), "Not enough mana", Color(0.5, 0.7, 1.0), 16)
			_mana_warn_cooldown = 1.0
		return false
	return use_skill(c, aim_point, "slot%d" % i)


func _camera_relative(input: Vector2) -> Vector3:
	if camera == null:
		return Vector3(input.x, 0, input.y)
	var fwd := -camera.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var v := right * input.x - fwd * input.y
	return v.normalized() * minf(1.0, input.length()) if v.length() > 0.01 else Vector3.ZERO


func _mouse_ground_point() -> Vector3:
	if camera == null:
		return global_position + facing
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	return hit if hit != null else global_position + facing


func _pickup_nearby() -> void:
	for drop in get_tree().get_nodes_in_group("loot"):
		if Game.flat_distance(drop.global_position, global_position) <= PICKUP_RANGE:
			drop.try_pickup(self)


func _on_death(_source: Actor) -> void:
	velocity = Vector3.ZERO
	Game.message("You have died.", Color(1, 0.3, 0.3))
	if Game.hud:
		Game.hud.show_death()


func respawn() -> void:
	dead = false
	ignite_time = 0.0
	ignite_dps = 0.0
	chill_time = 0.0
	shock_time = 0.0
	busy_time = 0.0
	cooldowns.clear()
	life = max_life
	mana = max_mana
	global_position = Vector3.ZERO


# ---------------------------------------------------------------------------
# Bot used by automated tests (run with: -- --autoplay). Not used in normal play.
# ---------------------------------------------------------------------------
func _bot_inputs() -> Array:
	var nearest: Node3D = null
	var best := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := Game.flat_distance(e.global_position, global_position)
		if d < best:
			best = d
			nearest = e
	var move := Vector3.ZERO
	var slot := -1
	# Walk to loot when nothing is close.
	if nearest == null or best > 14.0:
		for drop in get_tree().get_nodes_in_group("loot"):
			move = drop.global_position - global_position
			move.y = 0
			return [move.normalized(), -1]
	if nearest:
		aim_point = nearest.global_position
		var to := nearest.global_position - global_position
		to.y = 0
		if best < 3.0:
			move = -to.normalized()
		elif best > 9.0:
			move = to.normalized()
		else:
			move = to.normalized().rotated(Vector3.UP, PI / 2)
		if busy_time <= 0.0:
			for k in Inventory.SKILL_SLOTS:
				_bot_slot = (_bot_slot + 1) % Inventory.SKILL_SLOTS
				if compiled[_bot_slot] != null:
					slot = _bot_slot
					break
	if global_position.length() > 30.0:
		move = -global_position.normalized()
	return [move, slot]
