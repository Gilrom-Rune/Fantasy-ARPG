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


func setup(source: Skeleton3D, target: Skeleton3D, mapping: Dictionary = KAYKIT_TO_QUATERNIUS) -> void:
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
	for i in _order:
		var p := dst.get_bone_parent(i)
		var parent_q: Quaternion = _global[p] if p >= 0 else Quaternion.IDENTITY
		if _map.has(i):
			var s: int = _map[i]
			var src_q := src.get_bone_global_pose(s).basis.get_rotation_quaternion()
			var g: Quaternion = (src_q * _src_rest[s].inverse()) * _dst_rest[i]
			dst.set_bone_pose_rotation(i, (parent_q.inverse() * g).normalized())
			_global[i] = g
		else:
			# Unmapped bones (fingers, neck...) keep their rest pose.
			_global[i] = parent_q * _dst_local_rest[i]
	if _src_hips >= 0 and _dst_hips >= 0:
		var moved := src.get_bone_pose_position(_src_hips) - src.get_bone_rest(_src_hips).origin
		dst.set_bone_pose_position(_dst_hips, dst.get_bone_rest(_dst_hips).origin + moved * _hip_scale)
