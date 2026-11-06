class_name Enemy
extends Actor
## A monster. Uses the same skill system as the player (see skills.json).

const KINDS := {
	"brute": {
		"name": "Ghoul", "life": 30.0, "skill": "monster_slam", "speed": 3.4,
		"attack_range": 1.8, "windup": 0.45, "color": Color(0.5, 0.4, 0.3),
		"height": 1.7, "radius": 0.5, "xp": 6.0,
	},
	"caster": {
		"name": "Hexer", "life": 18.0, "skill": "monster_bolt", "speed": 3.0,
		"attack_range": 12.0, "keep_away": 5.0, "windup": 0.5, "color": Color(0.42, 0.28, 0.58),
		"height": 1.5, "radius": 0.4, "xp": 7.0,
	},
}
const RARITY_LIFE := [1.0, 2.4, 5.5]
const RARITY_DAMAGE := [1.0, 1.25, 1.6]
const RARITY_SIZE := [1.0, 1.15, 1.4]
const RARITY_XP := [1.0, 2.5, 6.0]
const RARE_PREFIX := ["Gutripper", "Blightmaw", "Ashen", "Hollowborn", "Grimwail", "Duskfang"]
const MAGIC_PREFIX := ["Frenzied", "Hulking", "Feral", "Vile"]

var kind := "brute"
var info: Dictionary
var rarity := 0
var display_name := ""
var compiled: Dictionary
var windup := 0.0
var windup_target := Vector3.ZERO
var aggro := false


## Call before adding to the scene tree.
func setup(kind_id: String, lvl: int, rar: int) -> void:
	kind = kind_id
	info = KINDS[kind]
	level = lvl
	rarity = rar
	team = 1


func _ready() -> void:
	super._ready()
	add_to_group("team_1")
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var s: float = RARITY_SIZE[rarity]
	build_body(info["color"], info["height"] * s, info["radius"] * s)
	base_stats = {
		"life": info["life"] * pow(1.15, level - 1) * RARITY_LIFE[rarity],
		"move_speed": info["speed"] * (1.0 + 0.06 * rarity),
		"fire_res": minf(level * 1.5, 30.0),
		"cold_res": minf(level * 1.5, 30.0),
		"lightning_res": minf(level * 1.5, 30.0),
	}
	stats.add("damage", "more", (pow(1.12, level - 1) * RARITY_DAMAGE[rarity] - 1.0) * 100.0)
	if rarity == 2:
		stats.add("attack_speed", "increased", 25)
		stats.add("cast_speed", "increased", 25)
	recalc()
	life = max_life
	compiled = SkillCompiler.compile(SkillGem.new(info["skill"], 1), stats)
	match rarity:
		0:
			display_name = info["name"]
		1:
			display_name = "%s %s" % [MAGIC_PREFIX.pick_random(), info["name"]]
			base_glow = Color(0.05, 0.12, 0.45)
		2:
			display_name = "%s, %s" % [RARE_PREFIX.pick_random(), info["name"]]
			base_glow = Color(0.45, 0.35, 0.05)


func name_color() -> Color:
	return [Color.WHITE, Color(0.5, 0.6, 1.0), Color(1.0, 0.88, 0.35)][rarity]


func _think(delta: float) -> void:
	var p := Game.player
	if p == null or p.dead:
		windup = 0.0
		return
	var to := p.global_position - global_position
	to.y = 0
	var dist := to.length()
	if not aggro:
		if dist < 22.0:
			aggro = true
		else:
			return

	if windup > 0.0:
		windup -= delta * action_speed()
		if body_mat:
			body_mat.emission += Color(0.6, 0.1, 0.05)
		if windup <= 0.0:
			face(windup_target - global_position)
			SkillExecutor.execute(self, compiled, windup_target)
			busy_time = compiled["use_time"] / action_speed()
		return
	if busy_time > 0.0:
		return

	var dir := to / maxf(dist, 0.001)
	var keep_away: float = info.get("keep_away", 0.0)
	if keep_away > 0.0 and dist < keep_away:
		_move(-dir, delta)
		face(dir)
	elif dist <= info["attack_range"] + p.radius:
		face(dir)
		windup = info["windup"]
		windup_target = p.global_position
	else:
		_move(dir, delta)
		face(dir)


## Walks in a direction, but never into the safe camp: at the edge the
## monster slides around it instead.
func _move(dir: Vector3, delta: float) -> void:
	var v := dir * move_speed * action_speed()
	if Game.in_camp(global_position + v * delta, radius):
		var out := global_position - Game.CAMP_CENTER
		out.y = 0
		var tangent := out.normalized().cross(Vector3.UP)
		v = tangent * v.dot(tangent)
		if Game.in_camp(global_position + v * delta, radius):
			v = Vector3.ZERO
	velocity = v
	move_and_slide()


func take_hit(hit: Dictionary, source: Actor) -> void:
	aggro = true
	super.take_hit(hit, source)


func _on_death(_source: Actor) -> void:
	remove_from_group("team_1")
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	Game.kills += 1
	if Game.player and not Game.player.dead:
		Game.player.gain_xp(info["xp"] * level * RARITY_XP[rarity])
	LootDrop.roll_drops(global_position, level, rarity)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.05, 1.3), 0.25)
	tw.tween_callback(queue_free)
