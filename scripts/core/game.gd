class_name Game
extends RefCounted
## Global references and helpers shared by the whole game.

static var player: Player
static var world: Node3D      ## Projectiles, effects, enemies and loot are added here.
static var hud: Hud
static var area_level := 1
static var kills := 0
static var autoplay := false  ## Bot mode used for automated testing (--autoplay).

const CAMP_CENTER := Vector3.ZERO
const CAMP_RADIUS := 7.0  ## Monsters can't enter the camp.


static func reset() -> void:
	player = null
	world = null
	hud = null
	area_level = 1
	kills = 0


static func float_text(pos: Vector3, text: String, color: Color, size: int = 18) -> void:
	if hud:
		hud.add_float_text(pos, text, color, size)


static func message(text: String, color: Color = Color.WHITE) -> void:
	if hud:
		hud.add_message(text, color)
	else:
		print(text)


static func tree() -> SceneTree:
	return world.get_tree() if world else null


## Everything that the given team is allowed to hit.
static func targets_for(team: int) -> Array:
	if world == null:
		return []
	return world.get_tree().get_nodes_in_group("team_%d" % (1 - team))


static func in_camp(pos: Vector3, margin: float = 0.0) -> bool:
	return flat_distance(pos, CAMP_CENTER) < CAMP_RADIUS + margin


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
