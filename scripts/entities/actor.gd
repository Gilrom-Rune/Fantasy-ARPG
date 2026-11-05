class_name Actor
extends CharacterBody3D
## Base class for anything that fights: the player and monsters.
## Handles life/mana, taking hits, resistances, ailments and using skills.

signal died(actor: Actor)

const IGNITE_DURATION := 3.0
const CHILL_DURATION := 2.0
const CHILL_SLOW := 0.3
const SHOCK_DURATION := 4.0
const SHOCK_EFFECT := 0.2  ## shocked targets take 20% more damage

var team := 0
var level := 1
var stats := StatBlock.new()
var base_stats := {}

var max_life := 1.0
var life := 1.0
var max_mana := 0.0
var mana := 0.0
var life_regen := 0.0
var mana_regen := 0.0
var move_speed := 5.0
var armour := 0.0
var resists := {"fire": 0.0, "cold": 0.0, "lightning": 0.0}

var dead := false
var radius := 0.5
var bar_height := 2.2  ## where the health bar is drawn above the actor
var busy_time := 0.0  ## seconds until this actor can use another skill
var cooldowns := {}
var facing := Vector3.FORWARD

var ignite_dps := 0.0
var ignite_time := 0.0
var ignite_source: Actor = null
var chill_time := 0.0
var shock_time := 0.0

var body_mat: StandardMaterial3D
var base_glow := Color.BLACK
var _flash := 0.0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


## Final value of a stat after every modifier from gear, supports, etc.
func stat(stat_name: String, tags: Array = []) -> float:
	return stats.calc(stat_name, float(base_stats.get(stat_name, 0.0)), tags)


## Re-reads the cached stats. Call after changing `stats` or `base_stats`.
func recalc() -> void:
	max_life = maxf(1.0, stat("life"))
	max_mana = maxf(0.0, stat("mana"))
	life = minf(life, max_life)
	mana = minf(mana, max_mana)
	life_regen = stat("life_regen")
	mana_regen = stat("mana_regen")
	move_speed = stat("move_speed")
	armour = stat("armour")
	for el in resists:
		resists[el] = minf(75.0, stat(el + "_res"))


func action_speed() -> float:
	return 1.0 - CHILL_SLOW if chill_time > 0.0 else 1.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	_tick(delta)
	if dead:
		return
	_think(delta)
	global_position.y = 0.0


## Override in subclasses for AI / input.
func _think(_delta: float) -> void:
	pass


func _tick(delta: float) -> void:
	busy_time = maxf(0.0, busy_time - delta)
	for k in cooldowns:
		cooldowns[k] = maxf(0.0, cooldowns[k] - delta)
	life = minf(max_life, life + life_regen * delta)
	mana = minf(max_mana, mana + mana_regen * delta)
	if ignite_time > 0.0:
		ignite_time -= delta
		_apply_damage(ignite_dps * delta, ignite_source if is_instance_valid(ignite_source) else null)
		if ignite_time <= 0.0:
			ignite_dps = 0.0
	chill_time = maxf(0.0, chill_time - delta)
	shock_time = maxf(0.0, shock_time - delta)
	_flash = maxf(0.0, _flash - delta)
	_update_tint()


func _update_tint() -> void:
	if body_mat == null:
		return
	var glow := base_glow
	if ignite_time > 0.0:
		glow += Color(0.35, 0.1, 0.0) * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02))
	if chill_time > 0.0:
		glow += Color(0.03, 0.1, 0.22)
	if shock_time > 0.0:
		glow += Color(0.25, 0.22, 0.02) * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.05))
	if _flash > 0.0:
		glow = Color(0.8, 0.8, 0.8)
	body_mat.emission = glow


func take_hit(hit: Dictionary, source: Actor) -> void:
	if dead:
		return
	var total := 0.0
	var dmg: Dictionary = hit["damage"]
	for el in dmg:
		var v: float = dmg[el]
		if el == "physical":
			if armour > 0.0 and v > 0.0:
				v *= 1.0 - minf(0.9, armour / (armour + 10.0 * v))
		else:
			v *= 1.0 - resists.get(el, 0.0) / 100.0
		total += v
	if shock_time > 0.0:
		total *= 1.0 + SHOCK_EFFECT

	# Ailments
	if dmg.has("fire") and randf() * 100.0 < hit["ignite_chance"]:
		var dps: float = dmg["fire"] * 0.5 * hit["ailment_mult"] * (1.0 - resists["fire"] / 100.0)
		if dps >= ignite_dps or ignite_time < 0.5:
			ignite_dps = dps
			ignite_time = IGNITE_DURATION
			ignite_source = source
	if hit["chill"]:
		chill_time = CHILL_DURATION
	if dmg.has("lightning") and randf() * 100.0 < hit["shock_chance"]:
		shock_time = SHOCK_DURATION

	var crit: bool = hit["crit"]
	var col := Color(1.0, 0.35, 0.3)
	if team != 0:
		col = Color(1.0, 0.85, 0.2) if crit else Color(0.95, 0.95, 0.95)
	Game.float_text(global_position + Vector3(0, 2.0, 0), str(roundi(total)) + ("!" if crit else ""), col, 26 if crit else 18)
	_flash = 0.08
	_apply_damage(total, source)


func _apply_damage(amount: float, source: Actor) -> void:
	if dead or amount <= 0.0:
		return
	life -= amount
	if life <= 0.0:
		life = 0.0
		dead = true
		died.emit(self)
		_on_death(source)


func _on_death(_source: Actor) -> void:
	pass


func face(dir: Vector3) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	facing = dir.normalized()
	rotation.y = atan2(-facing.x, -facing.z)


## Tries to use a compiled skill. Returns true if it was used.
func use_skill(c: Dictionary, target_point: Vector3, key: String) -> bool:
	if dead or busy_time > 0.0:
		return false
	if cooldowns.get(key, 0.0) > 0.0:
		return false
	if mana < c["mana_cost"]:
		return false
	mana -= c["mana_cost"]
	busy_time = c["use_time"] / action_speed()
	if c["cooldown"] > 0.0:
		cooldowns[key] = c["cooldown"]
	face(target_point - global_position)
	SkillExecutor.execute(self, c, target_point)
	for i in range(1, c["repeats"] + 1):
		get_tree().create_timer(0.18 * i, false).timeout.connect(func():
			if is_instance_valid(self) and not dead:
				SkillExecutor.execute(self, c, target_point))
	return true


## Creates the collision shape and a simple capsule body with a "nose" showing
## which way the actor faces. Swap this for real models later.
func build_body(color: Color, height: float, r: float) -> void:
	radius = r
	bar_height = height + 0.35
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = height
	col.shape = cap
	col.position.y = height * 0.5
	add_child(col)

	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = height
	mi.mesh = cm
	mi.position.y = height * 0.5
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = color
	body_mat.roughness = 0.65
	body_mat.emission_enabled = true
	body_mat.emission = Color.BLACK
	mi.material_override = body_mat
	add_child(mi)

	var nose := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(r * 0.7, r * 0.35, r * 0.7)
	nose.mesh = bm
	nose.position = Vector3(0, height * 0.72, -r * 0.85)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = color.lightened(0.45)
	nose.material_override = nose_mat
	add_child(nose)
