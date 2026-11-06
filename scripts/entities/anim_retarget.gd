class_name AnimRetarget
extends Node
## Copies the pose of one skeleton (the "source", which plays animations) onto
## a differently built skeleton (the "target", which you see), every frame.
##
## How: both skeletons stand in the same T-pose at rest. For each mapped bone
## we take how far the source bone has rotated away from its rest pose (in
## model space) and apply that same rotation to the target bone. This works
## even though the bones' own axes and lengths differ between the two rigs.
## The hips' movement (bobbing while running) is copied too, scaled to height.
##
## On top of the straight copy, three touch-ups make the result look natural
## on a normally-proportioned body (the source animations are for chibis):
##  - arm_down: lowers the arms when they are held out to the sides (chibis
##    hold them wide), but not when they point forward to aim or strike
##  - in-between bones (middle spine, neck) blend their neighbours, so the back
##    and neck curve smoothly instead of bending at one joint
##  - finger_curl: curls the fingers so hands look relaxed / grip weapons

## source bone name -> target bone name. KayKit rig -> Quaternius rig.
const KAYKIT_TO_QUATERNIUS := {
	"hips": "pelvis",
	"spine": "spine_01",
	"chest": "spine_03",
	"head": "Head",
	"upperarm.l": "upperarm_l", "lowerarm.l": "lowerarm_l", "wrist.l": "hand_l",
	"upperarm.r": "upperarm_r", "lowerarm.r": "lowerarm_r", "wrist.r": "hand_r",
	"upperleg.l": "thigh_l", "lowerleg.l": "calf_l", "foot.l": "foot_l", "toes.l": "ball_l",
	"upperleg.r": "thigh_r", "lowerleg.r": "calf_r", "foot.r": "foot_r", "toes.r": "ball_r",
}

## Target bones that get a blend of two source bones: [src_a, src_b, weight of b].
const BLENDS := {
	"spine_02": ["spine", "chest", 0.5],
	"neck_01": ["chest", "head", 0.5],
}
const ARM_BONES := {"l": ["upperarm_l", "lowerarm_l", "hand_l"], "r": ["upperarm_r", "lowerarm_r", "hand_r"]}
const FINGERS := ["index", "middle", "ring", "pinky"]

var src: Skeleton3D
var dst: Skeleton3D
var _map := {}            ## target bone index -> source bone index
var _order: Array = []    ## target bones, parents before children
var _src_rest := {}       ## source bone index -> rest rotation (model space)
var _dst_rest: Array = [] ## target rest rotation (model space), per bone
var _dst_local_rest: Array = []
var _global: Array = []   ## scratch: target pose rotations this frame
var _src_hips := -1
var _dst_hips := -1
var _hip_scale := 1.0
var _blend := {}          ## target bone index -> [src a, src b, weight]
var _correction := {}     ## target bone index -> side ("l"/"r") for arm_down
var _arm_q := {}          ## side -> full arm_down rotation
var _arm_src := {}        ## side -> source upper arm bone
var _arm_amount := {"l": 0.0, "r": 0.0}  ## side -> how much arm_down applies this frame


func setup(source: Skeleton3D, target: Skeleton3D, options: Dictionary = {}, mapping: Dictionary = KAYKIT_TO_QUATERNIUS) -> void:
	src = source
	dst = target
	process_priority = 100  # run after the source's AnimationPlayer has posed it
	for s_name in mapping:
		var s := src.find_bone(s_name)
		var d := dst.find_bone(mapping[s_name])
		if s >= 0 and d >= 0:
			_map[d] = s
			_src_rest[s] = src.get_bone_global_rest(s).basis.get_rotation_quaternion()
	var count := dst.get_bone_count()
	_dst_rest.resize(count)
	_dst_local_rest.resize(count)
	_global.resize(count)
	for i in count:
		_dst_rest[i] = dst.get_bone_global_rest(i).basis.get_rotation_quaternion()
		_dst_local_rest[i] = dst.get_bone_rest(i).basis.get_rotation_quaternion()
	# Parents first: sort bones by how deep they are in the hierarchy.
	var depth := {}
	for i in count:
		var dpt := 0
		var p := dst.get_bone_parent(i)
		while p >= 0:
			dpt += 1
			p = dst.get_bone_parent(p)
		depth[i] = dpt
	_order = range(count)
	_order.sort_custom(func(a, b): return depth[a] < depth[b])
	# In-between bones blend two source bones.
	for d_name in BLENDS:
		var d := dst.find_bone(d_name)
		var b: Array = BLENDS[d_name]
		var a := src.find_bone(b[0])
		var c := src.find_bone(b[1])
		if d >= 0 and a >= 0 and c >= 0:
			_blend[d] = [a, c, float(b[2])]
			for s in [a, c]:
				_src_rest[s] = src.get_bone_global_rest(s).basis.get_rotation_quaternion()
	# Arms: tilt the whole arm chain down. In the T-pose the left arm points
	# along +X and the right along -X, so "down" is a turn around the Z axis.
	var arm_down := deg_to_rad(float(options.get("arm_down", 0.0)))
	for side in ARM_BONES:
		_arm_q[side] = Quaternion(Vector3(0, 0, 1), -arm_down if side == "l" else arm_down)
		_arm_src[side] = src.find_bone("upperarm." + side)
		for bone_name in ARM_BONES[side]:
			var i := dst.find_bone(bone_name)
			if i >= 0 and arm_down != 0.0:
				_correction[i] = side
	# Fingers: give them a fixed curl (they are not animated).
	_curl_fingers(deg_to_rad(float(options.get("finger_curl", 0.0))))

	_src_hips = src.find_bone("hips")
	_dst_hips = dst.find_bone(String(mapping.get("hips", "")))
	if _src_hips >= 0 and _dst_hips >= 0:
		var sh := src.get_bone_global_rest(_src_hips).origin.y
		var dh := dst.get_bone_global_rest(_dst_hips).origin.y
		_hip_scale = dh / sh if sh > 0.001 else 1.0


func _process(_delta: float) -> void:
	apply()


func apply() -> void:
	if not is_instance_valid(src) or not is_instance_valid(dst):
		return
	# Where is each upper arm pointing? Full arm_down when it points out to the
	# side, none when it points forward, up or down.
	for side in _arm_src:
		var s: int = _arm_src[side]
		if s >= 0 and _src_rest.has(s):
			var dir: Vector3 = _delta(s) * Vector3(1 if side == "l" else -1, 0, 0)
			_arm_amount[side] = clampf(absf(dir.x) * 1.3 - 0.15, 0.0, 1.0)
	for i in _order:
		var p := dst.get_bone_parent(i)
		var parent_q: Quaternion = _global[p] if p >= 0 else Quaternion.IDENTITY
		if _map.has(i) or _blend.has(i):
			var delta: Quaternion
			if _map.has(i):
				delta = _delta(_map[i])
			else:
				var b: Array = _blend[i]
				delta = _delta(b[0]).slerp(_delta(b[1]), b[2])
			var rest: Quaternion = _dst_rest[i]
			if _correction.has(i):
				var side: String = _correction[i]
				rest = Quaternion.IDENTITY.slerp(_arm_q[side], _arm_amount[side]) * rest
			var g: Quaternion = delta * rest
			dst.set_bone_pose_rotation(i, (parent_q.inverse() * g).normalized())
			_global[i] = g
		else:
			# Unmapped bones (fingers, neck...) keep their rest pose.
			_global[i] = parent_q * _dst_local_rest[i]
	if _src_hips >= 0 and _dst_hips >= 0:
		var moved := src.get_bone_pose_position(_src_hips) - src.get_bone_rest(_src_hips).origin
		dst.set_bone_pose_position(_dst_hips, dst.get_bone_rest(_dst_hips).origin + moved * _hip_scale)


## How far a source bone has turned away from its rest pose (model space).
func _delta(s: int) -> Quaternion:
	return src.get_bone_global_pose(s).basis.get_rotation_quaternion() * _src_rest[s].inverse()


## Bends each finger joint toward the palm by `angle` (thumb a third as much),
## by changing the fingers' resting rotation once.
func _curl_fingers(angle: float) -> void:
	if absf(angle) < 0.001:
		return
	for side in ["l", "r"]:
		var sign := -1.0 if side == "l" else 1.0  # palms face down in the T-pose
		for f in FINGERS + ["thumb"]:
			var a := angle * (0.35 if f == "thumb" else 1.0)
			var axis := Vector3(0, 1, 0) if f == "thumb" else Vector3(0, 0, 1)
			for joint in [1, 2, 3]:
				var i := dst.find_bone("%s_%02d_%s" % [f, joint, side])
				if i < 0:
					continue
				# Turn the joint in model space, then express it relative to its parent.
				var p := dst.get_bone_parent(i)
				var parent_rest: Quaternion = _dst_rest[p]
				var parent_now := _curled_global(p)
				var turned: Quaternion = Quaternion(axis, sign * a) * parent_now * parent_rest.inverse() * _dst_rest[i]
				var local: Quaternion = (parent_now.inverse() * turned).normalized()
				_dst_local_rest[i] = local
				dst.set_bone_pose_rotation(i, local)


## The resting model-space rotation of a bone after earlier finger curls.
func _curled_global(i: int) -> Quaternion:
	var chain: Array = []
	var b := i
	while b >= 0:
		chain.push_front(b)
		b = dst.get_bone_parent(b)
	var q := Quaternion.IDENTITY
	for c in chain:
		q = q * _dst_local_rest[c]
	return q
