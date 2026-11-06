class_name CharacterModel
extends Node3D
## A 3D animated character (see data/models.json). Handles:
##  - showing only the weapon this character should hold
##  - attaching extra weapons to a hand bone
##  - idle / run / attack / death animations
##  - a colour tint used for hit flashes, burning, chill, magic/rare monsters

const BLEND := 0.12

var def: Dictionary
var anim: AnimationPlayer
var _overlay: StandardMaterial3D
var _action_left := 0.0
var _dead := false

static var _cache := {}


## Returns null if the model id is unknown (the actor then uses a plain capsule).
static func create(model_id: String) -> CharacterModel:
	var d := DB.model(model_id)
	if d.is_empty():
		return null
	var m := CharacterModel.new()
	m.def = d
	return m


static func load_scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


func _ready() -> void:
	var packed := load_scene(def["file"])
	if packed == null:
		push_error("Could not load model " + String(def["file"]))
		return
	var inst: Node3D = packed.instantiate()
	inst.rotation.y = PI  # the models face +Z; the game treats -Z as forward
	add_child(inst)
	scale = Vector3.ONE * float(def.get("scale", 0.72))

	# Hide every hand-held item except the ones this character uses.
	var keep: Array = def.get("keep_weapons", [])
	for att in inst.find_children("handslot*", "BoneAttachment3D", true, false):
		for c in att.get_children():
			if c is MeshInstance3D:
				c.visible = keep.has(String(c.name))

	# Attach extra weapons (e.g. an axe for skeleton warriors).
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	for a in def.get("attach", []):
		var weapon_scene := load_scene(a["file"])
		if skel == null or weapon_scene == null:
			continue
		var ba := BoneAttachment3D.new()
		ba.bone_name = a["bone"]
		skel.add_child(ba)
		ba.add_child(weapon_scene.instantiate())

	# Modular (Quaternius) characters: the model in "file" is only used as an
	# invisible puppet that plays the animations; the visible body is built from
	# the outfit pieces and copies the puppet's pose every frame.
	var visible_root: Node3D = inst
	if def.has("parts"):
		visible_root = _build_modular(inst, skel)

	# One shared see-through overlay material for tints.
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(0, 0, 0, 0)
	for mi in visible_root.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _overlay
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	anim = inst.find_child("AnimationPlayer", true, false)
	if anim:
		for loop_name in [def.get("idle", "Idle"), def.get("run", "Running_A")]:
			if anim.has_animation(loop_name):
				anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		anim.play(def.get("idle", "Idle"))


## Builds the visible Quaternius body, hides the puppet, moves the puppet's
## weapons into the new body's hand, and starts copying the pose across.
func _build_modular(puppet: Node3D, puppet_skel: Skeleton3D) -> Node3D:
	var parts: Array = def["parts"]
	var body := ModularBody.assemble(parts[0], parts.slice(1))
	body.rotation.y = PI
	body.scale = Vector3.ONE * float(def.get("body_scale", 1.0))
	add_child(body)
	var body_skel: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]

	# Weapons: keep their grip relative to the hand exactly as on the puppet.
	var keep: Array = def.get("keep_weapons", [])
	for att in puppet.find_children("handslot*", "BoneAttachment3D", true, false):
		var src_slot := puppet_skel.find_bone(String(att.bone_name))
		var src_hand := puppet_skel.get_bone_parent(puppet_skel.get_bone_parent(src_slot))  # handslot -> hand -> wrist
		var side := "l" if String(att.bone_name).ends_with(".l") else "r"
		var dst_hand := body_skel.find_bone("hand_" + side)
		if src_hand < 0 or dst_hand < 0:
			continue
		for c in att.get_children():
			if not (c is MeshInstance3D and keep.has(String(c.name))):
				continue
			var weapon: MeshInstance3D = c
			var rel := puppet_skel.get_bone_global_rest(src_hand).affine_inverse() \
				* puppet_skel.get_bone_global_rest(src_slot) * weapon.transform
			var ba := BoneAttachment3D.new()
			ba.bone_name = "hand_" + side
			body_skel.add_child(ba)
			var offset := Node3D.new()  # turns the new hand's axes into the puppet's
			offset.basis = Basis(body_skel.get_bone_global_rest(dst_hand).basis.get_rotation_quaternion().inverse() \
				* puppet_skel.get_bone_global_rest(src_hand).basis.get_rotation_quaternion())
			offset.scale = Vector3.ONE * float(def.get("weapon_scale", 1.0))
			ba.add_child(offset)
			att.remove_child(weapon)
			offset.add_child(weapon)
			weapon.transform = rel

	puppet.visible = false
	var retarget := AnimRetarget.new()
	add_child(retarget)
	retarget.setup(puppet_skel, body_skel)
	return body


## Called every physics frame by the actor.
func update(speed: float, delta: float) -> void:
	if anim == null or _dead:
		return
	if _action_left > 0.0:
		_action_left -= delta
		return
	var moving := speed > 0.3
	var want: String = def.get("run", "Running_A") if moving else def.get("idle", "Idle")
	if anim.current_animation != want:
		anim.play(want, BLEND)
	# Match leg speed to how fast the character actually moves.
	anim.speed_scale = clampf(speed / float(def.get("run_speed", 5.5)), 0.6, 1.8) if moving else 1.0


## Plays an attack/cast animation squeezed into `duration` seconds.
func play_action(anim_name: String, duration: float) -> void:
	if anim == null or _dead or not anim.has_animation(anim_name):
		return
	var length := anim.get_animation(anim_name).length
	var spd := clampf(length / maxf(duration, 0.05), 0.8, 3.5)
	anim.speed_scale = 1.0
	if anim.current_animation == anim_name:
		anim.seek(0.0, true)
	anim.play(anim_name, 0.06, spd)
	_action_left = length / spd


## Which animation fits a compiled skill.
func action_for(c: Dictionary) -> String:
	var acts: Dictionary = def.get("actions", {})
	var tags: Array = c.get("tags", [])
	var behavior: String = c.get("behavior", "")
	var key := ""
	if tags.has("attack"):
		key = "ranged" if behavior == "projectile" else ("nova" if behavior == "nova" else "melee")
	else:
		key = "spell_nova" if behavior == "nova" else "spell"
	if acts.has(key):
		return acts[key]
	if key.begins_with("spell") and acts.has("spell"):
		return acts["spell"]
	return acts.get("melee", "Idle")


func play_death() -> void:
	_dead = true
	if anim:
		anim.speed_scale = 1.0
		anim.play(def.get("death", "Death_A"), 0.08)


func revive() -> void:
	_dead = false
	_action_left = 0.0
	if anim:
		anim.play(def.get("idle", "Idle"))


## strength 0 = no tint, 1 = solid colour.
func set_tint(color: Color, strength: float) -> void:
	if _overlay:
		_overlay.albedo_color = Color(color.r, color.g, color.b, clampf(strength, 0.0, 0.8))
